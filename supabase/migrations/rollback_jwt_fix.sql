-- Rollback Script for JWT Vulnerability Fix
-- Date: 2025-09-10
-- Purpose: Emergency rollback if the security fix causes issues
-- WARNING: This will restore the vulnerable email-based authentication

-- ============================================================================
-- IMPORTANT: BEFORE RUNNING THIS ROLLBACK
-- ============================================================================
-- 1. Document why rollback is needed
-- 2. Have a plan to re-implement security fix
-- 3. Notify security team of temporary vulnerability window
-- 4. Enable additional monitoring during rollback period

-- ============================================================================
-- STEP 1: RESTORE OLD FUNCTION (TEMPORARILY VULNERABLE)
-- ============================================================================

-- Drop the secure function
DROP FUNCTION IF EXISTS user_has_client_access(UUID);
DROP FUNCTION IF EXISTS is_admin();
DROP FUNCTION IF EXISTS check_rate_limit(UUID, INTEGER);

-- Restore the old function (WITH SECURITY WARNING)
CREATE OR REPLACE FUNCTION user_has_client_access(p_client_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  -- WARNING: This is the vulnerable version using email claims
  -- This should only be used temporarily during rollback
  
  -- Log that we're using vulnerable version
  RAISE WARNING 'Using vulnerable email-based admin check - this is temporary!';
  
  RETURN (
    -- VULNERABLE: Checking email from JWT
    EXISTS (
      SELECT 1 FROM user_admins 
      WHERE email = auth.jwt() ->> 'email' 
      AND active = true
    )
    OR
    -- User check remains secure
    EXISTS (
      SELECT 1 FROM users 
      WHERE id::uuid = auth.uid() 
      AND client_uuid = p_client_uuid
    )
  );
END;
$$;

-- Add warning comment
COMMENT ON FUNCTION user_has_client_access IS 'WARNING: Rolled back to vulnerable version - uses JWT email claims';

-- ============================================================================
-- STEP 2: RESTORE OLD RLS POLICIES
-- ============================================================================

-- Drop secure policies
DROP POLICY IF EXISTS "users_insert_policy_secure" ON users;
DROP POLICY IF EXISTS "users_delete_policy_secure" ON users;
DROP POLICY IF EXISTS "users_update_policy_secure" ON users;
DROP POLICY IF EXISTS "organizations_modify_policy_secure" ON organizations;
DROP POLICY IF EXISTS "organizations_update_policy_secure" ON organizations;
DROP POLICY IF EXISTS "organizations_delete_policy_secure" ON organizations;
DROP POLICY IF EXISTS "org_positions_modify_policy_secure" ON org_positions;
DROP POLICY IF EXISTS "Only admins can create admins_secure" ON user_admins;
DROP POLICY IF EXISTS "Only admins can update admins_secure" ON user_admins;

-- Restore old policies (vulnerable version)
CREATE POLICY "users_insert_delete_policy" 
ON users FOR INSERT 
WITH CHECK (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "users_delete_policy" 
ON users FOR DELETE 
USING (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "users_update_policy" 
ON users FOR UPDATE 
USING (
  user_has_client_access(client_uuid) 
  AND (
    id::uuid = auth.uid()
    OR EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
  )
)
WITH CHECK (
  user_has_client_access(client_uuid) 
  AND (
    id::uuid = auth.uid()
    OR EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
  )
);

CREATE POLICY "organizations_modify_policy" 
ON organizations FOR INSERT 
WITH CHECK (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "organizations_update_policy" 
ON organizations FOR UPDATE 
USING (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "organizations_delete_policy" 
ON organizations FOR DELETE 
USING (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "org_positions_modify_policy" 
ON org_positions FOR ALL 
USING (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "Only admins can create admins" 
ON user_admins FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

CREATE POLICY "Only admins can update admins" 
ON user_admins FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- ============================================================================
-- STEP 3: KEEP AUDIT LOGGING (Don't remove security monitoring)
-- ============================================================================

-- Keep the audit log table and continue logging
-- This helps monitor for exploitation during vulnerable period

-- ============================================================================
-- STEP 4: LOG ROLLBACK EVENT
-- ============================================================================

INSERT INTO security_audit_log (
  event_type,
  user_id,
  success,
  error_message,
  metadata
) VALUES (
  'security_rollback',
  auth.uid(),
  true,
  'JWT vulnerability fix rolled back - system temporarily vulnerable',
  jsonb_build_object(
    'rollback_time', NOW(),
    'rollback_user', auth.jwt() ->> 'email',
    'warning', 'Email-based authentication restored - vulnerable to JWT spoofing'
  )
);

-- ============================================================================
-- STEP 5: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION user_has_client_access(UUID) TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check that rollback succeeded
SELECT 
  'ROLLBACK STATUS' as status,
  EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'user_has_client_access') as function_exists,
  COUNT(*) as vulnerable_policies
FROM pg_policies
WHERE schemaname = 'public'
AND qual::text LIKE '%auth.jwt()%email%';

-- ============================================================================
-- CRITICAL WARNINGS
-- ============================================================================

DO $$
BEGIN
  RAISE WARNING '==================================================';
  RAISE WARNING 'SECURITY ROLLBACK COMPLETED';
  RAISE WARNING 'System is now VULNERABLE to JWT email spoofing!';
  RAISE WARNING 'This should only be temporary!';
  RAISE WARNING 'Re-apply security fix ASAP!';
  RAISE WARNING '==================================================';
END $$;

-- ============================================================================
-- MONITORING QUERY
-- ============================================================================

-- Run this regularly to check for exploitation attempts
SELECT 
  date_trunc('hour', created_at) as hour,
  COUNT(*) FILTER (WHERE event_type = 'admin_client_access') as admin_accesses,
  COUNT(*) FILTER (WHERE event_type = 'unauthorized_client_access') as unauthorized_attempts,
  COUNT(DISTINCT user_email) as unique_users
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY 1
ORDER BY 1 DESC;
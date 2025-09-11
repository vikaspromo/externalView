-- ============================================================================
-- Migration: Fix RLS Non-Volatile Function Error
-- Date: 2025-09-10
-- Purpose: Remove INSERT/UPDATE operations from STABLE functions used in RLS
-- Error: "INSERT is not allowed in a non-volatile function"
-- ============================================================================

-- Drop the existing function
DROP FUNCTION IF EXISTS user_has_client_access(UUID);

-- Recreate the function without INSERT/UPDATE operations
CREATE OR REPLACE FUNCTION user_has_client_access(p_client_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN := false;
  v_has_access BOOLEAN := false;
BEGIN
  -- Check if user is admin using secure auth.uid()
  SELECT EXISTS (
    SELECT 1 FROM user_admins 
    WHERE auth_user_id = auth.uid() 
    AND active = true
    AND auth_user_id IS NOT NULL
  ) INTO v_is_admin;
  
  -- If admin, grant access (removed audit logging)
  IF v_is_admin THEN
    RETURN true;
  END IF;
  
  -- Check if regular user belongs to this client
  SELECT EXISTS (
    SELECT 1 FROM users 
    WHERE id::uuid = auth.uid() 
    AND client_uuid = p_client_uuid
    AND deleted_at IS NULL
  ) INTO v_has_access;
  
  RETURN v_has_access;
END;
$$;

-- Create a separate VOLATILE function for audit logging
CREATE OR REPLACE FUNCTION log_client_access(
  p_client_uuid UUID,
  p_access_type TEXT DEFAULT 'client_access'
)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_user_email TEXT;
  v_is_admin BOOLEAN;
BEGIN
  -- Get user email for logging
  v_user_email := auth.jwt() ->> 'email';
  
  -- Check if admin
  SELECT EXISTS (
    SELECT 1 FROM user_admins 
    WHERE auth_user_id = auth.uid() 
    AND active = true
  ) INTO v_is_admin;
  
  -- Log the access attempt
  INSERT INTO security_audit_log (
    event_type, 
    user_id, 
    user_email,
    client_uuid, 
    success,
    metadata
  ) VALUES (
    p_access_type,
    auth.uid(),
    v_user_email,
    p_client_uuid,
    true,
    jsonb_build_object(
      'is_admin', v_is_admin,
      'timestamp', NOW()
    )
  );
  
  -- Update admin last verified timestamp if admin
  IF v_is_admin THEN
    UPDATE user_admins 
    SET last_verified_at = NOW() 
    WHERE auth_user_id = auth.uid();
  END IF;
END;
$$;

-- Fix similar issues in other functions
DROP FUNCTION IF EXISTS get_user_client_uuid();

CREATE OR REPLACE FUNCTION get_user_client_uuid()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_client_uuid UUID;
BEGIN
  -- Check if user is admin first
  IF EXISTS (
    SELECT 1 FROM user_admins 
    WHERE auth_user_id = auth.uid() 
    AND active = true
  ) THEN
    RETURN NULL; -- Admins don't have a specific client
  END IF;
  
  -- Get user's client_uuid
  SELECT client_uuid INTO v_client_uuid
  FROM users
  WHERE id::uuid = auth.uid()
  AND deleted_at IS NULL;
  
  RETURN v_client_uuid;
END;
$$;

-- Ensure is_admin function is also STABLE without side effects
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_admins 
    WHERE auth_user_id = auth.uid() 
    AND active = true
    AND auth_user_id IS NOT NULL
  );
END;
$$;

-- Grant permissions on the new logging function
GRANT EXECUTE ON FUNCTION log_client_access(UUID, TEXT) TO authenticated;

-- Create a helper function to safely check rate limits without INSERT
CREATE OR REPLACE FUNCTION is_rate_limited(p_user_id UUID, p_limit INTEGER DEFAULT 100)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_request_count INTEGER;
BEGIN
  -- Count requests in last minute (read-only operation)
  SELECT COUNT(*) INTO v_request_count
  FROM security_audit_log
  WHERE user_id = p_user_id
  AND created_at > NOW() - INTERVAL '1 minute';
  
  RETURN v_request_count > p_limit;
END;
$$;

-- Drop the old rate limiting function that performed INSERT
DROP FUNCTION IF EXISTS check_rate_limit(UUID, INTEGER);

-- Grant permission on the new function
GRANT EXECUTE ON FUNCTION is_rate_limited(UUID, INTEGER) TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify all RLS functions are STABLE or IMMUTABLE and don't modify data
SELECT 
  proname as function_name,
  provolatile as volatility,
  CASE provolatile
    WHEN 'i' THEN 'IMMUTABLE'
    WHEN 's' THEN 'STABLE'
    WHEN 'v' THEN 'VOLATILE'
  END as volatility_text
FROM pg_proc
WHERE proname IN (
  'user_has_client_access',
  'get_user_client_uuid',
  'validate_client_uuid',
  'is_admin',
  'is_rate_limited'
)
ORDER BY proname;

-- ============================================================================
-- FIX TRIGGER FUNCTIONS
-- ============================================================================

-- The soft_delete_record function should not be used as a trigger
-- since it performs INSERT operations. Remove it if it exists.
DROP FUNCTION IF EXISTS soft_delete_record() CASCADE;

-- Create a simpler version that just sets deleted_at
CREATE OR REPLACE FUNCTION set_deleted_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Simply set the deleted_at timestamp
  NEW.deleted_at := NOW();
  RETURN NEW;
END;
$$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'RLS FUNCTION VOLATILITY FIXED';
  RAISE NOTICE 'All RLS functions are now STABLE without side effects';
  RAISE NOTICE 'Audit logging moved to separate VOLATILE function';
  RAISE NOTICE 'Rate limiting is now read-only';
  RAISE NOTICE '==================================================';
END $$;
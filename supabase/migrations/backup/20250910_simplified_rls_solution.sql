-- Migration: Simplified RLS Solution
-- Date: 2025-09-10
-- Purpose: Single consolidated approach for admin and user data access

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES AND FUNCTIONS
-- ============================================================================

-- Drop existing functions
DROP FUNCTION IF EXISTS get_clients_for_user();
DROP FUNCTION IF EXISTS get_client_organizations(UUID);
DROP FUNCTION IF EXISTS get_organization_details(UUID, UUID);
DROP FUNCTION IF EXISTS update_organization_notes(UUID, UUID, TEXT);

-- Drop all existing policies
DROP POLICY IF EXISTS "admin_or_own_client" ON clients;
DROP POLICY IF EXISTS "admin_or_own_client_v2" ON clients;
DROP POLICY IF EXISTS "admin_or_same_client_users" ON users;
DROP POLICY IF EXISTS "admin_or_same_client_users_v2" ON users;
DROP POLICY IF EXISTS "update_own_or_admin" ON users;
DROP POLICY IF EXISTS "update_own_or_admin_v2" ON users;
DROP POLICY IF EXISTS "admin_or_own_client_history" ON client_org_history;
DROP POLICY IF EXISTS "admin_or_own_client_history_v2" ON client_org_history;

-- ============================================================================
-- STEP 2: CREATE A SINGLE SECURITY CONTEXT FUNCTION
-- ============================================================================

-- This function determines if the current user can access data for a given client
CREATE OR REPLACE FUNCTION user_has_client_access(p_client_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    -- User is an admin
    EXISTS (
      SELECT 1 FROM user_admins 
      WHERE email = auth.jwt() ->> 'email' 
      AND active = true
    )
    OR
    -- User belongs to this client
    EXISTS (
      SELECT 1 FROM users 
      WHERE id::uuid = auth.uid() 
      AND client_uuid = p_client_uuid
    )
  );
END;
$$;

-- ============================================================================
-- STEP 3: CREATE SIMPLE RLS POLICIES USING THE FUNCTION
-- ============================================================================

-- CLIENTS TABLE
CREATE POLICY "client_access_policy" 
ON clients FOR ALL 
USING (user_has_client_access(uuid))
WITH CHECK (user_has_client_access(uuid));

-- USERS TABLE
CREATE POLICY "users_access_policy" 
ON users FOR SELECT 
USING (user_has_client_access(client_uuid));

CREATE POLICY "users_update_policy" 
ON users FOR UPDATE 
USING (
  user_has_client_access(client_uuid) 
  AND (
    id::uuid = auth.uid() -- Users can only update their own record
    OR EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true) -- Admins can update any
  )
)
WITH CHECK (
  user_has_client_access(client_uuid) 
  AND (
    id::uuid = auth.uid()
    OR EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
  )
);

CREATE POLICY "users_insert_delete_policy" 
ON users FOR INSERT 
WITH CHECK (
  -- Only admins can insert new users
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

CREATE POLICY "users_delete_policy" 
ON users FOR DELETE 
USING (
  -- Only admins can delete users
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

-- CLIENT_ORG_HISTORY TABLE
CREATE POLICY "client_org_history_access_policy" 
ON client_org_history FOR SELECT 
USING (user_has_client_access(client_uuid));

CREATE POLICY "client_org_history_modify_policy" 
ON client_org_history FOR INSERT 
WITH CHECK (user_has_client_access(client_uuid));

CREATE POLICY "client_org_history_update_policy" 
ON client_org_history FOR UPDATE 
USING (user_has_client_access(client_uuid))
WITH CHECK (user_has_client_access(client_uuid));

CREATE POLICY "client_org_history_delete_policy" 
ON client_org_history FOR DELETE 
USING (user_has_client_access(client_uuid));

-- ORGANIZATIONS TABLE (all authenticated users can read)
CREATE POLICY "organizations_read_policy" 
ON organizations FOR SELECT 
USING (auth.uid() IS NOT NULL);

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

-- ORG_POSITIONS TABLE (all authenticated users can read)
CREATE POLICY "org_positions_read_policy" 
ON org_positions FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "org_positions_modify_policy" 
ON org_positions FOR ALL 
USING (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_admins WHERE email = auth.jwt() ->> 'email' AND active = true)
);

-- ============================================================================
-- STEP 4: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION user_has_client_access(UUID) TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Test the function
SELECT 
  user_has_client_access('36fee78e-9bac-4443-9339-6f53003d3250'::uuid) as can_access_att,
  auth.jwt() ->> 'email' as current_user;
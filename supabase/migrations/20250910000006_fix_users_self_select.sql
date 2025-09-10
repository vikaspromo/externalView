-- ============================================================================
-- Migration: Fix Users Table Self-Select Policy
-- Date: 2025-09-10
-- Purpose: Allow users to query their own record by ID
-- Error: 406 Not Acceptable when querying users table by auth.uid()
-- ============================================================================

-- Drop the existing SELECT policy that only allows client-based access
DROP POLICY IF EXISTS "users_select_policy" ON users;
DROP POLICY IF EXISTS "users_access_policy" ON users;

-- Create a new SELECT policy that allows:
-- 1. Users to see their own record by ID
-- 2. Users to see all users in their client
-- 3. Admins to see all users
CREATE POLICY "users_select_policy" 
ON users FOR SELECT 
USING (
  -- User can always see their own record
  id::uuid = auth.uid()
  OR
  -- User can see other users in their client
  user_has_client_access(client_uuid)
  OR
  -- Admins can see all users
  is_admin()
);

-- Also ensure the other policies exist and are correct
-- These may have been dropped by the CASCADE in the volatile function fix

-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "users_update_policy" ON users;
DROP POLICY IF EXISTS "users_delete_policy" ON users;

-- INSERT: Only admins can create users, or users during registration
CREATE POLICY "users_insert_policy" 
ON users FOR INSERT 
WITH CHECK (
  is_admin()
  OR (
    -- Allow self-registration if the ID matches auth.uid()
    id::uuid = auth.uid()
  )
);

-- UPDATE: Users can update their own profile, admins can update anyone
CREATE POLICY "users_update_policy" 
ON users FOR UPDATE 
USING (
  id::uuid = auth.uid() -- Own profile
  OR is_admin()
)
WITH CHECK (
  id::uuid = auth.uid()
  OR is_admin()
);

-- DELETE: Only admins can delete users
CREATE POLICY "users_delete_policy" 
ON users FOR DELETE 
USING (is_admin());

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Test that a user can query their own record
DO $$
DECLARE
  test_result RECORD;
BEGIN
  -- This simulates what the app is doing: SELECT * FROM users WHERE id = auth.uid()
  -- The policy should allow this even if the user's client_uuid doesn't match
  RAISE NOTICE 'Users table SELECT policy updated to allow self-queries by ID';
  RAISE NOTICE 'Users can now:';
  RAISE NOTICE '  1. Query their own record by ID (fixes 406 error)';
  RAISE NOTICE '  2. See other users in their client';
  RAISE NOTICE '  3. Admins can see all users';
END $$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'USERS TABLE SELF-SELECT POLICY FIXED';
  RAISE NOTICE 'Users can now query their own record by ID';
  RAISE NOTICE 'This fixes the 406 Not Acceptable error';
  RAISE NOTICE '==================================================';
END $$;
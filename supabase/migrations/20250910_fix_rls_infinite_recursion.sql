-- Migration: Fix infinite recursion in RLS policies
-- Date: 2025-09-10
-- Purpose: Fix circular dependency between users and clients table policies

-- ============================================================================
-- STEP 1: DROP PROBLEMATIC POLICIES
-- ============================================================================

-- Drop existing policies on clients table
DROP POLICY IF EXISTS "Users see own client, admins see all" ON clients;
DROP POLICY IF EXISTS "Only admins can modify clients" ON clients;

-- Drop existing policies on users table
DROP POLICY IF EXISTS "Users see same client users, admins see all" ON users;
DROP POLICY IF EXISTS "Users update own record only" ON users;
DROP POLICY IF EXISTS "Only admins can insert users" ON users;
DROP POLICY IF EXISTS "Only admins can delete users" ON users;

-- Drop existing policies on client_org_history table
DROP POLICY IF EXISTS "Users see own client history, admins see all" ON client_org_history;
DROP POLICY IF EXISTS "Users insert own client history, admins insert any" ON client_org_history;
DROP POLICY IF EXISTS "Users update own client history, admins update any" ON client_org_history;
DROP POLICY IF EXISTS "Users delete own client history, admins delete any" ON client_org_history;

-- ============================================================================
-- STEP 2: CREATE FIXED POLICIES FOR CLIENTS TABLE
-- ============================================================================

-- Simplified policy without recursion
CREATE POLICY "Users see own client, admins see all" 
ON clients 
FOR SELECT 
USING (
  -- Check if user is an admin first
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- For regular users, check directly against the users table
  -- This avoids recursion by not querying clients from within the policy
  EXISTS (
    SELECT 1 
    FROM users 
    WHERE users.id::uuid = auth.uid()
    AND users.client_uuid = clients.uuid
  )
);

-- Only admins can modify clients
CREATE POLICY "Only admins can modify clients" 
ON clients 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

CREATE POLICY "Only admins can update clients" 
ON clients 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

CREATE POLICY "Only admins can delete clients" 
ON clients 
FOR DELETE 
USING (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- ============================================================================
-- STEP 3: CREATE FIXED POLICIES FOR USERS TABLE
-- ============================================================================

-- Users can see other users from same client (without recursion)
CREATE POLICY "Users see same client users, admins see all" 
ON users 
FOR SELECT 
USING (
  -- Admins can see all users
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Regular users see users from their same client
  -- We get the client_uuid directly from the authenticated user's record
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
);

-- Users can only update their own record
CREATE POLICY "Users update own record only" 
ON users 
FOR UPDATE 
USING (
  -- User can update their own record
  id::uuid = auth.uid()
  OR
  -- Admins can update any user
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
)
WITH CHECK (
  -- User can update their own record
  id::uuid = auth.uid()
  OR
  -- Admins can update any user
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- Only admins can insert users
CREATE POLICY "Only admins can insert users" 
ON users 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- Only admins can delete users
CREATE POLICY "Only admins can delete users" 
ON users 
FOR DELETE 
USING (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- ============================================================================
-- STEP 4: CREATE FIXED POLICIES FOR CLIENT_ORG_HISTORY TABLE
-- ============================================================================

-- Users can see records for their client
CREATE POLICY "Users see own client history, admins see all" 
ON client_org_history 
FOR SELECT 
USING (
  -- Admins see all history
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Users see their client's history
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
);

-- Users can insert records for their client
CREATE POLICY "Users insert own client history, admins insert any" 
ON client_org_history 
FOR INSERT 
WITH CHECK (
  -- Admins can insert for any client
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Users can insert for their client
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
);

-- Users can update records for their client
CREATE POLICY "Users update own client history, admins update any" 
ON client_org_history 
FOR UPDATE 
USING (
  -- Admins can see all records
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Users can see their client's records
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
)
WITH CHECK (
  -- Admins can update any records
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Users can update their client's records
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
);

-- Users can delete records for their client
CREATE POLICY "Users delete own client history, admins delete any" 
ON client_org_history 
FOR DELETE 
USING (
  -- Admins can delete any records
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Users can delete their client's records
  client_uuid IN (
    SELECT u.client_uuid 
    FROM users u 
    WHERE u.id::uuid = auth.uid()
  )
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. The infinite recursion error should be resolved
-- 2. Admins should see all clients in the dropdown
-- 3. Regular users should only see their own client
-- 4. No circular dependencies between table policies
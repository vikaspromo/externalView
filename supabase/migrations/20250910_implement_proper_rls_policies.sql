-- Migration: Implement Proper Row Level Security Policies
-- Date: 2025-09-10
-- Purpose: Restrict data access so users can only see data associated with their client_uuid
-- while allowing admins full access across all clients

-- ============================================================================
-- STEP 1: DROP ALL EXISTING PERMISSIVE POLICIES
-- ============================================================================
-- These policies use USING(true) which allows everyone to access everything

-- Drop permissive policies from client_org_history table
DROP POLICY IF EXISTS "Allow public read access to client_org_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public insert to client_org_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public update to client_org_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public delete from client_org_history" ON client_org_history;

-- Drop permissive policies from org_positions table
DROP POLICY IF EXISTS "Allow public read access to org_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public insert to org_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public update to org_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public delete from org_positions" ON org_positions;

-- ============================================================================
-- STEP 2: ENABLE RLS ON TABLES THAT DON'T HAVE IT
-- ============================================================================

-- Enable RLS on clients table
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- Enable RLS on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Enable RLS on organizations table
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- Note: client_org_history and org_positions already have RLS enabled

-- ============================================================================
-- STEP 3: CREATE RESTRICTIVE POLICIES FOR CLIENTS TABLE
-- ============================================================================

-- Users can only see their own client, admins can see all
CREATE POLICY "Users see own client, admins see all" 
ON clients 
FOR SELECT 
USING (
  -- Regular users see their own client
  (auth.uid() IS NOT NULL AND 
   uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins see all clients
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Only admins can insert/update/delete clients
CREATE POLICY "Only admins can modify clients" 
ON clients 
FOR ALL 
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

-- ============================================================================
-- STEP 4: CREATE RESTRICTIVE POLICIES FOR USERS TABLE  
-- ============================================================================

-- Users can see all users from their same client, admins see all
CREATE POLICY "Users see same client users, admins see all" 
ON users 
FOR SELECT 
USING (
  -- Users see others from same client
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins see all users
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Users can only update their own record
CREATE POLICY "Users update own record only" 
ON users 
FOR UPDATE 
USING (
  -- User can update their own record
  (auth.uid() IS NOT NULL AND id::uuid = auth.uid())
  OR
  -- Admins can update any user
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
)
WITH CHECK (
  -- User can update their own record
  (auth.uid() IS NOT NULL AND id::uuid = auth.uid())
  OR
  -- Admins can update any user
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Only admins can insert or delete users
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
-- STEP 5: CREATE RESTRICTIVE POLICIES FOR CLIENT_ORG_HISTORY TABLE
-- ============================================================================

-- Users can only see records for their client, admins see all
CREATE POLICY "Users see own client history, admins see all" 
ON client_org_history 
FOR SELECT 
USING (
  -- Users see their client's history
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins see all history
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Users can insert records for their client, admins can insert for any
CREATE POLICY "Users insert own client history, admins insert any" 
ON client_org_history 
FOR INSERT 
WITH CHECK (
  -- Users can insert for their client
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins can insert for any client
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Users can update records for their client, admins can update any
CREATE POLICY "Users update own client history, admins update any" 
ON client_org_history 
FOR UPDATE 
USING (
  -- Users can see their client's records
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins can see all records
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
)
WITH CHECK (
  -- Users can update their client's records
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins can update any records
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- Users can delete records for their client, admins can delete any
CREATE POLICY "Users delete own client history, admins delete any" 
ON client_org_history 
FOR DELETE 
USING (
  -- Users can delete their client's records
  (auth.uid() IS NOT NULL AND 
   client_uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
  OR
  -- Admins can delete any records
  (EXISTS (
     SELECT 1 
     FROM user_admins 
     WHERE email = auth.jwt() ->> 'email' 
     AND active = true
   ))
);

-- ============================================================================
-- STEP 6: CREATE RESTRICTIVE POLICIES FOR ORGANIZATIONS TABLE
-- ============================================================================

-- All authenticated users can read organizations (needed for UI)
-- But they can only modify organizations linked to their client
CREATE POLICY "All users can read organizations" 
ON organizations 
FOR SELECT 
USING (
  auth.uid() IS NOT NULL
);

-- Users can only insert/update/delete organizations if they're admin
CREATE POLICY "Only admins can modify organizations" 
ON organizations 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

CREATE POLICY "Only admins can update organizations" 
ON organizations 
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

CREATE POLICY "Only admins can delete organizations" 
ON organizations 
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
-- STEP 7: CREATE RESTRICTIVE POLICIES FOR ORG_POSITIONS TABLE
-- ============================================================================

-- All authenticated users can read positions (public data from ProPublica)
CREATE POLICY "All users can read org positions" 
ON org_positions 
FOR SELECT 
USING (
  auth.uid() IS NOT NULL
);

-- Only admins or service role can modify positions (populated by data pipeline)
CREATE POLICY "Only admins can modify org positions" 
ON org_positions 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

CREATE POLICY "Only admins can update org positions" 
ON org_positions 
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

CREATE POLICY "Only admins can delete org positions" 
ON org_positions 
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
-- VERIFICATION QUERIES
-- ============================================================================

-- Check that RLS is enabled on all tables:
-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND tablename IN ('clients', 'users', 'client_org_history', 'organizations', 'org_positions', 'user_admins');

-- Count policies per table:
-- SELECT schemaname, tablename, count(*) as policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- GROUP BY schemaname, tablename
-- ORDER BY tablename;

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
-- To rollback these changes, run the following:

-- -- Disable RLS on tables
-- ALTER TABLE clients DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE users DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE organizations DISABLE ROW LEVEL SECURITY;

-- -- Drop all restrictive policies on clients
-- DROP POLICY IF EXISTS "Users see own client, admins see all" ON clients;
-- DROP POLICY IF EXISTS "Only admins can modify clients" ON clients;

-- -- Drop all restrictive policies on users
-- DROP POLICY IF EXISTS "Users see same client users, admins see all" ON users;
-- DROP POLICY IF EXISTS "Users update own record only" ON users;
-- DROP POLICY IF EXISTS "Only admins can insert users" ON users;
-- DROP POLICY IF EXISTS "Only admins can delete users" ON users;

-- -- Drop all restrictive policies on client_org_history
-- DROP POLICY IF EXISTS "Users see own client history, admins see all" ON client_org_history;
-- DROP POLICY IF EXISTS "Users insert own client history, admins insert any" ON client_org_history;
-- DROP POLICY IF EXISTS "Users update own client history, admins update any" ON client_org_history;
-- DROP POLICY IF EXISTS "Users delete own client history, admins delete any" ON client_org_history;

-- -- Drop all restrictive policies on organizations
-- DROP POLICY IF EXISTS "All users can read organizations" ON organizations;
-- DROP POLICY IF EXISTS "Only admins can modify organizations" ON organizations;
-- DROP POLICY IF EXISTS "Only admins can update organizations" ON organizations;
-- DROP POLICY IF EXISTS "Only admins can delete organizations" ON organizations;

-- -- Drop all restrictive policies on org_positions
-- DROP POLICY IF EXISTS "All users can read org positions" ON org_positions;
-- DROP POLICY IF EXISTS "Only admins can modify org positions" ON org_positions;
-- DROP POLICY IF EXISTS "Only admins can update org positions" ON org_positions;
-- DROP POLICY IF EXISTS "Only admins can delete org positions" ON org_positions;

-- -- Restore permissive policies (for development only)
-- CREATE POLICY "Allow public read access to client_org_history" ON client_org_history FOR SELECT USING (true);
-- CREATE POLICY "Allow public insert to client_org_history" ON client_org_history FOR INSERT WITH CHECK (true);
-- CREATE POLICY "Allow public update to client_org_history" ON client_org_history FOR UPDATE USING (true) WITH CHECK (true);
-- CREATE POLICY "Allow public delete from client_org_history" ON client_org_history FOR DELETE USING (true);

-- CREATE POLICY "Allow public read access to org_positions" ON org_positions FOR SELECT USING (true);
-- CREATE POLICY "Allow public insert to org_positions" ON org_positions FOR INSERT WITH CHECK (true);
-- CREATE POLICY "Allow public update to org_positions" ON org_positions FOR UPDATE USING (true) WITH CHECK (true);
-- CREATE POLICY "Allow public delete from org_positions" ON org_positions FOR DELETE USING (true);
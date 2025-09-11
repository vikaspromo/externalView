-- Migration: Fix RLS policies for client_org_relationships table
-- Date: 2025-01-07
-- Purpose: Add Row Level Security policies to allow data access in development
-- 
-- Current Issue: Table has RLS enabled but no policies defined, causing 406 errors
-- Solution: Add permissive policies for development, with options for production security

-- ============================================================================
-- DEVELOPMENT POLICIES (Currently Active)
-- ============================================================================
-- These policies are permissive for development. 
-- Replace with production policies before deploying to production.

-- Drop existing policies if any (safe to run multiple times)
DROP POLICY IF EXISTS "Allow public read access to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public insert to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public update to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public delete from client_org_relationships" ON client_org_relationships;

-- Create a permissive SELECT policy for development
-- This allows all users (including anonymous) to read all records
CREATE POLICY "Allow public read access to client_org_relationships" 
ON client_org_relationships 
FOR SELECT 
USING (true);  -- Always true = allow all reads

-- Optional: Add INSERT policy for development
CREATE POLICY "Allow public insert to client_org_relationships" 
ON client_org_relationships 
FOR INSERT 
WITH CHECK (true);  -- Allow all inserts

-- Optional: Add UPDATE policy for development
CREATE POLICY "Allow public update to client_org_relationships" 
ON client_org_relationships 
FOR UPDATE 
USING (true)  -- Can see all records
WITH CHECK (true);  -- Can update all records

-- Optional: Add DELETE policy for development
CREATE POLICY "Allow public delete from client_org_relationships" 
ON client_org_relationships 
FOR DELETE 
USING (true);  -- Can delete all records

-- ============================================================================
-- PRODUCTION POLICIES (Commented Out - Activate Before Production)
-- ============================================================================
-- Uncomment and customize these policies for production use

-- -- Policy 1: Authenticated users can read their client's relationships
-- CREATE POLICY "Users can read their client relationships" 
-- ON client_org_relationships 
-- FOR SELECT 
-- USING (
--   auth.uid() IS NOT NULL AND 
--   client_uuid IN (
--     SELECT client_uuid 
--     FROM users 
--     WHERE id = auth.uid()::text
--   )
-- );

-- -- Policy 2: Admin users can read all relationships
-- CREATE POLICY "Admins can read all relationships" 
-- ON client_org_relationships 
-- FOR SELECT 
-- USING (
--   auth.uid() IS NOT NULL AND 
--   EXISTS (
--     SELECT 1 FROM users 
--     WHERE id = auth.uid()::text 
--     AND client_uuid = '36fee78e-9bac-4443-9339-6f53003d3250'  -- Admin client UUID
--   )
-- );

-- -- Policy 3: Users can modify their client's relationships
-- CREATE POLICY "Users can modify their client relationships" 
-- ON client_org_relationships 
-- FOR ALL 
-- USING (
--   auth.uid() IS NOT NULL AND 
--   client_uuid IN (
--     SELECT client_uuid 
--     FROM users 
--     WHERE id = auth.uid()::text
--   )
-- )
-- WITH CHECK (
--   auth.uid() IS NOT NULL AND 
--   client_uuid IN (
--     SELECT client_uuid 
--     FROM users 
--     WHERE id = auth.uid()::text
--   )
-- );

-- ============================================================================
-- ADDITIONAL SECURITY OPTIONS
-- ============================================================================

-- -- Option 1: Service role bypass (for server-side operations)
-- -- The service role key automatically bypasses RLS, so no policy needed

-- -- Option 2: Time-based access control
-- CREATE POLICY "Access during business hours only" 
-- ON client_org_relationships 
-- FOR SELECT 
-- USING (
--   EXTRACT(HOUR FROM NOW()) BETWEEN 8 AND 18 AND  -- 8 AM to 6 PM
--   EXTRACT(DOW FROM NOW()) BETWEEN 1 AND 5  -- Monday to Friday
-- );

-- -- Option 3: IP-based restrictions (requires pg_request extension)
-- CREATE POLICY "Access from allowed IPs only" 
-- ON client_org_relationships 
-- FOR SELECT 
-- USING (
--   inet_client_addr() << '10.0.0.0/8'::inet OR  -- Private network
--   inet_client_addr() << '192.168.0.0/16'::inet  -- Local network
-- );

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if RLS is enabled (should return true)
-- SELECT relrowsecurity FROM pg_class WHERE relname = 'client_org_relationships';

-- List all policies on the table
-- SELECT pol.polname, pol.polcmd, pol.polpermissive, pol.polroles, pol.polqual, pol.polwithcheck 
-- FROM pg_policy pol 
-- JOIN pg_class cls ON pol.polrelid = cls.oid 
-- WHERE cls.relname = 'client_org_relationships';

-- Test the policies (run as different users)
-- SELECT COUNT(*) FROM client_org_relationships;  -- Should return 11 records

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback these changes, run:
-- DROP POLICY IF EXISTS "Allow public read access to client_org_relationships" ON client_org_relationships;
-- DROP POLICY IF EXISTS "Allow public insert to client_org_relationships" ON client_org_relationships;
-- DROP POLICY IF EXISTS "Allow public update to client_org_relationships" ON client_org_relationships;
-- DROP POLICY IF EXISTS "Allow public delete from client_org_relationships" ON client_org_relationships;
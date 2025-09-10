-- Migration: Fix admin access to clients table
-- Date: 2025-09-10
-- Purpose: Ensure admins can properly see all clients in the dropdown

-- ============================================================================
-- FIX CLIENTS TABLE POLICY FOR ADMIN ACCESS
-- ============================================================================

-- Drop the existing policy
DROP POLICY IF EXISTS "Users see own client, admins see all" ON clients;

-- Create a more robust policy that properly handles admin access
CREATE POLICY "Users see own client, admins see all" 
ON clients 
FOR SELECT 
USING (
  -- Check if user is an admin first (more efficient)
  EXISTS (
    SELECT 1 
    FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
  OR
  -- Regular users see their own client
  (auth.uid() IS NOT NULL AND 
   uuid IN (
     SELECT client_uuid 
     FROM users 
     WHERE id::uuid = auth.uid()
   ))
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- To test this policy:
-- 1. Login as an admin user
-- 2. Check that all clients are visible in the dropdown
-- 3. Login as a regular user  
-- 4. Check that only their client is visible
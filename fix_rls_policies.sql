-- Fix RLS Policies and Permissions
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/vohyhkjygvkaxlmqkbem/sql/new

-- 1. First, temporarily disable RLS to test
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_admins DISABLE ROW LEVEL SECURITY;

-- 2. Grant proper permissions to authenticated users
GRANT ALL ON users TO authenticated;
GRANT ALL ON user_admins TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 3. Ensure your user exists in the users table
-- Replace with your actual email
INSERT INTO users (id, email, first_name, last_name, client_uuid, active)
SELECT 
    id,
    email,
    'Admin',
    'User',
    NULL,
    true
FROM auth.users
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
ON CONFLICT (id) DO UPDATE
SET active = true;

-- 4. Ensure your user is in user_admins with proper user_id
INSERT INTO user_admins (user_id, email, active)
SELECT 
    id,
    email,
    true
FROM auth.users
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
ON CONFLICT (user_id) DO UPDATE
SET active = true;

-- 5. Re-enable RLS with working policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_admins ENABLE ROW LEVEL SECURITY;

-- 6. Drop all existing policies first
DROP POLICY IF EXISTS "Users can view their own record" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Admins can view admin records" ON user_admins;
DROP POLICY IF EXISTS "Enable read access for all users" ON users;
DROP POLICY IF EXISTS "Enable read access for all users" ON user_admins;

-- 7. Create simple, permissive policies for testing
CREATE POLICY "Enable read access for authenticated users" 
ON users FOR SELECT 
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" 
ON user_admins FOR SELECT 
TO authenticated
USING (true);

-- 8. Verify the data
SELECT 'User record:' as info;
SELECT id, email, active FROM users WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

SELECT 'Admin record:' as info;
SELECT user_id, email, active FROM user_admins WHERE user_id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

SELECT 'Auth user:' as info;
SELECT id, email FROM auth.users WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';
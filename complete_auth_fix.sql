-- Complete Authentication Fix for Production
-- Run this entire script in Supabase SQL Editor
-- This consolidates all fixes needed to resolve the 500 errors

-- ============================================================================
-- STEP 1: Add user_id column to user_admins if missing
-- ============================================================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_admins' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE user_admins 
        ADD COLUMN user_id UUID REFERENCES auth.users(id);
        
        -- Create unique constraint on user_id
        ALTER TABLE user_admins 
        ADD CONSTRAINT user_admins_user_id_key UNIQUE (user_id);
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Map your specific user to admin
-- ============================================================================
-- First, ensure your auth.users record exists (Google OAuth should have created this)
DO $$
DECLARE
    v_user_id UUID := '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';
    v_user_email TEXT;
BEGIN
    -- Get the email from auth.users
    SELECT email INTO v_user_email
    FROM auth.users
    WHERE id = v_user_id;
    
    IF v_user_email IS NOT NULL THEN
        -- Update or insert into user_admins
        INSERT INTO user_admins (email, user_id, active, granted_by, granted_at)
        VALUES (v_user_email, v_user_id, true, 'system', NOW())
        ON CONFLICT (email) DO UPDATE
        SET user_id = v_user_id,
            active = true;
        
        -- Also handle if there's a conflict on user_id
        INSERT INTO user_admins (email, user_id, active, granted_by, granted_at)
        VALUES (v_user_email, v_user_id, true, 'system', NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET email = v_user_email,
            active = true;
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Ensure users table has your record
-- ============================================================================
INSERT INTO users (id, email, first_name, last_name, client_uuid, active)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'first_name', 'Admin'),
    COALESCE(raw_user_meta_data->>'last_name', 'User'),
    NULL,
    true
FROM auth.users
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
ON CONFLICT (id) DO UPDATE
SET active = true,
    email = EXCLUDED.email;

-- ============================================================================
-- STEP 4: Fix ALL RLS policies
-- ============================================================================
-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Users can view their own record" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Enable read access for all users" ON users;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON users;

DROP POLICY IF EXISTS "Admins can view admin records" ON user_admins;
DROP POLICY IF EXISTS "Allow users to check admin status" ON user_admins;
DROP POLICY IF EXISTS "Only admins can create admins" ON user_admins;
DROP POLICY IF EXISTS "Only admins can update admins" ON user_admins;
DROP POLICY IF EXISTS "No delete on admin records" ON user_admins;
DROP POLICY IF EXISTS "Enable read access for all users" ON user_admins;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON user_admins;

-- Create correct policies for users table
CREATE POLICY "Users can view own record"
ON users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Admins can view all users"
ON users FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM user_admins
        WHERE user_admins.user_id = auth.uid()
        AND user_admins.active = true
    )
);

-- Create correct policies for user_admins table
CREATE POLICY "Anyone can check admin status"
ON user_admins FOR SELECT
USING (true);  -- This is needed for the app to check if a user is an admin

CREATE POLICY "Admins can manage admins"
ON user_admins FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM user_admins existing
        WHERE existing.user_id = auth.uid()
        AND existing.active = true
    )
);

-- ============================================================================
-- STEP 5: Map other existing admins if they exist in auth.users
-- ============================================================================
UPDATE user_admins ua
SET user_id = au.id
FROM auth.users au
WHERE ua.email = au.email
AND ua.user_id IS NULL;

-- ============================================================================
-- STEP 6: Ensure proper indexes exist
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_admins_user_id ON user_admins(user_id);
CREATE INDEX IF NOT EXISTS idx_users_id ON users(id);
CREATE INDEX IF NOT EXISTS idx_users_client_uuid ON users(client_uuid);

-- ============================================================================
-- STEP 7: Grant necessary permissions
-- ============================================================================
GRANT ALL ON users TO authenticated;
GRANT ALL ON user_admins TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
SELECT '=== Your specific user in auth.users ===' as info;
SELECT id, email, created_at 
FROM auth.users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

SELECT '=== Your record in users table ===' as info;
SELECT id, email, active, client_uuid 
FROM users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

SELECT '=== Your admin status ===' as info;
SELECT user_id, email, active, granted_by 
FROM user_admins 
WHERE user_id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

SELECT '=== All active admins ===' as info;
SELECT user_id, email, active 
FROM user_admins 
WHERE active = true;

SELECT '=== RLS policies on users ===' as info;
SELECT polname, polcmd 
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'users';

SELECT '=== RLS policies on user_admins ===' as info;
SELECT polname, polcmd 
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_admins';
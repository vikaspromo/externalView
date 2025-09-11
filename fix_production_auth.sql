-- Emergency Fix for Production Database
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/vohyhkjygvkaxlmqkbem/editor
-- This fixes the authentication issues by ensuring proper table structure

-- 1. First, check if user_admins table needs the user_id column
DO $$ 
BEGIN
    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_admins' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE user_admins 
        ADD COLUMN user_id UUID REFERENCES auth.users(id);
        
        -- Update existing records to map email to user_id if possible
        UPDATE user_admins ua
        SET user_id = au.id
        FROM auth.users au
        WHERE ua.email = au.email;
    END IF;
END $$;

-- 2. Ensure users table exists with correct structure
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    client_uuid UUID,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 3. Create index on users.id if not exists
CREATE INDEX IF NOT EXISTS idx_users_id ON users(id);
CREATE INDEX IF NOT EXISTS idx_users_client_uuid ON users(client_uuid);

-- 4. Create index on user_admins.user_id if not exists
CREATE INDEX IF NOT EXISTS idx_user_admins_user_id ON user_admins(user_id);

-- 5. Enable RLS on tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_admins ENABLE ROW LEVEL SECURITY;

-- 6. Create basic RLS policies for users table
DROP POLICY IF EXISTS "Users can view their own record" ON users;
CREATE POLICY "Users can view their own record"
    ON users FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all users" ON users;
CREATE POLICY "Admins can view all users"
    ON users FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_admins
            WHERE user_admins.user_id = auth.uid()
            AND user_admins.active = true
        )
    );

-- 7. Create basic RLS policies for user_admins table
DROP POLICY IF EXISTS "Admins can view admin records" ON user_admins;
CREATE POLICY "Admins can view admin records"
    ON user_admins FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_admins ua
            WHERE ua.user_id = auth.uid()
            AND ua.active = true
        )
    );

-- 8. Insert your user into the users table if not exists
-- Replace YOUR_EMAIL with your actual email
DO $$
DECLARE
    v_user_id UUID;
    v_email TEXT;
BEGIN
    -- Get the current user's ID and email from auth.users
    SELECT id, email INTO v_user_id, v_email
    FROM auth.users
    WHERE email = 'YOUR_EMAIL@gmail.com';  -- REPLACE WITH YOUR EMAIL
    
    IF v_user_id IS NOT NULL THEN
        -- Insert into users table if not exists
        INSERT INTO users (id, email, first_name, last_name, client_uuid, active)
        VALUES (v_user_id, v_email, 'Admin', 'User', NULL, true)
        ON CONFLICT (id) DO NOTHING;
        
        -- Also ensure admin access
        INSERT INTO user_admins (user_id, email, active, created_at)
        VALUES (v_user_id, v_email, true, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET active = true;
    END IF;
END $$;

-- 9. Grant necessary permissions
GRANT ALL ON users TO authenticated;
GRANT ALL ON user_admins TO authenticated;

-- 10. Verify the setup
SELECT 'Users table columns:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;

SELECT 'User_admins table columns:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_admins'
ORDER BY ordinal_position;

SELECT 'Current users count:' as info, COUNT(*) as count FROM users;
SELECT 'Current admins count:' as info, COUNT(*) as count FROM user_admins WHERE active = true;
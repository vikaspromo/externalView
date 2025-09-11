-- Migration: Create user_admins table for admin authorization
-- Date: 2025-09-10
-- Purpose: Store admin users separately for better security and audit trail

-- ============================================================================
-- STEP 1: CREATE TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  granted_by VARCHAR(255),
  granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- STEP 2: INSERT INITIAL ADMIN USERS
-- ============================================================================
INSERT INTO user_admins (email, granted_by, active) VALUES
  ('jebory@gmail.com', 'system', true),
  ('vikassood@gmail.com', 'system', true)
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- STEP 3: CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_admins_email ON user_admins(email);
CREATE INDEX IF NOT EXISTS idx_user_admins_active ON user_admins(active);

-- ============================================================================
-- STEP 4: ENABLE ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE user_admins ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: CREATE RLS POLICIES
-- ============================================================================
-- Allow all authenticated users to check if an email is admin
-- This is needed for the dashboard to check admin status
CREATE POLICY "Allow users to check admin status" 
ON user_admins 
FOR SELECT 
USING (true);

-- Only admins can insert new admins
CREATE POLICY "Only admins can create admins" 
ON user_admins 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- Only admins can update admin records
CREATE POLICY "Only admins can update admins" 
ON user_admins 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM user_admins 
    WHERE email = auth.jwt() ->> 'email' 
    AND active = true
  )
);

-- No one can delete admin records (for audit trail)
-- If you need to revoke access, set active = false
CREATE POLICY "No delete on admin records" 
ON user_admins 
FOR DELETE 
USING (false);

-- ============================================================================
-- STEP 6: ADD COMMENTS
-- ============================================================================
COMMENT ON TABLE user_admins IS 'Stores admin users who can switch between all client organizations';
COMMENT ON COLUMN user_admins.email IS 'Email address of the admin user';
COMMENT ON COLUMN user_admins.granted_by IS 'Who granted admin access to this user';
COMMENT ON COLUMN user_admins.granted_at IS 'When admin access was granted';
COMMENT ON COLUMN user_admins.active IS 'Whether this admin is currently active';

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. user_admins table will exist with two admin users
-- 2. RLS policies ensure only admins can modify admin list
-- 3. All users can check if an email is admin (needed for app)
-- 4. Admin records cannot be deleted (audit trail)
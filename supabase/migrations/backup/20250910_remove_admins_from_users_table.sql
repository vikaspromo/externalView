-- Migration: Remove admin users from users table
-- Date: 2025-09-10
-- Purpose: Clean up users table to only contain actual client users

-- ============================================================================
-- STEP 1: DELETE ADMIN USERS FROM USERS TABLE
-- ============================================================================
-- Remove admin users who are now managed through user_admins table
DELETE FROM users 
WHERE email IN ('jebory@gmail.com', 'vikassood@gmail.com');

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. Admin users will only exist in user_admins table
-- 2. Users table will only contain actual client users
-- 3. Admins can still login and will be authenticated via user_admins table
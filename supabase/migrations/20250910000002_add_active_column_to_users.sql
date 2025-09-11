-- Migration: Add active column to users table
-- Date: 2025-09-10
-- Purpose: Add active column to track whether users are active or inactive

-- ============================================================================
-- STEP 1: ADD ACTIVE COLUMN
-- ============================================================================
-- Add active column to users table with default value of true
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;

-- ============================================================================
-- STEP 2: SET EXISTING USERS AS ACTIVE
-- ============================================================================
-- Ensure any existing users are marked as active
UPDATE users 
SET active = true 
WHERE active IS NULL;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. Users table will have an active column to track user status
-- 2. All existing users will be marked as active
-- 3. New users will be active by default unless specified otherwise
-- Migration: Update users table - drop company column and add first_name, last_name
-- Date: 2025-09-10
-- Purpose: Replace company column with first_name and last_name for better user identification

-- ============================================================================
-- STEP 1: ADD NEW COLUMNS
-- ============================================================================
-- Add first_name and last_name columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);

-- ============================================================================
-- STEP 2: MIGRATE DATA (if needed)
-- ============================================================================
-- If there's any existing data in the company field that needs to be preserved,
-- you could parse it here. For now, we'll just leave the new fields NULL
-- since they will be populated when users are properly added

-- ============================================================================
-- STEP 3: DROP THE COMPANY COLUMN
-- ============================================================================
-- Remove the company column as it's no longer needed
ALTER TABLE users 
DROP COLUMN IF EXISTS company;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. Users table will have first_name and last_name columns instead of company
-- 2. Users can be identified by their full name (first_name + last_name)
-- 3. Each user remains associated with their client_uuid
-- 
-- Example users that can be added later:
-- Alex Kolb (ak9622@att.com) - will have first_name='Alex', last_name='Kolb'
-- Katy Parsons (kw501a@att.com) - will have first_name='Katy', last_name='Parsons'
-- Erik Hower (eh0770@att.com) - will have first_name='Erik', last_name='Hower'
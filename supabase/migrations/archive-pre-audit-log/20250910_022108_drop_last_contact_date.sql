-- Migration: Drop last_contact_date column from client_organization_history
-- Date: 2025-09-10
-- Purpose: Remove unused last_contact_date field to simplify data model

-- ============================================================================
-- STEP 1: DROP THE COLUMN
-- ============================================================================
ALTER TABLE client_organization_history 
DROP COLUMN IF EXISTS last_contact_date;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, verify the column is removed:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'client_organization_history'
-- ORDER BY ordinal_position;

-- ============================================================================
-- NOTES
-- ============================================================================
-- Frontend has been updated to no longer display or reference this field
-- This simplifies the data model by removing an unused tracking field
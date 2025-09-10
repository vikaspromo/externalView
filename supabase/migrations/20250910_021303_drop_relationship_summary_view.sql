-- Migration: Drop relationship_summary view
-- Date: 2025-09-10
-- Purpose: Remove redundant view now that client_organization_history is simplified

-- ============================================================================
-- RATIONALE
-- ============================================================================
-- The relationship_summary view is no longer needed because:
-- 1. The client_organization_history table has been simplified
-- 2. The view only adds a JOIN and column renaming
-- 3. Frontend can query the base table directly with better transparency
-- 4. Removes unnecessary abstraction layer

-- ============================================================================
-- STEP 1: DROP THE VIEW
-- ============================================================================
DROP VIEW IF EXISTS relationship_summary CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, verify the view is gone:
-- SELECT viewname FROM pg_views WHERE viewname = 'relationship_summary';
-- Should return 0 rows

-- ============================================================================
-- NOTES
-- ============================================================================
-- Frontend code has been updated to query client_organization_history directly
-- with a join to organizations table for the organization name
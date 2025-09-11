-- Migration: Remove relationship_status column
-- Date: 2025-01-10
-- Purpose: Drop the relationship_status column from client_organization_history table and update view

-- ============================================================================
-- STEP 1: DROP THE EXISTING VIEW FIRST (IT DEPENDS ON THE COLUMN)
-- ============================================================================
DROP VIEW IF EXISTS relationship_summary;

-- ============================================================================
-- STEP 2: DROP THE COLUMN FROM THE TABLE
-- ============================================================================
ALTER TABLE client_organization_history 
DROP COLUMN IF EXISTS relationship_status;

-- ============================================================================
-- STEP 3: RECREATE THE RELATIONSHIP_SUMMARY VIEW WITHOUT STATUS
-- ============================================================================

CREATE OR REPLACE VIEW relationship_summary AS
SELECT 
    coh.client_uuid,
    coh.org_uuid,
    o.name AS org_name,
    NULL::TEXT AS org_type,  -- organizations table doesn't have a type column
    coh.annual_total_spend AS total_spend,
    NULL::TEXT AS status,  -- Keep for backward compatibility but always NULL
    coh.relationship_owner AS owner,
    coh.renewal_date,
    coh.policy_alignment_score AS alignment_score,
    coh.last_contact_date,
    coh.key_external_contacts,
    coh.notes
FROM 
    client_organization_history coh
LEFT JOIN 
    organizations o ON coh.org_uuid = o.uuid;

-- Grant permissions on the view
GRANT SELECT ON relationship_summary TO anon, authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, you can verify with:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'client_organization_history'
-- ORDER BY ordinal_position;

-- ============================================================================
-- NOTES
-- ============================================================================
-- This migration removes the relationship_status column entirely.
-- The view keeps a NULL status column for backward compatibility with 
-- existing queries, but it will always return NULL.
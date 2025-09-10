-- Migration: Clean up orphan records in relationship tables
-- Date: 2025-09-10
-- Purpose: Remove any existing orphan records before CASCADE deletes take effect

-- ============================================================================
-- STEP 1: LOG ORPHAN RECORDS BEFORE DELETION (for audit purposes)
-- ============================================================================

-- Count orphan records in client_organization_history
DO $$
DECLARE
    orphan_count INTEGER;
BEGIN
    -- Count orphans where client doesn't exist
    SELECT COUNT(*) INTO orphan_count
    FROM client_organization_history coh
    WHERE NOT EXISTS (SELECT 1 FROM clients c WHERE c.uuid = coh.client_uuid);
    
    IF orphan_count > 0 THEN
        RAISE NOTICE 'Found % orphan records in client_organization_history with missing clients', orphan_count;
    END IF;
    
    -- Count orphans where organization doesn't exist
    SELECT COUNT(*) INTO orphan_count
    FROM client_organization_history coh
    WHERE NOT EXISTS (SELECT 1 FROM organizations o WHERE o.uuid = coh.org_uuid);
    
    IF orphan_count > 0 THEN
        RAISE NOTICE 'Found % orphan records in client_organization_history with missing organizations', orphan_count;
    END IF;
    
    -- Count orphans in organization_positions
    SELECT COUNT(*) INTO orphan_count
    FROM organization_positions op
    WHERE NOT EXISTS (SELECT 1 FROM organizations o WHERE o.uuid = op.organization_uuid);
    
    IF orphan_count > 0 THEN
        RAISE NOTICE 'Found % orphan records in organization_positions with missing organizations', orphan_count;
    END IF;
END $$;

-- ============================================================================
-- STEP 2: DELETE ORPHAN RECORDS FROM client_organization_history
-- ============================================================================

-- Delete records where the client no longer exists
DELETE FROM client_organization_history coh
WHERE NOT EXISTS (
    SELECT 1 FROM clients c 
    WHERE c.uuid = coh.client_uuid
);

-- Delete records where the organization no longer exists
DELETE FROM client_organization_history coh
WHERE NOT EXISTS (
    SELECT 1 FROM organizations o 
    WHERE o.uuid = coh.org_uuid
);

-- ============================================================================
-- STEP 3: DELETE ORPHAN RECORDS FROM organization_positions
-- ============================================================================

-- Delete records where the organization no longer exists
DELETE FROM organization_positions op
WHERE NOT EXISTS (
    SELECT 1 FROM organizations o 
    WHERE o.uuid = op.organization_uuid
);

-- ============================================================================
-- STEP 4: VERIFY CLEANUP COMPLETED
-- ============================================================================

DO $$
DECLARE
    remaining_orphans INTEGER;
BEGIN
    -- Check for any remaining orphans in client_organization_history
    SELECT COUNT(*) INTO remaining_orphans
    FROM client_organization_history coh
    WHERE NOT EXISTS (SELECT 1 FROM clients c WHERE c.uuid = coh.client_uuid)
       OR NOT EXISTS (SELECT 1 FROM organizations o WHERE o.uuid = coh.org_uuid);
    
    IF remaining_orphans > 0 THEN
        RAISE WARNING 'Still have % orphan records in client_organization_history!', remaining_orphans;
    ELSE
        RAISE NOTICE 'Successfully cleaned all orphan records from client_organization_history';
    END IF;
    
    -- Check for any remaining orphans in organization_positions
    SELECT COUNT(*) INTO remaining_orphans
    FROM organization_positions op
    WHERE NOT EXISTS (SELECT 1 FROM organizations o WHERE o.uuid = op.organization_uuid);
    
    IF remaining_orphans > 0 THEN
        RAISE WARNING 'Still have % orphan records in organization_positions!', remaining_orphans;
    ELSE
        RAISE NOTICE 'Successfully cleaned all orphan records from organization_positions';
    END IF;
END $$;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- This migration removes orphan records that may have been created before
-- the CASCADE delete constraints were added. After this migration:
-- 1. All records in client_organization_history will have valid client and org references
-- 2. All records in organization_positions will have valid organization references
-- 3. Future deletions will cascade automatically due to the previous migration
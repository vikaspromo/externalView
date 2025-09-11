-- Migration: Add CASCADE deletes to client_organization_history foreign keys
-- Date: 2025-09-10
-- Purpose: Prevent orphan data by cascading deletes from parent tables

-- ============================================================================
-- STEP 1: DROP EXISTING FOREIGN KEY CONSTRAINTS
-- ============================================================================
-- First, we need to find and drop the existing foreign key constraints
-- PostgreSQL auto-generates constraint names if not specified

ALTER TABLE client_organization_history 
DROP CONSTRAINT IF EXISTS client_organization_history_client_uuid_fkey;

ALTER TABLE client_organization_history 
DROP CONSTRAINT IF EXISTS client_organization_history_org_uuid_fkey;

-- ============================================================================
-- STEP 2: RE-ADD FOREIGN KEY CONSTRAINTS WITH CASCADE DELETE
-- ============================================================================
-- Add back the foreign keys with ON DELETE CASCADE behavior

ALTER TABLE client_organization_history 
ADD CONSTRAINT client_organization_history_client_uuid_fkey 
FOREIGN KEY (client_uuid) 
REFERENCES clients(uuid) 
ON DELETE CASCADE;

ALTER TABLE client_organization_history 
ADD CONSTRAINT client_organization_history_org_uuid_fkey 
FOREIGN KEY (org_uuid) 
REFERENCES organizations(uuid) 
ON DELETE CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, you can verify with:
-- SELECT 
--     tc.constraint_name, 
--     tc.table_name, 
--     kcu.column_name, 
--     ccu.table_name AS foreign_table_name,
--     ccu.column_name AS foreign_column_name,
--     rc.delete_rule
-- FROM 
--     information_schema.table_constraints AS tc 
--     JOIN information_schema.key_column_usage AS kcu
--       ON tc.constraint_name = kcu.constraint_name
--       AND tc.table_schema = kcu.table_schema
--     JOIN information_schema.constraint_column_usage AS ccu
--       ON ccu.constraint_name = tc.constraint_name
--       AND ccu.table_schema = tc.table_schema
--     JOIN information_schema.referential_constraints AS rc
--       ON rc.constraint_name = tc.constraint_name
-- WHERE tc.constraint_type = 'FOREIGN KEY' 
--   AND tc.table_name='client_organization_history';

-- Expected result: Both foreign keys should show delete_rule = 'CASCADE'

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
-- To rollback this migration, run:
-- ALTER TABLE client_organization_history 
-- DROP CONSTRAINT client_organization_history_client_uuid_fkey;
-- ALTER TABLE client_organization_history 
-- DROP CONSTRAINT client_organization_history_org_uuid_fkey;
-- ALTER TABLE client_organization_history 
-- ADD FOREIGN KEY (client_uuid) REFERENCES clients(uuid);
-- ALTER TABLE client_organization_history 
-- ADD FOREIGN KEY (org_uuid) REFERENCES organizations(uuid);
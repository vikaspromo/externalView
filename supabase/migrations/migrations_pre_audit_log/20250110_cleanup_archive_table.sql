-- Migration: Clean up client_org_relationships_archive table
-- Date: 2025-01-10
-- Purpose: Remove the archive table and all associated database objects

-- ============================================================================
-- DROP POLICIES (if any still exist on the archive table)
-- ============================================================================
DROP POLICY IF EXISTS "Allow public read access to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public insert to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public update to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public delete from client_org_relationships" ON client_org_relationships_archive;

-- Drop any other policies that might exist
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all policies on the archive table
    FOR r IN (
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'client_org_relationships_archive'
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON client_org_relationships_archive', r.policyname);
    END LOOP;
END $$;

-- ============================================================================
-- DROP INDEXES
-- ============================================================================
DROP INDEX IF EXISTS idx_client_org_relationships_client_uuid;
DROP INDEX IF EXISTS idx_client_org_relationships_org_uuid;
DROP INDEX IF EXISTS idx_client_org_relationships_client_org;

-- Drop any other indexes on the archive table (excluding constraint-based indexes)
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all indexes on the archive table that are not part of constraints
    FOR r IN (
        SELECT indexname 
        FROM pg_indexes 
        WHERE tablename = 'client_org_relationships_archive'
        AND indexname NOT IN (
            SELECT conname 
            FROM pg_constraint 
            WHERE conrelid = 'client_org_relationships_archive'::regclass
        )
    ) LOOP
        EXECUTE format('DROP INDEX IF EXISTS %I', r.indexname);
    END LOOP;
END $$;

-- ============================================================================
-- DROP TRIGGERS (if any)
-- ============================================================================
DROP TRIGGER IF EXISTS update_client_org_relationships_updated_at ON client_org_relationships_archive;

-- Drop any other triggers
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all triggers on the archive table
    FOR r IN (
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'client_org_relationships_archive'
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON client_org_relationships_archive', r.trigger_name);
    END LOOP;
END $$;

-- ============================================================================
-- DROP THE ARCHIVE TABLE
-- ============================================================================
DROP TABLE IF EXISTS client_org_relationships_archive CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, you can verify the cleanup with:
-- SELECT tablename FROM pg_tables WHERE tablename LIKE '%client_org_relationships%';
-- This should only show 'client_organization_history' table

-- ============================================================================
-- NOTES
-- ============================================================================
-- This migration permanently removes the archive table and all its data.
-- Make sure you have backed up any important data before running this migration.
-- The new client_organization_history table is now the primary table for
-- tracking client-organization relationships.
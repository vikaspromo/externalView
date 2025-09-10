-- Migration: Rename client_organization_history to client_org_history
-- Date: 2025-09-10
-- Purpose: Shorten table name for consistency and brevity

-- ============================================================================
-- STEP 1: RENAME TABLE
-- ============================================================================
ALTER TABLE client_organization_history RENAME TO client_org_history;

-- ============================================================================
-- STEP 2: RENAME INDEXES (if they exist)
-- ============================================================================
ALTER INDEX IF EXISTS idx_client_organization_history_client RENAME TO idx_client_org_history_client;
ALTER INDEX IF EXISTS idx_client_organization_history_org RENAME TO idx_client_org_history_org;
ALTER INDEX IF EXISTS idx_client_organization_history_status RENAME TO idx_client_org_history_status;

-- ============================================================================
-- STEP 3: UPDATE RLS POLICIES
-- ============================================================================
-- Drop existing policies
DROP POLICY IF EXISTS "Allow public read access to client_organization_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public insert to client_organization_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public update to client_organization_history" ON client_org_history;
DROP POLICY IF EXISTS "Allow public delete from client_organization_history" ON client_org_history;

-- Recreate policies with new naming convention
CREATE POLICY "Allow public read access to client_org_history" 
ON client_org_history 
FOR SELECT 
USING (true);

CREATE POLICY "Allow public insert to client_org_history" 
ON client_org_history 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow public update to client_org_history" 
ON client_org_history 
FOR UPDATE 
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow public delete from client_org_history" 
ON client_org_history 
FOR DELETE 
USING (true);

-- ============================================================================
-- STEP 4: UPDATE FOREIGN KEY CONSTRAINT NAMES (if they exist)
-- ============================================================================
-- The foreign key constraints will automatically be renamed with the table
-- but if we want cleaner names, we can rename them explicitly:
ALTER TABLE client_org_history 
DROP CONSTRAINT IF EXISTS client_organization_history_client_uuid_fkey,
ADD CONSTRAINT client_org_history_client_uuid_fkey 
FOREIGN KEY (client_uuid) REFERENCES clients(uuid) ON DELETE CASCADE;

ALTER TABLE client_org_history 
DROP CONSTRAINT IF EXISTS client_organization_history_org_uuid_fkey,
ADD CONSTRAINT client_org_history_org_uuid_fkey 
FOREIGN KEY (org_uuid) REFERENCES organizations(uuid) ON DELETE CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. Table will be renamed to client_org_history
-- 2. All indexes will have consistent naming
-- 3. RLS policies will be updated
-- 4. Foreign key constraints will have cleaner names
-- 5. All existing data will be preserved
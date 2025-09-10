-- Migration: Rename organization_positions to org_positions
-- Date: 2025-09-10
-- Purpose: Shorten table name for consistency with org_* naming convention

-- ============================================================================
-- STEP 1: RENAME TABLE
-- ============================================================================
ALTER TABLE organization_positions RENAME TO org_positions;

-- ============================================================================
-- STEP 2: RENAME INDEXES (if they exist)
-- ============================================================================
ALTER INDEX IF EXISTS idx_organization_positions_org_uuid RENAME TO idx_org_positions_org_uuid;
ALTER INDEX IF EXISTS idx_organization_positions_ein RENAME TO idx_org_positions_ein;
ALTER INDEX IF EXISTS idx_organization_positions_unique_org RENAME TO idx_org_positions_unique_org;

-- ============================================================================
-- STEP 3: UPDATE RLS POLICIES
-- ============================================================================
-- Drop existing policies
DROP POLICY IF EXISTS "Allow public read access to organization_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public insert to organization_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public update to organization_positions" ON org_positions;
DROP POLICY IF EXISTS "Allow public delete from organization_positions" ON org_positions;

-- Recreate policies with new naming convention
CREATE POLICY "Allow public read access to org_positions" 
ON org_positions 
FOR SELECT 
USING (true);

CREATE POLICY "Allow public insert to org_positions" 
ON org_positions 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow public update to org_positions" 
ON org_positions 
FOR UPDATE 
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow public delete from org_positions" 
ON org_positions 
FOR DELETE 
USING (true);

-- ============================================================================
-- STEP 4: UPDATE TABLE AND COLUMN COMMENTS
-- ============================================================================
COMMENT ON TABLE org_positions IS 'Stores policy positions and stances of organizations fetched from Claude API';
COMMENT ON COLUMN org_positions.positions IS 'JSON array of position objects with description, position, positionDetails, and referenceMaterials';

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After this migration:
-- 1. Table will be renamed to org_positions
-- 2. All indexes will have consistent naming
-- 3. RLS policies will be updated
-- 4. Comments will be preserved
-- 5. All existing data and foreign key relationships will be preserved
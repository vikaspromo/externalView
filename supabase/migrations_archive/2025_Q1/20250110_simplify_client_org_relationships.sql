-- Migration: Simplify client_org_relationships and rename to client_organization_history
-- Date: 2025-01-10
-- Purpose: Simplify data structure to focus on key relationship tracking fields

-- ============================================================================
-- STEP 1: RENAME EXISTING TABLE FOR BACKUP
-- ============================================================================
ALTER TABLE IF EXISTS client_org_relationships 
RENAME TO client_org_relationships_archive;

-- ============================================================================
-- STEP 2: CREATE NEW SIMPLIFIED TABLE
-- ============================================================================
CREATE TABLE client_organization_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_uuid UUID NOT NULL REFERENCES clients(uuid),
    org_uuid UUID NOT NULL REFERENCES organizations(uuid),
    
    -- Core relationship fields
    annual_total_spend NUMERIC,
    relationship_owner TEXT,
    renewal_date DATE,
    relationship_status TEXT CHECK (relationship_status IN ('Red', 'Yellow', 'Green', NULL)),
    last_contact_date DATE,
    key_external_contacts JSONB DEFAULT '[]'::jsonb,
    policy_alignment_score INTEGER CHECK (policy_alignment_score >= 0 AND policy_alignment_score <= 100),
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure unique relationship per client-org pair
    UNIQUE(client_uuid, org_uuid)
);

-- Create indexes for performance
CREATE INDEX idx_client_organization_history_client ON client_organization_history(client_uuid);
CREATE INDEX idx_client_organization_history_org ON client_organization_history(org_uuid);
CREATE INDEX idx_client_organization_history_status ON client_organization_history(relationship_status);

-- ============================================================================
-- STEP 3: ENABLE ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE client_organization_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies on the archive table first (they'll be recreated for the new table)
DROP POLICY IF EXISTS "Allow public read access to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public insert to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public update to client_org_relationships" ON client_org_relationships_archive;
DROP POLICY IF EXISTS "Allow public delete from client_org_relationships" ON client_org_relationships_archive;

-- Create RLS policies for the new table (development - permissive)
CREATE POLICY "Allow public read access to client_organization_history" 
ON client_organization_history 
FOR SELECT 
USING (true);

CREATE POLICY "Allow public insert to client_organization_history" 
ON client_organization_history 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow public update to client_organization_history" 
ON client_organization_history 
FOR UPDATE 
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow public delete from client_organization_history" 
ON client_organization_history 
FOR DELETE 
USING (true);

-- ============================================================================
-- STEP 4: UPDATE OR RECREATE THE RELATIONSHIP_SUMMARY VIEW
-- ============================================================================
DROP VIEW IF EXISTS relationship_summary;

CREATE OR REPLACE VIEW relationship_summary AS
SELECT 
    coh.client_uuid,
    coh.org_uuid,
    o.name AS org_name,
    NULL::TEXT AS org_type,  -- organizations table doesn't have a type column
    coh.annual_total_spend AS total_spend,
    coh.relationship_status AS status,
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
-- STEP 5: CREATE TRIGGER FOR UPDATED_AT
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_client_organization_history_updated_at
BEFORE UPDATE ON client_organization_history
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 6: MIGRATE DATA (IF ANY EXISTS)
-- ============================================================================
-- This will attempt to migrate any existing data from the old structure
-- Adjust field mappings as needed based on your actual data
INSERT INTO client_organization_history (
    client_uuid,
    org_uuid,
    annual_total_spend,
    relationship_owner,
    renewal_date,
    relationship_status,
    last_contact_date,
    key_external_contacts,
    policy_alignment_score,
    notes,
    created_at,
    updated_at
)
SELECT 
    client_uuid,
    org_uuid,
    COALESCE(
        (financial_admin->>'annual_dues')::numeric,
        (financial_admin->>'total_spend')::numeric,
        (financial_admin->>'sponsorship_amount')::numeric,
        0
    ) as annual_total_spend,
    COALESCE(
        relationship_mgmt->>'relationship_owner',
        relationship_mgmt->>'owner',
        relationship_mgmt->>'account_manager'
    ) as relationship_owner,
    CASE 
        WHEN financial_admin->>'renewal_date' IS NOT NULL 
        THEN (financial_admin->>'renewal_date')::date
        WHEN financial_admin->>'membership_renewal' IS NOT NULL 
        THEN (financial_admin->>'membership_renewal')::date
        ELSE NULL
    END as renewal_date,
    COALESCE(
        relationship_mgmt->>'status',
        classification->>'relationship_status',
        'Yellow'
    ) as relationship_status,
    CASE 
        WHEN relationship_mgmt->>'last_contact' IS NOT NULL 
        THEN (relationship_mgmt->>'last_contact')::date
        WHEN relationship_mgmt->>'last_meeting' IS NOT NULL 
        THEN (relationship_mgmt->>'last_meeting')::date
        ELSE NULL
    END as last_contact_date,
    COALESCE(
        relationship_mgmt->'key_contacts',
        relationship_mgmt->'external_contacts',
        '[]'::jsonb
    ) as key_external_contacts,
    COALESCE(
        (strategic_alignment->>'alignment_score')::integer,
        (strategic_alignment->>'policy_alignment')::integer,
        50
    ) as policy_alignment_score,
    COALESCE(
        historical_context->>'notes',
        historical_context->>'context',
        relationship_mgmt->>'notes',
        ''
    ) as notes,
    created_at,
    updated_at
FROM client_org_relationships_archive
ON CONFLICT (client_uuid, org_uuid) DO NOTHING;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback these changes, run:
-- DROP TABLE IF EXISTS client_organization_history CASCADE;
-- ALTER TABLE client_org_relationships_archive RENAME TO client_org_relationships;
-- Then recreate the original RLS policies and view
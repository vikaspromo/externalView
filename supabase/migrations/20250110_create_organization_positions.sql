-- Create organization_positions table to store policy positions data from Claude API
CREATE TABLE IF NOT EXISTS organization_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_uuid UUID REFERENCES organizations(uuid) ON DELETE CASCADE,
  organization_name VARCHAR(255),
  ein VARCHAR(20),
  positions JSONB, -- Store the entire positions array as JSONB
  fetched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_organization_positions_org_uuid ON organization_positions(organization_uuid);
CREATE INDEX IF NOT EXISTS idx_organization_positions_ein ON organization_positions(ein);

-- Add unique constraint to prevent duplicate entries per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_positions_unique_org ON organization_positions(organization_uuid);

-- Enable Row Level Security (RLS)
ALTER TABLE organization_positions ENABLE ROW LEVEL SECURITY;

-- Create policies for development (permissive access)
-- In production, you should restrict these based on user roles
CREATE POLICY "Allow public read access to organization_positions" ON organization_positions
  FOR SELECT
  USING (true);

CREATE POLICY "Allow public insert to organization_positions" ON organization_positions
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow public update to organization_positions" ON organization_positions
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow public delete from organization_positions" ON organization_positions
  FOR DELETE
  USING (true);

-- Add comment to table
COMMENT ON TABLE organization_positions IS 'Stores policy positions and stances of organizations fetched from Claude API';
COMMENT ON COLUMN organization_positions.positions IS 'JSON array of position objects with description, position, positionDetails, and referenceMaterials';
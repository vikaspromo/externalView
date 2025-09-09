-- Add EIN columns to organizations table
ALTER TABLE organizations 
  ADD COLUMN IF NOT EXISTS ein VARCHAR(20),
  ADD COLUMN IF NOT EXISTS ein_related VARCHAR(20)[];

-- Optional: Add an index on the ein column for faster lookups
CREATE INDEX IF NOT EXISTS idx_organizations_ein ON organizations(ein);
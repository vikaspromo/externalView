-- Create allowed_users table for authentication whitelist
CREATE TABLE IF NOT EXISTS allowed_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  company TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create organizations table
CREATE TABLE IF NOT EXISTS organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create stakeholder_relationships table
CREATE TABLE IF NOT EXISTS stakeholder_relationships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  stakeholder_name TEXT NOT NULL,
  role TEXT,
  contact_info JSONB,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Enable Row Level Security
ALTER TABLE allowed_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE stakeholder_relationships ENABLE ROW LEVEL SECURITY;

-- Create policy for allowed_users (service role only for writes, authenticated users can read their own)
CREATE POLICY "Service role can manage allowed_users" ON allowed_users
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can read their own entry" ON allowed_users
  FOR SELECT USING (auth.email() = email);

-- Insert the authorized users
INSERT INTO allowed_users (email, company) VALUES 
  ('vikassood@gmail.com', 'External View'),
  ('jebory@gmail.com', 'External View')
ON CONFLICT (email) DO NOTHING;

-- Show the added users
SELECT email, company, created_at FROM allowed_users ORDER BY created_at DESC;
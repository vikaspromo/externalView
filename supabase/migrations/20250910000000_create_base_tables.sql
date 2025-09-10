-- ============================================================================
-- Migration: Create Base Tables for Multi-Tenant System
-- Date: 2025-09-10
-- Purpose: Initial table creation for the application
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE CLIENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS clients (
  uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for active clients
CREATE INDEX IF NOT EXISTS idx_clients_active ON clients(active);

-- ============================================================================
-- STEP 2: CREATE USERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  client_uuid UUID REFERENCES clients(uuid),
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for users
CREATE INDEX IF NOT EXISTS idx_users_client_uuid ON users(client_uuid);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);

-- ============================================================================
-- STEP 3: CREATE ORGANIZATIONS TABLE (MASTER LIST)
-- ============================================================================
CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  type VARCHAR(100),
  website VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for organization name
CREATE INDEX IF NOT EXISTS idx_organizations_name ON organizations(name);

-- ============================================================================
-- STEP 4: CREATE CLIENT_ORG_HISTORY TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS client_org_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_uuid UUID NOT NULL REFERENCES clients(uuid),
  organization_id UUID REFERENCES organizations(id),
  relationship_type VARCHAR(100),
  start_date DATE,
  end_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_client_org_history_client_uuid ON client_org_history(client_uuid);
CREATE INDEX IF NOT EXISTS idx_client_org_history_organization_id ON client_org_history(organization_id);

-- ============================================================================
-- STEP 5: CREATE ORG_POSITIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS org_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id),
  title VARCHAR(255) NOT NULL,
  department VARCHAR(255),
  level VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_org_positions_organization_id ON org_positions(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_positions_title ON org_positions(title);

-- ============================================================================
-- STEP 6: ENABLE ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_org_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_positions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'BASE TABLES CREATED SUCCESSFULLY';
  RAISE NOTICE 'Tables: clients, users, organizations, client_org_history, org_positions';
  RAISE NOTICE 'Row Level Security has been enabled on all tables';
  RAISE NOTICE '==================================================';
END $$;
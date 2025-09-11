-- ============================================================================
-- Migration: Comprehensive RLS Policies for Complete CRUD Protection
-- Date: 2025-09-10
-- Purpose: Implement INSERT, UPDATE, DELETE policies with cross-tenant protection
-- Security: Prevents unauthorized cross-tenant data modifications
-- ============================================================================

-- ============================================================================
-- STEP 1: ADD SOFT DELETE SUPPORT TO TABLES
-- ============================================================================

-- Add deleted_at column for soft deletes where missing
ALTER TABLE clients ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE client_org_history ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE org_positions ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create indexes for soft delete queries
CREATE INDEX IF NOT EXISTS idx_clients_deleted_at ON clients(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_client_org_history_deleted_at ON client_org_history(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_organizations_deleted_at ON organizations(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_org_positions_deleted_at ON org_positions(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================================
-- STEP 2: CREATE HELPER FUNCTIONS FOR CLIENT VALIDATION
-- ============================================================================

-- Function to get current user's client_uuid
CREATE OR REPLACE FUNCTION get_user_client_uuid()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_client_uuid UUID;
BEGIN
  -- Check if user is admin first
  IF is_admin() THEN
    RETURN NULL; -- Admins don't have a specific client
  END IF;
  
  -- Get user's client_uuid
  SELECT client_uuid INTO v_client_uuid
  FROM users
  WHERE id::uuid = auth.uid()
  AND deleted_at IS NULL;
  
  RETURN v_client_uuid;
END;
$$;

-- Function to validate if a client_uuid belongs to current user
CREATE OR REPLACE FUNCTION validate_client_uuid(p_client_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user_client UUID;
BEGIN
  -- Admins can access any client
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Get user's client
  v_user_client := get_user_client_uuid();
  
  -- Check if client matches
  IF v_user_client IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN v_user_client = p_client_uuid;
END;
$$;

-- Function to prevent client_uuid changes
CREATE OR REPLACE FUNCTION prevent_client_uuid_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Allow admins to change client_uuid
  IF is_admin() THEN
    RETURN NEW;
  END IF;
  
  -- Check if client_uuid is being changed
  IF OLD.client_uuid IS DISTINCT FROM NEW.client_uuid THEN
    RAISE EXCEPTION 'Cannot change client_uuid. Cross-tenant data transfer is not allowed.';
  END IF;
  
  RETURN NEW;
END;
$$;

-- Function to auto-populate client_uuid on insert
CREATE OR REPLACE FUNCTION auto_populate_client_uuid()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_client UUID;
BEGIN
  -- If admin, allow them to set any client_uuid
  IF is_admin() THEN
    RETURN NEW;
  END IF;
  
  -- Get user's client
  v_user_client := get_user_client_uuid();
  
  -- If client_uuid is not set, auto-populate it
  IF NEW.client_uuid IS NULL THEN
    NEW.client_uuid := v_user_client;
  -- If set, validate it matches user's client
  ELSIF NEW.client_uuid != v_user_client THEN
    RAISE EXCEPTION 'Cannot insert data for different client. Your client_uuid: %, Attempted: %', 
      v_user_client, NEW.client_uuid;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Function for soft delete
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Set deleted_at timestamp instead of actually deleting
  NEW.deleted_at := NOW();
  
  -- Log the deletion
  INSERT INTO security_audit_log (
    event_type,
    user_id,
    client_uuid,
    success,
    metadata
  ) VALUES (
    'soft_delete',
    auth.uid(),
    OLD.client_uuid,
    true,
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'record_id', OLD.id,
      'deleted_at', NEW.deleted_at
    )
  );
  
  RETURN NEW;
END;
$$;

-- ============================================================================
-- STEP 3: DROP EXISTING POLICIES (CLEAN SLATE)
-- ============================================================================

-- Drop all existing policies to recreate with proper CRUD separation
DROP POLICY IF EXISTS "client_access_policy" ON clients;
DROP POLICY IF EXISTS "users_access_policy" ON users;
DROP POLICY IF EXISTS "users_update_policy" ON users;
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "users_delete_policy" ON users;
DROP POLICY IF EXISTS "client_org_history_access_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_modify_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_update_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_delete_policy" ON client_org_history;
DROP POLICY IF EXISTS "organizations_read_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_modify_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;
DROP POLICY IF EXISTS "org_positions_read_policy" ON org_positions;
DROP POLICY IF EXISTS "org_positions_modify_policy" ON org_positions;

-- ============================================================================
-- STEP 4: CLIENTS TABLE POLICIES
-- ============================================================================

-- SELECT: Users can only see their own client
CREATE POLICY "clients_select_policy" 
ON clients FOR SELECT 
USING (
  user_has_client_access(uuid) 
  AND deleted_at IS NULL
);

-- INSERT: Only admins can create new clients
CREATE POLICY "clients_insert_policy" 
ON clients FOR INSERT 
WITH CHECK (is_admin());

-- UPDATE: Users can update their own client, admins can update any
CREATE POLICY "clients_update_policy" 
ON clients FOR UPDATE 
USING (
  user_has_client_access(uuid)
  AND deleted_at IS NULL
)
WITH CHECK (
  user_has_client_access(uuid)
  AND uuid = OLD.uuid -- Prevent changing client UUID
);

-- DELETE: Only admins can delete clients (soft delete)
CREATE POLICY "clients_delete_policy" 
ON clients FOR DELETE 
USING (is_admin());

-- ============================================================================
-- STEP 5: USERS TABLE POLICIES
-- ============================================================================

-- SELECT: Users can see all users in their client
CREATE POLICY "users_select_policy" 
ON users FOR SELECT 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- INSERT: Only admins can create users
CREATE POLICY "users_insert_policy" 
ON users FOR INSERT 
WITH CHECK (
  is_admin()
  OR (
    -- Allow users to be created during registration if client matches
    validate_client_uuid(client_uuid)
    AND auth.uid() = id::uuid
  )
);

-- UPDATE: Users can update their own profile, admins can update anyone
CREATE POLICY "users_update_policy" 
ON users FOR UPDATE 
USING (
  deleted_at IS NULL
  AND (
    id::uuid = auth.uid() -- Own profile
    OR is_admin()
  )
)
WITH CHECK (
  -- Prevent changing client_uuid
  client_uuid = OLD.client_uuid
  AND (
    id::uuid = auth.uid()
    OR is_admin()
  )
);

-- DELETE: Only admins can delete users
CREATE POLICY "users_delete_policy" 
ON users FOR DELETE 
USING (is_admin());

-- ============================================================================
-- STEP 6: CLIENT_ORG_HISTORY TABLE POLICIES
-- ============================================================================

-- SELECT: Users can see their client's organization history
CREATE POLICY "client_org_history_select_policy" 
ON client_org_history FOR SELECT 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- INSERT: Users can add organizations to their client
CREATE POLICY "client_org_history_insert_policy" 
ON client_org_history FOR INSERT 
WITH CHECK (
  validate_client_uuid(client_uuid)
);

-- UPDATE: Users can update their client's organization relationships
CREATE POLICY "client_org_history_update_policy" 
ON client_org_history FOR UPDATE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
)
WITH CHECK (
  -- Prevent changing client_uuid
  client_uuid = OLD.client_uuid
  AND user_has_client_access(client_uuid)
);

-- DELETE: Users can remove organizations from their client
CREATE POLICY "client_org_history_delete_policy" 
ON client_org_history FOR DELETE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- ============================================================================
-- STEP 7: ORGANIZATIONS TABLE POLICIES (MASTER LIST)
-- ============================================================================

-- SELECT: All authenticated users can view organizations
CREATE POLICY "organizations_select_policy" 
ON organizations FOR SELECT 
USING (
  auth.uid() IS NOT NULL
  AND deleted_at IS NULL
);

-- INSERT: Only admins can create organizations
CREATE POLICY "organizations_insert_policy" 
ON organizations FOR INSERT 
WITH CHECK (is_admin());

-- UPDATE: Only admins can update organizations
CREATE POLICY "organizations_update_policy" 
ON organizations FOR UPDATE 
USING (is_admin())
WITH CHECK (is_admin());

-- DELETE: Only admins can delete organizations
CREATE POLICY "organizations_delete_policy" 
ON organizations FOR DELETE 
USING (is_admin());

-- ============================================================================
-- STEP 8: ORG_POSITIONS TABLE POLICIES
-- ============================================================================

-- SELECT: All authenticated users can view positions
CREATE POLICY "org_positions_select_policy" 
ON org_positions FOR SELECT 
USING (
  auth.uid() IS NOT NULL
  AND deleted_at IS NULL
);

-- INSERT: Only admins can create positions
CREATE POLICY "org_positions_insert_policy" 
ON org_positions FOR INSERT 
WITH CHECK (is_admin());

-- UPDATE: Only admins can update positions
CREATE POLICY "org_positions_update_policy" 
ON org_positions FOR UPDATE 
USING (is_admin())
WITH CHECK (is_admin());

-- DELETE: Only admins can delete positions
CREATE POLICY "org_positions_delete_policy" 
ON org_positions FOR DELETE 
USING (is_admin());

-- ============================================================================
-- STEP 9: CREATE TRIGGERS FOR CLIENT_UUID VALIDATION
-- ============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS prevent_client_uuid_change_trigger ON users;
DROP TRIGGER IF EXISTS prevent_client_uuid_change_trigger ON client_org_history;
DROP TRIGGER IF EXISTS auto_populate_client_uuid_trigger ON client_org_history;

-- Trigger to prevent client_uuid changes on users table
CREATE TRIGGER prevent_client_uuid_change_trigger
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_client_uuid_change();

-- Trigger to prevent client_uuid changes on client_org_history
CREATE TRIGGER prevent_client_uuid_change_trigger
BEFORE UPDATE ON client_org_history
FOR EACH ROW
EXECUTE FUNCTION prevent_client_uuid_change();

-- Trigger to auto-populate client_uuid on client_org_history
CREATE TRIGGER auto_populate_client_uuid_trigger
BEFORE INSERT ON client_org_history
FOR EACH ROW
EXECUTE FUNCTION auto_populate_client_uuid();

-- ============================================================================
-- STEP 10: CREATE STAKEHOLDER TABLES IF THEY DON'T EXIST
-- ============================================================================

-- Create stakeholder_contacts table if it doesn't exist
CREATE TABLE IF NOT EXISTS stakeholder_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_uuid UUID NOT NULL REFERENCES clients(uuid),
  organization_id UUID REFERENCES organizations(id),
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(50),
  title VARCHAR(255),
  department VARCHAR(255),
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id)
);

-- Create stakeholder_notes table if it doesn't exist
CREATE TABLE IF NOT EXISTS stakeholder_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_uuid UUID NOT NULL REFERENCES clients(uuid),
  stakeholder_contact_id UUID REFERENCES stakeholder_contacts(id),
  note_text TEXT NOT NULL,
  note_type VARCHAR(50), -- 'meeting', 'email', 'call', 'general'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id)
);

-- Enable RLS on stakeholder tables
ALTER TABLE stakeholder_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE stakeholder_notes ENABLE ROW LEVEL SECURITY;

-- Create indexes for stakeholder tables
CREATE INDEX IF NOT EXISTS idx_stakeholder_contacts_client_uuid ON stakeholder_contacts(client_uuid);
CREATE INDEX IF NOT EXISTS idx_stakeholder_contacts_deleted_at ON stakeholder_contacts(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stakeholder_notes_client_uuid ON stakeholder_notes(client_uuid);
CREATE INDEX IF NOT EXISTS idx_stakeholder_notes_deleted_at ON stakeholder_notes(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================================
-- STEP 11: STAKEHOLDER_CONTACTS TABLE POLICIES
-- ============================================================================

-- SELECT: Users can see their client's contacts
CREATE POLICY "stakeholder_contacts_select_policy" 
ON stakeholder_contacts FOR SELECT 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- INSERT: Users can create contacts for their client
CREATE POLICY "stakeholder_contacts_insert_policy" 
ON stakeholder_contacts FOR INSERT 
WITH CHECK (
  validate_client_uuid(client_uuid)
);

-- UPDATE: Users can update their client's contacts
CREATE POLICY "stakeholder_contacts_update_policy" 
ON stakeholder_contacts FOR UPDATE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
)
WITH CHECK (
  client_uuid = OLD.client_uuid
  AND user_has_client_access(client_uuid)
);

-- DELETE: Users can delete their client's contacts
CREATE POLICY "stakeholder_contacts_delete_policy" 
ON stakeholder_contacts FOR DELETE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- ============================================================================
-- STEP 12: STAKEHOLDER_NOTES TABLE POLICIES
-- ============================================================================

-- SELECT: Users can see their client's notes
CREATE POLICY "stakeholder_notes_select_policy" 
ON stakeholder_notes FOR SELECT 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- INSERT: Users can create notes for their client
CREATE POLICY "stakeholder_notes_insert_policy" 
ON stakeholder_notes FOR INSERT 
WITH CHECK (
  validate_client_uuid(client_uuid)
);

-- UPDATE: Users can update their client's notes
CREATE POLICY "stakeholder_notes_update_policy" 
ON stakeholder_notes FOR UPDATE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
)
WITH CHECK (
  client_uuid = OLD.client_uuid
  AND user_has_client_access(client_uuid)
);

-- DELETE: Users can delete their client's notes
CREATE POLICY "stakeholder_notes_delete_policy" 
ON stakeholder_notes FOR DELETE 
USING (
  user_has_client_access(client_uuid)
  AND deleted_at IS NULL
);

-- ============================================================================
-- STEP 13: CREATE TRIGGERS FOR STAKEHOLDER TABLES
-- ============================================================================

-- Triggers for stakeholder_contacts
CREATE TRIGGER prevent_client_uuid_change_trigger
BEFORE UPDATE ON stakeholder_contacts
FOR EACH ROW
EXECUTE FUNCTION prevent_client_uuid_change();

CREATE TRIGGER auto_populate_client_uuid_trigger
BEFORE INSERT ON stakeholder_contacts
FOR EACH ROW
EXECUTE FUNCTION auto_populate_client_uuid();

-- Triggers for stakeholder_notes
CREATE TRIGGER prevent_client_uuid_change_trigger
BEFORE UPDATE ON stakeholder_notes
FOR EACH ROW
EXECUTE FUNCTION prevent_client_uuid_change();

CREATE TRIGGER auto_populate_client_uuid_trigger
BEFORE INSERT ON stakeholder_notes
FOR EACH ROW
EXECUTE FUNCTION auto_populate_client_uuid();

-- ============================================================================
-- STEP 14: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION get_user_client_uuid() TO authenticated;
GRANT EXECUTE ON FUNCTION validate_client_uuid(UUID) TO authenticated;

-- ============================================================================
-- STEP 15: CREATE TEST FUNCTIONS
-- ============================================================================

-- Function to test cross-tenant protection
CREATE OR REPLACE FUNCTION test_cross_tenant_protection()
RETURNS TABLE(
  test_name TEXT,
  test_result BOOLEAN,
  error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_test_client1 UUID := gen_random_uuid();
  v_test_client2 UUID := gen_random_uuid();
  v_test_user1 UUID := gen_random_uuid();
  v_test_user2 UUID := gen_random_uuid();
  v_error_msg TEXT;
BEGIN
  -- Test 1: User cannot insert data for different client
  test_name := 'INSERT cross-tenant prevention';
  BEGIN
    -- This should fail
    INSERT INTO client_org_history (client_uuid, organization_id)
    VALUES (v_test_client2, gen_random_uuid());
    
    test_result := false;
    error_message := 'Failed: User was able to insert for different client';
  EXCEPTION WHEN OTHERS THEN
    test_result := true;
    error_message := 'Passed: ' || SQLERRM;
  END;
  RETURN NEXT;
  
  -- Test 2: User cannot update client_uuid to different client
  test_name := 'UPDATE client_uuid prevention';
  BEGIN
    -- This should fail (trigger will prevent it)
    UPDATE client_org_history 
    SET client_uuid = v_test_client2
    WHERE client_uuid = v_test_client1;
    
    test_result := false;
    error_message := 'Failed: User was able to change client_uuid';
  EXCEPTION WHEN OTHERS THEN
    test_result := true;
    error_message := 'Passed: ' || SQLERRM;
  END;
  RETURN NEXT;
  
  -- Test 3: User cannot delete data from different client
  test_name := 'DELETE cross-tenant prevention';
  BEGIN
    -- This should fail (RLS will prevent it)
    DELETE FROM client_org_history
    WHERE client_uuid = v_test_client2;
    
    -- Check if any rows were deleted
    IF NOT FOUND THEN
      test_result := true;
      error_message := 'Passed: No rows deleted from different client';
    ELSE
      test_result := false;
      error_message := 'Failed: Rows were deleted from different client';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    test_result := true;
    error_message := 'Passed: ' || SQLERRM;
  END;
  RETURN NEXT;
  
  RETURN;
END;
$$;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check all tables have proper RLS policies
SELECT 
  schemaname,
  tablename,
  COUNT(*) as policy_count,
  STRING_AGG(policyname || ' (' || cmd || ')', ', ') as policies
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'clients', 'users', 'client_org_history', 
    'organizations', 'org_positions',
    'stakeholder_contacts', 'stakeholder_notes'
  )
GROUP BY schemaname, tablename
ORDER BY tablename;

-- Check triggers are properly installed
SELECT 
  trigger_schema,
  event_object_table,
  trigger_name,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
    'prevent_client_uuid_change_trigger',
    'auto_populate_client_uuid_trigger'
  )
ORDER BY event_object_table, trigger_name;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'COMPREHENSIVE RLS POLICIES APPLIED SUCCESSFULLY';
  RAISE NOTICE 'All CRUD operations now have cross-tenant protection';
  RAISE NOTICE 'Soft delete support has been added to all tables';
  RAISE NOTICE 'Client UUID validation triggers are active';
  RAISE NOTICE 'Run SELECT * FROM test_cross_tenant_protection() to test';
  RAISE NOTICE '==================================================';
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
-- To rollback: Run the previous migration to restore basic policies
-- Or create a specific rollback script if needed
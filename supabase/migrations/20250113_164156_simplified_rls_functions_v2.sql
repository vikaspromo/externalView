-- ============================================================================
-- SIMPLIFIED RLS FUNCTIONS (V2) - PARALLEL IMPLEMENTATION
-- ============================================================================
-- Purpose: Create simplified RLS functions alongside existing ones
-- These use _v2 suffix and don't replace current functions
-- They will be activated in Phase 4 switchover
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SIMPLIFIED CORE FUNCTIONS
-- ----------------------------------------------------------------------------

-- Simplified admin check - same logic, cleaner implementation
CREATE OR REPLACE FUNCTION is_admin_v2() 
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_admins 
    WHERE auth_user_id = auth.uid() AND active = true
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Simplified tenant check - combines client access logic
CREATE OR REPLACE FUNCTION in_same_tenant_v2(check_client_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users 
    WHERE auth_user_id = auth.uid() 
    AND client_uuid = check_client_uuid
    AND active = true
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Simplified ownership check
CREATE OR REPLACE FUNCTION owns_record_v2(record_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT auth.uid() = record_user_id;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Get current user's client (simplified)
CREATE OR REPLACE FUNCTION get_user_client_v2()
RETURNS UUID AS $$
  SELECT client_uuid FROM users 
  WHERE auth_user_id = auth.uid() AND active = true;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Universal access check - combines all access patterns
CREATE OR REPLACE FUNCTION has_access_v2(
  check_client_uuid UUID DEFAULT NULL,
  check_user_id UUID DEFAULT NULL,
  require_admin BOOLEAN DEFAULT FALSE
) RETURNS BOOLEAN AS $$
BEGIN
  -- Admin required but user is not admin
  IF require_admin AND NOT is_admin_v2() THEN
    RETURN FALSE;
  END IF;
  
  -- Admin always has access
  IF is_admin_v2() THEN
    RETURN TRUE;
  END IF;
  
  -- Check user ownership if user_id provided
  IF check_user_id IS NOT NULL THEN
    RETURN owns_record_v2(check_user_id);
  END IF;
  
  -- Check tenant access if client_uuid provided
  IF check_client_uuid IS NOT NULL THEN
    RETURN in_same_tenant_v2(check_client_uuid);
  END IF;
  
  -- Default deny
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- HELPER FUNCTIONS FOR COMMON PATTERNS
-- ----------------------------------------------------------------------------

-- Check if user can see another user (same tenant or admin)
CREATE OR REPLACE FUNCTION can_see_user_v2(target_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT is_admin_v2() OR EXISTS (
    SELECT 1 FROM users u1
    JOIN users u2 ON u1.client_uuid = u2.client_uuid
    WHERE u1.auth_user_id = auth.uid()
    AND u2.auth_user_id = target_user_id
    AND u1.active = true
    AND u2.active = true
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Check if user can modify a record (owns it or admin)
CREATE OR REPLACE FUNCTION can_modify_v2(
  record_user_id UUID,
  record_client_uuid UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
  SELECT is_admin_v2() 
    OR owns_record_v2(record_user_id)
    OR (record_client_uuid IS NOT NULL AND in_same_tenant_v2(record_client_uuid));
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- AUDIT TRIGGER FUNCTION (SIMPLIFIED)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_change_v2()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO security_audit_log (
    event_type,
    table_name,
    operation,
    user_id,
    client_uuid,
    row_id,
    old_data,
    new_data,
    success
  ) VALUES (
    TG_OP || '_' || TG_TABLE_NAME,
    TG_TABLE_NAME,
    TG_OP,
    auth.uid(),
    COALESCE(NEW.client_uuid, OLD.client_uuid),
    COALESCE(NEW.uuid, NEW.id, OLD.uuid, OLD.id),
    to_jsonb(OLD),
    to_jsonb(NEW),
    TRUE
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- NOTES FOR PHASE 4 SWITCHOVER
-- ----------------------------------------------------------------------------
-- These functions are created but NOT YET USED
-- In Phase 4, we will:
-- 1. Rename current functions to _old suffix
-- 2. Rename these _v2 functions to remove suffix
-- 3. Update all policies to use new functions
-- This allows instant rollback if needed
-- ----------------------------------------------------------------------------
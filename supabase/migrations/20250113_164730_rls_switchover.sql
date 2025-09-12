-- ============================================================================
-- RLS SWITCHOVER MIGRATION - PHASE 4
-- ============================================================================
-- Purpose: Atomically switch from old RLS to simplified v2 RLS
-- This migration activates the v2 functions and policies
-- Can be rolled back using the rollback script below
-- ============================================================================

-- Start transaction for atomic switchover
BEGIN;

-- ----------------------------------------------------------------------------
-- STEP 1: RENAME OLD FUNCTIONS TO _OLD SUFFIX
-- ----------------------------------------------------------------------------

ALTER FUNCTION is_admin() RENAME TO is_admin_old;
ALTER FUNCTION user_has_client_access(UUID) RENAME TO user_has_client_access_old;
ALTER FUNCTION get_user_client_uuid() RENAME TO get_user_client_uuid_old;
ALTER FUNCTION validate_client_uuid(UUID, TEXT) RENAME TO validate_client_uuid_old;

-- ----------------------------------------------------------------------------
-- STEP 2: RENAME V2 FUNCTIONS TO REMOVE _V2 SUFFIX
-- ----------------------------------------------------------------------------

ALTER FUNCTION is_admin_v2() RENAME TO is_admin;
ALTER FUNCTION in_same_tenant_v2(UUID) RENAME TO in_same_tenant;
ALTER FUNCTION owns_record_v2(UUID) RENAME TO owns_record;
ALTER FUNCTION get_user_client_v2() RENAME TO get_user_client;
ALTER FUNCTION has_access_v2(UUID, UUID, BOOLEAN) RENAME TO has_access;
ALTER FUNCTION can_see_user_v2(UUID) RENAME TO can_see_user;
ALTER FUNCTION can_modify_v2(UUID, UUID) RENAME TO can_modify;
ALTER FUNCTION audit_change_v2() RENAME TO audit_change;

-- ----------------------------------------------------------------------------
-- STEP 3: DROP OLD POLICIES
-- ----------------------------------------------------------------------------

-- Users table
DROP POLICY IF EXISTS "users_select_policy" ON users;
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "users_update_policy" ON users;
DROP POLICY IF EXISTS "users_delete_policy" ON users;

-- Clients table
DROP POLICY IF EXISTS "clients_select_policy" ON clients;
DROP POLICY IF EXISTS "clients_insert_policy" ON clients;
DROP POLICY IF EXISTS "clients_update_policy" ON clients;
DROP POLICY IF EXISTS "clients_delete_policy" ON clients;

-- Client notes table
DROP POLICY IF EXISTS "client_notes_select_policy" ON client_notes;
DROP POLICY IF EXISTS "client_notes_insert_policy" ON client_notes;
DROP POLICY IF EXISTS "client_notes_update_policy" ON client_notes;
DROP POLICY IF EXISTS "client_notes_delete_policy" ON client_notes;

-- Organizations table
DROP POLICY IF EXISTS "organizations_select_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_insert_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;

-- Client org history table
DROP POLICY IF EXISTS "client_org_history_select_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_insert_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_update_policy" ON client_org_history;
DROP POLICY IF EXISTS "client_org_history_delete_policy" ON client_org_history;

-- User admins table
DROP POLICY IF EXISTS "user_admins_select_policy" ON user_admins;
DROP POLICY IF EXISTS "user_admins_insert_policy" ON user_admins;
DROP POLICY IF EXISTS "user_admins_update_policy" ON user_admins;
DROP POLICY IF EXISTS "user_admins_delete_policy" ON user_admins;

-- Security audit log table
DROP POLICY IF EXISTS "audit_log_insert_policy" ON security_audit_log;
DROP POLICY IF EXISTS "audit_log_select_own_policy" ON security_audit_log;
DROP POLICY IF EXISTS "audit_log_admin_select_policy" ON security_audit_log;

-- ----------------------------------------------------------------------------
-- STEP 4: ACTIVATE V2 POLICIES WITH ACTUAL LOGIC
-- ----------------------------------------------------------------------------

-- Users table
DROP POLICY IF EXISTS "users_select_v2" ON users;
CREATE POLICY "users_select_policy" ON users
  FOR SELECT 
  USING (is_admin() OR owns_record(auth_user_id) OR can_see_user(auth_user_id));

DROP POLICY IF EXISTS "users_insert_v2" ON users;
CREATE POLICY "users_insert_policy" ON users
  FOR INSERT
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "users_update_v2" ON users;
CREATE POLICY "users_update_policy" ON users
  FOR UPDATE
  USING (is_admin() OR owns_record(auth_user_id))
  WITH CHECK (is_admin() OR (owns_record(auth_user_id) AND client_uuid = OLD.client_uuid));

DROP POLICY IF EXISTS "users_delete_v2" ON users;
CREATE POLICY "users_delete_policy" ON users
  FOR DELETE
  USING (is_admin());

-- Clients table
DROP POLICY IF EXISTS "clients_select_v2" ON clients;
CREATE POLICY "clients_select_policy" ON clients
  FOR SELECT
  USING (is_admin() OR uuid = get_user_client());

DROP POLICY IF EXISTS "clients_insert_v2" ON clients;
CREATE POLICY "clients_insert_policy" ON clients
  FOR INSERT
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "clients_update_v2" ON clients;
CREATE POLICY "clients_update_policy" ON clients
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "clients_delete_v2" ON clients;
CREATE POLICY "clients_delete_policy" ON clients
  FOR DELETE
  USING (is_admin());

-- Client notes table
DROP POLICY IF EXISTS "client_notes_select_v2" ON client_notes;
CREATE POLICY "client_notes_select_policy" ON client_notes
  FOR SELECT
  USING (has_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_insert_v2" ON client_notes;
CREATE POLICY "client_notes_insert_policy" ON client_notes
  FOR INSERT
  WITH CHECK (has_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_update_v2" ON client_notes;
CREATE POLICY "client_notes_update_policy" ON client_notes
  FOR UPDATE
  USING (has_access(client_uuid))
  WITH CHECK (has_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_delete_v2" ON client_notes;
CREATE POLICY "client_notes_delete_policy" ON client_notes
  FOR DELETE
  USING (is_admin());

-- Organizations table
DROP POLICY IF EXISTS "organizations_select_v2" ON organizations;
CREATE POLICY "organizations_select_policy" ON organizations
  FOR SELECT
  USING (
    is_admin() OR 
    EXISTS (
      SELECT 1 FROM client_org_history coh
      WHERE coh.organization_uuid = organizations.uuid
      AND has_access(coh.client_uuid)
    )
  );

DROP POLICY IF EXISTS "organizations_insert_v2" ON organizations;
CREATE POLICY "organizations_insert_policy" ON organizations
  FOR INSERT
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "organizations_update_v2" ON organizations;
CREATE POLICY "organizations_update_policy" ON organizations
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "organizations_delete_v2" ON organizations;
CREATE POLICY "organizations_delete_policy" ON organizations
  FOR DELETE
  USING (is_admin());

-- Client org history table
DROP POLICY IF EXISTS "client_org_history_select_v2" ON client_org_history;
CREATE POLICY "client_org_history_select_policy" ON client_org_history
  FOR SELECT
  USING (has_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_insert_v2" ON client_org_history;
CREATE POLICY "client_org_history_insert_policy" ON client_org_history
  FOR INSERT
  WITH CHECK (has_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_update_v2" ON client_org_history;
CREATE POLICY "client_org_history_update_policy" ON client_org_history
  FOR UPDATE
  USING (has_access(client_uuid))
  WITH CHECK (has_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_delete_v2" ON client_org_history;
CREATE POLICY "client_org_history_delete_policy" ON client_org_history
  FOR DELETE
  USING (is_admin());

-- User admins table
DROP POLICY IF EXISTS "user_admins_select_v2" ON user_admins;
CREATE POLICY "user_admins_select_policy" ON user_admins
  FOR SELECT
  USING (is_admin() OR owns_record(auth_user_id));

DROP POLICY IF EXISTS "user_admins_insert_v2" ON user_admins;
CREATE POLICY "user_admins_insert_policy" ON user_admins
  FOR INSERT
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "user_admins_update_v2" ON user_admins;
CREATE POLICY "user_admins_update_policy" ON user_admins
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "user_admins_delete_v2" ON user_admins;
CREATE POLICY "user_admins_delete_policy" ON user_admins
  FOR DELETE
  USING (is_admin());

-- Security audit log table
DROP POLICY IF EXISTS "audit_log_insert_v2" ON security_audit_log;
-- Keep insert always allowed

DROP POLICY IF EXISTS "audit_log_select_own_v2" ON security_audit_log;
CREATE POLICY "audit_log_select_own_policy" ON security_audit_log
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "audit_log_select_admin_v2" ON security_audit_log;
CREATE POLICY "audit_log_admin_select_policy" ON security_audit_log
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- ----------------------------------------------------------------------------
-- STEP 5: LOG THE SWITCHOVER
-- ----------------------------------------------------------------------------

INSERT INTO security_audit_log (
  event_type,
  table_name,
  operation,
  metadata,
  success,
  created_at
) VALUES (
  'rls_switchover',
  'system',
  'MIGRATE',
  jsonb_build_object(
    'migration', '20250113_164730_rls_switchover',
    'from_version', 'legacy',
    'to_version', 'simplified_v2',
    'timestamp', NOW()
  ),
  TRUE,
  NOW()
);

-- Commit the transaction
COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (Save this separately)
-- ============================================================================
-- If you need to rollback, run this script:
/*
BEGIN;

-- Rename v2 functions back
ALTER FUNCTION is_admin() RENAME TO is_admin_v2;
ALTER FUNCTION in_same_tenant(UUID) RENAME TO in_same_tenant_v2;
ALTER FUNCTION owns_record(UUID) RENAME TO owns_record_v2;
ALTER FUNCTION get_user_client() RENAME TO get_user_client_v2;
ALTER FUNCTION has_access(UUID, UUID, BOOLEAN) RENAME TO has_access_v2;
ALTER FUNCTION can_see_user(UUID) RENAME TO can_see_user_v2;
ALTER FUNCTION can_modify(UUID, UUID) RENAME TO can_modify_v2;
ALTER FUNCTION audit_change() RENAME TO audit_change_v2;

-- Restore old functions
ALTER FUNCTION is_admin_old() RENAME TO is_admin;
ALTER FUNCTION user_has_client_access_old(UUID) RENAME TO user_has_client_access;
ALTER FUNCTION get_user_client_uuid_old() RENAME TO get_user_client_uuid;
ALTER FUNCTION validate_client_uuid_old(UUID, TEXT) RENAME TO validate_client_uuid;

-- Then restore old policies using scripts/backup-current-rls.sql

COMMIT;
*/
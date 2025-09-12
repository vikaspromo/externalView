-- ============================================================================
-- SIMPLIFIED RLS POLICIES (V2) - DISABLED BY DEFAULT
-- ============================================================================
-- Purpose: Create simplified RLS policies using v2 functions
-- These are created with USING (false) so they're inactive
-- They will be activated in Phase 4 switchover
-- ============================================================================

-- ----------------------------------------------------------------------------
-- USERS TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Users: SELECT - See users in same tenant or own profile
CREATE POLICY "users_select_v2" ON users
  FOR SELECT 
  USING (false); -- DISABLED - will be enabled in Phase 4

-- Users: INSERT - Admin only
CREATE POLICY "users_insert_v2" ON users
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- Users: UPDATE - Own profile or admin
CREATE POLICY "users_update_v2" ON users
  FOR UPDATE
  USING (false) -- DISABLED
  WITH CHECK (false); -- DISABLED

-- Users: DELETE - Admin only
CREATE POLICY "users_delete_v2" ON users
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- CLIENTS TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Clients: SELECT - See own client or admin sees all
CREATE POLICY "clients_select_v2" ON clients
  FOR SELECT
  USING (false); -- DISABLED

-- Clients: INSERT - Admin only
CREATE POLICY "clients_insert_v2" ON clients
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- Clients: UPDATE - Admin only
CREATE POLICY "clients_update_v2" ON clients
  FOR UPDATE
  USING (false)
  WITH CHECK (false); -- DISABLED

-- Clients: DELETE - Admin only
CREATE POLICY "clients_delete_v2" ON clients
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- CLIENT_NOTES TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Client Notes: SELECT - Same tenant or admin
CREATE POLICY "client_notes_select_v2" ON client_notes
  FOR SELECT
  USING (false); -- DISABLED

-- Client Notes: INSERT - Same tenant or admin
CREATE POLICY "client_notes_insert_v2" ON client_notes
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- Client Notes: UPDATE - Same tenant or admin
CREATE POLICY "client_notes_update_v2" ON client_notes
  FOR UPDATE
  USING (false)
  WITH CHECK (false); -- DISABLED

-- Client Notes: DELETE - Admin only
CREATE POLICY "client_notes_delete_v2" ON client_notes
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- ORGANIZATIONS TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Organizations: SELECT - Through client relationship or admin
CREATE POLICY "organizations_select_v2" ON organizations
  FOR SELECT
  USING (false); -- DISABLED

-- Organizations: INSERT - Admin only
CREATE POLICY "organizations_insert_v2" ON organizations
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- Organizations: UPDATE - Admin only
CREATE POLICY "organizations_update_v2" ON organizations
  FOR UPDATE
  USING (false)
  WITH CHECK (false); -- DISABLED

-- Organizations: DELETE - Admin only
CREATE POLICY "organizations_delete_v2" ON organizations
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- CLIENT_ORG_HISTORY TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Client Org History: SELECT - Same tenant or admin
CREATE POLICY "client_org_history_select_v2" ON client_org_history
  FOR SELECT
  USING (false); -- DISABLED

-- Client Org History: INSERT - Same tenant or admin
CREATE POLICY "client_org_history_insert_v2" ON client_org_history
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- Client Org History: UPDATE - Same tenant or admin
CREATE POLICY "client_org_history_update_v2" ON client_org_history
  FOR UPDATE
  USING (false)
  WITH CHECK (false); -- DISABLED

-- Client Org History: DELETE - Admin only
CREATE POLICY "client_org_history_delete_v2" ON client_org_history
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- USER_ADMINS TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- User Admins: SELECT - Admin or own record
CREATE POLICY "user_admins_select_v2" ON user_admins
  FOR SELECT
  USING (false); -- DISABLED

-- User Admins: INSERT - Admin only
CREATE POLICY "user_admins_insert_v2" ON user_admins
  FOR INSERT
  WITH CHECK (false); -- DISABLED

-- User Admins: UPDATE - Admin only
CREATE POLICY "user_admins_update_v2" ON user_admins
  FOR UPDATE
  USING (false)
  WITH CHECK (false); -- DISABLED

-- User Admins: DELETE - Admin only
CREATE POLICY "user_admins_delete_v2" ON user_admins
  FOR DELETE
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- SECURITY_AUDIT_LOG TABLE POLICIES (SIMPLIFIED)
-- ----------------------------------------------------------------------------

-- Audit Log: INSERT - Always allowed for authenticated users
CREATE POLICY "audit_log_insert_v2" ON security_audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (true); -- This one stays ENABLED (safe to have both)

-- Audit Log: SELECT own - Users see their own logs
CREATE POLICY "audit_log_select_own_v2" ON security_audit_log
  FOR SELECT
  TO authenticated
  USING (false); -- DISABLED

-- Audit Log: SELECT all - Admins see all logs
CREATE POLICY "audit_log_select_admin_v2" ON security_audit_log
  FOR SELECT
  TO authenticated
  USING (false); -- DISABLED

-- ----------------------------------------------------------------------------
-- PHASE 4 ACTIVATION PLAN
-- ----------------------------------------------------------------------------
-- In Phase 4, we will run a migration that:
-- 1. Drops or renames old policies to _old suffix
-- 2. Updates these v2 policies to use the actual logic:
--    - users_select_v2: USING (is_admin_v2() OR owns_record_v2(auth_user_id) OR can_see_user_v2(auth_user_id))
--    - users_update_v2: USING (is_admin_v2() OR owns_record_v2(auth_user_id))
--    - clients_select_v2: USING (is_admin_v2() OR uuid = get_user_client_v2())
--    - client_notes_*_v2: USING (has_access_v2(client_uuid))
--    - etc.
-- 3. Renames v2 policies to remove the _v2 suffix
-- 
-- This approach ensures zero downtime and instant rollback capability
-- ----------------------------------------------------------------------------
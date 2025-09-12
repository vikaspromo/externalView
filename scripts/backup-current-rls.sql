-- ============================================================================
-- BACKUP OF CURRENT RLS IMPLEMENTATION
-- ============================================================================
-- Generated: 2025-01-13
-- Purpose: Complete backup of current working RLS policies and functions
-- Use this to restore if the simplified version has issues
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CURRENT RLS FUNCTIONS (Working State)
-- ----------------------------------------------------------------------------

-- Function: is_admin() - Checks if current user is admin
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_admins 
        WHERE auth_user_id = auth.uid() 
        AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function: user_has_client_access() - Core client access validation
CREATE OR REPLACE FUNCTION user_has_client_access(check_client_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Admins have access to all clients
    IF is_admin() THEN
        RETURN TRUE;
    END IF;
    
    -- Regular users only have access to their assigned client
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE auth_user_id = auth.uid()
        AND client_uuid = check_client_uuid
        AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function: get_user_client_uuid() - Gets current user's client
CREATE OR REPLACE FUNCTION get_user_client_uuid()
RETURNS UUID AS $$
DECLARE
    v_client_uuid UUID;
BEGIN
    SELECT client_uuid INTO v_client_uuid
    FROM users
    WHERE auth_user_id = auth.uid()
    AND active = true;
    
    RETURN v_client_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function: validate_client_uuid() - Validates client UUID operations
CREATE OR REPLACE FUNCTION validate_client_uuid(
    p_client_uuid UUID,
    p_operation TEXT DEFAULT 'access'
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check various operation types
    CASE p_operation
        WHEN 'access' THEN
            RETURN user_has_client_access(p_client_uuid);
        WHEN 'create' THEN
            -- For creation, check if user's client matches
            RETURN get_user_client_uuid() = p_client_uuid OR is_admin();
        ELSE
            RETURN FALSE;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- CURRENT RLS POLICIES (Working State)
-- ----------------------------------------------------------------------------

-- USERS TABLE POLICIES
DROP POLICY IF EXISTS "users_select_policy" ON users;
CREATE POLICY "users_select_policy" ON users
    FOR SELECT
    USING (
        is_admin() OR 
        auth.uid() = auth_user_id OR
        client_uuid IN (
            SELECT client_uuid FROM users WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "users_insert_policy" ON users;
CREATE POLICY "users_insert_policy" ON users
    FOR INSERT
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "users_update_policy" ON users;
CREATE POLICY "users_update_policy" ON users
    FOR UPDATE
    USING (
        is_admin() OR auth.uid() = auth_user_id
    )
    WITH CHECK (
        is_admin() OR 
        (auth.uid() = auth_user_id AND client_uuid = OLD.client_uuid)
    );

DROP POLICY IF EXISTS "users_delete_policy" ON users;
CREATE POLICY "users_delete_policy" ON users
    FOR DELETE
    USING (is_admin());

-- CLIENTS TABLE POLICIES
DROP POLICY IF EXISTS "clients_select_policy" ON clients;
CREATE POLICY "clients_select_policy" ON clients
    FOR SELECT
    USING (
        is_admin() OR 
        uuid IN (
            SELECT client_uuid FROM users WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "clients_insert_policy" ON clients;
CREATE POLICY "clients_insert_policy" ON clients
    FOR INSERT
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "clients_update_policy" ON clients;
CREATE POLICY "clients_update_policy" ON clients
    FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "clients_delete_policy" ON clients;
CREATE POLICY "clients_delete_policy" ON clients
    FOR DELETE
    USING (is_admin());

-- CLIENT_NOTES TABLE POLICIES
DROP POLICY IF EXISTS "client_notes_select_policy" ON client_notes;
CREATE POLICY "client_notes_select_policy" ON client_notes
    FOR SELECT
    USING (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_insert_policy" ON client_notes;
CREATE POLICY "client_notes_insert_policy" ON client_notes
    FOR INSERT
    WITH CHECK (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_update_policy" ON client_notes;
CREATE POLICY "client_notes_update_policy" ON client_notes
    FOR UPDATE
    USING (user_has_client_access(client_uuid))
    WITH CHECK (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_notes_delete_policy" ON client_notes;
CREATE POLICY "client_notes_delete_policy" ON client_notes
    FOR DELETE
    USING (is_admin());

-- ORGANIZATIONS TABLE POLICIES
DROP POLICY IF EXISTS "organizations_select_policy" ON organizations;
CREATE POLICY "organizations_select_policy" ON organizations
    FOR SELECT
    USING (
        is_admin() OR 
        EXISTS (
            SELECT 1 FROM client_org_history coh
            WHERE coh.organization_uuid = organizations.uuid
            AND user_has_client_access(coh.client_uuid)
        )
    );

DROP POLICY IF EXISTS "organizations_insert_policy" ON organizations;
CREATE POLICY "organizations_insert_policy" ON organizations
    FOR INSERT
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
CREATE POLICY "organizations_update_policy" ON organizations
    FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;
CREATE POLICY "organizations_delete_policy" ON organizations
    FOR DELETE
    USING (is_admin());

-- CLIENT_ORG_HISTORY TABLE POLICIES
DROP POLICY IF EXISTS "client_org_history_select_policy" ON client_org_history;
CREATE POLICY "client_org_history_select_policy" ON client_org_history
    FOR SELECT
    USING (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_insert_policy" ON client_org_history;
CREATE POLICY "client_org_history_insert_policy" ON client_org_history
    FOR INSERT
    WITH CHECK (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_update_policy" ON client_org_history;
CREATE POLICY "client_org_history_update_policy" ON client_org_history
    FOR UPDATE
    USING (user_has_client_access(client_uuid))
    WITH CHECK (user_has_client_access(client_uuid));

DROP POLICY IF EXISTS "client_org_history_delete_policy" ON client_org_history;
CREATE POLICY "client_org_history_delete_policy" ON client_org_history
    FOR DELETE
    USING (is_admin());

-- USER_ADMINS TABLE POLICIES
DROP POLICY IF EXISTS "user_admins_select_policy" ON user_admins;
CREATE POLICY "user_admins_select_policy" ON user_admins
    FOR SELECT
    USING (is_admin() OR auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "user_admins_insert_policy" ON user_admins;
CREATE POLICY "user_admins_insert_policy" ON user_admins
    FOR INSERT
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "user_admins_update_policy" ON user_admins;
CREATE POLICY "user_admins_update_policy" ON user_admins
    FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "user_admins_delete_policy" ON user_admins;
CREATE POLICY "user_admins_delete_policy" ON user_admins
    FOR DELETE
    USING (is_admin());

-- SECURITY_AUDIT_LOG TABLE POLICIES
DROP POLICY IF EXISTS "audit_log_insert_policy" ON security_audit_log;
CREATE POLICY "audit_log_insert_policy" ON security_audit_log
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "audit_log_select_own_policy" ON security_audit_log;
CREATE POLICY "audit_log_select_own_policy" ON security_audit_log
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "audit_log_admin_select_policy" ON security_audit_log;
CREATE POLICY "audit_log_admin_select_policy" ON security_audit_log
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- ----------------------------------------------------------------------------
-- TRIGGERS AND CONSTRAINTS
-- ----------------------------------------------------------------------------

-- Trigger: prevent_client_uuid_change
CREATE OR REPLACE FUNCTION prevent_client_uuid_change() 
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.client_uuid IS DISTINCT FROM NEW.client_uuid THEN
        IF NOT is_admin() THEN
            RAISE EXCEPTION 'Changing client_uuid is not allowed';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS prevent_client_uuid_change_trigger ON users;
CREATE TRIGGER prevent_client_uuid_change_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION prevent_client_uuid_change();

-- Trigger: auto_populate_client_uuid
CREATE OR REPLACE FUNCTION auto_populate_client_uuid()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.client_uuid IS NULL THEN
        NEW.client_uuid := get_user_client_uuid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply to relevant tables
DROP TRIGGER IF EXISTS auto_populate_client_uuid_trigger ON client_notes;
CREATE TRIGGER auto_populate_client_uuid_trigger
    BEFORE INSERT ON client_notes
    FOR EACH ROW
    EXECUTE FUNCTION auto_populate_client_uuid();

-- ----------------------------------------------------------------------------
-- RESTORATION INSTRUCTIONS
-- ----------------------------------------------------------------------------
-- To restore this RLS configuration:
-- 1. Connect to your Supabase database
-- 2. Run this entire SQL file
-- 3. All policies and functions will be restored to current working state
-- 
-- Note: This will overwrite any changes made by the simplified RLS migration
-- ----------------------------------------------------------------------------
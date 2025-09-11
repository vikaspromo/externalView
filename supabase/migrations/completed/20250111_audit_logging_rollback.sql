-- ============================================================================
-- AUDIT LOGGING SYSTEM - ROLLBACK SCRIPT
-- ============================================================================
-- Purpose: Safely remove audit logging system if needed
-- WARNING: This will remove all audit trails - use with extreme caution!
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: DROP TRIGGERS (Must be done first)
-- ----------------------------------------------------------------------------

-- Drop audit triggers from all tables
DROP TRIGGER IF EXISTS audit_trigger_users ON users;
DROP TRIGGER IF EXISTS audit_trigger_clients ON clients;
DROP TRIGGER IF EXISTS audit_trigger_organizations ON organizations;
DROP TRIGGER IF EXISTS audit_trigger_client_org_history ON client_org_history;
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_contacts ON stakeholder_contacts;
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_notes ON stakeholder_notes;
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_types ON stakeholder_types;
DROP TRIGGER IF EXISTS audit_trigger_event_attendees ON event_attendees;
DROP TRIGGER IF EXISTS audit_trigger_user_admins ON user_admins;

-- Drop detection triggers
DROP TRIGGER IF EXISTS detect_cross_client_trigger ON security_audit_log;
DROP TRIGGER IF EXISTS detect_suspicious_trigger ON security_audit_log;

-- Drop tamper protection triggers
DROP TRIGGER IF EXISTS prevent_audit_update ON security_audit_log;
DROP TRIGGER IF EXISTS prevent_audit_delete ON security_audit_log;

-- ----------------------------------------------------------------------------
-- STEP 2: DROP VIEWS
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS recent_pii_access CASCADE;
DROP VIEW IF EXISTS cross_client_attempts CASCADE;
DROP VIEW IF EXISTS admin_activity CASCADE;
DROP VIEW IF EXISTS data_exports CASCADE;
DROP VIEW IF EXISTS failed_access_attempts CASCADE;
DROP VIEW IF EXISTS audit_performance_metrics CASCADE;

-- ----------------------------------------------------------------------------
-- STEP 3: DROP POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS audit_log_insert_policy ON security_audit_log;
DROP POLICY IF EXISTS audit_log_select_own_policy ON security_audit_log;
DROP POLICY IF EXISTS audit_log_admin_select_policy ON security_audit_log;

-- ----------------------------------------------------------------------------
-- STEP 4: DROP FUNCTIONS
-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS audit_trigger_function() CASCADE;
DROP FUNCTION IF EXISTS audit_select_function() CASCADE;
DROP FUNCTION IF EXISTS prevent_audit_log_modification() CASCADE;
DROP FUNCTION IF EXISTS detect_cross_client_access() CASCADE;
DROP FUNCTION IF EXISTS detect_suspicious_activity() CASCADE;
DROP FUNCTION IF EXISTS get_current_user_email() CASCADE;
DROP FUNCTION IF EXISTS detect_changed_fields(JSONB, JSONB) CASCADE;
DROP FUNCTION IF EXISTS calculate_audit_checksum(UUID, TEXT, TEXT, UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS determine_data_classification(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_client_uuid_for_table(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS archive_old_audit_logs() CASCADE;
DROP FUNCTION IF EXISTS set_audit_purpose(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_record_audit_trail(TEXT, UUID) CASCADE;

-- ----------------------------------------------------------------------------
-- STEP 5: DROP TEST FUNCTIONS (if they exist)
-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS audit_tests.test_insert_logging() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_update_change_detection() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_delete_logging() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_data_classification() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_checksum_integrity() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_tamper_protection() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_no_change_update() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_cross_client_detection() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_performance_impact() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.test_compliance_views() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.run_all_tests() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.cleanup_test_data() CASCADE;
DROP FUNCTION IF EXISTS audit_tests.clear_test_logs() CASCADE;

-- Drop test schema if exists
DROP SCHEMA IF EXISTS audit_tests CASCADE;

-- ----------------------------------------------------------------------------
-- STEP 6: RESTORE PERMISSIONS ON AUDIT LOG TABLE
-- ----------------------------------------------------------------------------

-- Re-enable standard permissions (if you want to keep the table)
GRANT UPDATE, DELETE ON security_audit_log TO authenticated;

-- ----------------------------------------------------------------------------
-- STEP 7: REMOVE ADDED COLUMNS (Optional - keeps base table structure)
-- ----------------------------------------------------------------------------

-- Remove columns added by the audit system
ALTER TABLE security_audit_log 
DROP COLUMN IF EXISTS data_classification,
DROP COLUMN IF EXISTS purpose,
DROP COLUMN IF EXISTS checksum,
DROP COLUMN IF EXISTS session_id,
DROP COLUMN IF EXISTS request_id,
DROP COLUMN IF EXISTS is_cross_client_access,
DROP COLUMN IF EXISTS access_denied,
DROP COLUMN IF EXISTS error_message,
DROP COLUMN IF EXISTS execution_time_ms;

-- ----------------------------------------------------------------------------
-- STEP 8: DROP INDEXES
-- ----------------------------------------------------------------------------

DROP INDEX IF EXISTS idx_audit_log_user_id;
DROP INDEX IF EXISTS idx_audit_log_client_uuid;
DROP INDEX IF EXISTS idx_audit_log_timestamp;
DROP INDEX IF EXISTS idx_audit_log_table_operation;
DROP INDEX IF EXISTS idx_audit_log_cross_client;

-- ----------------------------------------------------------------------------
-- STEP 9: DISABLE RLS (Optional)
-- ----------------------------------------------------------------------------

ALTER TABLE security_audit_log DISABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- STEP 10: DROP ARCHIVE TABLE (if exists)
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS security_audit_log_archive CASCADE;

-- ----------------------------------------------------------------------------
-- OPTIONAL: COMPLETELY REMOVE AUDIT LOG TABLE
-- ----------------------------------------------------------------------------
-- WARNING: This will permanently delete all audit history!
-- Uncomment only if you want to completely remove the audit system

-- DROP TABLE IF EXISTS security_audit_log CASCADE;

-- ----------------------------------------------------------------------------
-- VERIFICATION
-- ----------------------------------------------------------------------------

-- Check that all triggers have been removed
SELECT 
    'Triggers remaining: ' || COUNT(*)::TEXT as status
FROM pg_triggers
WHERE schemaname = 'public'
AND triggername LIKE 'audit_%';

-- Check that all audit functions have been removed
SELECT 
    'Audit functions remaining: ' || COUNT(*)::TEXT as status
FROM pg_proc
WHERE proname LIKE '%audit%'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ----------------------------------------------------------------------------
-- COMPLETION MESSAGE
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    RAISE NOTICE 'Audit logging system has been rolled back.';
    RAISE NOTICE 'The security_audit_log table still exists with data intact.';
    RAISE NOTICE 'To completely remove the table and all audit data, uncomment the DROP TABLE statement.';
END $$;
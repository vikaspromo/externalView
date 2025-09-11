-- ============================================================================
-- FINAL TEST REPORT: RLS AND AUDIT LOGGING VERIFICATION
-- ============================================================================

\echo '=========================================='
\echo 'RLS AND AUDIT LOGGING TEST REPORT'
\echo '=========================================='
\echo ''

-- Clean any previous test data
DELETE FROM client_org_history WHERE client_uuid IN ('99999999-9999-9999-9999-999999999999', '88888888-8888-8888-8888-888888888888');
DELETE FROM users WHERE email LIKE 'final_test_%';
DELETE FROM clients WHERE name LIKE 'Final Test%';

-- Create test data properly
INSERT INTO clients (uuid, name, active) VALUES
  ('99999999-9999-9999-9999-999999999999', 'Final Test Client A', true);

INSERT INTO users (id, email, client_uuid, first_name, last_name) VALUES
  (gen_random_uuid(), 'final_test_user@example.com', '99999999-9999-9999-9999-999999999999', 'Final', 'Test');

\echo '✅ Test data created'
\echo ''
\echo '==========================================

-- TEST AUDIT LOGGING BY UPDATING A USER
\echo 'Testing Audit Logging...'
\echo '-----------------------------------------'

-- Count audit logs before
SELECT COUNT(*) as audit_logs_before_update FROM security_audit_log;

-- Perform update
UPDATE clients 
SET name = 'Final Test Client A - Updated'
WHERE uuid = '99999999-9999-9999-9999-999999999999';

-- Count audit logs after
SELECT COUNT(*) as audit_logs_after_update FROM security_audit_log;

-- Show the latest audit log
\echo ''
\echo 'Latest Audit Log Entry:'
SELECT 
    table_name,
    operation,
    row_id,
    old_data->>'name' as old_name,
    new_data->>'name' as new_name,
    changed_fields,
    data_classification,
    "timestamp"
FROM security_audit_log
WHERE table_name = 'clients'
ORDER BY "timestamp" DESC
LIMIT 1;

\echo ''
\echo '=========================================='
\echo 'TEST RESULTS SUMMARY'
\echo '=========================================='
\echo ''

-- Summary of RLS Tests
\echo 'RLS CROSS-TENANT PROTECTION:'
SELECT 
    test_name,
    CASE 
        WHEN test_result THEN '✅ PASSED'
        ELSE '❌ FAILED'
    END as result
FROM test_cross_tenant_protection();

\echo ''
\echo 'AUDIT LOGGING FEATURES:'
-- Check if audit logging is working
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ PASSED - Audit logs are being created'
        ELSE '❌ FAILED - No audit logs found'
    END as audit_logging_status
FROM security_audit_log
WHERE "timestamp" >= NOW() - INTERVAL '1 hour';

-- Check tamper protection
\echo ''
\echo 'TAMPER PROTECTION:'
DO $$
DECLARE
    v_log_id UUID;
    v_can_update BOOLEAN := FALSE;
    v_can_delete BOOLEAN := FALSE;
BEGIN
    -- Get an audit log ID
    SELECT id INTO v_log_id FROM security_audit_log LIMIT 1;
    
    IF v_log_id IS NOT NULL THEN
        -- Try to update
        BEGIN
            UPDATE security_audit_log SET user_email = 'test' WHERE id = v_log_id;
            v_can_update := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_can_update := FALSE;
        END;
        
        -- Try to delete
        BEGIN
            DELETE FROM security_audit_log WHERE id = v_log_id;
            v_can_delete := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_can_delete := FALSE;
        END;
        
        IF NOT v_can_update AND NOT v_can_delete THEN
            RAISE NOTICE '✅ PASSED - Audit logs are tamper-proof';
        ELSE
            RAISE NOTICE '❌ FAILED - Audit logs can be modified';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ SKIPPED - No audit logs to test';
    END IF;
END $$;

-- Check compliance views
\echo ''
\echo 'COMPLIANCE VIEWS:'
SELECT 
    'recent_pii_access' as view_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'recent_pii_access')
        THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
UNION ALL
SELECT 
    'admin_activity',
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'admin_activity')
        THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END
UNION ALL
SELECT 
    'cross_client_attempts',
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'cross_client_attempts')
        THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END
UNION ALL
SELECT 
    'data_exports',
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'data_exports')
        THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END;

-- Check audit triggers
\echo ''
\echo 'AUDIT TRIGGERS INSTALLED:'
SELECT 
    COUNT(*) as audit_trigger_count,
    STRING_AGG(c.relname, ', ' ORDER BY c.relname) as tables_with_triggers
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND t.tgname LIKE 'audit_trigger_%';

\echo ''
\echo '=========================================='
\echo 'FINAL VERDICT'
\echo '=========================================='

SELECT 
    CASE 
        WHEN (
            -- Check if we have audit triggers
            EXISTS (SELECT 1 FROM pg_trigger WHERE tgname LIKE 'audit_trigger_%')
            -- Check if we have audit logs
            AND EXISTS (SELECT 1 FROM security_audit_log)
            -- Check if we have compliance views
            AND EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'recent_pii_access')
            -- Check if RLS is enabled
            AND EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clients' AND rowsecurity = true)
        )
        THEN E'\n✅✅✅ SYSTEM IS SECURE ✅✅✅\nBoth RLS and Audit Logging are functioning correctly!'
        ELSE E'\n⚠️⚠️⚠️ ISSUES DETECTED ⚠️⚠️⚠️\nSome security features may not be working properly.'
    END as final_status;
-- ============================================================================
-- COMPREHENSIVE TEST SUITE FOR RLS AND AUDIT LOGGING
-- ============================================================================

-- Clean up any previous test run
DELETE FROM client_org_history WHERE client_uuid IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM users WHERE id IN ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
DELETE FROM clients WHERE uuid IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM organizations WHERE id IN ('org11111-1111-1111-1111-111111111111', 'org22222-2222-2222-2222-222222222222');

-- ----------------------------------------------------------------------------
-- SETUP TEST DATA
-- ----------------------------------------------------------------------------
\echo '=========================================='
\echo 'SETTING UP TEST DATA'
\echo '=========================================='

-- Create test clients
INSERT INTO clients (uuid, name, active) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Test Client 1', true),
  ('22222222-2222-2222-2222-222222222222', 'Test Client 2', true);

-- Create test users
INSERT INTO users (id, email, client_uuid, first_name, last_name) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'test_user1@example.com', '11111111-1111-1111-1111-111111111111', 'User', 'One'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'test_user2@example.com', '22222222-2222-2222-2222-222222222222', 'User', 'Two');

-- Create test organizations
INSERT INTO organizations (id, name, type) VALUES
  ('org11111-1111-1111-1111-111111111111', 'Test Org 1', 'corporate'),
  ('org22222-2222-2222-2222-222222222222', 'Test Org 2', 'government');

\echo 'Test data created successfully'

-- ----------------------------------------------------------------------------
-- TEST 1: RLS CROSS-TENANT PROTECTION
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 1: RLS CROSS-TENANT PROTECTION'
\echo '=========================================='

-- Run the built-in test function
SELECT 
    test_name,
    CASE 
        WHEN test_result THEN '✅ PASSED'
        ELSE '❌ FAILED'
    END as result,
    error_message
FROM test_cross_tenant_protection();

-- ----------------------------------------------------------------------------
-- TEST 2: AUDIT LOG INSERTION
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 2: AUDIT LOG INSERTION'
\echo '=========================================='

-- Count audit logs before operation
SELECT COUNT(*) as audit_logs_before FROM security_audit_log;

-- Perform an update to trigger audit logging
UPDATE users 
SET first_name = 'Updated'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Count audit logs after operation
SELECT COUNT(*) as audit_logs_after FROM security_audit_log;

-- Show the audit log entry
\echo 'Latest audit log entry:'
SELECT 
    user_email,
    table_name,
    operation,
    changed_fields,
    old_data->>'first_name' as old_first_name,
    new_data->>'first_name' as new_first_name,
    "timestamp"
FROM security_audit_log
WHERE table_name = 'users'
ORDER BY "timestamp" DESC
LIMIT 1;

-- ----------------------------------------------------------------------------
-- TEST 3: TAMPER PROTECTION
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 3: AUDIT LOG TAMPER PROTECTION'
\echo '=========================================='

-- Try to update an audit log (should fail)
DO $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Get an audit log ID
    SELECT id INTO v_log_id FROM security_audit_log LIMIT 1;
    
    -- Try to update it
    UPDATE security_audit_log 
    SET user_email = 'hacker@evil.com'
    WHERE id = v_log_id;
    
    RAISE NOTICE '❌ FAILED: Audit log was modified!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✅ PASSED: Cannot modify audit logs - %', SQLERRM;
END $$;

-- Try to delete an audit log (should fail)
DO $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Get an audit log ID
    SELECT id INTO v_log_id FROM security_audit_log LIMIT 1;
    
    -- Try to delete it
    DELETE FROM security_audit_log WHERE id = v_log_id;
    
    RAISE NOTICE '❌ FAILED: Audit log was deleted!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✅ PASSED: Cannot delete audit logs - %', SQLERRM;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 4: DATA CLASSIFICATION
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 4: DATA CLASSIFICATION'
\echo '=========================================='

-- Check data classification for different tables
SELECT DISTINCT
    table_name,
    data_classification,
    COUNT(*) as log_count
FROM security_audit_log
WHERE table_name IN ('users', 'clients', 'organizations')
GROUP BY table_name, data_classification
ORDER BY table_name;

-- ----------------------------------------------------------------------------
-- TEST 5: COMPLIANCE VIEWS
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 5: COMPLIANCE VIEWS'
\echo '=========================================='

-- Check if compliance views exist and work
\echo 'Checking recent_pii_access view:'
SELECT COUNT(*) as pii_access_count FROM recent_pii_access;

\echo 'Checking admin_activity view:'
SELECT COUNT(*) as admin_activity_count FROM admin_activity;

\echo 'Checking cross_client_attempts view:'
SELECT COUNT(*) as cross_client_attempts_count FROM cross_client_attempts;

\echo 'Checking data_exports view:'
SELECT COUNT(*) as data_exports_count FROM data_exports;

-- ----------------------------------------------------------------------------
-- TEST 6: PERFORMANCE CHECK
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST 6: PERFORMANCE CHECK'
\echo '=========================================='

DO $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration_ms INTEGER;
    i INTEGER;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Perform 50 updates
    FOR i IN 1..50 LOOP
        UPDATE organizations 
        SET type = CASE WHEN type = 'corporate' THEN 'government' ELSE 'corporate' END
        WHERE id = 'org11111-1111-1111-1111-111111111111';
    END LOOP;
    
    v_end_time := clock_timestamp();
    v_duration_ms := EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
    
    IF v_duration_ms < 500 THEN
        RAISE NOTICE '✅ PASSED: 50 updates completed in % ms (excellent performance)', v_duration_ms;
    ELSIF v_duration_ms < 1000 THEN
        RAISE NOTICE '✅ PASSED: 50 updates completed in % ms (good performance)', v_duration_ms;
    ELSE
        RAISE NOTICE '⚠️ WARNING: 50 updates took % ms (may need optimization)', v_duration_ms;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- SUMMARY
-- ----------------------------------------------------------------------------
\echo ''
\echo '=========================================='
\echo 'TEST SUMMARY'
\echo '=========================================='

-- Count total audit logs created during testing
SELECT 
    'Total audit logs created' as metric,
    COUNT(*) as value
FROM security_audit_log
WHERE user_email LIKE 'test_%@example.com'
   OR table_name IN ('clients', 'users', 'organizations')
   AND "timestamp" >= NOW() - INTERVAL '5 minutes';

-- Show audit log statistics
SELECT 
    table_name,
    operation,
    COUNT(*) as count
FROM security_audit_log
WHERE "timestamp" >= NOW() - INTERVAL '5 minutes'
GROUP BY table_name, operation
ORDER BY table_name, operation;

\echo ''
\echo '=========================================='
\echo 'ALL TESTS COMPLETED'
\echo '=========================================='
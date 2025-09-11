-- ============================================================================
-- AUDIT LOGGING SYSTEM - TEST CASES
-- ============================================================================
-- Purpose: Comprehensive test suite to verify audit logging functionality
-- Run these tests after applying the main migration
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SETUP
-- ----------------------------------------------------------------------------

-- Create a test schema to isolate test data
CREATE SCHEMA IF NOT EXISTS audit_tests;

-- Function to clear test audit logs
CREATE OR REPLACE FUNCTION audit_tests.clear_test_logs()
RETURNS VOID AS $$
BEGIN
    -- We can't delete audit logs, but we can mark test entries
    -- In production, you'd filter these out from reports
    NULL;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- TEST 1: INSERT OPERATION LOGGING
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_insert_logging()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_test_user_id UUID;
    v_audit_count INTEGER;
    v_test_client_id UUID;
BEGIN
    -- Set audit purpose for testing
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create a test client
    INSERT INTO clients (name, display_name)
    VALUES ('Test Client for Audit', 'Test Display')
    RETURNING id INTO v_test_client_id;
    
    -- Check if audit log was created
    SELECT COUNT(*) INTO v_audit_count
    FROM security_audit_log
    WHERE table_name = 'clients'
    AND operation = 'INSERT'
    AND row_id = v_test_client_id
    AND new_data->>'name' = 'Test Client for Audit';
    
    IF v_audit_count = 1 THEN
        RETURN QUERY SELECT 
            'INSERT Logging'::TEXT,
            'PASSED'::TEXT,
            'Insert operation correctly logged with full new_data'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'INSERT Logging'::TEXT,
            'FAILED'::TEXT,
            format('Expected 1 audit log, found %s', v_audit_count)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 2: UPDATE OPERATION - CHANGE DETECTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_update_change_detection()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_test_org_id UUID;
    v_audit_record RECORD;
    v_changed_fields_count INTEGER;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create a test organization
    INSERT INTO organizations (name, ein, mission)
    VALUES ('Test Org', '12-3456789', 'Original Mission')
    RETURNING id INTO v_test_org_id;
    
    -- Update only the mission field
    UPDATE organizations
    SET mission = 'Updated Mission'
    WHERE id = v_test_org_id;
    
    -- Check the update audit log
    SELECT * INTO v_audit_record
    FROM security_audit_log
    WHERE table_name = 'organizations'
    AND operation = 'UPDATE'
    AND row_id = v_test_org_id
    ORDER BY timestamp DESC
    LIMIT 1;
    
    -- Verify only changed fields are logged
    v_changed_fields_count := array_length(v_audit_record.changed_fields, 1);
    
    IF v_changed_fields_count = 1 
       AND v_audit_record.changed_fields[1] = 'mission'
       AND v_audit_record.old_data->>'mission' = 'Original Mission'
       AND v_audit_record.new_data->>'mission' = 'Updated Mission' THEN
        RETURN QUERY SELECT 
            'UPDATE Change Detection'::TEXT,
            'PASSED'::TEXT,
            'Only changed fields logged correctly'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'UPDATE Change Detection'::TEXT,
            'FAILED'::TEXT,
            format('Changed fields: %s, Expected: mission only', v_audit_record.changed_fields)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 3: DELETE OPERATION LOGGING
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_delete_logging()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_test_type_id UUID;
    v_audit_record RECORD;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create a test stakeholder type
    INSERT INTO stakeholder_types (name, description)
    VALUES ('Test Type', 'Test Description')
    RETURNING id INTO v_test_type_id;
    
    -- Delete the test type
    DELETE FROM stakeholder_types
    WHERE id = v_test_type_id;
    
    -- Check the delete audit log
    SELECT * INTO v_audit_record
    FROM security_audit_log
    WHERE table_name = 'stakeholder_types'
    AND operation = 'DELETE'
    AND row_id = v_test_type_id;
    
    IF v_audit_record.old_data->>'name' = 'Test Type' 
       AND v_audit_record.new_data IS NULL THEN
        RETURN QUERY SELECT 
            'DELETE Logging'::TEXT,
            'PASSED'::TEXT,
            'Delete operation logged with full old_data'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'DELETE Logging'::TEXT,
            'FAILED'::TEXT,
            'Delete operation not properly logged'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 4: DATA CLASSIFICATION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_data_classification()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_pii_class TEXT;
    v_sensitive_class TEXT;
    v_confidential_class TEXT;
    v_test_contact_id UUID;
    v_test_note_id UUID;
    v_test_client_id UUID;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create test data in different classification categories
    
    -- PII data (stakeholder_contacts)
    INSERT INTO clients (name, display_name)
    VALUES ('Test Client Class', 'Test')
    RETURNING id INTO v_test_client_id;
    
    INSERT INTO stakeholder_contacts (client_uuid, first_name, last_name, email)
    VALUES (v_test_client_id, 'John', 'Doe', 'john@test.com')
    RETURNING id INTO v_test_contact_id;
    
    SELECT data_classification INTO v_pii_class
    FROM security_audit_log
    WHERE row_id = v_test_contact_id
    AND table_name = 'stakeholder_contacts';
    
    -- Sensitive data (stakeholder_notes)
    INSERT INTO stakeholder_notes (client_uuid, contact_id, note)
    VALUES (v_test_client_id, v_test_contact_id, 'Sensitive note')
    RETURNING id INTO v_test_note_id;
    
    SELECT data_classification INTO v_sensitive_class
    FROM security_audit_log
    WHERE row_id = v_test_note_id
    AND table_name = 'stakeholder_notes';
    
    -- Confidential data (clients)
    SELECT data_classification INTO v_confidential_class
    FROM security_audit_log
    WHERE row_id = v_test_client_id
    AND table_name = 'clients';
    
    IF v_pii_class = 'PII' 
       AND v_sensitive_class = 'SENSITIVE'
       AND v_confidential_class = 'CONFIDENTIAL' THEN
        RETURN QUERY SELECT 
            'Data Classification'::TEXT,
            'PASSED'::TEXT,
            'All data classifications correctly assigned'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Data Classification'::TEXT,
            'FAILED'::TEXT,
            format('Classifications: PII=%s, SENSITIVE=%s, CONFIDENTIAL=%s', 
                   v_pii_class, v_sensitive_class, v_confidential_class)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 5: CHECKSUM INTEGRITY
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_checksum_integrity()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_test_client_id UUID;
    v_checksum1 TEXT;
    v_checksum2 TEXT;
    v_calculated_checksum TEXT;
    v_audit_record RECORD;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create test data
    INSERT INTO clients (name, display_name)
    VALUES ('Checksum Test', 'Test')
    RETURNING id INTO v_test_client_id;
    
    -- Get the audit record
    SELECT * INTO v_audit_record
    FROM security_audit_log
    WHERE row_id = v_test_client_id
    AND table_name = 'clients'
    AND operation = 'INSERT';
    
    -- Calculate expected checksum
    v_calculated_checksum := calculate_audit_checksum(
        v_audit_record.user_id,
        v_audit_record.table_name,
        v_audit_record.operation,
        v_audit_record.row_id,
        v_audit_record.new_data
    );
    
    IF v_audit_record.checksum = v_calculated_checksum THEN
        RETURN QUERY SELECT 
            'Checksum Integrity'::TEXT,
            'PASSED'::TEXT,
            'Checksum correctly calculated and stored'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Checksum Integrity'::TEXT,
            'FAILED'::TEXT,
            'Checksum mismatch detected'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 6: TAMPER PROTECTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_tamper_protection()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_error_caught BOOLEAN := FALSE;
    v_test_log_id UUID;
BEGIN
    -- Get any audit log entry
    SELECT id INTO v_test_log_id
    FROM security_audit_log
    LIMIT 1;
    
    -- Try to update an audit log (should fail)
    BEGIN
        UPDATE security_audit_log
        SET user_email = 'tampered@test.com'
        WHERE id = v_test_log_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_caught := TRUE;
    END;
    
    IF v_error_caught THEN
        RETURN QUERY SELECT 
            'Tamper Protection - UPDATE'::TEXT,
            'PASSED'::TEXT,
            'Audit logs cannot be updated'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Tamper Protection - UPDATE'::TEXT,
            'FAILED'::TEXT,
            'Update was not prevented'::TEXT;
    END IF;
    
    -- Try to delete an audit log (should fail)
    v_error_caught := FALSE;
    BEGIN
        DELETE FROM security_audit_log
        WHERE id = v_test_log_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_caught := TRUE;
    END;
    
    IF v_error_caught THEN
        RETURN QUERY SELECT 
            'Tamper Protection - DELETE'::TEXT,
            'PASSED'::TEXT,
            'Audit logs cannot be deleted'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Tamper Protection - DELETE'::TEXT,
            'FAILED'::TEXT,
            'Delete was not prevented'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 7: NO-CHANGE UPDATE DETECTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_no_change_update()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_test_org_id UUID;
    v_initial_count INTEGER;
    v_final_count INTEGER;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('audit_system_testing');
    
    -- Create test organization
    INSERT INTO organizations (name, ein, mission)
    VALUES ('No Change Test', '98-7654321', 'Test Mission')
    RETURNING id INTO v_test_org_id;
    
    -- Get initial audit count
    SELECT COUNT(*) INTO v_initial_count
    FROM security_audit_log
    WHERE row_id = v_test_org_id;
    
    -- Update with same values (no actual change)
    UPDATE organizations
    SET name = 'No Change Test',
        mission = 'Test Mission'
    WHERE id = v_test_org_id;
    
    -- Get final audit count
    SELECT COUNT(*) INTO v_final_count
    FROM security_audit_log
    WHERE row_id = v_test_org_id;
    
    -- Should not create new audit log for no-change update
    IF v_final_count = v_initial_count THEN
        RETURN QUERY SELECT 
            'No-Change Update Detection'::TEXT,
            'PASSED'::TEXT,
            'No audit log created for update with no changes'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'No-Change Update Detection'::TEXT,
            'FAILED'::TEXT,
            format('Audit count increased from %s to %s', v_initial_count, v_final_count)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 8: CROSS-CLIENT ACCESS DETECTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_cross_client_detection()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_client1_id UUID;
    v_client2_id UUID;
    v_user_id UUID;
    v_contact_id UUID;
    v_is_cross_client BOOLEAN;
BEGIN
    -- This test would require setting up multiple clients and user associations
    -- Simplified for demonstration
    
    RETURN QUERY SELECT 
        'Cross-Client Detection'::TEXT,
        'SKIPPED'::TEXT,
        'Requires multi-tenant setup with authenticated users'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 9: PERFORMANCE IMPACT
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_performance_impact()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration_ms INTEGER;
    v_test_client_id UUID;
BEGIN
    -- Set audit purpose
    PERFORM set_audit_purpose('performance_testing');
    
    -- Measure time for operations with audit logging
    v_start_time := clock_timestamp();
    
    -- Perform 100 inserts
    FOR i IN 1..100 LOOP
        INSERT INTO clients (name, display_name)
        VALUES ('Perf Test ' || i, 'Test ' || i);
    END LOOP;
    
    v_end_time := clock_timestamp();
    v_duration_ms := EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
    
    -- Check if performance is acceptable (< 1 second for 100 inserts)
    IF v_duration_ms < 1000 THEN
        RETURN QUERY SELECT 
            'Performance Impact'::TEXT,
            'PASSED'::TEXT,
            format('100 inserts completed in %s ms', v_duration_ms)::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Performance Impact'::TEXT,
            'WARNING'::TEXT,
            format('100 inserts took %s ms (may need optimization)', v_duration_ms)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- TEST 10: COMPLIANCE VIEWS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.test_compliance_views()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
DECLARE
    v_view_exists BOOLEAN;
    v_missing_views TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check if all compliance views exist and are accessible
    
    -- Check recent_pii_access view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'recent_pii_access'
    ) INTO v_view_exists;
    
    IF NOT v_view_exists THEN
        v_missing_views := array_append(v_missing_views, 'recent_pii_access');
    END IF;
    
    -- Check cross_client_attempts view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'cross_client_attempts'
    ) INTO v_view_exists;
    
    IF NOT v_view_exists THEN
        v_missing_views := array_append(v_missing_views, 'cross_client_attempts');
    END IF;
    
    -- Check admin_activity view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'admin_activity'
    ) INTO v_view_exists;
    
    IF NOT v_view_exists THEN
        v_missing_views := array_append(v_missing_views, 'admin_activity');
    END IF;
    
    -- Check data_exports view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'data_exports'
    ) INTO v_view_exists;
    
    IF NOT v_view_exists THEN
        v_missing_views := array_append(v_missing_views, 'data_exports');
    END IF;
    
    IF array_length(v_missing_views, 1) IS NULL THEN
        RETURN QUERY SELECT 
            'Compliance Views'::TEXT,
            'PASSED'::TEXT,
            'All compliance views exist and are accessible'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            'Compliance Views'::TEXT,
            'FAILED'::TEXT,
            format('Missing views: %s', array_to_string(v_missing_views, ', '))::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- MASTER TEST RUNNER
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_tests.run_all_tests()
RETURNS TABLE(test_name TEXT, status TEXT, details TEXT) AS $$
BEGIN
    RETURN QUERY SELECT * FROM audit_tests.test_insert_logging();
    RETURN QUERY SELECT * FROM audit_tests.test_update_change_detection();
    RETURN QUERY SELECT * FROM audit_tests.test_delete_logging();
    RETURN QUERY SELECT * FROM audit_tests.test_data_classification();
    RETURN QUERY SELECT * FROM audit_tests.test_checksum_integrity();
    RETURN QUERY SELECT * FROM audit_tests.test_tamper_protection();
    RETURN QUERY SELECT * FROM audit_tests.test_no_change_update();
    RETURN QUERY SELECT * FROM audit_tests.test_cross_client_detection();
    RETURN QUERY SELECT * FROM audit_tests.test_performance_impact();
    RETURN QUERY SELECT * FROM audit_tests.test_compliance_views();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- RUN TESTS
-- ----------------------------------------------------------------------------

-- Execute all tests and display results
SELECT * FROM audit_tests.run_all_tests();

-- ----------------------------------------------------------------------------
-- CLEANUP TEST DATA (Optional)
-- ----------------------------------------------------------------------------

-- Note: We cannot delete audit logs, but we can clean up test entities
-- This should be run after verifying test results

CREATE OR REPLACE FUNCTION audit_tests.cleanup_test_data()
RETURNS TEXT AS $$
BEGIN
    -- Delete test clients (will cascade to related data)
    DELETE FROM clients 
    WHERE name LIKE 'Test%' 
    OR name LIKE 'Perf Test%'
    OR name LIKE 'Checksum Test'
    OR name LIKE 'No Change Test';
    
    -- Delete test organizations
    DELETE FROM organizations
    WHERE name LIKE 'Test%'
    OR name LIKE 'No Change Test';
    
    -- Delete test stakeholder types
    DELETE FROM stakeholder_types
    WHERE name LIKE 'Test%';
    
    RETURN 'Test data cleaned up (audit logs remain for compliance)';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Uncomment to clean up after testing:
-- SELECT audit_tests.cleanup_test_data();
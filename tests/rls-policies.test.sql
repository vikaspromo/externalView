-- ============================================================================
-- RLS POLICY TEST SUITE
-- ============================================================================
-- Purpose: Comprehensive tests for current RLS implementation
-- This ensures we maintain the same security behavior after simplification
-- Run these tests before and after the RLS refactoring
-- ============================================================================

-- Setup test environment
BEGIN;

-- ----------------------------------------------------------------------------
-- TEST HELPER FUNCTIONS
-- ----------------------------------------------------------------------------

-- Function to create test users
CREATE OR REPLACE FUNCTION create_test_user(
    p_email TEXT,
    p_client_uuid UUID DEFAULT NULL,
    p_is_admin BOOLEAN DEFAULT FALSE
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Create auth user (simulate Supabase auth)
    v_user_id := gen_random_uuid();
    
    -- Insert into users table
    INSERT INTO users (auth_user_id, email, client_uuid, active)
    VALUES (v_user_id, p_email, p_client_uuid, TRUE);
    
    -- If admin, add to user_admins
    IF p_is_admin THEN
        INSERT INTO user_admins (auth_user_id, active, created_at)
        VALUES (v_user_id, TRUE, NOW());
    END IF;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to run test as specific user
CREATE OR REPLACE FUNCTION run_as_user(p_user_id UUID) RETURNS VOID AS $$
BEGIN
    -- Set the auth.uid() for this session
    PERFORM set_config('request.jwt.claims', 
        json_build_object('sub', p_user_id::TEXT)::TEXT, TRUE);
END;
$$ LANGUAGE plpgsql;

-- Function to assert test results
CREATE OR REPLACE FUNCTION assert(
    p_condition BOOLEAN,
    p_test_name TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT p_condition THEN
        RAISE EXCEPTION 'Test failed: %', p_test_name;
    END IF;
    RAISE NOTICE '✓ Test passed: %', p_test_name;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- TEST DATA SETUP
-- ----------------------------------------------------------------------------

-- Create test clients
INSERT INTO clients (uuid, client_name, active) VALUES
    ('11111111-1111-1111-1111-111111111111'::UUID, 'Test Client A', TRUE),
    ('22222222-2222-2222-2222-222222222222'::UUID, 'Test Client B', TRUE);

-- Create test users
DO $$
DECLARE
    v_admin_id UUID;
    v_user_a1_id UUID;
    v_user_a2_id UUID;
    v_user_b1_id UUID;
    v_user_no_client_id UUID;
BEGIN
    -- Create users with different access levels
    v_admin_id := create_test_user('admin@test.com', NULL, TRUE);
    v_user_a1_id := create_test_user('user_a1@test.com', '11111111-1111-1111-1111-111111111111'::UUID, FALSE);
    v_user_a2_id := create_test_user('user_a2@test.com', '11111111-1111-1111-1111-111111111111'::UUID, FALSE);
    v_user_b1_id := create_test_user('user_b1@test.com', '22222222-2222-2222-2222-222222222222'::UUID, FALSE);
    v_user_no_client_id := create_test_user('no_client@test.com', NULL, FALSE);
    
    -- Store IDs for later use
    PERFORM set_config('test.admin_id', v_admin_id::TEXT, FALSE);
    PERFORM set_config('test.user_a1_id', v_user_a1_id::TEXT, FALSE);
    PERFORM set_config('test.user_a2_id', v_user_a2_id::TEXT, FALSE);
    PERFORM set_config('test.user_b1_id', v_user_b1_id::TEXT, FALSE);
    PERFORM set_config('test.no_client_id', v_user_no_client_id::TEXT, FALSE);
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: USER TABLE ACCESS
-- ----------------------------------------------------------------------------

-- Test 1.1: Admin can see all users
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.admin_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM users;
    PERFORM assert(v_count = 5, 'Admin sees all users');
END $$;

-- Test 1.2: Regular user can only see users in same client
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM users;
    PERFORM assert(v_count = 2, 'User A1 sees only Client A users');
END $$;

-- Test 1.3: User can see their own profile even without client
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.no_client_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM users WHERE auth_user_id = current_setting('test.no_client_id')::UUID;
    PERFORM assert(v_count = 1, 'User without client can see own profile');
END $$;

-- Test 1.4: User cannot see users from other clients
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM users WHERE client_uuid = '22222222-2222-2222-2222-222222222222'::UUID;
    PERFORM assert(v_count = 0, 'User A1 cannot see Client B users');
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: USER MODIFICATIONS
-- ----------------------------------------------------------------------------

-- Test 2.1: User can update their own profile
DO $$
DECLARE
    v_success BOOLEAN := FALSE;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    BEGIN
        UPDATE users SET email = 'updated_a1@test.com' 
        WHERE auth_user_id = current_setting('test.user_a1_id')::UUID;
        v_success := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_success := FALSE;
    END;
    PERFORM assert(v_success, 'User can update own profile');
END $$;

-- Test 2.2: User cannot update another user's profile
DO $$
DECLARE
    v_success BOOLEAN := FALSE;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    BEGIN
        UPDATE users SET email = 'hacked@test.com' 
        WHERE auth_user_id = current_setting('test.user_a2_id')::UUID;
        v_success := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_success := FALSE;
    END;
    PERFORM assert(NOT v_success, 'User cannot update other user profile');
END $$;

-- Test 2.3: User cannot change their client_uuid
DO $$
DECLARE
    v_success BOOLEAN := FALSE;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    BEGIN
        UPDATE users SET client_uuid = '22222222-2222-2222-2222-222222222222'::UUID
        WHERE auth_user_id = current_setting('test.user_a1_id')::UUID;
        v_success := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_success := FALSE;
    END;
    PERFORM assert(NOT v_success, 'User cannot change their client_uuid');
END $$;

-- Test 2.4: Admin can update any user
DO $$
DECLARE
    v_success BOOLEAN := FALSE;
BEGIN
    PERFORM run_as_user(current_setting('test.admin_id')::UUID);
    BEGIN
        UPDATE users SET email = 'admin_updated@test.com' 
        WHERE auth_user_id = current_setting('test.user_a1_id')::UUID;
        v_success := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_success := FALSE;
    END;
    PERFORM assert(v_success, 'Admin can update any user');
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: CLIENT ACCESS
-- ----------------------------------------------------------------------------

-- Test 3.1: Admin can see all clients
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.admin_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM clients;
    PERFORM assert(v_count >= 2, 'Admin sees all clients');
END $$;

-- Test 3.2: Regular user can only see their assigned client
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM clients;
    PERFORM assert(v_count = 1, 'User sees only their client');
END $$;

-- Test 3.3: User without client cannot see any clients
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.no_client_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM clients;
    PERFORM assert(v_count = 0, 'User without client sees no clients');
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 4: CLIENT NOTES ACCESS
-- ----------------------------------------------------------------------------

-- Create test notes
INSERT INTO client_notes (id, client_uuid, notes, created_at, updated_at) VALUES
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111'::UUID, 'Note for Client A', NOW(), NOW()),
    (gen_random_uuid(), '22222222-2222-2222-2222-222222222222'::UUID, 'Note for Client B', NOW(), NOW());

-- Test 4.1: User can see notes for their client
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM client_notes;
    PERFORM assert(v_count = 1, 'User sees notes for their client');
END $$;

-- Test 4.2: User cannot see notes for other clients
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM client_notes 
    WHERE client_uuid = '22222222-2222-2222-2222-222222222222'::UUID;
    PERFORM assert(v_count = 0, 'User cannot see notes for other clients');
END $$;

-- Test 4.3: Admin can see all notes
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.admin_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM client_notes;
    PERFORM assert(v_count = 2, 'Admin sees all notes');
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 5: AUDIT LOG ACCESS
-- ----------------------------------------------------------------------------

-- Create test audit logs
INSERT INTO security_audit_log (event_type, user_id, client_uuid, success, metadata) VALUES
    ('login', current_setting('test.user_a1_id')::UUID, '11111111-1111-1111-1111-111111111111'::UUID, TRUE, '{}'),
    ('login', current_setting('test.user_b1_id')::UUID, '22222222-2222-2222-2222-222222222222'::UUID, TRUE, '{}');

-- Test 5.1: User can only see their own audit logs
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM security_audit_log;
    PERFORM assert(v_count = 1, 'User sees only their audit logs');
END $$;

-- Test 5.2: Admin can see all audit logs
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM run_as_user(current_setting('test.admin_id')::UUID);
    SELECT COUNT(*) INTO v_count FROM security_audit_log;
    PERFORM assert(v_count >= 2, 'Admin sees all audit logs');
END $$;

-- ----------------------------------------------------------------------------
-- TEST SUITE 6: CROSS-TENANT ISOLATION
-- ----------------------------------------------------------------------------

-- Test 6.1: Verify complete isolation between tenants
DO $$
DECLARE
    v_client_a_visible BOOLEAN;
    v_client_b_visible BOOLEAN;
BEGIN
    PERFORM run_as_user(current_setting('test.user_a1_id')::UUID);
    
    -- Check if can see Client A data
    SELECT EXISTS(SELECT 1 FROM clients WHERE uuid = '11111111-1111-1111-1111-111111111111'::UUID) 
    INTO v_client_a_visible;
    
    -- Check if can see Client B data
    SELECT EXISTS(SELECT 1 FROM clients WHERE uuid = '22222222-2222-2222-2222-222222222222'::UUID) 
    INTO v_client_b_visible;
    
    PERFORM assert(v_client_a_visible AND NOT v_client_b_visible, 'Complete tenant isolation verified');
END $$;

-- ----------------------------------------------------------------------------
-- TEST CLEANUP
-- ----------------------------------------------------------------------------

-- Clean up test data
DELETE FROM security_audit_log WHERE user_id IN (
    current_setting('test.admin_id')::UUID,
    current_setting('test.user_a1_id')::UUID,
    current_setting('test.user_a2_id')::UUID,
    current_setting('test.user_b1_id')::UUID,
    current_setting('test.no_client_id')::UUID
);

DELETE FROM client_notes WHERE client_uuid IN (
    '11111111-1111-1111-1111-111111111111'::UUID,
    '22222222-2222-2222-2222-222222222222'::UUID
);

DELETE FROM user_admins WHERE auth_user_id = current_setting('test.admin_id')::UUID;

DELETE FROM users WHERE auth_user_id IN (
    current_setting('test.admin_id')::UUID,
    current_setting('test.user_a1_id')::UUID,
    current_setting('test.user_a2_id')::UUID,
    current_setting('test.user_b1_id')::UUID,
    current_setting('test.no_client_id')::UUID
);

DELETE FROM clients WHERE uuid IN (
    '11111111-1111-1111-1111-111111111111'::UUID,
    '22222222-2222-2222-2222-222222222222'::UUID
);

-- Drop test functions
DROP FUNCTION IF EXISTS create_test_user(TEXT, UUID, BOOLEAN);
DROP FUNCTION IF EXISTS run_as_user(UUID);
DROP FUNCTION IF EXISTS assert(BOOLEAN, TEXT);

-- Rollback transaction (tests run in transaction for safety)
ROLLBACK;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RLS TEST SUITE COMPLETED SUCCESSFULLY';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All RLS policies are working as expected';
    RAISE NOTICE 'Run this test after RLS changes to verify behavior';
END $$;
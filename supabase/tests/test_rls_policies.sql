-- ============================================================================
-- RLS Policy Test Suite
-- Purpose: Comprehensive tests for cross-tenant protection
-- ============================================================================

-- Clean up any existing test data
DELETE FROM stakeholder_notes WHERE created_by IN (
  SELECT id FROM users WHERE email LIKE 'test_%@example.com'
);
DELETE FROM stakeholder_contacts WHERE created_by IN (
  SELECT id FROM users WHERE email LIKE 'test_%@example.com'
);
DELETE FROM client_org_history WHERE client_uuid IN (
  SELECT uuid FROM clients WHERE name LIKE 'Test Client %'
);
DELETE FROM users WHERE email LIKE 'test_%@example.com';
DELETE FROM clients WHERE name LIKE 'Test Client %';

-- ============================================================================
-- SETUP TEST DATA
-- ============================================================================

-- Create test clients
INSERT INTO clients (uuid, name, active) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Test Client 1', true),
  ('22222222-2222-2222-2222-222222222222', 'Test Client 2', true);

-- Create test users for each client
INSERT INTO users (id, email, client_uuid, first_name, last_name, active) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'test_user1@example.com', 
   '11111111-1111-1111-1111-111111111111', 'User', 'One', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'test_user2@example.com', 
   '22222222-2222-2222-2222-222222222222', 'User', 'Two', true);

-- Create test organizations
INSERT INTO organizations (id, name, type) VALUES
  ('org11111-1111-1111-1111-111111111111', 'Test Org 1', 'corporate'),
  ('org22222-2222-2222-2222-222222222222', 'Test Org 2', 'government');

-- ============================================================================
-- TEST 1: INSERT POLICY - Users cannot insert data for other clients
-- ============================================================================
DO $$
DECLARE
  v_result BOOLEAN;
  v_error TEXT;
BEGIN
  RAISE NOTICE 'TEST 1: INSERT Policy - Cross-tenant prevention';
  
  -- Set session as User 1 (Client 1)
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  
  BEGIN
    -- Try to insert data for Client 2 (should fail)
    INSERT INTO client_org_history (client_uuid, organization_id)
    VALUES ('22222222-2222-2222-2222-222222222222', 'org11111-1111-1111-1111-111111111111');
    
    RAISE NOTICE '  FAILED: User 1 was able to insert data for Client 2';
    v_result := false;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  PASSED: Insert blocked with error: %', SQLERRM;
    v_result := true;
  END;
  
  -- Now try to insert for own client (should succeed)
  BEGIN
    INSERT INTO client_org_history (client_uuid, organization_id)
    VALUES ('11111111-1111-1111-1111-111111111111', 'org11111-1111-1111-1111-111111111111');
    
    RAISE NOTICE '  PASSED: User 1 can insert data for their own client';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  FAILED: User 1 cannot insert for own client: %', SQLERRM;
  END;
END $$;

-- ============================================================================
-- TEST 2: UPDATE POLICY - Users cannot change client_uuid
-- ============================================================================
DO $$
DECLARE
  v_test_id UUID;
BEGIN
  RAISE NOTICE 'TEST 2: UPDATE Policy - Prevent client_uuid changes';
  
  -- Set session as User 1
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  
  -- Insert a record for Client 1
  INSERT INTO client_org_history (id, client_uuid, organization_id)
  VALUES (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'org11111-1111-1111-1111-111111111111')
  RETURNING id INTO v_test_id;
  
  BEGIN
    -- Try to change client_uuid to Client 2 (should fail)
    UPDATE client_org_history 
    SET client_uuid = '22222222-2222-2222-2222-222222222222'
    WHERE id = v_test_id;
    
    RAISE NOTICE '  FAILED: User was able to change client_uuid';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  PASSED: client_uuid change blocked: %', SQLERRM;
  END;
  
  -- Try to update other fields (should succeed)
  BEGIN
    UPDATE client_org_history 
    SET updated_at = NOW()
    WHERE id = v_test_id;
    
    RAISE NOTICE '  PASSED: User can update other fields';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  FAILED: User cannot update own records: %', SQLERRM;
  END;
END $$;

-- ============================================================================
-- TEST 3: DELETE POLICY - Users cannot delete other client's data
-- ============================================================================
DO $$
DECLARE
  v_count_before INTEGER;
  v_count_after INTEGER;
BEGIN
  RAISE NOTICE 'TEST 3: DELETE Policy - Cross-tenant prevention';
  
  -- Create data for Client 2
  PERFORM set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
  INSERT INTO client_org_history (client_uuid, organization_id)
  VALUES ('22222222-2222-2222-2222-222222222222', 'org22222-2222-2222-2222-222222222222');
  
  SELECT COUNT(*) INTO v_count_before 
  FROM client_org_history 
  WHERE client_uuid = '22222222-2222-2222-2222-222222222222';
  
  -- Switch to User 1 and try to delete Client 2's data
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  
  DELETE FROM client_org_history
  WHERE client_uuid = '22222222-2222-2222-2222-222222222222';
  
  SELECT COUNT(*) INTO v_count_after 
  FROM client_org_history 
  WHERE client_uuid = '22222222-2222-2222-2222-222222222222';
  
  IF v_count_before = v_count_after THEN
    RAISE NOTICE '  PASSED: User 1 cannot delete Client 2 data';
  ELSE
    RAISE NOTICE '  FAILED: User 1 was able to delete Client 2 data';
  END IF;
END $$;

-- ============================================================================
-- TEST 4: SELECT POLICY - Users cannot see other client's data
-- ============================================================================
DO $$
DECLARE
  v_visible_count INTEGER;
BEGIN
  RAISE NOTICE 'TEST 4: SELECT Policy - Data isolation';
  
  -- As User 1, try to see Client 2's data
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  
  SELECT COUNT(*) INTO v_visible_count
  FROM client_org_history
  WHERE client_uuid = '22222222-2222-2222-2222-222222222222';
  
  IF v_visible_count = 0 THEN
    RAISE NOTICE '  PASSED: User 1 cannot see Client 2 data';
  ELSE
    RAISE NOTICE '  FAILED: User 1 can see % records from Client 2', v_visible_count;
  END IF;
  
  -- Check that User 1 can see their own data
  SELECT COUNT(*) INTO v_visible_count
  FROM client_org_history
  WHERE client_uuid = '11111111-1111-1111-1111-111111111111';
  
  IF v_visible_count > 0 THEN
    RAISE NOTICE '  PASSED: User 1 can see their own data (% records)', v_visible_count;
  ELSE
    RAISE NOTICE '  WARNING: User 1 cannot see their own data';
  END IF;
END $$;

-- ============================================================================
-- TEST 5: AUTO-POPULATE CLIENT_UUID
-- ============================================================================
DO $$
DECLARE
  v_inserted_client UUID;
  v_test_id UUID;
BEGIN
  RAISE NOTICE 'TEST 5: Auto-populate client_uuid on INSERT';
  
  -- Set session as User 1
  PERFORM set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
  
  -- Insert without specifying client_uuid
  INSERT INTO stakeholder_contacts (first_name, last_name, email)
  VALUES ('Auto', 'Test', 'auto@test.com')
  RETURNING id, client_uuid INTO v_test_id, v_inserted_client;
  
  IF v_inserted_client = '11111111-1111-1111-1111-111111111111' THEN
    RAISE NOTICE '  PASSED: client_uuid auto-populated correctly';
  ELSE
    RAISE NOTICE '  FAILED: client_uuid not populated or wrong value: %', v_inserted_client;
  END IF;
  
  -- Clean up
  DELETE FROM stakeholder_contacts WHERE id = v_test_id;
END $$;

-- ============================================================================
-- TEST 6: SOFT DELETE FUNCTIONALITY
-- ============================================================================
DO $$
DECLARE
  v_test_id UUID;
  v_deleted_at TIMESTAMP;
  v_visible_count INTEGER;
BEGIN
  RAISE NOTICE 'TEST 6: Soft delete functionality';
  
  -- Create a test record
  INSERT INTO stakeholder_contacts (id, client_uuid, first_name, last_name)
  VALUES (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'Soft', 'Delete')
  RETURNING id INTO v_test_id;
  
  -- Soft delete it
  UPDATE stakeholder_contacts 
  SET deleted_at = NOW()
  WHERE id = v_test_id
  RETURNING deleted_at INTO v_deleted_at;
  
  IF v_deleted_at IS NOT NULL THEN
    RAISE NOTICE '  PASSED: Record soft deleted (deleted_at set)';
  ELSE
    RAISE NOTICE '  FAILED: Soft delete did not set deleted_at';
  END IF;
  
  -- Check if soft deleted records are hidden from normal queries
  SELECT COUNT(*) INTO v_visible_count
  FROM stakeholder_contacts
  WHERE id = v_test_id;
  
  IF v_visible_count = 0 THEN
    RAISE NOTICE '  PASSED: Soft deleted records hidden from queries';
  ELSE
    RAISE NOTICE '  FAILED: Soft deleted records still visible';
  END IF;
END $$;

-- ============================================================================
-- TEST 7: ADMIN BYPASS
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE 'TEST 7: Admin bypass for all operations';
  
  -- Create an admin user
  INSERT INTO user_admins (email, auth_user_id, active)
  VALUES ('admin@test.com', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
  
  -- Set session as admin
  PERFORM set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
  
  BEGIN
    -- Admin should be able to insert for any client
    INSERT INTO client_org_history (client_uuid, organization_id)
    VALUES ('22222222-2222-2222-2222-222222222222', 'org11111-1111-1111-1111-111111111111');
    
    RAISE NOTICE '  PASSED: Admin can insert for any client';
    
    -- Admin should be able to update any client's data
    UPDATE client_org_history 
    SET updated_at = NOW()
    WHERE client_uuid = '11111111-1111-1111-1111-111111111111';
    
    RAISE NOTICE '  PASSED: Admin can update any client data';
    
    -- Admin should be able to see all data
    IF (SELECT COUNT(*) FROM clients) > 0 THEN
      RAISE NOTICE '  PASSED: Admin can see all clients';
    END IF;
    
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  FAILED: Admin operations blocked: %', SQLERRM;
  END;
  
  -- Clean up admin
  DELETE FROM user_admins WHERE email = 'admin@test.com';
END $$;

-- ============================================================================
-- TEST 8: BULK OPERATION PERFORMANCE
-- ============================================================================
DO $$
DECLARE
  v_start_time TIMESTAMP;
  v_end_time TIMESTAMP;
  v_duration INTERVAL;
  i INTEGER;
BEGIN
  RAISE NOTICE 'TEST 8: Bulk operation performance';
  
  v_start_time := clock_timestamp();
  
  -- Insert 100 records
  FOR i IN 1..100 LOOP
    INSERT INTO stakeholder_contacts (client_uuid, first_name, last_name, email)
    VALUES ('11111111-1111-1111-1111-111111111111', 
            'Bulk', 'Test' || i, 'bulk' || i || '@test.com');
  END LOOP;
  
  v_end_time := clock_timestamp();
  v_duration := v_end_time - v_start_time;
  
  RAISE NOTICE '  Bulk insert of 100 records: %', v_duration;
  
  -- Clean up bulk test data
  DELETE FROM stakeholder_contacts WHERE first_name = 'Bulk';
  
  IF v_duration < INTERVAL '5 seconds' THEN
    RAISE NOTICE '  PASSED: Bulk operations perform acceptably';
  ELSE
    RAISE NOTICE '  WARNING: Bulk operations may be slow';
  END IF;
END $$;

-- ============================================================================
-- CLEANUP TEST DATA
-- ============================================================================
DELETE FROM stakeholder_notes WHERE created_by IN (
  SELECT id FROM users WHERE email LIKE 'test_%@example.com'
);
DELETE FROM stakeholder_contacts WHERE client_uuid IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);
DELETE FROM client_org_history WHERE client_uuid IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);
DELETE FROM users WHERE email LIKE 'test_%@example.com';
DELETE FROM organizations WHERE name LIKE 'Test Org %';
DELETE FROM clients WHERE name LIKE 'Test Client %';

-- ============================================================================
-- SUMMARY
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'RLS POLICY TEST SUITE COMPLETED';
  RAISE NOTICE 'All critical security tests have been executed';
  RAISE NOTICE 'Review the output above for any FAILED tests';
  RAISE NOTICE '==================================================';
END $$;
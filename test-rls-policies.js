#!/usr/bin/env node

/**
 * RLS Policy Test Suite
 * Tests comprehensive cross-tenant protection
 */

const { createClient } = require('@supabase/supabase-js');
const { config } = require('dotenv');

// Load environment variables
config();

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'your-anon-key';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-service-key';

// Test users
const TEST_USERS = {
  client1: {
    email: 'test.user1@client1.com',
    password: 'TestPassword123!',
    clientUuid: '11111111-1111-1111-1111-111111111111',
    clientName: 'Test Client 1'
  },
  client2: {
    email: 'test.user2@client2.com', 
    password: 'TestPassword123!',
    clientUuid: '22222222-2222-2222-2222-222222222222',
    clientName: 'Test Client 2'
  },
  admin: {
    email: 'admin@test.com',
    password: 'AdminPassword123!'
  }
};

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  bold: '\x1b[1m'
};

// Test result tracking
let passedTests = 0;
let failedTests = 0;

/**
 * Log test result
 */
function logTest(testName, passed, message = '') {
  if (passed) {
    console.log(`${colors.green}✓${colors.reset} ${testName}`);
    if (message) console.log(`  ${colors.green}${message}${colors.reset}`);
    passedTests++;
  } else {
    console.log(`${colors.red}✗${colors.reset} ${testName}`);
    if (message) console.log(`  ${colors.red}${message}${colors.reset}`);
    failedTests++;
  }
}

/**
 * Setup test data using service role key
 */
async function setupTestData() {
  console.log(`\n${colors.blue}${colors.bold}Setting up test data...${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  
  try {
    // Create test clients
    const { data: client1, error: c1Error } = await supabase
      .from('clients')
      .upsert({
        uuid: TEST_USERS.client1.clientUuid,
        name: TEST_USERS.client1.clientName,
        active: true
      })
      .select()
      .single();
      
    if (c1Error) throw c1Error;
    
    const { data: client2, error: c2Error } = await supabase
      .from('clients')
      .upsert({
        uuid: TEST_USERS.client2.clientUuid,
        name: TEST_USERS.client2.clientName,
        active: true
      })
      .select()
      .single();
      
    if (c2Error) throw c2Error;
    
    // Create test users
    const { data: user1Auth, error: u1AuthError } = await supabase.auth.admin.createUser({
      email: TEST_USERS.client1.email,
      password: TEST_USERS.client1.password,
      email_confirm: true
    });
    
    if (u1AuthError && !u1AuthError.message.includes('already been registered')) {
      throw u1AuthError;
    }
    
    const { data: user2Auth, error: u2AuthError } = await supabase.auth.admin.createUser({
      email: TEST_USERS.client2.email,
      password: TEST_USERS.client2.password,
      email_confirm: true
    });
    
    if (u2AuthError && !u2AuthError.message.includes('already been registered')) {
      throw u2AuthError;
    }
    
    // Link users to clients in users table
    if (user1Auth) {
      await supabase.from('users').upsert({
        id: user1Auth.user.id,
        email: TEST_USERS.client1.email,
        client_uuid: TEST_USERS.client1.clientUuid,
        first_name: 'Test',
        last_name: 'User1',
        active: true
      });
    }
    
    if (user2Auth) {
      await supabase.from('users').upsert({
        id: user2Auth.user.id,
        email: TEST_USERS.client2.email,
        client_uuid: TEST_USERS.client2.clientUuid,
        first_name: 'Test',
        last_name: 'User2',
        active: true
      });
    }
    
    // Create test organizations
    await supabase.from('organizations').upsert([
      { id: 'org11111-1111-1111-1111-111111111111', name: 'Test Org 1', type: 'corporate' },
      { id: 'org22222-2222-2222-2222-222222222222', name: 'Test Org 2', type: 'government' }
    ]);
    
    console.log(`${colors.green}Test data setup complete${colors.reset}\n`);
    return true;
    
  } catch (error) {
    console.error(`${colors.red}Failed to setup test data:`, error.message, colors.reset);
    return false;
  }
}

/**
 * Test 1: Cross-tenant INSERT prevention
 */
async function testCrossTenantInsert() {
  console.log(`\n${colors.bold}TEST 1: Cross-tenant INSERT Prevention${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Login as User 1
  const { data: session, error: loginError } = await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  if (loginError) {
    logTest('Login as User 1', false, loginError.message);
    return;
  }
  
  logTest('Login as User 1', true);
  
  // Try to insert data for Client 2 (should fail)
  const { error: crossInsertError } = await supabase
    .from('client_org_history')
    .insert({
      client_uuid: TEST_USERS.client2.clientUuid,
      organization_id: 'org11111-1111-1111-1111-111111111111'
    });
    
  logTest(
    'Prevent insert for different client',
    crossInsertError !== null,
    crossInsertError ? `Blocked: ${crossInsertError.message}` : 'Failed: Insert was allowed'
  );
  
  // Try to insert for own client (should succeed)
  const { data: ownInsert, error: ownInsertError } = await supabase
    .from('client_org_history')
    .insert({
      client_uuid: TEST_USERS.client1.clientUuid,
      organization_id: 'org11111-1111-1111-1111-111111111111'
    })
    .select();
    
  logTest(
    'Allow insert for own client',
    !ownInsertError && ownInsert?.length > 0,
    ownInsertError ? `Failed: ${ownInsertError.message}` : 'Success'
  );
  
  await supabase.auth.signOut();
}

/**
 * Test 2: Cross-tenant UPDATE prevention
 */
async function testCrossTenantUpdate() {
  console.log(`\n${colors.bold}TEST 2: Cross-tenant UPDATE Prevention${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Login as User 1
  const { error: loginError } = await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  if (loginError) {
    logTest('Login for update test', false, loginError.message);
    return;
  }
  
  // Get a record to update
  const { data: records } = await supabase
    .from('client_org_history')
    .select()
    .limit(1);
    
  if (records && records.length > 0) {
    // Try to change client_uuid (should fail)
    const { error: changeClientError } = await supabase
      .from('client_org_history')
      .update({ client_uuid: TEST_USERS.client2.clientUuid })
      .eq('id', records[0].id);
      
    logTest(
      'Prevent client_uuid change',
      changeClientError !== null,
      changeClientError ? `Blocked: ${changeClientError.message}` : 'Failed: Change was allowed'
    );
    
    // Update other fields (should succeed)
    const { error: updateError } = await supabase
      .from('client_org_history')
      .update({ notes: 'Updated note' })
      .eq('id', records[0].id);
      
    logTest(
      'Allow updating other fields',
      !updateError,
      updateError ? `Failed: ${updateError.message}` : 'Success'
    );
  }
  
  await supabase.auth.signOut();
}

/**
 * Test 3: Cross-tenant DELETE prevention
 */
async function testCrossTenantDelete() {
  console.log(`\n${colors.bold}TEST 3: Cross-tenant DELETE Prevention${colors.reset}`);
  
  const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Create data for Client 2 using service role
  const { data: client2Data } = await serviceSupabase
    .from('client_org_history')
    .insert({
      client_uuid: TEST_USERS.client2.clientUuid,
      organization_id: 'org22222-2222-2222-2222-222222222222'
    })
    .select()
    .single();
    
  // Login as User 1
  await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  if (client2Data) {
    // Try to delete Client 2's data (should fail)
    const { error: deleteError, count } = await supabase
      .from('client_org_history')
      .delete()
      .eq('id', client2Data.id);
      
    logTest(
      'Prevent deleting other client data',
      deleteError !== null || count === 0,
      deleteError ? `Blocked: ${deleteError.message}` : 'No rows deleted'
    );
  }
  
  await supabase.auth.signOut();
}

/**
 * Test 4: Data isolation (SELECT)
 */
async function testDataIsolation() {
  console.log(`\n${colors.bold}TEST 4: Data Isolation (SELECT)${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Login as User 1
  await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  // Try to see Client 2's data
  const { data: client2Data } = await supabase
    .from('client_org_history')
    .select()
    .eq('client_uuid', TEST_USERS.client2.clientUuid);
    
  logTest(
    'Cannot see other client data',
    !client2Data || client2Data.length === 0,
    client2Data?.length > 0 ? `Failed: Can see ${client2Data.length} records` : 'Success: No data visible'
  );
  
  // Check own data is visible
  const { data: ownData } = await supabase
    .from('client_org_history')
    .select()
    .eq('client_uuid', TEST_USERS.client1.clientUuid);
    
  logTest(
    'Can see own client data',
    ownData && ownData.length > 0,
    ownData?.length > 0 ? `Success: ${ownData.length} records visible` : 'Warning: No own data found'
  );
  
  await supabase.auth.signOut();
}

/**
 * Test 5: Auto-populate client_uuid
 */
async function testAutoPopulate() {
  console.log(`\n${colors.bold}TEST 5: Auto-populate client_uuid${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Login as User 1
  await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  // Insert without specifying client_uuid
  const { data: autoData, error } = await supabase
    .from('stakeholder_contacts')
    .insert({
      first_name: 'Auto',
      last_name: 'Test',
      email: 'auto@test.com'
    })
    .select()
    .single();
    
  logTest(
    'Auto-populate client_uuid on insert',
    !error && autoData?.client_uuid === TEST_USERS.client1.clientUuid,
    autoData?.client_uuid === TEST_USERS.client1.clientUuid 
      ? 'Success: client_uuid auto-populated' 
      : `Failed: ${error?.message || 'Wrong client_uuid'}`
  );
  
  await supabase.auth.signOut();
}

/**
 * Test 6: Soft delete functionality
 */
async function testSoftDelete() {
  console.log(`\n${colors.bold}TEST 6: Soft Delete Functionality${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Login as User 1
  await supabase.auth.signInWithPassword({
    email: TEST_USERS.client1.email,
    password: TEST_USERS.client1.password
  });
  
  // Create a test record
  const { data: testRecord } = await supabase
    .from('stakeholder_contacts')
    .insert({
      first_name: 'Delete',
      last_name: 'Test',
      email: 'delete@test.com'
    })
    .select()
    .single();
    
  if (testRecord) {
    // Soft delete it
    const { data: updated } = await supabase
      .from('stakeholder_contacts')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', testRecord.id)
      .select()
      .single();
      
    logTest(
      'Soft delete sets deleted_at',
      updated?.deleted_at !== null,
      updated?.deleted_at ? 'Success: deleted_at timestamp set' : 'Failed: deleted_at not set'
    );
    
    // Check if hidden from normal queries
    const { data: searchResult } = await supabase
      .from('stakeholder_contacts')
      .select()
      .eq('id', testRecord.id);
      
    logTest(
      'Soft deleted records hidden',
      !searchResult || searchResult.length === 0,
      searchResult?.length === 0 ? 'Success: Record hidden' : 'Failed: Record still visible'
    );
  }
  
  await supabase.auth.signOut();
}

/**
 * Cleanup test data
 */
async function cleanupTestData() {
  console.log(`\n${colors.yellow}Cleaning up test data...${colors.reset}`);
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  
  try {
    // Delete test data in reverse order of dependencies
    await supabase.from('stakeholder_notes').delete().in('client_uuid', [
      TEST_USERS.client1.clientUuid,
      TEST_USERS.client2.clientUuid
    ]);
    
    await supabase.from('stakeholder_contacts').delete().in('client_uuid', [
      TEST_USERS.client1.clientUuid,
      TEST_USERS.client2.clientUuid
    ]);
    
    await supabase.from('client_org_history').delete().in('client_uuid', [
      TEST_USERS.client1.clientUuid,
      TEST_USERS.client2.clientUuid
    ]);
    
    await supabase.from('users').delete().in('email', [
      TEST_USERS.client1.email,
      TEST_USERS.client2.email
    ]);
    
    await supabase.from('clients').delete().in('uuid', [
      TEST_USERS.client1.clientUuid,
      TEST_USERS.client2.clientUuid
    ]);
    
    await supabase.from('organizations').delete().in('name', [
      'Test Org 1',
      'Test Org 2'
    ]);
    
    // Delete auth users
    const { data: users } = await supabase.auth.admin.listUsers();
    for (const user of users?.users || []) {
      if ([TEST_USERS.client1.email, TEST_USERS.client2.email].includes(user.email)) {
        await supabase.auth.admin.deleteUser(user.id);
      }
    }
    
    console.log(`${colors.green}Cleanup complete${colors.reset}`);
    
  } catch (error) {
    console.error(`${colors.red}Cleanup failed:`, error.message, colors.reset);
  }
}

/**
 * Main test runner
 */
async function runTests() {
  console.log(`${colors.bold}${colors.blue}
╔══════════════════════════════════════════╗
║     RLS Policy Comprehensive Test Suite   ║
╚══════════════════════════════════════════╝
${colors.reset}`);
  
  // Check configuration
  if (!SUPABASE_SERVICE_KEY || SUPABASE_SERVICE_KEY === 'your-service-key') {
    console.error(`${colors.red}ERROR: Please set SUPABASE_SERVICE_ROLE_KEY in your .env file${colors.reset}`);
    console.log('\nYou can find your keys at: http://localhost:54323/project/default/settings/api\n');
    process.exit(1);
  }
  
  // Setup test data
  const setupSuccess = await setupTestData();
  if (!setupSuccess) {
    console.error(`${colors.red}Failed to setup test data. Exiting...${colors.reset}`);
    process.exit(1);
  }
  
  // Run tests
  await testCrossTenantInsert();
  await testCrossTenantUpdate();
  await testCrossTenantDelete();
  await testDataIsolation();
  await testAutoPopulate();
  await testSoftDelete();
  
  // Summary
  console.log(`\n${colors.bold}${colors.blue}
╔══════════════════════════════════════════╗
║              TEST SUMMARY                 ║
╚══════════════════════════════════════════╝${colors.reset}`);
  
  console.log(`
  ${colors.green}Passed: ${passedTests}${colors.reset}
  ${colors.red}Failed: ${failedTests}${colors.reset}
  ${colors.blue}Total:  ${passedTests + failedTests}${colors.reset}
  `);
  
  if (failedTests === 0) {
    console.log(`${colors.green}${colors.bold}✓ All tests passed! RLS policies are working correctly.${colors.reset}\n`);
  } else {
    console.log(`${colors.red}${colors.bold}✗ Some tests failed. Review RLS policies.${colors.reset}\n`);
  }
  
  // Cleanup
  await cleanupTestData();
  
  process.exit(failedTests > 0 ? 1 : 0);
}

// Run tests
runTests().catch(console.error);
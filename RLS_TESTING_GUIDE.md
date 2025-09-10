# RLS Policy Testing Guide

## Overview
This guide explains how to test the comprehensive Row Level Security (RLS) policies that protect your multi-tenant data.

## Quick Start

### Option 1: Automated Testing (Recommended)
```bash
# Run the automated test suite
./run-rls-tests.sh
```

This script will:
1. Start Supabase if not running
2. Apply all migrations
3. Run comprehensive tests
4. Report results

### Option 2: Manual SQL Testing
```bash
# Start Supabase
npx supabase start

# Reset database with migrations
npx supabase db reset

# Run SQL test suite
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f supabase/tests/test_rls_policies.sql
```

### Option 3: JavaScript Integration Testing
```bash
# Install dependencies
npm install @supabase/supabase-js dotenv

# Set up environment variables
cp .env.example .env.test
# Edit .env.test with your Supabase keys from http://localhost:54323

# Run JavaScript tests
node test-rls-policies.js
```

## What Gets Tested

### 1. **INSERT Protection** ✅
- Users cannot insert data for other tenants
- Client UUID validation on insert
- Auto-population of client_uuid for user's tenant

### 2. **UPDATE Protection** ✅
- Users cannot change client_uuid to another tenant
- Users can only update their own tenant's data
- Special case: users can update their own profile

### 3. **DELETE Protection** ✅
- Users cannot delete other tenant's data
- Soft delete implementation (deleted_at timestamp)
- Audit trail maintained

### 4. **SELECT Isolation** ✅
- Users only see their own tenant's data
- Complete data isolation between tenants
- Soft-deleted records are hidden

### 5. **Admin Bypass** ✅
- Admins can access all tenant data
- Admins verified via secure auth.uid()
- Admin actions are logged

### 6. **Performance** ✅
- Bulk operations tested
- Proper indexes in place
- Query performance monitored

## Test Files Created

```
/workspaces/externalView/
├── run-rls-tests.sh                    # Automated test runner
├── test-rls-policies.js                # JavaScript integration tests
├── supabase/
│   ├── migrations/
│   │   ├── 20250910000000_create_base_tables.sql
│   │   ├── 20250910000001_create_user_admins_table.sql
│   │   ├── 20250910000002_add_active_column_to_users.sql
│   │   ├── 20250910000003_fix_jwt_vulnerability_fixed.sql
│   │   └── 20250910000004_comprehensive_rls_policies.sql
│   └── tests/
│       └── test_rls_policies.sql       # SQL test suite
└── RLS_TESTING_GUIDE.md               # This file
```

## Expected Test Results

When all tests pass, you should see:

```
✓ Prevent insert for different client
✓ Allow insert for own client
✓ Prevent client_uuid change
✓ Allow updating other fields
✓ Prevent deleting other client data
✓ Cannot see other client data
✓ Can see own client data
✓ Auto-populate client_uuid on insert
✓ Soft delete sets deleted_at
✓ Soft deleted records hidden

TEST SUMMARY
============
Passed: 10
Failed: 0
Total:  10

✓ All tests passed! RLS policies are working correctly.
```

## Manual Verification via Supabase Studio

1. **Open Supabase Studio**
   ```bash
   npx supabase studio
   ```
   Opens at: http://localhost:54323

2. **Create Test Users**
   - Go to Authentication → Users
   - Create users for different clients
   - Note their UUIDs

3. **Test Cross-Tenant Access**
   - Use SQL Editor with different user contexts
   - Try INSERT/UPDATE/DELETE across tenants
   - Verify all operations are blocked

## Troubleshooting

### Issue: Supabase won't start
```bash
# Stop all containers
npx supabase stop --project-id externalView

# Start fresh
npx supabase start
```

### Issue: Migrations fail
```bash
# Check migration order
ls -la supabase/migrations/

# Apply manually if needed
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f supabase/migrations/[migration_file].sql
```

### Issue: Tests fail with auth errors
- Check your Supabase keys in `.env.test`
- Get fresh keys from: http://localhost:54323/project/default/settings/api

### Issue: Policies not working
```sql
-- Check installed policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';
```

## Security Checklist

- [ ] All tables have RLS enabled
- [ ] INSERT policies validate client_uuid
- [ ] UPDATE policies prevent tenant changes
- [ ] DELETE policies respect tenant boundaries
- [ ] SELECT policies filter by tenant
- [ ] Admin access uses auth.uid() not email
- [ ] Soft deletes implemented
- [ ] Audit logging in place
- [ ] Triggers prevent client_uuid changes
- [ ] Auto-populate works correctly

## Production Deployment

Before deploying to production:

1. **Run full test suite**
   ```bash
   ./run-rls-tests.sh
   ```

2. **Review migration order**
   ```bash
   ls -la supabase/migrations/
   ```

3. **Push to production**
   ```bash
   npx supabase db push
   ```

4. **Verify in production**
   - Create test accounts
   - Verify tenant isolation
   - Check performance

## Support

If tests fail or you need help:
1. Check the test output for specific failures
2. Review the migration files for issues
3. Verify Supabase is running correctly
4. Check the logs: `npx supabase logs`

## Summary

The comprehensive RLS policies provide:
- ✅ Complete multi-tenant data isolation
- ✅ Protection against cross-tenant operations
- ✅ Automatic client_uuid management
- ✅ Soft delete with audit trails
- ✅ Admin bypass with secure authentication
- ✅ Performance optimizations

Run `./run-rls-tests.sh` to verify everything is working correctly!
# RLS Simplification - Phase 5 Cleanup Guide

## Prerequisites
- Phase 1-4 completed and deployed
- System running stable for at least 1 week with simplified RLS
- All monitoring shows no access issues

## Cleanup Steps

### Step 1: Remove Old Database Functions
After confirming stability (minimum 1 week), remove the old functions:

```sql
-- Remove old functions (kept with _old suffix)
DROP FUNCTION IF EXISTS is_admin_old() CASCADE;
DROP FUNCTION IF EXISTS user_has_client_access_old(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_user_client_uuid_old() CASCADE;
DROP FUNCTION IF EXISTS validate_client_uuid_old(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS prevent_client_uuid_change() CASCADE;
DROP FUNCTION IF EXISTS auto_populate_client_uuid() CASCADE;

-- Remove associated triggers
DROP TRIGGER IF EXISTS prevent_client_uuid_change_trigger ON users;
DROP TRIGGER IF EXISTS auto_populate_client_uuid_trigger ON client_notes;
```

### Step 2: Remove Legacy Application Code
1. Delete the old access control file:
   ```bash
   git rm lib/utils/access-control.ts
   ```

2. Update imports in dashboard:
   ```typescript
   // Remove old import
   - import { requireClientAccess, validateClientAccess, logSecurityEvent } from '@/lib/utils/access-control'
   
   // Keep only new import
   import RLSHelper from '@/lib/utils/rls-helper'
   ```

3. Remove feature flag checks from dashboard:
   ```typescript
   // Remove the if (USE_SIMPLIFIED_RLS) blocks
   // Keep only the RLSHelper code path
   ```

### Step 3: Remove Feature Flag
1. Delete the feature flag file:
   ```bash
   git rm lib/config/features.ts
   ```

2. Remove feature flag imports:
   ```typescript
   // Remove from dashboard and any other files
   - import { USE_SIMPLIFIED_RLS } from '@/lib/config/features'
   ```

3. Remove environment variable from deployment:
   - Go to your deployment platform (Vercel/Heroku/etc.)
   - Remove `NEXT_PUBLIC_USE_SIMPLIFIED_RLS` environment variable

### Step 4: Clean Up Migrations
1. Create a final cleanup migration to document the completed state
2. Archive old migration files that are no longer needed

### Step 5: Update Documentation
1. Update README.md to reflect the simplified architecture
2. Remove references to the old access control system
3. Update any API documentation

### Step 6: Final Testing
1. Run the RLS test suite:
   ```sql
   -- In Supabase SQL Editor
   \i tests/rls-policies.test.sql
   ```

2. Test all major user flows:
   - User login and profile access
   - Client data access
   - Admin operations
   - Cross-tenant isolation

### Step 7: Create Final Commit
```bash
git add -A
git commit -m "cleanup: Remove legacy RLS implementation

- Remove old access-control.ts file
- Remove feature flag infrastructure
- Clean up conditional logic in dashboard
- Update documentation
- System now uses simplified RLS exclusively"
```

## Rollback Plan (Emergency Only)
If issues are discovered during cleanup:

1. Restore from git:
   ```bash
   git revert HEAD
   ```

2. Re-add environment variable:
   ```
   NEXT_PUBLIC_USE_SIMPLIFIED_RLS=false
   ```

3. Restore database functions using:
   ```sql
   -- Run scripts/backup-current-rls.sql
   ```

## Success Metrics
After cleanup, you should see:
- ~60% reduction in RLS-related code
- Single source of truth (database only)
- Simplified debugging and maintenance
- Maintained security and compliance

## Long-term Maintenance
- Keep the RLS test suite and run it before any schema changes
- Monitor audit logs for any access anomalies
- Document any new RLS policies using the simplified pattern
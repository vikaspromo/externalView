# Supabase Migration Instructions

## Applying the RLS Policy Fix

The migration file `20250107_fix_client_org_relationships_rls.sql` contains SQL policies to fix the Row Level Security (RLS) issues with the `client_org_relationships` table.

### How to Apply the Migration

#### Option 1: Via Supabase Dashboard (Recommended for Development)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** (in the left sidebar)
3. Copy the entire contents of `20250107_fix_client_org_relationships_rls.sql`
4. Paste it into the SQL editor
5. Click **Run** to execute the migration

#### Option 2: Using Supabase CLI

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Link to your project
supabase link --project-ref vohyhkjygvkaxlmqkbem

# Run the migration
supabase db push
```

#### Option 3: Direct Database Connection

If you have direct database access:

```bash
psql $DATABASE_URL < supabase/migrations/20250107_fix_client_org_relationships_rls.sql
```

### What This Migration Does

1. **Drops any existing policies** on the `client_org_relationships` table (safe to run multiple times)

2. **Creates permissive development policies** that allow:
   - Public READ access (SELECT)
   - Public INSERT access
   - Public UPDATE access
   - Public DELETE access

3. **Includes commented production policies** for when you're ready to deploy

### Testing the Fix

After applying the migration, test in your application:

1. Refresh your dashboard page
2. Click on any organization row to expand it
3. The financial admin data should now load without 406 errors

### Troubleshooting

If you still get errors after applying the migration:

1. **Check RLS is enabled**: 
   ```sql
   SELECT relrowsecurity FROM pg_class WHERE relname = 'client_org_relationships';
   ```
   Should return `true`

2. **Verify policies were created**:
   ```sql
   SELECT pol.polname 
   FROM pg_policy pol 
   JOIN pg_class cls ON pol.polrelid = cls.oid 
   WHERE cls.relname = 'client_org_relationships';
   ```
   Should show 4 policies

3. **Test direct query**:
   ```sql
   SELECT COUNT(*) FROM client_org_relationships;
   ```
   Should return 11 records

### Production Deployment

Before deploying to production:

1. Comment out the development policies
2. Uncomment and customize the production policies
3. Test thoroughly with different user roles
4. Consider adding time-based or IP-based restrictions as needed

### Rollback Instructions

If you need to rollback these changes:

```sql
DROP POLICY IF EXISTS "Allow public read access to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public insert to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public update to client_org_relationships" ON client_org_relationships;
DROP POLICY IF EXISTS "Allow public delete from client_org_relationships" ON client_org_relationships;
```
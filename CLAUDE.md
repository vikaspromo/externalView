# Claude Code Instructions for ExternalView Project

## RLS Simplification Status (2025-01-13)

### Current Status: Ready for Deployment
The RLS simplification is implemented on branch `feature/simplify-rls` and ready for deployment.

### Manual Steps Required:

1. **Add Environment Variable** (do this first, before deploying):
   ```
   NEXT_PUBLIC_USE_SIMPLIFIED_RLS=false
   ```
   Add this to your deployment platform (Vercel, Heroku, etc.)

2. **Deploy the Code**:
   - Merge `feature/simplify-rls` branch to main
   - Deploy with the feature flag set to `false`

3. **Run Database Migrations** (in order):
   ```sql
   -- Run in Supabase SQL Editor
   -- 1. Create v2 functions (safe, parallel to existing)
   20250113_164156_simplified_rls_functions_v2.sql
   
   -- 2. Create disabled v2 policies (safe, inactive)
   20250113_164257_simplified_rls_policies_v2.sql
   ```

4. **Test & Monitor** (with flag still false):
   - Run RLS test suite: `tests/rls-policies.test.sql`
   - Verify application works normally

5. **Switchover** (when ready):
   - Create Supabase backup
   - Run switchover migration: `20250113_164730_rls_switchover.sql`
   - Set `NEXT_PUBLIC_USE_SIMPLIFIED_RLS=true` in deployment platform
   - Monitor for 30 minutes

6. **Cleanup** (after 1 week stable):
   - Follow `docs/rls-simplification-cleanup.md`

### Rollback Plan:
- Instant: Set `NEXT_PUBLIC_USE_SIMPLIFIED_RLS=false`
- Full: Run rollback script in `20250113_164730_rls_switchover.sql` comments

### Files Changed:
- New: `lib/utils/rls-helper.ts` (simplified access control)
- New: `lib/config/features.ts` (feature flag)
- Modified: `app/dashboard/page.tsx` (uses feature flag)
- New migrations: 3 files in `supabase/migrations/`
- New tests: `tests/rls-policies.test.sql`
- Backup: `scripts/backup-current-rls.sql`

## Documentation Strategy

**IMPORTANT: Always consolidate new documentation into README.md rather than creating separate documentation files.**

### Guidelines:
- All project documentation should be added to README.md as new sections or subsections
- Keep README.md as the single source of truth for project documentation
- Organize content in README.md using proper markdown sections and hierarchy
- Only create separate documentation files when:
  - The user explicitly asks for a separate file
  - Technical requirements demand it (e.g., API docs that must be in a specific location)

### Why This Matters:
- Prevents documentation sprawl across multiple files
- Makes it easier to find and maintain documentation
- Reduces duplication and conflicts
- Provides a single entry point for new developers

## Database Migrations

### CRITICAL: Migration File Naming
**ALWAYS name migration files with datetime timestamp: `YYYYMMDD_HHMMSS_description.sql`**

**IMPORTANT: Use the CURRENT Eastern Time (EST/EDT) when creating the timestamp.**
- Get current EST time: `date "+%Y%m%d_%H%M%S" --date="now EST"`
- The HHMMSS must be the actual time in EST, not a sequence number
- This ensures chronological ordering even across time zones

```bash
# Format: YYYYMMDD_HHMMSS_description.sql
# Where HHMMSS = actual EST time (hours, minutes, seconds)

# CORRECT examples (with actual EST timestamps):
20250111_143025_add_user_table.sql          ✅ (2:30:25 PM EST)
20250111_090512_fix_rls_policies.sql        ✅ (9:05:12 AM EST)
20250111_235959_update_audit_log.sql        ✅ (11:59:59 PM EST)

# WRONG examples:
20250111_add_user_table.sql                 ❌ (missing time)
20250111000001_add_user_table.sql           ❌ (sequence number, not actual time)
20250111_120000_add_user_table.sql          ❌ (fake/rounded time, use actual time)
add_user_table.sql                          ❌ (no timestamp)
```

### Why This Matters:
- Ensures migrations run in exact chronological order
- Prevents naming conflicts when multiple changes happen same day
- Makes rollbacks easier to identify and execute

## Code Quality Checks

### IMPORTANT: Always run checks before committing
**You MUST run the following checks before committing any code changes:**

```bash
# Run all checks at once (recommended)
npm run check:all

# Or run individually:
npm run lint        # Check for ESLint errors
npm run typecheck   # Check for TypeScript type errors
```

### Automated Pre-commit Hooks
The project has Husky pre-commit hooks that automatically run these checks before each commit. If any check fails, the commit will be blocked until the issues are fixed.

### Common Issues to Watch For:
1. **Trailing commas** - ESLint requires trailing commas in objects and arrays
2. **Undefined objects** - TypeScript requires null checks before accessing properties
3. **Unused parameters** - Prefix with underscore (e.g., `_param`) if intentionally unused
4. **Console statements** - Use the logger utility instead of console.log/error

## Other Project Conventions

### Testing
- Run lint and typecheck before committing code changes
- Test RLS policies after any security-related changes
- Verify migrations work with `supabase db reset` locally when possible

### Security
- All admin checks must use `auth.uid()`, never JWT email claims
- Enable RLS on all tables containing user data
- Log security-sensitive operations to audit tables

### Git Commits
- Use conventional commit format (feat:, fix:, chore:, etc.)
- Include Co-Authored-By for pair programming or AI assistance
- Test changes before committing
# Claude Code Instructions for ExternalView Project

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
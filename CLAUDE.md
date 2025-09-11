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

```bash
# Format: YYYYMMDD_HHMMSS_description.sql

# CORRECT examples:
20250111_143025_add_user_table.sql          ✅
20250111_090512_fix_rls_policies.sql        ✅
20250111_235959_update_audit_log.sql        ✅

# WRONG examples:
20250111_add_user_table.sql                 ❌ (missing time)
20250111000001_add_user_table.sql           ❌ (sequence number instead of time)
add_user_table.sql                          ❌ (no timestamp)
```

### Why This Matters:
- Ensures migrations run in exact chronological order
- Prevents naming conflicts when multiple changes happen same day
- Makes rollbacks easier to identify and execute

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
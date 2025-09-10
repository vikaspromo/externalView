# Claude Code Instructions for ExternalView Project

## Database Migrations

### IMPORTANT: Creating New Migrations
**ALWAYS use the migration script for creating new database migrations:**

```bash
# DO THIS:
./scripts/create-migration.sh "description of change"

# Example:
./scripts/create-migration.sh "add user preferences table"
# Creates: supabase/migrations/20250910_164523_add_user_preferences_table.sql
```

**NEVER create migration files directly:**
```bash
# DON'T DO THIS:
Write: supabase/migrations/20250910_my_migration.sql  # ❌ Wrong
```

### Why This Matters:
- Ensures consistent timestamp naming (YYYYMMDD_HHMMSS_description.sql)
- Migrations run in correct chronological order
- Prevents naming conflicts
- Follows team conventions

### After Creating a Migration:
1. The script creates a template file with proper naming
2. Edit the file to add your SQL commands
3. Test the migration locally before committing

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
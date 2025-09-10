# Migration Naming Convention

## Format
All migration files must follow this naming pattern:
```
YYYYMMDD_HHMMSS_descriptive_name.sql
```

### Components:
- **YYYY**: 4-digit year
- **MM**: 2-digit month (01-12)
- **DD**: 2-digit day (01-31)
- **HH**: 2-digit hour in 24-hour format (00-23)
- **MM**: 2-digit minute (00-59)
- **SS**: 2-digit second (00-59)
- **descriptive_name**: Snake_case description of what the migration does

## Examples
- `20250110_143000_create_organization_positions.sql`
- `20250110_143015_simplify_client_org_relationships.sql`
- `20250110_143030_cleanup_archive_table.sql`
- `20250110_143045_drop_relationship_status.sql`

## Benefits
1. **Chronological Ordering**: Files naturally sort in the order they should be executed
2. **No Conflicts**: Timestamp precision prevents naming collisions
3. **Clear Purpose**: Descriptive names indicate what each migration does
4. **Easy Tracking**: Can quickly identify when migrations were created

## Creating New Migrations

### Automatic Method (Recommended)
Use the provided script to automatically create migrations with proper naming:
```bash
# From project root:
./scripts/create-migration.sh "description of your migration"

# Example:
./scripts/create-migration.sh "add user preferences table"
# Creates: 20250110_143256_add_user_preferences_table.sql
```

### Manual Method
If creating manually, use the current timestamp:
```bash
# Example: Create a new migration file
date +"%Y%m%d_%H%M%S"_your_description_here.sql
```

## Migration Order
Migrations should be executed in alphabetical order, which will naturally be chronological order due to the timestamp prefix.
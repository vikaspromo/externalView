#!/bin/bash

# Script to create a new Supabase migration with timestamp naming convention
# Usage: ./scripts/create-migration.sh "description of migration"

if [ -z "$1" ]; then
    echo "Usage: $0 \"description_of_migration\""
    echo "Example: $0 \"add_user_preferences_table\""
    exit 1
fi

# Convert description to snake_case
DESCRIPTION=$(echo "$1" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create migration file path
MIGRATION_DIR="/workspaces/externalView/supabase/migrations"
MIGRATION_FILE="${MIGRATION_DIR}/${TIMESTAMP}_${DESCRIPTION}.sql"

# Create migration file with template
cat > "$MIGRATION_FILE" << EOF
-- Migration: ${DESCRIPTION//_/ }
-- Date: $(date +"%Y-%m-%d %H:%M:%S")
-- Purpose: [Add purpose here]

-- ============================================================================
-- MIGRATION SCRIPT
-- ============================================================================

-- Add your SQL here

EOF

echo "Created migration: $MIGRATION_FILE"
echo "Edit the file to add your SQL commands."
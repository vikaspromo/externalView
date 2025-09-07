#!/bin/bash

# Get full database schema using Supabase CLI
echo "📊 Exporting complete database schema..."
echo "This will create a schema-only backup (no data)"
echo ""

# Database connection details from your project
DB_URL="postgresql://postgres.vohyhkjygvkaxlmqkbem:PASSWORD@aws-0-us-west-1.pooler.supabase.com:5432/postgres"

echo "⚠️  You need your database password from Supabase"
echo "Get it from: Supabase Dashboard → Settings → Database → Database Password"
echo ""
read -s -p "Enter your Supabase database password: " DB_PASSWORD
echo ""

# Replace PASSWORD in the connection string
DB_URL="postgresql://postgres.vohyhkjygvkaxlmqkbem:${DB_PASSWORD}@aws-0-us-west-1.pooler.supabase.com:5432/postgres"

# Output file with timestamp
OUTPUT_FILE="schema_backup_$(date +%Y%m%d_%H%M%S).sql"

echo "🔄 Connecting to database and exporting schema..."

# Use pg_dump to get schema only (no data)
pg_dump "$DB_URL" \
  --schema-only \
  --no-owner \
  --no-privileges \
  --no-comments \
  --schema=public \
  --file="$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Schema exported successfully!"
    echo "📁 Schema file: $OUTPUT_FILE"
    echo ""
    echo "📋 Tables found in schema:"
    grep "CREATE TABLE" "$OUTPUT_FILE" | sed 's/CREATE TABLE /  - /' | sed 's/ (//'
    echo ""
    echo "File size: $(ls -lh $OUTPUT_FILE | awk '{print $5}')"
else
    echo "❌ Export failed. Check your password and try again."
fi
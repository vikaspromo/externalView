#!/bin/bash

echo "📊 Getting COMPLETE database schema dump..."
echo ""

# Use the Supabase CLI we have installed
./supabase db dump \
  --db-url "postgresql://postgres.vohyhkjygvkaxlmqkbem:[YOUR-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:5432/postgres" \
  --schema-only \
  -f complete_schema.sql

echo ""
echo "⚠️  Replace [YOUR-PASSWORD] with your database password"
echo "Get it from: Supabase Dashboard → Settings → Database"
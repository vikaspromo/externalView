#!/bin/bash

# Load environment variables
source .env.local

# Extract connection details from Supabase URL
# Format: postgresql://postgres:[YOUR-PASSWORD]@db.vohyhkjygvkaxlmqkbem.supabase.co:5432/postgres

DB_HOST="db.vohyhkjygvkaxlmqkbem.supabase.co"
DB_NAME="postgres"
DB_USER="postgres"
DB_PORT="5432"

# Get password from Supabase dashboard (Settings -> Database -> Connection string)
echo "You need your database password from Supabase Dashboard"
echo "Go to: Settings -> Database -> Connection string"
echo "Look for the password in the connection string"
read -s -p "Enter database password: " DB_PASSWORD
echo

# Create backup filename with timestamp
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"

# Run pg_dump
echo "Creating backup: $BACKUP_FILE"
PGPASSWORD=$DB_PASSWORD pg_dump \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  -p $DB_PORT \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  > $BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "✅ Backup created successfully: $BACKUP_FILE"
  echo "File size: $(ls -lh $BACKUP_FILE | awk '{print $5}')"
else
  echo "❌ Backup failed"
fi
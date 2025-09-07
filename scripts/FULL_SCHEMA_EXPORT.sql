-- ============================================
-- COMPLETE DATABASE SCHEMA EXPORT
-- Run this in Supabase SQL Editor
-- Copy the entire output to save your schema
-- ============================================

-- 1. LIST ALL TABLES WITH ROW COUNTS
-- ============================================
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. GET CREATE TABLE STATEMENTS FOR ALL TABLES
-- ============================================
WITH table_ddl AS (
  SELECT 
    table_name,
    'CREATE TABLE ' || table_name || ' (' || E'\n' ||
    string_agg(
      '  ' || column_name || ' ' || 
      CASE 
        WHEN data_type = 'character varying' THEN 'VARCHAR(' || character_maximum_length || ')'
        WHEN data_type = 'numeric' THEN 'NUMERIC(' || numeric_precision || ',' || numeric_scale || ')'
        ELSE UPPER(data_type)
      END ||
      CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
      CASE WHEN column_default IS NOT NULL THEN ' DEFAULT ' || column_default ELSE '' END,
      E',\n' ORDER BY ordinal_position
    ) || E'\n);' as create_statement
  FROM information_schema.columns
  WHERE table_schema = 'public'
  GROUP BY table_name
)
SELECT * FROM table_ddl ORDER BY table_name;

-- 3. GET ALL INDEXES
-- ============================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- 4. GET ALL FOREIGN KEY CONSTRAINTS
-- ============================================
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    a.attname AS column_name,
    confrelid::regclass AS foreign_table_name,
    af.attname AS foreign_column_name
FROM
    pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
    JOIN pg_attribute af ON af.attrelid = c.confrelid AND af.attnum = ANY(c.confkey)
WHERE
    c.contype = 'f'
    AND c.connamespace = 'public'::regnamespace
ORDER BY
    conrelid::regclass::text,
    conname;

-- 5. GET ALL VIEWS
-- ============================================
SELECT 
    viewname,
    definition
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;

-- 6. GET ALL FUNCTIONS
-- ============================================
SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;

-- 7. GET ALL TRIGGERS
-- ============================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 8. GET ALL SEQUENCES
-- ============================================
SELECT 
    sequence_name,
    data_type,
    start_value,
    minimum_value,
    maximum_value,
    increment
FROM information_schema.sequences
WHERE sequence_schema = 'public'
ORDER BY sequence_name;

-- 9. SUMMARY - JUST TABLE NAMES
-- ============================================
SELECT 
    '-- Total tables: ' || COUNT(*) as summary,
    string_agg(tablename, ', ' ORDER BY tablename) as all_tables
FROM pg_tables
WHERE schemaname = 'public';
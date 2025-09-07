-- Run this in Supabase SQL Editor to see ALL your tables
-- Then you'll know which ones to add to the backup script

-- 1. Show all tables in your database
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 2. Show only tables starting with 'books_'
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'books_%'
ORDER BY table_name;

-- 3. Show table sizes and row counts
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  n_tup_ins AS rows_inserted
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY tablename;
-- List all tables in your database that start with 'books_'
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE 'books_%'
ORDER BY tablename;

-- Also show all tables in the public schema
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
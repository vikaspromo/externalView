-- Export COMPLETE database schema
-- Run this in Supabase SQL Editor and save the output

-- 1. List ALL tables with their columns
SELECT 
    t.table_name,
    array_agg(
        c.column_name || ' ' || c.data_type || 
        CASE 
            WHEN c.character_maximum_length IS NOT NULL 
            THEN '(' || c.character_maximum_length || ')'
            ELSE ''
        END ||
        CASE 
            WHEN c.is_nullable = 'NO' THEN ' NOT NULL'
            ELSE ''
        END
        ORDER BY c.ordinal_position
    ) AS columns
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public'
GROUP BY t.table_name
ORDER BY t.table_name;

-- 2. Get complete DDL for all tables (structure only)
SELECT 
    'CREATE TABLE ' || tablename || ' (' || chr(10) ||
    array_to_string(
        array_agg(
            '  ' || column_name || ' ' || data_type || 
            CASE 
                WHEN character_maximum_length IS NOT NULL 
                THEN '(' || character_maximum_length || ')'
                ELSE ''
            END ||
            CASE 
                WHEN is_nullable = 'NO' THEN ' NOT NULL'
                ELSE ''
            END
            ORDER BY ordinal_position
        ), ',' || chr(10)
    ) || chr(10) || ');'
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY tablename
ORDER BY tablename;
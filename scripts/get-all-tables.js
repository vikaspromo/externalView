const { createClient } = require('@supabase/supabase-js')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function getAllTables() {
  console.log('🔍 Fetching complete list of tables from your database...\n')

  // Query to get all tables - we'll try different approaches
  const queries = [
    // Approach 1: Direct query to pg_tables
    `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`,
    
    // Approach 2: Information schema
    `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name`,
    
    // Approach 3: Get all relations
    `SELECT relname FROM pg_class WHERE relkind = 'r' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public') ORDER BY relname`
  ]

  for (let i = 0; i < queries.length; i++) {
    try {
      console.log(`Trying approach ${i + 1}...`)
      
      // We'll try to use raw SQL through Supabase
      const { data, error } = await supabase.rpc('get_tables_list', {
        query_text: queries[i]
      })

      if (!error && data) {
        console.log('\n✅ Found tables:')
        data.forEach(table => console.log(`  - ${table.tablename || table.table_name || table.relname}`))
        return data
      }
    } catch (err) {
      // Try next approach
    }
  }

  // If RPC doesn't work, let's create the function
  console.log('\n📝 The RPC function needs to be created. Run this in Supabase SQL Editor:\n')
  console.log(`
-- Create a function to list all tables
CREATE OR REPLACE FUNCTION get_tables_list(query_text text)
RETURNS TABLE(tablename text) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY EXECUTE query_text;
END;
$$;

-- Then run this to see all your tables:
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;
  `)
  
  // Let's also try to detect tables by attempting to query them
  console.log('\n🔎 Attempting to detect tables by common patterns...\n')
  
  const patterns = [
    'books_', 'user_', 'order_', 'product_', 'customer_', 
    'inventory_', 'category_', 'author_', 'publisher_'
  ]
  
  const detectedTables = []
  
  // Known tables
  const knownTables = ['allowed_users', 'books']
  
  for (const table of knownTables) {
    try {
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true })
      
      if (!error) {
        detectedTables.push({ name: table, rows: count })
        console.log(`✅ Found: ${table} (${count} rows)`)
      }
    } catch (err) {
      // Table doesn't exist
    }
  }
  
  // Try to find books_ tables
  for (let i = 1; i <= 20; i++) {
    for (const pattern of ['books_', 'book_']) {
      const tableName = `${pattern}${i}`
      try {
        const { count, error } = await supabase
          .from(tableName)
          .select('*', { count: 'exact', head: true })
        
        if (!error) {
          detectedTables.push({ name: tableName, rows: count })
          console.log(`✅ Found: ${tableName} (${count} rows)`)
        }
      } catch (err) {
        // Continue
      }
    }
  }
  
  // Try common book-related table names
  const bookTables = [
    'books_authors', 'books_categories', 'books_genres', 'books_publishers',
    'books_reviews', 'books_ratings', 'books_inventory', 'books_sales',
    'books_users', 'books_favorites', 'books_wishlist', 'books_orders'
  ]
  
  for (const table of bookTables) {
    try {
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true })
      
      if (!error) {
        detectedTables.push({ name: table, rows: count })
        console.log(`✅ Found: ${table} (${count} rows)`)
      }
    } catch (err) {
      // Continue
    }
  }
  
  console.log(`\n📊 Total tables detected: ${detectedTables.length}`)
  
  return detectedTables
}

getAllTables()
  .then(tables => {
    console.log('\n✅ Done!')
    if (tables && tables.length > 0) {
      console.log('\nTo backup these tables, update the export script with these table names.')
    }
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Error:', error)
    process.exit(1)
  })
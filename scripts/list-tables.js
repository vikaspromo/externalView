const { createClient } = require('@supabase/supabase-js')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function listTables() {
  console.log('Fetching all tables from your Supabase database...\n')

  try {
    // Query to get all tables from the database
    const { data, error } = await supabase
      .rpc('get_tables', {})
      .select('*')
  } catch (error) {
    // If the RPC doesn't exist, try a different approach
    // Query the information_schema to get all tables
    const { data, error } = await supabase
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public')
    
    if (error) {
      // Try raw SQL query
      const { data: tables, error: sqlError } = await supabase
        .rpc('query', { 
          sql: "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
        })
      
      if (sqlError) {
        console.log('Could not fetch tables automatically.')
        console.log('\nTo see your tables, run this SQL in Supabase SQL Editor:')
        console.log("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'books_%';")
        return
      }
      
      console.log('Tables in your database:', tables)
    } else {
      console.log('Tables in your database:', data)
    }
  }
}

// Alternative: Try to query specific books_ tables
async function checkBooksTablesExist() {
  console.log('\nChecking for tables starting with "books_"...\n')
  
  const possibleTables = [
    'books',
    'books_authors', 
    'books_categories',
    'books_reviews',
    'books_users',
    'books_inventory',
    'books_orders',
    'books_publishers'
  ]

  for (const table of possibleTables) {
    try {
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true })
      
      if (!error) {
        console.log(`✓ Table "${table}" exists (${count || 0} rows)`)
      }
    } catch (err) {
      // Table doesn't exist, skip
    }
  }
}

listTables()
  .then(() => checkBooksTablesExist())
  .then(() => {
    console.log('\nDone!')
    process.exit(0)
  })
  .catch(error => {
    console.error('Error:', error)
    process.exit(1)
  })
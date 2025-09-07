const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY // Using service key to bypass RLS
)

async function exportAllTables() {
  console.log('🔄 Starting database export...\n')
  
  const backup = {
    timestamp: new Date().toISOString(),
    database: 'externalview',
    tables: {}
  }

  // List of tables to export
  // Add your books_ tables here
  const tablesToExport = [
    'allowed_users',
    'organizations',
    'stakeholder_relationships',
    // Add your books_ tables:
    // 'books_table1',
    // 'books_table2',
    // etc.
  ]

  for (const tableName of tablesToExport) {
    try {
      console.log(`Exporting table: ${tableName}...`)
      
      // Fetch all data from table
      const { data, error, count } = await supabase
        .from(tableName)
        .select('*', { count: 'exact' })
      
      if (error) {
        console.log(`  ⚠️  Skipped ${tableName}: ${error.message}`)
        continue
      }

      backup.tables[tableName] = {
        rowCount: count || 0,
        data: data || []
      }
      
      console.log(`  ✅ Exported ${count || 0} rows from ${tableName}`)
    } catch (err) {
      console.log(`  ❌ Error with ${tableName}:`, err.message)
    }
  }

  // Save to JSON file
  const filename = `backup_${new Date().toISOString().replace(/[:.]/g, '-')}.json`
  fs.writeFileSync(filename, JSON.stringify(backup, null, 2))
  
  console.log(`\n✅ Backup saved to: ${filename}`)
  console.log(`📦 Total tables exported: ${Object.keys(backup.tables).length}`)
  
  // Also create a restore script
  createRestoreScript(filename, backup)
}

function createRestoreScript(backupFile, backup) {
  const restoreScript = `
// Restore script for ${backupFile}
const { createClient } = require('@supabase/supabase-js')
const backup = require('./${backupFile}')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function restore() {
  console.log('🔄 Starting restore from ${backupFile}...')
  
  for (const [tableName, tableData] of Object.entries(backup.tables)) {
    console.log(\`Restoring \${tableName}...\`)
    
    if (tableData.data.length > 0) {
      const { error } = await supabase
        .from(tableName)
        .upsert(tableData.data, { onConflict: 'id' })
      
      if (error) {
        console.error(\`Error restoring \${tableName}:\`, error)
      } else {
        console.log(\`✅ Restored \${tableData.rowCount} rows to \${tableName}\`)
      }
    }
  }
  
  console.log('✅ Restore complete!')
}

restore().catch(console.error)
`

  const restoreFilename = `restore_${backupFile.replace('.json', '.js')}`
  fs.writeFileSync(restoreFilename, restoreScript)
  console.log(`📝 Restore script created: ${restoreFilename}`)
}

// Export all tables from Supabase to get a complete list
async function discoverAllTables() {
  console.log('\n🔍 Discovering all tables in your database...\n')
  
  // This query gets all table names from the public schema
  const { data, error } = await supabase
    .rpc('get_all_tables', {})
    
  if (error) {
    // If RPC doesn't exist, create and run SQL directly in Supabase:
    console.log('To see all your tables, run this SQL in Supabase SQL Editor:')
    console.log(`
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
    `)
    
    console.log('\nThen update the tablesToExport array in this script with your table names.')
    return []
  }
  
  return data
}

// Run the export
exportAllTables()
  .then(() => {
    console.log('\n✅ Export complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Export failed:', error)
    process.exit(1)
  })
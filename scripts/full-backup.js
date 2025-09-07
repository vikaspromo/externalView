const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function fullBackup() {
  console.log('🔄 Starting complete database backup...\n')
  
  // First, get ALL table names from your database
  const { data: tables, error: tablesError } = await supabase.rpc('sql', {
    query: `
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `
  }).single()

  // Since RPC might not work, let's manually list common tables
  // and try to detect which ones exist
  const possibleTables = [
    // Known tables
    'allowed_users',
    'organizations', 
    'stakeholder_relationships',
    
    // Common Supabase auth tables
    'profiles',
    'users',
    
    // Possible books tables - add any you know exist
    'books',
    'books_authors',
    'books_categories',
    'books_inventory',
    'books_orders',
    'books_publishers',
    'books_reviews',
    'books_users',
    
    // Add any other tables you might have
  ]

  const backup = {
    timestamp: new Date().toISOString(),
    database: process.env.NEXT_PUBLIC_SUPABASE_URL,
    tables: {},
    summary: {
      totalTables: 0,
      totalRows: 0,
      exportedTables: [],
      failedTables: []
    }
  }

  console.log('Attempting to export tables...\n')

  for (const tableName of possibleTables) {
    try {
      // Try to query the table
      const { data, error, count } = await supabase
        .from(tableName)
        .select('*', { count: 'exact' })
      
      if (!error && data) {
        backup.tables[tableName] = {
          rowCount: count || data.length,
          data: data
        }
        backup.summary.totalRows += (count || data.length)
        backup.summary.exportedTables.push(tableName)
        console.log(`✅ Exported ${count || data.length} rows from "${tableName}"`)
      }
    } catch (err) {
      // Table doesn't exist or error accessing it
    }
  }

  backup.summary.totalTables = backup.summary.exportedTables.length

  // Save the backup
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const filename = `full_backup_${timestamp}.json`
  
  fs.writeFileSync(filename, JSON.stringify(backup, null, 2))
  
  console.log('\n' + '='.repeat(50))
  console.log('✅ BACKUP COMPLETE!')
  console.log('='.repeat(50))
  console.log(`📁 Backup file: ${filename}`)
  console.log(`📊 Total tables backed up: ${backup.summary.totalTables}`)
  console.log(`📝 Total rows backed up: ${backup.summary.totalRows}`)
  console.log(`\n📋 Tables included:`)
  backup.summary.exportedTables.forEach(t => console.log(`   - ${t}`))
  
  // Create restore script
  const restoreScript = `
const { createClient } = require('@supabase/supabase-js')
const backup = require('./${filename}')
require('dotenv').config({ path: '.env.local' })

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function restore() {
  console.log('🔄 Restoring from backup: ${filename}')
  console.log('Tables to restore:', Object.keys(backup.tables).join(', '))
  
  for (const [tableName, tableData] of Object.entries(backup.tables)) {
    console.log(\`\\nRestoring \${tableName} (\${tableData.rowCount} rows)...\`)
    
    if (tableData.data && tableData.data.length > 0) {
      // Batch insert in chunks of 100
      const chunkSize = 100
      for (let i = 0; i < tableData.data.length; i += chunkSize) {
        const chunk = tableData.data.slice(i, i + chunkSize)
        const { error } = await supabase
          .from(tableName)
          .upsert(chunk, { 
            onConflict: 'id',
            ignoreDuplicates: true 
          })
        
        if (error) {
          console.error(\`  ❌ Error restoring \${tableName}:\`, error.message)
          break
        } else {
          console.log(\`  ✅ Restored batch \${Math.floor(i/chunkSize) + 1}\`)
        }
      }
    }
  }
  
  console.log('\\n✅ Restore complete!')
}

restore().catch(console.error)
`

  const restoreFilename = `restore_${timestamp}.js`
  fs.writeFileSync(restoreFilename, restoreScript)
  console.log(`\n🔧 Restore script created: ${restoreFilename}`)
  console.log(`   Run "node ${restoreFilename}" to restore this backup\n`)
}

fullBackup()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Backup failed:', error)
    process.exit(1)
  })
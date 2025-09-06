const { createClient } = require('@supabase/supabase-js')
require('dotenv').config({ path: '.env.local' })

// Initialize Supabase client with service key for admin access
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function addAuthorizedUsers() {
  const users = [
    { email: 'vikassood@gmail.com', company: 'External View' },
    { email: 'jebory@gmail.com', company: 'External View' }
  ]

  console.log('Adding authorized users...')

  for (const user of users) {
    try {
      // Check if user already exists
      const { data: existingUser } = await supabase
        .from('allowed_users')
        .select('*')
        .eq('email', user.email)
        .single()

      if (existingUser) {
        console.log(`✓ User ${user.email} already exists`)
      } else {
        // Add new user
        const { data, error } = await supabase
          .from('allowed_users')
          .insert([user])
          .select()

        if (error) {
          console.error(`✗ Error adding ${user.email}:`, error.message)
        } else {
          console.log(`✓ Successfully added ${user.email}`)
        }
      }
    } catch (error) {
      console.error(`✗ Error processing ${user.email}:`, error)
    }
  }

  console.log('\nAuthorized users:')
  const { data: allUsers } = await supabase
    .from('allowed_users')
    .select('*')
    .order('created_at', { ascending: false })

  if (allUsers) {
    allUsers.forEach(user => {
      console.log(`  - ${user.email} (${user.company})`)
    })
  }
}

addAuthorizedUsers()
  .then(() => {
    console.log('\nDone!')
    process.exit(0)
  })
  .catch(error => {
    console.error('Script failed:', error)
    process.exit(1)
  })
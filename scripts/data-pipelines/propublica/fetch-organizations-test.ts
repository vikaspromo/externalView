import { supabase } from '../shared/database'
import { delay, API_DELAYS } from '../shared/rate-limiter'
import { 
  ProPublicaOrganization, 
  ProPublicaSearchResponse, 
  PROPUBLICA_CONFIG 
} from './types'

// Interface for our database organization
interface Organization {
  id: string
  name: string
  type?: string
  priority?: number
  alignment_score?: number
  total_spend?: number
  status?: string
  owner?: string
  description?: string
}


// Search ProPublica API for an organization
async function searchProPublica(orgName: string): Promise<ProPublicaSearchResponse | null> {
  try {
    const encodedName = encodeURIComponent(orgName)
    const url = `${PROPUBLICA_CONFIG.API_BASE}${PROPUBLICA_CONFIG.SEARCH_ENDPOINT}?q=${encodedName}`
    
    const response = await fetch(url)
    
    if (!response.ok) {
      console.error(`API error for "${orgName}": ${response.status} ${response.statusText}`)
      return null
    }
    
    const data = await response.json()
    return data
  } catch (error) {
    console.error(`Error searching for "${orgName}":`, error)
    return null
  }
}

// Format and display organization data
function displayOrganizationResults(dbOrg: Organization, apiResponse: ProPublicaSearchResponse | null) {
  console.log('\n' + '='.repeat(60))
  console.log(`=== Organization: ${dbOrg.name} ===`)
  console.log('='.repeat(60))
  
  if (!apiResponse) {
    console.log('Status: ❌ API Error - Could not fetch data')
    return
  }
  
  const totalResults = apiResponse.total_results
  
  if (totalResults === 0) {
    console.log('Status: ⚠️  No results found')
    return
  }
  
  if (totalResults === 1) {
    console.log('Status: ✅ Exact match found')
    const org = apiResponse.organizations[0]
    console.log('\nDetails:')
    console.log(`  - EIN: ${org.ein}`)
    console.log(`  - Name: ${org.name}`)
    if (org.city && org.state) {
      console.log(`  - Location: ${org.city}, ${org.state}`)
    }
    if (org.ntee_code) {
      console.log(`  - NTEE Code: ${org.ntee_code}`)
    }
    if (org.subseccd) {
      console.log(`  - Subsection Code: ${org.subseccd}`)
    }
    if (org.totrevenue) {
      console.log(`  - Total Revenue: $${org.totrevenue.toLocaleString()}`)
    }
    if (org.totfuncexpns) {
      console.log(`  - Total Expenses: $${org.totfuncexpns.toLocaleString()}`)
    }
    if (org.score) {
      console.log(`  - Search Score: ${org.score}`)
    }
  } else {
    console.log(`Status: 🔍 Found ${totalResults} results (showing top ${Math.min(5, apiResponse.organizations.length)})`)
    console.log('\nTop matches:')
    
    const topOrgs = apiResponse.organizations.slice(0, 5)
    topOrgs.forEach((org, index) => {
      console.log(`\n${index + 1}. ${org.name} (EIN: ${org.ein})`)
      if (org.city && org.state) {
        console.log(`   Location: ${org.city}, ${org.state}`)
      }
      if (org.score) {
        console.log(`   Relevance Score: ${org.score}`)
      }
      if (org.totrevenue) {
        console.log(`   Revenue: $${org.totrevenue.toLocaleString()}`)
      }
    })
  }
}

// Main function
async function main() {
  console.log('🚀 Starting ProPublica data fetch...\n')
  
  // Fetch organizations from database
  console.log('📊 Fetching organizations from database...')
  const { data: organizations, error } = await supabase
    .from('organizations')
    .select('*')
    .order('name')
  
  if (error) {
    console.error('Error fetching organizations:', error)
    process.exit(1)
  }
  
  if (!organizations || organizations.length === 0) {
    console.log('No organizations found in database')
    process.exit(0)
  }
  
  console.log(`Found ${organizations.length} organizations in database\n`)
  console.log('🔍 Searching ProPublica API for each organization...')
  console.log('(Note: Adding 1-second delay between requests to respect rate limits)\n')
  
  // Process each organization
  for (let i = 0; i < organizations.length; i++) {
    const org = organizations[i]
    
    // Search ProPublica
    const apiResponse = await searchProPublica(org.name)
    
    // Display results
    displayOrganizationResults(org, apiResponse)
    
    // Add delay between requests (except for the last one)
    if (i < organizations.length - 1) {
      await delay(API_DELAYS.PROPUBLICA)
    }
  }
  
  console.log('\n' + '='.repeat(60))
  console.log('✅ Completed ProPublica data fetch')
  console.log('='.repeat(60))
  
  // Summary statistics
  let exactMatches = 0
  let multipleMatches = 0
  let noMatches = 0
  let apiErrors = 0
  
  // Re-process to get statistics
  for (const org of organizations) {
    const apiResponse = await searchProPublica(org.name)
    if (!apiResponse) {
      apiErrors++
    } else if (apiResponse.total_results === 0) {
      noMatches++
    } else if (apiResponse.total_results === 1) {
      exactMatches++
    } else {
      multipleMatches++
    }
    await delay(API_DELAYS.PROPUBLICA / 2) // Shorter delay for statistics gathering
  }
  
  console.log('\n📈 Summary Statistics:')
  console.log(`  - Total organizations: ${organizations.length}`)
  console.log(`  - Exact matches (1 result): ${exactMatches}`)
  console.log(`  - Multiple matches: ${multipleMatches}`)
  console.log(`  - No matches found: ${noMatches}`)
  if (apiErrors > 0) {
    console.log(`  - API errors: ${apiErrors}`)
  }
}

// Run the script
main().catch(console.error)
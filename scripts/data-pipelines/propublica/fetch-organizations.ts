import { supabase } from '../shared/database'
import { delay, API_DELAYS } from '../shared/rate-limiter'
import { 
  ProPublicaOrganization, 
  ProPublicaSearchResponse, 
  PROPUBLICA_CONFIG 
} from './types'

// Interface for our database organization
interface Organization {
  uuid: string
  name: string
  ein?: string | null
  ein_related?: string[] | null
  created_at?: string
  updated_at?: string
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

// Process organizations and update database
async function processOrganization(org: Organization): Promise<void> {
  console.log(`\n📊 Processing: ${org.name}`)
  
  // Search ProPublica
  const apiResponse = await searchProPublica(org.name)
  
  // Handle API error
  if (!apiResponse) {
    console.log(`  ❌ API Error - Marking as not found`)
    const { error } = await supabase
      .from('organizations')
      .update({ 
        ein: PROPUBLICA_CONFIG.NO_RESULTS_EIN,
        ein_related: []
      })
      .eq('uuid', org.uuid)
    
    if (error) {
      console.error(`  Error updating organization:`, error)
    }
    return
  }
  
  // Handle no results
  if (apiResponse.total_results === 0) {
    console.log(`  ⚠️ No results found - Marking with placeholder EIN`)
    const { error } = await supabase
      .from('organizations')
      .update({ 
        ein: PROPUBLICA_CONFIG.NO_RESULTS_EIN,
        ein_related: []
      })
      .eq('uuid', org.uuid)
    
    if (error) {
      console.error(`  Error updating organization:`, error)
    }
    return
  }
  
  // Find all organizations with the top score
  const topScore = Math.max(...apiResponse.organizations.map(o => o.score || 0))
  const topMatches = apiResponse.organizations.filter(o => o.score === topScore)
  
  console.log(`  🔍 Found ${topMatches.length} result(s) with top score ${topScore}`)
  
  // Handle single match
  if (topMatches.length === 1) {
    const match = topMatches[0]
    console.log(`  ✅ Single match: ${match.name} (EIN: ${match.strein})`)
    
    const { error } = await supabase
      .from('organizations')
      .update({ 
        name: match.name,
        ein: match.strein,
        ein_related: []
      })
      .eq('uuid', org.uuid)
    
    if (error) {
      console.error(`  Error updating organization:`, error)
    }
    return
  }
  
  // Handle multiple matches
  console.log(`  📝 Multiple matches with same score:`)
  const allEins = topMatches.map(m => m.strein)
  
  // Update the existing record with the first match
  const firstMatch = topMatches[0]
  console.log(`    Updating existing: ${firstMatch.name} (EIN: ${firstMatch.strein})`)
  
  const { error: updateError } = await supabase
    .from('organizations')
    .update({ 
      name: firstMatch.name,
      ein: firstMatch.strein,
      ein_related: allEins.filter(e => e !== firstMatch.strein)
    })
    .eq('uuid', org.uuid)
  
  if (updateError) {
    console.error(`  Error updating organization:`, updateError)
    return
  }
  
  // Insert new records for the remaining matches
  for (let i = 1; i < topMatches.length; i++) {
    const match = topMatches[i]
    console.log(`    Inserting new: ${match.name} (EIN: ${match.strein})`)
    
    // Insert new organization with minimal fields
    const { error: insertError } = await supabase
      .from('organizations')
      .insert({
        name: match.name,
        ein: match.strein,
        ein_related: allEins.filter(e => e !== match.strein)
      })
    
    if (insertError) {
      console.error(`  Error inserting new organization:`, insertError)
    }
  }
}

// Main function
async function main() {
  console.log('🚀 Starting ProPublica data fetch and save...\n')
  
  // Skip schema check - columns have been added via migration
  
  // Fetch organizations without EINs
  console.log('📊 Fetching organizations without EINs...')
  const { data: organizations, error } = await supabase
    .from('organizations')
    .select('*')
    .or(`ein.is.null,ein.eq.${PROPUBLICA_CONFIG.NO_RESULTS_EIN}`)  // Include both null and "not found" markers for re-processing
    .order('name')
  
  if (error) {
    console.error('Error fetching organizations:', error)
    process.exit(1)
  }
  
  if (!organizations || organizations.length === 0) {
    console.log('✅ All organizations already have EINs!')
    process.exit(0)
  }
  
  console.log(`Found ${organizations.length} organizations to process\n`)
  console.log('🔍 Processing each organization...')
  console.log('(Adding 1-second delay between requests to respect rate limits)\n')
  
  // Process each organization
  for (let i = 0; i < organizations.length; i++) {
    const org = organizations[i]
    await processOrganization(org)
    
    // Add delay between requests (except for the last one)
    if (i < organizations.length - 1) {
      await delay(API_DELAYS.PROPUBLICA)
    }
  }
  
  console.log('\n' + '='.repeat(60))
  console.log('✅ Completed ProPublica data fetch and save')
  console.log('='.repeat(60))
  
  // Get summary statistics
  const { data: finalStats, error: statsError } = await supabase
    .from('organizations')
    .select('ein')
  
  if (!statsError && finalStats) {
    const withEin = finalStats.filter(o => o.ein && o.ein !== PROPUBLICA_CONFIG.NO_RESULTS_EIN).length
    const notFound = finalStats.filter(o => o.ein === PROPUBLICA_CONFIG.NO_RESULTS_EIN).length
    const withoutEin = finalStats.filter(o => !o.ein).length
    
    console.log('\n📈 Final Statistics:')
    console.log(`  - Total organizations: ${finalStats.length}`)
    console.log(`  - With valid EIN: ${withEin}`)
    console.log(`  - Not found in ProPublica: ${notFound}`)
    console.log(`  - Still without EIN: ${withoutEin}`)
  }
}

// Run the script
main().catch(console.error)
import Anthropic from '@anthropic-ai/sdk'
import { supabase } from '../shared/database'

// Interface for position data structure
interface Position {
  description: string
  position: 'In favor' | 'Opposed' | 'No position'
  positionDetails: string
  referenceMaterials: string[]
}

interface PositionsResponse {
  organizationName: string
  ein: string
  positions: Position[]
}

// Interface for organization data
interface Organization {
  uuid: string
  name: string
  ein: string | null
  ein_related?: string[] | null
}

// Build the prompt for Claude
function buildPrompt(orgName: string, ein: string): string {
  return `Please analyze the public positions that ${orgName} (EIN: ${ein}) has taken in the last 12 months. Search for their press releases, statements, policy papers, and public communications to identify their stances on key issues.

Format your response as valid JSON with the following structure:

\`\`\`json
{
  "organizationName": "${orgName}",
  "ein": "${ein}", 
  "positions": [
    {
      "description": "[3-5 word description of the issue]",
      "position": "[In favor/Opposed/No position]",
      "positionDetails": "[3-5 sentences describing their specific stance, including key arguments and rationale they've provided]",
      "referenceMaterials": [
        "[URL or citation where this position can be verified]",
        "[Additional supporting links if available]"
      ]
    }
  ]
}
\`\`\`

Focus on substantive policy positions including:
* Legislative and regulatory matters
* Industry-specific regulations and compliance
* Labor and employment policies
* Tax and economic policies
* Health and safety regulations
* Government programs and funding
* Trade and international commerce
* Environmental regulations
* Technology and innovation policies
* Any controversial or politically significant topics

For each position, ensure you:
1. Accurately represent their stated view (don't infer unstated positions)
2. Provide specific details about their reasoning when available
3. Include direct links to source materials where possible
4. Use "No position" only if you find evidence they were asked about an issue but declined to take a stance

DO NOT output anything other than valid JSON. Ensure all URLs are functional and all quotes are accurate.`
}

async function fetchPositionsFromClaude(orgName: string, ein: string): Promise<PositionsResponse | null> {
  try {
    // Get API key from environment
    let apiKey = process.env.ANTHROPIC_API_KEY
    
    if (!apiKey) {
      console.error('❌ Error: ANTHROPIC_API_KEY not found in environment variables')
      console.log('\nTo use this script, you need to add your Anthropic API key:')
      console.log('1. Get your API key from: https://console.anthropic.com/settings/keys')
      console.log('2. Add it to .env.local:')
      console.log('   ANTHROPIC_API_KEY=sk-ant-api03-...')
      console.log('\nNote: CLAUDE_CREDENTIALS OAuth tokens cannot be used with the Anthropic SDK.')
      return null
    }

    console.log(`\n🤖 Querying Claude API for ${orgName} positions...`)
    
    const anthropic = new Anthropic({
      apiKey: apiKey,
    })

    const message = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307', // Using Haiku for cost efficiency
      max_tokens: 4096,
      temperature: 0,
      messages: [
        {
          role: 'user',
          content: buildPrompt(orgName, ein),
        },
      ],
    })

    // Extract the JSON from the response
    const content = message.content[0]
    if (content.type !== 'text') {
      console.error('Unexpected response type from Claude')
      return null
    }

    // Parse the JSON response
    const jsonMatch = content.text.match(/```json\n([\s\S]*?)\n```/)
    const jsonStr = jsonMatch ? jsonMatch[1] : content.text
    
    try {
      const data = JSON.parse(jsonStr) as PositionsResponse
      return data
    } catch (parseError) {
      console.error('Error parsing JSON response:', parseError)
      console.log('Raw response:', content.text)
      return null
    }
  } catch (error) {
    console.error('Error calling Claude API:', error)
    return null
  }
}

async function getAllOrganizationsWithoutPositions(): Promise<Organization[]> {
  try {
    // Get all organizations
    const { data: organizations, error: orgsError } = await supabase
      .from('organizations')
      .select('uuid, name, ein')
    
    if (orgsError) {
      console.error('Error fetching organizations:', orgsError)
      return []
    }

    if (!organizations || organizations.length === 0) {
      console.log('No organizations found')
      return []
    }

    // Get organizations that already have positions
    const { data: existingPositions, error: posError } = await supabase
      .from('org_positions')
      .select('organization_uuid')
    
    if (posError) {
      console.error('Error fetching existing positions:', posError)
      return []
    }

    // Filter out organizations that already have positions
    const existingUuids = new Set(existingPositions?.map(p => p.organization_uuid) || [])
    const orgsWithoutPositions = organizations.filter(org => !existingUuids.has(org.uuid))

    if (orgsWithoutPositions.length === 0) {
      console.log('All organizations already have positions data')
      return []
    }

    return orgsWithoutPositions
  } catch (error) {
    console.error('Error getting organizations:', error)
    return []
  }
}

async function savePositionsToDatabase(
  org: Organization, 
  positions: PositionsResponse
): Promise<boolean> {
  try {
    const { error } = await supabase
      .from('org_positions')
      .insert({
        organization_uuid: org.uuid,
        organization_name: positions.organizationName,
        ein: positions.ein,
        positions: positions.positions,
        fetched_at: new Date().toISOString(),
      })
    
    if (error) {
      console.error('Error saving positions to database:', error)
      return false
    }
    
    return true
  } catch (error) {
    console.error('Error saving to database:', error)
    return false
  }
}

async function main() {
  console.log('🚀 Starting Organization Positions Fetch...\n')
  
  // Check if the org_positions table exists
  const { error: tableCheckError } = await supabase
    .from('org_positions')
    .select('id')
    .limit(1)
  
  if (tableCheckError && tableCheckError.message.includes('relation')) {
    console.error('❌ Table "org_positions" does not exist!')
    console.log('Please run the migration first:')
    console.log('  SQL file: Run the migration to create org_positions table')
    process.exit(1)
  }

  // Get all organizations without positions
  const organizations = await getAllOrganizationsWithoutPositions()
  
  if (organizations.length === 0) {
    console.log('No organizations available to fetch positions for')
    process.exit(0)
  }

  console.log(`📊 Found ${organizations.length} organization(s) without positions\n`)
  console.log('Processing all organizations...\n')
  
  let successCount = 0
  let failureCount = 0
  
  // Process each organization
  for (let i = 0; i < organizations.length; i++) {
    const org = organizations[i]
    console.log('='.repeat(80))
    console.log(`Processing ${i + 1} of ${organizations.length}: ${org.name}`)
    console.log(`EIN: ${org.ein || 'No EIN'}`)
    console.log('='.repeat(80))
    
    // Fetch positions from Claude
    const positions = await fetchPositionsFromClaude(org.name, org.ein || 'Unknown')
    
    if (!positions) {
      console.log('⚠️  Failed to fetch positions from Claude API')
      failureCount++
      
      // Add delay before next request even on failure
      if (i < organizations.length - 1) {
        console.log('Waiting 2 seconds before next request...\n')
        await new Promise(resolve => setTimeout(resolve, 2000))
      }
      continue
    }

    // Display the results
    console.log('\n📋 Positions found:')
    if (positions.positions.length > 0) {
      positions.positions.forEach((pos, index) => {
        console.log(`  ${index + 1}. ${pos.description} - ${pos.position}`)
      })
    } else {
      console.log('  No positions found')
    }

    // Save to database
    console.log('\n💾 Saving to database...')
    const saved = await savePositionsToDatabase(org, positions)
    
    if (saved) {
      console.log('✅ Successfully saved positions to database')
      successCount++
    } else {
      console.log('⚠️  Failed to save to database')
      failureCount++
    }
    
    // Add delay between API calls (except for the last one)
    if (i < organizations.length - 1) {
      console.log('\nWaiting 2 seconds before next request...\n')
      await new Promise(resolve => setTimeout(resolve, 2000))
    }
  }
  
  // Final summary
  console.log('\n' + '='.repeat(80))
  console.log('📈 FINAL SUMMARY')
  console.log('='.repeat(80))
  console.log(`  Total organizations processed: ${organizations.length}`)
  console.log(`  ✅ Successfully saved: ${successCount}`)
  console.log(`  ⚠️  Failed: ${failureCount}`)
  console.log('='.repeat(80))
}

// Run the script
main().catch(console.error)
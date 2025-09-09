import { supabase } from '../shared/database'
import { PROPUBLICA_CONFIG } from './types'

async function checkData() {
  const { data, error } = await supabase
    .from('organizations')
    .select('name, ein, ein_related')
    .order('name')
  
  if (data) {
    console.log('Organizations with EINs:')
    data.forEach(org => {
      if (org.ein && org.ein !== PROPUBLICA_CONFIG.NO_RESULTS_EIN) {
        console.log(`  ${org.name}: EIN=${org.ein}, Related=${org.ein_related?.length || 0} others`)
      }
    })
    
    console.log('\nOrganizations without EINs:')
    data.forEach(org => {
      if (!org.ein || org.ein === PROPUBLICA_CONFIG.NO_RESULTS_EIN) {
        console.log(`  ${org.name}`)
      }
    })
    
    console.log(`\nTotal: ${data.length} organizations`)
  }
  if (error) console.error('Error:', error)
}

checkData()
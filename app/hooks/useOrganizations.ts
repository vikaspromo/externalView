/**
 * Custom hook for managing organizations data
 */

import { useEffect, useState, useCallback } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { Organization, ClientOrganizationHistory } from '@/lib/supabase/types'

export interface OrganizationsState {
  organizations: Organization[]
  orgDetails: Record<string, (ClientOrganizationHistory & { positions?: any[] }) | null>
  expandedRows: Set<string>
  loadOrganizations: (clientUuid: string) => Promise<void>
  fetchOrgDetails: (orgId: string, clientUuid: string) => Promise<void>
  toggleRowExpansion: (orgId: string, clientUuid: string) => Promise<void>
}

/**
 * Hook to manage organizations data and expansion state
 */
export const useOrganizations = (): OrganizationsState => {
  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [orgDetails, setOrgDetails] = useState<Record<string, (ClientOrganizationHistory & { positions?: any[] }) | null>>({})
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set())
  const supabase = createClientComponentClient()

  const loadOrganizations = useCallback(async (clientUuid: string) => {
    try {
      // Get organizations for this client by joining client_org_history with organizations
      const { data: relationshipData, error: relationshipError } = await supabase
        .from('client_org_history')
        .select(`
          client_uuid,
          org_uuid,
          annual_total_spend,
          relationship_owner,
          renewal_date,
          policy_alignment_score,
          organizations!org_uuid (
            name
          )
        `)
        .eq('client_uuid', clientUuid)
      
      if (relationshipError) {
        console.error('Error fetching client organization relationships:', relationshipError)
        setOrganizations([])
      } else {
        // Keep the full relationship data for table display
        const transformedOrgs = relationshipData?.map(rel => ({
          id: rel.org_uuid || '',
          name: (rel.organizations as any)?.name || '',
          alignment_score: rel.policy_alignment_score || 0,
          total_spend: rel.annual_total_spend || 0,
          owner: rel.relationship_owner || '',
          renewal_date: rel.renewal_date || '',
          created_at: '',
          updated_at: ''
        })) || []
        setOrganizations(transformedOrgs)
      }
    } catch (error) {
      console.error('Error in loadOrganizations:', error)
    }
  }, [supabase])

  const fetchOrgDetails = useCallback(async (orgId: string, clientUuid: string) => {
    try {
      // Fetch from client_org_history
      const { data: historyData, error: historyError } = await supabase
        .from('client_org_history')
        .select('*')
        .eq('client_uuid', clientUuid)
        .eq('org_uuid', orgId)
        .maybeSingle()
      
      // Fetch organization positions
      const { data: positionsData } = await supabase
        .from('organization_positions')
        .select('positions')
        .eq('organization_uuid', orgId)
        .maybeSingle()
      
      if (historyError) {
        console.error('Error fetching organization details:', historyError)
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: null
        }))
      } else {
        // Combine history data with positions
        const combinedData = {
          ...(historyData as ClientOrganizationHistory),
          positions: positionsData?.positions || []
        }
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: combinedData
        }))
      }
    } catch (error) {
      console.error('Unexpected error in fetchOrgDetails:', error)
      setOrgDetails(prev => ({
        ...prev,
        [orgId]: null
      }))
    }
  }, [supabase])

  const toggleRowExpansion = useCallback(async (orgId: string, clientUuid: string) => {
    const newExpandedRows = new Set(expandedRows)
    if (newExpandedRows.has(orgId)) {
      newExpandedRows.delete(orgId)
    } else {
      newExpandedRows.add(orgId)
      // Fetch detailed data if not already loaded
      if (!orgDetails[orgId] && clientUuid) {
        await fetchOrgDetails(orgId, clientUuid)
      }
    }
    setExpandedRows(newExpandedRows)
  }, [expandedRows, orgDetails, fetchOrgDetails])

  return {
    organizations,
    orgDetails,
    expandedRows,
    loadOrganizations,
    fetchOrgDetails,
    toggleRowExpansion
  }
}
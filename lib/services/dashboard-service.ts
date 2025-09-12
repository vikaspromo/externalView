/**
 * Dashboard Service Layer
 * Encapsulates all data access for the dashboard with built-in security checks
 * This provides a clean separation between UI and data/security logic
 */

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { Client, ClientOrganizationHistory, User } from '@/lib/supabase/types'
import { requireClientAccess, validateClientAccess, logSecurityEvent } from '@/lib/utils/access-control'
import { logger } from '@/lib/utils/logger'

export class DashboardService {
  private supabase = createClientComponentClient()

  /**
   * Load clients based on user permissions
   */
  async loadClients(userData: User | null, isAdmin: boolean): Promise<Client[]> {
    try {
      if (!userData) {
        return []
      }

      if (isAdmin) {
        // Admin: Load all clients
        const { data, error } = await this.supabase
          .from('clients')
          .select('uuid, name')
          .order('name', { ascending: true })
        
        if (error) {
          logger.error('Error fetching clients', error)
          return []
        }
        
        return data || []
      } else if (userData.client_uuid) {
        // Regular user: Load only their client
        const { data, error } = await this.supabase
          .from('clients')
          .select('uuid, name')
          .eq('uuid', userData.client_uuid)
          .single()
        
        if (error) {
          logger.error('Error fetching user client', error)
          return []
        }
        
        return data ? [data] : []
      }
      
      return []
    } catch (error) {
      logger.error('Error loading clients', error)
      return []
    }
  }

  /**
   * Load organizations for a specific client with security checks
   */
  async loadOrganizations(
    clientUuid: string,
    userData: User | null,
    isAdmin: boolean
  ): Promise<any[]> {
    try {
      // Validate access before fetching
      if (!validateClientAccess(clientUuid, userData, isAdmin)) {
        logSecurityEvent({
          event_type: 'access_denied',
          user_id: userData?.id,
          client_uuid: userData?.client_uuid,
          target_client_uuid: clientUuid,
          operation: 'load_organizations',
          metadata: {},
        })
        return []
      }

      const { data, error } = await this.supabase
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
      
      if (error) {
        logger.error('Error fetching organizations', error)
        return []
      }

      // Transform the data for UI consumption
      return (data || []).map(rel => ({
        id: rel.org_uuid || '',
        name: (rel.organizations as any)?.name || '',
        alignment_score: rel.policy_alignment_score || 0,
        total_spend: rel.annual_total_spend || 0,
        owner: rel.relationship_owner || '',
        renewal_date: rel.renewal_date || '',
        created_at: '',
        updated_at: '',
      }))
    } catch (error) {
      logger.error('Error in loadOrganizations', error)
      return []
    }
  }

  /**
   * Update organization notes with security validation
   */
  async updateOrgNotes(
    orgId: string,
    notes: string,
    selectedClientUuid: string,
    userData: User | null,
    isAdmin: boolean
  ): Promise<void> {
    // Validate client access before attempting update
    requireClientAccess(
      selectedClientUuid,
      userData,
      isAdmin,
      'update organization notes'
    )

    const { error } = await this.supabase
      .from('client_org_history')
      .update({ notes, updated_at: new Date().toISOString() })
      .eq('client_uuid', selectedClientUuid)
      .eq('org_uuid', orgId)

    if (error) {
      // Log security event if unauthorized
      if (error.message?.includes('Unauthorized') || error.code === '42501') {
        logSecurityEvent({
          event_type: 'unauthorized_attempt',
          user_id: userData?.id,
          client_uuid: userData?.client_uuid,
          target_client_uuid: selectedClientUuid,
          operation: 'update_org_notes',
          metadata: { orgId, error: error.message },
        })
      }
      throw error
    }
  }

  /**
   * Fetch organization details with security checks
   */
  async fetchOrgDetails(
    orgId: string,
    selectedClientUuid: string,
    userData: User | null,
    isAdmin: boolean
  ): Promise<ClientOrganizationHistory & { positions?: any[] } | null> {
    // Validate client access before fetching details
    if (!validateClientAccess(selectedClientUuid, userData, isAdmin)) {
      logSecurityEvent({
        event_type: 'access_denied',
        user_id: userData?.id,
        client_uuid: userData?.client_uuid,
        target_client_uuid: selectedClientUuid,
        operation: 'fetch_org_details',
        metadata: { orgId },
      })
      return null
    }

    try {
      // Fetch from client_org_history
      const { data: historyData, error: historyError } = await this.supabase
        .from('client_org_history')
        .select('*')
        .eq('client_uuid', selectedClientUuid)
        .eq('org_uuid', orgId)
        .maybeSingle()
      
      // Fetch organization positions
      const { data: positionsData } = await this.supabase
        .from('org_positions')
        .select('positions')
        .eq('organization_uuid', orgId)
        .maybeSingle()
      
      if (historyError) {
        logger.error('Error fetching organization details', historyError)
        return null
      }

      // Combine history data with positions
      return {
        ...(historyData as ClientOrganizationHistory),
        positions: positionsData?.positions || [],
      }
    } catch (error) {
      logger.error('Unexpected error in fetchOrgDetails', error)
      return null
    }
  }
}

// Export singleton instance
export const dashboardService = new DashboardService()
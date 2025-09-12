'use client'

import React, { useEffect, useState, useMemo, useCallback } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { Organization, Client, ClientOrganizationHistory } from '@/lib/supabase/types'
import { SortField, SortDirection } from '@/lib/types/dashboard'
import { formatCurrency, formatDate } from '@/app/utils/formatters'
import { AdminClientToggle } from '@/app/components/dashboard/AdminClientToggle'
import { EditableText } from '@/app/components/ui/EditableText'
import { Pagination } from '@/app/components/ui/Pagination'
import { useAuth } from '@/app/hooks/useAuth'
import { requireClientAccess, validateClientAccess, logSecurityEvent } from '@/lib/utils/access-control'
import { logger } from '@/lib/utils/logger'

export default function DashboardPage() {
  const { user, userData, isLoading: authLoading, isAdmin, signOut } = useAuth()
  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [selectedClientUuid, setSelectedClientUuid] = useState<string>('')
  const [selectedClient, setSelectedClient] = useState<Client | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [sortField, setSortField] = useState<SortField>('name')
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc')
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set())
  const [orgDetails, setOrgDetails] = useState<Record<string, (ClientOrganizationHistory & { positions?: any[] }) | null>>({})
  const [currentPage, setCurrentPage] = useState(1)
  const [itemsPerPage] = useState(100)
  const router = useRouter()
  const supabase = createClientComponentClient()

  // Load clients based on user type
  useEffect(() => {
    const loadClients = async () => {
      if (!user || !userData) {
        return
      }

      try {
        if (isAdmin) {
          // Admin: Load all clients
          const { data: clientsData, error: clientsError } = await supabase
            .from('clients')
            .select('uuid, name')
            .order('name', { ascending: true })
          
          if (clientsError) {
            logger.error('Error fetching clients', clientsError)
          } else if (clientsData) {
            setClients(clientsData)
            
            // Set initial client selection
            if (userData.client_uuid) {
              // Use user's default client if they have one
              const userClient = clientsData.find(c => c.uuid === userData.client_uuid)
              if (userClient) {
                setSelectedClientUuid(userClient.uuid)
                setSelectedClient(userClient)
              }
            } else if (clientsData.length > 0) {
              // Otherwise use first client
              setSelectedClientUuid(clientsData[0].uuid)
              setSelectedClient(clientsData[0])
            }
          }
        } else if (userData.client_uuid) {
          // Regular user: Load only their client
          const { data: clientData, error: clientError } = await supabase
            .from('clients')
            .select('uuid, name')
            .eq('uuid', userData.client_uuid)
            .single()
          
          if (clientError) {
            logger.error('Error fetching user client', clientError)
          } else if (clientData) {
            setClients([clientData])
            setSelectedClientUuid(clientData.uuid)
            setSelectedClient(clientData)
          }
        }
      } catch (error) {
        logger.error('Error loading clients', error)
      } finally {
        setIsLoading(false)
      }
    }

    if (!authLoading) {
      loadClients()
    }
  }, [user, userData, isAdmin, authLoading, supabase])

  // Load organizations for selected client
  const loadOrganizations = useCallback(async (clientUuid: string) => {
    try {
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
        logger.error('Error fetching client organization relationships', relationshipError)
        setOrganizations([])
      } else {
        const transformedOrgs = relationshipData?.map(rel => ({
          id: rel.org_uuid || '',
          name: (rel.organizations as any)?.name || '',
          alignment_score: rel.policy_alignment_score || 0,
          total_spend: rel.annual_total_spend || 0,
          owner: rel.relationship_owner || '',
          renewal_date: rel.renewal_date || '',
          created_at: '',
          updated_at: '',
        })) || []
        setOrganizations(transformedOrgs)
      }
    } catch (error) {
      logger.error('Error in loadOrganizations', error)
    }
  }, [supabase])

  // Load organizations when selectedClientUuid changes
  useEffect(() => {
    if (selectedClientUuid) {
      loadOrganizations(selectedClientUuid)
    }
  }, [selectedClientUuid, loadOrganizations])

  // Sorting logic
  const sortedOrganizations = useMemo(() => {
    const sorted = [...organizations].sort((a, b) => {
      let aValue: any = a[sortField]
      let bValue: any = b[sortField]

      if (aValue == null) aValue = 0
      if (bValue == null) bValue = 0

      if (sortField === 'name') {
        aValue = aValue.toLowerCase()
        bValue = bValue.toLowerCase()
        return sortDirection === 'asc' 
          ? aValue.localeCompare(bValue)
          : bValue.localeCompare(aValue)
      }

      return sortDirection === 'asc' 
        ? aValue - bValue 
        : bValue - aValue
    })
    
    return sorted
  }, [organizations, sortField, sortDirection])

  // Paginated organizations
  const paginatedOrganizations = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage
    const endIndex = startIndex + itemsPerPage
    return sortedOrganizations.slice(startIndex, endIndex)
  }, [sortedOrganizations, currentPage, itemsPerPage])

  const totalPages = Math.ceil(sortedOrganizations.length / itemsPerPage)

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortField(field)
      setSortDirection('desc')
    }
    setCurrentPage(1)
  }

  const handlePageChange = (page: number) => {
    setCurrentPage(page)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const toggleRowExpansion = async (orgId: string) => {
    const newExpandedRows = new Set(expandedRows)
    if (newExpandedRows.has(orgId)) {
      newExpandedRows.delete(orgId)
    } else {
      newExpandedRows.add(orgId)
      if (!orgDetails[orgId] && selectedClientUuid) {
        await fetchOrgDetails(orgId)
      }
    }
    setExpandedRows(newExpandedRows)
  }

  const updateOrgNotes = async (orgId: string, notes: string) => {
    try {
      // Validate client access before attempting update
      requireClientAccess(
        selectedClientUuid,
        userData,
        isAdmin,
        'update organization notes'
      )

      const { error } = await supabase
        .from('client_org_history')
        .update({ notes, updated_at: new Date().toISOString() })
        .eq('client_uuid', selectedClientUuid)
        .eq('org_uuid', orgId)

      if (error) {
        throw error
      }

      setOrgDetails(prev => ({
        ...prev,
        [orgId]: prev[orgId] ? { ...prev[orgId], notes } : null,
      }))
    } catch (error) {
      logger.error('Error updating notes', error)
      
      // Log security events for unauthorized attempts
      if (error instanceof Error && error.message.includes('Unauthorized')) {
        logSecurityEvent({
          event_type: 'unauthorized_attempt',
          user_id: user?.id,
          client_uuid: userData?.client_uuid,
          target_client_uuid: selectedClientUuid,
          operation: 'update_org_notes',
          metadata: { orgId },
        })
      }
      
      throw new Error('Failed to save notes')
    }
  }

  const fetchOrgDetails = async (orgId: string) => {
    try {
      // Validate client access before fetching details
      if (!validateClientAccess(selectedClientUuid, userData, isAdmin)) {
        logSecurityEvent({
          event_type: 'access_denied',
          user_id: user?.id,
          client_uuid: userData?.client_uuid,
          target_client_uuid: selectedClientUuid,
          operation: 'fetch_org_details',
          metadata: { orgId },
        })
        return
      }

      const { data: historyData, error: historyError } = await supabase
        .from('client_org_history')
        .select('*')
        .eq('client_uuid', selectedClientUuid)
        .eq('org_uuid', orgId)
        .maybeSingle()
      
      const { data: positionsData } = await supabase
        .from('org_positions')
        .select('positions')
        .eq('organization_uuid', orgId)
        .maybeSingle()
      
      if (historyError) {
        logger.error('Error fetching organization details', historyError)
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: null,
        }))
      } else {
        const combinedData = {
          ...(historyData as ClientOrganizationHistory),
          positions: positionsData?.positions || [],
        }
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: combinedData,
        }))
      }
    } catch (error) {
      logger.error('Unexpected error in fetchOrgDetails', error)
      setOrgDetails(prev => ({
        ...prev,
        [orgId]: null,
      }))
    }
  }

  // Show loading state
  if (authLoading || isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  // Redirect if not authenticated
  if (!user || !userData) {
    router.push('/')
    return null
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              {selectedClient && (
                <h1 className="text-2xl font-bold tracking-wide text-gray-900">
                  {selectedClient.name}
                </h1>
              )}
              {/* Only show client switcher for admins with multiple clients */}
              {isAdmin && clients.length > 1 && (
                <AdminClientToggle
                  clients={clients}
                  selectedClientUuid={selectedClientUuid}
                  selectedClient={selectedClient}
                  onClientChange={(client) => {
                    setSelectedClientUuid(client.uuid)
                    setSelectedClient(client)
                    setCurrentPage(1)
                  }}
                />
              )}
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-500">
                Welcome, {user.user_metadata?.full_name || user.email}
                {isAdmin && <span className="ml-2 text-xs bg-gray-100 px-2 py-1 rounded">Admin</span>}
              </div>
              <button
                onClick={signOut}
                className="bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-700 transition-colors"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">

        {/* Portfolio Card */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-semibold text-gray-900">Portfolio</h2>
          </div>
          <div className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <p className="text-sm font-medium text-gray-700 mb-2">Total Investment</p>
                <p className="text-2xl font-semibold text-gray-900">
                  {formatCurrency(organizations.reduce((sum, org) => sum + (org.total_spend || 0), 0))}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-gray-700 mb-2">Overall Alignment</p>
                <p className="text-2xl font-semibold text-gray-900">
                  {(() => {
                    const orgsWithScores = organizations.filter(org => org.alignment_score != null)
                    if (orgsWithScores.length === 0) return '-'
                    const avgScore = orgsWithScores.reduce((sum, org) => sum + (org.alignment_score || 0), 0) / orgsWithScores.length
                    return Math.round(avgScore) + '%'
                  })()}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-gray-700 mb-2">Reallocation Opportunity</p>
                <div>
                  <p className="text-2xl font-semibold text-gray-900">
                    {(() => {
                      const sixMonthsFromNow = new Date()
                      sixMonthsFromNow.setMonth(sixMonthsFromNow.getMonth() + 6)
                      
                      const atRiskTotal = organizations.reduce((sum, org) => {
                        if (!org.renewal_date) return sum
                        const renewalDate = new Date(org.renewal_date)
                        if (renewalDate <= sixMonthsFromNow) {
                          return sum + (org.total_spend || 0)
                        }
                        return sum
                      }, 0)
                      
                      return formatCurrency(atRiskTotal)
                    })()}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">Next 6 months</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Organizations Section */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-semibold text-gray-900">Organizations</h2>
          </div>
          
          <div className="p-6">
            {organizations.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th 
                        className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                        onClick={() => handleSort('name')}
                      >
                        <div className="flex items-center">
                          Organization
                          {sortField === 'name' && (
                            <span className="ml-1">
                              {sortDirection === 'asc' ? '↑' : '↓'}
                            </span>
                          )}
                        </div>
                      </th>
                      <th 
                        className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                        onClick={() => handleSort('alignment_score')}
                      >
                        <div className="flex items-center">
                          Alignment
                          {sortField === 'alignment_score' && (
                            <span className="ml-1">
                              {sortDirection === 'asc' ? '↑' : '↓'}
                            </span>
                          )}
                        </div>
                      </th>
                      <th 
                        className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                        onClick={() => handleSort('total_spend')}
                      >
                        <div className="flex items-center">
                          Investment
                          {sortField === 'total_spend' && (
                            <span className="ml-1">
                              {sortDirection === 'asc' ? '↑' : '↓'}
                            </span>
                          )}
                        </div>
                      </th>
                      <th 
                        className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                        onClick={() => handleSort('renewal_date')}
                      >
                        <div className="flex items-center">
                          Renewal Date
                          {sortField === 'renewal_date' && (
                            <span className="ml-1">
                              {sortDirection === 'asc' ? '↑' : '↓'}
                            </span>
                          )}
                        </div>
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Relationship Owner
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {paginatedOrganizations.map((org) => (
                      <React.Fragment key={org.id}>
                        <tr className="hover:bg-gray-50 cursor-pointer" onClick={() => toggleRowExpansion(org.id)}>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <button className="mr-3 text-gray-400 hover:text-gray-600">
                                {expandedRows.has(org.id) ? (
                                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                                  </svg>
                                ) : (
                                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                  </svg>
                                )}
                              </button>
                              <div className="text-sm text-gray-900">
                                {org.name}
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="text-sm text-gray-900">
                                {org.alignment_score ? `${org.alignment_score}%` : '-'}
                              </div>
                              {org.alignment_score && (
                                <div className="ml-2 w-16 bg-gray-200 rounded-full h-2">
                                  <div 
                                    className="bg-primary-600 h-2 rounded-full" 
                                    style={{ width: `${Math.min(org.alignment_score, 100)}%` }}
                                  />
                                </div>
                              )}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {org.total_spend ? formatCurrency(org.total_spend) : '-'}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {org.renewal_date ? formatDate(org.renewal_date) : '-'}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {org.owner || '-'}
                          </td>
                        </tr>
                        {expandedRows.has(org.id) && (
                          <tr>
                            <td colSpan={6} className="px-6 py-6 bg-gray-50">
                              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                                {orgDetails[org.id] ? (
                                  <>
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                      <div>
                                        <EditableText
                                          label="Notes"
                                          value={orgDetails[org.id]?.notes || ''}
                                          onSave={(newNotes) => updateOrgNotes(org.id, newNotes)}
                                          placeholder="Add notes about this organization..."
                                          multiline={true}
                                          maxLength={2000}
                                          className="text-sm"
                                        />
                                      </div>
                                      
                                      <div>
                                        <h5 className="text-sm font-medium text-gray-700 mb-2">Key Organization Contacts</h5>
                                        {(orgDetails[org.id]?.key_external_contacts?.length ?? 0) > 0 ? (
                                          <ul className="space-y-1">
                                            {orgDetails[org.id]?.key_external_contacts?.map((contact, index) => (
                                              <li key={index} className="text-sm text-gray-600 flex items-start">
                                                <span className="text-gray-400 mr-2">•</span>
                                                <span>{contact}</span>
                                              </li>
                                            ))}
                                          </ul>
                                        ) : (
                                          <p className="text-sm text-gray-500">No contacts listed</p>
                                        )}
                                      </div>
                                    </div>
                                    
                                    {(orgDetails[org.id]?.positions?.length ?? 0) > 0 && (
                                    <div className="mt-6">
                                      <h5 className="text-sm font-medium text-gray-700 mb-3">
                                        Policy Positions ({orgDetails[org.id]?.positions?.length || 0})
                                      </h5>
                                      <div className="space-y-3">
                                        {orgDetails[org.id]?.positions?.sort((a: any, b: any) => {
                                          const order: { [key: string]: number } = {
                                            'In favor': 1,
                                            'Opposed': 2,
                                            'No position': 3,
                                          }
                                          return (order[a.position] || 999) - (order[b.position] || 999)
                                        }).map((position: any, index: number) => (
                                          <div key={index} className="border border-gray-200 rounded-lg p-4">
                                            <div className="flex justify-between items-start mb-2">
                                              <h6 className="text-sm font-medium text-gray-900">{position.description}</h6>
                                              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                                position.position === 'In favor' 
                                                  ? 'bg-green-100 text-green-800'
                                                  : position.position === 'Opposed'
                                                  ? 'bg-red-100 text-red-800'
                                                  : 'bg-gray-100 text-gray-800'
                                              }`}>
                                                {position.position}
                                              </span>
                                            </div>
                                            
                                            <p className="text-sm text-gray-600 mb-3">
                                              {position.positionDetails}
                                            </p>
                                            
                                            {position.referenceMaterials && position.referenceMaterials.length > 0 && (
                                              <div>
                                                <p className="text-xs font-medium text-gray-500 mb-1">References:</p>
                                                <ul className="space-y-1">
                                                  {position.referenceMaterials.map((ref: string, refIndex: number) => (
                                                    <li key={refIndex} className="text-xs">
                                                      {ref.startsWith('http') ? (
                                                        <a 
                                                          href={ref} 
                                                          target="_blank" 
                                                          rel="noopener noreferrer"
                                                          className="text-blue-600 hover:text-blue-800 underline"
                                                        >
                                                          {ref}
                                                        </a>
                                                      ) : (
                                                        <span className="text-gray-500">• {ref}</span>
                                                      )}
                                                    </li>
                                                  ))}
                                                </ul>
                                              </div>
                                            )}
                                          </div>
                                        ))}
                                      </div>
                                    </div>
                                  )}
                                  </>
                                ) : (
                                  <div className="text-center py-4">
                                    <p className="text-sm text-gray-500">No relationship data available for this organization</p>
                                    <p className="text-xs text-gray-400 mt-2">Add relationship details to start tracking this organization</p>
                                  </div>
                                )}
                              </div>
                            </td>
                          </tr>
                        )}
                      </React.Fragment>
                    ))}
                  </tbody>
                </table>
                {sortedOrganizations.length > itemsPerPage && (
                  <Pagination
                    currentPage={currentPage}
                    totalPages={totalPages}
                    totalItems={sortedOrganizations.length}
                    itemsPerPage={itemsPerPage}
                    onPageChange={handlePageChange}
                  />
                )}
              </div>
            ) : (
              <div className="text-center py-12">
                <div className="text-gray-400 mb-4">
                  <svg className="mx-auto h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">No Organizations Yet</h3>
                <p className="text-gray-500 mb-4">
                  Start building your stakeholder intelligence by adding organizations to track.
                </p>
                <button className="bg-primary-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-primary-700 transition-colors">
                  Add First Organization
                </button>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  )
}
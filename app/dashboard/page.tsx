'use client'

import React, { useEffect, useState, useMemo, useCallback } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { User, Organization, Client, ClientOrganizationHistory } from '@/lib/supabase/types'
import { SortField, SortDirection } from '@/lib/types/dashboard'
import { formatCurrency, formatDate, formatFieldValue } from '@/app/utils/formatters'





export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<User | null>(null)
  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [selectedClientUuid, setSelectedClientUuid] = useState<string>('')
  const [selectedClient, setSelectedClient] = useState<Client | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [sortField, setSortField] = useState<SortField>('name')
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc')
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set())
  const [orgDetails, setOrgDetails] = useState<Record<string, (ClientOrganizationHistory & { positions?: any[] }) | null>>({})
  const [isDropdownOpen, setIsDropdownOpen] = useState(false)
  const router = useRouter()
  const supabase = createClientComponentClient()

  useEffect(() => {
    const getUser = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        
        if (!session?.user) {
          router.push('/')
          return
        }

        setUser(session.user)
        
        // Get user details from users table
        const { data: userData } = await supabase
          .from('users')
          .select('*')
          .eq('email', session.user.email)
          .single()
        
        if (!userData) {
          router.push('/')
          return
        }
        
        setUserData(userData)
        
        // Initialize organizations as empty - will be loaded after client selection
        setOrganizations([])

        // Get all clients from clients table
        const { data: clientsData, error: clientsError } = await supabase
          .from('clients')
          .select('uuid, name')
          .order('name', { ascending: true })
        
        if (clientsError) {
          console.error('Error fetching clients:', clientsError)
        } else {
          console.log('Clients data:', clientsData)
          setClients(clientsData || [])
          
          // Set the user's client UUID as the default selected client UUID
          if (userData.client_uuid) {
            setSelectedClientUuid(userData.client_uuid)
            
            // Also set the selectedClient object for display purposes
            if (clientsData) {
              const userClient = clientsData.find(client => client.uuid === userData.client_uuid)
              if (userClient) {
                setSelectedClient(userClient)
              }
            }
          }
        }
      } catch (error) {
        console.error('Error loading dashboard:', error)
        router.push('/')
      } finally {
        setIsLoading(false)
      }
    }

    getUser()
  }, [supabase, router])

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
        // No fallback - organizations are only shown through client relationships
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

  // Load organizations when selectedClientUuid changes
  useEffect(() => {
    if (selectedClientUuid) {
      loadOrganizations(selectedClientUuid)
    }
  }, [selectedClientUuid, loadOrganizations])

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
  }

  // Handle clicking outside dropdown to close it
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement
      if (!target.closest('#client-dropdown-container')) {
        setIsDropdownOpen(false)
      }
    }

    if (isDropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isDropdownOpen])

  // Sorting logic
  const sortedOrganizations = useMemo(() => {
    const sorted = [...organizations].sort((a, b) => {
      let aValue: any = a[sortField]
      let bValue: any = b[sortField]

      // Handle null/undefined values
      if (aValue == null) aValue = 0
      if (bValue == null) bValue = 0

      // String comparison for name
      if (sortField === 'name') {
        aValue = aValue.toLowerCase()
        bValue = bValue.toLowerCase()
        return sortDirection === 'asc' 
          ? aValue.localeCompare(bValue)
          : bValue.localeCompare(aValue)
      }

      // Numeric comparison for other fields
      return sortDirection === 'asc' 
        ? aValue - bValue 
        : bValue - aValue
    })
    
    return sorted
  }, [organizations, sortField, sortDirection])

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      // Toggle direction if clicking the same field
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      // Set new field with appropriate default direction
      setSortField(field)
      setSortDirection('desc')
    }
  }

  const toggleRowExpansion = async (orgId: string) => {
    const newExpandedRows = new Set(expandedRows)
    if (newExpandedRows.has(orgId)) {
      newExpandedRows.delete(orgId)
    } else {
      newExpandedRows.add(orgId)
      // Fetch detailed data if not already loaded
      if (!orgDetails[orgId] && selectedClientUuid) {
        await fetchOrgDetails(orgId)
      }
    }
    setExpandedRows(newExpandedRows)
  }

  const fetchOrgDetails = async (orgId: string) => {
    try {
      // Fetch from client_org_history
      const { data: historyData, error: historyError } = await supabase
        .from('client_org_history')
        .select('*')
        .eq('client_uuid', selectedClientUuid)
        .eq('org_uuid', orgId)
        .maybeSingle()
      
      // Fetch organization positions
      const { data: positionsData, error: positionsError } = await supabase
        .from('org_positions')
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
  }  // End of fetchOrgDetails function

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  if (!user || !userData) {
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
              {userData?.client_uuid === '36fee78e-9bac-4443-9339-6f53003d3250' && (
                <div id="client-dropdown-container" className="relative">
                  <button
                    onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                    className="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-md transition-colors"
                    aria-label="Switch company"
                  >
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  
                  {isDropdownOpen && (
                    <div className="absolute left-0 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50">
                      <div className="py-1" role="menu" aria-orientation="vertical">
                        <div className="px-4 py-2 text-xs text-gray-500 font-semibold uppercase tracking-wider">
                          Switch Company
                        </div>
                        {clients.map((client) => (
                          <button
                            key={client.uuid}
                            onClick={() => {
                              setSelectedClientUuid(client.uuid)
                              setSelectedClient(client)
                              setIsDropdownOpen(false)
                            }}
                            className={`w-full text-left px-4 py-2 text-sm hover:bg-gray-100 ${
                              selectedClientUuid === client.uuid ? 'bg-gray-50 font-medium' : ''
                            }`}
                            role="menuitem"
                          >
                            {client.name}
                            {selectedClientUuid === client.uuid && (
                              <span className="ml-2 text-primary-600">✓</span>
                            )}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-600">
                Welcome, {user.user_metadata?.full_name || user.email}
              </div>
              <button
                onClick={handleSignOut}
                className="bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-700 transition-colors"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

        {/* Organizations Section */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Organizations</h2>
            <p className="text-sm text-gray-600 mt-1">
              Manage stakeholder relationships across your target organizations
            </p>
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
                          Alignment Score
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
                          Budget
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
                    {sortedOrganizations.map((org) => (
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
                              <div className="text-sm font-medium text-gray-900">
                                {org.name}
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="text-sm font-medium text-gray-900">
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
                                      {/* Left side - Notes */}
                                      <div>
                                        <h5 className="text-sm font-semibold text-gray-700 mb-2">Notes</h5>
                                        <p className="text-sm text-gray-600">
                                          {orgDetails[org.id]?.notes || 'No notes available'}
                                        </p>
                                      </div>
                                      
                                      {/* Right side - Key External Contacts */}
                                      <div>
                                        <h5 className="text-sm font-semibold text-gray-700 mb-2">Key Organization Contacts</h5>
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
                                    
                                    {/* Policy Positions Card */}
                                    {(orgDetails[org.id]?.positions?.length ?? 0) > 0 && (
                                    <div className="mt-6">
                                      <h5 className="text-sm font-semibold text-gray-700 mb-4">
                                        Policy Positions ({orgDetails[org.id]?.positions?.length || 0})
                                      </h5>
                                      <div className="space-y-4">
                                        {orgDetails[org.id]?.positions?.map((position: any, index: number) => (
                                          <div key={index} className="border border-gray-200 rounded-lg p-4">
                                            {/* Position Header */}
                                            <div className="flex justify-between items-start mb-2">
                                              <h6 className="font-medium text-gray-900">{position.description}</h6>
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
                                            
                                            {/* Position Details */}
                                            <p className="text-sm text-gray-600 mb-3">
                                              {position.positionDetails}
                                            </p>
                                            
                                            {/* Reference Materials */}
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
              </div>
            ) : (
              <div className="text-center py-12">
                <div className="text-gray-400 mb-4">
                  <svg className="mx-auto h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">No Organizations Yet</h3>
                <p className="text-gray-600 mb-4">
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
'use client'

import React from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { useEffect, useState, useMemo, useCallback } from 'react'
import { User, Organization, Client, ClientOrganizationHistory } from '@/lib/supabase/types'

type SortField = 'name' | 'alignment_score' | 'total_spend'
type SortDirection = 'asc' | 'desc'

// Helper function to format currency values
const formatCurrency = (value: number | string): string => {
  const num = typeof value === 'string' ? parseFloat(value) : value
  if (isNaN(num)) return String(value)
  return `$${num.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}

// Helper function to check if a field name is likely a currency field
const isCurrencyField = (key: string): boolean => {
  const currencyKeywords = [
    'amount', 'spend', 'budget', 'cost', 'price', 'fee', 'revenue', 
    'dues', 'payment', 'sponsorship', 'value', 'salary', 'income',
    'expense', 'total', 'subtotal', 'balance', 'credit', 'debit'
  ]
  const lowerKey = key.toLowerCase()
  return currencyKeywords.some(keyword => lowerKey.includes(keyword))
}

// Helper function to check if a field name is likely a date field
const isDateField = (key: string): boolean => {
  const dateKeywords = [
    'date', 'time', 'created', 'updated', 'modified', 'deadline',
    'due', 'expires', 'renewal', 'start', 'end', 'birth', 'joined',
    'last', 'next', 'scheduled', 'completed', 'signed'
  ]
  const lowerKey = key.toLowerCase()
  return dateKeywords.some(keyword => lowerKey.includes(keyword))
}

// Helper function to format dates
const formatDate = (value: string | Date): string => {
  try {
    const date = value instanceof Date ? value : new Date(value)
    // Check if date is valid
    if (isNaN(date.getTime())) return String(value)
    
    // Format as "Month Day, Year" (e.g., "January 15, 2024")
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  } catch {
    return String(value)
  }
}

// Helper function to format field values with proper type handling
const formatFieldValue = (key: string, value: any): string => {
  if (value === null || value === undefined) return '-'
  
  // Handle arrays - join items with comma, no brackets or quotes
  if (Array.isArray(value)) {
    if (value.length === 0) return '-'
    // For arrays of objects, stringify each object
    if (value.some(item => typeof item === 'object' && item !== null)) {
      return value.map(item => 
        typeof item === 'object' ? JSON.stringify(item) : String(item)
      ).join(', ')
    }
    // For simple arrays, capitalize first letter of each item and join
    return value.map(item => {
      const str = String(item)
      return str.charAt(0).toUpperCase() + str.slice(1)
    }).join(', ')
  }
  
  // Check if it's a date field and the value looks like a date
  if (isDateField(key) && typeof value === 'string') {
    // Check if it looks like a date (ISO format, or contains date separators)
    if (value.match(/^\d{4}-\d{2}-\d{2}/) || value.match(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/)) {
      return formatDate(value)
    }
  }
  
  // Check if it's a currency field and the value is numeric
  if (isCurrencyField(key) && (typeof value === 'number' || !isNaN(parseFloat(value)))) {
    return formatCurrency(value)
  }
  
  // Handle objects (but not arrays, which are already handled above)
  if (typeof value === 'object' && value instanceof Date) {
    return formatDate(value)
  } else if (typeof value === 'object') {
    return JSON.stringify(value, null, 2)
  }
  
  // Handle booleans
  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No'
  }
  
  // Default to string representation
  return String(value)
}

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
  const [orgDetails, setOrgDetails] = useState<Record<string, ClientOrganizationHistory | null>>({})
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
      // Get organizations for this client using relationship_summary view
      const { data: relationshipData, error: relationshipError } = await supabase
        .from('relationship_summary')
        .select('client_uuid, org_uuid, org_name, org_type, total_spend, status, owner, renewal_date, alignment_score')
        .eq('client_uuid', clientUuid)
      
      if (relationshipError) {
        console.error('Error fetching from relationship_summary:', relationshipError)
        // No fallback - organizations are only shown through client relationships
        setOrganizations([])
      } else {
        // Keep the full relationship data for table display
        const transformedOrgs = relationshipData?.map(rel => ({
          id: rel.org_uuid || '',
          name: rel.org_name || '',
          type: rel.org_type || '',
          alignment_score: rel.alignment_score || 0,
          total_spend: rel.total_spend || 0,
          status: rel.status || '',
          owner: rel.owner || '',
          description: `${rel.org_type || ''} | Status: ${rel.status || ''} | Owner: ${rel.owner || ''}`,
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
      // Fetch from client_organization_history
      const { data, error } = await supabase
        .from('client_organization_history')
        .select('*')
        .eq('client_uuid', selectedClientUuid)
        .eq('org_uuid', orgId)
        .maybeSingle()
      
      if (error) {
        console.error('Error fetching organization details:', error)
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: null
        }))
      } else {
        setOrgDetails(prev => ({
          ...prev,
          [orgId]: data as ClientOrganizationHistory
        }))
      }
    } catch (error) {
      console.error('Unexpected error in fetchOrgDetails:', error)
      setOrgDetails(prev => ({
        ...prev,
        [orgId]: null
      }))
    }
  }

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
            <div className="flex items-center">
              <h1 className="text-2xl font-light tracking-wide text-red-600">
                External View
              </h1>
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

        {/* Client Selection Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            {selectedClient && (
              <h1 className="text-2xl font-bold tracking-wide text-gray-900">
                {selectedClient.name}
              </h1>
            )}
          </div>
          {userData?.client_uuid === '36fee78e-9bac-4443-9339-6f53003d3250' && (
            <div className="flex-shrink-0">
              <select
                id="client-select"
                value={selectedClientUuid}
                onChange={(e) => {
                  const newClientUuid = e.target.value
                  setSelectedClientUuid(newClientUuid)
                  
                  // Also update selectedClient object for display purposes
                  const client = clients.find(c => c.uuid === newClientUuid)
                  setSelectedClient(client || null)
                  
                  // Dashboard will automatically refresh via useEffect on selectedClientUuid change
                  // This will reload organizations and any other client-specific data
                }}
                className="block w-48 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm bg-white"
              >
                <option value="">Select a client...</option>
                {clients.map((client) => (
                  <option key={client.uuid} value={client.uuid}>
                    {client.name}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

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
                              <div>
                                <div className="text-sm font-medium text-gray-900">
                                  {org.name}
                                </div>
                                <div className="text-sm text-gray-500">
                                  {org.type || 'Organization'}
                                </div>
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
                        </tr>
                        {expandedRows.has(org.id) && (
                          <tr>
                            <td colSpan={4} className="px-6 py-6 bg-gray-50">
                              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                                <h4 className="text-base font-semibold text-gray-900 mb-4">Relationship Details</h4>
                                {orgDetails[org.id] ? (
                                  <div className="space-y-3">
                                    {/* Annual Total Spend */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Annual Total Spend:</span>
                                      <span className="text-gray-600">
                                        {orgDetails[org.id]?.annual_total_spend 
                                          ? formatCurrency(orgDetails[org.id]!.annual_total_spend!) 
                                          : '-'}
                                      </span>
                                    </div>
                                    
                                    {/* Relationship Owner */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Relationship Owner:</span>
                                      <span className="text-gray-600">
                                        {orgDetails[org.id]?.relationship_owner || '-'}
                                      </span>
                                    </div>
                                    
                                    {/* Renewal Date */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Renewal Date:</span>
                                      <span className="text-gray-600">
                                        {orgDetails[org.id]?.renewal_date 
                                          ? formatDate(orgDetails[org.id]!.renewal_date!) 
                                          : '-'}
                                      </span>
                                    </div>
                                    
                                    {/* Relationship Status */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Status:</span>
                                      <span className="flex items-center">
                                        {orgDetails[org.id]?.relationship_status && (
                                          <>
                                            <span className={`inline-block w-3 h-3 rounded-full mr-2 ${
                                              orgDetails[org.id]!.relationship_status === 'Green' ? 'bg-green-500' :
                                              orgDetails[org.id]!.relationship_status === 'Yellow' ? 'bg-yellow-500' :
                                              orgDetails[org.id]!.relationship_status === 'Red' ? 'bg-red-500' : ''
                                            }`}></span>
                                            <span className="text-gray-600">{orgDetails[org.id]!.relationship_status}</span>
                                          </>
                                        )}
                                        {!orgDetails[org.id]?.relationship_status && <span className="text-gray-600">-</span>}
                                      </span>
                                    </div>
                                    
                                    {/* Last Contact Date */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Last Contact:</span>
                                      <span className="text-gray-600">
                                        {orgDetails[org.id]?.last_contact_date 
                                          ? formatDate(orgDetails[org.id]!.last_contact_date!) 
                                          : '-'}
                                      </span>
                                    </div>
                                    
                                    {/* Key External Contacts */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Key Contacts:</span>
                                      <span className="text-gray-600">
                                        {orgDetails[org.id]?.key_external_contacts && orgDetails[org.id]!.key_external_contacts!.length > 0
                                          ? orgDetails[org.id]!.key_external_contacts!.join(', ')
                                          : '-'}
                                      </span>
                                    </div>
                                    
                                    {/* Policy Alignment Score */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Alignment Score:</span>
                                      <div className="flex items-center">
                                        {orgDetails[org.id]?.policy_alignment_score !== null && orgDetails[org.id]?.policy_alignment_score !== undefined ? (
                                          <>
                                            <span className="text-gray-600 mr-3">{orgDetails[org.id]!.policy_alignment_score}%</span>
                                            <div className="w-32 bg-gray-200 rounded-full h-2">
                                              <div 
                                                className="bg-primary-600 h-2 rounded-full" 
                                                style={{ width: `${Math.min(orgDetails[org.id]?.policy_alignment_score || 0, 100)}%` }}
                                              />
                                            </div>
                                          </>
                                        ) : (
                                          <span className="text-gray-600">-</span>
                                        )}
                                      </div>
                                    </div>
                                    
                                    {/* Notes */}
                                    <div className="flex items-start">
                                      <span className="font-medium text-gray-700 w-40">Notes:</span>
                                      <span className="text-gray-600 flex-1">
                                        {orgDetails[org.id]?.notes || '-'}
                                      </span>
                                    </div>
                                  </div>
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
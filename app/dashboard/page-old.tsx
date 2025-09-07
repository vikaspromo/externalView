'use client'

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { User, Organization, Client } from '@/lib/supabase/types'

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<User | null>(null)
  const [organizations, setOrganizations] = useState<any[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [selectedClientUuid, setSelectedClientUuid] = useState<string>('')
  const [selectedClient, setSelectedClient] = useState<Client | null>(null)
  const [expandedOrgId, setExpandedOrgId] = useState<string | null>(null)
  const [detailedOrgData, setDetailedOrgData] = useState<any>(null)
  const [isLoading, setIsLoading] = useState(true)
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

  // Load organizations when selectedClientUuid changes
  useEffect(() => {
    if (selectedClientUuid) {
      loadOrganizations(selectedClientUuid)
    }
  }, [selectedClientUuid])

  const loadOrganizations = async (clientUuid: string) => {
    try {
      // Get organizations for this client using client_org_relationships table
      const { data: relationshipData, error: relationshipError } = await supabase
        .from('client_org_relationships')
        .select('*')
        .eq('client_uuid', clientUuid)
      
      if (relationshipError) {
        console.error('Error fetching from client_org_relationships:', relationshipError)
        // No fallback - organizations are only shown through client relationships
        setOrganizations([])
      } else {
        console.log('Fetched relationship data:', relationshipData)
        // Store the full relationship data directly
        setOrganizations(relationshipData || [])
      }
    } catch (error) {
      console.error('Error in loadOrganizations:', error)
    }
  }

  const toggleOrgExpansion = async (orgId: string) => {
    if (expandedOrgId === orgId) {
      setExpandedOrgId(null)
      setDetailedOrgData(null)
    } else {
      setExpandedOrgId(orgId)
      await loadOrganizationDetails(orgId)
    }
  }

  const loadOrganizationDetails = async (orgUuid: string) => {
    // Simply find and use the organization from our already loaded data
    const orgData = organizations.find(org => org.org_uuid === orgUuid)
    if (orgData) {
      console.log('Using organization details:', orgData)
      setDetailedOrgData(orgData)
    } else {
      console.error('Organization not found:', orgUuid)
    }
  }

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
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
              <h1 className="text-2xl font-semibold text-gray-900">
                ExternalView
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
              <h1 className="text-2xl font-bold text-gray-900">
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
              Organizations associated with {selectedClient?.name || 'this client'}
            </p>
          </div>
          
          <div className="p-6">
            {organizations.length > 0 ? (
              <div>
                {/* Simple table showing organizations */}
                <pre>{JSON.stringify(organizations, null, 2)}</pre>
              </div>
            ) : (
              <p className="text-gray-500">No organizations found for this client.</p>
            )}
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Alignment Score
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Budget
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {organizations.map((org) => (
                      <tr
                        key={org.org_uuid || org.id}
                        className="hover:bg-gray-50"
                      >
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm font-medium text-gray-900">{org.org_name || 'Unnamed'}</div>
                          <div className="text-sm text-gray-500">{org.org_type}</div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                            org.priority === 'High' ? 'bg-red-100 text-red-800' :
                            org.priority === 'Medium' ? 'bg-orange-100 text-orange-800' :
                            org.priority === 'Low' ? 'bg-green-100 text-green-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {org.priority || 'N/A'}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {org.alignment_score || 'N/A'}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {org.total_spend ? `$${org.total_spend.toLocaleString()}` : 'N/A'}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                          {/* Empty cell - no expand button */}
                        </td>
                      </tr>
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                                    </svg>
                                    Financial Admin
                                  </h4>
                                  <div className="space-y-3">
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Total Spend</span>
                                      <p className="text-lg font-semibold text-gray-900">
                                        ${detailedOrgData.total_spend?.toLocaleString() || '0'}
                                      </p>
                                    </div>
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Renewal Date</span>
                                      <p className="text-sm font-medium text-gray-900">
                                        {detailedOrgData.renewal_date ? new Date(detailedOrgData.renewal_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Not set'}
                                      </p>
                                    </div>
                                    {detailedOrgData.budget && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Budget</span>
                                        <p className="text-sm font-medium text-gray-900">
                                          ${detailedOrgData.budget?.toLocaleString()}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.contract_value && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Contract Value</span>
                                        <p className="text-sm font-medium text-gray-900">
                                          ${detailedOrgData.contract_value?.toLocaleString()}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.payment_terms && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Payment Terms</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.payment_terms}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.financial_notes && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Financial Notes</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.financial_notes}</p>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Relationship Management Card */}
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                                    </svg>
                                    Relationship Management
                                  </h4>
                                  <div className="space-y-3">
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Owner</span>
                                      <p className="text-sm font-medium text-gray-900">{detailedOrgData.owner || 'Unassigned'}</p>
                                    </div>
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Status</span>
                                      <p className="text-sm">
                                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                          detailedOrgData.status === 'Active' ? 'bg-green-100 text-green-800' :
                                          detailedOrgData.status === 'Pending' ? 'bg-yellow-100 text-yellow-800' :
                                          detailedOrgData.status === 'Inactive' ? 'bg-gray-100 text-gray-800' :
                                          detailedOrgData.status === 'Prospect' ? 'bg-blue-100 text-blue-800' :
                                          'bg-gray-100 text-gray-800'
                                        }`}>
                                          {detailedOrgData.status || 'Unknown'}
                                        </span>
                                      </p>
                                    </div>
                                    {detailedOrgData.primary_contact && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Primary Contact</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.primary_contact}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.contact_email && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Contact Email</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.contact_email}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.contact_phone && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Contact Phone</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.contact_phone}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.stakeholder_count && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Stakeholders</span>
                                        <p className="text-sm font-medium text-gray-900">{detailedOrgData.stakeholder_count} contacts</p>
                                      </div>
                                    )}
                                    {detailedOrgData.relationship_notes && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Notes</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.relationship_notes}</p>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Alignment & Strategy Card */}
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                                    </svg>
                                    Alignment & Strategy
                                  </h4>
                                  <div className="space-y-3">
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Alignment Score</span>
                                      <div className="flex items-center space-x-2">
                                        <div className="flex-1 bg-gray-200 rounded-full h-2">
                                          <div 
                                            className={`h-2 rounded-full ${
                                              detailedOrgData.alignment_score >= 80 ? 'bg-green-500' :
                                              detailedOrgData.alignment_score >= 60 ? 'bg-yellow-500' :
                                              detailedOrgData.alignment_score >= 40 ? 'bg-orange-500' :
                                              'bg-red-500'
                                            }`}
                                            style={{ width: `${detailedOrgData.alignment_score || 0}%` }}
                                          />
                                        </div>
                                        <span className="text-sm font-semibold text-gray-900">{detailedOrgData.alignment_score || 0}%</span>
                                      </div>
                                    </div>
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Priority</span>
                                      <p className="text-sm">
                                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                          detailedOrgData.priority === 'High' ? 'bg-red-100 text-red-800' :
                                          detailedOrgData.priority === 'Medium' ? 'bg-orange-100 text-orange-800' :
                                          detailedOrgData.priority === 'Low' ? 'bg-green-100 text-green-800' :
                                          'bg-gray-100 text-gray-800'
                                        }`}>
                                          {detailedOrgData.priority || 'Not Set'}
                                        </span>
                                      </p>
                                    </div>
                                    {detailedOrgData.strategic_importance && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Strategic Importance</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.strategic_importance}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.growth_potential && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Growth Potential</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.growth_potential}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.risk_level && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Risk Level</span>
                                        <p className="text-sm">
                                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                            detailedOrgData.risk_level === 'High' ? 'bg-red-100 text-red-800' :
                                            detailedOrgData.risk_level === 'Medium' ? 'bg-yellow-100 text-yellow-800' :
                                            detailedOrgData.risk_level === 'Low' ? 'bg-green-100 text-green-800' :
                                            'bg-gray-100 text-gray-800'
                                          }`}>
                                            {detailedOrgData.risk_level}
                                          </span>
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.strategic_notes && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Strategic Notes</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.strategic_notes}</p>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Organization Details Card */}
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                                    </svg>
                                    Organization Details
                                  </h4>
                                  <div className="space-y-3">
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Organization Type</span>
                                      <p className="text-sm font-medium text-gray-900">{detailedOrgData.org_type || 'Not specified'}</p>
                                    </div>
                                    <div>
                                      <span className="text-xs text-gray-500 uppercase tracking-wider">Organization ID</span>
                                      <p className="text-xs font-mono text-gray-600">{detailedOrgData.org_uuid}</p>
                                    </div>
                                    {detailedOrgData.industry && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Industry</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.industry}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.company_size && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Company Size</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.company_size}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.location && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Location</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.location}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.website && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Website</span>
                                        <a href={detailedOrgData.website} target="_blank" rel="noopener noreferrer" className="text-sm text-blue-600 hover:underline">
                                          {detailedOrgData.website}
                                        </a>
                                      </div>
                                    )}
                                    {detailedOrgData.created_at && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Created</span>
                                        <p className="text-sm text-gray-700">
                                          {new Date(detailedOrgData.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.updated_at && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Last Updated</span>
                                        <p className="text-sm text-gray-700">
                                          {new Date(detailedOrgData.updated_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </p>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Engagement Metrics Card */}
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                                    </svg>
                                    Engagement Metrics
                                  </h4>
                                  <div className="space-y-3">
                                    {detailedOrgData.engagement_level && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Engagement Level</span>
                                        <p className="text-sm">
                                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                            detailedOrgData.engagement_level === 'High' ? 'bg-green-100 text-green-800' :
                                            detailedOrgData.engagement_level === 'Medium' ? 'bg-yellow-100 text-yellow-800' :
                                            detailedOrgData.engagement_level === 'Low' ? 'bg-red-100 text-red-800' :
                                            'bg-gray-100 text-gray-800'
                                          }`}>
                                            {detailedOrgData.engagement_level}
                                          </span>
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.last_contact_date && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Last Contact</span>
                                        <p className="text-sm text-gray-900">
                                          {new Date(detailedOrgData.last_contact_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.next_action_date && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Next Action</span>
                                        <p className="text-sm text-gray-900">
                                          {new Date(detailedOrgData.next_action_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.next_action && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Next Action Item</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.next_action}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.meeting_count && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Total Meetings</span>
                                        <p className="text-sm font-medium text-gray-900">{detailedOrgData.meeting_count}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.email_count && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Email Exchanges</span>
                                        <p className="text-sm font-medium text-gray-900">{detailedOrgData.email_count}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.response_time && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Avg Response Time</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.response_time}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.engagement_notes && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Engagement Notes</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.engagement_notes}</p>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Historical Context Card */}
                                <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                                  <h4 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
                                    <svg className="w-4 h-4 mr-2 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                    </svg>
                                    Historical Context
                                  </h4>
                                  <div className="space-y-3">
                                    {detailedOrgData.relationship_start_date && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Relationship Started</span>
                                        <p className="text-sm text-gray-900">
                                          {new Date(detailedOrgData.relationship_start_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.previous_contracts && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Previous Contracts</span>
                                        <p className="text-sm text-gray-900">{detailedOrgData.previous_contracts}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.historical_spend && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Historical Spend</span>
                                        <p className="text-sm font-medium text-gray-900">
                                          ${detailedOrgData.historical_spend?.toLocaleString()}
                                        </p>
                                      </div>
                                    )}
                                    {detailedOrgData.key_milestones && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Key Milestones</span>
                                        <p className="text-sm text-gray-700 whitespace-pre-wrap">{detailedOrgData.key_milestones}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.past_challenges && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Past Challenges</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.past_challenges}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.success_stories && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Success Stories</span>
                                        <p className="text-sm text-gray-700">{detailedOrgData.success_stories}</p>
                                      </div>
                                    )}
                                    {detailedOrgData.historical_notes && (
                                      <div>
                                        <span className="text-xs text-gray-500 uppercase tracking-wider">Historical Notes</span>
                                        <p className="text-sm text-gray-700 whitespace-pre-wrap">{detailedOrgData.historical_notes}</p>
                                      </div>
                                    )}
                                  </div>
                    ))
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
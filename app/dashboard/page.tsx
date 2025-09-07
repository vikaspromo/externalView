'use client'

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { User, Organization, Client } from '@/lib/supabase/types'

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<User | null>(null)
  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [selectedClientUuid, setSelectedClientUuid] = useState<string>('')
  const [selectedClient, setSelectedClient] = useState<Client | null>(null)
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
      // Get organizations for this client using relationship_summary view
      const { data: relationshipData, error: relationshipError } = await supabase
        .from('relationship_summary')
        .select('client_uuid, org_uuid, org_name, org_type, total_spend, status, owner, renewal_date, alignment_score, priority')
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
          priority: rel.priority || 0,
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
              Manage stakeholder relationships across your target organizations
            </p>
          </div>
          
          <div className="p-6">
            {organizations.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Organization
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Priority
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Alignment Score
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Budget
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {organizations.map((org) => (
                      <tr key={org.id} className="hover:bg-gray-50 cursor-pointer">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div>
                            <div className="text-sm font-medium text-gray-900">
                              {org.name}
                            </div>
                            <div className="text-sm text-gray-500">
                              {org.type || 'Organization'}
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                            org.priority === 1 ? 'bg-red-100 text-red-800' :
                            org.priority === 2 ? 'bg-yellow-100 text-yellow-800' :
                            org.priority === 3 ? 'bg-green-100 text-green-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            Priority {org.priority || '-'}
                          </span>
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
                          {org.total_spend ? `$${org.total_spend.toLocaleString()}` : '-'}
                        </td>
                      </tr>
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
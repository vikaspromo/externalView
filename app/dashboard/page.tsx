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
          
          // Set the user's client as the selected client based on their client_uuid
          if (clientsData && userData.client_uuid) {
            const userClient = clientsData.find(client => client.uuid === userData.client_uuid)
            if (userClient) {
              setSelectedClient(userClient)
              // Load organizations for this client
              loadOrganizations(userClient.uuid)
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

  // Load organizations when selected client changes
  useEffect(() => {
    if (selectedClient?.uuid) {
      loadOrganizations(selectedClient.uuid)
    }
  }, [selectedClient?.uuid])

  const loadOrganizations = async (clientUuid: string) => {
    try {
      // Try to get organizations for this client
      // Assuming there's a client_uuid field on organizations table
      const { data: orgsData, error: orgsError } = await supabase
        .from('organizations')
        .select('*')
        .eq('client_uuid', clientUuid)
        .limit(50)
      
      if (orgsError) {
        console.error('Error fetching organizations:', orgsError)
        // If the query fails, try without client filter (for testing)
        const { data: allOrgsData, error: allOrgsError } = await supabase
          .from('organizations')
          .select('*')
          .limit(10)
        
        if (allOrgsError) {
          console.error('Error fetching all organizations:', allOrgsError)
        } else {
          console.log('Loaded all organizations (no client filter):', allOrgsData)
          setOrganizations(allOrgsData || [])
        }
      } else {
        console.log('Loaded organizations for client:', clientUuid, orgsData)
        setOrganizations(orgsData || [])
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
                value={selectedClient?.uuid || ''}
                onChange={(e) => {
                  const client = clients.find(c => c.uuid === e.target.value)
                  setSelectedClient(client || null)
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
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {organizations.map((org) => (
                  <div
                    key={org.id}
                    className="border border-gray-200 rounded-lg p-4 hover:border-primary-300 hover:shadow-sm transition-all cursor-pointer"
                  >
                    <h3 className="font-medium text-gray-900 mb-2">{org.name}</h3>
                    {org.description && (
                      <p className="text-sm text-gray-600 mb-2 line-clamp-2">
                        {org.description}
                      </p>
                    )}
                    <div className="text-xs text-gray-500">
                      Created {new Date(org.created_at).toLocaleDateString()}
                    </div>
                  </div>
                ))}
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
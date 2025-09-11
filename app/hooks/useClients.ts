/**
 * Custom hook for managing client data
 */

import { useEffect, useState } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { Client } from '@/lib/supabase/types'

export interface ClientsState {
  clients: Client[]
  selectedClientUuid: string
  selectedClient: Client | null
  setSelectedClientUuid: (uuid: string) => void
  loadClients: (userClientUuid: string) => Promise<void>
}

/**
 * Hook to manage client selection and data
 */
export const useClients = (): ClientsState => {
  const [clients, setClients] = useState<Client[]>([])
  const [selectedClientUuid, setSelectedClientUuid] = useState<string>('')
  const [selectedClient, setSelectedClient] = useState<Client | null>(null)
  const supabase = createClientComponentClient()

  const loadClients = async (userClientUuid: string) => {
    try {
      const { data: clientData } = await supabase
        .from('clients')
        .select('uuid, name')
        .eq('uuid', userClientUuid)
        .single()
      
      if (clientData) {
        setClients([clientData as Client])
        setSelectedClientUuid(clientData.uuid)
        setSelectedClient(clientData as Client)
      }
    } catch (error) {
      console.error('Error loading clients:', error)
    }
  }

  return {
    clients,
    selectedClientUuid,
    selectedClient,
    setSelectedClientUuid,
    loadClients,
  }
}
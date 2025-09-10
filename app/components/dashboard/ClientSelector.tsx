/**
 * Client selector component for the dashboard
 */

import React from 'react'
import { Client } from '@/lib/supabase/types'

interface ClientSelectorProps {
  clients: Client[]
  selectedClientUuid: string
  onClientChange: (uuid: string) => void
}

export const ClientSelector: React.FC<ClientSelectorProps> = ({ 
  clients, 
  selectedClientUuid, 
  onClientChange 
}) => {
  if (clients.length === 0) {
    return null
  }

  return (
    <div className="bg-white shadow rounded-lg p-4">
      <label htmlFor="client-select" className="block text-sm font-medium text-gray-700">
        Select Client
      </label>
      <select
        id="client-select"
        value={selectedClientUuid}
        onChange={(e) => onClientChange(e.target.value)}
        className="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm rounded-md"
      >
        <option value="">Choose a client</option>
        {clients.map((client) => (
          <option key={client.uuid} value={client.uuid}>
            {client.name}
          </option>
        ))}
      </select>
    </div>
  )
}
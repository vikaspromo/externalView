'use client'

import React, { useState, useEffect } from 'react'
import { Client } from '@/lib/supabase/types'

interface AdminClientToggleProps {
  clients: Client[]
  selectedClientUuid: string
  selectedClient: Client | null
  onClientChange: (client: Client) => void
}

export function AdminClientToggle({ 
  clients, 
  selectedClientUuid, 
  selectedClient, 
  onClientChange, 
}: AdminClientToggleProps) {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false)

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

  return (
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
                  onClientChange(client)
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
  )
}
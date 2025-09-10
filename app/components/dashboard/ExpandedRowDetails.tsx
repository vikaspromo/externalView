/**
 * Expanded row details component for organization information
 */

import React from 'react'
import { ClientOrganizationHistory } from '@/lib/supabase/types'
import { PolicyPositionsCard } from './PolicyPositionsCard'

interface ExpandedRowDetailsProps {
  orgDetails: (ClientOrganizationHistory & { positions?: any[] }) | null
}

export const ExpandedRowDetails: React.FC<ExpandedRowDetailsProps> = ({ orgDetails }) => {
  if (!orgDetails) {
    return (
      <div className="text-center py-4">
        <p className="text-sm text-gray-500">No relationship data available for this organization</p>
        <p className="text-xs text-gray-400 mt-2">Add relationship details to start tracking this organization</p>
      </div>
    )
  }

  return (
    <>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Left side - Notes */}
        <div>
          <h5 className="text-sm font-semibold text-gray-700 mb-2">Notes</h5>
          <p className="text-sm text-gray-600">
            {orgDetails.notes || 'No notes available'}
          </p>
        </div>
        
        {/* Right side - Key External Contacts */}
        <div>
          <h5 className="text-sm font-semibold text-gray-700 mb-2">Key Organization Contacts</h5>
          {(orgDetails.key_external_contacts?.length ?? 0) > 0 ? (
            <ul className="space-y-1">
              {orgDetails.key_external_contacts?.map((contact, index) => (
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
      {orgDetails.positions && <PolicyPositionsCard positions={orgDetails.positions} />}
    </>
  )
}
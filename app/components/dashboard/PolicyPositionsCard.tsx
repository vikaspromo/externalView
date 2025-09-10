/**
 * Component to display policy positions for an organization
 */

import React from 'react'

interface PolicyPosition {
  description: string
  position: string
  positionDetails: string
  referenceMaterials?: string[]
}

interface PolicyPositionsCardProps {
  positions: PolicyPosition[]
}

export const PolicyPositionsCard: React.FC<PolicyPositionsCardProps> = ({ positions }) => {
  if (!positions || positions.length === 0) {
    return null
  }

  return (
    <div className="mt-6">
      <h5 className="text-sm font-semibold text-gray-700 mb-4">
        Policy Positions ({positions.length})
      </h5>
      <div className="space-y-4">
        {positions.map((position: any, index: number) => (
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
  )
}
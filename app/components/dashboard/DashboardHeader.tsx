/**
 * Dashboard header component with title and sign-out button
 */

import React from 'react'

interface DashboardHeaderProps {
  onSignOut: () => Promise<void>
}

export const DashboardHeader: React.FC<DashboardHeaderProps> = ({ onSignOut }) => {
  return (
    <header className="bg-white shadow-sm border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center">
            <h1 className="text-2xl font-light tracking-wide text-red-600">
              External View
            </h1>
          </div>
          <button
            onClick={onSignOut}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
          >
            Sign Out
          </button>
        </div>
      </div>
    </header>
  )
}
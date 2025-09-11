'use client'

import { ErrorBoundary } from './ErrorBoundary'
import { useRouter } from 'next/navigation'

export function DashboardErrorBoundary({ children }: { children: React.ReactNode }) {
  const router = useRouter()

  const handleError = () => {
    // Custom error handling for dashboard
    router.push('/')
  }

  return (
    <ErrorBoundary
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow-lg">
            <div className="text-center">
              <h2 className="text-3xl font-bold text-gray-900 mb-2">
                Dashboard Error
              </h2>
              <p className="text-gray-600 mb-4">
                We couldn&apos;t load the dashboard. This might be a temporary issue.
              </p>
              <div className="space-y-3">
                <button
                  onClick={() => window.location.reload()}
                  className="w-full px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
                >
                  Try Again
                </button>
                <button
                  onClick={handleError}
                  className="w-full px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition-colors"
                >
                  Return to Home
                </button>
              </div>
            </div>
          </div>
        </div>
      }
    >
      {children}
    </ErrorBoundary>
  )
}
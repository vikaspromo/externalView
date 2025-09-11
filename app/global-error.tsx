'use client'

export default function GlobalError({
  error: _error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html>
      <body>
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow-lg">
            <div className="text-center">
              <h1 className="text-4xl font-bold text-red-600 mb-4">
                Critical Error
              </h1>
              <p className="text-gray-600 mb-6">
                A critical error occurred. The application needs to restart.
              </p>
              <button
                onClick={reset}
                className="px-6 py-3 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
              >
                Restart Application
              </button>
            </div>
          </div>
        </div>
      </body>
    </html>
  )
}
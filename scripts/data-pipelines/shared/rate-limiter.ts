/**
 * Simple rate limiting utility for API calls
 */

// Add delay between API calls to respect rate limits
export const delay = (ms: number): Promise<void> => 
  new Promise(resolve => setTimeout(resolve, ms))

// Default delays for different API sources
export const API_DELAYS = {
  PROPUBLICA: 1000,  // 1 second between requests
  OPENSECRETS: 500,  // 500ms between requests
  FEC: 2000,         // 2 seconds between requests
  IRS: 1500,         // 1.5 seconds between requests
} as const

/**
 * Rate-limited fetch wrapper
 * @param url URL to fetch
 * @param delayMs Delay in milliseconds after fetch
 * @returns Fetch response
 */
export async function rateLimitedFetch(
  url: string, 
  delayMs: number = API_DELAYS.PROPUBLICA
): Promise<Response> {
  const response = await fetch(url)
  await delay(delayMs)
  return response
}
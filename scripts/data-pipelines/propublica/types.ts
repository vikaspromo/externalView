/**
 * TypeScript interfaces for ProPublica Nonprofit Explorer API
 */

// ProPublica API organization result
export interface ProPublicaOrganization {
  ein: string
  strein: string  // Formatted EIN with hyphen (e.g., "12-3456789")
  name: string
  sub_name?: string
  city?: string
  state?: string
  ntee_code?: string
  raw_ntee_code?: string
  subseccd?: number
  has_subseccd?: boolean
  have_filings?: boolean | null
  have_extracts?: boolean | null
  have_pdfs?: boolean | null
  totrevenue?: number
  totfuncexpns?: number
  score?: number
}

// ProPublica API search response
export interface ProPublicaSearchResponse {
  organizations: ProPublicaOrganization[]
  num_pages: number
  cur_page: number
  page_offset: number
  per_page: number
  total_results: number
}

// ProPublica API base configuration
export const PROPUBLICA_CONFIG = {
  API_BASE: 'https://projects.propublica.org/nonprofits/api/v2',
  SEARCH_ENDPOINT: '/search.json',
  ORG_ENDPOINT: '/organizations',
  NO_RESULTS_EIN: '00-0000000',  // Marker for organizations not found in ProPublica
} as const
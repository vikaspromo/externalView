/**
 * Core database table interfaces
 */

export interface User {
  id: string
  email: string
  first_name: string | null
  last_name: string | null
  client_uuid: string
  active: boolean
  created_at: string
  updated_at: string
}

export interface Organization {
  id: string
  name: string
  alignment_score?: number
  total_spend?: number
  owner?: string
  renewal_date?: string
  created_at: string
  updated_at: string
}

export interface Client {
  uuid: string
  name: string
}

export interface ClientOrganizationHistory {
  id: string
  client_uuid: string
  org_uuid: string
  annual_total_spend?: number
  relationship_owner?: string
  renewal_date?: string
  key_external_contacts?: string[]
  policy_alignment_score?: number
  notes?: string
  created_at: string
  updated_at: string
}

export interface OrganizationPosition {
  id: string
  organization_uuid: string
  organization_name?: string
  ein?: string
  positions?: any[]
  fetched_at?: string
  created_at: string
  updated_at: string
}
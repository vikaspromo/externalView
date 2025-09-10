export interface User {
  id: string
  email: string
  company: string
  client_uuid: string
  active: boolean
  created_at: string
  updated_at: string
}

export interface Organization {
  id: string
  name: string
  type?: string
  alignment_score?: number
  total_spend?: number
  status?: string
  owner?: string
  renewal_date?: string
  description?: string
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
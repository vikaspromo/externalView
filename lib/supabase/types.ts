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
  description?: string
  created_at: string
  updated_at: string
}

export interface Client {
  uuid: string
  name: string
}

export interface StakeholderRelationship {
  id: string
  organization_id: string
  stakeholder_name: string
  role?: string
  contact_info?: string
  notes?: string
  created_at: string
  updated_at: string
}
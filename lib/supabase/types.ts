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
  priority?: number
  alignment_score?: number
  total_spend?: number
  status?: string
  owner?: string
  description?: string
  created_at: string
  updated_at: string
}

export interface Client {
  uuid: string
  name: string
}
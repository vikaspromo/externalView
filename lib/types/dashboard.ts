/**
 * Dashboard-specific type definitions
 */

export type SortField = 'name' | 'alignment_score' | 'total_spend' | 'renewal_date'
export type SortDirection = 'asc' | 'desc'

export interface DashboardState {
  sortField: SortField
  sortDirection: SortDirection
  expandedRows: Set<string>
}

export interface TableColumn {
  key: string
  label: string
  sortable?: boolean
  width?: string
  align?: 'left' | 'center' | 'right'
}
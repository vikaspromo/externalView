/**
 * Audit and security event type definitions
 * Shared types for audit logging functionality
 */

/**
 * Security audit log event structure
 * Used for logging security-relevant operations
 */
export interface SecurityAuditLog {
  event_type: 'access_denied' | 'unauthorized_attempt' | 'admin_override'
  user_id: string | undefined
  client_uuid: string | null | undefined
  target_client_uuid?: string | null
  operation: string
  metadata?: Record<string, any>
}

/**
 * Types of security events that can be logged
 */
export const AUDIT_EVENT_TYPES = {
  // Access control events
  ACCESS_GRANTED: 'access_granted',
  ACCESS_DENIED: 'access_denied',
  UNAUTHORIZED_ATTEMPT: 'unauthorized_attempt',
  ADMIN_OVERRIDE: 'admin_override',
  
  // Authentication events
  LOGIN_SUCCESS: 'login_success',
  LOGIN_FAILURE: 'login_failure',
  LOGOUT: 'logout',
  SESSION_EXPIRED: 'session_expired',
  
  // Data modification events
  DATA_CREATE: 'data_create',
  DATA_UPDATE: 'data_update',
  DATA_DELETE: 'data_delete',
  
  // Rate limiting events
  RATE_LIMIT_EXCEEDED: 'rate_limit_exceeded',
  
  // Admin actions
  ADMIN_ACTION: 'admin_action',
  PERMISSION_CHANGE: 'permission_change',
  
  // System events
  SYSTEM_ERROR: 'system_error',
  CONFIGURATION_CHANGE: 'configuration_change',
} as const

export type AuditEventType = typeof AUDIT_EVENT_TYPES[keyof typeof AUDIT_EVENT_TYPES]
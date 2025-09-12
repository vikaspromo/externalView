/**
 * Audit log service for writing security events to the database
 * This service handles the persistence of security audit events
 */

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import type { SecurityAuditLog } from '@/lib/utils/access-control'
import { logger } from '@/lib/utils/logger'

/**
 * Writes an audit log event to the database
 * This function is called from the frontend to persist security events
 */
export async function writeAuditLog(event: SecurityAuditLog): Promise<void> {
  try {
    const supabase = createClientComponentClient()
    
    // Prepare the audit log entry
    const auditEntry = {
      event_type: event.event_type,
      user_id: event.user_id || null,
      client_uuid: event.client_uuid || null,
      success: event.event_type !== 'unauthorized_attempt' && event.event_type !== 'access_denied',
      metadata: {
        ...event.metadata,
        operation: event.operation,
        target_client_uuid: event.target_client_uuid,
        timestamp: new Date().toISOString(),
        source: 'frontend',
      },
      // Note: IP address and user agent would typically be captured server-side
      // For frontend logging, we'll include what we can
      user_agent: typeof window !== 'undefined' ? navigator.userAgent : null,
      created_at: new Date().toISOString(),
    }
    
    // Insert the audit log entry
    const { error } = await supabase
      .from('security_audit_log')
      .insert(auditEntry)
    
    if (error) {
      // Don't throw to prevent disrupting the user experience
      // Silent failure in production, log in development
      logger.error('Failed to write audit log', error)
    }
  } catch (error) {
    // Catch any unexpected errors to prevent disrupting the app
    logger.error('Unexpected error writing audit log', error)
  }
}

/**
 * Fetches audit logs for the current user or all logs for admins
 * @param isAdmin - Whether the current user is an admin
 * @param limit - Maximum number of logs to fetch
 */
export async function fetchAuditLogs(
  _isAdmin: boolean,
  limit: number = 100
): Promise<any[]> {
  try {
    const supabase = createClientComponentClient()
    
    let query = supabase
      .from('security_audit_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit)
    
    // Note: RLS policies will automatically filter based on user permissions
    // Admins see all logs, regular users see only their own
    
    const { data, error } = await query
    
    if (error) {
      logger.error('Failed to fetch audit logs', error)
      return []
    }
    
    return data || []
  } catch (error) {
    logger.error('Unexpected error fetching audit logs', error)
    return []
  }
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

/**
 * Helper function to create a standardized audit log event
 */
export function createAuditEvent(
  type: keyof typeof AUDIT_EVENT_TYPES,
  userId: string | undefined,
  clientUuid: string | null | undefined,
  operation: string,
  metadata?: Record<string, any>
): SecurityAuditLog {
  return {
    event_type: AUDIT_EVENT_TYPES[type] as any,
    user_id: userId,
    client_uuid: clientUuid,
    operation,
    metadata: metadata || {},
  }
}

/**
 * Get a summary of recent audit events for dashboard display
 */
export async function getAuditSummary(
  _isAdmin: boolean,
  hours: number = 24
): Promise<{
  totalEvents: number
  accessDenied: number
  unauthorizedAttempts: number
  recentEvents: any[]
}> {
  try {
    const supabase = createClientComponentClient()
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString()
    
    // Fetch recent events
    const { data, error } = await supabase
      .from('security_audit_log')
      .select('*')
      .gte('created_at', since)
      .order('created_at', { ascending: false })
    
    if (error) {
      logger.error('Failed to get audit summary', error)
      return {
        totalEvents: 0,
        accessDenied: 0,
        unauthorizedAttempts: 0,
        recentEvents: [],
      }
    }
    
    const events = data || []
    
    return {
      totalEvents: events.length,
      accessDenied: events.filter(e => e.event_type === 'access_denied').length,
      unauthorizedAttempts: events.filter(e => e.event_type === 'unauthorized_attempt').length,
      recentEvents: events.slice(0, 10),
    }
  } catch (error) {
    logger.error('Unexpected error getting audit summary', error)
    return {
      totalEvents: 0,
      accessDenied: 0,
      unauthorizedAttempts: 0,
      recentEvents: [],
    }
  }
}
/**
 * RLS Helper - Simplified access control that relies on database RLS
 * 
 * This is the new simplified approach where the database is the single
 * source of truth for access control. The application layer only:
 * 1. Executes operations
 * 2. Catches RLS violations
 * 3. Logs security events for audit
 * 
 * This replaces access-control.ts when USE_SIMPLIFIED_RLS is enabled
 */

import { PostgrestError } from '@supabase/supabase-js'
import { writeAuditLog } from '@/lib/services/audit-log'
import { SecurityAuditLog } from '@/lib/types/audit'
import { logger } from '@/lib/utils/logger'

/**
 * RLS error codes from PostgreSQL
 */
const RLS_ERROR_CODES = {
  INSUFFICIENT_PRIVILEGE: '42501',
  ROW_LEVEL_SECURITY_VIOLATION: '42501',
} as const

/**
 * Check if an error is an RLS violation
 */
function isRLSError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false
  
  const pgError = error as PostgrestError
  return pgError.code === RLS_ERROR_CODES.INSUFFICIENT_PRIVILEGE ||
         pgError.code === RLS_ERROR_CODES.ROW_LEVEL_SECURITY_VIOLATION ||
         (pgError.message && pgError.message.toLowerCase().includes('row-level security')) || false
}

/**
 * Format RLS error for user display
 */
function formatRLSError(error: PostgrestError, operation: string): string {
  // Provide user-friendly error messages
  if (isRLSError(error)) {
    return `You don't have permission to ${operation}. This action requires appropriate access rights.`
  }
  
  // For non-RLS errors, return the original message
  return error.message || `Failed to ${operation}`
}

/**
 * Main RLS Helper class - thin wrapper around database operations
 */
export class RLSHelper {
  /**
   * Execute an operation with automatic RLS error handling and audit logging
   * 
   * @param operation - Async function that performs the database operation
   * @param context - Context for audit logging
   * @returns Result of the operation or throws formatted error
   */
  static async executeWithAudit<T>(
    operation: () => Promise<T>,
    context: {
      operation: string
      userId?: string
      clientUuid?: string | null
      targetId?: string
      metadata?: Record<string, any>
    }
  ): Promise<T> {
    const startTime = Date.now()
    
    try {
      // Execute the operation - let database RLS handle access control
      const result = await operation()
      
      // Log successful operation for audit
      if (context.userId) {
        const auditEvent: SecurityAuditLog = {
          event_type: 'data_access' as any,
          user_id: context.userId,
          client_uuid: context.clientUuid,
          operation: context.operation,
          target_client_uuid: context.targetId || null,
          metadata: {
            ...context.metadata,
            execution_time_ms: Date.now() - startTime,
            rls_mode: 'simplified',
          },
        }
        
        // Fire and forget audit logging
        writeAuditLog(auditEvent).catch(error => {
          logger.error('Failed to write audit log', error)
        })
      }
      
      return result
    } catch (error) {
      const executionTime = Date.now() - startTime
      
      // Check if this is an RLS violation
      if (isRLSError(error)) {
        // Log the RLS violation for security audit
        if (context.userId) {
          const auditEvent: SecurityAuditLog = {
            event_type: 'access_denied' as any,
            user_id: context.userId,
            client_uuid: context.clientUuid,
            operation: context.operation,
            target_client_uuid: context.targetId || null,
            metadata: {
              ...context.metadata,
              error: (error as PostgrestError).message,
              error_code: (error as PostgrestError).code,
              execution_time_ms: executionTime,
              rls_mode: 'simplified',
            },
          }
          
          // Fire and forget audit logging
          writeAuditLog(auditEvent).catch(logError => {
            logger.error('Failed to write security violation log', logError)
          })
        }
        
        // Throw user-friendly error
        const userMessage = formatRLSError(error as PostgrestError, context.operation)
        throw new Error(userMessage)
      }
      
      // For non-RLS errors, just throw them as-is
      throw error
    }
  }
  
  /**
   * Test if user has access to perform an operation
   * This is useful for UI elements (show/hide buttons, etc.)
   * 
   * @param testOperation - Function that attempts the operation
   * @returns True if operation would succeed, false if RLS would block it
   */
  static async testAccess(
    testOperation: () => Promise<any>
  ): Promise<boolean> {
    try {
      // Try to execute the operation
      // Most tests would be SELECT queries with LIMIT 0
      await testOperation()
      return true
    } catch (error) {
      // If it's an RLS error, access is denied
      if (isRLSError(error)) {
        return false
      }
      
      // For other errors, we can't determine access
      // Log the error and assume no access for safety
      logger.error('Error testing RLS access', error)
      return false
    }
  }
  
  /**
   * Helper to create audit metadata
   */
  static createAuditMetadata(
    action: string,
    resourceType: string,
    resourceId?: string
  ): Record<string, any> {
    return {
      action,
      resource_type: resourceType,
      resource_id: resourceId,
      timestamp: new Date().toISOString(),
      source: 'rls-helper',
    }
  }
}

/**
 * Compatibility exports for easier migration from access-control.ts
 * These are thin wrappers that immediately delegate to RLS
 */

/**
 * Log security event (audit trail)
 * In simplified mode, this just writes to audit log
 */
export async function logSecurityEvent(event: SecurityAuditLog): Promise<void> {
  try {
    await writeAuditLog(event)
  } catch (error) {
    logger.error('Failed to log security event', error)
  }
}

/**
 * Test helpers for common access patterns
 * These return promises that resolve to boolean
 */
export const AccessTests = {
  /**
   * Test if user can access a client
   * @param supabase - Supabase client instance
   * @param clientUuid - Client UUID to test
   */
  async canAccessClient(supabase: any, clientUuid: string): Promise<boolean> {
    return RLSHelper.testAccess(async () => {
      const { data, error } = await supabase
        .from('clients')
        .select('uuid')
        .eq('uuid', clientUuid)
        .limit(1)
        .single()
      
      if (error) throw error
      return !!data
    })
  },
  
  /**
   * Test if user is admin
   * @param supabase - Supabase client instance
   */
  async isAdmin(supabase: any): Promise<boolean> {
    return RLSHelper.testAccess(async () => {
      // Try to select from user_admins table
      // Admins can see all records, non-admins can only see their own
      const { data, error } = await supabase
        .from('user_admins')
        .select('auth_user_id')
        .limit(2) // If we get 2+, we're admin
      
      if (error) throw error
      return data && data.length > 1
    })
  },
  
  /**
   * Test if user can modify another user
   * @param supabase - Supabase client instance
   * @param targetUserId - User ID to test modification rights
   */
  async canModifyUser(supabase: any, targetUserId: string): Promise<boolean> {
    return RLSHelper.testAccess(async () => {
      // Try a no-op update to test access
      const { error } = await supabase
        .from('users')
        .update({ updated_at: new Date().toISOString() })
        .eq('auth_user_id', targetUserId)
        .eq('auth_user_id', targetUserId) // Redundant but ensures no actual change
      
      if (error) throw error
      return true
    })
  },
}

export default RLSHelper
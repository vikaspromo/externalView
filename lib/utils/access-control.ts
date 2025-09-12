/**
 * Access control utilities to enforce RLS policies at the application level
 * These functions mirror the database RLS policies for consistent security
 */

import { User } from '@/lib/supabase/types'

/**
 * Validates if a user has access to a specific client's data
 * Mirrors the RLS policy: user_has_client_access()
 */
export function validateClientAccess(
  clientUuid: string | null | undefined,
  userData: User | null,
  isAdmin: boolean
): boolean {
  // Admins have access to all clients
  if (isAdmin) {
    return true
  }

  // Regular users can only access their assigned client
  if (!userData || !clientUuid) {
    return false
  }

  return userData.client_uuid === clientUuid
}

/**
 * Throws an error if the user doesn't have access to the client
 * Use this for operations that modify data
 */
export function requireClientAccess(
  clientUuid: string | null | undefined,
  userData: User | null,
  isAdmin: boolean,
  operation: string = 'perform this operation'
): void {
  if (!validateClientAccess(clientUuid, userData, isAdmin)) {
    throw new Error(
      `Unauthorized: You don't have permission to ${operation} for this client`
    )
  }
}

/**
 * Validates if a user is an admin
 * Mirrors the RLS policy: is_admin()
 */
export function requireAdmin(isAdmin: boolean): void {
  if (!isAdmin) {
    throw new Error('Unauthorized: Admin access required')
  }
}

/**
 * Validates if a user can modify their own data
 * Mirrors the RLS policy for user profile updates
 */
export function canModifyUser(
  targetUserId: string,
  currentUserId: string | undefined,
  isAdmin: boolean
): boolean {
  // Admins can modify any user
  if (isAdmin) {
    return true
  }

  // Users can only modify their own profile
  return currentUserId === targetUserId
}

/**
 * Validates if a user can view specific user data
 * Mirrors the RLS policy: users in same client can see each other
 */
export function canViewUser(
  targetUserClientUuid: string | null,
  currentUserClientUuid: string | null | undefined,
  isAdmin: boolean
): boolean {
  // Admins can view all users
  if (isAdmin) {
    return true
  }

  // Users can view others in their same client
  if (!currentUserClientUuid || !targetUserClientUuid) {
    return false
  }

  return currentUserClientUuid === targetUserClientUuid
}

/**
 * Validates if client_uuid is being changed (which is not allowed)
 * Mirrors the RLS policy: prevent_client_uuid_change()
 */
export function preventClientUuidChange(
  oldClientUuid: string | null | undefined,
  newClientUuid: string | null | undefined,
  isAdmin: boolean
): void {
  // Admins can change client_uuid
  if (isAdmin) {
    return
  }

  // Check if client_uuid is being changed
  if (oldClientUuid !== newClientUuid) {
    throw new Error(
      'Unauthorized: Cannot change client assignment. Cross-tenant data transfer is not allowed.'
    )
  }
}

/**
 * Gets the appropriate client UUID for queries based on user type
 * Returns null for admins (who can see all), or the user's specific client
 */
export function getScopedClientUuid(
  userData: User | null,
  isAdmin: boolean
): string | null {
  // Admins don't have a scoped client
  if (isAdmin) {
    return null
  }

  // Regular users are scoped to their client
  return userData?.client_uuid || null
}

/**
 * Builds a Supabase query filter based on user's access level
 * Use this to automatically add client filtering to queries
 */
export function applyClientFilter<T extends { client_uuid?: string }>(
  query: any,
  userData: User | null,
  isAdmin: boolean
): any {
  // Admins see all data
  if (isAdmin) {
    return query
  }

  // Regular users only see their client's data
  if (userData?.client_uuid) {
    return query.eq('client_uuid', userData.client_uuid)
  }

  // No access if no client assigned
  throw new Error('No client access configured for user')
}

/**
 * Validates organization access through client relationship
 * Mirrors the RLS policy for client_org_history access
 */
export function validateOrgAccess(
  orgClientUuid: string | null | undefined,
  userData: User | null,
  isAdmin: boolean
): boolean {
  return validateClientAccess(orgClientUuid, userData, isAdmin)
}

/**
 * Security audit logging helper
 * Use this to log security-relevant operations
 */
export interface SecurityAuditLog {
  event_type: 'access_denied' | 'unauthorized_attempt' | 'admin_override'
  user_id: string | undefined
  client_uuid: string | null | undefined
  target_client_uuid?: string | null
  operation: string
  metadata?: Record<string, any>
}

export function logSecurityEvent(event: SecurityAuditLog): void {
  // In production, this would send to your audit logging service
  console.warn('[SECURITY AUDIT]', {
    timestamp: new Date().toISOString(),
    ...event
  })
}
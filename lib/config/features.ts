/**
 * Feature flags for gradual rollout of new functionality
 * These allow us to safely deploy and test changes with easy rollback
 */

/**
 * USE_SIMPLIFIED_RLS - Controls whether to use the simplified RLS implementation
 * 
 * When false (default):
 * - Uses existing access-control.ts with application-layer validation
 * - Maintains current behavior with duplicate checks
 * 
 * When true:
 * - Uses new RLSHelper that relies solely on database RLS
 * - Application only catches and logs RLS errors
 * - Single source of truth for access control
 * 
 * To enable in production:
 * 1. Set USE_SIMPLIFIED_RLS=true in your deployment platform
 * 2. Monitor audit logs for any access issues
 * 3. Can instantly rollback by setting to false
 */
export const USE_SIMPLIFIED_RLS = process.env.NEXT_PUBLIC_USE_SIMPLIFIED_RLS === 'true'

// Log the current mode in development
if (process.env.NODE_ENV === 'development') {
  // eslint-disable-next-line no-console
  console.log(`[Feature Flags] RLS Mode: ${USE_SIMPLIFIED_RLS ? 'Simplified (v2)' : 'Legacy (current)'}`)
}
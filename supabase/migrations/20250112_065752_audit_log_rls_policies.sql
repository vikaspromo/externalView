-- ============================================================================
-- Migration: Add RLS Policies for Security Audit Log
-- Date: 2025-01-12
-- Purpose: Enable RLS and create policies for the security_audit_log table
-- Security: Ensures users can only see their own audit logs, admins see all
-- ============================================================================

-- Enable RLS on security_audit_log table
ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can insert their own audit log entries
-- ============================================================================
-- This allows the frontend to write audit events for the current user
CREATE POLICY "users_insert_own_audit_logs" 
ON security_audit_log
FOR INSERT 
WITH CHECK (
  auth.uid() IS NOT NULL
  AND (
    user_id = auth.uid() 
    OR user_id IS NULL  -- Allow anonymous events (e.g., failed login attempts)
  )
);

-- ============================================================================
-- POLICY 2: Users can view their own audit logs
-- ============================================================================
-- Regular users can only see audit events related to their own actions
CREATE POLICY "users_view_own_audit_logs" 
ON security_audit_log
FOR SELECT 
USING (
  user_id = auth.uid()
);

-- ============================================================================
-- POLICY 3: Admins can view all audit logs
-- ============================================================================
-- Admins need to see all security events for monitoring and compliance
CREATE POLICY "admins_view_all_audit_logs" 
ON security_audit_log
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM user_admins 
    WHERE user_id = auth.uid() 
    AND active = true
  )
);

-- ============================================================================
-- POLICY 4: System can insert audit logs for any user
-- ============================================================================
-- This allows backend functions and triggers to write audit logs
-- Note: This uses SECURITY DEFINER functions which bypass RLS
CREATE POLICY "system_insert_audit_logs" 
ON security_audit_log
FOR INSERT 
WITH CHECK (
  -- Check if the operation is being performed by a system function
  -- This is handled by SECURITY DEFINER functions
  current_setting('request.jwt.claim.sub', true) IS NOT NULL
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for user-specific queries
CREATE INDEX IF NOT EXISTS idx_audit_log_user_created 
ON security_audit_log(user_id, created_at DESC);

-- Index for event type filtering
CREATE INDEX IF NOT EXISTS idx_audit_log_event_type 
ON security_audit_log(event_type, created_at DESC);

-- Index for client-specific queries
CREATE INDEX IF NOT EXISTS idx_audit_log_client 
ON security_audit_log(client_uuid, created_at DESC);

-- Index for finding failed attempts
CREATE INDEX IF NOT EXISTS idx_audit_log_failures 
ON security_audit_log(success, created_at DESC) 
WHERE success = false;

-- ============================================================================
-- HELPER FUNCTION: Get audit log summary for dashboard
-- ============================================================================
CREATE OR REPLACE FUNCTION get_audit_summary(
  p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  total_events BIGINT,
  failed_attempts BIGINT,
  unique_users BIGINT,
  event_types JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_since TIMESTAMP WITH TIME ZONE;
  v_is_admin BOOLEAN;
BEGIN
  -- Calculate the time window
  v_since := NOW() - (p_hours || ' hours')::INTERVAL;
  
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM user_admins 
    WHERE user_id = auth.uid() 
    AND active = true
  ) INTO v_is_admin;
  
  -- Return summary based on user type
  IF v_is_admin THEN
    -- Admins see all events
    RETURN QUERY
    SELECT 
      COUNT(*)::BIGINT as total_events,
      COUNT(*) FILTER (WHERE success = false)::BIGINT as failed_attempts,
      COUNT(DISTINCT user_id)::BIGINT as unique_users,
      jsonb_object_agg(
        event_type, 
        count_by_type
      ) as event_types
    FROM (
      SELECT 
        event_type,
        COUNT(*) as count_by_type
      FROM security_audit_log
      WHERE created_at >= v_since
      GROUP BY event_type
    ) event_counts
    CROSS JOIN LATERAL (
      SELECT 1
    ) dummy
    GROUP BY dummy;
  ELSE
    -- Regular users see only their events
    RETURN QUERY
    SELECT 
      COUNT(*)::BIGINT as total_events,
      COUNT(*) FILTER (WHERE success = false)::BIGINT as failed_attempts,
      1::BIGINT as unique_users,  -- Always 1 for regular users
      jsonb_object_agg(
        event_type, 
        count_by_type
      ) as event_types
    FROM (
      SELECT 
        event_type,
        COUNT(*) as count_by_type
      FROM security_audit_log
      WHERE created_at >= v_since
      AND user_id = auth.uid()
      GROUP BY event_type
    ) event_counts
    CROSS JOIN LATERAL (
      SELECT 1
    ) dummy
    GROUP BY dummy;
  END IF;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT ON security_audit_log TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_summary TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE security_audit_log IS 'Stores security-related events for audit trail and compliance';
COMMENT ON POLICY "users_insert_own_audit_logs" ON security_audit_log IS 'Allows users to create audit log entries for their own actions';
COMMENT ON POLICY "users_view_own_audit_logs" ON security_audit_log IS 'Allows users to view their own audit history';
COMMENT ON POLICY "admins_view_all_audit_logs" ON security_audit_log IS 'Allows administrators to view all audit logs for security monitoring';
COMMENT ON FUNCTION get_audit_summary IS 'Returns a summary of audit events for dashboard display';
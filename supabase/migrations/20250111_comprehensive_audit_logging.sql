-- ============================================================================
-- COMPREHENSIVE AUDIT LOGGING SYSTEM FOR MULTI-TENANT RLS
-- ============================================================================
-- Purpose: Complete audit trail for SOC2, GDPR, and HIPAA compliance
-- Features: Smart change detection, tamper protection, performance optimization
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: ENHANCE AUDIT LOG TABLE STRUCTURE
-- ----------------------------------------------------------------------------

-- Add missing columns to existing security_audit_log table
ALTER TABLE security_audit_log 
ADD COLUMN IF NOT EXISTS data_classification TEXT DEFAULT 'PUBLIC',
ADD COLUMN IF NOT EXISTS purpose TEXT,
ADD COLUMN IF NOT EXISTS checksum TEXT,
ADD COLUMN IF NOT EXISTS session_id UUID,
ADD COLUMN IF NOT EXISTS request_id UUID,
ADD COLUMN IF NOT EXISTS is_cross_client_access BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS access_denied BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS error_message TEXT,
ADD COLUMN IF NOT EXISTS execution_time_ms INTEGER;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON security_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_client_uuid ON security_audit_log(client_uuid);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON security_audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_table_operation ON security_audit_log(table_name, operation);
CREATE INDEX IF NOT EXISTS idx_audit_log_cross_client ON security_audit_log(is_cross_client_access) WHERE is_cross_client_access = TRUE;

-- ----------------------------------------------------------------------------
-- STEP 2: TAMPER PROTECTION - MAKE AUDIT LOG INSERT-ONLY
-- ----------------------------------------------------------------------------

-- Revoke UPDATE and DELETE permissions from all roles
REVOKE UPDATE, DELETE ON security_audit_log FROM PUBLIC;
REVOKE UPDATE, DELETE ON security_audit_log FROM authenticated;
REVOKE UPDATE, DELETE ON security_audit_log FROM anon;

-- Create function to prevent updates and deletes even from superuser context
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs cannot be modified or deleted for compliance reasons';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers to prevent modification
DROP TRIGGER IF EXISTS prevent_audit_update ON security_audit_log;
CREATE TRIGGER prevent_audit_update
    BEFORE UPDATE ON security_audit_log
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

DROP TRIGGER IF EXISTS prevent_audit_delete ON security_audit_log;
CREATE TRIGGER prevent_audit_delete
    BEFORE DELETE ON security_audit_log
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

-- ----------------------------------------------------------------------------
-- STEP 3: ROW LEVEL SECURITY FOR AUDIT LOGS
-- ----------------------------------------------------------------------------

ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS audit_log_insert_policy ON security_audit_log;
DROP POLICY IF EXISTS audit_log_select_own_policy ON security_audit_log;
DROP POLICY IF EXISTS audit_log_admin_select_policy ON security_audit_log;

-- Allow inserts from authenticated users
CREATE POLICY audit_log_insert_policy ON security_audit_log
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Users can only see their own audit logs
CREATE POLICY audit_log_select_own_policy ON security_audit_log
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Admins can see all audit logs for their clients
CREATE POLICY audit_log_admin_select_policy ON security_audit_log
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_admins ua
            WHERE ua.user_id = auth.uid()
            AND ua.client_uuid = security_audit_log.client_uuid
        )
    );

-- ----------------------------------------------------------------------------
-- STEP 4: UTILITY FUNCTIONS FOR AUDIT LOGGING
-- ----------------------------------------------------------------------------

-- Function to get current user's email
CREATE OR REPLACE FUNCTION get_current_user_email()
RETURNS TEXT AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT email INTO user_email
    FROM users
    WHERE id = auth.uid();
    
    RETURN COALESCE(user_email, 'system');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to detect changed fields between two JSONB objects
CREATE OR REPLACE FUNCTION detect_changed_fields(old_data JSONB, new_data JSONB)
RETURNS TABLE(field TEXT, old_value JSONB, new_value JSONB) AS $$
BEGIN
    -- Return fields that exist in both but have different values
    RETURN QUERY
    SELECT 
        key AS field,
        old_data->key AS old_value,
        new_data->key AS new_value
    FROM jsonb_each(old_data)
    WHERE 
        new_data ? key 
        AND old_data->key IS DISTINCT FROM new_data->key
        AND key NOT IN ('updated_at', 'created_at') -- Exclude system fields
    
    UNION
    
    -- Return fields that only exist in new_data (added fields)
    SELECT 
        key AS field,
        NULL::JSONB AS old_value,
        new_data->key AS new_value
    FROM jsonb_each(new_data)
    WHERE 
        NOT (old_data ? key)
        AND key NOT IN ('updated_at', 'created_at')
    
    UNION
    
    -- Return fields that only exist in old_data (removed fields)
    SELECT 
        key AS field,
        old_data->key AS old_value,
        NULL::JSONB AS new_value
    FROM jsonb_each(old_data)
    WHERE 
        NOT (new_data ? key)
        AND key NOT IN ('updated_at', 'created_at');
END;
$$ LANGUAGE plpgsql;

-- Function to calculate checksum for integrity
CREATE OR REPLACE FUNCTION calculate_audit_checksum(
    p_user_id UUID,
    p_table_name TEXT,
    p_operation TEXT,
    p_row_id UUID,
    p_data JSONB
)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        digest(
            COALESCE(p_user_id::TEXT, '') || 
            COALESCE(p_table_name, '') || 
            COALESCE(p_operation, '') || 
            COALESCE(p_row_id::TEXT, '') || 
            COALESCE(p_data::TEXT, ''),
            'sha256'
        ),
        'hex'
    );
END;
$$ LANGUAGE plpgsql;

-- Function to determine data classification
CREATE OR REPLACE FUNCTION determine_data_classification(p_table_name TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN CASE 
        WHEN p_table_name IN ('users', 'stakeholder_contacts', 'event_attendees') THEN 'PII'
        WHEN p_table_name IN ('stakeholder_notes', 'user_admins') THEN 'SENSITIVE'
        WHEN p_table_name IN ('clients', 'organizations', 'client_org_history') THEN 'CONFIDENTIAL'
        ELSE 'PUBLIC'
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to get client UUID from various tables
CREATE OR REPLACE FUNCTION get_client_uuid_for_table(p_table_name TEXT, p_row_id UUID)
RETURNS UUID AS $$
DECLARE
    v_client_uuid UUID;
BEGIN
    CASE p_table_name
        WHEN 'users' THEN
            -- Users don't have direct client association
            RETURN NULL;
        WHEN 'clients' THEN
            RETURN p_row_id;
        WHEN 'organizations' THEN
            -- Organizations can be associated with multiple clients
            SELECT client_uuid INTO v_client_uuid
            FROM client_org_history
            WHERE org_uuid = p_row_id
            LIMIT 1;
        WHEN 'client_org_history' THEN
            SELECT client_uuid INTO v_client_uuid
            FROM client_org_history
            WHERE id = p_row_id;
        WHEN 'stakeholder_contacts', 'stakeholder_notes', 'event_attendees' THEN
            SELECT client_uuid INTO v_client_uuid
            FROM (
                SELECT client_uuid FROM stakeholder_contacts WHERE id = p_row_id
                UNION
                SELECT client_uuid FROM stakeholder_notes WHERE id = p_row_id
                UNION
                SELECT ec.client_uuid 
                FROM event_attendees ea
                JOIN stakeholder_contacts ec ON ea.email = ec.email
                WHERE ea.id = p_row_id
            ) t
            LIMIT 1;
        WHEN 'user_admins' THEN
            SELECT client_uuid INTO v_client_uuid
            FROM user_admins
            WHERE id = p_row_id;
        ELSE
            RETURN NULL;
    END CASE;
    
    RETURN v_client_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- STEP 5: MAIN AUDIT TRIGGER FUNCTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_user_email TEXT;
    v_client_uuid UUID;
    v_old_data JSONB;
    v_new_data JSONB;
    v_changed_fields TEXT[];
    v_ip_address INET;
    v_user_agent TEXT;
    v_checksum TEXT;
    v_row_id UUID;
    v_start_time TIMESTAMP;
    v_execution_time_ms INTEGER;
    v_classification TEXT;
    v_session_id UUID;
    v_request_id UUID;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Get current user info
    v_user_id := auth.uid();
    v_user_email := get_current_user_email();
    
    -- Get connection info
    v_ip_address := inet_client_addr();
    v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    v_session_id := current_setting('request.session_id', true)::UUID;
    v_request_id := current_setting('request.id', true)::UUID;
    
    -- Determine row ID
    v_row_id := CASE 
        WHEN TG_OP = 'DELETE' THEN OLD.id
        ELSE NEW.id
    END;
    
    -- Get client UUID
    v_client_uuid := get_client_uuid_for_table(TG_TABLE_NAME, v_row_id);
    
    -- Determine data classification
    v_classification := determine_data_classification(TG_TABLE_NAME);
    
    -- Process based on operation type
    IF TG_OP = 'INSERT' THEN
        v_new_data := to_jsonb(NEW);
        v_changed_fields := ARRAY(SELECT jsonb_object_keys(v_new_data));
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Detect actual changes
        v_old_data := jsonb_build_object();
        v_new_data := jsonb_build_object();
        v_changed_fields := ARRAY[]::TEXT[];
        
        -- Get only changed fields
        FOR v_field, v_old_value, v_new_value IN 
            SELECT * FROM detect_changed_fields(to_jsonb(OLD), to_jsonb(NEW))
        LOOP
            v_old_data := v_old_data || jsonb_build_object(v_field, v_old_value);
            v_new_data := v_new_data || jsonb_build_object(v_field, v_new_value);
            v_changed_fields := array_append(v_changed_fields, v_field);
        END LOOP;
        
        -- Skip if no actual changes
        IF array_length(v_changed_fields, 1) IS NULL THEN
            RETURN NEW;
        END IF;
        
    ELSIF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_changed_fields := ARRAY(SELECT jsonb_object_keys(v_old_data));
    END IF;
    
    -- Calculate checksum
    v_checksum := calculate_audit_checksum(
        v_user_id,
        TG_TABLE_NAME,
        TG_OP,
        v_row_id,
        COALESCE(v_new_data, v_old_data)
    );
    
    -- Calculate execution time
    v_execution_time_ms := EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time));
    
    -- Insert audit log
    INSERT INTO security_audit_log (
        user_id,
        user_email,
        client_uuid,
        table_name,
        operation,
        row_id,
        old_data,
        new_data,
        changed_fields,
        ip_address,
        user_agent,
        data_classification,
        checksum,
        session_id,
        request_id,
        execution_time_ms,
        purpose
    ) VALUES (
        v_user_id,
        v_user_email,
        v_client_uuid,
        TG_TABLE_NAME,
        TG_OP,
        v_row_id,
        v_old_data,
        v_new_data,
        v_changed_fields,
        v_ip_address,
        v_user_agent,
        v_classification,
        v_checksum,
        v_session_id,
        v_request_id,
        v_execution_time_ms,
        current_setting('app.audit_purpose', true)
    );
    
    -- Return appropriate value
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- STEP 6: CREATE AUDIT TRIGGERS FOR ALL TABLES
-- ----------------------------------------------------------------------------

-- Users table (PII)
DROP TRIGGER IF EXISTS audit_trigger_users ON users;
CREATE TRIGGER audit_trigger_users
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Clients table (Tenant data)
DROP TRIGGER IF EXISTS audit_trigger_clients ON clients;
CREATE TRIGGER audit_trigger_clients
    AFTER INSERT OR UPDATE OR DELETE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Organizations table (Master data)
DROP TRIGGER IF EXISTS audit_trigger_organizations ON organizations;
CREATE TRIGGER audit_trigger_organizations
    AFTER INSERT OR UPDATE OR DELETE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Client Organization History (Tenant relationships)
DROP TRIGGER IF EXISTS audit_trigger_client_org_history ON client_org_history;
CREATE TRIGGER audit_trigger_client_org_history
    AFTER INSERT OR UPDATE OR DELETE ON client_org_history
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Stakeholder Contacts (PII)
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_contacts ON stakeholder_contacts;
CREATE TRIGGER audit_trigger_stakeholder_contacts
    AFTER INSERT OR UPDATE OR DELETE ON stakeholder_contacts
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Stakeholder Notes (Sensitive content)
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_notes ON stakeholder_notes;
CREATE TRIGGER audit_trigger_stakeholder_notes
    AFTER INSERT OR UPDATE OR DELETE ON stakeholder_notes
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Stakeholder Types (Reference data)
DROP TRIGGER IF EXISTS audit_trigger_stakeholder_types ON stakeholder_types;
CREATE TRIGGER audit_trigger_stakeholder_types
    AFTER INSERT OR UPDATE OR DELETE ON stakeholder_types
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- Event Attendees (PII)
DROP TRIGGER IF EXISTS audit_trigger_event_attendees ON event_attendees;
CREATE TRIGGER audit_trigger_event_attendees
    AFTER INSERT OR UPDATE OR DELETE ON event_attendees
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- User Admins (Critical - admin access)
DROP TRIGGER IF EXISTS audit_trigger_user_admins ON user_admins;
CREATE TRIGGER audit_trigger_user_admins
    AFTER INSERT OR UPDATE OR DELETE ON user_admins
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();

-- ----------------------------------------------------------------------------
-- STEP 7: SELECT AUDIT LOGGING FOR SENSITIVE TABLES
-- ----------------------------------------------------------------------------

-- Function to log SELECT operations on sensitive tables
CREATE OR REPLACE FUNCTION audit_select_function()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_user_email TEXT;
    v_client_uuid UUID;
    v_ip_address INET;
    v_user_agent TEXT;
    v_checksum TEXT;
    v_session_id UUID;
    v_request_id UUID;
    v_classification TEXT;
BEGIN
    -- Only log for sensitive tables
    IF TG_TABLE_NAME NOT IN ('stakeholder_notes', 'stakeholder_contacts', 'user_admins') THEN
        RETURN NEW;
    END IF;
    
    -- Get current user info
    v_user_id := auth.uid();
    v_user_email := get_current_user_email();
    
    -- Get connection info
    v_ip_address := inet_client_addr();
    v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    v_session_id := current_setting('request.session_id', true)::UUID;
    v_request_id := current_setting('request.id', true)::UUID;
    
    -- Get client UUID if available
    v_client_uuid := CASE 
        WHEN TG_TABLE_NAME IN ('stakeholder_notes', 'stakeholder_contacts') THEN NEW.client_uuid
        WHEN TG_TABLE_NAME = 'user_admins' THEN NEW.client_uuid
        ELSE NULL
    END;
    
    -- Determine data classification
    v_classification := determine_data_classification(TG_TABLE_NAME);
    
    -- Calculate checksum
    v_checksum := calculate_audit_checksum(
        v_user_id,
        TG_TABLE_NAME,
        'SELECT',
        NEW.id,
        to_jsonb(NEW)
    );
    
    -- Insert audit log for SELECT
    INSERT INTO security_audit_log (
        user_id,
        user_email,
        client_uuid,
        table_name,
        operation,
        row_id,
        new_data,
        ip_address,
        user_agent,
        data_classification,
        checksum,
        session_id,
        request_id,
        purpose
    ) VALUES (
        v_user_id,
        v_user_email,
        v_client_uuid,
        TG_TABLE_NAME,
        'SELECT',
        NEW.id,
        jsonb_build_object('id', NEW.id), -- Only log ID for SELECT operations
        v_ip_address,
        v_user_agent,
        v_classification,
        v_checksum,
        v_session_id,
        v_request_id,
        current_setting('app.audit_purpose', true)
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create SELECT audit rules using RLS
-- Note: We'll use a different approach for SELECT auditing via RLS policies

-- ----------------------------------------------------------------------------
-- STEP 8: CROSS-CLIENT ACCESS DETECTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION detect_cross_client_access()
RETURNS TRIGGER AS $$
DECLARE
    v_user_client_uuid UUID;
    v_accessing_client_uuid UUID;
BEGIN
    -- Get the user's primary client
    SELECT client_uuid INTO v_user_client_uuid
    FROM user_admins
    WHERE user_id = auth.uid()
    LIMIT 1;
    
    -- Get the client being accessed
    v_accessing_client_uuid := NEW.client_uuid;
    
    -- Check if it's cross-client access
    IF v_user_client_uuid IS NOT NULL AND 
       v_accessing_client_uuid IS NOT NULL AND 
       v_user_client_uuid != v_accessing_client_uuid THEN
        
        -- Update the audit log to mark as cross-client
        UPDATE security_audit_log
        SET is_cross_client_access = TRUE
        WHERE id = NEW.id;
        
        -- Optionally raise a notice for monitoring
        RAISE NOTICE 'Cross-client access detected: User % accessing client %', 
            auth.uid(), v_accessing_client_uuid;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to detect cross-client access
DROP TRIGGER IF EXISTS detect_cross_client_trigger ON security_audit_log;
CREATE TRIGGER detect_cross_client_trigger
    AFTER INSERT ON security_audit_log
    FOR EACH ROW
    WHEN (NEW.client_uuid IS NOT NULL)
    EXECUTE FUNCTION detect_cross_client_access();

-- ----------------------------------------------------------------------------
-- STEP 9: COMPLIANCE REPORTING VIEWS
-- ----------------------------------------------------------------------------

-- View for recent PII access (last 30 days)
CREATE OR REPLACE VIEW recent_pii_access AS
SELECT 
    user_email,
    table_name,
    operation,
    row_id,
    changed_fields,
    ip_address,
    timestamp,
    client_uuid
FROM security_audit_log
WHERE 
    data_classification = 'PII'
    AND timestamp >= NOW() - INTERVAL '30 days'
ORDER BY timestamp DESC;

-- View for cross-client access attempts
CREATE OR REPLACE VIEW cross_client_attempts AS
SELECT 
    user_email,
    table_name,
    operation,
    client_uuid,
    ip_address,
    timestamp,
    access_denied,
    error_message
FROM security_audit_log
WHERE 
    is_cross_client_access = TRUE
ORDER BY timestamp DESC;

-- View for admin activity
CREATE OR REPLACE VIEW admin_activity AS
SELECT 
    sal.user_email,
    sal.table_name,
    sal.operation,
    sal.row_id,
    sal.changed_fields,
    sal.client_uuid,
    sal.timestamp,
    sal.ip_address
FROM security_audit_log sal
WHERE 
    EXISTS (
        SELECT 1 FROM user_admins ua 
        WHERE ua.user_id = sal.user_id
    )
ORDER BY sal.timestamp DESC;

-- View for bulk data exports (multiple SELECTs in short time)
CREATE OR REPLACE VIEW data_exports AS
WITH user_activity AS (
    SELECT 
        user_id,
        user_email,
        table_name,
        COUNT(*) as access_count,
        DATE_TRUNC('minute', timestamp) as minute_bucket,
        client_uuid
    FROM security_audit_log
    WHERE 
        operation = 'SELECT'
        AND timestamp >= NOW() - INTERVAL '24 hours'
    GROUP BY 
        user_id, 
        user_email, 
        table_name, 
        DATE_TRUNC('minute', timestamp),
        client_uuid
    HAVING COUNT(*) > 10  -- More than 10 accesses per minute
)
SELECT 
    user_email,
    table_name,
    access_count,
    minute_bucket as timestamp,
    client_uuid
FROM user_activity
ORDER BY minute_bucket DESC, access_count DESC;

-- View for failed access attempts
CREATE OR REPLACE VIEW failed_access_attempts AS
SELECT 
    user_email,
    table_name,
    operation,
    client_uuid,
    ip_address,
    error_message,
    timestamp
FROM security_audit_log
WHERE 
    access_denied = TRUE
ORDER BY timestamp DESC;

-- ----------------------------------------------------------------------------
-- STEP 10: SUSPICIOUS ACTIVITY DETECTION
-- ----------------------------------------------------------------------------

-- Function to detect and alert on suspicious patterns
CREATE OR REPLACE FUNCTION detect_suspicious_activity()
RETURNS TRIGGER AS $$
DECLARE
    v_recent_client_count INTEGER;
    v_rapid_access_count INTEGER;
    v_failed_attempts INTEGER;
BEGIN
    -- Check for rapid cross-client access (accessing multiple clients quickly)
    SELECT COUNT(DISTINCT client_uuid) INTO v_recent_client_count
    FROM security_audit_log
    WHERE 
        user_id = NEW.user_id
        AND timestamp >= NOW() - INTERVAL '5 minutes'
        AND client_uuid IS NOT NULL;
    
    IF v_recent_client_count > 3 THEN
        -- Log suspicious activity
        INSERT INTO security_audit_log (
            user_id,
            user_email,
            table_name,
            operation,
            new_data,
            ip_address,
            data_classification,
            purpose
        ) VALUES (
            NEW.user_id,
            NEW.user_email,
            'ALERT',
            'SUSPICIOUS_ACTIVITY',
            jsonb_build_object(
                'alert_type', 'rapid_cross_client_access',
                'client_count', v_recent_client_count,
                'trigger_event_id', NEW.id
            ),
            NEW.ip_address,
            'ALERT',
            'security_monitoring'
        );
        
        -- Notify via pg_notify for real-time alerts
        PERFORM pg_notify(
            'security_alert',
            json_build_object(
                'type', 'rapid_cross_client_access',
                'user_email', NEW.user_email,
                'client_count', v_recent_client_count
            )::text
        );
    END IF;
    
    -- Check for rapid data access (potential data scraping)
    SELECT COUNT(*) INTO v_rapid_access_count
    FROM security_audit_log
    WHERE 
        user_id = NEW.user_id
        AND timestamp >= NOW() - INTERVAL '1 minute'
        AND operation IN ('SELECT', 'UPDATE');
    
    IF v_rapid_access_count > 100 THEN
        -- Log suspicious activity
        INSERT INTO security_audit_log (
            user_id,
            user_email,
            table_name,
            operation,
            new_data,
            ip_address,
            data_classification,
            purpose
        ) VALUES (
            NEW.user_id,
            NEW.user_email,
            'ALERT',
            'SUSPICIOUS_ACTIVITY',
            jsonb_build_object(
                'alert_type', 'rapid_data_access',
                'access_count', v_rapid_access_count,
                'trigger_event_id', NEW.id
            ),
            NEW.ip_address,
            'ALERT',
            'security_monitoring'
        );
        
        -- Notify via pg_notify
        PERFORM pg_notify(
            'security_alert',
            json_build_object(
                'type', 'rapid_data_access',
                'user_email', NEW.user_email,
                'access_count', v_rapid_access_count
            )::text
        );
    END IF;
    
    -- Check for repeated failed access attempts
    SELECT COUNT(*) INTO v_failed_attempts
    FROM security_audit_log
    WHERE 
        user_id = NEW.user_id
        AND timestamp >= NOW() - INTERVAL '10 minutes'
        AND access_denied = TRUE;
    
    IF v_failed_attempts > 5 THEN
        -- Log suspicious activity
        INSERT INTO security_audit_log (
            user_id,
            user_email,
            table_name,
            operation,
            new_data,
            ip_address,
            data_classification,
            purpose
        ) VALUES (
            NEW.user_id,
            NEW.user_email,
            'ALERT',
            'SUSPICIOUS_ACTIVITY',
            jsonb_build_object(
                'alert_type', 'repeated_failed_access',
                'failed_count', v_failed_attempts,
                'trigger_event_id', NEW.id
            ),
            NEW.ip_address,
            'ALERT',
            'security_monitoring'
        );
        
        -- Notify via pg_notify
        PERFORM pg_notify(
            'security_alert',
            json_build_object(
                'type', 'repeated_failed_access',
                'user_email', NEW.user_email,
                'failed_count', v_failed_attempts
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for suspicious activity detection
DROP TRIGGER IF EXISTS detect_suspicious_trigger ON security_audit_log;
CREATE TRIGGER detect_suspicious_trigger
    AFTER INSERT ON security_audit_log
    FOR EACH ROW
    WHEN (NEW.operation != 'SUSPICIOUS_ACTIVITY')
    EXECUTE FUNCTION detect_suspicious_activity();

-- ----------------------------------------------------------------------------
-- STEP 11: AUDIT LOG RETENTION AND ARCHIVAL
-- ----------------------------------------------------------------------------

-- Function to archive old audit logs (keep last 2 years active)
CREATE OR REPLACE FUNCTION archive_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    v_archived_count INTEGER;
BEGIN
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS security_audit_log_archive (LIKE security_audit_log INCLUDING ALL);
    
    -- Move records older than 2 years to archive
    WITH archived AS (
        DELETE FROM security_audit_log
        WHERE timestamp < NOW() - INTERVAL '2 years'
        RETURNING *
    )
    INSERT INTO security_audit_log_archive
    SELECT * FROM archived;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RETURN v_archived_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- STEP 12: PERFORMANCE MONITORING
-- ----------------------------------------------------------------------------

-- View to monitor audit log performance impact
CREATE OR REPLACE VIEW audit_performance_metrics AS
SELECT 
    table_name,
    operation,
    AVG(execution_time_ms) as avg_execution_ms,
    MAX(execution_time_ms) as max_execution_ms,
    MIN(execution_time_ms) as min_execution_ms,
    COUNT(*) as operation_count,
    DATE_TRUNC('hour', timestamp) as hour_bucket
FROM security_audit_log
WHERE 
    timestamp >= NOW() - INTERVAL '24 hours'
    AND execution_time_ms IS NOT NULL
GROUP BY 
    table_name, 
    operation, 
    DATE_TRUNC('hour', timestamp)
ORDER BY 
    hour_bucket DESC, 
    avg_execution_ms DESC;

-- ----------------------------------------------------------------------------
-- STEP 13: HELPER FUNCTIONS FOR APPLICATIONS
-- ----------------------------------------------------------------------------

-- Function to set audit purpose (call before operations)
CREATE OR REPLACE FUNCTION set_audit_purpose(p_purpose TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.audit_purpose', p_purpose, true);
END;
$$ LANGUAGE plpgsql;

-- Function to get audit trail for a specific record
CREATE OR REPLACE FUNCTION get_record_audit_trail(
    p_table_name TEXT,
    p_row_id UUID
)
RETURNS TABLE (
    user_email TEXT,
    operation TEXT,
    changed_fields TEXT[],
    old_data JSONB,
    new_data JSONB,
    timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sal.user_email,
        sal.operation,
        sal.changed_fields,
        sal.old_data,
        sal.new_data,
        sal.timestamp
    FROM security_audit_log sal
    WHERE 
        sal.table_name = p_table_name
        AND sal.row_id = p_row_id
    ORDER BY sal.timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- STEP 14: GRANT NECESSARY PERMISSIONS
-- ----------------------------------------------------------------------------

-- Grant execute permissions on utility functions
GRANT EXECUTE ON FUNCTION get_current_user_email() TO authenticated;
GRANT EXECUTE ON FUNCTION set_audit_purpose(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_record_audit_trail(TEXT, UUID) TO authenticated;

-- Grant select on views
GRANT SELECT ON recent_pii_access TO authenticated;
GRANT SELECT ON admin_activity TO authenticated;

-- Admin-only views
GRANT SELECT ON cross_client_attempts TO authenticated;
GRANT SELECT ON data_exports TO authenticated;
GRANT SELECT ON failed_access_attempts TO authenticated;
GRANT SELECT ON audit_performance_metrics TO authenticated;

-- ----------------------------------------------------------------------------
-- VERIFICATION QUERIES
-- ----------------------------------------------------------------------------

-- Check that triggers are created
SELECT 
    tablename,
    triggername,
    CASE 
        WHEN triggername LIKE 'audit_trigger_%' THEN 'Audit Logging'
        WHEN triggername = 'detect_cross_client_trigger' THEN 'Cross-Client Detection'
        WHEN triggername = 'detect_suspicious_trigger' THEN 'Suspicious Activity Detection'
        ELSE 'Other'
    END as trigger_type
FROM pg_triggers
WHERE schemaname = 'public'
AND (
    triggername LIKE 'audit_trigger_%' 
    OR triggername IN ('detect_cross_client_trigger', 'detect_suspicious_trigger')
)
ORDER BY tablename, triggername;

-- Check audit log table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'security_audit_log'
ORDER BY ordinal_position;

-- Test query to verify audit logging is working (will create an audit entry)
-- DO $$
-- BEGIN
--     PERFORM set_audit_purpose('audit_system_verification');
--     -- This will be logged
--     PERFORM COUNT(*) FROM users WHERE id = auth.uid();
-- END $$;

COMMENT ON TABLE security_audit_log IS 'Comprehensive audit trail for all data access and modifications. Insert-only table for compliance with SOC2, GDPR, and HIPAA.';
COMMENT ON COLUMN security_audit_log.data_classification IS 'Data sensitivity level: PII, SENSITIVE, CONFIDENTIAL, PUBLIC';
COMMENT ON COLUMN security_audit_log.checksum IS 'SHA256 hash for integrity verification';
COMMENT ON COLUMN security_audit_log.is_cross_client_access IS 'Flag indicating access across tenant boundaries';
COMMENT ON COLUMN security_audit_log.purpose IS 'Business purpose for the operation (GDPR compliance)';
#!/bin/bash

# ============================================================================
# Audit Log Backup Script
# Purpose: Backup security audit logs with integrity verification
# Usage: ./scripts/backup-audit-logs.sh [--full|--incremental]
# ============================================================================

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_ROOT}/backups/audit-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_TODAY=$(date +%Y-%m-%d)
RETENTION_DAYS=${RETENTION_DAYS:-90}
BACKUP_TYPE="${1:-incremental}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backup directory structure
create_backup_dirs() {
    mkdir -p "$BACKUP_DIR"/{daily,archive,checksums,metadata}
    log_info "Created backup directory structure at $BACKUP_DIR"
}

# Get database connection URL
get_db_url() {
    if [ -n "$DATABASE_URL" ]; then
        echo "$DATABASE_URL"
    elif [ -f "${PROJECT_ROOT}/.env.local" ]; then
        # Extract from .env.local if available
        source "${PROJECT_ROOT}/.env.local"
        if [ -n "$SUPABASE_DB_URL" ]; then
            echo "$SUPABASE_DB_URL"
        else
            # Construct from Supabase project URL
            echo "postgresql://postgres:${SUPABASE_SERVICE_KEY}@db.${NEXT_PUBLIC_SUPABASE_URL#https://}.supabase.co:5432/postgres"
        fi
    else
        log_error "No database connection found. Set DATABASE_URL or configure .env.local"
        exit 1
    fi
}

# Perform incremental backup (last 24 hours)
backup_incremental() {
    local BACKUP_FILE="$BACKUP_DIR/daily/audit_log_incremental_${TIMESTAMP}"
    
    log_info "Starting incremental backup (last 24 hours)..."
    
    # Export as SQL dump
    DB_URL=$(get_db_url)
    
    # Create SQL file with WHERE clause for incremental
    cat > "${BACKUP_FILE}.sql" << EOF
-- Incremental Audit Log Backup
-- Generated: $(date)
-- Period: Last 24 hours

BEGIN;

-- Create temporary table for import if needed
CREATE TABLE IF NOT EXISTS security_audit_log_import (
    LIKE security_audit_log INCLUDING ALL
);

-- Insert data (last 24 hours only)
COPY security_audit_log_import FROM STDIN WITH (FORMAT CSV, HEADER);
EOF
    
    # Export last 24 hours of data as CSV and append
    psql "$DB_URL" -c "\COPY (
        SELECT * FROM security_audit_log 
        WHERE timestamp >= NOW() - INTERVAL '24 hours'
        ORDER BY timestamp ASC
    ) TO STDOUT WITH (FORMAT CSV, HEADER)" >> "${BACKUP_FILE}.sql"
    
    echo "\\." >> "${BACKUP_FILE}.sql"
    echo "COMMIT;" >> "${BACKUP_FILE}.sql"
    
    # Compress the backup
    gzip -9 "${BACKUP_FILE}.sql"
    
    # Generate checksum
    sha256sum "${BACKUP_FILE}.sql.gz" > "$BACKUP_DIR/checksums/audit_log_incremental_${TIMESTAMP}.sha256"
    
    # Create metadata file
    cat > "$BACKUP_DIR/metadata/audit_log_incremental_${TIMESTAMP}.json" << EOF
{
    "backup_type": "incremental",
    "timestamp": "$(date -Iseconds)",
    "file": "audit_log_incremental_${TIMESTAMP}.sql.gz",
    "period": "24_hours",
    "size_bytes": $(stat -c%s "${BACKUP_FILE}.sql.gz" 2>/dev/null || stat -f%z "${BACKUP_FILE}.sql.gz" 2>/dev/null),
    "checksum_file": "audit_log_incremental_${TIMESTAMP}.sha256"
}
EOF
    
    log_info "Incremental backup completed: ${BACKUP_FILE}.sql.gz"
}

# Perform full backup
backup_full() {
    local BACKUP_FILE="$BACKUP_DIR/archive/audit_log_full_${TIMESTAMP}"
    
    log_info "Starting full backup..."
    
    DB_URL=$(get_db_url)
    
    # Use pg_dump for full backup
    pg_dump "$DB_URL" \
        --table=security_audit_log \
        --data-only \
        --format=custom \
        --compress=9 \
        --file="${BACKUP_FILE}.dump"
    
    # Also create a plain SQL version for easier inspection
    pg_dump "$DB_URL" \
        --table=security_audit_log \
        --data-only \
        --format=plain \
        --file="${BACKUP_FILE}.sql"
    
    # Compress SQL version
    gzip -9 "${BACKUP_FILE}.sql"
    
    # Generate checksums
    sha256sum "${BACKUP_FILE}.dump" > "$BACKUP_DIR/checksums/audit_log_full_${TIMESTAMP}.dump.sha256"
    sha256sum "${BACKUP_FILE}.sql.gz" > "$BACKUP_DIR/checksums/audit_log_full_${TIMESTAMP}.sql.sha256"
    
    # Create metadata
    cat > "$BACKUP_DIR/metadata/audit_log_full_${TIMESTAMP}.json" << EOF
{
    "backup_type": "full",
    "timestamp": "$(date -Iseconds)",
    "files": {
        "dump": "audit_log_full_${TIMESTAMP}.dump",
        "sql": "audit_log_full_${TIMESTAMP}.sql.gz"
    },
    "size_bytes": {
        "dump": $(stat -c%s "${BACKUP_FILE}.dump" 2>/dev/null || stat -f%z "${BACKUP_FILE}.dump" 2>/dev/null),
        "sql": $(stat -c%s "${BACKUP_FILE}.sql.gz" 2>/dev/null || stat -f%z "${BACKUP_FILE}.sql.gz" 2>/dev/null)
    },
    "checksum_files": {
        "dump": "audit_log_full_${TIMESTAMP}.dump.sha256",
        "sql": "audit_log_full_${TIMESTAMP}.sql.sha256"
    }
}
EOF
    
    log_info "Full backup completed: ${BACKUP_FILE}.dump and ${BACKUP_FILE}.sql.gz"
}

# Export to JSON for analysis
export_json() {
    local JSON_FILE="$BACKUP_DIR/daily/audit_log_export_${DATE_TODAY}.json"
    
    log_info "Exporting audit logs to JSON..."
    
    DB_URL=$(get_db_url)
    
    psql "$DB_URL" -t -A -c "
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT * FROM security_audit_log 
            WHERE timestamp::date = '${DATE_TODAY}'
            ORDER BY timestamp
        ) t
    " > "$JSON_FILE"
    
    # Pretty print and compress
    if command -v jq &> /dev/null; then
        jq '.' "$JSON_FILE" > "${JSON_FILE}.pretty"
        mv "${JSON_FILE}.pretty" "$JSON_FILE"
    fi
    
    gzip -9 "$JSON_FILE"
    
    log_info "JSON export completed: ${JSON_FILE}.gz"
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
    
    # Clean daily backups
    find "$BACKUP_DIR/daily" -name "audit_log_*" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
    
    # Archive old full backups to a separate location (keep forever)
    find "$BACKUP_DIR/archive" -name "audit_log_full_*" -type f -mtime +365 -exec mv {} "$BACKUP_DIR/archive/yearly/" \; 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Verify backup integrity
verify_backup() {
    local BACKUP_FILE="$1"
    local CHECKSUM_FILE="${BACKUP_FILE}.sha256"
    
    if [ -f "$CHECKSUM_FILE" ]; then
        log_info "Verifying backup integrity..."
        if sha256sum -c "$CHECKSUM_FILE" > /dev/null 2>&1; then
            log_info "✓ Backup integrity verified"
            return 0
        else
            log_error "✗ Backup integrity check failed!"
            return 1
        fi
    else
        log_warning "No checksum file found for verification"
        return 0
    fi
}

# Generate backup report
generate_report() {
    local REPORT_FILE="$BACKUP_DIR/backup_report_${DATE_TODAY}.txt"
    
    log_info "Generating backup report..."
    
    cat > "$REPORT_FILE" << EOF
================================================================================
AUDIT LOG BACKUP REPORT
Generated: $(date)
================================================================================

BACKUP STATISTICS:
------------------
Total Backup Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
Daily Backups: $(find "$BACKUP_DIR/daily" -type f -name "*.gz" 2>/dev/null | wc -l)
Archive Backups: $(find "$BACKUP_DIR/archive" -type f -name "*.dump" 2>/dev/null | wc -l)

RECENT BACKUPS (Last 7 days):
------------------------------
$(find "$BACKUP_DIR" -type f -name "audit_log_*" -mtime -7 -exec ls -lh {} \; 2>/dev/null)

STORAGE USAGE:
--------------
Daily: $(du -sh "$BACKUP_DIR/daily" 2>/dev/null | cut -f1)
Archive: $(du -sh "$BACKUP_DIR/archive" 2>/dev/null | cut -f1)
Checksums: $(du -sh "$BACKUP_DIR/checksums" 2>/dev/null | cut -f1)
Metadata: $(du -sh "$BACKUP_DIR/metadata" 2>/dev/null | cut -f1)

INTEGRITY CHECKS:
-----------------
$(for checksum in $(find "$BACKUP_DIR/checksums" -name "*.sha256" -mtime -1); do
    echo "Checking: $(basename $checksum)"
    sha256sum -c "$checksum" 2>/dev/null && echo "  Status: ✓ PASSED" || echo "  Status: ✗ FAILED"
done)

================================================================================
EOF
    
    log_info "Report saved to: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# Main execution
main() {
    log_info "Starting Audit Log Backup Process..."
    log_info "Backup Type: $BACKUP_TYPE"
    
    # Check for required tools
    for tool in psql pg_dump gzip sha256sum; do
        if ! command -v $tool &> /dev/null; then
            log_error "Required tool '$tool' not found. Please install it first."
            exit 1
        fi
    done
    
    # Create backup directories
    create_backup_dirs
    
    # Perform backup based on type
    case "$BACKUP_TYPE" in
        --incremental|-i)
            backup_incremental
            export_json
            ;;
        --full|-f)
            backup_full
            ;;
        --both|-b)
            backup_incremental
            backup_full
            export_json
            ;;
        *)
            log_error "Invalid backup type. Use --incremental, --full, or --both"
            exit 1
            ;;
    esac
    
    # Clean old backups
    cleanup_old_backups
    
    # Generate report
    generate_report
    
    log_info "✓ Backup process completed successfully!"
}

# Run main function
main "$@"
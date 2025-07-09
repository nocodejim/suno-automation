#!/bin/bash
# Backup and Restore Script for Suno Automation

set -e

BACKUP_DIR="backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="suno-automation-backup-$TIMESTAMP"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

create_backup() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    log_info "Creating backup: $backup_path"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup essential files
    log_info "Backing up configuration files..."
    cp -f .env .env.example package*.json docker-compose.yml "$backup_path/" 2>/dev/null || true
    
    # Backup session data (if exists)
    if [[ -f session.json ]]; then
        log_info "Backing up session data..."
        cp session.json "$backup_path/"
    else
        log_warning "No session.json found to backup"
    fi
    
    # Create archive
    log_info "Creating compressed archive..."
    tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    rm -rf "$backup_path"
    
    log_success "Backup created: $backup_path.tar.gz"
}

# Main execution
case "${1:-create}" in
    "create")
        create_backup
        ;;
    *)
        echo "Usage: $0 [create]"
        ;;
esac

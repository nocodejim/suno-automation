#!/bin/bash
# CSV Validation Script
# Checks CSV files for common issues before automation runs

set -e

CSV_FILE="${1:-input/songs/songs.csv}"
TEMP_DIR="/tmp/csv-validation-$$"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

validate_csv() {
    local file="$1"
    local errors=0
    local warnings=0
    
    log_info "Validating CSV file: $file"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_error "CSV file not found: $file"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$file" ]]; then
        log_error "CSV file is not readable: $file"
        return 1
    fi
    
    # Check if file is empty
    if [[ ! -s "$file" ]]; then
        log_error "CSV file is empty: $file"
        return 1
    fi
    
    # Create temp directory for analysis
    mkdir -p "$TEMP_DIR"
    
    # Basic file info
    local line_count=$(wc -l < "$file")
    local file_size=$(du -h "$file" | cut -f1)
    log_info "File size: $file_size, Lines: $line_count"
    
    # Check header row
    local header=$(head -n1 "$file")
    log_info "Header: $header"
    
    if [[ "$header" != *"title"* ]] || [[ "$header" != *"style"* ]] || [[ "$header" != *"lyrics"* ]]; then
        log_error "Header row must contain: title, style, lyrics"
        ((errors++))
    fi
    
    # Summary
    echo ""
    log_info "Validation Summary:"
    echo "  Total rows: $((line_count - 1))"
    echo "  Errors: $errors"
    echo "  Warnings: $warnings"
    
    if [[ $errors -eq 0 ]]; then
        log_success "CSV validation passed! File is ready for processing."
        return 0
    else
        log_error "CSV validation failed with $errors errors."
        return 1
    fi
}

# Clean up function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_csv "$CSV_FILE"
fi

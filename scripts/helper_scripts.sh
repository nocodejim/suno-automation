# ===== SESSION CAPTURE HELPER =====
# src/capture-session.js - Browser console script for capturing authentication

# Run this in Chrome DevTools Console while on suno.com/create
cat > src/capture-session.js << 'EOF'
// Session Capture Script for Suno Authentication
// Instructions:
// 1. Navigate to suno.com/create in Chrome
// 2. Open DevTools (F12) -> Console tab
// 3. Paste and run this entire script
// 4. Copy the output to session.json in your project root

(async function captureSession() {
    console.log('🔧 Capturing Suno session data...');
    
    // Method 1: Get cookies via document.cookie (works in all browsers)
    const cookieString = document.cookie;
    const cookies = cookieString.split(';').map(cookie => {
        const [name, value] = cookie.trim().split('=');
        return {
            name: name,
            value: value,
            domain: 'suno.com',
            path: '/',
            secure: true,
            httpOnly: false
        };
    }).filter(cookie => cookie.name); // Remove empty cookies
    
    // Method 2: Try to get more detailed cookie info (Chrome only)
    let detailedCookies = [];
    if (typeof chrome !== 'undefined' && chrome.cookies) {
        try {
            detailedCookies = await new Promise((resolve) => {
                chrome.cookies.getAll({domain: 'suno.com'}, resolve);
            });
        } catch (e) {
            console.log('⚠️ Detailed cookie access not available, using basic method');
        }
    }
    
    // Use detailed cookies if available, otherwise use basic method
    const finalCookies = detailedCookies.length > 0 ? detailedCookies : cookies;
    
    const sessionData = {
        captured_at: new Date().toISOString(),
        method: detailedCookies.length > 0 ? 'chrome_api' : 'document_cookie',
        cookies: finalCookies.map(cookie => ({
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain || 'suno.com',
            path: cookie.path || '/',
            secure: cookie.secure !== false,
            httpOnly: cookie.httpOnly || false
        }))
    };
    
    console.log('✅ Session captured successfully!');
    console.log(`📊 Found ${finalCookies.length} cookies`);
    console.log('📋 Copy the following JSON to session.json:');
    console.log('=====================================');
    console.log(JSON.stringify(sessionData, null, 2));
    console.log('=====================================');
    
    // Try to download as file (may not work in all browsers)
    try {
        const blob = new Blob([JSON.stringify(sessionData, null, 2)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'session.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('💾 Session file download initiated');
    } catch (e) {
        console.log('⚠️ Automatic download failed, please copy manually');
    }
    
    return sessionData;
})();
EOF

# ===== CSV VALIDATION SCRIPT =====
# scripts/validate-csv.sh - Validates CSV format before processing

cat > scripts/validate-csv.sh << 'EOF'
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
    
    # Validate each data row
    local row_num=1
    while IFS= read -r line; do
        ((row_num++))
        
        # Skip header
        if [[ $row_num -eq 2 ]]; then continue; fi
        
        # Check for basic CSV structure
        local field_count=$(echo "$line" | awk -F',' '{print NF}')
        if [[ $field_count -lt 3 ]]; then
            log_warning "Row $row_num has only $field_count fields (expected 3+)"
            ((warnings++))
        fi
        
        # Check for problematic characters
        if [[ "$line" == *"["* ]] && [[ "$line" != *"]"* ]]; then
            log_warning "Row $row_num has unmatched bracket '[' - may cause Suno issues"
            ((warnings++))
        fi
        
        if [[ "$line" == *"("* ]] && [[ "$line" != *")"* ]]; then
            log_warning "Row $row_num has unmatched parenthesis '(' - may cause Suno issues"
            ((warnings++))
        fi
        
        # Check field lengths (rough estimate)
        local line_length=${#line}
        if [[ $line_length -gt 6000 ]]; then
            log_warning "Row $row_num is very long ($line_length chars) - may exceed Suno limits"
            ((warnings++))
        fi
        
    done < "$file"
    
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
EOF

# ===== MONITORING DASHBOARD SCRIPT =====
# scripts/monitor.sh - Real-time monitoring dashboard

cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring Dashboard for Suno Automation
# Provides real-time status and progress information

set -e

# Configuration
REFRESH_INTERVAL=5
LOG_TAIL_LINES=10
CONTAINER_NAME="suno-automation"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

show_header() {
    clear
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}│                   SUNO AUTOMATION MONITOR                  │${NC}"
    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Last Updated: $(date)${NC}"
    echo ""
}

show_container_status() {
    echo -e "${BOLD}Container Status:${NC}"
    
    if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -q "$CONTAINER_NAME"; then
        echo -e "  ${GREEN}✅ Running${NC}"
        docker ps --filter "name=$CONTAINER_NAME" --format "  Image: {{.Image}}\n  Status: {{.Status}}\n  Ports: {{.Ports}}"
    else
        echo -e "  ${RED}❌ Not Running${NC}"
        echo "  Use './scripts/build-and-deploy.sh deploy' to start"
    fi
    echo ""
}

show_progress() {
    echo -e "${BOLD}Progress Information:${NC}"
    
    # Count input songs
    local input_count=0
    if [[ -f input/songs/*.csv ]]; then
        input_count=$(find input/songs/ -name "*.csv" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        ((input_count--)) # Subtract header row
    fi
    
    # Count completed songs
    local completed_count=0
    if [[ -d output/completed ]]; then
        completed_count=$(find output/completed/ -name "*.csv" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        if [[ $completed_count -gt 0 ]]; then
            ((completed_count--)) # Subtract header row
        fi
    fi
    
    echo "  Input Songs: $input_count"
    echo "  Completed: $completed_count"
    
    if [[ $input_count -gt 0 ]]; then
        local percentage=$((completed_count * 100 / input_count))
        echo "  Progress: $percentage%"
        
        # Simple progress bar
        local bar_length=30
        local filled=$((percentage * bar_length / 100))
        local empty=$((bar_length - filled))
        
        printf "  ["
        printf "%*s" $filled "" | tr ' ' '█'
        printf "%*s" $empty "" | tr ' ' '░'
        printf "] %d%%\n" $percentage
    fi
    echo ""
}

show_recent_logs() {
    echo -e "${BOLD}Recent Logs:${NC}"
    
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        docker logs --tail=$LOG_TAIL_LINES "$CONTAINER_NAME" 2>/dev/null | head -15 | while read -r line; do
            echo "  $line"
        done
    else
        echo "  No container running"
    fi
    echo ""
}

show_system_resources() {
    echo -e "${BOLD}System Resources:${NC}"
    
    # Memory usage
    local mem_info=$(free -h | grep '^Mem:')
    echo "  Memory: $mem_info"
    
    # Disk space
    local disk_info=$(df -h . | tail -1)
    echo "  Disk: $disk_info"
    
    # Docker resources (if container is running)
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        local docker_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" "$CONTAINER_NAME" 2>/dev/null | tail -1)
        echo "  Container: $docker_stats"
    fi
    echo ""
}

show_recent_results() {
    echo -e "${BOLD}Recent Results:${NC}"
    
    if [[ -d output/completed ]]; then
        local latest_file=$(find output/completed/ -name "*.csv" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [[ -n "$latest_file" ]]; then
            echo "  Latest result file: $(basename "$latest_file")"
            echo "  Modified: $(stat -c %y "$latest_file" 2>/dev/null | cut -d'.' -f1)"
            
            # Show summary of latest results
            if [[ -f "$latest_file" ]]; then
                local total=$(tail -n +2 "$latest_file" | wc -l)
                local successful=$(tail -n +2 "$latest_file" | grep -c "success" || echo "0")
                local failed=$(tail -n +2 "$latest_file" | grep -c "failed" || echo "0")
                
                echo "  Total: $total, Success: $successful, Failed: $failed"
            fi
        else
            echo "  No result files found"
        fi
    else
        echo "  Output directory not found"
    fi
    echo ""
}

show_help() {
    echo -e "${BOLD}Controls:${NC}"
    echo "  q - Quit monitor"
    echo "  r - Refresh now"
    echo "  l - Show full logs"
    echo "  s - Show container status"
    echo ""
}

# Main monitoring loop
main() {
    # Check if running in terminal
    if [[ ! -t 1 ]]; then
        echo "This script requires a terminal. Run directly in bash."
        exit 1
    fi
    
    # Set up signal handling
    trap 'echo ""; echo "Monitor stopped."; exit 0' INT TERM
    
    while true; do
        show_header
        show_container_status
        show_progress
        show_recent_logs
        show_system_resources
        show_recent_results
        show_help
        
        # Wait for input or timeout
        if read -t $REFRESH_INTERVAL -n 1 key; then
            case $key in
                q|Q) echo ""; echo "Monitor stopped."; exit 0 ;;
                r|R) continue ;;
                l|L) 
                    echo ""
                    echo "Full logs (press q to return):"
                    docker logs "$CONTAINER_NAME" 2>/dev/null | less
                    ;;
                s|S)
                    echo ""
                    echo "Container details:"
                    docker inspect "$CONTAINER_NAME" 2>/dev/null | less
                    ;;
            esac
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

# ===== BACKUP AND RESTORE SCRIPT =====
# scripts/backup.sh - Backup important data

cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup and Restore Script for Suno Automation
# Backs up configuration, session data, and results

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
    
    # Backup input data
    if [[ -d input/songs ]] && [[ -n "$(ls -A input/songs/ 2>/dev/null)" ]]; then
        log_info "Backing up input songs..."
        cp -r input/songs "$backup_path/"
    else
        log_warning "No input songs found to backup"
    fi
    
    # Backup results
    if [[ -d output/completed ]] && [[ -n "$(ls -A output/completed/ 2>/dev/null)" ]]; then
        log_info "Backing up results..."
        cp -r output/completed "$backup_path/results"
    else
        log_warning "No completed results found to backup"
    fi
    
    # Backup important logs
    if [[ -d logs ]]; then
        log_info "Backing up recent logs..."
        mkdir -p "$backup_path/logs"
        find logs -name "*.log" -mtime -7 -exec cp {} "$backup_path/logs/" \; 2>/dev/null || true
    fi
    
    # Create archive
    log_info "Creating compressed archive..."
    tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    rm -rf "$backup_path"
    
    log_success "Backup created: $backup_path.tar.gz"
    log_info "Backup size: $(du -h "$backup_path.tar.gz" | cut -f1)"
}

list_backups() {
    log_info "Available backups:"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -printf "%T@ %p\n" | sort -nr | while read timestamp file; do
            local date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
            local size=$(du -h "$file" | cut -f1)
            echo "  $(basename "$file") - $date_str ($size)"
        done
    else
        log_warning "No backup directory found"
    fi
}

restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_warning "Please specify backup file to restore"
        list_backups
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_warning "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Restoring from backup: $backup_file"
    
    # Create temporary extraction directory
    local temp_dir="/tmp/suno-restore-$$"
    mkdir -p "$temp_dir"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Find extracted directory
    local extracted_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        log_warning "No valid backup structure found"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Restore files
    log_info "Restoring configuration files..."
    cp "$extracted_dir"/*.json "$extracted_dir"/.env* . 2>/dev/null || true
    
    if [[ -d "$extracted_dir/songs" ]]; then
        log_info "Restoring input songs..."
        mkdir -p input/songs
        cp -r "$extracted_dir/songs"/* input/songs/
    fi
    
    if [[ -d "$extracted_dir/results" ]]; then
        log_info "Restoring results..."
        mkdir -p output/completed
        cp -r "$extracted_dir/results"/* output/completed/
    fi
    
    if [[ -d "$extracted_dir/logs" ]]; then
        log_info "Restoring logs..."
        mkdir -p logs/automation
        cp -r "$extracted_dir/logs"/* logs/automation/
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Restore completed successfully"
}

cleanup_old_backups() {
    local keep_days="${1:-30}"
    
    log_info "Cleaning up backups older than $keep_days days..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$keep_days -delete
        log_success "Cleanup completed"
    else
        log_warning "No backup directory found"
    fi
}

show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  create                 Create new backup"
    echo "  list                   List available backups"
    echo "  restore FILE          Restore from backup file"
    echo "  cleanup [DAYS]        Remove backups older than DAYS (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 list"
    echo "  $0 restore backups/suno-automation-backup-20250708_143022.tar.gz"
    echo "  $0 cleanup 7"
}

# Main execution
case "${1:-create}" in
    "create")
        create_backup
        ;;
    "list")
        list_backups
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "cleanup")
        cleanup_old_backups "$2"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
EOF

# ===== MAKE ALL SCRIPTS EXECUTABLE =====
echo "Making all scripts executable..."
chmod +x scripts/*.sh
chmod +x setup.sh

# ===== GITHUB WORKFLOW CONFIGURATION =====
# .github/workflows/ci.yml - Basic CI/CD pipeline

mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'EOF'
name: Suno Automation CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run security audit
      run: npm audit --audit-level high
    
    - name: Validate Docker configuration
      run: |
        docker build --target builder .
        docker-compose config
    
    - name: Run basic tests
      run: npm test || echo "No tests configured yet"

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Docker image
      run: |
        docker build -t suno-automation:${{ github.sha }} .
        docker tag suno-automation:${{ github.sha }} suno-automation:latest
    
    - name: Save Docker image
      run: |
        docker save suno-automation:latest | gzip > suno-automation-image.tar.gz
    
    - name: Upload image artifact
      uses: actions/upload-artifact@v3
      with:
        name: docker-image
        path: suno-automation-image.tar.gz
        retention-days: 7
EOF

# ===== DEPENDABOT CONFIGURATION =====
# .github/dependabot.yml - Automated dependency updates

cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  # Enable version updates for npm
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "sunday"
      time: "04:00"
    reviewers:
      - "your-github-username"
    assignees:
      - "your-github-username"
    commit-message:
      prefix: "deps"
      include: "scope"
    
  # Enable version updates for Docker
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "monthly"
    reviewers:
      - "your-github-username"
    commit-message:
      prefix: "docker"
      include: "scope"

  # Enable version updates for GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    reviewers:
      - "your-github-username"
    commit-message:
      prefix: "ci"
      include: "scope"
EOF

# ===== DOCKER IMPROVEMENTS =====
# .dockerignore - Optimize Docker build context

cat > .dockerignore << 'EOF'
# Version control
.git
.gitignore

# Documentation
README.md
docs/
*.md

# Development files
.env
.env.*
session.json

# Dependencies (will be installed in container)
node_modules
npm-debug.log*

# Build artifacts
dist/
build/

# Logs and temporary files
logs/
*.log
tmp/
temp/

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Output directories (mounted as volumes)
output/
backups/

# Test files
test/
*.test.js
jest.config.js

# CI/CD
.github/
EOF

echo ""
echo "✅ All helper scripts and configurations created!"
echo ""
echo "📋 Additional scripts available:"
echo "  scripts/validate-csv.sh     - Validate CSV format before processing"
echo "  scripts/monitor.sh          - Real-time monitoring dashboard"  
echo "  scripts/backup.sh           - Backup and restore data"
echo "  src/capture-session.js      - Browser console session capture"
echo ""
echo "🔧 GitHub integration configured:"
echo "  .github/workflows/ci.yml    - CI/CD pipeline"
echo "  .github/dependabot.yml      - Automated dependency updates"
echo ""
echo "🐳 Docker optimization:"
echo "  .dockerignore               - Optimized build context"
echo ""

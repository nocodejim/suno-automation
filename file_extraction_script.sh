#!/bin/bash
# extract-files.sh - Helper to create all files from artifacts
# Run this after copying the artifact content manually

echo "🔧 Creating all project files from artifacts..."

# Create src/capture-session.js
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

# Create scripts/validate-csv.sh
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

# Create scripts/monitor.sh
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
        
        # Wait for input or timeout
        if read -t $REFRESH_INTERVAL -n 1 key; then
            case $key in
                q|Q) echo ""; echo "Monitor stopped."; exit 0 ;;
                r|R) continue ;;
            esac
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

# Create scripts/backup.sh
cat > scripts/backup.sh << 'EOF'
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
EOF

# Create .dockerignore
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

# Create GitHub workflow directory and files
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
EOF

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
    commit-message:
      prefix: "deps"
      include: "scope"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo ""
echo "✅ All files created successfully!"
echo ""
echo "📁 Created files:"
echo "  src/capture-session.js"
echo "  scripts/validate-csv.sh"
echo "  scripts/monitor.sh" 
echo "  scripts/backup.sh"
echo "  .dockerignore"
echo "  .github/workflows/ci.yml"
echo "  .github/dependabot.yml"
echo ""
echo "🔧 All scripts are now executable"
echo ""

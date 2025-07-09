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

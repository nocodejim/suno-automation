#!/bin/bash
# scripts/build-and-deploy.sh - Comprehensive build and deployment script
# This script handles everything needed to get the automation up and running

set -e  # Exit on any error

# ===== SCRIPT CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="logs/docker/build-deploy.log"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Color codes for better output readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===== LOGGING FUNCTIONS =====
# These functions help us track what's happening during the build process

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

# ===== DEPENDENCY CHECKING FUNCTIONS =====
# Before we start, we need to make sure all required tools are installed

check_dependency() {
    local dep_name="$1"
    local install_command="$2"
    local check_command="$3"
    
    log_info "Checking for $dep_name..."
    
    if command -v "$check_command" &> /dev/null; then
        local version=$($check_command --version 2>/dev/null | head -n1 || echo "Version unknown")
        log_success "$dep_name is installed: $version"
        return 0
    else
        log_warning "$dep_name is not installed. Installing..."
        
        # Log the installation attempt
        echo "Installing $dep_name with command: $install_command" >> "$LOG_FILE"
        
        # Execute installation command
        if eval "$install_command" >> "$LOG_FILE" 2>&1; then
            log_success "$dep_name installed successfully"
            return 0
        else
            log_error "Failed to install $dep_name"
            return 1
        fi
    fi
}

install_docker() {
    log_info "Installing Docker..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group (requires logout/login to take effect)
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    log_warning "You may need to logout and login again for Docker permissions to take effect"
}

install_node() {
    log_info "Installing Node.js..."
    
    # Install Node.js via NodeSource repository (recommended for Ubuntu)
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    log_success "Node.js installed successfully"
}

# ===== MAIN DEPENDENCY CHECK =====
check_all_dependencies() {
    log_info "Starting dependency check..."
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            install_docker
        else
            log_error "Docker not found. Please install Docker manually from https://docker.com"
            exit 1
        fi
    else
        log_success "Docker is installed: $(docker --version)"
    fi
    
    # Check for Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        log_error "Docker Compose not found. Please ensure Docker with Compose plugin is installed"
        exit 1
    else
        log_success "Docker Compose is available: $(docker compose version)"
    fi
    
    # Check for Node.js (for local development)
    if ! command -v node &> /dev/null; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            install_node
        else
            log_warning "Node.js not found. Installing for local development..."
            log_error "Please install Node.js manually from https://nodejs.org"
        fi
    else
        log_success "Node.js is installed: $(node --version)"
    fi
    
    # Check for npm
    if ! command -v npm &> /dev/null; then
        log_error "npm not found. npm should come with Node.js installation"
        exit 1
    else
        log_success "npm is installed: $(npm --version)"
    fi
    
    log_success "All dependencies checked"
}

# ===== PROJECT VALIDATION =====
validate_project_structure() {
    log_info "Validating project structure..."
    
    # Check required files
    required_files=(
        "package.json"
        "Dockerfile"
        "src/index.js"
        ".env.example"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file missing: $file"
            log_error "Please run setup.sh first to initialize the project"
            exit 1
        fi
    done
    
    # Check required directories
    required_dirs=(
        "src"
        "input"
        "output"
        "logs"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_warning "Directory missing: $dir, creating..."
            mkdir -p "$dir"
        fi
    done
    
    log_success "Project structure validated"
}

# ===== ENVIRONMENT SETUP =====
setup_environment() {
    log_info "Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        log_info "Creating .env file from template..."
        cp .env.example .env
        log_warning "Please edit .env file with your specific configuration"
    fi
    
    # Check for session file
    if [[ ! -f "session.json" ]]; then
        log_warning "session.json not found"
        log_info "You'll need to capture your Suno authentication session"
        log_info "See docs/INSTRUCTIONS.md for details on session capture"
    fi
    
    # Check for input CSV
    if [[ ! -f "input/songs/songs.csv" ]] && [[ ! -f "input/songs"/*.csv ]]; then
        log_warning "No CSV files found in input/songs/"
        log_info "Please add your song CSV file to input/songs/ directory"
        log_info "See input/templates/songs-template.csv for format example"
    fi
    
    log_success "Environment setup complete"
}

# ===== BUILD FUNCTIONS =====
build_docker_image() {
    log_info "Building Docker image..."
    
    # Build the Docker image with build timestamp
    docker build \
        --tag "suno-automation:latest" \
        --tag "suno-automation:$TIMESTAMP" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
        . >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_success "Docker image built successfully"
        log_info "Image tags: suno-automation:latest, suno-automation:$TIMESTAMP"
    else
        log_error "Docker image build failed. Check $LOG_FILE for details"
        exit 1
    fi
}

install_local_dependencies() {
    log_info "Installing local Node.js dependencies..."
    
    # Install dependencies locally for development
    if npm install >> "$LOG_FILE" 2>&1; then
        log_success "Local dependencies installed"
    else
        log_error "Failed to install local dependencies"
        exit 1
    fi
}

# ===== DEPLOYMENT FUNCTIONS =====
deploy_with_docker_compose() {
    log_info "Deploying with Docker Compose..."
    
    # Stop any existing containers
    docker compose down >> "$LOG_FILE" 2>&1 || true
    
    # Start the services
    if docker compose up -d >> "$LOG_FILE" 2>&1; then
        log_success "Container deployed successfully"
        
        # Show container status
        log_info "Container status:"
        docker compose ps
        
        # Show logs
        log_info "Recent logs:"
        docker compose logs --tail=10
        
    else
        log_error "Deployment failed. Check $LOG_FILE for details"
        exit 1
    fi
}

run_directly_with_docker() {
    log_info "Running directly with Docker..."
    
    # Stop any existing container with the same name
    docker stop suno-automation 2>/dev/null || true
    docker rm suno-automation 2>/dev/null || true
    
    # Run the container
    docker run \
        --name suno-automation \
        --detach \
        --volume "$(pwd)/input:/app/input" \
        --volume "$(pwd)/output:/app/output" \
        --volume "$(pwd)/logs:/app/logs" \
        --volume "$(pwd)/session.json:/app/session.json" \
        --volume "$(pwd)/.env:/app/.env" \
        suno-automation:latest >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_success "Container started successfully"
        
        # Show container status
        log_info "Container status:"
        docker ps --filter "name=suno-automation"
        
        # Show initial logs
        log_info "Initial logs:"
        docker logs --tail=10 suno-automation
        
    else
        log_error "Failed to start container. Check $LOG_FILE for details"
        exit 1
    fi
}

# ===== MONITORING FUNCTIONS =====
show_logs() {
    local container_name="suno-automation"
    
    log_info "Showing live logs (Ctrl+C to exit)..."
    
    if docker ps --filter "name=$container_name" --format "table {{.Names}}" | grep -q "$container_name"; then
        docker logs -f "$container_name"
    else
        log_error "Container $container_name is not running"
        exit 1
    fi
}

show_status() {
    log_info "Container Status:"
    docker ps --filter "name=suno-automation" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    log_info "Recent logs:"
    docker logs --tail=20 suno-automation 2>/dev/null || log_warning "No logs available"
    
    log_info "Output files:"
    if [[ -d "output/completed" ]]; then
        ls -la output/completed/ 2>/dev/null || log_info "No output files yet"
    fi
}

# ===== CLEANUP FUNCTIONS =====
cleanup() {
    log_info "Cleaning up..."
    
    # Stop and remove containers
    docker compose down 2>/dev/null || true
    docker stop suno-automation 2>/dev/null || true
    docker rm suno-automation 2>/dev/null || true
    
    log_success "Cleanup complete"
}

# ===== MAIN EXECUTION =====
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  build       Build Docker image only"
    echo "  deploy      Deploy with docker-compose (recommended)"
    echo "  run         Run directly with docker run"
    echo "  logs        Show live container logs"
    echo "  status      Show container status and recent logs"
    echo "  cleanup     Stop and remove containers"
    echo "  full        Full build and deploy (default)"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Full build and deploy"
    echo "  $0 full         # Same as above"
    echo "  $0 build        # Just build the image"
    echo "  $0 deploy       # Deploy using docker-compose"
    echo "  $0 logs         # Watch container logs"
    echo ""
}

main() {
    cd "$PROJECT_ROOT"
    
    local action="${1:-full}"
    
    log_info "Starting Suno Automation build and deploy process..."
    log_info "Timestamp: $TIMESTAMP"
    log_info "Action: $action"
    
    case "$action" in
        "build")
            check_all_dependencies
            validate_project_structure
            build_docker_image
            ;;
        
        "deploy")
            setup_environment
            deploy_with_docker_compose
            ;;
        
        "run")
            setup_environment
            run_directly_with_docker
            ;;
        
        "logs")
            show_logs
            ;;
        
        "status")
            show_status
            ;;
        
        "cleanup")
            cleanup
            ;;
        
        "full")
            check_all_dependencies
            validate_project_structure
            setup_environment
            install_local_dependencies
            build_docker_image
            deploy_with_docker_compose
            
            log_success "🎉 Build and deployment completed successfully!"
            log_info ""
            log_info "Next steps:"
            log_info "1. Check container status: $0 status"
            log_info "2. Watch logs: $0 logs"
            log_info "3. Check output files in: output/completed/"
            log_info ""
            log_info "To stop the automation: $0 cleanup"
            ;;
        
        "help"|"-h"|"--help")
            show_usage
            ;;
        
        *)
            log_error "Unknown action: $action"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

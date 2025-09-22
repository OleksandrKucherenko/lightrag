#!/usr/bin/env bash
set -euo pipefail

# Smart hosts file updater with PUBLISH_DOMAIN support
# This script resolves environment variables and updates /etc/hosts using hostctl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

log_info() { printf "${COLOR_BLUE}🌐 %s${COLOR_RESET}\n" "$1"; }
log_success() { printf "${COLOR_GREEN}✅ %s${COLOR_RESET}\n" "$1"; }
log_warn() { printf "${COLOR_YELLOW}⚠️  %s${COLOR_RESET}\n" "$1"; }
log_error() { printf "${COLOR_RED}❌ %s${COLOR_RESET}\n" "$1"; }

main() {
    cd "$REPO_ROOT"
    
    # Load environment variables
    if [[ ! -f ".env" ]]; then
        log_error ".env file not found. Please ensure you're in the project root."
        exit 1
    fi
    
    source .env
    
    # Set default if PUBLISH_DOMAIN is not set
    DOMAIN=${PUBLISH_DOMAIN:-dev.localhost}
    
    log_info "Updating hosts file with domain: $DOMAIN"
    
    # Detect environment and set appropriate IP
    HOST_IP="127.0.0.1"
    if [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null; then
        # WSL2 environment - use Windows host IP
        if command -v docker >/dev/null 2>&1; then
            WSL_IP=$(docker run --rm alpine sh -c "ip route | awk '/default/ { print \$3 }'" 2>/dev/null || echo "127.0.0.1")
            if [[ "$WSL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                HOST_IP="$WSL_IP"
                log_info "WSL2 detected - using Windows host IP: $HOST_IP"
            fi
        fi
    else
        log_info "Local environment - using localhost: $HOST_IP"
    fi
    
    # Create preprocessed .etchosts file
    TEMP_ETCHOSTS=$(mktemp)
    trap "rm -f $TEMP_ETCHOSTS" EXIT
    
    # Check if .etchosts exists
    if [[ ! -f ".etchosts" ]]; then
        log_error ".etchosts file not found. Please ensure you're in the project root."
        exit 1
    fi
    
    # Preprocess .etchosts by resolving environment variables
    log_info "Preprocessing .etchosts template..."
    envsubst < .etchosts > "$TEMP_ETCHOSTS"
    
    # Replace 127.0.0.1 with detected IP if needed (for WSL2)
    if [[ "$HOST_IP" != "127.0.0.1" ]]; then
        log_info "Adjusting IP addresses for WSL2..."
        sed -i "s/127\.0\.0\.1/$HOST_IP/g" "$TEMP_ETCHOSTS"
    fi
    
    echo
    log_info "Preprocessed hosts file:"
    cat "$TEMP_ETCHOSTS"
    echo
    
    # Check if hostctl is available
    if ! command -v hostctl >/dev/null 2>&1; then
        log_error "hostctl not found. Please install it first:"
        echo "  # Linux/macOS: brew install guumaster/tap/hostctl"
        echo "  # Windows: scoop install main/hostctl"
        echo "  # Or use mise: mise install hostctl"
        exit 1
    fi
    
    # Use hostctl to update hosts file with preprocessed content
    log_info "Updating /etc/hosts using hostctl..."
    
    if sudo hostctl replace lightrag --from "$TEMP_ETCHOSTS"; then
        echo
        log_success "Hosts file updated successfully!"
        log_success "All services now accessible at *.$DOMAIN"
        log_info "Main URL: https://$DOMAIN"
        
        echo
        log_info "Current hostctl profile status:"
        hostctl list lightrag 2>/dev/null || log_warn "Could not display profile status"
        
    else
        log_error "Failed to update hosts file. Please check permissions."
        exit 1
    fi
}

# Show usage if --help is passed
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Smart hosts file updater with PUBLISH_DOMAIN support"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "This script:"
    echo "  - Reads PUBLISH_DOMAIN from .env file"
    echo "  - Detects WSL2 environment and uses appropriate IP"
    echo "  - Generates resolved hosts entries"
    echo "  - Updates /etc/hosts using hostctl"
    echo ""
    echo "Environment variables:"
    echo "  PUBLISH_DOMAIN  Domain to use (default: dev.localhost)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use PUBLISH_DOMAIN from .env"
    echo "  PUBLISH_DOMAIN=myapp.local $0        # Override domain"
    echo ""
    exit 0
fi

main "$@"

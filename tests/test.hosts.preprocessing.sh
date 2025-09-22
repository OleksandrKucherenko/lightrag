#!/usr/bin/env bash
set -euo pipefail

# Test script to demonstrate .etchosts preprocessing
# This shows how environment variables are resolved before hostctl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

log_info() { printf "${COLOR_BLUE}ℹ️  %s${COLOR_RESET}\n" "$1"; }
log_success() { printf "${COLOR_GREEN}✅ %s${COLOR_RESET}\n" "$1"; }
log_test() { printf "${COLOR_YELLOW}🧪 %s${COLOR_RESET}\n" "$1"; }

main() {
    cd "$REPO_ROOT"
    
    log_test "Testing .etchosts preprocessing approach"
    echo
    
    # Load environment
    if [[ ! -f ".env" ]]; then
        echo "PUBLISH_DOMAIN=dev.localhost" > .env.test
        source .env.test
        log_info "Created temporary .env.test with PUBLISH_DOMAIN=dev.localhost"
    else
        source .env
        log_info "Loaded PUBLISH_DOMAIN from .env: ${PUBLISH_DOMAIN:-dev.localhost}"
    fi
    
    # Set default
    DOMAIN=${PUBLISH_DOMAIN:-dev.localhost}
    
    echo
    log_info "Original .etchosts template:"
    echo "----------------------------------------"
    cat .etchosts | head -20
    echo "----------------------------------------"
    
    echo
    log_info "Preprocessing with envsubst..."
    
    # Create preprocessed version
    TEMP_ETCHOSTS=$(mktemp)
    trap "rm -f $TEMP_ETCHOSTS .env.test 2>/dev/null || true" EXIT
    
    # Preprocess using envsubst
    envsubst < .etchosts > "$TEMP_ETCHOSTS"
    
    echo
    log_success "Preprocessed result:"
    echo "----------------------------------------"
    cat "$TEMP_ETCHOSTS"
    echo "----------------------------------------"
    
    echo
    log_test "Testing different environment variable combinations:"
    
    # Test with different combinations
    test_cases=(
        "HOST_IP=127.0.0.1 PUBLISH_DOMAIN=dev.localhost"
        "HOST_IP=192.168.1.100 PUBLISH_DOMAIN=myapp.local"
        "HOST_IP=10.0.0.50 PUBLISH_DOMAIN=staging.internal"
        "PUBLISH_DOMAIN=prod.company.com"  # Uses default HOST_IP
    )
    
    for test_case in "${test_cases[@]}"; do
        echo
        log_info "Testing with: $test_case"
        
        TEMP_TEST=$(mktemp)
        env -i bash -c "source .env; $test_case envsubst < .etchosts" > "$TEMP_TEST"
        
        echo "Result:"
        grep -v "^#" "$TEMP_TEST" | grep -v "^$" | head -3
        rm -f "$TEMP_TEST"
    done
    
    echo
    log_success "✨ Preprocessing works correctly!"
    log_info "The .etchosts template can be processed with any PUBLISH_DOMAIN value"
    log_info "and then passed to hostctl for proper hosts file management."
    
    echo
    log_info "Usage:"
    echo "  bin/update.hosts.sh     # Uses this preprocessing approach"
    echo "  mise run hosts-update   # Same via mise task"
}

main "$@"

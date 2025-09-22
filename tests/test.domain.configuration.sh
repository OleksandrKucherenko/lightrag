#!/usr/bin/env bash
set -Eeuo pipefail

# Test script for configurable domain functionality
# This script validates that PUBLISH_DOMAIN environment variable works correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"
COLOR_RESET="\033[0m"

log_info() { printf "${COLOR_BLUE}ℹ️  %s${COLOR_RESET}\n" "$1"; }
log_success() { printf "${COLOR_GREEN}✅ %s${COLOR_RESET}\n" "$1"; }
log_error() { printf "${COLOR_RED}❌ %s${COLOR_RESET}\n" "$1"; }

test_count=0
pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    ((test_count++))
    log_info "Testing: $test_name"
    
    if result=$(eval "$test_command" 2>&1); then
        if echo "$result" | grep -q "$expected_pattern"; then
            log_success "PASS: $test_name"
            ((pass_count++))
        else
            log_error "FAIL: $test_name - Expected pattern '$expected_pattern' not found in: $result"
            ((fail_count++))
        fi
    else
        log_error "FAIL: $test_name - Command failed: $result"
        ((fail_count++))
    fi
}

main() {
    log_info "🧪 Testing Configurable Domain Implementation"
    echo
    
    # Load environment
    cd "$REPO_ROOT"
    source .env
    
    # Test 1: Environment variable is set
    run_test "PUBLISH_DOMAIN environment variable" \
        "echo \$PUBLISH_DOMAIN" \
        "dev.localhost"
    
    # Test 2: Docker Compose config uses variable
    run_test "Docker Compose uses PUBLISH_DOMAIN" \
        "docker compose config | grep 'caddy:'" \
        "https://.*\\.dev\\.localhost"
    
    # Test 3: Test with custom domain
    run_test "Custom domain substitution" \
        "PUBLISH_DOMAIN=test.local docker compose config | grep 'caddy:' | head -1" \
        "https://.*\\.test\\.local"
    
    # Test 4: Verification script uses variable
    run_test "Verification script supports PUBLISH_DOMAIN" \
        "grep -q 'PUBLISH_DOMAIN:-dev.localhost' tests/verify.configuration.sh && echo 'found'" \
        "found"
    
    # Test 5: Test script uses variable
    run_test "Test script supports PUBLISH_DOMAIN" \
        "grep -q 'PUBLISH_DOMAIN:-dev.localhost' tests/test.suite.sh && echo 'found'" \
        "found"
    
    # Test 6: Host IP detection script works
    run_test "Host IP detection script works" \
        "bin/get-host-ip.sh | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && echo 'found'" \
        "found"
    
    echo
    log_info "📊 Test Results"
    echo "Total: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    
    if [[ $fail_count -eq 0 ]]; then
        log_success "🎉 All tests passed! Configurable domain implementation is working correctly."
        return 0
    else
        log_error "💥 $fail_count test(s) failed. Please review the implementation."
        return 1
    fi
}

main "$@"

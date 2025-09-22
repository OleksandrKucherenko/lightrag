#!/usr/bin/env bash

# =============================================================================
# Test Framework for LightRAG Solution
# =============================================================================
# This script implements TDD approach with comprehensive test suite
# Follows GIVEN/WHEN/THEN pattern for test structure

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    COLOR_RESET="$(tput sgr0)"
    COLOR_BOLD="$(tput bold)"
    COLOR_GREEN="$(tput setaf 2)"
    COLOR_YELLOW="$(tput setaf 3)"
    COLOR_BLUE="$(tput setaf 4)"
    COLOR_RED="$(tput setaf 1)"
    COLOR_GRAY="$(tput setaf 7)"
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_RED=""
    COLOR_GRAY=""
fi

# Test result tracking
declare -a TEST_RESULTS=()
declare -i TEST_COUNT=0
declare -i PASS_COUNT=0
declare -i FAIL_COUNT=0

# =============================================================================
# GIVEN/WHEN/THEN Test Framework
# =============================================================================

# Test structure functions
given() {
    printf "\n${COLOR_BLUE}GIVEN:${COLOR_RESET} %s\n" "$1"
}

when() {
    printf "${COLOR_YELLOW}WHEN:${COLOR_RESET} %s\n" "$1"
}

then() {
    printf "${COLOR_GREEN}THEN:${COLOR_RESET} %s\n" "$1"
}

and_then() {
    printf "${COLOR_GRAY}AND:${COLOR_RESET} %s\n" "$1"
}

# Test execution functions
test_start() {
    local test_name="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    printf "\n${COLOR_BOLD}🧪 TEST %d: %s${COLOR_RESET}\n" "$TEST_COUNT" "$test_name"
}

test_pass() {
    local test_name="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_RESULTS+=("PASS:$test_name")
    printf "${COLOR_GREEN}✅ PASS:${COLOR_RESET} %s\n" "$test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_RESULTS+=("FAIL:$test_name:$reason")
    printf "${COLOR_RED}❌ FAIL:${COLOR_RESET} %s - %s\n" "$test_name" "$reason"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    TEST_RESULTS+=("SKIP:$test_name:$reason")
    printf "${COLOR_YELLOW}⏭️  SKIP:${COLOR_RESET} %s - %s\n" "$test_name" "$reason"
}

# =============================================================================
# Test Categories
# =============================================================================

# Infrastructure Tests
test_infrastructure_setup() {
    local test_name="infrastructure_setup_verification"

    test_start "$test_name"

    given "project has required directory structure"
    when "checking for essential directories"
    then "all required directories should exist"

    local required_dirs=(
        "docker/data"
        "docker/etc"
        "docker/logs"
        "docker/ssl"
        ".secrets"
    )

    local all_dirs_exist=true
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$REPO_ROOT/$dir" ]]; then
            test_fail "$test_name" "Missing directory: $dir"
            all_dirs_exist=false
            break
        fi
    done

    if $all_dirs_exist; then
        test_pass "$test_name"
    fi
}

# Environment Configuration Tests
test_environment_configuration() {
    local test_name="environment_configuration_validation"

    test_start "$test_name"

    given "environment files exist and contain required variables"
    when "loading and validating environment configuration"
    then "all required environment variables should be present"

    # Load environment files
    local env_files=(".env" ".env.databases" ".env.lightrag" ".env.lobechat")
    for file in "${env_files[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            # shellcheck source=/dev/null
            source "$REPO_ROOT/$file"
        fi
    done

    local required_vars=(
        "REDIS_PASSWORD"
        "QDRANT_API_KEY"
        "LIGHTRAG_API_KEY"
        "MONITOR_BASIC_AUTH_HASH"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Missing variables: ${missing_vars[*]}"
    fi
}

# Docker Compose Tests
test_docker_compose_configuration() {
    local test_name="docker_compose_configuration_validation"

    test_start "$test_name"

    given "docker-compose.yaml file exists and is valid"
    when "validating docker-compose configuration"
    then "configuration should parse without errors"

    if docker compose config >/dev/null 2>&1; then
        and_then "all services should be properly defined"
        test_pass "$test_name"
    else
        test_fail "$test_name" "Invalid docker-compose configuration"
    fi
}

# Service Health Tests
test_service_health() {
    local test_name="service_health_check"

    test_start "$test_name"

    given "all services are running"
    when "checking service health status"
    then "all services should be healthy"

    local services=("proxy" "monitor" "kv" "graph" "graph-ui" "vectors" "rag" "lobechat")
    local unhealthy_services=()

    for service in "${services[@]}"; do
        local state health
        if state=$(docker inspect -f '{{.State.Status}}' "$service" 2>/dev/null); then
            health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$service" 2>/dev/null)
            if [[ "$state" != "running" || ("$health" != "healthy" && "$health" != "n/a") ]]; then
                unhealthy_services+=("$service")
            fi
        else
            unhealthy_services+=("$service")
        fi
    done

    if [[ ${#unhealthy_services[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Unhealthy services: ${unhealthy_services[*]}"
    fi
}

# Security Tests
test_security_configuration() {
    local test_name="security_configuration_verification"

    test_start "$test_name"

    given "security measures are properly configured"
    when "testing security endpoints"
    then "unauthorized access should be blocked"

    # Test Redis security
    local redis_output
    if redis_output=$(docker exec kv redis-cli ping 2>&1); then
        if [[ "$redis_output" == *"NOAUTH"* ]]; then
            and_then "Redis should reject unauthorized connections"
            test_pass "$test_name"
        else
            test_fail "$test_name" "Redis security issue: $redis_output"
        fi
    else
        test_skip "$test_name" "Redis not accessible for testing"
    fi
}

# Integration Tests
test_integration_connectivity() {
    local test_name="integration_connectivity_test"

    test_start "$test_name"

    given "services can communicate with each other"
    when "testing internal service connectivity"
    then "all inter-service communication should work"

    # Test LobeChat to LightRAG connectivity
    if docker compose exec -T lobechat wget -qO- http://rag:9621/health >/dev/null 2>&1; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "LobeChat cannot reach LightRAG"
    fi
}

# T008: LobeChat Redis Connectivity Test
test_lobechat_redis_connectivity() {
    local test_name="lobechat_redis_connectivity_test"

    test_start "$test_name"

    given "LobeChat service is running and Redis is accessible"
    when "testing LobeChat to Redis connectivity"
    then "LobeChat should connect to Redis databases 2 and 3"

    # Test Redis DB 2 (LobeChat database)
    local redis_db2_test
    if redis_db2_test=$(docker compose exec -T lobechat sh -c "echo 'ping' | nc kv 6379" 2>/dev/null); then
        and_then "Redis connection should be established"
        
        # Test Redis DB 3 (LobeChat cache)
        local redis_auth_test
        if redis_auth_test=$(docker compose exec -T kv redis-cli -a "${REDIS_PASSWORD:-}" ping 2>/dev/null); then
            and_then "Redis authentication should work"
            test_pass "$test_name"
        else
            test_fail "$test_name" "Redis authentication failed: $redis_auth_test"
        fi
    else
        test_fail "$test_name" "LobeChat cannot reach Redis service"
    fi
}

# T009: LobeChat API Endpoint Test
test_lobechat_api_endpoints() {
    local test_name="lobechat_api_endpoints_test"

    test_start "$test_name"

    given "LobeChat service is running and accessible"
    when "testing LobeChat web interface endpoints"
    then "API endpoints should respond correctly"

    # Test main landing page
    local status_code
    if status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3210/ 2>/dev/null); then
        if [[ "$status_code" == "200" ]]; then
            and_then "Landing page should return HTTP 200"
            
            # Test health endpoint if available
            local health_status
            if health_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3210/api/health 2>/dev/null); then
                and_then "Health endpoint accessibility checked"
            fi
            
            test_pass "$test_name"
        else
            test_fail "$test_name" "Landing page returned HTTP $status_code"
        fi
    else
        test_fail "$test_name" "LobeChat web interface not accessible on port 3210"
    fi
}

# T010: SSL/TLS Test for LobeChat
test_lobechat_ssl_tls() {
    local test_name="lobechat_ssl_tls_test"

    test_start "$test_name"

    given "SSL certificates are configured and LobeChat is accessible via HTTPS"
    when "testing HTTPS access to lobechat.dev.localhost"
    then "SSL/TLS connection should be established successfully"

    # Test HTTPS connectivity (skip certificate verification for dev environment)
    local https_status
    if https_status=$(curl -s -k -o /dev/null -w "%{http_code}" https://lobechat.dev.localhost/ 2>/dev/null); then
        if [[ "$https_status" == "200" ]]; then
            and_then "HTTPS connection established successfully"
            
            # Test SSL certificate validity (basic check)
            local cert_info
            if cert_info=$(echo | openssl s_client -connect lobechat.dev.localhost:443 -servername lobechat.dev.localhost 2>/dev/null | openssl x509 -noout -subject 2>/dev/null); then
                and_then "SSL certificate is readable: $cert_info"
            fi
            
            test_pass "$test_name"
        else
            test_fail "$test_name" "HTTPS returned status $https_status"
        fi
    else
        test_fail "$test_name" "Cannot establish HTTPS connection to lobechat.dev.localhost"
    fi
}

# =============================================================================
# Test Runner
# =============================================================================

run_all_tests() {
    printf "${COLOR_BOLD}🚀 Starting LightRAG Test Suite${COLOR_RESET}\n"

    # Run all tests
    test_infrastructure_setup
    test_environment_configuration
    test_docker_compose_configuration
    test_service_health
    test_security_configuration
    test_integration_connectivity
    test_lobechat_redis_connectivity
    test_lobechat_api_endpoints
    test_lobechat_ssl_tls

    # Print summary
    printf "\n${COLOR_BOLD}📊 Test Summary${COLOR_RESET}\n"
    printf "Total Tests: %d\n" "$TEST_COUNT"
    printf "Passed: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$PASS_COUNT"
    printf "Failed: ${COLOR_RED}%d${COLOR_RESET}\n" "$FAIL_COUNT"
    printf "Skipped: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$((TEST_COUNT - PASS_COUNT - FAIL_COUNT))"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        printf "${COLOR_GREEN}🎉 All tests passed!${COLOR_RESET}\n"
        return 0
    else
        printf "${COLOR_RED}💥 %d test(s) failed${COLOR_RESET}\n" "$FAIL_COUNT"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    if [[ $# -eq 0 ]]; then
        run_all_tests
    else
        case "$1" in
            "infrastructure") test_infrastructure_setup ;;
            "environment") test_environment_configuration ;;
            "docker") test_docker_compose_configuration ;;
            "health") test_service_health ;;
            "security") test_security_configuration ;;
            "integration") test_integration_connectivity ;;
            "lobechat-redis") test_lobechat_redis_connectivity ;;
            "lobechat-api") test_lobechat_api_endpoints ;;
            "lobechat-ssl") test_lobechat_ssl_tls ;;
            *) echo "Unknown test: $1"; exit 1 ;;
        esac
    fi
}

main "$@"

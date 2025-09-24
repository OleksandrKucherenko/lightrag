#!/bin/bash
# =============================================================================
# SSL VERIFICATION SCRIPT FOR LIGHTRAG STACK
# =============================================================================
# This script verifies that all services are properly configured with SSL/TLS
# certificates from the docker/ssl folder and are accessible via HTTPS.

set -e

# Configuration
PUBLISH_DOMAIN="dev.localhost"
SERVICES=(
    "proxy"
    "monitor"
    "kv"
    "graph"
    "vector"
    "rag"
    "lobechat"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check SSL certificate
check_ssl_cert() {
    local subdomain=$1
    local url="https://${subdomain}.${PUBLISH_DOMAIN}"

    print_status $YELLOW "Checking SSL certificate for ${url}..."

    # Check if we can connect via HTTPS
    if curl -k -s -o /dev/null -w "%{http_code}" "${url}" > /dev/null 2>&1; then
        print_status $GREEN "✓ HTTPS connection successful for ${url}"

        # Get certificate info
        local cert_info=$(echo | openssl s_client -servername "${subdomain}.${PUBLISH_DOMAIN}" -connect "${subdomain}.${PUBLISH_DOMAIN}:443" 2>/dev/null | openssl x509 -text -noout | grep -E "(Subject:|Issuer:)" | head -2)

        if [[ -n "$cert_info" ]]; then
            print_status $GREEN "✓ Certificate info:"
            echo "$cert_info" | sed 's/^/  /'
        fi
    else
        print_status $RED "✗ HTTPS connection failed for ${url}"
        return 1
    fi
}

# Function to check if Docker containers are running
check_docker_containers() {
    print_status $YELLOW "Checking Docker container status..."

    for service in "${SERVICES[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^${service}$"; then
            print_status $GREEN "✓ Container ${service} is running"
        else
            print_status $RED "✗ Container ${service} is not running"
            return 1
        fi
    done
}

# Function to check Caddy configuration
check_caddy_config() {
    print_status $YELLOW "Checking Caddy configuration..."

    # Check if Caddyfile exists and contains SSL configuration
    if [[ -f "docker/etc/caddy/Caddyfile" ]]; then
        if grep -q "tls.*ssl.*pem" docker/etc/caddy/Caddyfile; then
            print_status $GREEN "✓ Caddyfile contains SSL certificate configuration"
        else
            print_status $RED "✗ Caddyfile missing SSL certificate configuration"
            return 1
        fi
    else
        print_status $RED "✗ Caddyfile not found"
        return 1
    fi

    # Check if SSL certificates exist
    if [[ -f "docker/ssl/dev.localhost.pem" && -f "docker/ssl/dev.localhost-key.pem" ]]; then
        print_status $GREEN "✓ SSL certificates found in docker/ssl/"
    else
        print_status $RED "✗ SSL certificates missing from docker/ssl/"
        return 1
    fi
}

# Main verification function
main() {
    print_status $YELLOW "Starting SSL verification for LightRAG stack..."
    print_status $YELLOW "Domain: ${PUBLISH_DOMAIN}"
    print_status $YELLOW "SSL Certificate: docker/ssl/dev.localhost.pem"

    echo

    # Pre-flight checks
    check_caddy_config
    check_docker_containers

    echo

    # Test SSL for each service
    local failed_tests=0

    for service in "${SERVICES[@]}"; do
        if ! check_ssl_cert "$service"; then
            failed_tests=$((failed_tests + 1))
        fi
        echo
    done

    # Summary
    if [[ $failed_tests -eq 0 ]]; then
        print_status $GREEN "🎉 All SSL verification tests passed!"
        print_status $GREEN "All services are accessible via HTTPS with wildcard certificates."
    else
        print_status $RED "❌ ${failed_tests} SSL verification tests failed."
        print_status $RED "Please check the configuration and container logs."
        exit 1
    fi
}

# Run main function
main "$@"

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain-Based Setup Configuration Check
# =============================================================================
#
# GIVEN: The system should use domain-based configuration to eliminate CORS issues
# WHEN: We inspect the environment files and docker-compose configuration
# THEN: We verify all services are configured with proper subdomain routing
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment variables
if [[ -f "${REPO_ROOT}/.env" ]]; then
    set +e  # Temporarily disable exit on error for sourcing
    source "${REPO_ROOT}/.env" 2>/dev/null || true
    set -e  # Re-enable exit on error
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check LobeChat domain configuration
if [[ -f "${REPO_ROOT}/.env.lobechat" ]]; then
    if grep -q "OPENAI_PROXY_URL=https://api.\${PUBLISH_DOMAIN}$" "${REPO_ROOT}/.env.lobechat"; then
        echo "PASS|lobechat_domain_config|LobeChat using correct Ollama-compatible base URL|grep OPENAI_PROXY_URL .env.lobechat"
    else
        echo "FAIL|lobechat_domain_config|LobeChat not using correct Ollama base URL (should be base domain without path)|grep OPENAI_PROXY_URL .env.lobechat"
    fi
else
    echo "BROKEN|lobechat_domain_config|LobeChat environment file not found|ls .env.lobechat"
fi

# Check Docker Compose subdomain routing for LobeChat
if [[ -f "${REPO_ROOT}/docker-compose.yaml" ]]; then
    if grep -q 'caddy: "https://chat.${PUBLISH_DOMAIN}"' "${REPO_ROOT}/docker-compose.yaml"; then
        echo "PASS|chat_subdomain_routing|LobeChat configured for chat subdomain|grep caddy.*chat docker-compose.yaml"
    else
        echo "FAIL|chat_subdomain_routing|LobeChat subdomain not configured|grep caddy.*chat docker-compose.yaml"
    fi
else
    echo "BROKEN|chat_subdomain_routing|docker-compose.yaml not found|ls docker-compose.yaml"
fi

# Check Docker Compose subdomain routing for LightRAG API
if [[ -f "${REPO_ROOT}/docker-compose.yaml" ]]; then
    if grep -q 'caddy_1: "https://api.${PUBLISH_DOMAIN}"' "${REPO_ROOT}/docker-compose.yaml"; then
        echo "PASS|api_subdomain_routing|LightRAG API configured for api subdomain|grep caddy_1.*api docker-compose.yaml"
    else
        echo "FAIL|api_subdomain_routing|LightRAG API subdomain not configured|grep caddy_1.*api docker-compose.yaml"
    fi
else
    echo "BROKEN|api_subdomain_routing|docker-compose.yaml not found|ls docker-compose.yaml"
fi

# Check SSL certificate for wildcard subdomains
if [[ -f "${REPO_ROOT}/docker/certificates/dev.localhost.pem" ]]; then
    if command -v openssl >/dev/null 2>&1; then
        CERT_DOMAINS=$(openssl x509 -in "${REPO_ROOT}/docker/certificates/dev.localhost.pem" -text -noout | grep -A1 "Subject Alternative Name" | tail -1 2>/dev/null || echo "")
        if [[ "$CERT_DOMAINS" == *"*.$PUBLISH_DOMAIN"* ]]; then
            echo "PASS|wildcard_ssl_cert|SSL certificate covers wildcard subdomains|openssl x509 -in docker/certificates/dev.localhost.pem -text -noout"
        else
            echo "FAIL|wildcard_ssl_cert|SSL certificate may not cover all subdomains|openssl x509 -in docker/certificates/dev.localhost.pem -text -noout"
        fi
    else
        echo "INFO|wildcard_ssl_cert|OpenSSL not available to verify certificate|which openssl"
    fi
else
    echo "FAIL|wildcard_ssl_cert|SSL certificate not found|ls docker/certificates/dev.localhost.pem"
fi

# Check LobeChat server mode configuration
if [[ -f "${REPO_ROOT}/.env.lobechat" ]]; then
    if grep -q "^# NEXT_PUBLIC_SERVICE_MODE=server" "${REPO_ROOT}/.env.lobechat"; then
        echo "PASS|lobechat_server_mode|Server mode disabled (not needed with domain approach)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
    else
        echo "INFO|lobechat_server_mode|Server mode configuration unclear|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
    fi
else
    echo "BROKEN|lobechat_server_mode|LobeChat environment file not found|ls .env.lobechat"
fi

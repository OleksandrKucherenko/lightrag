#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# External Endpoints Check
# =============================================================================
# 
# GIVEN: Services that should be accessible externally via HTTPS
# WHEN: We test external endpoint accessibility
# THEN: We report on external API and web interface availability
# =============================================================================

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Define endpoints to test
declare -a ENDPOINTS=(
    "https://$PUBLISH_DOMAIN/health|Main Site Health"
    "https://rag.$PUBLISH_DOMAIN/health|LightRAG API Health"
    "https://lobechat.$PUBLISH_DOMAIN/|LobeChat Interface"
    "https://monitor.$PUBLISH_DOMAIN/|Monitoring Dashboard"
    "https://vector.$PUBLISH_DOMAIN/collections|Qdrant API"
)

# Function to test HTTP endpoint
test_endpoint() {
    local url="$1"
    local timeout=5
    
    # Use curl with proper SSL handling for dev domains
    local curl_opts="-skL --connect-timeout $timeout --max-time 10"
    
    # Add domain resolution for dev.localhost
    if [[ "$url" == *"dev.localhost"* ]]; then
        curl_opts="$curl_opts --resolve dev.localhost:443:127.0.0.1 --resolve dev.localhost:80:127.0.0.1"
    fi
    
    # Get HTTP status code
    local status
    if status=$(curl $curl_opts -w '%{http_code}' -o /dev/null "$url" 2>/dev/null); then
        echo "$status"
    else
        echo "0"
    fi
}

# Test each endpoint
for endpoint in "${ENDPOINTS[@]}"; do
    # Split on pipe separator
    url="${endpoint%%|*}"
    description="${endpoint#*|}"
    
    # WHEN: We test external accessibility
    status=$(test_endpoint "$url")
    
    # THEN: Evaluate response status
    case "$status" in
        200)
            echo "PASS|external_endpoints|$description - accessible (HTTP $status)|curl -I $url"
            ;;
        401|403)
            echo "PASS|external_endpoints|$description - accessible with auth required (HTTP $status)|curl -I $url"
            ;;
        404)
            echo "FAIL|external_endpoints|$description - not found (HTTP $status)|curl -I $url"
            ;;
        0)
            echo "FAIL|external_endpoints|$description - connection failed|curl -I $url"
            ;;
        *)
            echo "FAIL|external_endpoints|$description - unexpected status (HTTP $status)|curl -I $url"
            ;;
    esac
done

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Headers Validation Check
# =============================================================================
#
# GIVEN: LightRAG API should respond with proper CORS headers without duplicates
# WHEN: We send an OPTIONS preflight request to the API endpoint
# THEN: We verify correct CORS headers are present and no duplicates exist
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

# Check if services are running
if ! docker compose ps rag >/dev/null 2>&1 || ! docker compose ps rag | grep -q "Up"; then
    echo "INFO|cors_headers_test|LightRAG service not running - skipping CORS test|docker compose ps rag"
    exit 0
fi

# Test CORS preflight request
RESPONSE=$(curl -s -k -i \
    -H "Origin: https://chat.$PUBLISH_DOMAIN" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type,authorization" \
    -X OPTIONS \
    "https://api.$PUBLISH_DOMAIN/api/chat" 2>&1 || echo "CURL_ERROR")

if [[ "$RESPONSE" == "CURL_ERROR" ]] || [[ -z "$RESPONSE" ]]; then
    echo "FAIL|cors_preflight_request|Failed to connect to API endpoint|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
    exit 0
fi

# Check for duplicate Access-Control-Allow-Origin headers
DUPLICATE_ORIGIN=$(echo "$RESPONSE" | grep -i "access-control-allow-origin" | wc -l | tr -d '\n\r')
if [[ $DUPLICATE_ORIGIN -gt 1 ]]; then
    echo "FAIL|cors_duplicate_headers|Duplicate Access-Control-Allow-Origin headers detected|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
elif [[ $DUPLICATE_ORIGIN -eq 1 ]]; then
    echo "PASS|cors_duplicate_headers|No duplicate Access-Control-Allow-Origin headers|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
else
    echo "FAIL|cors_duplicate_headers|No Access-Control-Allow-Origin header found|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
fi

# Check if the correct origin is allowed
if echo "$RESPONSE" | grep -q "Access-Control-Allow-Origin.*https://chat.$PUBLISH_DOMAIN"; then
    echo "PASS|cors_origin_allowed|Correct origin allowed in CORS headers|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
elif echo "$RESPONSE" | grep -q "Access-Control-Allow-Origin.*\*"; then
    echo "INFO|cors_origin_allowed|Wildcard origin allowed in CORS headers|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
else
    ORIGIN_HEADER=$(echo "$RESPONSE" | grep -i "access-control-allow-origin" | head -1 | tr -d '\n\r' || echo "not found")
    echo "FAIL|cors_origin_allowed|Origin header incorrect: $ORIGIN_HEADER|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
fi

# Check for Access-Control-Allow-Methods header
if echo "$RESPONSE" | grep -qi "access-control-allow-methods"; then
    METHODS=$(echo "$RESPONSE" | grep -i "access-control-allow-methods" | head -1 | cut -d':' -f2- | tr -d '\n\r' | sed 's/^ *//')
    if [[ "$METHODS" == *"POST"* ]]; then
        echo "PASS|cors_methods_allowed|POST method allowed in CORS headers|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
    else
        echo "FAIL|cors_methods_allowed|POST method not allowed: $METHODS|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
    fi
else
    echo "FAIL|cors_methods_allowed|Access-Control-Allow-Methods header missing|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
fi

# Check for Access-Control-Allow-Headers
if echo "$RESPONSE" | grep -qi "access-control-allow-headers"; then
    HEADERS=$(echo "$RESPONSE" | grep -i "access-control-allow-headers" | head -1 | cut -d':' -f2- | tr -d '\n\r' | sed 's/^ *//')
    if [[ "$HEADERS" == *"content-type"* ]]; then
        echo "PASS|cors_headers_allowed|Content-Type header allowed in CORS|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
    else
        echo "FAIL|cors_headers_allowed|Content-Type header not allowed: $HEADERS|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
    fi
else
    echo "FAIL|cors_headers_allowed|Access-Control-Allow-Headers missing|curl -X OPTIONS https://api.$PUBLISH_DOMAIN/api/chat"
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Qdrant API Security Check
# =============================================================================
# 
# GIVEN: A Qdrant instance that may have API key protection
# WHEN: We test API access with and without authentication
# THEN: We determine if API security is ENABLED, DISABLED, or BROKEN
# =============================================================================

# Load environment
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check if Qdrant container is running
if ! docker compose ps -q vectors >/dev/null 2>&1; then
    echo "BROKEN|qdrant_api|Qdrant container not found|docker compose ps vectors"
    exit 0
fi

# Test internal API first (container-to-container)
base_url="http://localhost:6333"

if [[ -z "$QDRANT_API_KEY" ]]; then
    # WHEN: No API key is configured
    # THEN: Qdrant should be accessible without authentication (DISABLED state)
    
    if result=$(docker compose exec -T vectors curl -s --connect-timeout 5 "$base_url/collections" 2>&1); then
        if echo "$result" | jq . >/dev/null 2>&1; then
            echo "DISABLED|qdrant_api|No API key configured - open access|curl -s $base_url/collections"
        else
            echo "BROKEN|qdrant_api|No API key set but invalid response: ${result:0:50}|curl -s $base_url/collections"
        fi
    else
        echo "BROKEN|qdrant_api|Cannot connect to Qdrant|curl -s $base_url/collections"
    fi
else
    # WHEN: API key is configured
    # THEN: Test both unauthenticated (should fail) and authenticated (should work)
    
    # Test without API key
    unauth_result=$(docker compose exec -T vectors curl -s -w "%{http_code}" -o /dev/null --connect-timeout 5 "$base_url/collections" 2>/dev/null || echo "0")
    
    # Test with API key
    auth_result=$(docker compose exec -T vectors curl -s -w "%{http_code}" -o /dev/null --connect-timeout 5 -H "api-key: $QDRANT_API_KEY" "$base_url/collections" 2>/dev/null || echo "0")
    
    if [[ "$unauth_result" =~ ^(401|403)$ ]] && [[ "$auth_result" == "200" ]]; then
        echo "ENABLED|qdrant_api|API key protection working|curl -s -H 'api-key: \$QDRANT_API_KEY' $base_url/collections"
    elif [[ "$unauth_result" == "200" ]]; then
        echo "BROKEN|qdrant_api|API key set but no protection active|curl -s $base_url/collections"
    else
        echo "BROKEN|qdrant_api|API key auth failed (unauth: $unauth_result, auth: $auth_result)|curl -s -H 'api-key: \$QDRANT_API_KEY' $base_url/collections"
    fi
fi

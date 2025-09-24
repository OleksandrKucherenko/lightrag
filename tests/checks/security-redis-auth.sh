#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Redis Authentication Check
# =============================================================================
# 
# GIVEN: A Redis instance that may have authentication configured
# WHEN: We test Redis authentication status
# THEN: We determine if authentication is ENABLED, DISABLED, or BROKEN
# =============================================================================

# Load environment if available
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Check if Redis container is running
if ! docker compose ps -q kv >/dev/null 2>&1; then
    echo "BROKEN|redis_auth|Redis container not found|docker compose ps kv"
    exit 0
fi

if [[ -z "$REDIS_PASSWORD" ]]; then
    # WHEN: No password is configured
    # THEN: Redis should be accessible without authentication (DISABLED state)
    
    if result=$(docker compose exec -T kv redis-cli ping 2>&1); then
        if [[ "$result" == "PONG" ]]; then
            echo "DISABLED|redis_auth|No password configured - open access|docker compose exec kv redis-cli ping"
        else
            echo "BROKEN|redis_auth|No password set but ping failed: $result|docker compose exec kv redis-cli ping"
        fi
    else
        echo "BROKEN|redis_auth|Cannot connect to Redis container|docker compose exec kv redis-cli ping"
    fi
else
    # WHEN: Password is configured
    # THEN: Test both unauthenticated (should fail) and authenticated (should work)
    
    unauth_result=$(docker compose exec -T kv redis-cli ping 2>&1 || echo "AUTH_REQUIRED")
    auth_result=$(docker compose exec -T -e REDISCLI_AUTH="${REDIS_PASSWORD}" kv redis-cli ping 2>&1 || echo "AUTH_FAILED")
    
    if [[ "$unauth_result" == *"NOAUTH"* || "$unauth_result" == *"Authentication required"* ]]; then
        if [[ "$auth_result" == "PONG" ]]; then
            echo "ENABLED|redis_auth|Password protection working|docker compose exec -e REDISCLI_AUTH='\$REDIS_PASSWORD' kv redis-cli ping"
        else
            echo "BROKEN|redis_auth|Password set but auth failed|docker compose exec -e REDISCLI_AUTH='\$REDIS_PASSWORD' kv redis-cli ping"
        fi
    elif [[ "$auth_result" == "PONG" ]]; then
        echo "BROKEN|redis_auth|Password set but no auth required|docker compose exec kv redis-cli ping"
    else
        echo "BROKEN|redis_auth|Authentication configuration unclear|docker compose exec kv redis-cli ping"
    fi
fi

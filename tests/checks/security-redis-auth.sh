#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Redis Authentication Check
# =============================================================================
# GIVEN: A Redis instance that may have authentication configured
# WHEN: We test Redis authentication status
# THEN: We determine if authentication is ENABLED, DISABLED, or BROKEN
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="redis_auth"
readonly ENABLED_MSG="ENABLED|${TEST_ID}|Password protection working|docker compose exec -e REDISCLI_AUTH='\$REDIS_PASSWORD' kv redis-cli ping"
readonly DISABLED_MSG="DISABLED|${TEST_ID}|No password configured - open access|docker compose exec kv redis-cli ping"
readonly BROKEN_MISSING="BROKEN|${TEST_ID}|Redis container not found|docker compose ps kv"
readonly BROKEN_NOAUTH="BROKEN|${TEST_ID}|Password set but no auth required|docker compose exec kv redis-cli ping"
readonly BROKEN_AUTHFAIL="BROKEN|${TEST_ID}|Password set but auth failed|docker compose exec -e REDISCLI_AUTH='\$REDIS_PASSWORD' kv redis-cli ping"
readonly BROKEN_UNAUTHFAIL="BROKEN|${TEST_ID}|No password set but ping failed|docker compose exec kv redis-cli ping"
readonly BROKEN_UNCLEAR="BROKEN|${TEST_ID}|Authentication configuration unclear|docker compose exec kv redis-cli ping"

# GIVEN: Load environment and check prerequisites
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# WHEN: Check if Redis container is running
CONTAINER_RUNNING=$(probe_docker_service_running "kv" && echo "true" || echo "false")

# THEN: Determine authentication status based on password config and container state
if [[ "$CONTAINER_RUNNING" == "false" ]]; then
    echo "$BROKEN_MISSING"
    exit 0
fi

if [[ -z "$REDIS_PASSWORD" ]]; then
    # No password configured - test unauthenticated access
    PING_RESULT=$(clean_output "$(probe_redis_ping)")
    [[ "$PING_RESULT" == *"PONG"* ]] && echo "$DISABLED_MSG" || echo "$BROKEN_UNAUTHFAIL"
else
    # Password configured - test both authenticated and unauthenticated access
    UNAUTH_RESULT=$(clean_output "$(unset REDIS_PASSWORD; probe_redis_ping)")
    AUTH_RESULT=$(clean_output "$(REDIS_PASSWORD="$REDIS_PASSWORD" probe_redis_ping)")



    if [[ "$UNAUTH_RESULT" == *"NOAUTH"* ]] && [[ "$AUTH_RESULT" == *"PONG"* ]]; then
        echo "$ENABLED_MSG"
    elif [[ "$AUTH_RESULT" == *"PONG"* ]]; then
        echo "$BROKEN_NOAUTH"
    elif [[ "$UNAUTH_RESULT" == *"PONG"* ]]; then
        echo "$BROKEN_AUTHFAIL"
    else
        echo "$BROKEN_UNCLEAR"
    fi
fi
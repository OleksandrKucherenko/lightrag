#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Qdrant API Security Check
# =============================================================================
# GIVEN: A Qdrant instance that may have API key protection
# WHEN: We test API access with and without authentication
# THEN: We determine if API security is ENABLED, DISABLED, or BROKEN
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="qdrant_api"
readonly ENABLED_MSG="ENABLED|${TEST_ID}|API key protection working|docker run --rm --network container:vectors alpine/curl:latest -s -o /dev/null -w '%{http_code}' --connect-timeout 5 -H 'api-key: \$QDRANT_API_KEY' http://localhost:6333/collections"
readonly DISABLED_MSG="DISABLED|${TEST_ID}|No API key configured - open access|docker run --rm --network container:vectors alpine/curl:latest -s --connect-timeout 5 http://localhost:6333/collections"
readonly BROKEN_CONTAINER="BROKEN|${TEST_ID}|Qdrant container not found|docker compose ps vectors"
readonly BROKEN_NOAUTH="BROKEN|${TEST_ID}|API key set but no protection active|docker run --rm --network container:vectors alpine/curl:latest -s --connect-timeout 5 http://localhost:6333/collections"
readonly BROKEN_INVALID="BROKEN|${TEST_ID}|No API key set but invalid response|docker run --rm --network container:vectors alpine/curl:latest -s --connect-timeout 5 http://localhost:6333/collections"
readonly BROKEN_CONNECT="BROKEN|${TEST_ID}|Cannot connect to Qdrant|docker run --rm --network container:vectors alpine/curl:latest -s --connect-timeout 5 http://localhost:6333/collections"
readonly BROKEN_AUTHFAIL="BROKEN|${TEST_ID}|API key auth failed|docker run --rm --network container:vectors alpine/curl:latest -s -o /dev/null -w '%{http_code}' --connect-timeout 5 -H 'api-key: \$QDRANT_API_KEY' http://localhost:6333/collections"

# GIVEN: Load environment and check prerequisites
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"

# WHEN: Check if Qdrant container is running
CONTAINER_RUNNING=$(probe_docker_service_running "vectors" && echo "true" || echo "false")

# THEN: Exit early if container not running
[[ "$CONTAINER_RUNNING" == "false" ]] && { echo "$BROKEN_CONTAINER"; exit 0; }

# WHEN: Test API access based on key configuration
if [[ -z "$QDRANT_API_KEY" ]]; then
    # No API key configured - test unauthenticated access
    COLLECTIONS_RESULT=$(clean_output "$(probe_qdrant_collections)")
    COLLECTIONS_SUCCESS=$([[ "$COLLECTIONS_RESULT" != "COLLECTIONS_FAILED" ]] && echo "true" || echo "false")

    if [[ "$COLLECTIONS_SUCCESS" == "true" ]]; then
        echo "$DISABLED_MSG"
    else
        echo "$BROKEN_CONNECT"
    fi
else
    # API key configured - test both authenticated and unauthenticated access
    UNAUTH_RESULT=$(clean_output "$(probe_qdrant_collections vectors "")")
    AUTH_RESULT=$(clean_output "$(probe_qdrant_collections vectors "$QDRANT_API_KEY")")

    UNAUTH_SUCCESS=$([[ "$UNAUTH_RESULT" != "COLLECTIONS_FAILED" ]] && echo "true" || echo "false")
    AUTH_SUCCESS=$([[ "$AUTH_RESULT" != "COLLECTIONS_FAILED" ]] && echo "true" || echo "false")

    if [[ "$UNAUTH_SUCCESS" == "false" ]] && [[ "$AUTH_SUCCESS" == "true" ]]; then
        echo "$ENABLED_MSG"
    elif [[ "$UNAUTH_SUCCESS" == "true" ]]; then
        echo "$BROKEN_NOAUTH"
    else
        echo "$BROKEN_AUTHFAIL"
    fi
fi
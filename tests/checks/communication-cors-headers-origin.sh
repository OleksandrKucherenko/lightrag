#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Origin Allowed Check
# =============================================================================
# GIVEN: LightRAG API should allow the correct origin in CORS headers
# WHEN: We send an OPTIONS preflight request to the API endpoint
# THEN: We verify the correct origin is allowed in CORS headers
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_origin_allowed"
readonly PASS_CORRECT="PASS|${TEST_ID}|Correct origin allowed in CORS headers|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly INFO_WILDCARD="INFO|${TEST_ID}|Wildcard origin allowed in CORS headers|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly FAIL_INCORRECT="FAIL|${TEST_ID}|Origin header incorrect|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly INFO_NOTRUNNING="INFO|${TEST_ID}|LightRAG service not running - skipping test|docker compose ps rag"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Check if LightRAG service is running
SERVICE_RUNNING=$(probe_docker_service_running "rag" && echo "true" || echo "false")

# THEN: Exit if service not running
[[ "$SERVICE_RUNNING" == "false" ]] && { echo "$INFO_NOTRUNNING"; exit 0; }

# WHEN: Send CORS preflight request
RESPONSE=$(clean_output "$(curl -s -k -i \
    -H "Origin: https://chat.$PUBLISH_DOMAIN" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type,authorization" \
    -X OPTIONS \
    "https://api.$PUBLISH_DOMAIN/api/chat" 2>&1 || echo "CURL_ERROR")")

# THEN: Exit if curl failed
[[ "$RESPONSE" == "CURL_ERROR" ]] && { echo "FAIL|${TEST_ID}|Failed to connect to API endpoint|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"; exit 0; }

# WHEN: Check if the correct origin is allowed
CORRECT_ORIGIN=$(echo "$RESPONSE" | grep -qi "access-control-allow-origin.*https://chat.$PUBLISH_DOMAIN" && echo "true" || echo "false")
WILDCARD_ORIGIN=$(echo "$RESPONSE" | grep -qi "access-control-allow-origin.*\*" && echo "true" || echo "false")

# THEN: Report result
if [[ "$CORRECT_ORIGIN" == "true" ]]; then
    echo "$PASS_CORRECT"
elif [[ "$WILDCARD_ORIGIN" == "true" ]]; then
    echo "$INFO_WILDCARD"
else
    echo "$FAIL_INCORRECT"
fi
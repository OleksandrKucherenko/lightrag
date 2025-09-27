#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Duplicate Headers Check
# =============================================================================
# GIVEN: LightRAG API should respond with proper CORS headers without duplicates
# WHEN: We send an OPTIONS preflight request to the API endpoint
# THEN: We verify no duplicate Access-Control-Allow-Origin headers exist
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_duplicate_headers"
readonly PASS_MSG="PASS|${TEST_ID}|No duplicate Access-Control-Allow-Origin headers|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly FAIL_DUPLICATE="FAIL|${TEST_ID}|Duplicate Access-Control-Allow-Origin headers detected|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly FAIL_MISSING="FAIL|${TEST_ID}|No Access-Control-Allow-Origin header found|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
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

# WHEN: Check for duplicate Access-Control-Allow-Origin headers
DUPLICATE_ORIGIN=$(echo "$RESPONSE" | grep -i "access-control-allow-origin" | wc -l | tr -d '\n\r')

# THEN: Report result
if [[ "$DUPLICATE_ORIGIN" -gt 1 ]]; then
    echo "$FAIL_DUPLICATE"
elif [[ "$DUPLICATE_ORIGIN" -eq 1 ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_MISSING"
fi
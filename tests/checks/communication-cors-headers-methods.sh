#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Methods Allowed Check
# =============================================================================
# GIVEN: LightRAG API should allow POST method in CORS headers
# WHEN: We send an OPTIONS preflight request to the API endpoint
# THEN: We verify POST method is allowed in CORS headers
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_methods_allowed"
readonly PASS_MSG="PASS|${TEST_ID}|POST method allowed in CORS headers|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly FAIL_MISSING="FAIL|${TEST_ID}|Access-Control-Allow-Methods header missing|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
readonly FAIL_NOTALLOWED="FAIL|${TEST_ID}|POST method not allowed|curl -X OPTIONS https://api.\${PUBLISH_DOMAIN}/api/chat"
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

# WHEN: Check for Access-Control-Allow-Methods header
HAS_METHODS_HEADER=$(echo "$RESPONSE" | grep -qi "access-control-allow-methods" && echo "true" || echo "false")

# THEN: Exit if header missing
[[ "$HAS_METHODS_HEADER" == "false" ]] && { echo "$FAIL_MISSING"; exit 0; }

# WHEN: Check if POST method is allowed
METHODS=$(echo "$RESPONSE" | grep -i "access-control-allow-methods" | head -1 | cut -d':' -f2- | tr -d '\n\r' | sed 's/^ *//')
POST_ALLOWED=$(echo "$METHODS" | grep -q "POST" && echo "true" || echo "false")

# THEN: Report result
if [[ "$POST_ALLOWED" == "true" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_NOTALLOWED"
fi
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Service Check
# =============================================================================
# GIVEN: The docker-compose stack must define a proxy service managed by Caddy
# WHEN: We inspect the proxy service entry and its label section in docker-compose.yaml
# THEN: We confirm the service exists and includes Caddy labels for routing
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_service"
readonly PASS_MSG="PASS|${TEST_ID}|Proxy service defined with Caddy labels|yq eval '.services.proxy' docker-compose.yaml"
readonly FAIL_MISSING="FAIL|${TEST_ID}|Proxy service not defined|yq eval '.services.proxy' docker-compose.yaml"
readonly FAIL_NOLABELS="FAIL|${TEST_ID}|Proxy service defined without Caddy labels|yq eval '.services.proxy.labels' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Check prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
YQ_AVAILABLE=$(command -v yq >/dev/null 2>&1 && echo "true" || echo "false")

# WHEN: Check if docker-compose.yaml exists
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "$BROKEN_COMPOSE"; exit 0; }

# WHEN: Check if yq is available
# THEN: Exit if yq not available
[[ "$YQ_AVAILABLE" == "false" ]] && { echo "$BROKEN_YQ"; exit 0; }

# WHEN: Check if proxy service exists
PROXY_SERVICE=$(yq eval '.services.proxy' "$COMPOSE_FILE" 2>/dev/null || echo "null")
SERVICE_EXISTS=$([[ -n "$PROXY_SERVICE" && "$PROXY_SERVICE" != "null" ]] && echo "true" || echo "false")

# THEN: Exit if proxy service missing
[[ "$SERVICE_EXISTS" == "false" ]] && { echo "$FAIL_MISSING"; exit 0; }

# WHEN: Check if proxy service has labels
LABELS_EXIST=$(yq eval '.services.proxy.labels' "$COMPOSE_FILE" >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Report result
if [[ "$LABELS_EXIST" == "true" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_NOLABELS"
fi
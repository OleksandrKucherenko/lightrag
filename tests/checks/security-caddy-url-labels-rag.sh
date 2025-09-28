#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy URL Labels Check - RAG Service
# =============================================================================
# GIVEN: Caddy labels should publish the correct HTTPS endpoint for RAG service
# WHEN: We read the caddy URL label from docker-compose.yaml
# THEN: We confirm the label matches the expected domain pattern
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_url_labels_rag"
readonly PASS_MSG="PASS|${TEST_ID}|RAG service Caddy URL label correct|yq eval '.services.rag.labels.caddy' docker-compose.yaml"
readonly FAIL_MISSING="FAIL|${TEST_ID}|RAG service missing Caddy URL label|yq eval '.services.rag.labels.caddy' docker-compose.yaml"
readonly FAIL_INCORRECT="FAIL|${TEST_ID}|RAG service Caddy URL label incorrect|yq eval '.services.rag.labels.caddy' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Check prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
YQ_AVAILABLE=$(command -v yq >/dev/null 2>&1 && echo "true" || echo "false")
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Check if docker-compose.yaml exists
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "$BROKEN_COMPOSE"; exit 0; }

# WHEN: Check if yq is available
# THEN: Exit if yq not available
[[ "$YQ_AVAILABLE" == "false" ]] && { echo "$BROKEN_YQ"; exit 0; }

# WHEN: Get Caddy URL label for RAG service
CADDY_URL=$(yq eval '.services.rag.labels.caddy' "$COMPOSE_FILE" 2>/dev/null || echo "null")
LABEL_EXISTS=$([[ -n "$CADDY_URL" && "$CADDY_URL" != "null" ]] && echo "true" || echo "false")

# THEN: Exit if label missing
[[ "$LABEL_EXISTS" == "false" ]] && { echo "$FAIL_MISSING"; exit 0; }

# WHEN: Check if URL matches expected pattern
EXPECTED_URL="https://rag.\${PUBLISH_DOMAIN}"
URL_CORRECT=$([[ "$CADDY_URL" == "$EXPECTED_URL" ]] && echo "true" || echo "false")

# THEN: Report result
if [[ "$URL_CORRECT" == "true" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_INCORRECT"
fi
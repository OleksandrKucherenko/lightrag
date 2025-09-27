#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Env File Check
# =============================================================================
# GIVEN: The Caddy proxy relies on environment files for configuration
# WHEN: We inspect the proxy service env_file entries in docker-compose.yaml
# THEN: We ensure .env.caddy is included or report when configuration is missing
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_envfile"
readonly PASS_ENVFILE_CONFIGURED="PASS|${TEST_ID}|Caddy proxy env_file includes .env.caddy|yq eval '.services.proxy.env_file[]' docker-compose.yaml"
readonly INFO_NO_ENVFILES="INFO|${TEST_ID}|Caddy proxy service has no env_file entries defined|yq eval '.services.proxy.env_file' docker-compose.yaml"
readonly FAIL_MISSING_CADDY_ENV="FAIL|${TEST_ID}|Caddy proxy env_file does not include .env.caddy|yq eval '.services.proxy.env_file[]' docker-compose.yaml"
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

# WHEN: Get proxy service env_file entries
ENV_FILES=$(yq eval '.services.proxy.env_file[]' "$COMPOSE_FILE" 2>/dev/null || echo "")
ENV_FILES_COUNT=$(echo "$ENV_FILES" | grep -c "." 2>/dev/null || echo "0")

# THEN: Exit if no env_file entries
[[ "$ENV_FILES_COUNT" -eq 0 ]] && { echo "$INFO_NO_ENVFILES"; exit 0; }

# WHEN: Check for .env.caddy in env_file entries
CADDY_ENV_CONFIGURED=$(echo "$ENV_FILES" | grep -q "\.env\.caddy" && echo "true" || echo "false")

# THEN: Report result
if [[ "$CADDY_ENV_CONFIGURED" == "true" ]]; then
    echo "$PASS_ENVFILE_CONFIGURED"
else
    echo "$FAIL_MISSING_CADDY_ENV"
fi
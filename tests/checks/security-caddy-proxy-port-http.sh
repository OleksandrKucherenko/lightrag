#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy HTTP Port Check
# =============================================================================
# GIVEN: Optional HTTP port 80 assists with redirects to HTTPS
# WHEN: We inspect the proxy service port mappings in docker-compose.yaml
# THEN: We report whether port 80 is exposed for redirect handling
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_port_http"
readonly PASS_MSG="PASS|${TEST_ID}|Caddy proxy exposes HTTP port|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly FAIL_NO_PORTS="FAIL|${TEST_ID}|Caddy proxy service defines no ports|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly INFO_NO_HTTP="INFO|${TEST_ID}|Caddy proxy does not expose HTTP port 80 for redirects|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "$BROKEN_COMPOSE"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "$BROKEN_YQ"; exit 1; }

# WHEN: Extract port information
PORTS=$(yq eval '.services.proxy.ports[]' "$COMPOSE_FILE" 2>/dev/null || echo "null")
HAS_HTTP=$(echo "$PORTS" | grep -q "80" && echo "true" || echo "false")

# THEN: Qualify result
[[ "$PORTS" == "null" ]] && echo "$FAIL_NO_PORTS" || \
[[ "$HAS_HTTP" == "true" ]] && echo "$PASS_MSG" || echo "$INFO_NO_HTTP"

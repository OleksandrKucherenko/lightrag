#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy HTTPS Port Check
# =============================================================================
# GIVEN: External HTTPS traffic must reach the Caddy proxy on port 443
# WHEN: We evaluate the proxy service port mappings in docker-compose.yaml
# THEN: We verify that port 443 is exposed for secure traffic
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_port_https"
readonly PASS_MSG="PASS|${TEST_ID}|Caddy proxy exposes HTTPS port|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly FAIL_NO_PORTS="FAIL|${TEST_ID}|Caddy proxy service defines no ports|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly FAIL_NO_HTTPS="FAIL|${TEST_ID}|Caddy proxy must expose HTTPS port 443|yq eval '.services.proxy.ports[]' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "$BROKEN_COMPOSE"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "$BROKEN_YQ"; exit 1; }

# WHEN: Extract port information
PORTS=$(yq eval '.services.proxy.ports[]' "$COMPOSE_FILE" 2>/dev/null || echo "null")
HAS_HTTPS=$(echo "$PORTS" | grep -q "443" && echo "true" || echo "false")

# THEN: Qualify result
[[ "$PORTS" == "null" ]] && echo "$FAIL_NO_PORTS" || \
[[ "$HAS_HTTPS" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_NO_HTTPS"

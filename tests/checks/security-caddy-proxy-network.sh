#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Network Check
# =============================================================================
# GIVEN: The proxy must join the frontend network alongside routed services
# WHEN: We inspect proxy network assignments and the frontend definition
# THEN: We confirm the frontend network exists and the proxy is attached
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_network"
readonly PASS_MSG="PASS|${TEST_ID}|Caddy proxy attached to frontend network defined in docker-compose.yaml|yq eval '.services.proxy.networks' docker-compose.yaml"
readonly FAIL_NO_NETWORKS="FAIL|${TEST_ID}|Caddy proxy service missing network configuration|yq eval '.services.proxy.networks' docker-compose.yaml"
readonly FAIL_NO_FRONTEND="FAIL|${TEST_ID}|Caddy proxy service must attach to frontend network|yq eval '.services.proxy.networks[]' docker-compose.yaml"
readonly FAIL_NO_DEF="FAIL|${TEST_ID}|frontend network definition missing in docker-compose.yaml|yq eval '.networks.frontend' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "$BROKEN_COMPOSE"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "$BROKEN_YQ"; exit 1; }

# WHEN: Extract network information
PROXY_NETWORKS=$(yq eval '.services.proxy.networks' "$COMPOSE_FILE" 2>/dev/null || echo "null")
FRONTEND_NETWORK=$(yq eval '.networks.frontend' "$COMPOSE_FILE" 2>/dev/null || echo "null")
HAS_FRONTEND=$(yq eval '.services.proxy.networks[] | select(. == "frontend")' "$COMPOSE_FILE" 2>/dev/null || echo "null")

# THEN: Qualify result
[[ "$PROXY_NETWORKS" == "null" ]] && echo "$FAIL_NO_NETWORKS" || \
[[ "$FRONTEND_NETWORK" == "null" ]] && echo "$FAIL_NO_DEF" || \
[[ "$HAS_FRONTEND" == "null" ]] && echo "$FAIL_NO_FRONTEND" || echo "$PASS_MSG"

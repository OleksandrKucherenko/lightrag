#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Network Check
# =============================================================================
#
# GIVEN: The proxy must join the frontend network alongside routed services
# WHEN: We inspect proxy network assignments and the frontend definition
# THEN: We confirm the frontend network exists and the proxy is attached
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_network|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_network|yq is required to inspect network configuration|which yq"
    exit 1
fi

proxy_networks=$(yq eval '.services.proxy.networks' "$COMPOSE_FILE" 2>/dev/null || true)
network_command="yq eval '.services.proxy.networks' docker-compose.yaml"

if [[ -z "$proxy_networks" || "$proxy_networks" == "null" ]]; then
    echo "FAIL|caddy_proxy_network|Caddy proxy service missing network configuration|$network_command"
    exit 0
fi

if ! yq eval '.services.proxy.networks[] | select(. == "frontend")' "$COMPOSE_FILE" >/dev/null 2>&1; then
    echo "FAIL|caddy_proxy_network|Caddy proxy service must attach to frontend network|yq eval '.services.proxy.networks[]' docker-compose.yaml"
    exit 0
fi

frontend_network=$(yq eval '.networks.frontend' "$COMPOSE_FILE" 2>/dev/null || true)
if [[ -z "$frontend_network" || "$frontend_network" == "null" ]]; then
    echo "FAIL|caddy_proxy_network|frontend network definition missing in docker-compose.yaml|yq eval '.networks.frontend' docker-compose.yaml"
    exit 0
fi

echo "PASS|caddy_proxy_network|Caddy proxy attached to frontend network defined in docker-compose.yaml|yq eval '.services.proxy.networks' docker-compose.yaml"

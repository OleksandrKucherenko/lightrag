#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Service Check
# =============================================================================
#
# GIVEN: The docker-compose stack must define a proxy service managed by Caddy
# WHEN: We inspect the proxy service entry and its label section in docker-compose.yaml
# THEN: We confirm the service exists and includes Caddy labels for routing
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_service|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_service|yq is required to inspect Caddy proxy service|which yq"
    exit 1
fi

command="yq eval '.services.proxy' docker-compose.yaml"
service=$(yq eval '.services.proxy' "$COMPOSE_FILE" 2>/dev/null || true)

if [[ -z "$service" || "$service" == "null" ]]; then
    echo "FAIL|caddy_proxy_service|Proxy service not defined in docker-compose.yaml|$command"
    exit 0
fi

if ! yq eval '.services.proxy.labels' "$COMPOSE_FILE" >/dev/null 2>&1; then
    echo "FAIL|caddy_proxy_service|Proxy service defined without Caddy labels|yq eval '.services.proxy.labels' docker-compose.yaml"
    exit 0
fi

echo "PASS|caddy_proxy_service|Proxy service defined with Caddy labels in docker-compose.yaml|$command"

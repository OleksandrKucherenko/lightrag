#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy HTTP Port Check
# =============================================================================
#
# GIVEN: Optional HTTP port 80 assists with redirects to HTTPS
# WHEN: We inspect the proxy service port mappings in docker-compose.yaml
# THEN: We report whether port 80 is exposed for redirect handling
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_port_http|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_port_http|yq is required to inspect port configuration|which yq"
    exit 1
fi

command="yq eval '.services.proxy.ports[]' docker-compose.yaml"
mapfile -t ports < <(yq eval '.services.proxy.ports[]' "$COMPOSE_FILE" 2>/dev/null || true)

if ((${#ports[@]} == 0)); then
    echo "FAIL|caddy_proxy_port_http|Caddy proxy service defines no ports|$command"
    exit 0
fi

for port in "${ports[@]}"; do
    if [[ "$port" == *"80"* ]]; then
        echo "PASS|caddy_proxy_port_http|Caddy proxy exposes HTTP port (value: $port)|$command"
        exit 0
    fi

done

echo "INFO|caddy_proxy_port_http|Caddy proxy does not expose HTTP port 80 for redirects|$command"

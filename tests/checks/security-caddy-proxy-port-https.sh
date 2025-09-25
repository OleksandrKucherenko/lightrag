#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy HTTPS Port Check
# =============================================================================
#
# GIVEN: External HTTPS traffic must reach the Caddy proxy on port 443
# WHEN: We evaluate the proxy service port mappings in docker-compose.yaml
# THEN: We verify that port 443 is exposed for secure traffic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_port_https|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_port_https|yq is required to inspect port configuration|which yq"
    exit 1
fi

command="yq eval '.services.proxy.ports[]' docker-compose.yaml"
mapfile -t ports < <(yq eval '.services.proxy.ports[]' "$COMPOSE_FILE" 2>/dev/null || true)

if ((${#ports[@]} == 0)); then
    echo "FAIL|caddy_proxy_port_https|Caddy proxy service defines no ports|$command"
    exit 0
fi

for port in "${ports[@]}"; do
    if [[ "$port" == *"443"* ]]; then
        echo "PASS|caddy_proxy_port_https|Caddy proxy exposes HTTPS port (value: $port)|$command"
        exit 0
    fi

done

echo "FAIL|caddy_proxy_port_https|Caddy proxy must expose HTTPS port 443|$command"

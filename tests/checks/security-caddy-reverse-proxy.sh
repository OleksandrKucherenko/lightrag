#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Reverse Proxy Labels Check
# =============================================================================
#
# GIVEN: Services routed through Caddy should define reverse proxy labels
# WHEN: We inspect each service's caddy.reverse_proxy label in docker-compose.yaml
# THEN: We ensure the label exists and highlight when it deviates from the upstreams pattern
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_reverse_proxy|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_reverse_proxy|yq is required to inspect Caddy reverse proxy labels|which yq"
    exit 1
fi

declare -A services=(
    ["rag"]="rag"
    ["lobechat"]="lobechat"
    ["vectors"]="vector"
    ["monitor"]="monitor"
    ["kv"]="kv"
    ["graph-ui"]="graph"
)

for service in "${!services[@]}"; do
    label_path=".services.${service}.labels.\"caddy.reverse_proxy\""
    command="yq eval '${label_path}' docker-compose.yaml"
    reverse_proxy=$(yq eval "$label_path" "$COMPOSE_FILE" 2>/dev/null || true)

    if [[ -z "$reverse_proxy" || "$reverse_proxy" == "null" ]]; then
        echo "FAIL|caddy_reverse_proxy|Service $service missing Caddy reverse proxy label|$command"
        continue
    fi

    if [[ "$reverse_proxy" == *"{{upstreams"* ]]; then
        echo "PASS|caddy_reverse_proxy|Service $service reverse proxy label uses upstreams pattern (value: $reverse_proxy)|$command"
    else
        echo "INFO|caddy_reverse_proxy|Service $service reverse proxy label defined but not using upstreams pattern (value: $reverse_proxy)|$command"
    fi

done

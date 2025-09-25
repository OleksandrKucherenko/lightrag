#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy URL Labels Check
# =============================================================================
#
# GIVEN: Caddy labels should publish the correct HTTPS endpoint per service
# WHEN: We read the caddy URL labels from docker-compose.yaml
# THEN: We confirm each label matches the expected domain pattern
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_url_labels|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_url_labels|yq is required to inspect Caddy URL labels|which yq"
    exit 1
fi

declare -A service_subdomains=(
    ["proxy"]=""
    ["rag"]="rag"
    ["lobechat"]="lobechat"
    ["vectors"]="vector"
    ["monitor"]="monitor"
    ["kv"]="kv"
    ["graph-ui"]="graph"
)

for service in "${!service_subdomains[@]}"; do
    subdomain="${service_subdomains[$service]}"
    label_path=".services.${service}.labels.caddy"
    command="yq eval '${label_path}' docker-compose.yaml"
    caddy_url=$(yq eval "$label_path" "$COMPOSE_FILE" 2>/dev/null || true)

    if [[ -z "$caddy_url" || "$caddy_url" == "null" ]]; then
        echo "FAIL|caddy_url_labels|Service $service missing Caddy URL label|$command"
        continue
    fi

    if [[ "$service" == "proxy" ]]; then
        expected="https://\${PUBLISH_DOMAIN}"
    else
        expected="https://${subdomain}.\${PUBLISH_DOMAIN}"
    fi

    if [[ "$caddy_url" == "$expected" ]]; then
        echo "PASS|caddy_url_labels|Service $service Caddy URL label matches expected value $expected|$command"
    else
        echo "FAIL|caddy_url_labels|Service $service Caddy URL label expected $expected but found $caddy_url|$command"
    fi

done

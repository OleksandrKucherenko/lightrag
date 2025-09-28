#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy TLS Labels Check
# =============================================================================
#
# GIVEN: Each routed service must advertise TLS certificate labels for Caddy
# WHEN: We inspect caddy.tls label values in docker-compose.yaml
# THEN: We verify the labels reference /ssl certificate pairs for the expected domain
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_tls_labels|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_tls_labels|yq is required to inspect TLS labels|which yq"
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
    label_path=".services.${service}.labels.\"caddy.tls\""
    command="yq eval '${label_path}' docker-compose.yaml"
    tls_config=$(yq eval "$label_path" "$COMPOSE_FILE" 2>/dev/null || true)

    if [[ -z "$tls_config" || "$tls_config" == "null" ]]; then
        echo "FAIL|caddy_tls_labels|Service $service missing Caddy TLS label|$command"
        continue
    fi

    if [[ "$tls_config" != *"/ssl/"* || "$tls_config" != *".pem"* || "$tls_config" != *"-key.pem"* ]]; then
        echo "FAIL|caddy_tls_labels|Service $service TLS label must reference cert and key under /ssl (value: $tls_config)|$command"
        continue
    fi

    if [[ "$tls_config" != *"$DOMAIN"* ]]; then
        echo "INFO|caddy_tls_labels|Service $service TLS label uses different domain than $DOMAIN (value: $tls_config)|$command"
        continue
    fi

    echo "PASS|caddy_tls_labels|Service $service TLS label references /ssl certificates for $DOMAIN (value: $tls_config)|$command"

done

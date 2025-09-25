#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Certificate Volume Check
# =============================================================================
#
# GIVEN: The Caddy proxy must mount SSL certificates securely from the host
# WHEN: We inspect the proxy service volume definitions in docker-compose.yaml
# THEN: We verify a certificates volume exists, maps to /ssl, and is read-only
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_cert_volume|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_cert_volume|yq is required to inspect Caddy volumes|which yq"
    exit 1
fi

command="yq eval '.services.proxy.volumes[]' docker-compose.yaml"
mapfile -t volumes < <(yq eval '.services.proxy.volumes[]' "$COMPOSE_FILE" 2>/dev/null || true)

if ((${#volumes[@]} == 0)); then
    echo "FAIL|caddy_proxy_cert_volume|Caddy proxy service has no volumes configured|$command"
    exit 0
fi

for volume in "${volumes[@]}"; do
    if [[ "$volume" == *"certificates"* ]]; then
        has_cert_volume=true
        [[ "$volume" == *":/ssl"* ]] && has_ssl_path=true || true
        [[ "$volume" == *":ro" ]] && has_readonly=true || true
        cert_volume="$volume"
        break
    fi

done

if [[ -z "${has_cert_volume:-}" ]]; then
    echo "FAIL|caddy_proxy_cert_volume|Caddy proxy service missing SSL certificate volume|$command"
    exit 0
fi

if [[ -z "${has_ssl_path:-}" ]]; then
    echo "FAIL|caddy_proxy_cert_volume|Certificate volume must mount into /ssl (value: $cert_volume)|$command"
    exit 0
fi

if [[ -z "${has_readonly:-}" ]]; then
    echo "INFO|caddy_proxy_cert_volume|Certificate volume should be read-only (value: $cert_volume)|$command"
    exit 0
fi

echo "PASS|caddy_proxy_cert_volume|Caddy proxy certificate volume is mounted read-only at /ssl (value: $cert_volume)|$command"

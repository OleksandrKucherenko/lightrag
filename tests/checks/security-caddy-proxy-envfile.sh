#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Env File Check
# =============================================================================
#
# GIVEN: The Caddy proxy relies on environment files for configuration
# WHEN: We inspect the proxy service env_file entries in docker-compose.yaml
# THEN: We ensure .env.caddy is included or report when configuration is missing
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_proxy_envfile|docker-compose.yaml not found at $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_proxy_envfile|yq is required to inspect env_file configuration|which yq"
    exit 1
fi

command="yq eval '.services.proxy.env_file[]' docker-compose.yaml"
mapfile -t env_files < <(yq eval '.services.proxy.env_file[]' "$COMPOSE_FILE" 2>/dev/null || true)

if ((${#env_files[@]} == 0)); then
    echo "INFO|caddy_proxy_envfile|Caddy proxy service has no env_file entries defined|yq eval '.services.proxy.env_file' docker-compose.yaml"
    exit 0
fi

for env_file in "${env_files[@]}"; do
    if [[ "$env_file" == *.env.caddy ]]; then
        echo "PASS|caddy_proxy_envfile|Caddy proxy env_file includes .env.caddy (value: $env_file)|$command"
        exit 0
    fi

done

echo "FAIL|caddy_proxy_envfile|Caddy proxy env_file does not include .env.caddy|$command"

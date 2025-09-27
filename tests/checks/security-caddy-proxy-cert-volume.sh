#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Proxy Certificate Volume Check
# =============================================================================
# GIVEN: The Caddy proxy must mount SSL certificates securely from the host
# WHEN: We inspect the proxy service volume definitions in docker-compose.yaml
# THEN: We verify a certificates volume exists, maps to /ssl, and is read-only
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_proxy_cert_volume"
readonly PASS_VOLUME_CONFIGURED="PASS|${TEST_ID}|Caddy proxy certificate volume mounted read-only at /ssl|yq eval '.services.proxy.volumes[]' docker-compose.yaml"
readonly FAIL_NO_VOLUMES="FAIL|${TEST_ID}|Caddy proxy service has no volumes configured|yq eval '.services.proxy.volumes[]' docker-compose.yaml"
readonly FAIL_NO_CERT_VOLUME="FAIL|${TEST_ID}|Caddy proxy service missing SSL certificate volume|yq eval '.services.proxy.volumes[]' docker-compose.yaml"
readonly FAIL_WRONG_PATH="FAIL|${TEST_ID}|Certificate volume must mount into /ssl|yq eval '.services.proxy.volumes[]' docker-compose.yaml"
readonly INFO_NOT_READONLY="INFO|${TEST_ID}|Certificate volume should be read-only|yq eval '.services.proxy.volumes[]' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Check prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
YQ_AVAILABLE=$(command -v yq >/dev/null 2>&1 && echo "true" || echo "false")

# WHEN: Check if docker-compose.yaml exists
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "$BROKEN_COMPOSE"; exit 0; }

# WHEN: Check if yq is available
# THEN: Exit if yq not available
[[ "$YQ_AVAILABLE" == "false" ]] && { echo "$BROKEN_YQ"; exit 0; }

# WHEN: Get proxy service volumes
VOLUMES=$(yq eval '.services.proxy.volumes[]' "$COMPOSE_FILE" 2>/dev/null || echo "")
VOLUMES_COUNT=$(echo "$VOLUMES" | grep -c "." 2>/dev/null || echo "0")

# THEN: Exit if no volumes configured
[[ "$VOLUMES_COUNT" -eq 0 ]] && { echo "$FAIL_NO_VOLUMES"; exit 0; }

# WHEN: Check for certificate volume
CERT_VOLUME=$(echo "$VOLUMES" | grep "certificates" | head -1 || echo "")

# THEN: Exit if no certificate volume
[[ -z "$CERT_VOLUME" ]] && { echo "$FAIL_NO_CERT_VOLUME"; exit 0; }

# WHEN: Check if volume mounts to /ssl
SSL_PATH=$(echo "$CERT_VOLUME" | grep -q ":/ssl" && echo "true" || echo "false")

# THEN: Exit if wrong path
[[ "$SSL_PATH" == "false" ]] && { echo "$FAIL_WRONG_PATH"; exit 0; }

# WHEN: Check if volume is read-only
READONLY=$(echo "$CERT_VOLUME" | grep -q ":ro" && echo "true" || echo "false")

# THEN: Report result
if [[ "$READONLY" == "true" ]]; then
    echo "$PASS_VOLUME_CONFIGURED"
else
    echo "$INFO_NOT_READONLY"
fi
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Setup: Docker Volume Mounting Check
# =============================================================================
# GIVEN: Docker Compose should mount SSL directory
# WHEN: We check docker-compose configuration for SSL volume
# THEN: We verify SSL certificates are mounted into containers
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_docker_volume"
readonly PASS_VOLUME_MOUNTED="PASS|${TEST_ID}|Docker Compose mounts SSL directory|docker compose config"
readonly FAIL_VOLUME_NOTMOUNTED="FAIL|${TEST_ID}|Docker Compose not configured to mount SSL directory|docker compose config"

# WHEN: Check if docker-compose.yaml exists
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"; exit 0; }

# WHEN: Check for SSL volume mounting in docker-compose
VOLUME_MOUNTED=$(docker compose config 2>/dev/null | grep -q "docker/certificates" && echo "true" || echo "false")

# THEN: Report volume mounting status
if [[ "$VOLUME_MOUNTED" == "true" ]]; then
    echo "$PASS_VOLUME_MOUNTED"
else
    echo "$FAIL_VOLUME_NOTMOUNTED"
fi
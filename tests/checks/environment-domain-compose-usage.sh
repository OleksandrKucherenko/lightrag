#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain Configuration: Docker Compose Usage
# =============================================================================
# GIVEN: Docker Compose should use PUBLISH_DOMAIN variable
# WHEN: We check docker-compose configuration for domain usage
# THEN: We verify domain variable is properly interpolated
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="domain_compose_usage"
readonly PASS_DOMAIN_USED="PASS|${TEST_ID}|Docker Compose uses PUBLISH_DOMAIN correctly|docker compose config"
readonly FAIL_DOMAIN_NOTUSED="FAIL|${TEST_ID}|Docker Compose not using PUBLISH_DOMAIN variable|docker compose config"
readonly BROKEN_CONFIG="BROKEN|${TEST_ID}|Cannot get Docker Compose config|docker compose config"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Get Docker Compose configuration
COMPOSE_CONFIG=$(docker compose config 2>&1 || echo "FAILED")
CONFIG_SUCCESS=$([[ "$COMPOSE_CONFIG" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if config failed
[[ "$CONFIG_SUCCESS" == "false" ]] && { echo "$BROKEN_CONFIG: ${COMPOSE_CONFIG:0:50}"; exit 0; }

# WHEN: Check if domain is used in Caddy configuration
DOMAIN_USED=$(echo "$COMPOSE_CONFIG" | grep -q "caddy:.*https://.*\\.$PUBLISH_DOMAIN" && echo "true" || echo "false")

# THEN: Report domain usage
if [[ "$DOMAIN_USED" == "true" ]]; then
    echo "$PASS_DOMAIN_USED"
else
    echo "$FAIL_DOMAIN_NOTUSED"
fi
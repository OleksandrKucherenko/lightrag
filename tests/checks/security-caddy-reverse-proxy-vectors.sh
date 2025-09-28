#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy Reverse Proxy Labels Check - Vectors Service
# =============================================================================
# GIVEN: Vectors service should define reverse proxy labels for Caddy routing
# WHEN: We inspect the caddy.reverse_proxy label in docker-compose.yaml
# THEN: We ensure the label exists and uses the upstreams pattern
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_reverse_proxy_vectors"
readonly PASS_MSG="PASS|${TEST_ID}|Vectors reverse proxy label uses upstreams pattern|yq eval '.services.vectors.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
readonly FAIL_MISSING="FAIL|${TEST_ID}|Vectors service missing Caddy reverse proxy label|yq eval '.services.vectors.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
readonly INFO_NON_STANDARD="INFO|${TEST_ID}|Vectors reverse proxy label defined but not using upstreams pattern|yq eval '.services.vectors.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "$BROKEN_COMPOSE"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "$BROKEN_YQ"; exit 1; }

# WHEN: Extract reverse proxy label
REVERSE_PROXY=$(yq eval '.services.vectors.labels."caddy.reverse_proxy"' "$COMPOSE_FILE" 2>/dev/null || echo "null")

# THEN: Qualify result
[[ -z "$REVERSE_PROXY" || "$REVERSE_PROXY" == "null" ]] && echo "$FAIL_MISSING" || \
[[ "$REVERSE_PROXY" == *"{{upstreams"* ]] && echo "$PASS_MSG" || echo "$INFO_NON_STANDARD"
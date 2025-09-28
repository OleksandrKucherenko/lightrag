#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy TLS Labels Check - Vectors Service
# =============================================================================
# GIVEN: Vectors service must advertise TLS certificate labels for Caddy
# WHEN: We inspect caddy.tls label in docker-compose.yaml
# THEN: We verify the label references /ssl certificate pairs
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="caddy_tls_labels_vectors"
readonly PASS_MSG="PASS|${TEST_ID}|Vectors TLS label references /ssl certificates|yq eval '.services.vectors.labels.\"caddy.tls\"' docker-compose.yaml"
readonly FAIL_MISSING="FAIL|${TEST_ID}|Vectors service missing Caddy TLS label|yq eval '.services.vectors.labels.\"caddy.tls\"' docker-compose.yaml"
readonly FAIL_INVALID="FAIL|${TEST_ID}|Vectors TLS label must reference cert and key under /ssl|yq eval '.services.vectors.labels.\"caddy.tls\"' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"
readonly BROKEN_YQ="BROKEN|${TEST_ID}|yq is required|which yq"

# GIVEN: Prerequisites
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "$BROKEN_COMPOSE"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "$BROKEN_YQ"; exit 1; }

# WHEN: Extract TLS label for vectors service
TLS_CONFIG=$(yq eval '.services.vectors.labels."caddy.tls"' "$COMPOSE_FILE" 2>/dev/null || echo "null")

# THEN: Qualify result
[[ -z "$TLS_CONFIG" || "$TLS_CONFIG" == "null" ]] && echo "$FAIL_MISSING" || \
[[ "$TLS_CONFIG" == *"/ssl/"* && "$TLS_CONFIG" == *".pem"* && "$TLS_CONFIG" == *"-key.pem"* ]] && echo "$PASS_MSG" || echo "$FAIL_INVALID"
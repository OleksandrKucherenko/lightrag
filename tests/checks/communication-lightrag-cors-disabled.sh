#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG CORS Disabled Check
# =============================================================================
# GIVEN: LightRAG may have CORS disabled via comment
# WHEN: We inspect .env.lightrag for CORS disabled comment
# THEN: We report CORS disabled status (domain-based approach)
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lightrag_cors_disabled"
readonly INFO_DISABLED="INFO|${TEST_ID}|CORS disabled (domain-based approach)|grep '# CORS.*not needed' .env.lightrag"
readonly INFO_STATUS="INFO|${TEST_ID}|CORS configuration status unclear|grep CORS .env.lightrag"

# GIVEN: Prerequisites
[[ ! -f "${REPO_ROOT}/.env.lightrag" ]] && { echo "BROKEN|${TEST_ID}|Required file not found: .env.lightrag|ls -la .env.lightrag"; exit 1; }

# WHEN: Check for CORS disabled comment
CORS_DISABLED=$(grep -c "^# CORS.*not needed" "${REPO_ROOT}/.env.lightrag" 2>/dev/null || true)
CORS_DISABLED=${CORS_DISABLED:-0}

# THEN: Report CORS disabled status
[[ "$CORS_DISABLED" == "0" ]] && echo "$INFO_STATUS" || echo "$INFO_DISABLED"
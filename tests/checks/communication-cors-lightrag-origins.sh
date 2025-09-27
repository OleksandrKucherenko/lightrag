#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG CORS Origins Check
# =============================================================================
# GIVEN: LightRAG needs CORS origins configured for LobeChat
# WHEN: We inspect CORS_ORIGINS in .env.lightrag
# THEN: We verify LobeChat domain is included in CORS origins
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lightrag_cors_origins"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat domain in CORS origins|grep CORS_ORIGINS .env.lightrag"
readonly FAIL_MSG="FAIL|${TEST_ID}|LobeChat domain missing from CORS|grep CORS_ORIGINS .env.lightrag"
readonly FAIL_CORS="FAIL|${TEST_ID}|CORS_ORIGINS not configured|grep CORS_ORIGINS .env.lightrag"

# GIVEN: Ensure LightRAG env file exists
ensure_file "${REPO_ROOT}/.env.lightrag" "$TEST_ID"
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract and expand CORS origins
CORS_ORIGINS=$(action_get_env "${REPO_ROOT}/.env.lightrag" "CORS_ORIGINS")
EXPANDED_CORS=$(action_expand_vars "$CORS_ORIGINS")

# THEN: Verify LobeChat domain is in CORS origins
[[ -n "$EXPANDED_CORS" ]] || { echo "$FAIL_CORS"; exit 1; }
[[ "$EXPANDED_CORS" == *"chat.$PUBLISH_DOMAIN"* ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
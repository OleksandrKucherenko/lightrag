#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Origins Alignment Check
# =============================================================================
# GIVEN: LightRAG should allow LobeChat origin in CORS configuration
# WHEN: We inspect CORS_ORIGINS in .env.lightrag
# THEN: We verify LobeChat domain is included in allowed origins
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_alignment_origins"
readonly PASS_MSG="PASS|${TEST_ID}|LightRAG allows LobeChat origin|grep '^CORS_ORIGINS' .env.lightrag"
readonly FAIL_MISSING="FAIL|${TEST_ID}|CORS_ORIGINS missing from .env.lightrag|grep '^CORS_ORIGINS' .env.lightrag"
readonly FAIL_NOTALLOWED="FAIL|${TEST_ID}|LightRAG CORS_ORIGINS missing LobeChat origin|grep '^CORS_ORIGINS' .env.lightrag"

# GIVEN: Ensure LightRAG env file exists
ensure_file "${REPO_ROOT}/.env.lightrag" "$TEST_ID"
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract CORS origins
CORS_ORIGINS=$(action_get_env "${REPO_ROOT}/.env.lightrag" "CORS_ORIGINS")
EXPANDED_CORS=$(action_expand_vars "$CORS_ORIGINS")

# THEN: Verify LobeChat origin is allowed (check both chat and lobechat subdomains)
[[ -z "$CORS_ORIGINS" ]] && echo "$FAIL_MISSING" || \
([[ "$EXPANDED_CORS" == *"https://chat.$PUBLISH_DOMAIN"* ]] || [[ "$EXPANDED_CORS" == *"https://lobechat.$PUBLISH_DOMAIN"* ]]) && echo "$PASS_MSG" || echo "$FAIL_NOTALLOWED"
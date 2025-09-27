#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LobeChat Proxy URL Check
# =============================================================================
# GIVEN: LobeChat needs correct proxy URL for LightRAG API
# WHEN: We inspect OPENAI_PROXY_URL in .env.lobechat
# THEN: We verify proxy URL points to correct LightRAG endpoint
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lobechat_proxy_url"
readonly PASS_INTERNAL="PASS|${TEST_ID}|Correct internal LightRAG base URL|grep OPENAI_PROXY_URL .env.lobechat"
readonly PASS_EXTERNAL="PASS|${TEST_ID}|Correct external LightRAG base URL template|grep OPENAI_PROXY_URL .env.lobechat"
readonly FAIL_PATH="FAIL|${TEST_ID}|Proxy URL has incorrect path suffix|grep OPENAI_PROXY_URL .env.lobechat"
readonly INFO_CONFIGURED="INFO|${TEST_ID}|Proxy URL configured|grep OPENAI_PROXY_URL .env.lobechat"
readonly FAIL_MISSING="FAIL|${TEST_ID}|OPENAI_PROXY_URL not configured|grep OPENAI_PROXY_URL .env.lobechat"

# GIVEN: Prerequisites
[[ ! -f "${REPO_ROOT}/.env.lobechat" ]] && { echo "BROKEN|${TEST_ID}|Required file not found: .env.lobechat|ls -la .env.lobechat"; exit 1; }
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract proxy URL (check both OPENAI_PROXY_URL and OLLAMA_PROXY_URL)
PROXY_URL=$(action_get_env "${REPO_ROOT}/.env.lobechat" "OPENAI_PROXY_URL")
if [[ -z "$PROXY_URL" ]]; then
    PROXY_URL=$(action_get_env "${REPO_ROOT}/.env.lobechat" "OLLAMA_PROXY_URL")
fi
EXPANDED_URL=$(action_expand_vars "$PROXY_URL")

# THEN: Verify proxy URL configuration
[[ -z "$EXPANDED_URL" ]] && echo "$FAIL_MISSING" || \
[[ "$EXPANDED_URL" == "http://rag:9621" ]] && echo "$PASS_INTERNAL" || \
[[ "$EXPANDED_URL" == "http://rag:9621/v1" ]] && echo "$PASS_INTERNAL" || \
[[ "$EXPANDED_URL" == "https://api.$PUBLISH_DOMAIN" ]] && echo "$PASS_EXTERNAL" || \
[[ "$EXPANDED_URL" == *"/api" ]] && echo "$FAIL_PATH" || echo "$INFO_CONFIGURED"
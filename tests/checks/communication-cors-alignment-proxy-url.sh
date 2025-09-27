#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Proxy URL Alignment Check
# =============================================================================
# GIVEN: LobeChat should proxy to LightRAG internally to avoid CORS
# WHEN: We inspect OPENAI_PROXY_URL in .env.lobechat
# THEN: We verify proxy URL points to internal LightRAG service
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_alignment_proxy_url"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat proxy points to internal LightRAG|grep '^OPENAI_PROXY_URL' .env.lobechat"
readonly FAIL_INCORRECT="FAIL|${TEST_ID}|OPENAI_PROXY_URL should be http://rag:9621/v1|grep '^OPENAI_PROXY_URL' .env.lobechat"

# GIVEN: Ensure LobeChat env file exists
ensure_file "${REPO_ROOT}/.env.lobechat" "$TEST_ID"

# WHEN: Extract proxy URL
PROXY_URL=$(action_get_env "${REPO_ROOT}/.env.lobechat" "OPENAI_PROXY_URL")

# THEN: Verify proxy URL is correct
if [[ "$PROXY_URL" == "http://rag:9621/v1" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_INCORRECT"
fi
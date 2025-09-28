#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain Configuration: LobeChat Proxy URL
# =============================================================================
# GIVEN: LobeChat should use correct domain-based proxy URL
# WHEN: We inspect OPENAI_PROXY_URL in .env.lobechat
# THEN: We verify it uses the correct Ollama-compatible base URL
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="domain_lobechat_proxy_url"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat using correct Ollama base URL|grep OPENAI_PROXY_URL .env.lobechat"
readonly FAIL_INCORRECT="FAIL|${TEST_ID}|LobeChat not using correct Ollama base URL|grep OPENAI_PROXY_URL .env.lobechat"
readonly BROKEN_MISSING="BROKEN|${TEST_ID}|LobeChat environment file not found|ls .env.lobechat"

# GIVEN: Ensure LobeChat env file exists
ensure_file "${REPO_ROOT}/.env.lobechat" "$TEST_ID"
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract proxy URL
PROXY_URL=$(action_get_env "${REPO_ROOT}/.env.lobechat" "OPENAI_PROXY_URL")

# THEN: Verify proxy URL is correct (accept both domain and internal URLs)
if [[ "$PROXY_URL" == "https://api.\${PUBLISH_DOMAIN}" ]] || [[ "$PROXY_URL" == "http://rag:9621/v1" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_INCORRECT"
fi
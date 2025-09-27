#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Service Mode Alignment Check
# =============================================================================
# GIVEN: LobeChat should run in server mode to avoid browser CORS issues
# WHEN: We inspect NEXT_PUBLIC_SERVICE_MODE in .env.lobechat
# THEN: We verify service mode is set to server for API proxying
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_alignment_service_mode"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat server mode avoids browser CORS|grep '^NEXT_PUBLIC_SERVICE_MODE' .env.lobechat"
readonly FAIL_NOTSERVER="FAIL|${TEST_ID}|NEXT_PUBLIC_SERVICE_MODE should be 'server'|grep '^NEXT_PUBLIC_SERVICE_MODE' .env.lobechat"

# GIVEN: Ensure LobeChat env file exists
ensure_file "${REPO_ROOT}/.env.lobechat" "$TEST_ID"

# WHEN: Extract service mode
SERVICE_MODE=$(action_get_env "${REPO_ROOT}/.env.lobechat" "NEXT_PUBLIC_SERVICE_MODE")

# THEN: Verify service mode is server
if [[ "$SERVICE_MODE" == "server" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_NOTSERVER"
fi
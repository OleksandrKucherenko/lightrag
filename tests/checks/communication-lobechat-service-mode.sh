#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LobeChat Service Mode Check
# =============================================================================
# GIVEN: LobeChat can run in server or client mode
# WHEN: We inspect NEXT_PUBLIC_SERVICE_MODE in .env.lobechat
# THEN: We verify service mode is configured (server mode avoids CORS issues)
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lobechat_service_mode"
readonly PASS_MSG="PASS|${TEST_ID}|Server mode enabled (avoids CORS)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
readonly INFO_MSG="INFO|${TEST_ID}|Client mode active (CORS required)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"

# GIVEN: Ensure LobeChat env file exists
ensure_file "${REPO_ROOT}/.env.lobechat" "$TEST_ID"

# WHEN: Extract service mode
SERVICE_MODE=$(action_get_env "${REPO_ROOT}/.env.lobechat" "NEXT_PUBLIC_SERVICE_MODE")

# THEN: Verify service mode configuration
[[ "$SERVICE_MODE" == "server" ]] && echo "$PASS_MSG" || echo "$INFO_MSG"
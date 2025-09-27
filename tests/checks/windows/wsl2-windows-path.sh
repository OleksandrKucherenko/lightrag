#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Windows PATH Integration Check
# =============================================================================
# GIVEN: WSL2 may integrate Windows PATH into Linux environment
# WHEN: We check if Windows directories are in PATH
# THEN: We report whether Windows PATH is integrated
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_windows_path"
readonly PASS_MSG="PASS|${TEST_ID}|Windows PATH integrated into WSL2|echo \$PATH | grep Windows"
readonly INFO_MSG="INFO|${TEST_ID}|Windows PATH not integrated (may be intentional)|echo \$PATH | grep Windows"

# WHEN: Check PATH integration
WINDOWS_IN_PATH=$(echo "$PATH" | grep -q "/mnt/c/Windows" && echo "true" || echo "false")

# THEN: Qualify result
[[ "$WINDOWS_IN_PATH" == "true" ]] && echo "$PASS_MSG" || echo "$INFO_MSG"
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 CMD Access Check
# =============================================================================
# GIVEN: WSL2 should provide access to Windows CMD
# WHEN: We check if cmd.exe is accessible from WSL2
# THEN: We verify Windows CMD can be called from WSL2
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_cmd_access"
readonly PASS_MSG="PASS|${TEST_ID}|Windows CMD accessible from WSL2|which cmd.exe"
readonly FAIL_MSG="FAIL|${TEST_ID}|Windows CMD not accessible from WSL2|which cmd.exe"

# WHEN: Check CMD availability
CMD_AVAILABLE=$(command -v cmd.exe >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Qualify result
[[ "$CMD_AVAILABLE" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
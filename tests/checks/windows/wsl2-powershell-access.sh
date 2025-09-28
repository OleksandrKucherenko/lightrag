#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 PowerShell Access Check
# =============================================================================
# GIVEN: WSL2 should provide access to Windows PowerShell
# WHEN: We check if powershell.exe is accessible from WSL2
# THEN: We verify Windows PowerShell can be called from WSL2
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_powershell_access"
readonly PASS_MSG="PASS|${TEST_ID}|Windows PowerShell accessible from WSL2|which powershell.exe"
readonly FAIL_MSG="FAIL|${TEST_ID}|Windows PowerShell not accessible from WSL2|which powershell.exe"

# WHEN: Check PowerShell availability
POWERSHELL_AVAILABLE=$(command -v powershell.exe >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Qualify result
[[ "$POWERSHELL_AVAILABLE" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
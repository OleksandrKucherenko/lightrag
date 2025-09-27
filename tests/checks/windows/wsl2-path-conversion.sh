#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Path Conversion Check
# =============================================================================
# GIVEN: WSL2 should support path conversion between Linux and Windows
# WHEN: We test wslpath utility for converting /tmp to Windows path
# THEN: We verify path conversion is working correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_path_conversion"
readonly PASS_MSG="PASS|${TEST_ID}|Path conversion working|wslpath -w /tmp"
readonly FAIL_MSG="FAIL|${TEST_ID}|Path conversion not working|wslpath -w /tmp"
readonly BROKEN_MSG="BROKEN|${TEST_ID}|wslpath utility not available|which wslpath"

# WHEN: Check wslpath availability and functionality
WSLPATH_AVAILABLE=$(command -v wslpath >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Check if wslpath exists
[[ "$WSLPATH_AVAILABLE" == "false" ]] && { echo "$BROKEN_MSG"; exit 1; }

# WHEN: Test path conversion
WINDOWS_PATH=$(wslpath -w "/tmp" 2>/dev/null || echo "failed")
CONVERSION_WORKS=$([[ "$WINDOWS_PATH" != "failed" && -n "$WINDOWS_PATH" ]] && echo "true" || echo "false")

# THEN: Qualify result
[[ "$CONVERSION_WORKS" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
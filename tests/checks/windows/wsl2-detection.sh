#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Detection Check
# =============================================================================
# GIVEN: System should be running in WSL2 environment
# WHEN: We inspect /proc/version for WSL2 indicators
# THEN: We verify we're running in WSL2 (not WSL1 or native Linux)
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_detection"
readonly PASS_WSL2="PASS|${TEST_ID}|Running in WSL2 environment|cat /proc/version"
readonly INFO_WSL1="INFO|${TEST_ID}|Running in WSL1 environment|cat /proc/version"
readonly INFO_NATIVE="INFO|${TEST_ID}|Not running in WSL environment|cat /proc/version"

# WHEN: Check WSL version
PROC_VERSION=$(cat /proc/version 2>/dev/null || echo "unknown")
IS_MICROSOFT=$(echo "$PROC_VERSION" | grep -q "microsoft" && echo "true" || echo "false")
IS_WSL2=$(echo "$PROC_VERSION" | grep -q "WSL2" && echo "true" || echo "false")

# THEN: Qualify result
[[ "$IS_MICROSOFT" == "false" ]] && echo "$INFO_NATIVE" || \
[[ "$IS_WSL2" == "true" ]] && echo "$PASS_WSL2" || echo "$INFO_WSL1"
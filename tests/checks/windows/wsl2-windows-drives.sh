#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Windows Drives Check
# =============================================================================
# GIVEN: WSL2 should mount Windows drives automatically
# WHEN: We check if /mnt/c directory exists
# THEN: We verify Windows C: drive is mounted at /mnt/c
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_windows_drives"
readonly PASS_MSG="PASS|${TEST_ID}|Windows C: drive mounted at /mnt/c|ls -la /mnt/c"
readonly FAIL_MSG="FAIL|${TEST_ID}|Windows C: drive not mounted|ls -la /mnt/c"

# WHEN: Check if Windows drive is mounted
DRIVE_MOUNTED=$([[ -d "/mnt/c" ]] && echo "true" || echo "false")

# THEN: Qualify result
[[ "$DRIVE_MOUNTED" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
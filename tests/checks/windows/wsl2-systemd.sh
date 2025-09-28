#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 systemd Integration Check
# =============================================================================
# GIVEN: WSL2 may support systemd for service management
# WHEN: We check if systemctl is available and functional
# THEN: We verify systemd integration status
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_systemd"
readonly PASS_MSG="PASS|${TEST_ID}|systemd available in WSL2|systemctl --version"
readonly INFO_PRESENT="INFO|${TEST_ID}|systemd present but not functional|systemctl --version"
readonly INFO_MISSING="INFO|${TEST_ID}|systemd not available (normal for older WSL2)|which systemctl"

# WHEN: Check systemd availability
SYSTEMCTL_EXISTS=$(command -v systemctl >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Check if systemctl exists
[[ "$SYSTEMCTL_EXISTS" == "false" ]] && { echo "$INFO_MISSING"; exit 0; }

# WHEN: Test systemctl functionality
SYSTEMCTL_WORKS=$(systemctl --version >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Qualify result
[[ "$SYSTEMCTL_WORKS" == "true" ]] && echo "$PASS_MSG" || echo "$INFO_PRESENT"
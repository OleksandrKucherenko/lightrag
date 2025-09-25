#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Test Script in Subdirectory
# =============================================================================
# 
# GIVEN: Testing framework should support subdirectories
# WHEN: We place a check script in a subdirectory
# THEN: The orchestrator should find and execute it
# =============================================================================

echo "PASS|subdirectory_test|Test script in subdirectory executed successfully|find tests/checks -name '*security*'"
echo "INFO|subdirectory_test|This script is located in tests/checks/experimental/|ls tests/checks/experimental/"

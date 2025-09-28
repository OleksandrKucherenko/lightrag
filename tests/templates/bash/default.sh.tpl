#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# {{TITLE}}
# =============================================================================
# GIVEN: {{GIVEN}}
# WHEN: {{WHEN}}
# THEN: {{THEN}}
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="{{CHECK_ID}}"
readonly PASS_MSG="PASS|${TEST_ID}|Success message|{{COMMAND_HINT}}"
readonly FAIL_MSG="FAIL|${TEST_ID}|Failure message|{{COMMAND_HINT}}"
readonly INFO_MSG="INFO|${TEST_ID}|Info message|{{COMMAND_HINT}}"
readonly BROKEN_MSG="BROKEN|${TEST_ID}|Prerequisite missing|{{COMMAND_HINT}}"

# GIVEN: Prerequisites
# TODO: Add prerequisite validation here (ensure_file, defaults, etc.)

# WHEN: Extract data
# TODO: Add data extraction logic here

# THEN: Apply business rules and determine outcome
# TODO: Add qualification logic here
echo "$INFO_MSG"

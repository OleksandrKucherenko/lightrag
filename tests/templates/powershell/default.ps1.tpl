# =============================================================================
# {{TITLE}}
# =============================================================================
# GIVEN: {{GIVEN}}
# WHEN: {{WHEN}}
# THEN: {{THEN}}
# =============================================================================

# Constants - declare once, use everywhere
$TEST_ID = "{{CHECK_ID}}"
$PASS_MSG = "PASS|$TEST_ID|Success message|{{COMMAND_HINT}}"
$FAIL_MSG = "FAIL|$TEST_ID|Failure message|{{COMMAND_HINT}}"
$INFO_MSG = "INFO|$TEST_ID|Info message|{{COMMAND_HINT}}"
$BROKEN_MSG = "BROKEN|$TEST_ID|Prerequisite missing|{{COMMAND_HINT}}"

# GIVEN: Prerequisites
# TODO: Add prerequisite validation here (file existence, defaults, etc.)

# WHEN: Extract data
# TODO: Add data extraction logic here

# THEN: Apply business rules and determine outcome
# TODO: Add qualification logic here
Write-Output $INFO_MSG

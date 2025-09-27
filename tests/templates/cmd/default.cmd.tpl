@echo off

:: =============================================================================
:: {{TITLE}}
:: =============================================================================
:: GIVEN: {{GIVEN}}
:: WHEN: {{WHEN}}
:: THEN: {{THEN}}
:: =============================================================================

:: Constants - declare once, use everywhere
SET TEST_ID={{CHECK_ID}}
SET PASS_MSG=PASS|%TEST_ID%|Success message|{{COMMAND_HINT}}
SET FAIL_MSG=FAIL|%TEST_ID%|Failure message|{{COMMAND_HINT}}
SET INFO_MSG=INFO|%TEST_ID%|Info message|{{COMMAND_HINT}}
SET BROKEN_MSG=BROKEN|%TEST_ID%|Prerequisite missing|{{COMMAND_HINT}}

:: GIVEN: Prerequisites
:: TODO: Add prerequisite validation here (file existence, defaults, etc.)

:: WHEN: Extract data
:: TODO: Add data extraction logic here

:: THEN: Apply business rules and determine outcome
:: TODO: Add qualification logic here
ECHO %INFO_MSG%

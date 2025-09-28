#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Hosts Preprocessing: Basic Template Check
# =============================================================================
# GIVEN: .etchosts template should exist and be preprocessable
# WHEN: We test basic template preprocessing with envsubst
# THEN: We verify environment variables are properly substituted
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="hosts_basic_preprocessing"
readonly PASS_PREPROCESSING="PASS|${TEST_ID}|Basic template preprocessing working|envsubst < .etchosts"
readonly FAIL_SUBSTITUTION="FAIL|${TEST_ID}|Template variables not substituted properly|envsubst < .etchosts"
readonly BROKEN_TEMPLATE_MISSING="BROKEN|${TEST_ID}|.etchosts template not found|ls .etchosts"
readonly BROKEN_PREPROCESSING="BROKEN|${TEST_ID}|Template preprocessing failed|envsubst < .etchosts"

# GIVEN: Check if template exists
TEMPLATE_FILE="${REPO_ROOT}/.etchosts"
TEMPLATE_EXISTS=$([[ -f "$TEMPLATE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if template missing
[[ "$TEMPLATE_EXISTS" == "false" ]] && { echo "$BROKEN_TEMPLATE_MISSING"; exit 0; }

# WHEN: Set environment variables
export PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
export HOST_IP="${HOST_IP:-127.0.0.1}"

# WHEN: Test template preprocessing
PREPROCESSED=$(envsubst < "$TEMPLATE_FILE" 2>&1 || echo "FAILED")
PREPROCESS_SUCCESS=$([[ "$PREPROCESSED" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if preprocessing failed
[[ "$PREPROCESS_SUCCESS" == "false" ]] && { echo "$BROKEN_PREPROCESSING: ${PREPROCESSED:0:50}"; exit 0; }

# WHEN: Check if variables were substituted
DOMAIN_SUBSTITUTED=$(echo "$PREPROCESSED" | grep -q "$PUBLISH_DOMAIN" && echo "true" || echo "false")
VARIABLES_REMAINING=$(echo "$PREPROCESSED" | grep -q '\$PUBLISH_DOMAIN\|\$HOST_IP' && echo "true" || echo "false")

# THEN: Report preprocessing result
if [[ "$DOMAIN_SUBSTITUTED" == "true" ]] && [[ "$VARIABLES_REMAINING" == "false" ]]; then
    echo "$PASS_PREPROCESSING"
else
    echo "$FAIL_SUBSTITUTION"
fi
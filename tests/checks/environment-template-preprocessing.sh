#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Template Preprocessing Check
# =============================================================================
# GIVEN: Template files that need variable substitution
# WHEN: We test template preprocessing with detected host IP
# THEN: We verify variables are correctly substituted
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="template_preprocessing"
readonly PASS_MSG="PASS|${TEST_ID}|Template preprocessing working|envsubst < .etchosts"
readonly FAIL_SUBSTITUTION="FAIL|${TEST_ID}|Template preprocessing failed|envsubst < .etchosts"
readonly BROKEN_MISSING="BROKEN|${TEST_ID}|.etchosts template not found|ls .etchosts"
readonly BROKEN_PREPROCESS="BROKEN|${TEST_ID}|Template preprocessing failed|envsubst < .etchosts"

# GIVEN: Check if template file exists
TEMPLATE_PATH="${REPO_ROOT}/.etchosts"
TEMPLATE_EXISTS=$([[ -f "$TEMPLATE_PATH" ]] && echo "true" || echo "false")

# THEN: Exit if template doesn't exist
[[ "$TEMPLATE_EXISTS" == "false" ]] && { echo "$BROKEN_MISSING"; exit 0; }

# WHEN: Get detected host IP
HOST_IP_SCRIPT="${REPO_ROOT}/bin/get-host-ip.sh"
HOST_IP_EXISTS=$([[ -x "$HOST_IP_SCRIPT" ]] && echo "true" || echo "false")

if [[ "$HOST_IP_EXISTS" == "true" ]]; then
    DETECTED_IP=$(clean_output "$("$HOST_IP_SCRIPT" 2>&1)") || DETECTED_IP=""
else
    DETECTED_IP=""
fi

# WHEN: Set environment variables for substitution
export HOST_IP="${DETECTED_IP:-127.0.0.1}"
export PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Test template preprocessing
PREPROCESSED=$(clean_output "$(envsubst < "$TEMPLATE_PATH" 2>&1)") || PREPROCESSED="FAILED"
PREPROCESS_SUCCESS=$([[ "$PREPROCESSED" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if preprocessing failed
[[ "$PREPROCESS_SUCCESS" == "false" ]] && { echo "$BROKEN_PREPROCESS"; exit 0; }

# WHEN: Check if variables were substituted
CONTAINS_IP=$([[ "$PREPROCESSED" == *"$HOST_IP"* ]] && echo "true" || echo "false")
CONTAINS_VARS=$([[ "$PREPROCESSED" == *'$HOST_IP'* ]] && echo "true" || echo "false")

# THEN: Report preprocessing result
if [[ "$CONTAINS_IP" == "true" ]] && [[ "$CONTAINS_VARS" == "false" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_SUBSTITUTION"
fi
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Hosts Preprocessing: Custom IP Test
# =============================================================================
# GIVEN: Template preprocessing should work with custom HOST_IP
# WHEN: We test template preprocessing with custom HOST_IP
# THEN: We verify custom IP is properly substituted
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="hosts_custom_ip"
readonly PASS_CUSTOM_IP="PASS|${TEST_ID}|Custom IP preprocessing working|HOST_IP=192.168.1.100 envsubst < .etchosts"
readonly FAIL_CUSTOM_IP="FAIL|${TEST_ID}|Custom IP preprocessing failed|HOST_IP=192.168.1.100 envsubst < .etchosts"
readonly BROKEN_CUSTOM_IP="BROKEN|${TEST_ID}|Custom IP preprocessing error|HOST_IP=192.168.1.100 envsubst < .etchosts"

# GIVEN: Check if template exists
TEMPLATE_FILE="${REPO_ROOT}/.etchosts"
TEMPLATE_EXISTS=$([[ -f "$TEMPLATE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if template missing
[[ "$TEMPLATE_EXISTS" == "false" ]] && { echo "BROKEN|${TEST_ID}|.etchosts template not found|ls .etchosts"; exit 0; }

# WHEN: Test with custom IP
export PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
export HOST_IP="192.168.1.100"

IP_RESULT=$(envsubst < "$TEMPLATE_FILE" 2>&1 || echo "FAILED")
RESULT_SUCCESS=$([[ "$IP_RESULT" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if preprocessing failed
[[ "$RESULT_SUCCESS" == "false" ]] && { echo "$BROKEN_CUSTOM_IP: ${IP_RESULT:0:50}"; exit 0; }

# WHEN: Check if custom IP was substituted
IP_SUBSTITUTED=$(echo "$IP_RESULT" | grep -q "192.168.1.100" && echo "true" || echo "false")
VARIABLES_REMAINING=$(echo "$IP_RESULT" | grep -q '\$HOST_IP' && echo "true" || echo "false")

# THEN: Report custom IP result
if [[ "$IP_SUBSTITUTED" == "true" ]] && [[ "$VARIABLES_REMAINING" == "false" ]]; then
    echo "$PASS_CUSTOM_IP"
else
    echo "$FAIL_CUSTOM_IP"
fi
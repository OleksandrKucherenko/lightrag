#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Hosts Preprocessing: Custom Domain Test
# =============================================================================
# GIVEN: Template preprocessing should work with custom domains
# WHEN: We test template preprocessing with custom PUBLISH_DOMAIN
# THEN: We verify custom domain is properly substituted
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="hosts_custom_domain"
readonly PASS_CUSTOM_DOMAIN="PASS|${TEST_ID}|Custom domain preprocessing working|PUBLISH_DOMAIN=test.local envsubst < .etchosts"
readonly FAIL_CUSTOM_DOMAIN="FAIL|${TEST_ID}|Custom domain preprocessing failed|PUBLISH_DOMAIN=test.local envsubst < .etchosts"
readonly BROKEN_CUSTOM_DOMAIN="BROKEN|${TEST_ID}|Custom domain preprocessing error|PUBLISH_DOMAIN=test.local envsubst < .etchosts"

# GIVEN: Check if template exists
TEMPLATE_FILE="${REPO_ROOT}/.etchosts"
TEMPLATE_EXISTS=$([[ -f "$TEMPLATE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if template missing
[[ "$TEMPLATE_EXISTS" == "false" ]] && { echo "BROKEN|${TEST_ID}|.etchosts template not found|ls .etchosts"; exit 0; }

# WHEN: Test with custom domain
export PUBLISH_DOMAIN="test.local"
export HOST_IP="${HOST_IP:-127.0.0.1}"

CUSTOM_RESULT=$(envsubst < "$TEMPLATE_FILE" 2>&1 || echo "FAILED")
RESULT_SUCCESS=$([[ "$CUSTOM_RESULT" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if preprocessing failed
[[ "$RESULT_SUCCESS" == "false" ]] && { echo "$BROKEN_CUSTOM_DOMAIN: ${CUSTOM_RESULT:0:50}"; exit 0; }

# WHEN: Check if custom domain was substituted
DOMAIN_SUBSTITUTED=$(echo "$CUSTOM_RESULT" | grep -q "test.local" && echo "true" || echo "false")
VARIABLES_REMAINING=$(echo "$CUSTOM_RESULT" | grep -q '\$PUBLISH_DOMAIN' && echo "true" || echo "false")

# THEN: Report custom domain result
if [[ "$DOMAIN_SUBSTITUTED" == "true" ]] && [[ "$VARIABLES_REMAINING" == "false" ]]; then
    echo "$PASS_CUSTOM_DOMAIN"
else
    echo "$FAIL_CUSTOM_DOMAIN"
fi
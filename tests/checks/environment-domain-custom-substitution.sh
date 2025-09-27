#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain Configuration: Custom Domain Substitution
# =============================================================================
# GIVEN: Domain substitution should work with custom values
# WHEN: We test domain variable substitution with custom domain
# THEN: We verify domain interpolation works correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="domain_custom_substitution"
readonly PASS_SUBSTITUTION="PASS|${TEST_ID}|Custom domain substitution working|PUBLISH_DOMAIN=test.local docker compose config"
readonly FAIL_SUBSTITUTION="FAIL|${TEST_ID}|Custom domain substitution not working|PUBLISH_DOMAIN=test.local docker compose config"
readonly BROKEN_TEST="BROKEN|${TEST_ID}|Cannot test custom domain|PUBLISH_DOMAIN=test.local docker compose config"

# WHEN: Test custom domain substitution
CUSTOM_CONFIG=$(PUBLISH_DOMAIN=test.local docker compose config 2>&1 || echo "FAILED")
CONFIG_SUCCESS=$([[ "$CUSTOM_CONFIG" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if config failed
[[ "$CONFIG_SUCCESS" == "false" ]] && { echo "$BROKEN_TEST: ${CUSTOM_CONFIG:0:50}"; exit 0; }

# WHEN: Check if custom domain is substituted
SUBSTITUTION_WORKS=$(echo "$CUSTOM_CONFIG" | grep -q "caddy:.*https://.*\\.test\\.local" && echo "true" || echo "false")

# THEN: Report substitution result
if [[ "$SUBSTITUTION_WORKS" == "true" ]]; then
    echo "$PASS_SUBSTITUTION"
else
    echo "$FAIL_SUBSTITUTION"
fi
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain Configuration: Environment Variable Check
# =============================================================================
# GIVEN: PUBLISH_DOMAIN environment variable should be set
# WHEN: We check the PUBLISH_DOMAIN variable value
# THEN: We verify the domain variable is properly configured
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="domain_variable_set"
readonly INFO_DOMAIN_SET="INFO|${TEST_ID}|PUBLISH_DOMAIN set to|echo \$PUBLISH_DOMAIN"
readonly BROKEN_DOMAIN_NOTSET="BROKEN|${TEST_ID}|PUBLISH_DOMAIN environment variable not set|echo \$PUBLISH_DOMAIN"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-}"

# WHEN: Check if PUBLISH_DOMAIN is set
DOMAIN_SET=$([[ -n "$PUBLISH_DOMAIN" ]] && echo "true" || echo "false")

# THEN: Report domain variable status
if [[ "$DOMAIN_SET" == "true" ]]; then
    echo "$INFO_DOMAIN_SET: $PUBLISH_DOMAIN"
else
    echo "$BROKEN_DOMAIN_NOTSET"
fi
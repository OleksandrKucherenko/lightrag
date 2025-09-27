#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# External Main Site Endpoint Check
# =============================================================================
# GIVEN: Main site should be accessible externally via HTTPS
# WHEN: We test main site health endpoint accessibility
# THEN: We verify the endpoint responds correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="external_endpoint_main"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|Main site accessible|curl -I https://\${PUBLISH_DOMAIN}/health"
readonly PASS_AUTH="PASS|${TEST_ID}|Main site accessible with auth|curl -I https://\${PUBLISH_DOMAIN}/health"
readonly FAIL_NOTFOUND="FAIL|${TEST_ID}|Main site not found|curl -I https://\${PUBLISH_DOMAIN}/health"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|Main site connection failed|curl -I https://\${PUBLISH_DOMAIN}/health"
readonly FAIL_UNEXPECTED="FAIL|${TEST_ID}|Main site unexpected status|curl -I https://\${PUBLISH_DOMAIN}/health"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://$PUBLISH_DOMAIN/health"

# WHEN: Test endpoint accessibility
STATUS_CODE=$(probe_http_endpoint "$URL")

# THEN: Evaluate response status
case "$STATUS_CODE" in
    200)
        echo "$PASS_ACCESSIBLE"
        ;;
    401|403)
        echo "$PASS_AUTH"
        ;;
    404)
        echo "$FAIL_NOTFOUND"
        ;;
    0)
        echo "$FAIL_CONNECTION"
        ;;
    *)
        echo "$FAIL_UNEXPECTED"
        ;;
esac
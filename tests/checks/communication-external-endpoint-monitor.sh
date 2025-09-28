#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# External Monitoring Dashboard Endpoint Check
# =============================================================================
# GIVEN: Monitoring dashboard should be accessible externally via HTTPS
# WHEN: We test monitoring dashboard endpoint accessibility
# THEN: We verify the endpoint responds correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="external_endpoint_monitor"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|Monitoring dashboard accessible|curl -I https://monitor.\${PUBLISH_DOMAIN}/"
readonly PASS_AUTH="PASS|${TEST_ID}|Monitoring dashboard accessible with auth|curl -I https://monitor.\${PUBLISH_DOMAIN}/"
readonly FAIL_NOTFOUND="FAIL|${TEST_ID}|Monitoring dashboard not found|curl -I https://monitor.\${PUBLISH_DOMAIN}/"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|Monitoring dashboard connection failed|curl -I https://monitor.\${PUBLISH_DOMAIN}/"
readonly FAIL_UNEXPECTED="FAIL|${TEST_ID}|Monitoring dashboard unexpected status|curl -I https://monitor.\${PUBLISH_DOMAIN}/"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://monitor.$PUBLISH_DOMAIN/"

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
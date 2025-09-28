#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Endpoint Check: Proxy Service
# =============================================================================
# GIVEN: Proxy service should be accessible via HTTPS
# WHEN: We test HTTPS connectivity to proxy service
# THEN: We verify SSL/TLS communication is working
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_endpoint_proxy"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|Proxy HTTPS accessible|curl -I -k https://\${PUBLISH_DOMAIN}"
readonly PASS_AUTH="PASS|${TEST_ID}|Proxy HTTPS accessible with auth|curl -I -k https://\${PUBLISH_DOMAIN}"
readonly FAIL_STATUS="FAIL|${TEST_ID}|Proxy HTTPS unexpected status|curl -I -k https://\${PUBLISH_DOMAIN}"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|Proxy HTTPS connection failed|curl -I -k https://\${PUBLISH_DOMAIN}"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://$PUBLISH_DOMAIN"

# WHEN: Test HTTPS connectivity
STATUS_CODE=$(probe_http_endpoint "$URL")

# THEN: Evaluate response status
case "$STATUS_CODE" in
    200|301|302)
        echo "$PASS_ACCESSIBLE"
        ;;
    401|403)
        echo "$PASS_AUTH"
        ;;
    0)
        echo "$FAIL_CONNECTION"
        ;;
    *)
        echo "$FAIL_STATUS"
        ;;
esac
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# External LobeChat Interface Endpoint Check
# =============================================================================
# GIVEN: LobeChat interface should be accessible externally via HTTPS
# WHEN: We test LobeChat interface endpoint accessibility
# THEN: We verify the endpoint responds correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="external_endpoint_lobechat"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|LobeChat interface accessible|curl -I https://lobechat.\${PUBLISH_DOMAIN}/"
readonly PASS_AUTH="PASS|${TEST_ID}|LobeChat interface accessible with auth|curl -I https://lobechat.\${PUBLISH_DOMAIN}/"
readonly FAIL_NOTFOUND="FAIL|${TEST_ID}|LobeChat interface not found|curl -I https://lobechat.\${PUBLISH_DOMAIN}/"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|LobeChat interface connection failed|curl -I https://lobechat.\${PUBLISH_DOMAIN}/"
readonly FAIL_UNEXPECTED="FAIL|${TEST_ID}|LobeChat interface unexpected status|curl -I https://lobechat.\${PUBLISH_DOMAIN}/"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://lobechat.$PUBLISH_DOMAIN/"

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
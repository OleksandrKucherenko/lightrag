#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# External Qdrant API Endpoint Check
# =============================================================================
# GIVEN: Qdrant API should be accessible externally via HTTPS
# WHEN: We test Qdrant API collections endpoint accessibility
# THEN: We verify the endpoint responds correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="external_endpoint_qdrant"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|Qdrant API accessible|curl -I https://vector.\${PUBLISH_DOMAIN}/collections"
readonly PASS_AUTH="PASS|${TEST_ID}|Qdrant API accessible with auth|curl -I https://vector.\${PUBLISH_DOMAIN}/collections"
readonly FAIL_NOTFOUND="FAIL|${TEST_ID}|Qdrant API not found|curl -I https://vector.\${PUBLISH_DOMAIN}/collections"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|Qdrant API connection failed|curl -I https://vector.\${PUBLISH_DOMAIN}/collections"
readonly FAIL_UNEXPECTED="FAIL|${TEST_ID}|Qdrant API unexpected status|curl -I https://vector.\${PUBLISH_DOMAIN}/collections"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://vector.$PUBLISH_DOMAIN/collections"

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
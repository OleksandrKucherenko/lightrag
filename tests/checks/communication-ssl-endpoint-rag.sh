#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Endpoint Check: LightRAG Service
# =============================================================================
# GIVEN: LightRAG service should be accessible via HTTPS
# WHEN: We test HTTPS connectivity to LightRAG service
# THEN: We verify SSL/TLS communication is working
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_endpoint_rag"
readonly PASS_ACCESSIBLE="PASS|${TEST_ID}|LightRAG HTTPS accessible|curl -I -k https://rag.\${PUBLISH_DOMAIN}"
readonly PASS_AUTH="PASS|${TEST_ID}|LightRAG HTTPS accessible with auth|curl -I -k https://rag.\${PUBLISH_DOMAIN}"
readonly FAIL_STATUS="FAIL|${TEST_ID}|LightRAG HTTPS unexpected status|curl -I -k https://rag.\${PUBLISH_DOMAIN}"
readonly FAIL_CONNECTION="FAIL|${TEST_ID}|LightRAG HTTPS connection failed|curl -I -k https://rag.\${PUBLISH_DOMAIN}"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://rag.$PUBLISH_DOMAIN"

# WHEN: Test HTTPS connectivity
STATUS_CODE=$(probe_http_endpoint "$URL")

# THEN: Evaluate response status
case "$STATUS_CODE" in
    200|301|302|307|405)
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
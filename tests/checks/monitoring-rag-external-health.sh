#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG Health: External Health Endpoint Check
# =============================================================================
# GIVEN: LightRAG should be accessible externally via HTTPS
# WHEN: We test the external health endpoint
# THEN: We verify the service is accessible from outside
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="rag_external_health"
readonly PASS_EXTERNAL_ACCESSIBLE="PASS|${TEST_ID}|External health endpoint accessible|curl https://rag.\${PUBLISH_DOMAIN}/health"
readonly FAIL_EXTERNAL_ISSUES="FAIL|${TEST_ID}|External health endpoint issues|curl https://rag.\${PUBLISH_DOMAIN}/health"
readonly FAIL_EXTERNAL_INACCESSIBLE="FAIL|${TEST_ID}|External health endpoint not accessible|curl https://rag.\${PUBLISH_DOMAIN}/health"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
URL="https://rag.$PUBLISH_DOMAIN/health"

# WHEN: Test external health endpoint
EXTERNAL_RESULT=$(clean_output "$(curl -s --connect-timeout 5 "$URL" 2>&1 || echo "FAILED")")

# THEN: Exit if endpoint not accessible
[[ "$EXTERNAL_RESULT" == "FAILED" ]] && { echo "$FAIL_EXTERNAL_INACCESSIBLE"; exit 0; }

# WHEN: Check if external health response indicates healthy service
EXTERNAL_OK=$(echo "$EXTERNAL_RESULT" | grep -q "ok\|healthy\|success\|200" && echo "true" || echo "false")

# THEN: Report external health status
if [[ "$EXTERNAL_OK" == "true" ]]; then
    echo "$PASS_EXTERNAL_ACCESSIBLE"
else
    echo "$FAIL_EXTERNAL_ISSUES: ${EXTERNAL_RESULT:0:50}"
fi
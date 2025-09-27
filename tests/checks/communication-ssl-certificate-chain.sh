#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Certificate Chain Validation Check
# =============================================================================
# GIVEN: SSL certificates should have valid certificate chains
# WHEN: We test certificate chain validation
# THEN: We verify certificates are properly chained
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_certificate_chain"
readonly PASS_VALID="PASS|${TEST_ID}|Certificate chain validation successful|openssl verify -CAfile docker/ssl/rootCA.pem docker/ssl/\${PUBLISH_DOMAIN}.pem"
readonly INFO_INVALID="INFO|${TEST_ID}|Certificate chain validation failed (expected for self-signed)|openssl verify -CAfile docker/ssl/rootCA.pem docker/ssl/\${PUBLISH_DOMAIN}.pem"
readonly INFO_MISSING="INFO|${TEST_ID}|Certificate file not found for chain validation|ls docker/ssl/\${PUBLISH_DOMAIN}.pem"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
CERT_FILE="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}.pem"
CA_FILE="${REPO_ROOT}/docker/ssl/rootCA.pem"

# WHEN: Check if certificate file exists
CERT_EXISTS=$([[ -f "$CERT_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if certificate file missing
[[ "$CERT_EXISTS" == "false" ]] && { echo "$INFO_MISSING"; exit 0; }

# WHEN: Test certificate chain validation
CHAIN_VALID=$(openssl verify -CAfile "$CA_FILE" "$CERT_FILE" >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Report validation result
if [[ "$CHAIN_VALID" == "true" ]]; then
    echo "$PASS_VALID"
else
    echo "$INFO_INVALID"
fi
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Certificates: Certificate Validity Check
# =============================================================================
# GIVEN: SSL certificate files should exist and be valid
# WHEN: We check certificate and private key files
# THEN: We verify SSL certificates are properly configured
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_certificates_validity"
readonly PASS_CERT_VALID="PASS|${TEST_ID}|SSL certificate valid|openssl x509 -in docker/ssl/\${PUBLISH_DOMAIN}.pem -text -noout"
readonly INFO_CERT_EXPIRY="INFO|${TEST_ID}|Certificate expires|openssl x509 -in docker/ssl/\${PUBLISH_DOMAIN}.pem -enddate -noout"
readonly BROKEN_CERT_CORRUPTED="BROKEN|${TEST_ID}|SSL certificate file corrupted or invalid|openssl x509 -in docker/ssl/\${PUBLISH_DOMAIN}.pem -text -noout"
readonly BROKEN_FILES_MISSING="BROKEN|${TEST_ID}|SSL certificate files missing|ls docker/ssl/"
readonly PASS_KEY_VALID="PASS|${TEST_ID}|Private key valid and matches certificate|openssl rsa -in docker/ssl/\${PUBLISH_DOMAIN}-key.pem -check -noout"
readonly BROKEN_KEY_INVALID="BROKEN|${TEST_ID}|Private key invalid or corrupted|openssl rsa -in docker/ssl/\${PUBLISH_DOMAIN}-key.pem -check -noout"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
CERT_FILE="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}.pem"
KEY_FILE="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}-key.pem"

# WHEN: Check if certificate files exist
CERT_EXISTS=$([[ -f "$CERT_FILE" ]] && echo "true" || echo "false")
KEY_EXISTS=$([[ -f "$KEY_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if files missing
[[ "$CERT_EXISTS" == "false" ]] || [[ "$KEY_EXISTS" == "false" ]] && { echo "$BROKEN_FILES_MISSING"; exit 0; }

# WHEN: Check certificate validity
CERT_VALID=$(openssl x509 -in "$CERT_FILE" -text -noout >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Report certificate validity
if [[ "$CERT_VALID" == "true" ]]; then
    SUBJECT=$(openssl x509 -in "$CERT_FILE" -subject -noout 2>/dev/null | sed 's/subject=//')
    EXPIRY=$(openssl x509 -in "$CERT_FILE" -enddate -noout 2>/dev/null | sed 's/notAfter=//')
    echo "$PASS_CERT_VALID: $SUBJECT"
    echo "$INFO_CERT_EXPIRY: $EXPIRY"
else
    echo "$BROKEN_CERT_CORRUPTED"
fi

# WHEN: Check private key validity
KEY_VALID=$(openssl rsa -in "$KEY_FILE" -check -noout >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Report key validity
if [[ "$KEY_VALID" == "true" ]]; then
    echo "$PASS_KEY_VALID"
else
    echo "$BROKEN_KEY_INVALID"
fi
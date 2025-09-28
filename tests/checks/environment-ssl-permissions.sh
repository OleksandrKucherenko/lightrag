#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Setup: Certificate Permissions Check
# =============================================================================
# GIVEN: SSL certificate files should have proper permissions
# WHEN: We check file permissions on certificates and private keys
# THEN: We verify security permissions are correctly set
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_certificate_permissions"
readonly PASS_SECURE_KEY="PASS|${TEST_ID}|Private key has secure permissions|stat docker/ssl/"
readonly FAIL_INSECURE_KEY="FAIL|${TEST_ID}|Private key has insecure permissions|chmod 600 docker/ssl/"
readonly INFO_CERT_PERMS="INFO|${TEST_ID}|Certificate file permissions|stat docker/ssl/"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
SSL_DIR="${REPO_ROOT}/docker/ssl"
CERT_FILE="${SSL_DIR}/${PUBLISH_DOMAIN}.pem"
KEY_FILE="${SSL_DIR}/${PUBLISH_DOMAIN}-key.pem"

# WHEN: Check certificate file permissions
if [[ -f "$CERT_FILE" ]]; then
    CERT_PERMS=$(stat -f%Mp%Lp "$CERT_FILE" 2>/dev/null || stat -c%a "$CERT_FILE" 2>/dev/null || echo "unknown")
    echo "$INFO_CERT_PERMS: $CERT_PERMS for certificate"
fi

# WHEN: Check private key permissions
if [[ -f "$KEY_FILE" ]]; then
    KEY_PERMS=$(stat -f%Mp%Lp "$KEY_FILE" 2>/dev/null || stat -c%a "$KEY_FILE" 2>/dev/null || echo "unknown")
    if [[ "$KEY_PERMS" == "600" || "$KEY_PERMS" == "400" ]]; then
        echo "$PASS_SECURE_KEY: $KEY_PERMS"
    else
        echo "$FAIL_INSECURE_KEY: $KEY_PERMS (should be 600 or 400)"
    fi
fi
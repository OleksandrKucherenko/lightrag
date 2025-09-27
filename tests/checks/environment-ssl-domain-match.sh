#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Setup: Certificate Domain Match Check
# =============================================================================
# GIVEN: SSL certificates should match the current domain
# WHEN: We check certificate subject and wildcard support
# THEN: We verify certificates are valid for the domain
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_certificate_domain"
readonly PASS_DOMAIN_MATCH="PASS|${TEST_ID}|Certificate matches current domain|openssl x509 -in docker/ssl/ -text -noout"
readonly FAIL_DOMAIN_MISMATCH="FAIL|${TEST_ID}|Certificate does not match current domain|openssl x509 -in docker/ssl/ -text -noout"
readonly PASS_WILDCARD="PASS|${TEST_ID}|Certificate includes wildcard for subdomains|openssl x509 -in docker/ssl/ -text -noout"
readonly INFO_NO_WILDCARD="INFO|${TEST_ID}|Certificate may not include wildcard for subdomains|openssl x509 -in docker/ssl/ -text -noout"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
CERT_FILE="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}.pem"

# WHEN: Check if certificate file exists
CERT_EXISTS=$([[ -f "$CERT_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if certificate doesn't exist
[[ "$CERT_EXISTS" == "false" ]] && { echo "INFO|${TEST_ID}|Certificate file not found for domain check|ls docker/ssl/${PUBLISH_DOMAIN}.pem"; exit 0; }

# WHEN: Check if certificate matches domain
DOMAIN_MATCH=$(openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep -q "$PUBLISH_DOMAIN" && echo "true" || echo "false")

# THEN: Report domain match
if [[ "$DOMAIN_MATCH" == "true" ]]; then
    echo "$PASS_DOMAIN_MATCH: $PUBLISH_DOMAIN"
else
    echo "$FAIL_DOMAIN_MISMATCH: $PUBLISH_DOMAIN"
fi

# WHEN: Check for wildcard support
WILDCARD_SUPPORT=$(openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep -q "\\*\.$PUBLISH_DOMAIN" && echo "true" || echo "false")

# THEN: Report wildcard support
if [[ "$WILDCARD_SUPPORT" == "true" ]]; then
    echo "$PASS_WILDCARD: *.$PUBLISH_DOMAIN"
else
    echo "$INFO_NO_WILDCARD"
fi
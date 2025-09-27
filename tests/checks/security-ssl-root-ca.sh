#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Certificates: Root CA Check
# =============================================================================
# GIVEN: Root CA certificate should be valid for certificate chain
# WHEN: We check root CA certificate file
# THEN: We verify root CA is properly configured
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_root_ca"
readonly PASS_CA_VALID="PASS|${TEST_ID}|Root CA certificate valid|openssl x509 -in docker/ssl/rootCA.pem -text -noout"
readonly BROKEN_CA_INVALID="BROKEN|${TEST_ID}|Root CA certificate invalid|openssl x509 -in docker/ssl/rootCA.pem -text -noout"
readonly INFO_CA_MISSING="INFO|${TEST_ID}|Root CA certificate not found|ls docker/ssl/rootCA.pem"

# GIVEN: Check prerequisites
ROOT_CA="${REPO_ROOT}/docker/ssl/rootCA.pem"

# WHEN: Check if root CA file exists
CA_EXISTS=$([[ -f "$ROOT_CA" ]] && echo "true" || echo "false")

# THEN: Exit if CA missing
[[ "$CA_EXISTS" == "false" ]] && { echo "$INFO_CA_MISSING"; exit 0; }

# WHEN: Check root CA validity
CA_VALID=$(openssl x509 -in "$ROOT_CA" -text -noout >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Report CA validity
if [[ "$CA_VALID" == "true" ]]; then
    CA_SUBJECT=$(openssl x509 -in "$ROOT_CA" -subject -noout 2>/dev/null | sed 's/subject=//')
    echo "$PASS_CA_VALID: $CA_SUBJECT"
else
    echo "$BROKEN_CA_INVALID"
fi
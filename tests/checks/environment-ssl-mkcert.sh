#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Setup: mkcert Tool Check
# =============================================================================
# GIVEN: mkcert tool should be available for SSL certificate generation
# WHEN: We check if mkcert is installed and configured
# THEN: We verify mkcert is ready for use
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_mkcert_available"
readonly PASS_AVAILABLE="PASS|${TEST_ID}|mkcert tool available|mkcert -version"
readonly FAIL_MISSING="FAIL|${TEST_ID}|mkcert tool not available|which mkcert"
readonly PASS_CA_INSTALLED="PASS|${TEST_ID}|mkcert CA root installed|mkcert -CAROOT"
readonly FAIL_CA_MISSING="FAIL|${TEST_ID}|mkcert CA root not installed|mkcert -install"
readonly FAIL_CA_NOTCONFIGURED="FAIL|${TEST_ID}|mkcert CA root not configured|mkcert -CAROOT"

# WHEN: Check if mkcert is available
MKCERT_AVAILABLE=$(command -v mkcert >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Exit if mkcert not available
[[ "$MKCERT_AVAILABLE" == "false" ]] && { echo "$FAIL_MISSING"; exit 0; }

# WHEN: Get mkcert version
MKCERT_VERSION=$(mkcert -version 2>/dev/null || echo "unknown")

# THEN: Report mkcert availability
echo "$PASS_AVAILABLE: $MKCERT_VERSION"

# WHEN: Check if mkcert CA is configured
CA_CONFIGURED=$(mkcert -CAROOT >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Exit if CA not configured
[[ "$CA_CONFIGURED" == "false" ]] && { echo "$FAIL_CA_NOTCONFIGURED"; exit 0; }

# WHEN: Check if CA root file exists
CA_ROOT=$(mkcert -CAROOT 2>/dev/null)
CA_FILE_EXISTS=$([[ -f "$CA_ROOT/rootCA.pem" ]] && echo "true" || echo "false")

# THEN: Report CA installation status
if [[ "$CA_FILE_EXISTS" == "true" ]]; then
    echo "$PASS_CA_INSTALLED: $CA_ROOT"
else
    echo "$FAIL_CA_MISSING"
fi
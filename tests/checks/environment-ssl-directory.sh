#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Setup: Directory Structure Check
# =============================================================================
# GIVEN: SSL directory should exist with proper structure
# WHEN: We check SSL directory and required certificate files
# THEN: We verify SSL environment is properly set up
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_directory_structure"
readonly PASS_DIR_EXISTS="PASS|${TEST_ID}|SSL directory exists|ls docker/ssl/"
readonly BROKEN_DIR_MISSING="BROKEN|${TEST_ID}|SSL directory not found|ls docker/ssl/"
readonly PASS_CERT_EXISTS="PASS|${TEST_ID}|Certificate file exists|ls docker/ssl/"
readonly FAIL_CERT_MISSING="FAIL|${TEST_ID}|Certificate file missing|ls docker/ssl/"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
SSL_DIR="${REPO_ROOT}/docker/ssl"

# WHEN: Check if SSL directory exists
DIR_EXISTS=$([[ -d "$SSL_DIR" ]] && echo "true" || echo "false")

# THEN: Exit if directory missing
[[ "$DIR_EXISTS" == "false" ]] && { echo "$BROKEN_DIR_MISSING"; exit 0; }

# THEN: Report directory exists
echo "$PASS_DIR_EXISTS: $SSL_DIR"

# WHEN: Check for required certificate files
REQUIRED_FILES=("${PUBLISH_DOMAIN}.pem" "${PUBLISH_DOMAIN}-key.pem")

for file in "${REQUIRED_FILES[@]}"; do
    FILE_EXISTS=$([[ -f "${SSL_DIR}/${file}" ]] && echo "true" || echo "false")
    if [[ "$FILE_EXISTS" == "true" ]]; then
        FILE_SIZE=$(stat -f%z "${SSL_DIR}/${file}" 2>/dev/null || stat -c%s "${SSL_DIR}/${file}" 2>/dev/null || echo "unknown")
        echo "$PASS_CERT_EXISTS: $file ($FILE_SIZE bytes)"
    else
        echo "$FAIL_CERT_MISSING: $file"
    fi
done
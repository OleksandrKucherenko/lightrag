#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Subdomain Connectivity - LightRAG Check
# =============================================================================
# GIVEN: WSL2 should connect to subdomains after DNS resolution
# WHEN: We test HTTPS connectivity to rag subdomain
# THEN: We verify the subdomain is accessible
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_subdomain_rag_connectivity"
readonly PASS_MSG="PASS|${TEST_ID}|Subdomain accessible from WSL2: rag.${PUBLISH_DOMAIN:-dev.localhost}|curl -I https://rag.${PUBLISH_DOMAIN:-dev.localhost}"
readonly FAIL_MSG="FAIL|${TEST_ID}|Subdomain not accessible from WSL2: rag.${PUBLISH_DOMAIN:-dev.localhost}|curl -I https://rag.${PUBLISH_DOMAIN:-dev.localhost}"

# GIVEN: Set domain
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
FULL_DOMAIN="rag.${DOMAIN}"

# WHEN: Test connectivity
CONNECTS=$(curl -I -s -k --connect-timeout 3 "https://$FULL_DOMAIN" >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Qualify result
[[ "$CONNECTS" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
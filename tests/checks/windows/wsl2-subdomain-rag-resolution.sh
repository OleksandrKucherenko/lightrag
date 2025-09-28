#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Subdomain DNS Resolution - LightRAG Check
# =============================================================================
# GIVEN: WSL2 should resolve subdomains configured in hosts file
# WHEN: We test DNS resolution for rag subdomain
# THEN: We verify the subdomain resolves correctly
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="wsl2_subdomain_rag_resolution"
readonly PASS_MSG="PASS|${TEST_ID}|Subdomain resolves from WSL2: rag.${PUBLISH_DOMAIN:-dev.localhost}|nslookup rag.${PUBLISH_DOMAIN:-dev.localhost}"
readonly FAIL_MSG="FAIL|${TEST_ID}|Subdomain resolution failed from WSL2: rag.${PUBLISH_DOMAIN:-dev.localhost}|nslookup rag.${PUBLISH_DOMAIN:-dev.localhost}"

# GIVEN: Set domain
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
FULL_DOMAIN="rag.${DOMAIN}"

# WHEN: Test DNS resolution
RESOLVES=$(nslookup "$FULL_DOMAIN" >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Qualify result
[[ "$RESOLVES" == "true" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
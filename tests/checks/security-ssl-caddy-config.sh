#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Certificates: Caddy Configuration Check
# =============================================================================
# GIVEN: Caddy should be configured to use SSL certificates
# WHEN: We check Caddyfile for SSL configuration
# THEN: We verify Caddy is properly configured for HTTPS
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="ssl_caddy_config"
readonly PASS_SSL_CONFIG="PASS|${TEST_ID}|Caddyfile contains SSL certificate configuration|grep 'tls.*ssl.*pem' docker/etc/caddy/Caddyfile"
readonly DISABLED_SSL_MISSING="DISABLED|${TEST_ID}|Caddyfile missing SSL certificate configuration|grep 'tls.*ssl.*pem' docker/etc/caddy/Caddyfile"
readonly PASS_DOMAIN_CONFIG="PASS|${TEST_ID}|Caddyfile configured for domain|grep \${PUBLISH_DOMAIN} docker/etc/caddy/Caddyfile"
readonly DISABLED_DOMAIN_MISSING="DISABLED|${TEST_ID}|Caddyfile not configured for domain|grep \${PUBLISH_DOMAIN} docker/etc/caddy/Caddyfile"
readonly BROKEN_CADDYFILE_MISSING="BROKEN|${TEST_ID}|Caddyfile not found|ls docker/etc/caddy/Caddyfile"

# GIVEN: Check prerequisites
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
CADDYFILE="${REPO_ROOT}/docker/etc/caddy/Caddyfile"

# WHEN: Check if Caddyfile exists
CADDYFILE_EXISTS=$([[ -f "$CADDYFILE" ]] && echo "true" || echo "false")

# THEN: Exit if Caddyfile missing
[[ "$CADDYFILE_EXISTS" == "false" ]] && { echo "$BROKEN_CADDYFILE_MISSING"; exit 0; }

# WHEN: Check for SSL certificate configuration in Caddyfile
SSL_CONFIGURED=$(grep -q "tls.*ssl.*pem" "$CADDYFILE" 2>/dev/null && echo "true" || echo "false")

# THEN: Report SSL configuration
if [[ "$SSL_CONFIGURED" == "true" ]]; then
    echo "$PASS_SSL_CONFIG"
else
    echo "$DISABLED_SSL_MISSING"
fi

# WHEN: Check if domain is configured in Caddyfile
DOMAIN_CONFIGURED=$(grep -q "$PUBLISH_DOMAIN" "$CADDYFILE" 2>/dev/null && echo "true" || echo "false")

# THEN: Report domain configuration
if [[ "$DOMAIN_CONFIGURED" == "true" ]]; then
    echo "$PASS_DOMAIN_CONFIG: $PUBLISH_DOMAIN"
else
    echo "$DISABLED_DOMAIN_MISSING: $PUBLISH_DOMAIN"
fi
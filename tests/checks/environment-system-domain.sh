#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Domain Configuration Check
# =============================================================================
# 
# GIVEN: A configurable domain setup via PUBLISH_DOMAIN environment variable
# WHEN: We test domain configuration and resolution
# THEN: We verify domain is properly configured and accessible
# =============================================================================

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Docker and Docker Compose are assumed to be available

# WHEN: We test Docker Compose configuration uses the domain variable
if compose_config=$(docker compose config 2>&1); then
    if echo "$compose_config" | grep -q "caddy:.*https://.*\\.$PUBLISH_DOMAIN"; then
        echo "PASS|domain_configuration|Docker Compose uses PUBLISH_DOMAIN correctly|docker compose config | grep caddy:"
    else
        echo "FAIL|domain_configuration|Docker Compose not using PUBLISH_DOMAIN variable|docker compose config | grep caddy:"
    fi
else
    echo "BROKEN|domain_configuration|Cannot get Docker Compose config: ${compose_config:0:50}|docker compose config"
fi

# WHEN: We test custom domain substitution
if custom_config=$(PUBLISH_DOMAIN=test.local docker compose config 2>&1); then
    if echo "$custom_config" | grep -q "caddy:.*https://.*\\.test\\.local"; then
        echo "PASS|domain_configuration|Custom domain substitution working|PUBLISH_DOMAIN=test.local docker compose config"
    else
        echo "FAIL|domain_configuration|Custom domain substitution not working|PUBLISH_DOMAIN=test.local docker compose config"
    fi
else
    echo "BROKEN|domain_configuration|Cannot test custom domain: ${custom_config:0:50}|PUBLISH_DOMAIN=test.local docker compose config"
fi

# WHEN: We test environment variable is properly set
if [[ -n "$PUBLISH_DOMAIN" ]]; then
    echo "INFO|domain_configuration|PUBLISH_DOMAIN set to: $PUBLISH_DOMAIN|echo \$PUBLISH_DOMAIN"
else
    echo "BROKEN|domain_configuration|PUBLISH_DOMAIN environment variable not set|echo \$PUBLISH_DOMAIN"
fi

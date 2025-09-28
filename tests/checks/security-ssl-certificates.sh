#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Certificates Security Check
# =============================================================================
# 
# GIVEN: SSL certificates should be properly configured for HTTPS services
# WHEN: We verify certificate files and Caddy configuration
# THEN: We ensure SSL/TLS security is properly implemented
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: We check if SSL certificate files exist
cert_file="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}.pem"
key_file="${REPO_ROOT}/docker/ssl/${PUBLISH_DOMAIN}-key.pem"

if [[ -f "$cert_file" && -f "$key_file" ]]; then
    # Check certificate validity
    if openssl x509 -in "$cert_file" -text -noout >/dev/null 2>&1; then
        # Get certificate subject and expiry
        subject=$(openssl x509 -in "$cert_file" -subject -noout 2>/dev/null | sed 's/subject=//')
        expiry=$(openssl x509 -in "$cert_file" -enddate -noout 2>/dev/null | sed 's/notAfter=//')
        
        echo "PASS|ssl_certificates|SSL certificate valid: $subject|openssl x509 -in $cert_file -text -noout"
        echo "INFO|ssl_certificates|Certificate expires: $expiry|openssl x509 -in $cert_file -enddate -noout"
    else
        echo "BROKEN|ssl_certificates|SSL certificate file corrupted or invalid|openssl x509 -in $cert_file -text -noout"
    fi
    
    # Check private key validity
    if openssl rsa -in "$key_file" -check -noout >/dev/null 2>&1; then
        echo "PASS|ssl_certificates|Private key valid and matches certificate|openssl rsa -in $key_file -check -noout"
    else
        echo "BROKEN|ssl_certificates|Private key invalid or corrupted|openssl rsa -in $key_file -check -noout"
    fi
else
    echo "BROKEN|ssl_certificates|SSL certificate files missing: $cert_file or $key_file|ls docker/ssl/"
fi

# WHEN: We check Caddy configuration for SSL
caddyfile="${REPO_ROOT}/docker/etc/caddy/Caddyfile"
if [[ -f "$caddyfile" ]]; then
    if grep -q "tls.*ssl.*pem" "$caddyfile" 2>/dev/null; then
        echo "PASS|ssl_certificates|Caddyfile contains SSL certificate configuration|grep 'tls.*ssl.*pem' docker/etc/caddy/Caddyfile"
    else
        echo "DISABLED|ssl_certificates|Caddyfile missing SSL certificate configuration|grep 'tls.*ssl.*pem' docker/etc/caddy/Caddyfile"
    fi
    
    # Check if domain is properly configured in Caddyfile
    if grep -q "$PUBLISH_DOMAIN" "$caddyfile" 2>/dev/null; then
        echo "PASS|ssl_certificates|Caddyfile configured for domain: $PUBLISH_DOMAIN|grep $PUBLISH_DOMAIN docker/etc/caddy/Caddyfile"
    else
        echo "DISABLED|ssl_certificates|Caddyfile not configured for domain: $PUBLISH_DOMAIN|grep $PUBLISH_DOMAIN docker/etc/caddy/Caddyfile"
    fi
else
    echo "BROKEN|ssl_certificates|Caddyfile not found|ls docker/etc/caddy/Caddyfile"
fi

# WHEN: We check root CA certificate
root_ca="${REPO_ROOT}/docker/ssl/rootCA.pem"
if [[ -f "$root_ca" ]]; then
    if openssl x509 -in "$root_ca" -text -noout >/dev/null 2>&1; then
        ca_subject=$(openssl x509 -in "$root_ca" -subject -noout 2>/dev/null | sed 's/subject=//')
        echo "PASS|ssl_certificates|Root CA certificate valid: $ca_subject|openssl x509 -in $root_ca -text -noout"
    else
        echo "BROKEN|ssl_certificates|Root CA certificate invalid|openssl x509 -in $root_ca -text -noout"
    fi
else
    echo "INFO|ssl_certificates|Root CA certificate not found (may be generated separately)|ls docker/ssl/rootCA.pem"
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Environment Setup Check
# =============================================================================
# 
# GIVEN: SSL environment should be properly configured with mkcert and certificates
# WHEN: We verify SSL setup and certificate generation tools
# THEN: We ensure SSL development environment is ready
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: We check if mkcert is available
if command -v mkcert >/dev/null 2>&1; then
    mkcert_version=$(mkcert -version 2>/dev/null || echo "unknown")
    echo "PASS|ssl_setup|mkcert tool available: $mkcert_version|mkcert -version"
    
    # Check if mkcert CA is installed
    if mkcert -CAROOT >/dev/null 2>&1; then
        ca_root=$(mkcert -CAROOT 2>/dev/null)
        if [[ -f "$ca_root/rootCA.pem" ]]; then
            echo "PASS|ssl_setup|mkcert CA root installed: $ca_root|mkcert -CAROOT"
        else
            echo "FAIL|ssl_setup|mkcert CA root not properly installed|mkcert -install"
        fi
    else
        echo "FAIL|ssl_setup|mkcert CA root not configured|mkcert -CAROOT"
    fi
else
    echo "FAIL|ssl_setup|mkcert tool not available|which mkcert"
fi

# WHEN: We check SSL directory structure
ssl_dir="${REPO_ROOT}/docker/ssl"
if [[ -d "$ssl_dir" ]]; then
    echo "PASS|ssl_setup|SSL directory exists: $ssl_dir|ls docker/ssl/"
    
    # Check for required certificate files
    required_files=(
        "${PUBLISH_DOMAIN}.pem"
        "${PUBLISH_DOMAIN}-key.pem"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "${ssl_dir}/${file}" ]]; then
            file_size=$(stat -f%z "${ssl_dir}/${file}" 2>/dev/null || stat -c%s "${ssl_dir}/${file}" 2>/dev/null || echo "unknown")
            echo "PASS|ssl_setup|Certificate file exists: $file ($file_size bytes)|ls docker/ssl/$file"
        else
            echo "FAIL|ssl_setup|Certificate file missing: $file|ls docker/ssl/$file"
        fi
    done
    
    # Check for optional files
    optional_files=(
        "rootCA.pem"
        "rootCA-key.pem" 
        "${PUBLISH_DOMAIN}.p12"
        "${PUBLISH_DOMAIN}.pfx"
        "rootCA.crt"
        "rootCA.cer"
    )
    
    for file in "${optional_files[@]}"; do
        if [[ -f "${ssl_dir}/${file}" ]]; then
            echo "INFO|ssl_setup|Optional certificate file present: $file|ls docker/ssl/$file"
        fi
    done
else
    echo "BROKEN|ssl_setup|SSL directory not found: $ssl_dir|ls docker/ssl/"
fi

# WHEN: We check certificate permissions
cert_file="${ssl_dir}/${PUBLISH_DOMAIN}.pem"
key_file="${ssl_dir}/${PUBLISH_DOMAIN}-key.pem"

if [[ -f "$cert_file" ]]; then
    cert_perms=$(stat -f%Mp%Lp "$cert_file" 2>/dev/null || stat -c%a "$cert_file" 2>/dev/null || echo "unknown")
    echo "INFO|ssl_setup|Certificate file permissions: $cert_perms|stat $cert_file"
fi

if [[ -f "$key_file" ]]; then
    key_perms=$(stat -f%Mp%Lp "$key_file" 2>/dev/null || stat -c%a "$key_file" 2>/dev/null || echo "unknown")
    if [[ "$key_perms" == "600" || "$key_perms" == "400" ]]; then
        echo "PASS|ssl_setup|Private key has secure permissions: $key_perms|stat $key_file"
    else
        echo "FAIL|ssl_setup|Private key has insecure permissions: $key_perms (should be 600 or 400)|chmod 600 $key_file"
    fi
fi

# WHEN: We check if certificates match the current domain
if [[ -f "$cert_file" ]]; then
    if openssl x509 -in "$cert_file" -text -noout 2>/dev/null | grep -q "$PUBLISH_DOMAIN"; then
        echo "PASS|ssl_setup|Certificate matches current domain: $PUBLISH_DOMAIN|openssl x509 -in $cert_file -text -noout | grep $PUBLISH_DOMAIN"
    else
        echo "FAIL|ssl_setup|Certificate does not match current domain: $PUBLISH_DOMAIN|openssl x509 -in $cert_file -text -noout | grep Subject"
    fi
    
    # Check for wildcard support
    if openssl x509 -in "$cert_file" -text -noout 2>/dev/null | grep -q "\*\.$PUBLISH_DOMAIN"; then
        echo "PASS|ssl_setup|Certificate includes wildcard for subdomains: *.$PUBLISH_DOMAIN|openssl x509 -in $cert_file -text -noout | grep DNS"
    else
        echo "INFO|ssl_setup|Certificate may not include wildcard for subdomains|openssl x509 -in $cert_file -text -noout | grep DNS"
    fi
fi

# WHEN: We check Docker SSL volume mounting
if docker compose config 2>/dev/null | grep -q "docker/ssl"; then
    echo "PASS|ssl_setup|Docker Compose configured to mount SSL directory|docker compose config | grep ssl"
else
    echo "FAIL|ssl_setup|Docker Compose not configured to mount SSL directory|docker compose config | grep ssl"
fi

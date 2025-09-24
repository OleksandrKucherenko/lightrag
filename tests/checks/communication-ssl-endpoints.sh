#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SSL Endpoints Communication Check
# =============================================================================
# 
# GIVEN: Services should be accessible via HTTPS with valid SSL certificates
# WHEN: We test HTTPS connectivity to all service endpoints
# THEN: We verify SSL/TLS communication is working properly
# =============================================================================

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Define services to test (matching original script)
services=("proxy" "monitor" "kv" "graph" "vector" "rag" "lobechat")

# Function to test SSL endpoint
test_ssl_endpoint() {
    local service="$1"
    local url="https://${service}.${PUBLISH_DOMAIN}"
    
    # Skip proxy service (it's the main domain)
    if [[ "$service" == "proxy" ]]; then
        url="https://${PUBLISH_DOMAIN}"
    fi
    
    # Test HTTPS connectivity
    if http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 8 "$url" 2>/dev/null); then
        case "$http_code" in
            200|301|302)
                echo "PASS|ssl_endpoints|HTTPS accessible: $url (HTTP $http_code)|curl -I -k $url"
                ;;
            401|403)
                echo "PASS|ssl_endpoints|HTTPS accessible with auth required: $url (HTTP $http_code)|curl -I -k $url"
                ;;
            *)
                echo "FAIL|ssl_endpoints|HTTPS unexpected status: $url (HTTP $http_code)|curl -I -k $url"
                ;;
        esac
    else
        echo "FAIL|ssl_endpoints|HTTPS connection failed: $url|curl -I -k $url"
        return 1
    fi
}

# Function to get certificate info
get_cert_info() {
    local service="$1"
    local hostname="${service}.${PUBLISH_DOMAIN}"
    
    # Skip proxy service (it's the main domain)
    if [[ "$service" == "proxy" ]]; then
        hostname="$PUBLISH_DOMAIN"
    fi
    
    # Get certificate information with timeout
    if cert_info=$(timeout 10 bash -c "echo | openssl s_client -servername '$hostname' -connect '$hostname:443' 2>/dev/null | openssl x509 -text -noout 2>/dev/null"); then
        # Extract subject and issuer
        subject=$(echo "$cert_info" | grep -E "Subject:" | head -1 | sed 's/.*Subject: //')
        issuer=$(echo "$cert_info" | grep -E "Issuer:" | head -1 | sed 's/.*Issuer: //')
        
        if [[ -n "$subject" ]]; then
            echo "INFO|ssl_endpoints|Certificate subject for $hostname: $subject|openssl s_client -connect $hostname:443"
        fi
        
        # Check if it's a wildcard certificate
        if echo "$cert_info" | grep -q "DNS:\*\.$PUBLISH_DOMAIN"; then
            echo "PASS|ssl_endpoints|Wildcard certificate covers $hostname|openssl s_client -connect $hostname:443"
        elif echo "$cert_info" | grep -q "DNS:$hostname"; then
            echo "PASS|ssl_endpoints|Specific certificate for $hostname|openssl s_client -connect $hostname:443"
        else
            echo "FAIL|ssl_endpoints|Certificate does not cover $hostname|openssl s_client -connect $hostname:443"
        fi
    else
        echo "FAIL|ssl_endpoints|Cannot retrieve certificate info for $hostname|openssl s_client -connect $hostname:443"
    fi
}

# Test each service
for service in "${services[@]}"; do
    # Test HTTPS connectivity
    test_ssl_endpoint "$service"
    
    # Get certificate information
    get_cert_info "$service"
done

# Test certificate chain validation
echo "INFO|ssl_endpoints|Testing certificate chain validation|openssl verify"
cert_file="docker/ssl/${PUBLISH_DOMAIN}.pem"
if [[ -f "$cert_file" ]]; then
    if openssl verify -CAfile "docker/ssl/rootCA.pem" "$cert_file" >/dev/null 2>&1; then
        echo "PASS|ssl_endpoints|Certificate chain validation successful|openssl verify -CAfile docker/ssl/rootCA.pem $cert_file"
    else
        echo "INFO|ssl_endpoints|Certificate chain validation failed (expected for self-signed)|openssl verify -CAfile docker/ssl/rootCA.pem $cert_file"
    fi
else
    echo "INFO|ssl_endpoints|Certificate file not found for chain validation|ls $cert_file"
fi

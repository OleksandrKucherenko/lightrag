#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Caddy TLS Labels Security Check
# =============================================================================
# 
# GIVEN: Docker Compose services should have proper Caddy TLS configuration labels
# WHEN: We verify docker-compose.yaml for Caddy proxy labels and TLS settings
# THEN: We ensure all services are properly configured for SSL/TLS through Caddy
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Docker Compose file location
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "BROKEN|caddy_tls_labels|Docker Compose file not found: $COMPOSE_FILE|ls docker-compose.yaml"
    exit 1
fi

# WHEN: We check if docker-compose.yaml contains Caddy proxy configuration
if grep -q "caddy" "$COMPOSE_FILE" 2>/dev/null; then
    echo "PASS|caddy_tls_labels|Docker Compose contains Caddy configuration|grep caddy docker-compose.yaml"
else
    echo "FAIL|caddy_tls_labels|Docker Compose missing Caddy configuration|grep caddy docker-compose.yaml"
fi

# Function to check service labels for Caddy TLS configuration (concise version)
check_service_tls_labels() {
    local service_name="$1"
    local expected_subdomain="$2"
    
    # Extract service section from docker-compose.yaml
    if ! service_section=$(yq eval ".services.${service_name}" "$COMPOSE_FILE" 2>/dev/null); then
        echo "FAIL|caddy_tls_labels|Service $service_name: not found in docker-compose.yaml|yq eval '.services.$service_name' docker-compose.yaml"
        return 1
    fi
    
    if [[ "$service_section" == "null" ]]; then
        echo "FAIL|caddy_tls_labels|Service $service_name: not defined|yq eval '.services.$service_name' docker-compose.yaml"
        return 1
    fi
    
    # Check all required Caddy configuration in one go
    local issues=()
    local caddy_url tls_config reverse_proxy
    
    # Check main caddy label (URL configuration)
    caddy_url=$(yq eval ".services.${service_name}.labels.caddy" "$COMPOSE_FILE" 2>/dev/null)
    if [[ "$caddy_url" == "null" ]]; then
        issues+=("missing URL")
    else
        # Verify the URL matches expected pattern
        if [[ "$service_name" == "proxy" ]]; then
            expected_url="https://\${PUBLISH_DOMAIN}"
        else
            expected_url="https://${expected_subdomain}.\${PUBLISH_DOMAIN}"
        fi
        
        if [[ "$caddy_url" != "$expected_url" ]]; then
            issues+=("incorrect URL: $caddy_url")
        fi
    fi
    
    # Check for caddy.tls label
    tls_config=$(yq eval ".services.${service_name}.labels.\"caddy.tls\"" "$COMPOSE_FILE" 2>/dev/null)
    if [[ "$tls_config" == "null" ]]; then
        issues+=("missing TLS config")
    else
        # Check if TLS config has correct format and domain
        if [[ "$tls_config" != *"/ssl/"* ]] || [[ "$tls_config" != *".pem"* ]] || [[ "$tls_config" != *"-key.pem"* ]]; then
            issues+=("invalid TLS format")
        elif [[ "$tls_config" != *"$DOMAIN"* ]]; then
            issues+=("TLS domain mismatch")
        fi
    fi
    
    # Check for caddy.reverse_proxy label (for non-proxy services)
    if [[ "$service_name" != "proxy" ]]; then
        reverse_proxy=$(yq eval ".services.${service_name}.labels.\"caddy.reverse_proxy\"" "$COMPOSE_FILE" 2>/dev/null)
        if [[ "$reverse_proxy" == "null" ]]; then
            issues+=("missing reverse proxy")
        elif [[ "$reverse_proxy" != *"{{upstreams"* ]]; then
            issues+=("non-standard proxy config")
        fi
    fi
    
    # Generate single concise result
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "PASS|caddy_tls_labels|Service $service_name: Caddy TLS configuration complete|yq eval '.services.$service_name.labels' docker-compose.yaml"
    else
        local issue_list
        issue_list=$(IFS=', '; echo "${issues[*]}")
        echo "FAIL|caddy_tls_labels|Service $service_name: $issue_list|yq eval '.services.$service_name.labels' docker-compose.yaml"
    fi
}

# Check if yq is available for YAML parsing
if ! command -v yq >/dev/null 2>&1; then
    echo "BROKEN|caddy_tls_labels|yq tool not available for YAML parsing|which yq"
    
    # Fallback to grep-based checking
    echo "INFO|caddy_tls_labels|Falling back to grep-based label checking|grep -A 10 'labels:' docker-compose.yaml"
    
    # Check for basic Caddy labels presence
    if grep -q "caddy\." "$COMPOSE_FILE" 2>/dev/null; then
        echo "PASS|caddy_tls_labels|Docker Compose contains Caddy labels (basic check)|grep 'caddy\.' docker-compose.yaml"
    else
        echo "FAIL|caddy_tls_labels|Docker Compose missing Caddy labels|grep 'caddy\.' docker-compose.yaml"
    fi
    
    # Check for TLS configuration
    if grep -q "caddy\.tls" "$COMPOSE_FILE" 2>/dev/null; then
        echo "PASS|caddy_tls_labels|Docker Compose contains Caddy TLS labels (basic check)|grep 'caddy\.tls' docker-compose.yaml"
    else
        echo "FAIL|caddy_tls_labels|Docker Compose missing Caddy TLS labels|grep 'caddy\.tls' docker-compose.yaml"
    fi
    
    exit 0
fi

# Define services and their expected subdomains (based on actual docker-compose.yaml)
declare -A service_subdomains=(
    ["proxy"]=""          # Main domain, not a subdomain
    ["rag"]="rag"
    ["lobechat"]="lobechat"
    ["vectors"]="vector"
    ["monitor"]="monitor"
    ["kv"]="kv"
    ["graph-ui"]="graph"  # Note: service name is graph-ui but subdomain is graph
)

# WHEN: We check each service for proper Caddy TLS labels
for service in "${!service_subdomains[@]}"; do
    subdomain="${service_subdomains[$service]}"
    
    # Special handling for proxy service (main domain)
    if [[ "$service" == "proxy" ]]; then
        check_service_tls_labels "$service" ""
    else
        check_service_tls_labels "$service" "$subdomain"
    fi
done

# WHEN: We check global Caddy proxy service configuration (concise)
check_caddy_global_config() {
    local issues=()
    
    # Check if Caddy proxy service exists
    if ! caddy_service=$(yq eval ".services.proxy" "$COMPOSE_FILE" 2>/dev/null) || [[ "$caddy_service" == "null" ]]; then
        echo "FAIL|caddy_tls_labels|Caddy proxy service: not found in docker-compose.yaml|yq eval '.services.proxy' docker-compose.yaml"
        return 1
    fi
    
    # Check SSL certificate volume mount
    if ! ssl_volume=$(yq eval ".services.proxy.volumes[] | select(. | contains(\"certificates\"))" "$COMPOSE_FILE" 2>/dev/null) || [[ -z "$ssl_volume" ]]; then
        issues+=("missing SSL volume")
    elif [[ "$ssl_volume" != *":/ssl"* ]]; then
        issues+=("SSL volume wrong path")
    elif [[ "$ssl_volume" != *":ro" ]]; then
        issues+=("SSL volume not read-only")
    fi
    
    # Check network configuration
    if ! caddy_networks=$(yq eval ".services.proxy.networks" "$COMPOSE_FILE" 2>/dev/null) || [[ "$caddy_networks" == "null" ]]; then
        issues+=("missing networks")
    fi
    
    # Check frontend network exists
    if ! frontend_network=$(yq eval ".networks.frontend" "$COMPOSE_FILE" 2>/dev/null) || [[ "$frontend_network" == "null" ]]; then
        issues+=("no frontend network")
    fi
    
    # Check port configuration
    if ! caddy_ports=$(yq eval ".services.proxy.ports" "$COMPOSE_FILE" 2>/dev/null) || [[ "$caddy_ports" == "null" ]]; then
        issues+=("missing ports")
    else
        if ! echo "$caddy_ports" | grep -q "443" 2>/dev/null; then
            issues+=("no HTTPS port 443")
        fi
        if ! echo "$caddy_ports" | grep -q "80" 2>/dev/null; then
            issues+=("no HTTP port 80")
        fi
    fi
    
    # Generate single result
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "PASS|caddy_tls_labels|Caddy proxy service: global configuration complete|yq eval '.services.proxy' docker-compose.yaml"
    else
        local issue_list
        issue_list=$(IFS=', '; echo "${issues[*]}")
        echo "FAIL|caddy_tls_labels|Caddy proxy service: $issue_list|yq eval '.services.proxy' docker-compose.yaml"
    fi
}

check_caddy_global_config

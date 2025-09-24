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

# Function to check service labels for Caddy TLS configuration
check_service_tls_labels() {
    local service_name="$1"
    local expected_subdomain="$2"
    
    # Extract service section from docker-compose.yaml
    if ! service_section=$(yq eval ".services.${service_name}" "$COMPOSE_FILE" 2>/dev/null); then
        echo "FAIL|caddy_tls_labels|Service not found in docker-compose.yaml: $service_name|yq eval '.services.$service_name' docker-compose.yaml"
        return 1
    fi
    
    if [[ "$service_section" == "null" ]]; then
        echo "FAIL|caddy_tls_labels|Service not defined: $service_name|yq eval '.services.$service_name' docker-compose.yaml"
        return 1
    fi
    
    # Check for Caddy labels
    local has_caddy_labels=false
    local has_tls_config=false
    local caddy_url=""
    local tls_config=""
    
    # Check for main caddy label (URL configuration)
    if caddy_url=$(yq eval ".services.${service_name}.labels.caddy" "$COMPOSE_FILE" 2>/dev/null) && [[ "$caddy_url" != "null" ]]; then
        has_caddy_labels=true
        
        # Verify the URL matches expected pattern
        if [[ "$service_name" == "proxy" ]]; then
            expected_url="https://\${PUBLISH_DOMAIN}"
        else
            expected_url="https://${expected_subdomain}.\${PUBLISH_DOMAIN}"
        fi
        
        if [[ "$caddy_url" == "$expected_url" ]]; then
            echo "PASS|caddy_tls_labels|Service $service_name has correct Caddy URL: $caddy_url|yq eval '.services.$service_name.labels.caddy' docker-compose.yaml"
        else
            echo "FAIL|caddy_tls_labels|Service $service_name has incorrect Caddy URL: $caddy_url (expected: $expected_url)|yq eval '.services.$service_name.labels.caddy' docker-compose.yaml"
        fi
    fi
    
    # Check for caddy.tls label
    if tls_config=$(yq eval ".services.${service_name}.labels.\"caddy.tls\"" "$COMPOSE_FILE" 2>/dev/null) && [[ "$tls_config" != "null" ]]; then
        has_tls_config=true
        echo "PASS|caddy_tls_labels|Service $service_name has TLS configuration: $tls_config|yq eval '.services.$service_name.labels.\"caddy.tls\"' docker-compose.yaml"
        
        # Check if TLS config points to SSL files with correct format
        if [[ "$tls_config" == *"/ssl/"* ]] && [[ "$tls_config" == *".pem"* ]] && [[ "$tls_config" == *"-key.pem"* ]]; then
            echo "PASS|caddy_tls_labels|Service $service_name TLS config references correct SSL certificate files|yq eval '.services.$service_name.labels.\"caddy.tls\"' docker-compose.yaml"
        else
            echo "FAIL|caddy_tls_labels|Service $service_name TLS config incorrect format: $tls_config|yq eval '.services.$service_name.labels.\"caddy.tls\"' docker-compose.yaml"
        fi
        
        # Check if TLS config matches domain
        if [[ "$tls_config" == *"$DOMAIN"* ]]; then
            echo "PASS|caddy_tls_labels|Service $service_name TLS config matches domain: $DOMAIN|yq eval '.services.$service_name.labels.\"caddy.tls\"' docker-compose.yaml"
        else
            echo "INFO|caddy_tls_labels|Service $service_name TLS config may use different domain certificate|yq eval '.services.$service_name.labels.\"caddy.tls\"' docker-compose.yaml"
        fi
    fi
    
    # Check for caddy.reverse_proxy label (for services that need it)
    if [[ "$service_name" != "proxy" ]]; then
        if reverse_proxy=$(yq eval ".services.${service_name}.labels.\"caddy.reverse_proxy\"" "$COMPOSE_FILE" 2>/dev/null) && [[ "$reverse_proxy" != "null" ]]; then
            echo "PASS|caddy_tls_labels|Service $service_name has reverse proxy configuration: $reverse_proxy|yq eval '.services.$service_name.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
            
            # Check if reverse proxy uses upstreams pattern
            if [[ "$reverse_proxy" == *"{{upstreams"* ]]; then
                echo "PASS|caddy_tls_labels|Service $service_name uses Caddy upstreams pattern|yq eval '.services.$service_name.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
            else
                echo "INFO|caddy_tls_labels|Service $service_name uses custom reverse proxy configuration|yq eval '.services.$service_name.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
            fi
        else
            echo "FAIL|caddy_tls_labels|Service $service_name missing reverse proxy configuration|yq eval '.services.$service_name.labels.\"caddy.reverse_proxy\"' docker-compose.yaml"
        fi
    fi
    
    # Overall assessment for this service
    if [[ "$has_caddy_labels" == true ]]; then
        if [[ "$has_tls_config" == true ]]; then
            echo "PASS|caddy_tls_labels|Service $service_name properly configured for Caddy TLS|yq eval '.services.$service_name.labels' docker-compose.yaml"
        else
            echo "FAIL|caddy_tls_labels|Service $service_name missing TLS configuration in Caddy labels|yq eval '.services.$service_name.labels' docker-compose.yaml"
        fi
    else
        echo "FAIL|caddy_tls_labels|Service $service_name missing Caddy proxy labels|yq eval '.services.$service_name.labels' docker-compose.yaml"
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

# WHEN: We check for global TLS configuration in Caddy service
if caddy_service=$(yq eval ".services.proxy" "$COMPOSE_FILE" 2>/dev/null) && [[ "$caddy_service" != "null" ]]; then
    # Check if Caddy service has volume mounts for SSL certificates
    if ssl_volume=$(yq eval ".services.proxy.volumes[] | select(. | contains(\"certificates\"))" "$COMPOSE_FILE" 2>/dev/null); then
        echo "PASS|caddy_tls_labels|Caddy service has SSL certificate volume mount: $ssl_volume|yq eval '.services.proxy.volumes[] | select(. | contains(\"certificates\"))' docker-compose.yaml"
        
        # Check if the volume is mounted as read-only
        if [[ "$ssl_volume" == *":ro" ]]; then
            echo "PASS|caddy_tls_labels|SSL certificate volume mounted as read-only (secure)|yq eval '.services.proxy.volumes[] | select(. | contains(\"certificates\"))' docker-compose.yaml"
        else
            echo "INFO|caddy_tls_labels|SSL certificate volume not explicitly read-only|yq eval '.services.proxy.volumes[] | select(. | contains(\"certificates\"))' docker-compose.yaml"
        fi
        
        # Check if volume maps to /ssl inside container
        if [[ "$ssl_volume" == *":/ssl"* ]]; then
            echo "PASS|caddy_tls_labels|SSL certificates mapped to /ssl inside Caddy container|yq eval '.services.proxy.volumes[] | select(. | contains(\"certificates\"))' docker-compose.yaml"
        else
            echo "INFO|caddy_tls_labels|SSL certificates mapped to different path inside container|yq eval '.services.proxy.volumes[] | select(. | contains(\"certificates\"))' docker-compose.yaml"
        fi
    else
        echo "FAIL|caddy_tls_labels|Caddy service missing SSL certificate volume mount|yq eval '.services.proxy.volumes' docker-compose.yaml"
    fi
    
    # Check if Caddy service has environment files configured
    if env_files=$(yq eval ".services.proxy.env_file[]" "$COMPOSE_FILE" 2>/dev/null); then
        echo "PASS|caddy_tls_labels|Caddy service has environment files configured|yq eval '.services.proxy.env_file' docker-compose.yaml"
        
        # Check for .env.caddy file specifically
        if echo "$env_files" | grep -q "\.env\.caddy" 2>/dev/null; then
            echo "PASS|caddy_tls_labels|Caddy service includes .env.caddy configuration file|yq eval '.services.proxy.env_file' docker-compose.yaml"
        else
            echo "INFO|caddy_tls_labels|Caddy service may not have dedicated .env.caddy file|yq eval '.services.proxy.env_file' docker-compose.yaml"
        fi
    else
        echo "INFO|caddy_tls_labels|Caddy service environment files not explicitly configured|yq eval '.services.proxy.env_file' docker-compose.yaml"
    fi
else
    echo "FAIL|caddy_tls_labels|Caddy proxy service not found in docker-compose.yaml|yq eval '.services.proxy' docker-compose.yaml"
fi

# WHEN: We check for Caddy network configuration
if caddy_networks=$(yq eval ".services.proxy.networks" "$COMPOSE_FILE" 2>/dev/null) && [[ "$caddy_networks" != "null" ]]; then
    echo "PASS|caddy_tls_labels|Caddy service has network configuration|yq eval '.services.proxy.networks' docker-compose.yaml"
else
    echo "FAIL|caddy_tls_labels|Caddy service missing network configuration|yq eval '.services.proxy.networks' docker-compose.yaml"
fi

# WHEN: We verify that all services are on the same network as Caddy for proxy functionality
if frontend_network=$(yq eval ".networks.frontend" "$COMPOSE_FILE" 2>/dev/null) && [[ "$frontend_network" != "null" ]]; then
    echo "PASS|caddy_tls_labels|Frontend network defined for Caddy proxy|yq eval '.networks.frontend' docker-compose.yaml"
else
    echo "FAIL|caddy_tls_labels|Frontend network not defined for Caddy proxy|yq eval '.networks' docker-compose.yaml"
fi

# WHEN: We check for proper port exposure on Caddy service
if caddy_ports=$(yq eval ".services.proxy.ports" "$COMPOSE_FILE" 2>/dev/null) && [[ "$caddy_ports" != "null" ]]; then
    # Check for HTTPS port (443)
    if echo "$caddy_ports" | grep -q "443" 2>/dev/null; then
        echo "PASS|caddy_tls_labels|Caddy service exposes HTTPS port 443|yq eval '.services.proxy.ports' docker-compose.yaml"
    else
        echo "FAIL|caddy_tls_labels|Caddy service not exposing HTTPS port 443|yq eval '.services.proxy.ports' docker-compose.yaml"
    fi
    
    # Check for HTTP port (80)
    if echo "$caddy_ports" | grep -q "80" 2>/dev/null; then
        echo "PASS|caddy_tls_labels|Caddy service exposes HTTP port 80 (for redirects)|yq eval '.services.proxy.ports' docker-compose.yaml"
    else
        echo "INFO|caddy_tls_labels|Caddy service not exposing HTTP port 80|yq eval '.services.proxy.ports' docker-compose.yaml"
    fi
else
    echo "FAIL|caddy_tls_labels|Caddy service missing port configuration|yq eval '.services.proxy.ports' docker-compose.yaml"
fi

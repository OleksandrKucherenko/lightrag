#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 .etchosts.windows Generator
# =============================================================================
# Creates a Windows-specific hosts file for WSL2 environment using the correct
# Windows LAN IP address instead of localhost (127.0.0.1)
#
# Usage: ./bin/make.etchosts.windows.sh
# Output: .etchosts.windows (ready for hostctl or manual Windows hosts update)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/.etchosts.windows"

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------
log_info() { printf "[INFO] %s\n" "$1" >&2; }
log_warn() { printf "[WARN] %s\n" "$1" >&2; }
log_error() { printf "[ERROR] %s\n" "$1" >&2; }

# -----------------------------------------------------------------------------
# Detect Windows LAN IP for WSL2 (using logic from bin/diag.wsl2.sh)
# -----------------------------------------------------------------------------
get_windows_lan_ip() {
    if ! command -v powershell.exe &>/dev/null; then
        log_warn "PowerShell not available, using fallback method"
        return 1
    fi

    # Use the same logic as diag.wsl2.sh - prefer interface with 192.168.* gateway
    local windows_ip
    windows_ip=$(powershell.exe -NoProfile -Command '
        $c = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" -and $_.IPv4Address -ne $null };
        $lan = $c | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.IPv4DefaultGateway.NextHop -like "192.168.*" } | Select-Object -First 1;
        if (-not $lan) { $lan = $c | Where-Object { $_.IPv4Address.IPAddress -like "192.168.*" } | Select-Object -First 1 };
        if ($lan) { $lan.IPv4Address.IPAddress }
    ' | tr -d "\r")
    
    if [[ -n "$windows_ip" && "$windows_ip" =~ ^192\.168\.[0-9]+\.[0-9]+$ ]]; then
        log_info "Detected Windows LAN IP via PowerShell: $windows_ip"
        echo "$windows_ip"
        return 0
    fi
    
    return 1
}

detect_windows_lan_ip() {
    local windows_ip=""
    
    # Method 1: Use PowerShell to get proper Windows LAN IP (preferred)
    if windows_ip=$(get_windows_lan_ip); then
        echo "$windows_ip"
        return 0
    fi
    
    # Method 2: Fallback to WSL2 routing (may not be accurate with VPN)
    if command -v ip >/dev/null 2>&1; then
        windows_ip=$(ip route show default | awk '/default/ {print $3}' | head -1)
        if [[ -n "$windows_ip" && "$windows_ip" =~ ^192\.168\.[0-9]+\.[0-9]+$ ]]; then
            log_warn "Using WSL2 routing IP (may be incorrect with VPN): $windows_ip"
            echo "$windows_ip"
            return 0
        fi
    fi
    
    # Method 3: Use known fallback IP
    log_warn "Could not auto-detect Windows LAN IP, using known fallback: 192.168.1.103"
    log_warn "This may be incorrect if your network configuration differs"
    echo "192.168.1.103"
}

# -----------------------------------------------------------------------------
# Extract service information from docker-compose.yaml
# -----------------------------------------------------------------------------
extract_service_domains() {
    local compose_file="$REPO_ROOT/docker-compose.yaml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yaml not found at: $compose_file"
        return 1
    fi
    
    log_info "Extracting service domains from docker-compose.yaml..."
    
    # Use docker-compose to get service configuration if available
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        log_info "Using docker compose to extract service labels..."
        
        # Get the full compose config and extract caddy labels
        local compose_config
        if compose_config=$(docker compose config 2>/dev/null); then
            # Extract services with caddy labels pointing to dev.localhost
            echo "$compose_config" | awk '
            /^  [a-zA-Z][a-zA-Z0-9_-]*:/ { 
                service = $1; 
                gsub(/:/, "", service);
                in_service = 1;
            }
            /^[a-zA-Z]/ && !/^  / { 
                in_service = 0; 
            }
            in_service && /caddy:.*https:\/\/.*\.dev\.localhost/ { 
                match($0, /https:\/\/([^"[:space:]]+)/, arr);
                if (arr[1]) {
                    print service ":" arr[1];
                }
            }'
            
            # Check if we found any services
            local found_services
            found_services=$(echo "$compose_config" | grep -c 'caddy:.*https://.*\.dev\.localhost' || echo "0")
            if [[ "$found_services" -gt 0 ]]; then
                return 0
            fi
        fi
    fi
    
    # Fallback: Parse docker-compose.yaml directly with simpler approach
    log_warn "Using fallback parsing method..."
    
    # Extract service names and their caddy labels using a simpler approach
    local current_service=""
    local in_labels=false
    
    while IFS= read -r line; do
        # Check for service definition (starts with 2 spaces, service name, then colon)
        if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z][a-zA-Z0-9_-]*): ]]; then
            current_service="${BASH_REMATCH[1]}"
            in_labels=false
            continue
        fi
        
        # Check for labels section within a service
        if [[ -n "$current_service" ]] && [[ "$line" =~ ^[[:space:]]+labels: ]]; then
            in_labels=true
            continue
        fi
        
        # Reset when we encounter another service or top-level section
        if [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]]+labels: ]] && [[ ! "$line" =~ caddy: ]]; then
            in_labels=false
        fi
        
        # Reset current_service when we hit a new top-level section
        if [[ "$line" =~ ^[a-zA-Z] ]]; then
            current_service=""
            in_labels=false
        fi
        
        # Look for caddy labels
        if [[ "$in_labels" == true ]] && [[ -n "$current_service" ]] && [[ "$line" =~ caddy:.*https://.*\.dev\.localhost ]]; then
            local domain
            if [[ "$line" =~ https://([^\"[:space:]]+) ]]; then
                domain="${BASH_REMATCH[1]}"
                echo "$current_service:$domain"
            fi
        fi
    done < "$compose_file"
}

# -----------------------------------------------------------------------------
# Validate service domain consistency
# -----------------------------------------------------------------------------
validate_service_domains() {
    local service_domains=("$@")
    local inconsistencies=()
    local conflicts=()
    local domain_map=()
    
    log_info "Validating service domain consistency and conflicts..."
    
    # First pass: collect all domains and check for conflicts
    for entry in "${service_domains[@]}"; do
        IFS=':' read -r service_name domain <<< "$entry"
        
        # Check if domain is already used by another service
        for existing_entry in "${domain_map[@]}"; do
            IFS=':' read -r existing_service existing_domain <<< "$existing_entry"
            if [[ "$domain" == "$existing_domain" ]] && [[ "$service_name" != "$existing_service" ]]; then
                conflicts+=("Domain conflict: '$domain' used by both '$service_name' and '$existing_service'")
            fi
        done
        
        domain_map+=("$service_name:$domain")
    done
    
    # Second pass: check naming consistency
    for entry in "${service_domains[@]}"; do
        IFS=':' read -r service_name domain <<< "$entry"
        
        # Expected pattern: service.dev.localhost
        expected_domain="${service_name}.dev.localhost"
        
        if [[ "$domain" != "$expected_domain" ]]; then
            # Check for known acceptable variations
            case "$service_name" in
                "graph-ui")
                    if [[ "$domain" == "graph.dev.localhost" ]]; then
                        log_info "  ✓ Acceptable variation: '$service_name' → '$domain' (UI service using base name)"
                    else
                        inconsistencies+=("$service_name: expected 'graph.dev.localhost' or '$expected_domain', got '$domain'")
                    fi
                    ;;
                "vectors")
                    if [[ "$domain" == "vector.dev.localhost" ]]; then
                        log_info "  ✓ Acceptable variation: '$service_name' → '$domain' (singular form)"
                    else
                        inconsistencies+=("$service_name: expected 'vector.dev.localhost' or '$expected_domain', got '$domain'")
                    fi
                    ;;
                *)
                    # Check if it's a UI service pattern (service-ui → service.domain)
                    if [[ "$service_name" =~ ^(.+)-ui$ ]]; then
                        local base_service="${BASH_REMATCH[1]}"
                        local expected_ui_domain="${base_service}.dev.localhost"
                        if [[ "$domain" == "$expected_ui_domain" ]]; then
                            log_info "  ✓ UI service pattern: '$service_name' → '$domain' (using base service name)"
                        else
                            inconsistencies+=("$service_name: UI service expected '$expected_ui_domain' or '$expected_domain', got '$domain'")
                        fi
                    else
                        inconsistencies+=("$service_name: expected '$expected_domain', got '$domain'")
                    fi
                    ;;
            esac
        fi
    done
    
    # Report conflicts (these are errors)
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_error "Found domain conflicts:"
        for conflict in "${conflicts[@]}"; do
            log_error "  ❌ $conflict"
        done
    fi
    
    # Report inconsistencies (these are warnings)
    if [[ ${#inconsistencies[@]} -gt 0 ]]; then
        log_warn "Found naming inconsistencies:"
        for inconsistency in "${inconsistencies[@]}"; do
            log_warn "  ⚠️  $inconsistency"
        done
    fi
    
    if [[ ${#conflicts[@]} -eq 0 ]] && [[ ${#inconsistencies[@]} -eq 0 ]]; then
        log_info "✅ All service domains are consistent and conflict-free"
    fi
    
    # Return error code if there are conflicts (not just inconsistencies)
    return ${#conflicts[@]}
}

# -----------------------------------------------------------------------------
# Check for conflicts with services that don't have Caddy labels
# -----------------------------------------------------------------------------
check_service_conflicts() {
    local service_domains=("$@")
    local compose_file="$REPO_ROOT/docker-compose.yaml"
    
    log_info "Checking for potential conflicts with unlabeled services..."
    
    # Get all service names from docker-compose.yaml
    local all_services=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z][a-zA-Z0-9_-]*): ]]; then
            all_services+=("${BASH_REMATCH[1]}")
        fi
    done < "$compose_file"
    
    # Get domains that are being used
    local used_domains=()
    for entry in "${service_domains[@]}"; do
        IFS=':' read -r service_name domain <<< "$entry"
        used_domains+=("$domain")
    done
    
    # Check for potential conflicts
    local potential_conflicts=()
    for service in "${all_services[@]}"; do
        local potential_domain="${service}.dev.localhost"
        
        # Check if this service has a Caddy label
        local has_caddy_label=false
        for entry in "${service_domains[@]}"; do
            IFS=':' read -r labeled_service domain <<< "$entry"
            if [[ "$service" == "$labeled_service" ]]; then
                has_caddy_label=true
                break
            fi
        done
        
        # If service doesn't have Caddy label, check if its potential domain conflicts
        if [[ "$has_caddy_label" == false ]]; then
            for used_domain in "${used_domains[@]}"; do
                if [[ "$potential_domain" == "$used_domain" ]]; then
                    potential_conflicts+=("Service '$service' (no Caddy label) would conflict with domain '$used_domain' if it had a label")
                fi
            done
            
            # Special case: check for base service conflicts (e.g., graph vs graph-ui)
            for entry in "${service_domains[@]}"; do
                IFS=':' read -r labeled_service domain <<< "$entry"
                
                # Check if labeled service uses this unlabeled service's domain
                if [[ "$domain" == "$potential_domain" ]] && [[ "$labeled_service" != "$service" ]]; then
                    if [[ "$labeled_service" =~ ^${service}- ]]; then
                        log_info "  ✓ Domain sharing: '$service' (unlabeled) and '$labeled_service' → '$domain' (acceptable pattern)"
                    else
                        potential_conflicts+=("Domain '$domain' used by '$labeled_service' conflicts with potential domain for unlabeled service '$service'")
                    fi
                fi
            done
        fi
    done
    
    if [[ ${#potential_conflicts[@]} -gt 0 ]]; then
        log_warn "Found potential conflicts with unlabeled services:"
        for conflict in "${potential_conflicts[@]}"; do
            log_warn "  ⚠️  $conflict"
        done
    else
        log_info "✅ No conflicts detected with unlabeled services"
    fi
}

# -----------------------------------------------------------------------------
# Generate .etchosts.windows content from docker-compose.yaml
# -----------------------------------------------------------------------------
generate_etchosts_content() {
    local windows_ip="$1"
    
    # Extract service domains from docker-compose.yaml
    local service_domains=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && service_domains+=("$line")
    done < <(extract_service_domains)
    
    if [[ ${#service_domains[@]} -eq 0 ]]; then
        log_error "No services with Caddy labels found in docker-compose.yaml"
        return 1
    fi
    
    # Validate consistency and detect conflicts
    validate_service_domains "${service_domains[@]}"
    
    # Check for potential conflicts with services that don't have Caddy labels
    check_service_conflicts "${service_domains[@]}"
    
    # Generate the hosts file content
    cat <<EOF
# =============================================================================
# WSL2 Windows Hosts Configuration
# =============================================================================
# Generated by: bin/make.etchosts.windows.sh
# Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Windows LAN IP: $windows_ip
# Source: docker-compose.yaml ($(wc -l < "$REPO_ROOT/docker-compose.yaml") lines)
#
# Usage:
#   1. Copy content to Windows hosts file: C:\\Windows\\System32\\drivers\\etc\\hosts
#   2. Or use hostctl: hostctl replace lightrag --from .etchosts.windows
#
# Note: WSL2 requires Windows host IP, not 127.0.0.1

EOF

    echo "# Main development domain"
    printf "%-15s %s\n" "$windows_ip" "dev.localhost"

    echo ""
    echo "# Services from docker-compose.yaml"

    # Add each service domain
    for entry in "${service_domains[@]}"; do
        IFS=':' read -r service_name domain <<< "$entry"
        printf "%-15s %-30s  # %s service\n" "$windows_ip" "$domain" "$service_name"
    done
    
    echo ""
}

# -----------------------------------------------------------------------------
# Main execution
# -----------------------------------------------------------------------------
main() {
    log_info "Starting WSL2 .etchosts.windows generation..."
    
    # Detect Windows LAN IP
    local windows_ip
    windows_ip=$(detect_windows_lan_ip)
    
    if [[ -z "$windows_ip" ]]; then
        log_error "Failed to detect Windows LAN IP address"
        exit 1
    fi
    
    log_info "Using Windows LAN IP: $windows_ip"
    
    # Generate the hosts file content
    generate_etchosts_content "$windows_ip" > "$OUTPUT_FILE"
    
    # Verify file was created
    if [[ -f "$OUTPUT_FILE" ]]; then
        log_info "Successfully created: $OUTPUT_FILE"
        log_info "File size: $(wc -l < "$OUTPUT_FILE") lines"
        
        # Show preview
        echo ""
        echo "Preview of generated content:"
        echo "=============================="
        head -25 "$OUTPUT_FILE"
        echo ""
        
        log_info "Next steps:"
        log_info "1. Review the generated file: cat .etchosts.windows"
        log_info "2. Apply to Windows hosts: sudo hostctl replace lightrag --from .etchosts.windows"
        log_info "3. Or manually copy to: C:\\Windows\\System32\\drivers\\etc\\hosts"
        
    else
        log_error "Failed to create $OUTPUT_FILE"
        exit 1
    fi
}

# Execute main function
main "$@"

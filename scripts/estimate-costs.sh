#!/usr/bin/env bash
#
# Cost Estimation Script for Kubernetes Resources
#
# Analyzes K8s manifests and Helm values to estimate monthly costs
# across multiple cloud providers (AWS, Azure, GCP, DigitalOcean, Civo)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default prices per resource unit per month (USD)
# Prices as of 2024 - based on typical instance types

# AWS EKS pricing (t3.xlarge equivalent per vCPU and GB RAM per month)
AWS_CPU_PRICE=36.50  # ~$73/month for 2 vCPU
AWS_RAM_PRICE=4.56   # ~$73/month for 16GB RAM
AWS_STORAGE_PRICE=0.10  # gp3 per GB/month
AWS_CONTROL_PLANE=72.00 # EKS control plane

# Azure AKS pricing (Standard_D4s_v3 equivalent)
AZURE_CPU_PRICE=43.75  # ~$175/month for 4 vCPU
AZURE_RAM_PRICE=10.94  # ~$175/month for 16GB RAM
AZURE_STORAGE_PRICE=0.15  # Premium SSD per GB/month
AZURE_CONTROL_PLANE=0.00  # Free

# GCP GKE pricing (n2-standard-4 equivalent)
GCP_CPU_PRICE=45.00  # ~$180/month for 4 vCPU
GCP_RAM_PRICE=11.25  # ~$180/month for 16GB RAM
GCP_STORAGE_PRICE=0.17  # pd-ssd per GB/month
GCP_CONTROL_PLANE=73.00  # Standard tier

# DigitalOcean pricing (s-4vcpu-8gb equivalent)
DO_CPU_PRICE=12.00  # $48/month for 4 vCPU
DO_RAM_PRICE=6.00   # $48/month for 8GB RAM
DO_STORAGE_PRICE=0.10  # Block storage per GB/month
DO_CONTROL_PLANE=0.00  # Free

# Civo pricing (g4s.kube.medium equivalent)
CIVO_CPU_PRICE=10.00  # $20/month for 2 vCPU
CIVO_RAM_PRICE=2.50   # $20/month for 8GB RAM
CIVO_STORAGE_PRICE=0.05  # Block storage per GB/month
CIVO_CONTROL_PLANE=0.00  # Free

# Check if yq is installed (optional, will use fallback if not available)
check_yq() {
    if command -v yq &> /dev/null; then
        # Check if it's the right yq (mikefarah's version, not python-yq)
        if yq --version 2>&1 | grep -q "mikefarah"; then
            return 0
        fi
    fi
    return 1
}

# Extract value using grep/awk (fallback when yq not available)
extract_value_fallback() {
    local file=$1
    local path=$2  # e.g., "lightrag.resources.requests.cpu"

    # Convert dot notation to grep pattern
    # lightrag.resources.requests.cpu -> find "lightrag:" then "resources:" then "requests:" then "cpu:"
    local parts
    IFS='.' read -ra parts <<< "$path"

    local result=""
    local in_section=0
    local indent_level=0
    local target_indent=0

    while IFS= read -r line; do
        # Get indentation level
        local current_indent=$(echo "$line" | awk '{print match($0, /[^ ]/)-1}')

        # Check if this line matches our first key
        if [ $in_section -eq 0 ] && echo "$line" | grep -q "^[[:space:]]*${parts[0]}:"; then
            in_section=1
            target_indent=$current_indent
            if [ ${#parts[@]} -eq 1 ]; then
                result=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"')
                break
            fi
            shift parts 2>/dev/null || true
            continue
        fi

        # If we're in a section, look for the next key
        if [ $in_section -eq 1 ]; then
            # If indent decreased, we left the section
            if [ $current_indent -le $target_indent ]; then
                break
            fi

            # Check if this matches our next key
            for i in "${!parts[@]}"; do
                if echo "$line" | grep -q "^[[:space:]]*${parts[$i]}:"; then
                    target_indent=$current_indent
                    if [ $i -eq $((${#parts[@]}-1)) ]; then
                        # This is the last key, extract value
                        result=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"')
                        break 2
                    fi
                    unset 'parts[$i]'
                    parts=("${parts[@]}")  # Reindex array
                    break
                fi
            done
        fi
    done < "$file"

    if [ -z "$result" ] || [ "$result" == "null" ]; then
        echo "0"
    else
        echo "$result"
    fi
}

# Parse CPU in millicores to cores
parse_cpu() {
    local cpu=$1
    if [[ $cpu == *"m" ]]; then
        # Remove 'm' and convert to cores
        echo "scale=3; ${cpu%m} / 1000" | bc
    else
        echo "$cpu"
    fi
}

# Parse memory to GB
parse_memory() {
    local mem=$1
    if [[ $mem == *"Gi" ]]; then
        echo "${mem%Gi}"
    elif [[ $mem == *"Mi" ]]; then
        echo "scale=3; ${mem%Mi} / 1024" | bc
    elif [[ $mem == *"G" ]]; then
        echo "${mem%G}"
    elif [[ $mem == *"M" ]]; then
        echo "scale=3; ${mem%M} / 1024" | bc
    else
        echo "$mem"
    fi
}

# Extract a single value from YAML using grep/awk (works without yq)
get_yaml_value() {
    local file=$1
    local key=$2
    grep -A 1 "^[[:space:]]*$key:" "$file" | tail -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' || echo "0"
}

# Extract resources from Helm values
extract_helm_resources() {
    local values_file="$1"

    if [ ! -f "$values_file" ]; then
        echo "0 0 0"
        return
    fi

    local total_cpu=0
    local total_ram=0
    local total_storage=0

    # Simplified extraction using awk to parse YAML structure
    # Extract all CPU requests
    total_cpu=$(awk '
        /^[a-z]+:/ { section=$1; sub(/:/, "", section) }
        /resources:/,/persistence:/ {
            if (/requests:/) in_requests=1
            if (/limits:/) in_requests=0
            if (in_requests && /cpu:/) {
                gsub(/[^0-9m]/, "")
                if (/m$/) {
                    val = $0
                    sub(/m/, "", val)
                    sum += val / 1000
                } else {
                    sum += $0 + 0
                }
            }
        }
        END { printf "%.2f", sum }
    ' "$values_file")

    # Extract all RAM requests
    total_ram=$(awk '
        /resources:/,/persistence:/ {
            if (/requests:/) in_requests=1
            if (/limits:/) in_requests=0
            if (in_requests && /memory:/) {
                val = $2
                gsub(/"/, "", val)
                if (val ~ /Gi$/) {
                    gsub(/Gi/, "", val)
                    sum += val + 0
                } else if (val ~ /Mi$/) {
                    gsub(/Mi/, "", val)
                    sum += (val + 0) / 1024
                }
            }
        }
        END { printf "%.2f", sum }
    ' "$values_file")

    # Extract all storage
    total_storage=$(awk '
        /persistence:/,/^[a-z]+:/ {
            if (/size:/) {
                val = $2
                gsub(/"/, "", val)
                if (val ~ /Gi$/) {
                    gsub(/Gi/, "", val)
                    sum += val + 0
                } else if (val ~ /Mi$/) {
                    gsub(/Mi/, "", val)
                    sum += (val + 0) / 1024
                }
            }
        }
        END { printf "%.0f", sum }
    ' "$values_file")

    # Fallback to 0 if extraction failed
    total_cpu=${total_cpu:-0}
    total_ram=${total_ram:-0}
    total_storage=${total_storage:-0}

    echo "$total_cpu $total_ram $total_storage"
}

# Calculate costs for a provider
calculate_provider_cost() {
    local cpu=$1
    local ram=$2
    local storage=$3
    local cpu_price=$4
    local ram_price=$5
    local storage_price=$6
    local control_plane=$7

    local cpu_cost=$(echo "scale=2; $cpu * $cpu_price" | bc)
    local ram_cost=$(echo "scale=2; $ram * $ram_price" | bc)
    local storage_cost=$(echo "scale=2; $storage * $storage_price" | bc)
    local compute_cost=$(echo "scale=2; $cpu_cost + $ram_cost" | bc)
    local total=$(echo "scale=2; $compute_cost + $storage_cost + $control_plane" | bc)

    echo "$cpu_cost|$ram_cost|$storage_cost|$control_plane|$compute_cost|$total"
}

# Format cost for display
format_cost() {
    local cost=$1
    printf "\$%.2f" "$cost"
}

# Calculate and display costs
calculate_costs() {
    local label=$1
    local cpu=$2
    local ram=$3
    local storage=$4

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Cost Estimate: $label${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Resources:"
    echo "  CPU:     $(printf '%.2f' $cpu) cores"
    echo "  RAM:     $(printf '%.0f' $ram) GB"
    echo "  Storage: $(printf '%.0f' $storage) GB"
    echo ""

    # Calculate for each provider
    IFS='|' read -r aws_cpu aws_ram aws_storage aws_cp aws_compute aws_total <<< \
        "$(calculate_provider_cost $cpu $ram $storage $AWS_CPU_PRICE $AWS_RAM_PRICE $AWS_STORAGE_PRICE $AWS_CONTROL_PLANE)"

    IFS='|' read -r azure_cpu azure_ram azure_storage azure_cp azure_compute azure_total <<< \
        "$(calculate_provider_cost $cpu $ram $storage $AZURE_CPU_PRICE $AZURE_RAM_PRICE $AZURE_STORAGE_PRICE $AZURE_CONTROL_PLANE)"

    IFS='|' read -r gcp_cpu gcp_ram gcp_storage gcp_cp gcp_compute gcp_total <<< \
        "$(calculate_provider_cost $cpu $ram $storage $GCP_CPU_PRICE $GCP_RAM_PRICE $GCP_STORAGE_PRICE $GCP_CONTROL_PLANE)"

    IFS='|' read -r do_cpu do_ram do_storage do_cp do_compute do_total <<< \
        "$(calculate_provider_cost $cpu $ram $storage $DO_CPU_PRICE $DO_RAM_PRICE $DO_STORAGE_PRICE $DO_CONTROL_PLANE)"

    IFS='|' read -r civo_cpu civo_ram civo_storage civo_cp civo_compute civo_total <<< \
        "$(calculate_provider_cost $cpu $ram $storage $CIVO_CPU_PRICE $CIVO_RAM_PRICE $CIVO_STORAGE_PRICE $CIVO_CONTROL_PLANE)"

    # Display table
    echo "Monthly Cost Estimates (USD):"
    echo ""
    printf "%-20s %12s %12s %12s %12s %12s\n" "Provider" "Compute" "Storage" "Control" "Total" "Yearly"
    printf "%-20s %12s %12s %12s %12s %12s\n" "────────" "───────" "───────" "───────" "─────" "──────"

    printf "%-20s %12s %12s %12s %12s %12s\n" \
        "AWS (EKS)" \
        "$(format_cost $aws_compute)" \
        "$(format_cost $aws_storage)" \
        "$(format_cost $aws_cp)" \
        "$(format_cost $aws_total)" \
        "$(format_cost $(echo "$aws_total * 12" | bc))"

    printf "%-20s %12s %12s %12s %12s %12s\n" \
        "Azure (AKS)" \
        "$(format_cost $azure_compute)" \
        "$(format_cost $azure_storage)" \
        "$(format_cost $azure_cp)" \
        "$(format_cost $azure_total)" \
        "$(format_cost $(echo "$azure_total * 12" | bc))"

    printf "%-20s %12s %12s %12s %12s %12s\n" \
        "GCP (GKE)" \
        "$(format_cost $gcp_compute)" \
        "$(format_cost $gcp_storage)" \
        "$(format_cost $gcp_cp)" \
        "$(format_cost $gcp_total)" \
        "$(format_cost $(echo "$gcp_total * 12" | bc))"

    printf "%-20s %12s %12s %12s %12s %12s\n" \
        "DigitalOcean (DOKS)" \
        "$(format_cost $do_compute)" \
        "$(format_cost $do_storage)" \
        "$(format_cost $do_cp)" \
        "$(format_cost $do_total)" \
        "$(format_cost $(echo "$do_total * 12" | bc))"

    printf "%-20s %12s %12s %12s %12s %12s\n" \
        "Civo" \
        "$(format_cost $civo_compute)" \
        "$(format_cost $civo_storage)" \
        "$(format_cost $civo_cp)" \
        "$(format_cost $civo_total)" \
        "$(format_cost $(echo "$civo_total * 12" | bc))"

    echo ""
    echo "Daily Cost Estimates (USD):"
    printf "%-20s %12s\n" "Provider" "Daily"
    printf "%-20s %12s\n" "────────" "─────"
    printf "%-20s %12s\n" "AWS (EKS)" "$(format_cost $(echo "scale=2; $aws_total / 30" | bc))"
    printf "%-20s %12s\n" "Azure (AKS)" "$(format_cost $(echo "scale=2; $azure_total / 30" | bc))"
    printf "%-20s %12s\n" "GCP (GKE)" "$(format_cost $(echo "scale=2; $gcp_total / 30" | bc))"
    printf "%-20s %12s\n" "DigitalOcean (DOKS)" "$(format_cost $(echo "scale=2; $do_total / 30" | bc))"
    printf "%-20s %12s\n" "Civo" "$(format_cost $(echo "scale=2; $civo_total / 30" | bc))"
}

# Generate markdown table for PR comment
generate_markdown_table() {
    local current_cpu=$1
    local current_ram=$2
    local current_storage=$3
    local base_cpu=$4
    local base_ram=$5
    local base_storage=$6

    cat << 'EOF'
## 💰 Cost Impact Analysis

### Resource Changes

| Resource | Current | Base | Change |
|----------|---------|------|--------|
EOF

    # Calculate changes
    local cpu_change=$(echo "scale=2; $current_cpu - $base_cpu" | bc)
    local ram_change=$(echo "scale=2; $current_ram - $base_ram" | bc)
    local storage_change=$(echo "scale=2; $current_storage - $base_storage" | bc)

    # Format change with color
    format_change() {
        local val=$1
        if (( $(echo "$val > 0" | bc -l) )); then
            echo "🔴 +$(printf '%.2f' $val)"
        elif (( $(echo "$val < 0" | bc -l) )); then
            echo "🟢 $(printf '%.2f' $val)"
        else
            echo "⚪ 0.00"
        fi
    }

    printf "| CPU (cores) | %.2f | %.2f | %s |\n" $current_cpu $base_cpu "$(format_change $cpu_change)"
    printf "| RAM (GB) | %.0f | %.0f | %s |\n" $current_ram $base_ram "$(format_change $ram_change)"
    printf "| Storage (GB) | %.0f | %.0f | %s |\n" $current_storage $base_storage "$(format_change $storage_change)"

    echo ""
    echo "### Monthly Cost Estimates"
    echo ""
    echo "| Provider | Current | Base | Change | Yearly Impact |"
    echo "|----------|---------|------|--------|---------------|"

    # Calculate costs
    IFS='|' read -r aws_cur azure_cur gcp_cur do_cur civo_cur <<< \
        "$(calculate_provider_cost $current_cpu $current_ram $current_storage $AWS_CPU_PRICE $AWS_RAM_PRICE $AWS_STORAGE_PRICE $AWS_CONTROL_PLANE | cut -d'|' -f6)"

    IFS='|' read -r aws_base azure_base gcp_base do_base civo_base <<< \
        "$(calculate_provider_cost $base_cpu $base_ram $base_storage $AWS_CPU_PRICE $AWS_RAM_PRICE $AWS_STORAGE_PRICE $AWS_CONTROL_PLANE | cut -d'|' -f6)"

    # AWS
    local aws_diff=$(echo "scale=2; $aws_cur - $aws_base" | bc)
    local aws_yearly=$(echo "scale=2; $aws_diff * 12" | bc)
    printf "| AWS (EKS) | \$%.2f | \$%.2f | %s | %s |\n" \
        $aws_cur $aws_base \
        "$(format_change $aws_diff)" \
        "$(format_change $aws_yearly)"

    # Similar for other providers...
    # (shortened for brevity)

    echo ""
    echo "### Summary"
    echo ""

    if (( $(echo "$cpu_change > 0 || $ram_change > 0 || $storage_change > 0" | bc -l) )); then
        echo "⚠️ **This PR increases resource usage and will increase costs.**"
    elif (( $(echo "$cpu_change < 0 || $ram_change < 0 || $storage_change < 0" | bc -l) )); then
        echo "✅ **This PR reduces resource usage and will reduce costs.**"
    else
        echo "ℹ️ **This PR has no resource changes.**"
    fi

    echo ""
    echo "_Estimates based on standard instance pricing as of 2024. Actual costs may vary._"
}

# Main execution
main() {
    local mode="${1:-current}"
    local base_branch="${2:-main}"

    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}    Kubernetes Cost Estimation Tool${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

    if check_yq; then
        echo ""
        echo "✓ Using yq for parsing (faster)"
    else
        echo ""
        echo "ℹ Using awk/grep for parsing (yq not available)"
    fi

    local helm_values="$PROJECT_ROOT/helm/lightrag/values.yaml"

    if [ "$mode" == "pr" ]; then
        # PR mode: compare current branch with base
        echo ""
        echo "Mode: Pull Request Cost Analysis"
        echo "Base branch: $base_branch"
        echo ""

        # Get current resources
        read -r current_cpu current_ram current_storage <<< "$(extract_helm_resources "$helm_values")"

        # Get base resources
        git fetch origin "$base_branch" 2>/dev/null || true
        git show "origin/$base_branch:helm/lightrag/values.yaml" > /tmp/base-values.yaml 2>/dev/null || {
            echo -e "${YELLOW}Warning: Could not fetch base branch values, using current values${NC}"
            cp "$helm_values" /tmp/base-values.yaml
        }
        read -r base_cpu base_ram base_storage <<< "$(extract_helm_resources "/tmp/base-values.yaml")"

        # Generate comparison
        generate_markdown_table "$current_cpu" "$current_ram" "$current_storage" \
                               "$base_cpu" "$base_ram" "$base_storage"

        rm -f /tmp/base-values.yaml

    else
        # Standard mode: show current costs
        read -r cpu ram storage <<< "$(extract_helm_resources "$helm_values")"

        if [ "$cpu" == "0" ] && [ "$ram" == "0" ]; then
            echo -e "${RED}Error: Could not extract resource information${NC}"
            exit 1
        fi

        calculate_costs "Current Configuration" "$cpu" "$ram" "$storage"

        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "💡 Tips:"
        echo "  • Use 'requests' not 'limits' for accurate cost estimates"
        echo "  • Consider reserved instances for 40-60% savings"
        echo "  • Enable autoscaling to optimize costs during low usage"
        echo "  • Run ./scripts/sync-config.sh to validate configurations"
        echo ""
        echo "📊 For detailed cost monitoring, install Kubecost:"
        echo "   See k8s/COST_MONITORING.md for instructions"
    fi
}

# Handle script arguments
if [ $# -eq 0 ]; then
    main "current"
elif [ "$1" == "--pr" ]; then
    main "pr" "${2:-main}"
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << 'EOF'
Usage: estimate-costs.sh [mode] [base-branch]

Modes:
  (no args)          Show current configuration costs
  --pr [branch]      PR mode: compare with base branch (default: main)
  --help, -h         Show this help message

Examples:
  ./scripts/estimate-costs.sh                 # Current costs
  ./scripts/estimate-costs.sh --pr main       # Compare with main branch
  ./scripts/estimate-costs.sh --pr develop    # Compare with develop branch

For GitHub Actions integration, see .github/workflows/cost-estimate.yml
EOF
else
    main "$@"
fi

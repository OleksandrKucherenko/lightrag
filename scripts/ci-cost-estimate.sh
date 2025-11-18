#!/usr/bin/env bash
#
# CI script for PR cost estimation
#
# Extracts current and base branch resources, calculates costs for all providers,
# and generates a markdown report for PR comments.
#
# Usage:
#   ./scripts/ci-cost-estimate.sh <base_branch> <output_file>
#
# Example:
#   ./scripts/ci-cost-estimate.sh main /tmp/cost-report.md
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BASE_BRANCH="${1:-main}"
OUTPUT_FILE="${2:-/tmp/cost-report.md}"

# Source the cost estimation functions
source "$SCRIPT_DIR/estimate-costs.sh"

VALUES_FILE="$PROJECT_ROOT/helm/lightrag/values.yaml"

echo "Extracting current branch resources..."
read -r CURRENT_CPU CURRENT_RAM CURRENT_STORAGE <<< "$(extract_helm_resources "$VALUES_FILE")"

echo "Extracting base branch resources..."
git show "origin/$BASE_BRANCH:helm/lightrag/values.yaml" > /tmp/base-values.yaml 2>/dev/null || {
    echo "Warning: Could not fetch base values, using current values"
    cp "$VALUES_FILE" /tmp/base-values.yaml
}
read -r BASE_CPU BASE_RAM BASE_STORAGE <<< "$(extract_helm_resources "/tmp/base-values.yaml")"

# Calculate changes
CPU_CHANGE=$(echo "scale=2; $CURRENT_CPU - $BASE_CPU" | bc)
RAM_CHANGE=$(echo "scale=2; $CURRENT_RAM - $BASE_RAM" | bc)
STORAGE_CHANGE=$(echo "scale=2; $CURRENT_STORAGE - $BASE_STORAGE" | bc)

echo "Current: CPU=$CURRENT_CPU RAM=$CURRENT_RAM Storage=$CURRENT_STORAGE"
echo "Base: CPU=$BASE_CPU RAM=$BASE_RAM Storage=$BASE_STORAGE"
echo "Changes: CPU=$CPU_CHANGE RAM=$RAM_CHANGE Storage=$STORAGE_CHANGE"

# Calculate costs for each provider (current)
IFS='|' read -r aws_cpu aws_ram aws_storage aws_cp aws_compute aws_total <<< \
    "$(calculate_provider_cost $CURRENT_CPU $CURRENT_RAM $CURRENT_STORAGE \
       $AWS_CPU_PRICE $AWS_RAM_PRICE $AWS_STORAGE_PRICE $AWS_CONTROL_PLANE)"

IFS='|' read -r azure_cpu azure_ram azure_storage azure_cp azure_compute azure_total <<< \
    "$(calculate_provider_cost $CURRENT_CPU $CURRENT_RAM $CURRENT_STORAGE \
       $AZURE_CPU_PRICE $AZURE_RAM_PRICE $AZURE_STORAGE_PRICE $AZURE_CONTROL_PLANE)"

IFS='|' read -r gcp_cpu gcp_ram gcp_storage gcp_cp gcp_compute gcp_total <<< \
    "$(calculate_provider_cost $CURRENT_CPU $CURRENT_RAM $CURRENT_STORAGE \
       $GCP_CPU_PRICE $GCP_RAM_PRICE $GCP_STORAGE_PRICE $GCP_CONTROL_PLANE)"

IFS='|' read -r do_cpu do_ram do_storage do_cp do_compute do_total <<< \
    "$(calculate_provider_cost $CURRENT_CPU $CURRENT_RAM $CURRENT_STORAGE \
       $DO_CPU_PRICE $DO_RAM_PRICE $DO_STORAGE_PRICE $DO_CONTROL_PLANE)"

IFS='|' read -r civo_cpu civo_ram civo_storage civo_cp civo_compute civo_total <<< \
    "$(calculate_provider_cost $CURRENT_CPU $CURRENT_RAM $CURRENT_STORAGE \
       $CIVO_CPU_PRICE $CIVO_RAM_PRICE $CIVO_STORAGE_PRICE $CIVO_CONTROL_PLANE)"

# Calculate costs for base
IFS='|' read -r aws_total_base _ _ _ _ _ <<< \
    "$(calculate_provider_cost $BASE_CPU $BASE_RAM $BASE_STORAGE \
       $AWS_CPU_PRICE $AWS_RAM_PRICE $AWS_STORAGE_PRICE $AWS_CONTROL_PLANE)"

IFS='|' read -r azure_total_base _ _ _ _ _ <<< \
    "$(calculate_provider_cost $BASE_CPU $BASE_RAM $BASE_STORAGE \
       $AZURE_CPU_PRICE $AZURE_RAM_PRICE $AZURE_STORAGE_PRICE $AZURE_CONTROL_PLANE)"

IFS='|' read -r gcp_total_base _ _ _ _ _ <<< \
    "$(calculate_provider_cost $BASE_CPU $BASE_RAM $BASE_STORAGE \
       $GCP_CPU_PRICE $GCP_RAM_PRICE $GCP_STORAGE_PRICE $GCP_CONTROL_PLANE)"

IFS='|' read -r do_total_base _ _ _ _ _ <<< \
    "$(calculate_provider_cost $BASE_CPU $BASE_RAM $BASE_STORAGE \
       $DO_CPU_PRICE $DO_RAM_PRICE $DO_STORAGE_PRICE $DO_CONTROL_PLANE)"

IFS='|' read -r civo_total_base _ _ _ _ _ <<< \
    "$(calculate_provider_cost $BASE_CPU $BASE_RAM $BASE_STORAGE \
       $CIVO_CPU_PRICE $CIVO_RAM_PRICE $CIVO_STORAGE_PRICE $CIVO_CONTROL_PLANE)"

# Calculate diffs
AWS_DIFF=$(echo "scale=2; $aws_total - $aws_total_base" | bc)
AZURE_DIFF=$(echo "scale=2; $azure_total - $azure_total_base" | bc)
GCP_DIFF=$(echo "scale=2; $gcp_total - $gcp_total_base" | bc)
DO_DIFF=$(echo "scale=2; $do_total - $do_total_base" | bc)
CIVO_DIFF=$(echo "scale=2; $civo_total - $civo_total_base" | bc)

# Calculate daily and yearly
AWS_DAILY=$(echo "scale=2; $AWS_DIFF / 30" | bc)
AWS_YEARLY=$(echo "scale=2; $AWS_DIFF * 12" | bc)
AZURE_DAILY=$(echo "scale=2; $AZURE_DIFF / 30" | bc)
AZURE_YEARLY=$(echo "scale=2; $AZURE_DIFF * 12" | bc)
GCP_DAILY=$(echo "scale=2; $GCP_DIFF / 30" | bc)
GCP_YEARLY=$(echo "scale=2; $GCP_DIFF * 12" | bc)
DO_DAILY=$(echo "scale=2; $DO_DIFF / 30" | bc)
DO_YEARLY=$(echo "scale=2; $DO_DIFF * 12" | bc)
CIVO_DAILY=$(echo "scale=2; $CIVO_DIFF / 30" | bc)
CIVO_YEARLY=$(echo "scale=2; $CIVO_DIFF * 12" | bc)

# Determine summary status
if (( $(echo "$CPU_CHANGE > 0 || $RAM_CHANGE > 0 || $STORAGE_CHANGE > 0" | bc -l) )); then
    SUMMARY="⚠️ **This PR increases resource usage and will increase costs.**"
elif (( $(echo "$CPU_CHANGE < 0 || $RAM_CHANGE < 0 || $STORAGE_CHANGE < 0" | bc -l) )); then
    SUMMARY="✅ **This PR reduces resource usage and will reduce costs.**"
else
    SUMMARY="ℹ️ **This PR has no resource changes.**"
fi

# Export data for GitHub Actions (if GITHUB_OUTPUT is set)
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "current_cpu=$CURRENT_CPU"
        echo "current_ram=$CURRENT_RAM"
        echo "current_storage=$CURRENT_STORAGE"
        echo "base_cpu=$BASE_CPU"
        echo "base_ram=$BASE_RAM"
        echo "base_storage=$BASE_STORAGE"
        echo "cpu_change=$CPU_CHANGE"
        echo "ram_change=$RAM_CHANGE"
        echo "storage_change=$STORAGE_CHANGE"
        echo "aws_current=$aws_total"
        echo "aws_base=$aws_total_base"
        echo "aws_diff=$AWS_DIFF"
        echo "aws_daily=$AWS_DAILY"
        echo "aws_yearly=$AWS_YEARLY"
        echo "azure_current=$azure_total"
        echo "azure_base=$azure_total_base"
        echo "azure_diff=$AZURE_DIFF"
        echo "azure_daily=$AZURE_DAILY"
        echo "azure_yearly=$AZURE_YEARLY"
        echo "gcp_current=$gcp_total"
        echo "gcp_base=$gcp_total_base"
        echo "gcp_diff=$GCP_DIFF"
        echo "gcp_daily=$GCP_DAILY"
        echo "gcp_yearly=$GCP_YEARLY"
        echo "do_current=$do_total"
        echo "do_base=$do_total_base"
        echo "do_diff=$DO_DIFF"
        echo "do_daily=$DO_DAILY"
        echo "do_yearly=$DO_YEARLY"
        echo "civo_current=$civo_total"
        echo "civo_base=$civo_total_base"
        echo "civo_diff=$CIVO_DIFF"
        echo "civo_daily=$CIVO_DAILY"
        echo "civo_yearly=$CIVO_YEARLY"
    } >> "$GITHUB_OUTPUT"
fi

# Generate markdown report
# Note: COMMIT_SHA and COMMIT_SHORT should be provided by caller or environment
COMMIT_SHA="${COMMIT_SHA:-unknown}"
COMMIT_SHORT="${COMMIT_SHA:0:7}"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPO_URL="${REPO_URL:-https://github.com/user/repo}"

cat > "$OUTPUT_FILE" << EOF
## 💰 Cost Impact Analysis

> **Analysis based on commit:** [\`${COMMIT_SHORT}\`](${REPO_URL}/commit/${COMMIT_SHA})
> **Generated at:** ${TIMESTAMP}

### Resource Changes

| Resource | Current | Base | Change |
|----------|---------|------|--------|
| **CPU** (cores) | $CURRENT_CPU | $BASE_CPU | $CPU_CHANGE |
| **RAM** (GB) | $CURRENT_RAM | $BASE_RAM | $RAM_CHANGE |
| **Storage** (GB) | $CURRENT_STORAGE | $BASE_STORAGE | $STORAGE_CHANGE |

### Monthly Cost Estimates (USD)

| Provider | Current | Base | Monthly Δ | Daily Δ | Yearly Δ |
|----------|---------|------|-----------|---------|----------|
| **AWS EKS** | \$$aws_total | \$$aws_total_base | \$$AWS_DIFF | \$$AWS_DAILY | \$$AWS_YEARLY |
| **Azure AKS** | \$$azure_total | \$$azure_total_base | \$$AZURE_DIFF | \$$AZURE_DAILY | \$$AZURE_YEARLY |
| **GCP GKE** | \$$gcp_total | \$$gcp_total_base | \$$GCP_DIFF | \$$GCP_DAILY | \$$GCP_YEARLY |
| **DigitalOcean** | \$$do_total | \$$do_total_base | \$$DO_DIFF | \$$DO_DAILY | \$$DO_YEARLY |
| **Civo** | \$$civo_total | \$$civo_total_base | \$$CIVO_DIFF | \$$CIVO_DAILY | \$$CIVO_YEARLY |

### Summary

${SUMMARY}

---

**Cost Savings Tips:**
- Use reserved instances for 40-60% savings on predictable workloads
- Enable autoscaling to optimize costs during low usage periods
- Review resource requests vs limits - use requests for cost planning
- Consider spot/preemptible instances for non-critical workloads

_Estimates based on standard instance pricing as of 2024. Actual costs may vary based on region, discounts, and usage patterns._

📊 For real-time cost monitoring after deployment, see [Cost Monitoring Guide](../blob/main/k8s/COST_MONITORING.md)

---
<sub>🤖 This comment will be automatically updated when new commits are pushed.</sub>
EOF

echo "Cost report generated: $OUTPUT_FILE"

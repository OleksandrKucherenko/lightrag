#!/usr/bin/env bash
#
# Generate plain Kubernetes manifests from Helm chart
# This script creates k8s/generated/ directory with manifests from Helm templates
#
# Usage:
#   ./generate-from-helm.sh [output-dir] [values-file]
#
# Examples:
#   ./generate-from-helm.sh                          # Generate to k8s/generated/
#   ./generate-from-helm.sh ../deploy                # Generate to ../deploy/
#   ./generate-from-helm.sh . my-values.yaml         # Generate here with custom values
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default configuration
OUTPUT_DIR="${1:-generated}"
VALUES_FILE="${2:-}"
HELM_CHART="../helm/lightrag"
RELEASE_NAME="lightrag"
NAMESPACE="lightrag"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Generate Plain K8s Manifests from Helm Chart             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}⚠  Helm not found. Installing is recommended but not required.${NC}"
    echo ""
    echo "To install Helm:"
    echo "  Linux:   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    echo "  macOS:   brew install helm"
    echo "  Windows: choco install kubernetes-helm"
    echo ""
    exit 1
fi

# Check if chart exists
if [ ! -d "$HELM_CHART" ]; then
    echo -e "${YELLOW}✗ Helm chart not found at: $HELM_CHART${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found Helm chart at: $HELM_CHART"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}✓${NC} Output directory: $OUTPUT_DIR"

# Build helm template command
HELM_CMD="helm template $RELEASE_NAME $HELM_CHART --namespace $NAMESPACE"

if [ -n "$VALUES_FILE" ] && [ -f "$VALUES_FILE" ]; then
    HELM_CMD="$HELM_CMD --values $VALUES_FILE"
    echo -e "${GREEN}✓${NC} Using values file: $VALUES_FILE"
else
    echo -e "${BLUE}ℹ${NC}  Using default values"
fi

# Add common  settings for plain manifests
HELM_CMD="$HELM_CMD \
  --set ingress.enabled=true \
  --set ingress.className=nginx"

echo ""
echo "Generating manifests..."
echo ""

# Generate all manifests
$HELM_CMD > "$OUTPUT_DIR/lightrag-all.yaml"

echo -e "${GREEN}✓${NC} Generated: $OUTPUT_DIR/lightrag-all.yaml (all resources)"

# Split into individual files by kind
echo ""
echo "Splitting into individual files..."

# Use csplit or awk to split the YAML
awk '
BEGIN { file_num = 0; prefix = "'$OUTPUT_DIR'/"; }
/^---$/ {
    if (NR > 1) {
        close(filename);
        file_num++;
    }
    next;
}
/^# Source:/ {
    gsub(/^# Source: /, "");
    gsub(/\//, "-");
    gsub(/\.yaml$/, "");
    filename = prefix $0 ".yaml";
    print "# Source: " $0 > filename;
    next;
}
/^kind:/ {
    kind = $2;
    if (filename == "") {
        filename = prefix sprintf("%02d-", file_num) tolower(kind) ".yaml";
    }
}
/^  name:/ {
    if (name == "") {
        name = $2;
        if (filename == "") {
            filename = prefix sprintf("%02d-%s-%s.yaml", file_num, tolower(kind), name);
        }
    }
}
{
    if (filename != "") {
        print > filename;
    }
}
' "$OUTPUT_DIR/lightrag-all.yaml"

# Count generated files
NUM_FILES=$(ls -1 "$OUTPUT_DIR"/*.yaml 2>/dev/null | wc -l)

echo -e "${GREEN}✓${NC} Split into $NUM_FILES individual files"
echo ""

# List generated files
echo "Generated files:"
ls -lh "$OUTPUT_DIR"/*.yaml | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Generation Complete!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "To deploy:"
echo "  kubectl apply -f $OUTPUT_DIR/"
echo ""
echo "To validate:"
echo "  kubectl apply --dry-run=client -f $OUTPUT_DIR/"
echo ""
echo "To view a specific file:"
echo "  cat $OUTPUT_DIR/lightrag-all.yaml"
echo ""

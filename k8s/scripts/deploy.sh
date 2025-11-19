#!/usr/bin/env bash
#
# LightRAG Kubernetes Deployment Script
# This script deploys the LightRAG stack to Kubernetes with validation
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -n, --namespace <name>    Namespace to deploy to (default: lightrag)
#   -s, --skip-validation     Skip post-deployment validation
#   -w, --wait               Wait for all pods to be ready before exiting
#   -h, --help               Show this help message
#
# Example:
#   ./deploy.sh --namespace production --wait
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
NAMESPACE="lightrag"
SKIP_VALIDATION=false
WAIT_READY=false
TIMEOUT=600

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
LightRAG Kubernetes Deployment Script

Usage: $0 [options]

Options:
  -n, --namespace <name>    Namespace to deploy to (default: lightrag)
  -s, --skip-validation     Skip post-deployment validation
  -w, --wait               Wait for all pods to be ready before exiting
  -h, --help               Show this help message

Example:
  $0 --namespace production --wait

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -s|--skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            -w|--wait)
                WAIT_READY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if using kustomize
    if [ -f "$K8S_DIR/kustomization.yaml" ]; then
        log_info "Using Kustomize deployment"
        DEPLOY_METHOD="kustomize"
    else
        log_info "Using plain kubectl deployment"
        DEPLOY_METHOD="kubectl"
    fi

    log_success "Prerequisites check passed"
}

# Validate secrets
validate_secrets() {
    log_info "Checking secrets configuration..."

    local secrets_file="$K8S_DIR/02-secrets.yaml"

    if [ ! -f "$secrets_file" ]; then
        log_error "Secrets file not found: $secrets_file"
        exit 1
    fi

    # Check for placeholder values
    if grep -q "Y2hhbmdlLW1l" "$secrets_file"; then
        log_warning "Detected placeholder values in secrets file"
        log_warning "Please update $secrets_file with your actual base64-encoded secrets"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "Secrets configuration validated"
}

# Deploy resources
deploy_resources() {
    log_info "=== Starting LightRAG Deployment ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Deployment method: $DEPLOY_METHOD"
    echo ""

    cd "$K8S_DIR"

    if [ "$DEPLOY_METHOD" = "kustomize" ]; then
        log_info "Deploying with kustomize..."
        kubectl apply -k .
    else
        log_info "Deploying with kubectl..."

        # Deploy in order
        local files=(
            "00-namespace.yaml"
            "01-configmaps.yaml"
            "02-secrets.yaml"
            "03-storage.yaml"
            "04-redis.yaml"
            "05-memgraph.yaml"
            "06-qdrant.yaml"
            "07-lightrag.yaml"
            "08-lobechat.yaml"
            "09-monitor.yaml"
            "10-ingress.yaml"
        )

        for file in "${files[@]}"; do
            if [ -f "$file" ]; then
                log_info "Applying $file..."
                kubectl apply -f "$file"
            else
                log_warning "File not found: $file (skipping)"
            fi
        done
    fi

    log_success "Resources deployed successfully"
    echo ""
}

# Wait for pods
wait_for_pods() {
    if [ "$WAIT_READY" = false ]; then
        return 0
    fi

    log_info "Waiting for pods to be ready..."

    # Wait for databases first
    local components=(
        "redis:app.kubernetes.io/name=redis"
        "memgraph:app.kubernetes.io/name=memgraph"
        "qdrant:app.kubernetes.io/name=qdrant"
        "lightrag:app.kubernetes.io/name=lightrag"
        "lobechat:app.kubernetes.io/name=lobechat"
    )

    for component_label in "${components[@]}"; do
        IFS=':' read -r component label <<< "$component_label"

        log_info "Waiting for $component..."
        if kubectl wait --for=condition=ready pod \
            -l "$label" \
            -n "$NAMESPACE" \
            --timeout="${TIMEOUT}s" 2>&1 | grep -v "no matching resources found"; then
            log_success "$component is ready"
        else
            log_warning "$component: no pods found or timeout"
        fi
    done

    echo ""
    log_success "All pods are ready"
}

# Run validation
run_validation() {
    if [ "$SKIP_VALIDATION" = true ]; then
        log_info "Skipping validation (--skip-validation flag set)"
        return 0
    fi

    local validation_script="$SCRIPT_DIR/validate.sh"

    if [ ! -f "$validation_script" ]; then
        log_warning "Validation script not found: $validation_script"
        return 0
    fi

    log_info "=== Running Post-Deployment Validation ==="
    echo ""

    if bash "$validation_script" "$NAMESPACE"; then
        log_success "Validation passed"
        return 0
    else
        log_error "Validation failed"
        return 1
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    log_info "=== Deployment Complete ==="
    echo ""
    log_info "Next steps:"
    echo ""
    log_info "1. Check deployment status:"
    echo "   kubectl get pods -n $NAMESPACE"
    echo ""
    log_info "2. View logs:"
    echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=lightrag --tail=50 -f"
    echo ""
    log_info "3. Access services (port-forward):"
    echo "   kubectl port-forward -n $NAMESPACE svc/lobechat 3210:3210"
    echo "   kubectl port-forward -n $NAMESPACE svc/lightrag 9621:9621"
    echo ""
    log_info "4. Or configure ingress DNS:"
    log_info "   Get ingress IP: kubectl get ingress -n $NAMESPACE"
    log_info "   Add to /etc/hosts: <IP> chat.dev.localhost rag.dev.localhost"
    echo ""
    log_info "For troubleshooting, see: $K8S_DIR/README.md"
    echo ""
}

# Cleanup on error
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Deployment failed with exit code $exit_code"
        log_info "To view deployment status: kubectl get pods -n $NAMESPACE"
        log_info "To view logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/part-of=lightrag-stack --tail=100"
    fi
}

trap cleanup EXIT

# Main execution
main() {
    parse_args "$@"

    log_info "=== LightRAG Kubernetes Deployment Script ==="
    echo ""

    check_prerequisites
    echo ""

    validate_secrets
    echo ""

    deploy_resources

    wait_for_pods

    run_validation

    show_next_steps
}

main "$@"

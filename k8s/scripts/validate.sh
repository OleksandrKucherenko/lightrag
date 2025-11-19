#!/usr/bin/env bash
#
# LightRAG Kubernetes Deployment Validation Script
# This script validates that all components are healthy and running
#
# Usage:
#   ./validate.sh [namespace]
#
# Default namespace: lightrag
#

set -euo pipefail

# Configuration
NAMESPACE="${1:-lightrag}"
TIMEOUT="${TIMEOUT:-600}"  # 10 minutes
CHECK_INTERVAL=5

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

# Check if namespace exists
check_namespace() {
    log_info "Checking if namespace '$NAMESPACE' exists..."
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    log_success "Namespace exists"
}

# Wait for pods to be ready
wait_for_pods() {
    local component=$1
    local label=$2
    local timeout=$3

    log_info "Waiting for $component pods to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$NAMESPACE" \
        --timeout="${timeout}s" &> /dev/null; then
        log_success "$component pods are ready"
        return 0
    else
        log_error "$component pods failed to become ready"
        kubectl get pods -l "$label" -n "$NAMESPACE"
        return 1
    fi
}

# Check service endpoints
check_service() {
    local service=$1
    log_info "Checking service '$service'..."

    if ! kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
        log_error "Service '$service' not found"
        return 1
    fi

    local endpoints
    endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

    if [ -z "$endpoints" ]; then
        log_warning "Service '$service' has no endpoints"
        return 1
    fi

    log_success "Service '$service' has endpoints: $endpoints"
}

# Check PVC status
check_pvcs() {
    log_info "Checking PersistentVolumeClaims..."

    local pending_pvcs
    pending_pvcs=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase!="Bound")].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$pending_pvcs" ]; then
        log_error "Some PVCs are not bound: $pending_pvcs"
        kubectl get pvc -n "$NAMESPACE"
        return 1
    fi

    log_success "All PVCs are bound"
}

# Test HTTP endpoint
test_http_endpoint() {
    local service=$1
    local port=$2
    local path=$3
    local expected_code=${4:-200}

    log_info "Testing HTTP endpoint: http://$service:$port$path"

    # Use a temporary pod to test internal connectivity
    local response_code
    response_code=$(kubectl run curl-test-$$-$RANDOM \
        --image=curlimages/curl:latest \
        --rm -i --restart=Never \
        --namespace="$NAMESPACE" \
        -- curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        --max-time 10 \
        "http://$service:$port$path" 2>/dev/null || echo "000")

    if [ "$response_code" = "$expected_code" ]; then
        log_success "HTTP endpoint responded with $response_code"
        return 0
    else
        log_error "HTTP endpoint responded with $response_code (expected $expected_code)"
        return 1
    fi
}

# Main validation flow
main() {
    log_info "=== LightRAG Kubernetes Deployment Validation ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Timeout: ${TIMEOUT}s"
    echo ""

    local failed=0

    # 1. Check namespace
    check_namespace || ((failed++))
    echo ""

    # 2. Check PVCs
    check_pvcs || ((failed++))
    echo ""

    # 3. Wait for database pods
    log_info "=== Checking Database Components ==="
    wait_for_pods "Redis" "app.kubernetes.io/name=redis" "$TIMEOUT" || ((failed++))
    wait_for_pods "Memgraph" "app.kubernetes.io/name=memgraph" "$TIMEOUT" || ((failed++))
    wait_for_pods "Qdrant" "app.kubernetes.io/name=qdrant" "$TIMEOUT" || ((failed++))
    echo ""

    # 4. Wait for application pods
    log_info "=== Checking Application Components ==="
    wait_for_pods "LightRAG" "app.kubernetes.io/name=lightrag" "$TIMEOUT" || ((failed++))
    wait_for_pods "LobeChat" "app.kubernetes.io/name=lobechat" "$TIMEOUT" || ((failed++))
    echo ""

    # 5. Check services
    log_info "=== Checking Services ==="
    check_service "redis" || ((failed++))
    check_service "memgraph" || ((failed++))
    check_service "qdrant" || ((failed++))
    check_service "lightrag" || ((failed++))
    check_service "lobechat" || ((failed++))
    echo ""

    # 6. Test HTTP endpoints
    log_info "=== Testing HTTP Endpoints ==="
    test_http_endpoint "lightrag" "9621" "/health" "200" || ((failed++))
    test_http_endpoint "qdrant" "6333" "/" "200" || ((failed++))
    test_http_endpoint "lobechat" "3210" "/" "200" || ((failed++))
    echo ""

    # 7. Check ingress (if exists)
    log_info "=== Checking Ingress ==="
    if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
        local ingress_count
        ingress_count=$(kubectl get ingress -n "$NAMESPACE" -o json | jq '.items | length')
        log_success "Found $ingress_count ingress resource(s)"

        # Display ingress info
        kubectl get ingress -n "$NAMESPACE" -o custom-columns=\
NAME:.metadata.name,\
HOSTS:.spec.rules[*].host,\
ADDRESS:.status.loadBalancer.ingress[*].ip 2>/dev/null || true
    else
        log_warning "No ingress resources found"
    fi
    echo ""

    # 8. Summary
    log_info "=== Deployment Summary ==="
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""

    if [ $failed -eq 0 ]; then
        log_success "✓ All validation checks passed!"
        log_info "Your LightRAG deployment is healthy and ready to use"
        echo ""
        log_info "Access your services:"
        log_info "  - LobeChat UI: kubectl port-forward -n $NAMESPACE svc/lobechat 3210:3210"
        log_info "  - LightRAG API: kubectl port-forward -n $NAMESPACE svc/lightrag 9621:9621"
        log_info "  - Memgraph Lab: kubectl port-forward -n $NAMESPACE svc/memgraph-lab 3000:3000"
        log_info "  - Qdrant UI: kubectl port-forward -n $NAMESPACE svc/qdrant 6333:6333"
        return 0
    else
        log_error "✗ $failed validation check(s) failed"
        log_error "Please review the errors above and check pod logs:"
        log_error "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/part-of=lightrag-stack --tail=50"
        return 1
    fi
}

# Run main function
main "$@"

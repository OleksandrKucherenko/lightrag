#!/usr/bin/env bash
#
# LightRAG Kubernetes Deployment Verification Script
# Verifies that all components are deployed and healthy
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="lightrag"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[✓ PASS]${NC} $1"
  ((PASSED++))
}

log_warning() {
  echo -e "${YELLOW}[⚠ WARN]${NC} $1"
  ((WARNINGS++))
}

log_error() {
  echo -e "${RED}[✗ FAIL]${NC} $1"
  ((FAILED++))
}

# Check if kubectl is available
check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
  fi
  log_success "kubectl is installed"
}

# Check cluster connection
check_cluster() {
  if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
  fi
  log_success "Connected to Kubernetes cluster"
}

# Check namespace
check_namespace() {
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_success "Namespace '$NAMESPACE' exists"
  else
    log_error "Namespace '$NAMESPACE' does not exist"
  fi
}

# Check ConfigMaps
check_configmaps() {
  log_info "Checking ConfigMaps..."

  local configmaps=("lightrag-config" "lobechat-config")
  for cm in "${configmaps[@]}"; do
    if kubectl get configmap "$cm" -n "$NAMESPACE" &>/dev/null; then
      log_success "ConfigMap '$cm' exists"
    else
      log_error "ConfigMap '$cm' not found"
    fi
  done
}

# Check Secrets
check_secrets() {
  log_info "Checking Secrets..."

  local secrets=("lightrag-secrets" "redis-secret")
  for secret in "${secrets[@]}"; do
    if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
      log_success "Secret '$secret' exists"
    else
      log_error "Secret '$secret' not found"
    fi
  done
}

# Check PVCs
check_pvcs() {
  log_info "Checking PersistentVolumeClaims..."

  local pvcs=(
    "redis-data"
    "memgraph-data"
    "memgraph-log"
    "qdrant-storage"
    "qdrant-snapshots"
    "lightrag-storage"
    "lightrag-inputs"
    "lightrag-logs"
    "lobechat-data"
  )

  for pvc in "${pvcs[@]}"; do
    local status=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$status" == "Bound" ]; then
      log_success "PVC '$pvc' is Bound"
    elif [ -n "$status" ]; then
      log_warning "PVC '$pvc' is in '$status' state"
    else
      log_error "PVC '$pvc' not found"
    fi
  done
}

# Check Pods
check_pods() {
  log_info "Checking Pods..."

  local apps=(
    "redis"
    "memgraph"
    "memgraph-lab"
    "qdrant"
    "lightrag"
    "lobechat"
  )

  for app in "${apps[@]}"; do
    local pod_status=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app" \
      -o jsonpath='{.items[0].status.phase}' 2>/dev/null)

    if [ "$pod_status" == "Running" ]; then
      log_success "Pod '$app' is Running"

      # Check if pod is ready
      local ready=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app" \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

      if [ "$ready" == "True" ]; then
        log_success "Pod '$app' is Ready"
      else
        log_warning "Pod '$app' is Running but not Ready"
      fi
    elif [ -n "$pod_status" ]; then
      log_warning "Pod '$app' is in '$pod_status' state"
    else
      log_error "Pod '$app' not found"
    fi
  done
}

# Check Services
check_services() {
  log_info "Checking Services..."

  local services=(
    "redis"
    "memgraph"
    "memgraph-lab"
    "qdrant"
    "lightrag"
    "lobechat"
  )

  for svc in "${services[@]}"; do
    if kubectl get service "$svc" -n "$NAMESPACE" &>/dev/null; then
      local cluster_ip=$(kubectl get service "$svc" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
      log_success "Service '$svc' exists (ClusterIP: $cluster_ip)"
    else
      log_error "Service '$svc' not found"
    fi
  done
}

# Check Ingress
check_ingress() {
  log_info "Checking Ingress..."

  if kubectl get ingress -n "$NAMESPACE" &>/dev/null; then
    log_success "Ingress resources exist"

    # Check if ingress has an IP/hostname
    local ingress_ip=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$ingress_ip" ]; then
      ingress_ip=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    fi

    if [ -n "$ingress_ip" ]; then
      log_success "Ingress has external access: $ingress_ip"
    else
      log_warning "Ingress IP/hostname not yet assigned (may take a few minutes)"
    fi
  else
    log_error "No Ingress resources found"
  fi
}

# Check resource versions
check_versions() {
  log_info "Checking container image versions..."

  # Check that no containers use :latest tag
  local latest_images=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | grep ':latest' || true)

  if [ -z "$latest_images" ]; then
    log_success "No containers using :latest tag"
  else
    log_error "Found containers using :latest tag:"
    echo "$latest_images" | while read -r img; do
      echo "  - $img"
    done
  fi
}

# Check database connectivity (basic)
check_database_connectivity() {
  log_info "Checking database connectivity..."

  # Redis
  if kubectl exec -n "$NAMESPACE" deployment/lightrag -- timeout 5 nc -zv redis 6379 &>/dev/null; then
    log_success "LightRAG can reach Redis"
  else
    log_warning "LightRAG cannot reach Redis (may not be ready yet)"
  fi

  # Memgraph
  if kubectl exec -n "$NAMESPACE" deployment/lightrag -- timeout 5 nc -zv memgraph 7687 &>/dev/null; then
    log_success "LightRAG can reach Memgraph"
  else
    log_warning "LightRAG cannot reach Memgraph (may not be ready yet)"
  fi

  # Qdrant
  if kubectl exec -n "$NAMESPACE" deployment/lightrag -- timeout 5 nc -zv qdrant 6333 &>/dev/null; then
    log_success "LightRAG can reach Qdrant"
  else
    log_warning "LightRAG cannot reach Qdrant (may not be ready yet)"
  fi
}

# Print summary
print_summary() {
  echo ""
  echo "======================================"
  echo "  Verification Summary"
  echo "======================================"
  echo -e "${GREEN}Passed:${NC}   $PASSED"
  echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
  echo -e "${RED}Failed:${NC}   $FAILED"
  echo ""

  if [ $FAILED -eq 0 ]; then
    log_success "All critical checks passed!"
    if [ $WARNINGS -gt 0 ]; then
      log_warning "Some warnings were found - review them above"
    fi
    return 0
  else
    log_error "Some checks failed - please review the errors above"
    return 1
  fi
}

# Main verification
main() {
  echo "======================================"
  echo "  LightRAG K8s Deployment Verification"
  echo "======================================"
  echo ""

  check_kubectl
  check_cluster
  check_namespace
  check_configmaps
  check_secrets
  check_pvcs
  check_pods
  check_services
  check_ingress
  check_versions

  # Only check connectivity if pods are running
  if [ $FAILED -eq 0 ]; then
    check_database_connectivity
  fi

  print_summary
}

main "$@"

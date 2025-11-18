#!/usr/bin/env bash
#
# LightRAG Kubernetes Deployment Script
# This script helps deploy the LightRAG stack to Kubernetes
#
# Usage:
#   ./deploy.sh                 # Interactive deployment
#   ./deploy.sh --apply         # Deploy all resources
#   ./deploy.sh --delete        # Delete all resources
#   ./deploy.sh --status        # Check deployment status
#   ./deploy.sh --logs [pod]    # View logs
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
TIMEOUT="300s"

# Helper functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    log_success "Prerequisites checked"
}

# Verify secrets
verify_secrets() {
    log_warning "IMPORTANT: Please ensure you have updated the secrets in 02-secrets.yaml"
    log_warning "Default placeholder values must be replaced with actual base64-encoded secrets!"
    echo ""
    read -p "Have you updated the secrets? (yes/no): " response

    if [[ ! "$response" =~ ^[Yy]es$ ]]; then
        log_error "Please update secrets in 02-secrets.yaml before deploying"
        exit 1
    fi
}

# Deploy all resources
deploy_all() {
    log_info "Deploying LightRAG stack to Kubernetes..."

    # Check prerequisites
    check_prerequisites

    # Verify secrets
    verify_secrets

    # Create namespace
    log_info "Creating namespace..."
    kubectl apply -f 00-namespace.yaml

    # Apply configuration
    log_info "Applying ConfigMaps..."
    kubectl apply -f 01-configmaps.yaml

    log_info "Applying Secrets..."
    kubectl apply -f 02-secrets.yaml

    # Create storage
    log_info "Creating PersistentVolumeClaims..."
    kubectl apply -f 03-storage.yaml

    # Deploy databases
    log_info "Deploying Redis..."
    kubectl apply -f 04-redis.yaml
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n $NAMESPACE --timeout=$TIMEOUT || true

    log_info "Deploying Memgraph..."
    kubectl apply -f 05-memgraph.yaml
    log_info "Waiting for Memgraph to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=memgraph -n $NAMESPACE --timeout=$TIMEOUT || true

    log_info "Deploying Qdrant..."
    kubectl apply -f 06-qdrant.yaml
    log_info "Waiting for Qdrant to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=qdrant -n $NAMESPACE --timeout=$TIMEOUT || true

    # Deploy application
    log_info "Deploying LightRAG..."
    kubectl apply -f 07-lightrag.yaml
    log_info "Waiting for LightRAG to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=lightrag -n $NAMESPACE --timeout=$TIMEOUT || true

    # Deploy frontend
    log_info "Deploying LobeChat..."
    kubectl apply -f 08-lobechat.yaml

    log_info "Deploying Monitor..."
    kubectl apply -f 09-monitor.yaml

    # Deploy ingress
    log_info "Deploying Ingress..."
    kubectl apply -f 10-ingress.yaml

    log_success "Deployment complete!"
    echo ""
    show_status
}

# Delete all resources
delete_all() {
    log_warning "This will delete all LightRAG resources including data!"
    read -p "Are you sure? (yes/no): " response

    if [[ ! "$response" =~ ^[Yy]es$ ]]; then
        log_info "Deletion cancelled"
        exit 0
    fi

    log_info "Deleting LightRAG stack..."

    kubectl delete -f 10-ingress.yaml --ignore-not-found=true
    kubectl delete -f 09-monitor.yaml --ignore-not-found=true
    kubectl delete -f 08-lobechat.yaml --ignore-not-found=true
    kubectl delete -f 07-lightrag.yaml --ignore-not-found=true
    kubectl delete -f 06-qdrant.yaml --ignore-not-found=true
    kubectl delete -f 05-memgraph.yaml --ignore-not-found=true
    kubectl delete -f 04-redis.yaml --ignore-not-found=true
    kubectl delete -f 03-storage.yaml --ignore-not-found=true
    kubectl delete -f 02-secrets.yaml --ignore-not-found=true
    kubectl delete -f 01-configmaps.yaml --ignore-not-found=true

    read -p "Delete namespace (this will remove any remaining resources)? (yes/no): " ns_response
    if [[ "$ns_response" =~ ^[Yy]es$ ]]; then
        kubectl delete -f 00-namespace.yaml --ignore-not-found=true
    fi

    log_success "Deletion complete!"
}

# Show deployment status
show_status() {
    log_info "Deployment Status:"
    echo ""

    echo "=== Pods ==="
    kubectl get pods -n $NAMESPACE
    echo ""

    echo "=== Services ==="
    kubectl get svc -n $NAMESPACE
    echo ""

    echo "=== PersistentVolumeClaims ==="
    kubectl get pvc -n $NAMESPACE
    echo ""

    echo "=== Ingress ==="
    kubectl get ingress -n $NAMESPACE
    echo ""

    # Get ingress IP
    INGRESS_IP=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    if [ "$INGRESS_IP" == "pending" ] || [ -z "$INGRESS_IP" ]; then
        INGRESS_IP=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    fi

    echo "=== Access Information ==="
    if [ "$INGRESS_IP" != "pending" ] && [ -n "$INGRESS_IP" ]; then
        log_success "Ingress IP: $INGRESS_IP"
        echo ""
        echo "Add to /etc/hosts:"
        echo "$INGRESS_IP dev.localhost"
        echo "$INGRESS_IP chat.dev.localhost"
        echo "$INGRESS_IP rag.dev.localhost"
        echo "$INGRESS_IP graph.dev.localhost"
        echo "$INGRESS_IP vector.dev.localhost"
        echo ""
        echo "Then access:"
        echo "  LobeChat: https://chat.dev.localhost"
        echo "  LightRAG: https://rag.dev.localhost"
        echo "  Memgraph: https://graph.dev.localhost"
        echo "  Qdrant:   https://vector.dev.localhost"
    else
        log_warning "Ingress IP not yet assigned"
        echo ""
        echo "Use port-forwarding instead:"
        echo "  kubectl port-forward -n $NAMESPACE svc/lobechat 3210:3210"
        echo "  kubectl port-forward -n $NAMESPACE svc/lightrag 9621:9621"
    fi
}

# View logs
show_logs() {
    local pod_selector=$1

    if [ -z "$pod_selector" ]; then
        echo "Available pods:"
        kubectl get pods -n $NAMESPACE
        echo ""
        read -p "Enter pod name or label selector: " pod_selector
    fi

    # Check if it's a pod name or label
    if [[ "$pod_selector" == *"="* ]]; then
        log_info "Showing logs for pods matching: $pod_selector"
        kubectl logs -n $NAMESPACE -l "$pod_selector" --tail=100 -f
    else
        log_info "Showing logs for pod: $pod_selector"
        kubectl logs -n $NAMESPACE "$pod_selector" --tail=100 -f
    fi
}

# Interactive menu
interactive_menu() {
    echo "======================================"
    echo "  LightRAG Kubernetes Deployment"
    echo "======================================"
    echo ""
    echo "1) Deploy all resources"
    echo "2) Delete all resources"
    echo "3) Show deployment status"
    echo "4) View logs"
    echo "5) Port forward services"
    echo "6) Exit"
    echo ""
    read -p "Select option: " option

    case $option in
        1) deploy_all ;;
        2) delete_all ;;
        3) show_status ;;
        4) show_logs ;;
        5) port_forward_menu ;;
        6) exit 0 ;;
        *) log_error "Invalid option"; interactive_menu ;;
    esac
}

# Port forward menu
port_forward_menu() {
    echo ""
    echo "Port Forwarding Options:"
    echo "1) LobeChat (3210)"
    echo "2) LightRAG (9621)"
    echo "3) Memgraph Lab (3000)"
    echo "4) Qdrant (6333)"
    echo "5) Redis (6379)"
    echo "6) Back to main menu"
    echo ""
    read -p "Select service: " svc_option

    case $svc_option in
        1) kubectl port-forward -n $NAMESPACE svc/lobechat 3210:3210 ;;
        2) kubectl port-forward -n $NAMESPACE svc/lightrag 9621:9621 ;;
        3) kubectl port-forward -n $NAMESPACE svc/memgraph-lab 3000:3000 ;;
        4) kubectl port-forward -n $NAMESPACE svc/qdrant 6333:6333 ;;
        5) kubectl port-forward -n $NAMESPACE svc/redis 6379:6379 ;;
        6) interactive_menu ;;
        *) log_error "Invalid option"; port_forward_menu ;;
    esac
}

# Main script
main() {
    case "${1:-}" in
        --apply|apply|deploy)
            deploy_all
            ;;
        --delete|delete|remove)
            delete_all
            ;;
        --status|status)
            show_status
            ;;
        --logs|logs)
            show_logs "$2"
            ;;
        --help|help|-h)
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --apply     Deploy all resources"
            echo "  --delete    Delete all resources"
            echo "  --status    Show deployment status"
            echo "  --logs      View logs (optionally specify pod)"
            echo "  --help      Show this help message"
            echo ""
            echo "No options = Interactive menu"
            ;;
        *)
            interactive_menu
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
#
# Quick verification for K8s deployment on WSL2
# Run this after deploying to check basic functionality
#

set -e

echo "==================================="
echo "  Quick K8s Deployment Check"
echo "==================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo "❌ kubectl not found"
  echo ""
  echo "Install on WSL2 Ubuntu:"
  echo "  curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
  echo "  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
  exit 1
fi

echo "✓ kubectl found"

# Check cluster connection
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Cannot connect to cluster"
  echo ""
  echo "If using KIND, create cluster:"
  echo "  kind create cluster --name lightrag"
  exit 1
fi

echo "✓ Connected to cluster"

# Check namespace
if ! kubectl get namespace lightrag &>/dev/null; then
  echo "❌ Namespace 'lightrag' not found"
  echo ""
  echo "Deploy first:"
  echo "  cd /mnt/wsl/workspace/rag/k8s"
  echo "  ./deploy.sh --apply"
  exit 1
fi

echo "✓ Namespace exists"

# Quick pod check
echo ""
echo "Pod Status:"
kubectl get pods -n lightrag -o wide

echo ""
echo "Service Status:"
kubectl get svc -n lightrag

echo ""
echo "==================================="
echo "For detailed verification, run:"
echo "  ./verify-deployment.sh"
echo ""
echo "To access services locally:"
echo "  kubectl port-forward -n lightrag svc/lobechat 3210:3210 &"
echo "  kubectl port-forward -n lightrag svc/lightrag 9621:9621 &"
echo "==================================="

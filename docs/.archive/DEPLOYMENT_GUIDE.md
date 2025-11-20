# LightRAG Kubernetes Deployment Guide

## Quick Start with MISE (Recommended)

### 1. Prerequisites (WSL2 Ubuntu)
```bash
# Install mise (manages kubectl, kind, sops, age automatically)
brew install mise

# Navigate to project
cd /mnt/wsl/workspace/rag

# Trust mise configuration
mise trust

# Install all required tools
mise install
```

### Alternative: Manual Tool Installation
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install KIND (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify Docker is running
docker info
```

### 2. Setup Secrets (MISE Method - Recommended)
```bash
cd /mnt/wsl/workspace/rag

# Generate encryption key (one-time setup)
age-keygen -o .secrets/mise-age.txt
mkdir -p ~/.config/mise
cp .secrets/mise-age.txt ~/.config/mise/age.txt

# Create and edit secrets file
cp .env.secrets.example.json .env.secrets.json
nano .env.secrets.json  # Add your OpenAI API keys

# Encrypt secrets
PUBLIC_KEY=$(grep 'public key:' .secrets/mise-age.txt | cut -d: -f2 | xargs)
sops encrypt -i --age "$PUBLIC_KEY" .env.secrets.json
```

### 3. Deploy Everything (MISE Method)
```bash
# Create cluster
mise run k8s-cluster-create

# Generate secrets and deploy
mise run k8s-deploy

# This automatically:
# - Generates K8s secrets from mise environment
# - Deploys all resources
# - Waits for pods to be ready
```

### Alternative: Manual Deployment
```bash
# Create KIND cluster
kind create cluster --name lightrag

# Update secrets manually
cd /mnt/wsl/workspace/rag/k8s
nano 02-secrets.yaml  # Replace with base64-encoded values

# Deploy
./deploy.sh --apply
```

### 4. Verify Deployment
```bash
# Quick verification (recommended - built into deploy.sh)
mise run k8s-verify
# or: cd k8s && ./deploy.sh --verify

# Full comprehensive verification (all tests)
mise run k8s-verify-full
# or: cd k8s && ./verify-deployment.sh

# Just show status
mise run k8s-status
# or: cd k8s && ./deploy.sh --status

# Note: deploy.sh --apply automatically runs verification after deployment
```

### 5. Access Services
```bash
# MISE method (easiest - manages all ports)
mise run k8s-port-forward

# Or manual
kubectl port-forward -n lightrag svc/lobechat 3210:3210 &
kubectl port-forward -n lightrag svc/lightrag 9621:9621 &
kubectl port-forward -n lightrag svc/memgraph-lab 3000:3000 &

# Access in browser:
# - LobeChat: http://localhost:3210
# - LightRAG API: http://localhost:9621
# - Memgraph Lab: http://localhost:3000
```

## What Was Fixed

### Issue 1: LobeChat Using :latest Tag ❌
**Problem:** Unpredictable behavior, update surprises  
**Fix:** Changed to concrete version `v1.31.5`  
**File:** `08-lobechat.yaml`

### Issue 2: Wrong API Path ❌
**Problem:** `OLLAMA_PROXY_URL` had `/v1` suffix causing API failures  
**Fix:** Removed `/v1` - LightRAG uses Ollama API, not OpenAI  
**File:** `01-configmaps.yaml`

### Issue 3: Monitor Service Incompatible ❌
**Problem:** Isaiah requires Docker socket (not available in K8s)  
**Fix:** Disabled monitor, documented K8s-native alternatives  
**Files:** `09-monitor.yaml`, `deploy.sh`

## Monitoring in Kubernetes

Instead of Isaiah/lazydocker, use K8s-native tools:

### Terminal Tools
```bash
# kubectl commands
kubectl top pods -n lightrag
kubectl top nodes
kubectl get events -n lightrag --sort-by='.lastTimestamp'
kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --follow

# k9s - Interactive terminal UI
k9s -n lightrag
```

### GUI Tools
```bash
# Kubernetes Dashboard
kubectl proxy
# Visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

# Lens Desktop (https://k8slens.dev/)
# Download and install, then add your cluster
```

## Troubleshooting

### Pods Stuck in Pending
```bash
# Check PVC status
kubectl get pvc -n lightrag

# Check events
kubectl get events -n lightrag --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n lightrag <pod-name>
```

### Connection Errors
```bash
# Test connectivity from a pod
kubectl run -n lightrag test-pod --image=busybox --rm -it -- /bin/sh

# Inside the pod:
nc -zv redis 6379
nc -zv memgraph 7687
nc -zv qdrant 6333
nc -zv lightrag 9621
```

### View Logs
```bash
# All pods
kubectl logs -n lightrag --all-containers=true --tail=50

# Specific service
kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --tail=100

# Previous crashed container
kubectl logs -n lightrag <pod-name> --previous
```

## Clean Up

### Delete Deployment
```bash
# Delete all resources (keeps data)
./deploy.sh --delete

# Complete cleanup including namespace
kind delete cluster --name lightrag
```

## Files Structure

```
k8s/
├── 00-namespace.yaml          # Namespace definition
├── 01-configmaps.yaml         # Configuration data (✓ FIXED: removed /v1)
├── 02-secrets.yaml            # Sensitive data (⚠️ UPDATE THIS!)
├── 03-storage.yaml            # PersistentVolumeClaims
├── 04-redis.yaml              # Redis StatefulSet
├── 05-memgraph.yaml           # Memgraph + Lab
├── 06-qdrant.yaml             # Qdrant vector DB
├── 07-lightrag.yaml           # LightRAG application
├── 08-lobechat.yaml           # LobeChat frontend (✓ FIXED: version)
├── 09-monitor.yaml            # Monitor (✗ DISABLED for K8s)
├── 10-ingress.yaml            # Ingress configuration
├── deploy.sh                  # Deployment script (✓ UPDATED)
├── verify-deployment.sh       # Full verification (✓ NEW)
├── quick-verify.sh            # Quick check (✓ NEW)
├── K8S_FIXES.md              # Detailed fix documentation (✓ NEW)
└── DEPLOYMENT_GUIDE.md       # This file (✓ NEW)
```

## Production Considerations

### Storage Classes
For cloud deployments, update `03-storage.yaml`:
- **AWS**: Use `gp3` or `io1` storageClass
- **Azure**: Use `managed-premium`
- **GCP**: Use `ssd`

### Resource Limits
Adjust in respective YAML files based on workload:
- Redis: 512Mi-1Gi RAM
- Memgraph: 1Gi-8Gi RAM
- Qdrant: 2Gi-4Gi RAM
- LightRAG: 2Gi-4Gi RAM

### High Availability
Scale replicas for production:
```bash
kubectl scale deployment -n lightrag lightrag --replicas=3
kubectl scale deployment -n lightrag lobechat --replicas=2
```

### Monitoring Stack
For production, deploy:
- Prometheus + Grafana (metrics)
- EFK/ELK Stack (logging)
- Jaeger (tracing)

## Support

- **Documentation**: See `K8S_FIXES.md` for detailed explanations
- **Verification**: Run `./verify-deployment.sh` for health checks
- **Logs**: Use `kubectl logs` to debug issues
- **Events**: Check `kubectl get events -n lightrag` for cluster events

## Version Policy

| Environment    | Version Strategy  | Example                     |
| -------------- | ----------------- | --------------------------- |
| docker-compose | `:latest` allowed | `lobehub/lobe-chat:latest`  |
| Kubernetes     | Concrete versions | `lobehub/lobe-chat:v1.31.5` |

**Rationale:**
- **Development (docker-compose)**: Fast iteration, auto-updates
- **Production (K8s)**: Stability, predictability, auditability

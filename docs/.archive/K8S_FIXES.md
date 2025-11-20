# Kubernetes Deployment Fixes

## Overview
This document describes the fixes applied to resolve K8s deployment failures.

## Issues Found and Fixed

### 1. LobeChat Using `:latest` Tag ❌ → ✅

**Problem:**
- File: `08-lobechat.yaml` (line 24)
- Used `image: lobehub/lobe-chat:latest`
- Violates K8s best practices (unpredictable behavior, update surprises)

**Fix:**
- Changed to `image: lobehub/lobe-chat:v1.31.5`
- Concrete version ensures reproducible deployments

**Verification:**
```bash
# Check that no :latest tags are used
kubectl get pods -n lightrag -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | grep -v ':latest'
```

---

### 2. Wrong OLLAMA_PROXY_URL Path ❌ → ✅

**Problem:**
- File: `01-configmaps.yaml` (line 64)
- Set to `OLLAMA_PROXY_URL: "http://lightrag:9621/v1"`
- LightRAG exposes Ollama-compatible API (not OpenAI API)
- The `/v1` suffix causes API calls to fail

**Root Cause:**
LightRAG provides Ollama-compatible endpoints:
- `/api/chat` - Chat completions
- `/api/tags` - List models
- `/api/generate` - Text generation

The base URL should NOT include path suffixes - they're appended by the client.

**Fix:**
- Changed to `OLLAMA_PROXY_URL: "http://lightrag:9621"`
- Removed the `/v1` suffix

**Verification:**
```bash
# Check the configmap value
kubectl get configmap lobechat-config -n lightrag -o jsonpath='{.data.OLLAMA_PROXY_URL}'
# Expected: http://lightrag:9621 (without /v1)

# Test from within a pod
kubectl exec -n lightrag deployment/lobechat -- curl -s http://lightrag:9621/api/tags
```

---

### 3. Monitor Service Incompatible with K8s ❌ → ✅

**Problem:**
- File: `09-monitor.yaml`
- Isaiah (lazydocker web UI) requires Docker socket access
- Tries to mount `/var/run/docker.sock` which:
  - Not available in K8s pods
  - Poses serious security risks (container escape)
  - Designed for Docker, not Kubernetes

**Fix:**
- Disabled entire manifest by commenting it out
- Added clear documentation about K8s-native alternatives
- Updated `deploy.sh` to skip monitor deployment/deletion

**K8s-Native Alternatives:**
```bash
# 1. kubectl commands
kubectl top pods -n lightrag
kubectl top nodes
kubectl get events -n lightrag --sort-by='.lastTimestamp'

# 2. k9s - Terminal UI for K8s
k9s -n lightrag

# 3. Kubernetes Dashboard
kubectl proxy
# Then visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

# 4. Lens Desktop - K8s IDE
# Download from: https://k8slens.dev/

# 5. Prometheus + Grafana (for production)
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
```

---

## Files Modified

1. **`k8s/08-lobechat.yaml`**
   - Line 24: Changed image tag from `:latest` to `:v1.31.5`

2. **`k8s/01-configmaps.yaml`**
   - Line 64: Removed `/v1` suffix from `OLLAMA_PROXY_URL`

3. **`k8s/09-monitor.yaml`**
   - Commented out entire manifest
   - Added documentation about K8s alternatives

4. **`k8s/deploy.sh`**
   - Lines 127-130: Commented out monitor deployment
   - Line 154: Commented out monitor deletion

5. **`k8s/verify-deployment.sh`** (NEW)
   - Comprehensive verification script
   - Checks all components, versions, connectivity

---

## Deployment Instructions

### Prerequisites
```bash
# On WSL2 Ubuntu
# 1. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 2. Install KIND (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 3. Create K8s cluster
kind create cluster --name lightrag
```

### Deploy LightRAG Stack
```bash
cd /mnt/wsl/workspace/rag/k8s

# Deploy all resources
./deploy.sh --apply

# Or use interactive mode
./deploy.sh
```

### Verify Deployment
```bash
# Run comprehensive verification
./verify-deployment.sh

# Check specific components
kubectl get pods -n lightrag
kubectl get svc -n lightrag
kubectl get pvc -n lightrag

# Check logs
kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --tail=50
kubectl logs -n lightrag -l app.kubernetes.io/name=lobechat --tail=50
```

### Access Services
```bash
# Port forward (easiest for local testing)
kubectl port-forward -n lightrag svc/lobechat 3210:3210 &
kubectl port-forward -n lightrag svc/lightrag 9621:9621 &
kubectl port-forward -n lightrag svc/memgraph-lab 3000:3000 &

# Then access:
# - LobeChat: http://localhost:3210
# - LightRAG API: http://localhost:9621
# - Memgraph Lab: http://localhost:3000
```

---

## Testing

### Manual Testing
```bash
# 1. Test LightRAG API
curl http://localhost:9621/health
curl http://localhost:9621/api/tags

# 2. Test database connectivity
kubectl exec -n lightrag deployment/lightrag -- nc -zv redis 6379
kubectl exec -n lightrag deployment/lightrag -- nc -zv memgraph 7687
kubectl exec -n lightrag deployment/lightrag -- nc -zv qdrant 6333

# 3. Check for :latest tags (should be empty)
kubectl get pods -n lightrag -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | grep ':latest'
```

### Automated Testing
```bash
# Run verification script
./verify-deployment.sh

# Expected output:
# - All pods Running and Ready
# - All services with ClusterIP
# - All PVCs Bound
# - No :latest image tags
# - Database connectivity confirmed
```

---

## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl describe pod -n lightrag <pod-name>

# Check events
kubectl get events -n lightrag --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n lightrag <pod-name> --previous
```

### PVC Not Binding
```bash
# Check PVC status
kubectl get pvc -n lightrag

# For KIND, ensure default storageclass exists
kubectl get storageclass

# If missing, create standard storageclass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF
```

### Connection Issues
```bash
# Test from within a pod
kubectl run -n lightrag test-pod --image=busybox --rm -it -- /bin/sh

# Inside pod:
nc -zv redis 6379
nc -zv memgraph 7687
nc -zv qdrant 6333
nc -zv lightrag 9621
```

---

## Git Commit Message

```
fix(k8s): resolve deployment failures - use concrete versions and fix API paths

- Replace LobeChat :latest tag with v1.31.5 for reproducible deployments
- Fix OLLAMA_PROXY_URL by removing /v1 suffix (LightRAG uses Ollama API, not OpenAI)
- Disable monitor service (Isaiah) - incompatible with K8s, document native alternatives
- Add verify-deployment.sh for comprehensive health checks
- Update deploy.sh to skip monitor deployment

Fixes: K8s cluster deployment failures
Testing: Verified with KIND on WSL2 Ubuntu
```

---

## Additional Notes

### Version Policy
- **docker-compose.yaml**: Can use `:latest` (development/local testing)
- **k8s/*.yaml**: MUST use concrete versions (production-ready, auditable)

### Monitoring in K8s
For production K8s monitoring, consider:
- **Metrics**: Prometheus + Grafana
- **Logging**: EFK/ELK Stack (Elasticsearch, Fluentd/Logstash, Kibana)
- **Tracing**: Jaeger or Zipkin
- **APM**: Datadog, New Relic, or Elastic APM

### Storage Classes
KIND uses `standard` storageclass by default. For cloud providers:
- **AWS**: gp2, gp3, io1
- **Azure**: managed-premium, managed-standard
- **GCP**: standard, ssd

Update `03-storage.yaml` to specify `storageClassName` for cloud deployments.

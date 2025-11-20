# Kubernetes Manifests Overview

This document provides a quick reference for all Kubernetes manifests in this directory.

## File Structure

```
k8s/
├── 00-namespace.yaml          # Namespace definition
├── 01-configmaps.yaml         # Configuration (non-sensitive)
├── 02-secrets.yaml            # Secrets (MUST UPDATE before deploy!)
├── 03-storage.yaml            # PersistentVolumeClaims
├── 04-redis.yaml              # Redis StatefulSet + Service
├── 05-memgraph.yaml           # Memgraph StatefulSet + Lab + Services
├── 06-qdrant.yaml             # Qdrant StatefulSet + Service
├── 07-lightrag.yaml           # LightRAG Deployment + Service
├── 08-lobechat.yaml           # LobeChat Deployment + Service
├── 09-monitor.yaml            # Monitor Deployment + Service
├── 10-ingress.yaml            # Ingress configuration
├── kustomization.yaml         # Kustomize configuration
├── README.md                  # Full documentation
├── MANIFEST.md                # This file
├── TESTING.md                 # Testing guide with Kind
└── CLOUD_DEPLOYMENT.md        # Cloud provider deployment guides

Note: Deployment scripts (deploy.sh, validate.sh, generate-*.sh) moved to ../scripts/ folder
```

## Resource Breakdown

### 00-namespace.yaml
- **Resources**: 1 Namespace
- **Name**: `lightrag`
- **Purpose**: Isolate LightRAG stack resources

### 01-configmaps.yaml
- **Resources**: 2 ConfigMaps
- **Names**:
  - `lightrag-config` - Core configuration
  - `lobechat-config` - LobeChat settings
- **Contains**: Non-sensitive environment variables

### 02-secrets.yaml
- **Resources**: 2 Secrets
- **Names**:
  - `lightrag-secrets` - Main secrets (API keys, passwords)
  - `redis-secret` - Redis password
- **⚠️ WARNING**: Contains placeholder values - MUST UPDATE before deployment!

### 03-storage.yaml
- **Resources**: 9 PersistentVolumeClaims
- **Total Storage**: ~87Gi
- **Claims**:
  - `redis-data` (5Gi)
  - `memgraph-data` (10Gi)
  - `memgraph-log` (2Gi)
  - `qdrant-storage` (20Gi)
  - `qdrant-snapshots` (10Gi)
  - `lightrag-storage` (20Gi)
  - `lightrag-inputs` (10Gi)
  - `lightrag-logs` (5Gi)
  - `lobechat-data` (5Gi)

### 04-redis.yaml
- **Resources**: 1 StatefulSet, 1 Service
- **Image**: `redis:8-alpine`
- **Replicas**: 1
- **Resources**: 512Mi-1Gi RAM, 250m-500m CPU
- **Storage**: 5Gi
- **Port**: 6379

### 05-memgraph.yaml
- **Resources**: 2 Deployments/StatefulSets, 2 Services
- **Components**:
  - **Memgraph**: Graph database
    - Image: `memgraph/memgraph:latest`
    - Replicas: 1
    - Resources: 4Gi-8Gi RAM, 2-4 CPU
    - Storage: 10Gi data + 2Gi logs
    - Port: 7687 (Bolt)
  - **Memgraph Lab**: Web UI
    - Image: `memgraph/lab:latest`
    - Replicas: 1
    - Resources: 512Mi-1Gi RAM, 250m-500m CPU
    - Port: 3000

### 06-qdrant.yaml
- **Resources**: 1 StatefulSet, 1 Service
- **Image**: `qdrant/qdrant:latest`
- **Replicas**: 1
- **Resources**: 2Gi-4Gi RAM, 1-2 CPU
- **Storage**: 20Gi storage + 10Gi snapshots
- **Ports**: 6333 (HTTP), 6334 (gRPC)

### 07-lightrag.yaml
- **Resources**: 1 Deployment, 1 Service
- **Image**: `ghcr.io/hkuds/lightrag:latest`
- **Replicas**: 1
- **Resources**: 2Gi-4Gi RAM, 1-2 CPU
- **Storage**: 20Gi storage + 10Gi inputs + 5Gi logs
- **Port**: 9621
- **Dependencies**: Redis, Memgraph, Qdrant

### 08-lobechat.yaml
- **Resources**: 1 Deployment, 1 Service
- **Image**: `lobehub/lobe-chat:latest`
- **Replicas**: 1
- **Resources**: 512Mi-1Gi RAM, 250m-500m CPU
- **Storage**: 5Gi
- **Port**: 3210
- **Dependencies**: LightRAG, Redis

### 09-monitor.yaml
- **Resources**: 1 Deployment, 1 Service
- **Image**: `ghcr.io/will-moss/isaiah:latest`
- **Replicas**: 1
- **Resources**: 512Mi-1Gi RAM, 250m-500m CPU
- **Port**: 3000
- **Note**: Limited functionality in Kubernetes (designed for Docker)

### 10-ingress.yaml
- **Resources**: 1 Ingress
- **Controller**: NGINX (configurable)
- **Hosts**:
  - `dev.localhost` → LobeChat
  - `chat.dev.localhost` → LobeChat
  - `lobechat.dev.localhost` → LobeChat
  - `rag.dev.localhost` → LightRAG
  - `api.dev.localhost` → LightRAG (CORS-free)
  - `graph.dev.localhost` → Memgraph Lab
  - `vector.dev.localhost` → Qdrant
  - `monitor.dev.localhost` → Monitor
- **Features**: CORS enabled, increased timeouts for LLM, 100MB body size

## Total Resource Requirements

### CPU
- **Requests**: ~5 CPU cores
- **Limits**: ~10 CPU cores

### Memory
- **Requests**: ~10Gi RAM
- **Limits**: ~20Gi RAM

### Storage
- **Total**: ~87Gi

### Recommended Cluster
- **Nodes**: 2-3 nodes
- **Per Node**: 6-8 CPU, 16-32GB RAM
- **Storage**: Dynamic provisioning with 100Gi+ available

## Deployment Order

1. **Infrastructure** (00-03):
   - Namespace
   - ConfigMaps
   - Secrets (⚠️ UPDATE FIRST!)
   - Storage (PVCs)

2. **Databases** (04-06):
   - Redis → Memgraph → Qdrant
   - Wait for each to be ready before next

3. **Application** (07):
   - LightRAG
   - Depends on all databases

4. **Frontend** (08-09):
   - LobeChat
   - Monitor

5. **Networking** (10):
   - Ingress

## Quick Commands

```bash
# Deploy everything
kubectl apply -f k8s/

# Deploy with kustomize
kubectl apply -k k8s/

# Deploy with helper script
./scripts/k8s-deploy.sh --apply

# Check status
kubectl get all -n lightrag

# View logs
kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --tail=100 -f

# Delete everything
kubectl delete namespace lightrag
```

## Security Checklist

- [ ] Updated all secrets in `02-secrets.yaml`
- [ ] API keys are base64-encoded
- [ ] Secrets file not committed to git
- [ ] TLS certificates configured (if using HTTPS)
- [ ] Network policies applied (if required)
- [ ] RBAC configured (if required)
- [ ] Storage encryption enabled (if required)

## Before First Deployment

1. **Update Secrets**:
   ```bash
   # Edit 02-secrets.yaml
   # Replace ALL placeholder values with actual base64-encoded secrets
   ```

2. **Verify Storage**:
   ```bash
   # Check available storage classes
   kubectl get storageclass

   # Update 03-storage.yaml if needed (uncomment storageClassName)
   ```

3. **Check Ingress**:
   ```bash
   # Ensure ingress controller is installed
   kubectl get pods -n ingress-nginx

   # Or enable for minikube
   minikube addons enable ingress
   ```

4. **Configure DNS**:
   - Get ingress IP after deployment
   - Update `/etc/hosts` with service domains
   - Or configure actual DNS records

## Customization

### Change Domain
Edit `01-configmaps.yaml`:
```yaml
data:
  PUBLISH_DOMAIN: "your-domain.com"
```

Update ingress hosts in `10-ingress.yaml`.

### Adjust Resources
Edit resource limits in deployment files (04-09):
```yaml
resources:
  limits:
    memory: 4Gi
    cpu: 2000m
  requests:
    memory: 2Gi
    cpu: 1000m
```

### Scale Services
```bash
# Scale LobeChat
kubectl scale deployment lobechat --replicas=3 -n lightrag

# Scale LightRAG
kubectl scale deployment lightrag --replicas=2 -n lightrag
```

## Environment Variants

### Development
- Single replicas
- Lower resource limits
- Local storage (hostPath)
- Self-signed certificates

### Production
- Multiple replicas with anti-affinity
- Higher resource limits
- Network-attached storage
- Valid TLS certificates
- Secrets from external secret manager
- Network policies
- Pod security policies

## Related Documentation

- [Full Kubernetes README](README.md) - Complete deployment guide
- [Cloud Deployment Guide](CLOUD_DEPLOYMENT.md) - Deploy to Azure, AWS, GCP, DigitalOcean, Civo
- [Testing Guide](TESTING.md) - Local testing with Kind, performance testing
- [Cluster Maintenance Guide](CLUSTER_MAINTENANCE.md) - Production maintenance procedures
- [Helm Chart README](../helm/lightrag/README.md) - Helm deployment instructions
- [Main README](../README.md) - Project overview
- [Docker Compose](../docker-compose.yaml) - Alternative deployment

## Support

For issues:
1. Check [Troubleshooting](README.md#troubleshooting) section
2. Review pod logs: `kubectl logs -n lightrag <pod-name>`
3. Check events: `kubectl get events -n lightrag --sort-by='.lastTimestamp'`
4. Open GitHub issue with details

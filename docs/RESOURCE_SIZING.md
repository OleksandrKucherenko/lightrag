# LightRAG Kubernetes Resource Sizing Guide

This guide helps you determine the right resource allocation for your LightRAG deployment based on workload, scale, and environment.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Sizing Profiles](#sizing-profiles)
- [Component-by-Component Analysis](#component-by-component-analysis)
- [Workload-Based Sizing](#workload-based-sizing)
- [Cost Optimization](#cost-optimization)
- [Monitoring and Tuning](#monitoring-and-tuning)

---

## Quick Reference

### Deployment Size Comparison

| Profile | Total CPU | Total Memory | Storage | Use Case | Monthly Cost* |
|---------|-----------|--------------|---------|----------|---------------|
| **Minimal** | 2 cores | 4Gi | 15Gi | Dev/Test | ~$75 |
| **Development** | 5 cores | 10Gi | 40Gi | Team Development | ~$150 |
| **Small Production** | 8 cores | 16Gi | 100Gi | Small Teams (< 10 users) | ~$250 |
| **Medium Production** | 16 cores | 32Gi | 250Gi | Medium Teams (10-50 users) | ~$500 |
| **Large Production** | 32+ cores | 64+ Gi | 500+ Gi | Enterprise (50+ users) | ~$1000+ |

*Estimated costs on managed Kubernetes (AWS EKS, GCP GKE, Azure AKS). Actual costs vary by region and provider.

---

## Sizing Profiles

### 1. Minimal (Lightweight Mode)

**Target**: Local development, CI/CD testing, demos

```yaml
# Single pod, no external databases
LightRAG:
  cpu: 500m request, 1000m limit
  memory: 1Gi request, 2Gi limit
  storage: 8Gi

Total: 1 CPU, 2Gi RAM, 8Gi storage
```

**Characteristics**:
- Built-in storage (JsonKV, NanoVectorDB, NetworkX)
- Single replica
- ~5 docs/second ingestion
- ~150ms query latency
- Max dataset: ~10K documents

**When to Use**:
- Feature development
- Integration testing
- Quick demos
- Learning Kubernetes

**Deployment**:
```bash
kubectl apply -f k8s/examples/lightweight-deployment.yaml
```

---

### 2. Development (Team Environment)

**Target**: Development teams, staging environments

```yaml
# Minimal databases + application
Redis:
  cpu: 250m request, 500m limit
  memory: 512Mi request, 1Gi limit
  storage: 5Gi

Memgraph:
  cpu: 1000m request, 2000m limit
  memory: 2Gi request, 4Gi limit
  storage: 12Gi

Qdrant:
  cpu: 500m request, 1000m limit
  memory: 1Gi request, 2Gi limit
  storage: 20Gi

LightRAG:
  cpu: 500m request, 1000m limit
  memory: 1Gi request, 2Gi limit
  storage: 35Gi

LobeChat:
  cpu: 250m request, 500m limit
  memory: 512Mi request, 1Gi limit
  storage: 5Gi

Total: ~5 CPU, 10Gi RAM, 77Gi storage
```

**Characteristics**:
- Full database stack
- Single replicas
- ~10 docs/second ingestion
- ~100ms query latency
- Max dataset: ~100K documents

**When to Use**:
- Team development environments
- Staging/pre-production
- QA testing
- Small pilot projects

---

### 3. Small Production

**Target**: Small teams, startups, MVPs

```yaml
# Conservative production sizing
Redis:
  cpu: 250m request, 500m limit
  memory: 512Mi request, 1Gi limit
  storage: 5Gi

Memgraph:
  cpu: 2000m request, 4000m limit
  memory: 4Gi request, 8Gi limit
  storage: 20Gi

Qdrant:
  cpu: 1000m request, 2000m limit
  memory: 2Gi request, 4Gi limit
  storage: 50Gi

LightRAG:
  cpu: 1000m request, 2000m limit
  memory: 2Gi request, 4Gi limit
  storage: 50Gi

LobeChat:
  cpu: 250m request, 500m limit
  memory: 512Mi request, 1Gi limit
  storage: 5Gi

Total: ~8 CPU, 16Gi RAM, 130Gi storage
```

**Characteristics**:
- Production-ready configuration
- Single replicas with restart policies
- ~15 docs/second ingestion
- ~80ms query latency
- Max dataset: ~500K documents

**When to Use**:
- Small production deployments (< 10 concurrent users)
- Startups and MVPs
- Internal tools
- Low-traffic applications

**This is our default configuration** in `k8s/` directory.

---

### 4. Medium Production

**Target**: Growing businesses, medium teams

```yaml
# Scaled production sizing
Redis:
  replicas: 3 (Sentinel)
  cpu: 500m request, 1000m limit (each)
  memory: 1Gi request, 2Gi limit (each)
  storage: 10Gi (each)

Memgraph:
  replicas: 2 (HA pair)
  cpu: 4000m request, 8000m limit (each)
  memory: 8Gi request, 16Gi limit (each)
  storage: 50Gi (each)

Qdrant:
  replicas: 3 (cluster)
  cpu: 2000m request, 4000m limit (each)
  memory: 4Gi request, 8Gi limit (each)
  storage: 100Gi (each)

LightRAG:
  replicas: 3
  cpu: 2000m request, 4000m limit (each)
  memory: 4Gi request, 8Gi limit (each)
  storage: 100Gi (shared)

LobeChat:
  replicas: 2
  cpu: 500m request, 1000m limit (each)
  memory: 1Gi request, 2Gi limit (each)
  storage: 10Gi (shared)

Total: ~32 CPU, 64Gi RAM, 500Gi storage
```

**Characteristics**:
- High availability
- Multiple replicas
- ~30 docs/second ingestion
- ~50ms query latency
- Max dataset: ~2M documents

**When to Use**:
- Production with 10-50 concurrent users
- Business-critical applications
- 24/7 availability requirements
- Regional deployments

---

### 5. Large Production / Enterprise

**Target**: Enterprise, high-traffic applications

```yaml
# Enterprise-grade sizing
Redis:
  replicas: 6 (Cluster mode)
  cpu: 1000m request, 2000m limit (each)
  memory: 2Gi request, 4Gi limit (each)
  storage: 20Gi (each)

Memgraph Enterprise:
  replicas: 3 (HA + read replicas)
  cpu: 8000m request, 16000m limit (each)
  memory: 16Gi request, 32Gi limit (each)
  storage: 200Gi (each)

Qdrant:
  replicas: 6 (cluster)
  cpu: 4000m request, 8000m limit (each)
  memory: 8Gi request, 16Gi limit (each)
  storage: 500Gi (each)

LightRAG:
  replicas: 6
  cpu: 4000m request, 8000m limit (each)
  memory: 8Gi request, 16Gi limit (each)
  storage: 500Gi (shared)

LobeChat:
  replicas: 4
  cpu: 1000m request, 2000m limit (each)
  memory: 2Gi request, 4Gi limit (each)
  storage: 20Gi (shared)

Total: ~100+ CPU, 200+ Gi RAM, 2+ Ti storage
```

**Characteristics**:
- Multi-region HA
- Load balancing
- ~100+ docs/second ingestion
- ~30ms query latency
- Max dataset: 10M+ documents

**When to Use**:
- Enterprise deployments
- High-traffic applications (100+ concurrent users)
- Multi-region/global deployments
- SLA requirements > 99.9%

---

## Component-by-Component Analysis

### Redis (KV Storage)

**Role**: Document metadata, session state, caching

| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| Light (< 10K docs) | 250m | 512Mi | 5Gi | Development |
| Medium (< 100K docs) | 500m | 1Gi | 10Gi | Small production |
| Heavy (< 1M docs) | 1000m | 2Gi | 20Gi | Medium production |
| Very Heavy (> 1M docs) | 2000m+ | 4Gi+ | 50Gi+ | Enterprise |

**Scaling Factors**:
- Documents: ~100 bytes metadata per doc
- Sessions: ~1KB per active session
- Cache: Varies by query patterns

**Optimization Tips**:
- Enable Redis persistence (AOF or RDB)
- Use Redis Cluster for > 10Gi data
- Monitor memory usage and set maxmemory policy
- Consider Redis Sentinel for HA

---

### Memgraph (Graph Storage)

**Role**: Knowledge graph relationships, entity connections

| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| Light (< 10K nodes) | 1000m | 2Gi | 10Gi | Development |
| Medium (< 100K nodes) | 2000m | 4Gi | 20Gi | Small production |
| Heavy (< 1M nodes) | 4000m | 8Gi | 50Gi | Medium production |
| Very Heavy (> 1M nodes) | 8000m+ | 16Gi+ | 200Gi+ | Enterprise |

**Scaling Factors**:
- Nodes: ~500 bytes per node
- Relationships: ~200 bytes per edge
- Query complexity: More connections = more CPU

**Optimization Tips**:
- Tune `--memory-limit` based on dataset
- Enable query caching for repeated patterns
- Use read replicas for query-heavy workloads
- Monitor query performance with EXPLAIN

**Important**: Memgraph can be memory-intensive for large graphs. Allocate 2-3x your dataset size in RAM for optimal performance.

---

### Qdrant (Vector Storage)

**Role**: Embedding storage and similarity search

| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| Light (< 10K vectors) | 500m | 1Gi | 10Gi | Development |
| Medium (< 100K vectors) | 1000m | 2Gi | 20Gi | Small production |
| Heavy (< 1M vectors) | 2000m | 4Gi | 50Gi | Medium production |
| Very Heavy (> 1M vectors) | 4000m+ | 8Gi+ | 200Gi+ | Enterprise |

**Scaling Factors**:
- Embedding dimensions: 384-1536 dims per vector
- Vector size: ~1.5-6KB per document (depending on model)
- Search complexity: More vectors = more CPU for similarity search

**Optimization Tips**:
- Use quantization for 4x storage reduction
- Enable HNSW indexing for fast searches
- Shard collection for > 1M vectors
- Consider disk-backed collections for large datasets

**Formula**: Storage ≈ (num_docs × embedding_dim × 4 bytes) × 1.5 (overhead)

---

### LightRAG (Application)

**Role**: API server, orchestration, LLM coordination

| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| Light (< 10 req/min) | 500m | 1Gi | 20Gi | Development |
| Medium (< 100 req/min) | 1000m | 2Gi | 50Gi | Small production |
| Heavy (< 1000 req/min) | 2000m | 4Gi | 100Gi | Medium production |
| Very Heavy (> 1000 req/min) | 4000m+ | 8Gi+ | 200Gi+ | Enterprise |

**Scaling Factors**:
- Request rate: Concurrent queries
- Document size: Larger docs = more processing
- LLM calls: Token processing overhead
- Workers: More workers = more memory

**Optimization Tips**:
- Scale horizontally (multiple replicas)
- Tune `MAX_ASYNC` and `MAX_PARALLEL_INSERT`
- Increase `LLM_CONNECTION_POOL_SIZE` for high traffic
- Monitor request queue depth

**Workers Setting**:
- Development: 4 workers
- Production: 2 × CPU cores (e.g., 2 CPU → 4 workers)
- High traffic: 4 × CPU cores with more memory

---

### LobeChat (Frontend)

**Role**: Web UI, user interactions

| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| Light (< 10 users) | 250m | 512Mi | 5Gi | Development |
| Medium (< 50 users) | 500m | 1Gi | 10Gi | Small production |
| Heavy (< 200 users) | 1000m | 2Gi | 20Gi | Medium production |
| Very Heavy (> 200 users) | 2000m+ | 4Gi+ | 50Gi+ | Enterprise |

**Scaling Factors**:
- Concurrent users
- Session storage
- Chat history

**Optimization Tips**:
- Scale horizontally (easiest component to scale)
- Use CDN for static assets
- Enable session affinity if using local storage
- Monitor response times

---

## Workload-Based Sizing

### Document Volume

| Documents | Profile | CPU | Memory | Storage |
|-----------|---------|-----|--------|---------|
| < 1K | Minimal | 2 | 4Gi | 15Gi |
| 1K - 10K | Development | 5 | 10Gi | 40Gi |
| 10K - 100K | Small Production | 8 | 16Gi | 100Gi |
| 100K - 1M | Medium Production | 16 | 32Gi | 250Gi |
| > 1M | Large Production | 32+ | 64+ Gi | 500+ Gi |

### User Concurrency

| Concurrent Users | Profile | LightRAG Replicas | LobeChat Replicas |
|------------------|---------|-------------------|-------------------|
| < 5 | Single | 1 | 1 |
| 5 - 20 | Small | 2 | 2 |
| 20 - 50 | Medium | 3 | 3 |
| 50 - 100 | Large | 5 | 4 |
| > 100 | Enterprise | 10+ | 6+ |

### Query Complexity

| Complexity | Description | Resource Impact |
|------------|-------------|-----------------|
| **Simple** | Direct queries, small context | 1x baseline |
| **Medium** | Multi-hop queries, medium context | 2x baseline |
| **Complex** | Deep reasoning, large context | 4x baseline |

**Recommendation**: For complex queries, increase LightRAG and Memgraph resources by 2-4x.

---

## Cost Optimization

### Cloud Provider Comparison (Monthly Costs)

For **Small Production** profile (8 CPU, 16Gi RAM, 130Gi storage):

| Provider | Compute | Storage | Load Balancer | Total/Month |
|----------|---------|---------|---------------|-------------|
| **AWS EKS** | $175 | $13 | $20 | ~$208 |
| **GCP GKE** | $190 | $13 | $18 | ~$221 |
| **Azure AKS** | $185 | $10 | $15 | ~$210 |
| **DigitalOcean** | $150 | $10 | $10 | ~$170 |
| **Civo** | $130 | $8 | $5 | ~$143 |

*Costs are estimates for us-east region with standard storage and no reserved instances.*

### Cost Saving Strategies

#### 1. Use Spot/Preemptible Instances

Save 60-80% on compute for non-critical workloads:

```yaml
nodeSelector:
  eks.amazonaws.com/capacityType: SPOT  # AWS
  cloud.google.com/gke-preemptible: "true"  # GCP
  kubernetes.azure.com/scalesetpriority: spot  # Azure
```

**Best for**: Development, staging, CI/CD
**Not for**: Production databases

#### 2. Right-Size Resources

Start conservative and scale up based on actual usage:

```bash
# Monitor actual usage
kubectl top pods -n lightrag

# Example output:
# NAME                       CPU    MEMORY
# lightrag-xxx               180m   1200Mi  # Overprovisioned!
# redis-0                    45m    380Mi   # Overprovisioned!
```

**Action**: Reduce requests/limits by 30-50% if consistently underutilized.

#### 3. Use Efficient Storage Classes

| Storage Class | IOPS | Cost/GB/Month | Use Case |
|---------------|------|---------------|----------|
| **Standard HDD** | 500 | $0.04 | Logs, backups |
| **Standard SSD** | 3000 | $0.10 | Default |
| **High-Performance SSD** | 20000 | $0.20 | Databases |

```yaml
# Use standard storage for logs
- name: logs
  persistentVolumeClaim:
    claimName: lightrag-logs
    storageClassName: standard  # Not premium
```

#### 4. Cluster Autoscaling

Enable cluster autoscaler to scale nodes based on demand:

```bash
# AWS EKS
eksctl create cluster --managed --asg-access

# GCP GKE
gcloud container clusters create --enable-autoscaling

# Azure AKS
az aks update --enable-cluster-autoscaler
```

#### 5. Development During Work Hours Only

For dev/staging, schedule downtime:

```yaml
# Scale down at night
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-dev
spec:
  schedule: "0 19 * * 1-5"  # 7 PM weekdays
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scaler
            image: bitnami/kubectl
            command:
            - /bin/sh
            - -c
            - kubectl scale deployment --all --replicas=0 -n lightrag-dev
```

**Savings**: ~65% reduction for dev environments

---

## Monitoring and Tuning

### Key Metrics to Monitor

#### CPU Usage
```bash
# Real-time monitoring
kubectl top pods -n lightrag

# Historical data (with metrics-server)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/lightrag/pods
```

**Target**: 60-70% average utilization
- < 40%: Overprovisioned (reduce limits)
- > 85%: Underprovisioned (increase limits)

#### Memory Usage
```bash
# Check memory usage
kubectl top pods -n lightrag

# Check for OOMKilled pods
kubectl get pods -n lightrag -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}'
```

**Target**: 70-80% average utilization
- OOMKilled: Increase memory limits
- < 50%: Reduce memory requests

#### Storage Usage
```bash
# Check PVC usage (requires exec into pod)
kubectl exec -n lightrag redis-0 -- df -h /data
kubectl exec -n lightrag memgraph-0 -- df -h /var/lib/memgraph
kubectl exec -n lightrag qdrant-0 -- df -h /qdrant/storage
```

**Target**: < 80% full
- > 80%: Increase PVC size or add cleanup policies

### Performance Testing

#### Load Test Script
```bash
#!/bin/bash
# load-test.sh

# Ingestion load test
for i in {1..1000}; do
  curl -X POST http://localhost:9621/v1/documents \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"Test document $i\"}" &
done
wait

# Query load test
for i in {1..500}; do
  curl -X POST http://localhost:9621/v1/query \
    -H "Content-Type: application/json" \
    -d '{"query": "test query"}' &
done
wait
```

Monitor during load test:
```bash
watch -n 1 'kubectl top pods -n lightrag'
```

### Tuning Recommendations

#### If You See High CPU on LightRAG:
1. Increase `LLM_CONNECTION_POOL_SIZE` (reduce API wait time)
2. Scale horizontally (add replicas)
3. Optimize queries (use indexes)

#### If You See High Memory on Memgraph:
1. Tune `--memory-limit` parameter
2. Optimize graph queries (reduce traversal depth)
3. Scale vertically (more RAM)
4. Consider sharding for very large graphs

#### If You See High Latency:
1. Check database query performance
2. Increase worker count (`WORKERS`)
3. Enable caching
4. Scale horizontally

---

## Quick Sizing Calculator

### Estimate Your Needs

**Step 1**: Estimate your document count
- Small: < 10K documents
- Medium: 10K - 100K documents
- Large: 100K - 1M documents
- Very Large: > 1M documents

**Step 2**: Estimate concurrent users
- Low: < 10 users
- Medium: 10-50 users
- High: 50-100 users
- Very High: > 100 users

**Step 3**: Determine your environment
- Development: Use Lightweight or Development profile
- Staging: Use Development or Small Production profile
- Production: Use Small, Medium, or Large Production profile

### Recommended Profile Matrix

| Documents | Users | Environment | Profile | Estimated Cost/Month |
|-----------|-------|-------------|---------|----------------------|
| < 10K | < 10 | Dev | Lightweight | ~$75 |
| 10K-100K | 10-50 | Dev/Staging | Development | ~$150 |
| 10K-100K | < 10 | Production | Small Production | ~$250 |
| 100K-1M | 10-50 | Production | Medium Production | ~$500 |
| > 1M | > 50 | Production | Large Production | $1000+ |

---

## See Also

- [Main K8s README](../k8s/README.md) - Deployment instructions
- [Cost Monitoring Guide](../k8s/COST_MONITORING.md) - Kubecost setup
- [Lightweight Examples](../k8s/examples/README.md) - Alternative configurations
- [Cloud Deployment Guide](../k8s/CLOUD_DEPLOYMENT.md) - Provider-specific instructions

---

## Contributing

Have sizing recommendations or real-world benchmarks? Please share them via PR!

## License

Same as the main LightRAG project.

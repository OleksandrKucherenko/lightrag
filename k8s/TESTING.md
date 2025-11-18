# Testing LightRAG Kubernetes Deployment

This guide explains how to test the LightRAG Kubernetes configuration locally using Kind (Kubernetes in Docker).

## Prerequisites

- Docker installed and running
- `kind` CLI tool
- `kubectl` CLI tool
- At least 16GB RAM and 8 CPU cores available for Docker

## Quick Start with Kind

### 1. Install Required Tools

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Verify installations
kind version
kubectl version --client
```

### 2. Create a Kind Cluster

Create a cluster with enough resources:

```bash
# Create a configuration file for Kind
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: lightrag-test
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Create the cluster
kind create cluster --config kind-config.yaml
```

### 3. Install Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for the ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 4. Update Secrets

**IMPORTANT**: Before deploying, update the secrets with your actual API keys:

```bash
# Edit 02-secrets.yaml and replace placeholder values
# Or create secrets from command line:

kubectl create namespace lightrag

kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key' \
  --from-literal=LIGHTRAG_API_KEY='your-lightrag-key' \
  --from-literal=LOBECHAT_ACCESS_CODE='dev-access-2024'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'
```

### 5. Deploy LightRAG Stack

```bash
# Deploy everything (skip secrets if created manually)
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-configmaps.yaml
# kubectl apply -f 02-secrets.yaml  # Skip if created manually
kubectl apply -f 03-storage.yaml
kubectl apply -f 04-redis.yaml
kubectl apply -f 05-memgraph.yaml
kubectl apply -f 06-qdrant.yaml
kubectl apply -f 07-lightrag.yaml
kubectl apply -f 08-lobechat.yaml
kubectl apply -f 09-monitor.yaml
kubectl apply -f 10-ingress.yaml

# Or deploy all at once
kubectl apply -f . --recursive
```

### 6. Monitor Deployment

```bash
# Watch pods starting
kubectl get pods -n lightrag -w

# Check deployment status
kubectl get all -n lightrag

# View logs
kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --tail=100 -f
```

### 7. Configure DNS

Add to your `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```text
127.0.0.1 dev.localhost
127.0.0.1 chat.dev.localhost
127.0.0.1 lobechat.dev.localhost
127.0.0.1 rag.dev.localhost
127.0.0.1 api.dev.localhost
127.0.0.1 graph.dev.localhost
127.0.0.1 vector.dev.localhost
127.0.0.1 monitor.dev.localhost
```

### 8. Access Services

Open in your browser:

- **LobeChat**: http://chat.dev.localhost
- **LightRAG API**: http://rag.dev.localhost
- **Memgraph Lab**: http://graph.dev.localhost
- **Qdrant UI**: http://vector.dev.localhost

Or use port-forwarding:

```bash
# LobeChat
kubectl port-forward -n lightrag svc/lobechat 3210:3210

# LightRAG
kubectl port-forward -n lightrag svc/lightrag 9621:9621
```

## Validation

### Before Deployment

Run the validation script:

```bash
./validate.sh
```

This checks:
- YAML syntax
- Resource structure
- Resource references
- Labels and selectors
- Resource limits
- Health probes
- Security configurations

### After Deployment

```bash
# Check pod status
kubectl get pods -n lightrag

# Check services
kubectl get svc -n lightrag

# Check ingress
kubectl get ingress -n lightrag

# View events
kubectl get events -n lightrag --sort-by='.lastTimestamp'

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n lightrag -- \
  curl http://lightrag:9621/health
```

## Common Issues

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n lightrag

# Describe pod to see events
kubectl describe pod <pod-name> -n lightrag

# Check node resources
kubectl top nodes
```

**Solution**: Ensure your Kind cluster has enough resources allocated to Docker.

### ImagePullBackOff

```bash
# Describe the pod
kubectl describe pod <pod-name> -n lightrag
```

**Solution**: Check your internet connection and image names.

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress lightrag-ingress -n lightrag
```

**Solution**: Ensure NGINX ingress controller is installed and running.

### Out of Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n lightrag

# Scale down non-essential services
kubectl scale deployment monitor --replicas=0 -n lightrag
```

## Performance Testing

### Load Testing

```bash
# Install hey (HTTP load generator)
go install github.com/rakyll/hey@latest

# Test LightRAG API
hey -n 100 -c 10 http://rag.dev.localhost/health

# Test LobeChat
hey -n 100 -c 10 http://chat.dev.localhost
```

### Resource Monitoring

```bash
# Real-time monitoring
watch -n 1 kubectl top pods -n lightrag

# Get detailed metrics
kubectl describe nodes
```

## Scaling Tests

### Horizontal Scaling

```bash
# Scale LobeChat
kubectl scale deployment lobechat --replicas=3 -n lightrag

# Verify
kubectl get pods -n lightrag -l app.kubernetes.io/name=lobechat

# Test load distribution
for i in {1..10}; do curl http://chat.dev.localhost; done
```

### Vertical Scaling

```bash
# Edit deployment
kubectl edit deployment lightrag -n lightrag

# Change resource limits
# spec.template.spec.containers[0].resources.limits.memory: 8Gi

# Verify rollout
kubectl rollout status deployment/lightrag -n lightrag
```

## Cleanup

### Delete Deployment

```bash
# Delete all resources
kubectl delete namespace lightrag

# Or delete individual components
kubectl delete -f . --recursive
```

### Delete Kind Cluster

```bash
# Delete the cluster
kind delete cluster --name lightrag-test

# Verify deletion
kind get clusters
```

## Advanced Testing

### Network Policies

Test network isolation:

```bash
# Apply network policies
kubectl apply -f network-policies.yaml

# Test connectivity
kubectl run -it --rm test --image=busybox --restart=Never -n lightrag -- \
  wget -qO- http://redis:6379
```

### Backup and Restore

Test data persistence:

```bash
# Create a snapshot of Qdrant
kubectl exec -n lightrag qdrant-0 -- \
  curl -X POST 'http://localhost:6333/snapshots'

# Copy snapshot out
kubectl cp lightrag/qdrant-0:/qdrant/snapshots/snapshot.tar.gz ./snapshot.tar.gz

# Delete and restore
kubectl delete namespace lightrag
# ... re-deploy ...
kubectl cp ./snapshot.tar.gz lightrag/qdrant-0:/qdrant/snapshots/
```

### Upgrade Testing

Test rolling updates:

```bash
# Update image version
kubectl set image deployment/lightrag \
  lightrag=ghcr.io/hkuds/lightrag:v2.0 \
  -n lightrag

# Watch rollout
kubectl rollout status deployment/lightrag -n lightrag

# Rollback if needed
kubectl rollout undo deployment/lightrag -n lightrag
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test K8s Deployment

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Create Kind cluster
      uses: helm/kind-action@v1.8.0

    - name: Install ingress
      run: |
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=90s

    - name: Validate manifests
      run: ./k8s/validate.sh

    - name: Deploy
      run: kubectl apply -f k8s/ --recursive

    - name: Wait for pods
      run: kubectl wait --for=condition=ready pod --all -n lightrag --timeout=300s

    - name: Run tests
      run: |
        kubectl get all -n lightrag
        kubectl logs -n lightrag -l app.kubernetes.io/name=lightrag --tail=50
```

## Troubleshooting Commands

```bash
# Get all resources
kubectl get all -n lightrag

# Describe everything
kubectl describe all -n lightrag

# Get events
kubectl get events -n lightrag --sort-by='.lastTimestamp'

# Get logs from all pods
kubectl logs -n lightrag --all-containers --tail=100

# Execute shell in pod
kubectl exec -it <pod-name> -n lightrag -- /bin/sh

# Debug networking
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n lightrag -- bash

# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n lightrag -- nslookup redis
```

## Best Practices

1. **Always validate before deploying**
   ```bash
   python3 validate.py
   ```

2. **Use resource limits** to prevent cluster resource exhaustion

3. **Monitor logs** during deployment
   ```bash
   stern -n lightrag .
   ```

4. **Test incrementally** - deploy services one at a time for easier debugging

5. **Use labels** consistently for easier management

6. **Document issues** and their solutions

## Resources

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

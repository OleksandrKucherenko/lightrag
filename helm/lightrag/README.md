# LightRAG Helm Chart

This Helm chart deploys the complete LightRAG stack to Kubernetes.

> **Note**: This Helm chart is one of two deployment options. For a comparison with plain Kubernetes manifests, see [DEPLOYMENT_STRATEGY.md](../../DEPLOYMENT_STRATEGY.md).

## Why Use This Helm Chart?

✅ **Environment Flexibility**: Easy dev/staging/prod configurations
✅ **Value-Driven**: Customize via `values.yaml` or `--set` flags
✅ **Version Management**: Built-in upgrade and rollback
✅ **Production Ready**: Follows Helm best practices
✅ **No Code Duplication**: Single source of truth with templates

**Alternative**: For simple `kubectl apply` deployments, see `../../k8s/` directory.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure (for persistence)
- Ingress controller (NGINX recommended)

## Installation

### Quick Start

```bash
# Add your secrets
helm install lightrag . \
  --namespace lightrag \
  --create-namespace \
  --set secrets.llmBindingApiKey="sk-your-llm-key" \
  --set secrets.embeddingBindingApiKey="sk-your-embedding-key" \
  --set secrets.openaiApiKey="sk-your-openai-key" \
  --set secrets.redisPassword="your-secure-password"
```

### Using a Values File

Create a `my-values.yaml`:

```yaml
global:
  publishDomain: myapp.local

secrets:
  redisPassword: "my-secure-password"
  llmBindingApiKey: "sk-my-actual-key"
  embeddingBindingApiKey: "sk-my-actual-key"
  openaiApiKey: "sk-my-actual-key"

ingress:
  enabled: true
  className: nginx

lightrag:
  replicaCount: 2
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
```

Then install:

```bash
helm install lightrag . -f my-values.yaml --namespace lightrag --create-namespace
```

## Configuration

See `values.yaml` for all configuration options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.publishDomain` | Base domain for all services | `dev.localhost` |
| `global.storageClass` | Storage class for PVCs | `""` (default) |
| `redis.enabled` | Enable Redis | `true` |
| `memgraph.enabled` | Enable Memgraph | `true` |
| `qdrant.enabled` | Enable Qdrant | `true` |
| `lightrag.enabled` | Enable LightRAG | `true` |
| `lobechat.enabled` | Enable LobeChat | `true` |
| `ingress.enabled` | Enable Ingress | `true` |
| `secrets.*` | Various secrets | See values.yaml |

### Customizing Resources, Ports, and Image Versions

**All resources, ports, and image versions are fully parameterized** in `values.yaml` for easy customization:

#### Resource Limits and Requests

```bash
# Override CPU/RAM for specific services
helm install lightrag . \
  --set lightrag.resources.limits.cpu="4000m" \
  --set lightrag.resources.limits.memory="8Gi" \
  --set lightrag.resources.requests.cpu="2000m" \
  --set lightrag.resources.requests.memory="4Gi" \
  --set qdrant.resources.limits.memory="6Gi"
```

Or in `values.yaml`:

```yaml
lightrag:
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
    requests:
      cpu: 2000m
      memory: 4Gi

qdrant:
  resources:
    limits:
      cpu: 3000m
      memory: 6Gi
```

#### Service Ports

```bash
# Change service ports if needed
helm install lightrag . \
  --set lightrag.service.port=9621 \
  --set lobechat.service.port=3210 \
  --set redis.service.port=6379
```

#### Image Versions

**Important**: We use specific image tags (not `:latest`) for production stability:

```bash
# Override image versions
helm install lightrag . \
  --set lightrag.image.tag="0.0.6" \
  --set qdrant.image.tag="v1.11.0" \
  --set lobechat.image.tag="v1.18.0"
```

Or in `values.yaml`:

```yaml
lightrag:
  image:
    repository: ghcr.io/hkuds/lightrag
    tag: "0.0.6"  # Specify exact version
    pullPolicy: IfNotPresent

qdrant:
  image:
    repository: qdrant/qdrant
    tag: "v1.11.0"  # Specific version
    pullPolicy: IfNotPresent
```

**Current default versions**:
- **redis**: `8-alpine`
- **memgraph**: `2.18.1`
- **memgraph-lab**: `2.14.1`
- **qdrant**: `v1.10.1`
- **lightrag**: `0.0.5`
- **lobe-chat**: `v1.17.12`
- **isaiah**: `1.30.0`

These can all be overridden via `--set` flags or custom `values.yaml` file.

## Upgrading

```bash
helm upgrade lightrag . -f my-values.yaml
```

## Uninstalling

```bash
helm uninstall lightrag --namespace lightrag
```

**Note**: This will not delete PVCs. To delete data:

```bash
kubectl delete pvc --all -n lightrag
```

## Validation

```bash
# Lint the chart
helm lint .

# Dry run
helm install lightrag . --dry-run --debug

# Template output
helm template lightrag . > output.yaml
```

## Troubleshooting

View the status:

```bash
helm status lightrag -n lightrag
```

Get values:

```bash
helm get values lightrag -n lightrag
```

View release history:

```bash
helm history lightrag -n lightrag
```

## Maintenance

For production deployments, see our comprehensive [Cluster Maintenance Guide](../../k8s/CLUSTER_MAINTENANCE.md) which covers:

- **Secret Rotation**: Using Helm secrets and external secret management
- **Cluster Scaling**: Horizontal pod autoscaling, resource management
- **Service Management**: Rolling updates with Helm, node maintenance
- **Backup & Recovery**: Velero integration with Helm
- **Multi-Region Setup**: Geographic distribution strategies
- **Monitoring**: Prometheus, Grafana setup for Helm deployments
- **Emergency Procedures**: Recovery procedures for Helm-based deployments

### Helm-Specific Maintenance Commands

```bash
# Check release status
helm status lightrag -n lightrag

# Upgrade with new values
helm upgrade lightrag . -f my-values.yaml

# Rollback to previous version
helm rollback lightrag 1 -n lightrag

# View release history
helm history lightrag -n lightrag

# Scale with Helm (update values and upgrade)
helm upgrade lightrag . --set lightrag.replicaCount=3

# Restart services
helm upgrade lightrag . --set lightrag.revisionHistoryLimit=0

# Add monitoring
helm upgrade lightrag . --set monitoring.enabled=true
```

### Environment-Specific Values

Create separate values files for different environments:

```bash
# Development
helm install lightrag . -f values-dev.yaml

# Staging
helm install lightrag . -f values-staging.yaml

# Production
helm install lightrag . -f values-prod.yaml
```

## Development

Test the chart:

```bash
# Lint
helm lint .

# Template
helm template test-release .

# Install with debug
helm install test-release . --dry-run --debug
```

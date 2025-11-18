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

# Helm Templates

This directory contains Helm chart templates for LightRAG.

## Template Strategy

Unlike the plain manifests in `k8s/`, these templates use Helm's templating engine to enable:
- Dynamic configuration via `values.yaml`
- Environment-specific deployments
- Easier customization and upgrades

## Generating Plain Manifests

To generate plain Kubernetes manifests from this Helm chart:

```bash
# Generate all manifests
helm template lightrag . --namespace lightrag > output.yaml

# Generate with custom values
helm template lightrag . --namespace lightrag -f my-values.yaml > output.yaml

# Generate to k8s/generated/ directory
cd ../..
./scripts/k8s-generate-from-helm.sh
```

## Template Files

- `NOTES.txt` - Post-install instructions shown to users
- `_helpers.tpl` - Helper templates and functions
- Other templates are generated dynamically from the Helm chart

## Why Not Duplicate Plain YAML?

We deliberately **do not** duplicate the plain YAML manifests from `k8s/` here because:

1. **Single Source of Truth**: The Helm chart with `values.yaml` is the source of truth
2. **No Duplication**: Avoids maintaining identical files in multiple places
3. **Dynamic Generation**: Manifests are generated at install/template time
4. **Flexibility**: Easy to customize for different environments

## Usage

### Install with Helm

```bash
helm install lightrag . \
  --namespace lightrag \
  --create-namespace \
  --set secrets.redisPassword="your-password" \
  --set secrets.llmBindingApiKey="your-key"
```

### Generate Static Manifests

```bash
helm template lightrag . --namespace lightrag > ../../../k8s/generated/all.yaml
```

## Relationship to k8s/ Directory

| Directory        | Purpose                  | When to Use                               |
| ---------------- | ------------------------ | ----------------------------------------- |
| `k8s/`           | Simple, static manifests | Quick deployments, learning, testing      |
| `helm/lightrag/` | Templated, configurable  | Production, multi-environment, automation |
| `k8s/generated/` | Generated from Helm      | When you need plain YAML from Helm values |

## See Also

- [Helm Chart README](../README.md)
- [Main K8s README](../../k8s/README.md)
- [values.yaml](../values.yaml) - All configuration options

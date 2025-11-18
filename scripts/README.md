# LightRAG Helper Scripts

This directory contains utility scripts for managing the LightRAG deployment.

## Available Scripts

### sync-config.sh

**Purpose**: Validate configuration synchronization between Docker Compose and Kubernetes

**Usage**:
```bash
./scripts/sync-config.sh
```

**What it checks**:
- Image version differences between docker-compose, k8s manifests, and Helm values
- Environment variable configuration across platforms
- Port configuration consistency
- Resource limit definitions
- Common configuration mistakes (like using `:latest` tags in K8s)

**Exit codes**:
- `0`: Check passed or warnings only
- `1`: Check failed with errors

**Requirements**:
- `yq` (optional, for enhanced checks): `brew install yq` or https://github.com/mikefarah/yq

**Example output**:
```
========================================
Checking Image Versions
========================================

Service: rag -> lightrag
  Docker Compose: ghcr.io/hkuds/lightrag:latest
  K8s Manifest:   ghcr.io/hkuds/lightrag:0.0.5
  Helm Values:    ghcr.io/hkuds/lightrag:0.0.5
✓ Image repositories match

========================================
Summary
========================================

Warnings: 2
Errors:   0

⚠ Configuration sync check completed with 2 warnings
```

**Integration**:

Add to pre-commit hook:
```bash
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -q "docker-compose.yaml"; then
    ./scripts/sync-config.sh || exit 1
fi
```

Add to CI/CD (GitHub Actions):
```yaml
- name: Validate config sync
  run: ./scripts/sync-config.sh
```

## Workflow

The recommended workflow for using these scripts:

1. **Develop locally**: Make changes to `docker-compose.yaml` and test with Docker Compose
2. **Validate sync**: Run `./scripts/sync-config.sh` to check for configuration drift
3. **Manual sync**: Update `k8s/*.yaml` and `helm/lightrag/values.yaml` based on the report
4. **Test**: Deploy to staging K8s environment for validation
5. **Deploy**: Push to production

See [Development Workflow Guide](../docs/DEVELOPMENT_WORKFLOW.md) for complete details.

## Adding New Scripts

When adding new scripts to this directory:

1. **Make them executable**: `chmod +x scripts/your-script.sh`
2. **Add shebang**: `#!/usr/bin/env bash`
3. **Use strict mode**: `set -euo pipefail`
4. **Document here**: Add section above describing purpose and usage
5. **Add to workflow doc**: Update `../docs/DEVELOPMENT_WORKFLOW.md` if relevant

## Future Scripts (Ideas)

Potential future automation:

- `generate-k8s-from-compose.sh`: Generate K8s manifests from docker-compose (using kompose)
- `update-image-versions.sh`: Bulk update image versions across all configs
- `validate-secrets.sh`: Check that all required secrets are defined
- `compare-resources.sh`: Compare resource usage between environments
- `backup-configs.sh`: Backup current K8s configurations before updates

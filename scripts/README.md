# LightRAG Helper Scripts

This directory contains utility scripts for managing the LightRAG deployment.

## Available Scripts

### CI Scripts

These scripts are designed for GitHub Actions workflows but can also be run locally for testing.

#### ci-cost-estimate.sh

**Purpose**: Generate PR cost estimation report for GitHub Actions

**Usage**:
```bash
COMMIT_SHA=abc1234 REPO_URL=https://github.com/user/repo \
  ./scripts/ci-cost-estimate.sh main /tmp/cost-report.md
```

**What it does**:
- Extracts resources from current and base branch
- Calculates costs for all 5 cloud providers
- Generates markdown report with commit hash and timestamp
- Exports data to `$GITHUB_OUTPUT` if running in GitHub Actions

**Output**: Markdown file suitable for PR comments

---

#### ci-config-sync.sh

**Purpose**: Generate configuration sync validation report for GitHub Actions

**Usage**:
```bash
COMMIT_SHA=abc1234 REPO_URL=https://github.com/user/repo \
  ./scripts/ci-config-sync.sh /tmp/sync-report.md
```

**What it does**:
- Runs `sync-config.sh --ci` and captures output
- Parses warnings and errors
- Generates markdown report with detailed findings
- Exports data to `$GITHUB_OUTPUT` if running in GitHub Actions
- Exits with the same code as the sync check (fails CI on errors)

**Output**: Markdown file suitable for PR comments

---

### User Scripts

These scripts are meant to be run directly by developers.

#### estimate-costs.sh

**Purpose**: Estimate monthly/yearly Kubernetes costs across multiple cloud providers

**Usage**:
```bash
# Show current configuration costs
./scripts/estimate-costs.sh

# PR mode: compare with base branch
./scripts/estimate-costs.sh --pr main

# Show help
./scripts/estimate-costs.sh --help
```

**What it does**:
- Analyzes Helm values.yaml to extract CPU, RAM, and storage requirements
- Calculates estimated costs for 5 cloud providers:
  - AWS EKS
  - Azure AKS
  - GCP GKE
  - DigitalOcean DOKS
  - Civo
- Shows daily, monthly, and yearly cost projections
- In PR mode: compares costs with base branch and shows deltas

**Example output**:
```
Resources:
  CPU:     5.00 cores
  RAM:     10 GB
  Storage: 87 GB

Monthly Cost Estimates (USD):
Provider                  Compute      Storage      Control        Total       Yearly
AWS (EKS)                 $228.10        $8.70       $72.00      $308.80     $3705.60
Azure (AKS)               $328.15       $13.05        $0.00      $341.20     $4094.40
GCP (GKE)                 $337.50       $14.79       $73.00      $425.29     $5103.48
DigitalOcean (DOKS)       $120.00        $8.70        $0.00      $128.70     $1544.40
Civo                       $75.00        $4.35        $0.00       $79.35      $952.20
```

**GitHub Actions Integration**:
Automatically runs on PRs when `helm/lightrag/values.yaml` or `k8s/*.yaml` files change. Posts cost analysis as PR comment.

**Requirements**:
- `bc` (basic calculator) - usually pre-installed
- `awk` - usually pre-installed
- `yq` (optional) - for faster parsing

---

### sync-config.sh

**Purpose**: Validate configuration synchronization between Docker Compose and Kubernetes

**Usage**:
```bash
# Interactive mode with colors
./scripts/sync-config.sh

# CI mode without colors (for automation)
./scripts/sync-config.sh --ci
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

**GitHub Actions Integration**:
Automatically runs on PRs when `docker-compose.yaml`, `k8s/*.yaml`, or `helm/lightrag/values.yaml` files change. Posts sync status as PR comment with:
- ✅ All synchronized / ⚠️ Warnings detected / ❌ Errors detected
- Detailed drift report with recommendations
- Commit hash tracking

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

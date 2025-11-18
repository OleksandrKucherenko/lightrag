# Development Workflow: Docker Compose → Kubernetes

This document describes the recommended workflow for developing with Docker Compose locally and deploying to Kubernetes in production.

## Table of Contents

- [Overview](#overview)
- [Development Workflow](#development-workflow)
- [Configuration Synchronization](#configuration-synchronization)
- [Automated Checking](#automated-checking)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### The Two-Environment Approach

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEVELOPMENT (Local)                          │
│                                                                   │
│  • docker-compose.yaml                                           │
│  • .env files (local secrets)                                    │
│  • :latest image tags (auto-update)                             │
│  • Fast iteration                                                │
│  • Local storage volumes                                         │
│                                                                   │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │  Configuration Sync
                 │  (Manual + Validation)
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                  PRODUCTION (Kubernetes)                         │
│                                                                   │
│  • k8s/*.yaml (plain manifests)                                 │
│  • helm/lightrag/* (Helm charts)                                │
│  • Specific version tags (controlled updates)                   │
│  • ConfigMaps + Secrets                                          │
│  • Persistent Volumes                                            │
│  • Resource limits + autoscaling                                 │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Why This Approach?

**Development (Docker Compose)**:
- ✅ Fast startup and iteration
- ✅ Simple configuration with .env files
- ✅ Easy debugging
- ✅ Works on any machine with Docker
- ✅ Matches local development patterns

**Production (Kubernetes)**:
- ✅ Scalability and high availability
- ✅ Resource management
- ✅ Rolling updates and rollbacks
- ✅ Service discovery and load balancing
- ✅ Cloud-native operations

## Development Workflow

### Step 1: Local Development

Work with Docker Compose for day-to-day development:

```bash
# Start the stack
docker compose up -d

# View logs
docker compose logs -f rag

# Make code changes (hot reload in many cases)
# Edit .env files for configuration changes

# Restart specific service
docker compose restart rag

# Stop everything
docker compose down
```

### Step 2: Test Changes

Before syncing to Kubernetes configs:

```bash
# Verify everything works locally
docker compose ps
docker compose logs

# Test API endpoints
curl http://localhost:9621/health

# Test chat interface
open http://chat.dev.localhost
```

### Step 3: Check Configuration Drift

Run the sync validation script to identify differences:

```bash
# From project root
./scripts/sync-config.sh
```

This will report:
- Image version differences
- Environment variable mismatches
- Port configuration issues
- Resource limit discrepancies
- Common mistakes (like :latest tags in k8s)

### Step 4: Sync Configuration Changes

Based on the drift report, manually sync changes:

#### A. Image Version Updates

When you update an image in `docker-compose.yaml`:

```yaml
# docker-compose.yaml
services:
  rag:
    image: ghcr.io/hkuds/lightrag:latest  # Dev can use :latest
```

Update in **both** k8s and Helm:

```yaml
# k8s/07-lightrag.yaml
image: ghcr.io/hkuds/lightrag:0.0.6  # Specific version

# helm/lightrag/values.yaml
lightrag:
  image:
    repository: ghcr.io/hkuds/lightrag
    tag: "0.0.6"  # Specific version
```

#### B. Environment Variable Changes

When you add/change env vars in `docker-compose.yaml`:

```yaml
# docker-compose.yaml
services:
  rag:
    environment:
      - NEW_FEATURE_FLAG=enabled
```

Update in **both** k8s and Helm:

```yaml
# k8s/01-configmaps.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: lightrag-config
data:
  NEW_FEATURE_FLAG: "enabled"

# helm/lightrag/values.yaml
lightrag:
  config:
    newFeatureFlag: "enabled"
```

#### C. Port Changes

When you change ports in `docker-compose.yaml`:

```yaml
# docker-compose.yaml
services:
  rag:
    ports:
      - "9621:9621"  # HOST:CONTAINER
```

Update in **both** k8s and Helm:

```yaml
# k8s/07-lightrag.yaml
kind: Service
spec:
  ports:
  - port: 9621
    targetPort: 9621

# helm/lightrag/values.yaml
lightrag:
  service:
    port: 9621
```

#### D. Resource Limits

Resource limits are typically **different** between dev and prod:

```yaml
# docker-compose.yaml (optional, loose limits)
services:
  rag:
    deploy:
      resources:
        limits:
          memory: 8G  # Generous for development

# k8s/07-lightrag.yaml (required, tuned for production)
resources:
  limits:
    memory: 4Gi  # Optimized based on monitoring
    cpu: 2000m
  requests:
    memory: 2Gi
    cpu: 1000m
```

### Step 5: Test Kubernetes Deployment

Before deploying to production, test in a staging environment:

```bash
# Option 1: Test with Kind (local K8s)
kind create cluster --name lightrag-test
kubectl apply -f k8s/

# Option 2: Test with Helm
helm install lightrag-test ./helm/lightrag \
  --namespace lightrag-test \
  --create-namespace \
  --dry-run --debug  # First do dry-run

# Option 3: Test in cloud staging environment
kubectl apply -f k8s/ --namespace=staging
```

### Step 6: Deploy to Production

Once validated:

```bash
# Option A: kubectl (simple deployments)
kubectl apply -f k8s/ --namespace=production

# Option B: Helm (recommended for production)
helm upgrade --install lightrag ./helm/lightrag \
  --namespace production \
  --values values-production.yaml
```

## Configuration Synchronization

### What Needs to Stay in Sync?

| Configuration Type | Docker Compose | K8s Manifests | Helm Values | Sync Required? |
|--------------------|----------------|---------------|-------------|----------------|
| **Image names** | ✓ | ✓ | ✓ | ⚠️ Tags differ (latest vs specific) |
| **Ports** | ✓ | ✓ | ✓ | ✓ Must match |
| **Environment variables** | ✓ (.env) | ✓ (ConfigMap) | ✓ (values) | ✓ Names & values |
| **Secrets** | ✓ (.env) | ✓ (Secrets) | ✓ (--set/sealed) | ⚠️ Different format |
| **Resource limits** | ✓ (optional) | ✓ (required) | ✓ (required) | ✗ Can differ |
| **Volume paths** | ✓ | ✓ (PVC) | ✓ (PVC) | ⚠️ Different implementation |

### Configuration Sources

```
SINGLE SOURCE OF TRUTH (per environment):

Development:
├── docker-compose.yaml          ← Primary config for dev
├── .env                          ← Dev secrets
├── .env.lightrag                 ← LightRAG config
└── .env.caddy                    ← Caddy config

Production (kubectl):
├── k8s/01-configmaps.yaml       ← Non-secret config
├── k8s/02-secrets.yaml          ← Secret config (template)
└── k8s/03-10-*.yaml             ← Service definitions

Production (Helm):
├── helm/lightrag/values.yaml    ← PRIMARY SOURCE OF TRUTH
├── values-staging.yaml          ← Staging overrides
└── values-production.yaml       ← Production overrides
```

### Sync Checklist

When you change configuration in docker-compose, use this checklist:

- [ ] **Image updated?**
  - [ ] Update k8s/*.yaml with specific version tag
  - [ ] Update helm/lightrag/values.yaml
  - [ ] Document version in changelog

- [ ] **New environment variable?**
  - [ ] Add to k8s/01-configmaps.yaml
  - [ ] Add to helm/lightrag/values.yaml config section
  - [ ] Update documentation

- [ ] **Port changed?**
  - [ ] Update k8s service definitions
  - [ ] Update helm service port values
  - [ ] Update ingress routes if needed

- [ ] **New secret?**
  - [ ] Add to k8s/02-secrets.yaml (as placeholder)
  - [ ] Document in helm/lightrag/README.md
  - [ ] Update secret management procedures

- [ ] **Resource limit tuned?**
  - [ ] Evaluate if k8s limits need adjustment
  - [ ] Update helm values if needed
  - [ ] Document reasoning

- [ ] **Validation**
  - [ ] Run `./scripts/sync-config.sh`
  - [ ] Test in staging K8s environment
  - [ ] Verify all services start correctly

## Automated Checking

### Pre-commit Hook

Add automatic sync checking before commits:

```bash
# .git/hooks/pre-commit
#!/bin/bash

if git diff --cached --name-only | grep -q "docker-compose.yaml"; then
    echo "docker-compose.yaml changed, checking sync..."
    ./scripts/sync-config.sh

    if [ $? -ne 0 ]; then
        echo ""
        echo "⚠️  Configuration sync issues detected!"
        echo "Review the output above and sync changes to k8s/helm configs."
        echo ""
        echo "To bypass this check: git commit --no-verify"
        exit 1
    fi
fi
```

### CI/CD Integration

**Automated PR Checks (Already Configured)**: Configuration sync validation runs automatically on pull requests via `.github/workflows/config-sync-check.yml`. When you create or update a PR that modifies configuration files, the workflow will:

1. Run `./scripts/sync-config.sh --ci` to check for drift
2. Post a comment to the PR with:
   - ✅ All synchronized / ⚠️ Warnings / ❌ Errors
   - Detailed drift findings (expandable section)
   - Sync checklist and recommendations
   - Commit hash and timestamp
3. Update the same comment on new commits (single comment per PR)
4. Fail CI if configuration errors are detected

**Manual CI/CD Integration** (for other CI systems like GitLab CI, Jenkins, etc.):

```yaml
# Example for other CI systems
name: Validate Configuration Sync

on:
  pull_request:
    paths:
      - 'docker-compose.yaml'
      - 'k8s/**'
      - 'helm/**'

jobs:
  sync-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install yq (optional)
        run: |
          sudo wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          sudo chmod +x /usr/local/bin/yq

      - name: Run sync validation
        run: ./scripts/sync-config.sh --ci
```

## Best Practices

### 1. Image Version Management

```bash
# ✓ GOOD: Development
image: ghcr.io/hkuds/lightrag:latest

# ✓ GOOD: Production
image: ghcr.io/hkuds/lightrag:0.0.5

# ✗ BAD: Production with :latest
image: ghcr.io/hkuds/lightrag:latest
```

### 2. Environment Variables

```bash
# ✓ GOOD: Consistent naming
# docker-compose
LIGHTRAG_KV_STORAGE=RedisKVStorage

# k8s ConfigMap
LIGHTRAG_KV_STORAGE: "RedisKVStorage"

# ✗ BAD: Different naming
# docker-compose: LIGHTRAG_KV_STORAGE
# k8s: KV_STORAGE_TYPE
```

### 3. Secrets Management

```bash
# ✓ GOOD: Development
# .env (git-ignored)
OPENAI_API_KEY=sk-xxx

# ✓ GOOD: Production
# k8s Secrets (base64 encoded, not in git)
kubectl create secret generic lightrag-secrets \
  --from-literal=OPENAI_API_KEY=sk-xxx

# ✗ BAD: Secrets in git
# .env (committed to git)
OPENAI_API_KEY=sk-xxx
```

### 4. Configuration Comments

Add sync reminders in config files:

```yaml
# docker-compose.yaml
services:
  rag:
    image: ghcr.io/hkuds/lightrag:latest
    # SYNC NOTE: When changing image version, update:
    # - k8s/07-lightrag.yaml
    # - helm/lightrag/values.yaml
    environment:
      - MAX_PARALLEL_INSERT=4
      # SYNC NOTE: New env vars must be added to k8s ConfigMap
```

### 5. Documentation

Keep a CHANGELOG for configuration changes:

```markdown
## 2024-01-15
- Updated LightRAG image to v0.0.6
  - docker-compose.yaml: ✓
  - k8s/07-lightrag.yaml: ✓
  - helm/lightrag/values.yaml: ✓

- Added NEW_FEATURE_FLAG environment variable
  - docker-compose.yaml: ✓
  - k8s/01-configmaps.yaml: ✓
  - helm/lightrag/values.yaml: ✓
```

## Troubleshooting

### Issue: Changes not reflected in K8s

**Problem**: Modified environment variable in docker-compose, but K8s pod still has old value.

**Solution**:
```bash
# 1. Check if ConfigMap was updated
kubectl get configmap lightrag-config -n lightrag -o yaml

# 2. If ConfigMap is correct but pods unchanged, restart them
kubectl rollout restart deployment/lightrag -n lightrag

# 3. Pods don't automatically reload ConfigMaps without restart
```

### Issue: Image version mismatch

**Problem**: K8s pulling wrong image version.

**Solution**:
```bash
# 1. Check current image
kubectl describe pod <pod-name> -n lightrag | grep Image:

# 2. Verify manifest has correct version
grep "image:" k8s/07-lightrag.yaml

# 3. Update and apply
kubectl apply -f k8s/07-lightrag.yaml

# 4. Force pod recreation
kubectl delete pod -l app.kubernetes.io/name=lightrag -n lightrag
```

### Issue: Port conflicts

**Problem**: Service not accessible after port change.

**Solution**:
```bash
# 1. Verify Service ports
kubectl get svc lightrag -n lightrag -o yaml

# 2. Check container port matches
kubectl get pod <pod-name> -n lightrag -o yaml | grep containerPort

# 3. Check Ingress routing
kubectl get ingress -n lightrag -o yaml

# 4. Ensure all three match: container port, service port, ingress target
```

### Issue: Secrets not syncing

**Problem**: Updated secret in .env but K8s still has old value.

**Solution**:
```bash
# 1. Check current secret
kubectl get secret lightrag-secrets -n lightrag -o jsonpath='{.data.OPENAI_API_KEY}' | base64 -d

# 2. Update secret
kubectl create secret generic lightrag-secrets \
  --from-literal=OPENAI_API_KEY='sk-new-key' \
  --namespace lightrag \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart pods to pick up new secret
kubectl rollout restart deployment/lightrag -n lightrag
```

## Summary

The key to successful docker-compose → Kubernetes synchronization:

1. **Develop locally** with docker-compose for speed
2. **Validate changes** with `./scripts/sync-config.sh`
3. **Manually sync** configuration to k8s/Helm
4. **Test in staging** before production
5. **Document changes** in your changelog
6. **Automate checks** with pre-commit hooks and CI/CD

Remember: **There is no fully automatic sync** because the environments have different requirements (e.g., :latest vs specific versions, resource limits, etc.). The sync script helps you catch drift, but manual review ensures production-appropriate configurations.

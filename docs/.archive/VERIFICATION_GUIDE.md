# K8s Deployment Verification Guide

## Overview

The project provides two levels of verification:

1. **Quick Verification** - Built into `deploy.sh --verify` (fast, essential checks)
2. **Full Verification** - Standalone `verify-deployment.sh` (comprehensive, all tests)

## Quick Verification (Recommended)

### Using MISE
```bash
mise run k8s-verify
```

### Using deploy.sh directly
```bash
cd k8s
./deploy.sh --verify
```

### What It Checks
- ✓ Namespace exists
- ✓ All pods Running and Ready (redis, memgraph, qdrant, lightrag, lobechat)
- ✓ All services exist
- ✓ No containers using `:latest` tag

### When It Runs
- **Automatically** after `./deploy.sh --apply` completes
- **On demand** via `--verify` flag
- **Via MISE** with `mise run k8s-verify`
- **Interactive menu** option 4

### Output Example
```
[INFO] Running deployment verification...

✓ Namespace 'lightrag' exists
[INFO] Checking pods...
✓ Pod 'redis' is Running and Ready
✓ Pod 'memgraph' is Running and Ready
✓ Pod 'memgraph-lab' is Running and Ready
✓ Pod 'qdrant' is Running and Ready
✓ Pod 'lightrag' is Running and Ready
✓ Pod 'lobechat' is Running and Ready
[INFO] Checking services...
✓ Service 'redis' exists
✓ Service 'memgraph' exists
✓ Service 'memgraph-lab' exists
✓ Service 'qdrant' exists
✓ Service 'lightrag' exists
✓ Service 'lobechat' exists
[INFO] Checking image tags...
✓ No containers using :latest tag

[SUCCESS] Deployment verification passed!

Next steps:
  - Access services: mise run k8s-port-forward
  - View logs: ./deploy.sh --logs <pod-name>
  - Full verification: ./verify-deployment.sh
```

## Full Verification (Comprehensive)

### Using MISE
```bash
mise run k8s-verify-full
```

### Using script directly
```bash
cd k8s
./verify-deployment.sh
```

### What It Checks
- ✓ kubectl is installed
- ✓ Connected to K8s cluster
- ✓ Namespace exists
- ✓ ConfigMaps exist (lightrag-config, lobechat-config)
- ✓ Secrets exist (lightrag-secrets, redis-secret)
- ✓ PVCs are Bound (all 9 volumes)
- ✓ Pods are Running and Ready (with detailed status)
- ✓ Services have ClusterIPs
- ✓ Ingress exists
- ✓ No :latest tags
- ✓ Database connectivity (Redis, Memgraph, Qdrant)

### When to Use
- **First deployment** - Verify everything is configured correctly
- **Troubleshooting** - Diagnose issues with detailed checks
- **Production readiness** - Ensure all components are healthy
- **Post-update** - Verify changes didn't break anything

### Output Example
```
======================================
  LightRAG K8s Deployment Verification
======================================

[✓ PASS] kubectl is installed
[✓ PASS] Connected to Kubernetes cluster
[✓ PASS] Namespace 'lightrag' exists
[INFO] Checking ConfigMaps...
[✓ PASS] ConfigMap 'lightrag-config' exists
[✓ PASS] ConfigMap 'lobechat-config' exists
[INFO] Checking Secrets...
[✓ PASS] Secret 'lightrag-secrets' exists
[✓ PASS] Secret 'redis-secret' exists
[INFO] Checking PersistentVolumeClaims...
[✓ PASS] PVC 'redis-data' is Bound
[✓ PASS] PVC 'memgraph-data' is Bound
[✓ PASS] PVC 'memgraph-log' is Bound
[✓ PASS] PVC 'qdrant-storage' is Bound
[✓ PASS] PVC 'qdrant-snapshots' is Bound
[✓ PASS] PVC 'lightrag-storage' is Bound
[✓ PASS] PVC 'lightrag-inputs' is Bound
[✓ PASS] PVC 'lightrag-logs' is Bound
[✓ PASS] PVC 'lobechat-data' is Bound
[INFO] Checking Pods...
[✓ PASS] Pod 'redis' is Running
[✓ PASS] Pod 'redis' is Ready
[✓ PASS] Pod 'memgraph' is Running
[✓ PASS] Pod 'memgraph' is Ready
[✓ PASS] Pod 'memgraph-lab' is Running
[✓ PASS] Pod 'memgraph-lab' is Ready
[✓ PASS] Pod 'qdrant' is Running
[✓ PASS] Pod 'qdrant' is Ready
[✓ PASS] Pod 'lightrag' is Running
[✓ PASS] Pod 'lightrag' is Ready
[✓ PASS] Pod 'lobechat' is Running
[✓ PASS] Pod 'lobechat' is Ready
[INFO] Checking Services...
[✓ PASS] Service 'redis' exists (ClusterIP: 10.96.123.45)
[✓ PASS] Service 'memgraph' exists (ClusterIP: 10.96.123.46)
[✓ PASS] Service 'memgraph-lab' exists (ClusterIP: 10.96.123.47)
[✓ PASS] Service 'qdrant' exists (ClusterIP: 10.96.123.48)
[✓ PASS] Service 'lightrag' exists (ClusterIP: 10.96.123.49)
[✓ PASS] Service 'lobechat' exists (ClusterIP: 10.96.123.50)
[INFO] Checking Ingress...
[✓ PASS] Ingress resources exist
[⚠ WARN] Ingress IP/hostname not yet assigned (may take a few minutes)
[INFO] Checking container image versions...
[✓ PASS] No containers using :latest tag
[INFO] Checking database connectivity...
[✓ PASS] LightRAG can reach Redis
[✓ PASS] LightRAG can reach Memgraph
[✓ PASS] LightRAG can reach Qdrant

======================================
  Verification Summary
======================================
Passed:   42
Warnings: 1
Failed:   0

[SUCCESS] All critical checks passed!
[⚠ WARN] Some warnings were found - review them above
```

## Comparison

| Feature          | Quick (`--verify`) | Full (`verify-deployment.sh`) |
| ---------------- | ------------------ | ----------------------------- |
| **Speed**        | ~5 seconds         | ~15-30 seconds                |
| **Checks**       | 15+ checks         | 40+ checks                    |
| **Auto-run**     | Yes (after deploy) | No                            |
| **Use case**     | Daily verification | First deploy, troubleshooting |
| **Detail level** | Basic              | Comprehensive                 |
| **Connectivity** | No                 | Yes                           |
| **PVC status**   | No                 | Yes (detailed)                |
| **ConfigMaps**   | No                 | Yes                           |

## Usage Patterns

### After Deployment
```bash
# Quick check (automatically runs)
mise run k8s-deploy
# Output includes verification results

# Manual re-check
mise run k8s-verify
```

### Troubleshooting Issues
```bash
# 1. Quick check first
./deploy.sh --verify

# 2. If issues found, run full check
./verify-deployment.sh

# 3. Check specific pod logs
./deploy.sh --logs <pod-name>

# 4. Check events
kubectl get events -n lightrag --sort-by='.lastTimestamp'
```

### Regular Health Checks
```bash
# Daily quick check
mise run k8s-verify

# Weekly full check
mise run k8s-verify-full

# Continuous monitoring
watch -n 5 'kubectl get pods -n lightrag'
```

### CI/CD Integration
```bash
# Quick verification (recommended for CI)
./deploy.sh --verify || exit 1

# Full verification (for staging/production)
./verify-deployment.sh || exit 1
```

## Exit Codes

Both scripts follow standard exit codes:

- **0** - All checks passed
- **1** - Some checks failed or warnings present

Quick verification returns:
- `0` if all essential checks pass
- `1` if any pod/service is missing or not ready

Full verification returns:
- `0` if all checks pass (warnings allowed)
- `1` if any critical check fails

## Troubleshooting Common Issues

### "Namespace not found"
```bash
# Check if namespace exists
kubectl get namespace lightrag

# Recreate if missing
kubectl apply -f k8s/00-namespace.yaml
```

### "Pod not Ready"
```bash
# Check pod details
kubectl describe pod -n lightrag <pod-name>

# Check logs
./deploy.sh --logs <pod-name>

# Check events
kubectl get events -n lightrag
```

### "Service not found"
```bash
# List all services
kubectl get svc -n lightrag

# Reapply service
kubectl apply -f k8s/04-redis.yaml  # example
```

### "Latest tag found"
```bash
# Find which pod
kubectl get pods -n lightrag -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n'

# Fix in manifest
nano k8s/08-lobechat.yaml  # example

# Redeploy
kubectl apply -f k8s/08-lobechat.yaml
```

## Best Practices

1. **Always verify after deployment**
   - Quick verification runs automatically
   - Review the output before proceeding

2. **Use appropriate verification level**
   - Quick for daily checks
   - Full for important changes

3. **Integrate with automation**
   - CI/CD pipelines should run verification
   - Use exit codes for automation

4. **Monitor regularly**
   - Set up periodic health checks
   - Use `watch` for continuous monitoring

5. **Keep logs for troubleshooting**
   - Save verification output
   - Compare before/after changes

## Integration with MISE

MISE provides convenient aliases:

```bash
# Quickverification (built into deploy.sh)
mise run k8s-verify

# Full verification
mise run k8s-verify-full

# Both are dependencies-aware
# They check kubectl is installed first
```

## Summary

- **Quick verification** (`deploy.sh --verify`) - Fast, essential checks, auto-runs
- **Full verification** (`verify-deployment.sh`) - Comprehensive, all tests, manual
- **Use quick** for daily checks and CI/CD
- **Use full** for first deploy, troubleshooting, production readiness
- **MISE integration** makes both easily accessible

For more details, see:
- `deploy.sh --help` - Built-in verification options
- `MISE_QUICK_REFERENCE.md` - MISE task overview
- `DEPLOYMENT_GUIDE.md` - Complete deployment workflow

# LightRAG Deployment Strategy

This document explains the deployment options and the relationship between different configuration sources.

## 📁 Directory Structure

```
lightrag/
├── docker-compose.yaml          # Docker Compose (local development)
├── scripts/                     # Deployment scripts
│   ├── k8s-deploy.sh            # K8s deployment helper
│   ├── k8s-validate.sh          # Validation (78 checks)
│   ├── k8s-generate-from-helm.sh  # Generate from Helm
│   └── k8s-generate-secrets.sh  # Generate secrets from mise
├── k8s/                         # Plain Kubernetes manifests
│   ├── 00-namespace.yaml        # Static YAML files
│   ├── 01-configmaps.yaml       # Ready for kubectl apply
│   ├── ...                      # No templating
│   └── generated/               # Generated from Helm (git-ignored)
└── helm/lightrag/               # Helm chart
    ├── Chart.yaml               # Chart metadata
    ├── values.yaml              # Configuration values (SOURCE OF TRUTH)
    ├── templates/               # Helm templates
    │   ├── NOTES.txt            # Post-install instructions
    │   ├── _helpers.tpl         # Template helpers
    │   └── README.md            # Template documentation
    └── README.md                # Helm usage guide
```

## 🎯 Single Source of Truth: Two Paths

We maintain TWO deployment paths, each with its own source of truth:

### Path 1: Simple Kubernetes (k8s/)

**Source of Truth**: `k8s/*.yaml` (static YAML files)

**Best For**:
- Quick testing and learning
- Simple deployments
- When you don't need customization
- kubectl apply workflows

**Pros**:
- Simple to understand
- No tools required (just kubectl)
- Easy to inspect and modify
- Great for learning Kubernetes

**Cons**:
- No customization without editing files
- Hard to manage multiple environments
- Manual updates for configuration changes

**Usage**:
```bash
./scripts/k8s-validate.sh     # Validate manifests
kubectl apply -f k8s/         # Deploy everything
```

### Path 2: Helm Chart (helm/lightrag/)

**Source of Truth**: `helm/lightrag/values.yaml` + templates

**Best For**:
- Production deployments
- Multiple environments (dev/staging/prod)
- Easy customization
- Automated CI/CD pipelines

**Pros**:
- Environment-specific configuration
- Easy upgrades and rollbacks
- Template-driven (DRY principle)
- Standard Kubernetes package format

**Cons**:
- Requires Helm installation
- More complex for beginners
- Templates can be harder to debug

**Usage**:
```bash
cd helm/lightrag

# Install with custom values
helm install lightrag . \
  --namespace lightrag \
  --create-namespace \
  --set secrets.redisPassword="secure-password" \
  --set global.publishDomain="myapp.com"

# Or with values file
helm install lightrag . -f my-production-values.yaml
```

## 🔄 Generating Plain Manifests from Helm

If you want the flexibility of Helm but need static YAML:

```bash
# Generate to k8s/generated/ directory
./scripts/k8s-generate-from-helm.sh

# Deploy generated manifests
kubectl apply -f k8s/generated/

# Or generate with custom values
helm template lightrag ../helm/lightrag \
  --namespace lightrag \
  -f my-values.yaml \
  > generated/all.yaml
```

## 🤔 Which Path Should I Use?

### Use Plain k8s/ if you:
- ✅ Want simple, straightforward deployment
- ✅ Are learning Kubernetes
- ✅ Have a single environment
- ✅ Prefer direct YAML inspection
- ✅ Don't need much customization

### Use Helm if you:
- ✅ Need multiple environments (dev/staging/prod)
- ✅ Want easy version management
- ✅ Need to customize many values
- ✅ Use CI/CD pipelines
- ✅ Deploy to cloud providers
- ✅ Want production-ready packaging

### Use Generated Manifests if you:
- ✅ Want Helm's flexibility but need static YAML
- ✅ Your cluster doesn't allow Helm
- ✅ Need to review exact resources before deployment
- ✅ Want to commit generated manifests to GitOps repo

## 📊 Comparison Table

| Feature              | Plain k8s/ | Helm Chart    | Generated     |
| -------------------- | ---------- | ------------- | ------------- |
| **Simplicity**       | ⭐⭐⭐⭐⭐      | ⭐⭐⭐           | ⭐⭐⭐⭐          |
| **Customization**    | ⭐⭐         | ⭐⭐⭐⭐⭐         | ⭐⭐⭐⭐          |
| **Multi-env**        | ⭐          | ⭐⭐⭐⭐⭐         | ⭐⭐⭐           |
| **Version Control**  | ⭐⭐⭐        | ⭐⭐⭐⭐⭐         | ⭐⭐⭐           |
| **Learning Curve**   | Easy       | Medium        | Easy          |
| **Tools Required**   | kubectl    | kubectl, helm | kubectl, helm |
| **Production Ready** | Yes        | Yes           | Yes           |

## 🚫 What We DON'T Do (Avoiding Duplication)

We **DO NOT**:
- ❌ Duplicate plain YAML files in Helm templates
- ❌ Maintain identical configurations in multiple places
- ❌ Copy manifests between k8s/ and helm/

We **DO**:
- ✅ Keep k8s/ manifests simple and static
- ✅ Keep Helm chart with values-driven templates
- ✅ Generate one from the other when needed
- ✅ Document both approaches clearly

## 🔧 Maintenance Strategy

### Updating k8s/ Manifests

When you need to update the plain manifests:

1. Edit files in `k8s/*.yaml` directly
2. Run validation: `./bin/k8s-validate.sh`
3. Test deployment: `kubectl apply --dry-run=client -f k8s/`
4. Commit changes

### Updating Helm Chart

When you need to update Helm configuration:

1. Edit `helm/lightrag/values.yaml` for defaults
2. Update templates in `helm/lightrag/templates/` if needed
3. Test: `helm lint helm/lightrag`
4. Test install: `helm install test helm/lightrag --dry-run --debug`
5. Commit changes

### Keeping Them in Sync

**You don't have to!** They serve different purposes:

- **k8s/**: Simple, working examples
- **helm/**: Production-ready, customizable deployment

If you want to sync:
```bash
# Generate from Helm to k8s/generated/
./scripts/k8s-generate-from-helm.sh

# Review differences
diff -u 04-redis.yaml generated/*redis*.yaml
```

## 🌍 Real-World Scenarios

### Scenario 1: Local Development
```bash
# Use docker-compose for fastest startup
docker-compose up -d

# OR use k8s with Kind for testing
kind create cluster
kubectl apply -f k8s/
```

### Scenario 2: Cloud Deployment (Dev)
```bash
# Use Helm with dev values
helm install lightrag helm/lightrag \
  -f helm/lightrag/values-dev.yaml \
  --namespace lightrag-dev \
  --create-namespace
```

### Scenario 3: Cloud Deployment (Production)
```bash
# Use Helm with production values
helm install lightrag helm/lightrag \
  -f helm/lightrag/values-prod.yaml \
  --namespace lightrag \
  --create-namespace \
  --set secrets.redisPassword=$REDIS_PASSWORD \
  --set secrets.llmBindingApiKey=$LLM_API_KEY
```

### Scenario 4: GitOps Workflow
```bash
# Generate manifests for ArgoCD/Flux
helm template lightrag helm/lightrag \
  -f helm/lightrag/values-prod.yaml \
  > gitops/prod/lightrag.yaml

# Commit to Git
git add gitops/prod/lightrag.yaml
git commit -m "Update LightRAG prod manifests"
```

## 📚 Further Reading

- [k8s/README.md](k8s/README.md) - Plain Kubernetes deployment guide
- [k8s/CLOUD_DEPLOYMENT.md](k8s/CLOUD_DEPLOYMENT.md) - Cloud provider guides
- [k8s/TESTING.md](k8s/TESTING.md) - Testing with Kind
- [helm/lightrag/README.md](helm/lightrag/README.md) - Helm chart usage
- [helm/lightrag/values.yaml](helm/lightrag/values.yaml) - All configuration options

## ❓ FAQ

**Q: Why not use Kustomize?**
A: Kustomize is great! You can layer it on top of either approach. We chose Helm for its wider adoption and built-in versioning.

**Q: Can I use both k8s/ and helm/ together?**
A: No, choose one. They'll conflict if deployed to the same namespace.

**Q: Which is the "real" source of truth?**
A: Both are valid sources for their use cases. Helm is more flexible, k8s/ is simpler.

**Q: How do I migrate from k8s/ to Helm?**
A: Just start using Helm! Your data persists in PVCs, so you can uninstall k8s/ deployment and install with Helm.

**Q: Can I contribute changes to both?**
A: Yes! Please keep them functionally equivalent but don't duplicate code.

## 🎓 Recommendations

**For Learning**: Start with `k8s/` plain manifests
**For Production**: Use `helm/lightrag/` Helm chart
**For GitOps**: Generate from Helm to static YAML
**For Cloud**: Use Helm with cloud-specific values files

---

**Remember**: The goal is flexibility, not perfection. Choose what works best for your use case!

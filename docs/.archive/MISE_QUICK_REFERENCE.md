# MISE Quick Reference for K8s

## One-Time Setup

```bash
# Install mise
brew install mise  # or scoop install mise on Windows

# Navigate to project and trust
cd /mnt/wsl/workspace/rag
mise trust
mise install

# Setup secrets encryption
age-keygen -o .secrets/mise-age.txt
mkdir -p ~/.config/mise
cp .secrets/mise-age.txt ~/.config/mise/age.txt

# Create secrets file
cp .env.secrets.example.json .env.secrets.json
nano .env.secrets.json  # Add your API keys

# Encrypt secrets
PUBLIC_KEY=$(grep 'public key:' .secrets/mise-age.txt | cut -d: -f2 | xargs)
sops encrypt -i --age "$PUBLIC_KEY" .env.secrets.json
```

## Daily Workflow

```bash
# Create cluster (first time only)
mise run k8s-cluster-create

# Deploy application
mise run k8s-deploy

# Verify everything works
mise run k8s-verify

# Port forward to access services
mise run k8s-port-forward

# View logs
mise run k8s-logs -- lightrag-<pod-id>

# Check status
mise run k8s-status

# Delete deployment (keeps cluster)
mise run k8s-delete

# Delete cluster
mise run k8s-cluster-delete
```

## Available MISE Tasks

| Command                         | Description                                           |
| ------------------------------- | ----------------------------------------------------- |
| `mise run k8s-check-tools`      | Verify kubectl and kind are installed                 |
| `mise run k8s-cluster-create`   | Create KIND cluster named 'lightrag'                  |
| `mise run k8s-cluster-delete`   | Delete KIND cluster                                   |
| `mise run k8s-secrets-generate` | Generate K8s secrets from mise env                    |
| `mise run k8s-deploy`           | Deploy full stack (auto-generates secrets + verifies) |
| `mise run k8s-verify`           | Quick verification (pods, services, tags)             |
| `mise run k8s-verify-full`      | Comprehensive verification (all tests)                |
| `mise run k8s-status`           | Show pod/service status                               |
| `mise run k8s-logs`             | View pod logs                                         |
| `mise run k8s-port-forward`     | Port forward all services                             |
| `mise run k8s-delete`           | Delete deployment                                     |

## Common Tasks

### Update Secrets

```bash
# Edit encrypted secrets
sops .env.secrets.json  # Opens in $EDITOR

# Regenerate K8s secrets
mise run k8s-secrets-generate

# Apply updated secrets
kubectl apply -f k8s/02-secrets.yaml

# Restart pods to pick up new secrets
kubectl rollout restart deployment -n lightrag lightrag
kubectl rollout restart deployment -n lightrag lobechat
```

### Troubleshooting

```bash
# Check mise environment
mise env | grep -E '(LLM_|EMBEDDING_|REDIS_)'

# Verify secrets can decrypt
sops decrypt .env.secrets.json

# Check what's in generated secrets
cat k8s/02-secrets.yaml | grep "managed-by: mise"

# View pod logs for errors
mise run k8s-logs -- $(kubectl get pod -n lightrag -l app.kubernetes.io/name=lightrag -o name | head -1 | cut -d/ -f2)

# Get into a pod for debugging
kubectl exec -it -n lightrag deployment/lightrag -- /bin/sh
```

### Access Services

```bash
# Start port forwarding (blocks terminal)
mise run k8s-port-forward

# Or manual background forwarding
kubectl port-forward -n lightrag svc/lobechat 3210:3210 &
kubectl port-forward -n lightrag svc/lightrag 9621:9621 &
kubectl port-forward -n lightrag svc/memgraph-lab 3000:3000 &

# URLs:
# - LobeChat: http://localhost:3210
# - LightRAG API: http://localhost:9621/api/tags
# - Memgraph Lab: http://localhost:3000
```

### Clean Up

```bash
# Delete deployment but keep cluster
mise run k8s-delete

# Delete everything
mise run k8s-delete
mise run k8s-cluster-delete

# Force delete stuck resources
kubectl delete namespace lightrag --force --grace-period=0
```

## Environment Variables Used

From `.env`:
- `PUBLISH_DOMAIN` - Base domain (default: dev.localhost)
- `REDIS_PASSWORD` - Redis authentication
- `LIGHTRAG_API_KEY` - LightRAG API authentication
- `LOBECHAT_ACCESS_CODE` - LobeChat access code
- `MONITOR_BASIC_AUTH_HASH` - Monitor basic auth

From `.env.secrets.json` (SOPS-encrypted):
- `LLM_BINDING_API_KEY` - OpenAI API key for LLM
- `EMBEDDING_BINDING_API_KEY` - OpenAI API key for embeddings
- `DEFAULT_ADMIN_EMAIL` - Admin email

## Tips

1. **Keep age key private**: Never commit `.secrets/mise-age.txt`
2. **Always encrypt**: Run `sops encrypt` before committing secrets
3. **Verify after changes**: Run `mise run k8s-verify` after updates
4. **Use mise env**: Check variables with `mise env | grep SECRET_NAME`
5. **Background ports**: Add `&` to port-forward commands to run in background

## File Locations

- **MISE config**: `mise.toml` (in project root)
- **Age key**: `.secrets/mise-age.txt` (local, gitignored)
- **Encrypted secrets**: `.env.secrets.json` (SOPS-encrypted, can commit)
- **K8s secrets**: `k8s/02-secrets.yaml` (auto-generated, don't commit)
- **MISE docs**: `k8s/MISE_INTEGRATION.md` (detailed guide)

## Help

```bash
# List all mise tasks
mise tasks

# Show task details
mise tasks --extended

# Get help on specific task
mise help run

# Check mise status
mise doctor
```

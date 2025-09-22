# Caddy Docker Proxy Implementation Plan

## Problem Analysis

**Error:** `docker_proxy is not a registered directive, at /etc/caddy/Caddyfile:9`

**Root Cause:** The standard `caddy:2-alpine` Docker image doesn't include the Docker proxy plugin required for the `docker_proxy` directive used in the Caddyfile.

## Solution: Use lucaslorentz/caddy-docker-proxy

We'll replace the standard Caddy image with `lucaslorentz/caddy-docker-proxy`, which includes the necessary Docker proxy plugin for automatic service discovery.

## Required Changes

### 1. Update Docker Compose Configuration

**File:** `docker-compose.yaml`

**Change the image:**
```yaml
# FROM:
image: caddy:2-alpine

# TO:
image: lucaslorentz/caddy-docker-proxy:latest
```

### 2. Update Caddyfile Configuration

**File:** `etc/caddy/Caddyfile`

**Update the global configuration block:**
```caddyfile
# Current problematic configuration:
{
    email admin@local.dev
    acme_ca internal
    order docker_proxy before file_server
    docker_proxy
    auto_https internal
    skip_install_trust
}

# Replace with:
{
    email admin@local.dev
    acme_ca internal
    auto_https internal
    skip_install_trust
}
```

**Note:** The `lucaslorentz/caddy-docker-proxy` image automatically handles Docker service discovery without explicit `docker_proxy` directives in the global block.

### 3. Environment Configuration Updates

**File:** `.env.caddy`

Add Docker proxy specific configurations:
```bash
# Docker Provider Configuration
CADDY_DOCKER_ENDPOINT=unix:///var/run/docker.sock
CADDY_DOCKER_POLLING_INTERVAL=5s
CADDY_DOCKER_REFRESH_INTERVAL=30s

# Network Configuration
CADDY_DOCKER_NETWORK=lightrag_frontend

# Service Discovery Labels
CADDY_DOCKER_PROXY_LABEL_ENABLE=caddy.enable
CADDY_DOCKER_PROXY_LABEL_PREFIX=caddy
```

### 4. Docker Service Label Examples

For services that should be automatically discovered, add labels like:

```yaml
services:
  your-app:
    image: your-app:latest
    labels:
      caddy: your-app.local.dev
      caddy.reverse_proxy: "{{upstreams 8080}}"
    networks:
      - lightrag_frontend
```

## Implementation Steps

1. **Update Docker Compose image reference**
   - Change `image: caddy:2-alpine` to `image: lucaslorentz/caddy-docker-proxy:latest`

2. **Modify Caddyfile global configuration**
   - Remove `order docker_proxy before file_server` line
   - Remove standalone `docker_proxy` line

3. **Update environment variables (optional)**
   - Add Docker proxy specific configurations to `.env.caddy`

4. **Test the configuration**
   - Run `docker-compose down` to stop existing services
   - Run `docker-compose up -d` to start with new configuration
   - Check logs: `docker-compose logs proxy`

5. **Verify functionality**
   - Ensure Caddy starts without errors
   - Test basic reverse proxy functionality
   - Add service labels to test automatic discovery

## Key Benefits of This Solution

- **Automatic Service Discovery**: Services with proper Docker labels are automatically configured
- **No Manual Configuration**: Reduces need for manual Caddyfile updates for each service
- **Popular and Maintained**: `lucaslorentz/caddy-docker-proxy` is widely used and actively maintained
- **Docker Socket Integration**: Properly handles Docker socket communication for service discovery

## Fallback Manual Configuration

If automatic discovery is not needed immediately, the Caddyfile can be simplified to:

```caddyfile
{
    email admin@local.dev
    acme_ca internal
    auto_https internal
    skip_install_trust
}

# Manual service configuration example
your-app.local.dev {
    reverse_proxy your-app-container:8080
}

# Health check and default responses remain the same
:80, :443 {
    respond /health "OK" 200
    respond "LightRAG Local Development Stack" 200
    respond /debug "Environment: local.dev development" 200
}
```

## Testing Checklist

- [ ] Caddy container starts successfully
- [ ] No configuration errors in logs
- [ ] Health check endpoint `/health` responds
- [ ] Default response works on base domain
- [ ] Debug endpoint `/debug` responds
- [ ] Docker socket access is working (if using service discovery)
- [ ] SSL/TLS certificates are properly generated for local development

## Next Steps

After implementing these changes, you can add Docker labels to your application services to enable automatic reverse proxy configuration without manual Caddyfile updates.
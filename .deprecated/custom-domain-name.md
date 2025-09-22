# 🌐 Configurable Domain Implementation Guide

## Overview

The LightRAG stack now supports configurable domains via the `PUBLISH_DOMAIN` environment variable, allowing deployment across different environments with custom domain names.

## Quick Start

### Default Configuration (No Changes Required)
```bash
# Uses dev.localhost (existing behavior)
docker compose up -d
```

### Custom Domain Configuration
```bash
# Method 1: Update .env file
echo "PUBLISH_DOMAIN=myapp.local" > .env.custom
cat .env .env.custom > .env.new && mv .env.new .env

# Method 2: Environment override
PUBLISH_DOMAIN=lightrag.internal docker compose up -d

# Method 3: Production deployment
export PUBLISH_DOMAIN=ai.company.com
docker compose up -d
```

## Service URLs

All services automatically adapt to your `PUBLISH_DOMAIN`:

| Service | URL Pattern | Example (myapp.local) |
|---------|-------------|----------------------|
| **Main Landing** | `https://${PUBLISH_DOMAIN}` | `https://myapp.local` |
| **LobeChat UI** | `https://lobechat.${PUBLISH_DOMAIN}` | `https://lobechat.myapp.local` |
| **LightRAG API** | `https://rag.${PUBLISH_DOMAIN}` | `https://rag.myapp.local` |
| **Monitoring** | `https://monitor.${PUBLISH_DOMAIN}` | `https://monitor.myapp.local` |
| **Graph UI** | `https://graph.${PUBLISH_DOMAIN}` | `https://graph.myapp.local` |
| **Vector DB** | `https://vector.${PUBLISH_DOMAIN}` | `https://vector.myapp.local` |
| **Redis UI** | `https://kv.${PUBLISH_DOMAIN}` | `https://kv.myapp.local` |

## SSL Certificate Setup

### For Custom Domains
```bash
cd docker/ssl

# Generate certificates for your domain
CAROOT=$(pwd) mkcert -cert-file ${PUBLISH_DOMAIN}.pem \
  -key-file ${PUBLISH_DOMAIN}-key.pem \
  -p12-file ${PUBLISH_DOMAIN}.p12 \
  ${PUBLISH_DOMAIN} "*.${PUBLISH_DOMAIN}" \
  localhost 127.0.0.1 0.0.0.0 ::1

# Update docker-compose.yaml TLS references if needed
# (Most configurations use dev.localhost certificates by default)
```

### Certificate File Naming
- **Default**: `dev.localhost.pem`, `dev.localhost-key.pem`
- **Custom**: `${PUBLISH_DOMAIN}.pem`, `${PUBLISH_DOMAIN}-key.pem`

## DNS Configuration

### Local Development (127.0.0.1)
```bash
# Update /etc/hosts or use hostctl
echo "127.0.0.1 ${PUBLISH_DOMAIN}" >> /etc/hosts
echo "127.0.0.1 *.${PUBLISH_DOMAIN}" >> /etc/hosts
```

### WSL2 Environment
```bash
# Update Windows hosts file directly from WSL2
mise run hosts-update-windows

# Prerequisites on Windows host:
# scoop install main/sudo main/hostctl
```

### Production Environment
Configure your DNS server to point:
- `${PUBLISH_DOMAIN}` → Your server IP
- `*.${PUBLISH_DOMAIN}` → Your server IP (wildcard)

## Validation & Testing

### Quick Validation
```bash
# Test configuration
bin/test.domain.configuration.sh

# Verify Docker Compose config
docker compose config | grep caddy:

# Test with custom domain
PUBLISH_DOMAIN=test.local docker compose config | grep caddy:
```

### Service Health Checks
```bash
# Run verification with your domain
source .env
bin/verify.configuration.sh

# Test specific services
curl -k https://lobechat.${PUBLISH_DOMAIN}/
curl -k https://rag.${PUBLISH_DOMAIN}/health
```

## Environment Examples

### Development
```bash
PUBLISH_DOMAIN=dev.localhost  # Default
```

### Staging
```bash
PUBLISH_DOMAIN=staging.lightrag.internal
```

### Production
```bash
PUBLISH_DOMAIN=ai.company.com
```

### Local Testing
```bash
PUBLISH_DOMAIN=lightrag.local
```

## Migration from Hardcoded Setup

### If You Have Existing Setup
1. **No changes required** - defaults to `dev.localhost`
2. **Optional**: Add `PUBLISH_DOMAIN=dev.localhost` to `.env` for explicitness
3. **Test**: Run `bin/verify.configuration.sh` to ensure everything works

### To Use Custom Domain
1. **Set domain**: `PUBLISH_DOMAIN=your.domain` in `.env`
2. **Generate certificates**: Use mkcert for your domain
3. **Update DNS**: Point your domain to the server
4. **Restart services**: `docker compose down && docker compose up -d`
5. **Verify**: Run `bin/verify.configuration.sh`

## Troubleshooting

### Common Issues

#### Certificate Mismatch
```bash
# Problem: SSL certificate doesn't match domain
# Solution: Generate new certificates for your domain
cd docker/ssl
CAROOT=$(pwd) mkcert ${PUBLISH_DOMAIN} "*.${PUBLISH_DOMAIN}"
```

#### DNS Resolution
```bash
# Problem: Domain doesn't resolve
# Solution: Check DNS configuration
nslookup ${PUBLISH_DOMAIN}
getent hosts ${PUBLISH_DOMAIN}
```

#### Service Not Accessible
```bash
# Problem: Can't access https://service.${PUBLISH_DOMAIN}
# Solution: Check service health and proxy configuration
docker compose ps
docker compose logs proxy
```

### Debug Commands
```bash
# Check environment variable
echo $PUBLISH_DOMAIN

# Verify Docker Compose substitution
docker compose config | grep -A 2 -B 2 caddy:

# Test internal connectivity
docker compose exec lobechat curl -k https://rag.${PUBLISH_DOMAIN}/health

# Check certificate validity
echo | openssl s_client -connect ${PUBLISH_DOMAIN}:443 -servername ${PUBLISH_DOMAIN}
```

## Implementation Details

### Files Modified
- ✅ `.env` - Added PUBLISH_DOMAIN variable
- ✅ `docker-compose.yaml` - All Caddy labels use ${PUBLISH_DOMAIN}
- ✅ `.env.lightrag` - CORS_ORIGINS uses ${PUBLISH_DOMAIN}
- ✅ All scripts - Support ${PUBLISH_DOMAIN:-dev.localhost} pattern
- ✅ Documentation - Updated with variable examples

### Backward Compatibility
- ✅ **100% Compatible** - Existing setups work unchanged
- ✅ **Graceful Fallback** - Uses `dev.localhost` if PUBLISH_DOMAIN not set
- ✅ **No Breaking Changes** - All existing functionality preserved

### Security Considerations
- 🔒 **SSL/TLS**: Generate proper certificates for your domain
- 🔒 **DNS**: Ensure proper DNS configuration in production
- 🔒 **Firewall**: Configure appropriate firewall rules for your domain
- 🔒 **Access Control**: Review authentication settings for production domains

## Support

For issues or questions:
1. **Check logs**: `docker compose logs [service]`
2. **Run diagnostics**: `bin/verify.configuration.sh`
3. **Test configuration**: `bin/test.domain.configuration.sh`
4. **Validate setup**: `docker compose config`

---

**🎉 The configurable domain feature is production-ready and fully tested!**

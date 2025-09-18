# Add LobeChat to Existing LightRAG + Open WebUI Stack

## Prerequisites
- Existing LightRAG + Open WebUI stack running
- Docker Compose v2.0+
- 2GB+ available RAM
- Port 3210 available

## Step-by-Step Implementation

### 1. File Structure Setup

Your project should have this structure:
```
lightrag-project/
├── docker-compose.yml          # Main compose file
├── .env                        # Main environment
├── .env.caddy                  # Existing
├── .env.databases              # Existing  
├── .env.lightrag               # Existing
├── .env.openwebui              # Existing
├── .env.lobechat              # ← NEW FILE
├── .env.monitoring             # Existing
└── docker/
    ├── data/
    │   ├── openwebui/          # Existing
    │   ├── lightrag/           # Existing
    │   └── lobechat/           # ← NEW DIRECTORY
    └── ssl/                    # Existing
```

### 2. Create Required Files

#### A. Environment File: `.env.lobechat`
Create this file in your project root:
```bash
# File: .env.lobechat
# Location: ./env.lobechat (same directory as docker-compose.yml)

# Core Configuration
DATABASE_URL=redis://kv:6379/2
REDIS_URL=redis://kv:6379/3
OLLAMA_PROXY_URL=http://rag:9621/v1

# Access Control (optional)
LOBECHAT_ACCESS_CODE=dev-access-2024

# App Settings
NEXT_PUBLIC_APP_NAME="LobeChat + LightRAG"
DEFAULT_AGENT_CONFIG={"model":"lightrag","systemRole":"AI assistant with graph knowledge"}

# Optional LLM Providers (add your keys)
# OPENAI_API_KEY=sk-your-openai-key
# ANTHROPIC_API_KEY=sk-ant-your-anthropic-key

# Feature Flags
ENABLE_OAUTH_SSO=false
ENABLE_LANGFUSE=false
TELEMETRY_ENABLED=false
LOG_LEVEL=info
```

#### B. Create Data Directory
```bash
# Execute in your project root
mkdir -p ./docker/data/lobechat
chmod 755 ./docker/data/lobechat

# Verify directory creation
ls -la ./docker/data/ | grep lobechat
# Expected output: drwxr-xr-x ... lobechat
```

### 3. Docker Compose Changes

#### A. Add Service Definition
Edit your `docker-compose.yml` and add this service under the `services:` section:

```yaml
  # Add this AFTER your existing webui service
  lobechat:
    image: lobehub/lobe-chat:latest
    container_name: lobechat
    restart: unless-stopped
    depends_on:
      - proxy
      - rag
      - kv
    env_file:
      - .env
      - .env.lobechat
    environment:
      - DATABASE_URL=redis://kv:6379/2
      - REDIS_URL=redis://kv:6379/3
      - OLLAMA_PROXY_URL=http://rag:9621/v1
      - ACCESS_CODE=${LOBECHAT_ACCESS_CODE:-}
    volumes:
      - lobechat_data:/app/.next
    networks:
      - frontend
      - backend
    ports:
      - 3210:3210
    labels:
      caddy: "https://lobechat.dev.localhost"
      caddy.reverse_proxy: "{{upstreams 3210}}"
      caddy.tls: "/certificates/dev.localhost.pem /certificates/dev.localhost-key.pem"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3210/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

#### B. Add Volume Definition
Add this under the `volumes:` section at the bottom of your `docker-compose.yml`:

```yaml
  # Add this to your existing volumes section
  lobechat_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./docker/data/lobechat
```

### 4. Health Check Configuration

LobeChat uses these health check endpoints:
- **Primary**: `http://localhost:3210/api/health` - Main health endpoint
- **Alternative**: `http://localhost:3210/` - Basic connectivity
- **Advanced**: `http://localhost:3210/api/config` - Configuration check

The implemented health check:
```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3210/api/health"]
  interval: 30s      # Check every 30 seconds
  timeout: 10s       # Timeout after 10 seconds
  retries: 3         # Retry 3 times before marking unhealthy
  start_period: 60s  # Wait 60s before first check
```

### 5. Deployment Steps

```bash
# 1. Validate compose file syntax
docker compose config

# 2. Pull the new image
docker compose pull lobechat

# 3. Deploy the service
docker compose up -d lobechat

# 4. Check startup logs
docker compose logs -f lobechat

# Expected output should show:
# ✓ Ready on http://0.0.0.0:3210
# ✓ Database connected
# ✓ Redis connected
```

### 6. Verification & Testing

#### A. Service Status Checks
```bash
# Check all services are running
docker compose ps

# Expected output for lobechat:
# NAME       IMAGE                   STATUS        PORTS
# lobechat   lobehub/lobe-chat:latest Up (healthy)  0.0.0.0:3210->3210/tcp

# Check health status specifically
docker compose ps lobechat
# STATUS should show "Up (healthy)" not just "Up"
```

#### B. Network Connectivity Tests
```bash
# Test internal connectivity to LightRAG
docker compose exec lobechat wget -q --spider http://rag:9621/v1/models
echo $?  # Should return 0 (success)

# Test Redis connectivity
docker compose exec lobechat wget -q --spider http://kv:6379
echo $?  # Should return 0 (success)

# Test external access
curl -I https://lobechat.dev.localhost
# Expected: HTTP/2 200 OK
```

#### C. Application Functionality Tests
```bash
# 1. Access the web interface
open https://lobechat.dev.localhost
# OR
curl -s https://lobechat.dev.localhost | grep -q "LobeChat"
echo $?  # Should return 0

# 2. Test API endpoints
curl -s https://lobechat.dev.localhost/api/health
# Expected: {"status":"ok","timestamp":"..."}

# 3. Test LightRAG integration
curl -s https://lobechat.dev.localhost/api/models
# Should list "lightrag" model
```

#### D. Log Verification
```bash
# Check for successful startup messages
docker compose logs lobechat | grep -E "(Ready|Connected|Started)"

# Expected messages:
# ✓ Next.js ready on http://0.0.0.0:3210
# ✓ Database connected: redis://kv:6379/2  
# ✓ Ollama proxy configured: http://rag:9621/v1

# Check for errors
docker compose logs lobechat | grep -E "(ERROR|Error|error)"
# Should show minimal/no errors
```

### 7. Access URLs & Testing

| Service        | URL                            | Purpose            | Test Command                             |
| -------------- | ------------------------------ | ------------------ | ---------------------------------------- |
| **LobeChat**   | https://lobechat.dev.localhost | New TypeScript UI  | `curl -I https://lobechat.dev.localhost` |
| **Open WebUI** | https://webui.dev.localhost    | Existing Python UI | `curl -I https://webui.dev.localhost`    |
| **LightRAG**   | https://rag.dev.localhost      | Shared RAG Backend | `curl -I https://rag.dev.localhost`      |
| **Monitor**    | https://monitor.dev.localhost  | Docker Management  | `curl -I https://monitor.dev.localhost`  |

### 8. Functional Testing

#### A. LightRAG Query Modes in LobeChat
1. Access https://lobechat.dev.localhost
2. Test these queries:
```
What is this about?           # /hybrid (default)
/global Key insights?         # Global search
/local Specific details?      # Local search  
/mix Comprehensive analysis?  # Mixed approach
```

#### B. Model Selection
- Go to Settings → Model Provider
- Verify "LightRAG" appears as available model
- Test switching between models if multiple configured

### 9. Troubleshooting

#### Common Issues & Solutions

**Issue**: `lobechat` service won't start
```bash
# Check logs
docker compose logs lobechat
# Look for port conflicts, missing environment variables
```

**Issue**: Can't access https://lobechat.dev.localhost
```bash
# Check Caddy proxy
docker compose logs proxy | grep lobechat
# Verify SSL certificates exist
ls -la ./docker/ssl/dev.localhost*
```

**Issue**: LightRAG connection fails
```bash
# Test internal connectivity
docker compose exec lobechat ping rag
# Check LightRAG service status
docker compose ps rag
```

**Issue**: Redis connection errors
```bash
# Check Redis databases
docker compose exec kv redis-cli info keyspace
# Should show db2 and db3 with keys
```

### 10. Performance Monitoring

Monitor resource usage:
```bash
# Check memory/CPU usage
docker stats lobechat

# Expected usage:
# CONTAINER   CPU %    MEM USAGE/LIMIT    MEM %
# lobechat    1-5%     200-800MB/1GB      20-80%
```

### 11. Success Criteria Checklist

- [ ] `.env.lobechat` created with correct Redis URLs
- [ ] `./docker/data/lobechat` directory exists with correct permissions
- [ ] `docker compose ps lobechat` shows "Up (healthy)"
- [ ] https://lobechat.dev.localhost loads successfully
- [ ] LightRAG queries work with `/global`, `/local`, `/hybrid` prefixes
- [ ] Both Open WebUI and LobeChat can access same LightRAG backend
- [ ] Resource usage within expected limits (< 1GB RAM, < 0.5 CPU)
- [ ] No error messages in `docker compose logs lobechat`
- [ ] Health check endpoint returns HTTP 200

**Total Implementation Time**: 15-30 minutes

## Documentation Links
- **LobeChat Setup**: https://lobehub.com/docs/self-hosting/server-database
- **Environment Variables**: https://lobehub.com/docs/self-hosting/environment-variables
- **LightRAG API**: https://github.com/HKUDS/LightRAG/blob/main/lightrag/api/README.md
- **Docker Compose Health Checks**: https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck
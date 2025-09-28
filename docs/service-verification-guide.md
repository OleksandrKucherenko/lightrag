# Service Verification Guide

This guide provides comprehensive verification procedures for all LightRAG services to ensure proper functionality, security, and performance.

## Verification Overview

### Service Categories
- **Core Services**: LightRAG, LobeChat
- **Storage Services**: Redis, Memgraph, Qdrant
- **Infrastructure**: Caddy Proxy, Monitoring
- **UI Components**: Memgraph Lab, LobeChat Frontend

### Verification Types
- **Connectivity**: Network and service availability
- **Security**: SSL certificates, authentication, authorization
- **Functionality**: API endpoints, data operations
- **Performance**: Response times, resource usage
- **Integration**: Cross-service communication

## 1. Infrastructure Verification

### Caddy Reverse Proxy

```bash
# Test basic connectivity
curl -k https://dev.localhost/health
curl -k https://dev.localhost/debug

# Verify SSL certificate
curl -k -v https://dev.localhost/health 2>&1 | grep -E "(SSL|certificate)"

# Test subdomain routing
curl -k https://rag.dev.localhost/health
curl -k https://chat.dev.localhost/api/health
```

**Expected Results:**
- HTTP 200 responses from all endpoints
- Valid SSL certificate chain
- Proper subdomain resolution

### SSL Certificate Validation

```bash
# Check certificate validity
openssl x509 -in docker/ssl/dev.localhost.pem -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"

# Verify certificate chain
openssl verify -CAfile docker/ssl/rootCA.pem docker/ssl/dev.localhost.pem

# Test Windows certificate store (PowerShell)
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -Like "*LightRAG*"
```

## 2. Storage Services Verification

### Redis (Key-Value Store)

```bash
# Basic connectivity test
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" ping

# Authentication test
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" AUTH "$REDIS_PASSWORD"

# Storage test
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" SET test_key "test_value"
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" GET test_key
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" DEL test_key

# Performance test
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" --latency-history
```

**Expected Results:**
- PONG response to ping
- OK response to authentication
- Successful set/get/delete operations
- Latency < 1ms for local operations

### Memgraph (Graph Database)

```bash
# Connectivity test
timeout 10s bash -c ':> /dev/tcp/127.0.0.1/7687' && echo "Port open"

# Bolt protocol test
docker compose exec graph mgconsole --host 127.0.0.1 --port 7687 --username admin --password "$MEMGRAPH_PASSWORD" -q "RETURN 1;"

# Data insertion test
docker compose exec graph mgconsole --host 127.0.0.1 --port 7687 --username admin --password "$MEMGRAPH_PASSWORD" -q "CREATE (n:Test {name: 'test'}) RETURN n;"

# Query test
docker compose exec graph mgconsole --host 127.0.0.1 --port 7687 --username admin --password "$MEMGRAPH_PASSWORD" -q "MATCH (n:Test) RETURN count(n);"
```

**Expected Results:**
- Port 7687 accessible
- Successful authentication
- Successful node creation and querying

### Qdrant (Vector Database)

```bash
# Health check
curl -s http://localhost:6333/health

# Collection operations
curl -X PUT http://localhost:6333/collections/test \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 384, "distance": "Cosine"}}'

# Insert vectors
curl -X PUT http://localhost:6333/collections/test/points \
  -H "Content-Type: application/json" \
  -d '{"points": [{"id": 1, "vector": [0.1, 0.2, 0.3]}]}'

# Search test
curl -X POST http://localhost:6333/collections/test/points/search \
  -H "Content-Type: application/json" \
  -d '{"vector": [0.1, 0.2, 0.3], "limit": 1}'

# Cleanup
curl -X DELETE http://localhost:6333/collections/test
```

**Expected Results:**
- HTTP 200 responses from all endpoints
- Successful collection creation
- Successful vector operations

## 3. Core Application Verification

### LightRAG API

```bash
# Health endpoint
curl -k https://rag.dev.localhost/health

# OpenAI-compatible API test
curl -k -X POST https://rag.dev.localhost/v1/chat/completions \
  -H "Authorization: Bearer $LLM_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": "What is RAG?"}],
    "max_tokens": 100
  }'

# Document processing test (if documents exist)
curl -k -X POST https://rag.dev.localhost/process \
  -H "Content-Type: application/json" \
  -d '{"documents": ["test document content"]}'

# Storage connectivity
curl -k https://rag.dev.localhost/api/storage/health
```

**Expected Results:**
- Valid JSON responses from all endpoints
- Successful LLM API integration
- Proper error handling for invalid requests

### LobeChat Integration

```bash
# Web interface accessibility
curl -k -I https://chat.dev.localhost

# API connectivity to LightRAG
docker compose exec lobechat wget -qO- http://rag:9621/health

# Redis connectivity
docker compose exec lobechat redis-cli -a "$REDIS_PASSWORD" ping

# Session storage test
curl -k -X POST https://chat.dev.localhost/api/session \
  -H "Content-Type: application/json" \
  -d '{"message": "test"}'
```

**Expected Results:**
- HTTP 200 responses from web interface
- Successful backend connectivity
- Proper session management

## 4. Security Verification

### SSL/TLS Security

```bash
# Certificate chain validation
curl -k -v https://dev.localhost/health 2>&1 | grep -E "(SSL|TLS|certificate)"

# Test all service certificates
for service in rag chat graph kv vector monitor; do
  echo "Testing $service.dev.localhost..."
  curl -k -I "https://$service.dev.localhost" | head -1
done

# Check certificate expiry
openssl x509 -in docker/ssl/dev.localhost.pem -noout -dates
```

### Authentication & Authorization

```bash
# Redis password protection
docker compose exec kv redis-cli ping  # Should fail
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" ping  # Should succeed

# Memgraph authentication
docker compose exec graph mgconsole --host 127.0.0.1 --port 7687 -q "RETURN 1;"  # Should fail
docker compose exec graph mgconsole --host 127.0.0.1 --port 7687 --username admin --password "$MEMGRAPH_PASSWORD" -q "RETURN 1;"  # Should succeed

# Monitor basic auth
curl -k https://monitor.dev.localhost --user admin:wrong  # Should fail
curl -k https://monitor.dev.localhost --user admin:correct  # Should succeed
```

### CORS Configuration

```bash
# Test CORS headers
curl -k -H "Origin: https://chat.dev.localhost" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS https://rag.dev.localhost/v1/chat/completions \
  -v 2>&1 | grep -i "access-control"

# Test preflight requests
curl -k -H "Origin: https://chat.dev.localhost" \
  -X OPTIONS https://rag.dev.localhost/health \
  -v
```

## 5. Performance Verification

### Response Time Tests

```bash
# LightRAG API response time
time curl -k -s https://rag.dev.localhost/health > /dev/null

# Database query performance
time docker compose exec kv redis-cli -a "$REDIS_PASSWORD" SET perf_test "$(date)" > /dev/null
time docker compose exec kv redis-cli -a "$REDIS_PASSWORD" GET perf_test > /dev/null

# LLM API response time
time curl -k -s -X POST https://rag.dev.localhost/v1/chat/completions \
  -H "Authorization: Bearer $LLM_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 10}' > /dev/null
```

### Resource Usage Monitoring

```bash
# Container resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# Memory usage details
docker compose exec rag cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Disk usage for data volumes
docker system df -v
```

### Load Testing

```bash
# Concurrent API requests
for i in {1..10}; do
  curl -k -s -w "%{time_total}\n" -o /dev/null \
    https://rag.dev.localhost/health &
done | awk '{sum += $1} END {print "Average:", sum/NR}'

# Database load test
for i in {1..100}; do
  docker compose exec kv redis-cli -a "$REDIS_PASSWORD" SET "load_test_$i" "value_$i" &
done
```

## 6. Integration Verification

### End-to-End Workflows

```bash
# Document ingestion workflow
echo "Test document content for RAG processing" > /tmp/test_doc.txt

# Upload and process document
curl -k -X POST https://rag.dev.localhost/api/documents \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "content": "Test document content for RAG processing",
  "metadata": {"source": "verification_test"}
}
EOF

# Query the processed content
curl -k -X POST https://rag.dev.localhost/v1/chat/completions \
  -H "Authorization: Bearer $LLM_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": "What was the test document about?"}]
  }'
```

### Cross-Service Communication

```bash
# Test LobeChat -> LightRAG communication
docker compose exec lobechat curl -s http://rag:9621/health

# Test LightRAG -> Redis communication
docker compose exec rag redis-cli -h kv -a "$REDIS_PASSWORD" ping

# Test LightRAG -> Qdrant communication
docker compose exec rag curl -s http://vectors:6333/health

# Test LightRAG -> Memgraph communication
docker compose exec rag timeout 5s bash -c ':> /dev/tcp/graph/7687' && echo "Graph DB OK"
```

## 7. Automated Verification Scripts

### Using the Verification Framework

```bash
# Run all verification checks
./tests/verify.configuration.v3.sh

# Run specific categories
./tests/verify.configuration.v3.sh --category security
./tests/verify.configuration.v3.sh --category storage
./tests/verify.configuration.v3.sh --category communication

# List available checks
./tests/verify.configuration.v3.sh --list

# Run individual checks
./tests/checks/security-redis-auth.sh
./tests/checks/communication-connectivity-rag.sh
```

### Custom Verification Script

```bash
#!/bin/bash
# bin/verify-services.sh

set -e

echo "🔍 LightRAG Service Verification"
echo "================================"

# Infrastructure checks
echo "1. Testing Caddy proxy..."
curl -k -f https://dev.localhost/health || exit 1

# Storage checks
echo "2. Testing Redis..."
docker compose exec kv redis-cli -a "$REDIS_PASSWORD" ping | grep PONG || exit 1

echo "3. Testing Memgraph..."
timeout 10s bash -c ':> /dev/tcp/127.0.0.1/7687' || exit 1

echo "4. Testing Qdrant..."
curl -f http://localhost:6333/health || exit 1

# Application checks
echo "5. Testing LightRAG API..."
curl -k -f https://rag.dev.localhost/health || exit 1

echo "6. Testing LobeChat..."
curl -k -f https://chat.dev.localhost/api/health || exit 1

# Integration checks
echo "7. Testing LLM integration..."
curl -k -f -X POST https://rag.dev.localhost/v1/chat/completions \
  -H "Authorization: Bearer $LLM_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hi"}]}' || exit 1

echo "✅ All services verified successfully!"
```

## 8. Troubleshooting Failed Verifications

### Common Issues and Solutions

#### SSL Certificate Problems
```bash
# Regenerate certificates
cd docker/ssl
CAROOT=$(pwd) mkcert -install

# Restart services
docker compose restart proxy
```

#### DNS Resolution Issues
```bash
# Update hosts file
mise run hosts-update-windows

# Test DNS resolution
nslookup rag.dev.localhost
```

#### Service Connection Issues
```bash
# Check service status
docker compose ps

# View service logs
docker compose logs rag

# Restart services
docker compose restart
```

#### Authentication Failures
```bash
# Verify environment variables
docker compose exec rag env | grep -E "(PASSWORD|KEY)"

# Check secrets file
sops decrypt .env.secrets.json
```

### Getting Detailed Logs

```bash
# All service logs
docker compose logs -f

# Specific service logs
docker compose logs -f rag
docker compose logs -f lobechat

# Previous logs (if services restarted)
docker compose logs --tail 100 rag
```

## 9. Verification Checklist

- [ ] SSL certificates valid and trusted
- [ ] All subdomains resolve correctly
- [ ] Redis authentication working
- [ ] Memgraph connectivity and authentication
- [ ] Qdrant API responding
- [ ] LightRAG API accessible and functional
- [ ] LobeChat web interface loading
- [ ] LLM integration working
- [ ] Cross-service communication functional
- [ ] Performance within acceptable limits
- [ ] Security measures in place

## 10. Next Steps

After successful verification:
1. **Load Test Data**: Add documents for RAG testing
2. **Performance Tuning**: Adjust resource limits if needed
3. **Security Hardening**: Configure production certificates
4. **Monitoring Setup**: Configure alerts and dashboards
5. **Documentation**: Update runbooks with verified procedures
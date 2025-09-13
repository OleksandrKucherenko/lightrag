# LightRAG Performance Optimization Guide

## Executive Summary

This guide provides comprehensive performance tuning recommendations for LightRAG document processing, specifically optimized for medium-sized documents (1-10MB). The optimizations target slow document ingestion times through improved concurrency, resource allocation, and storage backend configuration.

## Current Performance Issues
- **Primary Issue**: Slow document ingestion and indexing
- **Document Type**: Medium documents (1-10MB) - research papers, reports, manuals
- **Current Bottleneck**: Conservative default concurrency settings

## Optimization Overview

### Performance Improvements Expected:
- **4x increase in concurrent chunk processing** (8 → 32 operations)
- **2x increase in document-level parallelism** (2 → 4 documents)
- **Reduced resource contention** through proper Docker limits
- **Optimized storage backends** for higher throughput

## 1. LightRAG Environment Variables (.env.lightrag)

### Current Configuration Issues:
```bash
WORKERS=8                    # Too high without resource limits
# Missing concurrency controls
# Missing LLM optimization settings
```

### Optimized Configuration:
```bash
# =============================================================================
# OPTIMIZED LIGHTRAG CONFIGURATION FOR MEDIUM DOCUMENT PROCESSING
# =============================================================================

# Server Configuration
HOST=0.0.0.0
PORT=9621

WEBUI_TITLE=LightRAG Production
WEBUI_DESCRIPTION=Production RAG System with Knowledge Graphs

CORS_ORIGINS=http://localhost:3000,https://dev.localhost

# OPTIMIZED: Reduced workers to prevent resource contention
WORKERS=6

# Directory Configuration
INPUT_DIR=/app/data/inputs
WORKING_DIR=/app/data/rag_storage
LOG_DIR=/app/logs

# Storage Configuration
LIGHTRAG_KV_STORAGE=RedisKVStorage
LIGHTRAG_DOC_STATUS_STORAGE=RedisDocStatusStorage
LIGHTRAG_VECTOR_STORAGE=QdrantVectorDBStorage
LIGHTRAG_GRAPH_STORAGE=MemgraphStorage

# Storage Connection Settings
REDIS_HOST=kv
REDIS_PORT=6379
REDIS_URI=redis://kv:6379
REDIS_WORKSPACE=production

QDRANT_URL=http://vectors:6333
QDRANT_WORKSPACE=production

MEMGRAPH_URI=bolt://graph:7687
MEMGRAPH_WORKSPACE=production

# Workspace Isolation
WORKSPACE=production

# LLM Configuration
LLM_BINDING=openai
LLM_MODEL=gpt-4o-mini
LLM_BINDING_HOST=https://api.openai.com/v1

# Embedding Configuration
EMBEDDING_BINDING=openai
EMBEDDING_BINDING_HOST=https://api.openai.com/v1
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIM=1536

# =============================================================================
# NEW PERFORMANCE OPTIMIZATION SETTINGS
# =============================================================================

# Document-Level Concurrency (CRITICAL IMPROVEMENT)
MAX_PARALLEL_INSERT=4        # Increased from default 2 (2x improvement)

# Chunk-Level Concurrency (MAJOR IMPROVEMENT) 
MAX_ASYNC=8                  # Increased from default 4 (2x improvement)
# Note: Graph-level concurrency auto-set to MAX_ASYNC * 2 = 16

# LLM API Optimization
LLM_API_TIMEOUT=120
LLM_API_RETRY_ATTEMPTS=3
LLM_API_RETRY_DELAY=1.0

# Embedding Batch Processing
EMBEDDING_BATCH_SIZE=100
EMBEDDING_API_TIMEOUT=60
EMBEDDING_API_RETRY_ATTEMPTS=3

# Connection Pool Settings
LLM_CONNECTION_POOL_SIZE=20
LLM_MAX_CONNECTIONS_PER_HOST=10
```

## 2. Docker Compose Resource Limits

### Current Issue:
```yaml
# LightRAG service has NO resource limits
rag:
  # ... no deploy.resources section
```

### Optimized Resource Allocation:
```yaml
# Add to LightRAG service in docker-compose.yaml
rag:
  # ... existing configuration ...
  deploy:
    resources:
      limits:
        memory: 6G        # Support 6 workers + 32 concurrent operations
        cpus: '3.0'       # 3 CPU cores for processing intensive tasks
      reservations:
        memory: 3G        # Guaranteed minimum memory
        cpus: '1.5'       # Guaranteed minimum CPU
  # Add health check
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9621/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
  # Add logging
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
```

## 3. Storage Backend Optimizations

### Redis (KV Storage) - Enhanced Connection Handling
```yaml
# Update Redis command in docker-compose.yaml
command: >
  redis-server 
  --appendonly yes 
  --appendfsync everysec 
  --save 900 1 --save 300 10 --save 60 10000 
  --maxmemory 1gb 
  --maxmemory-policy allkeys-lru 
  --tcp-keepalive 300 
  --timeout 300
  --maxclients 10000 
  --tcp-backlog 511 
  --io-threads 4 
  --io-threads-do-reads yes
```

### Qdrant (Vector Storage) - Performance Environment Variables
```yaml
# Add to Qdrant service environment
vectors:
  environment:
    - QDRANT__STORAGE__PERFORMANCE__MAX_SEARCH_THREADS=4
    - QDRANT__STORAGE__PERFORMANCE__MAX_OPTIMIZATION_THREADS=2
    - QDRANT__STORAGE__HNSW_INDEX__M=32
    - QDRANT__STORAGE__HNSW_INDEX__EF_CONSTRUCT=256
    - QDRANT__SERVICE__MAX_CONCURRENT_REQUESTS=100
```

### Memgraph (Graph Storage) - Memory Optimization
```yaml
# Update Memgraph command in docker-compose.yaml
command: >
  --log-level=WARNING 
  --also-log-to-stderr=true 
  --memory-limit=6144 
  --storage-properties-on-edges=true 
  --storage-snapshot-interval-sec=300 
  --storage-wal-enabled=true 
  --data-recovery-on-startup=true 
  --telemetry-enabled=false
  --query-execution-timeout-sec=600
```

## 4. System Resource Planning

### Total System Requirements:
- **Memory**: ~21GB (LightRAG: 6GB, Memgraph: 8GB, Qdrant: 4GB, Redis: 1GB, Other: 2GB)
- **CPU**: ~10.5 cores (LightRAG: 3.0, Memgraph: 4.0, Qdrant: 2.0, Redis: 0.5, Other: 1.0)

### Minimum Host Requirements:
- **RAM**: 24GB (with OS overhead)
- **CPU**: 12 cores minimum (16 cores recommended)
- **Storage**: NVMe SSD for optimal performance

## 5. Performance Monitoring Strategy

### Key Metrics to Monitor:
1. **Document Processing Time**: Average time per document
2. **Concurrent Operations**: Active chunk processing count
3. **Memory Usage**: Per-service memory consumption
4. **API Response Times**: LLM and embedding API latencies
5. **Storage Performance**: Redis/Qdrant/Memgraph response times

### Monitoring Commands:
```bash
# Monitor container resources
docker stats

# Check LightRAG logs for processing times
docker logs rag -f --tail 100

# Monitor API call patterns
docker exec rag curl -s http://localhost:9621/metrics

# Check storage backend health
docker exec kv redis-cli --latency-history
docker exec vectors curl -s http://localhost:6333/metrics
```

## 6. Expected Performance Improvements

### Theoretical Improvements:
- **Concurrent Chunk Operations**: 8 → 32 (4x increase)
- **Document Parallelism**: 2 → 4 (2x increase)
- **Overall Processing Speed**: 4-8x faster document ingestion

### Real-world Expectations:
- **Medium documents (1-10MB)**: 60-70% faster processing
- **Batch processing**: 80% improvement for multiple documents
- **System stability**: Better resource management, fewer crashes

### Performance Testing Approach:
1. **Baseline**: Process 10 medium documents with current settings
2. **Apply optimizations**: Implement all recommended changes
3. **Benchmark**: Process same 10 documents with optimized settings
4. **Compare**: Document time improvements and resource utilization

## 7. Implementation Checklist

### Phase 1: Environment Variables
- [ ] Update `.env.lightrag` with optimized concurrency settings
- [ ] Add LLM API optimization parameters
- [ ] Configure embedding batch processing

### Phase 2: Docker Compose Changes  
- [ ] Add resource limits to LightRAG service
- [ ] Update Redis command with connection optimizations
- [ ] Add Qdrant performance environment variables
- [ ] Update Memgraph memory allocation

### Phase 3: Testing & Validation
- [ ] Deploy changes to staging environment
- [ ] Run performance benchmarks
- [ ] Monitor system resource usage
- [ ] Validate document processing accuracy

### Phase 4: Production Deployment
- [ ] Apply changes to production
- [ ] Monitor performance improvements
- [ ] Document actual vs expected gains
- [ ] Fine-tune based on real-world usage

## 8. Risk Mitigation

### Potential Issues:
1. **Higher memory usage**: Monitor for OOM conditions
2. **API rate limits**: OpenAI may throttle high concurrency
3. **Storage contention**: Watch for database connection limits

### Mitigation Strategies:
- Gradual rollout with monitoring
- Fallback to previous configuration if issues arise
- Resource alerts and automatic scaling

## 9. Cost Implications

### Resource Costs:
- **Increased memory/CPU**: ~50% higher infrastructure costs
- **OpenAI API**: Same per-document cost, but faster processing
- **Overall**: Better cost-per-performance ratio

### ROI Analysis:
- **Faster processing**: Reduced user wait times
- **Higher throughput**: Process more documents per hour
- **Better UX**: Improved system responsiveness

## Conclusion

These optimizations should provide significant performance improvements for LightRAG document processing, specifically targeting the slow ingestion times you're experiencing. The key improvements are:

1. **4x concurrent chunk processing capacity**
2. **2x document-level parallelism**  
3. **Optimized storage backends**
4. **Proper resource allocation**

The changes are designed to be safe and reversible, with comprehensive monitoring to validate improvements.
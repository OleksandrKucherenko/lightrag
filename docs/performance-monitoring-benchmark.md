# LightRAG Performance Monitoring & Benchmarking Guide

## Overview

This guide provides comprehensive monitoring and benchmarking strategies to measure the performance improvements from the LightRAG optimizations. It includes baseline measurement, monitoring setup, and validation methodologies.

## 1. Baseline Performance Measurement

### Pre-Optimization Benchmark Setup

Before applying any optimizations, establish baseline metrics:

```bash
# 1. Create benchmark document set
mkdir -p ./benchmark-docs
# Place 10 representative medium documents (1-10MB each) in this folder

# 2. Clear existing data for clean benchmark
docker-compose down
docker volume prune -f
docker-compose up -d

# 3. Wait for services to be ready
sleep 120

# 4. Record baseline timestamp
echo "Baseline benchmark started: $(date)" > baseline-results.txt
```

### Baseline Metrics Collection

```bash
#!/bin/bash
# baseline-benchmark.sh

echo "=== LightRAG Baseline Performance Test ==="
echo "Start time: $(date)"

# System resource monitoring in background
docker stats --no-stream > baseline-docker-stats.txt &
STATS_PID=$!

# Monitor individual services
echo "=== Initial Resource State ===" 
docker exec rag cat /proc/meminfo | grep -E "(MemTotal|MemAvailable)" 
docker exec kv redis-cli info memory | grep used_memory_human
docker exec vectors curl -s http://localhost:6333/metrics | grep memory

# Process benchmark documents
DOCS_DIR="./benchmark-docs"
PROCESSED_COUNT=0
START_TIME=$(date +%s)

for doc in "$DOCS_DIR"/*.{pdf,txt,docx}; do
    if [ -f "$doc" ]; then
        echo "Processing: $(basename "$doc")"
        DOC_START=$(date +%s)
        
        # Upload document via API
        curl -X POST "http://localhost:9080/documents" \
             -F "file=@$doc" \
             -H "Authorization: Bearer ${LIGHTRAG_API_KEY}"
        
        DOC_END=$(date +%s)
        DOC_TIME=$((DOC_END - DOC_START))
        echo "Document processed in: ${DOC_TIME}s"
        
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
        
        # Wait between documents to avoid overwhelming
        sleep 5
    fi
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

# Stop background monitoring
kill $STATS_PID 2>/dev/null

echo "=== Baseline Results ==="
echo "Total documents: $PROCESSED_COUNT"
echo "Total time: ${TOTAL_TIME}s"
echo "Average time per document: $((TOTAL_TIME / PROCESSED_COUNT))s"
echo "End time: $(date)"

# Final resource state
echo "=== Final Resource State ==="
docker exec rag cat /proc/meminfo | grep -E "(MemTotal|MemAvailable)"
docker exec kv redis-cli info memory | grep used_memory_human
docker exec vectors curl -s http://localhost:6333/metrics | grep memory
```

## 2. Performance Monitoring Dashboard

### Real-time Monitoring Setup

```bash
#!/bin/bash
# monitor-performance.sh - Run during optimization testing

# Create monitoring log directory
mkdir -p ./monitoring-logs
cd monitoring-logs

# Start comprehensive monitoring
echo "Starting performance monitoring at $(date)"

# 1. System-wide resource monitoring
while true; do
    echo "$(date)," >> system-metrics.csv
    docker stats --no-stream --format "table {{.Container}},{{.CPUPerc}},{{.MemUsage}}" >> system-metrics.csv
    sleep 30
done &
SYSTEM_PID=$!

# 2. LightRAG specific metrics
while true; do
    echo "=== $(date) ===" >> lightrag-metrics.log
    docker exec rag curl -s http://localhost:9621/metrics >> lightrag-metrics.log 2>/dev/null || echo "API not responding" >> lightrag-metrics.log
    docker logs rag --tail 10 >> lightrag-processing.log 2>/dev/null
    sleep 60
done &
LIGHTRAG_PID=$!

# 3. Storage backend monitoring
while true; do
    echo "$(date)" >> storage-metrics.log
    echo "=== Redis ===" >> storage-metrics.log
    docker exec kv redis-cli --latency-history -i 10 -c 3 >> storage-metrics.log 2>/dev/null &
    
    echo "=== Qdrant ===" >> storage-metrics.log
    docker exec vectors curl -s http://localhost:6333/metrics | grep -E "(index|search|memory)" >> storage-metrics.log
    
    echo "=== Memgraph ===" >> storage-metrics.log
    docker exec graph echo "SHOW STATS;" | mgconsole --host graph --port 7687 --use-ssl false >> storage-metrics.log 2>/dev/null
    
    sleep 120
done &
STORAGE_PID=$!

# 4. API response time monitoring
while true; do
    TIMESTAMP=$(date +%s)
    RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:9080/health)
    echo "$TIMESTAMP,$RESPONSE_TIME" >> api-response-times.csv
    sleep 30
done &
API_PID=$!

echo "Monitoring started. PIDs: System=$SYSTEM_PID, LightRAG=$LIGHTRAG_PID, Storage=$STORAGE_PID, API=$API_PID"
echo "To stop monitoring, run: kill $SYSTEM_PID $LIGHTRAG_PID $STORAGE_PID $API_PID"

# Save PIDs for easy cleanup
echo "$SYSTEM_PID $LIGHTRAG_PID $STORAGE_PID $API_PID" > monitoring-pids.txt
```

## 3. Optimization Validation Benchmark

### Post-Optimization Testing

```bash
#!/bin/bash
# optimized-benchmark.sh

echo "=== LightRAG Optimized Performance Test ==="
echo "Start time: $(date)"

# Apply optimizations first
echo "Applying optimizations..."

# 1. Update environment variables
cp .env.lightrag .env.lightrag.backup
cat >> .env.lightrag << EOF

# Performance Optimizations
MAX_PARALLEL_INSERT=4
MAX_ASYNC=8
LLM_API_TIMEOUT=120
LLM_API_RETRY_ATTEMPTS=3
EMBEDDING_BATCH_SIZE=100
LLM_CONNECTION_POOL_SIZE=20
WORKERS=6
EOF

# 2. Update docker-compose with resource limits
# (Manual step - see optimization guide)

# 3. Restart services with optimizations
docker-compose down
sleep 30
docker-compose up -d

# Wait for services to be ready with optimizations
echo "Waiting for optimized services to initialize..."
sleep 180

# System resource monitoring
docker stats --no-stream > optimized-docker-stats.txt &
STATS_PID=$!

# Process same benchmark documents
DOCS_DIR="./benchmark-docs"
PROCESSED_COUNT=0
START_TIME=$(date +%s)

echo "=== Starting optimized document processing ==="

for doc in "$DOCS_DIR"/*.{pdf,txt,docx}; do
    if [ -f "$doc" ]; then
        echo "Processing: $(basename "$doc")"
        DOC_START=$(date +%s)
        
        curl -X POST "http://localhost:9080/documents" \
             -F "file=@$doc" \
             -H "Authorization: Bearer ${LIGHTRAG_API_KEY}"
        
        DOC_END=$(date +%s)
        DOC_TIME=$((DOC_END - DOC_START))
        echo "Document processed in: ${DOC_TIME}s"
        
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
        
        # Reduced wait time due to better concurrency
        sleep 2
    fi
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

kill $STATS_PID 2>/dev/null

echo "=== Optimized Results ==="
echo "Total documents: $PROCESSED_COUNT"
echo "Total time: ${TOTAL_TIME}s"
echo "Average time per document: $((TOTAL_TIME / PROCESSED_COUNT))s"
echo "End time: $(date)"
```

## 4. Performance Comparison Analysis

### Automated Comparison Script

```bash
#!/bin/bash
# compare-performance.sh

echo "=== LightRAG Performance Comparison ==="

# Read baseline results
if [ -f "baseline-results.txt" ] && [ -f "optimized-results.txt" ]; then
    BASELINE_TIME=$(grep "Total time:" baseline-results.txt | awk '{print $3}' | sed 's/s//')
    OPTIMIZED_TIME=$(grep "Total time:" optimized-results.txt | awk '{print $3}' | sed 's/s//')
    
    IMPROVEMENT=$(echo "scale=2; (($BASELINE_TIME - $OPTIMIZED_TIME) / $BASELINE_TIME) * 100" | bc)
    SPEEDUP=$(echo "scale=2; $BASELINE_TIME / $OPTIMIZED_TIME" | bc)
    
    echo "Baseline total time: ${BASELINE_TIME}s"
    echo "Optimized total time: ${OPTIMIZED_TIME}s"
    echo "Performance improvement: ${IMPROVEMENT}%"
    echo "Speed increase: ${SPEEDUP}x"
else
    echo "Error: Baseline or optimized results not found"
fi

# Resource usage comparison
echo "=== Resource Usage Comparison ==="
echo "Baseline Docker Stats:"
cat baseline-docker-stats.txt | grep -E "(rag|kv|vectors|graph)"

echo "Optimized Docker Stats:"
cat optimized-docker-stats.txt | grep -E "(rag|kv|vectors|graph)"
```

## 5. Continuous Monitoring Setup

### Production Monitoring Configuration

```yaml
# prometheus-config.yml for production monitoring
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'lightrag'
    static_configs:
      - targets: ['localhost:9080']
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: 'qdrant'
    static_configs:
      - targets: ['localhost:6333']
    metrics_path: /metrics
    scrape_interval: 60s

  - job_name: 'redis'
    static_configs:
      - targets: ['localhost:6379']
    scrape_interval: 60s
```

### Key Performance Indicators (KPIs)

```bash
#!/bin/bash
# kpi-dashboard.sh - Generate performance report

echo "=== LightRAG Performance KPIs ==="
echo "Generated: $(date)"

# 1. Document processing throughput
DOCS_PROCESSED=$(docker exec rag curl -s http://localhost:9621/metrics | grep "documents_processed_total" | awk '{print $2}')
echo "Total documents processed: $DOCS_PROCESSED"

# 2. Average processing time
AVG_TIME=$(docker logs rag | grep "Processing time:" | tail -10 | awk '{print $3}' | awk '{sum+=$1} END {print sum/NR}')
echo "Average processing time (last 10): ${AVG_TIME}s"

# 3. Current concurrency utilization
ACTIVE_WORKERS=$(docker exec rag ps aux | grep python | wc -l)
echo "Active workers: $ACTIVE_WORKERS"

# 4. Memory utilization
RAG_MEM=$(docker stats rag --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1)
echo "LightRAG memory usage: $RAG_MEM"

# 5. API response times
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:9080/health)
echo "API response time: ${RESPONSE_TIME}s"

# 6. Error rates
ERROR_COUNT=$(docker logs rag | grep -i error | tail -100 | wc -l)
echo "Recent errors (last 100 logs): $ERROR_COUNT"
```

## 6. Alert Thresholds

### Performance Degradation Alerts

```bash
#!/bin/bash
# performance-alerts.sh

# Define thresholds
MAX_RESPONSE_TIME=5.0
MAX_MEMORY_PERCENT=80
MIN_SUCCESS_RATE=95

# Check API response time
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:9080/health)
if (( $(echo "$RESPONSE_TIME > $MAX_RESPONSE_TIME" | bc -l) )); then
    echo "ALERT: API response time too high: ${RESPONSE_TIME}s (threshold: ${MAX_RESPONSE_TIME}s)"
fi

# Check memory usage
MEM_USAGE=$(docker stats rag --no-stream --format "{{.MemPerc}}" | sed 's/%//')
if (( $(echo "$MEM_USAGE > $MAX_MEMORY_PERCENT" | bc -l) )); then
    echo "ALERT: Memory usage too high: ${MEM_USAGE}% (threshold: ${MAX_MEMORY_PERCENT}%)"
fi

# Check error rate
TOTAL_LOGS=$(docker logs rag | wc -l)
ERROR_LOGS=$(docker logs rag | grep -i error | wc -l)
if [ $TOTAL_LOGS -gt 0 ]; then
    ERROR_RATE=$(echo "scale=2; (100 - ($ERROR_LOGS * 100 / $TOTAL_LOGS))" | bc)
    if (( $(echo "$ERROR_RATE < $MIN_SUCCESS_RATE" | bc -l) )); then
        echo "ALERT: Success rate too low: ${ERROR_RATE}% (threshold: ${MIN_SUCCESS_RATE}%)"
    fi
fi
```

## 7. Performance Testing Checklist

### Pre-Deployment Testing

- [ ] **Baseline Measurement**
  - [ ] Run baseline benchmark with current configuration
  - [ ] Record processing times for 10 representative documents
  - [ ] Document resource utilization levels
  - [ ] Capture API response times

- [ ] **Optimization Implementation**
  - [ ] Apply environment variable changes
  - [ ] Update Docker resource limits
  - [ ] Configure storage backend optimizations
  - [ ] Restart services with new configuration

- [ ] **Validation Testing**
  - [ ] Run identical benchmark with optimized configuration
  - [ ] Compare processing times and resource usage
  - [ ] Validate improvement expectations (4-8x faster)
  - [ ] Test system stability under load

- [ ] **Production Readiness**
  - [ ] Set up continuous monitoring
  - [ ] Configure performance alerts
  - [ ] Document rollback procedures
  - [ ] Train team on new metrics

### Success Criteria

- **Primary Goal**: 60-70% reduction in document processing time
- **Secondary Goals**:
  - No increase in error rates
  - Stable memory usage within allocated limits
  - API response times remain under 2 seconds
  - System can handle 4x concurrent document processing

## 8. Troubleshooting Performance Issues

### Common Issues and Solutions

1. **High Memory Usage**
   ```bash
   # Check memory breakdown
   docker exec rag cat /proc/meminfo
   # Reduce concurrency if needed
   # Update MAX_PARALLEL_INSERT to 2
   ```

2. **API Rate Limiting**
   ```bash
   # Check OpenAI API errors
   docker logs rag | grep "rate limit"
   # Increase retry delays
   # Reduce MAX_ASYNC if needed
   ```

3. **Storage Backend Bottlenecks**
   ```bash
   # Check Redis performance
   docker exec kv redis-cli --latency
   # Check Qdrant response times
   docker exec vectors curl -s http://localhost:6333/metrics
   ```

This comprehensive monitoring and benchmarking approach will provide clear validation of the performance improvements and ongoing insight into system health.
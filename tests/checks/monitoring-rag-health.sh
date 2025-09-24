#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG Health Monitoring Check
# =============================================================================
# 
# GIVEN: A LightRAG service that should be healthy and responsive
# WHEN: We test the health endpoint and service status
# THEN: We report on LightRAG service health and availability
# =============================================================================

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check if LightRAG container is running
if ! docker compose ps -q rag >/dev/null 2>&1; then
    echo "BROKEN|rag_health|LightRAG container not found|docker compose ps rag"
    exit 0
fi

# WHEN: We check container health status
if container_status=$(docker compose ps rag --format "table {{.Status}}" | tail -n +2 2>&1); then
    if echo "$container_status" | grep -q "Up"; then
        echo "PASS|rag_health|LightRAG container running|docker compose ps rag"
    else
        echo "FAIL|rag_health|LightRAG container not healthy: $container_status|docker compose ps rag"
    fi
else
    echo "BROKEN|rag_health|Cannot check container status: ${container_status:0:50}|docker compose ps rag"
fi

# WHEN: We test internal health endpoint
if health_result=$(docker compose exec -T rag curl -s --connect-timeout 5 http://localhost:9621/health 2>&1); then
    if echo "$health_result" | grep -q "ok\|healthy\|success" || [[ "$health_result" == *"200"* ]]; then
        echo "PASS|rag_health|Internal health endpoint responding|curl http://localhost:9621/health"
    else
        echo "FAIL|rag_health|Internal health endpoint unhealthy: ${health_result:0:50}|curl http://localhost:9621/health"
    fi
else
    echo "BROKEN|rag_health|Cannot reach internal health endpoint|curl http://localhost:9621/health"
fi

# WHEN: We test external health endpoint
if external_health=$(curl -s --connect-timeout 5 "https://rag.$PUBLISH_DOMAIN/health" 2>&1); then
    if echo "$external_health" | grep -q "ok\|healthy\|success" || [[ "$external_health" == *"200"* ]]; then
        echo "PASS|rag_health|External health endpoint accessible|curl https://rag.$PUBLISH_DOMAIN/health"
    else
        echo "FAIL|rag_health|External health endpoint issues: ${external_health:0:50}|curl https://rag.$PUBLISH_DOMAIN/health"
    fi
else
    echo "FAIL|rag_health|External health endpoint not accessible|curl https://rag.$PUBLISH_DOMAIN/health"
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Service Connectivity Check
# =============================================================================
# 
# GIVEN: Services that should communicate with each other
# WHEN: We test inter-service network connectivity
# THEN: We report on communication status between services
# =============================================================================

# Define service connections to test
declare -a CONNECTIONS=(
    "rag:kv:6379:LightRAG→Redis"
    "rag:vectors:6333:LightRAG→Qdrant"
    "rag:graph:7687:LightRAG→Memgraph"
    "lobechat:rag:9621:LobeChat→LightRAG"
    "lobechat:kv:6379:LobeChat→Redis"
)

# Test each connection
for connection in "${CONNECTIONS[@]}"; do
    IFS=':' read -r from_container to_container port description <<< "$connection"
    
    # Check if source container exists
    if ! docker compose ps -q "$from_container" >/dev/null 2>&1; then
        echo "BROKEN|service_connectivity|$description - source container '$from_container' not found|docker compose ps $from_container"
        continue
    fi
    
    # Check if target container exists
    if ! docker compose ps -q "$to_container" >/dev/null 2>&1; then
        echo "BROKEN|service_connectivity|$description - target container '$to_container' not found|docker compose ps $to_container"
        continue
    fi
    
    # WHEN: We test network connectivity
    if result=$(docker compose exec -T "$from_container" sh -c "nc -z $to_container $port && echo 'Connected' || echo 'Failed'" 2>&1); then
        if [[ "$result" == "Connected" ]]; then
            echo "PASS|service_connectivity|$description - network connectivity established|docker exec $from_container nc -z $to_container $port"
        else
            echo "FAIL|service_connectivity|$description - network connectivity failed|docker exec $from_container nc -z $to_container $port"
        fi
    else
        echo "BROKEN|service_connectivity|$description - cannot test connectivity: ${result:0:50}|docker exec $from_container nc -z $to_container $port"
    fi
done

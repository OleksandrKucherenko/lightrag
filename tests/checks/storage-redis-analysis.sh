#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Redis Storage Analysis Check
# =============================================================================
# 
# GIVEN: Redis used for LightRAG KV storage and document status
# WHEN: We analyze the stored data structures
# THEN: We report on storage state and data patterns
# =============================================================================

# Load environment
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Check if Redis container is running
if ! docker compose ps -q kv >/dev/null 2>&1; then
    echo "BROKEN|redis_storage|Redis container not found|docker compose ps kv"
    exit 0
fi

# Prepare auth flag
auth_flag=""
[[ -n "$REDIS_PASSWORD" ]] && auth_flag="-a \"$REDIS_PASSWORD\""

# WHEN: We analyze Redis data structures
if keys_result=$(docker compose exec -T kv sh -c "redis-cli $auth_flag keys '*'" 2>&1); then
    # Count total keys and clean newlines
    key_count=$(echo "$keys_result" | grep -v "^$" | wc -l | tr -d '\n\r')
    
    # Count document-related keys and clean newlines
    doc_keys=$(echo "$keys_result" | grep -c "doc" 2>/dev/null || echo "0")
    doc_keys=$(echo "$doc_keys" | tr -d '\n\r')
    
    # Count LightRAG-specific keys and clean newlines
    lightrag_keys=$(echo "$keys_result" | grep -c "lightrag" 2>/dev/null || echo "0")
    lightrag_keys=$(echo "$lightrag_keys" | tr -d '\n\r')
    
    # Get keyspace info
    if info_result=$(docker compose exec -T kv sh -c "redis-cli $auth_flag info keyspace" 2>&1); then
        # Extract database info and clean newlines
        db_info=$(echo "$info_result" | grep "db" | head -1 | tr -d '\n\r' || echo "no databases")
        
        # THEN: Report storage analysis
        if [[ "$key_count" -gt 0 ]]; then
            echo "INFO|redis_storage|Keys: $key_count, Documents: $doc_keys, LightRAG: $lightrag_keys, DB: ${db_info}|docker exec kv redis-cli $auth_flag keys '*'"
        else
            echo "INFO|redis_storage|Empty storage - no keys found|docker exec kv redis-cli $auth_flag keys '*'"
        fi
    else
        # Clean error message of newlines
        clean_error=$(echo "${info_result:0:50}" | tr -d '\n\r')
        echo "BROKEN|redis_storage|Cannot get keyspace info: ${clean_error}|docker exec kv redis-cli $auth_flag info keyspace"
    fi
else
    # Clean error message of newlines
    clean_error=$(echo "${keys_result:0:50}" | tr -d '\n\r')
    echo "BROKEN|redis_storage|Cannot list keys: ${clean_error}|docker exec kv redis-cli $auth_flag keys '*'"
fi

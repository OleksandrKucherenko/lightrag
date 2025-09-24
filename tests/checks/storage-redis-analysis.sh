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

redis_exec_base=(docker compose exec -T)
redis_command_display="docker compose exec -T"

if [[ -n "$REDIS_PASSWORD" ]]; then
    redis_exec_base+=(-e "REDISCLI_AUTH=$REDIS_PASSWORD")
    redis_command_display+=" -e REDISCLI_AUTH='\$REDIS_PASSWORD'"
fi

redis_exec_base+=(kv)
redis_command_display+=" kv redis-cli --no-auth-warning"

run_redis_cli() {
    "${redis_exec_base[@]}" redis-cli --no-auth-warning "$@"
}

sanitize_output() {
    local value="$1"
    value="${value//$'\r'/}"
    printf '%s' "$value"
}

# Check if Redis container is running
if ! docker compose ps -q kv >/dev/null 2>&1; then
    echo "BROKEN|redis_storage|Redis container not found|docker compose ps kv"
    exit 0
fi

# WHEN: We analyze Redis data structures
keys_status=0
keys_output=$(run_redis_cli --raw keys '*' 2>&1) || keys_status=$?

if (( keys_status == 0 )); then
    keys_result=$(sanitize_output "$keys_output")
    keys_lines=$(printf '%s\n' "$keys_result" | sed '/^$/d')

    if [[ "$keys_lines" == "(empty list or set)" ]]; then
        key_count=0
        doc_keys=0
        lightrag_keys=0
    else
        key_count=$(printf '%s\n' "$keys_lines" | awk 'NF{count++} END{print count+0}')
        if (( key_count == 0 )); then
            doc_keys=0
            lightrag_keys=0
        else
            doc_keys=$(printf '%s\n' "$keys_lines" | grep -c 'doc' || true)
            lightrag_keys=$(printf '%s\n' "$keys_lines" | grep -c 'lightrag' || true)
        fi
    fi

    info_status=0
    info_output=$(run_redis_cli info keyspace 2>&1) || info_status=$?

    if (( info_status == 0 )); then
        info_result=$(sanitize_output "$info_output")
        db_info=$(printf '%s\n' "$info_result" | awk -F: '/^db[0-9]+:/{print $0; exit}')
        [[ -z "$db_info" ]] && db_info="no databases"

        keys_command_display="$redis_command_display --raw keys '*'"

        if (( key_count > 0 )); then
            echo "INFO|redis_storage|Keys: $key_count, Documents: $doc_keys, LightRAG: $lightrag_keys, DB: ${db_info}|$keys_command_display"
        else
            echo "INFO|redis_storage|Empty storage - no keys found|$keys_command_display"
        fi
    else
        info_trimmed=$(sanitize_output "$info_output")
        echo "BROKEN|redis_storage|Cannot get keyspace info: ${info_trimmed:0:80}|$redis_command_display info keyspace"
    fi
else
    keys_trimmed=$(sanitize_output "${keys_output:-}")
    echo "BROKEN|redis_storage|Cannot list keys: ${keys_trimmed:0:80}|$redis_command_display --raw keys '*'"
fi

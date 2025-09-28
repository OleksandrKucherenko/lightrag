#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Redis Storage Analysis Check
# =============================================================================
# GIVEN: Redis used for LightRAG KV storage and document status
# WHEN: We analyze the stored data structures
# THEN: We report on storage state and data patterns
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="redis_storage"
readonly BROKEN_CONTAINER="BROKEN|${TEST_ID}|Redis container not found|docker compose ps kv"
readonly BROKEN_KEYS="BROKEN|${TEST_ID}|Cannot list keys|docker compose exec kv redis-cli keys '*'"
readonly BROKEN_INFO="BROKEN|${TEST_ID}|Cannot get keyspace info|docker compose exec kv redis-cli info keyspace"
readonly INFO_EMPTY="INFO|${TEST_ID}|Empty storage - no keys found|docker compose exec kv redis-cli keys '*'"

# GIVEN: Check if Redis container is running
CONTAINER_RUNNING=$(probe_docker_service_running "kv" && echo "true" || echo "false")

# THEN: Exit early if container not running
[[ "$CONTAINER_RUNNING" == "false" ]] && { echo "$BROKEN_CONTAINER"; exit 0; }

# WHEN: Get Redis keys
KEYS_RESULT=$(clean_output "$(probe_redis_keys)")
KEYS_SUCCESS=$([[ "$KEYS_RESULT" != "KEYS_FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if cannot get keys
[[ "$KEYS_SUCCESS" == "false" ]] && { echo "$BROKEN_KEYS"; exit 0; }

# WHEN: Count different types of keys
KEY_COUNT=$(echo "$KEYS_RESULT" | grep -v "^$" | wc -l | tr -d '\n\r')
DOC_KEYS=$(echo "$KEYS_RESULT" | grep -c "doc" 2>/dev/null || echo "0")
DOC_KEYS=$(clean_output "$DOC_KEYS")
LIGHTRAG_KEYS=$(echo "$KEYS_RESULT" | grep -c "lightrag" 2>/dev/null || echo "0")
LIGHTRAG_KEYS=$(clean_output "$LIGHTRAG_KEYS")

# WHEN: Get keyspace info
INFO_RESULT=$(clean_output "$(probe_docker_exec kv sh -c "redis-cli info keyspace" 2>/dev/null || echo "INFO_FAILED")")
INFO_SUCCESS=$([[ "$INFO_RESULT" != "INFO_FAILED" ]] && echo "true" || echo "false")

# WHEN: Extract database info
if [[ "$INFO_SUCCESS" == "true" ]]; then
    DB_INFO=$(echo "$INFO_RESULT" | grep "db" | head -1 | tr -d '\n\r' || echo "no databases")
else
    DB_INFO="no databases"
fi

# THEN: Report storage analysis
if [[ "$KEY_COUNT" -gt 0 ]]; then
    echo "INFO|${TEST_ID}|Keys: $KEY_COUNT, Documents: $DOC_KEYS, LightRAG: $LIGHTRAG_KEYS, DB: ${DB_INFO}|docker compose exec kv redis-cli keys '*'"
else
    echo "$INFO_EMPTY"
fi
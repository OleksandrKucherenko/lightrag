#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Qdrant Vector Storage Analysis Check
# =============================================================================
# GIVEN: Qdrant used for vector storage in LightRAG
# WHEN: We analyze collections and vector data
# THEN: We report on vector storage state and configuration
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="qdrant_storage"
readonly BROKEN_CONTAINER="BROKEN|${TEST_ID}|Qdrant container not found|docker compose ps vectors"
readonly BROKEN_IMAGE="BROKEN|${TEST_ID}|Unable to pull helper image|docker pull alpine/curl:latest"
readonly BROKEN_QUERY="BROKEN|${TEST_ID}|Cannot query collections|docker run --rm --network container:vectors alpine/curl:latest curl -s http://localhost:6333/collections"
readonly BROKEN_JSON="BROKEN|${TEST_ID}|Invalid JSON response|docker run --rm --network container:vectors alpine/curl:latest curl -s http://localhost:6333/collections"
readonly INFO_EMPTY="INFO|${TEST_ID}|No collections found|docker run --rm --network container:vectors alpine/curl:latest curl -s http://localhost:6333/collections"
readonly INFO_BASIC="INFO|${TEST_ID}|Collections found|docker run --rm --network container:vectors alpine/curl:latest curl -s http://localhost:6333/collections"

# GIVEN: Load environment and check prerequisites
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
CURL_HELPER_IMAGE="${CURL_HELPER_IMAGE:-alpine/curl:latest}"

# WHEN: Check if Qdrant container is running
CONTAINER_RUNNING=$(probe_docker_service_running "vectors" && echo "true" || echo "false")

# THEN: Exit early if container not running
[[ "$CONTAINER_RUNNING" == "false" ]] && { echo "$BROKEN_CONTAINER"; exit 0; }

# WHEN: Check if helper image is available
IMAGE_AVAILABLE=$(docker image inspect "$CURL_HELPER_IMAGE" >/dev/null 2>&1 && echo "true" || echo "false")

# WHEN: Try to pull image if not available
if [[ "$IMAGE_AVAILABLE" == "false" ]]; then
    PULL_SUCCESS=$(docker pull --quiet "$CURL_HELPER_IMAGE" >/dev/null 2>&1 && echo "true" || echo "false")
    [[ "$PULL_SUCCESS" == "false" ]] && { echo "$BROKEN_IMAGE"; exit 0; }
fi

# WHEN: Query collections
COLLECTIONS_RESULT=$(clean_output "$(probe_qdrant_collections)")
COLLECTIONS_SUCCESS=$([[ "$COLLECTIONS_RESULT" != "COLLECTIONS_FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if cannot query collections
[[ "$COLLECTIONS_SUCCESS" == "false" ]] && { echo "$BROKEN_QUERY"; exit 0; }

# WHEN: Parse JSON response
JSON_VALID=$(echo "$COLLECTIONS_RESULT" | jq . >/dev/null 2>&1 && echo "true" || echo "false")

# THEN: Exit if invalid JSON
[[ "$JSON_VALID" == "false" ]] && { echo "$BROKEN_JSON"; exit 0; }

# WHEN: Extract collection count
COLLECTION_COUNT=$(echo "$COLLECTIONS_RESULT" | jq -r '.result.collections | length' 2>/dev/null || echo "0")

# THEN: Report based on collection count
if [[ "$COLLECTION_COUNT" -gt 0 ]]; then
    echo "$INFO_BASIC"
else
    echo "$INFO_EMPTY"
fi
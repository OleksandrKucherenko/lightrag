#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Qdrant Vector Storage Analysis Check
# =============================================================================
# 
# GIVEN: Qdrant used for vector storage in LightRAG
# WHEN: We analyze collections and vector data
# THEN: We report on vector storage state and configuration
# =============================================================================

# Load environment
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
CURL_HELPER_IMAGE="${CURL_HELPER_IMAGE:-alpine/curl:latest}"

# Check if Qdrant container is running
if ! docker compose ps -q vectors >/dev/null 2>&1; then
    echo "BROKEN|qdrant_storage|Qdrant container not found|docker compose ps vectors"
    exit 0
fi

# Ensure helper image for HTTP requests is available
if ! docker image inspect "$CURL_HELPER_IMAGE" >/dev/null 2>&1; then
    if ! docker pull --quiet "$CURL_HELPER_IMAGE" >/dev/null 2>&1; then
        echo "BROKEN|qdrant_storage|Unable to pull helper image $CURL_HELPER_IMAGE|docker pull $CURL_HELPER_IMAGE"
        exit 0
    fi
fi

headers=""
[[ -n "$QDRANT_API_KEY" ]] && headers="-H 'api-key: $QDRANT_API_KEY'"

trim_whitespace() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

# WHEN: We analyze Qdrant collections
if collections_result=$(docker run --rm --network container:vectors alpine/curl:latest sh -c "curl -s $headers http://localhost:6333/collections" 2>&1); then
    if echo "$collections_result" | jq . >/dev/null 2>&1; then
        collection_count=$(echo "$collections_result" | jq -r '.result.collections | length' 2>/dev/null || echo "0")

        if [[ "$collection_count" -gt 0 ]]; then
            first_collection=$(echo "$collections_result" | jq -r '.result.collections[0].name' 2>/dev/null || echo "")

            if [[ -n "$first_collection" && "$first_collection" != "null" ]]; then
                # Get collection details
                if collection_info=$(docker run --rm --network container:vectors alpine/curl:latest sh -c "curl -s $headers http://localhost:6333/collections/$first_collection" 2>&1); then
                    vector_count=$(echo "$collection_info" | jq -r '.result.vectors_count // 0' 2>/dev/null || echo "0")
                    dimension=$(echo "$collection_info" | jq -r '.result.config.params.vectors.size // "unknown"' 2>/dev/null || echo "unknown")
                    distance=$(echo "$collection_info" | jq -r '.result.config.params.vectors.distance // "unknown"' 2>/dev/null || echo "unknown")
                    
                    # THEN: Report detailed storage information
                    echo "INFO|qdrant_storage|Collections: $collection_count, Vectors: $vector_count, Dimension: $dimension, Distance: $distance|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
                else
                    echo "INFO|qdrant_storage|Collections: $collection_count (details unavailable)|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
                fi
            else
                echo "INFO|qdrant_storage|Collections: $collection_count (no valid collection names)|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
            fi
        else
            # THEN: Report empty storage (normal for new installations)
            echo "INFO|qdrant_storage|No collections found - new installation|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
        fi
    else
        error_message=$(trim_whitespace "$collections_result")
        echo "BROKEN|qdrant_storage|Invalid JSON response: ${error_message:0:80}|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
    fi
else
    error_message=$(trim_whitespace "$collections_result")
    echo "BROKEN|qdrant_storage|Cannot query collections: ${error_message:0:80}|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
fi

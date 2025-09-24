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

base_url="http://localhost:6333"
helper_cmd_prefix="docker run --rm --network container:vectors $CURL_HELPER_IMAGE"
helper_run_base=(docker run --rm --network container:vectors "$CURL_HELPER_IMAGE")
curl_headers=()
[[ -n "$QDRANT_API_KEY" ]] && curl_headers+=(-H "api-key: $QDRANT_API_KEY")

trim_whitespace() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

# WHEN: We analyze Qdrant collections
collections_cmd_display="$helper_cmd_prefix -s --connect-timeout $CURL_TIMEOUT"
if [[ -n "$QDRANT_API_KEY" ]]; then
    collections_cmd_display+=" -H 'api-key: $QDRANT_API_KEY'"
fi
collections_cmd_display+=" ${base_url}/collections"

if collections_result=$("${helper_run_base[@]}" -s --connect-timeout "$CURL_TIMEOUT" "${curl_headers[@]}" "${base_url}/collections" 2>&1); then
    if echo "$collections_result" | jq . >/dev/null 2>&1; then
        collection_count=$(echo "$collections_result" | jq -r '.result.collections | length' 2>/dev/null || echo "0")

        if [[ "$collection_count" -gt 0 ]]; then
            first_collection=$(echo "$collections_result" | jq -r '.result.collections[0].name' 2>/dev/null || echo "")

            if [[ -n "$first_collection" && "$first_collection" != "null" ]]; then
                collection_cmd_display="$helper_cmd_prefix -s --connect-timeout $CURL_TIMEOUT"
                if [[ -n "$QDRANT_API_KEY" ]]; then
                    collection_cmd_display+=" -H 'api-key: $QDRANT_API_KEY'"
                fi
                collection_cmd_display+=" ${base_url}/collections/$first_collection"

                if collection_info=$("${helper_run_base[@]}" -s --connect-timeout "$CURL_TIMEOUT" "${curl_headers[@]}" "${base_url}/collections/$first_collection" 2>&1); then
                    vector_count=$(echo "$collection_info" | jq -r '.result.vectors_count // 0' 2>/dev/null || echo "0")
                    dimension=$(echo "$collection_info" | jq -r '.result.config.params.vectors.size // "unknown"' 2>/dev/null || echo "unknown")
                    distance=$(echo "$collection_info" | jq -r '.result.config.params.vectors.distance // "unknown"' 2>/dev/null || echo "unknown")

                    echo "INFO|qdrant_storage|Collections: $collection_count, Vectors: $vector_count, Dimension: $dimension, Distance: $distance|$collection_cmd_display"
                else
                    echo "INFO|qdrant_storage|Collections: $collection_count (details unavailable)|$collection_cmd_display"
                fi
            else
                echo "INFO|qdrant_storage|Collections: $collection_count (no valid collection names)|$collections_cmd_display"
            fi
        else
            echo "INFO|qdrant_storage|No collections found - new installation|$collections_cmd_display"
        fi
    else
        echo "BROKEN|qdrant_storage|Invalid JSON response: ${collections_result:0:80}|$collections_cmd_display"
    fi
else
    error_message=$(trim_whitespace "$collections_result")
    echo "BROKEN|qdrant_storage|Cannot query collections: ${error_message:0:80}|$collections_cmd_display"
fi

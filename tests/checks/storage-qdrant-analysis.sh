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

# Check if Qdrant container is running
if ! docker compose ps -q vectors >/dev/null 2>&1; then
    echo "BROKEN|qdrant_storage|Qdrant container not found|docker compose ps vectors"
    exit 0
fi

# Prepare headers
headers=""
[[ -n "$QDRANT_API_KEY" ]] && headers="-H 'api-key: $QDRANT_API_KEY'"

# WHEN: We analyze Qdrant collections
if collections_result=$(docker run --rm --network container:vectors alpine/curl:latest sh -c "curl -s $headers http://localhost:6333/collections" 2>&1); then
    # Check if response is valid JSON
    if echo "$collections_result" | jq . >/dev/null 2>&1; then
        # Extract collection information
        collection_count=$(echo "$collections_result" | jq -r '.result.collections | length' 2>/dev/null || echo "0")
        
        if [[ "$collection_count" -gt 0 ]]; then
            # Get details for first collection
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
        echo "BROKEN|qdrant_storage|Invalid JSON response: ${collections_result:0:50}|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
    fi
else
    echo "BROKEN|qdrant_storage|Cannot query collections: ${collections_result:0:50}|docker run --rm --network container:vectors alpine/curl:latest curl -s $headers http://localhost:6333/collections"
fi

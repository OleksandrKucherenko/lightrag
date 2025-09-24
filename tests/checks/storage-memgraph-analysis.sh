#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Memgraph Graph Storage Analysis Check
# =============================================================================
# 
# GIVEN: Memgraph used for graph storage in LightRAG
# WHEN: We analyze graph structure and schema
# THEN: We report on graph storage state and data
# =============================================================================

# Load environment
MEMGRAPH_USER="${MEMGRAPH_USER:-}"
MEMGRAPH_PASSWORD="${MEMGRAPH_PASSWORD:-}"

# Check if Memgraph container is running
if ! docker compose ps -q graph >/dev/null 2>&1; then
    echo "BROKEN|memgraph_storage|Memgraph container not found|docker compose ps graph"
    exit 0
fi

# Prepare auth flags
auth_flags=""
[[ -n "$MEMGRAPH_USER" && -n "$MEMGRAPH_PASSWORD" ]] && auth_flags="--username '$MEMGRAPH_USER' --password '$MEMGRAPH_PASSWORD'"

# WHEN: We analyze graph structure
# Count nodes
if node_result=$(docker compose exec -T graph sh -c "echo 'MATCH (n) RETURN count(n) as node_count;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags" 2>&1); then
    node_count=$(echo "$node_result" | grep -o '[0-9]\+' | head -1 || echo "0")
    
    # Count relationships
    if rel_result=$(docker compose exec -T graph sh -c "echo 'MATCH ()-[r]->() RETURN count(r) as rel_count;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags" 2>&1); then
        rel_count=$(echo "$rel_result" | grep -o '[0-9]\+' | head -1 || echo "0")
        
        # Get index information
        if index_result=$(docker compose exec -T graph sh -c "echo 'SHOW INDEX INFO;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags" 2>&1); then
            index_count=$(echo "$index_result" | grep -c "label+property" 2>/dev/null || echo "0")
            
            # THEN: Report comprehensive graph analysis
            if [[ "$node_count" -gt 0 || "$rel_count" -gt 0 ]]; then
                echo "INFO|memgraph_storage|Nodes: $node_count, Relationships: $rel_count, Indexes: $index_count|docker exec graph mgconsole $auth_flags"
            else
                echo "INFO|memgraph_storage|Empty graph - no nodes or relationships, Indexes: $index_count|docker exec graph mgconsole $auth_flags"
            fi
        else
            echo "INFO|memgraph_storage|Nodes: $node_count, Relationships: $rel_count, Indexes: unknown|docker exec graph mgconsole $auth_flags"
        fi
    else
        echo "BROKEN|memgraph_storage|Cannot count relationships: ${rel_result:0:50}|docker exec graph mgconsole $auth_flags"
    fi
else
    echo "BROKEN|memgraph_storage|Cannot count nodes: ${node_result:0:50}|docker exec graph mgconsole $auth_flags"
fi

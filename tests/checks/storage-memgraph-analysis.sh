#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Memgraph Graph Storage Analysis Check
# =============================================================================
# GIVEN: Memgraph used for graph storage in LightRAG
# WHEN: We analyze graph structure and schema
# THEN: We report on graph storage state and data
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="memgraph_storage"
readonly BROKEN_CONTAINER="BROKEN|${TEST_ID}|Memgraph container not found|docker compose ps graph"
readonly BROKEN_NODES="BROKEN|${TEST_ID}|Cannot count nodes|docker exec graph mgconsole"
readonly BROKEN_RELS="BROKEN|${TEST_ID}|Cannot count relationships|docker exec graph mgconsole"
readonly INFO_STORAGE="INFO|${TEST_ID}|Graph storage active|docker exec graph mgconsole"
readonly INFO_EMPTY="INFO|${TEST_ID}|Empty graph|docker exec graph mgconsole"

# GIVEN: Load environment and check prerequisites
MEMGRAPH_USER="${MEMGRAPH_USER:-}"
MEMGRAPH_PASSWORD="${MEMGRAPH_PASSWORD:-}"

# WHEN: Check if Memgraph container is running
CONTAINER_RUNNING=$(probe_docker_service_running "graph" && echo "true" || echo "false")

# THEN: Exit early if container not running
[[ "$CONTAINER_RUNNING" == "false" ]] && { echo "$BROKEN_CONTAINER"; exit 0; }

# WHEN: Count nodes
NODE_RESULT=$(clean_output "$(probe_memgraph_query "MATCH (n) RETURN count(n) as node_count;")")
NODE_SUCCESS=$([[ "$NODE_RESULT" != "QUERY_FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if cannot count nodes
[[ "$NODE_SUCCESS" == "false" ]] && { echo "$BROKEN_NODES"; exit 0; }

# WHEN: Extract node count
NODE_COUNT=$(echo "$NODE_RESULT" | grep -o '[0-9]\+' | head -1 || echo "0")

# WHEN: Count relationships
REL_RESULT=$(clean_output "$(probe_memgraph_query "MATCH ()-[r]->() RETURN count(r) as rel_count;")")
REL_SUCCESS=$([[ "$REL_RESULT" != "QUERY_FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if cannot count relationships
[[ "$REL_SUCCESS" == "false" ]] && { echo "$BROKEN_RELS"; exit 0; }

# WHEN: Extract relationship count
REL_COUNT=$(echo "$REL_RESULT" | grep -o '[0-9]\+' | head -1 || echo "0")

# THEN: Report storage analysis
if [[ "$NODE_COUNT" -gt 0 ]] || [[ "$REL_COUNT" -gt 0 ]]; then
    echo "$INFO_STORAGE"
else
    echo "$INFO_EMPTY"
fi
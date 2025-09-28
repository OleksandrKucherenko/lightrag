#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG Health: Container Status Check
# =============================================================================
# GIVEN: LightRAG container should be running and healthy
# WHEN: We check the container status via Docker Compose
# THEN: We verify the container is up and running
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="rag_container_status"
readonly PASS_CONTAINER_RUNNING="PASS|${TEST_ID}|LightRAG container running|docker compose ps rag"
readonly FAIL_CONTAINER_NOTHEALTHY="FAIL|${TEST_ID}|LightRAG container not healthy|docker compose ps rag"
readonly BROKEN_CONTAINER_MISSING="BROKEN|${TEST_ID}|LightRAG container not found|docker compose ps rag"
readonly BROKEN_STATUS_CHECK="BROKEN|${TEST_ID}|Cannot check container status|docker compose ps rag"

# WHEN: Check if LightRAG container exists
CONTAINER_EXISTS=$(probe_docker_service_running "rag" && echo "true" || echo "false")

# THEN: Exit if container missing
[[ "$CONTAINER_EXISTS" == "false" ]] && { echo "$BROKEN_CONTAINER_MISSING"; exit 0; }

# WHEN: Check container health status
CONTAINER_STATUS=$(docker compose ps rag --format "table {{.Status}}" | tail -n +2 2>&1 || echo "FAILED")
STATUS_SUCCESS=$([[ "$CONTAINER_STATUS" != "FAILED" ]] && echo "true" || echo "false")

# THEN: Exit if status check failed
[[ "$STATUS_SUCCESS" == "false" ]] && { echo "$BROKEN_STATUS_CHECK: ${CONTAINER_STATUS:0:50}"; exit 0; }

# WHEN: Check if container is healthy
CONTAINER_HEALTHY=$(echo "$CONTAINER_STATUS" | grep -q "Up" && echo "true" || echo "false")

# THEN: Report container status
if [[ "$CONTAINER_HEALTHY" == "true" ]]; then
    echo "$PASS_CONTAINER_RUNNING"
else
    echo "$FAIL_CONTAINER_NOTHEALTHY: $CONTAINER_STATUS"
fi
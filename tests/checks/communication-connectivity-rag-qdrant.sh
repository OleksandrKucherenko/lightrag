#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Service Connectivity: LightRAG → Qdrant
# =============================================================================
# GIVEN: LightRAG should be able to connect to Qdrant
# WHEN: We test network connectivity from LightRAG to Qdrant
# THEN: We verify the connection is established
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="service_connectivity_rag_qdrant"
readonly PASS_MSG="PASS|${TEST_ID}|LightRAG → Qdrant connectivity established|docker compose exec -T rag sh -c \"timeout 5 bash -c 'echo > /dev/tcp/vectors/6333'\""
readonly FAIL_CONNECT="FAIL|${TEST_ID}|LightRAG → Qdrant connectivity failed|docker compose exec -T rag sh -c \"timeout 5 bash -c 'echo > /dev/tcp/vectors/6333'\""
readonly BROKEN_TOOLING="BROKEN|${TEST_ID}|Connectivity tooling unavailable in rag|docker compose exec -T rag sh -c \"timeout 5 bash -c 'echo > /dev/tcp/vectors/6333'\""
readonly BROKEN_SOURCE="BROKEN|${TEST_ID}|Source container 'rag' not found|docker compose ps rag"
readonly BROKEN_TARGET="BROKEN|${TEST_ID}|Target container 'vectors' not found|docker compose ps vectors"

# WHEN: Check if source container exists
SOURCE_RUNNING=$(probe_docker_service_running "rag" && echo "true" || echo "false")

# THEN: Exit if source container not running
[[ "$SOURCE_RUNNING" == "false" ]] && { echo "$BROKEN_SOURCE"; exit 0; }

# WHEN: Check if target container exists
TARGET_RUNNING=$(probe_docker_service_running "vectors" && echo "true" || echo "false")

# THEN: Exit if target container not running
[[ "$TARGET_RUNNING" == "false" ]] && { echo "$BROKEN_TARGET"; exit 0; }

# WHEN: Test connectivity using bash /dev/tcp
CONNECTIVITY_TEST=$(clean_output "$(probe_docker_exec "rag" sh -c "timeout 5 bash -c 'echo > /dev/tcp/vectors/6333' 2>/dev/null && echo 'CONNECTED' || echo 'FAILED'")")

# THEN: Report connectivity result
if [[ "$CONNECTIVITY_TEST" == *"CONNECTED"* ]]; then
    echo "$PASS_MSG"
elif [[ "$CONNECTIVITY_TEST" == *"FAILED"* ]]; then
    echo "$FAIL_CONNECT"
else
    echo "$BROKEN_TOOLING"
fi
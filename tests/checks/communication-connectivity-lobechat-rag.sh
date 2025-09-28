#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Service Connectivity: LobeChat → LightRAG
# =============================================================================
# GIVEN: LobeChat should be able to connect to LightRAG
# WHEN: We test network connectivity from LobeChat to LightRAG
# THEN: We verify the connection is established
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="service_connectivity_lobechat_rag"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat → LightRAG connectivity established|docker compose exec -T lobechat nc -z rag 9621"
readonly FAIL_CONNECT="FAIL|${TEST_ID}|LobeChat → LightRAG connectivity failed|docker compose exec -T lobechat nc -z rag 9621"
readonly BROKEN_TOOLING="BROKEN|${TEST_ID}|Connectivity tooling unavailable in lobechat|docker compose exec -T lobechat nc -z rag 9621"
readonly BROKEN_SOURCE="BROKEN|${TEST_ID}|Source container 'lobechat' not found|docker compose ps lobechat"
readonly BROKEN_TARGET="BROKEN|${TEST_ID}|Target container 'rag' not found|docker compose ps rag"

# WHEN: Check if source container exists
SOURCE_RUNNING=$(probe_docker_service_running "lobechat" && echo "true" || echo "false")

# THEN: Exit if source container not running
[[ "$SOURCE_RUNNING" == "false" ]] && { echo "$BROKEN_SOURCE"; exit 0; }

# WHEN: Check if target container exists
TARGET_RUNNING=$(probe_docker_service_running "rag" && echo "true" || echo "false")

# THEN: Exit if target container not running
[[ "$TARGET_RUNNING" == "false" ]] && { echo "$BROKEN_TARGET"; exit 0; }

# WHEN: Test connectivity using netcat
CONNECTIVITY_TEST=$(clean_output "$(probe_docker_exec "lobechat" sh -c "nc -z rag 9621 2>&1 && echo 'CONNECTED' || echo 'FAILED'")")

# THEN: Report connectivity result
if [[ "$CONNECTIVITY_TEST" == *"CONNECTED"* ]]; then
    echo "$PASS_MSG"
elif [[ "$CONNECTIVITY_TEST" == *"FAILED"* ]]; then
    echo "$FAIL_CONNECT"
else
    echo "$BROKEN_TOOLING"
fi
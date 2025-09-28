#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Service Connectivity: LobeChat → Redis
# =============================================================================
# GIVEN: LobeChat should be able to connect to Redis
# WHEN: We test network connectivity from LobeChat to Redis
# THEN: We verify the connection is established
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="service_connectivity_lobechat_redis"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat → Redis connectivity established|docker compose exec -T lobechat nc -z kv 6379"
readonly FAIL_CONNECT="FAIL|${TEST_ID}|LobeChat → Redis connectivity failed|docker compose exec -T lobechat nc -z kv 6379"
readonly BROKEN_TOOLING="BROKEN|${TEST_ID}|Connectivity tooling unavailable in lobechat|docker compose exec -T lobechat nc -z kv 6379"
readonly BROKEN_SOURCE="BROKEN|${TEST_ID}|Source container 'lobechat' not found|docker compose ps lobechat"
readonly BROKEN_TARGET="BROKEN|${TEST_ID}|Target container 'kv' not found|docker compose ps kv"

# WHEN: Check if source container exists
SOURCE_RUNNING=$(probe_docker_service_running "lobechat" && echo "true" || echo "false")

# THEN: Exit if source container not running
[[ "$SOURCE_RUNNING" == "false" ]] && { echo "$BROKEN_SOURCE"; exit 0; }

# WHEN: Check if target container exists
TARGET_RUNNING=$(probe_docker_service_running "kv" && echo "true" || echo "false")

# THEN: Exit if target container not running
[[ "$TARGET_RUNNING" == "false" ]] && { echo "$BROKEN_TARGET"; exit 0; }

# WHEN: Test connectivity using netcat
CONNECTIVITY_TEST=$(clean_output "$(probe_docker_exec "lobechat" sh -c "nc -z kv 6379 2>&1 && echo 'CONNECTED' || echo 'FAILED'")")

# THEN: Report connectivity result
if [[ "$CONNECTIVITY_TEST" == *"CONNECTED"* ]]; then
    echo "$PASS_MSG"
elif [[ "$CONNECTIVITY_TEST" == *"FAILED"* ]]; then
    echo "$FAIL_CONNECT"
else
    echo "$BROKEN_TOOLING"
fi
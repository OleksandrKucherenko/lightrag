#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Docker Compose Proxy URL Check
# =============================================================================
# GIVEN: Docker Compose should set internal proxy URL for LobeChat
# WHEN: We inspect docker-compose.yaml for proxy URL configuration
# THEN: We verify proxy URL is set to internal LightRAG service
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_alignment_compose_proxy"
readonly PASS_MSG="PASS|${TEST_ID}|Docker Compose sets internal LightRAG proxy URL|grep 'OPENAI_PROXY_URL=http://rag:9621/v1' docker-compose.yaml"
readonly FAIL_NOTSET="FAIL|${TEST_ID}|Docker Compose should set OPENAI_PROXY_URL=http://rag:9621/v1|grep 'OPENAI_PROXY_URL' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"

# GIVEN: Check if docker-compose.yaml exists
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "$BROKEN_COMPOSE"; exit 0; }

# WHEN: Check for proxy URL setting in docker-compose.yaml
PROXY_URL_SET=$(grep -Fq 'OPENAI_PROXY_URL=http://rag:9621/v1' "$COMPOSE_FILE" && echo "true" || echo "false")

# THEN: Report result
if [[ "$PROXY_URL_SET" == "true" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_NOTSET"
fi
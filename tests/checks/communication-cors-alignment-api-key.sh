#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS API Key Mapping Check
# =============================================================================
# GIVEN: Docker Compose should map LIGHTRAG_API_KEY to LobeChat OPENAI_API_KEY
# WHEN: We inspect docker-compose.yaml for environment variable mapping
# THEN: We verify API key is properly mapped between services
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="cors_alignment_api_key"
readonly PASS_MSG="PASS|${TEST_ID}|Docker Compose maps LIGHTRAG_API_KEY to LobeChat|grep 'OPENAI_API_KEY=\${LIGHTRAG_API_KEY}' docker-compose.yaml"
readonly FAIL_NOTMAPPED="FAIL|${TEST_ID}|Docker Compose should map LIGHTRAG_API_KEY to OPENAI_API_KEY|grep 'OPENAI_API_KEY' docker-compose.yaml"
readonly BROKEN_COMPOSE="BROKEN|${TEST_ID}|docker-compose.yaml not found|ls docker-compose.yaml"

# GIVEN: Check if docker-compose.yaml exists
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yaml"
COMPOSE_EXISTS=$([[ -f "$COMPOSE_FILE" ]] && echo "true" || echo "false")

# THEN: Exit if compose file missing
[[ "$COMPOSE_EXISTS" == "false" ]] && { echo "$BROKEN_COMPOSE"; exit 0; }

# WHEN: Check for API key mapping in docker-compose.yaml
API_KEY_MAPPED=$(grep -Fq 'OPENAI_API_KEY=${LIGHTRAG_API_KEY}' "$COMPOSE_FILE" && echo "true" || echo "false")

# THEN: Report result
if [[ "$API_KEY_MAPPED" == "true" ]]; then
    echo "$PASS_MSG"
else
    echo "$FAIL_NOTMAPPED"
fi
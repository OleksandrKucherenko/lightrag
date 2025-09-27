#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Memgraph Authentication Check
# =============================================================================
# GIVEN: A Memgraph instance that may have authentication configured
# WHEN: We test database connection with and without credentials
# THEN: We determine if authentication is ENABLED, DISABLED, or BROKEN
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"
source "${CHECK_TOOLS:-"tests/tools"}/checks-probes.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="memgraph_auth"
readonly ENABLED_MSG="ENABLED|${TEST_ID}|Credentials working properly|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
readonly DISABLED_MSG="DISABLED|${TEST_ID}|No credentials configured - open access|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
readonly BROKEN_CONTAINER="BROKEN|${TEST_ID}|Memgraph container not found|docker compose ps graph"
readonly BROKEN_NOAUTH="BROKEN|${TEST_ID}|No credentials set but query failed|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
readonly BROKEN_CONNECT_NOAUTH="BROKEN|${TEST_ID}|Cannot connect to Memgraph container|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
readonly BROKEN_AUTHFAIL="BROKEN|${TEST_ID}|Credentials set but auth failed|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
readonly BROKEN_CONNECT_AUTH="BROKEN|${TEST_ID}|Cannot connect with credentials|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"

# GIVEN: Load environment and check prerequisites
MEMGRAPH_USER="${MEMGRAPH_USER:-}"
MEMGRAPH_PASSWORD="${MEMGRAPH_PASSWORD:-}"

# WHEN: Check if Memgraph container is running
CONTAINER_RUNNING=$(probe_docker_service_running "graph" && echo "true" || echo "false")

# THEN: Exit early if container not running
[[ "$CONTAINER_RUNNING" == "false" ]] && { echo "$BROKEN_CONTAINER"; exit 0; }

# WHEN: Test authentication based on credentials configuration
if [[ -z "$MEMGRAPH_USER" ]] || [[ -z "$MEMGRAPH_PASSWORD" ]]; then
    # No credentials configured - test unauthenticated access
    QUERY_RESULT=$(clean_output "$(probe_memgraph_query "RETURN 1;")")
    QUERY_SUCCESS=$([[ "$QUERY_RESULT" != "QUERY_FAILED" ]] && echo "true" || echo "false")

    if [[ "$QUERY_SUCCESS" == "true" ]]; then
        echo "$DISABLED_MSG"
    else
        echo "$BROKEN_NOAUTH"
    fi
else
    # Credentials configured - test authenticated access
    AUTH_QUERY_RESULT=$(clean_output "$(MEMGRAPH_USER=\"$MEMGRAPH_USER\" MEMGRAPH_PASSWORD=\"$MEMGRAPH_PASSWORD\" probe_memgraph_query "RETURN 1;")")
    AUTH_SUCCESS=$([[ "$AUTH_QUERY_RESULT" != "QUERY_FAILED" ]] && echo "true" || echo "false")

    if [[ "$AUTH_SUCCESS" == "true" ]]; then
        echo "$ENABLED_MSG"
    else
        echo "$BROKEN_AUTHFAIL"
    fi
fi
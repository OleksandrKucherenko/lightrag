#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Memgraph Authentication Check
# =============================================================================
# 
# GIVEN: A Memgraph instance that may have authentication configured
# WHEN: We test database connection with and without credentials
# THEN: We determine if authentication is ENABLED, DISABLED, or BROKEN
# =============================================================================

# Load environment
MEMGRAPH_USER="${MEMGRAPH_USER:-}"
MEMGRAPH_PASSWORD="${MEMGRAPH_PASSWORD:-}"

# Check if Memgraph container is running
if ! docker compose ps -q graph >/dev/null 2>&1; then
    echo "BROKEN|memgraph_auth|Memgraph container not found|docker compose ps graph"
    exit 0
fi

if [[ -z "$MEMGRAPH_USER" || -z "$MEMGRAPH_PASSWORD" ]]; then
    # WHEN: No credentials are configured
    # THEN: Memgraph should be accessible without authentication (DISABLED state)
    
    if result=$(docker compose exec -T graph sh -c "echo 'RETURN 1;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false" 2>&1); then
        if [[ "$result" == *"1"* ]]; then
            echo "DISABLED|memgraph_auth|No credentials configured - open access|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
        else
            echo "BROKEN|memgraph_auth|No credentials set but query failed: ${result:0:50}|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
        fi
    else
        echo "BROKEN|memgraph_auth|Cannot connect to Memgraph container|docker exec graph mgconsole --host 127.0.0.1 --port 7687"
    fi
else
    # WHEN: Credentials are configured
    # THEN: Test authentication
    
    if result=$(docker compose exec -T graph sh -c "echo 'RETURN 1;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false --username '$MEMGRAPH_USER' --password '$MEMGRAPH_PASSWORD'" 2>&1); then
        if [[ "$result" == *"1"* ]]; then
            echo "ENABLED|memgraph_auth|Credentials working properly|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
        else
            echo "BROKEN|memgraph_auth|Credentials set but auth failed: ${result:0:50}|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
        fi
    else
        echo "BROKEN|memgraph_auth|Cannot connect with credentials|docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
    fi
fi

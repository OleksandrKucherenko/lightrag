#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Service Connectivity Check
# =============================================================================
#
# GIVEN: Services that should communicate with each other
# WHEN: We test inter-service network connectivity
# THEN: We report on communication status between services
# =============================================================================

# Define service connections to test
declare -a CONNECTIONS=(
    "rag:kv:6379:LightRAG → Redis"
    "rag:vectors:6333:LightRAG → Qdrant"
    "rag:graph:7687:LightRAG → Memgraph"
    "lobechat:rag:9621:LobeChat → LightRAG"
    "lobechat:kv:6379:LobeChat → Redis"
)

COMMAND_CORE=""
COMMAND_EXTRA=""

extract_command_data() {
    local raw_output="$1"
    local fallback="$2"

    local sanitized="${raw_output//$'\r'/}"
    local first_line="${sanitized%%$'\n'*}"
    local remainder=""

    if [[ "$sanitized" == *$'\n'* ]]; then
        remainder="${sanitized#*$'\n'}"
    fi

    if [[ "$first_line" == TOOL:* ]]; then
        COMMAND_CORE="${first_line#TOOL:}"
        COMMAND_EXTRA="$remainder"
    else
        COMMAND_CORE="$fallback"
        COMMAND_EXTRA="$sanitized"
    fi

    COMMAND_CORE="$(printf '%s' "$COMMAND_CORE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ -z "$COMMAND_CORE" ]]; then
        COMMAND_CORE="$fallback"
    fi

    COMMAND_EXTRA="$(printf '%s' "$COMMAND_EXTRA" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
}

# Test each connection
for connection in "${CONNECTIONS[@]}"; do
    IFS=':' read -r from_container to_container port description <<<"$connection"

    # Check if source container exists
    if ! docker compose ps -q "$from_container" >/dev/null 2>&1; then
        echo "BROKEN|service_connectivity|$description - source container '$from_container' not found|docker compose ps $from_container"
        continue
    fi

    # Check if target container exists
    if ! docker compose ps -q "$to_container" >/dev/null 2>&1; then
        echo "BROKEN|service_connectivity|$description - target container '$to_container' not found|docker compose ps $to_container"
        continue
    fi

    # WHEN: We test network connectivity without assuming the presence of specific CLI tools
    if result=$(
        docker compose exec -T "$from_container" sh -s "$to_container" "$port" <<'SCRIPT'
set -eu

target_host="$1"
target_port="$2"

if command -v nc >/dev/null 2>&1; then
    printf 'TOOL:nc -z %s %s\n' "$target_host" "$target_port"
    nc -z "$target_host" "$target_port"
    exit $?
fi

if command -v python3 >/dev/null 2>&1; then
    printf 'TOOL:python3 socket.connect(%s,%s)\n' "$target_host" "$target_port"
    python3 - "$target_host" "$target_port" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])

sock = socket.socket()
sock.settimeout(5)

try:
    sock.connect((host, port))
except Exception as exc:  # noqa: BLE001 - want the raw message in stderr
    print(exc, file=sys.stderr)
    sys.exit(1)
finally:
    sock.close()

sys.exit(0)
PY
    exit $?
fi

if command -v python >/dev/null 2>&1; then
    printf 'TOOL:python socket.connect(%s,%s)\n' "$target_host" "$target_port"
    python - "$target_host" "$target_port" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])

sock = socket.socket()
sock.settimeout(5)

try:
    sock.connect((host, port))
except Exception as exc:  # noqa: BLE001 - want the raw message in stderr
    print(exc, file=sys.stderr)
    sys.exit(1)
finally:
    sock.close()

sys.exit(0)
PY
    exit $?
fi

if command -v node >/dev/null 2>&1; then
    printf 'TOOL:node net.createConnection(%s,%s)\n' "$target_host" "$target_port"
    node - "$target_host" "$target_port" <<'NODE'
const net = require('net');

const host = process.argv[1];
const port = Number(process.argv[2]);

const socket = net.createConnection({ host, port });
let settled = false;

const finish = (code, message) => {
  if (settled) return;
  settled = true;
  if (message) {
    console.error(message);
  }
  socket.destroy();
  process.exit(code);
};

socket.setTimeout(5000);
socket.on('connect', () => finish(0));
socket.on('timeout', () => finish(1, 'timeout'));
socket.on('error', (error) => finish(1, error?.message ?? String(error)));
NODE
    exit $?
fi

echo "connectivity test tooling not available"
exit 2
SCRIPT
    ); then
        extract_command_data "$result" "connectivity probe to ${to_container}:${port}"
        command_display="docker compose exec -T ${from_container} ${COMMAND_CORE}"
        echo "PASS|service_connectivity|$description - network connectivity established|$command_display"
    else
        status=$?
        extract_command_data "$result" "connectivity probe to ${to_container}:${port}"
        command_display="docker compose exec -T ${from_container} ${COMMAND_CORE}"
        local_message="$COMMAND_EXTRA"
        if [[ -z "$local_message" ]]; then
            local_message="no diagnostic output"
        fi
        local_message="${local_message:0:80}"
        case "$status" in
        1)
            echo "FAIL|service_connectivity|$description - network connectivity failed (${local_message})|$command_display"
            ;;
        2)
            echo "BROKEN|service_connectivity|$description - connectivity tooling unavailable in '$from_container'|$command_display"
            ;;
        *)
            echo "BROKEN|service_connectivity|$description - cannot test connectivity: ${local_message}|$command_display"
            ;;
        esac
    fi
done

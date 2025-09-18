#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# Basic colourised logging helpers
# -----------------------------------------------------------------------------
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  COLOR_RESET="$(tput sgr0)"
  COLOR_BOLD="$(tput bold)"
  COLOR_GREEN="$(tput setaf 2)"
  COLOR_YELLOW="$(tput setaf 3)"
  COLOR_BLUE="$(tput setaf 4)"
  COLOR_RED="$(tput setaf 1)"
  COLOR_GRAY="$(tput setaf 7)"
else
  COLOR_RESET=""
  COLOR_BOLD=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_RED=""
  COLOR_GRAY=""
fi

log_info() { printf "%s%s%s\n" "${COLOR_BLUE}" "$1" "${COLOR_RESET}"; }
log_warn() { printf "%s%s%s\n" "${COLOR_YELLOW}" "$1" "${COLOR_RESET}"; }
log_error() { printf "%s%s%s\n" "${COLOR_RED}" "$1" "${COLOR_RESET}"; }
log_success() { printf "%s%s%s\n" "${COLOR_GREEN}" "$1" "${COLOR_RESET}"; }
log_section() { printf "\n%s%s%s\n" "${COLOR_BOLD}" "$1" "${COLOR_RESET}"; }

# -----------------------------------------------------------------------------
# Result bookkeeping so we can emit a neat summary and exit appropriately
# -----------------------------------------------------------------------------
declare -A RESULT_STATUS=()
declare -A RESULT_DETAILS=()
RESULT_KEYS=()

record_result() {
  local key="$1" status="$2" message="$3"
  RESULT_STATUS["$key"]="$status"
  RESULT_DETAILS["$key"]="$message"
  RESULT_KEYS+=("$key")
  local tag="[$status] $key: $message"
  if [[ "$status" == "PASS" ]]; then
    # log_success "$tag"
    printf "[%sOK%s]%s $key: $message%s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_GRAY}" "${COLOR_RESET}"
  else
    # log_error "$tag"
    printf "[%sNO%s]%s $key: $message%s\n" "${COLOR_RED}" "${COLOR_RESET}" "${COLOR_GRAY}" "${COLOR_RESET}"
  fi
}

# -----------------------------------------------------------------------------
# Utility helpers
# -----------------------------------------------------------------------------
require_cmd() {
  local cmd="$1" friendly="${2:-$1}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing required command: $friendly"
    exit 1
  fi
}

resolve_flag() {
  local url="$1"
  local proto hostport host port
  proto="${url%%://*}"
  hostport="${url#*://}"
  hostport="${hostport%%/*}"
  host="${hostport%%:*}"
  port="${hostport#*:}"
  if [[ "$port" == "$hostport" ]]; then
    if [[ "$proto" == "https" ]]; then
      port=443
    else
      port=80
    fi
  fi
  printf '%s:%s:127.0.0.1' "$host" "$port"
}

fetch_url() {
  local method="$1" url="$2" status_var="$3" body_var="$4"
  shift 4
  local header_file body_file resolve_arg
  local http_status=0 http_body="" exit_code=0
  header_file="$(mktemp)"
  body_file="$(mktemp)"
  resolve_arg="$(resolve_flag "$url")"
  if ! curl -skL --connect-timeout 5 --max-time 20 --retry 0 --resolve "$resolve_arg" -X "$method" "$url" "$@" -D "$header_file" -o "$body_file"; then
    exit_code=$?
  fi
  http_status=$(awk 'toupper($1) ~ /^HTTP/ { code=$2 } END { if (code) print code }' "$header_file")
  if [[ -z "$http_status" ]]; then
    http_status=0
  fi
  http_body="$(cat "$body_file")"
  rm -f "$header_file" "$body_file"
  if (( exit_code != 0 )); then
    http_body="curl exited with code ${exit_code}: ${http_body}"
  fi
  printf -v "$status_var" '%s' "$http_status"
  printf -v "$body_var" '%s' "$http_body"
  return 0
}

load_env_file() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "${line}" =~ ^\s*# ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      # Trim surrounding quotes if present
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      # Only export if not already defined (secrets are injected by mise)
      if [[ -z "${!key+x}" ]]; then
        export "$key=$value"
      fi
    fi
  done <"$file"
}

assert_env_vars() {
  local missing=()
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing[@]} )); then
    log_error "Missing required environment variables: ${missing[*]}"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Checks
# -----------------------------------------------------------------------------
check_compose_services() {
  log_section "Docker Compose"
  local services=(proxy monitor kv graph graph-ui vectors rag webui lobechat)
  local all_ok=1
  for svc in "${services[@]}"; do
    local cid
    if ! cid=$(docker compose ps -q "$svc" 2>/dev/null); then
      cid=""
    fi
    if [[ -z "$cid" ]]; then
      record_result "service:${svc}" "FAIL" "Container not running (docker compose ps -q ${svc} is empty)"
      all_ok=0
      continue
    fi
    local state health
    state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo "unknown")
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$cid" 2>/dev/null || echo "n/a")
    if [[ "$state" == "running" && ( "$health" == "healthy" || "$health" == "n/a" ) ]]; then
      record_result "service:${svc}" "PASS" "State=${state}, Health=${health}"
    else
      record_result "service:${svc}" "FAIL" "State=${state}, Health=${health}"
      all_ok=0
      log_warn "Recent logs for ${svc}:"
      docker compose logs "$svc" --tail 20 || true
    fi
  done
  return $(( all_ok ? 0 : 1 ))
}

check_reverse_proxy() {
  log_section "Reverse Proxy"
  local url="https://dev.localhost/"
  local status=0 body=""
  fetch_url "GET" "$url" status body
  if [[ "$status" -eq 200 && "$body" == *"LightRAG Local Development Stack"* ]]; then
    record_result "proxy:landing" "PASS" "Received expected landing content"
  else
    record_result "proxy:landing" "FAIL" "Status=${status}, Body snippet=$(echo "$body" | head -c 120)"
  fi
}

check_monitor_ui() {
  log_section "Monitoring UI"
  local url="https://monitor.dev.localhost/"
  local status=0 body=""
  fetch_url "GET" "$url" status body
  if [[ "$status" -eq 401 || "$status" -eq 403 ]]; then
    record_result "monitor:unauth" "PASS" "Rejected unauthenticated access with ${status}"
  else
    record_result "monitor:unauth" "FAIL" "Expected 401/403, got ${status}"
  fi

  local monitor_user="${MONITOR_BASIC_AUTH_USER:-admin}"
  local monitor_pass="${MONITOR_BASIC_AUTH_PASSWORD:-admin}"
  fetch_url "GET" "$url" status body -u "${monitor_user}:${monitor_pass}"
  if [[ "$status" -eq 200 && "$body" == *"<html"* && "$body" == *"Isaiah"* ]]; then
    record_result "monitor:auth" "PASS" "Authenticated HTML dashboard returned"
  elif [[ "$status" -eq 200 && "$body" == *"<html"* ]]; then
    record_result "monitor:auth" "PASS" "Authenticated HTML page returned"
  else
    record_result "monitor:auth" "FAIL" "Status=${status}, Body snippet=$(echo "$body" | head -c 120)"
  fi
}

check_redis_security() {
  log_section "Redis"
  local output=""
  if output=$(docker exec kv redis-cli ping 2>&1); then
    if [[ "$output" == *"NOAUTH"* || "$output" == *"Authentication required"* ]]; then
      record_result "redis:noauth" "PASS" "Unauthenticated access blocked"
    else
      record_result "redis:noauth" "FAIL" "Unexpected response: ${output}"
    fi
  else
    record_result "redis:noauth" "FAIL" "Command failed: ${output}"
  fi

  if output=$(docker exec kv redis-cli -a "${REDIS_PASSWORD}" ping 2>&1); then
    if [[ "$output" == *"PONG"* ]]; then
      record_result "redis:auth" "PASS" "Authenticated PING succeeded"
    else
      record_result "redis:auth" "FAIL" "Unexpected response: ${output}"
    fi
  else
    record_result "redis:auth" "FAIL" "Authentication command failed"
  fi
}

check_qdrant_security() {
  log_section "Qdrant"
  local url="https://vector.dev.localhost/collections"
  local status=0 body=""
  fetch_url "GET" "$url" status body -H "Accept: application/json"
  if [[ "$status" -eq 401 || "$status" -eq 403 ]]; then
    record_result "qdrant:noauth" "PASS" "Rejected without API key (${status})"
  else
    record_result "qdrant:noauth" "FAIL" "Expected 401/403, got ${status}"
  fi

  fetch_url "GET" "$url" status body -H "Accept: application/json" -H "api-key: ${QDRANT_API_KEY}"
  if [[ "$status" -eq 200 ]]; then
    if echo "$body" | jq -e . >/dev/null 2>&1; then
      record_result "qdrant:auth" "PASS" "Authenticated request returned JSON"
    else
      record_result "qdrant:auth" "FAIL" "Response not JSON: $(echo "$body" | head -c 120)"
    fi
  else
    record_result "qdrant:auth" "FAIL" "Expected 200 with API key, got ${status}"
  fi
}

check_memgraph_access() {
  log_section "Memgraph"
  local output=""
  if output=$(docker exec graph sh -c "echo 'RETURN 1;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false" 2>&1); then
    if [[ "$output" == *"1"* ]]; then
      record_result "memgraph:query" "PASS" "Cypher query succeeded"
    else
      record_result "memgraph:query" "FAIL" "Unexpected output: $(echo "$output" | head -c 120)"
    fi
  else
    record_result "memgraph:query" "FAIL" "mgconsole execution failed: $(echo "$output" | head -c 120)"
  fi
}

check_lightrag_api() {
  log_section "LightRAG API"
  local url="https://rag.dev.localhost/documents"
  local status=0 body=""
  fetch_url "GET" "$url" status body -H "Accept: application/json"
  if [[ "$status" -eq 401 || "$status" -eq 403 ]]; then
    record_result "lightrag:noauth" "PASS" "Unauthorized as expected (${status})"
  else
    record_result "lightrag:noauth" "FAIL" "Expected 401/403, got ${status}"
  fi

  fetch_url "GET" "$url" status body -H "Accept: application/json" -H "X-API-Key: ${LIGHTRAG_API_KEY}"
  if [[ "$status" -eq 200 ]]; then
    if echo "$body" | jq -e '.statuses' >/dev/null 2>&1; then
      record_result "lightrag:auth" "PASS" "Authorized request returned document statuses"
    else
      record_result "lightrag:auth" "FAIL" "Response missing statuses field: $(echo "$body" | head -c 120)"
    fi
  else
    record_result "lightrag:auth" "FAIL" "Expected 200 with API key, got ${status}"
  fi
}

check_webui_flow() {
  log_section "Open WebUI"
  local url="https://webui.dev.localhost/"
  local status=0 body=""
  fetch_url "GET" "$url" status body
  if [[ "$status" -eq 200 && "$body" == *"<html"* ]]; then
    record_result "webui:landing" "PASS" "Received HTML shell"
  else
    record_result "webui:landing" "FAIL" "Status=${status}, Body snippet=$(echo "$body" | head -c 120)"
  fi

  local signin_url="https://webui.dev.localhost/api/v1/auths/signin"
  local payload
  payload=$(jq -nc --arg email "${DEFAULT_ADMIN_EMAIL}" --arg password "${DEFAULT_ADMIN_PASSWORD}" '{email:$email,password:$password}')
  fetch_url "POST" "$signin_url" status body -H "Content-Type: application/json" -H "Accept: application/json" --data "$payload"
  if [[ "$status" -eq 200 ]]; then
    local token role
    token=$(echo "$body" | jq -r '.token // empty' 2>/dev/null || true)
    role=$(echo "$body" | jq -r '.role // empty' 2>/dev/null || true)
    if [[ -n "$token" ]]; then
      record_result "webui:signin" "PASS" "Signin succeeded (role=${role:-unknown})"
      local status2=0 body2=""
      fetch_url "GET" "https://webui.dev.localhost/api/v1/users/active" status2 body2 -H "Accept: application/json" -H "Authorization: Bearer ${token}"
      if [[ "$status2" -eq 200 ]]; then
        record_result "webui:authz" "PASS" "Authenticated API call succeeded"
      else
        record_result "webui:authz" "FAIL" "Expected 200 from authenticated call, got ${status2}"
      fi
    else
      record_result "webui:signin" "FAIL" "Signin response missing token"
    fi
  else
    record_result "webui:signin" "FAIL" "Expected 200 from signin, got ${status}"
  fi
}

check_lobechat_ui() {
  log_section "LobeChat"
  local base="https://lobechat.dev.localhost"
  local status=0 body=""

  fetch_url "GET" "${base}/api/health" status body -H "Accept: application/json"
  if [[ "$status" -eq 200 ]] && echo "$body" | jq -e '.status == "ok"' >/dev/null 2>&1; then
    record_result "lobechat:health" "PASS" "Health endpoint returned status=ok"
  else
    record_result "lobechat:health" "FAIL" "Status=${status}, Body snippet=$(echo "$body" | head -c 120)"
  fi

  fetch_url "GET" "${base}/api/models" status body -H "Accept: application/json"
  if [[ "$status" -eq 200 ]] && echo "$body" | jq -e '.. | scalars | select(. == "lightrag")' >/dev/null 2>&1; then
    record_result "lobechat:models" "PASS" "Models list contains lightrag"
  else
    record_result "lobechat:models" "FAIL" "Status=${status}, Body snippet=$(echo "$body" | head -c 120)"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  log_section "Preflight"
  require_cmd docker
  require_cmd jq
  if ! docker compose version >/dev/null 2>&1; then
    log_error "docker compose plugin not available"
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    log_error "curl command not available"
    exit 1
  fi

  load_env_file "${REPO_ROOT}/.env"

  assert_env_vars \
    LIGHTRAG_API_KEY \
    DEFAULT_ADMIN_EMAIL \
    DEFAULT_ADMIN_PASSWORD \
    REDIS_PASSWORD \
    QDRANT_API_KEY

  check_compose_services || true
  check_reverse_proxy
  check_monitor_ui
  check_redis_security
  check_qdrant_security
  check_memgraph_access
  check_lightrag_api
  check_webui_flow
  check_lobechat_ui

  log_section "Summary"
  local exit_code=0
  for key in "${RESULT_KEYS[@]}"; do
    local status="${RESULT_STATUS[$key]}"
    local message="${RESULT_DETAILS[$key]}"
    local tag="[$status] $key: $message"
    if [[ "$status" == "PASS" ]]; then
      # log_success "$tag"
      printf "[%sOK%s]%s $key: $message%s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_GRAY}" "${COLOR_RESET}"
    else
      # log_error "$tag"
      printf "[%sNO%s]%s $key: $message%s\n" "${COLOR_RED}" "${COLOR_RESET}" "${COLOR_GRAY}" "${COLOR_RESET}"
      exit_code=1
    fi
  done
  exit $exit_code
}

main "$@"

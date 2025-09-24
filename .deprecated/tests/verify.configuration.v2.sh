#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG Configuration Verification Script v2.0
# =============================================================================
# 
# This script follows TDD principles with GIVEN/WHEN/THEN structure.
# It distinguishes between:
# - ENABLED: Security/feature working properly
# - DISABLED: Security/feature not configured (not an error)
# - BROKEN: Security/feature configured but failing
#
# Focus: Simpler code, user-friendly messages, exact commands shown
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  COLOR_RESET="$(tput sgr0)"
  COLOR_GREEN="$(tput setaf 2)"
  COLOR_YELLOW="$(tput setaf 3)"
  COLOR_BLUE="$(tput setaf 4)"
  COLOR_RED="$(tput setaf 1)"
  COLOR_GRAY="$(tput setaf 8)"
else
  COLOR_RESET="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_BLUE="" COLOR_RED="" COLOR_GRAY=""
fi

# Result tracking
declare -a RESULTS=()
TOTAL_CHECKS=0
PASSED_CHECKS=0
INFO_CHECKS=0
FAILED_CHECKS=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_section() {
  printf "\n%s=== %s ===%s\n" "${COLOR_BLUE}" "$1" "${COLOR_RESET}"
}

record_result() {
  local status="$1" check="$2" message="$3" command="${4:-}"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  case "$status" in
    "ENABLED"|"PASS")
      printf "[%s✓%s] %s: %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      ;;
    "DISABLED"|"INFO")
      printf "[%sℹ%s] %s: %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      INFO_CHECKS=$((INFO_CHECKS + 1))
      ;;
    "BROKEN"|"FAIL")
      printf "[%s✗%s] %s: %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      ;;
  esac
  
  RESULTS+=("$status|$check|$message|$command")
}

load_env_files() {
  local env_files=(".env" ".env.databases" ".env.lightrag" ".env.lobechat" ".env.monitoring")
  
  for file in "${env_files[@]}"; do
    local filepath="${REPO_ROOT}/${file}"
    [[ -r "$filepath" ]] || continue
    
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "${line}" =~ ^\s*# ]] && continue
      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        # Remove quotes
        value="${value%\"}" && value="${value#\"}"
        value="${value%\'}" && value="${value#\'}"
        # Only export if not already defined
        [[ -z "${!key+x}" ]] && export "$key=$value"
      fi
    done < "$filepath"
  done
}

docker_exec_safe() {
  local container="$1" command="$2"
  local result
  
  if ! docker compose ps -q "$container" >/dev/null 2>&1; then
    echo "ERROR: Container $container not found"
    return 1
  fi
  
  if ! result=$(docker compose exec -T "$container" sh -c "$command" 2>&1); then
    echo "ERROR: Command failed: $result"
    return 1
  fi
  
  echo "$result"
  return 0
}

http_check() {
  local url="$1" expected_status="${2:-200}" headers="${3:-}"
  local cmd="curl -skL --connect-timeout 5 --max-time 10"
  
  # Add headers if provided
  [[ -n "$headers" ]] && cmd="$cmd $headers"
  
  # Add URL resolution for local domains
  if [[ "$url" == *"dev.localhost"* ]]; then
    cmd="$cmd --resolve dev.localhost:443:127.0.0.1 --resolve dev.localhost:80:127.0.0.1"
  fi
  
  cmd="$cmd -w '%{http_code}' -o /dev/null '$url'"
  
  local status
  if status=$(eval "$cmd" 2>/dev/null); then
    echo "$status"
    return 0
  else
    echo "0"
    return 1
  fi
}

# =============================================================================
# CONFIGURATION DETECTION FUNCTIONS
# =============================================================================

check_redis_security() {
  log_section "Redis Security Configuration"
  
  # GIVEN: A Redis instance that may have authentication configured
  local redis_password="${REDIS_PASSWORD:-}"
  
  if [[ -z "$redis_password" ]]; then
    # WHEN: No password is configured
    # THEN: Redis should be accessible without authentication
    local result
    if result=$(docker_exec_safe "kv" "redis-cli ping"); then
      if [[ "$result" == "PONG" ]]; then
        record_result "DISABLED" "Redis Authentication" "No password configured - open access" "docker exec kv redis-cli ping"
      else
        record_result "BROKEN" "Redis Authentication" "No password set but ping failed: $result" "docker exec kv redis-cli ping"
      fi
    else
      record_result "BROKEN" "Redis Authentication" "Cannot connect to Redis container" "docker exec kv redis-cli ping"
    fi
  else
    # WHEN: Password is configured
    # THEN: Unauthenticated access should be blocked
    local unauth_result auth_result
    
    unauth_result=$(docker_exec_safe "kv" "redis-cli ping" 2>&1 || echo "FAILED")
    auth_result=$(docker_exec_safe "kv" "redis-cli -a '$redis_password' ping" 2>&1 || echo "FAILED")
    
    if [[ "$unauth_result" == *"NOAUTH"* || "$unauth_result" == *"Authentication required"* ]]; then
      if [[ "$auth_result" == "PONG" ]]; then
        record_result "ENABLED" "Redis Authentication" "Password protection working" "docker exec kv redis-cli -a '\$REDIS_PASSWORD' ping"
      else
        record_result "BROKEN" "Redis Authentication" "Password set but auth failed: $auth_result" "docker exec kv redis-cli -a '\$REDIS_PASSWORD' ping"
      fi
    else
      record_result "BROKEN" "Redis Authentication" "Password set but no auth required: $unauth_result" "docker exec kv redis-cli ping"
    fi
  fi
}

check_qdrant_security() {
  log_section "Qdrant Security Configuration"
  
  # GIVEN: A Qdrant instance that may have API key protection
  local api_key="${QDRANT_API_KEY:-}"
  local base_url="https://vector.${PUBLISH_DOMAIN:-dev.localhost}"
  
  if [[ -z "$api_key" ]]; then
    # WHEN: No API key is configured
    # THEN: Qdrant should be accessible without authentication
    local status
    status=$(http_check "$base_url/collections" 200 "-H 'Accept: application/json'")
    
    if [[ "$status" == "200" ]]; then
      record_result "DISABLED" "Qdrant API Security" "No API key configured - open access" "curl -s $base_url/collections"
    else
      record_result "BROKEN" "Qdrant API Security" "No API key set but access failed (HTTP $status)" "curl -s $base_url/collections"
    fi
  else
    # WHEN: API key is configured
    # THEN: Unauthenticated access should be blocked, authenticated should work
    local unauth_status auth_status
    
    unauth_status=$(http_check "$base_url/collections" 401 "-H 'Accept: application/json'")
    auth_status=$(http_check "$base_url/collections" 200 "-H 'Accept: application/json' -H 'api-key: $api_key'")
    
    if [[ "$unauth_status" =~ ^(401|403)$ ]] && [[ "$auth_status" == "200" ]]; then
      record_result "ENABLED" "Qdrant API Security" "API key protection working" "curl -s -H 'api-key: \$QDRANT_API_KEY' $base_url/collections"
    elif [[ "$unauth_status" == "200" ]]; then
      record_result "BROKEN" "Qdrant API Security" "API key set but no protection active" "curl -s $base_url/collections"
    else
      record_result "BROKEN" "Qdrant API Security" "API key auth failed (unauth: $unauth_status, auth: $auth_status)" "curl -s -H 'api-key: \$QDRANT_API_KEY' $base_url/collections"
    fi
  fi
}

check_memgraph_security() {
  log_section "Memgraph Security Configuration"
  
  # GIVEN: A Memgraph instance that may have authentication configured
  local user="${MEMGRAPH_USER:-}" password="${MEMGRAPH_PASSWORD:-}"
  
  if [[ -z "$user" || -z "$password" ]]; then
    # WHEN: No credentials are configured
    # THEN: Memgraph should be accessible without authentication
    local result
    if result=$(docker_exec_safe "graph" "echo 'RETURN 1;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false"); then
      if [[ "$result" == *"1"* ]]; then
        record_result "DISABLED" "Memgraph Authentication" "No credentials configured - open access" "docker exec graph mgconsole --host 127.0.0.1 --port 7687"
      else
        record_result "BROKEN" "Memgraph Authentication" "No credentials set but query failed: $result" "docker exec graph mgconsole --host 127.0.0.1 --port 7687"
      fi
    else
      record_result "BROKEN" "Memgraph Authentication" "Cannot connect to Memgraph container" "docker exec graph mgconsole --host 127.0.0.1 --port 7687"
    fi
  else
    # WHEN: Credentials are configured
    # THEN: Authentication should be working
    local result
    if result=$(docker_exec_safe "graph" "echo 'RETURN 1;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false --username '$user' --password '$password'"); then
      if [[ "$result" == *"1"* ]]; then
        record_result "ENABLED" "Memgraph Authentication" "Credentials working properly" "docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
      else
        record_result "BROKEN" "Memgraph Authentication" "Credentials set but auth failed: $result" "docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
      fi
    else
      record_result "BROKEN" "Memgraph Authentication" "Cannot connect with credentials" "docker exec graph mgconsole --username \$MEMGRAPH_USER --password \$MEMGRAPH_PASSWORD"
    fi
  fi
}

# =============================================================================
# STORAGE VALIDATION FUNCTIONS
# =============================================================================

check_redis_storage() {
  log_section "Redis Storage Analysis"
  
  # GIVEN: Redis used for KV storage and document status
  local password="${REDIS_PASSWORD:-}"
  local auth_flag=""
  [[ -n "$password" ]] && auth_flag="-a '$password'"
  
  # WHEN: We analyze Redis data structures
  local keys_result info_result
  
  if keys_result=$(docker_exec_safe "kv" "redis-cli $auth_flag keys '*'"); then
    local key_count
    key_count=$(echo "$keys_result" | grep -v "^$" | wc -l)
    
    if info_result=$(docker_exec_safe "kv" "redis-cli $auth_flag info keyspace"); then
      record_result "INFO" "Redis Storage State" "Keys: $key_count, Keyspace: ${info_result:-empty}" "docker exec kv redis-cli $auth_flag keys '*'"
    else
      record_result "BROKEN" "Redis Storage State" "Cannot get keyspace info" "docker exec kv redis-cli $auth_flag info keyspace"
    fi
  else
    record_result "BROKEN" "Redis Storage State" "Cannot list keys" "docker exec kv redis-cli $auth_flag keys '*'"
  fi
  
  # Check document status keys specifically
  if doc_keys=$(docker_exec_safe "kv" "redis-cli $auth_flag keys '*doc*' | head -5"); then
    local doc_count
    doc_count=$(echo "$doc_keys" | grep -v "^$" | wc -l)
    record_result "INFO" "Redis Document Status" "Document-related keys: $doc_count" "docker exec kv redis-cli $auth_flag keys '*doc*'"
  fi
}

check_qdrant_storage() {
  log_section "Qdrant Vector Storage Analysis"
  
  # GIVEN: Qdrant used for vector storage
  local api_key="${QDRANT_API_KEY:-}"
  local headers=""
  [[ -n "$api_key" ]] && headers="-H 'api-key: $api_key'"
  
  # WHEN: We analyze Qdrant collections
  local collections_result
  if collections_result=$(docker_exec_safe "vectors" "curl -s $headers http://localhost:6333/collections"); then
    if echo "$collections_result" | jq . >/dev/null 2>&1; then
      local collection_count
      collection_count=$(echo "$collections_result" | jq -r '.result.collections | length' 2>/dev/null || echo "0")
      
      if [[ "$collection_count" -gt 0 ]]; then
        # Get details for first collection
        local first_collection
        first_collection=$(echo "$collections_result" | jq -r '.result.collections[0].name' 2>/dev/null)
        
        if [[ -n "$first_collection" && "$first_collection" != "null" ]]; then
          local collection_info
          if collection_info=$(docker_exec_safe "vectors" "curl -s $headers http://localhost:6333/collections/$first_collection"); then
            local vector_count dimension
            vector_count=$(echo "$collection_info" | jq -r '.result.vectors_count // 0' 2>/dev/null || echo "0")
            dimension=$(echo "$collection_info" | jq -r '.result.config.params.vectors.size // "unknown"' 2>/dev/null || echo "unknown")
            
            record_result "INFO" "Qdrant Collections" "Collections: $collection_count, Vectors: $vector_count, Dimension: $dimension" "docker exec vectors curl -s $headers http://localhost:6333/collections"
          fi
        fi
      else
        record_result "INFO" "Qdrant Collections" "No collections found (new installation)" "docker exec vectors curl -s $headers http://localhost:6333/collections"
      fi
    else
      record_result "BROKEN" "Qdrant Collections" "Invalid JSON response: ${collections_result:0:100}" "docker exec vectors curl -s $headers http://localhost:6333/collections"
    fi
  else
    record_result "BROKEN" "Qdrant Collections" "Cannot query collections" "docker exec vectors curl -s $headers http://localhost:6333/collections"
  fi
}

check_memgraph_storage() {
  log_section "Memgraph Graph Storage Analysis"
  
  # GIVEN: Memgraph used for graph storage
  local user="${MEMGRAPH_USER:-}" password="${MEMGRAPH_PASSWORD:-}"
  local auth_flags=""
  [[ -n "$user" && -n "$password" ]] && auth_flags="--username '$user' --password '$password'"
  
  # WHEN: We analyze graph structure
  local node_result rel_result
  
  if node_result=$(docker_exec_safe "graph" "echo 'MATCH (n) RETURN count(n) as node_count;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags"); then
    local node_count
    node_count=$(echo "$node_result" | grep -o '[0-9]\+' | head -1)
    
    if rel_result=$(docker_exec_safe "graph" "echo 'MATCH ()-[r]->() RETURN count(r) as rel_count;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags"); then
      local rel_count
      rel_count=$(echo "$rel_result" | grep -o '[0-9]\+' | head -1)
      
      record_result "INFO" "Memgraph Graph State" "Nodes: ${node_count:-0}, Relationships: ${rel_count:-0}" "docker exec graph mgconsole $auth_flags"
    fi
  else
    record_result "BROKEN" "Memgraph Graph State" "Cannot query graph statistics" "docker exec graph mgconsole $auth_flags"
  fi
  
  # Check indexes
  if index_result=$(docker_exec_safe "graph" "echo 'SHOW INDEX INFO;' | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false $auth_flags"); then
    local index_count
    index_count=$(echo "$index_result" | grep -c "label+property" || echo "0")
    record_result "INFO" "Memgraph Indexes" "Indexes configured: $index_count" "docker exec graph echo 'SHOW INDEX INFO;' | mgconsole"
  fi
}

# =============================================================================
# SERVICE COMMUNICATION CHECKS
# =============================================================================

check_service_communication() {
  log_section "Inter-Service Communication"
  
  # Test key service connections
  local services=(
    "rag:kv:6379:LightRAG→Redis"
    "rag:vectors:6333:LightRAG→Qdrant"
    "rag:graph:7687:LightRAG→Memgraph"
    "lobechat:rag:9621:LobeChat→LightRAG"
  )
  
  for service_def in "${services[@]}"; do
    IFS=':' read -r from_container to_container port description <<< "$service_def"
    
    # GIVEN: Services that should communicate with each other
    # WHEN: We test network connectivity
    local result
    if result=$(docker_exec_safe "$from_container" "nc -z $to_container $port && echo 'Connected' || echo 'Failed'"); then
      if [[ "$result" == "Connected" ]]; then
        record_result "PASS" "$description" "Network connectivity established" "docker exec $from_container nc -z $to_container $port"
      else
        record_result "FAIL" "$description" "Network connectivity failed" "docker exec $from_container nc -z $to_container $port"
      fi
    else
      record_result "FAIL" "$description" "Cannot test connectivity" "docker exec $from_container nc -z $to_container $port"
    fi
  done
}

check_external_endpoints() {
  log_section "External API Endpoints"
  
  # GIVEN: Services that should be accessible externally
  local domain="${PUBLISH_DOMAIN:-dev.localhost}"
  local endpoints=(
    "https://$domain/health:Main Site Health"
    "https://rag.$domain/health:LightRAG API Health"
    "https://lobechat.$domain/:LobeChat Interface"
    "https://monitor.$domain/:Monitoring Dashboard"
  )
  
  for endpoint_def in "${endpoints[@]}"; do
    IFS=':' read -r url description <<< "$endpoint_def"
    
    # WHEN: We test external accessibility
    local status
    status=$(http_check "$url")
    
    if [[ "$status" =~ ^(200|401|403)$ ]]; then
      record_result "PASS" "$description" "Accessible (HTTP $status)" "curl -I $url"
    else
      record_result "FAIL" "$description" "Not accessible (HTTP $status)" "curl -I $url"
    fi
  done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  printf "%sLightRAG Configuration Verification v2.0%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
  printf "Domain: %s\n" "${PUBLISH_DOMAIN:-dev.localhost}"
  
  # Load environment variables
  load_env_files
  
  # Check if Docker Compose is running
  if ! docker compose ps >/dev/null 2>&1; then
    printf "%sERROR: Docker Compose not running or not accessible%s\n" "${COLOR_RED}" "${COLOR_RESET}"
    exit 1
  fi
  
  # Run all checks
  check_redis_security
  check_qdrant_security
  check_memgraph_security
  check_redis_storage
  check_qdrant_storage
  check_memgraph_storage
  check_service_communication
  check_external_endpoints
  
  # Summary
  log_section "Configuration Summary"
  printf "Total Checks: %d\n" "$TOTAL_CHECKS"
  printf "%s✓ Passed/Enabled: %d%s\n" "${COLOR_GREEN}" "$PASSED_CHECKS" "${COLOR_RESET}"
  printf "%sℹ Info/Disabled: %d%s\n" "${COLOR_BLUE}" "$INFO_CHECKS" "${COLOR_RESET}"
  printf "%s✗ Failed/Broken: %d%s\n" "${COLOR_RED}" "$FAILED_CHECKS" "${COLOR_RESET}"
  
  # Exit with error if any checks failed
  [[ "$FAILED_CHECKS" -eq 0 ]] && exit 0 || exit 1
}

main "$@"

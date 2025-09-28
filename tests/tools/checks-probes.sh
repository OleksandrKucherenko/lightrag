#!/usr/bin/env bash
# =============================================================================
# Service Probes for LightRAG Check Scripts
# =============================================================================
# Service-specific probe functions for common operations
# =============================================================================

set -Eeuo pipefail

# Source the action framework
source "${BASH_SOURCE[0]%/*}/action-framework.sh"

# =============================================================================
# DOCKER COMPOSE PROBES
# =============================================================================

# probe_docker_service_running - Check if a docker compose service is running
# Args: service_name
# Returns: 0 if running, 1 if not
probe_docker_service_running() {
    local service_name="$1"
    docker compose ps -q "$service_name" >/dev/null 2>&1
}

# probe_docker_exec - Execute command in docker container with proper error handling
# Args: service_name, command...
# Returns: command output or error message
probe_docker_exec() {
    local service_name="$1"
    shift
    docker compose exec -T "$service_name" "$@" 2>&1 || echo "EXEC_FAILED"
}

# =============================================================================
# REDIS PROBES
# =============================================================================

# probe_redis_ping - Test Redis connectivity
# Args: service_name (optional, defaults to 'kv')
# Returns: PONG on success, error message on failure
probe_redis_ping() {
    local service_name="${1:-kv}"
    local auth_flag=""

    if [[ -n "${REDIS_PASSWORD:-}" ]]; then
        auth_flag="-a \"$REDIS_PASSWORD\""
    fi

    probe_docker_exec "$service_name" sh -c "redis-cli $auth_flag ping" 2>/dev/null || echo "PING_FAILED"
}

# probe_redis_keys - Get Redis keys matching pattern
# Args: pattern (optional, defaults to '*'), service_name (optional, defaults to 'kv')
# Returns: list of keys or error message
probe_redis_keys() {
    local pattern="${1:-*}"
    local service_name="${2:-kv}"
    local auth_flag=""

    if [[ -n "${REDIS_PASSWORD:-}" ]]; then
        auth_flag="-a \"$REDIS_PASSWORD\""
    fi

    probe_docker_exec "$service_name" sh -c "redis-cli $auth_flag keys '$pattern'" 2>/dev/null || echo "KEYS_FAILED"
}

# =============================================================================
# QDRANT PROBES
# =============================================================================

# probe_qdrant_collections - Get Qdrant collections
# Args: service_name (optional, defaults to 'vector-db')
# Returns: JSON response or error message
probe_qdrant_collections() {
    local service_name="${1:-vectors}"
    local api_key="${2:-${QDRANT_API_KEY:-}}"

    local curl_cmd="docker run --rm --network container:$service_name alpine/curl:latest curl -s"
    if [[ -n "$api_key" ]]; then
        curl_cmd="$curl_cmd -H 'api-key: $api_key'"
    fi
    curl_cmd="$curl_cmd http://localhost:6333/collections"

    eval "$curl_cmd" 2>/dev/null || echo "COLLECTIONS_FAILED"
}

# =============================================================================
# MEMGRAPH PROBES
# =============================================================================

# probe_memgraph_query - Execute Cypher query on Memgraph
# Args: query, service_name (optional, defaults to 'graph')
# Returns: query result or error message
probe_memgraph_query() {
    local query="$1"
    local service_name="${2:-graph}"

    probe_docker_exec "$service_name" mgconsole -c "$query" 2>/dev/null || echo "QUERY_FAILED"
}

# =============================================================================
# HTTP/SSL PROBES
# =============================================================================

# probe_http_endpoint - Test HTTP endpoint accessibility
# Args: url
# Returns: HTTP status code or error message
probe_http_endpoint() {
    local url="$1"

    curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "HTTP_FAILED"
}

# probe_ssl_certificate - Check SSL certificate
# Args: host, port (optional, defaults to 443)
# Returns: certificate info or error message
probe_ssl_certificate() {
    local host="$1"
    local port="${2:-443}"

    echo | openssl s_client -connect "${host}:${port}" -servername "$host" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_FAILED"
}

# =============================================================================
# ENVIRONMENT PROBES
# =============================================================================

# probe_env_file_exists - Check if environment file exists and is readable
# Args: filename (without .env prefix)
# Returns: 0 if exists and readable, 1 if not
probe_env_file_exists() {
    local filename="$1"
    local filepath="${REPO_ROOT}/.env${filename:+.$filename}"

    [[ -f "$filepath" && -r "$filepath" ]]
}

# probe_host_ip - Detect host IP address
# Returns: detected IP address or error message
probe_host_ip() {
    # Try multiple methods to detect host IP
    local ip

    # Method 1: Check for WSL2
    if [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        # WSL2: Get Windows host IP
        ip=$(ip route | grep default | awk '{print $3}' | head -1) || ip=""
    fi

    # Method 2: Try hostname -I (Linux)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}') || ip=""
    fi

    # Method 3: Try ip route
    if [[ -z "$ip" ]]; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}') || ip=""
    fi

    # Method 4: Fallback to localhost
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi

    echo "$ip"
}
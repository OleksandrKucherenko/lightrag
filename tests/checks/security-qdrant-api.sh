#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Qdrant API Security Check
# =============================================================================
# 
# GIVEN: A Qdrant instance that may have API key protection
# WHEN: We test API access with and without authentication
# THEN: We determine if API security is ENABLED, DISABLED, or BROKEN
# =============================================================================

# Load environment
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
CURL_HELPER_IMAGE="${CURL_HELPER_IMAGE:-alpine/curl:latest}"

# Check if Qdrant container is running
if ! docker compose ps -q vectors >/dev/null 2>&1; then
    printf '%s\n' "BROKEN|qdrant_api|Qdrant container not found|docker compose ps vectors"
    exit 0
fi

# Pull helper image if needed so docker run doesn't flood output with progress
if ! docker image inspect "$CURL_HELPER_IMAGE" >/dev/null 2>&1; then
    if ! docker pull --quiet "$CURL_HELPER_IMAGE" >/dev/null 2>&1; then
        printf '%s\n' "BROKEN|qdrant_api|Unable to pull helper image $CURL_HELPER_IMAGE|docker pull $CURL_HELPER_IMAGE"
        exit 0
    fi
fi

base_url="http://localhost:6333"
helper_cmd="docker run --rm --network container:vectors $CURL_HELPER_IMAGE"

trim_whitespace() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

run_helper_for_status() {
    local __code_var="$1"
    local __error_var="$2"
    shift 2

    local output
    if output=$(docker run --rm --network container:vectors "$CURL_HELPER_IMAGE" -sS -o /dev/null -w '%{http_code}' --connect-timeout "$CURL_TIMEOUT" "$@" 2>&1); then
        printf -v "$__code_var" '%s' "$output"
        printf -v "$__error_var" '%s' ""
        return 0
    else
        output=$(trim_whitespace "$output")
        printf -v "$__code_var" '%s' "000"
        printf -v "$__error_var" '%s' "$output"
        return 1
    fi
}

if [[ -z "$QDRANT_API_KEY" ]]; then
    # WHEN: No API key is configured
    # THEN: Qdrant should be accessible without authentication (DISABLED state)
    
    if result=$(docker run --rm --network container:vectors "$CURL_HELPER_IMAGE" -sS --connect-timeout "$CURL_TIMEOUT" "$base_url/collections" 2>&1); then
        if echo "$result" | jq . >/dev/null 2>&1; then
            printf '%s\n' "DISABLED|qdrant_api|No API key configured - open access|$helper_cmd -s --connect-timeout $CURL_TIMEOUT ${base_url}/collections"
        else
            preview="${result:0:80}"
            printf '%s\n' "BROKEN|qdrant_api|No API key set but invalid response: ${preview}|$helper_cmd -s --connect-timeout $CURL_TIMEOUT ${base_url}/collections"
        fi
    else
        error_message=$(trim_whitespace "$result")
        if [[ -z "$error_message" ]]; then
            error_message="Unable to reach Qdrant"
        fi
        printf '%s\n' "BROKEN|qdrant_api|Cannot connect to Qdrant: ${error_message}|$helper_cmd -s --connect-timeout $CURL_TIMEOUT ${base_url}/collections"
    fi
else
    # WHEN: API key is configured
    # THEN: Test both unauthenticated (should fail) and authenticated (should work)
    
    unauth_code=""
    unauth_error=""
    run_helper_for_status unauth_code unauth_error "$base_url/collections" || true

    auth_code=""
    auth_error=""
    run_helper_for_status auth_code auth_error -H "api-key: ${QDRANT_API_KEY}" "$base_url/collections" || true

    if [[ "$unauth_code" =~ ^(401|403)$ ]] && [[ "$auth_code" == "200" ]]; then
        printf '%s\n' "ENABLED|qdrant_api|API key protection working|$helper_cmd -s -o /dev/null -w '%{http_code}' --connect-timeout $CURL_TIMEOUT -H 'api-key: \$QDRANT_API_KEY' ${base_url}/collections"
    elif [[ "$unauth_code" == "200" ]]; then
        printf '%s\n' "BROKEN|qdrant_api|API key set but no protection active|$helper_cmd -s --connect-timeout $CURL_TIMEOUT ${base_url}/collections"
    else
        details="unauth=${unauth_code}"
        [[ -n "$unauth_error" ]] && details+=" (${unauth_error})"
        details+="; auth=${auth_code}"
        [[ -n "$auth_error" ]] && details+=" (${auth_error})"
        printf '%s\n' "BROKEN|qdrant_api|API key auth failed (${details})|$helper_cmd -s -o /dev/null -w '%{http_code}' --connect-timeout $CURL_TIMEOUT -H 'api-key: \$QDRANT_API_KEY' ${base_url}/collections"
    fi
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Configuration Check
# =============================================================================
#
# GIVEN: LightRAG and LobeChat services need proper CORS configuration
# WHEN: We inspect the CORS_ORIGINS and service mode configuration
# THEN: We verify CORS is properly configured to allow cross-origin requests
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment variables
if [[ -f "${REPO_ROOT}/.env" ]]; then
    set +e  # Temporarily disable exit on error for sourcing
    source "${REPO_ROOT}/.env" 2>/dev/null || true
    set -e  # Re-enable exit on error
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check LightRAG CORS configuration
if [[ -f "${REPO_ROOT}/.env.lightrag" ]]; then
    if grep -q "^CORS_ORIGINS=" "${REPO_ROOT}/.env.lightrag"; then
        CORS_ORIGINS=$(grep "^CORS_ORIGINS=" "${REPO_ROOT}/.env.lightrag" | cut -d'=' -f2- | tr -d '"')
        # Expand variables for checking
        EXPANDED_CORS="${CORS_ORIGINS//\$\{PUBLISH_DOMAIN\}/$PUBLISH_DOMAIN}"
        
        if [[ "$EXPANDED_CORS" == *"https://lobechat.$PUBLISH_DOMAIN"* ]] || [[ "$EXPANDED_CORS" == *"https://chat.$PUBLISH_DOMAIN"* ]]; then
            echo "PASS|lightrag_cors_origins|CORS origins configured with LobeChat domain|grep CORS_ORIGINS .env.lightrag"
        else
            echo "FAIL|lightrag_cors_origins|LobeChat origin missing from CORS configuration|grep CORS_ORIGINS .env.lightrag"
        fi
    else
        echo "FAIL|lightrag_cors_origins|CORS_ORIGINS not configured in LightRAG|grep CORS_ORIGINS .env.lightrag"
    fi
else
    echo "BROKEN|lightrag_cors_origins|LightRAG environment file not found|ls .env.lightrag"
fi

# Check LobeChat service mode
if [[ -f "${REPO_ROOT}/.env.lobechat" ]]; then
    if grep -q "^NEXT_PUBLIC_SERVICE_MODE=server" "${REPO_ROOT}/.env.lobechat"; then
        echo "PASS|lobechat_service_mode|Server mode enabled (avoids browser CORS)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
    else
        echo "INFO|lobechat_service_mode|Server mode not enabled (using client-side requests)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
    fi
else
    echo "BROKEN|lobechat_service_mode|LobeChat environment file not found|ls .env.lobechat"
fi

# Check OpenAI proxy URL configuration
if [[ -f "${REPO_ROOT}/.env.lobechat" ]]; then
    if grep -q "^OPENAI_PROXY_URL=" "${REPO_ROOT}/.env.lobechat"; then
        PROXY_URL=$(grep "^OPENAI_PROXY_URL=" "${REPO_ROOT}/.env.lobechat" | cut -d'=' -f2- | tr -d '"')
        
        if [[ "$PROXY_URL" == "http://rag:9621" ]]; then
            echo "PASS|lobechat_proxy_url|Correct internal Ollama-compatible base URL|grep OPENAI_PROXY_URL .env.lobechat"
        elif [[ "$PROXY_URL" == "https://api.\${PUBLISH_DOMAIN}" ]]; then
            echo "PASS|lobechat_proxy_url|Correct external Ollama-compatible base URL template|grep OPENAI_PROXY_URL .env.lobechat"
        elif [[ "$PROXY_URL" == *"/api" ]] || [[ "$PROXY_URL" == *"/v1" ]]; then
            echo "FAIL|lobechat_proxy_url|Proxy URL has incorrect path suffix (Ollama base URL should have no path)|grep OPENAI_PROXY_URL .env.lobechat"
        else
            echo "INFO|lobechat_proxy_url|Proxy URL configured: $PROXY_URL|grep OPENAI_PROXY_URL .env.lobechat"
        fi
    else
        echo "FAIL|lobechat_proxy_url|OPENAI_PROXY_URL not configured|grep OPENAI_PROXY_URL .env.lobechat"
    fi
else
    echo "BROKEN|lobechat_proxy_url|LobeChat environment file not found|ls .env.lobechat"
fi

# Check if LightRAG has CORS disabled comment (domain-based approach)
if [[ -f "${REPO_ROOT}/.env.lightrag" ]]; then
    if grep -q "^# CORS.*not needed" "${REPO_ROOT}/.env.lightrag"; then
        echo "INFO|lightrag_cors_disabled|CORS disabled (domain-based approach)|grep '# CORS.*not needed' .env.lightrag"
    else
        echo "INFO|lightrag_cors_status|CORS configuration status unclear|grep CORS .env.lightrag"
    fi
else
    echo "BROKEN|lightrag_cors_status|LightRAG environment file not found|ls .env.lightrag"
fi

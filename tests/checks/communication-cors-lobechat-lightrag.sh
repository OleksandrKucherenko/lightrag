#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LobeChat ↔ LightRAG CORS Alignment Check
# =============================================================================
#
# GIVEN: LobeChat should talk to LightRAG through the internal proxy without
#        triggering browser-side CORS or mixed-content failures.
# WHEN:  We validate the configuration artifacts that coordinate origins and
#        proxy routing.
# THEN:  We confirm both services declare compatible origins and routing mode.
# =============================================================================

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-}"
if [[ -z "$PUBLISH_DOMAIN" && -f .env ]]; then
    PUBLISH_DOMAIN=$(grep -E '^PUBLISH_DOMAIN=' .env | tail -1 | cut -d'=' -f2-)
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

env_value() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        grep -E "^${key}=" "$file" | tail -1 | cut -d'=' -f2-
    fi
}

cors_origins=$(env_value .env.lightrag "CORS_ORIGINS")
expanded_cors_origins="${cors_origins//\$\{PUBLISH_DOMAIN\}/$PUBLISH_DOMAIN}"
expected_origin="https://lobechat.${PUBLISH_DOMAIN}"
if [[ -z "$cors_origins" ]]; then
    echo "FAIL|cors_alignment|CORS_ORIGINS missing from .env.lightrag|grep '^CORS_ORIGINS' .env.lightrag"
elif [[ "$expanded_cors_origins" == *"https://lobechat.${PUBLISH_DOMAIN}"* ]]; then
    echo "PASS|cors_alignment|LightRAG allows origin $expected_origin|grep '^CORS_ORIGINS' .env.lightrag"
else
    echo "FAIL|cors_alignment|LightRAG CORS_ORIGINS missing $expected_origin|grep '^CORS_ORIGINS' .env.lightrag"
fi

service_mode=$(env_value .env.lobechat "NEXT_PUBLIC_SERVICE_MODE")
if [[ "$service_mode" == "server" ]]; then
    echo "PASS|cors_alignment|LobeChat forces server mode for API proxying|grep '^NEXT_PUBLIC_SERVICE_MODE' .env.lobechat"
else
    echo "FAIL|cors_alignment|NEXT_PUBLIC_SERVICE_MODE should be 'server' to avoid browser CORS|grep '^NEXT_PUBLIC_SERVICE_MODE' .env.lobechat"
fi

proxy_url=$(env_value .env.lobechat "OPENAI_PROXY_URL")
if [[ "$proxy_url" == "http://rag:9621/v1" ]]; then
    echo "PASS|cors_alignment|LobeChat OpenAI proxy points at internal LightRAG service|grep '^OPENAI_PROXY_URL' .env.lobechat"
else
    echo "FAIL|cors_alignment|OPENAI_PROXY_URL should be http://rag:9621/v1 for internal proxying|grep '^OPENAI_PROXY_URL' .env.lobechat"
fi

if grep -Fq 'OPENAI_API_KEY=${LIGHTRAG_API_KEY}' docker-compose.yaml; then
    echo "PASS|cors_alignment|Docker Compose maps LIGHTRAG_API_KEY into LobeChat OpenAI credentials|grep 'OPENAI_API_KEY=\${LIGHTRAG_API_KEY}' docker-compose.yaml"
else
    echo "FAIL|cors_alignment|Docker Compose should pass LIGHTRAG_API_KEY to LobeChat as OPENAI_API_KEY|grep 'OPENAI_API_KEY' docker-compose.yaml"
fi

if grep -Fq 'OPENAI_PROXY_URL=http://rag:9621/v1' docker-compose.yaml; then
    echo "PASS|cors_alignment|Docker Compose enforces internal LightRAG proxy URL for LobeChat|grep 'OPENAI_PROXY_URL=http://rag:9621/v1' docker-compose.yaml"
else
    echo "FAIL|cors_alignment|Docker Compose should set OPENAI_PROXY_URL=http://rag:9621/v1 for LobeChat|grep 'OPENAI_PROXY_URL' docker-compose.yaml"
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Configuration Fix Verification Script
# =============================================================================
# This script verifies that the CORS configuration changes resolve the
# preflight redirect issue between LobeChat and LightRAG.
# =============================================================================

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "🔍 Verifying CORS Configuration Fix..."
echo "======================================"

# Load environment variables
if [[ -f .env ]]; then
    source .env
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

echo "📋 Configuration Check:"
echo "----------------------"

# Check LightRAG CORS configuration
echo "1. LightRAG CORS_ORIGINS:"
if grep -q "^CORS_ORIGINS=" .env.lightrag; then
    CORS_ORIGINS=$(grep "^CORS_ORIGINS=" .env.lightrag | cut -d'=' -f2- | tr -d '"')
    echo "   ✅ Configured: $CORS_ORIGINS"
    
    # Expand variables
    EXPANDED_CORS="${CORS_ORIGINS//\$\{PUBLISH_DOMAIN\}/$PUBLISH_DOMAIN}"
    echo "   📝 Expanded: $EXPANDED_CORS"
    
    if [[ "$EXPANDED_CORS" == *"https://lobechat.$PUBLISH_DOMAIN"* ]]; then
        echo "   ✅ LobeChat origin allowed"
    else
        echo "   ❌ LobeChat origin missing"
    fi
else
    echo "   ❌ CORS_ORIGINS not configured"
fi

# Check LobeChat service mode
echo ""
echo "2. LobeChat Service Mode:"
if grep -q "^NEXT_PUBLIC_SERVICE_MODE=server" .env.lobechat; then
    echo "   ✅ Server mode enabled (avoids browser CORS)"
else
    echo "   ❌ Server mode not enabled"
fi

# Check OpenAI proxy URL
echo ""
echo "3. LobeChat OpenAI Proxy:"
if grep -q "^OPENAI_PROXY_URL=" .env.lobechat; then
    PROXY_URL=$(grep "^OPENAI_PROXY_URL=" .env.lobechat | cut -d'=' -f2-)
    echo "   ✅ Configured: $PROXY_URL"
    
    if [[ "$PROXY_URL" == "http://rag:9621/v1" ]]; then
        echo "   ✅ Correct internal URL with /v1 endpoint"
    else
        echo "   ⚠️  URL should be http://rag:9621/v1"
    fi
else
    echo "   ❌ OPENAI_PROXY_URL not configured"
fi

echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Restart the services to apply configuration changes:"
echo "   docker-compose restart rag lobechat"
echo ""
echo "2. Test the connection:"
echo "   # Wait for services to be ready"
echo "   sleep 30"
echo ""
echo "   # Test LightRAG API directly"
echo "   curl -H 'Origin: https://lobechat.$PUBLISH_DOMAIN' \\"
echo "        -H 'Access-Control-Request-Method: GET' \\"
echo "        -H 'Access-Control-Request-Headers: content-type' \\"
echo "        -X OPTIONS https://rag.$PUBLISH_DOMAIN/api/tags"
echo ""
echo "3. Check browser console for CORS errors after restart"
echo ""
echo "🐛 Troubleshooting:"
echo "=================="
echo "If CORS errors persist:"
echo "- Check docker logs: docker-compose logs rag lobechat"
echo "- Verify services are running: docker-compose ps"
echo "- Test internal connectivity: docker-compose exec lobechat curl http://rag:9621/health"

# WSL2 specific verification for Windows hosts
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    echo ""
    echo "🪟 WSL2 Windows Host Verification:"
    echo "================================="
    echo "# On Windows host (CMD/PowerShell):"
    echo "curl -H \"Origin: https://lobechat.$PUBLISH_DOMAIN\" ^"
    echo "     -H \"Access-Control-Request-Method: GET\" ^"
    echo "     -H \"Access-Control-Request-Headers: content-type\" ^"
    echo "     -X OPTIONS https://rag.$PUBLISH_DOMAIN/api/tags"
    echo ""
    echo "# PowerShell alternative:"
    echo "Invoke-WebRequest -Uri \"https://rag.$PUBLISH_DOMAIN/api/tags\" \\"
    echo "                  -Method OPTIONS \\"
    echo "                  -Headers @{"
    echo "                      'Origin' = 'https://lobechat.$PUBLISH_DOMAIN'"
    echo "                      'Access-Control-Request-Method' = 'GET'"
    echo "                      'Access-Control-Request-Headers' = 'content-type'"
    echo "                  }"
fi

echo ""
echo "✅ CORS configuration verification complete!"

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# CORS Duplicate Headers Fix Test
# =============================================================================
# This script tests the corrected CORS configuration to ensure no duplicate
# headers are being sent.
# =============================================================================

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# Load environment variables
if [[ -f .env ]]; then
    source .env
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

echo "🔍 Testing CORS Fix for Duplicate Headers..."
echo "============================================"

echo "📋 Configuration:"
echo "   Chat URL: https://chat.$PUBLISH_DOMAIN"
echo "   API URL:  https://api.$PUBLISH_DOMAIN"
echo ""

echo "🧪 Testing CORS Preflight Request:"
echo "-----------------------------------"

# Test the preflight request that was failing
echo "Testing OPTIONS request to /api/chat..."
RESPONSE=$(curl -s -k -i \
    -H "Origin: https://chat.$PUBLISH_DOMAIN" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type,authorization" \
    -X OPTIONS \
    "https://api.$PUBLISH_DOMAIN/api/chat" 2>&1 || echo "CURL_ERROR")

if [[ "$RESPONSE" == "CURL_ERROR" ]]; then
    echo "❌ Failed to connect to API endpoint"
    echo "   Make sure services are running: docker-compose ps"
    exit 1
fi

echo "📊 Response Headers:"
echo "$RESPONSE" | grep -i "access-control" || echo "   No CORS headers found"

# Check for duplicate headers
DUPLICATE_ORIGIN=$(echo "$RESPONSE" | grep -i "access-control-allow-origin" | wc -l)
if [[ $DUPLICATE_ORIGIN -gt 1 ]]; then
    echo "❌ DUPLICATE Access-Control-Allow-Origin headers detected!"
    echo "$RESPONSE" | grep -i "access-control-allow-origin"
else
    echo "✅ No duplicate Access-Control-Allow-Origin headers"
fi

# Check if the origin is correctly set
if echo "$RESPONSE" | grep -q "Access-Control-Allow-Origin.*https://chat.$PUBLISH_DOMAIN"; then
    echo "✅ Correct origin allowed: https://chat.$PUBLISH_DOMAIN"
else
    echo "⚠️  Origin header check:"
    echo "$RESPONSE" | grep -i "access-control-allow-origin" || echo "   No origin header found"
fi

echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. If you see duplicate headers, restart the services:"
echo "   docker-compose restart rag"
echo ""
echo "2. Clear browser cache and try again"
echo ""
echo "3. Check the browser developer tools Network tab for the actual request"
echo ""
echo "4. If issues persist, check LightRAG logs:"
echo "   docker-compose logs rag"

echo ""
echo "✅ CORS duplicate headers test complete!"

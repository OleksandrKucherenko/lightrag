#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Advanced Domain-Based Setup Verification Script
# =============================================================================
# This script verifies the advanced subdomain configuration that eliminates
# CORS issues by serving all services under the same domain with different
# subdomains, following LobeHub's recommended approach.
# =============================================================================

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "🌐 Verifying Advanced Domain-Based Setup..."
echo "==========================================="

# Load environment variables
if [[ -f .env ]]; then
    source .env
fi
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

echo "📋 Domain Configuration:"
echo "------------------------"
echo "Base Domain: $PUBLISH_DOMAIN"
echo ""

# Define expected subdomains
declare -A SUBDOMAINS=(
    ["chat"]="LobeChat Frontend"
    ["api"]="LightRAG API"
    ["rag"]="LightRAG Admin"
    ["graph"]="Memgraph Lab"
    ["vector"]="Qdrant Dashboard"
    ["kv"]="Redis"
    ["monitor"]="Docker Monitor"
)

echo "🔍 Expected Service Subdomains:"
echo "-------------------------------"
for subdomain in "${!SUBDOMAINS[@]}"; do
    echo "   https://$subdomain.$PUBLISH_DOMAIN - ${SUBDOMAINS[$subdomain]}"
done
echo ""

echo "📝 Configuration Verification:"
echo "------------------------------"

# Check LobeChat configuration
echo "1. LobeChat Domain Configuration:"
if grep -q "OPENAI_PROXY_URL=https://api.\${PUBLISH_DOMAIN}/v1" .env.lobechat; then
    echo "   ✅ Using domain-based API URL (eliminates CORS)"
    echo "   📍 API URL: https://api.$PUBLISH_DOMAIN/v1"
else
    echo "   ❌ Not using domain-based API URL"
fi

if grep -q "^# NEXT_PUBLIC_SERVICE_MODE=server" .env.lobechat; then
    echo "   ✅ Server mode disabled (not needed with domain approach)"
else
    echo "   ⚠️  Server mode configuration unclear"
fi

# Check LightRAG configuration
echo ""
echo "2. LightRAG Domain Configuration:"
if grep -q "^# CORS.*not needed" .env.lightrag; then
    echo "   ✅ CORS disabled (not needed with domain approach)"
else
    echo "   ⚠️  CORS configuration unclear"
fi

# Check Docker Compose subdomain routing
echo ""
echo "3. Docker Compose Subdomain Routing:"
if grep -q 'caddy: "https://chat.${PUBLISH_DOMAIN}"' docker-compose.yaml; then
    echo "   ✅ LobeChat configured for chat.$PUBLISH_DOMAIN"
else
    echo "   ❌ LobeChat subdomain not configured"
fi

if grep -q 'caddy_1: "https://api.${PUBLISH_DOMAIN}"' docker-compose.yaml; then
    echo "   ✅ LightRAG API configured for api.$PUBLISH_DOMAIN"
else
    echo "   ❌ LightRAG API subdomain not configured"
fi

# Check SSL certificates
echo ""
echo "4. SSL Certificate Configuration:"
if [[ -f "docker/certificates/dev.localhost.pem" ]]; then
    echo "   ✅ Wildcard SSL certificate found"
    
    # Check certificate validity
    if command -v openssl >/dev/null 2>&1; then
        CERT_DOMAINS=$(openssl x509 -in docker/certificates/dev.localhost.pem -text -noout | grep -A1 "Subject Alternative Name" | tail -1 || echo "")
        if [[ "$CERT_DOMAINS" == *"*.$PUBLISH_DOMAIN"* ]]; then
            echo "   ✅ Certificate covers wildcard subdomains"
        else
            echo "   ⚠️  Certificate may not cover all subdomains"
        fi
    fi
else
    echo "   ❌ SSL certificate not found"
fi

echo ""
echo "🔧 Setup Instructions:"
echo "======================"
echo "1. Update your hosts file to include all subdomains:"
echo "   # Add these entries to /etc/hosts (Linux/WSL) or C:\\Windows\\System32\\drivers\\etc\\hosts (Windows)"
echo "   127.0.0.1 $PUBLISH_DOMAIN"
for subdomain in "${!SUBDOMAINS[@]}"; do
    echo "   127.0.0.1 $subdomain.$PUBLISH_DOMAIN"
done

echo ""
echo "2. Restart services to apply configuration:"
echo "   docker-compose down"
echo "   docker-compose up -d"
echo ""

echo "3. Wait for services to be ready (30-60 seconds):"
echo "   docker-compose ps"
echo ""

echo "4. Test the domain-based setup:"
echo "   # Main LobeChat interface"
echo "   curl -k https://chat.$PUBLISH_DOMAIN"
echo ""
echo "   # LightRAG API endpoint (should not have CORS issues)"
echo "   curl -k https://api.$PUBLISH_DOMAIN/health"
echo ""
echo "   # Test API from LobeChat domain (no CORS needed)"
echo "   curl -k -H 'Origin: https://chat.$PUBLISH_DOMAIN' https://api.$PUBLISH_DOMAIN/v1/models"

echo ""
echo "🌐 Access URLs:"
echo "==============="
echo "   LobeChat:        https://chat.$PUBLISH_DOMAIN"
echo "   LightRAG API:    https://api.$PUBLISH_DOMAIN"
echo "   LightRAG Admin:  https://rag.$PUBLISH_DOMAIN"
echo "   Graph Database:  https://graph.$PUBLISH_DOMAIN"
echo "   Vector Database: https://vector.$PUBLISH_DOMAIN"
echo "   Docker Monitor:  https://monitor.$PUBLISH_DOMAIN"

echo ""
echo "🐛 Troubleshooting:"
echo "=================="
echo "If you still see CORS errors:"
echo "1. Clear browser cache and cookies"
echo "2. Check browser developer tools for mixed content warnings"
echo "3. Verify all services are using HTTPS (not HTTP)"
echo "4. Check docker logs: docker-compose logs rag lobechat"
echo "5. Verify hosts file entries are correct"

# WSL2 specific instructions
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    echo ""
    echo "🪟 WSL2 Windows Host Setup:"
    echo "=========================="
    echo "1. Update Windows hosts file (as Administrator):"
    echo "   notepad C:\\Windows\\System32\\drivers\\etc\\hosts"
    echo ""
    echo "2. Add these entries:"
    echo "   127.0.0.1 $PUBLISH_DOMAIN"
    for subdomain in "${!SUBDOMAINS[@]}"; do
        echo "   127.0.0.1 $subdomain.$PUBLISH_DOMAIN"
    done
    echo ""
    echo "3. Test from Windows PowerShell:"
    echo "   Invoke-WebRequest -Uri \"https://chat.$PUBLISH_DOMAIN\" -SkipCertificateCheck"
fi

echo ""
echo "✅ Domain-based setup verification complete!"
echo ""
echo "🎯 Benefits of this approach:"
echo "   • Eliminates CORS issues entirely"
echo "   • Follows LobeHub best practices"
echo "   • Cleaner URL structure"
echo "   • Better security isolation"
echo "   • Easier to scale to production"

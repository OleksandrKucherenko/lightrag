#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LobeChat Debug Logs Monitor
# =============================================================================
# This script helps monitor LobeChat debug logs and provides various
# debugging utilities for troubleshooting CORS and API issues.
# =============================================================================

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "🔍 LobeChat Debug Logs Monitor"
echo "=============================="

# Check if LobeChat container is running
if ! docker-compose ps lobechat | grep -q "Up"; then
    echo "❌ LobeChat container is not running!"
    echo "   Start it with: docker-compose up -d lobechat"
    exit 1
fi

echo "📋 Debug Configuration Status:"
echo "------------------------------"

# Check current log level
if grep -q "LOG_LEVEL=debug" .env.lobechat; then
    echo "✅ LOG_LEVEL set to debug"
else
    echo "❌ LOG_LEVEL not set to debug"
    echo "   Current: $(grep LOG_LEVEL .env.lobechat || echo 'not set')"
fi

# Check debug environment
if grep -q "DEBUG=\*" .env.lobechat; then
    echo "✅ DEBUG environment enabled"
else
    echo "⚠️  DEBUG environment not enabled"
fi

if grep -q "NODE_ENV=development" .env.lobechat; then
    echo "✅ NODE_ENV set to development"
else
    echo "⚠️  NODE_ENV not set to development"
fi

echo ""
echo "🔧 Debug Commands:"
echo "=================="

echo "1. View live LobeChat logs:"
echo "   docker-compose logs -f lobechat"
echo ""

echo "2. View recent LobeChat logs (last 100 lines):"
echo "   docker-compose logs --tail=100 lobechat"
echo ""

echo "3. Filter for error logs only:"
echo "   docker-compose logs lobechat | grep -i error"
echo ""

echo "4. Filter for CORS-related logs:"
echo "   docker-compose logs lobechat | grep -i cors"
echo ""

echo "5. Filter for API request logs:"
echo "   docker-compose logs lobechat | grep -i 'api\\|request\\|fetch'"
echo ""

echo "6. View browser console logs (open in browser):"
echo "   https://chat.dev.localhost (F12 -> Console tab)"
echo ""

echo "7. Monitor network requests (open in browser):"
echo "   https://chat.dev.localhost (F12 -> Network tab)"
echo ""

# Interactive menu
echo "🎛️  Interactive Options:"
echo "======================="
echo "Choose an option:"
echo "1) View live logs"
echo "2) View recent logs" 
echo "3) Filter error logs"
echo "4) Filter CORS logs"
echo "5) Filter API logs"
echo "6) Restart LobeChat with debug"
echo "7) Exit"

read -p "Enter your choice (1-7): " choice

case $choice in
    1)
        echo "📺 Showing live LobeChat logs (Ctrl+C to exit)..."
        docker-compose logs -f lobechat
        ;;
    2)
        echo "📄 Recent LobeChat logs:"
        docker-compose logs --tail=100 lobechat
        ;;
    3)
        echo "🚨 Error logs:"
        docker-compose logs lobechat | grep -i error || echo "No error logs found"
        ;;
    4)
        echo "🌐 CORS-related logs:"
        docker-compose logs lobechat | grep -i cors || echo "No CORS logs found"
        ;;
    5)
        echo "🔗 API request logs:"
        docker-compose logs lobechat | grep -i -E 'api|request|fetch' || echo "No API logs found"
        ;;
    6)
        echo "🔄 Restarting LobeChat with debug configuration..."
        docker-compose restart lobechat
        echo "✅ LobeChat restarted. Waiting for startup..."
        sleep 10
        echo "📺 Showing startup logs:"
        docker-compose logs --tail=50 lobechat
        ;;
    7)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "💡 Tips for debugging:"
echo "====================="
echo "• Check browser developer tools (F12) for client-side errors"
echo "• Look for CORS errors in the Network tab"
echo "• Check the Console tab for JavaScript errors"
echo "• Monitor failed API requests in the Network tab"
echo "• Use 'Preserve log' option in browser dev tools"
echo ""
echo "🔧 Common debug scenarios:"
echo "========================="
echo "• CORS errors: Check Origin and Access-Control headers"
echo "• API failures: Look for 4xx/5xx status codes"
echo "• Network issues: Check if requests reach the server"
echo "• Authentication: Look for 401/403 errors"

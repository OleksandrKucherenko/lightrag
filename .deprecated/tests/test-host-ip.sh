#!/usr/bin/env bash
# Test script for get-host-ip.sh helper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🧪 Testing HOST_IP detection helper..."
echo

# Test the helper
HOST_IP=$(bin/get-host-ip.sh)

echo "📍 Detected HOST_IP: $HOST_IP"

# Validate IP format
if [[ "$HOST_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✅ Valid IP format"
else
    echo "❌ Invalid IP format"
    exit 1
fi

# Show environment info
echo
echo "🖥️  Environment info:"
echo "   OS: $(uname -s)"
echo "   Kernel: $(uname -r)"

if [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null; then
    echo "   WSL2: Yes"
    echo "   PowerShell available: $(command -v powershell.exe >/dev/null && echo "Yes" || echo "No")"
    echo "   Docker available: $(command -v docker >/dev/null && echo "Yes" || echo "No")"
else
    echo "   WSL2: No"
fi

echo
echo "🔧 Testing template preprocessing with detected IP..."

# Test template preprocessing
export HOST_IP
export PUBLISH_DOMAIN="test.example"

TEMP=$(mktemp)
trap "rm -f $TEMP" EXIT

envsubst < .etchosts > "$TEMP"

echo "📝 Sample preprocessed output:"
head -3 "$TEMP" | grep -v "^#" | grep -v "^$"

echo
echo "✅ HOST_IP helper working correctly!"

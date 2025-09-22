#!/usr/bin/env bash
# Update Windows hosts file from WSL2 using PowerShell and hostctl
# Assumes: sudo and hostctl are installed on Windows via scoop

set -euo pipefail

cd "$(dirname "$0")/.."

# Check if we're in WSL2
if [[ ! -f "/proc/version" ]] || ! grep -q "microsoft" "/proc/version" 2>/dev/null; then
    echo "❌ This script is designed for WSL2 environment only"
    echo "   For native Linux/macOS, use: bin/hosts-update.sh"
    exit 1
fi

# Check if PowerShell is available
if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "❌ PowerShell not found. This script requires WSL2 with Windows PowerShell access."
    exit 1
fi

# Load environment and detect IP using helper
source .env  # Required for standalone script
export HOST_IP=$(bin/get-host-ip.sh)
export PUBLISH_DOMAIN=${PUBLISH_DOMAIN:-dev.localhost}

# Preprocess .etchosts → temporary file
TEMP=$(mktemp)
trap "rm -f $TEMP" EXIT
envsubst < .etchosts > "$TEMP"

# Convert WSL path to Windows path
WINDOWS_TEMP=$(wslpath -w "$TEMP")

echo "🌐 Updating Windows hosts file for domain: $PUBLISH_DOMAIN (IP: $HOST_IP)"
echo "📁 Using temporary file: $WINDOWS_TEMP"

# Execute hostctl on Windows via PowerShell
if powershell.exe -Command "sudo hostctl replace lightrag --from '$WINDOWS_TEMP'"; then
    echo "✅ Windows hosts file updated successfully!"
    echo "🌐 All services now accessible at *.$PUBLISH_DOMAIN from Windows"
    
    # Show status
    echo
    echo "📋 Current Windows hostctl profile:"
    powershell.exe -Command "hostctl list lightrag" 2>/dev/null || echo "   (Could not display profile status)"
else
    echo "❌ Failed to update Windows hosts file"
    echo "   Make sure 'sudo' and 'hostctl' are installed on Windows via scoop:"
    echo "   scoop install main/sudo main/hostctl"
    exit 1
fi

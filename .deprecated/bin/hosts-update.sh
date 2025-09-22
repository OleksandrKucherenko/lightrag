#!/usr/bin/env bash
# Simple hostctl wrapper with .etchosts preprocessing
set -euo pipefail

cd "$(dirname "$0")/.."

# Load environment and detect IP using helper
source .env  # Required for standalone script (MISE tasks auto-load .env)
export HOST_IP=$(bin/get-host-ip.sh)
export PUBLISH_DOMAIN=${PUBLISH_DOMAIN:-dev.localhost}

# Preprocess .etchosts → temporary file → hostctl
TEMP=$(mktemp)
trap "rm -f $TEMP" EXIT
envsubst < .etchosts > "$TEMP"

echo "🌐 Updating hosts for domain: $PUBLISH_DOMAIN (IP: $HOST_IP)"
sudo hostctl replace lightrag --from "$TEMP"
echo "✅ Done! Services accessible at *.$PUBLISH_DOMAIN"

#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Host IP Detection Check
# =============================================================================
# 
# GIVEN: A host IP detection script for different environments (Linux/macOS/WSL2)
# WHEN: We test IP detection functionality
# THEN: We verify IP detection works correctly for the current environment
# =============================================================================

# Check if get-host-ip.sh script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOST_IP_SCRIPT="${REPO_ROOT}/bin/get-host-ip.sh"

if [[ ! -f "$HOST_IP_SCRIPT" ]]; then
    echo "BROKEN|host_ip_detection|get-host-ip.sh script not found|ls $HOST_IP_SCRIPT"
    exit 0
fi

if [[ ! -x "$HOST_IP_SCRIPT" ]]; then
    echo "BROKEN|host_ip_detection|get-host-ip.sh script not executable|chmod +x $HOST_IP_SCRIPT"
    exit 0
fi

# WHEN: We test IP detection
if detected_ip=$("$HOST_IP_SCRIPT" 2>&1); then
    # THEN: Validate IP format
    if [[ "$detected_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Determine environment type
        if [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null; then
            env_type="WSL2"
        else
            env_type="Native $(uname -s)"
        fi
        
        echo "PASS|host_ip_detection|IP detection working: $detected_ip ($env_type)|$HOST_IP_SCRIPT"
    else
        echo "FAIL|host_ip_detection|Invalid IP format detected: $detected_ip|$HOST_IP_SCRIPT"
    fi
else
    echo "BROKEN|host_ip_detection|IP detection script failed: ${detected_ip:0:50}|$HOST_IP_SCRIPT"
fi

# WHEN: We test template preprocessing with detected IP
if [[ -f "${REPO_ROOT}/.etchosts" ]]; then
    export HOST_IP="$detected_ip"
    export PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
    
    if preprocessed=$(envsubst < "${REPO_ROOT}/.etchosts" 2>&1); then
        # Check if preprocessing worked (should contain actual IP, not variables)
        if echo "$preprocessed" | grep -q "$detected_ip" && ! echo "$preprocessed" | grep -q '\$HOST_IP'; then
            echo "PASS|host_ip_detection|Template preprocessing working with detected IP|envsubst < .etchosts"
        else
            echo "FAIL|host_ip_detection|Template preprocessing failed - variables not substituted|envsubst < .etchosts"
        fi
    else
        echo "BROKEN|host_ip_detection|Template preprocessing failed: ${preprocessed:0:50}|envsubst < .etchosts"
    fi
else
    echo "INFO|host_ip_detection|.etchosts template not found - skipping preprocessing test|ls .etchosts"
fi

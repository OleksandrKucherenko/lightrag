#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 System Integration Check
# =============================================================================
# 
# GIVEN: WSL2 environment with Windows system integration
# WHEN: We test WSL2 system integration features
# THEN: We verify WSL2 is properly integrated with Windows
# =============================================================================

# Check if we're actually in WSL2
if [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null; then
    if grep -q "WSL2" "/proc/version" 2>/dev/null; then
        echo "PASS|wsl2_detection|Running in WSL2 environment|cat /proc/version"
    else
        echo "INFO|wsl2_detection|Running in WSL1 environment|cat /proc/version"
    fi
else
    echo "INFO|wsl2_detection|Not running in WSL environment|cat /proc/version"
    exit 0
fi

# Check if Windows executables are accessible
if command -v cmd.exe >/dev/null 2>&1; then
    echo "PASS|wsl2_integration|Windows CMD accessible from WSL2|which cmd.exe"
else
    echo "FAIL|wsl2_integration|Windows CMD not accessible from WSL2|which cmd.exe"
fi

if command -v powershell.exe >/dev/null 2>&1; then
    echo "PASS|wsl2_integration|Windows PowerShell accessible from WSL2|which powershell.exe"
else
    echo "FAIL|wsl2_integration|Windows PowerShell not accessible from WSL2|which powershell.exe"
fi

# Check if wslpath utility is available
if command -v wslpath >/dev/null 2>&1; then
    # Test path conversion
    if windows_path=$(wslpath -w "/tmp" 2>/dev/null); then
        echo "PASS|wsl2_integration|Path conversion working: /tmp -> $windows_path|wslpath -w /tmp"
    else
        echo "FAIL|wsl2_integration|Path conversion not working|wslpath -w /tmp"
    fi
else
    echo "BROKEN|wsl2_integration|wslpath utility not available|which wslpath"
fi

# Check Windows drives mounting
if [[ -d "/mnt/c" ]]; then
    echo "PASS|wsl2_integration|Windows C: drive mounted at /mnt/c|ls -la /mnt/c"
else
    echo "FAIL|wsl2_integration|Windows C: drive not mounted|ls -la /mnt/c"
fi

# Check if Windows PATH is integrated
if echo "$PATH" | grep -q "/mnt/c/Windows"; then
    echo "PASS|wsl2_integration|Windows PATH integrated into WSL2|echo \$PATH | grep Windows"
else
    echo "INFO|wsl2_integration|Windows PATH not integrated (may be intentional)|echo \$PATH | grep Windows"
fi

# Check systemd integration (if available)
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --version >/dev/null 2>&1; then
        echo "PASS|wsl2_integration|systemd available in WSL2|systemctl --version"
    else
        echo "INFO|wsl2_integration|systemd present but not functional|systemctl --version"
    fi
else
    echo "INFO|wsl2_integration|systemd not available (normal for older WSL2)|which systemctl"
fi

# Test subdomain resolution from WSL2
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
subdomains=("rag" "lobechat" "vector" "monitor")

for subdomain in "${subdomains[@]}"; do
    full_domain="${subdomain}.${DOMAIN}"
    
    # Test DNS resolution
    if nslookup "$full_domain" >/dev/null 2>&1; then
        echo "PASS|wsl2_subdomain|Subdomain resolves from WSL2: $full_domain|nslookup $full_domain"
    else
        echo "FAIL|wsl2_subdomain|Subdomain resolution failed from WSL2: $full_domain|nslookup $full_domain"
    fi
    
    # Test connectivity
    if curl -I -s -k --connect-timeout 3 "https://$full_domain" >/dev/null 2>&1; then
        echo "PASS|wsl2_subdomain|Subdomain accessible from WSL2: $full_domain|curl -I https://$full_domain"
    else
        echo "FAIL|wsl2_subdomain|Subdomain not accessible from WSL2: $full_domain|curl -I https://$full_domain"
    fi
done

# Check if WSL2 can access Windows localhost on different ports
windows_ports=("80" "443" "3000" "8080")
for port in "${windows_ports[@]}"; do
    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
        echo "PASS|wsl2_network|Windows localhost:$port accessible from WSL2|nc -z 127.0.0.1 $port"
    else
        echo "INFO|wsl2_network|Windows localhost:$port not accessible from WSL2 (may be unused)|nc -z 127.0.0.1 $port"
    fi
done

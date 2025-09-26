#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Root CA Integration Check
# =============================================================================
# 
# GIVEN: WSL2 environment with self-signed certificates that need Windows trust
# WHEN: We test root CA integration between WSL2 and Windows
# THEN: We verify certificates work across both environments
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check if we're in WSL2
if [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null; then
    if grep -q "WSL2" "/proc/version" 2>/dev/null; then
        echo "PASS|rootca_integration|Running in WSL2 environment|cat /proc/version"
    else
        echo "INFO|rootca_integration|Running in WSL1 environment|cat /proc/version"
    fi
else
    echo "INFO|rootca_integration|Not running in WSL environment - skipping Windows integration|cat /proc/version"
    exit 0
fi

# Check if PowerShell is available for Windows certificate checking
if command -v powershell.exe >/dev/null 2>&1; then
    echo "PASS|rootca_integration|PowerShell available for Windows certificate checking|which powershell.exe"
    
    # Run the PowerShell certificate check
    ps_script="${SCRIPT_DIR}/wsl2-windows-rootca.ps1"
    if [[ -f "$ps_script" ]]; then
        echo "INFO|rootca_integration|Running Windows certificate validation via PowerShell|powershell.exe -ExecutionPolicy Bypass -File $ps_script"
        
        # Convert WSL path to Windows path and run the PowerShell script
        if windows_path=$(wslpath -w "$ps_script" 2>/dev/null); then
            # Note: The PowerShell script output will be handled by the orchestrator
            echo "INFO|rootca_integration|Windows certificate check delegated to PowerShell script|powershell.exe -ExecutionPolicy Bypass -File $windows_path"
        else
            echo "BROKEN|rootca_integration|Cannot convert WSL path to Windows path for PowerShell script|wslpath -w $ps_script"
        fi
    else
        echo "BROKEN|rootca_integration|PowerShell certificate check script not found|ls $ps_script"
    fi
else
    echo "FAIL|rootca_integration|PowerShell not available for Windows certificate checking|which powershell.exe"
fi

# Check WSL2 certificate files
ssl_dir="${REPO_ROOT}/docker/ssl"
cert_file="${ssl_dir}/${DOMAIN}.pem"
key_file="${ssl_dir}/${DOMAIN}-key.pem"
rootca_file="${ssl_dir}/rootCA.pem"

if [[ -f "$rootca_file" ]]; then
    # Check if root CA is valid
    if openssl x509 -in "$rootca_file" -text -noout >/dev/null 2>&1; then
        ca_subject=$(openssl x509 -in "$rootca_file" -subject -noout 2>/dev/null | sed 's/subject=//')
        echo "PASS|rootca_integration|WSL2 root CA certificate valid: $ca_subject|openssl x509 -in $rootca_file -subject -noout"
        
        # Check if certificate is signed by this CA
        if [[ -f "$cert_file" ]]; then
            if openssl verify -CAfile "$rootca_file" "$cert_file" >/dev/null 2>&1; then
                echo "PASS|rootca_integration|Domain certificate signed by WSL2 root CA|openssl verify -CAfile $rootca_file $cert_file"
            else
                echo "FAIL|rootca_integration|Domain certificate not signed by WSL2 root CA|openssl verify -CAfile $rootca_file $cert_file"
            fi
        fi
    else
        echo "BROKEN|rootca_integration|WSL2 root CA certificate invalid or corrupted|openssl x509 -in $rootca_file -text -noout"
    fi
else
    echo "FAIL|rootca_integration|WSL2 root CA certificate not found: $rootca_file|ls $rootca_file"
fi

# Check if mkcert is available in WSL2
if command -v mkcert >/dev/null 2>&1; then
    mkcert_version=$(mkcert -version 2>/dev/null || echo "unknown")
    echo "PASS|rootca_integration|mkcert available in WSL2: $mkcert_version|mkcert -version"
    
    # Check mkcert CAROOT in WSL2
    if caroot=$(mkcert -CAROOT 2>/dev/null); then
        if [[ -d "$caroot" ]]; then
            echo "PASS|rootca_integration|mkcert CAROOT configured in WSL2: $caroot|mkcert -CAROOT"
            
            # Check if CAROOT contains certificates
            if [[ -f "$caroot/rootCA.pem" ]]; then
                echo "PASS|rootca_integration|mkcert root CA exists in WSL2 CAROOT|ls $caroot/rootCA.pem"
            else
                echo "FAIL|rootca_integration|mkcert root CA missing from WSL2 CAROOT|ls $caroot/rootCA.pem"
            fi
        else
            echo "FAIL|rootca_integration|mkcert CAROOT directory not found: $caroot|ls $caroot"
        fi
    else
        echo "FAIL|rootca_integration|Cannot get mkcert CAROOT in WSL2|mkcert -CAROOT"
    fi
else
    echo "FAIL|rootca_integration|mkcert not available in WSL2|which mkcert"
fi

# Test certificate accessibility from WSL2
if [[ -f "$cert_file" ]]; then
    # Test local SSL connectivity from WSL2
    if curl -s -k --connect-timeout 5 "https://$DOMAIN" >/dev/null 2>&1; then
        echo "PASS|rootca_integration|Local SSL connectivity working from WSL2: https://$DOMAIN|curl -I -k https://$DOMAIN"
    else
        echo "FAIL|rootca_integration|Local SSL connectivity failed from WSL2: https://$DOMAIN|curl -I -k https://$DOMAIN"
    fi
    
    # Test subdomain connectivity
    subdomains=("rag" "lobechat" "vector" "monitor")
    for subdomain in "${subdomains[@]}"; do
        subdomain_url="https://${subdomain}.${DOMAIN}"
        if curl -s -k --connect-timeout 3 "$subdomain_url" >/dev/null 2>&1; then
            echo "PASS|rootca_integration|Subdomain SSL connectivity working from WSL2: $subdomain_url|curl -I -k $subdomain_url"
        else
            echo "INFO|rootca_integration|Subdomain SSL connectivity failed from WSL2: $subdomain_url (may be service unavailable)|curl -I -k $subdomain_url"
        fi
    done
fi

# Provide instructions for manual certificate installation if needed
echo "INFO|rootca_integration|To install root CA on Windows: Import-Certificate -FilePath docker/ssl/rootCA.cer -CertStoreLocation Cert:\LocalMachine\Root|Import-Certificate -FilePath docker/ssl/rootCA.cer -CertStoreLocation Cert:\LocalMachine\Root"
echo "INFO|rootca_integration|Alternative: Use 'mkcert -install' on Windows to install mkcert root CA|mkcert -install"

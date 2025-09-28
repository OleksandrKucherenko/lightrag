# =============================================================================
# WSL2 Subdomain Integration Check (PowerShell)
# =============================================================================
# 
# GIVEN: WSL2 environment with subdomain routing for LightRAG services
# WHEN: We test subdomain accessibility from Windows host
# THEN: We verify subdomain integration is working properly
# =============================================================================

# Get domain from environment or use default
$domain = $env:PUBLISH_DOMAIN
if (-not $domain) {
    $domain = "dev.localhost"
}

# Define subdomains to test
$subdomains = @(
    @{Name="rag"; Description="LightRAG API"},
    @{Name="lobechat"; Description="LobeChat Interface"},
    @{Name="vector"; Description="Qdrant Vector API"},
    @{Name="monitor"; Description="Monitoring Dashboard"}
)

# Test each subdomain
foreach ($subdomain in $subdomains) {
    $url = "https://$($subdomain.Name).$domain"
    $description = $subdomain.Description
    
    try {
        # Test DNS resolution first
        $resolved = Resolve-DnsName "$($subdomain.Name).$domain" -ErrorAction SilentlyContinue
        if ($resolved) {
            $ipAddresses = ($resolved | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress) -join ' '
            if (-not $ipAddresses) {
                $ipAddresses = ($resolved | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue) -join ' '
            }
            Write-Output "PASS|subdomain_dns|$description DNS resolves: $($subdomain.Name).$domain -> $ipAddresses|nslookup $($subdomain.Name).$domain"
        } else {
            Write-Output "FAIL|subdomain_dns|$description DNS resolution failed: $($subdomain.Name).$domain|nslookup $($subdomain.Name).$domain"
            continue
        }
        
        # Test HTTP connectivity
        $response = Invoke-WebRequest -Uri $url -Method HEAD -TimeoutSec 5 -SkipCertificateCheck -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Output "PASS|subdomain_http|$description accessible via HTTPS: $url (HTTP $($response.StatusCode))|curl -I $url"
        } elseif ($response.StatusCode -in @(401, 403)) {
            Write-Output "PASS|subdomain_http|$description accessible with auth required: $url (HTTP $($response.StatusCode))|curl -I $url"
        } else {
            Write-Output "FAIL|subdomain_http|$description unexpected status: $url (HTTP $($response.StatusCode))|curl -I $url"
        }
    } catch {
        # Try with curl as fallback
        try {
            $curlResult = & curl.exe -I -s -k --connect-timeout 5 $url 2>$null
            $statusMatch = [regex]::Match($curlResult, "HTTP/\d(?:\.\d)?\s+(\d+)")

            if ($statusMatch.Success) {
                $statusCode = $statusMatch.Groups[1].Value

                switch ($statusCode) {
                    "200" { Write-Output "PASS|subdomain_http|$description accessible via curl: $url (HTTP $statusCode)|curl -I $url" }
                    "401" { Write-Output "PASS|subdomain_http|$description accessible with auth required: $url (HTTP $statusCode)|curl -I $url" }
                    "403" { Write-Output "PASS|subdomain_http|$description accessible with auth required: $url (HTTP $statusCode)|curl -I $url" }
                    "405" { Write-Output "PASS|subdomain_http|$description reachable but HEAD not allowed: $url (HTTP $statusCode)|curl -I $url" }
                    "404" { Write-Output "PASS|subdomain_http|$description reachable but resource not found: $url (HTTP $statusCode)|curl -I $url" }
                    Default { Write-Output "FAIL|subdomain_http|$description unexpected status via curl: $url (HTTP $statusCode)|curl -I $url" }
                }
            } else {
                Write-Output "FAIL|subdomain_http|$description not accessible: $url|curl -I $url"
            }
        } catch {
            Write-Output "FAIL|subdomain_http|$description connection failed: $url - $($_.Exception.Message)|curl -I $url"
        }
    }
}

# Test wildcard certificate support
try {
    $certCheck = & openssl.exe s_client -connect "rag.$domain:443" -servername "rag.$domain" -verify_return_error 2>$null | Select-String "Verify return code"
    if ($certCheck -match "Verify return code: 0") {
        Write-Output "PASS|subdomain_ssl|Wildcard SSL certificate valid for subdomains|openssl s_client -connect rag.$domain:443"
    } else {
        Write-Output "INFO|subdomain_ssl|SSL certificate verification issues (expected for dev)|openssl s_client -connect rag.$domain:443"
    }
} catch {
    Write-Output "INFO|subdomain_ssl|Cannot verify SSL certificates - openssl not available|openssl s_client -connect rag.$domain:443"
}

# Test subdomain routing from Windows hosts file
try {
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
    
    $domainEntries = $hostsContent | Where-Object { $_ -match $domain.Replace(".", "\.") }
    if ($domainEntries.Count -gt 0) {
        $subdomainCount = ($domainEntries | Where-Object { $_ -match "\w+\.$($domain.Replace('.', '\.'))" }).Count
        if ($subdomainCount -gt 0) {
            Write-Output "PASS|subdomain_hosts|Windows hosts file contains $subdomainCount subdomain entries for $domain|type $hostsFile | findstr $domain"
        } else {
            Write-Output "INFO|subdomain_hosts|Windows hosts file has main domain but no subdomains for $domain|type $hostsFile | findstr $domain"
        }
    } else {
        Write-Output "INFO|subdomain_hosts|No entries found in Windows hosts file for $domain|type $hostsFile | findstr $domain"
    }
} catch {
    Write-Output "INFO|subdomain_hosts|Cannot read Windows hosts file: $($_.Exception.Message)|type C:\Windows\System32\drivers\etc\hosts"
}

# =============================================================================
# WSL2 Windows Root CA Certificate Check (PowerShell)
# =============================================================================
# 
# GIVEN: WSL2 environment with self-signed certificates for development
# WHEN: We test Windows host machine root CA certificate registration
# THEN: We verify SSL certificates are trusted by Windows system
# =============================================================================

# Get domain from environment or use default
$domain = $env:PUBLISH_DOMAIN
if (-not $domain) {
    $domain = "dev.localhost"
}

# Check if we're running from WSL2 (this script should be called from WSL2)
if ($env:WSL_DISTRO_NAME -or $env:WSLENV) {
    Write-Output "INFO|windows_rootca|Running from WSL2 environment: $env:WSL_DISTRO_NAME|echo `$WSL_DISTRO_NAME"
} else {
    Write-Output "INFO|windows_rootca|Running directly on Windows (not from WSL2)|echo `$env:COMPUTERNAME"
}

# Function to check certificate in Windows certificate store
function Test-CertificateInStore {
    param(
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$Subject
    )
    
    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        
        $certificates = $store.Certificates | Where-Object { $_.Subject -like "*$Subject*" }
        $store.Close()
        
        return $certificates.Count -gt 0, $certificates.Count
    } catch {
        return $false, 0
    }
}

# Check for mkcert root CA in Windows certificate store
$mkcertSubjects = @("mkcert", "mkcert development CA", "mkcert root CA")
$foundMkcertCA = $false
$mkcertDetails = ""

foreach ($subject in $mkcertSubjects) {
    $found, $count = Test-CertificateInStore "Root" "LocalMachine" $subject
    if ($found) {
        $foundMkcertCA = $true
        $mkcertDetails = "$subject ($count certificates)"
        break
    }
    
    # Also check CurrentUser store
    $found, $count = Test-CertificateInStore "Root" "CurrentUser" $subject
    if ($found) {
        $foundMkcertCA = $true
        $mkcertDetails = "$subject in CurrentUser store ($count certificates)"
        break
    }
}

if ($foundMkcertCA) {
    Write-Output "PASS|windows_rootca|mkcert root CA found in Windows certificate store: $mkcertDetails|Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*mkcert*'"
} else {
    Write-Output "FAIL|windows_rootca|mkcert root CA not found in Windows certificate store|Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*mkcert*'"
}

# Check for specific domain certificate in Personal store
$found, $count = Test-CertificateInStore "My" "LocalMachine" $domain
if ($found) {
    Write-Output "PASS|windows_rootca|Domain certificate found in Windows Personal store: $domain ($count certificates)|Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like '*$domain*'"
} else {
    # Check CurrentUser Personal store
    $found, $count = Test-CertificateInStore "My" "CurrentUser" $domain
    if ($found) {
        Write-Output "INFO|windows_rootca|Domain certificate found in CurrentUser Personal store: $domain ($count certificates)|Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -like '*$domain*'"
    } else {
        Write-Output "INFO|windows_rootca|Domain certificate not found in Windows certificate stores: $domain|Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like '*$domain*'"
    }
}

# Test SSL validation for the domain
try {
    $url = "https://$domain"
    $request = [System.Net.WebRequest]::Create($url)
    $request.Timeout = 5000
    
    # This will throw an exception if SSL validation fails
    $response = $request.GetResponse()
    $statusCode = [int]$response.StatusCode
    $response.Close()
    
    Write-Output "PASS|windows_rootca|SSL validation successful for $url (HTTP $statusCode)|Invoke-WebRequest -Uri $url"
} catch [System.Net.WebException] {
    $exception = $_.Exception
    if ($exception.Message -like "*SSL*" -or $exception.Message -like "*certificate*" -or $exception.Message -like "*trust*") {
        Write-Output "FAIL|windows_rootca|SSL validation failed for $url - certificate not trusted - $($exception.Message)|Invoke-WebRequest -Uri $url"
    } else {
        Write-Output "INFO|windows_rootca|Connection failed for $url (may be service unavailable) - $($exception.Message)|Invoke-WebRequest -Uri $url"
    }
} catch {
    Write-Output "INFO|windows_rootca|SSL test failed for $url - $($_.Exception.Message)|Invoke-WebRequest -Uri $url"
}

# Check if mkcert command is available on Windows
try {
    $mkcertVersion = & mkcert -version 2>$null
    if ($mkcertVersion) {
        Write-Output "PASS|windows_rootca|mkcert tool available on Windows: $mkcertVersion|mkcert -version"
        
        # Check mkcert CAROOT
        try {
            $caroot = & mkcert -CAROOT 2>$null
            if ($caroot -and (Test-Path $caroot)) {
                Write-Output "PASS|windows_rootca|mkcert CAROOT configured: $caroot|mkcert -CAROOT"
                
                # Check if rootCA files exist in CAROOT
                $rootCAPem = Join-Path $caroot "rootCA.pem"
                $rootCAKey = Join-Path $caroot "rootCA-key.pem"
                
                if ((Test-Path $rootCAPem) -and (Test-Path $rootCAKey)) {
                    Write-Output "PASS|windows_rootca|mkcert root CA files exist in CAROOT|ls `"$caroot`""
                } else {
                    Write-Output "FAIL|windows_rootca|mkcert root CA files missing from CAROOT: $caroot|ls `"$caroot`""
                }
            } else {
                Write-Output "FAIL|windows_rootca|mkcert CAROOT not configured or inaccessible: $caroot|mkcert -CAROOT"
            }
        } catch {
            Write-Output "FAIL|windows_rootca|Cannot get mkcert CAROOT - $($_.Exception.Message)|mkcert -CAROOT"
        }
    } else {
        Write-Output "INFO|windows_rootca|mkcert command available but version check failed|mkcert -version"
    }
} catch {
    Write-Output "FAIL|windows_rootca|mkcert tool not available on Windows PATH|where mkcert"
}

# Check Windows certificate store permissions
try {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    $certCount = $store.Certificates.Count
    $store.Close()
    
    Write-Output "INFO|windows_rootca|Windows Root certificate store accessible: $certCount certificates|Get-ChildItem Cert:\LocalMachine\Root | Measure-Object"
} catch {
    Write-Output "FAIL|windows_rootca|Cannot access Windows Root certificate store - $($_.Exception.Message)|Get-ChildItem Cert:\LocalMachine\Root"
}

# Test certificate validation for subdomains
$subdomains = @("rag", "lobechat", "vector", "monitor")
foreach ($subdomain in $subdomains) {
    $subdomainUrl = "https://$subdomain.$domain"
    
    try {
        # Use .NET WebRequest for certificate validation
        $request = [System.Net.WebRequest]::Create($subdomainUrl)
        $request.Timeout = 3000
        $response = $request.GetResponse()
        $statusCode = [int]$response.StatusCode
        $response.Close()
        
        Write-Output "PASS|windows_rootca|Subdomain SSL validation successful - $subdomainUrl (HTTP $statusCode)|Invoke-WebRequest -Uri $subdomainUrl"
    } catch [System.Net.WebException] {
        $exception = $_.Exception
        if ($exception.Message -like "*SSL*" -or $exception.Message -like "*certificate*") {
            Write-Output "FAIL|windows_rootca|Subdomain SSL validation failed - $subdomainUrl - $($exception.Message)|Invoke-WebRequest -Uri $subdomainUrl"
        } else {
            Write-Output "INFO|windows_rootca|Subdomain connection failed - $subdomainUrl (may be service unavailable)|Invoke-WebRequest -Uri $subdomainUrl"
        }
    } catch {
        Write-Output "INFO|windows_rootca|Subdomain SSL test error - $subdomainUrl - $($_.Exception.Message)|Invoke-WebRequest -Uri $subdomainUrl"
    }
}

# =============================================================================
# WSL2 Windows Root CA Certificate Check (PowerShell)
# =============================================================================
#
# GIVEN: WSL2 environment with optional Windows-based TLS integration
# WHEN: We inspect Windows certificate stores and tooling
# THEN: We report whether mkcert certificates are available and usable
# =============================================================================

$ErrorActionPreference = "Stop"
$script:checkName = "windows_rootca"

function Write-Result {
    param(
        [string]$Status,
        [string]$Message,
        [string]$Command
    )

    Write-Output ("{0}|{1}|{2}|{3}" -f $Status, $script:checkName, $Message, $Command)
}

$script:enforceWindowsTrust = $true

function Publish {
    param(
        [string]$Status,
        [string]$Message,
        [string]$Command
    )

    if ($Status -eq "FAIL" -and -not $script:enforceWindowsTrust) {
        Write-Result "INFO" $Message $Command
    } else {
        Write-Result $Status $Message $Command
    }
}

function Configure-Enforcement {
    $enforceEnv = $env:WINDOWS_ROOTCA_ENFORCE
    if ($null -ne $enforceEnv) {
        switch ($enforceEnv) {
            "0" { $script:enforceWindowsTrust = $false }
            "1" { $script:enforceWindowsTrust = $true }
        }
    }
}

function Resolve-RepositoryRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $testsDir = Split-Path -Parent $scriptDir
    return (Split-Path -Parent $testsDir)
}

function Resolve-RootCaPath {
    if ($env:WINDOWS_ROOTCA_PATH) {
        return $env:WINDOWS_ROOTCA_PATH
    }

    $repoRoot = Resolve-RepositoryRoot
    if (-not $repoRoot) {
        return $null
    }

    $defaultCer = Join-Path $repoRoot "docker\ssl\rootCA.cer"
    if (Test-Path $defaultCer) {
        return $defaultCer
    }

    return $null
}

function Test-CertificateInStore {
    param(
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$Subject
    )

    $result = [PSCustomObject]@{
        Found = $false
        Count = 0
        Error = $null
    }

    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation)
        try {
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            $matches = $store.Certificates | Where-Object { $_.Subject -like "*$Subject*" }
            if ($matches) {
                $result.Found = $matches.Count -gt 0
                $result.Count = $matches.Count
            }
        } finally {
            $store.Close()
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

function Test-CertificateByThumbprint {
    param(
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$Thumbprint
    )

    $normalizedThumbprint = $Thumbprint -replace "\s", ""
    $normalizedThumbprint = $normalizedThumbprint.ToUpperInvariant()

    $result = [PSCustomObject]@{
        Found = $false
        Count = 0
        Error = $null
    }

    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation)
        try {
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            $matches = $store.Certificates | Where-Object { ($_.Thumbprint -replace "\s", "").ToUpperInvariant() -eq $normalizedThumbprint }
            if ($matches) {
                $result.Found = $matches.Count -gt 0
                $result.Count = $matches.Count
            }
        } finally {
            $store.Close()
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

function Test-SslEndpoint {
    param(
        [string]$Url,
        [string]$Label
    )

    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $statusCode = 0
        if ($response -is [System.Net.HttpWebResponse]) {
            $statusCode = [int]$response.StatusCode
        }
        $response.Close()
        Publish "PASS" "$Label SSL validation successful for $Url (HTTP $statusCode)" "Invoke-WebRequest -Uri $Url"
    } catch [System.Net.WebException] {
        $message = $_.Exception.Message
        if ($message -match "SSL" -or $message -match "certificate" -or $message -match "trust") {
            Publish "FAIL" "$Label SSL validation failed for $Url`: $message" "Invoke-WebRequest -Uri $Url"
        } else {
            Publish "INFO" "$Label connection failed for $Url`: $message" "Invoke-WebRequest -Uri $Url"
        }
    } catch {
        $message = $_.Exception.Message
        Publish "INFO" "$Label SSL test error for $Url`: $message" "Invoke-WebRequest -Uri $Url"
    }
}

try {
    Configure-Enforcement

    $domain = $env:PUBLISH_DOMAIN
    if ([string]::IsNullOrWhiteSpace($domain)) {
        $domain = "dev.localhost"
    }

    $fromWsl = [bool]($env:WSL_DISTRO_NAME -or $env:WSLENV)
    if ($fromWsl) {
        Publish "INFO" "Running from WSL2 environment`: $($env:WSL_DISTRO_NAME)" "echo `$WSL_DISTRO_NAME"
    } else {
        Publish "INFO" "Running directly on Windows host`: $env:COMPUTERNAME" "echo `$env:COMPUTERNAME"
    }

    $expectedImportCommand = "sudo Import-Certificate -FilePath rootCA.cer -CertStoreLocation Cert:\LocalMachine\Root"

    $rootCaPath = Resolve-RootCaPath
    if (-not $rootCaPath) {
        Publish "BROKEN" "rootCA certificate file not found. Ensure rootCA.cer exists under docker\ssl and import it." $expectedImportCommand
        return
    }

    if (-not (Test-Path $rootCaPath)) {
        Publish "BROKEN" "root CA certificate file missing at $rootCaPath" $expectedImportCommand
        return
    }

    try {
        Add-Type -AssemblyName System.Security
    } catch {
        Publish "BROKEN" "System.Security assembly unavailable`: $($_.Exception.Message)" "Add-Type -AssemblyName System.Security"
        return
    }

    try {
        $rootCaCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($rootCaPath)
    } catch {
        Publish "BROKEN" "Unable to load root CA certificate from $rootCaPath`: $($_.Exception.Message)" $expectedImportCommand
        return
    }

    $rootCaThumbprint = ($rootCaCert.Thumbprint -replace "\s", "").ToUpperInvariant()
    $rootCaSubject = $rootCaCert.Subject
    Publish "INFO" "Loaded root CA certificate`: $rootCaSubject (Thumbprint $rootCaThumbprint)" "Get-ChildItem '$rootCaPath'"

    try {
        $storeProbe = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "LocalMachine")
        $storeProbe.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $storeProbe.Close()
    } catch {
        Publish "BROKEN" "Windows certificate store not accessible`: $($_.Exception.Message)" "New-Object System.Security.Cryptography.X509Certificates.X509Store"
        return
    }

    $localRootResult = Test-CertificateByThumbprint -StoreName "Root" -StoreLocation "LocalMachine" -Thumbprint $rootCaThumbprint
    if ($localRootResult.Error) {
        Publish "BROKEN" "Error inspecting LocalMachine root store`: $($localRootResult.Error)" $expectedImportCommand
    } elseif ($localRootResult.Found) {
        Publish "PASS" "rootCA certificate present in LocalMachine Root store (matches rootCA.cer)" $expectedImportCommand
    } else {
        $userRootResult = Test-CertificateByThumbprint -StoreName "Root" -StoreLocation "CurrentUser" -Thumbprint $rootCaThumbprint
        if ($userRootResult.Error) {
            Publish "BROKEN" "Error inspecting CurrentUser root store`: $($userRootResult.Error)" $expectedImportCommand
        } elseif ($userRootResult.Found) {
            Publish "FAIL" "rootCA certificate installed in CurrentUser Root store; re-run import with elevated PowerShell" $expectedImportCommand
        } else {
            Publish "FAIL" "rootCA certificate not installed in Windows Root store. Run the import command in elevated PowerShell." $expectedImportCommand
        }
    }

    $domainResult = Test-CertificateInStore -StoreName "My" -StoreLocation "LocalMachine" -Subject $domain
    if ($domainResult.Error) {
        Publish "INFO" "Error inspecting LocalMachine personal store for '$domain'`: $($domainResult.Error)" "Get-ChildItem Cert:\LocalMachine\My"
    } elseif ($domainResult.Found) {
        Publish "PASS" "Domain certificate found in Windows Personal store`: $domain ($($domainResult.Count) certificates)" "Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like '*$domain*'"
    } else {
        $userDomainResult = Test-CertificateInStore -StoreName "My" -StoreLocation "CurrentUser" -Subject $domain
        if ($userDomainResult.Error) {
            Publish "INFO" "Error inspecting CurrentUser personal store for '$domain'`: $($userDomainResult.Error)" "Get-ChildItem Cert:\CurrentUser\My"
        } elseif ($userDomainResult.Found) {
            Publish "INFO" "Domain certificate found in CurrentUser Personal store`: $domain ($($userDomainResult.Count) certificates)" "Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -like '*$domain*'"
        } else {
            Publish "INFO" "Domain certificate not found in Windows certificate stores`: $domain" "Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like '*$domain*'"
        }
    }

    Test-SslEndpoint -Url "https://$domain" -Label "Primary domain"

    $subdomains = @("rag", "lobechat", "vector", "monitor")
    foreach ($subdomain in $subdomains) {
        $subUrl = "https://$subdomain.$domain"
        Test-SslEndpoint -Url $subUrl -Label "Subdomain"
    }

    try {
        $mkcertVersion = & mkcert -version 2>$null
        if ($mkcertVersion) {
            Publish "PASS" "mkcert tool available on Windows`: $mkcertVersion" "mkcert -version"

            try {
                $caroot = & mkcert -CAROOT 2>$null
                if ($caroot -and (Test-Path $caroot)) {
                    Publish "PASS" "mkcert CAROOT configured`: $caroot" "mkcert -CAROOT"

                    $rootCaPem = Join-Path $caroot "rootCA.pem"
                    $rootCaKey = Join-Path $caroot "rootCA-key.pem"
                    if ((Test-Path $rootCaPem) -and (Test-Path $rootCaKey)) {
                        Publish "PASS" "mkcert root CA files exist in CAROOT" "ls `"$caroot`""
                    } else {
                        Publish "FAIL" "mkcert root CA files missing in CAROOT`: $caroot" "ls `"$caroot`""
                    }
                } else {
                    Publish "FAIL" "mkcert CAROOT not configured or inaccessible" "mkcert -CAROOT"
                }
            } catch {
                Publish "FAIL" "Cannot determine mkcert CAROOT`: $($_.Exception.Message)" "mkcert -CAROOT"
            }
        } else {
            Publish "INFO" "mkcert command available but version detection returned no output" "mkcert -version"
        }
    } catch {
        Publish "FAIL" "mkcert tool not available on Windows PATH" "where mkcert"
    }

    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "LocalMachine")
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $certCount = $store.Certificates.Count
        $store.Close()
        Publish "INFO" "Windows Root certificate store accessible`: $certCount certificates" "Get-ChildItem Cert:\LocalMachine\Root | Measure-Object"
    } catch {
        Publish "FAIL" "Cannot access Windows Root certificate store`: $($_.Exception.Message)" "Get-ChildItem Cert:\LocalMachine\Root"
    }

} catch {
    Publish "BROKEN" "Unexpected PowerShell error`: $($_.Exception.Message)" "wsl2-windows-rootca.ps1"
}

# =============================================================================
# WSL2 Windows Docker Integration Check (PowerShell)
# =============================================================================
# 
# GIVEN: WSL2 environment with Docker Desktop integration
# WHEN: We test Windows Docker daemon accessibility from WSL2
# THEN: We verify Docker integration is working properly
# =============================================================================

# Check if Docker Desktop is running on Windows
try {
    $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
    if ($dockerVersion) {
        Write-Output "PASS|windows_docker|Docker Desktop accessible from WSL2: v$dockerVersion|docker version"
    } else {
        Write-Output "FAIL|windows_docker|Docker Desktop not accessible from WSL2|docker version"
    }
} catch {
    Write-Output "BROKEN|windows_docker|Cannot execute docker command: $($_.Exception.Message)|docker version"
}

# Check Docker Desktop WSL2 integration
try {
    # Try multiple registry paths where Docker Desktop settings might be stored
    $registryPaths = @(
        "HKCU:\Software\Docker Inc.\Docker Desktop",
        "HKLM:\Software\Docker Inc.\Docker Desktop",
        "HKCU:\Software\Docker\Docker Desktop"
    )
    
    $wslEnabled = $false
    $foundPath = ""
    
    foreach ($path in $registryPaths) {
        try {
            if (Test-Path $path) {
                $wslIntegration = Get-ItemProperty -Path $path -Name "WSLEngineEnabled" -ErrorAction SilentlyContinue
                if ($wslIntegration -and $wslIntegration.WSLEngineEnabled -eq 1) {
                    $wslEnabled = $true
                    $foundPath = $path
                    break
                }
            }
        } catch {
            # Continue to next path
        }
    }
    
    if ($wslEnabled) {
        Write-Output "PASS|windows_docker|WSL2 integration enabled in Docker Desktop (found in $foundPath)|Registry: WSLEngineEnabled"
    } else {
        # Check if Docker is working from WSL2 as alternative verification
        try {
            $dockerInfo = docker info --format "{{.OperatingSystem}}" 2>$null
            if ($dockerInfo -match "linux") {
                Write-Output "INFO|windows_docker|WSL2 integration working (Docker shows Linux OS) but registry setting not found|docker info"
            } else {
                Write-Output "FAIL|windows_docker|WSL2 integration not enabled in Docker Desktop|Registry: WSLEngineEnabled"
            }
        } catch {
            Write-Output "FAIL|windows_docker|WSL2 integration not enabled in Docker Desktop|Registry: WSLEngineEnabled"
        }
    }
} catch {
    Write-Output "INFO|windows_docker|Cannot check WSL2 integration registry setting - $($_.Exception.Message)|Registry: WSLEngineEnabled"
}

# Check if Docker contexts include WSL2
try {
    $contexts = docker context ls --format "{{.Name}}" 2>$null
    if ($contexts -match "desktop-linux") {
        Write-Output "PASS|windows_docker|Docker Desktop Linux context available|docker context ls"
    } else {
        Write-Output "FAIL|windows_docker|Docker Desktop Linux context not found|docker context ls"
    }
} catch {
    Write-Output "BROKEN|windows_docker|Cannot list Docker contexts: $($_.Exception.Message)|docker context ls"
}

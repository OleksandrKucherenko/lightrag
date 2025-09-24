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
    $wslIntegration = Get-ItemProperty -Path "HKCU:\Software\Docker Inc.\Docker Desktop" -Name "WSLEngineEnabled" -ErrorAction SilentlyContinue
    if ($wslIntegration.WSLEngineEnabled -eq 1) {
        Write-Output "PASS|windows_docker|WSL2 integration enabled in Docker Desktop|Registry: WSLEngineEnabled"
    } else {
        Write-Output "FAIL|windows_docker|WSL2 integration not enabled in Docker Desktop|Registry: WSLEngineEnabled"
    }
} catch {
    Write-Output "INFO|windows_docker|Cannot check WSL2 integration registry setting|Registry: WSLEngineEnabled"
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

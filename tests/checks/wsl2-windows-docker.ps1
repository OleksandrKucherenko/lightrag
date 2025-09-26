# =============================================================================
# WSL2 Docker Integration Check (PowerShell)
# =============================================================================
# 
# GIVEN: WSL2 environment with Docker (Desktop or native installation)
# WHEN: We test Docker daemon accessibility and configuration
# THEN: We verify Docker integration is working properly
# =============================================================================

# Detect Docker installation type and check accessibility
try {
    $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
    if ($dockerVersion) {
        Write-Output "PASS|windows_docker|Docker accessible from WSL2: v$dockerVersion|docker version"
        
        # Check if this is Docker Desktop or native Docker
        $dockerInfo = docker info --format "{{.ServerVersion}}" 2>$null
        if ($dockerInfo) {
            # Try to detect Docker Desktop vs native installation
            $dockerDesktopCheck = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
            if ($dockerDesktopCheck) {
                Write-Output "INFO|windows_docker|Docker Desktop installation detected|Get-Process 'Docker Desktop'"
                
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
                
                # Check Docker Desktop contexts
                try {
                    $contexts = docker context ls --format "{{.Name}}" 2>$null
                    if ($contexts -match "desktop-linux") {
                        Write-Output "PASS|windows_docker|Docker Desktop Linux context available|docker context ls"
                    } else {
                        Write-Output "FAIL|windows_docker|Docker Desktop Linux context not found|docker context ls"
                    }
                } catch {
                    Write-Output "INFO|windows_docker|Cannot list Docker contexts|docker context ls"
                }
            } else {
                Write-Output "INFO|windows_docker|Native WSL2 Docker installation detected (no Docker Desktop)|docker info"
                
                # For native Docker, check if daemon is running in WSL2
                try {
                    $dockerStatus = docker info --format "{{.ServerVersion}}" 2>$null
                    if ($dockerStatus) {
                        Write-Output "PASS|windows_docker|Native Docker daemon running in WSL2|docker info"
                    } else {
                        Write-Output "FAIL|windows_docker|Native Docker daemon not responding|docker info"
                    }
                } catch {
                    Write-Output "FAIL|windows_docker|Cannot connect to native Docker daemon|docker info"
                }
                
                # Check Docker contexts for native installation
                try {
                    $contexts = docker context ls --format "{{.Name}}" 2>$null
                    if ($contexts -match "default") {
                        Write-Output "PASS|windows_docker|Default Docker context available|docker context ls"
                    } else {
                        Write-Output "INFO|windows_docker|Custom Docker context configuration|docker context ls"
                    }
                } catch {
                    Write-Output "INFO|windows_docker|Cannot list Docker contexts|docker context ls"
                }
            }
        }
    } else {
        Write-Output "FAIL|windows_docker|Docker not accessible from WSL2|docker version"
    }
} catch {
    Write-Output "BROKEN|windows_docker|Cannot execute docker command: $($_.Exception.Message)|docker version"
}

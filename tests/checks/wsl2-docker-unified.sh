#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Docker Unified Integration Check
# =============================================================================
# 
# GIVEN: WSL2 environment with Docker (Desktop or native installation)
# WHEN: We automatically detect and test the Docker configuration
# THEN: We verify Docker integration works regardless of installation type
# =============================================================================

# Function to check if we're in WSL2
is_wsl2() {
    [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null
}

# Function to check if Docker Desktop is running on Windows
check_docker_desktop() {
    if is_wsl2 && command -v powershell.exe >/dev/null 2>&1; then
        # Check if Docker Desktop process is running on Windows
        if powershell.exe -Command "Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue" >/dev/null 2>&1; then
            return 0  # Docker Desktop found
        fi
    fi
    return 1  # Docker Desktop not found
}

# Function to run Docker Desktop specific checks
check_docker_desktop_integration() {
    echo "INFO|docker_unified|Docker Desktop installation detected|powershell.exe Get-Process 'Docker Desktop'"
    
    # Run the PowerShell script for Docker Desktop checks
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local ps_script="${script_dir}/wsl2-windows-docker.ps1"
    
    if [[ -f "$ps_script" ]] && command -v powershell.exe >/dev/null 2>&1; then
        # Copy script to Windows temp and run with proper execution policy
        local windows_temp
        if windows_temp=$(cmd.exe /c "echo %TEMP%" 2>/dev/null | tr -d '\r'); then
            local wsl_temp_path
            if wsl_temp_path=$(wslpath "$windows_temp" 2>/dev/null); then
                local temp_script="${wsl_temp_path}/wsl2-windows-docker.ps1"
                cp "$ps_script" "$temp_script" 2>/dev/null || {
                    echo "BROKEN|docker_unified|Cannot copy PowerShell script to Windows temp|cp $ps_script"
                    return 1
                }
                
                # Run PowerShell script with execution policy bypass
                if powershell.exe -ExecutionPolicy Bypass -File "$temp_script" 2>/dev/null; then
                    # Cleanup
                    rm -f "$temp_script" 2>/dev/null || true
                else
                    echo "BROKEN|docker_unified|PowerShell Docker Desktop check failed|powershell.exe -ExecutionPolicy Bypass"
                    rm -f "$temp_script" 2>/dev/null || true
                    return 1
                fi
            else
                echo "BROKEN|docker_unified|Cannot convert Windows temp path|wslpath"
                return 1
            fi
        else
            echo "BROKEN|docker_unified|Cannot get Windows temp directory|cmd.exe /c echo %TEMP%"
            return 1
        fi
    else
        echo "BROKEN|docker_unified|PowerShell script not found or PowerShell not available|ls $ps_script"
        return 1
    fi
}

# Function to run native Docker checks
check_native_docker() {
    echo "INFO|docker_unified|Native WSL2 Docker installation detected|docker info"
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo "BROKEN|docker_unified|Docker command not found|which docker"
        return 1
    fi

    # Check Docker version and daemon
    local docker_version
    docker_version=$(docker version --format "{{.Server.Version}}" 2>/dev/null)
    if [[ -n "$docker_version" ]]; then
        echo "PASS|docker_unified|Native Docker daemon accessible: v$docker_version|docker version"
    else
        echo "FAIL|docker_unified|Native Docker daemon not accessible|docker version"
        return 1
    fi

    # Check if Docker service is running
    if systemctl is-active docker >/dev/null 2>&1; then
        echo "PASS|docker_unified|Docker service running (systemd)|systemctl is-active docker"
    elif service docker status >/dev/null 2>&1; then
        echo "PASS|docker_unified|Docker service running (service)|service docker status"
    else
        echo "FAIL|docker_unified|Docker service not running|systemctl status docker"
    fi

    # Check Docker daemon info
    if docker info >/dev/null 2>&1; then
        echo "PASS|docker_unified|Docker daemon responding|docker info"
        
        # Check storage driver
        local storage_driver
        storage_driver=$(docker info --format "{{.Driver}}" 2>/dev/null || echo "unknown")
        echo "INFO|docker_unified|Storage driver: $storage_driver|docker info --format '{{.Driver}}'"
    else
        echo "FAIL|docker_unified|Docker daemon not responding|docker info"
    fi

    # Test container execution
    if docker run --rm hello-world >/dev/null 2>&1; then
        echo "PASS|docker_unified|Docker container execution working|docker run --rm hello-world"
    else
        echo "FAIL|docker_unified|Cannot run Docker containers|docker run --rm hello-world"
    fi

    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker-compose version --short 2>/dev/null || echo "unknown")
        echo "PASS|docker_unified|Docker Compose available: v$compose_version|docker-compose version"
    elif docker compose version >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo "PASS|docker_unified|Docker Compose (plugin) available: v$compose_version|docker compose version"
    else
        echo "INFO|docker_unified|Docker Compose not installed|docker-compose version"
    fi

    # Check user permissions
    if groups | grep -q docker; then
        echo "PASS|docker_unified|User in docker group|groups | grep docker"
    else
        echo "INFO|docker_unified|User not in docker group (sudo may be required)|sudo usermod -aG docker \$USER"
    fi
}

# Main execution logic
main() {
    # First, check if we're in WSL2
    if ! is_wsl2; then
        echo "INFO|docker_unified|Not running in WSL2 environment|cat /proc/version"
        echo "INFO|docker_unified|Skipping WSL2-specific Docker checks|uname -r"
        exit 0
    fi

    echo "PASS|docker_unified|Running in WSL2 environment|cat /proc/version"

    # Check basic Docker availability first
    if ! command -v docker >/dev/null 2>&1; then
        echo "BROKEN|docker_unified|Docker command not available|which docker"
        exit 1
    fi

    # Try to detect Docker installation type
    if check_docker_desktop; then
        # Docker Desktop is running - use Desktop-specific checks
        check_docker_desktop_integration
    else
        # No Docker Desktop detected - assume native Docker
        check_native_docker
    fi

    # Common checks for both installations
    echo "INFO|docker_unified|Docker integration check completed|docker --version"
}

# Run main function
main "$@"

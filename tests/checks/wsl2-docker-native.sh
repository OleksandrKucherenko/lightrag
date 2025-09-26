#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# WSL2 Native Docker Installation Check
# =============================================================================
# 
# GIVEN: WSL2 environment with native Docker installation (no Docker Desktop)
# WHEN: We test Docker daemon and service configuration
# THEN: We verify native Docker setup is working properly
# =============================================================================

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "BROKEN|docker_native|Docker command not found|which docker"
    exit 1
fi

# Check Docker version
if docker_version=$(docker version --format "{{.Server.Version}}" 2>/dev/null); then
    echo "PASS|docker_native|Docker daemon accessible: v$docker_version|docker version"
else
    echo "FAIL|docker_native|Docker daemon not accessible|docker version"
    exit 1
fi

# Check if Docker service is running (systemd)
if systemctl is-active docker >/dev/null 2>&1; then
    echo "PASS|docker_native|Docker service running (systemd)|systemctl is-active docker"
elif service docker status >/dev/null 2>&1; then
    echo "PASS|docker_native|Docker service running (service)|service docker status"
else
    echo "FAIL|docker_native|Docker service not running|systemctl status docker"
fi

# Check if Docker service is enabled
if systemctl is-enabled docker >/dev/null 2>&1; then
    echo "PASS|docker_native|Docker service enabled for startup|systemctl is-enabled docker"
else
    echo "INFO|docker_native|Docker service not enabled for auto-start|systemctl enable docker"
fi

# Check Docker daemon configuration
if docker info >/dev/null 2>&1; then
    echo "PASS|docker_native|Docker daemon responding to info command|docker info"
    
    # Check storage driver
    storage_driver=$(docker info --format "{{.Driver}}" 2>/dev/null || echo "unknown")
    echo "INFO|docker_native|Storage driver: $storage_driver|docker info --format '{{.Driver}}'"
    
    # Check if Docker is running rootless
    if docker info --format "{{.SecurityOptions}}" 2>/dev/null | grep -q "rootless"; then
        echo "INFO|docker_native|Running in rootless mode|docker info"
    else
        echo "INFO|docker_native|Running in standard (root) mode|docker info"
    fi
else
    echo "FAIL|docker_native|Docker daemon not responding|docker info"
fi

# Test Docker functionality with a simple container
if docker run --rm hello-world >/dev/null 2>&1; then
    echo "PASS|docker_native|Docker container execution working|docker run --rm hello-world"
else
    echo "FAIL|docker_native|Cannot run Docker containers|docker run --rm hello-world"
fi

# Check Docker Compose availability
if command -v docker-compose >/dev/null 2>&1; then
    compose_version=$(docker-compose version --short 2>/dev/null || echo "unknown")
    echo "PASS|docker_native|Docker Compose available: v$compose_version|docker-compose version"
elif docker compose version >/dev/null 2>&1; then
    compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
    echo "PASS|docker_native|Docker Compose (plugin) available: v$compose_version|docker compose version"
else
    echo "INFO|docker_native|Docker Compose not installed|docker-compose version"
fi

# Check user permissions
if groups | grep -q docker; then
    echo "PASS|docker_native|User in docker group (no sudo required)|groups | grep docker"
else
    echo "INFO|docker_native|User not in docker group (sudo may be required)|sudo usermod -aG docker \$USER"
fi

# Check Docker socket permissions
if [[ -S "/var/run/docker.sock" ]]; then
    echo "PASS|docker_native|Docker socket exists|ls -la /var/run/docker.sock"
    
    if [[ -r "/var/run/docker.sock" && -w "/var/run/docker.sock" ]]; then
        echo "PASS|docker_native|Docker socket accessible|ls -la /var/run/docker.sock"
    else
        echo "INFO|docker_native|Docker socket permissions may require sudo|ls -la /var/run/docker.sock"
    fi
else
    echo "FAIL|docker_native|Docker socket not found|ls -la /var/run/docker.sock"
fi

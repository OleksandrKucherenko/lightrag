# Docker 28.x WSL2 Bind Mount Issue

## Problem Description

Docker 28.x introduced changes in bind mount behavior in WSL2 environments that affect mounting subdirectories from Windows filesystem mounts (paths under `/mnt/`).

### Symptoms
- SSL certificate files exist on the host filesystem
- Direct bind mount of subdirectory (`./docker/ssl:/ssl:ro`) results in empty directory inside container
- Error: `open /ssl/dev.localhost.pem: no such file or directory`

### Root Cause
Docker 28.x has stricter security policies for bind mounts in WSL2, particularly affecting:
- Paths mounted from Windows filesystems (`/mnt/workspace`, `/mnt/c`, etc.)
- Direct subdirectory bind mounts from these locations
- **Directory naming/metadata issues**: Certain directory names (like `ssl`) fail to mount while others (`certificates`) work with identical files

## Solution

### Directory Naming Fix (Recommended - Simplest)
Rename the SSL directory from `ssl` to `certificates` - this resolves the bind mount issue:

```bash
# Automated setup with directory rename
./bin/setup-ssl-certs.sh
```

```yaml
# ✅ Simple and secure: Direct bind mount works with 'certificates' directory name
volumes:
  - ./docker/certificates:/ssl:ro
```

**Key Discovery**: Docker 28.x WSL2 has issues with certain directory names or metadata. The directory named `ssl` fails to mount, but `certificates` works perfectly with the same files.

### Alternative: WSL2 Native Filesystem
Copy SSL certificates to WSL2 native filesystem:

```bash
# Copy to WSL2 native filesystem
mkdir -p ~/.lightrag/ssl
cp docker/ssl/* ~/.lightrag/ssl/
```

```yaml
# ✅ Secure: Uses WSL2 native filesystem
volumes:
  - ~/.lightrag/ssl:/ssl:ro
```

### Alternative: Parent Directory Mount (Less Secure)
```yaml
# ⚠️ Works but exposes all files in ./docker directory
volumes:
  - caddy_ssl:/docker:ro

# Volume definition
volumes:
  caddy_ssl:
    <<: *volume-bind
    driver_opts:
      <<: *volume-bind-opts
      device: ./docker
```

**Security Risk**: This approach exposes configuration files, data, and logs from other services to the proxy container.

## Verification

### Test SSL Certificate Access
```bash
# Check if proxy starts without errors
docker compose up proxy -d

# Verify SSL endpoint works
curl -k https://dev.localhost/health
# Expected output: OK
```

### Check Container File Access
```bash
# Verify files are accessible inside container
docker exec proxy ls -la /docker/ssl/
```

## Environment Details

- **Docker Version**: 28.2.2/28.4.0
- **OS**: WSL2 Ubuntu on Windows 11
- **Mount Path**: `/mnt/workspace` (Windows filesystem mount)
- **Issue**: Direct subdirectory bind mounts fail for certain directory names
- **Solution**: Rename directory from `ssl` to `certificates`

## Directory Naming Investigation

Testing revealed that Docker 28.x WSL2 has issues with specific directory names:

| Directory Name | Mount Result | Status |
|---------------|--------------|---------|
| `ssl` (original) | Empty directory | ❌ Fails |
| `certificates` | Files visible | ✅ Works |
| `certs` | Files visible | ✅ Works |
| `ssl-test` (new) | Files visible | ✅ Works |

**Hypothesis**: The original `ssl` directory may have metadata, inode, or filesystem attributes that Docker 28.x WSL2 cannot handle properly.

## Alternative Solutions

1. **Directory Rename**: Rename `ssl` to `certificates` (recommended)
2. **Copy to WSL2 Native Filesystem**: Move project to `~/` instead of `/mnt/workspace`
3. **Docker Volumes**: Use named volumes and copy files during container initialization
4. **Init Containers**: Use init containers to copy SSL certificates from mounted volumes

## Git Commit Message
```
fix(docker): resolve SSL cert mount issue with Docker 28.x WSL2 directory naming

- Rename SSL directory from 'ssl' to 'certificates' to fix bind mount issue
- Docker 28.x WSL2 has issues with certain directory names/metadata
- Add automated setup script with directory rename functionality
- Document directory naming investigation and workaround

Resolves Docker 28.x WSL2 bind mount failures for specific directory names
```

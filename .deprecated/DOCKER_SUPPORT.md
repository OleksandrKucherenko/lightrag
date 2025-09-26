# Docker Configuration Support

The LightRAG testing framework supports **both** Docker Desktop and native WSL2 Docker installations automatically.

## Supported Configurations

### 🖥️ **Docker Desktop (Windows)**
- Docker Desktop application installed on Windows
- WSL2 integration enabled in Docker Desktop settings
- Docker commands work from WSL2 via Docker Desktop

### 🐧 **Native WSL2 Docker**
- Docker Engine installed directly in WSL2
- Docker daemon running as systemd service in WSL2
- No Docker Desktop application required

## Automatic Detection

The testing framework **automatically detects** your Docker configuration:

```bash
# Run the unified check (recommended)
./tests/checks/wsl2-docker-unified.sh

# Or run the full verification suite
./tests/verify.configuration.v3.sh
```

## Available Test Scripts

### **Unified Script** (Recommended)
- `wsl2-docker-unified.sh` - Automatically detects and tests both configurations

### **Specific Scripts** (For targeted testing)
- `wsl2-windows-docker.ps1` - Docker Desktop specific checks (PowerShell)
- `wsl2-docker-native.sh` - Native Docker specific checks (Bash)

## Expected Results

### **Docker Desktop Configuration**
```
✓ Docker Desktop installation detected
✓ Docker accessible from WSL2: v28.0.1
✓ WSL2 integration enabled in Docker Desktop
✓ Docker Desktop Linux context available
```

### **Native WSL2 Docker Configuration**
```
✓ Native WSL2 Docker installation detected
✓ Native Docker daemon accessible: v24.0.7
✓ Docker service running (systemd)
✓ Docker daemon responding
✓ Docker container execution working
✓ User in docker group
```

## Troubleshooting

### **Docker Desktop Issues**
1. **WSL2 integration not enabled**:
   - Open Docker Desktop → Settings → Resources → WSL Integration
   - Enable integration with your WSL2 distribution

2. **Linux context missing**:
   - Restart Docker Desktop completely
   - Verify with: `docker context ls`

### **Native Docker Issues**
1. **Service not running**:
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **Permission denied**:
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

3. **Docker daemon not responding**:
   ```bash
   sudo systemctl restart docker
   docker info
   ```

## Installation Guides

### **Installing Native Docker in WSL2**
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install docker.io

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again, then test
docker run hello-world
```

### **Installing Docker Compose**
```bash
# For native Docker installations
sudo apt install docker-compose

# Or install Docker Compose plugin
sudo apt install docker-compose-plugin
```

## Benefits Comparison

### **Docker Desktop**
- ✅ Easy GUI management
- ✅ Automatic updates
- ✅ Windows integration
- ❌ Higher resource usage
- ❌ Requires Windows license

### **Native WSL2 Docker**
- ✅ Lower resource usage
- ✅ Faster performance
- ✅ More control over configuration
- ✅ No Windows GUI dependencies
- ❌ Manual setup required
- ❌ Command-line management only

## Framework Integration

The LightRAG verification framework:
1. **Automatically detects** your Docker configuration
2. **Runs appropriate tests** for your setup
3. **Provides specific guidance** for any issues found
4. **Supports both configurations** without user intervention

No configuration changes needed - just run the verification suite and it handles the rest! 🎉

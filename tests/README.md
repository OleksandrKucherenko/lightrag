# LightRAG Testing Framework

This directory contains a comprehensive Test-Driven Development (TDD) framework for the LightRAG solution, following GIVEN/WHEN/THEN patterns and modular architecture principles.

- [LightRAG Testing Framework](#lightrag-testing-framework)
  - [🎯 Quick Start](#-quick-start)
    - [Run All Tests](#run-all-tests)
    - [Run Specific Test Categories](#run-specific-test-categories)
    - [Run Individual Tests](#run-individual-tests)
  - [🏗️ Architecture](#️-architecture)
    - [Pattern-Based Modular System](#pattern-based-modular-system)
    - [Supported Script Types](#supported-script-types)
  - [📋 Test Categories](#-test-categories)
    - [Security Configuration](#security-configuration)
    - [Storage Analysis](#storage-analysis)
    - [Service Communication](#service-communication)
    - [Environment Configuration](#environment-configuration)
    - [Monitoring \& Health](#monitoring--health)
    - [WSL2 Windows Integration](#wsl2-windows-integration)
  - [🔧 Adding New Checks](#-adding-new-checks)
    - [1. Create Check Script](#1-create-check-script)
    - [2. Follow Standard Structure](#2-follow-standard-structure)
    - [3. Use Standard Output Format](#3-use-standard-output-format)
    - [4. Auto-Discovery](#4-auto-discovery)
    - [Template-Based Generator](#template-based-generator)
  - [🎨 GIVEN/WHEN/THEN Structure](#-givenwhenthen-structure)
  - [🌐 Multi-Platform Support](#-multi-platform-support)
    - [Environment Detection](#environment-detection)
    - [WSL2 Features](#wsl2-features)
    - [Cross-Platform IP Detection](#cross-platform-ip-detection)
  - [📊 Output Examples](#-output-examples)
    - [Successful Security Check](#successful-security-check)
    - [WSL2 Integration Results](#wsl2-integration-results)
    - [Storage Analysis](#storage-analysis-1)
  - [🔍 Troubleshooting](#-troubleshooting)
    - [Common Issues](#common-issues)
    - [Debug Individual Checks](#debug-individual-checks)
  - [⚠️ Common Pitfalls and Solutions](#️-common-pitfalls-and-solutions)
    - [PowerShell Script Issues](#powershell-script-issues)
    - [Bash Script Output Format Issues](#bash-script-output-format-issues)
    - [Certificate Store and SSL Issues](#certificate-store-and-ssl-issues)
    - [Framework Integration Issues](#framework-integration-issues)
    - [Best Practices Summary](#best-practices-summary)
  - [🚀 Integration with Development Workflow](#-integration-with-development-workflow)
    - [Pre-commit Validation](#pre-commit-validation)
    - [CI/CD Integration](#cicd-integration)
    - [Development](#development)
  - [📁 Directory Structure](#-directory-structure)
  - [🎯 Benefits](#-benefits)


## 🎯 Quick Start

### Run All Tests

```bash
# Run complete configuration verification
./tests/verify.configuration.v3.sh

# List all available checks
./tests/verify.configuration.v3.sh --list
```

### Run Specific Test Categories

```bash
# Security checks only
find tests/checks -name "security-*" -exec {} \;

# Environment configuration checks
find tests/checks -name "environment-*" -exec {} \;

# WSL2 integration checks (Windows/PowerShell/CMD)
find tests/checks -name "wsl2-*" -exec {} \;
```

### Run Individual Tests

```bash
# Single check script
./tests/checks/security-redis-auth.sh
./tests/checks/storage-qdrant-analysis.sh
./tests/checks/wsl2-subdomain-integration.ps1
```

## 🏗️ Architecture

### Pattern-Based Modular System

All check scripts follow the naming pattern:
```
{group}-{service}-{test_name}.{ext}
```

**Examples:**
- `security-redis-auth.sh` - Redis authentication check (Bash)
- `storage-qdrant-analysis.sh` - Qdrant vector storage analysis (Bash)
- `wsl2-windows-docker.ps1` - Windows Docker integration (PowerShell)
- `communication-external-endpoints.sh` - External API testing (Bash)

### Supported Script Types
- **`.sh`** - Bash scripts (Linux/macOS/WSL2)
- **`.ps1`** - PowerShell scripts (Windows via WSL2)
- **`.cmd/.bat`** - CMD scripts (Windows via WSL2)

## 📋 Test Categories

### Security Configuration
- **`security-redis-auth.sh`** - Redis password authentication
- **`security-qdrant-api.sh`** - Qdrant API key protection
- **`security-memgraph-auth.sh`** - Memgraph credentials validation
- **`security-ssl-certificates.sh`** - SSL certificate validation and integrity
- **`security-caddy-proxy-service.sh`** - Proxy service definition and base labels
- **`security-caddy-url-labels.sh`** - Caddy URL labels for each routed service
- **`security-caddy-tls-labels.sh`** - TLS label presence and certificate references
- **`security-caddy-reverse-proxy.sh`** - Reverse proxy label patterns for services
- **`security-caddy-proxy-cert-volume.sh`** - Certificate volume mount configuration
- **`security-caddy-proxy-envfile.sh`** - Proxy env_file entries for Caddy configuration
- **`security-caddy-proxy-network.sh`** - Frontend network attachment for Caddy proxy
- **`security-caddy-proxy-port-https.sh`** - HTTPS port exposure on the Caddy proxy
- **`security-caddy-proxy-port-http.sh`** - HTTP port exposure for redirects on the Caddy proxy

### Storage Analysis
- **`storage-redis-analysis.sh`** - Redis KV/Document storage validation
- **`storage-qdrant-analysis.sh`** - Qdrant vector collections and embeddings
- **`storage-memgraph-analysis.sh`** - Memgraph graph data structures

### Service Communication
- **`communication-services-connectivity.sh`** - Inter-service network connectivity
- **`communication-external-endpoints.sh`** - External HTTPS endpoint accessibility

### Environment Configuration
- **`environment-system-domain.sh`** - Domain configuration validation
- **`environment-system-hostip.sh`** - Host IP detection across platforms
- **`environment-system-hosts.sh`** - Hosts file preprocessing

### Monitoring & Health
- **`monitoring-rag-health.sh`** - LightRAG service health checks

### WSL2 Windows Integration
- **`wsl2-system-integration.sh`** - WSL2 system integration (Bash)
- **`wsl2-windows-docker.ps1`** - Docker Desktop integration (PowerShell)
- **`wsl2-windows-network.cmd`** - Network connectivity (CMD)
- **`wsl2-subdomain-integration.ps1`** - Subdomain routing (PowerShell)
- **`wsl2-windows-rootca.ps1`** - Windows root CA certificate validation (PowerShell)
- **`wsl2-rootca-integration.sh`** - Root CA integration between WSL2 and Windows (Bash)

## 🔧 Adding New Checks

### 1. Create Check Script

```bash
# Create new check following naming pattern
touch tests/checks/monitoring-caddy-health.sh
chmod +x tests/checks/monitoring-caddy-health.sh
```

### 2. Follow Standard Structure

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Check Description
# =============================================================================
# 
# GIVEN: System state or preconditions
# WHEN: Action or test being performed
# THEN: Expected outcome or validation
# =============================================================================

# Your test logic here
echo "PASS|check_name|Test passed successfully|command used"
```

### 3. Use Standard Output Format

```
STATUS|CHECK_NAME|MESSAGE|COMMAND
```

**Status Values:**
- `ENABLED` - Feature is enabled and working
- `DISABLED` - Feature is intentionally disabled
- `PASS` - Test passed successfully
- `FAIL` - Test failed
- `BROKEN` - System error or misconfiguration
- `INFO` - Informational message

### 4. Auto-Discovery

The orchestrator automatically discovers and runs your new check based on the filename pattern. No manual registration required!

### Template-Based Generator

- Generate new checks directly from a description containing GIVEN/WHEN/THEN:
  ```bash
  ./tests/verify.configuration.v3.sh /check \
    "Security Redis authentication check. GIVEN: Redis has password auth WHEN: I run redis-cli THEN: unauthenticated access is blocked"
  ```
- Use `--interactive` to supply missing fields, or provide overrides such as `--group`, `--service`, `--test`, and `--script-type`.
- Inspect available templates with `./tests/verify.configuration.v3.sh --list-templates` and validate them via `--validate-templates`.
- Generated files follow the `{group}-{service}-{test}.{ext}` naming pattern and default to informative status output so they will not fail the suite until you implement the logic.

```bash
# example:
./tests/verify.configuration.v3.sh /check \
  --group security \
  --service python \
  --test deprecation \
  "Test deprecation check. GIVEN: Python file moved WHEN: running script THEN: should work with MO"

# Generated check: security-python-deprecation.sh
# Template: bash_default
# Group   : security
# Service : python
# Test    : deprecation
# Reminder: Update the placeholder logic before running the orchestrator.
```

## 🎨 GIVEN/WHEN/THEN Structure

All tests follow BDD (Behavior-Driven Development) patterns:

```bash
# GIVEN: A Redis instance with password authentication configured
# WHEN: We test authentication with correct and incorrect credentials
# THEN: We verify password protection is working properly

# Test implementation with clear sections
if [[ -n "$REDIS_PASSWORD" ]]; then
    # WHEN: Password is configured
    # THEN: Test both unauthenticated (should fail) and authenticated (should work)
    
    unauth_result=$(docker compose exec -T kv redis-cli ping 2>&1 || echo "AUTH_REQUIRED")
    auth_result=$(docker compose exec -T kv redis-cli -a "$REDIS_PASSWORD" ping 2>&1 || echo "AUTH_FAILED")
    
    if [[ "$unauth_result" == *"NOAUTH"* ]] && [[ "$auth_result" == "PONG" ]]; then
        echo "ENABLED|redis_auth|Password protection working|docker exec kv redis-cli -a '\$REDIS_PASSWORD' ping"
    else
        echo "BROKEN|redis_auth|Authentication configuration issues|docker exec kv redis-cli ping"
    fi
else
    echo "DISABLED|redis_auth|No password configured - open access|docker exec kv redis-cli ping"
fi
```

## 🌐 Multi-Platform Support

### Environment Detection
- **Linux**: Native Docker environment
- **macOS**: Native Docker environment  
- **WSL2**: Windows Subsystem for Linux with Docker Desktop integration

### WSL2 Features
- **Automatic Detection**: `is_wsl2()` function detects WSL2 environment
- **Path Conversion**: `wslpath` for Windows/Linux path translation
- **Windows Execution**: PowerShell and CMD scripts via `powershell.exe` and `cmd.exe`
- **Subdomain Testing**: Cross-platform DNS and connectivity validation

### Cross-Platform IP Detection

```bash
# Automatic HOST_IP detection
bin/get-host-ip.sh
# Returns: 127.0.0.1 (Linux/macOS) or 192.168.x.x (WSL2)
```

## 📊 Output Examples

### Successful Security Check

```
=== Security Configuration ===
[✓] redis_auth: Password protection working
    Command: docker exec kv redis-cli -a '$REDIS_PASSWORD' ping

[✓] qdrant_api: API key protection working
    Command: curl -s -H 'api-key: $QDRANT_API_KEY' http://localhost:6333/collections
```

### WSL2 Integration Results

```
=== WSL2 Windows Integration ===
[✓] wsl2_detection: Running in WSL2 environment
    Command: cat /proc/version

[✓] subdomain_dns: LightRAG API DNS resolves: rag.dev.localhost -> 127.0.0.1
    Command: nslookup rag.dev.localhost

[ℹ] subdomain_ssl: SSL certificate verification issues (expected for dev)
    Command: openssl s_client -connect rag.dev.localhost:443
```

### Storage Analysis

```
=== Storage Analysis ===
[✓] redis_storage: Active storage - Keys: 42, Documents: 15
    Command: docker exec kv redis-cli keys '*'

[✓] qdrant_storage: Collections: 2, Total vectors: 1,234
    Command: curl -s http://localhost:6333/collections

[✓] memgraph_storage: Graph nodes: 89, relationships: 156
    Command: docker exec graph mgconsole -c "MATCH (n) RETURN count(n);"
```

## 🔍 Troubleshooting

### Common Issues

**1. Permission Denied**

```bash
chmod +x tests/checks/*.sh
```

**2. WSL2 PowerShell Not Found**

```bash
# Ensure PowerShell is available in WSL2
which powershell.exe
```

**3. Docker Services Not Running**

```bash
docker compose up -d
./tests/verify.configuration.v3.sh
```

**4. Environment Variables Missing**

```bash
# Check environment files
ls -la .env*
source .env
```

### Debug Individual Checks

```bash
# Run with verbose output
bash -x ./tests/checks/security-redis-auth.sh

# Check specific service
docker compose ps redis
docker compose logs redis
```

## ⚠️ Common Pitfalls and Solutions

### PowerShell Script Issues

**1. Variable Reference Syntax Errors**

❌ **Problem**: PowerShell fails with "Variable reference is not valid. ':' was not followed by a valid variable name character"
```powershell
Write-Output "ERROR: Connection failed for $url: $($_.Exception.Message)"
```

✅ **Solution**: Replace colons with dashes in string literals containing variable expressions
```powershell
Write-Output "ERROR: Connection failed for $url - $($_.Exception.Message)"
```

**2. Certificate Detection with Spaces and Special Characters**

❌ **Problem**: mkcert certificates not detected due to case-sensitive matching and limited search fields
```powershell
$certificates = $store.Certificates | Where-Object { $_.Subject -like "*$Subject*" }
```

✅ **Solution**: Use case-insensitive matching across multiple certificate fields
```powershell
$certificates = $store.Certificates | Where-Object { 
    $_.Subject -ilike "*$Subject*" -or
    $_.Issuer -ilike "*$Subject*" -or
    $_.FriendlyName -ilike "*$Subject*"
}
```

**3. Windows Path Handling in WSL2**

❌ **Problem**: UNC paths cause script execution failures
```
\\wsl.localhost\Ubuntu\mnt\workspace\lightrag
UNC paths are not supported
```

✅ **Solution**: Copy scripts to Windows temp folder before execution (handled by framework)
```bash
# Framework automatically handles this via copy_to_windows_temp() function
```

### Bash Script Output Format Issues

**4. Multiline Output Breaking Framework Parsing**

❌ **Problem**: Commands with newlines break the `STATUS|CHECK_NAME|MESSAGE|COMMAND` format
```bash
key_count=$(echo "$keys_result" | wc -l)  # Contains newline
echo "INFO|redis_storage|Keys: $key_count|command"  # Breaks parsing
```

✅ **Solution**: Clean all command output of newlines and carriage returns
```bash
key_count=$(echo "$keys_result" | wc -l | tr -d '\n\r')
echo "INFO|redis_storage|Keys: $key_count|command"
```

**5. Variable Contamination from Command Output**

❌ **Problem**: Variables contain unexpected whitespace or control characters
```bash
result=$(docker exec container command)
echo "STATUS|check|Result: $result|command"  # May contain newlines
```

✅ **Solution**: Always clean command output before using in variables
```bash
result=$(docker exec container command | tr -d '\n\r')
# Or use head/tail to get specific lines
result=$(docker exec container command | head -1 | tr -d '\n\r')
```

### Certificate Store and SSL Issues

**6. Incomplete Certificate Store Search**

❌ **Problem**: Only checking LocalMachine store misses user-installed certificates
```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*mkcert*'
```

✅ **Solution**: Search both LocalMachine and CurrentUser stores
```powershell
$stores = @("Cert:\LocalMachine\Root", "Cert:\CurrentUser\Root")
foreach ($store in $stores) {
    Get-ChildItem $store | Where-Object Subject -ilike '*mkcert*'
}
```

**7. Insufficient mkcert Pattern Matching**

❌ **Problem**: mkcert certificates have various subject formats not caught by simple patterns
```powershell
$mkcertSubjects = @("mkcert")
```

✅ **Solution**: Use comprehensive pattern list for mkcert detection
```powershell
$mkcertSubjects = @(
    "mkcert", 
    "mkcert development CA", 
    "mkcert root CA",
    "mkcert development certificate",
    "development CA",
    "localhost"
)
```

### Framework Integration Issues

**8. Status Code Misuse**

❌ **Problem**: Using FAIL for intentionally disabled features
```bash
echo "FAIL|ssl_certificates|SSL not configured"
```

✅ **Solution**: Use appropriate status codes for different scenarios
```bash
echo "DISABLED|ssl_certificates|SSL intentionally not configured"  # Expected state
echo "BROKEN|ssl_certificates|SSL configuration corrupted"         # Needs fixing
echo "FAIL|ssl_certificates|SSL validation failed"                 # Test failed
echo "INFO|ssl_certificates|SSL status information"                # Informational
```

### Best Practices Summary

1. **Always clean command output**: Use `tr -d '\n\r'` on any command output used in variables
2. **Use case-insensitive matching**: PowerShell `-ilike` and `-imatch` instead of `-like` and `-match`
3. **Search multiple certificate stores**: Check both LocalMachine and CurrentUser stores
4. **Avoid colons in PowerShell strings**: Use dashes or other separators with variable expressions
5. **Use appropriate status codes**: DISABLED for intentional, BROKEN for errors, FAIL for test failures
6. **Test with spaces and special characters**: Ensure scripts handle paths and names with spaces
7. **Provide debug information**: When detection fails, show what was actually found

## 🚀 Integration with Development Workflow

### Pre-commit Validation

```bash
# Add to git hooks
./tests/verify.configuration.v3.sh
```

### CI/CD Integration

```bash
# In CI pipeline
docker compose up -d
./tests/verify.configuration.v3.sh
```

### Development 

```bash
# After configuration changes
./tests/verify.configuration.v3.sh

# After adding new services
find tests/checks -name "*new-service*" -exec {} \;
```

## 📁 Directory Structure

```bash
tests/
├── checks/                            # Individual check scripts
│   ├── security-redis-auth.sh         # Redis authentication
│   ├── storage-qdrant-analysis.sh     # Qdrant storage validation
│   ├── wsl2-subdomain-integration.ps1 # WSL2 subdomain testing
│   └── ...
├── verify.configuration.v3.sh         # Main orchestrator
└── README.md                          # This documentation
```

## 🎯 Benefits

1. **Modular**: Each check is independent and focused
2. **Self-Organizing**: Automatic discovery based on filename patterns
3. **Multi-Platform**: Supports Linux, macOS, WSL2, Windows
4. **Multi-Language**: Bash, PowerShell, CMD scripts
5. **Extensible**: Add new checks without modifying orchestrator
6. **Maintainable**: Clear separation of concerns
7. **Debuggable**: Individual checks can be run and tested independently

The testing framework provides comprehensive validation of the entire LightRAG stack while maintaining simplicity and extensibility.

# Configuration Verification Guide

## Overview

The LightRAG configuration verification system provides comprehensive validation of your Docker-based LightRAG stack. It uses a modular architecture where small, focused scripts handle individual checks, and a main orchestrator aggregates results into user-friendly reports.

## Architecture v3.0 - Modular Design

### 🏗️ **Modular Structure**

```
tests/
├── checks/                    # Individual check scripts
│   ├── redis-auth.sh         # Redis authentication check
│   ├── qdrant-api.sh         # Qdrant API security check
│   ├── memgraph-auth.sh      # Memgraph authentication check
│   ├── redis-storage.sh      # Redis storage analysis
│   ├── qdrant-storage.sh     # Qdrant vector storage analysis
│   ├── memgraph-storage.sh   # Memgraph graph analysis
│   ├── service-connectivity.sh # Inter-service communication
│   └── external-endpoints.sh  # External API endpoints
└── verify.configuration.v3.sh # Main orchestrator
```

### 🎯 **Benefits of Modular Design**

- **Simple Coding**: Each script does one specific thing
- **Easy Testing**: Individual checks can be run and tested separately
- **Maintainable**: Add new checks by creating new scripts
- **Debuggable**: Issues isolated to specific check scripts
- **Reusable**: Individual checks can be used in other contexts

## Key Improvements in v3.0

### 🎯 **Configuration State Detection**

Instead of binary pass/fail, the system now detects three distinct states:

- **✓ ENABLED**: Feature is configured and working properly
- **ℹ DISABLED**: Feature is not configured (this is not an error)
- **✗ BROKEN**: Feature is configured but failing

### 🧪 **Standardized Output Format**

All check scripts use a consistent output format:

```
STATUS|CHECK_NAME|MESSAGE|COMMAND
```

- **GIVEN/WHEN/THEN** structure in all check scripts
- Clear business purpose in script comments
- Standardized result reporting for consistent aggregation

### 🔧 **Simpler Code Structure**

- Function-based approach eliminates nested if/else statements
- Each verification function has a single responsibility
- Clear separation between detection, validation, and reporting

## Usage

### Basic Verification

```bash
# Run all checks via the orchestrator
./tests/verify.configuration.v3.sh

# List available individual checks
./tests/verify.configuration.v3.sh --list

# Run individual check scripts
./tests/checks/redis-auth.sh
./tests/checks/qdrant-storage.sh
```

### Individual Check Scripts

```bash
# Security checks
./tests/checks/redis-auth.sh
./tests/checks/qdrant-api.sh  
./tests/checks/memgraph-auth.sh

# Storage analysis
./tests/checks/redis-storage.sh
./tests/checks/qdrant-storage.sh
./tests/checks/memgraph-storage.sh

# Communication tests
./tests/checks/service-connectivity.sh
./tests/checks/external-endpoints.sh
```

### Example Output

```
LightRAG Configuration Verification v3.0
Domain: dev.localhost
Checks Directory: /mnt/workspace/lightrag/tests/checks

=== Security Configuration ===
[✓] redis_auth: Password protection working
    Command: docker exec kv redis-cli -a '$REDIS_PASSWORD' ping

[ℹ] qdrant_api: No API key configured - open access
    Command: curl -s http://localhost:6333/collections

[✗] memgraph_auth: Credentials set but auth failed
    Command: docker exec graph mgconsole --username $MEMGRAPH_USER

=== Storage Analysis ===
[ℹ] redis_storage: Keys: 42, Documents: 15, LightRAG: 28
    Command: docker exec kv redis-cli keys '*'

=== Configuration Summary ===
Total Checks: 8
✓ Passed/Enabled: 3
ℹ Info/Disabled: 4  
✗ Failed/Broken: 1

Configuration State:
🔓 Development configuration (most features disabled)
⚠️  Issues detected - 1 checks failed
```

## Configuration Categories

### 1. Security Configuration

#### Redis Authentication
- **ENABLED**: `REDIS_PASSWORD` set and authentication working
- **DISABLED**: No `REDIS_PASSWORD` set, open access (not an error for dev)
- **BROKEN**: Password set but authentication failing

```bash
# Test command shown in output:
docker exec kv redis-cli -a '$REDIS_PASSWORD' ping
```

#### Qdrant API Security
- **ENABLED**: `QDRANT_API_KEY` set and API protection active
- **DISABLED**: No API key, open access (acceptable for development)
- **BROKEN**: API key set but protection not working

```bash
# Test commands shown in output:
curl -s https://vector.dev.localhost/collections
curl -s -H 'api-key: $QDRANT_API_KEY' https://vector.dev.localhost/collections
```

#### Memgraph Authentication
- **ENABLED**: `MEMGRAPH_USER`/`MEMGRAPH_PASSWORD` set and working
- **DISABLED**: No credentials configured, open access
- **BROKEN**: Credentials set but authentication failing

```bash
# Test command shown in output:
docker exec graph mgconsole --username $MEMGRAPH_USER --password $MEMGRAPH_PASSWORD
```

### 2. Storage Validation

#### Redis Storage Analysis
Analyzes the actual data structures stored in Redis:

- Key count and patterns
- Document status tracking keys
- Keyspace information

```bash
# Commands used for analysis:
docker exec kv redis-cli -a '$REDIS_PASSWORD' keys '*'
docker exec kv redis-cli -a '$REDIS_PASSWORD' info keyspace
docker exec kv redis-cli -a '$REDIS_PASSWORD' keys '*doc*'
```

#### Qdrant Vector Storage
Deep validation of vector storage:

- Collection count and structure
- Vector dimensions and configuration
- Storage utilization

```bash
# Commands used for analysis:
docker exec vectors curl -s -H 'api-key: $QDRANT_API_KEY' http://localhost:6333/collections
docker exec vectors curl -s -H 'api-key: $QDRANT_API_KEY' http://localhost:6333/collections/{collection_name}
```

#### Memgraph Graph Storage
Graph database structure analysis:

- Node and relationship counts
- Index configuration
- Schema information

```bash
# Commands used for analysis:
docker exec graph echo 'MATCH (n) RETURN count(n);' | mgconsole --username $MEMGRAPH_USER --password $MEMGRAPH_PASSWORD
docker exec graph echo 'MATCH ()-[r]->() RETURN count(r);' | mgconsole --username $MEMGRAPH_USER --password $MEMGRAPH_PASSWORD
docker exec graph echo 'SHOW INDEX INFO;' | mgconsole --username $MEMGRAPH_USER --password $MEMGRAPH_PASSWORD
```

### 3. Service Communication

#### Inter-Service Connectivity
Tests network connectivity between services:

- LightRAG → Redis (port 6379)
- LightRAG → Qdrant (port 6333)  
- LightRAG → Memgraph (port 7687)
- LobeChat → LightRAG (port 9621)

```bash
# Test commands:
docker exec rag nc -z kv 6379
docker exec rag nc -z vectors 6333
docker exec rag nc -z graph 7687
docker exec lobechat nc -z rag 9621
```

#### External API Endpoints
Validates external accessibility:

- Main site health endpoint
- LightRAG API health
- LobeChat interface
- Monitoring dashboard

```bash
# Test commands:
curl -I https://dev.localhost/health
curl -I https://rag.dev.localhost/health
curl -I https://lobechat.dev.localhost/
curl -I https://monitor.dev.localhost/
```

## Individual Check Script Structure

### Standard Format

Each check script follows this structure:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# GIVEN/WHEN/THEN structure in comments:
# GIVEN: Description of the system state being tested
# WHEN: Description of the test action
# THEN: Description of expected outcome

# Load environment variables
VARIABLE="${VARIABLE:-}"

# Check prerequisites (container running, etc.)
if ! docker compose ps -q container >/dev/null 2>&1; then
    echo "BROKEN|check_name|Container not found|docker compose ps container"
    exit 0
fi

# Perform the actual check
if result=$(test_command); then
    # Evaluate result and output in standard format
    echo "STATUS|check_name|message|command_used"
else
    echo "BROKEN|check_name|error_message|command_used"
fi
```

### Output Format Standard

```
STATUS|CHECK_NAME|MESSAGE|COMMAND
```

- **STATUS**: `ENABLED`, `DISABLED`, `BROKEN`, `PASS`, `FAIL`, `INFO`
- **CHECK_NAME**: Unique identifier (no spaces, use underscores)
- **MESSAGE**: Human-readable description of the result
- **COMMAND**: Exact command used for verification (for reproduction)

### Check Categories

1. **Security Configuration** (`*-auth.sh`, `*-api.sh`)
   - Authentication and authorization validation
   - API key and credential verification

2. **Storage Analysis** (`*-storage.sh`)
   - Data structure validation
   - Storage utilization analysis

3. **Communication Tests** (`*-connectivity.sh`, `*-endpoints.sh`)
   - Inter-service network connectivity
   - External endpoint accessibility

## Environment Variables

The verification script automatically loads and uses these environment variables:

### Required for Security Features
```bash
REDIS_PASSWORD="your_redis_password"
QDRANT_API_KEY="your_qdrant_api_key"
MEMGRAPH_USER="your_memgraph_user"
MEMGRAPH_PASSWORD="your_memgraph_password"
LIGHTRAG_API_KEY="your_lightrag_api_key"
```

### Configuration
```bash
PUBLISH_DOMAIN="dev.localhost"  # Base domain for all services
```

### Optional Monitoring
```bash
MONITOR_BASIC_AUTH_USER="admin"
MONITOR_BASIC_AUTH_PASSWORD="admin"
```

## Troubleshooting

### Common Issues

#### 1. Services Not Running
```
[✗] LightRAG→Redis: Network connectivity failed
    Command: docker exec rag nc -z kv 6379
```
**Solution**: Ensure Docker Compose stack is running:
```bash
docker compose up -d
docker compose ps  # Check service status
```

#### 2. Authentication Configured But Failing
```
[✗] Redis Authentication: Password set but auth failed
    Command: docker exec kv redis-cli -a '$REDIS_PASSWORD' ping
```
**Solution**: Check environment variable and Redis configuration:
```bash
echo $REDIS_PASSWORD  # Verify variable is set
docker compose logs kv  # Check Redis logs
```

#### 3. Domain Resolution Issues
```
[✗] Main Site Health: Not accessible (HTTP 0)
    Command: curl -I https://dev.localhost/health
```
**Solution**: Check DNS configuration:
```bash
# Update hosts file
mise run hosts-update

# Verify resolution
nslookup dev.localhost
```

### Debug Mode

For detailed debugging, you can run individual verification functions:

```bash
# Source the verification script
source tests/verify.configuration.v2.sh

# Run individual checks
check_redis_security
check_qdrant_security
check_memgraph_security
```

## Integration with Existing Workflow

### MISE Tasks Integration

Add verification to your MISE workflow:

```toml
# In mise.toml
[tasks.verify]
description = "Run configuration verification"
run = "./tests/verify.configuration.v2.sh"

[tasks.test-verify]
description = "Run verification unit tests"
run = "./tests/test.verify.configuration.sh"
```

### CI/CD Integration

```bash
# In your CI pipeline
./tests/test.verify.configuration.sh  # Run unit tests first
./tests/verify.configuration.v2.sh   # Then run full verification
```

## Creating New Check Scripts

### Step 1: Create the Script

```bash
# Create new check script
touch tests/checks/my-new-check.sh
chmod +x tests/checks/my-new-check.sh
```

### Step 2: Follow the Template

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# My New Check Description
# =============================================================================
# 
# GIVEN: Description of what we're testing
# WHEN: Description of the test action
# THEN: Description of expected outcomes
# =============================================================================

# Load environment variables
MY_VAR="${MY_VAR:-}"

# Check prerequisites
if ! docker compose ps -q my_service >/dev/null 2>&1; then
    echo "BROKEN|my_new_check|Service container not found|docker compose ps my_service"
    exit 0
fi

# Perform the check
if result=$(docker compose exec -T my_service my_command 2>&1); then
    if [[ "$result" == "expected_output" ]]; then
        echo "PASS|my_new_check|Check successful|docker exec my_service my_command"
    else
        echo "FAIL|my_new_check|Unexpected result: $result|docker exec my_service my_command"
    fi
else
    echo "BROKEN|my_new_check|Command failed: $result|docker exec my_service my_command"
fi
```

### Step 3: Test Individually

```bash
# Test your new check
./tests/checks/my-new-check.sh

# Expected output format:
# STATUS|my_new_check|message|command
```

### Step 4: Run with Orchestrator

```bash
# The orchestrator will automatically find and run your new check
./tests/verify.configuration.v3.sh
```

## Migration from Previous Versions

### From v1 (Monolithic)
```
# Old: One large script with complex logic
verify.configuration.sh (550 lines)
```

### To v3 (Modular)
```
# New: Multiple focused scripts + orchestrator
tests/checks/redis-auth.sh (45 lines)
tests/checks/qdrant-api.sh (52 lines)
... (8 individual scripts)
tests/verify.configuration.v3.sh (orchestrator)
```

### Key Improvements

1. **Modularity**: Each check is a separate, focused script
2. **Simplicity**: Individual scripts are easy to understand and maintain
3. **Testability**: Each check can be run and debugged independently
4. **Extensibility**: Add new checks by creating new scripts
5. **Reusability**: Individual checks can be used in other contexts

## Best Practices

### 1. Development vs Production

- **Development**: DISABLED security is acceptable and expected
- **Production**: All security features should be ENABLED

### 2. Regular Verification

Run verification:
- After environment changes
- Before deploying new configurations  
- When troubleshooting issues
- As part of CI/CD pipeline

### 3. Understanding Results

- **Green (✓)**: Configuration working as intended
- **Blue (ℹ)**: Information about current state (not an error)
- **Red (✗)**: Something needs attention

## Advanced Usage

### Running Specific Check Categories

```bash
# Run only security checks
for check in redis-auth qdrant-api memgraph-auth; do
    ./tests/checks/$check.sh
done

# Run only storage analysis
for check in redis-storage qdrant-storage memgraph-storage; do
    ./tests/checks/$check.sh
done
```

### Integration with CI/CD

```bash
# In your CI pipeline
#!/bin/bash
set -e

# Run verification and capture exit code
if ./tests/verify.configuration.v3.sh; then
    echo "✅ All configuration checks passed"
else
    echo "❌ Configuration issues detected"
    exit 1
fi
```

### Custom Check Development

```bash
# Create domain-specific checks
./tests/checks/custom-business-logic.sh
./tests/checks/performance-thresholds.sh
./tests/checks/security-compliance.sh
```

The modular verification system makes it easy to understand, maintain, and extend your LightRAG configuration validation, with each component doing one thing well.

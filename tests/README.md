# Tests Directory

This directory contains all test scripts for the LightRAG project, following TDD (Test-Driven Development) principles.

## Test Scripts

### Core Test Suite
- **`test.suite.sh`** - Main comprehensive test framework with GIVEN/WHEN/THEN structure
  - Infrastructure setup tests
  - Environment configuration tests
  - Docker Compose validation
  - Service health checks
  - Security configuration tests
  - Integration connectivity tests
  - LobeChat-specific tests
  - Performance tests
  - LightRAG query mode tests

### Specialized Tests
- **`test-host-ip.sh`** - Tests HOST_IP detection for different environments (Linux, macOS, WSL2)
- **`test.domain.configuration.sh`** - Tests configurable domain functionality
- **`test.hosts.preprocessing.sh`** - Tests .etchosts template preprocessing

### Verification
- **`verify.configuration.sh`** - Comprehensive configuration verification script

## Usage

### Run All Tests
```bash
# From project root
tests/test.suite.sh

# Run specific test category
tests/test.suite.sh infrastructure
tests/test.suite.sh health
tests/test.suite.sh integration
```

### Run Individual Tests
```bash
# Test HOST_IP detection
tests/test-host-ip.sh

# Test domain configuration
tests/test.domain.configuration.sh

# Verify complete configuration
tests/verify.configuration.sh
```

### Test Categories Available in test.suite.sh
- `infrastructure` - Directory structure and basic setup
- `environment` - Environment variable validation
- `docker` - Docker Compose configuration
- `health` - Service health checks
- `security` - Security configuration tests
- `integration` - Service connectivity tests
- `lobechat-redis` - LobeChat to Redis connectivity
- `lobechat-api` - LobeChat API endpoints
- `lobechat-ssl` - SSL/TLS tests for LobeChat
- `lobechat-performance` - Performance benchmarks
- `lightrag-query-modes` - LightRAG query functionality

## Test Framework Features

### GIVEN/WHEN/THEN Structure
All tests follow BDD-style structure:
```bash
given "project has required directory structure"
when "checking for essential directories"
then_step "all required directories should exist"
and_then "additional validation step"
```

### Test Results
- ✅ **PASS** - Test completed successfully
- ❌ **FAIL** - Test failed with reason
- ⏭️ **SKIP** - Test skipped with reason

### Environment Support
Tests are designed to work across:
- **Linux** - Native Docker environment
- **macOS** - Native Docker environment  
- **WSL2** - Windows Subsystem for Linux with Docker Desktop

## Integration with Project

These tests integrate with:
- **mise.toml** - Environment management
- **docker-compose.yaml** - Service definitions
- **Environment files** - Configuration validation
- **SSL certificates** - Security testing
- **Host networking** - Multi-platform IP detection

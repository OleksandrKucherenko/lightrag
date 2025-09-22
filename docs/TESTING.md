# LightRAG Test Framework Documentation

## Overview

The LightRAG solution now includes a comprehensive Test-Driven Development (TDD) approach with automated test suites that follow the GIVEN/WHEN/THEN pattern specified in the project requirements.

## Test Structure

### GIVEN/WHEN/THEN Pattern

All tests follow the BDD (Behavior-Driven Development) approach with clear separation of test phases:

- **GIVEN**: Sets up the initial context and preconditions
- **WHEN**: Describes the action or event being tested
- **THEN**: Specifies the expected outcome or behavior
- **AND**: Additional steps within the same phase

## Test Categories

### 1. Infrastructure Tests
**Purpose**: Verify the basic project structure and required files exist

**Test Coverage**:
- Directory structure validation
- Essential file presence
- Configuration file syntax
- SSL certificate setup

### 2. Environment Configuration Tests
**Purpose**: Validate environment variables and configuration files

**Test Coverage**:
- Environment file loading
- Required variable presence
- Configuration consistency
- Secret management

### 3. Docker Compose Tests
**Purpose**: Ensure Docker configuration is valid and services can start

**Test Coverage**:
- Docker Compose syntax validation
- Service dependency resolution
- Volume and network configuration
- Health check definitions

### 4. Service Health Tests
**Purpose**: Verify all services are running and healthy

**Test Coverage**:
- Container status checking
- Health endpoint validation
- Service connectivity
- Resource usage monitoring

### 5. Security Tests
**Purpose**: Validate security measures and access controls

**Test Coverage**:
- Authentication verification
- Authorization testing
- SSL/TLS validation
- API key protection
- Rate limiting checks

### 6. Integration Tests
**Purpose**: Test inter-service communication and data flow

**Test Coverage**:
- Service-to-service connectivity
- Data pipeline validation
- API endpoint testing
- Cross-service functionality

## Running Tests

### Bash Test Suite
```bash
# Run all tests
./bin/test.suite.sh

# Run specific test categories
./bin/test.suite.sh infrastructure
./bin/test.suite.sh environment
./bin/test.suite.sh security
./bin/test.suite.sh integration
```

### Test Framework
```bash
# TBD
```

### Verification Script

```bash
# Run existing verification suite
./bin/verify.configuration.sh
```

### WSL2 Diagnostics

```bash
# Check WSL2 network configuration
./bin/diag.wsl2.sh
```

## Test Results

### Success Criteria
- ✅ All tests pass
- ✅ No security vulnerabilities
- ✅ All services healthy
- ✅ Configuration valid
- ✅ Integration working

### Test Output Format

```
# TBD
```

## Continuous Integration

### Automated Testing
Tests should be run automatically on:
- Pre-commit hooks
- Pull request validation
- Deployment pipelines
- Scheduled health checks

### Test Integration with MISE
```toml
# mise.toml
[tasks.test]
description = "Run comprehensive test suite"
run = [
    "./bin/test.suite.sh",
    "python3 bin/test_framework.py"
]

[tasks.test-quick]
description = "Run quick smoke tests"
run = [
    "./bin/verify.configuration.sh"
]
```

## Troubleshooting

### Common Test Failures

#### Infrastructure Test Failures
- Missing directories: Run `mise run setup`
- Missing files: Check git status and pull latest changes
- Permission issues: Run `chmod +x bin/*.sh`

#### Environment Test Failures
- Missing variables: Check `.env` files and run `mise run setup`
- Invalid configuration: Validate JSON/YAML syntax
- Secret issues: Run `sops decrypt .env.secrets.json`

#### Service Test Failures
- Services not running: Run `docker compose up -d`
- Port conflicts: Check `docker compose ps` and resolve conflicts
- Resource limits: Adjust `deploy` limits in docker-compose.yaml

#### Security Test Failures
- Authentication issues: Verify API keys and passwords
- SSL problems: Check certificate validity
- Access control: Review security configurations

## Extending the Test Suite

### Adding New Tests

#### Bash Tests
Add new test functions to `bin/test.suite.sh` following the pattern:
```bash
test_new_feature() {
    local test_name="new_feature_validation"

    test_start "$test_name"

    given "specific precondition"
    when "action being tested"
    then "expected outcome"

    if [condition]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "reason for failure"
    fi
}
```

#### Python Tests
Create new test classes inheriting from `BaseTest`:
```python
class NewFeatureTest(BaseTest):
    def __init__(self):
        super().__init__("New Feature", "Test description")

        self.given("precondition", self._setup_condition) \
            .when("action", self._perform_action) \
            .then("outcome", self._verify_result)
```

### Test Data Management
- Use test-specific data in `tests/fixtures/`
- Implement data cleanup in teardown methods
- Use environment-specific configurations
- Mock external dependencies when possible

## Performance Testing

### Resource Usage Tests
- Memory consumption monitoring
- CPU usage tracking
- Network I/O measurement
- Response time benchmarking

### Load Testing
- Concurrent user simulation
- API endpoint stress testing
- Database query performance
- File processing benchmarks

## Security Testing

### Vulnerability Scanning
- Container image scanning
- Dependency vulnerability checks
- API security testing
- Configuration security audit

### Penetration Testing
- Authentication bypass attempts
- Authorization testing
- Input validation testing
- SQL injection prevention

## Monitoring and Reporting

### Test Metrics
- Test execution time
- Success/failure rates
- Code coverage metrics
- Performance benchmarks

### Reporting
- HTML test reports
- JSON export for CI/CD
- Slack/email notifications
- Historical trend analysis

## Best Practices

### Test Organization
- Group related tests in categories
- Use descriptive test names
- Include business context in descriptions
- Maintain test independence

### Test Data
- Use realistic test data
- Implement proper cleanup
- Separate test and production data
- Use data factories for complex objects

### Error Handling
- Comprehensive error messages
- Proper exception handling
- Detailed logging
- Failure screenshots for UI tests

### Maintenance
- Regular test review and updates
- Remove obsolete tests
- Update tests for new features
- Monitor test execution time

## Conclusion

The comprehensive test framework ensures the LightRAG solution maintains high quality, security, and reliability. Regular test execution catches issues early and provides confidence in deployments to both local and cloud environments.

# Check Script Composition Rules for LightRAG Project

## Overview

This document defines the rules and principles for writing check scripts in the LightRAG project. Check scripts are atomic unit tests that verify specific configuration aspects of the system. They follow TDD principles and are automatically discovered and executed by the orchestrator.

## CRITICAL PRINCIPLES (Must Follow)

### 1. Single Responsibility Principle (TDD/Unit Test Style)

- ✅ **CRITICAL**: Each check script must test **exactly one thing**
- ✅ **CRITICAL**: Script name must clearly indicate what is being tested
- ✅ **CRITICAL**: Only two outcomes: PASS/FAIL (INFO acceptable for warnings)
- ❌ **NEVER**: Multiple unrelated assertions in one script

```bash
# ✅ GOOD: Single focused test
communication-cors-lightrag-origins.sh  # Tests only CORS origins configuration

# ❌ BAD: Multiple concerns
communication-cors-configuration.sh     # Tests CORS + service mode + proxy URL
```

### 2. GIVEN/WHEN/THEN Pattern (Flat Structure)

- ✅ **CRITICAL**: Use flat, linear structure with no nested syntax (functions, if/else, loops)
- ✅ **CRITICAL**: Map GIVEN/WHEN/THEN directly to pre-required/action/qualify:
  - **GIVEN**: Validate prerequisites (files exist, set defaults)
  - **WHEN**: Extract/gather data (no business logic)
  - **THEN**: Apply business rules and determine PASS/FAIL

```bash
# ✅ CRITICAL STRUCTURE - Completely flat, no indentation
# GIVEN: Prerequisites
ensure_file "${REPO_ROOT}/.env.lightrag" "test_id" || exit 1
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract data
CORS_ORIGINS=$(action_get_env "${REPO_ROOT}/.env.lightrag" "CORS_ORIGINS")

# THEN: Qualify result
[[ "$CORS_ORIGINS" == *"expected_value"* ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
```

### 3. Shared Library Usage (No Code Duplication)

- ✅ **CRITICAL**: Use existing shared libraries (`action-framework.sh`, `checks-probes.sh`)
- ✅ **CRITICAL**: Reuse common functions (`ensure_file`, `action_get_env`, etc.)
- ❌ **NEVER**: Duplicate file existence checks, environment loading, or common operations

### 4. Orchestrator Integration (Zero Configuration)

- ✅ **CRITICAL**: Follow naming convention: `{category}-{specific-test}.sh`
- ✅ **CRITICAL**: No manual test suite runners (orchestrator auto-discovers)
- ✅ **CRITICAL**: Output format: `STATUS|test_id|message|verification_command`

## IMPORTANT PRINCIPLES (Should Follow)

### 5. Atomic File Organization

- 🔶 **IMPORTANT**: One check per file (enables independent execution)
- 🔶 **IMPORTANT**: Descriptive filenames that indicate exact test purpose
- 🔶 **IMPORTANT**: Group related checks by category prefix

```bash
# ✅ GOOD: Atomic organization
communication-cors-lightrag-origins.sh
communication-lobechat-service-mode.sh
communication-lobechat-proxy-url.sh

# ❌ BAD: Monolithic
communication-cors-all-checks.sh
```

### 6. Error Handling and Validation

- 🔶 **IMPORTANT**: Validation is minimalistic - fail quickly if something critical is missing
- 🔶 **IMPORTANT**: Use pre-defined fallback actions and assume sensible defaults when possible
- 🔶 **IMPORTANT**: If validation is super critical, create dedicated check script instead of repeating checks
- 🔶 **IMPORTANT**: Use folder structure to define execution scope and user-friendly test organization

### 7. Business Logic Centralization

- 🔶 **IMPORTANT**: Keep validation rules in `qualify` functions
- 🔶 **IMPORTANT**: Make business rules easily changeable
- 🔶 **IMPORTANT**: Document expected values and patterns

### 8. Constants and Clean Code

- 🔶 **IMPORTANT**: Declare output messages as readonly constants at the top
- 🔶 **IMPORTANT**: Keep action code clean - no inline message construction
- 🔶 **IMPORTANT**: Use descriptive constant names (PASS_MSG, FAIL_MSG, INFO_MSG)
- 🔶 **IMPORTANT**: Eliminate duplication of test IDs and verification commands

## NICE TO HAVE (Optional)

### 9. Documentation and Comments

- 🔶 **CRITICAL**: GIVEN/WHEN/THEN comments for clarity
- 🔷 **OPTIONAL**: Inline documentation for complex validation logic
- 🔷 **OPTIONAL**: Examples of expected vs invalid configurations

### 10. Performance Considerations

- 🔷 **OPTIONAL**: Minimize external command calls
- 🔷 **OPTIONAL**: Cache environment loading when possible
- 🔷 **OPTIONAL**: Use efficient pattern matching

## Validation Philosophy

### Minimalistic Validation Approach

- **Fail Fast**: Only validate truly critical prerequisites that would make the test meaningless
- **Sensible Defaults**: Use fallback values for non-critical configuration (e.g., `PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"`)
- **Dedicated Checks**: If validation is complex or super critical, create a separate check script instead of repeating validation logic
- **Folder Scoping**: Use folder structure to define execution scope and user-friendly organization

### Validation Examples

```bash
# ✅ GOOD: Minimalistic validation with defaults
pre_required() {
    # Critical: File must exist for test to be meaningful
    ensure_file "${REPO_ROOT}/.env.lightrag" "test_id" || return 1
    # Non-critical: Use sensible default
    PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"
}

# ❌ BAD: Over-validation that should be separate checks
pre_required() {
    ensure_file "${REPO_ROOT}/.env.lightrag" "test_id" || return 1
    ensure_service_running "lightrag" || return 1
    ensure_network_connectivity || return 1
    ensure_ssl_certificates_valid || return 1  # These should be separate checks!
}

# ✅ BETTER: Create dedicated checks instead
# tests/checks/critical/lightrag-service-running.sh
# tests/checks/critical/network-connectivity.sh  
# tests/checks/critical/ssl-certificates-valid.sh
```

### Folder Execution Patterns

```bash
# Critical checks run first - system must pass these
tests/checks/critical/
├── docker-compose-available.sh
├── environment-files-present.sh
└── network-connectivity.sh

# Category checks run after critical checks pass
tests/checks/communication/
tests/checks/security/
tests/checks/storage/

# Optional checks run last - warnings only
tests/checks/optional/
├── performance-benchmarks.sh
└── monitoring-dashboards.sh
```

## Check Script Template

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# [Specific Test Name] Check
# =============================================================================
# GIVEN: [Prerequisites/context]
# WHEN: [What we inspect/test]  
# THEN: [Expected outcome]
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="test_id"
readonly PASS_MSG="PASS|${TEST_ID}|Success message|verification_command"
readonly FAIL_MSG="FAIL|${TEST_ID}|Failure message|verification_command"
readonly INFO_MSG="INFO|${TEST_ID}|Info message|verification_command"

# GIVEN: Minimalistic validation - fail quickly or use defaults
ensure_file "${REPO_ROOT}/.env.service" "$TEST_ID" || exit 1
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract/gather data - no business logic
CONFIG_VALUE=$(action_get_env "${REPO_ROOT}/.env.service" "CONFIG_VAR")

# THEN: Apply business rules and determine outcome
[[ "$CONFIG_VALUE" == "expected_pattern" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
```

## Quality Evaluation Criteria

### 🔴 CRITICAL FAILURES (Immediate Rejection)

1. **Multiple Responsibilities**: Script tests more than one thing
2. **No Shared Library Usage**: Duplicates existing functionality
3. **Wrong Output Format**: Doesn't follow `STATUS|id|message|command` format
4. **Nested Syntax**: Uses functions, if/else blocks, loops, or any indented code
5. **Missing GIVEN/WHEN/THEN**: Doesn't follow flat linear structure

### 🟡 IMPORTANT ISSUES (Needs Improvement)

1. **Poor Naming**: Filename doesn't clearly indicate test purpose
2. **Weak Error Handling**: Missing prerequisite validation
3. **Hardcoded Values**: Business rules not easily changeable
4. **No Verification Command**: Missing actionable verification steps

### 🟢 QUALITY INDICATORS (Good Practices)

1. **Single Assertion**: Tests exactly one configuration aspect
2. **Flat Structure**: No nested syntax, functions, or indentation - completely linear
3. **Clear GIVEN/WHEN/THEN**: Distinct phases with descriptive comments
4. **Reusable Components**: Uses shared library functions
5. **Descriptive Output**: Clear pass/fail messages with context
6. **Independent Execution**: Can run standalone without dependencies
7. **Appropriate Folder**: Placed in correct folder based on criticality and scope
8. **Minimal Validation**: Only validates truly critical prerequisites, uses defaults otherwise
9. **Clean Constants**: Output messages declared as readonly constants, no inline construction

## Anti-Patterns to Avoid

### ❌ NEVER DO THIS:

```bash
# Nested syntax with functions and indentation
pre_required() {
    if [[ -f "${REPO_ROOT}/.env.service" ]]; then
        return 0
    else
        echo "FAIL|test_id|File missing"
        return 1
    fi
}

action() {
    local value
    if [[ -f "${REPO_ROOT}/.env.service" ]]; then
        value=$(grep "VAR=" "${REPO_ROOT}/.env.service" | cut -d'=' -f2)
        echo "$value"
    fi
}

qualify() {
    local result="$1"
    if [[ "$result" == "expected" ]]; then
        echo "PASS|test_id|Success message|verification_command"
    else
        echo "FAIL|test_id|Failure message|verification_command"
    fi
}

# Function calls and execution
pre_required || exit 1
RESULT=$(action)
qualify "$RESULT"
```

### ✅ DO THIS INSTEAD:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants declared once at the top
readonly TEST_ID="specific_test"
readonly PASS_MSG="PASS|${TEST_ID}|Configuration valid|grep SPECIFIC_VAR .env.service"
readonly FAIL_MSG="FAIL|${TEST_ID}|Configuration invalid|grep SPECIFIC_VAR .env.service"

# GIVEN: Flat validation - no functions, no indentation
ensure_file "${REPO_ROOT}/.env.service" "$TEST_ID" || exit 1
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Flat action - direct execution
CONFIG_VALUE=$(action_get_env "${REPO_ROOT}/.env.service" "SPECIFIC_VAR")

# THEN: Flat qualification - simple conditional
[[ "$CONFIG_VALUE" == "expected_pattern" ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
```

## Validation Checklist

Before submitting a check script, verify:

- [ ] **CRITICAL**: Tests exactly one thing (single responsibility)
- [ ] **CRITICAL**: Uses flat GIVEN/WHEN/THEN structure (no functions, if/else, loops)
- [ ] **CRITICAL**: Uses shared library functions (no duplication)
- [ ] **CRITICAL**: Follows naming convention `{category}-{specific-test}.sh`
- [ ] **CRITICAL**: Outputs correct format `STATUS|id|message|command`
- [ ] **IMPORTANT**: Has clear, descriptive filename
- [ ] **IMPORTANT**: Uses minimalistic validation with sensible defaults
- [ ] **IMPORTANT**: Declares output messages as readonly constants at the top
- [ ] **IMPORTANT**: Provides actionable verification commands
- [ ] **OPTIONAL**: Includes GIVEN/WHEN/THEN documentation
- [ ] **OPTIONAL**: Optimized for performance

## Success Metrics

A high-quality check script should:

1. **Execute in <5 seconds** (performance)
2. **Be <50 lines** including comments (simplicity)
3. **Have zero code duplication** (reusability)
4. **Pass shellcheck linting** (code quality)
5. **Be understandable by new developers** (maintainability)

## Categories and Folder Structure

### Folder-Based Organization

Use multi-level folder nesting to represent logical test depth and developer-friendly organization. **Only script names matter for execution** - folder structure is purely for human organization.

#### Key Principles:
1. **Multi-folder nesting supported** - organize as deep as needed
2. **Script name is the identifier** - folder path is ignored by orchestrator  
3. **Logical depth representation** - nest by configuration layers and dependencies
4. **Developer choice** - organize structure that makes sense for your project

#### Idealistic Checks Structure:

```bash
tests/checks/
├── environment/                          # Level 1: Base configuration
│   ├── files-present.sh                  # Check .env files exist
│   ├── variables-defined.sh              # Check required variables set
│   ├── secrets-configured.sh             # Check API keys, passwords set
│   └── docker-compose/                   # Level 2: Docker compose consumption
│       ├── env-files-mounted.sh          # Check compose mounts env files
│       ├── variables-interpolated.sh     # Check compose uses variables
│       ├── services-defined.sh           # Check all required services present
│       ├── networks-configured.sh        # Check network topology
│       ├── resources/                    # Level 3: Resource requirements
│       │   ├── gpu-access-configured.sh  # Check GPU device mapping
│       │   ├── memory-limits-set.sh      # Check resource constraints
│       │   └── cpu-limits-appropriate.sh # Check CPU allocation
│       ├── storage/                      # Level 3: Storage configuration
│       │   ├── volumes-mounted.sh        # Check volume mappings
│       │   ├── ssl-certs-volume.sh       # Check certificate volumes
│       │   ├── data-persistence.sh       # Check persistent volumes
│       │   └── backup-volumes.sh         # Check backup mount points
│       └── runtime/                      # Level 3: Runtime verification
│           ├── containers-started.sh     # Check containers running
│           ├── health-checks-pass.sh     # Check container health
│           ├── ports-exposed.sh          # Check port mappings
│           ├── storage/                  # Level 4: Runtime storage
│           │   ├── data-persisted.sh     # Check actual data persistence
│           │   ├── backups-created.sh    # Check backup functionality
│           │   └── recovery-works.sh     # Check data recovery
│           ├── performance/              # Level 4: Runtime performance
│           │   ├── response-times.sh     # Check API response times
│           │   ├── memory-usage.sh       # Check memory consumption
│           │   ├── cpu-utilization.sh    # Check CPU usage patterns
│           │   └── throughput-limits.sh  # Check request throughput
│           ├── communication/            # Level 4: Service communication
│           │   ├── cors-headers-sent.sh  # Check CORS headers
│           │   ├── service-discovery.sh  # Check services find each other
│           │   ├── load-balancing.sh     # Check traffic distribution
│           │   └── circuit-breakers.sh   # Check failure handling
│           ├── security/                 # Level 4: Runtime security
│           │   ├── tls-certificates.sh   # Check SSL/TLS active
│           │   ├── auth-tokens-valid.sh  # Check authentication
│           │   ├── access-controls.sh    # Check authorization
│           │   └── secrets-rotation.sh   # Check secret management
│           └── observability/            # Level 4: Monitoring & logging
│               ├── logs-collected.sh     # Check log aggregation
│               ├── metrics-exported.sh   # Check metrics collection
│               ├── traces-captured.sh    # Check distributed tracing
│               └── alerts-configured.sh  # Check alerting rules
├── deployment/                           # Level 1: Deployment verification
│   ├── compose-syntax-valid.sh           # Check YAML syntax
│   ├── images-available.sh               # Check Docker images exist
│   ├── dependencies-resolved.sh          # Check service dependencies
│   └── rollback/                         # Level 2: Rollback capabilities
│       ├── previous-version-kept.sh      # Check version management
│       └── rollback-procedure.sh         # Check rollback works
└── integration/                          # Level 1: End-to-end tests
    ├── user-workflows.sh                 # Check complete user journeys
    ├── data-consistency.sh               # Check cross-service data sync
    └── disaster-recovery/                # Level 2: Disaster scenarios
        ├── service-failure-handling.sh   # Check graceful degradation
        ├── data-corruption-recovery.sh   # Check data recovery
        └── network-partition-handling.sh # Check split-brain scenarios
```

### Supported Categories (Legacy Flat Structure)

- `communication-*` - Service Communication checks
- `security-*` - Security Configuration checks
- `storage-*` - Storage Analysis checks
- `environment-*` - Environment Configuration checks
- `monitoring-*` - Monitoring & Health checks
- `performance-*` - Performance Validation checks

#### Logical Depth Representation

The folder nesting represents the **dependency chain** and **configuration flow**:

1. **Level 1**: Base configuration (files, variables, certificates)
2. **Level 2**: System consumption (docker-compose, service configs)  
3. **Level 3**: Runtime behavior (containers, processes, endpoints)
4. **Level 4+**: Cross-system interactions (service-to-service, external APIs)

**Example Flow**: `environment/docker-compose/runtime/communication/`
- Environment files exist → Docker Compose reads them → Containers get config → Services communicate

### Naming Examples

```bash
# ✅ GOOD: Folder-based organization (script name is key)
environment/files-present.sh                    # Clear, specific
security/tls/endpoints/https-enforced.sh        # Nested by logical depth
storage/connectivity/redis-ping-success.sh      # Dependency-based nesting

# ✅ GOOD: Legacy flat structure (still supported)
communication-cors-lightrag-origins.sh          # Category prefix
security-redis-auth-enabled.sh                  # Clear responsibility

# ❌ BAD: Poor naming regardless of structure
cors-check.sh                                   # Too generic
communication-all-tests.sh                      # Multiple responsibilities  
check-everything.sh                             # No clear purpose
test.sh                                         # Meaningless name
```

## Shared Libraries Reference

### Available Functions

#### From `action-framework.sh`:
- `ensure_file(file_path, test_id)` - Validate file exists
- `action_get_env(file_path, var_name)` - Extract environment variable
- `action_expand_vars(value)` - Expand ${PUBLISH_DOMAIN} variables
- `execute_check(pre_fn, action_fn, qualify_fn)` - Execute APQ pattern

#### From `checks-probes.sh`:
- Various service-specific probe functions
- Container and service validation utilities

## Examples

### Simple Environment Check

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG CORS Origins Check
# =============================================================================
# GIVEN: LightRAG needs CORS origins configured for LobeChat
# WHEN: We inspect CORS_ORIGINS in .env.lightrag
# THEN: We verify LobeChat domain is included in CORS origins
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lightrag_cors_origins"
readonly PASS_MSG="PASS|${TEST_ID}|LobeChat domain in CORS origins|grep CORS_ORIGINS .env.lightrag"
readonly FAIL_MSG="FAIL|${TEST_ID}|LobeChat domain missing from CORS|grep CORS_ORIGINS .env.lightrag"
readonly FAIL_CORS="FAIL|${TEST_ID}|CORS_ORIGINS not configured|grep CORS_ORIGINS .env.lightrag"

# GIVEN: Ensure LightRAG env file exists
ensure_file "${REPO_ROOT}/.env.lightrag" "$TEST_ID" || exit 1
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# WHEN: Extract and expand CORS origins
CORS_ORIGINS=$(action_get_env "${REPO_ROOT}/.env.lightrag" "CORS_ORIGINS")
EXPANDED_CORS=$(action_expand_vars "$CORS_ORIGINS")

# THEN: Verify LobeChat domain is in CORS origins
[[ -n "$EXPANDED_CORS" ]] || { echo "$FAIL_CORS"; exit 1; }
[[ "$EXPANDED_CORS" == *"lobechat.$PUBLISH_DOMAIN"* ]] && echo "$PASS_MSG" || echo "$FAIL_MSG"
```

### Simple Service Mode Check

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LobeChat Service Mode Check
# =============================================================================
# GIVEN: LobeChat can run in server or client mode
# WHEN: We inspect NEXT_PUBLIC_SERVICE_MODE in .env.lobechat
# THEN: We verify service mode is configured (server mode avoids CORS issues)
# =============================================================================

source "${CHECK_TOOLS:-"tests/tools"}/action-framework.sh"

# Constants - declare once, use everywhere
readonly TEST_ID="lobechat_service_mode"
readonly PASS_MSG="PASS|${TEST_ID}|Server mode enabled (avoids CORS)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"
readonly INFO_MSG="INFO|${TEST_ID}|Client mode active (CORS required)|grep NEXT_PUBLIC_SERVICE_MODE .env.lobechat"

# GIVEN: Ensure LobeChat env file exists
ensure_file "${REPO_ROOT}/.env.lobechat" "$TEST_ID" || exit 1

# WHEN: Extract service mode
SERVICE_MODE=$(action_get_env "${REPO_ROOT}/.env.lobechat" "NEXT_PUBLIC_SERVICE_MODE")

# THEN: Verify service mode configuration
[[ "$SERVICE_MODE" == "server" ]] && echo "$PASS_MSG" || echo "$INFO_MSG"
```

## Remember

Think of check scripts as **unit tests** - they should be atomic, focused, fast, and reliable. The orchestrator (`tests/verify.configuration.v3.sh`) handles the complexity of running and reporting multiple checks automatically.

**Key Philosophy**: Each check script should answer exactly one question about the system configuration, and it should answer it clearly and definitively.

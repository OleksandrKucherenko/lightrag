#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Test Framework Validation Check
# =============================================================================
# 
# GIVEN: A comprehensive test framework for LightRAG solution
# WHEN: We validate the test framework components
# THEN: We verify all test components are working correctly
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Check if main test suite exists
if [[ -f "${REPO_ROOT}/tests/test.suite.sh" ]]; then
    if [[ -x "${REPO_ROOT}/tests/test.suite.sh" ]]; then
        echo "PASS|test_framework|Main test suite available and executable|ls -la tests/test.suite.sh"
    else
        echo "FAIL|test_framework|Main test suite not executable|chmod +x tests/test.suite.sh"
    fi
else
    echo "BROKEN|test_framework|Main test suite not found|ls tests/test.suite.sh"
fi

# Check if modular checks directory exists
if [[ -d "${REPO_ROOT}/tests/checks" ]]; then
    check_count=$(find "${REPO_ROOT}/tests/checks" -name "*.sh" -type f | wc -l)
    if [[ "$check_count" -gt 0 ]]; then
        echo "PASS|test_framework|Modular checks directory with $check_count scripts|ls tests/checks/*.sh"
    else
        echo "FAIL|test_framework|Modular checks directory empty|ls tests/checks/"
    fi
else
    echo "BROKEN|test_framework|Modular checks directory not found|ls tests/checks/"
fi

# Check if main orchestrator exists
if [[ -f "${REPO_ROOT}/tests/verify.configuration.v3.sh" ]]; then
    if [[ -x "${REPO_ROOT}/tests/verify.configuration.v3.sh" ]]; then
        echo "PASS|test_framework|Configuration verification orchestrator available|ls -la tests/verify.configuration.v3.sh"
    else
        echo "FAIL|test_framework|Configuration verification orchestrator not executable|chmod +x tests/verify.configuration.v3.sh"
    fi
else
    echo "BROKEN|test_framework|Configuration verification orchestrator not found|ls tests/verify.configuration.v3.sh"
fi

# Check if deprecated files were moved
if [[ -d "${REPO_ROOT}/.deprecated/tests" ]]; then
    deprecated_count=$(find "${REPO_ROOT}/.deprecated/tests" -name "*.sh" -type f | wc -l)
    echo "INFO|test_framework|Deprecated test files moved: $deprecated_count files|ls .deprecated/tests/"
else
    echo "INFO|test_framework|No deprecated tests directory found|ls .deprecated/tests/"
fi

# Validate individual check scripts format
error_count=0
for check_script in "${REPO_ROOT}/tests/checks"/*.sh; do
    [[ -f "$check_script" ]] || continue
    
    script_name=$(basename "$check_script" .sh)
    
    # Check if script is executable
    if [[ ! -x "$check_script" ]]; then
        echo "FAIL|test_framework|Check script not executable: $script_name|chmod +x $check_script"
        ((error_count++))
        continue
    fi
    
    # Check if script has proper shebang
    if ! head -1 "$check_script" | grep -q "#!/usr/bin/env bash"; then
        echo "FAIL|test_framework|Check script missing proper shebang: $script_name|head -1 $check_script"
        ((error_count++))
        continue
    fi
    
    # Check if script has GIVEN/WHEN/THEN comments
    if ! grep -q "# GIVEN:" "$check_script" || ! grep -q "# WHEN:" "$check_script" || ! grep -q "# THEN:" "$check_script"; then
        echo "FAIL|test_framework|Check script missing GIVEN/WHEN/THEN structure: $script_name|grep 'GIVEN\\|WHEN\\|THEN' $check_script"
        ((error_count++))
        continue
    fi
done

if [[ "$error_count" -eq 0 ]]; then
    echo "PASS|test_framework|All individual check scripts properly formatted|find tests/checks/ -name '*.sh' -exec grep -l 'GIVEN\\|WHEN\\|THEN' {} \\;"
else
    echo "FAIL|test_framework|$error_count check scripts have formatting issues|find tests/checks/ -name '*.sh'"
fi

#!/usr/bin/env bash
# =============================================================================
# Action Framework for LightRAG Check Scripts
# =============================================================================
# Shared functions for check scripts to ensure consistency and reduce duplication
# =============================================================================

set -Eeuo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# ensure_file - Validate that a file exists
# Args: file_path, test_id
# Returns: 0 if file exists, exits with error message if not
ensure_file() {
    local file_path="$1"
    local test_id="$2"

    if [[ ! -f "$file_path" ]]; then
        echo "BROKEN|${test_id}|Required file not found: $file_path|ls -la \"$file_path\""
        exit 1
    fi
}

# action_get_env - Extract environment variable from file
# Args: file_path, var_name
# Returns: variable value or empty string if not found
action_get_env() {
    local file_path="$1"
    local var_name="$2"

    if [[ ! -f "$file_path" ]]; then
        echo ""
        return
    fi

    local value
    value=$(grep "^${var_name}=" "$file_path" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//' || echo "")
    echo "$value"
}

# action_expand_vars - Expand ${VAR} variables in a string
# Args: input_string
# Returns: string with variables expanded
action_expand_vars() {
    local input="$1"

    # Expand PUBLISH_DOMAIN if present
    local result="${input//\$\{PUBLISH_DOMAIN\}/${PUBLISH_DOMAIN:-dev.localhost}}"
    result="${result//\$PUBLISH_DOMAIN/${PUBLISH_DOMAIN:-dev.localhost}}"

    echo "$result"
}

# clean_output - Remove newlines and carriage returns from command output
# Args: input_string
# Returns: cleaned string
clean_output() {
    local input="$1"
    echo "$input" | tr -d '\n\r'
}

# execute_check - Execute a check with pre/action/qualify pattern (for complex checks)
# Args: pre_fn, action_fn, qualify_fn
# Note: This is for future use if needed, but prefer flat structure
execute_check() {
    local pre_fn="$1"
    local action_fn="$2"
    local qualify_fn="$3"

    # This function exists for backward compatibility
    # Prefer flat GIVEN/WHEN/THEN structure in new scripts
    echo "INFO|framework|execute_check is deprecated - use flat structure|echo 'Use flat GIVEN/WHEN/THEN pattern'"
}
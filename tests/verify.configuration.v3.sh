#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# LightRAG Configuration Verification Orchestrator v3.0
# =============================================================================
# 
# This script runs all individual check scripts and aggregates results
# into a user-friendly report. Each check script does one specific thing.
# 
# Architecture:
# - tests/checks/*.sh - Individual check scripts
# - This script - Orchestrator that runs all checks and formats output
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"

# Colors for output
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  COLOR_RESET="$(tput sgr0)"
  COLOR_GREEN="$(tput setaf 2)"
  COLOR_YELLOW="$(tput setaf 3)"
  COLOR_BLUE="$(tput setaf 4)"
  COLOR_RED="$(tput setaf 1)"
  COLOR_GRAY="$(tput setaf 8)"
else
  COLOR_RESET="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_BLUE="" COLOR_RED="" COLOR_GRAY=""
fi

# Result tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
INFO_CHECKS=0
FAILED_CHECKS=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_section() {
  printf "\n%s=== %s ===%s\n" "${COLOR_BLUE}" "$1" "${COLOR_RESET}"
}

load_env_files() {
  local env_files=(".env" ".env.databases" ".env.lightrag" ".env.lobechat" ".env.monitoring")
  
  for file in "${env_files[@]}"; do
    local filepath="${REPO_ROOT}/${file}"
    [[ -r "$filepath" ]] || continue
    
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "${line}" =~ ^\s*# ]] && continue
      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        # Remove quotes
        value="${value%\"}" && value="${value#\"}"
        value="${value%\'}" && value="${value#\'}"
        # Only export if not already defined
        [[ -z "${!key+x}" ]] && export "$key=$value"
      fi
    done < "$filepath"
  done
}

format_result() {
  local status="$1" check="$2" message="$3" command="${4:-}"
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  case "$status" in
    "ENABLED"|"PASS")
      printf "[%s✓%s] %s: %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      ;;
    "DISABLED"|"INFO")
      printf "[%sℹ%s] %s: %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      INFO_CHECKS=$((INFO_CHECKS + 1))
      ;;
    "BROKEN"|"FAIL")
      printf "[%s✗%s] %s: %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$check" "$message"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      ;;
    *)
      printf "[%s?%s] %s: %s (unknown status: %s)\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$check" "$message" "$status"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      ;;
  esac
}

is_wsl2() {
  [[ -f "/proc/version" ]] && grep -q "microsoft" "/proc/version" 2>/dev/null
}

run_check_script() {
  local script_path="$1"
  local script_name script_ext
  script_name=$(basename "$script_path")
  script_ext="${script_name##*.}"
  
  # Handle different script types
  case "$script_ext" in
    "sh")
      run_bash_script "$script_path"
      ;;
    "ps1")
      run_powershell_script "$script_path"
      ;;
    "cmd"|"bat")
      run_cmd_script "$script_path"
      ;;
    *)
      format_result "BROKEN" "${script_name%.*}" "Unsupported script type: $script_ext" "file $script_path"
      return 1
      ;;
  esac
}

run_bash_script() {
  local script_path="$1"
  local script_name
  script_name=$(basename "$script_path" .sh)
  
  # Check if script exists and is executable
  if [[ ! -f "$script_path" ]]; then
    format_result "BROKEN" "$script_name" "Check script not found" "ls $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    chmod +x "$script_path" 2>/dev/null || {
      format_result "BROKEN" "$script_name" "Check script not executable" "chmod +x $script_path"
      return 1
    }
  fi
  
  # Run the check script and parse output
  local output
  if output=$("$script_path" 2>&1); then
    # Parse each line of output (some scripts may output multiple results)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      
      # Parse the standard format: STATUS|CHECK_NAME|MESSAGE|COMMAND
      if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
        local status="${BASH_REMATCH[1]}"
        local check="${BASH_REMATCH[2]}"
        local message="${BASH_REMATCH[3]}"
        local command="${BASH_REMATCH[5]:-}"
        
        format_result "$status" "$check" "$message" "$command"
      else
        # Handle non-standard output
        format_result "BROKEN" "$script_name" "Invalid output format: $line" "$script_path"
      fi
    done <<< "$output"
  else
    format_result "BROKEN" "$script_name" "Check script failed to execute: ${output:0:100}" "$script_path"
    return 1
  fi
}

run_powershell_script() {
  local script_path="$1"
  local script_name
  script_name=$(basename "$script_path" .ps1)
  
  # Check if we're in WSL2
  if ! is_wsl2; then
    format_result "INFO" "$script_name" "PowerShell script skipped - not in WSL2 environment" "uname -r"
    return 0
  fi
  
  # Check if PowerShell is available
  if ! command -v powershell.exe >/dev/null 2>&1; then
    format_result "BROKEN" "$script_name" "PowerShell not available in WSL2" "which powershell.exe"
    return 1
  fi
  
  # Check if script exists
  if [[ ! -f "$script_path" ]]; then
    format_result "BROKEN" "$script_name" "PowerShell script not found" "ls $script_path"
    return 1
  fi
  
  # Convert WSL path to Windows path
  local windows_path
  if windows_path=$(wslpath -w "$script_path" 2>/dev/null); then
    # Run PowerShell script and parse output
    local output
    if output=$(powershell.exe -ExecutionPolicy Bypass -File "$windows_path" 2>&1); then
      # Parse each line of output
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Remove Windows line endings
        line="${line%$'\r'}"
        
        # Parse the standard format: STATUS|CHECK_NAME|MESSAGE|COMMAND
        if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
          local status="${BASH_REMATCH[1]}"
          local check="${BASH_REMATCH[2]}"
          local message="${BASH_REMATCH[3]}"
          local command="${BASH_REMATCH[5]:-}"
          
          format_result "$status" "$check" "$message" "$command"
        else
          # Handle non-standard output
          format_result "BROKEN" "$script_name" "Invalid output format: $line" "powershell.exe -File $windows_path"
        fi
      done <<< "$output"
    else
      format_result "BROKEN" "$script_name" "PowerShell script failed: ${output:0:100}" "powershell.exe -File $windows_path"
      return 1
    fi
  else
    format_result "BROKEN" "$script_name" "Cannot convert WSL path to Windows path" "wslpath -w $script_path"
    return 1
  fi
}

run_cmd_script() {
  local script_path="$1"
  local script_name script_ext
  script_ext="${script_path##*.}"
  script_name=$(basename "$script_path" ".$script_ext")
  
  # Check if we're in WSL2
  if ! is_wsl2; then
    format_result "INFO" "$script_name" "CMD script skipped - not in WSL2 environment" "uname -r"
    return 0
  fi
  
  # Check if cmd.exe is available
  if ! command -v cmd.exe >/dev/null 2>&1; then
    format_result "BROKEN" "$script_name" "CMD not available in WSL2" "which cmd.exe"
    return 1
  fi
  
  # Check if script exists
  if [[ ! -f "$script_path" ]]; then
    format_result "BROKEN" "$script_name" "CMD script not found" "ls $script_path"
    return 1
  fi
  
  # Convert WSL path to Windows path
  local windows_path
  if windows_path=$(wslpath -w "$script_path" 2>/dev/null); then
    # Run CMD script and parse output
    local output
    if output=$(cmd.exe /c "$windows_path" 2>&1); then
      # Parse each line of output
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Remove Windows line endings
        line="${line%$'\r'}"
        
        # Parse the standard format: STATUS|CHECK_NAME|MESSAGE|COMMAND
        if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
          local status="${BASH_REMATCH[1]}"
          local check="${BASH_REMATCH[2]}"
          local message="${BASH_REMATCH[3]}"
          local command="${BASH_REMATCH[5]:-}"
          
          format_result "$status" "$check" "$message" "$command"
        else
          # Handle non-standard output
          format_result "BROKEN" "$script_name" "Invalid output format: $line" "cmd.exe /c $windows_path"
        fi
      done <<< "$output"
    else
      format_result "BROKEN" "$script_name" "CMD script failed: ${output:0:100}" "cmd.exe /c $windows_path"
      return 1
    fi
  else
    format_result "BROKEN" "$script_name" "Cannot convert WSL path to Windows path" "wslpath -w $script_path"
    return 1
  fi
}

run_category_checks() {
  local category="$1"
  local pattern="$2"
  
  log_section "$category"
  
  # Find all scripts matching the pattern (bash, PowerShell, CMD)
  local scripts=()
  while IFS= read -r -d '' script; do
    scripts+=("$script")
  done < <(find "$CHECKS_DIR" \( -name "${pattern}-*.sh" -o -name "${pattern}-*.ps1" -o -name "${pattern}-*.cmd" -o -name "${pattern}-*.bat" \) -type f -print0 2>/dev/null | sort -z)
  
  if [[ ${#scripts[@]} -eq 0 ]]; then
    printf "  No checks found for pattern: %s\n" "$pattern"
    return
  fi
  
  for script_path in "${scripts[@]}"; do
    run_check_script "$script_path"
  done
}

# Group definitions with user-friendly names
declare -A GROUP_NAMES=(
  ["security"]="Security Configuration"
  ["storage"]="Storage Analysis"
  ["communication"]="Service Communication"
  ["environment"]="Environment Configuration"
  ["monitoring"]="Monitoring & Health"
  ["performance"]="Performance Validation"
  ["wsl2"]="WSL2 Windows Integration"
)

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  printf "%sLightRAG Configuration Verification v3.0%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
  printf "Domain: %s\n" "${PUBLISH_DOMAIN:-dev.localhost}"
  printf "Checks Directory: %s\n" "$CHECKS_DIR"
  
  # Load environment variables
  load_env_files
  
  # Check if any services are running
  if ! docker compose ps >/dev/null 2>&1; then
    printf "%sWARNING: Docker Compose not running or not accessible%s\n" "${COLOR_YELLOW}" "${COLOR_RESET}"
    printf "Some checks may fail. Consider running: docker compose up -d\n"
  fi
  
  # Run checks by category - automatically discover based on filename patterns
  run_category_checks "${GROUP_NAMES[security]}" "security"
  run_category_checks "${GROUP_NAMES[storage]}" "storage"
  run_category_checks "${GROUP_NAMES[communication]}" "communication"
  run_category_checks "${GROUP_NAMES[environment]}" "environment"
  run_category_checks "${GROUP_NAMES[monitoring]}" "monitoring"
  run_category_checks "${GROUP_NAMES[performance]}" "performance"
  run_category_checks "${GROUP_NAMES[wsl2]}" "wsl2"
  
  # Summary
  log_section "Configuration Summary"
  printf "Total Checks: %d\n" "$TOTAL_CHECKS"
  printf "%s✓ Passed/Enabled: %d%s\n" "${COLOR_GREEN}" "$PASSED_CHECKS" "${COLOR_RESET}"
  printf "%sℹ Info/Disabled: %d%s\n" "${COLOR_BLUE}" "$INFO_CHECKS" "${COLOR_RESET}"
  printf "%s✗ Failed/Broken: %d%s\n" "${COLOR_RED}" "$FAILED_CHECKS" "${COLOR_RESET}"
  
  # Configuration state summary
  printf "\n%sConfiguration State:%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
  
  # Determine overall security posture
  if [[ "$FAILED_CHECKS" -eq 0 ]]; then
    if [[ "$PASSED_CHECKS" -gt "$INFO_CHECKS" ]]; then
      printf "🔒 Security-focused configuration (most features enabled)\n"
    else
      printf "🔓 Development configuration (most features disabled)\n"
    fi
    printf "✅ All systems operational\n"
  else
    printf "⚠️  Issues detected - %d checks failed\n" "$FAILED_CHECKS"
    printf "🔧 Review failed checks and run suggested commands\n"
  fi
  
  # Exit with error if any checks failed
  [[ "$FAILED_CHECKS" -eq 0 ]] && exit 0 || exit 1
}

# Handle command line arguments
case "${1:-}" in
  --help|-h)
    printf "Usage: %s [options]\n" "$(basename "$0")"
    printf "\nOptions:\n"
    printf "  --help, -h     Show this help message\n"
    printf "  --list         List available check scripts\n"
    printf "\nEnvironment:\n"
    printf "  PUBLISH_DOMAIN Domain for external endpoints (default: dev.localhost)\n"
    printf "\nCheck Scripts Location: %s\n" "$CHECKS_DIR"
    exit 0
    ;;
  --list)
    printf "Available check scripts (grouped by pattern):\n\n"
    if [[ -d "$CHECKS_DIR" ]]; then
      # Group by pattern
      for group in security storage communication environment monitoring performance wsl2; do
        local group_name="${GROUP_NAMES[$group]:-$group}"
        local scripts=()
        while IFS= read -r -d '' script; do
          local script_name=$(basename "$script")
          scripts+=("$script_name")
        done < <(find "$CHECKS_DIR" \( -name "${group}-*.sh" -o -name "${group}-*.ps1" -o -name "${group}-*.cmd" -o -name "${group}-*.bat" \) -type f -print0 2>/dev/null | sort -z)
        
        if [[ ${#scripts[@]} -gt 0 ]]; then
          printf "%s:\n" "$group_name"
          for script in "${scripts[@]}"; do
            printf "  %s\n" "$script"
          done
          printf "\n"
        fi
      done
    else
      printf "  No checks directory found: %s\n" "$CHECKS_DIR"
    fi
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac

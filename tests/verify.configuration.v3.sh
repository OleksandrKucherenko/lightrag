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
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MO_TOOL="${SCRIPT_DIR}/tools/mo.sh"

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

# Timeout configuration
CHECK_TIMEOUT="${CHECK_TIMEOUT:-30}"  # Timeout in seconds for each individual check (can be overridden via environment)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_section() {
  printf "\n%s=== %s ===%s\n" "${COLOR_BLUE}" "$1" "${COLOR_RESET}"
}

current_timestamp() {
  date +%s.%N
}

elapsed_time() {
  local start="$1"
  local end="$2"
  awk -v start="$start" -v end="$end" 'BEGIN {
    diff = end - start;
    if (diff < 0) {
      diff = 0;
    }
    printf "%.6f", diff;
  }'
}

format_duration_label() {
  local duration="$1"
  local formatted
  formatted=$(awk -v value="$duration" 'BEGIN { printf "%.2f", value }')

  local color="$COLOR_GREEN"
  if awk -v value="$duration" 'BEGIN { exit !(value > 5) }'; then
    color="$COLOR_RED"
  elif awk -v value="$duration" 'BEGIN { exit !(value >= 1 && value <= 5) }'; then
    color="$COLOR_YELLOW"
  fi

  printf "taken: %s%s s%s" "$color" "$formatted" "$COLOR_RESET"
}

# Helper function to copy script to Windows temp folder and return Windows path
copy_to_windows_temp() {
  local script_path="$1"
  local script_name
  script_name=$(basename "$script_path")
  
  # Get Windows temp directory
  local windows_temp
  if ! windows_temp=$(cmd.exe /c "echo %TEMP%" 2>/dev/null | tr -d '\r'); then
    echo "ERROR: Cannot get Windows temp directory" >&2
    return 1
  fi
  
  # Convert to WSL path for copying
  local wsl_temp_path
  if ! wsl_temp_path=$(wslpath "$windows_temp" 2>/dev/null); then
    echo "ERROR: Cannot convert Windows temp path to WSL path" >&2
    return 1
  fi
  
  # Copy script to Windows temp folder
  local temp_script_path="${wsl_temp_path}/${script_name}"
  if ! cp "$script_path" "$temp_script_path" 2>/dev/null; then
    echo "ERROR: Cannot copy script to Windows temp folder" >&2
    return 1
  fi
  
  # Return Windows path to the copied script
  echo "${windows_temp}\\${script_name}"
  return 0
}

# Timeout wrapper function
run_with_timeout() {
  local timeout_duration="$1"
  shift
  local script_name="$1"
  shift
  
  # Create a temporary file for the output
  local temp_output
  temp_output=$(mktemp)
  local temp_status
  temp_status=$(mktemp)
  
  # Run command in background with timeout
  (
    "$@" > "$temp_output" 2>&1
    echo $? > "$temp_status"
  ) &
  
  local pid=$!
  local timeout_occurred=false
  local start_epoch
  start_epoch=$(date +%s)
  
  # Wait for completion or timeout
  while kill -0 "$pid" 2>/dev/null; do
    local now_epoch
    now_epoch=$(date +%s)
    if (( now_epoch - start_epoch >= timeout_duration )); then
      timeout_occurred=true
      kill -TERM "$pid" 2>/dev/null
      sleep 1
      kill -KILL "$pid" 2>/dev/null
      break
    fi
    sleep 0.1
  done
  
  # Wait for process to finish
  wait "$pid" 2>/dev/null || true
  
  # Handle timeout
  if [[ "$timeout_occurred" == true ]]; then
    echo "BROKEN|${script_name}_timeout|Check timed out after ${timeout_duration} seconds|timeout ${timeout_duration}s $*"
    rm -f "$temp_output" "$temp_status"
    return 1
  fi
  
  # Get the exit status and output
  local exit_status=0
  if [[ -f "$temp_status" ]]; then
    exit_status=$(cat "$temp_status")
  fi
  
  if [[ -f "$temp_output" ]]; then
    cat "$temp_output"
  fi
  
  rm -f "$temp_output" "$temp_status"
  return "$exit_status"
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

# =============================================================================
# BASH-BASED TEMPLATE GENERATION FUNCTIONS (replaces Python usage)
# =============================================================================

parse_tdd_sections() {
  local description="$1"
  local given="" when="" then=""

  # Split description by TDD keywords (case insensitive)
  local parts
  IFS=$'\n' read -r -d '' -a parts <<< "$(echo "$description" | grep -oP '(?i)(GIVEN|WHEN|THEN).*?(?=(?i)(GIVEN|WHEN|THEN|$))' || echo "$description")"

  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^[Gg][Ii][Vv][Ee][Nn] ]]; then
      given="${part#*:}"
      given="${given#"${given%%[![:space:]]*}"}"  # trim leading whitespace
    elif [[ "$part" =~ ^[Ww][Hh][Ee][Nn] ]]; then
      when="${part#*:}"
      when="${when#"${when%%[![:space:]]*}"}"
    elif [[ "$part" =~ ^[Tt][Hh][Ee][Nn] ]]; then
      then="${part#*:}"
      then="${then#"${then%%[![:space:]]*}"}"
    fi
  done

  # If no TDD sections found, treat whole description as THEN
  if [[ -z "$given" && -z "$when" && -z "$then" ]]; then
    then="$description"
  fi

  echo "$given|$when|$then"
}

infer_group_from_description() {
  local description="$1"
  local groups=("security" "storage" "communication" "environment" "monitoring" "performance" "wsl2")

  for group in "${groups[@]}"; do
    if echo "$description" | grep -qi "\\b$group\\b"; then
      echo "$group"
      return 0
    fi
  done

  echo ""
}

infer_service_and_test() {
  local description="$1" group="$2"
  local service="" test_name=""

  # Remove TDD guidance to focus on summary
  local summary
  summary="$(echo "$description" | sed 's/[Gg][Ii][Vv][Ee][Nn].*//;s/[Ww][Hh][Ee][Nn].*//;s/[Tt][Hh][Ee][Nn].*//' | head -1)"

  # Pattern 1: "for redis authentication"
  if [[ "$summary" =~ for[[:space:]]+([a-z0-9][a-z0-9_-]*)([[:space:]]+([a-z0-9][a-z0-9_-]*))? ]]; then
    service="$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
    if [[ -n "${BASH_REMATCH[3]}" ]]; then
      test_name="$(echo "${BASH_REMATCH[3]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
    fi
  fi

  # Pattern 2: group + service ("security redis authentication")
  if [[ -z "$service" && -n "$group" ]]; then
    if [[ "$summary" =~ $group[[:space:]]+([a-z0-9][a-z0-9_-]*)([[:space:]]+([a-z0-9][a-z0-9_-]*))? ]]; then
      service="$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
      if [[ -n "${BASH_REMATCH[3]}" ]]; then
        test_name="$(echo "${BASH_REMATCH[3]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
      fi
    fi
  fi

  # Fallback: word after "for"
  if [[ -z "$service" ]]; then
    if [[ "$summary" =~ for[[:space:]]+([a-z0-9][a-z0-9_-]*) ]]; then
      service="$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
    fi
  fi

  # Look for verbs to derive test name
  if [[ -z "$test_name" ]]; then
    if [[ "$summary" =~ \b(ensure|verify|validate|confirm|check)\b[[:space:]]+([a-z0-9][a-z0-9_-]*[[:space:]]*[a-z0-9_-]*) ]]; then
      test_name="$(echo "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr ' ' '-')"
    fi
  fi

  echo "$service|$test_name"
}

slugify() {
  local value="$1"
  value="$(echo "$value" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')"
  echo "$value"
}

title_case() {
  local result=""
  for word in "$@"; do
    if [[ -n "$word" ]]; then
      result="$result $(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')$(echo "${word:1}" | tr '[:upper:]' '[:lower:]')"
    fi
  done
  echo "${result#"${result%%[![:space:]]*}"}"  # trim leading space
}

ensure_mo_tool() {
  if [[ ! -f "$MO_TOOL" ]]; then
    printf "ERROR: MO template tool not found at %s\n" "$MO_TOOL" >&2
    return 1
  fi

  if [[ ! -x "$MO_TOOL" ]]; then
    chmod +x "$MO_TOOL" 2>/dev/null || true
  fi

  return 0
}

generate_check_with_mo() {
  local description="$1" group="$2" service="$3" test_name="$4" script_type="$5" template_id="$6" output_dir="$7" force="$8"

  # Parse TDD sections
  local tdd_parts
  IFS='|' read -r given when then <<< "$(parse_tdd_sections "$description")"

  # Infer missing values
  if [[ -z "$group" ]]; then
    group="$(infer_group_from_description "$description")"
  fi

  if [[ -z "$service" || -z "$test_name" ]]; then
    local inferred
    IFS='|' read -r inf_service inf_test <<< "$(infer_service_and_test "$description" "$group")"
    service="${service:-$inf_service}"
    test_name="${test_name:-$inf_test}"
  fi

  # Validate required values
  if [[ -z "$group" || -z "$service" || -z "$test_name" ]]; then
    printf "ERROR: Could not determine group, service, or test name from description\n" >&2
    printf "Please provide explicit --group, --service, and --test parameters\n" >&2
    return 1
  fi

  # Select template
  if [[ -z "$template_id" ]]; then
    case "$script_type" in
      bash) template_id="bash_default" ;;
      powershell) template_id="powershell_default" ;;
      cmd) template_id="cmd_default" ;;
      *) template_id="bash_default" ;;
    esac
  fi

  # Find template file
  local template_path=""
  case "$template_id" in
    bash_default) template_path="$TEMPLATES_DIR/bash/default.sh.tpl" ;;
    powershell_default) template_path="$TEMPLATES_DIR/powershell/default.ps1.tpl" ;;
    cmd_default) template_path="$TEMPLATES_DIR/cmd/default.cmd.tpl" ;;
    *) printf "ERROR: Unknown template_id: %s\n" "$template_id" >&2; return 1 ;;
  esac

  if [[ ! -f "$template_path" ]]; then
    printf "ERROR: Template file not found: %s\n" "$template_path" >&2
    return 1
  fi

  # Determine extension
  local extension=""
  case "$template_id" in
    bash_default) extension="sh" ;;
    powershell_default) extension="ps1" ;;
    cmd_default) extension="cmd" ;;
  esac

  # Generate check ID and filename
  local check_id="${group}_${service}_${test_name}"
  local filename="${group}-${service}-${test_name}.${extension}"
  local output_path="${output_dir:-$CHECKS_DIR}/$filename"

  # Check if file exists
  if [[ -f "$output_path" && "$force" != "true" ]]; then
    printf "ERROR: Check file already exists: %s\n" "$output_path" >&2
    printf "Use --force to overwrite\n" >&2
    return 1
  fi

  # Generate title
  local title
  title="$(title_case "$group" "$service" "$test_name")"

  # Determine command hint
  local command_hint=""
  case "$script_type" in
    bash) command_hint="replace_with_command" ;;
    powershell) command_hint="Replace-With-Command" ;;
    cmd) command_hint="REPLACE_WITH_COMMAND" ;;
  esac

  # Set environment variables for MO
  export TITLE="$title"
  export GIVEN="$given"
  export WHEN="$when"
  export THEN="$then"
  export CHECK_ID="$check_id"
  export COMMAND_HINT="$command_hint"

  # Render template with MO
  local rendered
  if ! rendered="$("$MO_TOOL" "$template_path" 2>/dev/null)"; then
    printf "ERROR: Failed to render template with MO\n" >&2
    return 1
  fi

  # Write output file
  mkdir -p "$(dirname "$output_path")"
  echo "$rendered" > "$output_path"

  # Make executable if bash script
  if [[ "$extension" == "sh" ]]; then
    chmod +x "$output_path"
  fi

  # Output result
  printf "Generated check: %s\n" "$filename"
  printf "  Template: %s\n" "$template_id"
  printf "  Group   : %s\n" "$group"
  printf "  Service : %s\n" "$service"
  printf "  Test    : %s\n" "$test_name"
  printf "  Reminder: Update the placeholder logic before running the orchestrator.\n"

  return 0
}



print_check_help() {
  cat <<'EOF'
/check command usage:

  ./tests/verify.configuration.v3.sh /check "Security Redis authentication check. GIVEN: ... WHEN: ... THEN: ..."

Supported options:
  --description, -d   Explicit natural language description (GIVEN/WHEN/THEN)
  --group             Override detected group (security, storage, ...)
  --service           Override detected service name
  --test              Override detected test name
  --script-type       Preferred script type (bash, powershell, cmd)
  --template-id       Use a specific template id from the registry
  --interactive       Prompt for missing information
  --dry-run           Print generated script without writing to disk
  --force             Overwrite existing check file if it already exists
  --output-dir        Target directory (defaults to tests/checks)
  --json              Emit metadata as JSON to stdout
  --metadata          Path to store metadata JSON alongside the generated check

Additional helpers:
  ./tests/verify.configuration.v3.sh --list-templates
  ./tests/verify.configuration.v3.sh --validate-templates
EOF
}

handle_check_command() {
  local subcommand="${1:-}"
  shift || true

  ensure_mo_tool || return 1

  local description=""
  local group=""
  local service=""
  local test_name=""
  local script_type="bash"
  local template_id=""
  local output_dir="$CHECKS_DIR"
  local force="false"
  local dry_run="false"
  local interactive="false"
  local json="false"
  local metadata=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_check_help
        return 0
        ;;
      --description|-d)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --description requires a value.\n" >&2
          return 1
        fi
        description="$1"
        shift
        ;;
      --group)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --group requires a value.\n" >&2
          return 1
        fi
        group="$(slugify "$1")"
        shift
        ;;
      --service)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --service requires a value.\n" >&2
          return 1
        fi
        service="$(slugify "$1")"
        shift
        ;;
      --test)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --test requires a value.\n" >&2
          return 1
        fi
        test_name="$(slugify "$1")"
        shift
        ;;
      --script-type)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --script-type requires a value.\n" >&2
          return 1
        fi
        script_type="$1"
        shift
        ;;
      --template-id)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --template-id requires a value.\n" >&2
          return 1
        fi
        template_id="$1"
        shift
        ;;
      --output-dir)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --output-dir requires a value.\n" >&2
          return 1
        fi
        output_dir="$1"
        shift
        ;;
      --metadata)
        shift
        if [[ $# -eq 0 ]]; then
          printf "ERROR: --metadata requires a value.\n" >&2
          return 1
        fi
        metadata="$1"
        shift
        ;;
      --force)
        force="true"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --interactive)
        interactive="true"
        shift
        ;;
      --json)
        json="true"
        shift
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          if [[ -z "$description" ]]; then
            description="$1"
          else
            printf "WARNING: Ignoring extra argument '%s' for /check command.\n" "$1" >&2
          fi
          shift
        done
        break
        ;;
      -*)
        printf "ERROR: Unknown /check option: %s\n" "$1" >&2
        return 1
        ;;
      *)
        if [[ -z "$description" ]]; then
          description="$1"
        else
          printf "WARNING: Ignoring extra argument '%s' for /check command.\n" "$1" >&2
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$description" ]]; then
    printf "ERROR: Description is required for check generation.\n" >&2
    printf "Use --description or provide it as the first argument.\n" >&2
    return 1
  fi

  # For now, skip unsupported features
  if [[ "$dry_run" == "true" ]]; then
    printf "ERROR: --dry-run not yet implemented in bash version.\n" >&2
    return 1
  fi

  if [[ "$interactive" == "true" ]]; then
    printf "ERROR: --interactive not yet implemented in bash version.\n" >&2
    return 1
  fi

  if [[ "$json" == "true" ]]; then
    printf "ERROR: --json not yet implemented in bash version.\n" >&2
    return 1
  fi

  if [[ -n "$metadata" ]]; then
    printf "ERROR: --metadata not yet implemented in bash version.\n" >&2
    return 1
  fi

  generate_check_with_mo "$description" "$group" "$service" "$test_name" "$script_type" "$template_id" "$output_dir" "$force"
  return $?
}

handle_list_templates() {
  local registry_file="$TEMPLATES_DIR/registry.json"

  if [[ ! -f "$registry_file" ]]; then
    printf "ERROR: Template registry not found: %s\n" "$registry_file" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf "ERROR: jq is required for template listing\n" >&2
    return 1
  fi

  local version
  version="$(jq -r '.version' "$registry_file")"

  printf "Template registry version: %s\n" "$version"

  # Process each template
  local template_count
  template_count="$(jq '.templates | length' "$registry_file")"

  for ((i=0; i<template_count; i++)); do
    local id label description script_type extension path categories placeholders

    id="$(jq -r ".templates[$i].id" "$registry_file")"
    label="$(jq -r ".templates[$i].label // \"$id\"" "$registry_file")"
    description="$(jq -r ".templates[$i].description // empty" "$registry_file")"
    script_type="$(jq -r ".templates[$i].script_type" "$registry_file")"
    extension="$(jq -r ".templates[$i].extension" "$registry_file")"
    path="$(jq -r ".templates[$i].path" "$registry_file")"

    categories="$(jq -r ".templates[$i].categories | join(\", \")" "$registry_file")"
    placeholders="$(jq -r ".templates[$i].placeholders | join(\", \")" "$registry_file")"

    printf "\nID: %s\n" "$id"
    printf "  Label      : %s\n" "$label"
    if [[ -n "$description" ]]; then
      printf "  Description: %s\n" "$description"
    fi
    printf "  Script Type: %s (.%s)\n" "$script_type" "$extension"
    printf "  Path       : %s\n" "$path"
    printf "  Categories : %s\n" "${categories:-(all)}"
    printf "  Placeholders: %s\n" "$placeholders"
  done
}

handle_validate_templates() {
  local registry_file="$TEMPLATES_DIR/registry.json"

  if [[ ! -f "$registry_file" ]]; then
    printf "ERROR: Template registry not found: %s\n" "$registry_file" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf "ERROR: jq is required for template validation\n" >&2
    return 1
  fi

  local had_issue=false
  local required_placeholders=("TITLE" "GIVEN" "WHEN" "THEN" "CHECK_ID" "COMMAND_HINT")

  # Process each template
  local template_count
  template_count="$(jq '.templates | length' "$registry_file")"

  for ((i=0; i<template_count; i++)); do
    local id path template_path issues=()

    id="$(jq -r ".templates[$i].id" "$registry_file")"
    path="$(jq -r ".templates[$i].path" "$registry_file")"
    template_path="$TEMPLATES_DIR/$path"

    if [[ ! -f "$template_path" ]]; then
      issues+=("Template file missing: $template_path")
    else
      local content
      content="$(cat "$template_path")"

      # Check for required placeholders
      local missing=()
      for placeholder in "${required_placeholders[@]}"; do
        if ! echo "$content" | grep -q "{{$placeholder}}"; then
          missing+=("$placeholder")
        fi
      done

      if [[ ${#missing[@]} -gt 0 ]]; then
        issues+=("Missing placeholders: ${missing[*]}")
      fi

      # Check for GIVEN/WHEN/THEN structure
      if ! echo "$content" | grep -q "GIVEN" || ! echo "$content" | grep -q "WHEN" || ! echo "$content" | grep -q "THEN"; then
        issues+=("Does not include GIVEN/WHEN/THEN guidance")
      fi
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
      printf "Template %s issues:\n" "$id"
      for issue in "${issues[@]}"; do
        printf "  - %s\n" "$issue"
      done
      had_issue=true
    else
      printf "Template %s: OK\n" "$id"
    fi
  done

  if [[ "$had_issue" == true ]]; then
    return 1
  fi

  printf "All templates validated successfully.\n"
  return 0
}

format_result() {
  local status="$1" check="$2" message="$3" command="${4:-}" duration_info="${5:-}"
  local message_body="$message"
  if [[ -n "$duration_info" ]]; then
    message_body+="  ${duration_info}"
  fi
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  case "$status" in
    "ENABLED"|"PASS")
      printf "[%s✓%s] %s: %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$check" "$message_body"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      ;;
    "DISABLED"|"INFO")
      printf "[%sℹ%s] %s: %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$check" "$message_body"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      INFO_CHECKS=$((INFO_CHECKS + 1))
      ;;
    "BROKEN"|"FAIL")
      printf "[%s✗%s] %s: %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$check" "$message_body"
      [[ -n "$command" ]] && printf "    Command: %s%s%s\n" "${COLOR_GRAY}" "$command" "${COLOR_RESET}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      ;;
    *)
      printf "[%s?%s] %s: %s (unknown status: %s)\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$check" "$message_body" "$status"
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
  
  # Run the check script with timeout and parse output
  local start_time end_time duration_seconds duration_label
  start_time=$(current_timestamp)
  local output=""
  local run_status=0
  if output=$(run_with_timeout "$CHECK_TIMEOUT" "$script_name" "$script_path"); then
    run_status=0
  else
    run_status=$?
  fi
  end_time=$(current_timestamp)
  duration_seconds=$(elapsed_time "$start_time" "$end_time")
  duration_label=$(format_duration_label "$duration_seconds")

  if [[ $run_status -eq 0 ]]; then
    # Parse each line of output (some scripts may output multiple results)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      
      # Parse the standard format: STATUS|CHECK_NAME|MESSAGE|COMMAND
      if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
        local status="${BASH_REMATCH[1]}"
        local check="${BASH_REMATCH[2]}"
        local message="${BASH_REMATCH[3]}"
        local command="${BASH_REMATCH[5]:-}"
        
        format_result "$status" "$check" "$message" "$command" "$duration_label"
      else
        # Handle non-standard output
        format_result "BROKEN" "$script_name" "Invalid output format: $line" "$script_path" "$duration_label"
      fi
    done <<< "$output"
  else
    # Check if this was a timeout (output will contain timeout message)
    if [[ "$output" == *"timed out after"* ]]; then
      # Parse timeout message and format it
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
          local status="${BASH_REMATCH[1]}"
          local check="${BASH_REMATCH[2]}"
          local message="${BASH_REMATCH[3]}"
          local command="${BASH_REMATCH[5]:-}"
          format_result "$status" "$check" "$message" "$command" "$duration_label"
        fi
      done <<< "$output"
      # Don't return error for timeout - it's just another check result
      return 0
    else
      format_result "BROKEN" "$script_name" "Check script failed to execute: ${output:0:100}" "$script_path" "$duration_label"
      return 1
    fi
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
  
  # Copy script to Windows temp folder to avoid UNC path issues
  local windows_path
  if windows_path=$(copy_to_windows_temp "$script_path"); then
    # Run PowerShell script with timeout and parse output
    local start_time end_time duration_seconds duration_label
    start_time=$(current_timestamp)
    local output=""
    local run_status=0
    if output=$(run_with_timeout "$CHECK_TIMEOUT" "$script_name" powershell.exe -ExecutionPolicy Bypass -File "$windows_path"); then
      run_status=0
    else
      run_status=$?
    fi
    end_time=$(current_timestamp)
    duration_seconds=$(elapsed_time "$start_time" "$end_time")
    duration_label=$(format_duration_label "$duration_seconds")

    if [[ $run_status -eq 0 ]]; then
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
          
          format_result "$status" "$check" "$message" "$command" "$duration_label"
        else
          # Handle non-standard output
          format_result "BROKEN" "$script_name" "Invalid output format: $line" "powershell.exe -File $windows_path" "$duration_label"
        fi
      done <<< "$output"
    else
      # Check if this was a timeout (output will contain timeout message)
      if [[ "$output" == *"timed out after"* ]]; then
        # Parse timeout message and format it
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          line="${line%$'\r'}"  # Remove Windows line endings
          if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
            local status="${BASH_REMATCH[1]}"
            local check="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[3]}"
            local command="${BASH_REMATCH[5]:-}"
            format_result "$status" "$check" "$message" "$command" "$duration_label"
          fi
        done <<< "$output"
        # Don't return error for timeout - it's just another check result
        return 0
      else
        format_result "BROKEN" "$script_name" "PowerShell script failed: ${output:0:100}" "powershell.exe -File $windows_path" "$duration_label"
        return 1
      fi
    fi
    
    # Cleanup: Remove temporary script file
    local wsl_temp_path
    if wsl_temp_path=$(wslpath "$(dirname "$windows_path")" 2>/dev/null); then
      rm -f "${wsl_temp_path}/$(basename "$windows_path")" 2>/dev/null || true
    fi
  else
    format_result "BROKEN" "$script_name" "Cannot copy PowerShell script to Windows temp folder" "copy_to_windows_temp $script_path"
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
  
  # Copy script to Windows temp folder to avoid UNC path issues
  local windows_path
  if windows_path=$(copy_to_windows_temp "$script_path"); then
    # Run CMD script with timeout and parse output
    local start_time end_time duration_seconds duration_label
    start_time=$(current_timestamp)
    local output=""
    local run_status=0
    if output=$(run_with_timeout "$CHECK_TIMEOUT" "$script_name" cmd.exe /c "$windows_path"); then
      run_status=0
    else
      run_status=$?
    fi
    end_time=$(current_timestamp)
    duration_seconds=$(elapsed_time "$start_time" "$end_time")
    duration_label=$(format_duration_label "$duration_seconds")

    if [[ $run_status -eq 0 ]]; then
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
          
          format_result "$status" "$check" "$message" "$command" "$duration_label"
        else
          # Handle non-standard output
          format_result "BROKEN" "$script_name" "Invalid output format: $line" "cmd.exe /c $windows_path" "$duration_label"
        fi
      done <<< "$output"
    else
      # Check if this was a timeout (output will contain timeout message)
      if [[ "$output" == *"timed out after"* ]]; then
        # Parse timeout message and format it
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          line="${line%$'\r'}"  # Remove Windows line endings
          if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
            local status="${BASH_REMATCH[1]}"
            local check="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[3]}"
            local command="${BASH_REMATCH[5]:-}"
            format_result "$status" "$check" "$message" "$command" "$duration_label"
          fi
        done <<< "$output"
        # Don't return error for timeout - it's just another check result
        return 0
      else
        format_result "BROKEN" "$script_name" "CMD script failed: ${output:0:100}" "cmd.exe /c $windows_path" "$duration_label"
        return 1
      fi
    fi
    
    # Cleanup: Remove temporary script file
    local wsl_temp_path
    if wsl_temp_path=$(wslpath "$(dirname "$windows_path")" 2>/dev/null); then
      rm -f "${wsl_temp_path}/$(basename "$windows_path")" 2>/dev/null || true
    fi
  else
    format_result "BROKEN" "$script_name" "Cannot copy CMD script to Windows temp folder" "copy_to_windows_temp $script_path"
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
  printf "Total Checks: %d (timeout: %ds per check)\n" "$TOTAL_CHECKS" "$CHECK_TIMEOUT"
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
    printf "  --list-templates  List available check templates\n"
    printf "  --validate-templates  Validate template integrity\n"
    printf "  /check        Launch interactive/template-driven check creation\n"
    printf "  --check-help  Detailed help for /check workflow\n"
    printf "\nConfiguration:\n"
    printf "  CHECK_TIMEOUT  Timeout for individual checks in seconds (default: %d)\n" "$CHECK_TIMEOUT"
    printf "\nEnvironment:\n"
    printf "  PUBLISH_DOMAIN Domain for external endpoints (default: dev.localhost)\n"
    printf "\nCheck Scripts Location: %s (searches recursively in subdirectories)\n" "$CHECKS_DIR"
    exit 0
    ;;
  --list)
    printf "Available check scripts (grouped by pattern):\n\n"
    if [[ -d "$CHECKS_DIR" ]]; then
      # Group by pattern
      for group in security storage communication environment monitoring performance wsl2; do
        group_name="${GROUP_NAMES[$group]:-$group}"
        scripts=()
        while IFS= read -r -d '' script; do
          relative_path="${script#$CHECKS_DIR/}"
          scripts+=("$relative_path")
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
  --list-templates)
    handle_list_templates
    exit $?
    ;;
  --validate-templates)
    handle_validate_templates
    exit $?
    ;;
  --check-help)
    print_check_help
    exit 0
    ;;
  /check|check)
    handle_check_command "$@"
    exit $?
    ;;
  *)
    main "$@"
    ;;
esac

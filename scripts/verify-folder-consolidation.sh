#!/usr/bin/env bash
#
# Verify that bin/ and scripts/ folders have been consolidated into scripts/
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() {
  echo -e "${GREEN}[✓]${NC} $1"
  ((PASSED++))
}
log_warning() {
  echo -e "${YELLOW}[⚠]${NC} $1"
  ((WARNINGS++))
}
log_error() {
  echo -e "${RED}[✗]${NC} $1"
  ((FAILED++))
}

echo "========================================="
echo "  Folder Consolidation Verification"
echo "========================================="
echo ""

# Check bin/ folder is removed
log_info "Checking bin/ folder removal..."
if [ -d "bin" ]; then
  log_error "bin/ folder still exists - should be removed"
else
  log_success "bin/ folder successfully removed"
fi

# Check all scripts are in scripts/
log_info "Checking scripts are in scripts/ folder..."
expected_scripts=(
  "scripts/00-setup-folders.sh"
  "scripts/diag.wsl2.sh"
  "scripts/get-host-ip.sh"
  "scripts/k8s-deploy.sh"
  "scripts/k8s-generate-from-helm.sh"
  "scripts/k8s-generate-secrets.sh"
  "scripts/k8s-validate.sh"
  "scripts/verify-k8s-scripts-migration.sh"
  "scripts/verify-mise-k8s.sh"
  "scripts/verify-folder-consolidation.sh"
)

for script in "${expected_scripts[@]}"; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then
      log_success "Script '$script' exists and is executable"
    else
      log_warning "Script '$script' exists but not executable"
    fi
  else
    log_error "Script '$script' not found"
  fi
done

# Check mise.toml uses scripts/
log_info "Checking mise.toml references..."
if grep -q "./scripts/" mise.toml; then
  bin_count=$(grep -c "scripts/" mise.toml || echo "0")
  log_success "mise.toml updated with scripts/ references ($bin_count occurrences)"
else
  log_error "mise.toml missing scripts/ references"
fi

# Check for any remaining bin/ references (excluding archives)
log_info "Checking for old bin/ references..."
old_refs=$(grep -r "\./bin/\|bin/get-host-ip\|bin/k8s-\|bin/00-setup\|bin/diag\|bin/verify" \
  --include="*.md" --include="*.sh" --include="*.toml" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="docs/.archive" \
  --exclude-dir=".specify" \
  . 2>/dev/null | grep -v "Binary file" || true)

if [ -z "$old_refs" ]; then
  log_success "No old bin/ references found (excluding archives)"
else
  log_warning "Found some bin/ references (may be in archives or comments):"
  echo "$old_refs" | head -5 | while IFS= read -r line; do
    echo "  $line"
  done
  if [ $(echo "$old_refs" | wc -l) -gt 5 ]; then
    echo "  ... and $(($(echo "$old_refs" | wc -l) - 5)) more"
  fi
fi

# Check key documentation files
log_info "Checking key documentation..."
docs_to_check=(
  "README.md"
  "mise.toml"
  "k8s/MANIFEST.md"
  "k8s/SUMMARY.md"
  "k8s/TESTING.md"
  "DEPLOYMENT_STRATEGY.md"
  "tests/README.md"
)

for doc in "${docs_to_check[@]}"; do
  if [ -f "$doc" ]; then
    if grep -q "scripts/" "$doc" 2>/dev/null; then
      log_success "Documentation '$doc' updated with scripts/ references"
    else
      log_warning "Documentation '$doc' may need updates (or doesn't reference scripts)"
    fi
  fi
done

# Verify scripts/ README exists
log_info "Checking scripts/ documentation..."
if [ -f "scripts/README.md" ]; then
  log_success "scripts/README.md exists"
else
  log_warning "scripts/README.md not found - should document available scripts"
fi

# Summary
echo ""
echo "========================================="
echo "  Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All checks passed! Folder consolidation complete."
  exit 0
elif [ $FAILED -eq 0 ]; then
  log_warning "Consolidation complete with some warnings."
  exit 0
else
  log_error "Consolidation incomplete. Please fix errors above."
  exit 1
fi

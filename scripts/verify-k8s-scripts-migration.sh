#!/usr/bin/env bash
#
# Verify that k8s/*.sh scripts were successfully moved to bin/
# and all references were updated correctly
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
echo "  K8s Scripts Migration Verification"
echo "========================================="
echo ""

# Check scripts were moved to scripts/
log_info "Checking scripts are in scripts/..."
scripts=(
  "scripts/k8s-deploy.sh"
  "scripts/k8s-generate-secrets.sh"
  "scripts/k8s-generate-from-helm.sh"
  "scripts/k8s-validate.sh"
)

for script in "${scripts[@]}"; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then
      log_success "Script '$script' exists and is executable"
    else
      log_error "Script '$script' exists but not executable"
    fi
  else
    log_error "Script '$script' not found"
  fi
done

# Check old scripts are removed from k8s/
log_info "Checking old scripts removed from k8s/..."
old_scripts=(
  "k8s/deploy.sh"
  "k8s/generate-secrets.sh"
  "k8s/generate-from-helm.sh"
  "k8s/validate.sh"
)

for script in "${old_scripts[@]}"; do
  if [ -f "$script" ]; then
    log_error "Old script '$script' still exists - should be removed"
  else
    log_success "Old script '$script' correctly removed"
  fi
done

# Check mise.toml references
log_info "Checking mise.toml references..."
if grep -q "./scripts/k8s-generate-secrets.sh" mise.toml; then
  log_success "mise.toml: k8s-secrets-generate task updated"
else
  log_error "mise.toml: k8s-secrets-generate task not updated"
fi

if grep -q "./scripts/k8s-deploy.sh" mise.toml; then
  log_success "mise.toml: k8s deployment tasks updated"
else
  log_error "mise.toml: k8s deployment tasks not updated"
fi

# Check for any remaining old references
log_info "Checking for old script references..."
old_refs=$(grep -r "k8s/deploy.sh\|k8s/validate.sh\|k8s/generate" \
  --include="*.md" --include="*.sh" --include="*.toml" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="docs/.archive" \
  . 2>/dev/null | grep -v "Binary file" | grep -v "docs/.archive" || true)

if [ -z "$old_refs" ]; then
  log_success "No old script references found (excluding archives)"
else
  log_warning "Found old script references (check if in archives):"
  echo "$old_refs" | while IFS= read -r line; do
    echo "  $line"
  done
fi

# Check scripts/verify-mise-k8s.sh
log_info "Checking scripts/verify-mise-k8s.sh..."
if [ -f "scripts/verify-mise-k8s.sh" ]; then
  if grep -q "scripts/k8s-deploy.sh" scripts/verify-mise-k8s.sh; then
    log_success "scripts/verify-mise-k8s.sh references updated"
  else
    log_error "scripts/verify-mise-k8s.sh references not updated"
  fi
else
  log_error "scripts/verify-mise-k8s.sh not found"
fi

# Check documentation files
log_info "Checking documentation updates..."
docs_to_check=(
  "k8s/MANIFEST.md"
  "k8s/SUMMARY.md"
  "k8s/TESTING.md"
  "DEPLOYMENT_STRATEGY.md"
)

for doc in "${docs_to_check[@]}"; do
  if [ -f "$doc" ]; then
    if grep -q "scripts/k8s-" "$doc" 2>/dev/null; then
      log_success "Documentation '$doc' updated with scripts/ references"
    else
      log_warning "Documentation '$doc' may need updates"
    fi
  fi
done

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
  log_success "All checks passed! K8s scripts migration complete."
  exit 0
elif [ $FAILED -eq 0 ]; then
  log_warning "Migration complete with some warnings."
  exit 0
else
  log_error "Migration incomplete. Please fix errors above."
  exit 1
fi

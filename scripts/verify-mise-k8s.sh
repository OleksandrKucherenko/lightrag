#!/usr/bin/env bash
#
# Verify MISE K8s integration is working correctly
# Tests tools, secrets, and deployment tasks
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
echo "  MISE K8s Integration Verification"
echo "========================================="
echo ""

# Check MISE is installed
if command -v mise &>/dev/null; then
  log_success "MISE is installed: $(mise --version)"
else
  log_error "MISE not found - install with: brew install mise"
  exit 1
fi

# Check MISE config exists
if [ -f "mise.toml" ]; then
  log_success "mise.toml configuration found"
else
  log_error "mise.toml not found in current directory"
  exit 1
fi

# Check MISE is trusted
if mise trust --status &>/dev/null; then
  log_success "MISE configuration is trusted"
else
  log_warning "MISE not trusted - run: mise trust"
fi

# Check tools defined in mise.toml
log_info "Checking required tools in mise.toml..."
required_tools=("age" "hostctl" "kind" "kubectl" "mkcert" "sops")
for tool in "${required_tools[@]}"; do
  if grep -q "^$tool = " mise.toml; then
    log_success "Tool '$tool' defined in mise.toml"
  else
    log_error "Tool '$tool' missing from mise.toml"
  fi
done

# Check K8s tasks exist
log_info "Checking K8s tasks..."
k8s_tasks=(
  "k8s-check-tools"
  "k8s-cluster-create"
  "k8s-cluster-delete"
  "k8s-secrets-generate"
  "k8s-deploy"
  "k8s-verify"
  "k8s-status"
  "k8s-logs"
  "k8s-delete"
  "k8s-port-forward"
)

for task in "${k8s_tasks[@]}"; do
  if grep -q "\[tasks\.$task\]" mise.toml; then
    log_success "Task '$task' defined"
  else
    log_error "Task '$task' missing"
  fi
done

# Check secrets setup
log_info "Checking secrets configuration..."

if [ -f ".secrets/mise-age.txt" ]; then
  log_success "Age key file exists: .secrets/mise-age.txt"

  # Check if it's a valid age key
  if grep -q "AGE-SECRET-KEY-" .secrets/mise-age.txt; then
    log_success "Age key appears valid"
  else
    log_warning "Age key file exists but format looks wrong"
  fi
else
  log_warning "Age key not found - create with: age-keygen -o .secrets/mise-age.txt"
fi

if [ -f ".env.secrets.json" ]; then
  log_success "Secrets file exists: .env.secrets.json"

  # Check if encrypted
  if grep -q "sops" .env.secrets.json; then
    log_success "Secrets file is encrypted (SOPS)"
  else
    log_warning "Secrets file not encrypted - run: sops encrypt -i --age <key> .env.secrets.json"
  fi
else
  log_warning "Secrets file not found - copy from .env.secrets.example.json"
fi

# Check K8s scripts
log_info "Checking K8s scripts..."
k8s_scripts=(
  "scripts/k8s-deploy.sh"
  "scripts/k8s-generate-secrets.sh"
  "scripts/k8s-generate-from-helm.sh"
  "scripts/k8s-validate.sh"
)

for script in "${k8s_scripts[@]}"; do
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

# Check K8s documentation
log_info "Checking documentation..."
docs=(
  "k8s/DEPLOYMENT_GUIDE.md"
  "k8s/MISE_INTEGRATION.md"
  "k8s/MISE_QUICK_REFERENCE.md"
  "k8s/K8S_FIXES.md"
)

for doc in "${docs[@]}"; do
  if [ -f "$doc" ]; then
    log_success "Documentation '$doc' exists"
  else
    log_warning "Documentation '$doc' not found"
  fi
done

# Test MISE environment loading
log_info "Testing MISE environment..."
if mise env &>/dev/null; then
  log_success "MISE can load environment"

  # Check if specific vars are loaded
  if mise env | grep -q "PUBLISH_DOMAIN"; then
    log_success "PUBLISH_DOMAIN loaded from environment"
  else
    log_warning "PUBLISH_DOMAIN not found in mise env"
  fi
else
  log_error "MISE cannot load environment"
fi

# Check if tools can be listed
if mise tasks &>/dev/null; then
  log_success "MISE tasks command works"
else
  log_error "MISE tasks command failed"
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
  log_success "All checks passed! MISE K8s integration is ready."
  echo ""
  echo "Next steps:"
  echo "  1. mise run k8s-cluster-create"
  echo "  2. mise run k8s-deploy"
  echo "  3. mise run k8s-verify"
  exit 0
elif [ $FAILED -eq 0 ]; then
  log_warning "Setup mostly complete with some warnings."
  echo ""
  echo "Review warnings above and fix if needed."
  exit 0
else
  log_error "Setup incomplete. Please fix errors above."
  exit 1
fi

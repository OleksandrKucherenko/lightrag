#!/usr/bin/env bash
#
# Setup script for git hooks and secret detection tools
# This script installs and configures lefthook, gitleaks, and trufflehog
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main setup
main() {
    echo ""
    info "Setting up git hooks for secret detection..."
    echo ""

    # Check if mise is available
    if ! command_exists mise; then
        error "mise is not installed or not in PATH"
        error "Please install mise first: https://mise.jdx.dev/getting-started.html"
        exit 1
    fi

    success "mise is installed"

    # Install tools via mise
    info "Installing tools via mise (gitleaks, trufflehog, lefthook)..."
    if mise install; then
        success "Tools installed successfully"
    else
        error "Failed to install tools via mise"
        exit 1
    fi

    # Verify tools are installed
    echo ""
    info "Verifying tool installation..."

    local all_installed=true

    if command_exists gitleaks; then
        success "gitleaks $(gitleaks version 2>&1 | head -n1 || echo 'installed')"
    else
        error "gitleaks not found in PATH"
        all_installed=false
    fi

    if command_exists trufflehog; then
        success "trufflehog $(trufflehog --version 2>&1 | head -n1 || echo 'installed')"
    else
        error "trufflehog not found in PATH"
        all_installed=false
    fi

    if command_exists lefthook; then
        success "lefthook $(lefthook version 2>&1 || echo 'installed')"
    else
        error "lefthook not found in PATH"
        all_installed=false
    fi

    if [ "$all_installed" = false ]; then
        error "Some tools are not properly installed"
        warning "Try running: eval \"\$(mise activate bash)\" or restart your shell"
        exit 1
    fi

    # Install git hooks using lefthook
    echo ""
    info "Installing git hooks using lefthook..."
    if lefthook install; then
        success "Git hooks installed successfully"
    else
        error "Failed to install git hooks"
        exit 1
    fi

    # Test the hooks
    echo ""
    info "Testing git hooks configuration..."
    if lefthook run --no-tty pre-commit 2>&1 | grep -q "EXECUTE\|Skipped"; then
        success "Git hooks are configured correctly"
    else
        warning "Could not verify git hooks (this may be normal if there are no staged files)"
    fi

    # Final instructions
    echo ""
    success "Setup complete! 🎉"
    echo ""
    info "Git hooks are now active and will run automatically on:"
    echo "  • git commit (pre-commit hook)"
    echo "  • git push (pre-push hook)"
    echo ""
    info "To test the hooks manually, run:"
    echo "  lefthook run pre-commit"
    echo ""
    info "To bypass hooks temporarily (not recommended):"
    echo "  LEFTHOOK=0 git commit -m 'message'"
    echo ""
    info "For more information, see SECURITY.md"
    echo ""
}

main "$@"

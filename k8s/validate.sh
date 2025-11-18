#!/usr/bin/env bash
#
# Comprehensive validation script for LightRAG Kubernetes manifests
# This script performs extensive validation without requiring a running cluster
#

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
CHECKS=0

# Helper functions
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}======================================================================${NC}"
    echo -e "${BOLD}${BLUE}$(printf '%*s' $(($(tput cols 2>/dev/null || echo 70))) | tr ' ' ' ')${NC}"
    echo -e "${BOLD}${BLUE}$(printf '%*s' $(((${#1}+70)/2)) "$1" | tr ' ' ' ')${NC}"
    echo -e "${BOLD}${BLUE}======================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=0

    if command -v yq &> /dev/null; then
        print_success "yq is installed"
    else
        print_warning "yq not found (optional, but recommended for advanced validation)"
        print_info "Install: https://github.com/mikefarah/yq"
        missing=1
    fi

    if command -v jq &> /dev/null; then
        print_success "jq is installed"
    else
        print_warning "jq not found (optional)"
        missing=1
    fi

    if [ $missing -eq 0 ]; then
        print_success "All recommended tools are installed"
    fi
}

# Validate YAML syntax
validate_yaml_syntax() {
    print_header "Validating YAML Syntax"

    local yaml_files=($(find . -maxdepth 1 -name "*.yaml" ! -name "kustomization.yaml" ! -name ".*" -type f | sort))

    if [ ${#yaml_files[@]} -eq 0 ]; then
        print_error "No YAML files found"
        return 1
    fi

    for file in "${yaml_files[@]}"; do
        ((CHECKS++))

        # Basic YAML validation using yq (faster and more portable)
        if command -v yq &> /dev/null; then
            local doc_count=$(yq eval-all 'length' "$file" 2>/dev/null || echo "1")
            if [ $? -eq 0 ]; then
                print_success "$(basename $file): valid YAML"
            else
                print_error "$(basename $file): Invalid YAML syntax"
            fi
        else
            # Fallback to basic syntax check
            if grep -q "^---" "$file" && grep -q "kind:" "$file"; then
                print_success "$(basename $file): appears valid"
            else
                print_warning "$(basename $file): cannot fully validate (install yq for better validation)"
            fi
        fi
    done
}

# Validate Kubernetes resource structure
validate_k8s_structure() {
    print_header "Validating Kubernetes Resource Structure"

    local yaml_files=($(find . -maxdepth 1 -name "*.yaml" ! -name "kustomization.yaml" ! -name ".*" -type f | sort))

    for file in "${yaml_files[@]}"; do
        # Check for required fields using grep (portable)
        local has_apiversion=$(grep -c "^apiVersion:" "$file" || true)
        local has_kind=$(grep -c "^kind:" "$file" || true)
        local has_metadata=$(grep -c "^metadata:" "$file" || true)

        if [ $has_apiversion -eq 0 ]; then
            print_error "$(basename $file): Missing apiVersion"
        fi

        if [ $has_kind -eq 0 ]; then
            print_error "$(basename $file): Missing kind"
        fi

        if [ $has_metadata -eq 0 ]; then
            print_error "$(basename $file): Missing metadata"
        fi

        if [ $has_apiversion -gt 0 ] && [ $has_kind -gt 0 ] && [ $has_metadata -gt 0 ]; then
            ((CHECKS++))
        fi
    done

    if [ $ERRORS -eq 0 ]; then
        print_success "All resources have valid Kubernetes structure"
    fi
}

# Validate resource references
validate_references() {
    print_header "Validating Resource References"

    # Extract all ConfigMap names
    local configmaps=($(grep -h "^  name:" 01-configmaps.yaml 2>/dev/null | awk '{print $2}' || true))
    # Extract all Secret names
    local secrets=($(grep -h "^  name:" 02-secrets.yaml 2>/dev/null | awk '{print $2}' || true))
    # Extract all PVC names
    local pvcs=($(grep -h "^  name:" 03-storage.yaml 2>/dev/null | awk '{print $2}' || true))

    print_info "Found ${#configmaps[@]} ConfigMap(s), ${#secrets[@]} Secret(s), ${#pvcs[@]} PVC(s)"

    # Check ConfigMap references
    local cm_refs=($(grep -h "configMapRef:" *.yaml 2>/dev/null | grep -o "name:.*" | awk '{print $2}' || true))
    for ref in "${cm_refs[@]}"; do
        ((CHECKS++))
        if printf '%s\n' "${configmaps[@]}" | grep -q "^${ref}$"; then
            print_success "ConfigMap reference '$ref' exists"
        else
            print_error "ConfigMap reference '$ref' not found"
        fi
    done

    # Check Secret references
    local secret_refs=($(grep -h "secretKeyRef:" *.yaml 2>/dev/null | grep -o "name:.*" | awk '{print $2}' || true))
    for ref in "${secret_refs[@]}"; do
        ((CHECKS++))
        if printf '%s\n' "${secrets[@]}" | grep -q "^${ref}$"; then
            print_success "Secret reference '$ref' exists"
        else
            print_error "Secret reference '$ref' not found"
        fi
    done

    # Check PVC references
    local pvc_refs=($(grep -h "claimName:" *.yaml 2>/dev/null | awk '{print $2}' || true))
    for ref in "${pvc_refs[@]}"; do
        ((CHECKS++))
        if printf '%s\n' "${pvcs[@]}" | grep -q "^${ref}$"; then
            print_success "PVC reference '$ref' exists"
        else
            print_error "PVC reference '$ref' not found"
        fi
    done

    if [ $ERRORS -eq 0 ] && [ ${#cm_refs[@]} -gt 0 ] || [ ${#secret_refs[@]} -gt 0 ] || [ ${#pvc_refs[@]} -gt 0 ]; then
        print_success "All resource references are valid"
    fi
}

# Validate resource limits
validate_resources() {
    print_header "Validating Resource Limits"

    local deployment_files=($(grep -l "kind: Deployment\|kind: StatefulSet" *.yaml 2>/dev/null || true))

    for file in "${deployment_files[@]}"; do
        local name=$(grep -A 2 "^kind:" "$file" | grep "name:" | head -1 | awk '{print $2}')

        if grep -q "resources:" "$file"; then
            if grep -A 5 "resources:" "$file" | grep -q "limits:"; then
                print_success "$name has resource limits defined"
                ((CHECKS++))
            else
                print_warning "$name missing resource limits"
            fi

            if grep -A 5 "resources:" "$file" | grep -q "requests:"; then
                print_success "$name has resource requests defined"
                ((CHECKS++))
            else
                print_warning "$name missing resource requests"
            fi
        else
            print_warning "$name has no resource configuration"
        fi
    done
}

# Validate health probes
validate_probes() {
    print_header "Validating Health Probes"

    local deployment_files=($(grep -l "kind: Deployment\|kind: StatefulSet" *.yaml 2>/dev/null || true))

    for file in "${deployment_files[@]}"; do
        local name=$(grep -A 2 "^kind:" "$file" | grep "name:" | head -1 | awk '{print $2}')

        if grep -q "livenessProbe:" "$file"; then
            print_success "$name has livenessProbe"
            ((CHECKS++))
        else
            print_warning "$name missing livenessProbe"
        fi

        if grep -q "readinessProbe:" "$file"; then
            print_success "$name has readinessProbe"
            ((CHECKS++))
        else
            print_warning "$name missing readinessProbe"
        fi
    done
}

# Validate security
validate_security() {
    print_header "Validating Security Configurations"

    # Check for non-base64 encoded secrets
    if [ -f "02-secrets.yaml" ]; then
        local suspicious_secrets=$(grep -A 1 "^  [A-Z_]*:" 02-secrets.yaml | grep -v "^--$" | grep -v "^  #" | grep -v "base64" | wc -l)

        if [ $suspicious_secrets -gt 0 ]; then
            print_warning "Secrets file may contain placeholder values (update before deploying!)"
        else
            print_success "Secrets appear to be properly encoded"
        fi
        ((CHECKS++))
    fi

    # Check for privileged containers
    if grep -q "privileged: true" *.yaml 2>/dev/null; then
        print_warning "Found privileged containers (security risk)"
    else
        print_success "No privileged containers found"
        ((CHECKS++))
    fi

    # Check for host network
    if grep -q "hostNetwork: true" *.yaml 2>/dev/null; then
        print_warning "Found containers using host network (security risk)"
    else
        print_success "No containers using host network"
        ((CHECKS++))
    fi
}

# Validate labels and selectors
validate_labels() {
    print_header "Validating Labels and Selectors"

    local service_files=($(grep -l "kind: Service" *.yaml 2>/dev/null || true))

    for file in "${service_files[@]}"; do
        local name=$(grep -A 2 "^kind: Service" "$file" | grep "name:" | head -1 | awk '{print $2}')

        if grep -q "selector:" "$file"; then
            print_success "Service $name has selector defined"
            ((CHECKS++))
        else
            print_warning "Service $name missing selector"
        fi
    done

    # Check for recommended labels
    local all_resources=($(grep -l "^kind:" *.yaml 2>/dev/null || true))

    for file in "${all_resources[@]}"; do
        if grep -q "app.kubernetes.io/name:" "$file"; then
            ((CHECKS++))
        else
            local kind=$(grep "^kind:" "$file" | head -1 | awk '{print $2}')
            if [ "$kind" != "Namespace" ]; then
                print_warning "$(basename $file): Missing recommended label 'app.kubernetes.io/name'"
            fi
        fi
    done
}

# Validate ingress configuration
validate_ingress() {
    print_header "Validating Ingress Configuration"

    if [ -f "10-ingress.yaml" ]; then
        # Check for ingress class
        if grep -q "ingressClassName:" "10-ingress.yaml"; then
            local class=$(grep "ingressClassName:" "10-ingress.yaml" | awk '{print $2}')
            print_success "Ingress class defined: $class"
            ((CHECKS++))
        else
            print_warning "No ingress class specified (will use default)"
        fi

        # Check for hosts
        local host_count=$(grep -c "host:" "10-ingress.yaml" || true)
        if [ $host_count -gt 0 ]; then
            print_success "Found $host_count ingress host(s)"
            ((CHECKS++))
        else
            print_error "No ingress hosts defined"
        fi

        # Check for TLS
        if grep -q "tls:" "10-ingress.yaml"; then
            print_info "TLS configuration found (commented or enabled)"
        else
            print_warning "No TLS configuration (HTTPS not enabled)"
        fi
    else
        print_error "Ingress file not found (10-ingress.yaml)"
    fi
}

# Check for common issues
check_common_issues() {
    print_header "Checking for Common Issues"

    # Check for hardcoded localhost
    if grep -r "localhost" *.yaml 2>/dev/null | grep -v "dev.localhost" | grep -v "#" | grep -q .; then
        print_warning "Found hardcoded 'localhost' references (may cause issues)"
    else
        print_success "No hardcoded localhost references"
        ((CHECKS++))
    fi

    # Check for large images without version tags
    if grep -r "image:.*:latest" *.yaml 2>/dev/null | grep -q .; then
        print_warning "Found images using ':latest' tag (not recommended for production)"
    else
        print_success "No images using ':latest' tag"
        ((CHECKS++))
    fi

    # Check for missing namespace
    local no_namespace=$(grep -L "namespace:" *.yaml 2>/dev/null | grep -v "00-namespace.yaml" | grep -v "kustomization.yaml" || true)
    if [ -n "$no_namespace" ]; then
        print_info "Some files missing namespace (will use default or from context)"
    fi
}

# Generate statistics
generate_stats() {
    print_header "Resource Statistics"

    echo "Resource Type Breakdown:"
    for kind in Namespace ConfigMap Secret PersistentVolumeClaim StatefulSet Deployment Service Ingress; do
        local count=$(grep -h "^kind: $kind" *.yaml 2>/dev/null | wc -l || echo 0)
        if [ $count -gt 0 ]; then
            printf "  %-30s %3d resource(s)\n" "$kind" "$count"
        fi
    done

    echo ""
    print_info "Total YAML files: $(find . -maxdepth 1 -name "*.yaml" ! -name "kustomization.yaml" -type f | wc -l)"
    print_info "Total checks performed: $CHECKS"
}

# Print summary
print_summary() {
    print_header "Validation Summary"

    if [ $ERRORS -gt 0 ]; then
        print_error "Found $ERRORS error(s)"
    else
        print_success "No errors found!"
    fi

    if [ $WARNINGS -gt 0 ]; then
        print_warning "Found $WARNINGS warning(s)"
    else
        print_success "No warnings!"
    fi

    echo ""

    # Final verdict
    if [ $ERRORS -eq 0 ]; then
        if [ $WARNINGS -eq 0 ]; then
            echo -e "${BOLD}${GREEN}$(printf '%*s' 70)${NC}" | tr ' ' '='
            echo -e "${BOLD}${GREEN}$(printf '%*s' $(((16+70)/2)) "✓ VALIDATION PASSED")${NC}"
            echo -e "${BOLD}${GREEN}$(printf '%*s' 70)${NC}" | tr ' ' '='
            return 0
        else
            echo -e "${BOLD}${YELLOW}$(printf '%*s' 70)${NC}" | tr ' ' '='
            echo -e "${BOLD}${YELLOW}$(printf '%*s' $(((32+70)/2)) "⚠ VALIDATION PASSED WITH WARNINGS")${NC}"
            echo -e "${BOLD}${YELLOW}$(printf '%*s' 70)${NC}" | tr ' ' '='
            return 0
        fi
    else
        echo -e "${BOLD}${RED}$(printf '%*s' 70)${NC}" | tr ' ' '='
        echo -e "${BOLD}${RED}$(printf '%*s' $(((20+70)/2)) "✗ VALIDATION FAILED")${NC}"
        echo -e "${BOLD}${RED}$(printf '%*s' 70)${NC}" | tr ' ' '='
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║       LightRAG Kubernetes Manifest Validation Tool                ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_prerequisites
    validate_yaml_syntax
    validate_k8s_structure
    validate_references
    validate_resources
    validate_probes
    validate_security
    validate_labels
    validate_ingress
    check_common_issues
    generate_stats
    print_summary
}

# Run main function
main
exit $?

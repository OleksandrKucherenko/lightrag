#!/usr/bin/env bash
#
# Configuration Sync Helper for Docker Compose -> Kubernetes
#
# This script helps identify configuration drift between docker-compose.yaml
# and Kubernetes manifests, ensuring changes made during local development
# are properly reflected in production configurations.
#
# Usage:
#   ./sync-config.sh         # Interactive mode with colors
#   ./sync-config.sh --ci    # CI mode without colors, structured output
#

set -euo pipefail

# Check for CI mode
CI_MODE=false
if [ "${1:-}" = "--ci" ]; then
    CI_MODE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_COMPOSE="$PROJECT_ROOT/docker-compose.yaml"
K8S_DIR="$PROJECT_ROOT/k8s"
HELM_VALUES="$PROJECT_ROOT/helm/lightrag/values.yaml"

# Colors for output (disabled in CI mode)
if [ "$CI_MODE" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Counters
WARNINGS=0
ERRORS=0

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Extract image version from docker-compose
get_docker_image_version() {
    local service=$1
    grep -A 10 "^  $service:" "$DOCKER_COMPOSE" | grep "image:" | head -n1 | sed 's/.*image: *//' | tr -d '"' || echo ""
}

# Extract image version from k8s manifest
get_k8s_image_version() {
    local manifest=$1
    local image_name=$2
    grep "image: $image_name" "$manifest" | head -n1 | sed 's/.*image: *//' | tr -d '"' || echo ""
}

# Extract image version from helm values
get_helm_image_version() {
    local service=$1
    local repo=$(yq eval ".$service.image.repository" "$HELM_VALUES" 2>/dev/null || echo "")
    local tag=$(yq eval ".$service.image.tag" "$HELM_VALUES" 2>/dev/null || echo "")
    if [ -n "$repo" ] && [ -n "$tag" ]; then
        echo "$repo:$tag"
    fi
}

# Check if yq is installed (mikefarah's version, not python-yq)
check_yq() {
    if command -v yq &> /dev/null; then
        # Check if it's the right yq (mikefarah's version, not python-yq)
        if yq --version 2>&1 | grep -q "mikefarah"; then
            return 0
        fi
    fi
    # yq not installed or wrong version
    return 1
}

# Compare image versions
check_image_versions() {
    print_header "Checking Image Versions"

    declare -A services=(
        ["kv"]="redis:04-redis.yaml:redis"
        ["graph"]="memgraph:05-memgraph.yaml:memgraph"
        ["vectors"]="qdrant:06-qdrant.yaml:qdrant"
        ["rag"]="lightrag:07-lightrag.yaml:lightrag"
        ["lobechat"]="lobechat:08-lobechat.yaml:lobechat"
        ["monitor"]="monitor:09-monitor.yaml:monitor"
    )

    for service in "${!services[@]}"; do
        IFS=':' read -r k8s_name k8s_file helm_name <<< "${services[$service]}"

        docker_img=$(get_docker_image_version "$service")
        k8s_img=$(get_k8s_image_version "$K8S_DIR/$k8s_file" "")

        echo ""
        echo "Service: $service -> $k8s_name"
        echo "  Docker Compose: $docker_img"
        echo "  K8s Manifest:   $k8s_img"

        if check_yq; then
            helm_img=$(get_helm_image_version "$helm_name")
            echo "  Helm Values:    $helm_img"

            # Extract just the image repository (without tag)
            docker_repo=$(echo "$docker_img" | cut -d':' -f1)
            k8s_repo=$(echo "$k8s_img" | cut -d':' -f1)
            helm_repo=$(echo "$helm_img" | cut -d':' -f1)

            # Check if repositories match
            if [ "$docker_repo" = "$k8s_repo" ] && [ "$docker_repo" = "$helm_repo" ]; then
                print_success "Image repositories match"
            else
                print_error "Image repositories differ!"
            fi

            # Check if using latest tag (bad practice for k8s)
            if [[ "$k8s_img" == *":latest" ]] || [[ "$helm_img" == *":latest" ]]; then
                print_error "Using ':latest' tag in K8s/Helm (bad practice!)"
            fi
        fi
    done
}

# Check environment variables
check_env_config() {
    print_header "Checking Environment Configuration"

    # Key environment variables that should be consistent
    declare -A env_vars=(
        ["REDIS_PORT"]="6379"
        ["MEMGRAPH_PORT"]="7687"
        ["QDRANT_HTTP_PORT"]="6333"
        ["LIGHTRAG_PORT"]="9621"
        ["LOBECHAT_PORT"]="3210"
    )

    print_info "Checking critical port configurations..."

    for var in "${!env_vars[@]}"; do
        expected="${env_vars[$var]}"

        # Check in docker-compose
        compose_value=$(grep -i "$var" "$DOCKER_COMPOSE" | head -n1 | grep -oE '[0-9]+' || echo "$expected")

        echo ""
        echo "Port: $var"
        echo "  Expected:        $expected"
        echo "  Docker Compose:  $compose_value"

        if [ "$compose_value" = "$expected" ]; then
            print_success "Port configuration matches"
        else
            print_warning "Port mismatch detected"
        fi
    done
}

# Check resource limits
check_resources() {
    print_header "Checking Resource Configurations"

    print_info "Resource limits should be set in K8s/Helm but not necessarily in docker-compose"
    print_info "Verify that Helm values.yaml has appropriate limits for your environment"

    if check_yq; then
        echo ""
        echo "Current Helm Resource Limits:"
        echo "  LightRAG: $(yq eval '.lightrag.resources.limits.memory' "$HELM_VALUES") / $(yq eval '.lightrag.resources.limits.cpu' "$HELM_VALUES")"
        echo "  Qdrant:   $(yq eval '.qdrant.resources.limits.memory' "$HELM_VALUES") / $(yq eval '.qdrant.resources.limits.cpu' "$HELM_VALUES")"
        echo "  Memgraph: $(yq eval '.memgraph.resources.limits.memory' "$HELM_VALUES") / $(yq eval '.memgraph.resources.limits.cpu' "$HELM_VALUES")"
        echo "  Redis:    $(yq eval '.redis.resources.limits.memory' "$HELM_VALUES") / $(yq eval '.redis.resources.limits.cpu' "$HELM_VALUES")"
    fi
}

# Check for common mistakes
check_common_issues() {
    print_header "Checking Common Configuration Issues"

    # Check for latest tags
    if grep -r ":latest" "$K8S_DIR"/*.yaml 2>/dev/null | grep -v "#" | grep "image:"; then
        print_error "Found ':latest' tags in K8s manifests (should use specific versions)"
    else
        print_success "No ':latest' tags found in K8s manifests"
    fi

    # Check for hardcoded passwords/secrets
    if grep -r "password:" "$K8S_DIR"/*.yaml 2>/dev/null | grep -v "secretKeyRef" | grep -v "#"; then
        print_warning "Possible hardcoded passwords in K8s manifests"
    else
        print_success "No obvious hardcoded secrets in K8s manifests"
    fi

    # Check if .env files are documented
    if [ -f "$PROJECT_ROOT/.env" ]; then
        print_success ".env file exists for local development"
    else
        print_warning ".env file not found (may need to be created)"
    fi

    # Check if secrets template exists
    if [ -f "$K8S_DIR/02-secrets.yaml" ]; then
        print_success "K8s secrets template exists"
    else
        print_error "K8s secrets template not found!"
    fi
}

# Provide sync recommendations
print_recommendations() {
    print_header "Sync Recommendations"

    cat << 'EOF'

When you make changes to docker-compose.yaml, ensure you update:

1. **Image Versions**:
   - docker-compose.yaml: Can use :latest for dev
   - k8s/*.yaml: Must use specific version tags
   - helm/lightrag/values.yaml: Must use specific version tags

   Action: When updating an image version, update all three locations

2. **Environment Variables**:
   - docker-compose.yaml: Uses .env files
   - k8s/01-configmaps.yaml: Update ConfigMap values
   - helm/lightrag/values.yaml: Update config sections

   Action: Keep environment variable names and values consistent

3. **Ports**:
   - docker-compose.yaml: Container ports
   - k8s services: Service ports must match
   - helm/lightrag/values.yaml: Service port configuration

   Action: Ports should remain consistent across environments

4. **Resource Limits**:
   - docker-compose.yaml: Optional resource limits
   - k8s manifests: Required for production
   - helm/lightrag/values.yaml: Customize per environment

   Action: Test resource limits in dev before setting in prod

5. **Secrets**:
   - docker-compose.yaml: Uses .env files
   - k8s/02-secrets.yaml: Base64-encoded secrets
   - Helm: --set flags or sealed-secrets

   Action: Never commit real secrets, use templates

AUTOMATION OPTIONS:
- Run this script before commits: ./scripts/sync-config.sh
- Add to pre-commit hook for automatic checking
- Use CI/CD to validate configuration parity

WORKFLOW:
1. Develop locally with docker-compose
2. Run ./scripts/sync-config.sh to check drift
3. Manually sync changed values to k8s/Helm
4. Test K8s deployment in staging
5. Deploy to production

EOF
}

# Main execution
main() {
    echo ""
    print_header "LightRAG Configuration Sync Check"
    echo ""

    check_image_versions
    echo ""

    check_env_config
    echo ""

    check_resources
    echo ""

    check_common_issues
    echo ""

    print_recommendations
    echo ""

    print_header "Summary"
    echo ""
    echo "Warnings: $WARNINGS"
    echo "Errors:   $ERRORS"
    echo ""

    if [ $ERRORS -gt 0 ]; then
        print_error "Configuration sync check failed with $ERRORS errors"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        print_warning "Configuration sync check completed with $WARNINGS warnings"
        exit 0
    else
        print_success "Configuration sync check passed!"
        exit 0
    fi
}

# Run main
main

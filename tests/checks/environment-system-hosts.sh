#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Hosts File Preprocessing Check
# =============================================================================
# 
# GIVEN: A .etchosts template that uses environment variables
# WHEN: We test template preprocessing with envsubst
# THEN: We verify environment variables are properly substituted
# =============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
PUBLISH_DOMAIN="${PUBLISH_DOMAIN:-dev.localhost}"

# Check if .etchosts template exists
if [[ ! -f "${REPO_ROOT}/.etchosts" ]]; then
    echo "BROKEN|hosts_preprocessing|.etchosts template not found|ls ${REPO_ROOT}/.etchosts"
    exit 0
fi

# envsubst is assumed to be available

# WHEN: We test basic template preprocessing
export PUBLISH_DOMAIN
export HOST_IP="${HOST_IP:-127.0.0.1}"

if preprocessed=$(envsubst < "${REPO_ROOT}/.etchosts" 2>&1); then
    # THEN: Check if variables were substituted
    if echo "$preprocessed" | grep -q "$PUBLISH_DOMAIN" && ! echo "$preprocessed" | grep -q '\$PUBLISH_DOMAIN'; then
        echo "PASS|hosts_preprocessing|Basic template preprocessing working|envsubst < .etchosts"
    else
        echo "FAIL|hosts_preprocessing|Template variables not substituted properly|envsubst < .etchosts"
    fi
else
    echo "BROKEN|hosts_preprocessing|Template preprocessing failed: ${preprocessed:0:50}|envsubst < .etchosts"
fi

# WHEN: We test with different domain values
test_domains=("test.local" "staging.company.com")

for test_domain in "${test_domains[@]}"; do
    export PUBLISH_DOMAIN="$test_domain"
    
    if test_result=$(envsubst < "${REPO_ROOT}/.etchosts" 2>&1); then
        if echo "$test_result" | grep -q "$test_domain" && ! echo "$test_result" | grep -q '\$PUBLISH_DOMAIN'; then
            echo "PASS|hosts_preprocessing|Custom domain preprocessing working: $test_domain|PUBLISH_DOMAIN=$test_domain envsubst < .etchosts"
        else
            echo "FAIL|hosts_preprocessing|Custom domain preprocessing failed: $test_domain|PUBLISH_DOMAIN=$test_domain envsubst < .etchosts"
        fi
    else
        echo "BROKEN|hosts_preprocessing|Custom domain preprocessing error: ${test_result:0:50}|PUBLISH_DOMAIN=$test_domain envsubst < .etchosts"
    fi
done

# WHEN: We test with different HOST_IP values
test_ips=("192.168.1.100" "62.119.15.83")

for test_ip in "${test_ips[@]}"; do
    export HOST_IP="$test_ip"
    export PUBLISH_DOMAIN="dev.localhost"  # Reset to default
    
    if ip_result=$(envsubst < "${REPO_ROOT}/.etchosts" 2>&1); then
        if echo "$ip_result" | grep -q "$test_ip" && ! echo "$ip_result" | grep -q '\$HOST_IP'; then
            echo "PASS|hosts_preprocessing|Custom IP preprocessing working: $test_ip|HOST_IP=$test_ip envsubst < .etchosts"
        else
            echo "FAIL|hosts_preprocessing|Custom IP preprocessing failed: $test_ip|HOST_IP=$test_ip envsubst < .etchosts"
        fi
    else
        echo "BROKEN|hosts_preprocessing|Custom IP preprocessing error: ${ip_result:0:50}|HOST_IP=$test_ip envsubst < .etchosts"
    fi
done

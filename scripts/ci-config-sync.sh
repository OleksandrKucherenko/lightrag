#!/usr/bin/env bash
#
# CI script for configuration sync validation
#
# Runs sync check, parses results, and generates markdown report for PR comments.
#
# Usage:
#   ./scripts/ci-config-sync.sh <output_file>
#
# Example:
#   ./scripts/ci-config-sync.sh /tmp/sync-report.md
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${1:-/tmp/sync-report.md}"

# Run sync check and capture output
set +e  # Don't exit on error
SYNC_OUTPUT=$("$SCRIPT_DIR/sync-config.sh" --ci 2>&1)
EXIT_CODE=$?
set -e

# Extract warning and error counts from output
WARNINGS=$(echo "$SYNC_OUTPUT" | grep "^Warnings:" | awk '{print $2}' || echo "0")
ERRORS=$(echo "$SYNC_OUTPUT" | grep "^Errors:" | awk '{print $2}' || echo "0")

echo "Sync check completed: warnings=$WARNINGS errors=$ERRORS exit_code=$EXIT_CODE"

# Export to GitHub Actions if GITHUB_OUTPUT is set
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "warnings=$WARNINGS"
        echo "errors=$ERRORS"
        echo "exit_code=$EXIT_CODE"
    } >> "$GITHUB_OUTPUT"
fi

# Determine status
if [ "$ERRORS" -gt 0 ]; then
    STATUS="❌ **Configuration drift detected with errors**"
    SUMMARY="This PR has configuration inconsistencies that need to be addressed."
elif [ "$WARNINGS" -gt 0 ]; then
    STATUS="⚠️ **Configuration drift detected with warnings**"
    SUMMARY="This PR has minor configuration inconsistencies. Review recommended."
else
    STATUS="✅ **All configurations are synchronized**"
    SUMMARY="Docker Compose and Kubernetes configurations are properly synchronized."
fi

# Get commit info from environment or defaults
COMMIT_SHA="${COMMIT_SHA:-unknown}"
COMMIT_SHORT="${COMMIT_SHA:0:7}"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPO_URL="${REPO_URL:-https://github.com/user/repo}"

# Generate markdown report
cat > "$OUTPUT_FILE" << EOF
## 🔄 Configuration Sync Check

> **Analysis based on commit:** [\`${COMMIT_SHORT}\`](${REPO_URL}/commit/${COMMIT_SHA})
> **Generated at:** ${TIMESTAMP}

### Summary

${STATUS}

${SUMMARY}

### Results

- **Warnings:** ${WARNINGS}
- **Errors:** ${ERRORS}

EOF

# Add detailed findings if there are issues
if [ "$ERRORS" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << 'DETAILS_EOF'

### Detailed Findings

<details>
<summary>Click to expand full sync check output</summary>

```
DETAILS_EOF
    echo "$SYNC_OUTPUT" >> "$OUTPUT_FILE"
    cat >> "$OUTPUT_FILE" << 'DETAILS_END'
```

</details>

---

### 📋 Sync Checklist

When syncing configurations, ensure you update:

- [ ] **Image Versions**: docker-compose.yaml → k8s/*.yaml + helm/lightrag/values.yaml
- [ ] **Environment Variables**: .env files → k8s/01-configmaps.yaml + helm values
- [ ] **Ports**: Ensure consistency across all configurations
- [ ] **Resource Limits**: Update K8s/Helm resource definitions appropriately
- [ ] **Secrets**: Update k8s/02-secrets.yaml template (never commit real secrets!)

**Workflow**:
1. Review the drift report above
2. Sync changes from docker-compose.yaml to k8s/Helm configs
3. Run `./scripts/sync-config.sh` locally to verify
4. Push updates to this PR

📖 See [Development Workflow Guide](../blob/main/docs/DEVELOPMENT_WORKFLOW.md) for detailed sync procedures.
DETAILS_END
fi

# Add footer
cat >> "$OUTPUT_FILE" << 'EOF'

---
<sub>🤖 This comment will be automatically updated when new commits are pushed.</sub>
EOF

echo "Sync report generated: $OUTPUT_FILE"

# Exit with the original sync check exit code
exit $EXIT_CODE

# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated CI/CD processes.

## Workflows

### Secret Detection (`secret-detection.yml`)

**Purpose:** Automatically scan for secrets, API keys, passwords, and other sensitive information in all pull requests and pushes to protected branches.

**Triggers:**
- Pull requests (opened, synchronized, reopened)
- Pushes to `main`, `master`, `develop`, `release/**` branches
- Manual workflow dispatch

**Tools Used:**
- **Gitleaks** - Fast regex-based secret scanner
- **TruffleHog** - Deep scanner with verification

**What It Does:**
1. Scans entire repository history for secrets
2. Uses project configurations (`.gitleaks.toml`, `.trufflehog.yaml`)
3. Uploads findings to GitHub Security tab (SARIF format)
4. Posts results as PR comments with action items
5. Fails the build if secrets are detected

**Required Permissions:**
- `contents: read` - Checkout code
- `pull-requests: write` - Post comments
- `security-events: write` - Upload SARIF reports

**Viewing Results:**
- **PR Comments:** Automated summary with scan results
- **Security Tab:** Navigate to Security → Code scanning
- **Workflow Logs:** Click on failed runs for details

**Configuration:**
See [SECURITY.md](../SECURITY.md) for detailed documentation.

---

### Configuration Sync Check (`config-sync-check.yml`)

**Purpose:** Validates that configuration values are synchronized across Docker Compose, Kubernetes, and Helm configurations.

**Triggers:**
- Pull requests that modify:
  - `docker-compose.yaml`
  - `k8s/*.yaml`
  - `helm/lightrag/values.yaml`
  - The workflow file itself

**What It Does:**
1. Compares resource limits across configurations
2. Validates environment variables
3. Checks service endpoints and ports
4. Posts sync report as PR comment

---

### Cost Impact Analysis (`cost-estimate.yml`)

**Purpose:** Estimates infrastructure costs based on Kubernetes resource requests and limits.

**Triggers:**
- Pull requests that modify:
  - `helm/lightrag/values.yaml`
  - `k8s/*.yaml`
  - The workflow file itself

**What It Does:**
1. Calculates resource costs (CPU, memory, storage)
2. Compares against base branch
3. Shows cost deltas and impacts
4. Posts cost estimate as PR comment

---

## Workflow Best Practices

### For All Workflows

1. **Use specific action versions** - Pin to major versions (e.g., `@v4`)
2. **Minimize permissions** - Request only necessary permissions
3. **Cache dependencies** - Speed up workflow execution
4. **Use job summaries** - Provide clear output via `$GITHUB_STEP_SUMMARY`
5. **Update comments** - Don't create duplicate PR comments

### For Secret Detection

1. **Never bypass CI** - Local hooks can be skipped, CI cannot
2. **Review failures promptly** - Investigate all detected secrets
3. **Rotate exposed secrets** - If secrets reach the repo, rotate immediately
4. **Update configurations** - Maintain allowlists for false positives
5. **Monitor Security tab** - Regular review of code scanning results

### Adding New Workflows

When creating new workflows:

1. Use meaningful names and descriptions
2. Document triggers and permissions
3. Add comments explaining complex steps
4. Follow existing patterns (PR comments, job summaries)
5. Test with workflow_dispatch before enabling for PRs
6. Update this README with workflow documentation

## Troubleshooting

### Workflow Not Running

- Check trigger conditions match your branch/files
- Verify workflow file is valid YAML
- Look for workflow errors in Actions tab

### Permission Errors

- Ensure workflow has required permissions
- Check repository settings → Actions → General
- Verify `GITHUB_TOKEN` has necessary scopes

### Secret Detection False Positives

1. Verify it's actually a false positive (not a real secret!)
2. Add to allowlist in `.gitleaks.toml` or `.trufflehog.yaml`
3. Document the reason in the configuration file
4. Never add real secrets to allowlists

### Workflow Taking Too Long

For secret detection:
- Adjust scan depth if scanning full history
- Use incremental scanning for PRs
- Check for network issues with verification

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [TruffleHog Documentation](https://github.com/trufflesecurity/trufflehog)
- [SARIF Format](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- [Security Tab](https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/managing-code-scanning-alerts-for-your-repository)

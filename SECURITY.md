# Security

This document outlines the security measures implemented in the LightRAG project, particularly around secret detection and prevention.

## Secret Detection

To prevent accidental commits of secrets, API keys, passwords, and other sensitive information, this project uses automated secret detection via git hooks.

### Tools

We use a dual-layer approach for comprehensive secret detection:

1. **Gitleaks** - Fast regex-based secret scanner
   - Scans for known secret patterns (API keys, tokens, passwords, etc.)
   - Quick execution with minimal false positives
   - [GitHub](https://github.com/gitleaks/gitleaks)

2. **TruffleHog** - Deep secret scanner with verification
   - Uses entropy analysis to find high-entropy strings
   - Verifies secrets against actual services
   - Reduces false positives by only reporting verified secrets
   - [GitHub](https://github.com/trufflesecurity/trufflehog)

3. **Lefthook** - Git hooks manager
   - Manages and orchestrates the git hooks
   - Fast parallel execution
   - Easy team-wide setup
   - [GitHub](https://github.com/evilmartians/lefthook)

### Setup

#### First-time Setup

1. **Install tools via mise:**
   ```bash
   mise install
   ```
   This will install `gitleaks`, `trufflehog`, and `lefthook` as defined in `mise.toml`.

2. **Install git hooks:**
   ```bash
   lefthook install
   ```
   This creates the necessary git hooks in `.git/hooks/`.

3. **Verify installation:**
   ```bash
   lefthook run pre-commit
   ```
   This runs the pre-commit checks manually to ensure everything is working.

#### Automatic Setup

If you have mise hooks enabled (already configured in `mise.toml`), the setup will run automatically when you enter the project directory.

### How It Works

The secret detection runs automatically at two points:

1. **Pre-commit** - Before you create a commit
   - Gitleaks scans staged files for secret patterns
   - TruffleHog performs deep analysis on changes
   - Commit is blocked if secrets are detected

2. **Pre-push** - Before you push to remote (safety net)
   - Gitleaks scans all commits being pushed
   - Prevents pushing secrets even if pre-commit was bypassed
   - Last line of defense before secrets reach the remote

3. **CI/CD** - Automated checks on GitHub
   - Runs on all pull requests and pushes to main branches
   - Independent verification even if local hooks are bypassed
   - Blocks merging if secrets are detected
   - Posts results as PR comments

### CI Integration

Secret detection also runs automatically on GitHub Actions for all pull requests and pushes to protected branches. This provides an additional safety layer that cannot be bypassed.

#### GitHub Actions Workflow

The `.github/workflows/secret-detection.yml` workflow:

**Triggers on:**
- Pull requests (opened, synchronized, reopened)
- Pushes to `main`, `master`, `develop`, and `release/**` branches
- Manual workflow dispatch

**Jobs:**

1. **Gitleaks Job**
   - Scans entire repository history
   - Uses `.gitleaks.toml` configuration
   - Uploads results to GitHub Security tab (SARIF format)
   - Fails the build if secrets are found

2. **TruffleHog Job**
   - Performs deep scan with verification
   - Uses `.trufflehog.yaml` configuration
   - Only reports verified secrets
   - Fails the build if verified secrets are found

3. **Post Results Job**
   - Runs after both scanners complete
   - Posts a summary comment on pull requests
   - Updates existing comments instead of creating duplicates
   - Provides clear action items if secrets are detected

#### Viewing CI Results

**In Pull Requests:**
- Automated comment shows scan results in a table format
- Clear ✅/❌ status for each scanner
- Action items if secrets are detected
- Links to SECURITY.md for guidance

**In GitHub Security Tab:**
- Navigate to **Security** → **Code scanning**
- View detailed Gitleaks findings
- Filter by severity, status, and tool
- Track remediation over time

**In Workflow Logs:**
- Click on failed workflow run
- View detailed output from each scanner
- See exact locations of detected secrets

#### CI Permissions

The workflow requires these permissions:
- `contents: read` - To checkout code
- `pull-requests: write` - To post comments
- `security-events: write` - To upload SARIF reports

#### Bypassing CI (Not Recommended)

**Important:** Unlike local hooks, you cannot bypass CI checks. This is intentional for security.

- CI runs independently of local hooks
- Even if you use `LEFTHOOK=0` or `--no-verify` locally, CI still runs
- Pull requests cannot be merged if CI detects secrets
- This ensures team-wide enforcement

**If you need to bypass for a legitimate reason:**
1. Document the reason in PR description
2. Get approval from team lead/security team
3. Add specific exceptions to `.gitleaks.toml` or `.trufflehog.yaml`
4. Never bypass for actual secrets - rotate them instead

#### Monitoring and Alerts

**GitHub Notifications:**
- Workflow failures trigger GitHub notifications
- Subscribe to repository notifications for security alerts
- Security tab shows historical scan results

**Best Practices:**
- Review Security tab regularly
- Investigate all workflow failures promptly
- Don't ignore or bypass CI failures
- Use the opportunity to improve detection rules

### Configuration Files

- **`.gitleaks.toml`** - Gitleaks configuration
  - Custom rules for project-specific secrets
  - Allowlist for known false positives
  - Path exclusions (test files, docs, etc.)

- **`.trufflehog.yaml`** - TruffleHog configuration
  - Verification settings
  - Allowlist patterns
  - Path exclusions

- **`lefthook.yml`** - Git hooks configuration
  - Hook definitions and commands
  - Parallel execution settings
  - Error messages

### Usage

#### Normal Workflow

Just use git as usual! The hooks run automatically:

```bash
git add .
git commit -m "your message"  # Hooks run here automatically
git push                       # Hooks run here too
```

#### If Secrets Are Detected

1. **Remove the secret** from your code
2. **Replace with environment variable** or configuration
3. **Add to `.env.example`** with placeholder value
4. **Never commit the actual secret**

Example:
```bash
# Bad - secret in code
API_KEY = "sk-1234567890abcdef"

# Good - use environment variable
API_KEY = os.getenv("API_KEY")
```

#### Bypassing Hooks (Emergency Only)

**⚠️ WARNING: Only bypass if you're absolutely sure there are no secrets!**

To skip hooks temporarily:

```bash
# Skip all hooks
LEFTHOOK=0 git commit -m "your message"
LEFTHOOK=0 git push

# Or use git's built-in flag (skips all hooks)
git commit --no-verify -m "your message"
git push --no-verify
```

**Note:** Bypassing hooks should be rare and only for:
- False positives that can't be resolved immediately
- Emergency hotfixes (but review later!)
- Updating the hook configuration itself

#### Running Hooks Manually

You can run the hooks manually without committing:

```bash
# Run pre-commit checks
lefthook run pre-commit

# Run pre-push checks
lefthook run pre-push

# Run a specific command
lefthook run pre-commit --commands gitleaks
lefthook run pre-commit --commands trufflehog
```

#### Scanning Entire Repository

To scan the entire repository history:

```bash
# Gitleaks - scan all history
gitleaks detect --source=. --verbose

# TruffleHog - scan all history
trufflehog git file://. --only-verified
```

### Configuration Customization

#### Adding Allowlist Patterns

If you have legitimate strings that trigger false positives:

1. **For Gitleaks** - Edit `.gitleaks.toml`:
   ```toml
   [allowlist]
   regexes = [
       '''your_pattern_here''',
   ]
   ```

2. **For TruffleHog** - Edit `.trufflehog.yaml`:
   ```yaml
   allowlist:
     regexes:
       - "your_pattern_here"
   ```

#### Excluding Files/Paths

Add paths to exclude in the respective config files:

- `.gitleaks.toml` - `[allowlist.paths]` section
- `.trufflehog.yaml` - `exclude.paths` section

#### Custom Secret Patterns

Add project-specific secret patterns in `.gitleaks.toml`:

```toml
[[rules]]
id = "custom-secret"
description = "My custom secret pattern"
regex = '''your_regex_pattern'''
tags = ["custom"]
```

### Troubleshooting

#### Hooks Not Running

```bash
# Reinstall hooks
lefthook install

# Check lefthook status
lefthook version

# Verify tools are installed
which gitleaks
which trufflehog
which lefthook
```

#### False Positives

1. Verify it's actually a false positive (not a real secret!)
2. Add to allowlist in `.gitleaks.toml` or `.trufflehog.yaml`
3. Or temporarily bypass with `LEFTHOOK=0` (not recommended)

#### Performance Issues

If hooks are too slow:

1. **Disable TruffleHog for commits** (keep for push):
   - Edit `lefthook.yml` and remove trufflehog from `pre-commit`
   - Keep it in `pre-push` for thorough checking

2. **Adjust TruffleHog verification**:
   - Set `only-verified: true` to reduce noise (already configured)

3. **Use parallel execution** (already configured):
   - Lefthook runs commands in parallel by default

### Best Practices

1. **Never commit secrets** - Use environment variables
2. **Use `.env` files** - Keep them in `.gitignore`
3. **Provide `.env.example`** - With placeholder values
4. **Encrypt sensitive configs** - Use SOPS/age (already set up in this project)
5. **Review hook output** - Don't blindly bypass warnings
6. **Monitor CI results** - Check GitHub Actions and Security tab regularly
7. **Keep configs updated** - Maintain allowlists and exclusions
8. **Run manual scans** - Periodically scan full repository
9. **Rotate exposed secrets** - If secrets are pushed, rotate them immediately
10. **Document exceptions** - When adding allowlist entries, document why

### Secret Storage

This project uses SOPS with Age encryption for secret management:

- Encrypted secrets in `.secrets/` directory
- Age key management via mise
- See `mise.toml` for configuration

For more information on secret management with SOPS:
```bash
mise run --help
```

### Reporting Security Issues

If you discover a security vulnerability, please email [security contact] instead of using the issue tracker.

### Additional Resources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [TruffleHog Documentation](https://github.com/trufflesecurity/trufflehog)
- [Lefthook Documentation](https://github.com/evilmartians/lefthook)
- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

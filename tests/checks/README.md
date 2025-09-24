# Configuration Check Scripts

This directory contains individual check scripts that each perform one specific verification using a pattern-based naming system.

## Naming Pattern

All check scripts follow this pattern:
```
{group}-{service}-{test_name}.{ext}
```

Where:
- **group**: Category of the check (security, storage, communication, environment, monitoring, performance, wsl2)
- **service**: Service name from docker-compose.yaml or system component
- **test_name**: Descriptive name of what is being tested
- **ext**: Script extension (.sh, .ps1, .cmd, .bat)

## Examples

```bash
security-redis-auth.sh           # Redis authentication check (Bash)
storage-qdrant-analysis.sh       # Qdrant vector storage analysis (Bash)
communication-external-endpoints.sh # External API endpoint testing (Bash)
environment-system-domain.sh     # Domain configuration validation (Bash)
wsl2-windows-docker.ps1          # Windows Docker integration (PowerShell)
wsl2-windows-network.cmd         # Windows network integration (CMD)
wsl2-subdomain-integration.ps1   # Subdomain routing integration (PowerShell)
wsl2-system-integration.sh       # WSL2 system integration (Bash)
```

## Standard Output Format

Each check script must output results in this format:

```
STATUS|CHECK_NAME|MESSAGE|COMMAND
```

Where:
- **STATUS**: `ENABLED`, `DISABLED`, `BROKEN`, `PASS`, `FAIL`, `INFO`
- **CHECK_NAME**: Short descriptive name (no spaces, use underscores)
- **MESSAGE**: Human-readable description
- **COMMAND**: Exact command used for verification (optional)

## Group Categories

The orchestrator automatically discovers and groups checks by their filename prefix:

- **security-\***: Authentication and authorization checks
- **storage-\***: Data structure validation and analysis
- **communication-\***: Service connectivity and API testing
- **environment-\***: System configuration and setup
- **monitoring-\***: Health checks and monitoring validation
- **performance-\***: Performance thresholds and benchmarks
- **wsl2-\***: WSL2 Windows integration checks (PowerShell/CMD/Bash)
  - System integration and path conversion
  - Windows Docker Desktop integration
  - Network connectivity between WSL2 and Windows
  - Subdomain routing and DNS resolution
  - SSL certificate validation for subdomains

## Adding New Checks

To add a new check:

1. Create a script following the naming pattern: `{group}-{service}-{test}.sh`
2. Make it executable: `chmod +x {group}-{service}-{test}.sh`
3. Follow the GIVEN/WHEN/THEN structure in comments
4. Output results in the standard format
5. The orchestrator will automatically discover and run it

Example:
```bash
# Create new monitoring check for LightRAG health
touch monitoring-rag-health.sh
chmod +x monitoring-rag-health.sh
# The orchestrator will automatically include it in "Monitoring & Health" category
```

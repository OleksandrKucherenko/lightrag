# Configuration Check Scripts

This directory contains individual check scripts that each perform one specific verification using a pattern-based naming system.

## Naming Pattern

All check scripts follow this pattern:
```
{group}-{service}-{test_name}.sh
```

Where:
- **group**: Category of the check (security, storage, communication, environment, monitoring, performance)
- **service**: Service name from docker-compose.yaml or system component
- **test_name**: Descriptive name of what is being tested

## Examples

```bash
security-redis-auth.sh           # Redis authentication check
storage-qdrant-analysis.sh       # Qdrant vector storage analysis
communication-external-endpoints.sh # External API endpoint testing
environment-system-domain.sh     # Domain configuration validation
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

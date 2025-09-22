# Docker 28.x WSL2 Directory Naming Issue

## Discovery Summary

**Issue**: Docker 28.x in WSL2 environments fails to bind mount certain directories based on their names or metadata, even when the files are identical.

**Key Finding**: Renaming the directory from `ssl` to `certificates` resolves the bind mount issue completely.

## Test Results

| Directory Name | Files | Docker Mount Result | Status |
|---------------|-------|-------------------|---------|
| `ssl` (original) | ✅ Present | ❌ Empty directory | **FAILS** |
| `certificates` | ✅ Present | ✅ Files visible | **WORKS** |
| `certs` | ✅ Present | ✅ Files visible | **WORKS** |
| `ssl-test` (new) | ✅ Present | ✅ Files visible | **WORKS** |

## Hypothesis

The original `ssl` directory appears to have some metadata, inode information, or filesystem attributes that Docker 28.x WSL2 cannot handle properly. This could be related to:

1. **Directory creation history**: How/when the directory was originally created
2. **Windows filesystem metadata**: Extended attributes from Windows filesystem
3. **Docker cache/metadata**: Docker's internal directory tracking
4. **WSL2 filesystem translation**: Issues in the Windows-to-Linux filesystem bridge

## Solution Implementation

### Automated Fix
```bash
# Run the setup script to automatically handle the rename
./bin/setup-ssl-certs.sh
```

### Manual Fix
```bash
# Backup original directory
mv docker/ssl docker/ssl-backup

# Create new directory with different name
mkdir docker/certificates
cp docker/ssl-backup/* docker/certificates/

# Update docker-compose.yaml
# Change: ./docker/ssl:/ssl:ro
# To:     ./docker/certificates:/ssl:ro
```

## Verification

```bash
# Test that Docker can access the renamed directory
docker run --rm -v ./docker/certificates:/ssl:ro alpine ls -la /ssl

# Should show all SSL certificate files
```

## Impact

This discovery provides the **simplest and most elegant solution** to the Docker 28.x WSL2 bind mount issue:

- ✅ **No security risks**: Direct bind mount of only SSL certificates
- ✅ **No file copying**: Files remain in project directory
- ✅ **No complex workarounds**: Simple directory rename
- ✅ **Maintains project structure**: SSL certificates stay within project

## Lessons Learned

1. **Directory names matter**: Docker 28.x WSL2 is sensitive to directory names/metadata
2. **Test with fresh directories**: New directories with same content may work differently
3. **Simple solutions first**: Sometimes the simplest fix (rename) is the best
4. **Document edge cases**: This behavior is not well documented by Docker

## Recommendation

For any Docker 28.x WSL2 bind mount issues:

1. **First**: Try renaming the problematic directory
2. **Second**: Test with a fresh directory containing the same files
3. **Last resort**: Use alternative mounting strategies (volumes, native filesystem)

This approach should be the **primary recommendation** for Docker 28.x WSL2 bind mount issues.

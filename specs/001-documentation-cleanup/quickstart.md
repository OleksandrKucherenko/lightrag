# Documentation Cleanup Quickstart Guide

## Overview
This guide provides a step-by-step approach to cleaning up and consolidating the LightRAG project documentation.

## Prerequisites
- Git repository access
- Basic command line knowledge
- Understanding of markdown format
- Access to the project repository

## Quick Start Steps

### Step 1: Environment Setup
```bash
# Navigate to project directory
cd /path/to/lightrag

# Ensure you're on the correct branch
git checkout 001-documentation-cleanup

# Verify current documentation structure
ls -la docs/
```

### Step 2: Documentation Analysis
```bash
# Review existing documentation files
for file in docs/*.md; do
    echo "=== $file ==="
    head -20 "$file"
    echo ""
done

# Check README.md current state
head -50 README.md
```

### Step 3: Information Extraction
```bash
# Create extraction script
cat > bin/extract-docs-info.sh << 'EOF'
#!/bin/bash
# Script to extract key information from documentation files

echo "Extracting information from documentation files..."

# Function to extract section headers from markdown files
extract_sections() {
    local file="$1"
    echo "Processing: $file"
    grep -n "^## " "$file" | head -10
    echo ""
}

# Process all documentation files
for file in docs/*.md; do
    if [[ -f "$file" ]]; then
        extract_sections "$file"
    fi
done
EOF

chmod +x bin/extract-docs-info.sh
```

### Step 4: Consolidation Process
```bash
# Run extraction script
./bin/extract-docs-info.sh

# Manual review process:
# 1. Read each documentation file
# 2. Identify key information that should be in README
# 3. Note which files can be deprecated
# 4. Plan the new README structure
```

### Step 5: Implementation
```bash
# Backup current README
cp README.md README.md.backup

# Create new consolidated README structure
# (Manual process - see consolidation plan)

# Move deprecated files
mkdir -p .deprecated
mv docs/deprecated-file-1.md .deprecated/
mv docs/deprecated-file-2.md .deprecated/

# Update README with extracted information
# (Manual process)
```

### Step 6: Verification
```bash
# Run verification script
./bin/verify-docs-cleanup.sh

# Check that all essential information is preserved
grep -r "essential-topic" README.md

# Verify no broken links
# (Manual verification required)
```

## Key Information to Extract

### From TESTING.md
- Test framework overview
- GIVEN/WHEN/THEN testing pattern
- Test categories and how to run them
- Troubleshooting information

### From Performance Documentation
- Performance optimization guidelines
- Configuration recommendations
- Benchmarking information

### From Configuration Documentation
- Caddy proxy setup details
- Domain configuration steps
- SSL certificate management

## Consolidation Structure

The new README.md should follow this structure:
1. **Project Overview** (existing)
2. **Quick Start** (existing + enhancements)
3. **Configuration** (consolidated from multiple docs)
4. **Testing** (extracted from TESTING.md)
5. **Performance** (extracted from performance docs)
6. **Troubleshooting** (consolidated from various sources)
7. **Development** (existing)
8. **Contributing** (existing)

## Success Criteria
- [ ] All essential information from docs/ is accessible from README.md
- [ ] Deprecated files are properly archived in .deprecated/
- [ ] No broken links or references
- [ ] Documentation is easier to navigate
- [ ] All changes are tested and verified

## Troubleshooting

### Common Issues
- **Missing information**: Check if content was accidentally omitted during consolidation
- **Broken links**: Verify all internal links point to correct locations
- **File permissions**: Ensure .deprecated/ directory maintains proper permissions

### Recovery Steps
- Use `README.md.backup` to restore previous version if needed
- Check git history for specific changes
- Verify consolidation against the original documentation files

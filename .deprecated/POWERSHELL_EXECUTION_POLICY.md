# PowerShell Execution Policy Support

The LightRAG testing framework automatically handles PowerShell execution policy issues to ensure seamless script execution across all Windows configurations.

## Automatic Execution Policy Bypass

### **Main Verification Script**
The `verify.configuration.v3.sh` script automatically runs all PowerShell scripts with:
```bash
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$script_path"
```

### **Key Features**
- ✅ **`-ExecutionPolicy Bypass`**: Skips signature verification requirements
- ✅ **`-NoProfile`**: Faster startup by skipping PowerShell profile loading
- ✅ **UNC Path Handling**: Copies scripts to Windows temp folder to avoid UNC path restrictions
- ✅ **Timeout Protection**: Prevents hanging on execution policy prompts

## Implementation Details

### **Script Copying Process**
1. **Get Windows temp directory**: `cmd.exe /c "echo %TEMP%"`
2. **Convert to WSL path**: `wslpath "$windows_temp"`
3. **Copy script**: Avoid UNC path issues by copying to Windows filesystem
4. **Execute with bypass**: Run with full execution policy bypass
5. **Cleanup**: Remove temporary script file after execution

### **Error Handling**
- **PowerShell not available**: Graceful fallback with informative messages
- **Copy failures**: Clear error messages about temp folder access
- **Execution failures**: Distinguishes between timeout and execution policy issues

## Supported PowerShell Scripts

All PowerShell scripts in the testing framework use this approach:

### **WSL2 Integration Scripts**
- `wsl2-windows-rootca.ps1` - Windows certificate validation
- `wsl2-windows-docker.ps1` - Docker Desktop integration checks
- `wsl2-subdomain-integration.ps1` - Subdomain accessibility testing

### **Individual Script Execution**
For manual testing, always use the bypass flag:
```powershell
# Correct way to run PowerShell scripts manually
powershell.exe -ExecutionPolicy Bypass -File ".\script-name.ps1"

# Or use the wrapper script
.\run-powershell-check.cmd script-name.ps1
```

## Execution Policy Levels

### **Windows PowerShell Execution Policies**
- **Restricted** (Default): No scripts allowed
- **AllSigned**: Only signed scripts allowed
- **RemoteSigned**: Local scripts OK, remote scripts must be signed
- **Unrestricted**: All scripts allowed with warnings
- **Bypass**: No restrictions or warnings (used by framework)

### **Why Bypass is Safe**
- Scripts are **locally developed** and **version controlled**
- **Temporary execution** only during testing
- **No permanent policy changes** to the system
- **Isolated to testing framework** usage

## Troubleshooting

### **Common Issues and Solutions**

1. **"Execution policy does not allow this script"**
   ```bash
   # Solution: Use the main verification script (automatic bypass)
   ./tests/verify.configuration.v3.sh
   ```

2. **"UNC paths are not supported"**
   ```bash
   # Solution: Framework automatically copies to Windows temp folder
   # No action needed - handled automatically
   ```

3. **"PowerShell not found"**
   ```bash
   # Check if PowerShell is available in WSL2
   which powershell.exe
   
   # If not found, ensure Windows PowerShell is accessible
   export PATH="$PATH:/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
   ```

## Security Considerations

### **Framework Security Measures**
- **Script validation**: All scripts are version-controlled and reviewed
- **Temporary execution**: No permanent system changes
- **Isolated scope**: Bypass only applies to individual script execution
- **No profile loading**: `-NoProfile` prevents loading of user customizations

### **Best Practices**
- ✅ Always use the main verification script for automated testing
- ✅ Use `-ExecutionPolicy Bypass` for manual PowerShell script testing
- ✅ Never permanently change system execution policy for testing
- ❌ Don't run unknown PowerShell scripts with bypass

## Integration with CI/CD

The framework's automatic execution policy handling makes it suitable for:
- **Automated testing pipelines**
- **Developer workstation validation**
- **Production deployment verification**
- **Cross-platform compatibility testing**

All PowerShell execution policy complexities are handled transparently! 🎉

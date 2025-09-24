@echo off
REM =============================================================================
REM WSL2 Windows Network Integration Check (CMD)
REM =============================================================================
REM 
REM GIVEN: WSL2 environment with Windows network integration
REM WHEN: We test network connectivity between WSL2 and Windows
REM THEN: We verify network integration is working properly
REM =============================================================================

REM Change to Windows temp directory to avoid UNC path issues
cd /d %TEMP% >nul 2>&1

REM Check if we can resolve Windows hostname from WSL2 (with timeout)
ping -n 1 -w 2000 %COMPUTERNAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|Can resolve Windows hostname from WSL2: %COMPUTERNAME%^|ping -w 2000 %COMPUTERNAME%
) else (
    echo FAIL^|windows_network^|Cannot resolve Windows hostname from WSL2: %COMPUTERNAME%^|ping -w 2000 %COMPUTERNAME%
)

REM Check Windows localhost accessibility (with timeout)
ping -n 1 -w 1000 127.0.0.1 >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|Windows localhost accessible^|ping -w 1000 127.0.0.1
) else (
    echo FAIL^|windows_network^|Windows localhost not accessible^|ping -w 1000 127.0.0.1
)

REM Check if Windows firewall allows WSL2 connections
netsh advfirewall firewall show rule name="vEthernet (WSL)" >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|WSL2 firewall rule exists^|netsh advfirewall firewall show rule name="vEthernet (WSL)"
) else (
    echo INFO^|windows_network^|WSL2 firewall rule not found - may use default rules^|netsh advfirewall firewall show rule name="vEthernet (WSL)"
)

REM Check WSL2 network adapter
ipconfig /all | findstr "vEthernet (WSL)" >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|WSL2 network adapter present^|ipconfig /all ^| findstr "vEthernet (WSL)"
) else (
    echo FAIL^|windows_network^|WSL2 network adapter not found^|ipconfig /all ^| findstr "vEthernet (WSL)"
)

REM Test subdomain resolution from Windows
set DOMAIN=%PUBLISH_DOMAIN%
if "%DOMAIN%"=="" set DOMAIN=dev.localhost

REM Test main domain resolution via ping (works with hosts file)
ping -n 1 -w 2000 %DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|Main domain resolves from Windows: %DOMAIN%^|ping -n 1 %DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|Main domain resolution failed from Windows: %DOMAIN%^|ping -n 1 %DOMAIN%
)

REM Test subdomain resolution via ping (works with hosts file)
ping -n 1 -w 2000 rag.%DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|LightRAG subdomain resolves from Windows: rag.%DOMAIN%^|ping -n 1 rag.%DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|LightRAG subdomain resolution failed from Windows: rag.%DOMAIN%^|ping -n 1 rag.%DOMAIN%
)

ping -n 1 -w 2000 lobechat.%DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|LobeChat subdomain resolves from Windows: lobechat.%DOMAIN%^|ping -n 1 lobechat.%DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|LobeChat subdomain resolution failed from Windows: lobechat.%DOMAIN%^|ping -n 1 lobechat.%DOMAIN%
)

REM Test subdomain connectivity with curl (if available, with short timeout)
where curl >nul 2>&1
if %errorlevel% equ 0 (
    timeout 8 curl -I -s -k --connect-timeout 2 --max-time 5 https://rag.%DOMAIN% >nul 2>&1
    if %errorlevel% equ 0 (
        echo PASS^|windows_subdomain^|LightRAG subdomain accessible from Windows: https://rag.%DOMAIN%^|curl -I --connect-timeout 2 https://rag.%DOMAIN%
    ) else (
        echo FAIL^|windows_subdomain^|LightRAG subdomain not accessible from Windows: https://rag.%DOMAIN%^|curl -I --connect-timeout 2 https://rag.%DOMAIN%
    )
) else (
    echo INFO^|windows_subdomain^|curl not available for connectivity testing^|where curl
)

@echo off
REM =============================================================================
REM WSL2 Windows Network Integration Check (CMD)
REM =============================================================================
REM 
REM GIVEN: WSL2 environment with Windows network integration
REM WHEN: We test network connectivity between WSL2 and Windows
REM THEN: We verify network integration is working properly
REM =============================================================================

REM Check if we can resolve Windows hostname from WSL2
ping -n 1 %COMPUTERNAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|Can resolve Windows hostname from WSL2: %COMPUTERNAME%^|ping %COMPUTERNAME%
) else (
    echo FAIL^|windows_network^|Cannot resolve Windows hostname from WSL2: %COMPUTERNAME%^|ping %COMPUTERNAME%
)

REM Check Windows localhost accessibility
ping -n 1 127.0.0.1 >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_network^|Windows localhost accessible^|ping 127.0.0.1
) else (
    echo FAIL^|windows_network^|Windows localhost not accessible^|ping 127.0.0.1
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

REM Test main domain resolution
nslookup %DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|Main domain resolves from Windows: %DOMAIN%^|nslookup %DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|Main domain resolution failed from Windows: %DOMAIN%^|nslookup %DOMAIN%
)

REM Test subdomain resolution
nslookup rag.%DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|LightRAG subdomain resolves from Windows: rag.%DOMAIN%^|nslookup rag.%DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|LightRAG subdomain resolution failed from Windows: rag.%DOMAIN%^|nslookup rag.%DOMAIN%
)

nslookup lobechat.%DOMAIN% >nul 2>&1
if %errorlevel% equ 0 (
    echo PASS^|windows_subdomain^|LobeChat subdomain resolves from Windows: lobechat.%DOMAIN%^|nslookup lobechat.%DOMAIN%
) else (
    echo FAIL^|windows_subdomain^|LobeChat subdomain resolution failed from Windows: lobechat.%DOMAIN%^|nslookup lobechat.%DOMAIN%
)

REM Test subdomain connectivity with curl (if available)
where curl >nul 2>&1
if %errorlevel% equ 0 (
    curl -I -s -k --connect-timeout 3 https://rag.%DOMAIN% >nul 2>&1
    if %errorlevel% equ 0 (
        echo PASS^|windows_subdomain^|LightRAG subdomain accessible from Windows: https://rag.%DOMAIN%^|curl -I https://rag.%DOMAIN%
    ) else (
        echo FAIL^|windows_subdomain^|LightRAG subdomain not accessible from Windows: https://rag.%DOMAIN%^|curl -I https://rag.%DOMAIN%
    )
) else (
    echo INFO^|windows_subdomain^|curl not available for connectivity testing^|where curl
)

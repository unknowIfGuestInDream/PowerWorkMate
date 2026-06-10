@echo off
setlocal

set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%Start-PowerWorkMate.ps1"
set "WINPS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if exist "%WINPS%" (
    "%WINPS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" %*
    exit /b %ERRORLEVEL%
)

where pwsh.exe >nul 2>nul
if errorlevel 1 (
    echo [PowerWorkMate] Unable to find Windows PowerShell 5.1 or pwsh.exe.
    exit /b 1
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" %*

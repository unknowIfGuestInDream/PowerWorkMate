@echo off
setlocal

set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%Start-PowerWorkMate.ps1"
set "WINPS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if exist "%WINPS%" (
    "%WINPS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" %*
    exit /b %ERRORLEVEL%
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" %*

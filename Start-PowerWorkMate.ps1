[CmdletBinding()]
param(
    [switch]$Minimized,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PwmLauncherIsWindows {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
        return [bool]$IsWindows
    }

    return $true
}

function Get-PwmLauncherExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $windowsPowerShell = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $windowsPowerShell) {
        return $windowsPowerShell
    }

    $pwsh = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }

    throw 'Unable to find Windows PowerShell 5.1 or pwsh.exe. Please install PowerShell before starting PowerWorkMate.'
}

if (-not (Test-PwmLauncherIsWindows)) {
    throw 'PowerWorkMate requires Windows with a desktop session. Use Pester tests for non-Windows development.'
}

$root = Split-Path -Path $PSCommandPath -Parent
$scriptPath = Join-Path -Path $root -ChildPath 'PowerWorkMate.ps1'
$powerShell = Get-PwmLauncherExecutable
$arguments = @(
    '-NoLogo'
    '-NoProfile'
    '-ExecutionPolicy'
    'Bypass'
    '-Sta'
    '-File'
    $scriptPath
)

if ($Minimized) {
    $arguments += '-Minimized'
}

if ($RemainingArguments) {
    $arguments += $RemainingArguments
}

Start-Process -FilePath $powerShell -ArgumentList $arguments -WorkingDirectory $root | Out-Null

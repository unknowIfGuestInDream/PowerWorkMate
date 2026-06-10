<#
    Shared bootstrap for PowerWorkMate Pester tests.

    Dot-source from a test's BeforeAll, then call Initialize-PwmTestContext to
    get a fresh, isolated data root and a ready-to-use JSON repository.
#>

$script:PwmRoot = Split-Path -Path $PSScriptRoot -Parent

# Utilities + services (services must load base before derived).
. (Join-Path $script:PwmRoot 'utils/Common.ps1')
. (Join-Path $script:PwmRoot 'utils/Security.ps1')
. (Join-Path $script:PwmRoot 'services/DataRepository.ps1')
. (Join-Path $script:PwmRoot 'services/JsonRepository.ps1')
. (Join-Path $script:PwmRoot 'services/SqliteRepository.ps1')

function Initialize-PwmTestContext {
    <#
    .SYNOPSIS
        Creates an isolated temp data root and returns a JsonRepository for it.
    #>
    [CmdletBinding()]
    param()

    $dir = Join-Path ([System.IO.Path]::GetTempPath()) (".pwm-test-" + [guid]::NewGuid().ToString('N'))
    $env:POWERWORKMATE_DATA = $dir
    Initialize-PwmDataRoot -Path $dir | Out-Null
    return [JsonRepository]::new($dir)
}

function Remove-PwmTestContext {
    [CmdletBinding()]
    param([string]$Path)

    if ($Path -and (Test-Path -LiteralPath $Path)) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:POWERWORKMATE_DATA = $null
}

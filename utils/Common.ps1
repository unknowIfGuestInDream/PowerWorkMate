<#
.SYNOPSIS
    Common helper functions shared across PowerWorkMate.

.DESCRIPTION
    Provides cross-cutting utilities: resolving the user data root,
    safe JSON read/write helpers and small validation helpers.

    User data is kept separate from program logic. By default it lives under
    %APPDATA%\PowerWorkMate on Windows. The POWERWORKMATE_DATA environment
    variable overrides the location (used by tests and portable installs);
    non-Windows hosts fall back to ~/.powerworkmate so the logic remains
    testable on any platform.
#>

Set-StrictMode -Version Latest

function Get-PwmDataRoot {
    <#
    .SYNOPSIS
        Returns the absolute path of the PowerWorkMate user-data directory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:POWERWORKMATE_DATA) {
        return $env:POWERWORKMATE_DATA
    }

    if ($env:APPDATA) {
        return (Join-Path -Path $env:APPDATA -ChildPath 'PowerWorkMate')
    }

    $userHome = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not $userHome) { $userHome = $env:HOME }
    return (Join-Path -Path $userHome -ChildPath '.powerworkmate')
}

function Initialize-PwmDataRoot {
    <#
    .SYNOPSIS
        Ensures the data root (and its notes sub-folder) exists and returns it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Path = (Get-PwmDataRoot)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    $notes = Join-Path -Path $Path -ChildPath 'notes'
    if (-not (Test-Path -LiteralPath $notes)) {
        New-Item -ItemType Directory -Path $notes -Force | Out-Null
    }

    return $Path
}

function Read-PwmJsonFile {
    <#
    .SYNOPSIS
        Reads a JSON file and returns the deserialized object.

    .DESCRIPTION
        Returns $Default (a new empty array by default) when the file is
        missing or empty. Throws on malformed JSON so corruption is visible.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [object]$Default = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    return ($raw | ConvertFrom-Json)
}

function Write-PwmJsonFile {
    <#
    .SYNOPSIS
        Serializes an object to JSON and writes it atomically to disk.

    .DESCRIPTION
        Writes to a temporary file first then moves it into place so a crash
        mid-write cannot leave a half-written (corrupt) data file behind.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject,

        [int]$Depth = 10
    )

    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Write JSON')) {
        $json = $InputObject | ConvertTo-Json -Depth $Depth
        $tmp = "$Path.tmp"
        Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8 -NoNewline
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }
}

function New-PwmId {
    <#
    .SYNOPSIS
        Returns a new GUID string used as a stable identifier for entities.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return [guid]::NewGuid().ToString()
}

function Test-PwmRegexPattern {
    <#
    .SYNOPSIS
        Returns $true when the supplied string is a valid .NET regex pattern.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pattern
    )

    try {
        [void][System.Text.RegularExpressions.Regex]::new($Pattern)
        return $true
    }
    catch {
        return $false
    }
}

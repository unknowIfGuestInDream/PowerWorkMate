<#
.SYNOPSIS
    FileSearch - module one: multi-directory file search.

.DESCRIPTION
    Manages the persisted list of work directories and performs filename
    searches across them. Supports plain text, wildcards (* ?) and regular
    expressions, extension filtering and folder / filename exclusions.

    All persistence goes through a DataRepository instance (passed in), so the
    module never touches data files directly.
#>

Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'utils' | Join-Path -ChildPath 'Common.ps1')

$script:WorkspaceCollection = 'workspaces'

function Get-PwmWorkspace {
    <#
    .SYNOPSIS
        Returns the persisted work directories.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    return @($Repository.GetCollection($script:WorkspaceCollection))
}

function Add-PwmWorkspace {
    <#
    .SYNOPSIS
        Adds a work directory (de-duplicated) and persists the list.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalized = $Path.TrimEnd('\', '/')
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($w in (Get-PwmWorkspace -Repository $Repository)) {
        if ($w.path -eq $normalized) {
            return @(Get-PwmWorkspace -Repository $Repository)
        }
        $items.Add($w)
    }

    $items.Add([pscustomobject]@{
        id      = (New-PwmId)
        path    = $normalized
        addedAt = (Get-Date).ToString('o')
    })

    $Repository.SaveCollection($script:WorkspaceCollection, $items.ToArray())
    return @($items.ToArray())
}

function Remove-PwmWorkspace {
    <#
    .SYNOPSIS
        Removes a work directory by path (or id) and persists the list.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalized = $Path.TrimEnd('\', '/')
    $remaining = @(Get-PwmWorkspace -Repository $Repository |
        Where-Object { $_.path -ne $normalized -and $_.id -ne $Path })

    $Repository.SaveCollection($script:WorkspaceCollection, $remaining)
    return $remaining
}

function Test-PwmPathExcluded {
    <#
    .SYNOPSIS
        Returns $true when a file lives under one of the excluded folders.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FullPath,

        [string]$Root,

        [string[]]$ExcludeFolders
    )

    if (-not $ExcludeFolders) { return $false }

    $relative = $FullPath
    if ($Root -and $FullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $FullPath.Substring($Root.Length)
    }
    $segments = $relative -split '[\\/]+' | Where-Object { $_ -ne '' }

    foreach ($segment in $segments) {
        foreach ($ex in $ExcludeFolders) {
            if ([string]::IsNullOrWhiteSpace($ex)) { continue }
            if ($segment -like $ex) { return $true }
        }
    }
    return $false
}

function Format-PwmFileSize {
    <#
    .SYNOPSIS
        Formats a byte count as a human readable size string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N1} GB' -f ($Bytes / 1GB))
}

function Search-PwmFile {
    <#
    .SYNOPSIS
        Searches one or more directories for files matching the criteria.

    .DESCRIPTION
        * Pattern is matched against the file name. With -Regex it is treated as
          a .NET regular expression; otherwise as a wildcard (* and ?). An empty
          pattern matches every file.
        * -Extensions limits results to the given extensions (with or without a
          leading dot, e.g. ps1 or .ps1).
        * -ExcludeFolders skips files under matching folder names (e.g. .git,
          node_modules). -ExcludeFilePattern skips files whose name matches a
          wildcard pattern.

    .OUTPUTS
        Objects with Name, FullPath, Directory, LastWriteTime, SizeBytes, Size.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [string]$Pattern = '',

        [switch]$Regex,

        [string[]]$Extensions,

        [string[]]$ExcludeFolders,

        [string[]]$ExcludeFilePattern
    )

    if ($Regex -and -not (Test-PwmRegexPattern -Pattern $Pattern)) {
        throw "Invalid regular expression: '$Pattern'."
    }

    $normExt = $null
    if ($Extensions) {
        $normExt = $Extensions | ForEach-Object {
            $e = $_.Trim()
            if ($e -and -not $e.StartsWith('.')) { $e = ".$e" }
            $e.ToLowerInvariant()
        } | Where-Object { $_ }
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($root in $Path) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }
        $rootFull = (Resolve-Path -LiteralPath $root).Path

        Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                $file = $_

                if (Test-PwmPathExcluded -FullPath $file.FullName -Root $rootFull -ExcludeFolders $ExcludeFolders) {
                    return
                }

                if ($normExt -and ($file.Extension.ToLowerInvariant() -notin $normExt)) {
                    return
                }

                if ($ExcludeFilePattern) {
                    foreach ($xp in $ExcludeFilePattern) {
                        if ($xp -and ($file.Name -like $xp)) { return }
                    }
                }

                $nameMatches = $true
                if (-not [string]::IsNullOrEmpty($Pattern)) {
                    if ($Regex) {
                        $nameMatches = [System.Text.RegularExpressions.Regex]::IsMatch(
                            $file.Name, $Pattern,
                            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    }
                    else {
                        $nameMatches = $file.Name -like $Pattern
                    }
                }
                if (-not $nameMatches) { return }

                $results.Add([pscustomobject]@{
                    Name          = $file.Name
                    FullPath      = $file.FullName
                    Directory     = $file.DirectoryName
                    LastWriteTime = $file.LastWriteTime
                    SizeBytes     = [long]$file.Length
                    Size          = (Format-PwmFileSize -Bytes ([long]$file.Length))
                })
            }
    }

    return @($results.ToArray())
}

Export-ModuleMember -Function @(
    'Get-PwmWorkspace',
    'Add-PwmWorkspace',
    'Remove-PwmWorkspace',
    'Search-PwmFile',
    'Test-PwmPathExcluded',
    'Format-PwmFileSize'
)

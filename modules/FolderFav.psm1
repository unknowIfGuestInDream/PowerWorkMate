<#
.SYNOPSIS
    FolderFav - module two: folder quick-links (favorites).

.DESCRIPTION
    Manages a list of folder shortcuts that is stored independently from the
    work directories, supporting add / remove / rename / reorder and open in
    Explorer, plus export / import. Persistence goes through a DataRepository.
#>

Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'utils' | Join-Path -ChildPath 'Common.ps1')

$script:FavoriteCollection = 'favorites'

function Get-PwmFavorite {
    <#
    .SYNOPSIS
        Returns the persisted folder quick-links in their stored order.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    return @($Repository.GetCollection($script:FavoriteCollection))
}

function Add-PwmFavorite {
    <#
    .SYNOPSIS
        Adds a folder quick-link. Name defaults to the leaf folder name.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Name
    )

    $normalized = $Path.TrimEnd('\', '/')
    if (-not $Name) {
        $Name = Split-Path -Path $normalized -Leaf
        if (-not $Name) { $Name = $normalized }
    }

    $items = @(Get-PwmFavorite -Repository $Repository)
    if ($items | Where-Object { $_.path -eq $normalized }) {
        return $items
    }

    $order = 0
    if ($items.Count -gt 0) {
        $order = (($items | Measure-Object -Property order -Maximum).Maximum) + 1
    }

    $new = [pscustomobject]@{
        id    = (New-PwmId)
        name  = $Name
        path  = $normalized
        order = $order
    }

    $updated = @($items + $new)
    $Repository.SaveCollection($script:FavoriteCollection, $updated)
    return $updated
}

function Remove-PwmFavorite {
    <#
    .SYNOPSIS
        Removes a quick-link by id.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $remaining = @(Get-PwmFavorite -Repository $Repository | Where-Object { $_.id -ne $Id })
    $Repository.SaveCollection($script:FavoriteCollection, $remaining)
    return $remaining
}

function Rename-PwmFavorite {
    <#
    .SYNOPSIS
        Renames a quick-link by id.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    $items = @(Get-PwmFavorite -Repository $Repository)
    foreach ($item in $items) {
        if ($item.id -eq $Id) {
            $item.name = $NewName
        }
    }
    $Repository.SaveCollection($script:FavoriteCollection, $items)
    return $items
}

function Set-PwmFavoriteOrder {
    <#
    .SYNOPSIS
        Reorders quick-links to match the supplied ordered list of ids.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string[]]$OrderedIds
    )

    $items = @(Get-PwmFavorite -Repository $Repository)
    $byId = @{}
    foreach ($item in $items) { $byId[$item.id] = $item }

    $ordered = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($id in $OrderedIds) {
        if ($byId.ContainsKey($id)) {
            $byId[$id].order = $index
            $ordered.Add($byId[$id])
            $byId.Remove($id)
            $index++
        }
    }
    # Append any ids not mentioned, preserving their relative order.
    foreach ($item in $items) {
        if ($byId.ContainsKey($item.id)) {
            $item.order = $index
            $ordered.Add($item)
            $index++
        }
    }

    $result = @($ordered.ToArray())
    $Repository.SaveCollection($script:FavoriteCollection, $result)
    return $result
}

function Open-PwmFavorite {
    <#
    .SYNOPSIS
        Opens a quick-link's folder in the system file explorer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Folder not found: '$Path'."
    }
    Invoke-Item -LiteralPath $Path
}

function Export-PwmFavorite {
    <#
    .SYNOPSIS
        Exports all quick-links to a JSON file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $items = @(Get-PwmFavorite -Repository $Repository)
    Write-PwmJsonFile -Path $Path -InputObject $items
}

function Import-PwmFavorite {
    <#
    .SYNOPSIS
        Imports quick-links from a JSON file, merging by path.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $imported = @(Read-PwmJsonFile -Path $Path -Default @())
    $existing = @(Get-PwmFavorite -Repository $Repository)
    $existingPaths = @($existing | ForEach-Object { $_.path })

    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($e in $existing) { $merged.Add($e) }

    foreach ($item in $imported) {
        if ($item.path -in $existingPaths) { continue }
        $merged.Add([pscustomobject]@{
            id    = if ($item.PSObject.Properties['id'] -and $item.id) { $item.id } else { New-PwmId }
            name  = $item.name
            path  = $item.path
            order = $merged.Count
        })
    }

    $result = @($merged.ToArray())
    $Repository.SaveCollection($script:FavoriteCollection, $result)
    return $result
}

Export-ModuleMember -Function @(
    'Get-PwmFavorite',
    'Add-PwmFavorite',
    'Remove-PwmFavorite',
    'Rename-PwmFavorite',
    'Set-PwmFavoriteOrder',
    'Open-PwmFavorite',
    'Export-PwmFavorite',
    'Import-PwmFavorite'
)

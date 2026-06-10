<#
.SYNOPSIS
    JsonRepository - JSON-file implementation of DataRepository.

.DESCRIPTION
    Stores each collection as <root>/<name>.json and each document as
    <root>/<folder>/<id>.json. Relies on the helpers in utils/Common.ps1
    (Read-PwmJsonFile / Write-PwmJsonFile / Initialize-PwmDataRoot), which
    must be dot-sourced into the session before the repository is used.

    Load order (see DataRepository.ps1):
        . utils/Common.ps1
        . services/DataRepository.ps1
        . services/JsonRepository.ps1
#>

Set-StrictMode -Version Latest

class JsonRepository : DataRepository {
    [string]$Root

    JsonRepository([string]$root) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            throw [System.ArgumentException]::new('Repository root path is required.')
        }
        $this.Root = (Initialize-PwmDataRoot -Path $root)
    }

    hidden [string] CollectionPath([string]$name) {
        return (Join-Path -Path $this.Root -ChildPath ("{0}.json" -f $name))
    }

    hidden [string] DocumentFolder([string]$folder) {
        $path = Join-Path -Path $this.Root -ChildPath $folder
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        return $path
    }

    [object[]] GetCollection([string]$name) {
        $data = Read-PwmJsonFile -Path ($this.CollectionPath($name)) -Default @()
        return @($data)
    }

    [void] SaveCollection([string]$name, [object[]]$items) {
        Write-PwmJsonFile -Path ($this.CollectionPath($name)) -InputObject @($items)
    }

    [string[]] ListDocuments([string]$folder) {
        $path = $this.DocumentFolder($folder)
        $files = Get-ChildItem -LiteralPath $path -Filter '*.json' -File -ErrorAction SilentlyContinue
        return @($files | ForEach-Object { $_.BaseName })
    }

    [object] GetDocument([string]$folder, [string]$id) {
        $file = Join-Path -Path ($this.DocumentFolder($folder)) -ChildPath ("{0}.json" -f $id)
        if (-not (Test-Path -LiteralPath $file)) {
            return $null
        }
        return (Read-PwmJsonFile -Path $file -Default $null)
    }

    [void] SaveDocument([string]$folder, [string]$id, [object]$document) {
        $file = Join-Path -Path ($this.DocumentFolder($folder)) -ChildPath ("{0}.json" -f $id)
        Write-PwmJsonFile -Path $file -InputObject $document
    }

    [bool] RemoveDocument([string]$folder, [string]$id) {
        $file = Join-Path -Path ($this.DocumentFolder($folder)) -ChildPath ("{0}.json" -f $id)
        if (Test-Path -LiteralPath $file) {
            Remove-Item -LiteralPath $file -Force
            return $true
        }
        return $false
    }
}

function New-PwmRepository {
    <#
    .SYNOPSIS
        Factory that returns the active DataRepository implementation.

    .DESCRIPTION
        Currently always returns a JsonRepository. When SqliteRepository is
        completed, switch on $Backend here so callers never change.
    #>
    [CmdletBinding()]
    [OutputType([DataRepository])]
    param(
        [string]$Root = (Get-PwmDataRoot),

        [ValidateSet('Json', 'Sqlite')]
        [string]$Backend = 'Json'
    )

    switch ($Backend) {
        'Sqlite' {
            throw [System.NotImplementedException]::new('The SQLite backend is reserved for a future release. Use -Backend Json.')
        }
        default {
            return [JsonRepository]::new($Root)
        }
    }
}

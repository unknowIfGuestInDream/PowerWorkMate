<#
.SYNOPSIS
    SqliteRepository - reserved SQLite implementation of DataRepository.

.DESCRIPTION
    Placeholder kept to honour the "reserve room for SQLite" requirement and to
    document the intended extension point. The methods deliberately throw
    NotImplementedException so the backend cannot be selected by accident.

    To complete this backend:
      * ship a SQLite engine (e.g. System.Data.SQLite or Microsoft.Data.Sqlite),
      * map collections to a key/value table and documents to a folder/id table,
      * register the backend in New-PwmRepository (services/JsonRepository.ps1).

    Load order (see DataRepository.ps1):
        . services/DataRepository.ps1
        . services/SqliteRepository.ps1
#>

Set-StrictMode -Version Latest

class SqliteRepository : DataRepository {
    [string]$DatabasePath

    SqliteRepository([string]$databasePath) {
        $this.DatabasePath = $databasePath
        throw [System.NotImplementedException]::new('SqliteRepository is reserved for a future release.')
    }

    [object[]] GetCollection([string]$name) {
        throw [System.NotImplementedException]::new('SqliteRepository.GetCollection is not implemented yet.')
    }

    [void] SaveCollection([string]$name, [object[]]$items) {
        throw [System.NotImplementedException]::new('SqliteRepository.SaveCollection is not implemented yet.')
    }

    [string[]] ListDocuments([string]$folder) {
        throw [System.NotImplementedException]::new('SqliteRepository.ListDocuments is not implemented yet.')
    }

    [object] GetDocument([string]$folder, [string]$id) {
        throw [System.NotImplementedException]::new('SqliteRepository.GetDocument is not implemented yet.')
    }

    [void] SaveDocument([string]$folder, [string]$id, [object]$document) {
        throw [System.NotImplementedException]::new('SqliteRepository.SaveDocument is not implemented yet.')
    }

    [bool] RemoveDocument([string]$folder, [string]$id) {
        throw [System.NotImplementedException]::new('SqliteRepository.RemoveDocument is not implemented yet.')
    }
}

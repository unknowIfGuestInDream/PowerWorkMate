<#
.SYNOPSIS
    DataRepository - the storage abstraction (interface) for PowerWorkMate.

.DESCRIPTION
    Defines the contract every storage backend must implement. Business logic
    (modules / services) talks only to this interface, never to files or a
    database directly, so the backend can be swapped (JSON now, SQLite later)
    without touching callers.

    PowerShell parses a whole file before executing it, so a derived class
    cannot extend a base class that is dot-sourced from inside the same file.
    Load the repository files in dependency order instead:

        . services/DataRepository.ps1
        . services/JsonRepository.ps1
        . services/SqliteRepository.ps1

    Use New-PwmRepository (see JsonRepository.ps1) to obtain an instance.

    The contract has two layers:
      * Collections - a named list of objects (workspaces, favorites, vault...).
      * Documents   - an individually addressable file inside a folder, used by
                      notes so each note is its own file as required by the spec.
#>

Set-StrictMode -Version Latest

class DataRepository {
    # --- Collection API -----------------------------------------------------

    # Returns all items in a named collection as an array (empty when absent).
    [object[]] GetCollection([string]$name) {
        throw [System.NotImplementedException]::new('GetCollection must be implemented by a derived repository.')
    }

    # Persists the full contents of a named collection.
    [void] SaveCollection([string]$name, [object[]]$items) {
        throw [System.NotImplementedException]::new('SaveCollection must be implemented by a derived repository.')
    }

    # --- Document API (one addressable record per id) -----------------------

    # Returns the ids of every document in a folder.
    [string[]] ListDocuments([string]$folder) {
        throw [System.NotImplementedException]::new('ListDocuments must be implemented by a derived repository.')
    }

    # Returns a single document, or $null when it does not exist.
    [object] GetDocument([string]$folder, [string]$id) {
        throw [System.NotImplementedException]::new('GetDocument must be implemented by a derived repository.')
    }

    # Creates or replaces a single document.
    [void] SaveDocument([string]$folder, [string]$id, [object]$document) {
        throw [System.NotImplementedException]::new('SaveDocument must be implemented by a derived repository.')
    }

    # Removes a single document. Returns $true when something was deleted.
    [bool] RemoveDocument([string]$folder, [string]$id) {
        throw [System.NotImplementedException]::new('RemoveDocument must be implemented by a derived repository.')
    }
}

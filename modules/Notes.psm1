<#
.SYNOPSIS
    Notes - module five: memo / sticky notes.

.DESCRIPTION
    Supports multiple notes, each with its own title and content, persisted as
    an individual document (one file per note) through the DataRepository
    document API. Provides create / read / update (save) / delete and a
    lightweight list of note metadata for the UI's left-hand list.
#>

Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'utils' | Join-Path -ChildPath 'Common.ps1')

$script:NotesFolder = 'notes'

function Get-PwmNoteList {
    <#
    .SYNOPSIS
        Returns metadata (id, title, updatedAt) for every note, newest first.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($id in $Repository.ListDocuments($script:NotesFolder)) {
        $note = $Repository.GetDocument($script:NotesFolder, $id)
        if ($null -eq $note) { continue }
        $list.Add([pscustomobject]@{
            id        = $note.id
            title     = $note.title
            updatedAt = $note.updatedAt
        })
    }

    return @($list.ToArray() | Sort-Object -Property updatedAt -Descending)
}

function New-PwmNote {
    <#
    .SYNOPSIS
        Creates a new note and returns it.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [string]$Title = 'Untitled',

        [string]$Content = ''
    )

    $now = (Get-Date).ToString('o')
    $note = [pscustomobject]@{
        id        = (New-PwmId)
        title     = $Title
        content   = $Content
        createdAt = $now
        updatedAt = $now
    }

    $Repository.SaveDocument($script:NotesFolder, $note.id, $note)
    return $note
}

function Get-PwmNote {
    <#
    .SYNOPSIS
        Returns a single note by id, or $null when it does not exist.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    return $Repository.GetDocument($script:NotesFolder, $Id)
}

function Set-PwmNote {
    <#
    .SYNOPSIS
        Updates a note's title and/or content (auto-save) and returns it.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id,

        [string]$Title,

        [string]$Content
    )

    $note = $Repository.GetDocument($script:NotesFolder, $Id)
    if ($null -eq $note) {
        throw "Note not found: '$Id'."
    }

    if ($PSBoundParameters.ContainsKey('Title')) { $note.title = $Title }
    if ($PSBoundParameters.ContainsKey('Content')) { $note.content = $Content }
    $note.updatedAt = (Get-Date).ToString('o')

    $Repository.SaveDocument($script:NotesFolder, $Id, $note)
    return $note
}

function Remove-PwmNote {
    <#
    .SYNOPSIS
        Deletes a note by id. Returns $true when a note was removed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    return $Repository.RemoveDocument($script:NotesFolder, $Id)
}

Export-ModuleMember -Function @(
    'Get-PwmNoteList',
    'New-PwmNote',
    'Get-PwmNote',
    'Set-PwmNote',
    'Remove-PwmNote'
)

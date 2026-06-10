<#
.SYNOPSIS
    CredentialVault - module six: credential / secret keeper.

.DESCRIPTION
    Stores credential entries (name, account, secret, notes). Secrets are
    encrypted at rest via utils/Security.ps1 (DPAPI on Windows, AES fallback
    elsewhere) and are never returned in clear text by list operations. The
    plain-text secret is only produced on explicit request (reveal / copy).
#>

Set-StrictMode -Version Latest

$script:UtilsDir = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'utils')
. (Join-Path -Path $script:UtilsDir -ChildPath 'Common.ps1')
. (Join-Path -Path $script:UtilsDir -ChildPath 'Security.ps1')

$script:CredentialCollection = 'credentials'
$script:Mask = '********'

function Get-PwmCredential {
    <#
    .SYNOPSIS
        Returns credential entries with the secret masked (never in clear text).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    $entries = @($Repository.GetCollection($script:CredentialCollection))
    return @($entries | ForEach-Object {
        [pscustomobject]@{
            id           = $_.id
            name         = $_.name
            account      = $_.account
            notes        = $_.notes
            secretMasked = $script:Mask
            updatedAt    = $_.updatedAt
        }
    })
}

function Add-PwmCredential {
    <#
    .SYNOPSIS
        Adds a credential entry, encrypting the secret at rest.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Account = '',

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Secret,

        [string]$Notes = ''
    )

    $entry = [pscustomobject]@{
        id        = (New-PwmId)
        name      = $Name
        account   = $Account
        secret    = (Protect-PwmSecret -PlainText $Secret)
        notes     = $Notes
        updatedAt = (Get-Date).ToString('o')
    }

    $entries = @($Repository.GetCollection($script:CredentialCollection))
    $updated = @($entries + $entry)
    $Repository.SaveCollection($script:CredentialCollection, $updated)
    return $entry
}

function Set-PwmCredential {
    <#
    .SYNOPSIS
        Updates an existing credential entry. Only supplied fields change.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id,

        [string]$Name,

        [string]$Account,

        [string]$Secret,

        [string]$Notes
    )

    $entries = @($Repository.GetCollection($script:CredentialCollection))
    $found = $null
    foreach ($e in $entries) {
        if ($e.id -eq $Id) {
            if ($PSBoundParameters.ContainsKey('Name'))    { $e.name = $Name }
            if ($PSBoundParameters.ContainsKey('Account')) { $e.account = $Account }
            if ($PSBoundParameters.ContainsKey('Notes'))   { $e.notes = $Notes }
            if ($PSBoundParameters.ContainsKey('Secret'))  { $e.secret = (Protect-PwmSecret -PlainText $Secret) }
            $e.updatedAt = (Get-Date).ToString('o')
            $found = $e
        }
    }

    if ($null -eq $found) {
        throw "Credential not found: '$Id'."
    }

    $Repository.SaveCollection($script:CredentialCollection, $entries)
    return $found
}

function Remove-PwmCredential {
    <#
    .SYNOPSIS
        Removes a credential entry by id.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $remaining = @($Repository.GetCollection($script:CredentialCollection) |
        Where-Object { $_.id -ne $Id })
    $Repository.SaveCollection($script:CredentialCollection, $remaining)
    return $remaining
}

function Get-PwmCredentialSecret {
    <#
    .SYNOPSIS
        Decrypts and returns the clear-text secret for a single entry.

    .NOTES
        Use only when the user explicitly reveals or copies a secret.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $entry = $Repository.GetCollection($script:CredentialCollection) |
        Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if ($null -eq $entry) {
        throw "Credential not found: '$Id'."
    }
    return (Unprotect-PwmSecret -CipherText $entry.secret)
}

function Copy-PwmCredentialSecret {
    <#
    .SYNOPSIS
        Copies an entry's secret to the clipboard. Returns a status message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $secret = Get-PwmCredentialSecret -Repository $Repository -Id $Id
    if (Get-Command -Name Set-Clipboard -ErrorAction SilentlyContinue) {
        Set-Clipboard -Value $secret
        return 'Copied'
    }
    throw 'Clipboard is not available on this host.'
}

Export-ModuleMember -Function @(
    'Get-PwmCredential',
    'Add-PwmCredential',
    'Set-PwmCredential',
    'Remove-PwmCredential',
    'Get-PwmCredentialSecret',
    'Copy-PwmCredentialSecret'
)

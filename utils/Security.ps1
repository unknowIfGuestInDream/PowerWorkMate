<#
.SYNOPSIS
    Encryption helpers for PowerWorkMate sensitive data.

.DESCRIPTION
    Sensitive fields (credentials / keys) are never stored in plain text.

    On Windows the primary mechanism is the Windows Data Protection API
    (DPAPI) scoped to the current user, exactly as required by the spec.
    DPAPI is not available on .NET Core / non-Windows hosts, so a documented
    AES fallback (key derived from the current user + machine identity) keeps
    the vault logic round-trippable and testable on any platform. The chosen
    scheme is recorded as a prefix on the cipher text so values can be read
    back regardless of where they were written.
#>

Set-StrictMode -Version Latest

$script:PwmDpapiAvailable = $null

function Test-PwmDpapiAvailable {
    <#
    .SYNOPSIS
        Returns $true when Windows DPAPI (ProtectedData) can be used.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -ne $script:PwmDpapiAvailable) {
        return $script:PwmDpapiAvailable
    }

    $available = $false
    $isWindowsHost = $true
    if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
        $isWindowsHost = $IsWindows
    }

    if ($isWindowsHost) {
        try {
            Add-Type -AssemblyName 'System.Security' -ErrorAction Stop
            $available = $null -ne ([System.Security.Cryptography.ProtectedData])
        }
        catch {
            $available = $false
        }
    }

    $script:PwmDpapiAvailable = $available
    return $available
}

function Get-PwmFallbackKey {
    <#
    .SYNOPSIS
        Derives a 256-bit AES key from the current user/machine identity.
    .NOTES
        Used only when DPAPI is unavailable (non-Windows dev/test hosts).
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param()

    $material = '{0}|{1}|PowerWorkMate' -f $env:USERNAME, $env:COMPUTERNAME
    if ([string]::IsNullOrEmpty($env:USERNAME) -and $env:USER) {
        $material = '{0}|{1}|PowerWorkMate' -f $env:USER, [System.Net.Dns]::GetHostName()
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($material))
    }
    finally {
        $sha.Dispose()
    }
}

function Protect-PwmSecret {
    <#
    .SYNOPSIS
        Encrypts a plain-text secret and returns a storable string.

    .OUTPUTS
        A string of the form "<scheme>:<base64>" where scheme is dpapi or aes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$PlainText
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)

    if (Test-PwmDpapiAvailable) {
        $cipher = [System.Security.Cryptography.ProtectedData]::Protect(
            $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return 'dpapi:' + [Convert]::ToBase64String($cipher)
    }

    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.Key = Get-PwmFallbackKey
        $aes.GenerateIV()
        $encryptor = $aes.CreateEncryptor()
        $cipher = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length)
        # Prepend the IV so decryption is self-contained.
        $payload = New-Object byte[] ($aes.IV.Length + $cipher.Length)
        [Array]::Copy($aes.IV, 0, $payload, 0, $aes.IV.Length)
        [Array]::Copy($cipher, 0, $payload, $aes.IV.Length, $cipher.Length)
        return 'aes:' + [Convert]::ToBase64String($payload)
    }
    finally {
        $aes.Dispose()
    }
}

function Unprotect-PwmSecret {
    <#
    .SYNOPSIS
        Decrypts a value produced by Protect-PwmSecret back to plain text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CipherText
    )

    if ([string]::IsNullOrEmpty($CipherText)) {
        return ''
    }

    $scheme, $data = $CipherText -split ':', 2
    if (-not $data) {
        # Treat unprefixed values as plain text for forward compatibility.
        return $CipherText
    }

    $payload = [Convert]::FromBase64String($data)

    switch ($scheme) {
        'dpapi' {
            if (-not (Test-PwmDpapiAvailable)) {
                throw 'This credential was encrypted with DPAPI and can only be read on the original Windows user account.'
            }
            $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                $payload, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        }
        'aes' {
            $aes = [System.Security.Cryptography.Aes]::Create()
            try {
                $aes.Key = Get-PwmFallbackKey
                $ivLength = $aes.BlockSize / 8
                $iv = New-Object byte[] $ivLength
                [Array]::Copy($payload, 0, $iv, 0, $ivLength)
                $aes.IV = $iv
                $cipher = New-Object byte[] ($payload.Length - $ivLength)
                [Array]::Copy($payload, $ivLength, $cipher, 0, $cipher.Length)
                $decryptor = $aes.CreateDecryptor()
                $bytes = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
                return [System.Text.Encoding]::UTF8.GetString($bytes)
            }
            finally {
                $aes.Dispose()
            }
        }
        default {
            throw "Unknown encryption scheme '$scheme'."
        }
    }
}

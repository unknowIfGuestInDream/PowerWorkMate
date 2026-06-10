<#
.SYNOPSIS
    SerialMonitor - module three: serial (COM) port monitor.

.DESCRIPTION
    Lists the system serial ports with a description, an availability status
    (probed by attempting to open the port) and, when available, the USB
    VID/PID hardware identifiers. Designed for embedded-development workflows.

    The hardware-detail lookups rely on Windows (CIM / WMI). On non-Windows
    hosts the functions degrade gracefully and simply report what .NET exposes.
#>

Set-StrictMode -Version Latest

function ConvertFrom-PwmDeviceId {
    <#
    .SYNOPSIS
        Extracts USB VID and PID from a PNPDeviceID / hardware id string.

    .EXAMPLE
        ConvertFrom-PwmDeviceId 'USB\VID_1A86&PID_7523\5&abc'
        # -> @{ VID = '1A86'; PID = '7523' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$DeviceId
    )

    $result = @{ VID = $null; PID = $null }
    if ([string]::IsNullOrEmpty($DeviceId)) { return $result }

    $vidMatch = [regex]::Match($DeviceId, 'VID_([0-9A-Fa-f]{4})')
    $pidMatch = [regex]::Match($DeviceId, 'PID_([0-9A-Fa-f]{4})')
    if ($vidMatch.Success) { $result.VID = $vidMatch.Groups[1].Value.ToUpperInvariant() }
    if ($pidMatch.Success) { $result.PID = $pidMatch.Groups[1].Value.ToUpperInvariant() }
    return $result
}

function Test-PwmSerialPortInUse {
    <#
    .SYNOPSIS
        Returns $true when a COM port cannot be opened (already in use / busy).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $port = $null
    try {
        $port = New-Object System.IO.Ports.SerialPort $Name
        $port.Open()
        return $false
    }
    catch {
        return $true
    }
    finally {
        if ($port -and $port.IsOpen) { $port.Close() }
        if ($port) { $port.Dispose() }
    }
}

function Get-PwmSerialPort {
    <#
    .SYNOPSIS
        Returns the available serial ports with status and hardware details.

    .OUTPUTS
        Objects with Name, Description, Status (Available/InUse), VID, PID.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [switch]$SkipProbe
    )

    $names = @()
    try {
        $names = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique
    }
    catch {
        $names = @()
    }

    # Collect hardware descriptions via CIM where available (Windows only).
    $details = @{}
    $isWindowsHost = $true
    if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
        $isWindowsHost = $IsWindows
    }
    if ($isWindowsHost) {
        try {
            $entities = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
                Where-Object { $_.Name -match '\(COM\d+\)' }
            foreach ($e in $entities) {
                $m = [regex]::Match($e.Name, '\((COM\d+)\)')
                if ($m.Success) {
                    $details[$m.Groups[1].Value] = $e
                }
            }
        }
        catch {
            $details = @{}
        }
    }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $names) {
        $description = $name
        $vid = $null
        $usbPid = $null
        if ($details.ContainsKey($name)) {
            $entity = $details[$name]
            $description = $entity.Name
            $ids = ConvertFrom-PwmDeviceId -DeviceId ([string]$entity.PNPDeviceID)
            $vid = $ids.VID
            $usbPid = $ids.PID
        }

        $status = 'Unknown'
        if (-not $SkipProbe) {
            $status = if (Test-PwmSerialPortInUse -Name $name) { 'InUse' } else { 'Available' }
        }

        $results.Add([pscustomobject]@{
            Name        = $name
            Description = $description
            Status      = $status
            VID         = $vid
            PID         = $usbPid
        })
    }

    return @($results.ToArray())
}

Export-ModuleMember -Function @(
    'Get-PwmSerialPort',
    'Test-PwmSerialPortInUse',
    'ConvertFrom-PwmDeviceId'
)

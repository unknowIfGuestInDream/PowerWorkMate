<#
.SYNOPSIS
    TrayIcon - module four: system tray integration and run-at-startup.

.DESCRIPTION
    Provides the run-at-startup helpers (HKCU ...\Run registry value) and a
    factory that builds the NotifyIcon with its context menu (show / exit /
    toggle startup). The startup helpers are written so they degrade safely on
    non-Windows hosts, which keeps them unit-testable.

    UI construction (New-PwmTrayIcon) requires System.Windows.Forms and only
    runs on Windows with a desktop session.
#>

Set-StrictMode -Version Latest

$script:StartupRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:StartupValueName = 'PowerWorkMate'

function Test-PwmIsWindows {
    <#
    .SYNOPSIS
        Returns $true when running on Windows (PS 5.1 or PS 7+).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
        return [bool]$IsWindows
    }
    # Windows PowerShell 5.1 has no $IsWindows and is always Windows.
    return $true
}

function Test-PwmStartupEnabled {
    <#
    .SYNOPSIS
        Returns $true when PowerWorkMate is registered to run at logon.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-PwmIsWindows)) { return $false }

    try {
        $value = Get-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -ErrorAction Stop
        return [bool]$value.$($script:StartupValueName)
    }
    catch {
        return $false
    }
}

function Enable-PwmStartup {
    <#
    .SYNOPSIS
        Registers PowerWorkMate to launch at user logon via the Run key.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ScriptPath
    )

    if (-not (Test-PwmIsWindows)) {
        Write-Warning 'Run-at-startup is only supported on Windows.'
        return
    }

    if (-not $ScriptPath) {
        $ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'PowerWorkMate.ps1'
    }
    $command = '"{0}" -NoProfile -WindowStyle Hidden -File "{1}"' -f (Get-Process -Id $PID).Path, $ScriptPath

    if ($PSCmdlet.ShouldProcess($script:StartupValueName, 'Enable run-at-startup')) {
        if (-not (Test-Path -LiteralPath $script:StartupRegPath)) {
            New-Item -Path $script:StartupRegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -Value $command
    }
}

function Disable-PwmStartup {
    <#
    .SYNOPSIS
        Removes the run-at-startup registration if present.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-PwmIsWindows)) { return }

    if ($PSCmdlet.ShouldProcess($script:StartupValueName, 'Disable run-at-startup')) {
        try {
            Remove-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -ErrorAction Stop
        }
        catch {
            # Already absent - nothing to do.
        }
    }
}

function Set-PwmStartup {
    <#
    .SYNOPSIS
        Enables or disables run-at-startup from a single boolean (UI checkbox).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled,

        [string]$ScriptPath
    )

    if ($Enabled) {
        Enable-PwmStartup -ScriptPath $ScriptPath
    }
    else {
        Disable-PwmStartup
    }
}

function New-PwmTrayIcon {
    <#
    .SYNOPSIS
        Builds the system tray NotifyIcon with its context menu.

    .DESCRIPTION
        Right-click menu: Show main window, toggle Run at startup, Exit.
        Requires System.Windows.Forms; only call on Windows with a desktop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Form]$Form
    )

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Text = 'PowerWorkMate'
    $notify.Icon = [System.Drawing.SystemIcons]::Application
    if (Get-Command -Name New-PwmAppIcon -ErrorAction SilentlyContinue) {
        try { $notify.Icon = New-PwmAppIcon } catch { Write-Verbose $_.Exception.Message }
    }
    $notify.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $showItem = $menu.Items.Add('显示主窗口')
    $showItem.add_Click({
        $Form.Show()
        $Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $Form.Activate()
    }.GetNewClosure())

    $startupItem = New-Object System.Windows.Forms.ToolStripMenuItem '开机启动'
    $startupItem.CheckOnClick = $true
    $startupItem.Checked = (Test-PwmStartupEnabled)
    $startupItem.add_Click({
        Set-PwmStartup -Enabled $startupItem.Checked
    }.GetNewClosure())
    [void]$menu.Items.Add($startupItem)

    $exitItem = $menu.Items.Add('退出')
    $exitItem.add_Click({
        $notify.Visible = $false
        $Form.Dispose()
        [System.Windows.Forms.Application]::Exit()
    }.GetNewClosure())

    $notify.ContextMenuStrip = $menu
    $notify.add_DoubleClick({
        $Form.Show()
        $Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $Form.Activate()
    }.GetNewClosure())

    return $notify
}

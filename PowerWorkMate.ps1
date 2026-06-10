<#
.SYNOPSIS
    PowerWorkMate - main entry point.

.DESCRIPTION
    Bootstraps the application: loads the utilities, the repository layer (in
    dependency order) and the feature modules, builds the main window and the
    system-tray icon, then runs the Windows Forms message loop. Closing the
    window minimises to the tray; exit is performed from the tray menu.

    Requires Windows with a desktop session for the UI. The underlying modules
    and services are platform-independent and unit-tested separately.
#>

[CmdletBinding()]
param(
    [ValidateSet('Json', 'Sqlite')]
    [string]$Backend = 'Json',

    [switch]$Minimized
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

# --- Utilities -------------------------------------------------------------
. (Join-Path $root 'utils/Common.ps1')
. (Join-Path $root 'utils/Security.ps1')

# --- Services (load in dependency order: base before derived) --------------
. (Join-Path $root 'services/DataRepository.ps1')
. (Join-Path $root 'services/JsonRepository.ps1')
. (Join-Path $root 'services/SqliteRepository.ps1')

# --- Feature modules -------------------------------------------------------
Import-Module (Join-Path $root 'modules/FileSearch.psm1') -Force
Import-Module (Join-Path $root 'modules/FolderFav.psm1') -Force
Import-Module (Join-Path $root 'modules/SerialMonitor.psm1') -Force
Import-Module (Join-Path $root 'modules/Notes.psm1') -Force
Import-Module (Join-Path $root 'modules/CredentialVault.psm1') -Force

# --- UI --------------------------------------------------------------------
. (Join-Path $root 'ui/AppIcon.ps1')
. (Join-Path $root 'ui/TrayIcon.ps1')
. (Join-Path $root 'ui/MainForm.ps1')

Initialize-PwmDataRoot | Out-Null
$repository = New-PwmRepository -Backend $Backend

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Hide the host console window so only the UI (and tray icon) remain visible.
# Launching with "powershell.exe -File ..." creates a command window next to the
# UI; SW_HIDE removes it. Guarded for Windows and wrapped so a failure here can
# never stop the application from starting.
$onWindows = $true
if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
    $onWindows = [bool]$IsWindows
}
if ($onWindows) {
    try {
        if (-not ('PwmNative.ConsoleWindow' -as [type])) {
            Add-Type -Namespace 'PwmNative' -Name 'ConsoleWindow' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        }
        $consoleHandle = [PwmNative.ConsoleWindow]::GetConsoleWindow()
        if ($consoleHandle -ne [System.IntPtr]::Zero) {
            [void][PwmNative.ConsoleWindow]::ShowWindow($consoleHandle, 0) # 0 = SW_HIDE
        }
    }
    catch {
        Write-Verbose ("Unable to hide console window: {0}" -f $_.Exception.Message)
    }
}

$form = New-PwmMainForm -Repository $repository
$tray = New-PwmTrayIcon -Form $form

# Close button minimises to tray instead of exiting.
$form.add_FormClosing({
    param($eventSender, $eventArgs)
    if ($eventArgs.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $eventArgs.Cancel = $true
        $eventSender.Hide()
    }
}.GetNewClosure())

if ($Minimized) {
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    $form.ShowInTaskbar = $false
}

[System.Windows.Forms.Application]::Run($form)
$tray.Dispose()

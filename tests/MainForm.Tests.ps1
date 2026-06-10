Describe 'MainForm UI wiring' {
    BeforeAll {
        $script:root = Split-Path -Path $PSScriptRoot -Parent
        $script:mainForm = Get-Content -Path (Join-Path $script:root 'ui/MainForm.ps1') -Raw
        $script:trayIcon = Get-Content -Path (Join-Path $script:root 'ui/TrayIcon.ps1') -Raw
        $script:entry = Get-Content -Path (Join-Path $script:root 'PowerWorkMate.ps1') -Raw
    }

    It 'lets the credential vault add and edit entries' {
        $script:mainForm | Should -Match 'Show-PwmCredentialDialog'
        $script:mainForm | Should -Match 'Add-PwmCredential'
        $script:mainForm | Should -Match 'Set-PwmCredential'
    }

    It 'lets folder quick-links be renamed and reordered' {
        $script:mainForm | Should -Match 'Rename-PwmFavorite'
        $script:mainForm | Should -Match 'Set-PwmFavoriteOrder'
        $script:mainForm | Should -Match 'Show-PwmInputDialog'
    }

    It 'labels the file-search directory setting' {
        $script:mainForm | Should -Match 'workspaceLabel'
    }

    It 'auto-refreshes the serial tab when it is activated' {
        $script:mainForm | Should -Match '\$tab\.Tag = \$refresh'
        $script:mainForm | Should -Match 'add_SelectedIndexChanged'
        $script:mainForm | Should -Match 'Tag -is \[scriptblock\]'
    }

    It 'applies the application icon to the window and tray' {
        $script:mainForm | Should -Match 'New-PwmAppIcon'
        $script:trayIcon | Should -Match 'New-PwmAppIcon'
    }

    It 'hides the host console window on startup' {
        $script:entry | Should -Match 'GetConsoleWindow'
        $script:entry | Should -Match 'ShowWindow'
    }
}

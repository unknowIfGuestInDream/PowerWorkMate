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

    It 'exposes right-click context menus on every module list' {
        ([regex]::Matches($script:mainForm, 'ContextMenuStrip')).Count |
            Should -BeGreaterThan 4
        $script:mainForm | Should -Match '\$workspaceList\.ContextMenuStrip'
        $script:mainForm | Should -Match '\$list\.ContextMenuStrip'
        $script:mainForm | Should -Match '\$grid\.ContextMenuStrip'
    }

    It 'supports drag-and-drop to add folders for search and quick-links' {
        $script:mainForm | Should -Match '\$workspaceList\.AllowDrop = \$true'
        $script:mainForm | Should -Match '\$list\.AllowDrop = \$true'
        $script:mainForm | Should -Match 'add_DragEnter'
        $script:mainForm | Should -Match 'add_DragDrop'
        $script:mainForm | Should -Match 'DataFormats\]::FileDrop'
        $script:mainForm | Should -Match 'ConvertTo-PwmFolderPath'
    }

    It 'normalises dropped paths to de-duplicated folders' {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput(
            $script:mainForm, [ref]$null, [ref]$null)
        $fn = $ast.Find({
            param($n)
            $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $n.Name -eq 'ConvertTo-PwmFolderPath'
        }, $true)
        $fn | Should -Not -BeNullOrEmpty
        Invoke-Expression $fn.Extent.Text

        $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))
        $file = New-Item -ItemType File -Path (Join-Path $dir 'note.txt')

        $result = @(ConvertTo-PwmFolderPath -Path @(
            $dir.FullName, $file.FullName, '', $null, $dir.FullName))
        # Folder kept once; the file maps to its parent (same folder) => 1 unique.
        $result.Count | Should -Be 1
        $result[0] | Should -Be $dir.FullName
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

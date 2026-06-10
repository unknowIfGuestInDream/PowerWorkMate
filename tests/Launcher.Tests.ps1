Describe 'Launcher assets' {
    BeforeAll {
        $script:root = Split-Path -Path $PSScriptRoot -Parent
        $script:launcherScript = Join-Path -Path $script:root -ChildPath 'Start-PowerWorkMate.ps1'
        $script:launcherCmd = Join-Path -Path $script:root -ChildPath 'Start-PowerWorkMate.cmd'
        $script:vscodeLaunch = Join-Path -Path $script:root -ChildPath '.vscode/launch.json'
    }

    It 'provides a PowerShell launcher script that starts the app in STA mode' {
        $content = Get-Content -Path $script:launcherScript -Raw

        $content | Should -Match 'Get-PwmLauncherExecutable'
        $content | Should -Match '-Sta'
        $content | Should -Match 'PowerWorkMate\.ps1'
        $content | Should -Match 'Start-Process'
        $content | Should -Match '-PassThru'
    }

    It 'provides a one-click cmd launcher that bootstraps through Windows PowerShell' {
        $content = Get-Content -Path $script:launcherCmd -Raw

        $content | Should -Match 'WindowsPowerShell\\v1\.0\\powershell\.exe'
        $content | Should -Match 'Start-PowerWorkMate\.ps1'
        $content | Should -Match 'where pwsh\.exe'
        $content | Should -Match '%\*'
    }

    It 'includes VS Code launch configurations for normal and minimized startup' {
        $config = Get-Content -Path $script:vscodeLaunch -Raw | ConvertFrom-Json

        $config.version | Should -Be '0.2.0'
        $config.configurations.Count | Should -Be 2
        $config.configurations[0].type | Should -Be 'PowerShell'
        $config.configurations[0].script | Should -Be '${workspaceFolder}/Start-PowerWorkMate.ps1'
        $config.configurations[1].args | Should -Contain '-Minimized'
    }

    It 'fails fast with a clear message on non-Windows hosts' {
        $runningOnWindows = $true
        if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) {
            $runningOnWindows = [bool]$IsWindows
        }

        if ($runningOnWindows) {
            Set-ItResult -Skipped -Because 'Launcher integration is intended for Windows hosts.'
            return
        }

        $currentPowerShell = (Get-Process -Id $PID).Path
        $output = & $currentPowerShell -NoLogo -NoProfile -File $script:launcherScript 2>&1 | Out-String
        $? | Should -BeFalse
        $output | Should -Match 'requires Windows with a desktop session'
    }
}

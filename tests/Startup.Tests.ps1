Describe 'Startup helpers (TrayIcon)' {
    BeforeAll {
        . (Join-Path (Split-Path -Parent $PSScriptRoot) 'ui/TrayIcon.ps1')
    }

    It 'reports startup state without throwing on any platform' {
        { Test-PwmStartupEnabled } | Should -Not -Throw
    }

    It 'degrades safely on non-Windows hosts' {
        if (-not (Test-PwmIsWindows)) {
            Test-PwmStartupEnabled | Should -BeFalse
            { Set-PwmStartup -Enabled $true } | Should -Not -Throw
        }
        else {
            Set-ItResult -Skipped -Because 'Windows-specific registry behaviour is validated on Windows.'
        }
    }
}

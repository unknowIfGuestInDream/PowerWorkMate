Describe 'AppIcon' {
    BeforeAll {
        $script:root = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path $script:root 'ui/AppIcon.ps1')

        $script:drawingAvailable = $false
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            $probe = New-Object System.Drawing.Bitmap 1, 1
            $probe.Dispose()
            $script:drawingAvailable = $true
        }
        catch {
            $script:drawingAvailable = $false
        }
    }

    It 'exposes a New-PwmAppIcon command' {
        Get-Command -Name New-PwmAppIcon -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'builds a System.Drawing.Icon for the window and tray' {
        if (-not $script:drawingAvailable) {
            Set-ItResult -Skipped -Because 'System.Drawing (GDI+) is unavailable on this host.'
            return
        }

        $icon = New-PwmAppIcon -Size 32
        try {
            $icon | Should -BeOfType [System.Drawing.Icon]
            $icon.Width | Should -BeGreaterThan 0
            $icon.Height | Should -BeGreaterThan 0
        }
        finally {
            if ($icon) { $icon.Dispose() }
        }
    }
}

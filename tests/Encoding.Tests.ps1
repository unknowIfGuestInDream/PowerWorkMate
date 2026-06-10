Describe 'Source file encoding' {
    BeforeAll {
        $script:root = Split-Path -Path $PSScriptRoot -Parent

        # Windows PowerShell 5.1 decodes BOM-less scripts with the legacy ANSI
        # code page. On non-UTF-8 locales (e.g. Japanese/Chinese Windows) that
        # corrupts any non-ASCII content and breaks the parser, so every source
        # file that contains non-ASCII characters must carry a UTF-8 BOM.
        $script:utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)

        $script:sourceFiles = Get-ChildItem -Path $script:root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
            Where-Object { $_.FullName -notmatch '[\\/]tests[\\/]' }
    }

    It 'starts every non-ASCII source file with a UTF-8 BOM' {
        $offenders = @()

        foreach ($file in $script:sourceFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasNonAscii = $bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1
            if (-not $hasNonAscii) { continue }

            $hasBom = $bytes.Length -ge 3 -and
                $bytes[0] -eq $script:utf8Bom[0] -and
                $bytes[1] -eq $script:utf8Bom[1] -and
                $bytes[2] -eq $script:utf8Bom[2]

            if (-not $hasBom) {
                $offenders += $file.FullName.Substring($script:root.Length + 1)
            }
        }

        $offenders -join ', ' | Should -BeNullOrEmpty
    }
}

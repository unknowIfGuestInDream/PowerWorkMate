Describe 'Common utilities' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    Context 'Get-PwmDataRoot' {
        It 'honours the POWERWORKMATE_DATA override' {
            $env:POWERWORKMATE_DATA = '/tmp/pwm-explicit'
            Get-PwmDataRoot | Should -Be '/tmp/pwm-explicit'
            $env:POWERWORKMATE_DATA = $null
        }
    }

    Context 'JSON round-trip' {
        It 'writes and reads back an object atomically' {
            $file = Join-Path ([System.IO.Path]::GetTempPath()) ("pwm-" + [guid]::NewGuid().ToString('N') + '.json')
            Write-PwmJsonFile -Path $file -InputObject @(@{ a = 1 }, @{ a = 2 })
            $data = Read-PwmJsonFile -Path $file
            $data.Count | Should -Be 2
            Remove-Item -LiteralPath $file -Force
        }

        It 'returns the default for a missing file' {
            Read-PwmJsonFile -Path '/no/such/file.json' -Default @() | Should -BeNullOrEmpty
        }
    }

    Context 'Helpers' {
        It 'New-PwmId returns unique GUID strings' {
            (New-PwmId) | Should -Not -Be (New-PwmId)
        }

        It 'Test-PwmRegexPattern validates patterns' {
            Test-PwmRegexPattern -Pattern '^a.*z$' | Should -BeTrue
            Test-PwmRegexPattern -Pattern '[unterminated' | Should -BeFalse
        }
    }
}

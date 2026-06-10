Describe 'SerialMonitor module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Import-Module (Join-Path $script:PwmRoot 'modules/SerialMonitor.psm1') -Force
    }

    Context 'ConvertFrom-PwmDeviceId' {
        It 'extracts VID and PID from a USB hardware id' {
            $ids = ConvertFrom-PwmDeviceId -DeviceId 'USB\VID_1A86&PID_7523\5&abcdef'
            $ids.VID | Should -Be '1A86'
            $ids.PID | Should -Be '7523'
        }

        It 'returns nulls when no ids are present' {
            $ids = ConvertFrom-PwmDeviceId -DeviceId 'ACPI\PNP0501'
            $ids.VID | Should -BeNullOrEmpty
            $ids.PID | Should -BeNullOrEmpty
        }

        It 'handles empty input gracefully' {
            $ids = ConvertFrom-PwmDeviceId -DeviceId ''
            $ids.VID | Should -BeNullOrEmpty
        }
    }

    Context 'Get-PwmSerialPort' {
        It 'returns a collection without throwing (probe skipped)' {
            { Get-PwmSerialPort -SkipProbe } | Should -Not -Throw
        }
    }
}

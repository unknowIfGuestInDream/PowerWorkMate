Describe 'Security (encryption)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    It 'round-trips a secret through Protect/Unprotect' {
        $cipher = Protect-PwmSecret -PlainText 'p@ssw0rd!'
        $cipher | Should -Not -Be 'p@ssw0rd!'
        Unprotect-PwmSecret -CipherText $cipher | Should -Be 'p@ssw0rd!'
    }

    It 'tags the cipher text with the scheme used' {
        $cipher = Protect-PwmSecret -PlainText 'x'
        ($cipher -split ':', 2)[0] | Should -BeIn @('dpapi', 'aes')
    }

    It 'handles empty input' {
        Unprotect-PwmSecret -CipherText (Protect-PwmSecret -PlainText '') | Should -Be ''
    }

    It 'returns empty string for empty cipher text' {
        Unprotect-PwmSecret -CipherText '' | Should -Be ''
    }
}

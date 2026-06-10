Describe 'CredentialVault module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Import-Module (Join-Path $script:PwmRoot 'modules/CredentialVault.psm1') -Force
        $script:repo = Initialize-PwmTestContext
        $script:root = $env:POWERWORKMATE_DATA
    }

    AfterAll {
        Remove-PwmTestContext -Path $script:root
    }

    It 'adds a credential and stores the secret encrypted (not in clear text)' {
        $entry = Add-PwmCredential -Repository $repo -Name 'GitHub' -Account 'me' -Secret 'token123'
        $entry.secret | Should -Not -Be 'token123'
        $raw = Get-Content -Raw -Path (Join-Path $script:root 'credentials.json')
        $raw | Should -Not -Match 'token123'
    }

    It 'masks the secret in list output' {
        $list = Get-PwmCredential -Repository $repo
        $list[0].secretMasked | Should -Be '********'
        ($list[0].PSObject.Properties.Name) | Should -Not -Contain 'secret'
    }

    It 'reveals the clear-text secret on explicit request' {
        $id = (Get-PwmCredential -Repository $repo)[0].id
        Get-PwmCredentialSecret -Repository $repo -Id $id | Should -Be 'token123'
    }

    It 'updates only the supplied fields' {
        $id = (Get-PwmCredential -Repository $repo)[0].id
        Set-PwmCredential -Repository $repo -Id $id -Account 'updated' | Out-Null
        $entry = (Get-PwmCredential -Repository $repo | Where-Object { $_.id -eq $id })
        $entry.account | Should -Be 'updated'
        Get-PwmCredentialSecret -Repository $repo -Id $id | Should -Be 'token123'
    }

    It 'removes a credential' {
        $id = (Get-PwmCredential -Repository $repo)[0].id
        Remove-PwmCredential -Repository $repo -Id $id | Out-Null
        @(Get-PwmCredential -Repository $repo | Where-Object { $_.id -eq $id }).Count | Should -Be 0
    }
}

Describe 'Notes module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Import-Module (Join-Path $script:PwmRoot 'modules/Notes.psm1') -Force
        $script:repo = Initialize-PwmTestContext
        $script:root = $env:POWERWORKMATE_DATA
    }

    AfterAll {
        Remove-PwmTestContext -Path $script:root
    }

    It 'creates a note stored as its own document' {
        $note = New-PwmNote -Repository $repo -Title 'First' -Content 'hello'
        $note.id | Should -Not -BeNullOrEmpty
        $repo.ListDocuments('notes') | Should -Contain $note.id
    }

    It 'lists notes metadata' {
        @(Get-PwmNoteList -Repository $repo).Count | Should -BeGreaterOrEqual 1
    }

    It 'updates (auto-saves) a note' {
        $note = New-PwmNote -Repository $repo -Title 'Edit me'
        Start-Sleep -Milliseconds 5
        $updated = Set-PwmNote -Repository $repo -Id $note.id -Content 'changed'
        $updated.content | Should -Be 'changed'
        $updated.updatedAt | Should -Not -Be $note.updatedAt
    }

    It 'deletes a note' {
        $note = New-PwmNote -Repository $repo -Title 'Temp'
        Remove-PwmNote -Repository $repo -Id $note.id | Should -BeTrue
        Get-PwmNote -Repository $repo -Id $note.id | Should -BeNullOrEmpty
    }

    It 'throws when updating a missing note' {
        { Set-PwmNote -Repository $repo -Id 'missing' -Title 'x' } | Should -Throw
    }
}

Describe 'JsonRepository' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $script:repo = Initialize-PwmTestContext
        $script:root = $env:POWERWORKMATE_DATA
    }

    AfterAll {
        Remove-PwmTestContext -Path $script:root
    }

    Context 'Collections' {
        It 'returns an empty array for an unknown collection' {
            @($repo.GetCollection('nope')).Count | Should -Be 0
        }

        It 'saves and loads a collection' {
            $repo.SaveCollection('things', @([pscustomobject]@{ id = '1' }, [pscustomobject]@{ id = '2' }))
            @($repo.GetCollection('things')).Count | Should -Be 2
        }
    }

    Context 'Documents' {
        It 'saves, lists, gets and removes a document' {
            $repo.SaveDocument('notes', 'd1', @{ title = 't' })
            $repo.ListDocuments('notes') | Should -Contain 'd1'
            $repo.GetDocument('notes', 'd1').title | Should -Be 't'
            $repo.RemoveDocument('notes', 'd1') | Should -BeTrue
            $repo.GetDocument('notes', 'd1') | Should -BeNullOrEmpty
        }
    }

    Context 'Factory and reserved backend' {
        It 'New-PwmRepository returns a JsonRepository' {
            (New-PwmRepository -Root $script:root) -is [JsonRepository] | Should -BeTrue
        }

        It 'rejects the reserved SQLite backend' {
            { New-PwmRepository -Backend Sqlite } | Should -Throw
        }
    }
}

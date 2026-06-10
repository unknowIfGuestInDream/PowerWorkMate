Describe 'FileSearch module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Import-Module (Join-Path $script:PwmRoot 'modules/FileSearch.psm1') -Force
        $script:repo = Initialize-PwmTestContext
        $script:root = $env:POWERWORKMATE_DATA

        # Build a small sample tree to search.
        $script:tree = Join-Path ([System.IO.Path]::GetTempPath()) ("pwm-tree-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:tree 'src') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:tree '.git') -Force | Out-Null
        Set-Content -Path (Join-Path $script:tree 'src/app.ps1') -Value 'a'
        Set-Content -Path (Join-Path $script:tree 'src/readme.txt') -Value 'b'
        Set-Content -Path (Join-Path $script:tree 'src/main.c') -Value 'c'
        Set-Content -Path (Join-Path $script:tree '.git/config.ps1') -Value 'd'
    }

    AfterAll {
        Remove-PwmTestContext -Path $script:root
        Remove-Item -LiteralPath $script:tree -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Workspace management' {
        It 'adds, de-duplicates and removes workspaces' {
            Add-PwmWorkspace -Repository $repo -Path '/tmp/ws1' | Out-Null
            Add-PwmWorkspace -Repository $repo -Path '/tmp/ws1' | Out-Null
            @(Get-PwmWorkspace -Repository $repo).Count | Should -Be 1
            Remove-PwmWorkspace -Repository $repo -Path '/tmp/ws1' | Out-Null
            @(Get-PwmWorkspace -Repository $repo).Count | Should -Be 0
        }
    }

    Context 'Searching' {
        It 'finds all files when pattern is empty (excluding .git)' {
            $r = Search-PwmFile -Path $script:tree -ExcludeFolders '.git'
            @($r).Count | Should -Be 3
        }

        It 'filters by extension' {
            $r = Search-PwmFile -Path $script:tree -Extensions 'ps1' -ExcludeFolders '.git'
            @($r).Count | Should -Be 1
            $r[0].Name | Should -Be 'app.ps1'
        }

        It 'supports wildcards' {
            $r = Search-PwmFile -Path $script:tree -Pattern 'r*' -ExcludeFolders '.git'
            $r.Name | Should -Be 'readme.txt'
        }

        It 'supports regular expressions' {
            $r = Search-PwmFile -Path $script:tree -Pattern '\.(c|txt)$' -Regex -ExcludeFolders '.git'
            @($r).Count | Should -Be 2
        }

        It 'excludes folders' {
            $withGit = Search-PwmFile -Path $script:tree -Extensions 'ps1'
            @($withGit).Count | Should -Be 2
            $withoutGit = Search-PwmFile -Path $script:tree -Extensions 'ps1' -ExcludeFolders '.git'
            @($withoutGit).Count | Should -Be 1
        }

        It 'throws on an invalid regular expression' {
            { Search-PwmFile -Path $script:tree -Pattern '[bad' -Regex } | Should -Throw
        }
    }

    Context 'Helpers' {
        It 'formats file sizes' {
            Format-PwmFileSize -Bytes 512 | Should -Be '512 B'
            Format-PwmFileSize -Bytes 2048 | Should -Be '2.0 KB'
        }
    }
}

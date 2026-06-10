Describe 'FolderFav module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Import-Module (Join-Path $script:PwmRoot 'modules/FolderFav.psm1') -Force
        $script:repo = Initialize-PwmTestContext
        $script:root = $env:POWERWORKMATE_DATA
    }

    AfterAll {
        Remove-PwmTestContext -Path $script:root
    }

    It 'adds favorites with a default name and de-duplicates' {
        $items = Add-PwmFavorite -Repository $repo -Path '/tmp/projects/alpha'
        ($items | Where-Object { $_.path -eq '/tmp/projects/alpha' }).name | Should -Be 'alpha'
        Add-PwmFavorite -Repository $repo -Path '/tmp/projects/alpha' | Out-Null
        @(Get-PwmFavorite -Repository $repo).Count | Should -Be 1
    }

    It 'renames a favorite' {
        $fav = (Get-PwmFavorite -Repository $repo)[0]
        Rename-PwmFavorite -Repository $repo -Id $fav.id -NewName 'Alpha Project' | Out-Null
        (Get-PwmFavorite -Repository $repo)[0].name | Should -Be 'Alpha Project'
    }

    It 'reorders favorites' {
        Add-PwmFavorite -Repository $repo -Path '/tmp/projects/beta' | Out-Null
        $items = Get-PwmFavorite -Repository $repo
        $ids = @($items.id)
        [array]::Reverse($ids)
        $reordered = Set-PwmFavoriteOrder -Repository $repo -OrderedIds $ids
        $reordered[0].id | Should -Be $ids[0]
        $reordered[0].order | Should -Be 0
    }

    It 'exports and imports favorites' {
        $file = Join-Path ([System.IO.Path]::GetTempPath()) ("fav-" + [guid]::NewGuid().ToString('N') + '.json')
        Export-PwmFavorite -Repository $repo -Path $file
        $other = Initialize-PwmTestContext
        $merged = Import-PwmFavorite -Repository $other -Path $file
        @($merged).Count | Should -Be 2
        Remove-Item -LiteralPath $file -Force
    }

    It 'removes a favorite' {
        $fav = (Get-PwmFavorite -Repository $repo)[0]
        Remove-PwmFavorite -Repository $repo -Id $fav.id | Out-Null
        @(Get-PwmFavorite -Repository $repo | Where-Object { $_.id -eq $fav.id }).Count | Should -Be 0
    }
}

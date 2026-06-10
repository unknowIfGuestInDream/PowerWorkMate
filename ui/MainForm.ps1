<#
.SYNOPSIS
    MainForm - the PowerWorkMate main window (Windows Forms).

.DESCRIPTION
    Builds a tabbed window that surfaces every module: file search, folder
    quick-links, serial monitor, notes, credential vault and settings. The form
    talks to the modules only (which in turn talk to the repository), keeping UI
    free of storage and business logic.

    Requires System.Windows.Forms / System.Drawing and therefore only runs on
    Windows with a desktop session. Closing the window minimises to the tray
    instead of exiting (see PowerWorkMate.ps1 wiring).
#>

Set-StrictMode -Version Latest

function New-PwmMainForm {
    <#
    .SYNOPSIS
        Creates and returns the main application Form.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'PowerWorkMate'
    $form.Size = New-Object System.Drawing.Size(900, 620)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $form.Controls.Add($tabs)

    $tabs.TabPages.Add((New-PwmSearchTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmFavoritesTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmSerialTab))
    $tabs.TabPages.Add((New-PwmNotesTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmVaultTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmSettingsTab))

    return $form
}

function New-PwmSearchTab {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Repository)

    $tab = New-Object System.Windows.Forms.TabPage '文件搜索'

    $patternBox = New-Object System.Windows.Forms.TextBox
    $patternBox.SetBounds(10, 15, 300, 24)

    $regexCheck = New-Object System.Windows.Forms.CheckBox
    $regexCheck.Text = '正则'
    $regexCheck.SetBounds(320, 15, 60, 24)

    $extBox = New-Object System.Windows.Forms.TextBox
    $extBox.SetBounds(390, 15, 120, 24)

    $excludeBox = New-Object System.Windows.Forms.TextBox
    $excludeBox.Text = '.git;node_modules'
    $excludeBox.SetBounds(520, 15, 160, 24)

    $searchBtn = New-Object System.Windows.Forms.Button
    $searchBtn.Text = '搜索'
    $searchBtn.SetBounds(690, 14, 80, 26)

    $workspaceList = New-Object System.Windows.Forms.ListBox
    $workspaceList.SetBounds(10, 50, 200, 480)
    $workspaceList.Anchor = 'Top,Bottom,Left'

    $addWsBtn = New-Object System.Windows.Forms.Button
    $addWsBtn.Text = '添加目录'
    $addWsBtn.SetBounds(10, 535, 95, 26)
    $addWsBtn.Anchor = 'Bottom,Left'

    $removeWsBtn = New-Object System.Windows.Forms.Button
    $removeWsBtn.Text = '移除'
    $removeWsBtn.SetBounds(115, 535, 95, 26)
    $removeWsBtn.Anchor = 'Bottom,Left'

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.SetBounds(220, 50, 650, 510)
    $grid.Anchor = 'Top,Bottom,Left,Right'
    $grid.ReadOnly = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'

    $refreshWorkspaces = {
        $workspaceList.Items.Clear()
        foreach ($w in (Get-PwmWorkspace -Repository $Repository)) {
            [void]$workspaceList.Items.Add($w.path)
        }
    }.GetNewClosure()

    & $refreshWorkspaces

    $addWsBtn.add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [void](Add-PwmWorkspace -Repository $Repository -Path $dialog.SelectedPath)
            & $refreshWorkspaces
        }
    }.GetNewClosure())

    $removeWsBtn.add_Click({
        if ($workspaceList.SelectedItem) {
            [void](Remove-PwmWorkspace -Repository $Repository -Path $workspaceList.SelectedItem)
            & $refreshWorkspaces
        }
    }.GetNewClosure())

    $doSearch = {
        $paths = @(Get-PwmWorkspace -Repository $Repository | ForEach-Object { $_.path })
        if ($workspaceList.SelectedItems.Count -gt 0) {
            $paths = @($workspaceList.SelectedItems)
        }
        if ($paths.Count -eq 0) { return }

        $exts = $extBox.Text -split '[;,]' | Where-Object { $_ }
        $excludes = $excludeBox.Text -split '[;,]' | Where-Object { $_ }
        try {
            $results = Search-PwmFile -Path $paths -Pattern $patternBox.Text `
                -Regex:$regexCheck.Checked -Extensions $exts -ExcludeFolders $excludes
            $grid.DataSource = [System.Collections.ArrayList]@($results |
                Select-Object Name, FullPath, LastWriteTime, Size)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '搜索错误')
        }
    }.GetNewClosure()

    $searchBtn.add_Click($doSearch)

    $grid.add_CellDoubleClick({
        param($eventSender, $eventArgs)
        if ($eventArgs.RowIndex -ge 0) {
            $path = $eventSender.Rows[$eventArgs.RowIndex].Cells['FullPath'].Value
            if ($path -and (Test-Path -LiteralPath $path)) {
                Invoke-Item -LiteralPath $path
            }
        }
    })

    $tab.Controls.AddRange(@(
        $patternBox, $regexCheck, $extBox, $excludeBox, $searchBtn,
        $workspaceList, $addWsBtn, $removeWsBtn, $grid))
    return $tab
}

function New-PwmFavoritesTab {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Repository)

    $tab = New-Object System.Windows.Forms.TabPage '文件夹快链'

    $list = New-Object System.Windows.Forms.ListBox
    $list.SetBounds(10, 10, 500, 520)
    $list.Anchor = 'Top,Bottom,Left,Right'

    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = '添加'
    $addBtn.SetBounds(530, 10, 120, 28)
    $addBtn.Anchor = 'Top,Right'

    $openBtn = New-Object System.Windows.Forms.Button
    $openBtn.Text = '在资源管理器打开'
    $openBtn.SetBounds(530, 48, 120, 28)
    $openBtn.Anchor = 'Top,Right'

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = '删除'
    $removeBtn.SetBounds(530, 86, 120, 28)
    $removeBtn.Anchor = 'Top,Right'

    $script:favItems = @()
    $refresh = {
        $list.Items.Clear()
        $script:favItems = @(Get-PwmFavorite -Repository $Repository | Sort-Object order)
        foreach ($f in $script:favItems) {
            [void]$list.Items.Add(('{0}  ->  {1}' -f $f.name, $f.path))
        }
    }.GetNewClosure()
    & $refresh

    $addBtn.add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [void](Add-PwmFavorite -Repository $Repository -Path $dialog.SelectedPath)
            & $refresh
        }
    }.GetNewClosure())

    $openBtn.add_Click({
        if ($list.SelectedIndex -ge 0) {
            Open-PwmFavorite -Path $script:favItems[$list.SelectedIndex].path
        }
    }.GetNewClosure())

    $removeBtn.add_Click({
        if ($list.SelectedIndex -ge 0) {
            [void](Remove-PwmFavorite -Repository $Repository -Id $script:favItems[$list.SelectedIndex].id)
            & $refresh
        }
    }.GetNewClosure())

    $tab.Controls.AddRange(@($list, $addBtn, $openBtn, $removeBtn))
    return $tab
}

function New-PwmSerialTab {
    [CmdletBinding()]
    param()

    $tab = New-Object System.Windows.Forms.TabPage '串口监视'

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.SetBounds(10, 50, 860, 510)
    $grid.Anchor = 'Top,Bottom,Left,Right'
    $grid.ReadOnly = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AllowUserToAddRows = $false

    $refreshBtn = New-Object System.Windows.Forms.Button
    $refreshBtn.Text = '刷新'
    $refreshBtn.SetBounds(10, 12, 100, 28)

    $refresh = {
        $grid.DataSource = [System.Collections.ArrayList]@(Get-PwmSerialPort)
    }.GetNewClosure()
    $refreshBtn.add_Click($refresh)
    & $refresh

    $tab.Controls.AddRange(@($refreshBtn, $grid))
    return $tab
}

function New-PwmNotesTab {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Repository)

    $tab = New-Object System.Windows.Forms.TabPage '备忘录'

    $list = New-Object System.Windows.Forms.ListBox
    $list.SetBounds(10, 10, 220, 520)
    $list.Anchor = 'Top,Bottom,Left'

    $titleBox = New-Object System.Windows.Forms.TextBox
    $titleBox.SetBounds(240, 10, 630, 24)
    $titleBox.Anchor = 'Top,Left,Right'

    $contentBox = New-Object System.Windows.Forms.TextBox
    $contentBox.Multiline = $true
    $contentBox.ScrollBars = 'Vertical'
    $contentBox.SetBounds(240, 44, 630, 446)
    $contentBox.Anchor = 'Top,Bottom,Left,Right'

    $newBtn = New-Object System.Windows.Forms.Button
    $newBtn.Text = '新建'
    $newBtn.SetBounds(240, 500, 100, 28)
    $newBtn.Anchor = 'Bottom,Left'

    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = '保存'
    $saveBtn.SetBounds(350, 500, 100, 28)
    $saveBtn.Anchor = 'Bottom,Left'

    $deleteBtn = New-Object System.Windows.Forms.Button
    $deleteBtn.Text = '删除'
    $deleteBtn.SetBounds(460, 500, 100, 28)
    $deleteBtn.Anchor = 'Bottom,Left'

    $script:noteItems = @()
    $refresh = {
        $list.Items.Clear()
        $script:noteItems = @(Get-PwmNoteList -Repository $Repository)
        foreach ($n in $script:noteItems) { [void]$list.Items.Add($n.title) }
    }.GetNewClosure()
    & $refresh

    $list.add_SelectedIndexChanged({
        if ($list.SelectedIndex -ge 0) {
            $note = Get-PwmNote -Repository $Repository -Id $script:noteItems[$list.SelectedIndex].id
            if ($note) {
                $titleBox.Text = $note.title
                $contentBox.Text = $note.content
            }
        }
    }.GetNewClosure())

    $newBtn.add_Click({
        [void](New-PwmNote -Repository $Repository -Title '未命名')
        & $refresh
    }.GetNewClosure())

    $saveBtn.add_Click({
        if ($list.SelectedIndex -ge 0) {
            [void](Set-PwmNote -Repository $Repository -Id $script:noteItems[$list.SelectedIndex].id `
                -Title $titleBox.Text -Content $contentBox.Text)
            & $refresh
        }
    }.GetNewClosure())

    $deleteBtn.add_Click({
        if ($list.SelectedIndex -ge 0) {
            [void](Remove-PwmNote -Repository $Repository -Id $script:noteItems[$list.SelectedIndex].id)
            $titleBox.Clear(); $contentBox.Clear()
            & $refresh
        }
    }.GetNewClosure())

    $tab.Controls.AddRange(@($list, $titleBox, $contentBox, $newBtn, $saveBtn, $deleteBtn))
    return $tab
}

function New-PwmVaultTab {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Repository)

    $tab = New-Object System.Windows.Forms.TabPage '凭证保管'

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.SetBounds(10, 10, 700, 520)
    $grid.Anchor = 'Top,Bottom,Left,Right'
    $grid.ReadOnly = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'

    $copyBtn = New-Object System.Windows.Forms.Button
    $copyBtn.Text = '复制密钥'
    $copyBtn.SetBounds(720, 10, 150, 28)
    $copyBtn.Anchor = 'Top,Right'

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = '删除'
    $removeBtn.SetBounds(720, 48, 150, 28)
    $removeBtn.Anchor = 'Top,Right'

    $script:vaultItems = @()
    $refresh = {
        $script:vaultItems = @(Get-PwmCredential -Repository $Repository)
        $grid.DataSource = [System.Collections.ArrayList]@($script:vaultItems |
            Select-Object name, account, secretMasked, notes)
    }.GetNewClosure()
    & $refresh

    $copyBtn.add_Click({
        if ($grid.SelectedRows.Count -gt 0) {
            $id = $script:vaultItems[$grid.SelectedRows[0].Index].id
            [void](Copy-PwmCredentialSecret -Repository $Repository -Id $id)
            [System.Windows.Forms.MessageBox]::Show('已复制', 'PowerWorkMate',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }.GetNewClosure())

    $removeBtn.add_Click({
        if ($grid.SelectedRows.Count -gt 0) {
            $id = $script:vaultItems[$grid.SelectedRows[0].Index].id
            [void](Remove-PwmCredential -Repository $Repository -Id $id)
            & $refresh
        }
    }.GetNewClosure())

    $tab.Controls.AddRange(@($grid, $copyBtn, $removeBtn))
    return $tab
}

function New-PwmSettingsTab {
    [CmdletBinding()]
    param()

    $tab = New-Object System.Windows.Forms.TabPage '设置'

    $startupCheck = New-Object System.Windows.Forms.CheckBox
    $startupCheck.Text = '开机自启'
    $startupCheck.SetBounds(20, 20, 200, 24)
    $startupCheck.Checked = (Test-PwmStartupEnabled)
    $startupCheck.add_CheckedChanged({
        Set-PwmStartup -Enabled $startupCheck.Checked
    }.GetNewClosure())

    $tab.Controls.Add($startupCheck)
    return $tab
}

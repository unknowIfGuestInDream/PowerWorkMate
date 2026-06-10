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

    if (Get-Command -Name New-PwmAppIcon -ErrorAction SilentlyContinue) {
        try { $form.Icon = New-PwmAppIcon } catch { Write-Verbose $_.Exception.Message }
    }

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $form.Controls.Add($tabs)

    $tabs.TabPages.Add((New-PwmSearchTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmFavoritesTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmSerialTab))
    $tabs.TabPages.Add((New-PwmNotesTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmVaultTab -Repository $Repository))
    $tabs.TabPages.Add((New-PwmSettingsTab))

    # When a tab exposes a refresh script via its Tag, run it on activation so,
    # for example, the serial monitor re-scans the COM ports automatically.
    $tabs.add_SelectedIndexChanged({
        param($eventSender, $eventArgs)
        $selected = $eventSender.SelectedTab
        if ($selected -and $selected.Tag -is [scriptblock]) {
            & $selected.Tag
        }
    })

    return $form
}

function New-PwmSearchTab {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Repository)

    $tab = New-Object System.Windows.Forms.TabPage '文件搜索'

    $patternLabel = New-Object System.Windows.Forms.Label
    $patternLabel.Text = '关键字'
    $patternLabel.SetBounds(10, 8, 60, 16)

    $patternBox = New-Object System.Windows.Forms.TextBox
    $patternBox.SetBounds(10, 26, 300, 24)

    $regexCheck = New-Object System.Windows.Forms.CheckBox
    $regexCheck.Text = '正则'
    $regexCheck.SetBounds(320, 26, 60, 24)

    $extLabel = New-Object System.Windows.Forms.Label
    $extLabel.Text = '扩展名'
    $extLabel.SetBounds(390, 8, 120, 16)

    $extBox = New-Object System.Windows.Forms.TextBox
    $extBox.SetBounds(390, 26, 120, 24)

    $excludeLabel = New-Object System.Windows.Forms.Label
    $excludeLabel.Text = '排除文件夹'
    $excludeLabel.SetBounds(520, 8, 160, 16)

    $excludeBox = New-Object System.Windows.Forms.TextBox
    $excludeBox.Text = '.git;node_modules'
    $excludeBox.SetBounds(520, 26, 160, 24)

    $searchBtn = New-Object System.Windows.Forms.Button
    $searchBtn.Text = '搜索'
    $searchBtn.SetBounds(690, 25, 80, 26)

    $workspaceLabel = New-Object System.Windows.Forms.Label
    $workspaceLabel.Text = '搜索目录'
    $workspaceLabel.SetBounds(10, 60, 200, 16)

    $workspaceList = New-Object System.Windows.Forms.ListBox
    $workspaceList.SetBounds(10, 80, 200, 450)
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
    $grid.SetBounds(220, 80, 650, 480)
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

    $addWorkspace = {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [void](Add-PwmWorkspace -Repository $Repository -Path $dialog.SelectedPath)
            & $refreshWorkspaces
        }
    }.GetNewClosure()

    $removeWorkspace = {
        if ($workspaceList.SelectedItem) {
            [void](Remove-PwmWorkspace -Repository $Repository -Path $workspaceList.SelectedItem)
            & $refreshWorkspaces
        }
    }.GetNewClosure()

    $addWsBtn.add_Click($addWorkspace)
    $removeWsBtn.add_Click($removeWorkspace)

    # Right-click context menu mirrors the add / remove buttons.
    $wsMenu = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$wsMenu.Items.Add('添加目录', $null, [System.EventHandler]({ & $addWorkspace }.GetNewClosure()))
    [void]$wsMenu.Items.Add('移除', $null, [System.EventHandler]({ & $removeWorkspace }.GetNewClosure()))
    $workspaceList.ContextMenuStrip = $wsMenu

    # Drag a folder (or file) from Explorer onto the list to add it as a search directory.
    $workspaceList.AllowDrop = $true
    $workspaceList.add_DragEnter([System.Windows.Forms.DragEventHandler]{
        param($eventSender, $eventArgs)
        if ($eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        }
    })
    $workspaceList.add_DragDrop([System.Windows.Forms.DragEventHandler]({
        param($eventSender, $eventArgs)
        $dropped = $eventArgs.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        foreach ($folder in (ConvertTo-PwmFolderPath -Path $dropped)) {
            [void](Add-PwmWorkspace -Repository $Repository -Path $folder)
        }
        & $refreshWorkspaces
    }.GetNewClosure()))

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
        $patternLabel, $patternBox, $regexCheck, $extLabel, $extBox,
        $excludeLabel, $excludeBox, $searchBtn,
        $workspaceLabel, $workspaceList, $addWsBtn, $removeWsBtn, $grid))
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

    $renameBtn = New-Object System.Windows.Forms.Button
    $renameBtn.Text = '重命名'
    $renameBtn.SetBounds(530, 124, 120, 28)
    $renameBtn.Anchor = 'Top,Right'

    $upBtn = New-Object System.Windows.Forms.Button
    $upBtn.Text = '上移'
    $upBtn.SetBounds(530, 162, 58, 28)
    $upBtn.Anchor = 'Top,Right'

    $downBtn = New-Object System.Windows.Forms.Button
    $downBtn.Text = '下移'
    $downBtn.SetBounds(592, 162, 58, 28)
    $downBtn.Anchor = 'Top,Right'

    # Shared state lives in a hashtable so every event closure created via
    # GetNewClosure() reads and writes the *same* instance. A plain $script:
    # variable does not work here: each GetNewClosure() closure gets its own
    # dynamic module scope, so refreshes would not be visible to other handlers.
    $state = @{ favItems = @() }
    $refresh = {
        $list.Items.Clear()
        $state.favItems = @(Get-PwmFavorite -Repository $Repository | Sort-Object order)
        foreach ($f in $state.favItems) {
            [void]$list.Items.Add(('{0}  ->  {1}' -f $f.name, $f.path))
        }
    }.GetNewClosure()
    & $refresh

    $addFavorite = {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [void](Add-PwmFavorite -Repository $Repository -Path $dialog.SelectedPath)
            & $refresh
        }
    }.GetNewClosure()

    $openFavorite = {
        if ($list.SelectedIndex -ge 0) {
            Open-PwmFavorite -Path $state.favItems[$list.SelectedIndex].path
        }
    }.GetNewClosure()

    $removeFavorite = {
        if ($list.SelectedIndex -ge 0) {
            [void](Remove-PwmFavorite -Repository $Repository -Id $state.favItems[$list.SelectedIndex].id)
            & $refresh
        }
    }.GetNewClosure()

    $renameFavorite = {
        if ($list.SelectedIndex -ge 0) {
            $current = $state.favItems[$list.SelectedIndex]
            $newName = Show-PwmInputDialog -Title '重命名快链' -Prompt '请输入新的名称：' -Default $current.name
            if ($newName) {
                [void](Rename-PwmFavorite -Repository $Repository -Id $current.id -NewName $newName)
                & $refresh
            }
        }
    }.GetNewClosure()

    $addBtn.add_Click($addFavorite)
    $openBtn.add_Click($openFavorite)
    $removeBtn.add_Click($removeFavorite)
    $renameBtn.add_Click($renameFavorite)

    $moveFavorite = {
        param([int]$Delta)
        $index = $list.SelectedIndex
        if ($index -lt 0) { return }
        $target = $index + $Delta
        if ($target -lt 0 -or $target -ge $state.favItems.Count) { return }

        $ids = [System.Collections.Generic.List[string]]::new()
        foreach ($f in $state.favItems) { $ids.Add($f.id) }
        $moved = $ids[$index]
        $ids.RemoveAt($index)
        $ids.Insert($target, $moved)

        [void](Set-PwmFavoriteOrder -Repository $Repository -OrderedIds $ids.ToArray())
        & $refresh
        $list.SelectedIndex = $target
    }.GetNewClosure()

    $upBtn.add_Click({ & $moveFavorite -Delta -1 }.GetNewClosure())
    $downBtn.add_Click({ & $moveFavorite -Delta 1 }.GetNewClosure())

    # Right-click context menu mirrors the side buttons.
    $favMenu = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$favMenu.Items.Add('添加', $null, [System.EventHandler]({ & $addFavorite }.GetNewClosure()))
    [void]$favMenu.Items.Add('在资源管理器打开', $null, [System.EventHandler]({ & $openFavorite }.GetNewClosure()))
    [void]$favMenu.Items.Add('重命名', $null, [System.EventHandler]({ & $renameFavorite }.GetNewClosure()))
    [void]$favMenu.Items.Add('删除', $null, [System.EventHandler]({ & $removeFavorite }.GetNewClosure()))
    [void]$favMenu.Items.Add('上移', $null, [System.EventHandler]({ & $moveFavorite -Delta -1 }.GetNewClosure()))
    [void]$favMenu.Items.Add('下移', $null, [System.EventHandler]({ & $moveFavorite -Delta 1 }.GetNewClosure()))
    $list.ContextMenuStrip = $favMenu

    # Drag a folder (or file) from Explorer onto the list to add it as a quick-link.
    $list.AllowDrop = $true
    $list.add_DragEnter([System.Windows.Forms.DragEventHandler]{
        param($eventSender, $eventArgs)
        if ($eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        }
    })
    $list.add_DragDrop([System.Windows.Forms.DragEventHandler]({
        param($eventSender, $eventArgs)
        $dropped = $eventArgs.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        foreach ($folder in (ConvertTo-PwmFolderPath -Path $dropped)) {
            [void](Add-PwmFavorite -Repository $Repository -Path $folder)
        }
        & $refresh
    }.GetNewClosure()))

    $tab.Controls.AddRange(@($list, $addBtn, $openBtn, $removeBtn, $renameBtn, $upBtn, $downBtn))
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

    # Expose the refresh action so the host form re-scans the ports every time
    # the user switches to this tab (see New-PwmMainForm SelectedIndexChanged).
    $tab.Tag = $refresh

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

    # Shared state in a hashtable so every GetNewClosure() event handler reads
    # and writes the same instance (see the favorites tab for the rationale).
    $state = @{ noteItems = @() }
    $refresh = {
        $list.Items.Clear()
        $state.noteItems = @(Get-PwmNoteList -Repository $Repository)
        foreach ($n in $state.noteItems) { [void]$list.Items.Add($n.title) }
    }.GetNewClosure()
    & $refresh

    $list.add_SelectedIndexChanged({
        if ($list.SelectedIndex -ge 0 -and $list.SelectedIndex -lt $state.noteItems.Count) {
            $note = Get-PwmNote -Repository $Repository -Id $state.noteItems[$list.SelectedIndex].id
            if ($note) {
                $titleBox.Text = $note.title
                $contentBox.Text = $note.content
            }
        }
    }.GetNewClosure())

    $newNote = {
        [void](New-PwmNote -Repository $Repository -Title '未命名')
        & $refresh
    }.GetNewClosure()

    $saveNote = {
        if ($list.SelectedIndex -ge 0 -and $list.SelectedIndex -lt $state.noteItems.Count) {
            [void](Set-PwmNote -Repository $Repository -Id $state.noteItems[$list.SelectedIndex].id `
                -Title $titleBox.Text -Content $contentBox.Text)
            & $refresh
        }
    }.GetNewClosure()

    $deleteNote = {
        if ($list.SelectedIndex -ge 0 -and $list.SelectedIndex -lt $state.noteItems.Count) {
            [void](Remove-PwmNote -Repository $Repository -Id $state.noteItems[$list.SelectedIndex].id)
            $titleBox.Clear(); $contentBox.Clear()
            & $refresh
        }
    }.GetNewClosure()

    $newBtn.add_Click($newNote)
    $saveBtn.add_Click($saveNote)
    $deleteBtn.add_Click($deleteNote)

    # Right-click context menu mirrors the new / save / delete buttons.
    $noteMenu = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$noteMenu.Items.Add('新建', $null, [System.EventHandler]({ & $newNote }.GetNewClosure()))
    [void]$noteMenu.Items.Add('保存', $null, [System.EventHandler]({ & $saveNote }.GetNewClosure()))
    [void]$noteMenu.Items.Add('删除', $null, [System.EventHandler]({ & $deleteNote }.GetNewClosure()))
    $list.ContextMenuStrip = $noteMenu

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

    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = '添加'
    $addBtn.SetBounds(720, 48, 150, 28)
    $addBtn.Anchor = 'Top,Right'

    $editBtn = New-Object System.Windows.Forms.Button
    $editBtn.Text = '编辑'
    $editBtn.SetBounds(720, 86, 150, 28)
    $editBtn.Anchor = 'Top,Right'

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = '删除'
    $removeBtn.SetBounds(720, 124, 150, 28)
    $removeBtn.Anchor = 'Top,Right'

    # Shared state in a hashtable so every GetNewClosure() event handler reads
    # and writes the same instance (see the favorites tab for the rationale).
    $state = @{ vaultItems = @() }
    $refresh = {
        $state.vaultItems = @(Get-PwmCredential -Repository $Repository)
        $grid.DataSource = [System.Collections.ArrayList]@($state.vaultItems |
            Select-Object name, account, secretMasked, notes)
    }.GetNewClosure()
    & $refresh

    $copyCredential = {
        if ($grid.SelectedRows.Count -gt 0) {
            $id = $state.vaultItems[$grid.SelectedRows[0].Index].id
            [void](Copy-PwmCredentialSecret -Repository $Repository -Id $id)
            [System.Windows.Forms.MessageBox]::Show('已复制', 'PowerWorkMate',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }.GetNewClosure()

    $addCredential = {
        $result = Show-PwmCredentialDialog -Title '添加凭证'
        if ($result) {
            [void](Add-PwmCredential -Repository $Repository -Name $result.Name `
                -Account $result.Account -Secret $result.Secret -Notes $result.Notes)
            & $refresh
        }
    }.GetNewClosure()

    $editCredential = {
        if ($grid.SelectedRows.Count -gt 0) {
            $entry = $state.vaultItems[$grid.SelectedRows[0].Index]
            $result = Show-PwmCredentialDialog -Title '编辑凭证' -Name $entry.name `
                -Account $entry.account -Notes $entry.notes -SecretIsOptional
            if ($result) {
                $params = @{
                    Repository = $Repository
                    Id         = $entry.id
                    Name       = $result.Name
                    Account    = $result.Account
                    Notes      = $result.Notes
                }
                # An empty secret on edit means "keep the existing one".
                if (-not [string]::IsNullOrEmpty($result.Secret)) {
                    $params['Secret'] = $result.Secret
                }
                [void](Set-PwmCredential @params)
                & $refresh
            }
        }
    }.GetNewClosure()

    $removeCredential = {
        if ($grid.SelectedRows.Count -gt 0) {
            $id = $state.vaultItems[$grid.SelectedRows[0].Index].id
            [void](Remove-PwmCredential -Repository $Repository -Id $id)
            & $refresh
        }
    }.GetNewClosure()

    $copyBtn.add_Click($copyCredential)
    $addBtn.add_Click($addCredential)
    $editBtn.add_Click($editCredential)
    $removeBtn.add_Click($removeCredential)

    # Right-click context menu mirrors the side buttons.
    $vaultMenu = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$vaultMenu.Items.Add('复制密钥', $null, [System.EventHandler]({ & $copyCredential }.GetNewClosure()))
    [void]$vaultMenu.Items.Add('添加', $null, [System.EventHandler]({ & $addCredential }.GetNewClosure()))
    [void]$vaultMenu.Items.Add('编辑', $null, [System.EventHandler]({ & $editCredential }.GetNewClosure()))
    [void]$vaultMenu.Items.Add('删除', $null, [System.EventHandler]({ & $removeCredential }.GetNewClosure()))
    $grid.ContextMenuStrip = $vaultMenu

    $tab.Controls.AddRange(@($grid, $copyBtn, $addBtn, $editBtn, $removeBtn))
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

function ConvertTo-PwmFolderPath {
    <#
    .SYNOPSIS
        Normalises dropped Explorer paths to a de-duplicated list of folders.

    .DESCRIPTION
        Used by the drag-and-drop handlers of the file-search and folder
        quick-link lists. A dropped directory is kept as-is; a dropped file is
        mapped to its parent directory so dragging either a folder or a file
        path adds a usable folder. Missing or blank entries are skipped.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string[]]$Path
    )

    $folders = [System.Collections.Generic.List[string]]::new()
    foreach ($p in @($Path)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $folder = $null
        if (Test-Path -LiteralPath $p -PathType Container) {
            $folder = $p
        }
        elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            $folder = Split-Path -Path $p -Parent
        }
        if ($folder -and ($folder -notin $folders)) {
            $folders.Add($folder)
        }
    }
    return @($folders.ToArray())
}

function Show-PwmInputDialog {
    <#
    .SYNOPSIS
        Shows a small modal text-input dialog and returns the entered string.

    .DESCRIPTION
        Returns the trimmed text when the user confirms with OK, or $null when
        they cancel or leave the box empty. Used for quick edits such as
        renaming a folder quick-link.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Title = '输入',
        [string]$Prompt = '',
        [string]$Default = ''
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.StartPosition = 'CenterParent'
    $dialog.ClientSize = New-Object System.Drawing.Size(360, 120)
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.SetBounds(12, 12, 336, 18)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Text = $Default
    $textBox.SetBounds(12, 36, 336, 24)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = '确定'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.SetBounds(184, 78, 80, 28)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = '取消'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.SetBounds(268, 78, 80, 28)

    $dialog.Controls.AddRange(@($label, $textBox, $okButton, $cancelButton))
    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $value = $textBox.Text.Trim()
            if ($value) { return $value }
        }
        return $null
    }
    finally {
        $dialog.Dispose()
    }
}

function Show-PwmCredentialDialog {
    <#
    .SYNOPSIS
        Shows a modal dialog for adding or editing a credential entry.

    .DESCRIPTION
        Returns a PSCustomObject with Name, Account, Secret and Notes when the
        user confirms (Name is required), or $null when they cancel. With
        -SecretIsOptional the secret may be left blank to keep the existing
        value (used by the edit flow); the secret field never shows clear text.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string]$Title = '凭证',
        [string]$Name = '',
        [string]$Account = '',
        [string]$Notes = '',
        [switch]$SecretIsOptional
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.StartPosition = 'CenterParent'
    $dialog.ClientSize = New-Object System.Drawing.Size(380, 240)
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = '名称'
    $nameLabel.SetBounds(12, 14, 80, 20)
    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Text = $Name
    $nameBox.SetBounds(100, 12, 264, 24)

    $accountLabel = New-Object System.Windows.Forms.Label
    $accountLabel.Text = '账号'
    $accountLabel.SetBounds(12, 48, 80, 20)
    $accountBox = New-Object System.Windows.Forms.TextBox
    $accountBox.Text = $Account
    $accountBox.SetBounds(100, 46, 264, 24)

    $secretLabel = New-Object System.Windows.Forms.Label
    $secretLabel.Text = if ($SecretIsOptional) { '密钥(留空不改)' } else { '密钥' }
    $secretLabel.SetBounds(12, 82, 84, 20)
    $secretBox = New-Object System.Windows.Forms.TextBox
    $secretBox.UseSystemPasswordChar = $true
    $secretBox.SetBounds(100, 80, 264, 24)

    $notesLabel = New-Object System.Windows.Forms.Label
    $notesLabel.Text = '备注'
    $notesLabel.SetBounds(12, 116, 80, 20)
    $notesBox = New-Object System.Windows.Forms.TextBox
    $notesBox.Multiline = $true
    $notesBox.ScrollBars = 'Vertical'
    $notesBox.Text = $Notes
    $notesBox.SetBounds(100, 114, 264, 64)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = '确定'
    $okButton.SetBounds(196, 196, 80, 28)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = '取消'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.SetBounds(284, 196, 80, 28)

    # Name is mandatory; only close on OK when it is provided.
    $okButton.add_Click({
        if ([string]::IsNullOrWhiteSpace($nameBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show('请填写名称。', 'PowerWorkMate',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    }.GetNewClosure())

    $dialog.Controls.AddRange(@(
        $nameLabel, $nameBox, $accountLabel, $accountBox,
        $secretLabel, $secretBox, $notesLabel, $notesBox,
        $okButton, $cancelButton))
    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return [pscustomobject]@{
                Name    = $nameBox.Text.Trim()
                Account = $accountBox.Text.Trim()
                Secret  = $secretBox.Text
                Notes   = $notesBox.Text
            }
        }
        return $null
    }
    finally {
        $dialog.Dispose()
    }
}

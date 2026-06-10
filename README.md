# PowerWorkMate

基于 **PowerShell 5.1+ / Windows Forms** 的桌面效率工具，面向日常开发与嵌入式工作流。采用 **仓储模式（Repository）+ 服务层** 设计，业务逻辑同时与 UI 和存储实现解耦，便于后续将存储从 JSON 平滑切换为 SQLite。

## 功能模块

| 模块 | 说明 |
|------|------|
| 多目录文件搜索 | 管理多个工作目录；支持普通字符串、通配符（`* ?`）、正则；按扩展名筛选；排除文件夹/文件名；结果含文件名、路径、修改时间、大小，可双击打开 |
| 文件夹快链 | 添加/删除/重命名/排序快链；在资源管理器打开；与工作目录独立存储，支持导出/导入 |
| 串口监视器 | 列出所有 COM 口，显示名称、描述、占用状态（探测打开）、VID/PID；支持刷新 |
| 系统托盘 & 开机启动 | 关闭按钮最小化到托盘；托盘右键菜单（显示/退出/开机启动）；通过 `HKCU\...\Run` 注册表实现自启 |
| 备忘录 | 多备忘录，每个独立标题与内容；每条备忘录存为单独文件；新建/保存/删除 |
| 凭证保管 | 条目管理（名称/账号/密钥/备注）；密码默认掩码；一键复制到剪贴板；敏感字段使用 Windows DPAPI 加密存储 |

## 目录结构

```
PowerWorkMate/
├── PowerWorkMate.ps1       # 主入口（加载服务/模块，构建窗口与托盘）
├── ui/                     # MainForm.ps1、TrayIcon.ps1（Windows Forms）
├── modules/                # FileSearch / FolderFav / SerialMonitor / Notes / CredentialVault
├── services/               # DataRepository（接口）、JsonRepository、SqliteRepository（预留）
├── utils/                  # Common.ps1、Security.ps1
└── tests/                  # Pester 测试
```

用户数据（工作目录、快链、备忘录、凭证）默认存放于 `%APPDATA%\PowerWorkMate\`，与程序逻辑分离；可用环境变量 `POWERWORKMATE_DATA` 覆盖存储位置（测试与便携部署使用）。

## 运行

```powershell
# Windows 桌面会话
pwsh -File .\PowerWorkMate.ps1
# 启动即最小化到托盘
pwsh -File .\PowerWorkMate.ps1 -Minimized
```

> UI 依赖 Windows Forms，仅在 Windows 桌面会话下运行。模块与服务层为平台无关逻辑，可在任意平台单独测试。

## 开发

```powershell
# 静态检查
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error

# 运行测试
$config = New-PesterConfiguration
$config.Run.Path = './tests'
Invoke-Pester -Configuration $config
```

### 设计要点

- **仓储接口**：`services/DataRepository.ps1` 定义集合（collection）与文档（document）两套契约；模块只依赖该接口，从不直接读写文件。
- **存储实现可替换**：当前为 `JsonRepository`；`SqliteRepository` 已预留并在 `New-PwmRepository` 中保留切换点。
- **加密**：`utils/Security.ps1` 在 Windows 上使用 DPAPI；在非 Windows 开发/测试主机上回退为 AES（密钥派生自用户/机器标识），密文带方案前缀以便读回。

# Copilot Instructions — PowerWorkMate

These instructions guide GitHub Copilot (and other AI assistants) when contributing to **PowerWorkMate**, a PowerShell-based desktop productivity tool for Windows.

## Project overview

- **Language:** PowerShell 5.1+ (native Windows, low footprint)
- **UI framework:** Windows Forms (lightweight, low memory)
- **Storage:** JSON files under `%APPDATA%\PowerWorkMate\` initially, with a repository abstraction that reserves room for a future SQLite implementation
- **Architecture:** Repository pattern + Service layer so the storage backend can be swapped without touching business logic

### Planned layout

```
PowerWorkMate/
├── PowerWorkMate.ps1      # Main entry point
├── ui/                    # MainForm, TrayIcon, custom controls
├── modules/               # FileSearch, FolderFav, SerialMonitor, Notes, CredentialVault
├── services/              # DataRepository (interface), JsonRepository, SqliteRepository (reserved)
├── utils/                 # Common.ps1, Security.ps1
└── tests/                 # Pester tests
```

User data (workspaces, favorites, notes, credentials) is stored under `%APPDATA%\PowerWorkMate\`, kept separate from program logic.

## Coding conventions

- Target **PowerShell 5.1** and keep dependencies minimal; prefer built-in cmdlets and .NET types already shipped with Windows.
- Use approved PowerShell verbs (`Get-`, `Set-`, `New-`, `Remove-`, ...) for functions and `PascalCase` for public function names.
- Keep modules (`.psm1`) focused on a single concern and export only the public surface via `Export-ModuleMember`.
- Access data only through the repository interface (`DataRepository`); never read or write data files directly from UI or module code.
- Encrypt sensitive fields (credentials/keys) with Windows DPAPI / CMS (`Protect-CmsMessage`); never store secrets in plain text and never commit secrets.
- Run [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) and fix warnings before opening a PR.
- Add or update [Pester](https://pester.dev/) tests under `tests/` for any behavior you change.

## Commit message convention (Angular)

All commits and PR titles **must** follow the [Angular Conventional Commits](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type** — one of:
  - `feat` — a new feature
  - `fix` — a bug fix
  - `docs` — documentation only changes
  - `style` — formatting, missing semicolons, etc. (no code behavior change)
  - `refactor` — a code change that neither fixes a bug nor adds a feature
  - `perf` — a code change that improves performance
  - `test` — adding or correcting tests
  - `build` — changes to the build system or dependencies
  - `ci` — changes to CI configuration and scripts
  - `chore` — other changes that don't modify src or test files
  - `revert` — reverts a previous commit
- **scope** *(optional)* — the affected area, e.g. `filesearch`, `notes`, `vault`, `tray`, `ci`.
- **subject** — short imperative description, lower case, no trailing period, ≤ 72 characters.
- **body** *(optional)* — motivation for the change and contrast with previous behavior.
- **footer** *(optional)* — breaking changes (`BREAKING CHANGE: ...`) and issue references (`Closes #123`).

Examples:

```
feat(filesearch): support regex and folder exclusion
fix(vault): mask password field by default
docs: add setup instructions to README
ci: run Pester tests on windows-latest
```

## Pull request guidance

- Keep changes small and focused; one logical change per PR.
- Ensure CI is green (PSScriptAnalyzer + Pester on Windows).
- Reference the related issue in the PR description.
- Use Chinese to output the summary and comments of the PR.

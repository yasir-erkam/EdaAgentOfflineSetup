# Repository Guidelines

## Project Structure & Module Organization

This repository packages upstream `salitronic/eda-agent` for offline Windows x64 installation, with separate Altium and KiCad backends.

- Root PowerShell scripts prepare bundles, compile installers, and perform offline installation; `Install.cmd` provides a launcher.
- `payload/` contains Python runtime helpers and `Start-EdaAgent.cmd` copied into bundles.
- `installer/` contains setup, integration cleanup, and the Altium connection assistant; `EdaAgentOfflineSetup.iss` defines the bilingual Inno Setup wizard.
- `tests/` contains PowerShell integration checks and Python regression/probe scripts.
- `dist/` holds generated bundles/installers; `.work/` holds temporary build/test data. Both are ignored. `.tools/InnoSetup/` contains tracked compiler resources.

## Build, Test, and Development Commands

Use Windows PowerShell 5.1 or later from the repository root:

```powershell
.\Build-OfflineBundle.ps1 -Backend altium
.\Build-Installer.ps1 -Backend altium
```

The first command downloads Python, upstream sources, and dependencies. The second requires Inno Setup 6 and creates an EXE plus SHA256 file in `dist/`. Repeat with `-Backend kicad` for KiCad. Pin upstream with `-SourceCommit <40-character-SHA>`. Rebuild bundles after changing packaged helpers.

```powershell
python tests/test_configure.py payload/configure_opencode.py
.\tests\Test-OfflineBundle.ps1 -BundlePath '.\dist\EdaAgent-<build-id>'
```

These run configuration regression checks and Altium bundle integration checks, respectively. Python may be supplied by a prepared bundle's `runtime\python.exe`.

## Coding Style & Naming Conventions

Match existing four-space indentation. Use PowerShell `Verb-Noun.ps1` filenames, descriptive PascalCase parameters, strict mode, and terminating errors. Python uses `snake_case` functions/modules and standard-library helpers where practical. Preserve Windows PowerShell 5.1 compatibility and Turkish/English installer text. No dedicated formatter or linter configuration is present.

## Testing Guidelines

Python checks use `unittest`; PowerShell tests use `Test-*.ps1` names. No numeric coverage threshold is configured. Cover configuration preservation, invalid input, rollback, and backend isolation when affected. Run wizard and separate-package tests in a disposable Windows account. Verify real EDA connectivity separately; MCP probes do not exercise design operations.

## Commit & Pull Request Guidelines

History includes descriptive `feat:` commits alongside informal subjects; prefer concise, imperative subjects with a suitable prefix. PRs should explain behavior changes, affected backends, validation commands/results, and linked issues when available. Include screenshots for wizard or assistant changes.

## Security & Public Distribution

Never commit API keys, real OpenCode configurations/backups, proprietary designs, or machine-specific paths. Review staged changes before publishing. Keep generated bundles and logs out of commits, and preserve upstream LICENSE/NOTICE files in distributions.

# Contributing to PaletteShellScripts

Thanks for sharing your scripts! Contributions are organized **one folder per author** so attribution stays clear and script names never collide.

## Quick start

1. Fork this repository.
2. Create a folder named after your GitHub handle: `scripts/<your-handle>/`.
3. Copy [`scripts/_template/README.md`](scripts/_template/README.md) into your folder and fill it out.
4. Add your `.ps1` scripts (top level of your folder only).
5. Open a pull request.

## Rules

- **Your folder is yours.** Only add or edit files inside `scripts/<your-handle>/`. To change someone else's script, open a PR that explains the fix and ideally tag them.
- **PowerShell only.** Scripts are `.ps1` files that run under PaletteShell.
- **No secrets, no destructive surprises.** Anything that deletes files, modifies the registry, or needs admin rights must declare it (see below) so users are prompted first.
- **Keep it self-contained.** If a script needs a helper module, note it in your folder's README.

## Script format

PaletteShell reads metadata from each script via comment-based help and `[Script*]` attributes — it parses the file with the PowerShell AST and **never executes it just to read metadata**. A minimal script looks like this:

```powershell
using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Generate GUID
.DESCRIPTION
    Generate a new GUID and copy it to the clipboard.
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🆔')]
[ScriptTimeout(5000)]
[ScriptOutput('None')]
param()

$guid = [System.Guid]::NewGuid().ToString()
Write-Host "Generated GUID: $guid"
Set-ClipboardText $guid
```

- `.SYNOPSIS` becomes the command **title** (falls back to the file name).
- `.DESCRIPTION` becomes the subtitle.
- `param()` drives an interactive input form; `[ValidateSet(...)]` becomes a dropdown, `[ValidateRange(...)]` becomes min/max bounds.

### Common attributes

| Attribute | Purpose |
|---|---|
| `[ScriptHost('pwsh'\|'powershell')]` | Which PowerShell to run under. Optional — omit it to run under the user's configured default host instead of pinning one. |
| `[ScriptGroup('Name')]` | Category/group in the palette |
| `[ScriptVersion('1.0.0')]` | Script version (SemVer recommended) — lets tools detect when a newer copy is available |
| `[ScriptIcon('🆔')]` | Emoji or glyph icon |
| `[ScriptTimeout(5000)]` | Timeout in milliseconds |
| `[ScriptOutput('None'\|'Toast'\|'Clipboard'\|'Markdown'\|'File'\|'List')]` | How stdout is handled |
| `[ScriptCwd('path')]` | Working directory |
| `[ScriptEnv('KEY','value')]` | Set an environment variable |
| `[RequiresElevation()]` | Run as administrator (or use `#Requires -RunAsAdministrator`) |
| `[ConfirmBeforeRun('message')]` | Prompt yes/no before running — use for destructive scripts |

> The `PaletteScriptAttributes.psm1` module (which defines these attributes and the `Get-ClipboardText` / `Set-ClipboardText` helpers) ships with the PaletteShell extension and is copied next to your scripts at runtime. You don't need to include it here.

## Checklist before opening a PR

- [ ] Everything is under `scripts/<your-handle>/`.
- [ ] Each script has a `.SYNOPSIS` and `.DESCRIPTION`.
- [ ] Destructive or elevated scripts declare `[ConfirmBeforeRun(...)]` / `[RequiresElevation()]`.
- [ ] Your folder's `README.md` lists your scripts.
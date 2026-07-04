# PaletteShellScripts

Community script library for **[PaletteShell](https://github.com/paletteshell/PaletteShellExtension)** — a [Windows Command Palette](https://learn.microsoft.com/windows/powertoys/command-palette/overview) extension that runs custom PowerShell scripts straight from the palette.

Browse a collection you like, copy the `.ps1` files into your scripts folder (defaults to `Documents\PaletteShellScripts`, but is configurable from PaletteShell's Settings), run **"Reload scripts"** in the palette, and they show up as searchable, runnable commands.

> 💡 You can reach this repository from inside the palette via the **"Find more scripts"** command.

## 📂 Repository layout

Every script lives under [`scripts/`](scripts/), organized into one folder per **author**:

```
scripts/
├── README.md              ← author folder convention
├── <author-a>/
│   ├── README.md          ← who they are + index of their scripts
│   ├── Some-Script.ps1
│   └── Another-Script.ps1
└── <author-b>/
    ├── README.md
    └── Cool-Script.ps1
```

Each author owns a single folder named after their GitHub handle and is responsible for the scripts inside it. This keeps contributions isolated, makes attribution obvious, and avoids naming collisions between people who happen to write a `Format-Json.ps1`.

## 🗂️ index.json

[`index.json`](index.json) at the repo root is a machine-readable catalog of every script in this repository. It's generated from `scripts/` by [`tools/Build-Index.ps1`](tools/Build-Index.ps1) and committed automatically by a GitHub Actions workflow after every merge to `main` — don't hand-edit it, and you don't need to touch it in your PR.

## 🚀 Using a script

1. Open an author's folder under [`scripts/`](scripts/) and pick a script.
2. Copy the `.ps1` file into your scripts folder (use **"Open scripts folder"** in the palette to get there — it defaults to `Documents\PaletteShellScripts`, but is configurable from Settings).
3. Run **"Reload scripts"** in the palette. The script now appears as a command.

> ℹ️ Scripts may declare a target host (`pwsh` or `powershell`), parameters, an icon, and other behavior via `[Script*]` attributes. PaletteShell reads this metadata without executing the script. Review any script before you run it.

## ✍️ Contributing

Add your own collection under `scripts/<your-github-handle>/`. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full guide, including the expected script header format and a template.

## 📜 License

Released under the [MIT License](LICENSE). By contributing, you agree that your scripts are shared under the same license.

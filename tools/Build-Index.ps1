<#
.SYNOPSIS
    Build index.json - the catalog the PaletteShell extension's in-palette
    "Browse community scripts" page fetches and installs from.
.DESCRIPTION
    Scans every scripts/<author>/*.ps1 file (top level only - PaletteShell itself never
    recurses into subfolders, so neither does this), parses each with the same
    comment-based-help + attribute conventions PaletteShell uses (via the PowerShell AST -
    scripts are never executed just to read their metadata), and writes the result to
    index.json at the repo root.
.PARAMETER RepoRoot
    Root of the PaletteShellScripts repo. Defaults to the parent of this script's folder.
.PARAMETER OutputPath
    Where to write the catalog. Defaults to <RepoRoot>/index.json.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot 'index.json'
}

# Author folders that don't hold real, shareable scripts.
$ExcludedAuthors = @('_template')

# Mirrors PowerShellScriptParser.ParseCommentHelp in the PaletteShellExtension repo: find the
# first <# ... #> block anywhere in the raw text (not tied to AST position - a script's
# comment help commonly sits after a leading "using module" line, which the built-in
# $ast.GetHelpContent() does not recognize as script-level help) and read .SYNOPSIS /
# .DESCRIPTION out of it line by line.
function Get-CommentHelp {
    param([Parameter(Mandatory)][string]$Content)

    $result = [pscustomobject]@{ Synopsis = $null; Description = $null }

    $blockMatch = [regex]::Match($Content, '<#(.*?)#>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $blockMatch.Success) {
        return $result
    }

    $section = $null
    $buffer = [System.Text.StringBuilder]::new()

    foreach ($rawLine in ($blockMatch.Groups[1].Value -replace "`r`n", "`n" -split "`n")) {
        $line = $rawLine.Trim()
        $keyMatch = [regex]::Match($line, '^\.(?<k>[A-Za-z]+)(?:\s+(?<a>\S+))?\s*$')
        if ($keyMatch.Success) {
            if ($section -eq 'SYNOPSIS') { $result.Synopsis = $buffer.ToString().Trim() }
            elseif ($section -eq 'DESCRIPTION') { $result.Description = $buffer.ToString().Trim() }
            $buffer.Clear() | Out-Null

            $keyword = $keyMatch.Groups['k'].Value.ToUpperInvariant()
            $section = if ($keyword -in @('SYNOPSIS', 'DESCRIPTION')) { $keyword } else { $null }
            continue
        }

        if ($section) {
            [void]$buffer.AppendLine($rawLine)
        }
    }

    if ($section -eq 'SYNOPSIS') { $result.Synopsis = $buffer.ToString().Trim() }
    elseif ($section -eq 'DESCRIPTION') { $result.Description = $buffer.ToString().Trim() }

    if ([string]::IsNullOrWhiteSpace($result.Synopsis)) { $result.Synopsis = $null }
    if ([string]::IsNullOrWhiteSpace($result.Description)) { $result.Description = $null }

    return $result
}

function Get-ScriptMetadata {
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        throw "Parse error(s): $($parseErrors -join '; ')"
    }

    $help = Get-CommentHelp -Content (Get-Content -Path $Path -Raw)
    $title = if ($help.Synopsis) { $help.Synopsis } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    $description = $help.Description

    # [ScriptGroup(...)] / [ScriptIcon(...)] / [ScriptVersion(...)] live on the param block's
    # attribute list, ahead of param() itself - read them straight off the AST rather than
    # executing anything. ParamBlock is null for a script with no param() at all.
    $group = $null
    $icon = $null
    $version = $null

    if ($ast.ParamBlock) {
        foreach ($attributeAst in $ast.ParamBlock.Attributes) {
            $firstArg = $attributeAst.PositionalArguments | Select-Object -First 1
            if ($firstArg -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
                continue
            }

            switch ($attributeAst.TypeName.Name) {
                'ScriptGroup' { $group = $firstArg.Value }
                'ScriptIcon' { $icon = $firstArg.Value }
                'ScriptVersion' { $version = $firstArg.Value }
            }
        }
    }

    # A script that omits [ScriptVersion(...)] is assumed to be at the baseline version rather
    # than having "no version" - keeps every catalog entry comparable instead of the Store
    # having to special-case a missing field.
    if (-not $version) {
        $version = '1.0.0'
    }

    [pscustomobject]@{
        Title       = $title
        Description = $description
        Group       = $group
        Icon        = $icon
        Version     = $version
    }
}

$scriptsRoot = Join-Path $RepoRoot 'scripts'
$entries = [System.Collections.Generic.List[object]]::new()
$hadErrors = $false

Get-ChildItem -Path $scriptsRoot -Directory | ForEach-Object {
    $author = $_.Name
    if ($ExcludedAuthors -contains $author) {
        return
    }

    Get-ChildItem -Path $_.FullName -Filter '*.ps1' -File | ForEach-Object {
        $scriptFile = $_
        $relativePath = ('scripts/{0}/{1}' -f $author, $scriptFile.Name).Replace('\', '/')

        try {
            $meta = Get-ScriptMetadata -Path $scriptFile.FullName
        } catch {
            Write-Error "Failed to parse ${relativePath}: $_"
            $hadErrors = $true
            return
        }

        $sha = (git -C $RepoRoot hash-object $scriptFile.FullName).Trim()

        # Commit date of the most recent commit that touched this file - i.e. what GitHub's
        # own "Latest commit" file history shows. Requires full history (not a shallow clone);
        # on a depth-1 checkout every file would falsely show the same single available commit.
        # $null (rather than empty output) when the file has no commits yet, e.g. it's staged
        # but not committed - `git log` prints nothing rather than an empty line.
        $lastModifiedRaw = git -C $RepoRoot log -1 --format=%cI -- $relativePath
        $lastModified = if ($lastModifiedRaw) { $lastModifiedRaw.Trim() } else { $null }

        $entries.Add([ordered]@{
            path         = $relativePath
            title        = $meta.Title
            description  = $meta.Description
            group        = $meta.Group
            icon         = $meta.Icon
            author       = $author
            tags         = @()
            sha          = $sha
            version      = $meta.Version
            lastModified = $lastModified
        })
    }
}

if ($hadErrors) {
    throw 'One or more scripts failed to parse - see errors above. index.json was not written.'
}

$sortedEntries = $entries | Sort-Object path

$index = [ordered]@{
    version = 1
    scripts = @($sortedEntries)
}

# Depth needs to comfortably exceed the object graph (script -> string fields + tags array).
$json = $index | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($OutputPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Output "Wrote $($entries.Count) script(s) from $((Get-ChildItem -Path $scriptsRoot -Directory | Where-Object { $ExcludedAuthors -notcontains $_.Name }).Count) author folder(s) to $OutputPath"

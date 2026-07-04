<#
.SYNOPSIS
    Validate script contribution checklist items.
.DESCRIPTION
    Checks the scripts/ tree for contributor-facing requirements that should be
    caught on pull requests: parseable PowerShell, filled-in comment help, author
    README files, README script listings, and basic PaletteShell metadata shape.
.PARAMETER RepoRoot
    Root of the PaletteShellScripts repo. Defaults to the parent of this script's folder.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExcludedAuthors = @('_template')
$AllowedHosts = @('pwsh', 'powershell')
$AllowedOutputs = @('None', 'Toast', 'Clipboard', 'Markdown', 'File', 'List')
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Message
    )

    $failures.Add("${Path}: ${Message}")
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $Path)
    return $relative.Replace('\', '/')
}

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

function Get-FirstAttributeArgument {
    param([Parameter(Mandatory)]$AttributeAst)

    $firstArg = $AttributeAst.PositionalArguments | Select-Object -First 1
    if ($firstArg -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $firstArg.Value
    }

    if ($firstArg -is [System.Management.Automation.Language.ConstantExpressionAst]) {
        return [string]$firstArg.Value
    }

    return $null
}

$scriptsRoot = Join-Path $RepoRoot 'scripts'
if (-not (Test-Path -Path $scriptsRoot -PathType Container)) {
    throw "Scripts directory not found: $scriptsRoot"
}

$authorFolders = Get-ChildItem -Path $scriptsRoot -Directory |
    Where-Object { $ExcludedAuthors -notcontains $_.Name } |
    Sort-Object Name

foreach ($authorFolder in $authorFolders) {
    $authorRelativePath = Get-RelativePath -Path $authorFolder.FullName
    $readmePath = Join-Path $authorFolder.FullName 'README.md'
    $readmeContent = $null

    if (-not (Test-Path -Path $readmePath -PathType Leaf)) {
        Add-Failure -Path $authorRelativePath -Message 'Missing README.md for this author folder.'
    }
    else {
        $readmeContent = Get-Content -Path $readmePath -Raw
        $placeholderPatterns = @(
            '<Your Name>',
            '@your-handle',
            'your-handle',
            'Example-Script.ps1',
            'Remove the placeholder row'
        )

        foreach ($placeholder in $placeholderPatterns) {
            if ($readmeContent -like "*$placeholder*") {
                Add-Failure -Path (Get-RelativePath -Path $readmePath) -Message "Still contains template placeholder text: '$placeholder'."
            }
        }
    }

    $scriptFiles = Get-ChildItem -Path $authorFolder.FullName -Filter '*.ps1' -File | Sort-Object Name
    foreach ($scriptFile in $scriptFiles) {
        $relativePath = Get-RelativePath -Path $scriptFile.FullName
        $content = Get-Content -Path $scriptFile.FullName -Raw

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors -and $parseErrors.Count -gt 0) {
            Add-Failure -Path $relativePath -Message "PowerShell parse error(s): $($parseErrors -join '; ')"
            continue
        }

        $help = Get-CommentHelp -Content $content
        if (-not $help.Synopsis) {
            Add-Failure -Path $relativePath -Message 'Missing .SYNOPSIS in comment-based help.'
        }

        if (-not $help.Description) {
            Add-Failure -Path $relativePath -Message 'Missing .DESCRIPTION in comment-based help.'
        }

        if ($readmeContent -and $readmeContent -notmatch [regex]::Escape($scriptFile.Name)) {
            Add-Failure -Path (Get-RelativePath -Path $readmePath) -Message "Does not list $($scriptFile.Name)."
        }

        $attributes = @{}
        if ($ast.ParamBlock) {
            foreach ($attributeAst in $ast.ParamBlock.Attributes) {
                $attributes[$attributeAst.TypeName.Name] = Get-FirstAttributeArgument -AttributeAst $attributeAst
            }
        }

        if (-not $attributes.ContainsKey('ScriptHost')) {
            Add-Failure -Path $relativePath -Message 'Missing [ScriptHost(''pwsh''|''powershell'')].'
        }
        elseif ($AllowedHosts -notcontains $attributes['ScriptHost']) {
            Add-Failure -Path $relativePath -Message "Invalid ScriptHost '$($attributes['ScriptHost'])'. Expected one of: $($AllowedHosts -join ', ')."
        }

        if ($attributes.ContainsKey('ScriptOutput') -and $AllowedOutputs -notcontains $attributes['ScriptOutput']) {
            Add-Failure -Path $relativePath -Message "Invalid ScriptOutput '$($attributes['ScriptOutput'])'. Expected one of: $($AllowedOutputs -join ', ')."
        }

        if ($attributes.ContainsKey('ScriptTimeout')) {
            $timeout = 0
            if (-not [int]::TryParse($attributes['ScriptTimeout'], [ref]$timeout) -or $timeout -le 0) {
                Add-Failure -Path $relativePath -Message "Invalid ScriptTimeout '$($attributes['ScriptTimeout'])'. Expected a positive integer number of milliseconds."
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Contribution validation failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }

    exit 1
}

Write-Output "Contribution validation passed for $($authorFolders.Count) author folder(s)."

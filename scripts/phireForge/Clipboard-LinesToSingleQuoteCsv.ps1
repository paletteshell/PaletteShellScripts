using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Join Lines (Quoted)
.DESCRIPTION
    Take multi-line text from the clipboard, wrap each line in single quotes, and join into one comma-delimited line
#>
[ScriptHost('pwsh')]
[ScriptGroup('Text')]
[ScriptIcon('🔗')]
[ScriptTimeout(5000)]
[ScriptOutput('Clipboard')]
param()

$text = Get-ClipboardText
if ([string]::IsNullOrWhiteSpace($text)) {
    Write-Error 'Clipboard is empty or contains no text.'
    return
}

# Split on any line-ending style, drop blank/whitespace-only lines, trim each.
$lines = $text -split '\r?\n' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

# Wrap each line in single quotes, escaping any embedded single quote by doubling it (SQL-style).
$quoted = $lines | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }

$joined = $quoted -join ', '

Write-Output $joined

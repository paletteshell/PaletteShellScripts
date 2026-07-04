using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Join Lines (Double Quoted)
.DESCRIPTION
    Take multi-line text from the clipboard, wrap each line in double quotes, and join into one comma-delimited line
#>
[ScriptGroup('Text')]
[ScriptVersion('1.0.0')]
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

# Wrap each line in double quotes, escaping any embedded double quote by doubling it (CSV-style).
$quoted = $lines | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }

$joined = $quoted -join ', '

Write-Output $joined

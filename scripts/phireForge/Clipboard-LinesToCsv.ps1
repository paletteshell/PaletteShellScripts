using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Join Lines
.DESCRIPTION
    Take multi-line text from the clipboard and join it into a single comma-delimited line
#>
[ScriptHost('pwsh')]
[ScriptGroup('Text')]
[ScriptIcon('🔗')]
[ScriptTimeout(5000)]
[ScriptOutput('Clipboard')]
param(
    # Text placed between each line. Defaults to a comma and a space.
    [ValidateSet(', ', ',', '; ', ';', ' | ', ' ')]
    [string]$Separator = ', '
)

$text = Get-ClipboardText
if ([string]::IsNullOrWhiteSpace($text)) {
    Write-Error 'Clipboard is empty or contains no text.'
    return
}

# Split on any line-ending style, drop blank/whitespace-only lines, trim each.
$lines = $text -split '\r?\n' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

$joined = $lines -join $Separator

Write-Output $joined

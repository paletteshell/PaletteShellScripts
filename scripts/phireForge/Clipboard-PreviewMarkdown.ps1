using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Preview Markdown
.DESCRIPTION
    Take Markdown text from the clipboard and display it rendered in Markdown mode
#>
[ScriptHost('pwsh')]
[ScriptGroup('Text')]
[ScriptIcon('👁️')]
[ScriptTimeout(5000)]
[ScriptOutput('Markdown')]
param()

$text = Get-ClipboardText
if ([string]::IsNullOrWhiteSpace($text)) {
    Write-Error 'Clipboard is empty or contains no Markdown text.'
    return
}

Write-Host $text

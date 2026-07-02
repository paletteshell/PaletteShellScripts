using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Env Vars to Markdown
.DESCRIPTION
    Dump the current environment variables as a fenced Markdown code block
#>
[ScriptHost('pwsh')]
[ScriptGroup('Utilities')]
[ScriptIcon('🌱')]
[ScriptTimeout(10000)]
[ScriptOutput('Markdown')]
param()

$vars = Get-ChildItem Env: | Sort-Object Name

Write-Host '```ini'
foreach ($v in $vars) {
    Write-Host "$($v.Name)=$($v.Value)"
}
Write-Host '```'

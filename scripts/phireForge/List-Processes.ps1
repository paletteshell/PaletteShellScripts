using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    List Processes
.DESCRIPTION
    Browse running processes sorted by memory use; select one to copy its PID (pair with "Stop Process" to terminate it)
.PARAMETER Filter
    Optional text to match against the process name
#>
[ScriptHost('pwsh')]
[ScriptGroup('Utilities')]
[ScriptIcon('📋')]
[ScriptTimeout(15000)]
[ScriptOutput('List')]
param(
    # Type to filter by process name
    [Parameter()]
    [string]$Filter = ''
)

$procs = Get-Process

if (-not [string]::IsNullOrWhiteSpace($Filter)) {
    $procs = $procs | Where-Object { $_.ProcessName -like "*$Filter*" }
}

# One row per process, largest memory first. The copy value is the PID so selecting an
# item drops the PID onto the clipboard for use with Stop-Process.
$rows = $procs |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 100 |
    ForEach-Object {
        [pscustomobject]@{
            title    = $_.ProcessName
            subtitle = "PID $($_.Id)  -  $([math]::Round($_.WorkingSet64 / 1MB, 1)) MB"
            value    = "$($_.Id)"
        }
    }

# -AsArray keeps the output a JSON array even when a single process matches.
$rows | ConvertTo-Json -AsArray -Depth 3

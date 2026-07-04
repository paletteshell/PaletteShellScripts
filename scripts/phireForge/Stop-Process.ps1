using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Stop Process
.DESCRIPTION
    Terminate a running process by PID or name. Pairs with "List Processes", which copies a PID you can paste here.
.PARAMETER Target
    A process ID (e.g. 1234) or a process name (e.g. notepad)
.EXAMPLE
    .\Stop-Process.ps1 -Target 1234
    Terminate the process with PID 1234
.EXAMPLE
    .\Stop-Process.ps1 -Target notepad
    Terminate every process named notepad
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🛑')]
[ScriptTimeout(10000)]
[ScriptOutput('Toast')]
[ConfirmBeforeRun('This will forcibly terminate the matching process(es). Unsaved work may be lost.')]
[CmdletBinding()]
param(
    # A process ID or a process name
    [Parameter(Mandatory = $true, HelpMessage = 'Process ID (e.g. 1234) or name (e.g. notepad)')]
    [string]$Target
)

$Target = $Target.Trim()

# A purely numeric target is treated as a PID; anything else is a process name.
if ($Target -match '^\d+$') {
    $procId = [int]$Target
    $procs = @(Get-Process -Id $procId -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        Write-Output "No process found with PID $procId."
        return
    }
}
else {
    $name = $Target -replace '\.exe$', ''
    $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        Write-Output "No process found named '$name'."
        return
    }
}

$stopped = 0
$failed = @()
foreach ($p in $procs) {
    try {
        Stop-Process -Id $p.Id -Force -ErrorAction Stop
        $stopped++
    }
    catch {
        $failed += "$($p.ProcessName) (PID $($p.Id))"
    }
}

$summary = "Terminated $stopped process(es)."
if ($failed.Count -gt 0) {
    $summary += " Failed: $($failed -join ', '). Try running as administrator."
}
Write-Output $summary

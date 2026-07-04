using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Event Log Errors
.DESCRIPTION
    Show recent Windows Event Log errors, rendered as Markdown
.PARAMETER Days
    Number of days of event history to search
.PARAMETER MaxEvents
    Maximum number of events to display
.PARAMETER IncludeWarnings
    Include warning events along with errors
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🚨')]
[ScriptTimeout(20000)]
[ScriptOutput('Markdown')]
param(
    [ValidateRange(1, 30)]
    [int]$Days = 1,

    [ValidateRange(1, 100)]
    [int]$MaxEvents = 25,

    [bool]$IncludeWarnings = $false
)

function Format-TableValue {
    param($Value)

    if ($null -eq $Value) { return 'n/a' }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'n/a' }

    return ($text.Trim() -replace '\|', '\|' -replace "`r?`n", '<br>')
}

function Format-Message {
    param(
        $Value,

        [int]$MaxLength = 220
    )

    $text = Format-TableValue $Value
    if ($text -eq 'n/a') { return $text }
    if ($text.Length -le $MaxLength) { return $text }

    return ($text.Substring(0, $MaxLength - 3) + '...')
}

$levels = if ($IncludeWarnings) { @(2, 3) } else { @(2) }
$levelLabel = if ($IncludeWarnings) { 'errors and warnings' } else { 'errors' }
$startTime = (Get-Date).AddDays(-$Days)
$logs = @('Application', 'System')
$events = @()
$queryErrors = @()

foreach ($log in $logs) {
    try {
        $events += Get-WinEvent -FilterHashtable @{
            LogName   = $log
            Level     = $levels
            StartTime = $startTime
        } -MaxEvents $MaxEvents -ErrorAction Stop
    }
    catch {
        $queryErrors += ('{0}: {1}' -f $log, $_.Exception.Message)
    }
}

$events = $events |
    Sort-Object TimeCreated -Descending |
    Select-Object -First $MaxEvents

Write-Host '# 🚨 Event Log Errors'
Write-Host ''
Write-Host "_Showing recent $levelLabel since $($startTime.ToString('yyyy-MM-dd HH:mm'))_"
Write-Host ''

if ($queryErrors.Count -gt 0) {
    Write-Host '## Query Notes'
    Write-Host ''
    foreach ($queryError in $queryErrors) {
        Write-Host ("- {0}" -f (Format-TableValue $queryError))
    }
    Write-Host ''
}

Write-Host '## Events'
Write-Host ''
Write-Host '| Time | Log | Level | Source | ID | Message |'
Write-Host '| --- | --- | --- | --- | ---: | --- |'

if ($events.Count -eq 0) {
    Write-Host '| n/a | n/a | n/a | n/a | n/a | No matching events found. |'
}
else {
    foreach ($event in $events) {
        Write-Host ('| {0} | {1} | {2} | {3} | {4} | {5} |' -f `
                (Format-TableValue $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')),
                (Format-TableValue $event.LogName),
                (Format-TableValue $event.LevelDisplayName),
                (Format-TableValue $event.ProviderName),
                (Format-TableValue $event.Id),
                (Format-Message $event.Message))
    }
}

using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Time Zones
.DESCRIPTION
    Show current time across all or selected time zones, rendered as Markdown
.PARAMETER TimeZones
    Comma-delimited Windows time zone IDs to display. Leave blank to show all time zones.
.PARAMETER Use24HourTime
    Display times in 24-hour format
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🕒')]
[ScriptTimeout(10000)]
[ScriptOutput('Markdown')]
param(
    [string]$TimeZones = '',

    [bool]$Use24HourTime = $false
)

function Format-TableValue {
    param($Value)

    if ($null -eq $Value) { return 'n/a' }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'n/a' }

    return ($text.Trim() -replace '\|', '\|' -replace "`r?`n", '<br>')
}

function Get-TimeZoneById {
    param([string]$Id)

    try {
        return [System.TimeZoneInfo]::FindSystemTimeZoneById($Id)
    }
    catch {
        return $null
    }
}

$showAllTimeZones = [string]::IsNullOrWhiteSpace($TimeZones)
$requestedTimeZones = if ($showAllTimeZones) {
    [System.TimeZoneInfo]::GetSystemTimeZones()
}
else {
    $TimeZones -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' } |
        Select-Object -Unique
}

$now = Get-Date
$utcNow = $now.ToUniversalTime()
$timeFormat = if ($Use24HourTime) { 'yyyy-MM-dd HH:mm:ss' } else { 'yyyy-MM-dd h:mm:ss tt' }
$rows = @()
$invalidTimeZones = @()
$requestedTimeZoneIds = @($requestedTimeZones | ForEach-Object {
        if ($_ -is [System.TimeZoneInfo]) { $_.Id } else { $_ }
    })

if ('UTC' -notin $requestedTimeZoneIds) {
    $rows += [pscustomobject]@{
        Name       = 'UTC'
        Id         = 'UTC'
        Time       = $utcNow
        Offset     = [TimeSpan]::Zero
        IsDaylight = $false
    }
}

foreach ($timeZoneId in $requestedTimeZones) {
    $timeZone = if ($timeZoneId -is [System.TimeZoneInfo]) { $timeZoneId } else { Get-TimeZoneById -Id $timeZoneId }
    if ($null -eq $timeZone) {
        $invalidTimeZones += $timeZoneId
        continue
    }

    $time = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $timeZone)

    $rows += [pscustomobject]@{
        Name       = $timeZone.DisplayName
        Id         = $timeZone.Id
        Time       = $time
        Offset     = $timeZone.GetUtcOffset($utcNow)
        IsDaylight = $timeZone.IsDaylightSavingTime($time)
    }
}

Write-Host '# 🕒 Time Zones'
Write-Host ''
Write-Host "_Generated $($now.ToString($timeFormat)) local time_"
Write-Host ''

if ($invalidTimeZones.Count -gt 0) {
    Write-Host '## Notes'
    Write-Host ''
    foreach ($invalidTimeZone in $invalidTimeZones) {
        Write-Host ('- Unknown Windows time zone ID: `{0}`' -f (Format-TableValue $invalidTimeZone))
    }
    Write-Host ''
}

Write-Host '## Current Time'
Write-Host ''
Write-Host '| Time zone | ID | Current time | UTC offset | DST |'
Write-Host '| --- | --- | --- | ---: | --- |'

foreach ($row in $rows) {
    $offset = if ($row.Offset -ge [TimeSpan]::Zero) {
        '+{0:hh\:mm}' -f $row.Offset
    }
    else {
        '-{0:hh\:mm}' -f $row.Offset.Duration()
    }

    $dst = if ($row.IsDaylight) { 'Yes' } else { 'No' }

    Write-Host ('| {0} | `{1}` | {2} | UTC{3} | {4} |' -f `
            (Format-TableValue $row.Name),
            (Format-TableValue $row.Id),
            (Format-TableValue $row.Time.ToString($timeFormat)),
            $offset,
            $dst)
}

Write-Host ''
Write-Host '## Tip'
Write-Host ''
Write-Host 'Leave `TimeZones` blank to show every system time zone, or pass Windows time zone IDs like `Eastern Standard Time, Pacific Standard Time, GMT Standard Time`.'

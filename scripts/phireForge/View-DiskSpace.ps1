using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Disk Space
.DESCRIPTION
    Show disk space statistics for all drives, rendered as Markdown
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('💾')]
[ScriptTimeout(15000)]
[ScriptOutput('Markdown')]
param()

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} KB' -f ($Bytes / 1KB))
}

function Get-UsageBar {
    param([double]$Percent)
    $slots = 10
    $filled = [math]::Round($Percent / 100 * $slots)
    if ($filled -gt $slots) { $filled = $slots }
    if ($filled -lt 0) { $filled = 0 }
    return ('█' * $filled) + ('░' * ($slots - $filled))
}

# Fixed local disks (DriveType 3)
$disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' | Sort-Object DeviceID

Write-Host "# 💾 Disk Space"
Write-Host ""
Write-Host "_Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME_"
Write-Host ""
Write-Host "| Drive | Label | Used | Free | Total | Usage |"
Write-Host "| --- | --- | ---: | ---: | ---: | :--- |"

$totalSize = 0.0
$totalFree = 0.0

foreach ($disk in $disks) {
    $size = [double]$disk.Size
    $free = [double]$disk.FreeSpace
    if ($size -le 0) { continue }

    $used = $size - $free
    $percentUsed = $used / $size * 100
    $bar = Get-UsageBar -Percent $percentUsed
    $label = if ([string]::IsNullOrWhiteSpace($disk.VolumeName)) { '—' } else { $disk.VolumeName }

    $totalSize += $size
    $totalFree += $free

    Write-Host ("| {0} | {1} | {2} | {3} | {4} | {5} {6:N0}% |" -f `
        $disk.DeviceID, $label, (Format-Size $used), (Format-Size $free), (Format-Size $size), $bar, $percentUsed)
}

if ($totalSize -gt 0) {
    $totalUsed = $totalSize - $totalFree
    $totalPercent = $totalUsed / $totalSize * 100
    Write-Host ""
    Write-Host ("**Total:** {0} used / {1} free of {2} ({3:N0}% used)" -f `
        (Format-Size $totalUsed), (Format-Size $totalFree), (Format-Size $totalSize), $totalPercent)
}

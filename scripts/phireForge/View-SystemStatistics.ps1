using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    System Statistics
.DESCRIPTION
    Show operating system, hardware, memory, disk, network, and process statistics rendered as Markdown
.PARAMETER TopProcesses
    Number of memory-heavy processes to include
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('📊')]
[ScriptTimeout(20000)]
[ScriptOutput('Markdown')]
param(
    [ValidateRange(1, 25)]
    [int]$TopProcesses = 8
)

function Get-SafeCimInstance {
    param(
        [Parameter(Mandatory)]
        [string]$ClassName,

        [string]$Filter
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Filter)) {
            return Get-CimInstance -ClassName $ClassName -ErrorAction Stop
        }

        return Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Format-Bytes {
    param([Nullable[double]]$Bytes)

    if ($null -eq $Bytes) { return 'n/a' }
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function Format-Percent {
    param([Nullable[double]]$Value)

    if ($null -eq $Value) { return 'n/a' }
    return ('{0:N1}%' -f $Value)
}

function Format-Duration {
    param([Nullable[TimeSpan]]$Duration)

    if ($null -eq $Duration) { return 'n/a' }

    $parts = @()
    if ($Duration.Value.Days -gt 0) { $parts += ('{0}d' -f $Duration.Value.Days) }
    if ($Duration.Value.Hours -gt 0) { $parts += ('{0}h' -f $Duration.Value.Hours) }
    if ($Duration.Value.Minutes -gt 0 -or $parts.Count -eq 0) { $parts += ('{0}m' -f $Duration.Value.Minutes) }

    return ($parts -join ' ')
}

function Format-TableValue {
    param($Value)

    if ($null -eq $Value) { return 'n/a' }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'n/a' }
    return ($text -replace '\|', '\|' -replace "`r?`n", '<br>')
}

function Write-KeyValueTable {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Values
    )

    Write-Host "## $Title"
    Write-Host ''
    Write-Host '| Metric | Value |'
    Write-Host '| --- | --- |'

    foreach ($key in $Values.Keys) {
        Write-Host ('| {0} | {1} |' -f (Format-TableValue $key), (Format-TableValue $Values[$key]))
    }

    Write-Host ''
}

$os = Get-SafeCimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -First 1
$computer = Get-SafeCimInstance -ClassName 'Win32_ComputerSystem' | Select-Object -First 1
$processor = Get-SafeCimInstance -ClassName 'Win32_Processor' | Select-Object -First 1
$bios = Get-SafeCimInstance -ClassName 'Win32_BIOS' | Select-Object -First 1
$videoControllers = Get-SafeCimInstance -ClassName 'Win32_VideoController'
$logicalDisks = Get-SafeCimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DriveType = 3' | Sort-Object DeviceID
$networkAdapters = Get-SafeCimInstance -ClassName 'Win32_NetworkAdapter' -Filter 'NetEnabled = True' | Sort-Object Name
$networkConfigs = Get-SafeCimInstance -ClassName 'Win32_NetworkAdapterConfiguration' -Filter 'IPEnabled = True'

$lastBoot = if ($os -and $os.LastBootUpTime) { $os.LastBootUpTime } else { $null }
$uptime = if ($lastBoot) { (Get-Date) - $lastBoot } else { $null }
$totalMemoryBytes = if ($computer -and $computer.TotalPhysicalMemory) { [double]$computer.TotalPhysicalMemory } else { $null }
$freeMemoryBytes = if ($os -and $os.FreePhysicalMemory) { [double]$os.FreePhysicalMemory * 1KB } else { $null }
$usedMemoryBytes = if ($null -ne $totalMemoryBytes -and $null -ne $freeMemoryBytes) { $totalMemoryBytes - $freeMemoryBytes } else { $null }
$memoryUsedPercent = if ($totalMemoryBytes -and $totalMemoryBytes -gt 0 -and $null -ne $usedMemoryBytes) { $usedMemoryBytes / $totalMemoryBytes * 100 } else { $null }
$computerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($computer.Name) { $computer.Name } else { 'n/a' }
$gpuNames = if ($videoControllers) {
    ($videoControllers | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } | Select-Object -ExpandProperty Name -Unique) -join '<br>'
} else {
    'n/a'
}

Write-Host '# 📊 System Statistics'
Write-Host ''
Write-Host "_Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') on ${computerName}_"
Write-Host ''

Write-KeyValueTable -Title 'Overview' -Values ([ordered]@{
        'Computer'     = $computerName
        'User'         = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { $env:USERNAME }
        'Uptime'       = (Format-Duration $uptime)
        'Last boot'    = if ($lastBoot) { $lastBoot.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
        'PowerShell'   = $PSVersionTable.PSVersion.ToString()
        'Process arch' = $env:PROCESSOR_ARCHITECTURE
    })

Write-KeyValueTable -Title 'Operating System' -Values ([ordered]@{
        'Caption'      = $os.Caption
        'Version'      = $os.Version
        'Build number' = $os.BuildNumber
        'Install date' = if ($os.InstallDate) { $os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
        'Locale'       = $os.Locale
        'Time zone'    = (Get-TimeZone).DisplayName
    })

Write-KeyValueTable -Title 'Hardware' -Values ([ordered]@{
        'Manufacturer' = $computer.Manufacturer
        'Model'        = $computer.Model
        'BIOS version' = if ($bios.SMBIOSBIOSVersion) { $bios.SMBIOSBIOSVersion } else { ($bios.BIOSVersion -join ', ') }
        'CPU'          = $processor.Name
        'Cores'        = $processor.NumberOfCores
        'Logical CPUs' = $processor.NumberOfLogicalProcessors
        'GPU'          = $gpuNames
    })

Write-Host '## Memory'
Write-Host ''
Write-Host '| Total | Used | Free | Usage |'
Write-Host '| ---: | ---: | ---: | ---: |'
Write-Host ('| {0} | {1} | {2} | {3} |' -f `
        (Format-Bytes $totalMemoryBytes),
        (Format-Bytes $usedMemoryBytes),
        (Format-Bytes $freeMemoryBytes),
        (Format-Percent $memoryUsedPercent))
Write-Host ''

Write-Host '## Fixed Disks'
Write-Host ''
Write-Host '| Drive | Label | Used | Free | Total | Usage |'
Write-Host '| --- | --- | ---: | ---: | ---: | ---: |'

if ($logicalDisks) {
    foreach ($disk in $logicalDisks) {
        $size = [double]$disk.Size
        $free = [double]$disk.FreeSpace
        if ($size -le 0) { continue }

        $used = $size - $free
        $usedPercent = $used / $size * 100
        $label = if ([string]::IsNullOrWhiteSpace($disk.VolumeName)) { 'n/a' } else { $disk.VolumeName }

        Write-Host ('| {0} | {1} | {2} | {3} | {4} | {5} |' -f `
                (Format-TableValue $disk.DeviceID),
                (Format-TableValue $label),
                (Format-Bytes $used),
                (Format-Bytes $free),
                (Format-Bytes $size),
                (Format-Percent $usedPercent))
    }
}
else {
    Write-Host '| n/a | n/a | n/a | n/a | n/a | n/a |'
}

Write-Host ''
Write-Host '## Network'
Write-Host ''
Write-Host '| Adapter | MAC | Speed | IP addresses |'
Write-Host '| --- | --- | ---: | --- |'

if ($networkAdapters) {
    foreach ($adapter in $networkAdapters) {
        $config = $networkConfigs | Where-Object { $_.MACAddress -eq $adapter.MACAddress } | Select-Object -First 1
        $ips = if ($config -and $config.IPAddress) {
            ($config.IPAddress | Where-Object { $_ -notmatch '^fe80:' }) -join '<br>'
        }
        else {
            'n/a'
        }

        Write-Host ('| {0} | {1} | {2} | {3} |' -f `
                (Format-TableValue $adapter.Name),
                (Format-TableValue $adapter.MACAddress),
                (Format-Bytes $adapter.Speed),
                (Format-TableValue $ips))
    }
}
else {
    Write-Host '| n/a | n/a | n/a | n/a |'
}

Write-Host ''
Write-Host "## Top $TopProcesses Processes by Memory"
Write-Host ''
Write-Host '| Process | PID | Working set | CPU time |'
Write-Host '| --- | ---: | ---: | ---: |'

$processes = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First $TopProcesses

foreach ($process in $processes) {
    $cpuTime = if ($null -ne $process.CPU) { ('{0:N1}s' -f $process.CPU) } else { 'n/a' }
    Write-Host ('| {0} | {1} | {2} | {3} |' -f `
            (Format-TableValue $process.ProcessName),
            $process.Id,
            (Format-Bytes $process.WorkingSet64),
            $cpuTime)
}

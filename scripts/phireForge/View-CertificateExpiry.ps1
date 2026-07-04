using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Certificate Expiry
.DESCRIPTION
    Show local certificates that are expired or expiring soon, rendered as Markdown
.PARAMETER Days
    Number of days ahead to check for expiring certificates
.PARAMETER Scope
    Certificate store scope to search
.PARAMETER Store
    Certificate store to search
.PARAMETER IncludeExpired
    Include certificates that have already expired
.PARAMETER MaxCertificates
    Maximum number of certificates to display
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🔐')]
[ScriptTimeout(20000)]
[ScriptOutput('Markdown')]
param(
    [ValidateRange(1, 365)]
    [int]$Days = 30,

    [ValidateSet('CurrentUser', 'LocalMachine', 'All')]
    [string]$Scope = 'All',

    [ValidateSet('My', 'Root', 'CA', 'AuthRoot', 'TrustedPublisher', 'All')]
    [string]$Store = 'My',

    [bool]$IncludeExpired = $true,

    [ValidateRange(1, 200)]
    [int]$MaxCertificates = 50
)

function Format-TableValue {
    param($Value)

    if ($null -eq $Value) { return 'n/a' }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'n/a' }

    return ($text.Trim() -replace '\|', '\|' -replace "`r?`n", '<br>')
}

function Format-Subject {
    param($Certificate)

    if ($Certificate.FriendlyName) { return $Certificate.FriendlyName }
    if ($Certificate.DnsNameList -and $Certificate.DnsNameList.Count -gt 0) {
        return (($Certificate.DnsNameList | Select-Object -First 3) -join ', ')
    }
    if ($Certificate.Subject -match 'CN=([^,]+)') { return $Matches[1] }

    return $Certificate.Subject
}

function Get-CertificateStorePath {
    param(
        [string]$ScopeName,
        [string]$StoreName
    )

    if ($StoreName -eq 'All') {
        return "Cert:\$ScopeName"
    }

    return "Cert:\$ScopeName\$StoreName"
}

$now = Get-Date
$cutoff = $now.AddDays($Days)
$scopes = if ($Scope -eq 'All') { @('CurrentUser', 'LocalMachine') } else { @($Scope) }
$certificates = @()
$readErrors = @()

foreach ($scopeName in $scopes) {
    $path = Get-CertificateStorePath -ScopeName $scopeName -StoreName $Store

    try {
        $certificates += Get-ChildItem -Path $path -Recurse -ErrorAction Stop |
            Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] } |
            ForEach-Object {
                $daysRemaining = [math]::Floor(($_.NotAfter - $now).TotalDays)
                $status = if ($_.NotAfter -lt $now) { 'Expired' } else { 'Expiring' }

                [pscustomobject]@{
                    Scope         = $scopeName
                    Store         = $_.PSParentPath -replace '^.*::', ''
                    Subject       = Format-Subject $_
                    Issuer        = if ($_.Issuer -match 'CN=([^,]+)') { $Matches[1] } else { $_.Issuer }
                    Thumbprint    = $_.Thumbprint
                    NotAfter      = $_.NotAfter
                    DaysRemaining = $daysRemaining
                    Status        = $status
                }
            }
    }
    catch {
        $readErrors += ('{0}: {1}' -f $path, $_.Exception.Message)
    }
}

$matchingCertificates = $certificates |
    Where-Object {
        $_.NotAfter -le $cutoff -and ($IncludeExpired -or $_.NotAfter -ge $now)
    } |
    Sort-Object NotAfter |
    Select-Object -First $MaxCertificates

Write-Host '# 🔐 Certificate Expiry'
Write-Host ''
Write-Host "_Showing certificates expiring by $($cutoff.ToString('yyyy-MM-dd')) across scope '$Scope' and store '$Store'_"
Write-Host ''

if ($readErrors.Count -gt 0) {
    Write-Host '## Read Notes'
    Write-Host ''
    foreach ($readError in $readErrors) {
        Write-Host ("- {0}" -f (Format-TableValue $readError))
    }
    Write-Host ''
}

Write-Host '## Certificates'
Write-Host ''
Write-Host '| Status | Expires | Days | Scope | Store | Subject | Issuer | Thumbprint |'
Write-Host '| --- | --- | ---: | --- | --- | --- | --- | --- |'

if ($matchingCertificates.Count -eq 0) {
    Write-Host '| n/a | n/a | n/a | n/a | n/a | No matching certificates found. | n/a | n/a |'
}
else {
    foreach ($certificate in $matchingCertificates) {
        Write-Host ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | `{7}` |' -f `
                (Format-TableValue $certificate.Status),
                (Format-TableValue $certificate.NotAfter.ToString('yyyy-MM-dd')),
                (Format-TableValue $certificate.DaysRemaining),
                (Format-TableValue $certificate.Scope),
                (Format-TableValue $certificate.Store),
                (Format-TableValue $certificate.Subject),
                (Format-TableValue $certificate.Issuer),
                (Format-TableValue $certificate.Thumbprint))
    }
}

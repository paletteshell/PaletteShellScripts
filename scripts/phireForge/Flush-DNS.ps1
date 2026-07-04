using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Flush DNS Cache
.DESCRIPTION
    Clear the Windows DNS resolver cache so the next lookups hit DNS fresh
#>
[ScriptGroup('Utilities')]
[ScriptVersion('1.0.0')]
[ScriptIcon('🧹')]
[ScriptTimeout(10000)]
[ScriptOutput('Toast')]
[RequiresElevation()]
param()

# Prefer the DnsClient cmdlet when available; fall back to ipconfig /flushdns.
if (Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) {
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Host 'DNS resolver cache flushed.'
        return
    }
    catch {
        # Fall through to ipconfig if the cmdlet is blocked for any reason.
    }
}

$output = ipconfig /flushdns 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host 'DNS resolver cache flushed.'
}
else {
    Write-Host "Failed to flush DNS cache: $($output -join ' ')"
}

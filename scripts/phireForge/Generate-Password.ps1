using module .\PaletteScriptAttributes.psm1

<#
.SYNOPSIS
    Generate Password
.DESCRIPTION
    Generate a random password from a form of options and copy it to the clipboard
.PARAMETER Length
    How many characters the password should be
.PARAMETER Uppercase
    Include uppercase letters (A-Z)
.PARAMETER Lowercase
    Include lowercase letters (a-z)
.PARAMETER Digits
    Include digits (0-9)
.PARAMETER Symbols
    Include symbols (!@#$...)
.PARAMETER ExcludeAmbiguous
    Exclude easily-confused characters (O, 0, l, 1, I)
.EXAMPLE
    .\Password-Generator.ps1 -Length 20 -Symbols:$true
    Generate a 20-character password that includes symbols
#>
[ScriptHost('pwsh')]
[ScriptGroup('Utilities')]
[ScriptIcon('🔑')]
[ScriptTimeout(5000)]
[ScriptOutput('Clipboard')]
[CmdletBinding()]
param(
    # Password length
    [Parameter(HelpMessage = 'Number of characters')]
    [ValidateRange(4, 128)]
    [int]$Length = 16,

    # Include uppercase letters
    [Parameter()]
    [bool]$Uppercase = $true,

    # Include lowercase letters
    [Parameter()]
    [bool]$Lowercase = $true,

    # Include digits
    [Parameter()]
    [bool]$Digits = $true,

    # Include symbols
    [Parameter()]
    [bool]$Symbols = $true,

    # Exclude easily-confused characters (O, 0, l, 1, I)
    [Parameter()]
    [bool]$ExcludeAmbiguous = $false
)

$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$lower = 'abcdefghijklmnopqrstuvwxyz'
$nums  = '0123456789'
$syms  = '!@#$%^&*()-_=+[]{};:,.?'

# Build the pool of enabled character sets. Each set is kept separately so we can
# guarantee at least one character from every selected set.
$sets = @()
if ($Uppercase) { $sets += $upper }
if ($Lowercase) { $sets += $lower }
if ($Digits)    { $sets += $nums }
if ($Symbols)   { $sets += $syms }

if ($sets.Count -eq 0) {
    Write-Error 'Select at least one character type.'
    return
}

if ($ExcludeAmbiguous) {
    $ambiguous = 'O0l1I'.ToCharArray()
    $sets = $sets | ForEach-Object {
        -join ($_.ToCharArray() | Where-Object { $_ -notin $ambiguous })
    } | Where-Object { $_.Length -gt 0 }
}

# Cryptographically secure random index into a character set.
function Get-RandomChar {
    param([string]$Set)
    $idx = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($Set.Length)
    return $Set[$idx]
}

# Guarantee one char from each selected set, then fill the rest from the combined pool.
$all = -join $sets
$chars = New-Object System.Collections.Generic.List[char]

foreach ($set in $sets) {
    $chars.Add((Get-RandomChar -Set $set))
}
while ($chars.Count -lt $Length) {
    $chars.Add((Get-RandomChar -Set $all))
}

# Fisher-Yates shuffle so the guaranteed characters aren't stuck at the front.
for ($i = $chars.Count - 1; $i -gt 0; $i--) {
    $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($i + 1)
    $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
}

# If Length was shorter than the number of selected sets, trim to the requested length.
$password = (-join $chars).Substring(0, $Length)

Write-Output $password

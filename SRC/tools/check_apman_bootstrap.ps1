param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$BinPath,
    [Parameter(Mandatory = $true)][string]$S19Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "APMAN bootstrap check: $Message"
}

foreach ($path in @($PackagePath, $BinPath, $S19Path)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "missing file: $path"
    }
}

[byte[]]$package = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PackagePath))
[byte[]]$sector = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $BinPath))
if ($sector.Length -ne 0x1000) {
    Fail ('dense sector length is ${0:X4}, expected $1000' -f $sector.Length)
}
if ($package.Length -lt 5 -or $package.Length -gt $sector.Length) {
    Fail ('package length ${0:X4} is invalid' -f $package.Length)
}
for ($i = 0; $i -lt $package.Length; $i++) {
    if ($sector[$i] -ne $package[$i]) {
        Fail ('BIN differs from package at offset ${0:X4}' -f $i)
    }
}
for ($i = $package.Length; $i -lt $sector.Length; $i++) {
    if ($sector[$i] -ne 0xFF) {
        Fail ('BIN erased tail is programmed at offset ${0:X4}' -f $i)
    }
}

[byte[]]$fromS19 = New-Object byte[] 0x1000
[bool[]]$present = New-Object bool[] 0x1000
$s9 = -1
foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $S19Path))) {
    $line = $raw.Trim()
    if ($line.Length -eq 0) { continue }
    if ($line.Length -lt 10 -or $line[0] -ne 'S') { Fail "malformed record: $line" }
    $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
    if ($line.Length -ne (4 + (2 * $count))) { Fail "record count mismatch: $line" }
    $sum = $count
    for ($i = 0; $i -lt $count; $i++) {
        $sum += [Convert]::ToInt32($line.Substring(4 + (2 * $i), 2), 16)
    }
    if (($sum -band 0xFF) -ne 0xFF) { Fail "checksum mismatch: $line" }

    if ($line[1] -eq '1') {
        $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
        $dataLength = $count - 3
        for ($i = 0; $i -lt $dataLength; $i++) {
            $at = $address + $i
            if ($at -lt 0x8000 -or $at -gt 0x8FFF) {
                Fail ('S1 address ${0:X4} is outside $8000-$8FFF' -f $at)
            }
            $offset = $at - 0x8000
            if ($present[$offset]) { Fail ('duplicate S1 address ${0:X4}' -f $at) }
            $fromS19[$offset] = [Convert]::ToByte($line.Substring(8 + (2 * $i), 2), 16)
            $present[$offset] = $true
        }
    } elseif ($line[1] -eq '9') {
        if ($s9 -ne -1) { Fail 'multiple S9 records' }
        if ($count -ne 3) { Fail 'S9 is not a 16-bit start record' }
        $s9 = [Convert]::ToInt32($line.Substring(4, 4), 16)
    } else {
        Fail "unexpected record type S$($line[1])"
    }
}

if ($s9 -ne 0x8000) { Fail ('S9 start is ${0:X4}, expected $8000' -f $s9) }
for ($i = 0; $i -lt 0x1000; $i++) {
    if (-not $present[$i]) { Fail ('missing S1 address ${0:X4}' -f (0x8000 + $i)) }
    if ($fromS19[$i] -ne $sector[$i]) {
        Fail ('S19 differs from BIN at address ${0:X4}' -f (0x8000 + $i))
    }
}

Write-Host ('APMAN bootstrap OK: package=${0:X4}; dense BIN/S19=$8000-$8FFF; S9=$8000' -f $package.Length)

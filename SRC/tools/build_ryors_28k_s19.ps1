param(
    [string]$AsmS19Path = "BUILD/s19/asm-v1-flash-8000.s19",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$S19Path = "BUILD/s19/ryors-v1.2-himon-asm-bank3-8-e.s19",
    [int]$RangeStart = 0x8000,
    [int]$RangeEnd = 0xEFFF,
    [int]$StartAddress = 0xC000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) { throw "R-YORS flash S19 build: $Message" }

$memory = [byte[]]::new(0x10000)
$present = [bool[]]::new(0x10000)
for ($address = $RangeStart; $address -le $RangeEnd; $address++) { $memory[$address] = 0xFF }

function Import-S19([string]$Path, [int]$AllowedStart, [int]$AllowedEnd, [string]$Role) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "$Role input is missing: $Path" }
    $loaded = 0
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $line = $raw.Trim()
        if ($line.Length -lt 4 -or $line[0] -ne 'S') { continue }
        $addressBytes = switch ($line[1]) { '1' { 2 } '2' { 3 } '3' { 4 } default { 0 } }
        if ($addressBytes -eq 0) { continue }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        $expectedChars = 4 + ($count * 2)
        if ($line.Length -ne $expectedChars) { Fail "$Role malformed record length: $line" }
        $sum = $count
        for ($i = 0; $i -lt $count; $i++) { $sum += [Convert]::ToInt32($line.Substring(4 + ($i * 2), 2), 16) }
        if (($sum -band 0xFF) -ne 0xFF) { Fail "$Role checksum failure: $line" }
        $address = [Convert]::ToInt32($line.Substring(4, $addressBytes * 2), 16)
        $dataBytes = $count - $addressBytes - 1
        for ($i = 0; $i -lt $dataBytes; $i++) {
            $target = $address + $i
            if ($target -lt $AllowedStart -or $target -gt $AllowedEnd) {
                Fail ('{0} byte ${1:X4} is outside ${2:X4}-${3:X4}' -f $Role, $target, $AllowedStart, $AllowedEnd)
            }
            if ($present[$target]) { Fail ('duplicate input byte at ${0:X4}' -f $target) }
            $memory[$target] = [Convert]::ToByte($line.Substring(4 + ($addressBytes * 2) + ($i * 2), 2), 16)
            $present[$target] = $true
            $loaded++
        }
    }
    if ($loaded -eq 0) { Fail "$Role input contains no data" }
}

Import-S19 $AsmS19Path 0x8000 0xBFFF 'ASM'
Import-S19 $HimonS19Path 0xC000 0xEFFF 'HIMON'

if ($RangeStart -lt 0x8000 -or $RangeEnd -gt 0xEFFF -or $RangeEnd -lt $RangeStart) {
    Fail ('requested range ${0:X4}-${1:X4} is outside R-YORS $8000-$EFFF' -f $RangeStart, $RangeEnd)
}
if ($StartAddress -lt $RangeStart -or $StartAddress -gt $RangeEnd) {
    Fail ('S9 start ${0:X4} is outside output range' -f $StartAddress)
}
if (-not $present[0x8000] -or -not $present[0xC000]) { Fail 'ASM or HIMON entry byte is absent' }

$lines = [Collections.Generic.List[string]]::new()
for ($address = $RangeStart; $address -le $RangeEnd; $address += 32) {
    $length = [Math]::Min(32, $RangeEnd - $address + 1)
    $count = $length + 3
    $sum = $count + (($address -shr 8) -band 0xFF) + ($address -band 0xFF)
    $data = [Text.StringBuilder]::new()
    for ($i = 0; $i -lt $length; $i++) {
        $value = $memory[$address + $i]
        $sum += $value
        $null = $data.Append(('{0:X2}' -f $value))
    }
    $checksum = ($sum -bxor 0xFF) -band 0xFF
    $lines.Add(('S1{0:X2}{1:X4}{2}{3:X2}' -f $count, $address, $data.ToString(), $checksum))
}
$s9Sum = 3 + (($StartAddress -shr 8) -band 0xFF) + ($StartAddress -band 0xFF)
$lines.Add(('S903{0:X4}{1:X2}' -f $StartAddress, (($s9Sum -bxor 0xFF) -band 0xFF)))

$parent = Split-Path -Parent $S19Path
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
[IO.File]::WriteAllLines($S19Path, $lines, [Text.Encoding]::ASCII)
Write-Host ('R-YORS FLASH S19 = {0}' -f $S19Path)
Write-Host ('RANGE/S9         = ${0:X4}-${1:X4} / ${2:X4}' -f $RangeStart, $RangeEnd, $StartAddress)
Write-Host ('BYTES/RECORDS    = {0} / {1}' -f ($RangeEnd - $RangeStart + 1), $lines.Count)

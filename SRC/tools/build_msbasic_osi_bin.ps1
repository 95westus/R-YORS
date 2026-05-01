param(
    [string]$MapPath = "BUILD/s19/msbasic-osi.map",
    [string]$S19Path = "BUILD/s19/msbasic-osi.s19",
    [string]$BinPath = "BUILD/bin/msbasic-osi-fnv-b000-8k.bin",
    [int]$BaseAddress = 0xB000,
    [int]$SlotSize = 0x2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MapPath)) {
    $altMapPath = $MapPath.Replace("\s19\", "\map\").Replace("/s19/", "/map/")
    if (Test-Path -LiteralPath $altMapPath) {
        $MapPath = $altMapPath
    } else {
        throw "Map file not found: $MapPath"
    }
}
if (-not (Test-Path -LiteralPath $S19Path)) {
    throw "S19 file not found: $S19Path"
}

function Get-SymbolAddress {
    param([Parameter(Mandatory = $true)][string]$Name)

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([Regex]::Escape($Name))$"
    $line = Select-String -Path $MapPath -Pattern $pattern | Select-Object -First 1
    if (-not $line) {
        throw "Missing symbol '$Name' in $MapPath"
    }
    return [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
}

$fnv = Get-SymbolAddress -Name "MSBASIC_FNV"
$entry = Get-SymbolAddress -Name "MSBASIC_ENTRY"
$cold = Get-SymbolAddress -Name "COLD_START"
$end = Get-SymbolAddress -Name "_END_CODE"
$slotEnd = $BaseAddress + $SlotSize
$used = $end - $BaseAddress

if ($fnv -ne $BaseAddress) {
    throw ("MSBASIC_FNV is {0:X4}; expected {1:X4}" -f $fnv, $BaseAddress)
}
if ($entry -ne ($BaseAddress + 8)) {
    throw ("MSBASIC_ENTRY is {0:X4}; expected {1:X4}" -f $entry, ($BaseAddress + 8))
}
if ($end -gt $slotEnd) {
    throw ("MS BASIC image is {0} bytes and crosses {1:X4}; refusing to build 8K BIN" -f $used, $slotEnd)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinPath) | Out-Null

$srecCat = (Get-Command srec_cat -ErrorAction Stop).Source
$baseArg = "0x{0:X}" -f $BaseAddress
$slotEndArg = "0x{0:X}" -f $slotEnd
$offsetArg = "-0x{0:X}" -f $BaseAddress
& $srecCat $S19Path -motorola `
    -crop $baseArg $slotEndArg `
    -fill 0xFF $baseArg $slotEndArg `
    -offset $offsetArg `
    -o $BinPath -binary

if ($LASTEXITCODE -ne 0) {
    throw "srec_cat failed with exit code $LASTEXITCODE"
}

$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -ne $SlotSize) {
    throw "Unexpected BIN size $($bin.Length); expected $SlotSize bytes"
}

$head = $bin[0..15] | ForEach-Object { "{0:X2}" -f $_ }
Write-Host ("Symbols FNV/ENTRY/COLD/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $fnv, $entry, $cold, $end)
Write-Host ("Used/Padded/File bytes     = {0}/{1}/{2}" -f $used, ($SlotSize - $used), $bin.Length)
Write-Host ("Head bytes                 = {0}" -f ($head -join " "))
Write-Host ("BIN                        = {0}" -f $BinPath)

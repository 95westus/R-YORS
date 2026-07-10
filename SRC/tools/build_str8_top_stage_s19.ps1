param(
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin",
    [string]$S19Path = "BUILD/s19/str8-top-stage-0a00.s19",
    [int]$SourceOffset = 0x7000,
    [int]$StageAddress = 0x0A00,
    [int]$Length = 0x1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-SignedHex {
    param([Parameter(Mandatory = $true)][int]$Value)

    if ($Value -lt 0) {
        return ("-0x{0:X}" -f (-$Value))
    }
    return ("0x{0:X}" -f $Value)
}

function Read-HexByte {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$Offset
    )

    return [Convert]::ToByte($Text.Substring($Offset, 2), 16)
}

function New-S9Record {
    param([Parameter(Mandatory = $true)][int]$Address)

    $sum = 3 + (($Address -shr 8) -band 0xFF) + ($Address -band 0xFF)
    $chk = ($sum -bxor 0xFF) -band 0xFF
    return ("S903{0:X4}{1:X2}" -f $Address, $chk)
}

function Format-Bytes {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    return (($Bytes | ForEach-Object { "{0:X2}" -f $_ }) -join " ")
}

if (-not (Test-Path -LiteralPath $BinPath)) {
    throw "BIN file not found: $BinPath"
}
if ($SourceOffset -lt 0 -or $StageAddress -lt 0 -or $Length -le 0) {
    throw "SourceOffset, StageAddress, and Length must describe positive ranges"
}
if (($StageAddress + $Length) -gt 0x10000) {
    throw ("Stage range {0:X4}-{1:X4} crosses S1 address space" -f $StageAddress, ($StageAddress + $Length - 1))
}

[byte[]]$bin = [System.IO.File]::ReadAllBytes($BinPath)
if (($SourceOffset + $Length) -gt $bin.Length) {
    throw ("Source range offset {0:X}-{1:X} crosses BIN length {2:X}" -f $SourceOffset, ($SourceOffset + $Length - 1), $bin.Length)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $S19Path) | Out-Null

$srecCat = (Get-Command srec_cat -ErrorAction Stop).Source
$tmpPath = Join-Path (Split-Path -Parent $S19Path) (".tmp-str8-top-stage-{0}.s19" -f [guid]::NewGuid().ToString("N"))
$offsetArg = Format-SignedHex -Value ($StageAddress - $SourceOffset)

try {
    & $srecCat $BinPath -binary `
        -crop ("0x{0:X}" -f $SourceOffset) ("0x{0:X}" -f ($SourceOffset + $Length)) `
        -offset $offsetArg `
        -address-length=2 `
        -o $tmpPath -motorola
    if ($LASTEXITCODE -ne 0) {
        throw "srec_cat failed with exit code $LASTEXITCODE"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $seen = New-Object bool[] $Length
    $dataBytes = 0

    foreach ($rawLine in Get-Content -Path $tmpPath) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if (-not $line.StartsWith("S1", [System.StringComparison]::Ordinal)) {
            continue
        }

        $count = Read-HexByte -Text $line -Offset 2
        $addr = ([int](Read-HexByte -Text $line -Offset 4) -shl 8) -bor [int](Read-HexByte -Text $line -Offset 6)
        $recordDataBytes = $count - 3
        if ($recordDataBytes -le 0) {
            throw "Bad S1 record with no data: $line"
        }
        if (($addr -lt $StageAddress) -or (($addr + $recordDataBytes) -gt ($StageAddress + $Length))) {
            throw ("S1 record outside stage range {0:X4}-{1:X4}: {2}" -f $StageAddress, ($StageAddress + $Length - 1), $line)
        }
        for ($i = 0; $i -lt $recordDataBytes; $i++) {
            $seenIndex = ($addr + $i) - $StageAddress
            if ($seen[$seenIndex]) {
                throw ("Duplicate staged byte at {0:X4}" -f ($addr + $i))
            }
            $seen[$seenIndex] = $true
        }
        $dataBytes += $recordDataBytes
        $lines.Add($line)
    }

    if ($dataBytes -ne $Length) {
        throw ("Staged S19 has {0} data bytes; expected {1}" -f $dataBytes, $Length)
    }
    for ($i = 0; $i -lt $Length; $i++) {
        if (-not $seen[$i]) {
            throw ("Staged S19 missing byte at {0:X4}" -f ($StageAddress + $i))
        }
    }

    $lines.Add((New-S9Record -Address $StageAddress))
    [System.IO.File]::WriteAllLines($S19Path, $lines, [System.Text.Encoding]::ASCII)
} finally {
    if (Test-Path -LiteralPath $tmpPath) {
        Remove-Item -LiteralPath $tmpPath -Force
    }
}

$sourceEnd = $SourceOffset + $Length - 1
$stageEnd = $StageAddress + $Length - 1
$head = $bin[$SourceOffset..($SourceOffset + [Math]::Min(8, $Length - 1))]
$tail = $bin[($SourceOffset + $Length - 6)..($SourceOffset + $Length - 1)]

Write-Host ("BIN source           = {0}" -f $BinPath)
Write-Host ("Stage S19            = {0}" -f $S19Path)
Write-Host ("BIN offset range      = {0:X4}-{1:X4}" -f $SourceOffset, $sourceEnd)
Write-Host ("Stage address range   = {0:X4}-{1:X4}" -f $StageAddress, $stageEnd)
Write-Host ("S9 start              = {0:X4}" -f $StageAddress)
Write-Host ("S1 data bytes         = {0}" -f $Length)
Write-Host ("Stage head            = {0}" -f (Format-Bytes -Bytes $head))
Write-Host ("Stage vectors         = {0}" -f (Format-Bytes -Bytes $tail))

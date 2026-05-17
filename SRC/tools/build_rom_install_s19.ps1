param(
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin",
    [string]$S19Path = "BUILD/s19/himon-str8-rom-install.s19",
    [int]$BaseAddress = 0x8000,
    [int]$StartAddress = -1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BinPath)) {
    throw "BIN file not found: $BinPath"
}

[byte[]]$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -eq 0) {
    throw "BIN file is empty: $BinPath"
}
if ($BaseAddress -lt 0 -or $BaseAddress -gt 0xFFFF) {
    throw ("Base address {0:X} is outside S1 address range" -f $BaseAddress)
}
$endExclusive = $BaseAddress + $bin.Length
if ($endExclusive -gt 0x10000) {
    throw ("BIN length {0} at base {1:X4} crosses S1 address range" -f $bin.Length, $BaseAddress)
}

if ($StartAddress -lt 0) {
    $resetVector = 0xFFFC
    if ($BaseAddress -le $resetVector -and $endExclusive -gt ($resetVector + 1)) {
        $vecOffset = $resetVector - $BaseAddress
        $StartAddress = [int]$bin[$vecOffset] -bor ([int]$bin[$vecOffset + 1] -shl 8)
    } else {
        $StartAddress = $BaseAddress
    }
}
if ($StartAddress -lt 0 -or $StartAddress -gt 0xFFFF) {
    throw ("Start address {0:X} is outside S1/S9 address range" -f $StartAddress)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $S19Path) | Out-Null

$srecCat = (Get-Command srec_cat -ErrorAction Stop).Source
$tmpPath = Join-Path (Split-Path -Parent $S19Path) (".tmp-rom-install-{0}.s19" -f [guid]::NewGuid().ToString("N"))

try {
    $baseArg = "0x{0:X}" -f $BaseAddress
    & $srecCat $BinPath -binary -offset $baseArg -address-length=2 -o $tmpPath -motorola
    if ($LASTEXITCODE -ne 0) {
        throw "srec_cat failed with exit code $LASTEXITCODE"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($rawLine in Get-Content -Path $tmpPath) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if ($line.StartsWith("S1", [System.StringComparison]::Ordinal)) {
            $lines.Add($line)
            continue
        }
        if ($line.StartsWith("S0", [System.StringComparison]::Ordinal) -or
            $line.StartsWith("S5", [System.StringComparison]::Ordinal) -or
            $line.StartsWith("S9", [System.StringComparison]::Ordinal)) {
            continue
        }
        throw "Unsupported S-record emitted by srec_cat for HIMON/STR8 install stream: $line"
    }

    if ($lines.Count -eq 0) {
        throw "No S1 data records were produced from $BinPath"
    }

    $sum = 3 + (($StartAddress -shr 8) -band 0xFF) + ($StartAddress -band 0xFF)
    $chk = ($sum -bxor 0xFF) -band 0xFF
    $lines.Add(("S903{0:X4}{1:X2}" -f $StartAddress, $chk))

    [System.IO.File]::WriteAllLines($S19Path, $lines, [System.Text.Encoding]::ASCII)
} finally {
    if (Test-Path -LiteralPath $tmpPath) {
        Remove-Item -LiteralPath $tmpPath -Force
    }
}

$rangeEnd = $endExclusive - 1
$recordTypes = @(Select-String -Path $S19Path -Pattern '^S[0-9]' | ForEach-Object { $_.Line.Substring(0, 2) } | Sort-Object -Unique)
$tail = ''
if ($BaseAddress -le 0xFFFA -and $endExclusive -gt 0xFFFF) {
    $tailOffset = 0xFFFA - $BaseAddress
    $tail = ($bin[$tailOffset..($tailOffset + 5)] | ForEach-Object { "{0:X2}" -f $_ }) -join " "
}

Write-Host ("BIN                  = {0}" -f $BinPath)
Write-Host ("Install S19          = {0}" -f $S19Path)
Write-Host ("Address range        = {0:X4}-{1:X4}" -f $BaseAddress, $rangeEnd)
Write-Host ("S9 start             = {0:X4}" -f $StartAddress)
Write-Host ("Record types         = {0}" -f ($recordTypes -join " "))
if (-not [string]::IsNullOrWhiteSpace($tail)) {
    Write-Host ("Vectors FFFA-FFFF    = {0}" -f $tail)
}

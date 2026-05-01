param(
    [string]$MapPath = "BUILD/map/himon-rom.map",
    [string]$S19Path = "BUILD/s19/himon-rom.s19",
    [string]$BinPath = "BUILD/bin/himon-rom.bin",
    [string]$TmpVecPath = "BUILD/tmp/himon-rom-vectors.bin",
    [string]$NmiSymbol = "SYS_VEC_ENTRY_NMI",
    [string]$ResetSymbol = "START",
    [string]$IrqSymbol = "SYS_VEC_ENTRY_IRQ_MASTER"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MapPath)) {
    throw "Map file not found: $MapPath"
}
if (-not (Test-Path -LiteralPath $S19Path)) {
    throw "S19 file not found: $S19Path"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TmpVecPath) | Out-Null

function Get-SymbolAddress {
    param([Parameter(Mandatory = $true)][string]$Name)

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([Regex]::Escape($Name))$"
    $line = Select-String -Path $MapPath -Pattern $pattern | Select-Object -First 1
    if (-not $line) {
        throw "Missing symbol '$Name' in $MapPath"
    }
    return [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
}

$nmi = Get-SymbolAddress -Name $NmiSymbol
$reset = Get-SymbolAddress -Name $ResetSymbol
$irq = Get-SymbolAddress -Name $IrqSymbol

[byte[]]$vectors = @(
    [byte]($nmi -band 0xFF), [byte](($nmi -shr 8) -band 0xFF),
    [byte]($reset -band 0xFF), [byte](($reset -shr 8) -band 0xFF),
    [byte]($irq -band 0xFF), [byte](($irq -shr 8) -band 0xFF)
)
[System.IO.File]::WriteAllBytes($TmpVecPath, $vectors)

$srecCat = (Get-Command srec_cat -ErrorAction Stop).Source
& $srecCat $S19Path -motorola `
    -crop 0x8000 0x10000 `
    -fill 0xFF 0x8000 0xFFFA `
    -offset -0x8000 `
    $TmpVecPath -binary -offset 0x7FFA `
    -o $BinPath -binary

if ($LASTEXITCODE -ne 0) {
    throw "srec_cat failed with exit code $LASTEXITCODE"
}

$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -ne 32768) {
    throw "Unexpected BIN size $($bin.Length); expected 32768 bytes for 8000-FFFF"
}

$tail = $bin[32762..32767] | ForEach-Object { "{0:X2}" -f $_ }
Write-Host ("Symbols NMI/RESET/IRQ = {0}/{1}/{2}" -f $NmiSymbol, $ResetSymbol, $IrqSymbol)
Write-Host ("Vectors NMI/RESET/IRQ = {0:X4}/{1:X4}/{2:X4}" -f $nmi, $reset, $irq)
Write-Host ("Tail FFFA-FFFF       = {0}" -f ($tail -join " "))
Write-Host ("BIN                 = {0}" -f $BinPath)

# Cleanup helper vector blob after successful BIN generation/validation.
if (Test-Path -LiteralPath $TmpVecPath) {
    Remove-Item -LiteralPath $TmpVecPath -Force
}

param(
    [string]$MapPath = "BUILD/map/himon-rom-c000.map",
    [string]$S19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$BinPath = "BUILD/bin/himon-rom-c000.bin",
    [string]$TmpVecPath = "BUILD/tmp/himon-rom-c000-vectors.bin",
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

function Read-HexByte {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$Offset
    )

    return [Convert]::ToByte($Text.Substring($Offset, 2), 16)
}

function Import-S19IntoImage {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Image,
        [Parameter(Mandatory = $true)][int]$BankOffset
    )

    foreach ($rawLine in Get-Content -Path $Path) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if (-not $line.StartsWith("S")) {
            throw "Bad S-record in ${Path}: $line"
        }

        $type = $line.Substring(1, 1)
        if ($type -notin @("1", "2", "3")) {
            continue
        }

        $count = Read-HexByte -Text $line -Offset 2
        $addrBytes = @{ "1" = 2; "2" = 3; "3" = 4 }[$type]
        $expectedChars = 4 + ($count * 2)
        if ($line.Length -lt $expectedChars) {
            throw "Short S-record in ${Path}: $line"
        }

        $sum = $count
        $addr = 0
        $pos = 4
        for ($i = 0; $i -lt $addrBytes; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $addr = (($addr -shl 8) -bor $b)
            $pos += 2
        }

        $dataCount = $count - $addrBytes - 1
        for ($i = 0; $i -lt $dataCount; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $absolute = $addr + $i
            if ($absolute -ge 0x8000 -and $absolute -lt 0x10000) {
                $offset = $BankOffset + ($absolute - 0x8000)
                if ($Image[$offset] -ne 0xFF -and $Image[$offset] -ne $b) {
                    throw ("Conflicting bytes at {0:X4}: existing {1:X2}, new {2:X2} from {3}" -f $absolute, $Image[$offset], $b, $Path)
                }
                $Image[$offset] = $b
            }
            $pos += 2
        }

        $checksum = Read-HexByte -Text $line -Offset $pos
        $sum += $checksum
        if (($sum -band 0xFF) -ne 0xFF) {
            throw "Checksum failure in ${Path}: $line"
        }
    }
}

[byte[]]$vectors = @(
    [byte]($nmi -band 0xFF), [byte](($nmi -shr 8) -band 0xFF),
    [byte]($reset -band 0xFF), [byte](($reset -shr 8) -band 0xFF),
    [byte]($irq -band 0xFF), [byte](($irq -shr 8) -band 0xFF)
)
[System.IO.File]::WriteAllBytes($TmpVecPath, $vectors)

$imageSize = 32768
$bankOffset = 0
$label = "32K ROM bank image"

[byte[]]$bin = New-Object byte[] $imageSize
for ($i = 0; $i -lt $bin.Length; $i++) {
    $bin[$i] = 0xFF
}

Import-S19IntoImage -Path $S19Path -Image $bin -BankOffset $bankOffset
for ($i = 0; $i -lt $vectors.Length; $i++) {
    $bin[$bankOffset + 0x7FFA + $i] = $vectors[$i]
}

[System.IO.File]::WriteAllBytes($BinPath, $bin)

$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -ne $imageSize) {
    throw "Unexpected BIN size $($bin.Length); expected $imageSize bytes for $label"
}

$head = $bin[$bankOffset..($bankOffset + 15)] | ForEach-Object { "{0:X2}" -f $_ }
$resetHeadOffset = $bankOffset + ($reset - 0x8000)
$resetHead = $bin[$resetHeadOffset..($resetHeadOffset + 15)] | ForEach-Object { "{0:X2}" -f $_ }
$tail = $bin[($bankOffset + 0x7FFA)..($bankOffset + 0x7FFF)] | ForEach-Object { "{0:X2}" -f $_ }
Write-Host ("Symbols NMI/RESET/IRQ = {0}/{1}/{2}" -f $NmiSymbol, $ResetSymbol, $IrqSymbol)
Write-Host ("Vectors NMI/RESET/IRQ = {0:X4}/{1:X4}/{2:X4}" -f $nmi, $reset, $irq)
Write-Host ("Image layout          = {0}" -f $label)
Write-Host ("Bank offset           = 0x{0:X5}" -f $bankOffset)
Write-Host ("Bank head @ 8000      = {0}" -f ($head -join " "))
Write-Host ("Reset head @ {0:X4}   = {1}" -f $reset, ($resetHead -join " "))
Write-Host ("Tail FFFA-FFFF       = {0}" -f ($tail -join " "))
Write-Host ("BIN                 = {0}" -f $BinPath)

# Cleanup helper vector blob after successful BIN generation/validation.
if (Test-Path -LiteralPath $TmpVecPath) {
    Remove-Item -LiteralPath $TmpVecPath -Force
}

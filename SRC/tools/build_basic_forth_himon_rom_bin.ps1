param(
    [string]$MicrochessMapPath = "BUILD/map/microchess-a900.map",
    [string]$MicrochessS19Path = "BUILD/s19/microchess-a900.s19",
    [string]$ForthMapPath = "BUILD/map/fig-forth-9000.map",
    [string]$ForthS19Path = "BUILD/s19/fig-forth-9000.s19",
    [string]$MsbasicMapPath = "BUILD/s19/msbasic-osi.map",
    [string]$MsbasicS19Path = "BUILD/s19/msbasic-osi.s19",
    [string]$HimonMapPath = "BUILD/map/himon-rom.map",
    [string]$HimonS19Path = "BUILD/s19/himon-rom.s19",
    [string]$BinPath = "BUILD/bin/basic-forth-himon-rom.bin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return $Path
    }

    $alt = $Path.Replace("\s19\", "\map\").Replace("/s19/", "/map/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    $alt = $Path.Replace("\map\", "\s19\").Replace("/map/", "/s19/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    throw "Required file not found: $Path"
}

function Get-SymbolAddress {
    param(
        [Parameter(Mandatory = $true)][string]$MapPath,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([Regex]::Escape($Name))$"
    $line = Select-String -Path $MapPath -Pattern $pattern | Select-Object -First 1
    if (-not $line) {
        throw "Missing symbol '$Name' in $MapPath"
    }
    return [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
}

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
        [Parameter(Mandatory = $true)][byte[]]$Image
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
                $offset = $absolute - 0x8000
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

$MicrochessMapPath = Resolve-ArtifactPath -Path $MicrochessMapPath
$MicrochessS19Path = Resolve-ArtifactPath -Path $MicrochessS19Path
$ForthMapPath = Resolve-ArtifactPath -Path $ForthMapPath
$ForthS19Path = Resolve-ArtifactPath -Path $ForthS19Path
$MsbasicMapPath = Resolve-ArtifactPath -Path $MsbasicMapPath
$MsbasicS19Path = Resolve-ArtifactPath -Path $MsbasicS19Path
$HimonMapPath = Resolve-ArtifactPath -Path $HimonMapPath
$HimonS19Path = Resolve-ArtifactPath -Path $HimonS19Path

$microchessFnv = Get-SymbolAddress -MapPath $MicrochessMapPath -Name "MICROCHESS_FNV"
$microchessEntry = Get-SymbolAddress -MapPath $MicrochessMapPath -Name "START"
$microchessEnd = Get-SymbolAddress -MapPath $MicrochessMapPath -Name "_END_CODE"

$forthFnv = Get-SymbolAddress -MapPath $ForthMapPath -Name "FIG_FORTH_FNV"
$forthEntry = Get-SymbolAddress -MapPath $ForthMapPath -Name "START"
$forthEnd = Get-SymbolAddress -MapPath $ForthMapPath -Name "_END_CODE"

$basicFnv = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "MSBASIC_FNV"
$basicEntry = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "MSBASIC_ENTRY"
$basicCold = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "COLD_START"
$basicEnd = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "_END_CODE"

$monStart = Get-SymbolAddress -MapPath $HimonMapPath -Name "START"
$monNmi = Get-SymbolAddress -MapPath $HimonMapPath -Name "SYS_VEC_ENTRY_NMI"
$monIrq = Get-SymbolAddress -MapPath $HimonMapPath -Name "SYS_VEC_ENTRY_IRQ_MASTER"
$monEnd = Get-SymbolAddress -MapPath $HimonMapPath -Name "_END_CODE"

if ($microchessFnv -ne 0xA900) {
    throw ("MICROCHESS_FNV is {0:X4}; expected A900" -f $microchessFnv)
}
if ($microchessEntry -ne 0xA908) {
    throw ("MicroChess START is {0:X4}; expected A908" -f $microchessEntry)
}
if ($microchessEnd -gt 0xB000) {
    throw ("MicroChess crosses BASIC slot at B000; _END_CODE={0:X4}" -f $microchessEnd)
}
if ($forthFnv -ne 0x9000) {
    throw ("FIG_FORTH_FNV is {0:X4}; expected 9000" -f $forthFnv)
}
if ($forthEntry -ne 0x9008) {
    throw ("FORTH START is {0:X4}; expected 9008" -f $forthEntry)
}
if ($forthEnd -gt 0xB000) {
    throw ("FORTH crosses BASIC slot at B000; _END_CODE={0:X4}" -f $forthEnd)
}
if ($basicFnv -ne 0xB000) {
    throw ("MSBASIC_FNV is {0:X4}; expected B000" -f $basicFnv)
}
if ($basicEntry -ne 0xB008) {
    throw ("MSBASIC_ENTRY is {0:X4}; expected B008" -f $basicEntry)
}
if ($basicEnd -gt 0xD000) {
    throw ("MS BASIC crosses HIMON at D000; _END_CODE={0:X4}" -f $basicEnd)
}
if ($monStart -ne 0xD000) {
    throw ("HIMON START is {0:X4}; expected D000" -f $monStart)
}
if ($monEnd -gt 0xFFFA) {
    throw ("HIMON code crosses vector area; _END_CODE={0:X4}" -f $monEnd)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinPath) | Out-Null

[byte[]]$bin = New-Object byte[] 32768
for ($i = 0; $i -lt $bin.Length; $i++) {
    $bin[$i] = 0xFF
}

Import-S19IntoImage -Path $MicrochessS19Path -Image $bin
Import-S19IntoImage -Path $ForthS19Path -Image $bin
Import-S19IntoImage -Path $MsbasicS19Path -Image $bin
Import-S19IntoImage -Path $HimonS19Path -Image $bin

[byte[]]$vectors = @(
    [byte]($monNmi -band 0xFF), [byte](($monNmi -shr 8) -band 0xFF),
    [byte]($monStart -band 0xFF), [byte](($monStart -shr 8) -band 0xFF),
    [byte]($monIrq -band 0xFF), [byte](($monIrq -shr 8) -band 0xFF)
)
for ($i = 0; $i -lt $vectors.Length; $i++) {
    $bin[0x7FFA + $i] = $vectors[$i]
}

[System.IO.File]::WriteAllBytes($BinPath, $bin)

$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -ne 32768) {
    throw "Unexpected BIN size $($bin.Length); expected 32768 bytes for 8000-FFFF"
}

$bankHead = $bin[0x0000..0x000F] | ForEach-Object { "{0:X2}" -f $_ }
$forthHead = $bin[0x1000..0x100F] | ForEach-Object { "{0:X2}" -f $_ }
$chessHead = $bin[0x2900..0x290F] | ForEach-Object { "{0:X2}" -f $_ }
$basicHead = $bin[0x3000..0x300F] | ForEach-Object { "{0:X2}" -f $_ }
$monHead = $bin[0x5000..0x500F] | ForEach-Object { "{0:X2}" -f $_ }
$tail = $bin[32762..32767] | ForEach-Object { "{0:X2}" -f $_ }

Write-Host ("MICROCHESS FNV/ENTRY/END  = {0:X4}/{1:X4}/{2:X4}" -f $microchessFnv, $microchessEntry, $microchessEnd)
Write-Host ("FORTH FNV/ENTRY/END       = {0:X4}/{1:X4}/{2:X4}" -f $forthFnv, $forthEntry, $forthEnd)
Write-Host ("BASIC FNV/ENTRY/COLD/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $basicFnv, $basicEntry, $basicCold, $basicEnd)
Write-Host ("HIMON START/NMI/IRQ/END  = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $monStart, $monNmi, $monIrq, $monEnd)
Write-Host ("Bank start @ 8000         = {0}" -f ($bankHead -join " "))
Write-Host ("FORTH @ 9000              = {0}" -f ($forthHead -join " "))
Write-Host ("MICROCHESS @ A900         = {0}" -f ($chessHead -join " "))
Write-Host ("BASIC @ B000              = {0}" -f ($basicHead -join " "))
Write-Host ("HIMON @ D000              = {0}" -f ($monHead -join " "))
Write-Host ("Vectors FFFA-FFFF         = {0}" -f ($tail -join " "))
Write-Host ("BIN                       = {0}" -f $BinPath)

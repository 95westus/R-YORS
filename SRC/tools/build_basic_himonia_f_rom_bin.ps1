param(
    [string]$MsbasicMapPath = "BUILD/s19/msbasic-osi.map",
    [string]$MsbasicS19Path = "BUILD/s19/msbasic-osi.s19",
    [string]$HimoniaMapPath = "BUILD/map/himonia-f-rom.map",
    [string]$HimoniaS19Path = "BUILD/s19/himonia-f-rom.s19",
    [string]$BinPath = "BUILD/bin/basic-himonia-f.bin",
    [string]$TmpVecPath = "BUILD/tmp/basic-himonia-f-vectors.bin"
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

$MsbasicMapPath = Resolve-ArtifactPath -Path $MsbasicMapPath
$MsbasicS19Path = Resolve-ArtifactPath -Path $MsbasicS19Path
$HimoniaMapPath = Resolve-ArtifactPath -Path $HimoniaMapPath
$HimoniaS19Path = Resolve-ArtifactPath -Path $HimoniaS19Path

$basicFnv = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "MSBASIC_FNV"
$basicEntry = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "MSBASIC_ENTRY"
$basicCold = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "COLD_START"
$basicEnd = Get-SymbolAddress -MapPath $MsbasicMapPath -Name "_END_CODE"

$monStart = Get-SymbolAddress -MapPath $HimoniaMapPath -Name "START"
$monNmi = Get-SymbolAddress -MapPath $HimoniaMapPath -Name "SYS_VEC_ENTRY_NMI"
$monIrq = Get-SymbolAddress -MapPath $HimoniaMapPath -Name "SYS_VEC_ENTRY_IRQ_MASTER"
$monEnd = Get-SymbolAddress -MapPath $HimoniaMapPath -Name "_END_CODE"

if ($basicFnv -ne 0xB000) {
    throw ("MSBASIC_FNV is {0:X4}; expected B000" -f $basicFnv)
}
if ($basicEntry -ne 0xB008) {
    throw ("MSBASIC_ENTRY is {0:X4}; expected B008" -f $basicEntry)
}
if ($basicEnd -gt 0xD000) {
    throw ("MS BASIC crosses Himonia-F at D000; _END_CODE={0:X4}" -f $basicEnd)
}
if ($monStart -ne 0xD000) {
    throw ("Himonia-F START is {0:X4}; expected D000" -f $monStart)
}
if ($monEnd -gt 0xFFFA) {
    throw ("Himonia-F code crosses vector area; _END_CODE={0:X4}" -f $monEnd)
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

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinPath) | Out-Null

[byte[]]$bin = New-Object byte[] 32768
for ($i = 0; $i -lt $bin.Length; $i++) {
    $bin[$i] = 0xFF
}
$bin[0] = 0x00

Import-S19IntoImage -Path $MsbasicS19Path -Image $bin
Import-S19IntoImage -Path $HimoniaS19Path -Image $bin

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

$basicHead = $bin[0x3000..0x300F] | ForEach-Object { "{0:X2}" -f $_ }
$monHead = $bin[0x5000..0x500F] | ForEach-Object { "{0:X2}" -f $_ }
$bankHead = $bin[0..15] | ForEach-Object { "{0:X2}" -f $_ }
$tail = $bin[32762..32767] | ForEach-Object { "{0:X2}" -f $_ }

Write-Host ("BASIC FNV/ENTRY/COLD/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $basicFnv, $basicEntry, $basicCold, $basicEnd)
Write-Host ("Himonia START/NMI/IRQ/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $monStart, $monNmi, $monIrq, $monEnd)
Write-Host ("Bank start @ 8000          = {0}" -f ($bankHead -join " "))
Write-Host ("BASIC @ B000              = {0}" -f ($basicHead -join " "))
Write-Host ("Himonia-F @ D000          = {0}" -f ($monHead -join " "))
Write-Host ("Vectors FFFA-FFFF         = {0}" -f ($tail -join " "))
Write-Host ("BIN                       = {0}" -f $BinPath)

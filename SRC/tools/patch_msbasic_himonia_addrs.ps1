param(
    [string]$SourcePath = "../LOCAL/msbasic/generated/osi-basic.asm",
    [string]$MapPath = "BUILD/map/himonia-f-rom.map"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return $Path
    }

    $alt = $Path.Replace("\map\", "\s19\").Replace("/map/", "/s19/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    $alt = $Path.Replace("\s19\", "\map\").Replace("/s19/", "/map/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    throw "Required file not found: $Path"
}

function Get-SymbolAddress {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([Regex]::Escape($Name))$"
    $line = Select-String -Path $Path -Pattern $pattern | Select-Object -First 1
    if (-not $line) {
        throw "Missing symbol '$Name' in $Path"
    }
    $addr = [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
    return ("`${0:X4}" -f $addr)
}

function Set-Equate {
    param(
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $pattern = "^($([Regex]::Escape($Name))\s+EQU\s+)\$[0-9A-Fa-f]{4}(\s*(?:;.*)?)$"
    $count = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            $Lines[$i] = $Matches[1] + $Value + $Matches[2]
            $count++
        }
    }
    if ($count -ne 1) {
        throw "Expected one equate for $Name in $SourcePath; found $count"
    }
}

$SourcePath = Resolve-ArtifactPath -Path $SourcePath
$MapPath = Resolve-ArtifactPath -Path $MapPath

$readChar = Get-SymbolAddress -Path $MapPath -Name "HIMONIA_ABI_READ_BYTE"
$writeChar = Get-SymbolAddress -Path $MapPath -Name "HIMONIA_ABI_WRITE_BYTE"
$ctrlC = Get-SymbolAddress -Path $MapPath -Name "SYS_GET_CTRL_C"

[string[]]$lines = Get-Content -Path $SourcePath
Set-Equate -Lines $lines -Name "MSBASIC_GET_CHAR_ADDR" -Value $readChar
Set-Equate -Lines $lines -Name "MSBASIC_PUT_CHAR_ADDR" -Value $writeChar
Set-Equate -Lines $lines -Name "MSBASIC_GET_CTRL_C_ADDR" -Value $ctrlC
Set-Equate -Lines $lines -Name "MONRDKEY" -Value $readChar
Set-Equate -Lines $lines -Name "MONCOUT" -Value $writeChar
Set-Content -Path $SourcePath -Value $lines

Write-Host ("MSBASIC monitor ABI = READ {0}, WRITE {1}, CTRL-C {2}" -f $readChar, $writeChar, $ctrlC)

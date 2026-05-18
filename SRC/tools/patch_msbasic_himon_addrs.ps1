param(
    [string]$SourcePath = "../LOCAL/msbasic/generated/osi-basic.asm",
    [string]$MapPath = "BUILD/map/himon-rom.map",
    [ValidateSet("himon", "str8")]
    [string]$Profile = "himon"
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
        [Parameter(Mandatory = $true)][string]$Value,
        [switch]$Optional
    )

    $pattern = "^($([Regex]::Escape($Name))\s+EQU\s+)\$[0-9A-Fa-f]{4}(\s*(?:;.*)?)$"
    $count = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            $Lines[$i] = $Matches[1] + $Value + $Matches[2]
            $count++
        }
    }
    if ($Optional -and $count -eq 0) {
        return
    }
    if ($count -ne 1) {
        throw "Expected one equate for $Name in $SourcePath; found $count"
    }
}

$SourcePath = Resolve-ArtifactPath -Path $SourcePath
$MapPath = Resolve-ArtifactPath -Path $MapPath

if ($Profile -eq "str8") {
    $readChar = Get-SymbolAddress -Path $MapPath -Name "STR8_CON_READ_BYTE_BLOCK"
    $writeChar = Get-SymbolAddress -Path $MapPath -Name "STR8_CON_WRITE_BYTE_BLOCK"
    $ctrlC = '$0000'
} else {
    $readChar = Get-SymbolAddress -Path $MapPath -Name "BIO_FTDI_READ_BYTE_BLOCK"
    $writeChar = Get-SymbolAddress -Path $MapPath -Name "BIO_FTDI_WRITE_BYTE_BLOCK"
    $ctrlC = Get-SymbolAddress -Path $MapPath -Name "SYS_GET_CTRL_C"
}

[string[]]$lines = Get-Content -Path $SourcePath
Set-Equate -Lines $lines -Name "MSBASIC_GET_CHAR_ADDR" -Value $readChar
Set-Equate -Lines $lines -Name "MSBASIC_PUT_CHAR_ADDR" -Value $writeChar
Set-Equate -Lines $lines -Name "MSBASIC_GET_CTRL_C_ADDR" -Value $ctrlC -Optional
Set-Equate -Lines $lines -Name "MONRDKEY" -Value $readChar
Set-Equate -Lines $lines -Name "MONCOUT" -Value $writeChar
Set-Content -Path $SourcePath -Value $lines

Write-Host ("MSBASIC {0} calls = READ {1}, WRITE {2}, CTRL-C {3}" -f $Profile.ToUpperInvariant(), $readChar, $writeChar, $ctrlC)

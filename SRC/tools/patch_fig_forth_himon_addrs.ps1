param(
    [string]$SourcePath = "../LOCAL/fig-forth/generated/fig-forth.asm",
    [string]$MapPath = "BUILD/s19/himon-rom-c000.map"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-MapAddress {
    param(
        [string]$Path,
        [string]$Name
    )

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([regex]::Escape($Name))\s*$"
    $match = Select-String -Path $Path -Pattern $pattern | Select-Object -First 1
    if (-not $match) {
        throw "Symbol '$Name' not found in $Path"
    }

    $raw = $match.Matches[0].Groups[1].Value
    return '$' + $raw.Substring(4).ToUpperInvariant()
}

function Equ-Line {
    param(
        [string]$Name,
        [string]$Value
    )

    return ("{0,-26} EQU             {1}" -f $Name, $Value)
}

$readAddr = Get-MapAddress -Path $MapPath -Name "BIO_FTDI_READ_BYTE_BLOCK"
$writeAddr = Get-MapAddress -Path $MapPath -Name "BIO_FTDI_WRITE_BYTE_BLOCK"
$startAddr = Get-MapAddress -Path $MapPath -Name "START"

$lines = Get-Content -Path $SourcePath
$sawRead = $false
$sawWrite = $false
$sawStart = $false
$changed = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ($line -match "^\s*XREF\s+BIO_FTDI_READ_BYTE_BLOCK\s*$" -or
        $line -match "^BIO_FTDI_READ_BYTE_BLOCK\s+EQU\s+") {
        $replacement = Equ-Line -Name "BIO_FTDI_READ_BYTE_BLOCK" -Value $readAddr
        $sawRead = $true
    } elseif ($line -match "^\s*XREF\s+BIO_FTDI_WRITE_BYTE_BLOCK\s*$" -or
        $line -match "^BIO_FTDI_WRITE_BYTE_BLOCK\s+EQU\s+") {
        $replacement = Equ-Line -Name "BIO_FTDI_WRITE_BYTE_BLOCK" -Value $writeAddr
        $sawWrite = $true
    } elseif ($line -match "^HIMON_START\s+EQU\s+") {
        $replacement = Equ-Line -Name "HIMON_START" -Value $startAddr
        $sawStart = $true
    } else {
        continue
    }

    if ($line -ne $replacement) {
        $lines[$i] = $replacement
        $changed = $true
    }
}

if (-not $sawRead) {
    throw "BIO_FTDI_READ_BYTE_BLOCK XREF/EQU not found in $SourcePath"
}
if (-not $sawWrite) {
    throw "BIO_FTDI_WRITE_BYTE_BLOCK XREF/EQU not found in $SourcePath"
}
if (-not $sawStart) {
    throw "HIMON_START EQU not found in $SourcePath"
}

if ($changed) {
    Set-Content -Path $SourcePath -Value $lines -Encoding ASCII
}

Write-Host ("fig-FORTH HIMON calls = READ {0}, WRITE {1}, MON {2}" -f $readAddr, $writeAddr, $startAddr)

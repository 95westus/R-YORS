param(
    [string]$BinDir = "BUILD/bin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BinDir)) {
    throw "BIN directory not found: $BinDir"
}

function Format-BinBytes {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset,
        [Parameter(Mandatory = $true)][int]$Count
    )

    $end = [Math]::Min($Bytes.Length - 1, $Offset + $Count - 1)
    if ($Offset -lt 0 -or $Offset -ge $Bytes.Length -or $end -lt $Offset) {
        return ""
    }

    $items = @()
    for ($i = $Offset; $i -le $end; $i++) {
        $items += ("{0:X2}" -f $Bytes[$i])
    }
    return ($items -join " ")
}

function Test-AllErased {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset,
        [Parameter(Mandatory = $true)][int]$Count
    )

    $end = [Math]::Min($Bytes.Length - 1, $Offset + $Count - 1)
    if ($Offset -lt 0 -or $Offset -ge $Bytes.Length -or $end -lt $Offset) {
        return $true
    }

    for ($i = $Offset; $i -le $end; $i++) {
        if ($Bytes[$i] -ne 0xFF) {
            return $false
        }
    }
    return $true
}

function Test-RomBankImage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$BankOffset,
        [Parameter(Mandatory = $true)][string]$BankLabel
    )

    $bankSize = 32768
    if (($BankOffset + $bankSize) -gt $Bytes.Length) {
        return ("{0}: {1} offset {2:X5} is outside file length {3}" -f $Name, $BankLabel, $BankOffset, $Bytes.Length)
    }

    $tailOffset = $BankOffset + 0x7FFA
    $nmi = [int]$Bytes[$tailOffset] -bor ([int]$Bytes[$tailOffset + 1] -shl 8)
    $reset = [int]$Bytes[$tailOffset + 2] -bor ([int]$Bytes[$tailOffset + 3] -shl 8)
    $irq = [int]$Bytes[$tailOffset + 4] -bor ([int]$Bytes[$tailOffset + 5] -shl 8)
    $resetOffset = $BankOffset + ($reset - 0x8000)
    $tail = Format-BinBytes -Bytes $Bytes -Offset $tailOffset -Count 6

    if ($reset -lt 0x8000 -or $reset -gt 0xFFFF) {
        return ("{0}: RESET vector {1:X4} is outside the 8000-FFFF ROM bank; {2}-tail={3}" -f $Name, $reset, $BankLabel, $tail)
    }

    if (Test-AllErased -Bytes $Bytes -Offset $resetOffset -Count 16) {
        return ("{0}: RESET vector {1:X4} points at erased bytes; reset-head={2}; {3}-tail={4}" -f $Name, $reset, (Format-BinBytes -Bytes $Bytes -Offset $resetOffset -Count 16), $BankLabel, $tail)
    }

    if ($Bytes[$BankOffset] -eq 0x4C) {
        $jmpTarget = [int]$Bytes[$BankOffset + 1] -bor ([int]$Bytes[$BankOffset + 2] -shl 8)
        if ($jmpTarget -ne $reset) {
            return ("{0}: {1} start JMP target {2:X4} does not match RESET vector {3:X4}; {1}-head={4}; {1}-tail={5}" -f $Name, $BankLabel, $jmpTarget, $reset, (Format-BinBytes -Bytes $Bytes -Offset $BankOffset -Count 16), $tail)
        }
    }

    Write-Host ("BIN OK {0,-32} len={1,6} file-head={2} {3}-head={4} reset={5:X4} reset-head={6} vectors={7:X4}/{8:X4}/{9:X4}" -f $Name, $Bytes.Length, (Format-BinBytes -Bytes $Bytes -Offset 0 -Count 16), $BankLabel, (Format-BinBytes -Bytes $Bytes -Offset $BankOffset -Count 16), $reset, (Format-BinBytes -Bytes $Bytes -Offset $resetOffset -Count 16), $nmi, $reset, $irq)
    return $null
}

$bad = @()
Get-ChildItem -LiteralPath $BinDir -Filter *.bin -File | Sort-Object Name | ForEach-Object {
    [byte[]]$bin = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bin.Length -eq 0) {
        $bad += ("{0}: empty BIN" -f $_.Name)
        return
    }

    $headCount = [Math]::Min(16, $bin.Length)
    $head = @()
    for ($i = 0; $i -lt $headCount; $i++) {
        $head += ("{0:X2}" -f $bin[$i])
    }

    if ($bin.Length -eq 32768) {
        $problem = Test-RomBankImage -Name $_.Name -Bytes $bin -BankOffset 0 -BankLabel "bank"
        if ($problem) {
            $bad += $problem
        }
        return
    }

    if ($bin.Length -eq 131072) {
        $problem = Test-RomBankImage -Name $_.Name -Bytes $bin -BankOffset 0x18000 -BankLabel "bank3"
        if ($problem) {
            $bad += $problem
        }
        return
    }

    Write-Host ("BIN OK {0,-32} len={1,5} head={2}" -f $_.Name, $bin.Length, ($head -join " "))
}

if ($bad.Count -gt 0) {
    foreach ($item in $bad) {
        Write-Error $item
    }
    throw ("BIN policy check failed for {0} file(s)." -f $bad.Count)
}

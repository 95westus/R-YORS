param(
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$LedContractPath = "HIMON/himon-led-eq.inc",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$HimonMapPath = "BUILD/s19/himon-rom-c000.map"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "HIMON I/O LED check: $Message"
}

foreach ($path in @($HimonSourcePath, $LedContractPath, $HimonS19Path, $HimonMapPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail-Check "missing file: $path"
    }
}

$source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HimonSourcePath))
$contract = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $LedContractPath))

function Read-Equ([string]$Name) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s+EQU\s+\$([0-9A-Fa-f]+)\s*$'
    $match = [regex]::Match($contract, $pattern)
    if (-not $match.Success) { Fail-Check "missing LED constant $Name" }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

$expectedEqu = [ordered]@{
    HIM_LED_PIA_PORTA = 0x7FA0
    HIM_LED_FLAG_HOST = 0x02
    HIM_LED_STATUS_NO_HOST_WAIT = 0x21
    HIM_LED_STATUS_HOST_INPUT_WAIT = 0x43
    HIM_LED_STATUS_RX_ACTIVITY = 0x07
    HIM_LED_STATUS_TX_ACTIVITY = 0x0B
}
foreach ($entry in $expectedEqu.GetEnumerator()) {
    if ((Read-Equ $entry.Key) -ne $entry.Value) {
        Fail-Check ('{0} must be ${1:X2}' -f $entry.Key, $entry.Value)
    }
}

function Read-MapSymbol([string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    foreach ($line in [IO.File]::ReadLines($HimonMapPath)) {
        if ($line -match $pattern) {
            return [Convert]::ToInt32($matches[1], 16)
        }
    }
    Fail-Check "map symbol $Name is missing"
}

$memory = [byte[]]::new(0x10000)
$present = [bool[]]::new(0x10000)
foreach ($rawLine in [IO.File]::ReadLines($HimonS19Path)) {
    $line = $rawLine.Trim()
    if ($line.Length -lt 4 -or $line[0] -ne 'S' -or $line[1] -notin @('1','2','3')) { continue }
    $addressBytes = switch ($line[1]) { '1' { 2 }; '2' { 3 }; '3' { 4 } }
    $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
    $address = [Convert]::ToInt32($line.Substring(4, $addressBytes * 2), 16)
    $dataBytes = $count - $addressBytes - 1
    for ($i = 0; $i -lt $dataBytes; $i++) {
        $target = $address + $i
        if ($target -lt 0 -or $target -ge 0x10000) { Fail-Check 'S19 address is outside 16-bit memory' }
        $memory[$target] = [Convert]::ToByte($line.Substring(4 + 2 * $addressBytes + 2 * $i, 2), 16)
        $present[$target] = $true
    }
}

function Read-Word([int]$Address) {
    if (-not $present[$Address] -or -not $present[$Address + 1]) {
        Fail-Check ('missing S19 word at ${0:X4}' -f $Address)
    }
    return [int]$memory[$Address] -bor ([int]$memory[$Address + 1] -shl 8)
}

function Assert-Bytes([int]$Address, [int[]]$Expected, [string]$Description) {
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        if (-not $present[$Address + $i] -or $memory[$Address + $i] -ne $Expected[$i]) {
            Fail-Check ('{0} differs at ${1:X4}' -f $Description, ($Address + $i))
        }
    }
}

function Jsr-Jmp-Bytes([int]$JsrTarget, [int]$JmpTarget) {
    return @(0x20, ($JsrTarget -band 0xFF), (($JsrTarget -shr 8) -band 0xFF),
        0x4C, ($JmpTarget -band 0xFF), (($JmpTarget -shr 8) -band 0xFF))
}

function Rel8([int]$FromAfterOperand, [int]$Target) {
    return (($Target - $FromAfterOperand) -band 0xFF)
}

$rx = Read-MapSymbol 'HIM_IO_RX_ACTIVITY_A'
$wait = Read-MapSymbol 'HIM_IO_PUBLISH_INPUT_WAIT'
$waitPublish = Read-MapSymbol 'HIM_IO_PUBLISH_WAIT'
$refresh = Read-MapSymbol 'HIM_IO_REFRESH_INPUT_WAIT'
$refreshNoHost = Read-MapSymbol 'HIM_IO_REFRESH_NO_HOST_WAIT'
$refreshDone = Read-MapSymbol 'HIM_IO_REFRESH_WAIT_DONE'
$tx = Read-MapSymbol 'HIM_IO_TX_ACTIVITY_A'
$sysEnum = Read-MapSymbol 'SYS_CHECK_ENUMERATED'
$nonblock = Read-MapSymbol 'BIO_FTDI_READ_BYTE_NONBLOCK'
$readHw = Read-MapSymbol 'HIM_READ_BYTE_HW'
Assert-Bytes $readHw @(0x20,($nonblock -band 0xFF),(($nonblock -shr 8) -band 0xFF),
    0xB0,(Rel8 ($readHw + 5) $rx),
    0x20,($refresh -band 0xFF),(($refresh -shr 8) -band 0xFF),
    0x80,(Rel8 ($readHw + 10) $readHw)) 'private cooperative input loop'
Assert-Bytes $rx @(0x48,0xA9,0x07,0x8D,0xA0,0x7F,0x68,0x38,0x60) 'RX activity veneer'
Assert-Bytes $wait @(0x20,($sysEnum -band 0xFF),(($sysEnum -shr 8) -band 0xFF),
    0x90,0x04,0xA9,0x43,0x80,0x02,0xA9,0x21,0x8D,0xA0,0x7F,0x60) 'input-wait publisher'
Assert-Bytes $refresh @(0x20,($sysEnum -band 0xFF),(($sysEnum -shr 8) -band 0xFF),
    0x90,(Rel8 ($refresh + 5) $refreshNoHost),
    0xAD,0xA0,0x7F,0x29,0x02,
    0xD0,(Rel8 ($refresh + 12) $refreshDone),
    0xA9,0x43,
    0x80,(Rel8 ($refresh + 16) $waitPublish)) 'host-present refresh path'
Assert-Bytes $refreshNoHost @(0xAD,0xA0,0x7F,0xC9,0x21,
    0xF0,(Rel8 ($refreshNoHost + 7) $refreshDone),
    0xA9,0x21,
    0x80,(Rel8 ($refreshNoHost + 11) $waitPublish)) 'no-host refresh path'
Assert-Bytes $refreshDone @(0x60) 'unchanged-host refresh return'
Assert-Bytes $tx @(0x48,0xA9,0x0B,0x8D,0xA0,0x7F,0x68,0x60) 'TX activity veneer'

$wrappers = [ordered]@{
    HIM_IO_WRITE_BYTE_ACTIVITY = 'BIO_FTDI_WRITE_BYTE_BLOCK'
    HIM_IO_WRITE_CSTRING_ACTIVITY = 'SYS_WRITE_CSTRING'
    HIM_IO_WRITE_HEX_BYTE_ACTIVITY = 'SYS_WRITE_HEX_BYTE'
    HIM_IO_WRITE_CRLF_ACTIVITY = 'SYS_WRITE_CRLF'
}
foreach ($entry in $wrappers.GetEnumerator()) {
    $address = Read-MapSymbol $entry.Key
    $target = Read-MapSymbol $entry.Value
    Assert-Bytes $address (Jsr-Jmp-Bytes $tx $target) "$($entry.Key) call chain"
}

$table = Read-MapSymbol 'HIM_SVC_BOOT_TABLE'
$serviceWords = [ordered]@{
    8 = 'HIM_IO_WRITE_BYTE_ACTIVITY'
    10 = 'HIM_IO_WRITE_CSTRING_ACTIVITY'
    12 = 'HIM_IO_WRITE_HEX_BYTE_ACTIVITY'
    14 = 'HIM_IO_WRITE_CRLF_ACTIVITY'
    16 = 'HIM_READ_LINE_ECHO'
}
foreach ($entry in $serviceWords.GetEnumerator()) {
    if ((Read-Word ($table + [int]$entry.Key)) -ne (Read-MapSymbol $entry.Value)) {
        Fail-Check "service vector +$($entry.Key) does not use $($entry.Value)"
    }
}

$putCstrRecord = Read-MapSymbol 'BIO_FTDI_PUT_CSTR_FNV'
if ((Read-Word ($putCstrRecord + 8)) -ne (Read-MapSymbol 'HIM_IO_WRITE_CSTRING_ACTIVITY')) {
    Fail-Check 'BIO_FTDI_PUT_CSTR record bypasses the HIMON TX veneer'
}
foreach ($name in @('BIO_FTDI_READ_BYTE_BLOCK','BIO_FTDI_WRITE_BYTE_BLOCK')) {
    $record = Read-MapSymbol ($name + '_FNV')
    if ((Read-Word ($record + 8)) -ne (Read-MapSymbol $name)) {
        Fail-Check "$name public record no longer points to its raw entry"
    }
}

$lineSetMode = Read-MapSymbol 'HIM_READ_LINE_SET_MODE'
Assert-Bytes ($lineSetMode + 8) @(0x20,($wait -band 0xFF),(($wait -shr 8) -band 0xFF)) 'line-reader wait hook'
$hbString = Read-MapSymbol 'HIM_WRITE_HBSTRING'
Assert-Bytes $hbString @(0x20,($tx -band 0xFF),(($tx -shr 8) -band 0xFF)) 'HIMON string TX hook'
if ($source -notmatch '(?s)HIM_CHECK_CTRL_C:.*?JSR\s+BIO_FTDI_READ_BYTE_NONBLOCK.*?JSR\s+HIM_IO_RX_ACTIVITY_A') {
    Fail-Check 'nonblocking HIMON input does not publish RX activity'
}

$endData = Read-MapSymbol '_END_DATA'
if ($endData -gt 0xF000) { Fail-Check ('HIMON overlaps STR8-N at ${0:X4}' -f $endData) }
Write-Host ('HIMON I/O LED check = PASS; live wait=$21/$43 rx=$07 tx=$0B; end=${0:X4}; margin=${1:X4}' -f $endData, (0xF000 - $endData))

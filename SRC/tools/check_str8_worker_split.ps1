param(
    [string]$JumpMapPath = "BUILD/map/str8-jump-worker-0200.map",
    [string]$MutationMapPath = "BUILD/map/str8-mutation-worker-0200.map"
)

$ErrorActionPreference = "Stop"

function Read-MapSymbols {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing map: $Path" }
    $symbols = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([0-9A-Fa-f]{8})\s+(\S+)\s*$') {
            $symbols[$Matches[2].ToUpperInvariant()] = [Convert]::ToInt32($Matches[1], 16)
        }
    }
    return $symbols
}

function Get-Symbol {
    param([hashtable]$Symbols, [string]$Name)

    $key = $Name.ToUpperInvariant()
    if (-not $Symbols.ContainsKey($key)) { throw "Missing symbol: $Name" }
    return [int]$Symbols[$key]
}

function Assert-Missing {
    param([hashtable]$Symbols, [string[]]$Names, [string]$Image)

    foreach ($name in $Names) {
        if ($Symbols.ContainsKey($name.ToUpperInvariant())) {
            throw "$Image unexpectedly exports $name"
        }
    }
}

$jump = Read-MapSymbols $JumpMapPath
$mutation = Read-MapSymbols $MutationMapPath

$jumpStart = Get-Symbol $jump 'START'
$jumpEnd = Get-Symbol $jump 'STR8_WORKER_END'
$jumpService = Get-Symbol $jump 'STR8W_BANK_SELECT_SERVICE'
$jumpSize = $jumpEnd - $jumpStart

$mutationStart = Get-Symbol $mutation 'START'
$mutationEnd = Get-Symbol $mutation 'STR8_WORKER_END'
$mutationSize = $mutationEnd - $mutationStart

if ($jumpStart -ne 0x0200 -or $mutationStart -ne 0x0200) {
    throw ('Split worker starts are ${0:X4}/${1:X4}; expected $0200/$0200' -f $jumpStart, $mutationStart)
}
if ($jumpService -ne 0x0203) {
    throw ('Jump worker bank-select ABI is ${0:X4}; expected $0203' -f $jumpService)
}
if ($jumpSize -gt 0xF3) {
    throw ('Jump worker is ${0:X} bytes; exceeds the $F3-byte reserve-inclusive ceiling' -f $jumpSize)
}
if ($mutationEnd -gt 0x0A00) {
    throw ('Mutation worker ends at ${0:X4}; exceeds the $0200-$09FF RAM tray' -f $mutationEnd)
}

foreach ($name in @('STR8W_JUMP_BANK', 'STR8W_SELECT_BANK3', 'STR8W_BANK_SELECT_A')) {
    [void](Get-Symbol $jump $name)
}
foreach ($name in @(
        'STR8W_PROGRAM_STAGED_SECTOR',
        'STR8W_STAGE_BANK_SECTOR',
        'STR8W_PROGRAM_RECORD',
        'STR8W_FLASH_ERASE',
        'STR8W_FLASH_WRITE',
        'STR8W_SELECT_BANK3',
        'STR8W_BANK_SELECT_A'
    )) {
    [void](Get-Symbol $mutation $name)
}

Assert-Missing $jump @('STR8W_PROGRAM_STAGED_SECTOR', 'STR8W_STAGE_BANK_SECTOR', 'STR8W_PROGRAM_RECORD', 'STR8W_FLASH_WRITE') 'Jump worker'
Assert-Missing $mutation @('STR8W_BANK_SELECT_SERVICE', 'STR8W_JUMP_BANK') 'Mutation worker'

$physicalRoom = 0xFFB0 - 0xFE7D
$headroom = $physicalRoom - $jumpSize
$reserve = 0x40
$reserveHeadroom = $headroom - $reserve

Write-Host ('JUMP WORKER             = ${0:X4}-${1:X4}; ${2:X} bytes' -f $jumpStart, ($jumpEnd - 1), $jumpSize)
Write-Host ('MUTATION WORKER         = ${0:X4}-${1:X4}; ${2:X} bytes' -f $mutationStart, ($mutationEnd - 1), $mutationSize)
Write-Host ('PRE-DIRECTORY ROOM      = ${0:X} bytes' -f $physicalRoom)
Write-Host ('ROOM AFTER JUMP WORKER  = ${0:X} bytes' -f $headroom)
Write-Host ('ROOM AFTER $40 RESERVE  = ${0:X} bytes' -f $reserveHeadroom)
Write-Host 'SPLIT WORKER SIZE CHECK = PASS'

param(
    [string]$JumpMapPath = "BUILD/map/str8-jump-worker-0200.map",
    [string]$JumpS19Path = "BUILD/s19/str8-jump-worker-0200.s19",
    [string]$MutationMapPath = "BUILD/map/str8-mutation-worker-0200.map",
    [string]$MutationS19Path = "BUILD/s19/str8-mutation-worker-0200.s19",
    [string]$WorkerEqPath = "STR8/str8-worker-eq.inc",
    [string]$ResidentMapPath = "BUILD/map/str8-v1-installer-transaction-f000.map"
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

function Get-EquValue {
    param([string]$Path, [string]$Name)

    $pattern = '^\s*' + [Regex]::Escape($Name) + '\s+EQU\s+(.+?)\s*$'
    $match = Select-String -LiteralPath $Path -Pattern $pattern | Select-Object -First 1
    if (-not $match) { throw "Missing constant: $Name" }
    $value = $match.Matches[0].Groups[1].Value.Trim()
    if ($value -match '^\$([0-9A-Fa-f]+)$') { return [Convert]::ToInt32($Matches[1], 16) }
    if ($value -match "^'(.)'$" ) { return [int][char]$Matches[1] }
    throw "Unsupported constant value for $Name`: $value"
}

function Read-S19Memory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing S19: $Path" }
    [byte[]]$memory = New-Object byte[] 65536
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -notmatch '^S1([0-9A-Fa-f]+)$') { continue }
        $hex = $Matches[1]
        $count = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        $address = [Convert]::ToInt32($hex.Substring(2, 4), 16)
        $dataLength = $count - 3
        for ($i = 0; $i -lt $dataLength; $i++) {
            $memory[$address + $i] = [Convert]::ToByte($hex.Substring(6 + ($i * 2), 2), 16)
        }
    }
    return ,$memory
}

$jump = Read-MapSymbols $JumpMapPath
$mutation = Read-MapSymbols $MutationMapPath
$resident = Read-MapSymbols $ResidentMapPath

$jumpStart = Get-Symbol $jump 'START'
$jumpEnd = Get-Symbol $jump 'STR8_WORKER_END'
$jumpService = Get-Symbol $jump 'STR8W_BANK_SELECT_SERVICE'
$jumpSize = $jumpEnd - $jumpStart

$mutationStart = Get-Symbol $mutation 'START'
$mutationEnd = Get-Symbol $mutation 'STR8_WORKER_END'
$mutationSize = $mutationEnd - $mutationStart
$residentEnd = Get-Symbol $resident '_END_DATA'
$mutationSig = Get-Symbol $mutation 'STR8W_MUTATION_SIG'
$expectedJumpStart = Get-EquValue $WorkerEqPath 'STR8_JUMP_WORKER_START'
$expectedJumpEnd = Get-EquValue $WorkerEqPath 'STR8_JUMP_WORKER_END'
$expectedJumpSize = Get-EquValue $WorkerEqPath 'STR8_JUMP_WORKER_SIZE'
$expectedJumpStore = Get-EquValue $WorkerEqPath 'STR8_JUMP_WORKER_STORE'
$expectedSigAddress = Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG'
$expectedMutationEnd = Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_END'
[byte[]]$expectedSig = @(
    Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG0'
    Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG1'
    Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG2'
    Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG3'
)
[byte[]]$mutationMemory = Read-S19Memory $MutationS19Path
[byte[]]$jumpMemory = Read-S19Memory $JumpS19Path

if ($jumpStart -ne $expectedJumpStart -or $mutationStart -ne 0x0200) {
    throw ('Split worker starts are ${0:X4}/${1:X4}; expected $0200/$0200' -f $jumpStart, $mutationStart)
}
if ($jumpEnd -ne $expectedJumpEnd -or $jumpSize -ne $expectedJumpSize) {
    throw ('Jump worker extent is ${0:X4}-${1:X4}/${2:X}; expected ${3:X4}-${4:X4}/${5:X}' -f `
        $jumpStart, ($jumpEnd - 1), $jumpSize, $expectedJumpStart, ($expectedJumpEnd - 1), $expectedJumpSize)
}
if ($jumpService -ne 0x0203) {
    throw ('Jump worker bank-select ABI is ${0:X4}; expected $0203' -f $jumpService)
}
$jumpModeGate = Get-Symbol $jump 'STR8W_JUMP_START'
[byte[]]$expectedJumpModeGate = @(
    0xAD, 0xF0, 0x7D, # LDA $7DF0
    0xC9, 0x08,       # CMP #$08
    0xF0, 0x02,       # BEQ guarded jump body
    0x18, 0x60        # CLC / RTS for every other mode
)
for ($i = 0; $i -lt $expectedJumpModeGate.Length; $i++) {
    if ($jumpMemory[$jumpModeGate + $i] -ne $expectedJumpModeGate[$i]) {
        throw ('Jump worker mode gate mismatch at ${0:X4}' -f ($jumpModeGate + $i))
    }
}
if ($mutationEnd -gt 0x0A00) {
    throw ('Mutation worker ends at ${0:X4}; exceeds the $0200-$09FF RAM tray' -f $mutationEnd)
}
if ($mutationEnd -ne $expectedMutationEnd -or $mutationSig -ne $expectedSigAddress) {
    throw ('Mutation identity extent is SIG=${0:X4} END=${1:X4}; expected ${2:X4}/${3:X4}' -f `
        $mutationSig, $mutationEnd, $expectedSigAddress, $expectedMutationEnd)
}
for ($i = 0; $i -lt $expectedSig.Length; $i++) {
    if ($mutationMemory[$mutationSig + $i] -ne $expectedSig[$i]) {
        throw ('Mutation signature mismatch at ${0:X4}' -f ($mutationSig + $i))
    }
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

Assert-Missing $jump @('STR8W_PROGRAM_STAGED_SECTOR', 'STR8W_STAGE_BANK_SECTOR', 'STR8W_PROGRAM_RECORD', 'STR8W_FLASH_ERASE', 'STR8W_FLASH_WRITE') 'Jump worker'
Assert-Missing $mutation @('STR8W_BANK_SELECT_SERVICE', 'STR8W_JUMP_BANK') 'Mutation worker'

$physicalRoom = 0xFFB0 - $residentEnd
$headroom = $physicalRoom - $jumpSize
$reserve = 0x40
$growthTarget = 0x80
$reserveHeadroom = $headroom - $reserve
$residentWorkerStore = ((Get-Symbol $resident 'STR8_WORKER_STORE_HI') -shl 8) -bor `
    (Get-Symbol $resident 'STR8_WORKER_STORE_LO')
$residentWorkerCopyLength = ((Get-Symbol $resident 'STR8_WORKER_COPY_LEN_HI') -shl 8) -bor `
    (Get-Symbol $resident 'STR8_WORKER_COPY_LEN_LO')
if ($reserveHeadroom -lt $growthTarget) {
    throw ('Jump worker leaves ${0:X} bytes after the $40 reserve; growth target is ${1:X}' -f $reserveHeadroom, $growthTarget)
}
if ($expectedJumpStore -ne (0xFFB0 - $jumpSize)) {
    throw ('Frozen jump-worker store is ${0:X4}; packed extent requires ${1:X4}' -f $expectedJumpStore, (0xFFB0 - $jumpSize))
}
if ($residentWorkerStore -ne $expectedJumpStore -or $residentWorkerCopyLength -ne $jumpSize) {
    throw ('Transaction copy contract is store=${0:X4} len=${1:X}; expected ${2:X4}/${3:X}' -f `
        $residentWorkerStore, $residentWorkerCopyLength, $expectedJumpStore, $jumpSize)
}

Write-Host ('JUMP WORKER             = ${0:X4}-${1:X4}; ${2:X} bytes' -f $jumpStart, ($jumpEnd - 1), $jumpSize)
Write-Host ('MUTATION WORKER         = ${0:X4}-${1:X4}; ${2:X} bytes' -f $mutationStart, ($mutationEnd - 1), $mutationSize)
Write-Host ('MUTATION ID             = ${0:X4}; {1}' -f $mutationSig, (($expectedSig | ForEach-Object { '{0:X2}' -f $_ }) -join ' '))
Write-Host ('TRANSACTION RESIDENT    = $F000-${0:X4}; ${1:X} bytes' -f ($residentEnd - 1), ($residentEnd - 0xF000))
Write-Host ('PRE-DIRECTORY ROOM      = ${0:X} bytes' -f $physicalRoom)
Write-Host ('ROOM AFTER JUMP WORKER  = ${0:X} bytes' -f $headroom)
Write-Host ('ROOM AFTER $40 RESERVE  = ${0:X} bytes (target ${1:X})' -f $reserveHeadroom, $growthTarget)
Write-Host ('TRANSACTION JUMP STORE  = ${0:X4}-${1:X4}; ${2:X} bytes' -f $residentWorkerStore, ($residentWorkerStore + $residentWorkerCopyLength - 1), $residentWorkerCopyLength)
Write-Host 'SPLIT WORKER SIZE CHECK = PASS'

param(
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$HimonMapPath = "BUILD/s19/himon-rom-c000.map",
    [string]$WorkerEqPath = "STR8/str8-worker-eq.inc"
)

$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "HIMON banked AP check: $Message"
}

function Read-MapSymbol([string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    foreach ($line in [System.IO.File]::ReadLines($HimonMapPath)) {
        if ($line -match $pattern) {
            return [Convert]::ToInt32($matches[1], 16)
        }
    }
    Fail-Check "map symbol $Name is missing"
}

function Read-S19Memory {
    $memory = [byte[]]::new(0x10000)
    $present = [bool[]]::new(0x10000)
    foreach ($rawLine in [System.IO.File]::ReadLines($HimonS19Path)) {
        $line = $rawLine.Trim()
        if ($line.Length -lt 4 -or $line[0] -ne 'S') { continue }
        $kind = $line[1]
        $addressBytes = switch ($kind) {
            '1' { 2 }
            '2' { 3 }
            '3' { 4 }
            default { 0 }
        }
        if ($addressBytes -eq 0) { continue }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        $address = [Convert]::ToInt32(
            $line.Substring(4, $addressBytes * 2), 16
        )
        $dataBytes = $count - $addressBytes - 1
        for ($i = 0; $i -lt $dataBytes; $i++) {
            $target = $address + $i
            if ($target -lt 0 -or $target -ge 0x10000) {
                Fail-Check ('S19 data address ${0:X} is outside 16-bit memory' -f $target)
            }
            $memory[$target] = [Convert]::ToByte(
                $line.Substring(4 + ($addressBytes * 2) + ($i * 2), 2), 16
            )
            $present[$target] = $true
        }
    }
    return [pscustomobject]@{ Memory = $memory; Present = $present }
}

function Set-Nz([int]$Status, [int]$Value) {
    $next = $Status -band 0x7D
    if (($Value -band 0xFF) -eq 0) { $next = $next -bor 0x02 }
    if (($Value -band 0x80) -ne 0) { $next = $next -bor 0x80 }
    return $next
}

function Invoke-RamStage(
    [byte[]]$Routine,
    [byte[][]]$Banks,
    [int]$Bank,
    [int]$StartHigh,
    [int]$InitialStatus,
    [bool]$FailInitialSelect = $false,
    [int]$RestoreFailures = 0
) {
    $memory = [byte[]]::new(0x8000)
    for ($i = 0x0A00; $i -lt 0x1A00; $i++) {
        $memory[$i] = 0x5A
    }
    [Array]::Copy($Routine, 0, $memory, 0x0300, $Routine.Length)

    $cmdIoTmp = Read-MapSymbol 'CMD_IO_TMP'
    $cmdStartHi = Read-MapSymbol 'CMDP_START_HI'
    $memory[$cmdIoTmp] = [byte]$Bank
    $memory[$cmdStartHi] = [byte]$StartHigh

    $pc = 0x0300
    $a = 0
    $x = 0
    $y = 0
    $status = $InitialStatus -band 0xFF
    $selectedBank = 3
    $stack = [System.Collections.Generic.Stack[int]]::new()
    $steps = 0

    while ($steps -lt 100000) {
        $steps++
        $opcode = [int]$memory[$pc]
        switch ($opcode) {
            0x08 { # PHP
                $stack.Push($status)
                $pc++
            }
            0x78 { # SEI
                $status = $status -bor 0x04
                $pc++
            }
            0xAD { # LDA abs
                $address = [int]$memory[$pc + 1] -bor `
                    ([int]$memory[$pc + 2] -shl 8)
                $a = [int]$memory[$address]
                $status = Set-Nz $status $a
                $pc += 3
            }
            0xA5 { # LDA zp
                $a = [int]$memory[[int]$memory[$pc + 1]]
                $status = Set-Nz $status $a
                $pc += 2
            }
            0x20 { # JSR abs; only the two published selectors are legal here.
                $target = [int]$memory[$pc + 1] -bor `
                    ([int]$memory[$pc + 2] -shl 8)
                $pc += 3
                if ($target -eq 0xF010) {
                    if ($FailInitialSelect -or $a -lt 0 -or $a -gt 3) {
                        $status = $status -band 0xFE
                    } else {
                        $selectedBank = $a
                        $status = $status -bor 0x01
                    }
                    continue
                }
                if ($target -eq 0x0203) {
                    if ($RestoreFailures -gt 0) {
                        $RestoreFailures--
                        $status = $status -band 0xFE
                    } elseif ($a -eq 3) {
                        $selectedBank = 3
                        $status = $status -bor 0x01
                    } else {
                        $status = $status -band 0xFE
                    }
                    continue
                }
                Fail-Check ('RAM body called unexpected ${0:X4}' -f $target)
            }
            0x90 { # BCC rel
                $offset = [int]$memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 0x01) -eq 0) { $pc += $offset }
            }
            0x64 { # STZ zp
                $memory[[int]$memory[$pc + 1]] = 0
                $pc += 2
            }
            0x29 { # AND imm
                $a = $a -band [int]$memory[$pc + 1]
                $status = Set-Nz $status $a
                $pc += 2
            }
            0x85 { # STA zp
                $memory[[int]$memory[$pc + 1]] = [byte]$a
                $pc += 2
            }
            0xA9 { # LDA imm
                $a = [int]$memory[$pc + 1]
                $status = Set-Nz $status $a
                $pc += 2
            }
            0xA2 { # LDX imm
                $x = [int]$memory[$pc + 1]
                $status = Set-Nz $status $x
                $pc += 2
            }
            0xA0 { # LDY imm
                $y = [int]$memory[$pc + 1]
                $status = Set-Nz $status $y
                $pc += 2
            }
            0xB1 { # LDA (zp),Y
                $zp = [int]$memory[$pc + 1]
                $address = ([int]$memory[$zp] -bor `
                    ([int]$memory[($zp + 1) -band 0xFF] -shl 8)) + $y
                $address = $address -band 0xFFFF
                if ($address -ge 0x8000) {
                    $a = [int]$Banks[$selectedBank][$address - 0x8000]
                } else {
                    $a = [int]$memory[$address]
                }
                $status = Set-Nz $status $a
                $pc += 2
            }
            0x91 { # STA (zp),Y
                $zp = [int]$memory[$pc + 1]
                $address = ([int]$memory[$zp] -bor `
                    ([int]$memory[($zp + 1) -band 0xFF] -shl 8)) + $y
                $address = $address -band 0xFFFF
                if ($address -ge 0x8000) {
                    Fail-Check ('RAM body attempted bank-window write at ${0:X4}' -f $address)
                }
                $memory[$address] = [byte]$a
                $pc += 2
            }
            0xC8 { # INY
                $y = ($y + 1) -band 0xFF
                $status = Set-Nz $status $y
                $pc++
            }
            0xD0 { # BNE rel
                $offset = [int]$memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 0x02) -eq 0) { $pc += $offset }
            }
            0xE6 { # INC zp
                $zp = [int]$memory[$pc + 1]
                $value = ([int]$memory[$zp] + 1) -band 0xFF
                $memory[$zp] = [byte]$value
                $status = Set-Nz $status $value
                $pc += 2
            }
            0xCA { # DEX
                $x = ($x - 1) -band 0xFF
                $status = Set-Nz $status $x
                $pc++
            }
            0x28 { # PLP
                if ($stack.Count -eq 0) { Fail-Check 'RAM body PLP underflow' }
                $status = $stack.Pop()
                $pc++
            }
            0x38 { # SEC
                $status = $status -bor 0x01
                $pc++
            }
            0x18 { # CLC
                $status = $status -band 0xFE
                $pc++
            }
            0x60 { # RTS
                if ($stack.Count -ne 0) { Fail-Check 'RAM body returned with saved status' }
                return [pscustomobject]@{
                    Memory = $memory
                    Status = $status
                    SelectedBank = $selectedBank
                    Steps = $steps
                }
            }
            default {
                Fail-Check ('unsupported RAM opcode ${0:X2} at ${1:X4}' -f $opcode, $pc)
            }
        }
    }
    Fail-Check 'RAM body did not return within the step limit'
}

foreach ($path in @($HimonSourcePath, $HimonS19Path, $HimonMapPath, $WorkerEqPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail-Check "missing input $path" }
}

$sourceLines = [System.IO.File]::ReadAllLines((Resolve-Path $HimonSourcePath))
$codeText = ($sourceLines | ForEach-Object { ($_ -split ';', 2)[0] }) -join "`n"
foreach ($retired in @('$F003', 'STR8_RUN_WORKER_SERVICE',
        'STR8_COPY_MODE_STAGE_BANK_SECTOR')) {
    if ($codeText.Contains($retired)) { Fail-Check "source still uses $retired" }
}
foreach ($required in @('HIM_AP_BANK_STAGE_RAM    EQU             $0300',
        'JSR             STR8_BANK_SELECT_SERVICE',
        'JSR             STR8_BANK_SELECT_RAM',
        'STA             (HIM_AP_STAGE_DST_LO),Y')) {
    if (-not $codeText.Contains($required)) { Fail-Check "source is missing $required" }
}

$workerEqText = [System.IO.File]::ReadAllText((Resolve-Path $WorkerEqPath))
if ($workerEqText -notmatch 'STR8_JUMP_WORKER_END\s+EQU\s+\$([0-9A-Fa-f]{4})') {
    Fail-Check 'jump-worker end constant is missing'
}
$jumpWorkerEnd = [Convert]::ToInt32($matches[1], 16)

$sourceStart = Read-MapSymbol 'HIM_AP_BANK_STAGE_CODE'
$sourceEnd = Read-MapSymbol 'HIM_AP_BANK_STAGE_CODE_END'
$size = Read-MapSymbol 'HIM_AP_BANK_STAGE_CODE_SIZE'
$ramStart = Read-MapSymbol 'HIM_AP_BANK_STAGE_RAM'
if ($size -ne ($sourceEnd - $sourceStart)) {
    Fail-Check 'linked RAM-body size does not match its label extent'
}
if ($size -le 0 -or $size -gt 0x80) {
    Fail-Check ('RAM body size ${0:X} exceeds the reverse-copy loop contract' -f $size)
}
if ($ramStart -lt $jumpWorkerEnd -or ($ramStart + $size) -gt 0x0A00) {
    Fail-Check 'RAM body overlaps the selector trampoline or AP sector tray'
}

$image = Read-S19Memory
$routine = [byte[]]::new($size)
for ($i = 0; $i -lt $size; $i++) {
    $address = $sourceStart + $i
    if (-not $image.Present[$address]) {
        Fail-Check ('RAM body byte ${0:X4} is absent from the S19' -f $address)
    }
    $routine[$i] = $image.Memory[$address]
}

$banks = [byte[][]]::new(4)
for ($bank = 0; $bank -lt 4; $bank++) {
    $banks[$bank] = [byte[]]::new(0x8000)
    for ($offset = 0; $offset -lt 0x8000; $offset++) {
        $address = 0x8000 + $offset
        $banks[$bank][$offset] = [byte](
            (($bank * 0x41) + ($address -band 0xFF) +
                ((($address -shr 8) -band 0xFF) * 3)) -band 0xFF
        )
    }
}

$maxSteps = 0
foreach ($bank in 0..2) {
    foreach ($startHigh in @(0x8A, 0xC7, 0xFF)) {
        $initialStatus = if (($bank + $startHigh) -band 1) { 0x24 } else { 0x20 }
        $result = Invoke-RamStage -Routine $routine -Banks $banks `
            -Bank $bank -StartHigh $startHigh -InitialStatus $initialStatus
        if (($result.Status -band 0x01) -eq 0 -or $result.SelectedBank -ne 3) {
            Fail-Check "B$bank sector $($startHigh.ToString('X2')) did not restore Bank 3"
        }
        if (($result.Status -band 0x04) -ne ($initialStatus -band 0x04)) {
            Fail-Check "B$bank sector $($startHigh.ToString('X2')) changed interrupt state"
        }
        $sector = $startHigh -band 0xF0
        for ($i = 0; $i -lt 0x1000; $i++) {
            $expected = $banks[$bank][(($sector - 0x80) -shl 8) + $i]
            if ($result.Memory[0x0A00 + $i] -ne $expected) {
                Fail-Check ('B{0} sector ${1:X2} differs at +${2:X3}' -f `
                    $bank, $sector, $i)
            }
        }
        $maxSteps = [Math]::Max($maxSteps, $result.Steps)
    }
}

$failed = Invoke-RamStage -Routine $routine -Banks $banks -Bank 1 `
    -StartHigh 0xC2 -InitialStatus 0x20 -FailInitialSelect $true
if (($failed.Status -band 0x01) -ne 0 -or $failed.SelectedBank -ne 3) {
    Fail-Check 'initial selector failure did not fail closed in Bank 3'
}
for ($i = 0; $i -lt 0x1000; $i++) {
    if ($failed.Memory[0x0A00 + $i] -ne 0x5A) {
        Fail-Check 'initial selector failure changed the AP sector tray'
    }
}

$retried = Invoke-RamStage -Routine $routine -Banks $banks -Bank 2 `
    -StartHigh 0x91 -InitialStatus 0x24 -RestoreFailures 1
if (($retried.Status -band 0x01) -eq 0 -or $retried.SelectedBank -ne 3) {
    Fail-Check 'restore retry did not finish in Bank 3'
}
$maxSteps = [Math]::Max($maxSteps, $retried.Steps)

Write-Host (('HIMON banked AP check OK body=${0:X4}-${1:X4} ram=${2:X4} ' +
    'bytes=${3:X2} cases=11 max-steps={4}') -f `
    $sourceStart, ($sourceEnd - 1), $ramStart, $size, $maxSteps)

param(
    [string]$ConstantsPath = "STR8/str8-directory-eq.inc",
    [string]$BinPath = "BUILD/bin/himon-str8-v1-layout-preview.bin",
    [string]$Str8MapPath = "BUILD/s19/str8-v1-layout-f000.map"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EquValue([string]$Name) {
    $pattern = '^\s*' + [Regex]::Escape($Name) + '\s+EQU\s+\$([0-9A-Fa-f]+)\s*$'
    $match = Select-String -Path $ConstantsPath -Pattern $pattern | Select-Object -First 1
    if (-not $match) {
        throw "Constant $Name not found in $ConstantsPath"
    }
    return [Convert]::ToInt32($match.Matches[0].Groups[1].Value, 16)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-MapSymbols([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "V1 STR8 map not found: $Path"
    }
    $symbols = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([0-9A-Fa-f]{8})\s+(\S+)\s*$') {
            $symbols[$Matches[2].ToUpperInvariant()] = [Convert]::ToInt32($Matches[1], 16)
        }
    }
    return $symbols
}

function Get-MapSymbol([hashtable]$Symbols, [string]$Name) {
    $key = $Name.ToUpperInvariant()
    if (-not $Symbols.ContainsKey($key)) {
        throw "Resident directory symbol not found: $Name"
    }
    return [int]$Symbols[$key]
}

function Set-NzFlags([int]$Status, [int]$Value) {
    $statusOut = $Status -band 0x7D
    $byteValue = $Value -band 0xFF
    if ($byteValue -eq 0) { $statusOut = $statusOut -bor 0x02 }
    if (($byteValue -band 0x80) -ne 0) { $statusOut = $statusOut -bor 0x80 }
    return $statusOut
}

# Execute the compiled resident directory routines directly from the guarded
# V1 image. The optional worker hook models the mode-$07 boundary after the
# compiled writer has completed its own preflight. Unexpected opcodes fail the
# gate instead of being silently approximated.
function Invoke-ResidentDirectoryRoutine {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [byte]$A = 0,
        [byte]$X = 0,
        [byte]$Y = 0,
        [int]$WorkerHook = -1,
        [ValidateSet('None', 'Success', 'Fail', 'Corrupt')]
        [string]$WorkerBehavior = 'None',
        [int]$ReadHook = -1,
        [int]$WriteHook = -1,
        [byte[]]$InputBytes = @()
    )

    $pc = $Start
    $aReg = [int]$A
    $xReg = [int]$X
    $yReg = [int]$Y
    $status = 0
    $returns = New-Object System.Collections.Generic.Stack[int]
    $dataStack = New-Object System.Collections.Generic.Stack[int]
    $output = New-Object System.Collections.Generic.List[byte]
    $inputIndex = 0
    $workerCalls = 0

    for ($step = 0; $step -lt 16384; $step++) {
        $opcode = [int]$Memory[$pc]
        switch ($opcode) {
            0x05 { # ORA zero page
                $aReg = $aReg -bor [int]$Memory[[int]$Memory[$pc + 1]]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0x0A { # ASL A
                $status = $status -band 0xFE
                if (($aReg -band 0x80) -ne 0) { $status = $status -bor 0x01 }
                $aReg = ($aReg -shl 1) -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc++
                continue
            }
            0x10 { # BPL relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 0x80) -eq 0) { $pc += $offset }
                continue
            }
            0x18 { # CLC
                $status = $status -band 0xFE
                $pc++
                continue
            }
            0x20 { # JSR absolute
                $target = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                if ($target -eq $ReadHook) {
                    if ($inputIndex -ge $InputBytes.Length) {
                        throw ('Resident text input exhausted at ${0:X4}' -f $pc)
                    }
                    $aReg = [int]$InputBytes[$inputIndex++]
                    $status = Set-NzFlags $status $aReg
                    $status = $status -bor 0x01
                    $pc += 3
                    continue
                }
                if ($target -eq $WriteHook) {
                    $output.Add([byte]$aReg)
                    $status = $status -bor 0x01
                    $pc += 3
                    continue
                }
                if ($target -eq $WorkerHook) {
                    $workerCalls++
                    $recordAddress = ([int]$Memory[0x7E9E]) -bor (([int]$Memory[0x7E9F]) -shl 8)
                    $recordLength = [int]$Memory[0x7EA0]
                    if ($WorkerBehavior -eq 'Success' -or $WorkerBehavior -eq 'Corrupt') {
                        for ($i = 0; $i -lt $recordLength; $i++) {
                            $Memory[$recordAddress + $i] = $Memory[0x7B00 + $i]
                        }
                        if ($WorkerBehavior -eq 'Corrupt' -and $recordLength -gt 0) {
                            $last = $recordAddress + $recordLength - 1
                            $Memory[$last] = [byte](([int]$Memory[$last]) -bxor 0x01)
                        }
                        $status = $status -bor 0x01
                    } else {
                        $Memory[0x7EA5] = [byte]($recordAddress -band 0xFF)
                        $Memory[0x7EA6] = [byte](($recordAddress -shr 8) -band 0xFF)
                        $Memory[0x7EA7] = $Memory[$recordAddress]
                        $Memory[0x7EA8] = $Memory[0x7B00]
                        $status = $status -band 0xFE
                    }
                    $pc += 3
                    continue
                }
                $returns.Push($pc + 3)
                $pc = $target
                continue
            }
            0x30 { # BMI relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 0x80) -ne 0) { $pc += $offset }
                continue
            }
            0x29 { # AND immediate
                $aReg = $aReg -band [int]$Memory[$pc + 1]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0x31 { # AND (zero page),Y
                $zp = [int]$Memory[$pc + 1]
                $base = ([int]$Memory[$zp]) -bor (([int]$Memory[($zp + 1) -band 0xFF]) -shl 8)
                $aReg = $aReg -band [int]$Memory[($base + $yReg) -band 0xFFFF]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0x38 { # SEC
                $status = $status -bor 0x01
                $pc++
                continue
            }
            0x46 { # LSR zero page
                $address = [int]$Memory[$pc + 1]
                $value = [int]$Memory[$address]
                $status = $status -band 0xFE
                if (($value -band 1) -ne 0) { $status = $status -bor 0x01 }
                $value = ($value -shr 1) -band 0xFF
                $Memory[$address] = [byte]$value
                $status = Set-NzFlags $status $value
                $pc += 2
                continue
            }
            0x48 { # PHA
                $dataStack.Push($aReg)
                $pc++
                continue
            }
            0x4A { # LSR A
                $status = $status -band 0xFE
                if (($aReg -band 1) -ne 0) { $status = $status -bor 0x01 }
                $aReg = ($aReg -shr 1) -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc++
                continue
            }
            0x4C { # JMP absolute
                $target = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                if ($target -eq $WriteHook) {
                    $output.Add([byte]$aReg)
                    $status = $status -bor 0x01
                    if ($returns.Count -eq 0) {
                        return [pscustomobject]@{
                            A = [byte]$aReg
                            X = [byte]$xReg
                            Y = [byte]$yReg
                            Carry = $true
                            Steps = $step + 1
                            WorkerCalls = $workerCalls
                            InputConsumed = $inputIndex
                            Output = $output.ToArray()
                        }
                    }
                    $pc = $returns.Pop()
                    continue
                }
                $pc = $target
                continue
            }
            0x60 { # RTS
                if ($returns.Count -eq 0) {
                    return [pscustomobject]@{
                        A = [byte]$aReg
                        X = [byte]$xReg
                        Y = [byte]$yReg
                        Carry = (($status -band 1) -ne 0)
                        Steps = $step + 1
                        WorkerCalls = $workerCalls
                        InputConsumed = $inputIndex
                        Output = $output.ToArray()
                    }
                }
                $pc = $returns.Pop()
                continue
            }
            0x68 { # PLA
                if ($dataStack.Count -eq 0) { throw ('PLA underflow at ${0:X4}' -f $pc) }
                $aReg = $dataStack.Pop()
                $status = Set-NzFlags $status $aReg
                $pc++
                continue
            }
            0x64 { # STZ zero page
                $Memory[[int]$Memory[$pc + 1]] = 0
                $pc += 2
                continue
            }
            0x69 { # ADC immediate
                $value = [int]$Memory[$pc + 1]
                $sum = $aReg + $value + ($status -band 1)
                $status = $status -band 0xFE
                if ($sum -gt 0xFF) { $status = $status -bor 0x01 }
                $aReg = $sum -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0x6D { # ADC absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $sum = $aReg + [int]$Memory[$address] + ($status -band 1)
                $status = $status -band 0xFE
                if ($sum -gt 0xFF) { $status = $status -bor 0x01 }
                $aReg = $sum -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc += 3
                continue
            }
            0x80 { # BRA relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc = $pc + 2 + $offset
                continue
            }
            0x84 { # STY zero page
                $Memory[[int]$Memory[$pc + 1]] = [byte]$yReg
                $pc += 2
                continue
            }
            0x85 { # STA zero page
                $Memory[[int]$Memory[$pc + 1]] = [byte]$aReg
                $pc += 2
                continue
            }
            0x86 { # STX zero page
                $Memory[[int]$Memory[$pc + 1]] = [byte]$xReg
                $pc += 2
                continue
            }
            0x88 { # DEY
                $yReg = ($yReg - 1) -band 0xFF
                $status = Set-NzFlags $status $yReg
                $pc++
                continue
            }
            0x8A { # TXA
                $aReg = $xReg
                $status = Set-NzFlags $status $aReg
                $pc++
                continue
            }
            0x8D { # STA absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $Memory[$address] = [byte]$aReg
                $pc += 3
                continue
            }
            0x8E { # STX absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $Memory[$address] = [byte]$xReg
                $pc += 3
                continue
            }
            0x90 { # BCC relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 1) -eq 0) { $pc += $offset }
                continue
            }
            0x98 { # TYA
                $aReg = $yReg
                $status = Set-NzFlags $status $aReg
                $pc++
                continue
            }
            0x99 { # STA absolute,Y
                $address = (([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)) + $yReg
                $Memory[$address -band 0xFFFF] = [byte]$aReg
                $pc += 3
                continue
            }
            0x9C { # STZ absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $Memory[$address] = 0
                $pc += 3
                continue
            }
            0x9D { # STA absolute,X
                $address = (([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)) + $xReg
                $Memory[$address -band 0xFFFF] = [byte]$aReg
                $pc += 3
                continue
            }
            0x9E { # STZ absolute,X
                $address = (([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)) + $xReg
                $Memory[$address -band 0xFFFF] = 0
                $pc += 3
                continue
            }
            0xA0 { # LDY immediate
                $yReg = [int]$Memory[$pc + 1]
                $status = Set-NzFlags $status $yReg
                $pc += 2
                continue
            }
            0xA2 { # LDX immediate
                $xReg = [int]$Memory[$pc + 1]
                $status = Set-NzFlags $status $xReg
                $pc += 2
                continue
            }
            0xA5 { # LDA zero page
                $aReg = [int]$Memory[[int]$Memory[$pc + 1]]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0xA6 { # LDX zero page
                $xReg = [int]$Memory[[int]$Memory[$pc + 1]]
                $status = Set-NzFlags $status $xReg
                $pc += 2
                continue
            }
            0xA9 { # LDA immediate
                $aReg = [int]$Memory[$pc + 1]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0xAD { # LDA absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $aReg = [int]$Memory[$address]
                $status = Set-NzFlags $status $aReg
                $pc += 3
                continue
            }
            0xB0 { # BCS relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 1) -ne 0) { $pc += $offset }
                continue
            }
            0xB1 { # LDA (zero page),Y
                $zp = [int]$Memory[$pc + 1]
                $base = ([int]$Memory[$zp]) -bor (([int]$Memory[($zp + 1) -band 0xFF]) -shl 8)
                $aReg = [int]$Memory[($base + $yReg) -band 0xFFFF]
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0xBD { # LDA absolute,X
                $address = (([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)) + $xReg
                $aReg = [int]$Memory[$address -band 0xFFFF]
                $status = Set-NzFlags $status $aReg
                $pc += 3
                continue
            }
            0xC0 { # CPY immediate
                $value = [int]$Memory[$pc + 1]
                $difference = ($yReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($yReg -ge $value) { $status = $status -bor 0x01 }
                if ($yReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 2
                continue
            }
            0xC4 { # CPY zero page
                $value = [int]$Memory[[int]$Memory[$pc + 1]]
                $difference = ($yReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($yReg -ge $value) { $status = $status -bor 0x01 }
                if ($yReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 2
                continue
            }
            0xC6 { # DEC zero page
                $address = [int]$Memory[$pc + 1]
                $value = (([int]$Memory[$address]) - 1) -band 0xFF
                $Memory[$address] = [byte]$value
                $status = Set-NzFlags $status $value
                $pc += 2
                continue
            }
            0xC8 { # INY
                $yReg = ($yReg + 1) -band 0xFF
                $status = Set-NzFlags $status $yReg
                $pc++
                continue
            }
            0xC9 { # CMP immediate
                $value = [int]$Memory[$pc + 1]
                $difference = ($aReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($aReg -ge $value) { $status = $status -bor 0x01 }
                if ($aReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 2
                continue
            }
            0xCA { # DEX
                $xReg = ($xReg - 1) -band 0xFF
                $status = Set-NzFlags $status $xReg
                $pc++
                continue
            }
            0xD0 { # BNE relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 2) -eq 0) { $pc += $offset }
                continue
            }
            0xD1 { # CMP (zero page),Y
                $zp = [int]$Memory[$pc + 1]
                $base = ([int]$Memory[$zp]) -bor (([int]$Memory[($zp + 1) -band 0xFF]) -shl 8)
                $value = [int]$Memory[($base + $yReg) -band 0xFFFF]
                $difference = ($aReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($aReg -ge $value) { $status = $status -bor 0x01 }
                if ($aReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 2
                continue
            }
            0xD8 { # CLD
                $status = $status -band 0xF7
                $pc++
                continue
            }
            0xE0 { # CPX immediate
                $value = [int]$Memory[$pc + 1]
                $difference = ($xReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($xReg -ge $value) { $status = $status -bor 0x01 }
                if ($xReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 2
                continue
            }
            0xE8 { # INX
                $xReg = ($xReg + 1) -band 0xFF
                $status = Set-NzFlags $status $xReg
                $pc++
                continue
            }
            0xE9 { # SBC immediate
                $value = [int]$Memory[$pc + 1]
                $difference = $aReg - $value - $(if (($status -band 1) -ne 0) { 0 } else { 1 })
                $status = $status -band 0xFE
                if ($difference -ge 0) { $status = $status -bor 0x01 }
                $aReg = $difference -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc += 2
                continue
            }
            0xE6 { # INC zero page
                $address = [int]$Memory[$pc + 1]
                $value = (([int]$Memory[$address]) + 1) -band 0xFF
                $Memory[$address] = [byte]$value
                $status = Set-NzFlags $status $value
                $pc += 2
                continue
            }
            0xEE { # INC absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $value = (([int]$Memory[$address]) + 1) -band 0xFF
                $Memory[$address] = [byte]$value
                $status = Set-NzFlags $status $value
                $pc += 3
                continue
            }
            0xF0 { # BEQ relative
                $offset = [int]$Memory[$pc + 1]
                if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2
                if (($status -band 2) -ne 0) { $pc += $offset }
                continue
            }
            default {
                throw ('Unsupported resident directory opcode ${0:X2} at ${1:X4}' -f $opcode, $pc)
            }
        }
    }
    throw ('Resident directory routine did not return from ${0:X4}' -f $Start)
}

$dirBase = Get-EquValue "STR8_DIR_BASE"
$dirEnd = Get-EquValue "STR8_DIR_END"
$recordSize = Get-EquValue "STR8_DIR_RECORD_SIZE"
$recordCount = Get-EquValue "STR8_DIR_RECORD_COUNT"
$offType = Get-EquValue "STR8_DIR_TYPE"
$offReserved = Get-EquValue "STR8_DIR_RESERVED"
$reservedLength = Get-EquValue "STR8_DIR_RESERVED_LEN"
$offDescription = Get-EquValue "STR8_DIR_DESCRIPTION"
$descriptionLength = Get-EquValue "STR8_DIR_DESCRIPTION_LEN"
$offSeal = Get-EquValue "STR8_DIR_SEAL"
$offEntryLo = Get-EquValue "STR8_DIR_ENTRY_LO"
$offEntryHi = Get-EquValue "STR8_DIR_ENTRY_HI"
$offJournal = Get-EquValue "STR8_DIR_JOURNAL"
$journalLength = Get-EquValue "STR8_DIR_JOURNAL_LEN"
$emptyByte = Get-EquValue "STR8_DIR_EMPTY_BYTE"
$sealValue = Get-EquValue "STR8_DIR_SEAL_VALUE"
$bank3 = Get-EquValue "STR8_DIR_BANK3"
$bank3EntryMinHi = Get-EquValue "STR8_DIR_BANK3_ENTRY_MIN_HI"
$bank3EntryMaxHi = Get-EquValue "STR8_DIR_BANK3_ENTRY_MAX_HI"
$pairComplete = Get-EquValue "STR8_DIR_PAIR_COMPLETE"
$pairIllegal = Get-EquValue "STR8_DIR_PAIR_ILLEGAL"
$pairStarted = Get-EquValue "STR8_DIR_PAIR_STARTED"
$pairUnused = Get-EquValue "STR8_DIR_PAIR_UNUSED"
$pairNone = Get-EquValue "STR8_DIR_PAIR_NONE"
$journalInvalid = Get-EquValue "STR8_DIR_JOURNAL_INVALID"
$journalFresh = Get-EquValue "STR8_DIR_JOURNAL_FRESH"
$journalStarted = Get-EquValue "STR8_DIR_JOURNAL_STARTED"
$journalComplete = Get-EquValue "STR8_DIR_JOURNAL_COMPLETE"
$journalFull = Get-EquValue "STR8_DIR_JOURNAL_FULL"
$recordInvalid = Get-EquValue "STR8_DIR_RECORD_INVALID"
$recordEmpty = Get-EquValue "STR8_DIR_RECORD_EMPTY"
$recordIncomplete = Get-EquValue "STR8_DIR_RECORD_INCOMPLETE"
$recordComplete = Get-EquValue "STR8_DIR_RECORD_COMPLETE"
$writeOk = Get-EquValue "STR8_DIR_WRITE_OK"
$writeBadCount = Get-EquValue "STR8_DIR_WRITE_BAD_COUNT"
$writeBadRange = Get-EquValue "STR8_DIR_WRITE_BAD_RANGE"
$writeBadTransition = Get-EquValue "STR8_DIR_WRITE_BAD_TRANS"
$writeWorker = Get-EquValue "STR8_DIR_WRITE_WORKER"
$writeVerify = Get-EquValue "STR8_DIR_WRITE_VERIFY"

Assert-True ($dirBase -eq 0xFFB0) "Directory base must be FFB0"
Assert-True ($dirEnd -eq 0xFFEF) "Directory end must be FFEF"
Assert-True ($recordSize -eq 0x10 -and $recordCount -eq 4) "Directory must contain four 16-byte records"
Assert-True (($dirBase + ($recordSize * $recordCount) - 1) -eq $dirEnd) "Directory span does not match its record geometry"
Assert-True ($offType -eq 0 -and $offReserved -eq 1 -and $reservedLength -eq 3) "TYPE/RESERVED layout mismatch"
Assert-True ($offDescription -eq 4 -and $descriptionLength -eq 5) "DESCRIPTION layout mismatch"
Assert-True ($offSeal -eq 9 -and $offEntryLo -eq 0x0A -and $offEntryHi -eq 0x0B) "SEAL/ENTRY layout mismatch"
Assert-True ($offJournal -eq 0x0C -and $journalLength -eq 4) "JOURNAL layout mismatch"
Assert-True ($bank3 -eq 3 -and $bank3EntryMinHi -eq 0x80 -and $bank3EntryMaxHi -eq 0xEF) "Bank-3 LOCAL ENTRY policy mismatch"
Assert-True ($pairComplete -eq 0 -and $pairIllegal -eq 1 -and $pairStarted -eq 2 -and $pairUnused -eq 3) "Journal pair encoding mismatch"
Assert-True ($writeOk -eq 0 -and $writeBadCount -eq 1 -and $writeBadRange -eq 2) "Directory writer count/range status mismatch"
Assert-True ($writeBadTransition -eq 3 -and $writeWorker -eq 4 -and $writeVerify -eq 5) "Directory writer failure status mismatch"

# Exhaust the independent electrical transition rule across all byte pairs.
$legalByteTransitions = 0
$illegalByteTransitions = 0
for ($oldByte = 0; $oldByte -le 0xFF; $oldByte++) {
    for ($newByte = 0; $newByte -le 0xFF; $newByte++) {
        if (($oldByte -band $newByte) -eq $newByte) {
            $legalByteTransitions++
        } else {
            $illegalByteTransitions++
        }
    }
}
Assert-True ($legalByteTransitions -eq 6561) "One-to-zero legal byte-pair count changed"
Assert-True ($illegalByteTransitions -eq 58975) "One-to-zero illegal byte-pair count changed"

function New-Journal([int]$Completed, [bool]$Started) {
    if ($Completed -lt 0 -or $Completed -gt 16 -or ($Started -and $Completed -ge 16)) {
        throw "Invalid journal fixture request completed=$Completed started=$Started"
    }
    [int[]]$pairs = @(3) * 16
    for ($i = 0; $i -lt $Completed; $i++) {
        $pairs[$i] = 0
    }
    if ($Started) {
        $pairs[$Completed] = 2
    }
    return Convert-PairsToJournal $pairs
}

function Convert-PairsToJournal([int[]]$Pairs) {
    Assert-True ($Pairs.Count -eq 16) "Journal fixture must contain 16 pairs"
    [byte[]]$bytes = New-Object byte[] 4
    for ($i = 0; $i -lt 16; $i++) {
        $byteIndex = [Math]::Floor($i / 4)
        $shift = ($i % 4) * 2
        $bytes[$byteIndex] = [byte]($bytes[$byteIndex] -bor (($Pairs[$i] -band 3) -shl $shift))
    }
    return $bytes
}

function Get-JournalResult([byte[]]$Bytes) {
    if ($Bytes.Length -ne 4) {
        throw "Journal must be exactly four bytes"
    }
    $completed = 0
    $openState = 0
    $nextPair = 0
    for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
        $pair = ($Bytes[[Math]::Floor($pairIndex / 4)] -shr (($pairIndex % 4) * 2)) -band 3
        if ($openState -eq 0) {
            switch ($pair) {
                0 { $completed++; continue }
                1 { return [pscustomobject]@{ State = $journalInvalid; Pair = $pairNone } }
                2 { $openState = $journalStarted; $nextPair = $pairIndex; continue }
                3 {
                    $openState = $(if ($completed -eq 0) { $journalFresh } else { $journalComplete })
                    $nextPair = $pairIndex
                    continue
                }
            }
        } elseif ($pair -ne 3) {
            return [pscustomobject]@{ State = $journalInvalid; Pair = $pairNone }
        }
    }
    if ($openState -eq 0) {
        return [pscustomobject]@{ State = $journalFull; Pair = $pairNone }
    }
    return [pscustomobject]@{ State = $openState; Pair = $nextPair }
}

function Test-DescriptionByte([int]$Value) {
    return (($Value -ge [byte][char]'A' -and $Value -le [byte][char]'Z') -or
        ($Value -ge [byte][char]'0' -and $Value -le [byte][char]'9') -or
        $Value -eq [byte][char]'-' -or $Value -eq [byte][char]'_' -or $Value -eq [byte][char]'.')
}

function Get-RecordResult([int]$Bank, [byte[]]$Record) {
    if ($Bank -lt 0 -or $Bank -ge $recordCount -or $Record.Length -ne $recordSize) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "geometry" }
    }
    $nonEmpty = @($Record | Where-Object { $_ -ne $emptyByte }).Count
    if ($nonEmpty -eq 0) {
        return [pscustomobject]@{ State = $recordEmpty; Pair = 0; Reason = "empty" }
    }
    for ($i = 0; $i -lt $reservedLength; $i++) {
        if ($Record[$offReserved + $i] -ne $emptyByte) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "reserved" }
        }
    }
    for ($i = 0; $i -lt $descriptionLength; $i++) {
        if (-not (Test-DescriptionByte $Record[$offDescription + $i])) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "description" }
        }
    }
    if ($Record[$offSeal] -ne $sealValue) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "seal" }
    }
    $entry = ([int]$Record[$offEntryLo]) -bor (([int]$Record[$offEntryHi]) -shl 8)
    if ($Bank -lt 3) {
        if ($entry -ne 0xFFFF) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "entry" }
        }
    } elseif ($entry -ne 0xFFFF -and ($entry -lt 0x8000 -or $entry -gt 0xEFFF)) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "entry" }
    }
    [byte[]]$journal = $Record[$offJournal..($offJournal + $journalLength - 1)]
    $journalResult = Get-JournalResult $journal
    if ($journalResult.State -eq $journalInvalid -or $journalResult.State -eq $journalFresh) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "journal" }
    }
    if ($journalResult.State -eq $journalStarted) {
        return [pscustomobject]@{ State = $recordIncomplete; Pair = $journalResult.Pair; Reason = "started" }
    }
    return [pscustomobject]@{ State = $recordComplete; Pair = $journalResult.Pair; Reason = "complete" }
}

function New-Record([int]$Bank, [string]$Description, [int]$Entry, [byte[]]$Journal) {
    [byte[]]$record = New-Object byte[] $recordSize
    for ($i = 0; $i -lt $record.Length; $i++) {
        $record[$i] = $emptyByte
    }
    $record[$offType] = 0x5A
    [byte[]]$descriptionBytes = [System.Text.Encoding]::ASCII.GetBytes($Description)
    Assert-True ($descriptionBytes.Length -eq $descriptionLength) "Description fixture must be exactly five bytes"
    [Array]::Copy($descriptionBytes, 0, $record, $offDescription, $descriptionLength)
    $record[$offSeal] = $sealValue
    $record[$offEntryLo] = [byte]($Entry -band 0xFF)
    $record[$offEntryHi] = [byte](($Entry -shr 8) -band 0xFF)
    [Array]::Copy($Journal, 0, $record, $offJournal, $journalLength)
    return $record
}

function Assert-ResidentJournalResult([byte[]]$Journal) {
    $expected = Get-JournalResult $Journal
    [byte[]]$memory = $script:residentTemplate.Clone()
    for ($i = 0; $i -lt $script:recordSize; $i++) {
        $memory[$script:dirBase + $i] = [byte]$script:emptyByte
    }
    [Array]::Copy($Journal, 0, $memory, $script:dirBase + $script:offJournal, $script:journalLength)
    $memory[$script:residentPtrLo] = [byte]($script:dirBase -band 0xFF)
    $memory[$script:residentPtrHi] = [byte](($script:dirBase -shr 8) -band 0xFF)
    $actual = Invoke-ResidentDirectoryRoutine -Memory $memory -Start $script:residentJournalEntry
    $expectedCarry = $expected.State -ne $script:journalInvalid
    if ($actual.A -ne $expected.State -or $actual.X -ne $expected.Pair -or $actual.Carry -ne $expectedCarry) {
        throw ('Resident journal mismatch bytes={0}: got A/X/C={1:X2}/{2:X2}/{3}, expected {4:X2}/{5:X2}/{6}' -f `
            (($Journal | ForEach-Object { '{0:X2}' -f $_ }) -join ' '),
            $actual.A, $actual.X, [int]$actual.Carry,
            $expected.State, $expected.Pair, [int]$expectedCarry)
    }
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $actual.Steps)
    $script:residentJournalCases++
}

function Assert-ResidentRecordResult([int]$Bank, [byte[]]$Record) {
    $expected = Get-RecordResult $Bank $Record
    [byte[]]$memory = $script:residentTemplate.Clone()
    if ($Bank -ge 0 -and $Bank -lt $script:recordCount) {
        $recordAddress = $script:dirBase + ($Bank * $script:recordSize)
        [Array]::Copy($Record, 0, $memory, $recordAddress, $script:recordSize)
    }
    $actual = Invoke-ResidentDirectoryRoutine -Memory $memory -Start $script:residentRecordEntry -A ([byte]$Bank)
    $expectedCarry = $expected.State -ne $script:recordInvalid
    if ($actual.A -ne $expected.State -or $actual.X -ne $expected.Pair -or $actual.Carry -ne $expectedCarry) {
        throw ('Resident record mismatch bank={0} reason={1}: got A/X/C={2:X2}/{3:X2}/{4}, expected {5:X2}/{6:X2}/{7}' -f `
            $Bank, $expected.Reason,
            $actual.A, $actual.X, [int]$actual.Carry,
            $expected.State, $expected.Pair, [int]$expectedCarry)
    }
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $actual.Steps)
    $script:residentRecordCases++
}

function Invoke-ResidentWriterFixture {
    param(
        [int]$Address,
        [byte[]]$OldBytes,
        [byte[]]$DesiredBytes,
        [ValidateSet('Success', 'Fail', 'Corrupt')]
        [string]$WorkerBehavior = 'Success'
    )

    [byte[]]$memory = $script:residentTemplate.Clone()
    for ($i = 0; $i -lt $OldBytes.Length; $i++) {
        $target = $Address + $i
        if ($target -ge $script:dirBase -and $target -le $script:dirEnd) {
            $memory[$target] = $OldBytes[$i]
        }
    }
    for ($i = 0; $i -lt $DesiredBytes.Length; $i++) {
        $memory[$script:residentDataBuffer + $i] = $DesiredBytes[$i]
    }
    $memory[$script:residentAddressLo] = [byte]($Address -band 0xFF)
    $memory[$script:residentAddressHi] = [byte](($Address -shr 8) -band 0xFF)
    $memory[$script:residentDataLength] = [byte]$DesiredBytes.Length
    [byte[]]$before = $memory[$script:dirBase..$script:dirEnd]
    $result = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $script:residentWriterEntry `
        -WorkerHook $script:residentWorkerHook `
        -WorkerBehavior $WorkerBehavior
    [byte[]]$after = $memory[$script:dirBase..$script:dirEnd]
    return [pscustomobject]@{
        Cpu = $result
        Memory = $memory
        Before = $before
        After = $after
        Status = [int]$memory[$script:residentStatus]
        FailAddress = ([int]$memory[$script:residentFailLo]) -bor (([int]$memory[$script:residentFailHi]) -shl 8)
        Observed = [int]$memory[$script:residentObserved]
        Expected = [int]$memory[$script:residentExpected]
    }
}

function Assert-ResidentWriterStatus {
    param(
        [pscustomobject]$Fixture,
        [int]$ExpectedStatus,
        [bool]$ExpectedCarry,
        [int]$ExpectedWorkerCalls,
        [string]$Name
    )

    if ($Fixture.Cpu.A -ne $ExpectedStatus -or
        $Fixture.Status -ne $ExpectedStatus -or
        $Fixture.Cpu.Carry -ne $ExpectedCarry -or
        $Fixture.Cpu.WorkerCalls -ne $ExpectedWorkerCalls) {
        throw ('Resident writer {0}: got A/S/C/W={1:X2}/{2:X2}/{3}/{4}, expected {5:X2}/{5:X2}/{6}/{7}' -f `
            $Name, $Fixture.Cpu.A, $Fixture.Status, [int]$Fixture.Cpu.Carry,
            $Fixture.Cpu.WorkerCalls, $ExpectedStatus, [int]$ExpectedCarry,
            $ExpectedWorkerCalls)
    }
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $Fixture.Cpu.Steps)
    $script:residentWriterCases++
}

function Assert-ByteArraysEqual([byte[]]$Actual, [byte[]]$Expected, [string]$Message) {
    if ($Actual.Length -ne $Expected.Length) { throw $Message }
    for ($i = 0; $i -lt $Actual.Length; $i++) {
        if ($Actual[$i] -ne $Expected[$i]) {
            throw ('{0} at +${1:X}: got ${2:X2}, expected ${3:X2}' -f $Message, $i, $Actual[$i], $Expected[$i])
        }
    }
}

function Invoke-ResidentLineFixture {
    param(
        [byte[]]$InputBytes,
        [int]$Limit,
        [int]$PendingLf = 0,
        [byte[]]$Memory = $null
    )

    if ($null -eq $Memory) {
        [byte[]]$Memory = $script:residentTemplate.Clone()
    }
    $Memory[$script:residentSkipLf] = [byte]$PendingLf
    $cpu = Invoke-ResidentDirectoryRoutine -Memory $Memory `
        -Start $script:residentLineEntry `
        -X ([byte]$Limit) `
        -ReadHook $script:residentReadHook `
        -WriteHook $script:residentWriteHook `
        -InputBytes $InputBytes
    return [pscustomobject]@{
        Cpu = $cpu
        Memory = $Memory
        Text = [System.Text.Encoding]::ASCII.GetString($Memory, $script:residentDataBuffer, [int]$cpu.A)
        Output = $cpu.Output
        PendingLf = [int]$Memory[$script:residentSkipLf]
    }
}

function Assert-ResidentLineFixture {
    param(
        [byte[]]$InputBytes,
        [int]$Limit,
        [string]$ExpectedText,
        [byte[]]$ExpectedOutput,
        [int]$ExpectedPendingLf,
        [string]$Name
    )

    $fixture = Invoke-ResidentLineFixture $InputBytes $Limit
    if ($fixture.Cpu.A -ne $ExpectedText.Length -or
        $fixture.Text -cne $ExpectedText -or
        $fixture.Memory[$script:residentDataBuffer + $ExpectedText.Length] -ne 0 -or
        $fixture.PendingLf -ne $ExpectedPendingLf -or
        $fixture.Cpu.InputConsumed -ne $InputBytes.Length) {
        throw ('Resident line editor {0}: got len/text/pending/consumed={1}/{2}/{3}/{4}' -f `
            $Name, $fixture.Cpu.A, $fixture.Text, $fixture.PendingLf, $fixture.Cpu.InputConsumed)
    }
    Assert-ByteArraysEqual $fixture.Output $ExpectedOutput ("Resident line editor $Name echo mismatch")
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $fixture.Cpu.Steps)
    $script:residentLineCases++
}

function Invoke-ResidentIPreviewFixture {
    param(
        [byte[]]$InputBytes,
        [hashtable]$Records = @{}
    )

    [byte[]]$memory = $script:residentTemplate.Clone()
    $memory[$script:residentDataBuffer + 1] = 0
    foreach ($bankKey in $Records.Keys) {
        $recordAddress = $script:dirBase + ([int]$bankKey * $script:recordSize)
        [byte[]]$record = $Records[$bankKey]
        [Array]::Copy($record, 0, $memory, $recordAddress, $script:recordSize)
    }
    [byte[]]$beforeDirectory = $memory[$script:dirBase..$script:dirEnd]
    $cpu = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $script:residentInstallPreviewEntry `
        -WorkerHook $script:residentWorkerHook `
        -WorkerBehavior 'Fail' `
        -ReadHook $script:residentReadHook `
        -WriteHook $script:residentWriteHook `
        -InputBytes $InputBytes
    return [pscustomobject]@{
        Cpu = $cpu
        Memory = $memory
        BeforeDirectory = $beforeDirectory
        AfterDirectory = [byte[]]($memory[$script:dirBase..$script:dirEnd])
    }
}

function Assert-ResidentIPreviewFixture {
    param(
        [pscustomobject]$Fixture,
        [byte[]]$InputBytes,
        [string]$ExpectedOutput,
        [string]$Name
    )

    [byte[]]$expectedBytes = [System.Text.Encoding]::ASCII.GetBytes($ExpectedOutput)
    Assert-ByteArraysEqual $Fixture.Cpu.Output $expectedBytes ("Resident I preview $Name output mismatch")
    Assert-ByteArraysEqual $Fixture.AfterDirectory $Fixture.BeforeDirectory ("Resident I preview $Name mutated directory")
    Assert-True ($Fixture.Cpu.WorkerCalls -eq 0 -and $Fixture.Cpu.InputConsumed -eq $InputBytes.Length) `
        ("Resident I preview $Name reached a worker or left input unread")
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $Fixture.Cpu.Steps)
    $script:residentLineCases++
}

$legalJournalCases = 0
$result = Get-JournalResult (New-Journal 0 $false)
Assert-True ($result.State -eq $journalFresh -and $result.Pair -eq 0) "Fresh journal rejected"
$legalJournalCases++
for ($completed = 0; $completed -lt 16; $completed++) {
    $result = Get-JournalResult (New-Journal $completed $true)
    Assert-True ($result.State -eq $journalStarted -and $result.Pair -eq $completed) "Started journal $completed rejected"
    $legalJournalCases++
}
for ($completed = 1; $completed -lt 16; $completed++) {
    $result = Get-JournalResult (New-Journal $completed $false)
    Assert-True ($result.State -eq $journalComplete -and $result.Pair -eq $completed) "Complete journal $completed rejected"
    $legalJournalCases++
}
$result = Get-JournalResult (New-Journal 16 $false)
Assert-True ($result.State -eq $journalFull -and $result.Pair -eq $pairNone) "Full journal rejected"
$legalJournalCases++

$illegalJournalCases = 0
for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 1
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Illegal 01 pair $pairIndex accepted"
    $illegalJournalCases++
}
for ($pairIndex = 1; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 0
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Journal hole at pair $pairIndex accepted"
    $illegalJournalCases++
}
for ($pairIndex = 0; $pairIndex -lt 15; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 2
    $pairs[$pairIndex + 1] = 0
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Completion after START at pair $pairIndex accepted"
    $illegalJournalCases++
    $pairs[$pairIndex + 1] = 2
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Second START after pair $pairIndex accepted"
    $illegalJournalCases++
}

$recordCases = 0
for ($bank = 0; $bank -lt 3; $bank++) {
    $record = New-Record $bank "STR8N" 0xFFFF (New-Journal 1 $false)
    $result = Get-RecordResult $bank $record
    Assert-True ($result.State -eq $recordComplete -and $result.Pair -eq 1) ("Bank {0} complete record rejected: state={1} pair={2} reason={3}" -f $bank, $result.State, $result.Pair, $result.Reason)
    $recordCases++
}
foreach ($entry in @(0x8000, 0xEFFF, 0xFFFF)) {
    $record = New-Record 3 "A0-_." $entry (New-Journal 1 $false)
    $result = Get-RecordResult 3 $record
    Assert-True ($result.State -eq $recordComplete) ("Bank 3 entry {0:X4} rejected" -f $entry)
    $recordCases++
}
$record = New-Record 3 "STR8N" 0x8000 (New-Journal 5 $true)
$result = Get-RecordResult 3 $record
Assert-True ($result.State -eq $recordIncomplete -and $result.Pair -eq 5) "Incomplete record rejected"
$recordCases++
$record = New-Record 0 "STR8N" 0xFFFF (New-Journal 16 $false)
$result = Get-RecordResult 0 $record
Assert-True ($result.State -eq $recordComplete -and $result.Pair -eq $pairNone) "Exhausted complete record rejected"
$recordCases++

$goodRecord = New-Record 0 "STR8N" 0xFFFF (New-Journal 1 $false)
for ($i = 0; $i -lt $reservedLength; $i++) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offReserved + $i] = 0xFE
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) "Programmed reserved byte accepted"
    $recordCases++
}
foreach ($badCharacter in @([byte][char]'a', [byte][char]' ', [byte][char]'/', 0x7F, 0xFF)) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offDescription] = $badCharacter
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bad description byte {0:X2} accepted" -f $badCharacter)
    $recordCases++
}
foreach ($badSeal in @(0xFF, 0xFC, 0xA5, 0x00)) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offSeal] = $badSeal
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bad seal {0:X2} accepted" -f $badSeal)
    $recordCases++
}
foreach ($entry in @(0x0000, 0x8000, 0xFFFE)) {
    $bad = New-Record 0 "STR8N" $entry (New-Journal 1 $false)
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bank 0 entry {0:X4} accepted" -f $entry)
    $recordCases++
}
foreach ($entry in @(0x7FFF, 0xF000, 0xFF00)) {
    $bad = New-Record 3 "STR8N" $entry (New-Journal 1 $false)
    Assert-True ((Get-RecordResult 3 $bad).State -eq $recordInvalid) ("Bank 3 entry {0:X4} accepted" -f $entry)
    $recordCases++
}
$bad = New-Record 0 "STR8N" 0xFFFF (New-Journal 0 $false)
Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) "Sealed record with fresh journal accepted"
$recordCases++
[byte[]]$partial = New-Object byte[] $recordSize
for ($i = 0; $i -lt $partial.Length; $i++) { $partial[$i] = $emptyByte }
[Array]::Copy((New-Journal 0 $true), 0, $partial, $offJournal, $journalLength)
Assert-True ((Get-RecordResult 0 $partial).State -eq $recordInvalid) "Partial first-install descriptor accepted"
$recordCases++

if (-not (Test-Path -LiteralPath $BinPath)) {
    throw "V1 preview BIN not found: $BinPath"
}
[byte[]]$bin = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $BinPath).Path)
Assert-True ($bin.Length -eq 0x8000) "V1 preview BIN must be exactly 32K"
$residentSymbols = Read-MapSymbols $Str8MapPath
$residentRecordEntry = Get-MapSymbol $residentSymbols "STR8_DIR_VALIDATE_BANK_A"
$residentJournalEntry = Get-MapSymbol $residentSymbols "STR8_DIR_SCAN_JOURNAL"
$residentWriterEntry = Get-MapSymbol $residentSymbols "STR8_DIR_WRITE_BYTES"
$residentLineEntry = Get-MapSymbol $residentSymbols "STR8_READ_LINE"
$residentInstallPreviewEntry = Get-MapSymbol $residentSymbols "STR8_CMD_INSTALL_PREVIEW"
$residentDispatchEntry = Get-MapSymbol $residentSymbols "STR8_DISPATCH_A"
$residentConfirmEntry = Get-MapSymbol $residentSymbols "STR8_CONFIRM_Y"
$residentReadHook = Get-MapSymbol $residentSymbols "STR8_CON_READ_BYTE_BLOCK"
$residentWriteHook = Get-MapSymbol $residentSymbols "STR8_CON_WRITE_BYTE_BLOCK"
$residentSkipLf = Get-MapSymbol $residentSymbols "STR8_INPUT_SKIP_LF"
$residentInstallBank = Get-MapSymbol $residentSymbols "STR8_INSTALL_BANK"
$residentInstallType = Get-MapSymbol $residentSymbols "STR8_INSTALL_TYPE"
$residentInstallDesc = Get-MapSymbol $residentSymbols "STR8_INSTALL_DESC"
$residentInstallState = Get-MapSymbol $residentSymbols "STR8_INSTALL_STATE"
$residentInstallPair = Get-MapSymbol $residentSymbols "STR8_INSTALL_PAIR"
$residentInstallEntryLo = Get-MapSymbol $residentSymbols "STR8_INSTALL_ENTRY_LO"
$residentInstallEntryHi = Get-MapSymbol $residentSymbols "STR8_INSTALL_ENTRY_HI"
$residentScreen = Get-MapSymbol $residentSymbols "MSG_SCREEN"
$residentHelp = Get-MapSymbol $residentSymbols "MSG_HELP"
$residentWorkerHook = Get-MapSymbol $residentSymbols "STR8_RUN_PROGRAM_RECORD_WORKER"
$residentWriterEnd = Get-MapSymbol $residentSymbols "STR8_RECORD_SERVICE_BODY"
$residentValidatorEnd = $residentWriterEntry
$residentPtrLo = Get-MapSymbol $residentSymbols "STR8_PTR_LO"
$residentPtrHi = Get-MapSymbol $residentSymbols "STR8_PTR_HI"
$residentStatus = Get-MapSymbol $residentSymbols "STR8_REC_STATUS"
$residentAddressLo = Get-MapSymbol $residentSymbols "STR8_REC_ADDR_LO"
$residentAddressHi = Get-MapSymbol $residentSymbols "STR8_REC_ADDR_HI"
$residentDataLength = Get-MapSymbol $residentSymbols "STR8_REC_DATA_LEN"
$residentFailLo = Get-MapSymbol $residentSymbols "STR8_REC_FAIL_LO"
$residentFailHi = Get-MapSymbol $residentSymbols "STR8_REC_FAIL_HI"
$residentObserved = Get-MapSymbol $residentSymbols "STR8_REC_OBSERVED"
$residentExpected = Get-MapSymbol $residentSymbols "STR8_REC_EXPECTED"
$residentDataBuffer = Get-MapSymbol $residentSymbols "STR8_REC_DATA_BUF"
$residentValidatorSize = $residentValidatorEnd - $residentRecordEntry
$residentWriterSize = $residentWriterEnd - $residentWriterEntry
Assert-True ($residentValidatorSize -gt 0 -and $residentValidatorSize -le 0x0140) `
    ("Resident validator size is `${0:X}; expected 1-140" -f $residentValidatorSize)
Assert-True ($residentWriterSize -gt 0 -and $residentWriterSize -le 0x00B0) `
    ("Resident writer size is `${0:X}; expected 1-B0" -f $residentWriterSize)
foreach ($retiredName in @(
        'STR8_CMD_UPDATE_HIMON', 'STR8_CMD_G_HIMON', 'STR8_CMD_COPY_FAIL',
        'STR8_UPD_INIT', 'STR8_READ_HIMON_S19', 'STR8_PROGRAM_HIMON_UPDATE',
        'STR8_PRINT_COPY_FAIL', 'MSG_UPDATE_HIMON', 'MSG_G_HIMON',
        'STR8_CMD_ID', 'MSG_UNKNOWN'
    )) {
    Assert-True (-not $residentSymbols.ContainsKey($retiredName)) "Retired V1 U/G symbol remains: $retiredName"
}
[byte[]]$residentTemplate = New-Object byte[] 65536
[Array]::Copy($bin, 0, $residentTemplate, 0x8000, $bin.Length)
[byte[]]$expectedV1Help = [System.Text.Encoding]::ASCII.GetBytes('I J0 J1 J2 J3 R')
for ($i = 0; $i -lt $expectedV1Help.Length; $i++) {
    Assert-True ($residentTemplate[$residentScreen + $i] -eq $expectedV1Help[$i]) 'V1 prompt does not publish only I/J0-J3/R'
}
Assert-True ($residentHelp -eq $residentScreen) 'V1 screen/help command list unexpectedly has a prefix'
$residentJournalCases = 0
$residentRecordCases = 0
$residentWriterCases = 0
$residentLineCases = 0
$residentMaxSteps = 0

foreach ($unknownCommand in @('?', 'X')) {
    [byte[]]$memory = $residentTemplate.Clone()
    $unknown = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $residentDispatchEntry `
        -A ([byte][char]$unknownCommand) `
        -WriteHook $residentWriteHook
    [byte[]]$expectedUnknown = [System.Text.Encoding]::ASCII.GetBytes("`r`nI J0 J1 J2 J3 R`r`n")
    Assert-ByteArraysEqual $unknown.Output $expectedUnknown ("Unknown command {0} help mismatch" -f $unknownCommand)
    Assert-True ($unknown.WorkerCalls -eq 0) ("Unknown command {0} reached worker" -f $unknownCommand)
    $residentMaxSteps = [Math]::Max($residentMaxSteps, $unknown.Steps)
    $residentLineCases++
}

[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("ab1-_`r")
[byte[]]$lineEcho = [System.Text.Encoding]::ASCII.GetBytes('AB1-_')
Assert-ResidentLineFixture $lineInput 5 'AB1-_' $lineEcho 1 'uppercase CR'

[byte[]]$lineInput = @([byte][char]'a', [byte][char]'b', 0x08, [byte][char]'c', 0x0D)
[byte[]]$lineEcho = @([byte][char]'A', [byte][char]'B', 0x08, 0x20, 0x08, [byte][char]'C')
Assert-ResidentLineFixture $lineInput 5 'AC' $lineEcho 1 'backspace'

[byte[]]$lineInput = @([byte][char]'a', [byte][char]'b', 0x7F, [byte][char]'d', 0x0A)
[byte[]]$lineEcho = @([byte][char]'A', [byte][char]'B', 0x08, 0x20, 0x08, [byte][char]'D')
Assert-ResidentLineFixture $lineInput 5 'AD' $lineEcho 0 'delete'

[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("abc`n")
[byte[]]$lineEcho = [System.Text.Encoding]::ASCII.GetBytes('AB')
Assert-ResidentLineFixture $lineInput 2 'AB' $lineEcho 0 'limit'

Assert-ResidentLineFixture ([byte[]]@(0x0D)) 5 '' ([byte[]]@()) 1 'empty CR'

$fixture = Invoke-ResidentLineFixture ([byte[]]@(0x0A, [byte][char]'x', 0x0A)) 5 1
if ($fixture.Cpu.A -ne 1 -or $fixture.Text -cne 'X' -or
    $fixture.PendingLf -ne 0 -or $fixture.Cpu.InputConsumed -ne 3) {
    throw 'Resident line editor did not consume exactly one deferred LF before the next line'
}
Assert-ByteArraysEqual $fixture.Output ([byte[]]@([byte][char]'X')) 'Resident line editor CR/LF echo mismatch'
$residentMaxSteps = [Math]::Max($residentMaxSteps, $fixture.Cpu.Steps)
$residentLineCases++

foreach ($confirmation in @(
        [pscustomobject]@{ Name = 'lowercase yes'; Input = [System.Text.Encoding]::ASCII.GetBytes("y`r"); Carry = $true; Output = 'Y' },
        [pscustomobject]@{ Name = 'no'; Input = [System.Text.Encoding]::ASCII.GetBytes("n`n"); Carry = $false; Output = 'N' },
        [pscustomobject]@{ Name = 'empty'; Input = [byte[]]@(0x0D); Carry = $false; Output = '' }
    )) {
    [byte[]]$memory = $residentTemplate.Clone()
    $confirm = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $residentConfirmEntry `
        -ReadHook $residentReadHook `
        -WriteHook $residentWriteHook `
        -InputBytes $confirmation.Input
    [byte[]]$expectedConfirmEcho = [System.Text.Encoding]::ASCII.GetBytes($confirmation.Output)
    Assert-ByteArraysEqual $confirm.Output $expectedConfirmEcho ("Resident confirmation {0} echo mismatch" -f $confirmation.Name)
    Assert-True ($confirm.Carry -eq $confirmation.Carry -and $confirm.InputConsumed -eq $confirmation.Input.Length) `
        ("Resident confirmation {0} result mismatch" -f $confirmation.Name)
    $residentMaxSteps = [Math]::Max($residentMaxSteps, $confirm.Steps)
    $residentLineCases++
}

[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("2`r`na5`r`nryors`r")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput
$expectedPreview = "`r`nI B0-3: 2`r`nTYPE: A5`r`nDESC: RYORS`r`nI B2 8000-FFFF `r`nT=A5 D=RYORS EMPTY P=00 NO WRITE`r`n"
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'empty Bank 2 metadata'
Assert-True ($previewFixture.Memory[$residentInstallBank] -eq 2 -and
    $previewFixture.Memory[$residentInstallType] -eq 0xA5 -and
    $previewFixture.Memory[$residentInstallState] -eq $recordEmpty -and
    $previewFixture.Memory[$residentInstallPair] -eq 0) 'Resident I Bank-2 persistent preflight state mismatch'
Assert-True ([System.Text.Encoding]::ASCII.GetString($previewFixture.Memory, $residentInstallDesc, 5) -ceq 'RYORS') `
    'Resident I Bank-2 description state mismatch'

[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("3`r5a`rstr8n`r")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput
$expectedPreview = "`r`nI B0-3: 3`r`nTYPE: 5A`r`nDESC: STR8N`r`nI B3 8000-EFFF `r`nT=5A D=STR8N EMPTY P=00 NO WRITE`r`n"
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'empty Bank 3 range'
Assert-True ($previewFixture.Memory[$residentInstallBank] -eq 3 -and
    $previewFixture.Memory[$residentInstallEntryLo] -eq 0xFF -and
    $previewFixture.Memory[$residentInstallEntryHi] -eq 0xFF) 'Resident I empty Bank-3 state mismatch'

[byte[]]$completeRecord = New-Record 1 'HELLO' 0xFFFF (New-Journal 1 $false)
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("1`r")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 1 = $completeRecord }
$expectedPreview = "`r`nI B0-3: 1`r`nI B1 8000-FFFF `r`nT=5A D=HELLO COMPLETE P=01 NO WRITE`r`n"
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'existing complete Bank 1'

[byte[]]$incompleteRecord = New-Record 3 'LOCAL' 0xC030 (New-Journal 2 $true)
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("3`n")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 3 = $incompleteRecord }
$expectedPreview = "`r`nI B0-3: 3`r`nI B3 8000-EFFF `r`nT=5A D=LOCAL E=`$C030 INCOMPLETE P=02 NO WRITE`r`n"
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'existing incomplete Bank 3'

[byte[]]$fullRecord = New-Record 0 'FULL0' 0xFFFF (New-Journal 16 $false)
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("0`r")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 0 = $fullRecord }
$expectedPreview = "`r`nI B0-3: 0`r`nI B0 8000-FFFF `r`nT=5A D=FULL0 FULL P=FF NO WRITE`r`n"
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'full Bank 0 journal'

[byte[]]$invalidRecord = $completeRecord.Clone()
$invalidRecord[$offReserved] = 0xFE
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("1`r")
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 1 = $invalidRecord }
Assert-ResidentIPreviewFixture $previewFixture $lineInput "`r`nI B0-3: 1`r`nDIR INVALID`r`n" 'invalid directory record'

foreach ($negativePreview in @(
        [pscustomobject]@{ Name = 'empty bank'; Input = [byte[]]@(0x0D); Output = "`r`nI B0-3: `r`nABORT`r`n" },
        [pscustomobject]@{ Name = 'bank 4'; Input = [byte[]]@([byte][char]'4', 0x0A); Output = "`r`nI B0-3: 4`r`nI J0 J1 J2 J3 R`r`n" },
        [pscustomobject]@{ Name = 'bad type'; Input = [System.Text.Encoding]::ASCII.GetBytes("0`rG0`r"); Output = "`r`nI B0-3: 0`r`nTYPE: G0`r`nI J0 J1 J2 J3 R`r`n" },
        [pscustomobject]@{ Name = 'bad description'; Input = [System.Text.Encoding]::ASCII.GetBytes("0`r12`rAB CD`r"); Output = "`r`nI B0-3: 0`r`nTYPE: 12`r`nDESC: AB CD`r`nI J0 J1 J2 J3 R`r`n" }
    )) {
    $previewFixture = Invoke-ResidentIPreviewFixture $negativePreview.Input
    Assert-ResidentIPreviewFixture $previewFixture $negativePreview.Input $negativePreview.Output $negativePreview.Name
}

for ($bank = 0; $bank -lt $recordCount; $bank++) {
    $offset = ($dirBase - 0x8000) + ($bank * $recordSize)
    [byte[]]$record = $bin[$offset..($offset + $recordSize - 1)]
    $result = Get-RecordResult $bank $record
    Assert-True ($result.State -eq $recordEmpty -and $result.Pair -eq 0) "Preview Bank $bank record is not exactly empty"
}

# Execute the compiled journal scanner across the same complete legal/illegal
# progression matrix as the host reference.
Assert-ResidentJournalResult (New-Journal 0 $false)
for ($completed = 0; $completed -lt 16; $completed++) {
    Assert-ResidentJournalResult (New-Journal $completed $true)
}
for ($completed = 1; $completed -lt 16; $completed++) {
    Assert-ResidentJournalResult (New-Journal $completed $false)
}
Assert-ResidentJournalResult (New-Journal 16 $false)
for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 1
    Assert-ResidentJournalResult (Convert-PairsToJournal $pairs)
}
for ($pairIndex = 1; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 0
    Assert-ResidentJournalResult (Convert-PairsToJournal $pairs)
}
for ($pairIndex = 0; $pairIndex -lt 15; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 2
    $pairs[$pairIndex + 1] = 0
    Assert-ResidentJournalResult (Convert-PairsToJournal $pairs)
    $pairs[$pairIndex + 1] = 2
    Assert-ResidentJournalResult (Convert-PairsToJournal $pairs)
}

# Execute the compiled record validator across empty, complete, incomplete,
# exhausted, malformed, and bank-specific entry fixtures.
[byte[]]$emptyRecord = New-Object byte[] $recordSize
for ($i = 0; $i -lt $emptyRecord.Length; $i++) { $emptyRecord[$i] = $emptyByte }
for ($bank = 0; $bank -lt $recordCount; $bank++) {
    Assert-ResidentRecordResult $bank $emptyRecord
}
for ($bank = 0; $bank -lt 3; $bank++) {
    Assert-ResidentRecordResult $bank (New-Record $bank "STR8N" 0xFFFF (New-Journal 1 $false))
}
foreach ($entry in @(0x8000, 0xEFFF, 0xFFFF)) {
    Assert-ResidentRecordResult 3 (New-Record 3 "A0-_." $entry (New-Journal 1 $false))
}
Assert-ResidentRecordResult 3 (New-Record 3 "STR8N" 0x8000 (New-Journal 5 $true))
Assert-ResidentRecordResult 0 (New-Record 0 "STR8N" 0xFFFF (New-Journal 16 $false))

$goodResidentRecord = New-Record 0 "STR8N" 0xFFFF (New-Journal 1 $false)
for ($i = 0; $i -lt $reservedLength; $i++) {
    [byte[]]$bad = $goodResidentRecord.Clone()
    $bad[$offReserved + $i] = 0xFE
    Assert-ResidentRecordResult 0 $bad
}
foreach ($badCharacter in @([byte][char]'a', [byte][char]' ', [byte][char]'/', 0x7F, 0xFF)) {
    [byte[]]$bad = $goodResidentRecord.Clone()
    $bad[$offDescription] = $badCharacter
    Assert-ResidentRecordResult 0 $bad
}
foreach ($badSeal in @(0xFF, 0xFC, 0xA5, 0x00)) {
    [byte[]]$bad = $goodResidentRecord.Clone()
    $bad[$offSeal] = $badSeal
    Assert-ResidentRecordResult 0 $bad
}
foreach ($entry in @(0x0000, 0x8000, 0xFFFE)) {
    Assert-ResidentRecordResult 0 (New-Record 0 "STR8N" $entry (New-Journal 1 $false))
}
foreach ($entry in @(0x7FFF, 0xF000, 0xFF00)) {
    Assert-ResidentRecordResult 3 (New-Record 3 "STR8N" $entry (New-Journal 1 $false))
}
Assert-ResidentRecordResult 0 (New-Record 0 "STR8N" 0xFFFF (New-Journal 0 $false))
[byte[]]$partialResident = New-Object byte[] $recordSize
for ($i = 0; $i -lt $partialResident.Length; $i++) { $partialResident[$i] = $emptyByte }
[Array]::Copy((New-Journal 0 $true), 0, $partialResident, $offJournal, $journalLength)
Assert-ResidentRecordResult 0 $partialResident
Assert-ResidentRecordResult 4 $emptyRecord

# Execute the compiled one-to-zero writer through a modeled worker boundary.
# Invalid count/range/transition cases must fail before that boundary and leave
# the complete directory unchanged.
[byte[]]$fullOld = New-Object byte[] 64
[byte[]]$fullDesired = New-Object byte[] 64
for ($i = 0; $i -lt 64; $i++) {
    $fullOld[$i] = 0xFF
    $fullDesired[$i] = [byte](0xF0 -bor ($i -band 0x0F))
}
$fixture = Invoke-ResidentWriterFixture $dirBase $fullOld $fullDesired
Assert-ResidentWriterStatus $fixture $writeOk $true 1 'full-directory success'
Assert-ByteArraysEqual $fixture.After $fullDesired 'Full-directory write mismatch'

$fixture = Invoke-ResidentWriterFixture $dirEnd ([byte[]]@(0xFE)) ([byte[]]@(0xFE))
Assert-ResidentWriterStatus $fixture $writeOk $true 1 'idempotent end-byte success'
Assert-True ($fixture.Memory[$dirEnd] -eq 0xFE) 'Idempotent end-byte write changed data'

$fixture = Invoke-ResidentWriterFixture $dirEnd ([byte[]]@(0xFF)) ([byte[]]@(0xFE))
Assert-ResidentWriterStatus $fixture $writeOk $true 1 'end-byte clear success'
Assert-True ($fixture.Memory[$dirEnd] -eq 0xFE) 'Final directory byte was not programmed'

$fixture = Invoke-ResidentWriterFixture $dirBase ([byte[]]@()) ([byte[]]@())
Assert-ResidentWriterStatus $fixture $writeBadCount $false 0 'zero length'
Assert-ByteArraysEqual $fixture.After $fixture.Before 'Zero-length request mutated directory'

foreach ($rangeCase in @(
        @{ Name = 'below base'; Address = $dirBase - 1; Length = 1 },
        @{ Name = 'above end'; Address = $dirEnd + 1; Length = 1 },
        @{ Name = 'wrong high byte'; Address = 0xFEB0; Length = 1 },
        @{ Name = 'end crossing'; Address = $dirEnd; Length = 2 },
        @{ Name = '65-byte span'; Address = $dirBase; Length = 65 }
    )) {
    [byte[]]$old = New-Object byte[] $rangeCase.Length
    [byte[]]$desired = New-Object byte[] $rangeCase.Length
    for ($i = 0; $i -lt $rangeCase.Length; $i++) {
        $old[$i] = 0xFF
        $desired[$i] = 0xFE
    }
    $fixture = Invoke-ResidentWriterFixture $rangeCase.Address $old $desired
    Assert-ResidentWriterStatus $fixture $writeBadRange $false 0 $rangeCase.Name
    Assert-ByteArraysEqual $fixture.After $fixture.Before ("Range case mutated directory: {0}" -f $rangeCase.Name)
}

$fixture = Invoke-ResidentWriterFixture $dirBase ([byte[]]@(0xFF, 0x00)) ([byte[]]@(0xFE, 0x01))
Assert-ResidentWriterStatus $fixture $writeBadTransition $false 0 'later illegal transition'
Assert-ByteArraysEqual $fixture.After $fixture.Before 'Later illegal transition partially programmed directory'
Assert-True ($fixture.FailAddress -eq ($dirBase + 1) -and $fixture.Observed -eq 0x00 -and $fixture.Expected -eq 0x01) `
    'Later illegal transition failure tuple mismatch'

$fixture = Invoke-ResidentWriterFixture $dirBase ([byte[]]@(0x00)) ([byte[]]@(0x01))
Assert-ResidentWriterStatus $fixture $writeBadTransition $false 0 'first illegal transition'
Assert-ByteArraysEqual $fixture.After $fixture.Before 'First illegal transition mutated directory'

$fixture = Invoke-ResidentWriterFixture $dirBase ([byte[]]@(0xFF)) ([byte[]]@(0xFE)) 'Fail'
Assert-ResidentWriterStatus $fixture $writeWorker $false 1 'worker failure'
Assert-ByteArraysEqual $fixture.After $fixture.Before 'Worker failure mutated directory fixture'
Assert-True ($fixture.FailAddress -eq $dirBase -and $fixture.Observed -eq 0xFF -and $fixture.Expected -eq 0xFE) `
    'Worker failure tuple mismatch'

$fixture = Invoke-ResidentWriterFixture $dirBase ([byte[]]@(0xFF)) ([byte[]]@(0xFE)) 'Corrupt'
Assert-ResidentWriterStatus $fixture $writeVerify $false 1 'read-back mismatch'
Assert-True ($fixture.FailAddress -eq $dirBase -and $fixture.Observed -eq 0xFF -and $fixture.Expected -eq 0xFE) `
    'Read-back mismatch failure tuple mismatch'

# Every journal START and COMPLETE byte change must be accepted. Attempts to
# reopen either a completed or started pair require a 0-to-1 edge and must be
# rejected before the worker boundary with no mutation.
for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
    $journalByte = [Math]::Floor($pairIndex / 4)
    $address = $dirBase + $offJournal + $journalByte

    [byte[]]$beforeStart = New-Journal $pairIndex $false
    [byte[]]$afterStart = New-Journal $pairIndex $true
    $fixture = Invoke-ResidentWriterFixture $address `
        ([byte[]]@($beforeStart[$journalByte])) `
        ([byte[]]@($afterStart[$journalByte]))
    Assert-ResidentWriterStatus $fixture $writeOk $true 1 ("journal START pair {0}" -f $pairIndex)
    Assert-True ($fixture.Memory[$address] -eq $afterStart[$journalByte]) `
        ("Journal START pair {0} byte mismatch" -f $pairIndex)

    [byte[]]$afterComplete = New-Journal ($pairIndex + 1) $false
    $fixture = Invoke-ResidentWriterFixture $address `
        ([byte[]]@($afterStart[$journalByte])) `
        ([byte[]]@($afterComplete[$journalByte]))
    Assert-ResidentWriterStatus $fixture $writeOk $true 1 ("journal COMPLETE pair {0}" -f $pairIndex)
    Assert-True ($fixture.Memory[$address] -eq $afterComplete[$journalByte]) `
        ("Journal COMPLETE pair {0} byte mismatch" -f $pairIndex)

    $fixture = Invoke-ResidentWriterFixture $address `
        ([byte[]]@($afterComplete[$journalByte])) `
        ([byte[]]@($afterStart[$journalByte]))
    Assert-ResidentWriterStatus $fixture $writeBadTransition $false 0 ("journal completed rollback {0}" -f $pairIndex)
    Assert-ByteArraysEqual $fixture.After $fixture.Before ("Completed journal pair {0} rollback mutated directory" -f $pairIndex)

    $fixture = Invoke-ResidentWriterFixture $address `
        ([byte[]]@($afterStart[$journalByte])) `
        ([byte[]]@($beforeStart[$journalByte]))
    Assert-ResidentWriterStatus $fixture $writeBadTransition $false 0 ("journal START rollback {0}" -f $pairIndex)
    Assert-ByteArraysEqual $fixture.After $fixture.Before ("Started journal pair {0} rollback mutated directory" -f $pairIndex)
}

Write-Host ("STR8 V1 DIRECTORY       = {0:X4}-{1:X4}; {2} x `${3:X}-byte records" -f $dirBase, $dirEnd, $recordCount, $recordSize)
Write-Host ("BYTE TRANSITIONS        = {0} legal; {1} illegal" -f $legalByteTransitions, $illegalByteTransitions)
Write-Host ("LEGAL JOURNAL FIXTURES  = {0}" -f $legalJournalCases)
Write-Host ("ILLEGAL JOURNAL FIXTURES= {0}" -f $illegalJournalCases)
Write-Host ("RECORD FIXTURES         = {0}" -f $recordCases)
Write-Host ("PREVIEW EMPTY RECORDS   = {0}" -f $recordCount)
Write-Host ("RESIDENT VALIDATOR      = {0:X4}-{1:X4}; `${2:X} bytes" -f $residentRecordEntry, ($residentValidatorEnd - 1), $residentValidatorSize)
Write-Host ("RESIDENT DIR WRITER     = {0:X4}-{1:X4}; `${2:X} bytes" -f $residentWriterEntry, ($residentWriterEnd - 1), $residentWriterSize)
Write-Host ("RESIDENT JOURNAL CASES  = {0}" -f $residentJournalCases)
Write-Host ("RESIDENT RECORD CASES   = {0}" -f $residentRecordCases)
Write-Host ("RESIDENT WRITER CASES   = {0}" -f $residentWriterCases)
Write-Host ("RESIDENT LINE/I CASES   = {0}" -f $residentLineCases)
Write-Host ("RESIDENT MAX STEPS      = {0}" -f $residentMaxSteps)
Write-Host "STR8 V1 DIRECTORY CHECK = PASS"

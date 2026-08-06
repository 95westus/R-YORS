param(
    [string]$ConstantsPath = "STR8/str8-directory-eq.inc",
    [string]$BinPath = "BUILD/bin/himon-str8-v1-layout-preview.bin",
    [string]$Str8MapPath = "BUILD/s19/str8-v1-layout-f000.map",
    [string]$DryInstallerS19Path = "",
    [string]$TransactionInstallerS19Path = "",
    [string]$MutationWorkerS19Path = ""
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
        [int]$ReadNonblockHook = -1,
        [int]$DelayHook = -1,
        [int]$WriteHook = -1,
        [byte[]]$InputBytes = @(),
        [object[]]$TimedInput = @(),
        [int]$RecordHook = -1,
        [object[]]$RecordFixtures = @(),
        [int]$StageHook = -1,
        [int]$StageSectorAddress = -1,
        [int]$SectorHook = -1,
        [int]$SectorFailAt = 0,
        [int]$SectorCorruptAt = 0,
        [hashtable]$FlashBanks = @{},
        [int]$WorkerFailAt = 0,
        [int]$WorkerCorruptAt = 0,
        [int]$MaxSteps = 1000000,
        [string]$FixtureName = ''
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
    $timedInputIndex = 0
    $delayCalls = 0
    $workerCalls = 0
    $sectorCalls = 0
    $recordIndex = 0
    $stageSectors = New-Object System.Collections.Generic.List[object]
    $stageHighs = New-Object System.Collections.Generic.List[byte]
    $stageRecordCounts = New-Object System.Collections.Generic.List[int]
    $events = New-Object System.Collections.Generic.List[string]

    for ($step = 0; $step -lt $MaxSteps; $step++) {
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
                if ($target -eq $DelayHook) {
                    $delayCalls++
                    $pc += 3
                    continue
                }
                if ($target -eq $RecordHook) {
                    if ($recordIndex -ge $RecordFixtures.Length) {
                        throw ('Resident record fixtures exhausted in {0} at ${1:X4}; records={2} phase=${3:X2} expected=${4:X2}{5:X2}' -f `
                            $FixtureName, $pc, $recordIndex, $Memory[0x009E], $Memory[0x009C], $Memory[0x009B])
                    }
                    $record = $RecordFixtures[$recordIndex++]
                    if ([int]$record.FailStatus -ne 0) {
                        $Memory[0x7E98] = [byte]$record.FailStatus
                        $status = $status -band 0xFE
                    } else {
                        $Memory[0x7E98] = 0
                        $Memory[0x7E9C] = [byte]$record.Kind
                        $Memory[0x7E9D] = $(if ([int]$record.Kind -eq 3) { 1 } else { 0 })
                        $Memory[0x7E9E] = [byte]([int]$record.Address -band 0xFF)
                        $Memory[0x7E9F] = [byte](([int]$record.Address -shr 8) -band 0xFF)
                        [byte[]]$recordData = $record.Data
                        $Memory[0x7EA0] = [byte]$recordData.Length
                        $Memory[0x7EA1] = [byte]([int]$record.Entry -band 0xFF)
                        $Memory[0x7EA2] = [byte](([int]$record.Entry -shr 8) -band 0xFF)
                        if ($recordData.Length -gt 0) {
                            [Array]::Copy($recordData, 0, $Memory, 0x7B00, $recordData.Length)
                        }
                        $status = $status -bor 0x01
                    }
                    $pc += 3
                    continue
                }
                if ($target -eq $StageHook) {
                    [byte[]]$snapshot = New-Object byte[] 0x1000
                    [Array]::Copy($Memory, 0x0A00, $snapshot, 0, 0x1000)
                    $stageSectors.Add($snapshot)
                    $stageHighs.Add($Memory[$StageSectorAddress])
                    $stageRecordCounts.Add($recordIndex)
                    $status = $status -bor 0x01
                    $pc += 3
                    continue
                }
                if ($target -eq $SectorHook) {
                    $sectorCalls++
                    [byte[]]$snapshot = New-Object byte[] 0x1000
                    [Array]::Copy($Memory, 0x0A00, $snapshot, 0, 0x1000)
                    $sectorHigh = [int]$Memory[$StageSectorAddress]
                    $sectorBank = [int]$Memory[0x1FEF]
                    $stageSectors.Add($snapshot)
                    $stageHighs.Add([byte]$sectorHigh)
                    $stageRecordCounts.Add($recordIndex)
                    $events.Add(('S:{0}:{1:X2}' -f $sectorBank, $sectorHigh))
                    $failed = $SectorFailAt -gt 0 -and $sectorCalls -eq $SectorFailAt
                    $corrupt = $SectorCorruptAt -gt 0 -and $sectorCalls -eq $SectorCorruptAt
                    if (-not $failed -and $FlashBanks.ContainsKey($sectorBank)) {
                        [byte[]]$flash = $FlashBanks[$sectorBank]
                        [Array]::Copy($snapshot, 0, $flash, $sectorHigh -shl 8, 0x1000)
                        if ($corrupt) {
                            $flash[$sectorHigh -shl 8] = [byte](([int]$flash[$sectorHigh -shl 8]) -bxor 0x01)
                        }
                    }
                    if ($failed -or $corrupt) {
                        $status = $status -band 0xFE
                    } else {
                        $status = $status -bor 0x01
                    }
                    $pc += 3
                    continue
                }
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
                if ($target -eq $ReadNonblockHook) {
                    if ($TimedInput.Length -gt 0) {
                        if ($timedInputIndex -ge $TimedInput.Length -or
                            [int]$TimedInput[$timedInputIndex].AfterDelay -gt $delayCalls) {
                            $aReg = 0
                            $status = Set-NzFlags $status $aReg
                            $status = $status -band 0xFE
                        } else {
                            $aReg = [int]$TimedInput[$timedInputIndex].Byte
                            $timedInputIndex++
                            $status = Set-NzFlags $status $aReg
                            $status = $status -bor 0x01
                        }
                    } elseif ($inputIndex -ge $InputBytes.Length) {
                        $aReg = 0
                        $status = Set-NzFlags $status $aReg
                        $status = $status -band 0xFE
                    } else {
                        $aReg = [int]$InputBytes[$inputIndex++]
                        $status = Set-NzFlags $status $aReg
                        $status = $status -bor 0x01
                    }
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
                    $activeWorkerBehavior = $WorkerBehavior
                    if ($WorkerFailAt -gt 0 -and $workerCalls -eq $WorkerFailAt) {
                        $activeWorkerBehavior = 'Fail'
                    } elseif ($WorkerCorruptAt -gt 0 -and $workerCalls -eq $WorkerCorruptAt) {
                        $activeWorkerBehavior = 'Corrupt'
                    }
                    $events.Add(('D:{0:X4}:{1}' -f $recordAddress, $recordLength))
                    if ($activeWorkerBehavior -eq 'Success' -or $activeWorkerBehavior -eq 'Corrupt') {
                        for ($i = 0; $i -lt $recordLength; $i++) {
                            $Memory[$recordAddress + $i] = $Memory[0x7B00 + $i]
                        }
                        if ($activeWorkerBehavior -eq 'Corrupt' -and $recordLength -gt 0) {
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
            0x2D { # AND absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $aReg = $aReg -band [int]$Memory[$address]
                $status = Set-NzFlags $status $aReg
                $pc += 3
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
            0x3A { # DEC A
                $aReg = ($aReg - 1) -band 0xFF
                $status = Set-NzFlags $status $aReg
                $pc++
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
                            TimedInputConsumed = $timedInputIndex
                            DelayCalls = $delayCalls
                            Output = $output.ToArray()
                            RecordCalls = $recordIndex
                            StageCalls = $stageSectors.Count
                            StageSectors = $stageSectors.ToArray()
                            StageHighs = $stageHighs.ToArray()
                            StageRecordCounts = $stageRecordCounts.ToArray()
                            SectorCalls = $sectorCalls
                            Events = $events.ToArray()
                        }
                    }
                    $pc = $returns.Pop()
                    continue
                }
                $pc = $target
                continue
            }
            0x5A { # PHY
                $dataStack.Push($yReg)
                $pc++
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
                        TimedInputConsumed = $timedInputIndex
                        DelayCalls = $delayCalls
                        Output = $output.ToArray()
                        RecordCalls = $recordIndex
                        StageCalls = $stageSectors.Count
                        StageSectors = $stageSectors.ToArray()
                        StageHighs = $stageHighs.ToArray()
                        StageRecordCounts = $stageRecordCounts.ToArray()
                        SectorCalls = $sectorCalls
                        Events = $events.ToArray()
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
            0x7A { # PLY
                if ($dataStack.Count -eq 0) { throw ('PLY underflow at ${0:X4}' -f $pc) }
                $yReg = $dataStack.Pop()
                $status = Set-NzFlags $status $yReg
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
            0x91 { # STA (zero page),Y
                $zp = [int]$Memory[$pc + 1]
                $base = ([int]$Memory[$zp]) -bor (([int]$Memory[($zp + 1) -band 0xFF]) -shl 8)
                $Memory[($base + $yReg) -band 0xFFFF] = [byte]$aReg
                $pc += 2
                continue
            }
            0x95 { # STA zero page,X
                $address = (([int]$Memory[$pc + 1]) + $xReg) -band 0xFF
                $Memory[$address] = [byte]$aReg
                $pc += 2
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
            0xAA { # TAX
                $xReg = $aReg
                $status = Set-NzFlags $status $xReg
                $pc++
                continue
            }
            0xAD { # LDA absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $aReg = [int]$Memory[$address]
                $status = Set-NzFlags $status $aReg
                $pc += 3
                continue
            }
            0xAE { # LDX absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $xReg = [int]$Memory[$address]
                $status = Set-NzFlags $status $xReg
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
            0xB5 { # LDA zero page,X
                $address = (([int]$Memory[$pc + 1]) + $xReg) -band 0xFF
                $aReg = [int]$Memory[$address]
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
            0xC5 { # CMP zero page
                $value = [int]$Memory[[int]$Memory[$pc + 1]]
                $difference = ($aReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($aReg -ge $value) { $status = $status -bor 0x01 }
                if ($aReg -eq $value) { $status = $status -bor 0x02 }
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
            0xCD { # CMP absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $value = [int]$Memory[$address]
                $difference = ($aReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($aReg -ge $value) { $status = $status -bor 0x01 }
                if ($aReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 3
                continue
            }
            0xDD { # CMP absolute,X
                $address = (([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)) + $xReg
                $value = [int]$Memory[$address -band 0xFFFF]
                $difference = ($aReg - $value) -band 0xFF
                $status = $status -band 0x7C
                if ($aReg -ge $value) { $status = $status -bor 0x01 }
                if ($aReg -eq $value) { $status = $status -bor 0x02 }
                if (($difference -band 0x80) -ne 0) { $status = $status -bor 0x80 }
                $pc += 3
                continue
            }
            0xCA { # DEX
                $xReg = ($xReg - 1) -band 0xFF
                $status = Set-NzFlags $status $xReg
                $pc++
                continue
            }
            0xCE { # DEC absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                $value = (([int]$Memory[$address]) - 1) -band 0xFF
                $Memory[$address] = [byte]$value
                $status = Set-NzFlags $status $value
                $pc += 3
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
            0xDA { # PHX
                $dataStack.Push($xReg)
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
            0xFA { # PLX
                if ($dataStack.Count -eq 0) { throw ('PLX underflow at ${0:X4}' -f $pc) }
                $xReg = $dataStack.Pop()
                $status = Set-NzFlags $status $xReg
                $pc++
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

function New-ProvisionalRecord([byte]$Type, [string]$Description, [int]$Entry, [byte[]]$Journal) {
    [byte[]]$record = New-Object byte[] $recordSize
    for ($i = 0; $i -lt $record.Length; $i++) {
        $record[$i] = $emptyByte
    }
    $record[$offType] = $Type
    [byte[]]$descriptionBytes = [System.Text.Encoding]::ASCII.GetBytes($Description)
    Assert-True ($descriptionBytes.Length -eq $descriptionLength) "Description fixture must be exactly five bytes"
    [Array]::Copy($descriptionBytes, 0, $record, $offDescription, $descriptionLength)
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
    if ([Convert]::ToBase64String($Actual) -ceq [Convert]::ToBase64String($Expected)) { return }
    for ($i = 0; $i -lt $Actual.Length; $i++) {
        if ($Actual[$i] -ne $Expected[$i]) {
            throw ('{0} at +${1:X}: got ${2:X2}, expected ${3:X2}' -f $Message, $i, $Actual[$i], $Expected[$i])
        }
    }
}

function Get-HighBitStringBytes([byte[]]$Memory, [int]$Address) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($true) {
        $value = [int]$Memory[$Address++]
        $bytes.Add([byte]($value -band 0x7F))
        if (($value -band 0x80) -ne 0) { return $bytes.ToArray() }
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
        [hashtable]$Records = @{},
        [object[]]$DenseRecords = @()
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
        -ReadNonblockHook $script:residentReadNonblockHook `
        -WriteHook $script:residentWriteHook `
        -InputBytes $InputBytes `
        -RecordHook $script:residentRecordHook `
        -RecordFixtures $DenseRecords `
        -StageHook $script:residentStageHook `
        -StageSectorAddress $script:residentInstallSectorHi
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
    if ($Fixture.Cpu.Output.Length -ne $expectedBytes.Length) {
        $actualText = [System.Text.Encoding]::ASCII.GetString($Fixture.Cpu.Output).Replace("`r", '\r').Replace("`n", '\n')
        $wantedText = $ExpectedOutput.Replace("`r", '\r').Replace("`n", '\n')
        throw ("Resident I preview $Name output length mismatch: got '$actualText'; expected '$wantedText'")
    }
    Assert-ByteArraysEqual $Fixture.Cpu.Output $expectedBytes ("Resident I preview $Name output mismatch")
    Assert-ByteArraysEqual $Fixture.AfterDirectory $Fixture.BeforeDirectory ("Resident I preview $Name mutated directory")
    Assert-True ($Fixture.Cpu.WorkerCalls -eq 0 -and $Fixture.Cpu.InputConsumed -eq $InputBytes.Length) `
        ("Resident I preview $Name reached a worker or left input unread")
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $Fixture.Cpu.Steps)
    $script:residentLineCases++
}

function New-TransactionFlashBanks {
    $banks = @{}
    for ($bank = 0; $bank -lt 4; $bank++) {
        [byte[]]$image = New-Object byte[] 65536
        $fill = [byte](0x40 + $bank)
        for ($address = 0x8000; $address -le 0xFFFF; $address++) {
            $image[$address] = $fill
        }
        $banks[$bank] = $image
    }
    return $banks
}

function Invoke-ResidentITransactionFixture {
    param(
        [byte[]]$InputBytes,
        [hashtable]$Records = @{},
        [object[]]$DenseRecords = @(),
        [AllowNull()][object[]]$WorkerRecords = $null,
        [int]$WorkerFailAt = 0,
        [int]$WorkerCorruptAt = 0,
        [int]$SectorFailAt = 0,
        [int]$SectorCorruptAt = 0
    )

    [byte[]]$memory = $script:residentTemplate.Clone()
    $memory[$script:residentDataBuffer + 1] = 0
    foreach ($bankKey in $Records.Keys) {
        $recordAddress = $script:dirBase + ([int]$bankKey * $script:recordSize)
        [byte[]]$record = $Records[$bankKey]
        [Array]::Copy($record, 0, $memory, $recordAddress, $script:recordSize)
    }
    $flashBanks = New-TransactionFlashBanks
    $beforeBanks = @{}
    foreach ($bankKey in $flashBanks.Keys) {
        $beforeBanks[$bankKey] = ([byte[]]$flashBanks[$bankKey]).Clone()
    }
    [byte[]]$beforeDirectory = $memory[$script:dirBase..$script:dirEnd]
    [object[]]$combinedRecords = Join-TransactionRecords $DenseRecords $WorkerRecords
    $cpu = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $script:residentInstallPreviewEntry `
        -WorkerHook $script:residentWorkerHook `
        -WorkerBehavior 'Success' `
        -WorkerFailAt $WorkerFailAt `
        -WorkerCorruptAt $WorkerCorruptAt `
        -ReadHook $script:residentReadHook `
        -ReadNonblockHook $script:residentReadNonblockHook `
        -WriteHook $script:residentWriteHook `
        -InputBytes $InputBytes `
        -RecordHook $script:residentRecordHook `
        -RecordFixtures $combinedRecords `
        -SectorHook $script:residentSectorHook `
        -SectorFailAt $SectorFailAt `
        -SectorCorruptAt $SectorCorruptAt `
        -FlashBanks $flashBanks `
        -StageSectorAddress $script:residentInstallSectorHi `
        -FixtureName ("transaction dense={0} wf={1} wc={2} sf={3} sc={4}" -f `
            $DenseRecords.Length, $WorkerFailAt, $WorkerCorruptAt, $SectorFailAt, $SectorCorruptAt)
    return [pscustomobject]@{
        Cpu = $cpu
        Memory = $memory
        BeforeDirectory = $beforeDirectory
        AfterDirectory = [byte[]]($memory[$script:dirBase..$script:dirEnd])
        BeforeBanks = $beforeBanks
        FlashBanks = $flashBanks
    }
}

function Invoke-TransactionRoutineFixture {
    param(
        [int]$Start,
        [int]$Bank,
        [int]$State,
        [int]$Pair,
        [byte[]]$Record,
        [byte]$Type = 0x5A,
        [string]$Description = 'STR8N',
        [int]$Entry = 0xFFFF,
        [int]$SectorHigh = 0x80,
        [int]$WorkerFailAt = 0,
        [int]$WorkerCorruptAt = 0,
        [int]$SectorFailAt = 0,
        [int]$SectorCorruptAt = 0
    )

    [byte[]]$memory = $script:residentTemplate.Clone()
    $recordAddress = $script:dirBase + ($Bank * $script:recordSize)
    [Array]::Copy($Record, 0, $memory, $recordAddress, $script:recordSize)
    $memory[$script:residentInstallBank] = [byte]$Bank
    $memory[$script:residentInstallState] = [byte]$State
    $memory[$script:residentInstallPair] = [byte]$Pair
    $memory[$script:residentInstallType] = $Type
    [byte[]]$descriptionBytes = [System.Text.Encoding]::ASCII.GetBytes($Description)
    [Array]::Copy($descriptionBytes, 0, $memory, $script:residentInstallDesc, $script:descriptionLength)
    $memory[$script:residentInstallEntryLo] = [byte]($Entry -band 0xFF)
    $memory[$script:residentInstallEntryHi] = [byte](($Entry -shr 8) -band 0xFF)
    $memory[$script:residentInstallSectorHi] = [byte]$SectorHigh
    for ($i = 0; $i -lt 0x1000; $i++) {
        $memory[0x0A00 + $i] = [byte](($i * 13 + $SectorHigh) -band 0xFF)
    }
    $flashBanks = New-TransactionFlashBanks
    $beforeBanks = @{}
    foreach ($bankKey in $flashBanks.Keys) {
        $beforeBanks[$bankKey] = ([byte[]]$flashBanks[$bankKey]).Clone()
    }
    [byte[]]$beforeDirectory = $memory[$script:dirBase..$script:dirEnd]
    $cpu = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $Start `
        -WorkerHook $script:residentWorkerHook `
        -WorkerBehavior 'Success' `
        -WorkerFailAt $WorkerFailAt `
        -WorkerCorruptAt $WorkerCorruptAt `
        -SectorHook $script:residentSectorHook `
        -SectorFailAt $SectorFailAt `
        -SectorCorruptAt $SectorCorruptAt `
        -FlashBanks $flashBanks `
        -StageSectorAddress $script:residentInstallSectorHi `
        -WriteHook $script:residentWriteHook
    return [pscustomobject]@{
        Cpu = $cpu
        Memory = $memory
        BeforeDirectory = $beforeDirectory
        AfterDirectory = [byte[]]($memory[$script:dirBase..$script:dirEnd])
        BeforeBanks = $beforeBanks
        FlashBanks = $flashBanks
    }
}

function Assert-TransactionOutput {
    param(
        [pscustomobject]$Fixture,
        [byte[]]$InputBytes,
        [string]$ExpectedOutput,
        [string]$Name
    )

    [byte[]]$expectedBytes = [System.Text.Encoding]::ASCII.GetBytes($ExpectedOutput)
    if ([Convert]::ToBase64String($Fixture.Cpu.Output) -cne [Convert]::ToBase64String($expectedBytes)) {
        $actualText = [System.Text.Encoding]::ASCII.GetString($Fixture.Cpu.Output).Replace("`r", '\r').Replace("`n", '\n')
        $wantedText = $ExpectedOutput.Replace("`r", '\r').Replace("`n", '\n')
        throw ("Transaction $Name output mismatch: got '$actualText'; expected '$wantedText'; " +
            ('status=${0:X2} phase=${1:X2} expected=${2:X2}{3:X2} records={4}' -f `
                $Fixture.Memory[$script:residentInstallStatus],
                $Fixture.Memory[$script:residentInstallPhase],
                $Fixture.Memory[$script:residentInstallExpectHi],
                $Fixture.Memory[$script:residentInstallExpectLo],
                $Fixture.Cpu.RecordCalls))
    }
    Assert-True ($Fixture.Cpu.InputConsumed -eq $InputBytes.Length) `
        ("Transaction $Name left text input unread")
    $script:residentMaxSteps = [Math]::Max($script:residentMaxSteps, $Fixture.Cpu.Steps)
    $script:residentInstallerCases++
}

function Assert-StringArraysEqual([string[]]$Actual, [string[]]$Expected, [string]$Message) {
    if ($Actual.Length -ne $Expected.Length) {
        throw ("$Message count: got $($Actual.Length), expected $($Expected.Length)")
    }
    for ($i = 0; $i -lt $Actual.Length; $i++) {
        if ($Actual[$i] -cne $Expected[$i]) {
            throw ("$Message at $i`: got '$($Actual[$i])', expected '$($Expected[$i])'")
        }
    }
}

function Assert-TransactionFlash {
    param(
        [pscustomobject]$Fixture,
        [int]$Bank,
        [pscustomobject]$Dense,
        [int]$SectorCount,
        [string]$Name
    )

    Assert-True ($Fixture.Cpu.SectorCalls -eq $SectorCount) `
        ("Transaction $Name sector-call count mismatch")
    for ($candidate = 0; $candidate -lt 4; $candidate++) {
        [byte[]]$actual = $Fixture.FlashBanks[$candidate]
        [byte[]]$before = $Fixture.BeforeBanks[$candidate]
        if ($candidate -ne $Bank) {
            Assert-ByteArraysEqual $actual $before ("Transaction $Name changed unrelated Bank $candidate")
            continue
        }
        for ($offset = 0; $offset -lt 0x8000; $offset++) {
            $address = 0x8000 + $offset
            if ($offset -lt $Dense.Image.Length) {
                $expected = $Dense.Image[$offset]
            } else {
                $expected = $before[$address]
            }
            if ($actual[$address] -ne $expected) {
                throw ('Transaction {0} flash mismatch Bank {1} ${2:X4}: got ${3:X2}, expected ${4:X2}' -f `
                    $Name, $Bank, $address, $actual[$address], $expected)
            }
        }
    }
    $expectedRecordCount = $Dense.Records.Length + $script:mutationWorkerRecords.Length
    Assert-True ($Fixture.Cpu.StageRecordCounts[$SectorCount - 1] -eq $expectedRecordCount) `
        ("Transaction $Name released its final sector before S9")
    [byte[]]$actualWorker = $Fixture.Memory[0x0200..($script:mutationWorkerEnd - 1)]
    Assert-ByteArraysEqual $actualWorker $script:mutationWorkerImage `
        ("Transaction $Name mutation worker upload mismatch")
}

function Assert-DirectoryRecord {
    param(
        [pscustomobject]$Fixture,
        [int]$Bank,
        [byte[]]$Expected,
        [string]$Name
    )

    $offset = $Bank * $script:recordSize
    [byte[]]$actual = $Fixture.AfterDirectory[$offset..($offset + $script:recordSize - 1)]
    Assert-ByteArraysEqual $actual $Expected ("Transaction $Name directory record mismatch")
    for ($candidate = 0; $candidate -lt 4; $candidate++) {
        if ($candidate -eq $Bank) { continue }
        $otherOffset = $candidate * $script:recordSize
        [byte[]]$before = $Fixture.BeforeDirectory[$otherOffset..($otherOffset + $script:recordSize - 1)]
        [byte[]]$after = $Fixture.AfterDirectory[$otherOffset..($otherOffset + $script:recordSize - 1)]
        Assert-ByteArraysEqual $after $before ("Transaction $Name changed directory Bank $candidate")
    }
}

function New-DenseRecordFixture {
    param(
        [int]$Length,
        [int]$Entry,
        [int]$ChunkLength,
        [bool]$IncludeS0
    )

    [byte[]]$image = New-Object byte[] $Length
    for ($i = 0; $i -lt $Length; $i++) {
        $image[$i] = [byte](($i * 37 + 0x5A) -band 0xFF)
    }
    if ($Length -eq 0x8000) {
        $image[0x7FFC] = [byte]($Entry -band 0xFF)
        $image[0x7FFD] = [byte](($Entry -shr 8) -band 0xFF)
    }
    $records = New-Object System.Collections.Generic.List[object]
    if ($IncludeS0) {
        $records.Add([pscustomobject]@{
            FailStatus = 0; Kind = 1; Address = 0; Data = [byte[]]@(); Entry = 0
        })
    }
    for ($offset = 0; $offset -lt $Length; $offset += $ChunkLength) {
        $count = [Math]::Min($ChunkLength, $Length - $offset)
        [byte[]]$data = New-Object byte[] $count
        [Array]::Copy($image, $offset, $data, 0, $count)
        $records.Add([pscustomobject]@{
            FailStatus = 0
            Kind = 2
            Address = 0x8000 + $offset
            Data = $data
            Entry = 0
        })
    }
    $records.Add([pscustomobject]@{
        FailStatus = 0; Kind = 3; Address = $Entry; Data = [byte[]]@(); Entry = $Entry
    })
    return [pscustomobject]@{ Image = $image; Records = $records.ToArray() }
}

function Read-MutationWorkerFixture {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Mutation worker S19 not found: $Path" }
    $records = New-Object System.Collections.Generic.List[object]
    $bytes = New-Object System.Collections.Generic.List[byte]
    $expectedAddress = 0x0200
    $s9Count = 0
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -notmatch '^S([19])([0-9A-Fa-f]+)$') { continue }
        $type = [int]$Matches[1]
        $hex = $Matches[2]
        $count = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        Assert-True ($hex.Length -eq (2 + ($count * 2))) 'Malformed mutation-worker S-record length'
        $sum = $count
        for ($i = 0; $i -lt $count; $i++) {
            $sum = ($sum + [Convert]::ToInt32($hex.Substring(2 + ($i * 2), 2), 16)) -band 0xFF
        }
        Assert-True ($sum -eq 0xFF) 'Mutation-worker S-record checksum mismatch'
        $address = [Convert]::ToInt32($hex.Substring(2, 4), 16)
        if ($type -eq 9) {
            Assert-True ($address -eq 0x0200) 'Mutation-worker S9 must be $0200'
            $s9Count++
            continue
        }
        Assert-True ($address -eq $expectedAddress) `
            ('Mutation-worker S1 gap at ${0:X4}; expected ${1:X4}' -f $address, $expectedAddress)
        $dataLength = $count - 3
        [byte[]]$data = New-Object byte[] $dataLength
        for ($i = 0; $i -lt $dataLength; $i++) {
            $data[$i] = [byte][Convert]::ToInt32($hex.Substring(6 + ($i * 2), 2), 16)
            $bytes.Add($data[$i])
        }
        $records.Add([pscustomobject]@{
            FailStatus = 0; Kind = 2; Address = $address; Data = $data; Entry = 0
        })
        $expectedAddress += $dataLength
    }
    Assert-True ($s9Count -eq 1) 'Mutation-worker S19 must contain exactly one S9'
    return [pscustomobject]@{
        Start = 0x0200
        End = $expectedAddress
        Image = $bytes.ToArray()
        Records = $records.ToArray()
    }
}

function Join-TransactionRecords {
    param(
        [object[]]$DenseRecords,
        [AllowNull()][object[]]$WorkerRecords = $null
    )

    if (-not $script:transactionInstallerMode) { return $DenseRecords }
    if ($null -eq $WorkerRecords) { $WorkerRecords = $script:mutationWorkerRecords }
    $combined = New-Object System.Collections.Generic.List[object]
    $denseIndex = 0
    if ($DenseRecords.Length -gt 0 -and [int]$DenseRecords[0].Kind -eq 1) {
        $combined.Add($DenseRecords[0])
        $denseIndex = 1
    }
    foreach ($record in $WorkerRecords) { $combined.Add($record) }
    for ($i = $denseIndex; $i -lt $DenseRecords.Length; $i++) { $combined.Add($DenseRecords[$i]) }
    return $combined.ToArray()
}

function Assert-DenseStageFixture {
    param(
        [pscustomobject]$Fixture,
        [pscustomobject]$Dense,
        [int]$SectorCount,
        [byte[]]$InputBytes,
        [string]$ExpectedOutput,
        [string]$Name
    )

    if ($Fixture.Memory[$script:residentInstallStatus] -ne 0) {
        throw ('Dense {0} failed: status=${1:X2}, records={2}, stages={3}, input={4}/{5}, expected=${6:X2}{7:X2}, phase=${8:X2}, limit=${9:X2}, sector=${10:X2}' -f `
            $Name, $Fixture.Memory[$script:residentInstallStatus], $Fixture.Cpu.RecordCalls,
            $Fixture.Cpu.StageCalls, $Fixture.Cpu.InputConsumed, $InputBytes.Length,
            $Fixture.Memory[$script:residentInstallExpectHi],
            $Fixture.Memory[$script:residentInstallExpectLo],
            $Fixture.Memory[$script:residentInstallPhase],
            $Fixture.Memory[$script:residentInstallLimitHi],
            $Fixture.Memory[$script:residentInstallSectorHi])
    }
    Assert-ResidentIPreviewFixture $Fixture $InputBytes $ExpectedOutput $Name
    Assert-True ($Fixture.Cpu.RecordCalls -eq $Dense.Records.Length) `
        ("Dense $Name did not consume every record")
    Assert-True ($Fixture.Cpu.StageCalls -eq $SectorCount) `
        ("Dense $Name staged $($Fixture.Cpu.StageCalls) sectors; expected $SectorCount")
    for ($sector = 0; $sector -lt $SectorCount; $sector++) {
        Assert-True ($Fixture.Cpu.StageHighs[$sector] -eq (0x80 + ($sector * 0x10))) `
            ("Dense $Name sector $sector target-high mismatch")
        [byte[]]$expected = New-Object byte[] 0x1000
        [Array]::Copy($Dense.Image, $sector * 0x1000, $expected, 0, 0x1000)
        Assert-ByteArraysEqual $Fixture.Cpu.StageSectors[$sector] $expected `
            ("Dense $Name sector $sector staging mismatch")
    }
    Assert-True ($Fixture.Cpu.StageRecordCounts[$SectorCount - 1] -eq $Dense.Records.Length) `
        ("Dense $Name released its final sector before consuming S9")
    Assert-True ($Fixture.Memory[$script:residentInstallStatus] -eq 0) `
        ("Dense $Name left a failure status")
    $script:residentInstallerCases++
}

function Invoke-ResidentDenseFixture {
    param(
        [int]$Bank,
        [object[]]$DenseRecords,
        [byte[]]$InputBytes = @(),
        [int]$State = 1,
        [int]$Entry = 0xFFFF
    )

    [byte[]]$memory = $script:residentTemplate.Clone()
    $memory[$script:residentInstallBank] = [byte]$Bank
    $memory[$script:residentInstallState] = [byte]$State
    $memory[$script:residentInstallEntryLo] = [byte]($Entry -band 0xFF)
    $memory[$script:residentInstallEntryHi] = [byte](($Entry -shr 8) -band 0xFF)
    [byte[]]$beforeDirectory = $memory[$script:dirBase..$script:dirEnd]
    [object[]]$combinedRecords = Join-TransactionRecords $DenseRecords
    $cpu = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $script:residentDenseEntry `
        -ReadNonblockHook $script:residentReadNonblockHook `
        -InputBytes $InputBytes `
        -RecordHook $script:residentRecordHook `
        -RecordFixtures $combinedRecords `
        -WorkerHook $(if ($script:transactionInstallerMode) { $script:residentWorkerHook } else { -1 }) `
        -WorkerBehavior $(if ($script:transactionInstallerMode) { 'Success' } else { 'None' }) `
        -StageHook $script:residentStageHook `
        -StageSectorAddress $script:residentInstallSectorHi `
        -FixtureName ("dense bank={0} records={1}" -f $Bank, $DenseRecords.Length)
    return [pscustomobject]@{
        Bank = $Bank
        Cpu = $cpu
        Memory = $memory
        BeforeDirectory = $beforeDirectory
        AfterDirectory = [byte[]]($memory[$script:dirBase..$script:dirEnd])
    }
}

function Assert-DenseReject {
    param(
        [pscustomobject]$Fixture,
        [int]$Status,
        [int]$InputLength,
        [string]$Name,
        [bool]$AfterStart = $false
    )

    Assert-True (-not $Fixture.Cpu.Carry) "Dense reject $Name returned carry set"
    Assert-True ($Fixture.Memory[$script:residentInstallStatus] -eq $Status) `
        ("Dense reject $Name status mismatch")
    Assert-True ($Fixture.Cpu.InputConsumed -eq $InputLength) `
        ("Dense reject $Name left queued input")
    if ($AfterStart) {
        Assert-True ($Fixture.Cpu.WorkerCalls -ge 1 -and $Fixture.Cpu.WorkerCalls -le 2) `
            ("Dense reject $Name crossed an unexpected transaction boundary")
        $offset = $Fixture.Bank * $script:recordSize
        [byte[]]$record = $Fixture.AfterDirectory[$offset..($offset + $script:recordSize - 1)]
        $journal = Get-JournalResult ([byte[]]$record[$script:offJournal..($script:offJournal + $script:journalLength - 1)])
        Assert-True ($journal.State -eq $script:journalStarted -and $record[$script:offSeal] -eq $script:emptyByte) `
            ("Dense reject $Name did not remain STARTED/unsealed")
    } else {
        Assert-True ($Fixture.Cpu.WorkerCalls -eq 0) `
            ("Dense reject $Name reached a worker before its first valid payload record")
        Assert-ByteArraysEqual $Fixture.AfterDirectory $Fixture.BeforeDirectory `
            ("Dense reject $Name mutated directory before START")
    }
    $script:residentInstallerCases++
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

$transactionInstallerMode = -not [string]::IsNullOrWhiteSpace($TransactionInstallerS19Path)
$dryInstallerMode = $transactionInstallerMode -or -not [string]::IsNullOrWhiteSpace($DryInstallerS19Path)
$installerConfirmText = $(if ($transactionInstallerMode) { 'WRITE' } else { 'STAGE' })
[byte[]]$residentTemplate = New-Object byte[] 65536
if ($dryInstallerMode) {
    $installerS19Path = $(if ($transactionInstallerMode) { $TransactionInstallerS19Path } else { $DryInstallerS19Path })
    if (-not (Test-Path -LiteralPath $installerS19Path)) {
        throw "V1 installer S19 not found: $installerS19Path"
    }
    for ($address = 0x8000; $address -le 0xFFFF; $address++) {
        $residentTemplate[$address] = 0xFF
    }
    $s9Count = 0
    foreach ($line in Get-Content -LiteralPath $installerS19Path) {
        $textLine = $line.Trim()
        if ($textLine -notmatch '^S([19])([0-9A-Fa-f]+)$') { continue }
        $type = [int]$Matches[1]
        $hex = $Matches[2]
        $count = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        Assert-True ($hex.Length -eq (2 + ($count * 2))) "Malformed installer-dry S-record length"
        $sum = $count
        for ($i = 0; $i -lt $count; $i++) {
            $sum = ($sum + [Convert]::ToInt32($hex.Substring(2 + ($i * 2), 2), 16)) -band 0xFF
        }
        Assert-True ($sum -eq 0xFF) "Installer-dry S-record checksum mismatch"
        $recordAddress = [Convert]::ToInt32($hex.Substring(2, 4), 16)
        if ($type -eq 9) {
            Assert-True ($recordAddress -eq 0xF000) "Installer-dry S9 must be F000"
            $s9Count++
            continue
        }
        $dataLength = $count - 3
        for ($i = 0; $i -lt $dataLength; $i++) {
            $residentTemplate[$recordAddress + $i] = [byte][Convert]::ToInt32($hex.Substring(6 + ($i * 2), 2), 16)
        }
    }
    Assert-True ($s9Count -eq 1) "Installer-dry S19 must contain exactly one S9"
    [byte[]]$bin = $residentTemplate[0x8000..0xFFFF]
} else {
    if (-not (Test-Path -LiteralPath $BinPath)) {
        throw "V1 preview BIN not found: $BinPath"
    }
    [byte[]]$bin = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $BinPath).Path)
    Assert-True ($bin.Length -eq 0x8000) "V1 preview BIN must be exactly 32K"
    [Array]::Copy($bin, 0, $residentTemplate, 0x8000, $bin.Length)
}
$residentSymbols = Read-MapSymbols $Str8MapPath
$residentRecordEntry = Get-MapSymbol $residentSymbols "STR8_DIR_VALIDATE_BANK_A"
$residentEnd = Get-MapSymbol $residentSymbols "_END_DATA"
$residentStart = 0xF000
$workerStoreStart = 0xFD1F
$workerReserveFloor = 0x40
$residentSize = $residentEnd - $residentStart
$workerGap = [Math]::Max(0, $workerStoreStart - $residentEnd)
$workerOverlap = [Math]::Max(0, $residentEnd - $workerStoreStart)
$workerFitDebt = [Math]::Max(0, $residentEnd - ($workerStoreStart - $workerReserveFloor))
$residentJournalEntry = Get-MapSymbol $residentSymbols "STR8_DIR_SCAN_JOURNAL"
$residentWriterEntry = Get-MapSymbol $residentSymbols "STR8_DIR_WRITE_BYTES"
$residentLineEntry = Get-MapSymbol $residentSymbols "STR8_READ_LINE"
$residentInstallPreviewEntry = Get-MapSymbol $residentSymbols "STR8_CMD_INSTALL_PREVIEW"
$residentDenseEntry = $(if ($dryInstallerMode) { Get-MapSymbol $residentSymbols "STR8_I_RECEIVE_DENSE" } else { -1 })
$residentRecordHook = $(if ($dryInstallerMode) { Get-MapSymbol $residentSymbols "STR8_RECORD_SERVICE_BODY" } else { -1 })
$residentStageHook = $(if ($dryInstallerMode) { Get-MapSymbol $residentSymbols "STR8_I_STAGE_SECTOR_READY" } else { -1 })
$residentSectorHook = $(if ($transactionInstallerMode) { Get-MapSymbol $residentSymbols "STR8_I_RUN_SECTOR_WORKER" } else { -1 })
$residentBeginTransaction = $(if ($transactionInstallerMode) { Get-MapSymbol $residentSymbols "STR8_I_BEGIN_TRANSACTION" } else { -1 })
$residentFinishTransaction = $(if ($transactionInstallerMode) { Get-MapSymbol $residentSymbols "STR8_I_FINISH_TRANSACTION" } else { -1 })
$residentDispatchEntry = Get-MapSymbol $residentSymbols "STR8_DISPATCH_A"
$residentConfirmEntry = Get-MapSymbol $residentSymbols "STR8_CONFIRM_Y"
$residentReadHook = Get-MapSymbol $residentSymbols "STR8_CON_READ_BYTE_BLOCK"
$residentReadNonblockHook = Get-MapSymbol $residentSymbols "STR8_CON_READ_BYTE_NONBLOCK"
$residentWriteHook = Get-MapSymbol $residentSymbols "STR8_CON_WRITE_BYTE_BLOCK"
$residentStartupEntry = Get-MapSymbol $residentSymbols "STR8_STARTUP_DELAY"
$residentStartupDelayHook = Get-MapSymbol $residentSymbols "STR8_DELAY_FIXED_A"
$residentBootPollEntry = Get-MapSymbol $residentSymbols "STR8_BOOT_KEY_POLL"
$residentIdMessage = Get-MapSymbol $residentSymbols "MSG_ID"
$residentBootPrompt = Get-MapSymbol $residentSymbols "MSG_BOOT_PROMPT"
$residentSkipLf = Get-MapSymbol $residentSymbols "STR8_INPUT_SKIP_LF"
$residentInstallBank = Get-MapSymbol $residentSymbols "STR8_INSTALL_BANK"
$residentInstallType = Get-MapSymbol $residentSymbols "STR8_INSTALL_TYPE"
$residentInstallDesc = Get-MapSymbol $residentSymbols "STR8_INSTALL_DESC"
$residentInstallState = Get-MapSymbol $residentSymbols "STR8_INSTALL_STATE"
$residentInstallPair = Get-MapSymbol $residentSymbols "STR8_INSTALL_PAIR"
$residentInstallEntryLo = Get-MapSymbol $residentSymbols "STR8_INSTALL_ENTRY_LO"
$residentInstallEntryHi = Get-MapSymbol $residentSymbols "STR8_INSTALL_ENTRY_HI"
$residentInstallExpectLo = Get-MapSymbol $residentSymbols "STR8_INSTALL_EXPECT_LO"
$residentInstallExpectHi = Get-MapSymbol $residentSymbols "STR8_INSTALL_EXPECT_HI"
$residentInstallLimitHi = Get-MapSymbol $residentSymbols "STR8_INSTALL_LIMIT_HI"
$residentInstallPhase = Get-MapSymbol $residentSymbols "STR8_INSTALL_PHASE"
$residentInstallSectorHi = Get-MapSymbol $residentSymbols "STR8_INSTALL_SECTOR_HI"
$residentInstallStatus = Get-MapSymbol $residentSymbols "STR8_INSTALL_STATUS"
$residentScreen = Get-MapSymbol $residentSymbols "MSG_SCREEN"
$residentHelp = Get-MapSymbol $residentSymbols "MSG_HELP"
$residentWorkerHook = Get-MapSymbol $residentSymbols "STR8_RUN_PROGRAM_RECORD_WORKER"
$script:mutationWorkerRecords = @()
$script:mutationWorkerImage = [byte[]]@()
$script:mutationWorkerEnd = 0x0200
if ($transactionInstallerMode) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($MutationWorkerS19Path)) `
        'Transaction installer requires a mutation-worker S19'
    $mutationWorker = Read-MutationWorkerFixture $MutationWorkerS19Path
    $mutationEnd = Get-MapSymbol $residentSymbols 'STR8_MUTATION_WORKER_END'
    $mutationSig = Get-MapSymbol $residentSymbols 'STR8_MUTATION_WORKER_SIG'
    Assert-True ($mutationWorker.End -eq $mutationEnd) `
        ('Mutation-worker end is ${0:X4}; resident expects ${1:X4}' -f $mutationWorker.End, $mutationEnd)
    Assert-True ($mutationSig -eq 0x0203) 'Mutation-worker signature must remain at $0203'
    [byte[]]$expectedMutationSig = 0x49, 0x57, 0x01, 0xFE
    [byte[]]$actualMutationSig = $mutationWorker.Image[3..6]
    Assert-ByteArraysEqual $actualMutationSig $expectedMutationSig 'Mutation-worker identity mismatch'
    $script:mutationWorkerRecords = $mutationWorker.Records
    $script:mutationWorkerImage = $mutationWorker.Image
    $script:mutationWorkerEnd = $mutationWorker.End
    Assert-True ((Get-MapSymbol $residentSymbols 'STR8_INSTALL_WORKER') -eq 0x15) `
        'Mutation-worker receive failure status must remain $15'
}
Assert-True (($residentInstallBank -eq 0x90) -and
    ($residentInstallType -eq 0x91) -and
    ($residentInstallDesc -eq 0x92) -and
    ($residentInstallState -eq 0x97) -and
    ($residentInstallPair -eq 0x98) -and
    ($residentInstallEntryLo -eq 0x99) -and
    ($residentInstallEntryHi -eq 0x9A) -and
    ($residentInstallExpectLo -eq 0x9B) -and
    ($residentInstallExpectHi -eq 0x9C) -and
    ($residentInstallLimitHi -eq 0x9D) -and
    ($residentInstallPhase -eq 0x9E) -and
    ($residentInstallSectorHi -eq 0x9F) -and
    ($residentInstallStatus -eq 0xA0) -and
    ($residentInstallStatus -lt 0xCD)) `
    'Resident I state must occupy only the $90-$A0 transient ZP frame'
if ($dryInstallerMode) {
    Assert-True ($residentEnd -le $dirBase) 'Installer-dry resident crosses the immutable directory boundary'
} else {
    Assert-True ($workerGap -ge $workerReserveFloor) 'V1 preview violates the resident/worker reserve floor'
}
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
        'STR8_CMD_UPDATE_HIMON', 'STR8_CMD_G_HIMON', 'STR8_CMD_RESET', 'STR8_CMD_COPY_FAIL',
        'STR8_UPD_INIT', 'STR8_READ_HIMON_S19', 'STR8_PROGRAM_HIMON_UPDATE',
        'STR8_PRINT_COPY_FAIL', 'MSG_UPDATE_HIMON', 'MSG_G_HIMON',
        'STR8_CMD_ID', 'MSG_UNKNOWN'
    )) {
    Assert-True (-not $residentSymbols.ContainsKey($retiredName)) "Retired V1 command symbol remains: $retiredName"
}
[byte[]]$expectedV1Help = [System.Text.Encoding]::ASCII.GetBytes('I 0-3 J0-3')
for ($i = 0; $i -lt $expectedV1Help.Length; $i++) {
    Assert-True ($residentTemplate[$residentScreen + $i] -eq $expectedV1Help[$i]) 'V1 prompt does not publish I/0-3/J0-3'
}
Assert-True ($residentHelp -eq $residentScreen) 'V1 screen/help command list unexpectedly has a prefix'
if ($transactionInstallerMode) {
    foreach ($deadName in @('STR8_ENTER_MENU', 'STR8_PRINT_SCREEN', 'STR8_CMD_OK', 'MSG_OK')) {
        Assert-True (-not $residentSymbols.ContainsKey($deadName)) `
            "Transaction-only dead symbol remains: $deadName"
    }
    $txnPrintPage0 = Get-MapSymbol $residentSymbols 'STR8_PRINT_TXN_PAGE0_X'
    $txnPrintPage1 = Get-MapSymbol $residentSymbols 'STR8_PRINT_TXN_PAGE1_X'
    $residentPrintXy = Get-MapSymbol $residentSymbols 'STR8_PRINT_XY'
    $txnPage0High = (Get-MapSymbol $residentSymbols 'MSG_ID') -shr 8
    $txnPage1High = (Get-MapSymbol $residentSymbols 'MSG_CRLF') -shr 8
    $txnSummaryAddress = Get-MapSymbol $residentSymbols 'MSG_I_SUMMARY'
    $txnInstallOkAddress = Get-MapSymbol $residentSymbols 'MSG_I_INSTALL_OK'
    $txnRange32Address = Get-MapSymbol $residentSymbols 'MSG_I_RANGE_32K'
    $txnTypeAddress = Get-MapSymbol $residentSymbols 'MSG_I_TYPE'
    $txnDescAddress = Get-MapSymbol $residentSymbols 'MSG_I_DESC'
    $txnEntryAddress = Get-MapSymbol $residentSymbols 'MSG_I_ENTRY'
    $txnEmptyAddress = Get-MapSymbol $residentSymbols 'MSG_I_EMPTY'
    $txnSetDirAddress = Get-MapSymbol $residentSymbols 'STR8_I_SET_DIR_ADDRESS_A'
    $txnStageReadyAddress = Get-MapSymbol $residentSymbols 'STR8_I_STAGE_SECTOR_READY'
    $txnWriteByteAddress = Get-MapSymbol $residentSymbols 'STR8_CON_WRITE_BYTE_BLOCK'
    $str8SourcePath = Join-Path (Split-Path -Parent $ConstantsPath) 'str8.asm'
    $txnPage0CallCount = (Select-String -LiteralPath $str8SourcePath `
        -Pattern '^\s+(?:JSR|JMP)\s+STR8_PRINT_TXN_PAGE0_X\s*$').Count
    $txnPage1CallCount = (Select-String -LiteralPath $str8SourcePath `
        -Pattern '^\s+(?:JSR|JMP)\s+STR8_PRINT_TXN_PAGE1_X\s*$').Count

    Assert-True (($residentSize -eq 0x0ED4) -and
        ($txnPage0High -eq 0xFD) -and ($txnPage1High -eq 0xFE) -and
        ($txnPage1High -eq $txnPage0High + 1) -and
        ($txnSummaryAddress -eq 0xFE29) -and ($txnInstallOkAddress -eq 0xFE2E) -and
        ($txnRange32Address -eq 0xFE36) -and ($txnTypeAddress -eq 0xFE4C) -and
        ($txnDescAddress -eq 0xFE50) -and ($txnEntryAddress -eq 0xFE53) -and
        ($txnEmptyAddress -eq 0xFE57) -and
        ($txnPage0CallCount -eq 8) -and ($txnPage1CallCount -eq 29)) `
        'Transaction worker-upload pass must retain its exact size, boundary, and 8/29 call split'
    Assert-True (($txnPrintPage0 + 4 -eq $txnPrintPage1) -and
        ($txnPrintPage1 + 2 -eq $residentPrintXy)) `
        'Transaction print-page helpers must be the six bytes immediately before STR8_PRINT_XY'
    [byte[]]$actualTxnPrintHelpers = $residentTemplate[$txnPrintPage0..($txnPrintPage1 + 1)]
    [byte[]]$expectedTxnPrintHelpers = @(0xA0, $txnPage0High, 0x80, 0x02, 0xA0, $txnPage1High)
    Assert-ByteArraysEqual $actualTxnPrintHelpers $expectedTxnPrintHelpers `
        'Transaction print-page helper opcodes changed'
    [byte[]]$actualTxnBankShift = $residentTemplate[($txnSetDirAddress + 3)..($txnSetDirAddress + 8)]
    [byte[]]$expectedTxnBankShift = @(0x0A, 0x0A, 0x0A, 0x0A, 0x69, 0xB0)
    Assert-ByteArraysEqual $actualTxnBankShift $expectedTxnBankShift `
        'Transaction directory address must reuse carry cleared by the fourth bank shift'
    [byte[]]$actualTxnStageTail = $residentTemplate[($txnStageReadyAddress + 25)..($txnStageReadyAddress + 29)]
    [byte[]]$expectedTxnStageTail = @(
        0xA9, 0x2E, 0x4C,
        ($txnWriteByteAddress -band 0xFF), ($txnWriteByteAddress -shr 8)
    )
    Assert-ByteArraysEqual $actualTxnStageTail $expectedTxnStageTail `
        'Transaction sector dot must tail-call the carry-setting blocking writer'

    foreach ($messageName in @(
            'MSG_ID', 'MSG_BOOT_MENU', 'MSG_SCREEN', 'MSG_HELP', 'MSG_PROMPT',
            'MSG_BOOT_PROMPT', 'MSG_BOOT_BANK_WAIT', 'MSG_ABORT'
        )) {
        $messageAddress = Get-MapSymbol $residentSymbols $messageName
        Assert-True (($messageAddress -shr 8) -eq $txnPage0High) `
            ("Transaction page-0 message moved pages: $messageName")
    }
    foreach ($messageName in @(
            'MSG_I_BANK', 'MSG_I_TYPE_PROMPT', 'MSG_I_DESC_PROMPT',
            'MSG_I_INVALID', 'MSG_I_SUMMARY', 'MSG_I_INSTALL_OK',
            'MSG_I_RANGE_32K', 'MSG_I_RANGE_28K', 'MSG_I_TYPE', 'MSG_I_DESC',
            'MSG_I_ENTRY',
            'MSG_I_EMPTY', 'MSG_I_INCOMPLETE', 'MSG_I_COMPLETE',
            'MSG_I_FULL', 'MSG_I_PAIR', 'MSG_I_WRITE_CONFIRM', 'MSG_I_SEND_S19',
            'MSG_I_TRANSACTION_FAIL', 'MSG_I_S19_FAIL',
            'MSG_I_NO_WRITE', 'MSG_NO_BOOT', 'MSG_JUMP_B', 'MSG_JUMP_FAIL_B',
            'MSG_JUMP_FAIL_VEC', 'MSG_CRLF'
        )) {
        $messageAddress = Get-MapSymbol $residentSymbols $messageName
        Assert-True (($messageAddress -shr 8) -eq $txnPage1High) `
            ("Transaction page-1 message moved pages: $messageName")
    }
}
$residentJournalCases = 0
$residentRecordCases = 0
$residentWriterCases = 0
$residentLineCases = 0
$residentInstallerCases = 0
$residentStartupCases = 0
$residentMaxSteps = 0

# Run the compiled two-phase startup routine with an early R queued before the
# midpoint and G/R/S arriving on successive live dots. The midpoint flush must
# discard the early R; live G/R must remain silent; only S may terminate and
# echo. Delay calls are hooked so this verifies sequencing without wall time.
$startupTimedInput = @(
    [pscustomobject]@{ AfterDelay = 0; Byte = [byte][char]'R' },
    [pscustomobject]@{ AfterDelay = 17; Byte = [byte][char]'G' },
    [pscustomobject]@{ AfterDelay = 18; Byte = [byte][char]'R' },
    [pscustomobject]@{ AfterDelay = 19; Byte = [byte][char]'S' }
)
[byte[]]$startupMemory = $residentTemplate.Clone()
$startup = Invoke-ResidentDirectoryRoutine -Memory $startupMemory `
    -Start $residentStartupEntry `
    -ReadNonblockHook $residentReadNonblockHook `
    -DelayHook $residentStartupDelayHook `
    -WriteHook $residentWriteHook `
    -TimedInput $startupTimedInput
$idText = [System.Text.Encoding]::ASCII.GetString((Get-HighBitStringBytes $residentTemplate $residentIdMessage))
$bootPromptText = [System.Text.Encoding]::ASCII.GetString((Get-HighBitStringBytes $residentTemplate $residentBootPrompt))
[byte[]]$expectedStartup = [System.Text.Encoding]::ASCII.GetBytes(
    (("`n" * 35) + "................`r`n${idText}${bootPromptText}...S"))
Assert-ByteArraysEqual $startup.Output $expectedStartup 'Two-phase startup output mismatch'
Assert-True ($startup.Carry -and $startup.A -eq [byte][char]'S' -and
    $startup.DelayCalls -eq 19 -and $startup.TimedInputConsumed -eq $startupTimedInput.Count) `
    'Two-phase startup did not quarantine early R and accept only the live S'
$residentMaxSteps = [Math]::Max($residentMaxSteps, $startup.Steps)
$residentStartupCases++

[byte[]]$startupMemory = $residentTemplate.Clone()
$startup = Invoke-ResidentDirectoryRoutine -Memory $startupMemory `
    -Start $residentStartupEntry `
    -ReadNonblockHook $residentReadNonblockHook `
    -DelayHook $residentStartupDelayHook `
    -WriteHook $residentWriteHook
[byte[]]$expectedStartup = [System.Text.Encoding]::ASCII.GetBytes(
    (("`n" * 35) + "................`r`n${idText}${bootPromptText}................"))
Assert-ByteArraysEqual $startup.Output $expectedStartup 'Two-phase startup timeout output mismatch'
Assert-True (-not $startup.Carry -and $startup.DelayCalls -eq 32) `
    'Two-phase startup timeout did not complete exactly 16 attach plus 16 live dots'
$residentMaxSteps = [Math]::Max($residentMaxSteps, $startup.Steps)
$residentStartupCases++

foreach ($pollCase in @(
        [pscustomobject]@{ Input = '0'; Accepted = $true; Echo = '0' },
        [pscustomobject]@{ Input = '1'; Accepted = $true; Echo = '1' },
        [pscustomobject]@{ Input = '2'; Accepted = $true; Echo = '2' },
        [pscustomobject]@{ Input = '3'; Accepted = $true; Echo = '3' },
        [pscustomobject]@{ Input = 's'; Accepted = $true; Echo = 'S' },
        [pscustomobject]@{ Input = 'G'; Accepted = $false; Echo = '' },
        [pscustomobject]@{ Input = 'R'; Accepted = $false; Echo = '' },
        [pscustomobject]@{ Input = '4'; Accepted = $false; Echo = '' },
        [pscustomobject]@{ Input = "`r"; Accepted = $false; Echo = '' },
        [pscustomobject]@{ Input = "`n"; Accepted = $false; Echo = '' }
    )) {
    [byte[]]$pollInput = [System.Text.Encoding]::ASCII.GetBytes($pollCase.Input)
    $poll = Invoke-ResidentDirectoryRoutine -Memory ([byte[]]$residentTemplate.Clone()) `
        -Start $residentBootPollEntry `
        -ReadNonblockHook $residentReadNonblockHook `
        -WriteHook $residentWriteHook `
        -InputBytes $pollInput
    [byte[]]$expectedEcho = [System.Text.Encoding]::ASCII.GetBytes($pollCase.Echo)
    Assert-ByteArraysEqual $poll.Output $expectedEcho ("Live selector {0} echo mismatch" -f [int]$pollInput[0])
    Assert-True ($poll.Carry -eq $pollCase.Accepted -and $poll.InputConsumed -eq 1) `
        ("Live selector {0} acceptance mismatch" -f [int]$pollInput[0])
    $residentMaxSteps = [Math]::Max($residentMaxSteps, $poll.Steps)
    $residentStartupCases++
}

foreach ($unknownCommand in @('?', 'G', 'R', 'X')) {
    [byte[]]$memory = $residentTemplate.Clone()
    $unknown = Invoke-ResidentDirectoryRoutine -Memory $memory `
        -Start $residentDispatchEntry `
        -A ([byte][char]$unknownCommand) `
        -WriteHook $residentWriteHook
    [byte[]]$expectedUnknown = [System.Text.Encoding]::ASCII.GetBytes("`r`nI 0-3 J0-3`r`n")
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
$expectedPreview = "`r`nI B0-3: 2`r`nTYPE: A5`r`nDESC: RYORS`r`nI B2 8000-FFFF `r`nT=A5 D=RYORS EMPTY P=00 NO WRITE`r`n"
if ($dryInstallerMode) {
    [byte[]]$lineInput = $lineInput + [System.Text.Encoding]::ASCII.GetBytes("n`r")
    $expectedPreview = "`r`nI B0-3: 2`r`nTYPE: A5`r`nDESC: RYORS`r`nI B2 8000-FFFF `r`nT=A5 D=RYORS EMPTY P=00 $installerConfirmText`? Y: N`r`nABORT`r`n"
}
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'empty Bank 2 metadata'
Assert-True ($previewFixture.Memory[$residentInstallBank] -eq 2 -and
    $previewFixture.Memory[$residentInstallType] -eq 0xA5 -and
    $previewFixture.Memory[$residentInstallState] -eq $recordEmpty -and
    $previewFixture.Memory[$residentInstallPair] -eq 0) 'Resident I Bank-2 persistent preflight state mismatch'
Assert-True ([System.Text.Encoding]::ASCII.GetString($previewFixture.Memory, $residentInstallDesc, 5) -ceq 'RYORS') `
    'Resident I Bank-2 description state mismatch'

[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("3`r5a`rstr8n`r")
$expectedPreview = "`r`nI B0-3: 3`r`nTYPE: 5A`r`nDESC: STR8N`r`nI B3 8000-EFFF `r`nT=5A D=STR8N EMPTY P=00 NO WRITE`r`n"
if ($dryInstallerMode) {
    [byte[]]$lineInput = $lineInput + [System.Text.Encoding]::ASCII.GetBytes("n`r")
    $expectedPreview = "`r`nI B0-3: 3`r`nTYPE: 5A`r`nDESC: STR8N`r`nI B3 8000-EFFF `r`nT=5A D=STR8N EMPTY P=00 $installerConfirmText`? Y: N`r`nABORT`r`n"
}
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'empty Bank 3 range'
Assert-True ($previewFixture.Memory[$residentInstallBank] -eq 3 -and
    $previewFixture.Memory[$residentInstallEntryLo] -eq 0xFF -and
    $previewFixture.Memory[$residentInstallEntryHi] -eq 0xFF) 'Resident I empty Bank-3 state mismatch'

[byte[]]$completeRecord = New-Record 1 'HELLO' 0xFFFF (New-Journal 1 $false)
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("1`r")
$expectedPreview = "`r`nI B0-3: 1`r`nI B1 8000-FFFF `r`nT=5A D=HELLO COMPLETE P=01 NO WRITE`r`n"
if ($dryInstallerMode) {
    [byte[]]$lineInput = $lineInput + [System.Text.Encoding]::ASCII.GetBytes("n`r")
    $expectedPreview = "`r`nI B0-3: 1`r`nI B1 8000-FFFF `r`nT=5A D=HELLO COMPLETE P=01 $installerConfirmText`? Y: N`r`nABORT`r`n"
}
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 1 = $completeRecord }
Assert-ResidentIPreviewFixture $previewFixture $lineInput $expectedPreview 'existing complete Bank 1'

[byte[]]$incompleteRecord = New-Record 3 'LOCAL' 0xC030 (New-Journal 2 $true)
[byte[]]$lineInput = [System.Text.Encoding]::ASCII.GetBytes("3`n")
$expectedPreview = "`r`nI B0-3: 3`r`nI B3 8000-EFFF `r`nT=5A D=LOCAL E=`$C030 INCOMPLETE P=02 NO WRITE`r`n"
if ($dryInstallerMode) {
    [byte[]]$lineInput = $lineInput + [System.Text.Encoding]::ASCII.GetBytes("n`r")
    $expectedPreview = "`r`nI B0-3: 3`r`nI B3 8000-EFFF `r`nT=5A D=LOCAL E=`$C030 INCOMPLETE P=02 $installerConfirmText`? Y: N`r`nABORT`r`n"
}
$previewFixture = Invoke-ResidentIPreviewFixture $lineInput @{ 3 = $incompleteRecord }
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
        [pscustomobject]@{ Name = 'bank 4'; Input = [byte[]]@([byte][char]'4', 0x0A); Output = "`r`nI B0-3: 4`r`nI 0-3 J0-3`r`n" },
        [pscustomobject]@{ Name = 'bad type'; Input = [System.Text.Encoding]::ASCII.GetBytes("0`rG0`r"); Output = "`r`nI B0-3: 0`r`nTYPE: G0`r`nI 0-3 J0-3`r`n" },
        [pscustomobject]@{ Name = 'bad description'; Input = [System.Text.Encoding]::ASCII.GetBytes("0`r12`rAB CD`r"); Output = "`r`nI B0-3: 0`r`nTYPE: 12`r`nDESC: AB CD`r`nI 0-3 J0-3`r`n" }
    )) {
    $previewFixture = Invoke-ResidentIPreviewFixture $negativePreview.Input
    Assert-ResidentIPreviewFixture $previewFixture $negativePreview.Input $negativePreview.Output $negativePreview.Name
}

if ($dryInstallerMode) {
    $dense32 = New-DenseRecordFixture -Length 0x8000 -Entry 0x8000 -ChunkLength 251 -IncludeS0 $true
    [byte[]]$denseInput = [System.Text.Encoding]::ASCII.GetBytes("2`ra5`rryors`ry`r")
    $dense28 = New-DenseRecordFixture -Length 0x7000 -Entry 0x8000 -ChunkLength 193 -IncludeS0 $false
    if ($transactionInstallerMode) {
        $transactionFixture = Invoke-ResidentITransactionFixture -InputBytes $denseInput -DenseRecords $dense32.Records
        $expectedTransaction = "`r`nI B0-3: 2`r`nTYPE: A5`r`nDESC: RYORS`r`nI B2 8000-FFFF `r`nT=A5 D=RYORS EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n........`r`nI OK`r`n"
        Assert-TransactionOutput $transactionFixture $denseInput $expectedTransaction '32K Bank 2 success'
        Assert-TransactionFlash $transactionFixture 2 $dense32 8 '32K Bank 2 success'
        [byte[]]$expectedRecord = New-Record 2 'RYORS' 0xFFFF (New-Journal 1 $false)
        $expectedRecord[$offType] = 0xA5
        Assert-DirectoryRecord $transactionFixture 2 $expectedRecord '32K Bank 2 success'
        Assert-True ($transactionFixture.Cpu.WorkerCalls -eq 4) 'Bank-2 transaction directory-call count mismatch'
        [string[]]$expectedEvents = @('D:FFDC:1', 'D:FFD0:9')
        for ($sector = 0; $sector -lt 8; $sector++) {
            $expectedEvents += ('S:2:{0:X2}' -f (0x80 + ($sector * 0x10)))
        }
        $expectedEvents += @('D:FFD9:1', 'D:FFDC:1')
        Assert-StringArraysEqual $transactionFixture.Cpu.Events $expectedEvents `
            'Bank-2 START/metadata/sector/seal/COMPLETE order'

        [byte[]]$denseInput = [System.Text.Encoding]::ASCII.GetBytes("3`r5a`rstr8n`ry`n")
        $transactionFixture = Invoke-ResidentITransactionFixture -InputBytes $denseInput -DenseRecords $dense28.Records
        $expectedTransaction = "`r`nI B0-3: 3`r`nTYPE: 5A`r`nDESC: STR8N`r`nI B3 8000-EFFF `r`nT=5A D=STR8N EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n.......`r`nI OK`r`n"
        Assert-TransactionOutput $transactionFixture $denseInput $expectedTransaction '28K Bank 3 success'
        Assert-TransactionFlash $transactionFixture 3 $dense28 7 '28K Bank 3 success'
        $expectedRecord = New-Record 3 'STR8N' 0x8000 (New-Journal 1 $false)
        Assert-DirectoryRecord $transactionFixture 3 $expectedRecord '28K Bank 3 success'
        Assert-True ($transactionFixture.Cpu.WorkerCalls -eq 5) 'Bank-3 transaction directory-call count mismatch'
        [string[]]$expectedEvents = @('D:FFEC:1', 'D:FFE0:9')
        for ($sector = 0; $sector -lt 7; $sector++) {
            $expectedEvents += ('S:3:{0:X2}' -f (0x80 + ($sector * 0x10)))
        }
        $expectedEvents += @('D:FFEA:2', 'D:FFE9:1', 'D:FFEC:1')
        Assert-StringArraysEqual $transactionFixture.Cpu.Events $expectedEvents `
            'Bank-3 START/metadata/sector/entry/seal/COMPLETE order'

        # The transaction accepts exactly the linked mutation worker before
        # any persistent write. A bad identity, address gap, or short image
        # reports worker status $15 and leaves the directory untouched.
        [byte[]]$workerFailureInput = [System.Text.Encoding]::ASCII.GetBytes("0`r5a`rfail0`ry`r")
        $expectedWorkerFailure = "`r`nI B0-3: 0`r`nTYPE: 5A`r`nDESC: FAIL0`r`nI B0 8000-FFFF `r`nT=5A D=FAIL0 EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n`r`nI FAIL `$15`r`n"

        [object[]]$badWorker = @($script:mutationWorkerRecords)
        [byte[]]$badWorkerData = ([byte[]]$badWorker[0].Data).Clone()
        $badWorkerData[3] = $badWorkerData[3] -bxor 0x01
        $badWorker[0] = [pscustomobject]@{
            FailStatus = 0; Kind = 2; Address = 0x0200; Data = $badWorkerData; Entry = 0
        }
        $fixture = Invoke-ResidentITransactionFixture -InputBytes $workerFailureInput `
            -DenseRecords $dense32.Records -WorkerRecords $badWorker
        Assert-TransactionOutput $fixture $workerFailureInput $expectedWorkerFailure 'mutation-worker identity failure'
        Assert-True ($fixture.Cpu.WorkerCalls -eq 0) 'Bad mutation-worker identity reached a flash worker'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Bad mutation-worker identity changed directory'

        [object[]]$badWorker = @($script:mutationWorkerRecords)
        $gapRecord = $badWorker[1]
        $badWorker[1] = [pscustomobject]@{
            FailStatus = 0; Kind = 2; Address = ([int]$gapRecord.Address + 1)
            Data = [byte[]]$gapRecord.Data; Entry = 0
        }
        $fixture = Invoke-ResidentITransactionFixture -InputBytes $workerFailureInput `
            -DenseRecords $dense32.Records -WorkerRecords $badWorker
        Assert-TransactionOutput $fixture $workerFailureInput $expectedWorkerFailure 'mutation-worker address gap'
        Assert-True ($fixture.Cpu.WorkerCalls -eq 0) 'Mutation-worker address gap reached a flash worker'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Mutation-worker address gap changed directory'

        [object[]]$shortWorker = $script:mutationWorkerRecords[0..($script:mutationWorkerRecords.Length - 2)]
        $fixture = Invoke-ResidentITransactionFixture -InputBytes $workerFailureInput `
            -DenseRecords $dense32.Records -WorkerRecords $shortWorker
        Assert-TransactionOutput $fixture $workerFailureInput $expectedWorkerFailure 'short mutation worker'
        Assert-True ($fixture.Cpu.WorkerCalls -eq 0) 'Short mutation worker reached a flash worker'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Short mutation worker changed directory'

        # BEGIN failure boundaries: START failure changes nothing; metadata
        # failure leaves a visible START pair and an unsealed descriptor.
        [byte[]]$emptyTxnRecord = New-Object byte[] $recordSize
        for ($i = 0; $i -lt $recordSize; $i++) { $emptyTxnRecord[$i] = $emptyByte }
        $fixture = Invoke-TransactionRoutineFixture -Start $residentBeginTransaction `
            -Bank 0 -State $recordEmpty -Pair 0 -Record $emptyTxnRecord -Description 'NEW00' -WorkerFailAt 1
        Assert-True (-not $fixture.Cpu.Carry -and $fixture.Cpu.WorkerCalls -eq 1) `
            'Transaction START worker failure did not stop BEGIN'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Transaction START failure changed directory'
        $residentInstallerCases++

        [byte[]]$beginFailureInput = [System.Text.Encoding]::ASCII.GetBytes("0`r5a`rfail0`ry`r")
        $fixture = Invoke-ResidentITransactionFixture -InputBytes $beginFailureInput `
            -DenseRecords $dense32.Records -WorkerFailAt 1
        $expectedFailure = "`r`nI B0-3: 0`r`nTYPE: 5A`r`nDESC: FAIL0`r`nI B0 8000-FFFF `r`nT=5A D=FAIL0 EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n`r`nDIR FAIL `$04`r`n"
        Assert-TransactionOutput $fixture $beginFailureInput $expectedFailure 'START directory failure'
        Assert-True ($fixture.Memory[$residentInstallStatus] -eq 0x14) `
            'START directory failure did not publish installer status $14'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Command-level START failure changed directory'

        $fixture = Invoke-TransactionRoutineFixture -Start $residentBeginTransaction `
            -Bank 0 -State $recordEmpty -Pair 0 -Record $emptyTxnRecord -Description 'NEW00' -WorkerFailAt 2
        Assert-True (-not $fixture.Cpu.Carry -and $fixture.Cpu.WorkerCalls -eq 2) `
            'Transaction metadata worker failure did not stop BEGIN'
        [byte[]]$actualRecord = $fixture.AfterDirectory[0..($recordSize - 1)]
        $journal = Get-JournalResult ([byte[]]$actualRecord[$offJournal..($offJournal + $journalLength - 1)])
        Assert-True ($journal.State -eq $journalStarted -and $journal.Pair -eq 0 -and
            $actualRecord[$offSeal] -eq $emptyByte) `
            'Metadata failure did not leave STARTED/unsealed state'
        $residentInstallerCases++

        # FINISH boundaries for a first Bank-3 install: ENTRY, SEAL, and
        # COMPLETE are separate verified writes, and COMPLETE is last.
        [byte[]]$provisional3 = New-ProvisionalRecord 0x5A 'STR8N' 0xFFFF (New-Journal 0 $true)
        foreach ($finishFailure in @(
                [pscustomobject]@{ Call = 1; Seal = $emptyByte; State = $recordInvalid; Name = 'entry' },
                [pscustomobject]@{ Call = 2; Seal = $emptyByte; State = $recordInvalid; Name = 'seal' },
                [pscustomobject]@{ Call = 3; Seal = $sealValue; State = $recordIncomplete; Name = 'complete' }
            )) {
            $fixture = Invoke-TransactionRoutineFixture -Start $residentFinishTransaction `
                -Bank 3 -State $recordEmpty -Pair 0 -Record $provisional3 -Entry 0x8000 `
                -WorkerFailAt $finishFailure.Call
            Assert-True (-not $fixture.Cpu.Carry -and
                $fixture.Cpu.WorkerCalls -eq $finishFailure.Call) `
                ("Transaction Bank-3 $($finishFailure.Name) failure did not stop FINISH")
            [byte[]]$actualRecord = $fixture.AfterDirectory[(3 * $recordSize)..((4 * $recordSize) - 1)]
            $recordResult = Get-RecordResult 3 $actualRecord
            Assert-True ($actualRecord[$offSeal] -eq $finishFailure.Seal -and
                $recordResult.State -eq $finishFailure.State) `
                ("Transaction Bank-3 $($finishFailure.Name) failure state mismatch")
            $journal = Get-JournalResult ([byte[]]$actualRecord[$offJournal..($offJournal + $journalLength - 1)])
            Assert-True ($journal.State -eq $journalStarted -and $journal.Pair -eq 0) `
                ("Transaction Bank-3 $($finishFailure.Name) failure completed journal")
            $residentInstallerCases++
        }

        $fixture = Invoke-TransactionRoutineFixture -Start $residentFinishTransaction `
            -Bank 3 -State $recordEmpty -Pair 0 -Record $provisional3 -Entry 0x8000
        $expectedRecord = New-Record 3 'STR8N' 0x8000 (New-Journal 1 $false)
        Assert-DirectoryRecord $fixture 3 $expectedRecord 'direct Bank-3 FINISH success'
        Assert-StringArraysEqual $fixture.Cpu.Events @('D:FFEA:2', 'D:FFE9:1', 'D:FFEC:1') `
            'Direct Bank-3 FINISH order'
        $residentInstallerCases++

        # Completed records consume the next pair. Incomplete records retry
        # the same START pair idempotently and complete it without replacing
        # immutable metadata.
        [byte[]]$retryRecord = New-Record 1 'HELLO' 0xFFFF (New-Journal 1 $false)
        $fixture = Invoke-TransactionRoutineFixture -Start $residentBeginTransaction `
            -Bank 1 -State $recordComplete -Pair 1 -Record $retryRecord -Description 'XXXXX'
        Assert-True ($fixture.Cpu.Carry -and $fixture.Cpu.WorkerCalls -eq 1) `
            'Complete-record next-pair START failed'
        [byte[]]$startedRecord = $fixture.AfterDirectory[$recordSize..((2 * $recordSize) - 1)]
        $recordResult = Get-RecordResult 1 $startedRecord
        Assert-True ($recordResult.State -eq $recordIncomplete -and $recordResult.Pair -eq 1) `
            'Complete-record next pair was not STARTED'
        $fixture = Invoke-TransactionRoutineFixture -Start $residentFinishTransaction `
            -Bank 1 -State $recordComplete -Pair 1 -Record $startedRecord
        $expectedRecord = New-Record 1 'HELLO' 0xFFFF (New-Journal 2 $false)
        Assert-DirectoryRecord $fixture 1 $expectedRecord 'complete-record next-pair completion'
        $residentInstallerCases++

        [byte[]]$retryRecord = New-Record 3 'LOCAL' 0x8000 (New-Journal 2 $true)
        $fixture = Invoke-TransactionRoutineFixture -Start $residentBeginTransaction `
            -Bank 3 -State $recordIncomplete -Pair 2 -Record $retryRecord -Entry 0x8000
        Assert-True ($fixture.Cpu.Carry -and $fixture.Cpu.WorkerCalls -eq 1) `
            'Incomplete-record retry START failed'
        Assert-ByteArraysEqual $fixture.AfterDirectory $fixture.BeforeDirectory `
            'Incomplete-record idempotent START changed directory'
        $fixture = Invoke-TransactionRoutineFixture -Start $residentFinishTransaction `
            -Bank 3 -State $recordIncomplete -Pair 2 -Record $retryRecord -Entry 0x8000
        $expectedRecord = New-Record 3 'LOCAL' 0x8000 (New-Journal 3 $false)
        Assert-DirectoryRecord $fixture 3 $expectedRecord 'incomplete-record retry completion'
        $residentInstallerCases++

        # Every legal 32K sector boundary reaches mode $05 with the exact
        # target high byte. An injected worker failure returns carry clear and
        # leaves the modeled destination unchanged.
        for ($sectorHigh = 0x80; $sectorHigh -le 0xF0; $sectorHigh += 0x10) {
            $fixture = Invoke-TransactionRoutineFixture -Start $residentStageHook `
                -Bank 2 -State $recordComplete -Pair 1 -Record $emptyTxnRecord `
                -SectorHigh $sectorHigh
            Assert-True ($fixture.Cpu.Carry -and $fixture.Cpu.SectorCalls -eq 1 -and
                $fixture.Cpu.Events[0] -ceq ('S:2:{0:X2}' -f $sectorHigh) -and
                $fixture.Memory[0x1FE9] -eq $sectorHigh -and
                $fixture.Memory[0x1FEF] -eq 2 -and
                $fixture.Memory[0x1FF0] -eq 0x05 -and
                $fixture.Memory[0x1FF6] -eq 0x0A) `
                ("Sector boundary `${0:X2} success mismatch" -f $sectorHigh)
            $fixture = Invoke-TransactionRoutineFixture -Start $residentStageHook `
                -Bank 2 -State $recordComplete -Pair 1 -Record $emptyTxnRecord `
                -SectorHigh $sectorHigh -SectorFailAt 1
            Assert-True (-not $fixture.Cpu.Carry -and $fixture.Cpu.SectorCalls -eq 1) `
                ("Sector boundary `${0:X2} failure mismatch" -f $sectorHigh)
            Assert-ByteArraysEqual $fixture.FlashBanks[2] $fixture.BeforeBanks[2] `
                ("Sector boundary `${0:X2} failure changed flash" -f $sectorHigh)
            $residentInstallerCases += 2
        }

        # Full-command receive and first-sector flash failures both leave a
        # STARTED journal, no seal, and no COMPLETE transition.
        [object[]]$badTransactionRecords = @($dense32.Records)
        $secondData = $badTransactionRecords[2]
        $badTransactionRecords[2] = [pscustomobject]@{
            FailStatus = 0; Kind = 2; Address = ([int]$secondData.Address + 1); Data = $secondData.Data; Entry = 0
        }
        [byte[]]$failureInput = [System.Text.Encoding]::ASCII.GetBytes("0`r5a`rfail0`ry`r")
        $fixture = Invoke-ResidentITransactionFixture -InputBytes $failureInput `
            -DenseRecords $badTransactionRecords
        $expectedFailure = "`r`nI B0-3: 0`r`nTYPE: 5A`r`nDESC: FAIL0`r`nI B0 8000-FFFF `r`nT=5A D=FAIL0 EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n`r`nI FAIL `$10`r`n"
        Assert-TransactionOutput $fixture $failureInput $expectedFailure 'receive failure after START'
        Assert-True ($fixture.Cpu.WorkerCalls -eq 2 -and $fixture.Cpu.SectorCalls -eq 0) `
            'Receive failure reached a sector or later directory write'
        [byte[]]$actualRecord = $fixture.AfterDirectory[0..($recordSize - 1)]
        $journal = Get-JournalResult ([byte[]]$actualRecord[$offJournal..($offJournal + $journalLength - 1)])
        Assert-True ($journal.State -eq $journalStarted -and $actualRecord[$offSeal] -eq $emptyByte) `
            'Receive failure did not remain STARTED/unsealed'

        $fixture = Invoke-ResidentITransactionFixture -InputBytes $failureInput `
            -DenseRecords $dense32.Records -SectorFailAt 1
        $expectedFailure = "`r`nI B0-3: 0`r`nTYPE: 5A`r`nDESC: FAIL0`r`nI B0 8000-FFFF `r`nT=5A D=FAIL0 EMPTY P=00 WRITE? Y: Y`r`nSEND S19`r`n`r`nI FAIL `$12`r`n"
        Assert-TransactionOutput $fixture $failureInput $expectedFailure 'first-sector worker failure'
        Assert-True ($fixture.Cpu.WorkerCalls -eq 2 -and $fixture.Cpu.SectorCalls -eq 1) `
            'First-sector failure reached a later transaction boundary'
        Assert-ByteArraysEqual $fixture.FlashBanks[0] $fixture.BeforeBanks[0] `
            'First-sector failure changed modeled target flash'
    } else {
        $previewFixture = Invoke-ResidentIPreviewFixture -InputBytes $denseInput -DenseRecords $dense32.Records
        $expectedPreview = "`r`nI B0-3: 2`r`nTYPE: A5`r`nDESC: RYORS`r`nI B2 8000-FFFF `r`nT=A5 D=RYORS EMPTY P=00 STAGE? Y: Y`r`nSEND S19`r`nSTAGE OK NO WRITE`r`n"
        Assert-DenseStageFixture $previewFixture $dense32 8 $denseInput $expectedPreview '32K Bank 2 crossing stream'

        [byte[]]$denseInput = [System.Text.Encoding]::ASCII.GetBytes("3`r5a`rstr8n`ry`n")
        $previewFixture = Invoke-ResidentIPreviewFixture -InputBytes $denseInput -DenseRecords $dense28.Records
        $expectedPreview = "`r`nI B0-3: 3`r`nTYPE: 5A`r`nDESC: STR8N`r`nI B3 8000-EFFF `r`nT=5A D=STR8N EMPTY P=00 STAGE? Y: Y`r`nSEND S19`r`nSTAGE OK NO WRITE`r`n"
        Assert-DenseStageFixture $previewFixture $dense28 7 $denseInput $expectedPreview '28K Bank 3 crossing stream'
        Assert-True ($previewFixture.Memory[$residentInstallEntryLo] -eq 0x00 -and
            $previewFixture.Memory[$residentInstallEntryHi] -eq 0x80) `
            'Dense empty Bank-3 stage did not retain the validated local entry'
    }

    [object[]]$badRecords = @($dense32.Records)
    $firstData = $badRecords[1]
    $badRecords[1] = [pscustomobject]@{
        FailStatus = 0; Kind = 2; Address = 0x8001; Data = $firstData.Data; Entry = 0
    }
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 0x10 0 'initial gap'

    [object[]]$badRecords = @(
        [pscustomobject]@{ FailStatus = 0; Kind = 2; Address = 0x8000; Data = [byte[]]@(); Entry = 0 },
        [pscustomobject]@{ FailStatus = 0; Kind = 3; Address = 0x8000; Data = [byte[]]@(); Entry = 0x8000 }
    )
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 0x10 0 'zero-length S1'

    [object[]]$badRecords = @(
        [pscustomobject]@{ FailStatus = 0; Kind = 3; Address = 0x8000; Data = [byte[]]@(); Entry = 0x8000 }
    )
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 0x10 0 'early S9'

    [object[]]$badRecords = @($dense32.Records)
    $badRecords[$badRecords.Length - 1] = [pscustomobject]@{
        FailStatus = 0; Kind = 3; Address = 0x9000; Data = [byte[]]@(); Entry = 0x9000
    }
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 0x11 0 'S9 reset mismatch' $transactionInstallerMode

    $bad28 = New-DenseRecordFixture -Length 0x7000 -Entry 0xF000 -ChunkLength 252 -IncludeS0 $false
    $fixture = Invoke-ResidentDenseFixture 3 $bad28.Records
    Assert-DenseReject $fixture 0x11 0 'Bank-3 entry range' $transactionInstallerMode

    $fixture = Invoke-ResidentDenseFixture -Bank 3 -DenseRecords $dense28.Records -State 3 -Entry 0xC030
    Assert-DenseReject $fixture 0x11 0 'immutable Bank-3 entry mismatch' $transactionInstallerMode

    [object[]]$badRecords = @(
        [pscustomobject]@{ FailStatus = 0; Kind = 1; Address = 0; Data = [byte[]]@(); Entry = 0 },
        [pscustomobject]@{ FailStatus = 0; Kind = 1; Address = 0; Data = [byte[]]@(); Entry = 0 }
    )
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 0x10 0 'duplicate S0'

    [object[]]$badRecords = @(
        [pscustomobject]@{ FailStatus = 8; Kind = 0; Address = 0; Data = [byte[]]@(); Entry = 0 }
    )
    $fixture = Invoke-ResidentDenseFixture 0 $badRecords
    Assert-DenseReject $fixture 8 0 'parser checksum failure'

    [byte[]]$trailing = [System.Text.Encoding]::ASCII.GetBytes('XY')
    $fixture = Invoke-ResidentDenseFixture -Bank 3 -DenseRecords $dense28.Records -InputBytes $trailing
    Assert-DenseReject $fixture 0x13 $trailing.Length 'queued data after S9' $transactionInstallerMode
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
Write-Host ("STR8 RESIDENT IMAGE     = {0:X4}-{1:X4}; `${2:X} bytes" -f $residentStart, ($residentEnd - 1), $residentSize)
if ($dryInstallerMode) {
    $installerLabel = if ($transactionInstallerMode) { "TXN" } else { "DRY" }
    Write-Host ("{0}/WORKER OVERLAP      = {1:X4}-{2:X4}; `${3:X} bytes" -f $installerLabel, $workerStoreStart, ($residentEnd - 1), $workerOverlap)
    Write-Host ("{0} FIT DEBT +`${1:X} GAP   = `${2:X} bytes" -f $installerLabel, $workerReserveFloor, $workerFitDebt)
} else {
    Write-Host ("RESIDENT/WORKER GAP     = {0:X4}-{1:X4}; `${2:X} bytes" -f $residentEnd, ($workerStoreStart - 1), $workerGap)
}
Write-Host ("RESIDENT JOURNAL CASES  = {0}" -f $residentJournalCases)
Write-Host ("RESIDENT RECORD CASES   = {0}" -f $residentRecordCases)
Write-Host ("RESIDENT WRITER CASES   = {0}" -f $residentWriterCases)
Write-Host ("RESIDENT LINE/I CASES   = {0}" -f $residentLineCases)
Write-Host ("RESIDENT STARTUP CASES  = {0}" -f $residentStartupCases)
if ($dryInstallerMode) {
    Write-Host ("RESIDENT INSTALL CASES  = {0}" -f $residentInstallerCases)
}
Write-Host ("RESIDENT MAX STEPS      = {0}" -f $residentMaxSteps)
Write-Host "STR8 V1 DIRECTORY CHECK = PASS"
if ($dryInstallerMode) {
    if ($transactionInstallerMode) {
        Write-Host "STR8 V1 INSTALLER TRANSACTION CHECK = PASS"
    } else {
        Write-Host "STR8 V1 INSTALLER DRY CHECK = PASS"
    }
}

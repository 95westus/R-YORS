param(
    [string]$HimonMapPath = "BUILD/map/himon-rom-c000.map",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$Str8MapPath = "BUILD/map/str8-f000.map",
    [string]$Str8S19Path = "BUILD/s19/str8-f000.s19",
    [string]$WorkerMapPath = "BUILD/map/str8-worker-0200.map",
    [string]$WorkerS19Path = "BUILD/s19/str8-worker-0200.s19"
)

$ErrorActionPreference = "Stop"

function Read-MapSymbols {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing map: $Path"
    }
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
    if (-not $Symbols.ContainsKey($key)) {
        throw "Missing symbol: $Name"
    }
    return [int]$Symbols[$key]
}

function Read-S19Memory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing S19: $Path"
    }
    [byte[]]$memory = New-Object byte[] 65536
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if (-not $line.StartsWith('S1', [System.StringComparison]::Ordinal)) {
            continue
        }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        if ($line.Length -ne (4 + ($count * 2))) {
            throw "Bad S1 length: $line"
        }
        $sum = $count
        for ($i = 0; $i -lt $count; $i++) {
            $sum += [Convert]::ToInt32($line.Substring(4 + ($i * 2), 2), 16)
        }
        if (($sum -band 0xFF) -ne 0xFF) {
            throw "Bad S1 checksum: $line"
        }
        $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
        $dataLength = $count - 3
        for ($i = 0; $i -lt $dataLength; $i++) {
            $memory[$address + $i] = [Convert]::ToByte($line.Substring(8 + ($i * 2), 2), 16)
        }
    }
    return ,$memory
}

function Test-ByteSequence {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [int]$EndExclusive,
        [byte[]]$Sequence
    )

    for ($address = $Start; $address -le ($EndExclusive - $Sequence.Length); $address++) {
        $match = $true
        for ($i = 0; $i -lt $Sequence.Length; $i++) {
            if ($Memory[$address + $i] -ne $Sequence[$i]) {
                $match = $false
                break
            }
        }
        if ($match) { return $true }
    }
    return $false
}

function Test-AbsoluteCall {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [int]$EndExclusive,
        [int]$Target
    )

    [byte[]]$call = 0x20, ($Target -band 0xFF), (($Target -shr 8) -band 0xFF)
    return Test-ByteSequence $Memory $Start $EndExclusive $call
}

function Get-AbsoluteCallSites {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [int]$EndExclusive,
        [int]$Target
    )

    $sites = @()
    for ($address = $Start; $address -lt ($EndExclusive - 2); $address++) {
        if ($Memory[$address] -eq 0x20 -and
            $Memory[$address + 1] -eq ($Target -band 0xFF) -and
            $Memory[$address + 2] -eq (($Target -shr 8) -band 0xFF)) {
            $sites += $address
        }
    }
    return $sites
}

function Test-RelativeBranch {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [int]$EndExclusive,
        [byte]$Opcode,
        [int]$Target
    )

    for ($address = $Start; $address -lt ($EndExclusive - 1); $address++) {
        if ($Memory[$address] -ne $Opcode) { continue }
        $offset = [int]$Memory[$address + 1]
        if ($offset -ge 0x80) { $offset -= 0x100 }
        if (($address + 2 + $offset) -eq $Target) { return $true }
    }
    return $false
}

function Invoke-DispatcherPrefix {
    param(
        [byte[]]$Memory,
        [int]$Start,
        [int]$ModeAddress,
        [byte]$Mode
    )

    $pc = $Start
    $a = 0
    $p = 0x01       # Start with carry set so unknown-mode CLC is proved.
    $stack = New-Object System.Collections.Generic.Stack[int]

    for ($step = 0; $step -lt 64; $step++) {
        $opcode = $Memory[$pc]
        switch ($opcode) {
            0x08 { # PHP
                $stack.Push($p)
                $pc++
                continue
            }
            0x4C { # JMP absolute
                $pc = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                continue
            }
            0x78 { # SEI
                $p = $p -bor 0x04
                $pc++
                continue
            }
            0xAD { # LDA absolute
                $address = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                if ($address -eq $ModeAddress) {
                    $a = $Mode
                } else {
                    $a = $Memory[$address]
                }
                $pc += 3
                continue
            }
            0xC9 { # CMP immediate
                $value = $Memory[$pc + 1]
                $p = $p -band 0xFC
                if ($a -ge $value) { $p = $p -bor 0x01 }
                if ($a -eq $value) { $p = $p -bor 0x02 }
                $pc += 2
                continue
            }
            0xF0 { # BEQ relative
                $offset = [int][sbyte]$Memory[$pc + 1]
                $pc += 2
                if (($p -band 0x02) -ne 0) { $pc += $offset }
                continue
            }
            0x28 { # PLP
                if ($stack.Count -eq 0) { throw ('PLP underflow for mode ${0:X2}' -f $Mode) }
                $p = $stack.Pop()
                $pc++
                continue
            }
            0x18 { # CLC
                $p = $p -band 0xFE
                $pc++
                continue
            }
            0x20 { # JSR absolute: stop at the first operation dispatch.
                $target = ([int]$Memory[$pc + 1]) -bor (([int]$Memory[$pc + 2]) -shl 8)
                return [pscustomobject]@{ Action = 'JSR'; Target = $target; Carry = (($p -band 1) -ne 0) }
            }
            0x60 { # RTS
                return [pscustomobject]@{ Action = 'RTS'; Target = -1; Carry = (($p -band 1) -ne 0) }
            }
            default {
                throw ('Unsupported dispatcher opcode ${0:X2} at ${1:X4} for mode ${2:X2}' -f $opcode, $pc, $Mode)
            }
        }
    }
    throw ('Dispatcher did not terminate for mode ${0:X2}' -f $Mode)
}

$himonSymbols = Read-MapSymbols $HimonMapPath
$str8Symbols = Read-MapSymbols $Str8MapPath
$workerSymbols = Read-MapSymbols $WorkerMapPath
$himonMemory = Read-S19Memory $HimonS19Path
$str8Memory = Read-S19Memory $Str8S19Path
$memory = Read-S19Memory $WorkerS19Path

$himonBankCount = Get-Symbol $himonSymbols 'STR8_BANK_COUNT'
$str8BankCount = Get-Symbol $str8Symbols 'STR8_BANK_COUNT'
$workerBankCount = Get-Symbol $workerSymbols 'STR8_BANK_COUNT'
if ($himonBankCount -ne 0x04 -or $str8BankCount -ne $himonBankCount -or $workerBankCount -ne $himonBankCount) {
    throw ('Bank count HIMON/STR8/worker is {0:X2}/{1:X2}/{2:X2}; expected 04/04/04' -f $himonBankCount, $str8BankCount, $workerBankCount)
}

$himonClearStart = Get-Symbol $himonSymbols 'MON_CLEAR_RAM'
$himonClearBegin = Get-Symbol $himonSymbols 'MON_CLEAR_RAM_BEGIN'
$himonColdRangeFound = $false
for ($address = $himonClearStart; $address -le ($himonClearBegin - 3); $address++) {
    if ($himonMemory[$address] -eq 0xC9 -and
        $himonMemory[$address + 1] -eq $himonBankCount -and
        $himonMemory[$address + 2] -eq 0xB0) {
        $himonColdRangeFound = $true
        break
    }
}
if (-not $himonColdRangeFound) { throw 'HIMON cold clear must preserve Bank Jump Record banks 00-03' }

$residentJumpStart = Get-Symbol $str8Symbols 'STR8_CMD_JUMP_BANK'
$residentJumpEnd = Get-Symbol $str8Symbols 'STR8_CMD_UPDATE_HIMON'
$residentRangeFound = $false
for ($address = $residentJumpStart; $address -lt ($residentJumpEnd - 1); $address++) {
    if ($str8Memory[$address] -eq 0xC9 -and $str8Memory[$address + 1] -eq 0x34) {
        $residentRangeFound = $true
        break
    }
}
if (-not $residentRangeFound) { throw 'Resident J parser must accept through ASCII 3' }

[byte[]]$expectedHelp = [System.Text.Encoding]::ASCII.GetBytes('U 0-3 J0-3')
$idMessage = Get-Symbol $str8Symbols 'MSG_ID'
$bootMenuMessage = Get-Symbol $str8Symbols 'MSG_BOOT_MENU'
$screenMessage = Get-Symbol $str8Symbols 'MSG_SCREEN'
$promptMessage = Get-Symbol $str8Symbols 'MSG_PROMPT'
if (-not (Test-ByteSequence $str8Memory $screenMessage ($screenMessage + $expectedHelp.Length) $expectedHelp)) {
    throw 'Resident help does not publish the compact U/0-3/J0-3 surface'
}
if ($screenMessage -ne ($bootMenuMessage + 2) -or
    $str8Memory[$bootMenuMessage] -ne 0x0D -or $str8Memory[$bootMenuMessage + 1] -ne 0x0A) {
    throw 'Resident live-dot menu does not join one CRLF directly to the compact help'
}

$residentDispatch = Get-Symbol $str8Symbols 'STR8_DISPATCH_A'
$residentSelector = Get-Symbol $str8Symbols 'STR8_CMD_SELECT_A'
$residentSelectorHimon = Get-Symbol $str8Symbols 'STR8_CMD_SELECT_HIMON'
$residentJumpPrep = Get-Symbol $str8Symbols 'STR8_JUMP_BANK_PREP_A'
$residentJumpLaunch = Get-Symbol $str8Symbols 'STR8_JUMP_BANK_LAUNCH'
[byte[]]$selectorJump = 0x4C, ($residentSelector -band 0xFF), (($residentSelector -shr 8) -band 0xFF)
if (-not (Test-ByteSequence $str8Memory $residentDispatch $residentSelector ([byte[]](0xC9, 0x30))) -or
    -not (Test-ByteSequence $str8Memory $residentDispatch $residentSelector ([byte[]](0xC9, 0x34))) -or
    -not (Test-ByteSequence $str8Memory $residentDispatch $residentSelector $selectorJump)) {
    throw 'Resident dispatch does not range-route bare 0-3 to the shared selector'
}
if (-not (Test-RelativeBranch $str8Memory $residentSelector $residentSelectorHimon 0xF0 $residentSelectorHimon) -or
    -not (Test-AbsoluteCall $str8Memory $residentSelector $residentSelectorHimon $residentJumpPrep) -or
    -not (Test-ByteSequence $str8Memory $residentSelector $residentSelectorHimon `
        ([byte[]](0x4C, ($residentJumpLaunch -band 0xFF), (($residentJumpLaunch -shr 8) -band 0xFF))))) {
    throw 'Resident bare selector no longer maps 0-2 to J handoff and 3 to warm HIMON'
}

$residentBankService = Get-Symbol $str8Symbols 'STR8_BANK_SELECT_SERVICE_ENTRY'
$residentBankBody = Get-Symbol $str8Symbols 'STR8_BANK_SELECT_SERVICE_BODY'
$residentBankRam = Get-Symbol $str8Symbols 'STR8_BANK_SELECT_RAM'
$workerBankService = Get-Symbol $workerSymbols 'STR8W_BANK_SELECT_SERVICE'
if ($residentBankService -ne 0xF010) { throw 'Resident bank-select service must remain at F010' }
if ($residentBankRam -ne 0x0203 -or $workerBankService -ne $residentBankRam) {
    throw 'Resident/worker bank-select RAM entry must remain at 0203'
}
[byte[]]$residentBankJump = 0x4C, ($residentBankBody -band 0xFF), (($residentBankBody -shr 8) -band 0xFF)
if (-not (Test-ByteSequence $str8Memory $residentBankService ($residentBankService + 3) $residentBankJump)) {
    throw 'Resident F010 bank-select front door is not a JMP to its body'
}
[byte[]]$workerBankGate = 0x08, 0x78, 0xC9, 0x04, 0xB0
if (-not (Test-ByteSequence $memory $workerBankService ($workerBankService + 5) $workerBankGate)) {
    throw 'RAM bank-select service must mask IRQ and reject banks above 3 before selection'
}
$workerRawSelector = Get-Symbol $workerSymbols 'STR8W_BANK_SELECT_A'
[byte[]]$workerBankServiceBody = @(
    0x08, 0x78, 0xC9, 0x04, 0xB0, 0x06,
    0x20, ($workerRawSelector -band 0xFF), (($workerRawSelector -shr 8) -band 0xFF),
    0x28, 0x38, 0x60, 0x28, 0x18, 0x60
)
if (-not (Test-ByteSequence $memory $workerBankService ($workerBankService + $workerBankServiceBody.Length) $workerBankServiceBody)) {
    throw 'RAM bank-select service no longer validates, selects, restores P, and returns with exact carry status'
}
$residentCopyWorker = Get-Symbol $str8Symbols 'STR8_COPY_WORKER_TO_RAM'
$residentBankBodyEnd = Get-Symbol $str8Symbols 'STR8_AP_IMPORT_LINK_SERVICE_BODY'
[byte[]]$residentRamReturnGate = 0x48, 0xBA, 0xBD, 0x03, 0x01, 0x30
if (-not (Test-ByteSequence $str8Memory $residentBankBody $residentBankBodyEnd $residentRamReturnGate)) {
    throw 'Resident bank-select service does not reject a banked-ROM return address'
}
[byte[]]$residentCopyAndTail = @(
    0x20, ($residentCopyWorker -band 0xFF), (($residentCopyWorker -shr 8) -band 0xFF),
    0x68, 0x4C, 0x03, 0x02
)
if (-not (Test-ByteSequence $str8Memory $residentBankBody $residentBankBodyEnd $residentCopyAndTail)) {
    throw 'Resident bank-select service does not copy the worker and tail-call RAM $0203'
}

[byte[]]$expectedBannerTail = 0x20, 0x24, 0x46, 0x0D, 0x8A
if (-not (Test-ByteSequence $str8Memory ($bootMenuMessage - $expectedBannerTail.Length) $bootMenuMessage $expectedBannerTail)) {
    throw 'Resident STR8 ID does not end with " $F" and CRLF'
}

[byte[]]$legacyRomLine = [System.Text.Encoding]::ASCII.GetBytes('ROM $F000')
if (Test-ByteSequence $str8Memory $idMessage $promptMessage $legacyRomLine) {
    throw 'Resident STR8 still contains the legacy ROM $F000 screen line'
}

$startupDelay = Get-Symbol $str8Symbols 'STR8_STARTUP_DELAY'
$startupDelayFixed = Get-Symbol $str8Symbols 'STR8_DELAY_FIXED_A'
$startupPollIf = Get-Symbol $str8Symbols 'STR8_BOOT_KEY_POLL_IF_ENABLED'
$startupPoll = Get-Symbol $str8Symbols 'STR8_BOOT_KEY_POLL'
$startupPollEnd = Get-Symbol $str8Symbols 'STR8_PRINT_SCREEN'
$startupFlag = Get-Symbol $str8Symbols 'STR8_BOOT_KEY_ENABLE'
$startupFlush = Get-Symbol $str8Symbols 'STR8_CON_FLUSH_RX'
$startupBanner = Get-Symbol $str8Symbols 'STR8_PRINT_BANNER'
$selectorHimonEnd = Get-Symbol $str8Symbols 'STR8_CMD_UPDATE_HIMON'
$selectorWarmTarget = Get-Symbol $str8Symbols 'STR8_ENTER_HIMON_WARM'
[byte[]]$startupClear = 0xA2, 0x23, 0xA9, 0x0A
[byte[]]$startupHead = 0x9C, ($startupFlag -band 0xFF), (($startupFlag -shr 8) -band 0xFF), 0xA9, 0x20
[byte[]]$startupArm = 0xEE, ($startupFlag -band 0xFF), (($startupFlag -shr 8) -band 0xFF)
if (-not (Test-ByteSequence $str8Memory $startupDelay $startupDelayFixed $startupClear) -or
    -not (Test-ByteSequence $str8Memory $startupDelay $startupDelayFixed $startupHead) -or
    -not (Test-ByteSequence $str8Memory $startupDelay $startupDelayFixed ([byte[]](0xC9, 0x10))) -or
    -not (Test-AbsoluteCall $str8Memory $startupDelay $startupDelayFixed $startupFlush) -or
    -not (Test-ByteSequence $str8Memory $startupDelay $startupDelayFixed $startupArm) -or
    -not (Test-AbsoluteCall $str8Memory $startupDelay $startupDelayFixed $startupBanner) -or
    -not (Test-AbsoluteCall $str8Memory $startupDelay $startupDelayFixed $startupPollIf)) {
    throw 'Resident startup is not 35 LFs plus one 32-dot loop with a flush/arm/banner midpoint at 16'
}
foreach ($removedKey in @([byte][char]'G', [byte][char]'R')) {
    if (Test-ByteSequence $str8Memory $startupPoll $startupPollEnd ([byte[]](0xC9, $removedKey))) {
        throw ('Removed live selector {0} remains in boot-key polling' -f [char]$removedKey)
    }
}
[byte[]]$selectorWarmJump = 0x4C, ($selectorWarmTarget -band 0xFF), (($selectorWarmTarget -shr 8) -band 0xFF)
if (-not (Test-AbsoluteCall $str8Memory $residentSelectorHimon $selectorHimonEnd $startupFlush) -or
    -not (Test-ByteSequence $str8Memory $residentSelectorHimon $selectorHimonEnd $selectorWarmJump)) {
    throw 'Bare 3 does not flush the command tail and enter HIMON warm'
}

$coldEntry = Get-Symbol $str8Symbols 'STR8_ENTER_HIMON_COLD'
$warmEntry = Get-Symbol $str8Symbols 'STR8_ENTER_HIMON_WARM'
$availability = Get-Symbol $str8Symbols 'STR8_BOOT_TARGET_AVAILABLE'
$noBootEntry = Get-Symbol $str8Symbols 'STR8_ENTER_MENU_NO_BOOT'
$menuHelpEntry = Get-Symbol $str8Symbols 'STR8_ENTER_MENU_HELP'
$noBootMessage = Get-Symbol $str8Symbols 'MSG_NO_BOOT'

foreach ($entry in @(
        @{ Name = 'cold'; Start = $coldEntry; End = $warmEntry },
        @{ Name = 'warm'; Start = $warmEntry; End = $availability }
    )) {
    if (-not (Test-AbsoluteCall $str8Memory $entry.Start $entry.End $availability)) {
        throw ('STR8 {0} C000 entry does not call the availability gate' -f $entry.Name)
    }
    if (-not (Test-RelativeBranch $str8Memory $entry.Start $entry.End 0x90 $noBootEntry)) {
        throw ('STR8 {0} C000 entry does not BCC to the menu fallback' -f $entry.Name)
    }
}

[byte[]]$entryFaceScan = 0xA0, 0x00, 0xB9, 0x00, 0xC0, 0xC9, 0xFF
if (-not (Test-ByteSequence $str8Memory $availability $noBootEntry $entryFaceScan) -or
    -not (Test-ByteSequence $str8Memory $availability $noBootEntry ([byte[]](0xC0, 0x10))) -or
    -not (Test-ByteSequence $str8Memory $availability $noBootEntry ([byte[]](0x18, 0x60, 0x38, 0x60)))) {
    throw 'STR8 C000 availability gate must reject an all-FF 16-byte entry face'
}

[byte[]]$menuJump = 0x4C, ($menuHelpEntry -band 0xFF), (($menuHelpEntry -shr 8) -band 0xFF)
if (-not (Test-ByteSequence $str8Memory $noBootEntry $startupDelay $menuJump)) {
    throw 'STR8 unavailable-target path does not enter compact resident help'
}

[byte[]]$expectedNoBoot = [System.Text.Encoding]::ASCII.GetBytes('NO BOOT @C000')
if (-not (Test-ByteSequence $str8Memory $noBootMessage ($noBootMessage + $expectedNoBoot.Length) $expectedNoBoot) -or
    $str8Memory[$noBootMessage + $expectedNoBoot.Length] -ne 0x0D -or
    $str8Memory[$noBootMessage + 1 + $expectedNoBoot.Length] -ne 0x8A) {
    throw 'STR8 unavailable-target message changed'
}

$retiredResident = @(
    'STR8_CMD_BACKUP',
    'STR8_CMD_RESTORE_A',
    'STR8_RUN_COPY',
    'STR8_PRINT_COPY_PAIR',
    'STR8_CMD_G_HIMON',
    'STR8_CMD_RESET',
    'MSG_G_HIMON'
)
$retiredWorker = @(
    'STR8W_COPY_BANKS',
    'STR8W_STAGE_SRC_SECTOR',
    'STR8W_PRESERVE_IF_RESTORE',
    'STR8W_TOP_FAIL_HALT'
)
foreach ($name in $retiredResident) {
    if ($str8Symbols.ContainsKey($name)) { throw "Retired resident symbol remains: $name" }
}
foreach ($name in $retiredWorker) {
    if ($workerSymbols.ContainsKey($name)) { throw "Retired worker symbol remains: $name" }
}

$expected = @{
    0x05 = Get-Symbol $workerSymbols 'STR8W_PROGRAM_STAGED_SECTOR'
    0x06 = Get-Symbol $workerSymbols 'STR8W_STAGE_BANK_SECTOR'
    0x07 = Get-Symbol $workerSymbols 'STR8W_PROGRAM_RECORD'
    0x08 = Get-Symbol $workerSymbols 'STR8W_JUMP_BANK'
}
if ((Get-Symbol $workerSymbols 'STR8_COPY_MODE_PROGRAM_STAGED') -ne 0x05) { throw 'PROGRAM_STAGED mode changed' }
if ((Get-Symbol $workerSymbols 'STR8_COPY_MODE_STAGE_BANK_SECTOR') -ne 0x06) { throw 'STAGE_BANK_SECTOR mode changed' }
if ((Get-Symbol $workerSymbols 'STR8_COPY_MODE_PROGRAM_RECORD') -ne 0x07) { throw 'PROGRAM_RECORD mode changed' }
if ((Get-Symbol $workerSymbols 'STR8_COPY_MODE_JUMP_BANK') -ne 0x08) { throw 'JUMP_BANK mode changed' }

$programRecord = Get-Symbol $workerSymbols 'STR8W_PROGRAM_RECORD'
$recordInit = Get-Symbol $workerSymbols 'STR8W_RECORD_INIT'
$flashWrite = Get-Symbol $workerSymbols 'STR8W_FLASH_WRITE'
$workerAddrLo = Get-Symbol $workerSymbols 'STR8W_ADDR_LO'
$workerData = Get-Symbol $workerSymbols 'STR8W_DATA'
$initCalls = @(Get-AbsoluteCallSites $memory $programRecord $recordInit $recordInit)
$flashCalls = @(Get-AbsoluteCallSites $memory $programRecord $recordInit $flashWrite)
if ($initCalls.Count -ne 2) {
    throw ('PROGRAM_RECORD must initialize its pointers twice; found {0}' -f $initCalls.Count)
}
if ($flashCalls.Count -ne 1 -or $flashCalls[0] -le $initCalls[1]) {
    throw 'PROGRAM_RECORD must begin flash writes only after its second pointer initialization'
}
[byte[]]$oneToZeroPreflight = 0xB1, ($workerAddrLo -band 0xFF), 0x25, ($workerData -band 0xFF), 0xC5, ($workerData -band 0xFF), 0xD0
if (-not (Test-ByteSequence $memory ($initCalls[0] + 3) $initCalls[1] $oneToZeroPreflight)) {
    throw 'PROGRAM_RECORD does not preflight old AND new == new before its write pass'
}

$jumpBank = Get-Symbol $workerSymbols 'STR8W_JUMP_BANK'
if ($memory[$jumpBank + 3] -ne 0xC9 -or $memory[$jumpBank + 4] -ne 0x04) {
    throw 'JUMP_BANK must accept only bank bytes 00-03'
}
$bankBits = Get-Symbol $workerSymbols 'STR8W_BANK_BIT_TABLE'
[byte[]]$expectedBankBits = 0xCC, 0xCE, 0xEC, 0xEE
for ($i = 0; $i -lt $expectedBankBits.Length; $i++) {
    if ($memory[$bankBits + $i] -ne $expectedBankBits[$i]) {
        throw ('Bank-select table mismatch at index {0}' -f $i)
    }
}

$start = Get-Symbol $workerSymbols 'START'
$end = Get-Symbol $workerSymbols 'STR8_WORKER_END'
$modeAddress = Get-Symbol $workerSymbols 'STR8_COPY_MODE'
$rejected = 0
for ($mode = 0; $mode -le 0xFF; $mode++) {
    $result = Invoke-DispatcherPrefix $memory $start $modeAddress ([byte]$mode)
    if ($expected.ContainsKey($mode)) {
        if ($result.Action -ne 'JSR' -or $result.Target -ne $expected[$mode]) {
            throw ('Mode ${0:X2} dispatched to {1} ${2:X4}, expected JSR ${3:X4}' -f $mode, $result.Action, $result.Target, $expected[$mode])
        }
        continue
    }
    if ($result.Action -ne 'RTS' -or $result.Carry) {
        throw ('Unknown mode ${0:X2} did not fail closed: {1}, C={2}' -f $mode, $result.Action, [int]$result.Carry)
    }
    $rejected++
}

Write-Host ('STR8 WORKER             = {0:X4}-{1:X4}; ${2:X} bytes' -f $start, ($end - 1), ($end - $start))
Write-Host 'ACTIVE MODES            = 05 06 07 08'
Write-Host 'RESIDENT J RANGE        = J0-J3'
Write-Host 'JUMP BANK RANGE         = 00-03'
Write-Host 'RAM BANK SELECT ABI     = F010 -> 0203; A=00-03'
Write-Host 'HIMON COLD RECORD RANGE = 00-03'
Write-Host 'C000 ERASED FALLBACK    = STR8 MENU'
Write-Host 'MODE 07 RECORD PREFLIGHT= WHOLE REQUEST BEFORE WRITE'
Write-Host ('REJECTED MODE BYTES     = {0}' -f $rejected)
Write-Host 'RETIRED MODES 00/01/03  = FAIL CLOSED'
Write-Host 'STR8 WORKER MODE CHECK  = PASS'

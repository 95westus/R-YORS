param(
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$HimonMapPath = "BUILD/s19/himon-rom-c000.map",
    [string]$PublicContractPath = "BUILD/inc/str8n-public.inc"
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "AP Store inventory check: $Message"
}

function Map([string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    foreach ($line in [IO.File]::ReadLines($HimonMapPath)) {
        if ($line -match $pattern) { return [Convert]::ToInt32($matches[1], 16) }
    }
    Fail "map symbol $Name is missing"
}

function Read-S19 {
    $memory = [byte[]]::new(0x10000)
    $present = [bool[]]::new(0x10000)
    foreach ($raw in [IO.File]::ReadLines($HimonS19Path)) {
        $line = $raw.Trim()
        if ($line.Length -lt 4 -or $line[0] -ne 'S') { continue }
        $addressBytes = switch ($line[1]) { '1' { 2 } '2' { 3 } '3' { 4 } default { 0 } }
        if ($addressBytes -eq 0) { continue }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        $address = [Convert]::ToInt32($line.Substring(4, 2 * $addressBytes), 16)
        $dataBytes = $count - $addressBytes - 1
        for ($i = 0; $i -lt $dataBytes; $i++) {
            $at = $address + $i
            if ($at -lt 0 -or $at -ge 0x10000) { Fail ('S19 address ${0:X}' -f $at) }
            $memory[$at] = [Convert]::ToByte(
                $line.Substring(4 + (2 * $addressBytes) + (2 * $i), 2), 16
            )
            $present[$at] = $true
        }
    }
    [pscustomobject]@{ Memory = $memory; Present = $present }
}

function Set-Nz([int]$Status, [int]$Value) {
    $next = $Status -band 0x7D
    if (($Value -band 0xFF) -eq 0) { $next = $next -bor 0x02 }
    if (($Value -band 0x80) -ne 0) { $next = $next -bor 0x80 }
    $next
}

function Set-Cmp([int]$Status, [int]$Left, [int]$Right) {
    if (($Left -band 0xFF) -ge ($Right -band 0xFF)) {
        $next = $Status -bor 0x01
    } else {
        $next = $Status -band 0xFE
    }
    Set-Nz $next (($Left - $Right) -band 0xFF)
}

function Fnv32([byte[]]$Bytes) {
    [uint64]$hash = 2166136261
    foreach ($value in $Bytes) {
        $hash = (($hash -bxor [uint64]$value) * [uint64]16777619) -band [uint64]4294967295
    }
    [uint32]$hash
}

function New-Header([int]$Location, [int]$State, [int]$Generation = 1) {
    [byte[]]$header = [byte[]]::new(16)
    for ($i = 0; $i -lt $header.Length; $i++) { $header[$i] = 0xFF }
    $header[0] = [byte][char]'A'
    $header[1] = [byte][char]'S'
    $header[2] = [byte][char]'1'
    $header[3] = [byte]$Location
    $header[4] = [byte]($Generation -band 0xFF)
    $header[5] = [byte](($Generation -shr 8) -band 0xFF)
    [byte[]]$identity = $header[0..5]
    [uint32]$hash = Fnv32 $identity
    0..3 | ForEach-Object {
        $header[6 + $_] = [byte](([uint64]$hash -shr (8 * $_)) -band 0xFF)
    }
    $header[15] = [byte]$State
    $header
}

function Invoke-HeaderReader(
    [byte[]]$Routine,
    [byte[][]]$Banks,
    [int]$Bank,
    [int]$SectorHigh,
    [int]$InitialStatus,
    [bool]$FailInitialSelect = $false,
    [int]$RestoreFailures = 0
) {
    $memory = [byte[]]::new(0x8000)
    for ($i = 0; $i -lt $memory.Length; $i++) { $memory[$i] = 0x5A }
    [Array]::Copy($Routine, 0, $memory, (Map 'HIM_APS_HEADER_READ_RAM'), $Routine.Length)
    $memory[(Map 'HIM_APS_BANK')] = [byte]$Bank
    $memory[(Map 'HIM_APS_SECTOR_HI')] = [byte]$SectorHigh

    $pc = Map 'HIM_APS_HEADER_READ_RAM'
    $a = 0; $x = 0; $y = 0; $status = $InitialStatus -band 0xFF
    $selectedBank = 3
    $stack = [Collections.Generic.Stack[int]]::new()
    $steps = 0
    while ($steps -lt 2000) {
        $steps++
        $opcode = [int]$memory[$pc]
        switch ($opcode) {
            0x08 { $stack.Push($status); $pc++ }
            0x78 { $status = $status -bor 0x04; $pc++ }
            0xAD {
                $at = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)
                $a = [int]$memory[$at]; $status = Set-Nz $status $a; $pc += 3
            }
            0x20 {
                $target = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)
                $pc += 3
                if ($target -eq 0xF010) {
                    if ($FailInitialSelect -or $a -lt 0 -or $a -gt 3) {
                        $status = $status -band 0xFE
                    } else {
                        $selectedBank = $a; $status = $status -bor 0x01
                    }
                } elseif ($target -eq 0x0203) {
                    if ($RestoreFailures -gt 0) {
                        $RestoreFailures--; $status = $status -band 0xFE
                    } elseif ($a -eq 3) {
                        $selectedBank = 3; $status = $status -bor 0x01
                    } else {
                        $status = $status -band 0xFE
                    }
                } else { Fail ('reader called ${0:X4}' -f $target) }
            }
            0x90 {
                $offset = [int]$memory[$pc + 1]; if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2; if (($status -band 1) -eq 0) { $pc += $offset }
            }
            0x64 { $memory[[int]$memory[$pc + 1]] = 0; $pc += 2 }
            0x85 { $memory[[int]$memory[$pc + 1]] = [byte]$a; $pc += 2 }
            0xA9 { $a = [int]$memory[$pc + 1]; $status = Set-Nz $status $a; $pc += 2 }
            0xA2 { $x = [int]$memory[$pc + 1]; $status = Set-Nz $status $x; $pc += 2 }
            0xA0 { $y = [int]$memory[$pc + 1]; $status = Set-Nz $status $y; $pc += 2 }
            0xB1 {
                $zp = [int]$memory[$pc + 1]
                $at = (([int]$memory[$zp] -bor ([int]$memory[($zp + 1) -band 0xFF] -shl 8)) + $y) -band 0xFFFF
                if ($at -ge 0x8000) {
                    $a = [int]$Banks[$selectedBank][$at - 0x8000]
                } else { $a = [int]$memory[$at] }
                $status = Set-Nz $status $a; $pc += 2
            }
            0x91 {
                $zp = [int]$memory[$pc + 1]
                $at = (([int]$memory[$zp] -bor ([int]$memory[($zp + 1) -band 0xFF] -shl 8)) + $y) -band 0xFFFF
                if ($at -ge 0x8000) { Fail ('reader wrote bank window ${0:X4}' -f $at) }
                $memory[$at] = [byte]$a; $pc += 2
            }
            0xC8 { $y = ($y + 1) -band 0xFF; $status = Set-Nz $status $y; $pc++ }
            0xCA { $x = ($x - 1) -band 0xFF; $status = Set-Nz $status $x; $pc++ }
            0xD0 {
                $offset = [int]$memory[$pc + 1]; if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2; if (($status -band 2) -eq 0) { $pc += $offset }
            }
            0x28 {
                if ($stack.Count -eq 0) { Fail 'reader PLP underflow' }
                $status = $stack.Pop(); $pc++
            }
            0x38 { $status = $status -bor 1; $pc++ }
            0x18 { $status = $status -band 0xFE; $pc++ }
            0x60 {
                if ($stack.Count -ne 0) { Fail 'reader returned with saved status' }
                return [pscustomobject]@{
                    Memory = $memory; Status = $status; SelectedBank = $selectedBank; Steps = $steps
                }
            }
            default { Fail ('unsupported reader opcode ${0:X2} at ${1:X4}' -f $opcode, $pc) }
        }
    }
    Fail 'reader step limit'
}

function Invoke-Classifier([byte[]]$Image, [byte[]]$Header, [int]$Location) {
    [byte[]]$memory = $Image.Clone()
    $base = Map 'HIM_APS_HEADER_BASE'
    [Array]::Copy($Header, 0, $memory, $base, 16)
    $memory[(Map 'HIM_APS_LOCATION')] = [byte]$Location
    $pc = Map 'HIM_APS_CLASSIFY_HEADER'
    $a = 0; $x = 0; $y = 0; $status = 0x20
    $returns = [Collections.Generic.Stack[int]]::new()
    $steps = 0
    while ($steps -lt 10000) {
        $steps++
        $opcode = [int]$memory[$pc]
        switch ($opcode) {
            0xA2 { $x = [int]$memory[$pc + 1]; $status = Set-Nz $status $x; $pc += 2 }
            0xA0 { $y = [int]$memory[$pc + 1]; $status = Set-Nz $status $y; $pc += 2 }
            0xA9 { $a = [int]$memory[$pc + 1]; $status = Set-Nz $status $a; $pc += 2 }
            0xA5 { $a = [int]$memory[[int]$memory[$pc + 1]]; $status = Set-Nz $status $a; $pc += 2 }
            0xAD {
                $at = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)
                $a = [int]$memory[$at]; $status = Set-Nz $status $a; $pc += 3
            }
            0xB5 {
                $at = ([int]$memory[$pc + 1] + $x) -band 0xFF
                $a = [int]$memory[$at]; $status = Set-Nz $status $a; $pc += 2
            }
            0xB9 {
                $at = ([int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)) + $y
                $a = [int]$memory[$at -band 0xFFFF]; $status = Set-Nz $status $a; $pc += 3
            }
            0xBD {
                $at = ([int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)) + $x
                $a = [int]$memory[$at -band 0xFFFF]; $status = Set-Nz $status $a; $pc += 3
            }
            0x85 { $memory[[int]$memory[$pc + 1]] = [byte]$a; $pc += 2 }
            0x95 {
                $at = ([int]$memory[$pc + 1] + $x) -band 0xFF
                $memory[$at] = [byte]$a; $pc += 2
            }
            0x45 {
                $a = $a -bxor [int]$memory[[int]$memory[$pc + 1]]
                $status = Set-Nz $status $a; $pc += 2
            }
            0xC9 { $status = Set-Cmp $status $a ([int]$memory[$pc + 1]); $pc += 2 }
            0xC0 { $status = Set-Cmp $status $y ([int]$memory[$pc + 1]); $pc += 2 }
            0xCD {
                $at = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)
                $status = Set-Cmp $status $a ([int]$memory[$at]); $pc += 3
            }
            0xDD {
                $at = ([int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)) + $x
                $status = Set-Cmp $status $a ([int]$memory[$at -band 0xFFFF]); $pc += 3
            }
            0xCA { $x = ($x - 1) -band 0xFF; $status = Set-Nz $status $x; $pc++ }
            0xC8 { $y = ($y + 1) -band 0xFF; $status = Set-Nz $status $y; $pc++ }
            0x18 { $status = $status -band 0xFE; $pc++ }
            0x06 {
                $at = [int]$memory[$pc + 1]; $value = [int]$memory[$at]
                if (($value -band 0x80) -ne 0) { $status = $status -bor 1 } else { $status = $status -band 0xFE }
                $value = ($value -shl 1) -band 0xFF; $memory[$at] = [byte]$value
                $status = Set-Nz $status $value; $pc += 2
            }
            0x26 {
                $at = [int]$memory[$pc + 1]; $value = [int]$memory[$at]; $carry = $status -band 1
                if (($value -band 0x80) -ne 0) { $status = $status -bor 1 } else { $status = $status -band 0xFE }
                $value = (($value -shl 1) -bor $carry) -band 0xFF; $memory[$at] = [byte]$value
                $status = Set-Nz $status $value; $pc += 2
            }
            0x65 {
                $sum = $a + [int]$memory[[int]$memory[$pc + 1]] + ($status -band 1)
                if ($sum -gt 0xFF) { $status = $status -bor 1 } else { $status = $status -band 0xFE }
                $a = $sum -band 0xFF; $status = Set-Nz $status $a; $pc += 2
            }
            0x20 {
                $target = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8)
                $returns.Push($pc + 3); $pc = $target
            }
            0x4C { $pc = [int]$memory[$pc + 1] -bor ([int]$memory[$pc + 2] -shl 8) }
            0x10 {
                $offset = [int]$memory[$pc + 1]; if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2; if (($status -band 0x80) -eq 0) { $pc += $offset }
            }
            0xD0 {
                $offset = [int]$memory[$pc + 1]; if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2; if (($status -band 2) -eq 0) { $pc += $offset }
            }
            0xF0 {
                $offset = [int]$memory[$pc + 1]; if ($offset -ge 0x80) { $offset -= 0x100 }
                $pc += 2; if (($status -band 2) -ne 0) { $pc += $offset }
            }
            0x60 {
                if ($returns.Count -eq 0) { return [pscustomobject]@{ Class = $a; Steps = $steps } }
                $pc = $returns.Pop()
            }
            default { Fail ('unsupported classifier opcode ${0:X2} at ${1:X4}' -f $opcode, $pc) }
        }
    }
    Fail 'classifier step limit'
}

foreach ($path in @($HimonSourcePath, $HimonS19Path, $HimonMapPath, $PublicContractPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "missing $path" }
}

$source = [IO.File]::ReadAllText((Resolve-Path $HimonSourcePath))
foreach ($required in @(
    'CMD_APS_FNV:', 'HIM_APS_CLASSIFY_HEADER:', 'HIM_APS_HEADER_READ_CODE:',
    'JSR             STR8_BANK_SELECT_SERVICE', 'JSR             STR8_BANK_SELECT_RAM',
    'LDX             #APS_SECTOR_HEADER_BYTES', 'CMP             #$03'
)) {
    if (-not $source.Contains($required)) { Fail "source is missing $required" }
}

$contract = [IO.File]::ReadAllText((Resolve-Path $PublicContractPath))
if ($contract -notmatch 'STR8_WORKER_SELECT_END\s+EQU\s+\$([0-9A-Fa-f]{4})') {
    Fail 'selector end missing from public contract'
}
$selectorEnd = [Convert]::ToInt32($matches[1], 16)

$image = Read-S19
$readerStart = Map 'HIM_APS_HEADER_READ_CODE'
$readerEnd = Map 'HIM_APS_HEADER_READ_CODE_END'
$readerSize = Map 'HIM_APS_HEADER_READ_CODE_SIZE'
$readerRam = Map 'HIM_APS_HEADER_READ_RAM'
if ($readerSize -ne ($readerEnd - $readerStart) -or $readerSize -le 0 -or $readerSize -gt 0x80) {
    Fail ('reader extent/size invalid: ${0:X4}-${1:X4} size=${2:X}' -f $readerStart, $readerEnd, $readerSize)
}
if ($readerRam -lt $selectorEnd -or ($readerRam + $readerSize) -gt 0x0A00) {
    Fail 'reader RAM overlaps selector or staging boundary'
}
[byte[]]$routine = [byte[]]::new($readerSize)
for ($i = 0; $i -lt $readerSize; $i++) {
    if (-not $image.Present[$readerStart + $i]) { Fail 'reader byte missing from S19' }
    $routine[$i] = $image.Memory[$readerStart + $i]
}

$apsRecord = @(0x46,0x4E,0xD6,0x45,0xCE,0xA6,0x64,0x01)
$apsEntry = Map 'CMD_APS_FNV'
for ($i = 0; $i -lt $apsRecord.Count; $i++) {
    if ($image.Memory[$apsEntry + $i] -ne $apsRecord[$i]) { Fail 'APS FNV command record changed' }
}

$banks = [byte[][]]::new(4)
$before = [byte[][]]::new(4)
for ($bank = 0; $bank -lt 4; $bank++) {
    $banks[$bank] = [byte[]]::new(0x8000)
    for ($i = 0; $i -lt 0x8000; $i++) {
        $banks[$bank][$i] = [byte](($bank * 0x43 + $i * 3 + ($i -shr 8)) -band 0xFF)
    }
}

$expectedClasses = @(4,0,1,3,2,5,6,7, 0,4,1,2,3,5,6,7, 1,0,4,2,3,5,6,7)
$case = 0
for ($bank = 0; $bank -le 2; $bank++) {
    for ($sector = 8; $sector -le 15; $sector++) {
        $location = ($bank -shl 4) -bor $sector
        $class = $expectedClasses[$case++]
        [byte[]]$header = switch ($class) {
            0 { [byte[]](0..15 | ForEach-Object { 0xFF }) }
            1 { [byte[]](0..15 | ForEach-Object { [byte](0x40 + $_) }) }
            2 { $h = New-Header $location 0xFE ($case + 0x100); $h[6] = $h[6] -bxor 1; $h }
            3 { New-Header $location 0xFF ($case + 0x100) }
            4 { New-Header $location 0xFE ($case + 0x100) }
            5 { New-Header $location 0xFC ($case + 0x100) }
            6 { New-Header $location 0xFA ($case + 0x100) }
            7 { New-Header $location 0xF8 ($case + 0x100) }
        }
        $offset = ($sector - 8) * 0x1000
        [Array]::Copy($header, 0, $banks[$bank], $offset, 16)
    }
}
for ($bank = 0; $bank -lt 4; $bank++) { $before[$bank] = $banks[$bank].Clone() }

$readerMaxSteps = 0; $classifierMaxSteps = 0; $case = 0
for ($bank = 0; $bank -le 2; $bank++) {
    for ($sector = 8; $sector -le 15; $sector++) {
        $sectorHigh = $sector -shl 4
        $initialStatus = if (($bank + $sector) -band 1) { 0x24 } else { 0x20 }
        $read = Invoke-HeaderReader $routine $banks $bank $sectorHigh $initialStatus
        if (($read.Status -band 1) -eq 0 -or $read.SelectedBank -ne 3) {
            Fail "B$bank sector $sector did not restore Bank 3"
        }
        if (($read.Status -band 4) -ne ($initialStatus -band 4)) {
            Fail "B$bank sector $sector changed interrupt state"
        }
        $offset = ($sector - 8) * 0x1000
        for ($i = 0; $i -lt 16; $i++) {
            if ($read.Memory[(Map 'HIM_APS_HEADER_BASE') + $i] -ne $banks[$bank][$offset + $i]) {
                Fail ('B{0}:${1:X} header differs at +${2:X}' -f $bank, $sector, $i)
            }
        }
        foreach ($guard in 0x7C14..0x7C1F) {
            if ($read.Memory[$guard] -ne 0x5A) { Fail ('header reader changed guard ${0:X4}' -f $guard) }
        }
        [byte[]]$copied = $read.Memory[(Map 'HIM_APS_HEADER_BASE')..((Map 'HIM_APS_HEADER_BASE') + 15)]
        $classified = Invoke-Classifier $image.Memory $copied (($bank -shl 4) -bor $sector)
        if ($classified.Class -ne $expectedClasses[$case]) {
            Fail ('B{0}:${1:X} class={2}, expected={3}' -f $bank, $sector, $classified.Class, $expectedClasses[$case])
        }
        $case++
        $readerMaxSteps = [Math]::Max($readerMaxSteps, $read.Steps)
        $classifierMaxSteps = [Math]::Max($classifierMaxSteps, $classified.Steps)
    }
}

# Focused corruptions: wrong location, reserved byte, invalid state, and FNV.
$focused = @()
$h = New-Header 0x08 0xFE; $h[3] = 0x09; $focused += ,$h
$h = New-Header 0x08 0xFE; $h[10] = 0x7F; $focused += ,$h
$h = New-Header 0x08 0xFE; $h[15] = 0xF6; $focused += ,$h
$h = New-Header 0x08 0xFE; $h[4] = $h[4] -bxor 1; $focused += ,$h
foreach ($header in $focused) {
    if ((Invoke-Classifier $image.Memory $header 0x08).Class -ne 2) { Fail 'focused corruption accepted' }
}

$failed = Invoke-HeaderReader $routine $banks 1 0xA0 0x20 $true
if (($failed.Status -band 1) -ne 0 -or $failed.SelectedBank -ne 3) {
    Fail 'selector failure did not fail closed in Bank 3'
}
for ($i = 0; $i -lt 16; $i++) {
    if ($failed.Memory[(Map 'HIM_APS_HEADER_BASE') + $i] -ne 0x5A) {
        Fail 'selector failure changed header buffer'
    }
}
$retried = Invoke-HeaderReader $routine $banks 2 0xF0 0x24 $false 1
if (($retried.Status -band 1) -eq 0 -or $retried.SelectedBank -ne 3) {
    Fail 'restore retry did not finish in Bank 3'
}
$readerMaxSteps = [Math]::Max($readerMaxSteps, $retried.Steps)

for ($bank = 0; $bank -lt 4; $bank++) {
    for ($i = 0; $i -lt 0x8000; $i++) {
        if ($banks[$bank][$i] -ne $before[$bank][$i]) {
            Fail ('flash mutation B{0} +${1:X4}' -f $bank, $i)
        }
    }
}

$codeBytes = (Map '_END_CODE') - (Map '_BEG_CODE')
$dataBytes = (Map '_END_DATA') - (Map '_BEG_DATA')
$residentBytes = (Map '_END_DATA') - (Map '_BEG_CODE')
$margin = 0xF000 - (Map '_END_DATA')
if ($margin -lt 0) { Fail 'HIMON crosses STR8 at $F000' }

Write-Host (('AP Store inventory check OK candidates=24 banks=0-2 sectors=8-F ' +
    'reader=${0:X4}-${1:X4} bytes={2} ram=${3:X4} HTO=20B staging=0 ' +
    'reader-max={4} classifier-max={5}') -f $readerStart, ($readerEnd - 1),
    $readerSize, $readerRam, $readerMaxSteps, $classifierMaxSteps)
Write-Host (('HIMON size CODE={0} DATA={1} resident={2} end=${3:X4} margin-to-F000={4}') -f
    $codeBytes, $dataBytes, $residentBytes, (Map '_END_DATA'), $margin)

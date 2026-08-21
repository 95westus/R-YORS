param(
    [string]$SourcePath = "PROOFS/ap-store-v1-sector-tool.asm",
    [string]$S19Path = "BUILD/s19/ap-store-v1-sector-tool-7000.s19",
    [string]$MapPath = "BUILD/s19/ap-store-v1-sector-tool-7000.map"
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "AP Store sector tool check: $Message" }

function Map([string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    foreach ($line in [IO.File]::ReadLines($MapPath)) {
        if ($line -match $pattern) { return [Convert]::ToInt32($matches[1], 16) }
    }
    Fail "map symbol $Name is missing"
}

function Read-S19 {
    [byte[]]$memory = [byte[]]::new(0x10000)
    [bool[]]$present = [bool[]]::new(0x10000)
    foreach ($raw in [IO.File]::ReadLines($S19Path)) {
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
            $memory[$at] = [Convert]::ToByte($line.Substring(4 + (2 * $addressBytes) + (2 * $i), 2), 16)
            $present[$at] = $true
        }
    }
    [pscustomobject]@{ Memory = $memory; Present = $present }
}

function Slice([byte[]]$Bytes, [int]$Offset, [int]$Length) {
    [byte[]]$result = [byte[]]::new($Length)
    [Array]::Copy($Bytes, $Offset, $result, 0, $Length)
    $result
}

function Equal-Bytes([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($i = 0; $i -lt $Left.Length; $i++) {
        if ($Left[$i] -ne $Right[$i]) { return $false }
    }
    $true
}

function Fnv32([byte[]]$Bytes) {
    [uint64]$hash = 2166136261
    foreach ($value in $Bytes) {
        $hash = (($hash -bxor [uint64]$value) * [uint64]16777619) -band [uint64]4294967295
    }
    [uint32]$hash
}

function Crc16([byte[]]$Bytes) {
    [int]$crc = 0xFFFF
    foreach ($value in $Bytes) {
        $crc = $crc -bxor ([int]$value -shl 8)
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 0x8000) -ne 0) {
                $crc = (($crc -shl 1) -bxor 0x1021) -band 0xFFFF
            } else {
                $crc = ($crc -shl 1) -band 0xFFFF
            }
        }
    }
    $crc
}

function New-ErasedSector {
    [byte[]]$sector = [byte[]]::new(4096)
    for ($i = 0; $i -lt $sector.Length; $i++) { $sector[$i] = 0xFF }
    $sector
}

function New-Header([int]$Bank, [int]$Sector, [int]$Generation, [int]$State = 0xFE) {
    [byte[]]$header = [byte[]]::new(16)
    for ($i = 0; $i -lt $header.Length; $i++) { $header[$i] = 0xFF }
    $header[0] = [byte][char]'A'
    $header[1] = [byte][char]'S'
    $header[2] = [byte][char]'1'
    $header[3] = [byte](($Bank -shl 4) -bor $Sector)
    $header[4] = [byte]($Generation -band 0xFF)
    $header[5] = [byte](($Generation -shr 8) -band 0xFF)
    [uint32]$hash = Fnv32 (Slice $header 0 6)
    for ($i = 0; $i -lt 4; $i++) {
        $header[6 + $i] = [byte](([uint64]$hash -shr (8 * $i)) -band 0xFF)
    }
    $header[15] = [byte]$State
    $header
}

function New-ManagedSector([int]$Bank, [int]$Sector, [int]$Generation, [int]$State = 0xFE) {
    [byte[]]$media = New-ErasedSector
    [byte[]]$header = New-Header $Bank $Sector $Generation $State
    [Array]::Copy($header, 0, $media, 0, 16)
    $media
}

function Sector-Class([byte[]]$Media, [int]$Bank, [int]$Sector) {
    $headerFF = $true
    for ($i = 0; $i -lt 16; $i++) {
        if ($Media[$i] -ne 0xFF) { $headerFF = $false; break }
    }
    if ($headerFF) { return 'HEADER_FF' }
    if ($Media[0] -ne [byte][char]'A' -or $Media[1] -ne [byte][char]'S' -or $Media[2] -ne [byte][char]'1') {
        return 'OPAQUE'
    }
    if ($Media[3] -ne (($Bank -shl 4) -bor $Sector)) { return 'CORRUPT' }
    for ($i = 10; $i -le 14; $i++) { if ($Media[$i] -ne 0xFF) { return 'CORRUPT' } }
    [uint32]$stored = [uint32]$Media[6] -bor ([uint32]$Media[7] -shl 8) -bor
        ([uint32]$Media[8] -shl 16) -bor ([uint32]$Media[9] -shl 24)
    if ($stored -ne (Fnv32 (Slice $Media 0 6))) { return 'CORRUPT' }
    switch ($Media[15]) {
        0xFF { 'STAGED' }
        0xFE { 'ACTIVE' }
        0xFC { 'RETIRED' }
        0xFA { 'BAD' }
        0xF8 { 'RETIRED_BAD' }
        default { 'CORRUPT' }
    }
}

function Inspect-Sector([byte[]]$Media, [int]$Bank, [int]$Sector) {
    $fullErased = $true
    for ($i = 0; $i -lt 4096; $i++) { if ($Media[$i] -ne 0xFF) { $fullErased = $false; break } }
    $tailErased = $true
    for ($i = 16; $i -lt 4096; $i++) { if ($Media[$i] -ne 0xFF) { $tailErased = $false; break } }
    $generation = [int]$Media[4] -bor ([int]$Media[5] -shl 8)
    [pscustomobject]@{
        Class = Sector-Class $Media $Bank $Sector
        FullErased = $fullErased
        TailErased = $tailErased
        Generation = $generation
        Crc = Crc16 $Media
    }
}

function Prepare([string]$Operation, [byte[]]$Media, [int]$Bank, [int]$Sector) {
    if ($Bank -lt 0 -or $Bank -gt 2 -or $Sector -lt 8 -or $Sector -gt 15) {
        return [pscustomobject]@{ Status = 'BAD_REQUEST'; Snapshot = $null }
    }
    $scan = Inspect-Sector $Media $Bank $Sector
    $generation = 1
    switch ($Operation) {
        'CLAIM' {
            if (-not $scan.FullErased) { return [pscustomobject]@{ Status = 'OCCUPIED'; Snapshot = $null } }
        }
        'CONVERT' {
            if ($scan.FullErased) { return [pscustomobject]@{ Status = 'NOT_OCCUPIED'; Snapshot = $null } }
            if ($scan.Class -in @('ACTIVE','RETIRED','BAD','RETIRED_BAD')) {
                return [pscustomobject]@{ Status = 'ALREADY_MANAGED'; Snapshot = $null }
            }
        }
        'FORMAT' {
            if ($scan.Class -notin @('ACTIVE','RETIRED','BAD','RETIRED_BAD')) {
                return [pscustomobject]@{ Status = 'NOT_MANAGED'; Snapshot = $null }
            }
            if (-not $scan.TailErased) { return [pscustomobject]@{ Status = 'SECTOR_IN_USE'; Snapshot = $null } }
            if ($scan.Generation -eq 0xFFFF) { return [pscustomobject]@{ Status = 'GEN_EXHAUSTED'; Snapshot = $null } }
            $generation = $scan.Generation + 1
        }
        default { return [pscustomobject]@{ Status = 'BAD_REQUEST'; Snapshot = $null } }
    }
    [pscustomobject]@{
        Status = 'PREPARED'
        Snapshot = [pscustomobject]@{
            Operation = $Operation; Bank = $Bank; Sector = $Sector
            Class = $scan.Class; FullErased = $scan.FullErased
            TailErased = $scan.TailErased; Crc = $scan.Crc; Generation = $generation
        }
    }
}

function Execute(
    [pscustomobject]$Prepared,
    [byte[]]$Media,
    [int]$Bank,
    [int]$Sector,
    [bool]$Confirmed,
    [int]$FaultAfter = -1
) {
    [byte[]]$result = $Media.Clone()
    if (-not $Confirmed) { return [pscustomobject]@{ Status = 'NOT_CONFIRMED'; Media = $result; Actions = 0 } }
    if ($Prepared.Status -ne 'PREPARED') { return [pscustomobject]@{ Status = 'MEDIA_CHANGED'; Media = $result; Actions = 0 } }
    $snapshot = $Prepared.Snapshot
    $current = Inspect-Sector $result $Bank $Sector
    if ($snapshot.Bank -ne $Bank -or $snapshot.Sector -ne $Sector -or
        $snapshot.Class -ne $current.Class -or $snapshot.FullErased -ne $current.FullErased -or
        $snapshot.TailErased -ne $current.TailErased -or $snapshot.Crc -ne $current.Crc) {
        return [pscustomobject]@{ Status = 'MEDIA_CHANGED'; Media = $result; Actions = 0 }
    }

    [byte[]]$header = New-Header $Bank $Sector $snapshot.Generation 0xFF
    $actions = 0
    if ($snapshot.Operation -ne 'CLAIM') {
        if ($FaultAfter -eq $actions) { return [pscustomobject]@{ Status = 'FAULT'; Media = $result; Actions = $actions } }
        $result = New-ErasedSector
        $actions++
    }
    for ($i = 0; $i -lt 15; $i++) {
        if ($FaultAfter -eq $actions) { return [pscustomobject]@{ Status = 'FAULT'; Media = $result; Actions = $actions } }
        $result[$i] = $header[$i]
        $actions++
    }
    if ($FaultAfter -eq $actions) { return [pscustomobject]@{ Status = 'FAULT'; Media = $result; Actions = $actions } }
    $result[15] = 0xFE
    $actions++
    [pscustomobject]@{ Status = 'OK'; Media = $result; Actions = $actions }
}

if (-not (Test-Path -LiteralPath $SourcePath)) { Fail "missing $SourcePath" }
if (-not (Test-Path -LiteralPath $S19Path)) { Fail "missing $S19Path" }
if (-not (Test-Path -LiteralPath $MapPath)) { Fail "missing $MapPath" }

$expectedMap = @{
    APSW_PREPARE_ENTRY = 0x7000; APSW_EXECUTE_ENTRY = 0x7003; APSW_LIMIT_EXCLUSIVE = 0x7C00
    APSW_CARD_BASE = 0x7C00; APSW_OP = 0x7C00; APSW_BANK = 0x7C01; APSW_SECTOR = 0x7C02
    APSW_CONFIRM = 0x7C03; APSW_PREP_CRC_LO = 0x7C04; APSW_PREP_CRC_HI = 0x7C05
    APSW_STATUS = 0x7C06; APSW_CLASS = 0x7C07; APSW_FLAGS = 0x7C08
    APSW_GENERATION_LO = 0x7C09; APSW_GENERATION_HI = 0x7C0A; APSW_FAIL_PHASE = 0x7C0B
    APSW_FAIL_ADDR_LO = 0x7C0C; APSW_FAIL_ADDR_HI = 0x7C0D
    APSW_CURRENT_CRC_LO = 0x7C0E; APSW_CURRENT_CRC_HI = 0x7C0F; APSW_HEADER_BASE = 0x7C10
    APSW_PRIVATE_BASE = 0x7C20; APSW_CARD_END = 0x7C2F
    APSW_OP_CLAIM = 1; APSW_OP_CONVERT = 2; APSW_OP_FORMAT = 3
    APSW_CONFIRM_EXECUTE = 0xA5; APSW_STATUS_PREPARED = 0xA0; APSW_STATUS_OK = 0xAC
    APSW_STATUS_BAD_REQUEST = 0xE0; APSW_STATUS_SELECT_FAILED = 0xE1
    APSW_STATUS_OCCUPIED = 0xE2; APSW_STATUS_NOT_MANAGED = 0xE3
    APSW_STATUS_SECTOR_IN_USE = 0xE4; APSW_STATUS_GEN_EXHAUSTED = 0xE5
    APSW_STATUS_MEDIA_CHANGED = 0xE6; APSW_STATUS_NOT_CONFIRMED = 0xE7
    APSW_STATUS_ERASE_FAILED = 0xE8; APSW_STATUS_PROGRAM_FAILED = 0xE9
    APSW_STATUS_VERIFY_FAILED = 0xEA; APSW_STATUS_RESTORE_FAILED = 0xEB
    APSW_STATUS_ALREADY_MANAGED = 0xEC; APSW_STATUS_NOT_OCCUPIED = 0xED
    APSW_CLASS_HEADER_FF = 0; APSW_CLASS_OPAQUE = 1; APSW_CLASS_CORRUPT = 2
    APSW_CLASS_STAGED = 3; APSW_CLASS_ACTIVE = 4; APSW_CLASS_RETIRED = 5
    APSW_CLASS_BAD = 6; APSW_CLASS_RETIRED_BAD = 7
    APSW_PHASE_NONE = 0; APSW_PHASE_SCAN = 1; APSW_PHASE_POLICY = 2
    APSW_PHASE_ERASE = 3; APSW_PHASE_ERASE_VERIFY = 4; APSW_PHASE_HEADER_WRITE = 5
    APSW_PHASE_HEADER_VERIFY = 6; APSW_PHASE_COMMIT = 7; APSW_PHASE_RESTORE = 8
}
foreach ($name in $expectedMap.Keys) {
    if ((Map $name) -ne $expectedMap[$name]) { Fail "$name changed" }
}

$endCode = Map '_END_CODE'
if ($endCode -gt (Map 'APSW_LIMIT_EXCLUSIVE')) { Fail ('linked code crosses overlay: ${0:X4}' -f $endCode) }
$image = Read-S19
for ($at = 0; $at -lt 0x10000; $at++) {
    if ($image.Present[$at] -and ($at -lt 0x7000 -or $at -ge 0x7C00)) {
        Fail ('S19 byte outside transient tray at ${0:X4}' -f $at)
    }
}
foreach ($entry in @(@(0x7000,'APSW_PREPARE'),@(0x7003,'APSW_EXECUTE'))) {
    $at = $entry[0]; $target = Map $entry[1]
    if ($image.Memory[$at] -ne 0x4C -or $image.Memory[$at + 1] -ne ($target -band 0xFF) -or
        $image.Memory[$at + 2] -ne (($target -shr 8) -band 0xFF)) {
        Fail ("entry stub at `${0:X4} does not JMP {1}" -f $at, $entry[1])
    }
}

$source = [IO.File]::ReadAllText((Resolve-Path $SourcePath))
foreach ($required in @(
    'JSR             STR8_BANK_SELECT_SERVICE', 'JSR             STR8_BANK_SELECT_RAM',
    'APSW_MUTATE_HEADER_BYTE:', 'APSW_VERIFY_HEADER_STAGED:', 'APSW_PHASE_COMMIT',
    'CMP             #APSW_CONFIRM_EXECUTE', 'STZ             APSW_CONFIRM',
    'APSW_FORCE_BANK3:', 'TRB             STR8_BANK_STATE_BYTE', 'TSB             STR8_BANK_STATE_BYTE'
)) {
    if (-not $source.Contains($required)) { Fail "source contract missing $required" }
}
foreach ($line in ($source -split "`r?`n")) {
    if ($line -match '^\s*JSR\s+([^;\s]+)') {
        $target = $matches[1]
        if ($target -notmatch '^(APSW_|STR8_BANK_SELECT_)') { Fail "unexpected external call $target" }
    }
}

# Policy matrix and exact committed headers across every eligible location.
$cases = 0
for ($bank = 0; $bank -le 2; $bank++) {
    for ($sector = 8; $sector -le 15; $sector++) {
        [byte[]]$blank = New-ErasedSector
        $claim = Prepare 'CLAIM' $blank $bank $sector
        if ($claim.Status -ne 'PREPARED' -or $claim.Snapshot.Generation -ne 1) { Fail 'erased CLAIM rejected' }
        $claimed = Execute $claim $blank $bank $sector $true
        if ($claimed.Status -ne 'OK' -or (Sector-Class $claimed.Media $bank $sector) -ne 'ACTIVE') { Fail 'CLAIM did not commit active header' }
        if (-not (Equal-Bytes (Slice $claimed.Media 0 16) (New-Header $bank $sector 1))) { Fail 'CLAIM header bytes changed' }
        $cases++
    }
}

[byte[]]$opaque = New-ErasedSector
$opaque[0x321] = 0x42
if ((Prepare 'CLAIM' $opaque 2 9).Status -ne 'OCCUPIED') { Fail 'CLAIM accepted occupied sector' }
if ((Prepare 'CONVERT' (New-ErasedSector) 2 9).Status -ne 'NOT_OCCUPIED') { Fail 'CONVERT accepted erased sector' }
$convert = Prepare 'CONVERT' $opaque 2 9
$converted = Execute $convert $opaque 2 9 $true
if ($converted.Status -ne 'OK' -or (Sector-Class $converted.Media 2 9) -ne 'ACTIVE' -or $converted.Media[0x321] -ne 0xFF) {
    Fail 'CONVERT did not erase and commit'
}
if ((Prepare 'CONVERT' (New-ManagedSector 2 9 7) 2 9).Status -ne 'ALREADY_MANAGED') { Fail 'CONVERT accepted managed sector' }

[byte[]]$managed = New-ManagedSector 1 12 0x1234
$format = Prepare 'FORMAT' $managed 1 12
$formatted = Execute $format $managed 1 12 $true
if ($formatted.Status -ne 'OK' -or $format.Snapshot.Generation -ne 0x1235 -or
    -not (Equal-Bytes (Slice $formatted.Media 0 16) (New-Header 1 12 0x1235))) { Fail 'FORMAT generation/header failed' }
$managed[16] = 0x41
if ((Prepare 'FORMAT' $managed 1 12).Status -ne 'SECTOR_IN_USE') { Fail 'FORMAT accepted nonempty log' }
$corrupt = New-ManagedSector 1 12 3
$corrupt[6] = $corrupt[6] -bxor 1
if ((Prepare 'FORMAT' $corrupt 1 12).Status -ne 'NOT_MANAGED') { Fail 'FORMAT accepted corrupt identity' }
if ((Prepare 'FORMAT' (New-ManagedSector 1 12 0xFFFF) 1 12).Status -ne 'GEN_EXHAUSTED') { Fail 'FORMAT wrapped generation' }
foreach ($state in @(0xFC,0xFA,0xF8)) {
    if ((Prepare 'FORMAT' (New-ManagedSector 0 15 9 $state) 0 15).Status -ne 'PREPARED') { Fail ('FORMAT rejected managed state ${0:X2}' -f $state) }
}

foreach ($bad in @(@(-1,8),@(3,8),@(0,7),@(0,16))) {
    if ((Prepare 'CLAIM' (New-ErasedSector) $bad[0] $bad[1]).Status -ne 'BAD_REQUEST') { Fail 'bad location accepted' }
}

# Confirmation and prepare/execute media binding are non-mutating failures.
[byte[]]$before = New-ErasedSector
$prepared = Prepare 'CLAIM' $before 0 8
$notConfirmed = Execute $prepared $before 0 8 $false
if ($notConfirmed.Status -ne 'NOT_CONFIRMED' -or -not (Equal-Bytes $before $notConfirmed.Media)) { Fail 'confirmation gate mutated media' }
[byte[]]$changed = $before.Clone(); $changed[0x222] = 0x00
$stale = Execute $prepared $changed 0 8 $true
if ($stale.Status -ne 'MEDIA_CHANGED' -or -not (Equal-Bytes $changed $stale.Media)) { Fail 'stale-media gate mutated media' }

# Commit-last fault matrix. No requested generation may classify ACTIVE before
# its final state-byte action; the last action must produce the exact header.
$faults = 0
foreach ($scenario in @(
    [pscustomobject]@{ Op='CLAIM'; Media=(New-ErasedSector); Bank=0; Sector=8 },
    [pscustomobject]@{ Op='CONVERT'; Media=$opaque.Clone(); Bank=2; Sector=9 },
    [pscustomobject]@{ Op='FORMAT'; Media=(New-ManagedSector 1 12 4); Bank=1; Sector=12 }
)) {
    $prep = Prepare $scenario.Op $scenario.Media $scenario.Bank $scenario.Sector
    $complete = Execute $prep $scenario.Media $scenario.Bank $scenario.Sector $true
    for ($cut = 0; $cut -lt $complete.Actions; $cut++) {
        $fault = Execute $prep $scenario.Media $scenario.Bank $scenario.Sector $true $cut
        if ($fault.Status -ne 'FAULT') { Fail "$($scenario.Op) fault $cut did not stop" }
        $class = Sector-Class $fault.Media $scenario.Bank $scenario.Sector
        $generation = [int]$fault.Media[4] -bor ([int]$fault.Media[5] -shl 8)
        if ($class -eq 'ACTIVE' -and $generation -eq $prep.Snapshot.Generation) {
            Fail "$($scenario.Op) exposed requested generation before commit at fault $cut"
        }
        $faults++
    }
    if ($complete.Status -ne 'OK' -or (Sector-Class $complete.Media $scenario.Bank $scenario.Sector) -ne 'ACTIVE') {
        Fail "$($scenario.Op) final commit failed"
    }
}

# A selected-sector operation cannot touch arbitrary peers or Bank 3 in the
# media model.
$banks = @()
for ($bank = 0; $bank -lt 4; $bank++) {
    [byte[]]$bytes = [byte[]]::new(0x8000)
    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [byte](($bank * 37 + $i) -band 0xFF) }
    $banks += ,$bytes
}
$targetOffset = (10 - 8) * 4096
[byte[]]$target = New-ErasedSector
[Array]::Copy($target, 0, $banks[2], $targetOffset, 4096)
$peerBaseline = @()
for ($bank = 0; $bank -lt 4; $bank++) { $peerBaseline += ,([byte[]]$banks[$bank].Clone()) }
$peerPrep = Prepare 'CLAIM' (Slice $banks[2] $targetOffset 4096) 2 10
$peerDone = Execute $peerPrep (Slice $banks[2] $targetOffset 4096) 2 10 $true
[Array]::Copy($peerDone.Media, 0, $banks[2], $targetOffset, 4096)
for ($bank = 0; $bank -lt 4; $bank++) {
    for ($i = 0; $i -lt 0x8000; $i++) {
        $inTarget = $bank -eq 2 -and $i -ge $targetOffset -and $i -lt ($targetOffset + 4096)
        if (-not $inTarget -and $banks[$bank][$i] -ne $peerBaseline[$bank][$i]) {
            Fail ('outside-sector mutation B{0} offset ${1:X4}' -f $bank, $i)
        }
    }
}

$size = $endCode - (Map 'APSW_LOAD_BASE')
Write-Host ("AP Store sector tool check passed: bytes={0} end=`${1:X4} locations={2} fault-cuts={3}" -f $size, $endCode, $cases, $faults)
Write-Host "AP Store sector tool policy: CLAIM erased-only; CONVERT occupied-unmanaged; FORMAT managed-empty-log; commit-last"

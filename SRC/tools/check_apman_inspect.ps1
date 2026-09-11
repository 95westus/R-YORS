param(
    [string]$SourcePath = "APPS/apman-7000.asm",
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$MapPath = "BUILD/s19/apman-7000.map",
    [string]$PackagePath = "BUILD/bin/apman-v1.ap"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "APMAN inspect check: $Message"
}

function Fnv32([byte[]]$Bytes) {
    [uint64]$hash = 2166136261
    foreach ($value in $Bytes) {
        $hash = (($hash -bxor [uint64]$value) * [uint64]16777619) -band [uint64]4294967295
    }
    [uint32]$hash
}

function Map([string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $MapPath))) {
        if ($line -match $pattern) { return [Convert]::ToInt32($matches[1], 16) }
    }
    Fail "map symbol $Name is missing"
}

$source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SourcePath))
$himonSource = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HimonSourcePath))
$apDispatchStart = $himonSource.IndexOf('CMD_AP:')
$apDispatchEnd = $himonSource.IndexOf('CMD_AP_SRC_OK:')
if ($apDispatchStart -lt 0 -or $apDispatchEnd -le $apDispatchStart) {
    Fail 'HIMON AP dispatch bounds are malformed'
}
$apDispatch = $himonSource.Substring($apDispatchStart, $apDispatchEnd - $apDispatchStart)
if (-not $apDispatch.Contains("CMP             #'D'") -or
        -not $apDispatch.Contains('BEQ             CMD_AP_MANAGER')) {
    Fail 'HIMON does not route AP D to APMAN'
}
if (-not $himonSource.Contains('AP [L|D] Bn name|s000 [dst')) {
    Fail 'HIMON AP usage does not advertise D inspection mode'
}
foreach ($required in @(
    'FLAG_DUMP', "CMP             #'D'", 'APMAN_AP_DUMP_EOL:',
    'JSR             APMAN_PRINT_CARRIER_DETAIL_BODY',
    'JSR             APMAN_PRINT_SECTIONS', 'JSR             APMAN_DUMP_PREFIX',
    'APMAN_PRINT_SECTIONS:', 'LDA             #$05',
    'APMAN_DUMP_PREFIX:', 'LDA             #$04', 'CPY             #$10',
    'MSG_APD_PREFIX:        DB              "APD ",0',
    'MSG_APC:               DB              "APC ",0'
)) {
    if (-not $source.Contains($required)) { Fail "source is missing $required" }
}

$dumpStart = $source.IndexOf('APMAN_AP_DUMP_EOL:')
$normalStart = $source.IndexOf('APMAN_AP_NOT_DUMP:')
if ($dumpStart -lt 0 -or $normalStart -le $dumpStart) { Fail 'inspect branch bounds are malformed' }
$dumpBranch = $source.Substring($dumpStart, $normalStart - $dumpStart)
if (-not $dumpBranch.Contains('JMP             APMAN_RETURN_OK')) {
    Fail 'inspect branch does not return before normal AP handling'
}
foreach ($forbidden in @(
    'APMAN_SELECTED_IS_MANAGER', 'APMAN_LOAD_RANGE_SAFE', 'HIM_AP_OP_LOAD',
    'APMAN_INSTALL', 'STR8_WORKER_ENTRY', 'APMAN_AP_EXECUTE'
)) {
    if ($dumpBranch.Contains($forbidden)) { Fail "inspect branch reaches $forbidden" }
}

$printStart = $source.IndexOf('APMAN_PRINT_SECTIONS:')
$printEnd = $source.IndexOf('APMAN_PRINT_LOCATION:')
if ($printStart -lt 0 -or $printEnd -le $printStart) { Fail 'inspect printer bounds are malformed' }
$printers = $source.Substring($printStart, $printEnd - $printStart)
foreach ($required in @('PHY', 'PLY')) {
    if (-not $printers.Contains($required)) { Fail "dump loop does not preserve Y with $required" }
}
foreach ($forbidden in @('APMAN_STAGE_RAW', 'STR8_SELECT', 'STR8_WORKER', 'STA             (')) {
    if ($printers.Contains($forbidden)) { Fail "inspect printer contains mutating operation $forbidden" }
}

[byte[]]$package = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PackagePath))
if ($package.Length -lt 0x40 -or $package.Length -gt 0x1000) {
    Fail ('package length ${0:X4} is outside $0040-$1000' -f $package.Length)
}
if ($package[0] -ne [byte][char]'A' -or $package[1] -ne [byte][char]'P' -or $package[2] -ne 2) {
    Fail 'package is not AP v2'
}
$declared = [int]$package[3] -bor ([int]$package[4] -shl 8)
if ($declared -ne $package.Length) { Fail 'declared package length mismatch' }

$tags = @('S','R','E','I','B')
$bounds = [Collections.Generic.List[string]]::new()
$cursor = 5
$exportStart = -1
$bodyStart = -1
for ($section = 0; $section -lt $tags.Count; $section++) {
    if (($cursor + 3) -gt $package.Length) { Fail 'truncated section header' }
    $tag = [char]$package[$cursor]
    if ($tag -ne $tags[$section]) { Fail "section $section is $tag, expected $($tags[$section])" }
    $length = [int]$package[$cursor + 1] -bor ([int]$package[$cursor + 2] -shl 8)
    $end = $cursor + 3 + $length
    if ($end -gt $package.Length) { Fail "section $tag is truncated" }
    $bounds.Add(('{0}:{1:X4}-{2:X4}' -f $tag, $cursor, ($end - 1)))
    if ($tag -eq 'E') { $exportStart = $cursor + 3 }
    if ($tag -eq 'B') { $bodyStart = $cursor + 3 }
    $cursor = $end
}
if ($cursor -ne $package.Length) { Fail 'section walk does not end at package length' }

if ($exportStart -lt 0 -or $package[$exportStart] -ne 1) { Fail 'single export table is missing' }
$row = $exportStart + 1
if (($package[$row] -band 0x80) -eq 0) { Fail 'APMAN export is not the entry' }
[uint32]$expectedHash = Fnv32 ([Text.Encoding]::ASCII.GetBytes('APMAN'))
[uint32]$actualHash = [uint32]$package[$row + 3] -bor
    ([uint32]$package[$row + 4] -shl 8) -bor
    ([uint32]$package[$row + 5] -shl 16) -bor
    ([uint32]$package[$row + 6] -shl 24)
if ($actualHash -ne $expectedHash -or $package[$row + 7] -ne 5) {
    Fail 'APMAN named self-selector metadata is wrong'
}

$imageEnd = Map 'APMAN_IMAGE_END'
if ($imageEnd -gt 0x7C00) { Fail ('APMAN body exceeds tray: end=${0:X4}' -f $imageEnd) }
if ((Map 'APMAN_DUMP_PREFIX') -ge (Map 'APMAN_PRINT_LOCATION')) {
    Fail 'bounded dump routine is outside the inspect-printer slice'
}

# APMAN owns the PIA display while it stages banked media. Freeze the linked
# sequence that publishes SECTOR|BANK, reloads BANK into A, and only then calls
# the checked STR8 selector. This is deliberately before bank switching and
# remains safe when APMAN executes from its RAM overlay.
if ($bodyStart -lt 0) { Fail 'BODY payload is missing' }
$stageOffset = $bodyStart + (Map 'APMAN_STAGE_RAW') - 0x7000
[byte[]]$stagePrefix = @(
    0x08, 0x78,             # PHP / SEI
    0xA5, 0xA8,             # LDA SECTOR
    0x05, 0xA7,             # ORA BANK
    0x8D, 0xA0, 0x7F,       # STA $7FA0
    0xA5, 0xA7,             # LDA BANK
    0x20, 0x10, 0xF0        # JSR $F010
)
for ($i = 0; $i -lt $stagePrefix.Length; $i++) {
    if ($package[$stageOffset + $i] -ne $stagePrefix[$i]) {
        Fail ('APMAN stage LED/select prefix differs at +${0:X2}' -f $i)
    }
}

Write-Host (('APMAN inspect check OK package=${0:X4} body-end=${1:X4} sections={2} ' +
    'dump=0000-003F self=APMAN read-only LED=SECTOR|BANK') -f $package.Length, $imageEnd, ($bounds -join ','))

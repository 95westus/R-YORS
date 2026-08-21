param(
    [string]$ContractPath = "ASM/asm-abi-v1.inc",
    [string]$AsmSourcePath = "ASM/asm-v1-core.asm",
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$HimonSharedPath = "HIMON/himon-shared-eq.inc",
    [string]$PackagePath = "BUILD/bin/asm-session-report-v1.2-7000.ap.bin"
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "ASM ABI v1 check: $Message" }

function Read-Equ([string]$Text, [string]$Name) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s+EQU\s+(\$[0-9A-Fa-f]+|''.'')\s*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { Fail "missing literal $Name" }
    $token = $match.Groups[1].Value
    if ($token[0] -eq '$') { return [Convert]::ToInt32($token.Substring(1), 16) }
    return [int][char]$token[1]
}

foreach ($path in @($ContractPath, $AsmSourcePath, $HimonSourcePath,
        $HimonSharedPath, $PackagePath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "missing input $path" }
}

$contract = [IO.File]::ReadAllText((Resolve-Path $ContractPath))
$asm = [IO.File]::ReadAllText((Resolve-Path $AsmSourcePath))
$himon = [IO.File]::ReadAllText((Resolve-Path $HimonSourcePath))
$shared = [IO.File]::ReadAllText((Resolve-Path $HimonSharedPath))

$expected = [ordered]@{
    ASM_ABI_VERSION = 1
    ASM_ABI_SVC_SIG0 = 0x7E02; ASM_ABI_SVC_SIG1 = 0x7E03
    ASM_ABI_SVC_VERSION = 0x7E04; ASM_ABI_SVC_COUNT = 0x7E05
    ASM_ABI_SVC_FIRST_VECTOR = 0x7E06; ASM_ABI_SVC_CHECKSUM = 0x7E1C
    ASM_ABI_SVC_SIG0_VALUE = [int][char]'R'; ASM_ABI_SVC_SIG1_VALUE = [int][char]'Y'
    ASM_ABI_SVC_VERSION_VALUE = 1; ASM_ABI_SVC_VECTOR_COUNT = 11
    ASM_ABI_PACK40_ASCII = 0x7E1F; ASM_ABI_PACK40_PACK3 = 0x7E21
    ASM_ABI_AP_IMPORT_PTR = 0x7E23; ASM_ABI_FLASH_INSTALL = 0x7E25
    ASM_ABI_AP_SERVICE = 0x7E2D; ASM_ABI_AP_OP = 0x7E2F
    ASM_ABI_AP_STATUS = 0x7E30; ASM_ABI_AP_SRC = 0x7E31
    ASM_ABI_AP_DST = 0x7E33; ASM_ABI_AP_PACKAGE_LEN = 0x7E35
    ASM_ABI_AP_BODY = 0x7E37; ASM_ABI_AP_BODY_LEN = 0x7E39
    ASM_ABI_AP_RELOC_COUNT = 0x7E3B; ASM_ABI_AP_IMPORT_COUNT = 0x7E3C
    ASM_ABI_AP_INSTALL = 0x7E3D; ASM_ABI_AP_RELOC_PTR = 0x7E3F
    ASM_ABI_AP_OP_PARSE = 0; ASM_ABI_AP_OP_LOAD = 1
    ASM_ABI_AP_OP_SUGGEST = 2; ASM_ABI_AP_OP_LINK = 3
    ASM_ABI_STATUS_OK = 0; ASM_ABI_STATUS_BAD_RANGE = 6
    ASM_ABI_STATUS_BAD_LINE = 7; ASM_ABI_STATUS_BAD_FIX = 9
    ASM_ABI_AP_SIG0_VALUE = [int][char]'A'; ASM_ABI_AP_SIG1_VALUE = [int][char]'P'
    ASM_ABI_AP_VERSION = 2; ASM_ABI_AP_HEADER_BYTES = 5
    ASM_ABI_AP_FIXED_BYTES = 31; ASM_ABI_AP_MAX_BYTES = 4096
    ASM_ABI_AP_TAG_SEAL = [int][char]'S'; ASM_ABI_AP_TAG_RELOC = [int][char]'R'
    ASM_ABI_AP_TAG_EXPORT = [int][char]'E'; ASM_ABI_AP_TAG_IMPORT = [int][char]'I'
    ASM_ABI_AP_TAG_BODY = [int][char]'B'; ASM_ABI_AP_SEAL_BYTES = 11
    ASM_ABI_AP_ROW_MAX = 64; ASM_ABI_AP_KIND_EXEC = 1
    ASM_ABI_AP_KIND_DATA = 2; ASM_ABI_AP_FLAG_ENTRY = 0x80
    ASM_ABI_AP_RELOC_ABS16 = 1; ASM_ABI_AP_RELOC_LO8 = 2
    ASM_ABI_AP_RELOC_HI8 = 3; ASM_ABI_AP_RELOC_ABS16_IMP = 4
    ASM_ABI_AP_RELOC_LO8_IMP = 5; ASM_ABI_AP_RELOC_HI8_IMP = 6
}
foreach ($entry in $expected.GetEnumerator()) {
    $actual = Read-Equ $contract $entry.Key
    if ($actual -ne $entry.Value) { Fail "$($entry.Key)=$actual, expected $($entry.Value)" }
}

foreach ($text in @($asm, $himon)) {
    if (-not $text.Contains('INCLUDE         "ASM/asm-abi-v1.inc"')) {
        Fail 'ASM and HIMON must include the canonical contract'
    }
}

$addressPairs = [ordered]@{
    HIM_SVC_SIG0 = 'ASM_ABI_SVC_SIG0'; HIM_SVC_SIG1 = 'ASM_ABI_SVC_SIG1'
    HIM_SVC_VERSION = 'ASM_ABI_SVC_VERSION'; HIM_SVC_COUNT = 'ASM_ABI_SVC_COUNT'
    HIM_SVC_JOIN_LO = 'ASM_ABI_SVC_FIRST_VECTOR'; HIM_SVC_CHECKSUM = 'ASM_ABI_SVC_CHECKSUM'
    HIM_SVC_PACK40_ASCII_LO = 'ASM_ABI_PACK40_ASCII'; HIM_SVC_PACK40_PACK3_LO = 'ASM_ABI_PACK40_PACK3'
    HIM_AP_IMPORT_LO = 'ASM_ABI_AP_IMPORT_PTR'; HIM_SVC_FLASH_INSTALL_LO = 'ASM_ABI_FLASH_INSTALL'
    HIM_SVC_AP_LO = 'ASM_ABI_AP_SERVICE'; HIM_AP_OP = 'ASM_ABI_AP_OP'
    HIM_AP_STATUS = 'ASM_ABI_AP_STATUS'; HIM_AP_SRC_LO = 'ASM_ABI_AP_SRC'
    HIM_AP_DST_LO = 'ASM_ABI_AP_DST'; HIM_AP_PKG_LEN_LO = 'ASM_ABI_AP_PACKAGE_LEN'
    HIM_AP_BODY_LO = 'ASM_ABI_AP_BODY'; HIM_AP_BODY_LEN_LO = 'ASM_ABI_AP_BODY_LEN'
    HIM_AP_RELOC_COUNT = 'ASM_ABI_AP_RELOC_COUNT'; HIM_AP_IMPORT_COUNT = 'ASM_ABI_AP_IMPORT_COUNT'
    HIM_AP_INSTALL_LO = 'ASM_ABI_AP_INSTALL'; HIM_AP_REL_LO = 'ASM_ABI_AP_RELOC_PTR'
}
foreach ($entry in $addressPairs.GetEnumerator()) {
    $actual = Read-Equ $shared $entry.Key
    if ($actual -ne $expected[$entry.Value]) { Fail "$($entry.Key) moved" }
}

$bootOrder = @('THE_JOIN_EXEC_XY','BIO_FTDI_WRITE_BYTE_BLOCK','SYS_WRITE_CSTRING',
    'SYS_WRITE_HEX_BYTE','SYS_WRITE_CRLF','HIM_READ_LINE_ECHO',
    'UTL_HEX_ASCII_TO_NIBBLE','FNV1A_INIT','FNV1A_UPDATE_A_FAST',
    'HIM_CHAR_TO_UPPER','HIM_WRITE_HBSTRING')
$boot = [regex]::Match($himon, 'HIM_SVC_BOOT_TABLE:(.*?)HIM_SVC_BOOT_TABLE_END:', 'Singleline').Groups[1].Value
$vectors = [regex]::Matches($boot, '(?m)^\s*DW\s+([A-Z0-9_]+)\s*$') |
    ForEach-Object { $_.Groups[1].Value }
if (($vectors -join ',') -ne ($bootOrder -join ',')) { Fail 'service-vector order changed' }

[byte[]]$bytes = [IO.File]::ReadAllBytes((Resolve-Path $PackagePath))
if ($bytes.Length -lt 31 -or $bytes.Length -gt 4096) { Fail 'AP package size is outside ABI bounds' }
if ($bytes[0] -ne [byte][char]'A' -or $bytes[1] -ne [byte][char]'P' -or $bytes[2] -ne 2) {
    Fail 'AP package identity changed'
}
$total = [int]$bytes[3] -bor ([int]$bytes[4] -shl 8)
if ($total -ne $bytes.Length) { Fail 'AP package total length mismatch' }
$cursor = 5
foreach ($tag in @('S','R','E','I','B')) {
    if ($cursor + 3 -gt $bytes.Length -or $bytes[$cursor] -ne [byte][char]$tag) {
        Fail "AP section order changed at $tag"
    }
    $length = [int]$bytes[$cursor + 1] -bor ([int]$bytes[$cursor + 2] -shl 8)
    $cursor += 3 + $length
}
if ($cursor -ne $bytes.Length) { Fail 'AP package has trailing or truncated data' }

Write-Host 'ASM ABI v1 check passed.'

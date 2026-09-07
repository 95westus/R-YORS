param(
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$HimonMapPath = "BUILD/s19/himon-rom-c000.map",
    [string]$PublicContractPath = "BUILD/inc/str8n-public.inc"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "HIMON STR8 record-client check: $Message"
}

if (-not (Test-Path -LiteralPath $HimonMapPath -PathType Leaf)) {
    $mapLeaf = Split-Path -Leaf $HimonMapPath
    $buildDir = Split-Path -Parent (Split-Path -Parent $HimonMapPath)
    $artifactMap = Join-Path (Join-Path $buildDir 'map') $mapLeaf
    if (Test-Path -LiteralPath $artifactMap -PathType Leaf) {
        $HimonMapPath = $artifactMap
    }
}

foreach ($path in @($HimonSourcePath, $HimonMapPath, $PublicContractPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail-Check "missing file: $path"
    }
}

$source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HimonSourcePath))
$map = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HimonMapPath))
$contract = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PublicContractPath))

function Require-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { Fail-Check "missing $Description" }
}

function Forbid-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -match $Pattern) { Fail-Check "found retired $Description" }
}

function Read-ContractHex([string]$Name) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s+EQU\s+\$([0-9A-Fa-f]+)\s*$'
    $matches = [regex]::Matches($contract, $pattern)
    if ($matches.Count -ne 1) {
        Fail-Check "contract must define $Name exactly once"
    }
    return [Convert]::ToInt32($matches[0].Groups[1].Value, 16)
}

$expectedContract = [ordered]@{
    STR8_RECORD_SERVICE = 0xF009
    STR8_REC_SIG0_ADDR = 0xF00C
    STR8_REC_SIG1_ADDR = 0xF00D
    STR8_REC_VERSION_ADDR = 0xF00E
    STR8_REC_CAPS_ADDR = 0xF00F
    STR8_REC_VERSION_VALUE = 0x02
    STR8_REC_CAP_BUFFER = 0x01
    STR8_REC_OP = 0x7E95
    STR8_REC_SRC_LO = 0x7E99
    STR8_REC_KIND = 0x7E9C
    STR8_REC_DATA_LEN = 0x7EA0
    STR8_REC_ENTRY_LO = 0x7EA1
    STR8_REC_DATA_LO = 0x7EA3
    STR8_REC_DATA_BUF = 0x7B00
    STR8_REC_OP_PARSE = 0x01
    STR8_REC_FORMAT_S19 = 0x01
    STR8_REC_SOURCE_BUFFER = 0x00
    STR8_REC_KIND_METADATA = 0x01
    STR8_REC_KIND_DATA = 0x02
    STR8_REC_KIND_END = 0x03
    STR8_REC_BAD_START = 0x04
    STR8_REC_BAD_END = 0x09
    STR8_SOFT_RESET_SIG0 = 0x7DE7
    STR8_SOFT_RESET_SIG1 = 0x7DE8
}

foreach ($entry in $expectedContract.GetEnumerator()) {
    $actual = Read-ContractHex $entry.Key
    if ($actual -ne $entry.Value) {
        Fail-Check ('contract {0} is ${1:X}, expected ${2:X}' -f $entry.Key, $actual, $entry.Value)
    }
}

Require-Match $source '(?m)^L_STR8_REQUIRE_SERVICE:' 'STR8 service compatibility gate'
Require-Match $source '(?m)^L_PARSE_RECORD_STR8:' 'STR8 record adapter'
Require-Match $source '(?m)^\s+JSR\s+STR8_RECORD_SERVICE\s*$' 'call through the public $F009 doorway'
Require-Match $source '(?m)^\s+LDA\s+#STR8_REC_SOURCE_BUFFER\s*$' 'buffer-source request'
Require-Match $source '(?m)^\s+LDA\s+#<CMD_BUF\s*$' 'HIMON command-buffer request pointer'
Require-Match $source '(?m)^L_VALIDATE_RAM_SPAN:' 'HIMON RAM-span policy'
Require-Match $source '(?m)^\s+CMP\s+#\$7A\s*$' 'HIMON $7A00 protection ceiling'
Require-Match $source '(?m)^\s+LDA\s+\(CMDP_PTR_LO\),Y\s*$' 'validated descriptor-buffer copy'
Require-Match $source '(?m)^\s+LDA\s+#LOAD_FAIL_SERVICE\s*$' 'service failure mapping'
Require-Match $source '(?m)^CMD_STR8_SOFT_RESET:' 'STR8 software-reset wrapper'
Require-Match $source '(?ms)^CMD_STR8_SOFT_RESET:\s+SEI\s+STZ\s+STR8_SOFT_RESET_SIG1\s+LDA\s+#STR8_SOFT_RESET_SIG0_VALUE\s+STA\s+STR8_SOFT_RESET_SIG0\s+LDA\s+#STR8_SOFT_RESET_SIG1_VALUE\s+STA\s+STR8_SOFT_RESET_SIG1\s+JMP\s+\$F000\s*$' 'ordered RS commit and immediate STR8 transfer'
Require-Match $source '(?ms)^CMD_STR8_FNV:.*?DW\s+CMD_STR8_SOFT_RESET\s+DW\s+TXT_STR8\s*$' 'STR8 command binding to the software-reset wrapper'

foreach ($retired in @(
    'L_PARSE_RECORD', 'L_PARSE_HEADER', 'L_SUM_ADD_A',
    'L_VERIFY_CHECKSUM_EOL', 'L_PARSE_HEX_BYTE_STRICT'
)) {
    Forbid-Match $source ('(?m)^' + [regex]::Escape($retired) + ':') "$retired source label"
    Forbid-Match $map ('(?m)^\s*[0-9A-Fa-f]{8}\s+' + [regex]::Escape($retired) + '\s*$') "$retired map symbol"
}

foreach ($required in @(
    'L_STR8_REQUIRE_SERVICE', 'L_PARSE_RECORD_STR8',
    'L_PARSE_RECORD_STR8_COPY', 'L_VALIDATE_RAM_SPAN'
)) {
    Require-Match $map ('(?m)^\s*[0-9A-Fa-f]{8}\s+' + [regex]::Escape($required) + '\s*$') "$required map symbol"
}

$endMatch = [regex]::Match($map, '(?m)^\s*([0-9A-Fa-f]{8})\s+_END_DATA\s*$')
if (-not $endMatch.Success) { Fail-Check 'map symbol _END_DATA is missing' }
$endData = [Convert]::ToInt32($endMatch.Groups[1].Value, 16)
if ($endData -gt 0xF000) {
    Fail-Check ('HIMON end ${0:X4} overlaps STR8-N at $F000' -f $endData)
}

Write-Host ('HIMON STR8 client = PASS; SR/02 parser + ordered RS reset marker; end=${0:X4}; margin=${1:X4}' -f $endData, (0xF000 - $endData))

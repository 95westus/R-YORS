param(
    [Parameter(Mandatory = $true)][string]$AsmPath,
    [Parameter(Mandatory = $true)][string]$APath,
    [Parameter(Mandatory = $true)][string]$S19Path,
    [Parameter(Mandatory = $true)][string]$MapPath,
    [Parameter(Mandatory = $true)][string]$GeneratorPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-S19([string]$Path) {
    $data = [Collections.Generic.SortedDictionary[int,byte]]::new()
    $entry = $null
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -notmatch '^S([0-9])([0-9A-Fa-f]{2})([0-9A-Fa-f]+)$') {
            throw "malformed S-record: $line"
        }
        $type = [int]$matches[1]
        $count = [Convert]::ToInt32($matches[2],16)
        $tail = $matches[3]
        if ($tail.Length -ne $count * 2) { throw "wrong S-record byte count: $line" }
        $bytes = for ($i=0; $i -lt $count; $i++) {
            [Convert]::ToByte($tail.Substring(2*$i,2),16)
        }
        $sum = $count
        foreach ($b in $bytes) { $sum += $b }
        if (($sum -band 0xFF) -ne 0xFF) { throw "bad S-record checksum: $line" }
        $addressBytes = if ($type -in 1,9) { 2 } elseif ($type -in 2,8) { 3 } elseif ($type -in 3,7) { 4 } else { 0 }
        if ($addressBytes -eq 0) { continue }
        $address = 0
        for ($i=0; $i -lt $addressBytes; $i++) {
            $address = 256*$address + $bytes[$i]
        }
        if ($type -in 7,8,9) { $entry = $address -band 0xFFFF; continue }
        for ($i=0; $i -lt ($count-$addressBytes-1); $i++) {
            $data.Add(($address+$i)-band 0xFFFF,$bytes[$addressBytes+$i])
        }
    }
    return [pscustomobject]@{Data=$data;Entry=$entry}
}

foreach ($path in @($AsmPath,$APath,$S19Path,$MapPath,$GeneratorPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing BANKDUMP input: $path" }
}

# Recreate the .a and compare it byte-for-byte.  This proves that every fixed
# internal operand still names the host linker's current $2000 address.
$temp = Join-Path ([IO.Path]::GetTempPath()) ("bank-dump-{0}.a" -f [guid]::NewGuid())
try {
    & (Resolve-Path -LiteralPath $GeneratorPath) -AsmPath $AsmPath -MapPath $MapPath -OutPath $temp
    $actualText = [Convert]::ToBase64String(
        [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $APath)))
    $expectedText = [Convert]::ToBase64String([IO.File]::ReadAllBytes($temp))
    if ($actualText -cne $expectedText) {
        throw 'BANKDUMP onboard source is stale relative to host source/map'
    }
}
finally {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}

$aText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $APath))
$lineNumber = 0
foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $APath))) {
    $lineNumber++
    if ($line.TrimStart().StartsWith(';')) { continue }
    if ($line.Length -gt 63) {
        throw "BANKDUMP onboard source line $lineNumber is $($line.Length) columns; maximum is 63"
    }
}
foreach ($required in @(
    'ENTRY BANKDUMP',
    'IMPORT BIO_FTDI_PUT_CSTR',
    'IMPORT SYS_READ_CSTRING_ECHO_UPPER',
    'IMPORT BIO_FTDI_WRITE_BYTE_BLOCK',
    'BANK_SELECT EQU $F010',
    'BANK_SELECT_RAM EQU $0203')) {
    if (-not $aText.Contains($required)) { throw ".a is missing required contract: $required" }
}
foreach ($forbidden in @('$F003','FLASH_WRITE','FLASH_ERASE','PROGRAM_BYTE')) {
    if ($aText.Contains($forbidden)) { throw ".a reaches or names forbidden mutation surface: $forbidden" }
}

$imports = @(
    'BIO_FTDI_PUT_CSTR',
    'SYS_READ_CSTRING_ECHO_UPPER',
    'BIO_FTDI_WRITE_BYTE_BLOCK'
)
$relocRows = 0
foreach ($import in $imports) {
    $uses = [regex]::Matches($aText,
        ('(?m)^(?:[A-Z_][A-Z0-9_]*\s+)?(?:JSR|JMP)\s+' + [regex]::Escape($import) + '\s*$')).Count
    if ($uses -ne 1) { throw "BANKDUMP import $import has $uses uses, expected one" }
    $relocRows += $uses
}
if ($relocRows -ne 3) { throw "BANKDUMP relocation-row count is $relocRows, expected 3" }

$symbolicCalls = [regex]::Matches($aText,
    '(?m)^(?:[A-Z_][A-Z0-9_]*\s+)?(?:JSR|JMP)\s+([A-Z_][A-Z0-9_]*)\s*$')
foreach ($call in $symbolicCalls) {
    $target = $call.Groups[1].Value
    if (($imports -notcontains $target) -and
            $target -notin @('BANK_SELECT','BANK_SELECT_RAM')) {
        throw "BANKDUMP has an unexpected relocatable call target: $target"
    }
}

$s19 = Read-S19 $S19Path
if ($s19.Entry -ne 0x2000) { throw ('S19 entry is ${0:X4}, expected $2000' -f $s19.Entry) }
$keys = @($s19.Data.Keys)
if ($keys.Count -eq 0 -or $keys[0] -ne 0x2000) { throw 'S19 does not begin at $2000' }
$last = $keys[-1]
for ($address=0x2000; $address -le $last; $address++) {
    if (-not $s19.Data.ContainsKey($address)) { throw ('S19 gap at ${0:X4}' -f $address) }
}
[byte[]]$image = for ($address=0x2000; $address -le $last; $address++) {
    $s19.Data[$address]
}
if ($image.Length -ne 0x0516) {
    throw ('BANKDUMP body is ${0:X4}, expected $0516' -f $image.Length)
}
$hex = [BitConverter]::ToString($image).Replace('-','')
foreach ($required in @('2010F0','200302','AD0040C941','AD0140C950','AD0240C902')) {
    if (-not $hex.Contains($required)) { throw "S19 is missing required read-only sequence $required" }
}

$fnv = [uint64]2166136261
foreach ($b in $image) {
    $fnv = (($fnv -bxor [uint64]$b) * [uint64]16777619) -band [uint64]4294967295
}
if ([uint32]$fnv -ne [uint32]0x2CB2A3ED) {
    throw ('BANKDUMP FNV32 is ${0:X8}, expected $2CB2A3ED' -f [uint32]$fnv)
}
$exportRecordLength = 1 + 1 + 2 + 4 + 1 + (2 * [Math]::Ceiling('BANKDUMP'.Length / 3.0))
$importSectionLength = 1
foreach ($import in $imports) {
    $importSectionLength += 1 + 4 + 1 + (2 * [Math]::Ceiling($import.Length / 3.0))
}
$packageLength = [int](0x1F + (1 + (5 * $relocRows)) +
    $exportRecordLength + $importSectionLength + $image.Length)
if ($packageLength -ne 0x0597) {
    throw ('BANKDUMP package length is ${0:X4}, expected $0597' -f $packageLength)
}

Write-Host 'BANKDUMP host map/onboard fixed operands: identical and current'
Write-Host ('BANKDUMP S19: $2000-${0:X4}, {1} bytes, FNV32=${2:X8}' -f $last,$image.Length,[uint32]$fnv)
Write-Host ('BANKDUMP onboard AP v2: {0} import relocations, package length=${1:X4}' -f $relocRows,$packageLength)
Write-Host 'BANKDUMP policy: stage, restore B3, decode/dump/CRC; no mutation doorway'

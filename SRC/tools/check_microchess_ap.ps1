param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$LicensePath,
    [Parameter(Mandatory = $true)][string]$MapPath,
    [Parameter(Mandatory = $true)][string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Text {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) { throw $Message }
}

function Get-MapAddress {
    param([string[]]$Lines, [string]$Symbol)
    $escaped = [regex]::Escape($Symbol)
    foreach ($line in $Lines) {
        if ($line -match "^\s*([0-9A-Fa-f]{8})\s+$escaped\s*$") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    }
    throw "missing map symbol: $Symbol"
}

$source = Get-Content -LiteralPath $SourcePath -Raw
$license = Get-Content -LiteralPath $LicensePath -Raw
$map = Get-Content -LiteralPath $MapPath
$package = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PackagePath))

Require-Text $source 'Kim-1 MicroChess \(c\) 1976-2005 Peter Jennings' 'upstream copyright notice is missing'
Require-Text $source 'Redistribution and use in source and binary forms' 'upstream redistribution terms are missing'
Require-Text $source 'name of the author may not be used to endorse' 'upstream non-endorsement condition is missing'
Require-Text $source 'produced with assistance from OpenAI\s+; Codex, an AI coding system' 'R-YORS AI adaptation notice is missing'
Require-Text $source 'This notice does not alter the upstream\s+; copyright or license terms above' 'AI notice must preserve the upstream terms'
Require-Text $license 'Kim-1 MicroChess \(c\) 1976-2005 Peter Jennings' 'binary-distribution copyright notice is missing'
Require-Text $license 'Redistribution and use in source and binary forms' 'binary-distribution terms are missing'
Require-Text $license 'THIS SOFTWARE IS PROVIDED BY THE AUTHOR' 'binary-distribution disclaimer is missing'
Require-Text $source 'BIO_FTDI_READ_BYTE_BLOCK' 'HIMON input adapter is missing'
Require-Text $source 'BIO_FTDI_WRITE_BYTE_BLOCK' 'HIMON output adapter is missing'
Require-Text $source 'MICROCHESS_IMP_WRITE_HEX:\s+DW\s+\$FFFF' 'published SYS hex adapter is missing'
Require-Text $source 'BOARD\s+EQU\s+\$50' 'wrap-sensitive board zero-page base changed'
Require-Text $source 'COUNT\s+EQU\s+\$DE\s+BCAP2\s+EQU\s+\$DE' 'counter aliases changed'
Require-Text $source 'CALLER_SP\s+EQU\s+\$1B00' 'AP caller stack slot changed'
Require-Text $source 'DONE:\s+LDX\s+CALLER_SP\s+TXS\s+LDA\s+#\$AC\s+SEC\s+RTS' 'AP return sequence changed'
Require-Text $source 'CHESS:\s+CLD\s+LDX\s+CALLER_SP\s+TXS\s+; preserve AP return frame\s+TXA\s+SEC\s+SBC\s+#\$37\s+; original \$FF/\$C8 separation\s+STA\s+SP2' 'per-command two-stack reset changed'
Require-Text $source 'STY\s+BOARD,X\s+; FROM' 'original zero-page indexed board move changed'

if ($source -match '\$7F7[0-3]') { throw 'direct 6551 register access returned to the AP source' }
if ($source -match 'LDX\s+#\$FF\s*; TWO STACKS') { throw 'KIM-only stack reset would destroy the AP return frame' }

$entry = Get-MapAddress $map 'MICROCHESS'
$engineEnd = Get-MapAddress $map 'MICROCHESS_ENGINE_END'
$linkedEnd = Get-MapAddress $map '_END_CODE'
if ($entry -ne 0x2000) { throw ('MICROCHESS moved from $2000 to ${0:X4}' -f $entry) }
if ($engineEnd -le $entry -or $engineEnd -gt $linkedEnd) { throw 'engine/link boundary is invalid' }
if ($linkedEnd -gt 0x3000) { throw ('linked AP body crosses $3000: ${0:X4}' -f $linkedEnd) }

if ($package.Length -lt 8 -or $package[0] -ne 0x41 -or $package[1] -ne 0x50 -or $package[2] -ne 0x02) {
    throw 'not an AP-v2 package'
}
$declaredLength = [int]$package[3] + ([int]$package[4] -shl 8)
if ($declaredLength -ne $package.Length) { throw 'AP package length field does not match the file' }
if ($package.Length -gt 0x1000) { throw 'Microchess AP does not fit one carrier sector' }

$expectedTags = @([byte][char]'S', [byte][char]'R', [byte][char]'E', [byte][char]'I', [byte][char]'B')
$offset = 5
$bodyLength = -1
$sectionPayloads = @{}
foreach ($tag in $expectedTags) {
    if ($offset + 3 -gt $package.Length -or $package[$offset] -ne $tag) {
        throw ('missing AP section {0} at offset ${1:X4}' -f [char]$tag, $offset)
    }
    $sectionLength = [int]$package[$offset + 1] + ([int]$package[$offset + 2] -shl 8)
    $sectionPayloads[([char]$tag).ToString()] = [pscustomobject]@{ Start = $offset + 3; Length = $sectionLength }
    if ($tag -eq [byte][char]'B') { $bodyLength = $sectionLength }
    $offset += 3 + $sectionLength
}
if ($offset -ne $package.Length) { throw 'AP sections do not consume the exact package' }
if ($bodyLength -ne ($linkedEnd - $entry)) { throw 'BODY length does not reach the linked service end' }

$rel = $sectionPayloads['R']
$expectedSites = @(
    ((Get-MapAddress $map 'MICROCHESS_IMP_READ') - $entry)
    ((Get-MapAddress $map 'MICROCHESS_IMP_WRITE_CHAR') - $entry)
    ((Get-MapAddress $map 'MICROCHESS_IMP_WRITE_HEX') - $entry)
)
if ($rel.Length -ne 16 -or $package[$rel.Start] -ne 3) { throw 'expected three ABS16 import relocation rows' }
for ($i = 0; $i -lt 3; $i++) {
    $columns = $rel.Start + 1
    $site = [int]$package[$columns + 3 + $i] +
        ([int]$package[$columns + 6 + $i] -shl 8)
    if ($package[$columns + $i] -ne 4 -or $site -ne $expectedSites[$i] -or
        $package[$columns + 9 + $i] -ne $i -or
        $package[$columns + 12 + $i] -ne 0) {
        throw "bad import relocation row $i"
    }
}

$imp = $sectionPayloads['I']
$expectedImports = @('BIO_FTDI_READ_BYTE_BLOCK', 'BIO_FTDI_WRITE_BYTE_BLOCK', 'SYS_WRITE_HEX_BYTE')
if ($package[$imp.Start] -ne $expectedImports.Count) { throw 'expected three import records' }
$alphabet = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?.'
$cursor = $imp.Start + 1
for ($i = 0; $i -lt $expectedImports.Count; $i++) {
    if ($package[$cursor] -ne 1) { throw "import $i is not EXEC" }
    $nameLength = [int]$package[$cursor + 5]
    $packedLength = 2 * [Math]::Ceiling($nameLength / 3.0)
    $decoded = [System.Text.StringBuilder]::new()
    for ($packed = 0; $packed -lt $packedLength; $packed += 2) {
        $value = [int]$package[$cursor + 6 + $packed] + ([int]$package[$cursor + 7 + $packed] -shl 8)
        foreach ($code in @([Math]::Floor($value / 1600), [Math]::Floor(($value % 1600) / 40), ($value % 40))) {
            [void]$decoded.Append($alphabet[[int]$code])
        }
    }
    $name = $decoded.ToString().Substring(0, $nameLength)
    if ($name -ne $expectedImports[$i]) { throw "unexpected import $i '$name'" }
    $cursor += 6 + $packedLength
}
if ($cursor -ne ($imp.Start + $imp.Length)) { throw 'import section length mismatch' }

Write-Host ('Microchess AP check passed: engine=${0:X4}-${1:X4}, linked end=${2:X4}, body={3}, package={4}' -f $entry, $engineEnd, $linkedEnd, $bodyLength, $package.Length)

$srcDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$runtimeCheck = Join-Path $srcDir 'tools\check_microchess_runtime.py'
$py65Root = Join-Path $srcDir 'BUILD\tmp\asm-error-deps'
if (-not (Test-Path -LiteralPath (Join-Path $py65Root 'py65'))) {
    throw 'py65 dependency missing; follow DOC/GUIDES/ASM/TEST_PLAN.md setup'
}
& python $runtimeCheck --package $PackagePath --map $MapPath --py65-root $py65Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

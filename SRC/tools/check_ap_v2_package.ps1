param(
    [string]$PackagePath = "BUILD/bin/asm-session-report-v1.2-4800.ap.bin",
    [string]$AsmSourcePath = "ASM/asm-v1-core.asm",
    [string]$AsmFlashSourcePath = "ASM/asm-v1-flash.asm",
    [string]$RuntimePasteSourcePath = "PROOFS/asm-v1-runtime-paste.asm",
    [string]$HimonSourcePath = "HIMON/himon.asm",
    [string]$Reloc64CardPath = "../DOC/GUIDES/ASM/SAMPLES/apv2-reloc64-2000.a",
    [string]$Export64CardPath = "../DOC/GUIDES/ASM/SAMPLES/apv2-export64-2000.a",
    [string]$Import64CardPath = "../DOC/GUIDES/ASM/SAMPLES/apv2-import64-2000.a"
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw "AP v2 check: $Message" }

function Read-Equ([string]$Text, [string]$Name) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s+EQU\s+\$([0-9A-Fa-f]+)'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { Fail "missing $Name" }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

function U16([byte[]]$Bytes, [int]$Offset) {
    if ($Offset -lt 0 -or ($Offset + 1) -ge $Bytes.Length) { Fail 'truncated word' }
    $lo = [int]$Bytes.GetValue($Offset)
    $hi = [int]$Bytes.GetValue($Offset + 1)
    return [int]($lo -bor ($hi -shl 8))
}

function U32([byte[]]$Bytes, [int]$Offset) {
    if ($Offset -lt 0 -or ($Offset + 3) -ge $Bytes.Length) { Fail 'truncated dword' }
    return [uint32](([uint64]$Bytes[$Offset]) -bor
        ([uint64]$Bytes[$Offset + 1] -shl 8) -bor
        ([uint64]$Bytes[$Offset + 2] -shl 16) -bor
        ([uint64]$Bytes[$Offset + 3] -shl 24))
}

function Fnv32([byte[]]$Bytes) {
    $hash = [uint64]2166136261
    foreach ($byte in $Bytes) {
        $hash = (($hash -bxor [uint64]$byte) * [uint64]16777619) -band [uint64]4294967295
    }
    return [uint32]$hash
}

function Read-Section([byte[]]$Bytes, [ref]$Cursor, [char]$Tag) {
    if (($Cursor.Value + 3) -gt $Bytes.Length) { Fail "truncated $Tag header" }
    if ($Bytes[$Cursor.Value] -ne [byte][char]$Tag) { Fail "expected $Tag section" }
    $length = U16 $Bytes ($Cursor.Value + 1)
    $start = $Cursor.Value + 3
    if (($start + $length) -gt $Bytes.Length) { Fail "$Tag payload exceeds package" }
    $Cursor.Value = $start + $length
    return [pscustomobject]@{ Start = $start; Length = $length }
}

function Decode-Pack40Name([byte[]]$Bytes, [int]$Offset, [int]$NameLength) {
    $alphabet = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?."
    $packedLength = 2 * [Math]::Ceiling($NameLength / 3.0)
    if (($Offset + $packedLength) -gt $Bytes.Length) { Fail 'truncated PACK40 name' }
    $builder = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $packedLength; $i += 2) {
        $value = [int](U16 $Bytes ($Offset + $i))
        $code0 = [int][Math]::Floor($value / 1600.0)
        $remainder = $value - ($code0 * 1600)
        $code1 = [int][Math]::Floor($remainder / 40.0)
        $code2 = $remainder - ($code1 * 40)
        $codes = @($code0, $code1, $code2)
        foreach ($code in $codes) {
            if ($code -lt 0 -or $code -ge 40) { Fail 'invalid PACK40 code' }
            [void]$builder.Append($alphabet[$code])
        }
    }
    $decoded = $builder.ToString()
    if ($decoded.Length -lt $NameLength) { Fail 'short PACK40 name' }
    if ($decoded.Substring($NameLength).Trim(' ').Length -ne 0) { Fail 'nonzero PACK40 padding' }
    return $decoded.Substring(0, $NameLength)
}

function Check-PublicSection(
    [byte[]]$Bytes, [int]$Start, [int]$Length, [bool]$Export
) {
    if ($Length -lt 1) { Fail 'empty public section' }
    $end = $Start + $Length
    $count = [int]$Bytes[$Start]
    if ($count -gt 64) { Fail "public count $count exceeds 64" }
    $cursor = $Start + 1
    $entries = 0
    for ($row = 0; $row -lt $count; $row++) {
        $fixed = if ($Export) { 8 } else { 6 }
        if (($cursor + $fixed) -gt $end) { Fail "public row $row is truncated" }
        $kind = [int]$Bytes[$cursor]
        $allowed = if ($Export) { 0x83 } else { 0x03 }
        if (($kind -band $allowed) -ne $kind) { Fail "public row $row has unknown flags" }
        $baseKind = $kind -band 0x03
        if ($baseKind -ne 1 -and $baseKind -ne 2) { Fail "public row $row has invalid kind" }
        if (($kind -band 0x80) -ne 0) {
            if (-not $Export -or $baseKind -ne 1) { Fail "public row $row has invalid ENTRY" }
            $entries++
            if ($entries -gt 1) { Fail 'multiple ENTRY exports' }
        }
        $hashOffset = if ($Export) { $cursor + 3 } else { $cursor + 1 }
        $nameLengthOffset = if ($Export) { $cursor + 7 } else { $cursor + 5 }
        $nameLength = [int]$Bytes[$nameLengthOffset]
        if ($nameLength -lt 1 -or $nameLength -gt 31) { Fail "public row $row has invalid name length" }
        $packedLength = 2 * [Math]::Ceiling($nameLength / 3.0)
        if (($cursor + $fixed + $packedLength) -gt $end) { Fail "public row $row name exceeds section" }
        $name = Decode-Pack40Name $Bytes ($cursor + $fixed) $nameLength
        $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($name)
        $expectedHash = Fnv32 $nameBytes
        $storedHash = U32 $Bytes $hashOffset
        if ($storedHash -ne $expectedHash) { Fail "public row $row hash/name mismatch" }
        $cursor += $fixed + $packedLength
    }
    if ($cursor -ne $end) { Fail 'public section has trailing or missing bytes' }
    return $count
}

foreach ($path in @($PackagePath, $AsmSourcePath, $AsmFlashSourcePath,
        $RuntimePasteSourcePath, $HimonSourcePath,
        $Reloc64CardPath, $Export64CardPath, $Import64CardPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "missing input $path" }
}

function Read-CardCode([string]$Path) {
    return (([System.IO.File]::ReadAllLines((Resolve-Path $Path)) |
        ForEach-Object { ($_ -split ';', 2)[0].Trim().ToUpperInvariant() } |
        Where-Object { $_ -ne '' }) -join "`n")
}

$reloc64Card = Read-CardCode $Reloc64CardPath
$export64Card = Read-CardCode $Export64CardPath
$import64Card = Read-CardCode $Import64CardPath
foreach ($card in @($reloc64Card, $export64Card, $import64Card)) {
    if ($card -match '\$7[0-7][0-9A-F]{2}') {
        Fail 'APv2 capacity card writes inside the $7000-$771C reporter image'
    }
}
foreach ($sentinel in @(
    @($reloc64Card, 'STA $7900'),
    @($export64Card, 'STA $7901'),
    @($import64Card, 'STA $7902')
)) {
    if (-not $sentinel[0].Contains($sentinel[1])) {
        Fail "capacity card is missing $($sentinel[1])"
    }
}
$importDecls = [regex]::Matches(
    $import64Card, '(?m)^IMPORT\s+(I[0-9]{2})$'
)
$importUses = [regex]::Matches(
    $import64Card, '(?m)^DW\s+([^\r\n]+)$'
) | ForEach-Object {
    [regex]::Matches($_.Groups[1].Value, '\bI[0-9]{2}\b') |
        ForEach-Object { $_.Value }
}
$expectedImports = 0..63 | ForEach-Object { 'I{0:D2}' -f $_ }
if ($importDecls.Count -ne 64 -or $importUses.Count -ne 64) {
    Fail "64-import card has $($importDecls.Count) declarations and $($importUses.Count) relocation uses"
}
for ($i = 0; $i -lt 64; $i++) {
    if ($importDecls[$i].Groups[1].Value -ne $expectedImports[$i] -or
            $importUses[$i] -ne $expectedImports[$i]) {
        Fail "64-import card row $i does not declare and use $($expectedImports[$i])"
    }
}

$asmText = [System.IO.File]::ReadAllText((Resolve-Path $AsmSourcePath))
$asmFlashText = [System.IO.File]::ReadAllText((Resolve-Path $AsmFlashSourcePath))
$runtimePasteText = [System.IO.File]::ReadAllText((Resolve-Path $RuntimePasteSourcePath))
$himonText = [System.IO.File]::ReadAllText((Resolve-Path $HimonSourcePath))
foreach ($check in @(
    @($asmText, 'ASM_PACKAGE_VERSION', 2),
    @($asmText, 'ASM_RELOC_MAX', 64),
    @($asmText, 'ASM_EXPORT_MAX', 64),
    @($asmText, 'ASM_IMPORT_MAX', 64),
    @($asmText, 'ASM_SYM_MAX', 128),
    @($asmText, 'ASM_SYM_NAME_POOL_BYTES', 2048),
    @($himonText, 'HIM_AP_VERSION', 2),
    @($himonText, 'HIM_AP_RELOC_MAX', 64),
    @($himonText, 'HIM_AP_PUBLIC_MAX', 64)
)) {
    $actual = Read-Equ $check[0] $check[1]
    if ($actual -ne $check[2]) { Fail "$($check[1])=$actual, expected $($check[2])" }
}
foreach ($required in @('ASM_SYM_NAME_OFF_LO', 'ASM_SYM_NAME_OFF_HI',
        'ASM_LINE_SYM_NAME_USED_LO', 'ASM_LINE_SYM_NAME_USED_HI')) {
    if (-not $asmText.Contains($required)) { Fail "missing symbol-pool guard $required" }
}

# Post-END numeric operands are HIMON-style bare hex without changing normal
# ASM source numbers. Keep both interactive wrappers on the dedicated parser,
# and keep executable smoke fixtures for digit- and letter-leading addresses.
foreach ($required in @('XDEF            ASM_PARSE_SEAL_EXPR',
        'ASM_NEXT_TOKEN_BARE_HEX:', 'ASM_NEXT_TOKEN_HEX_COMMON:',
        'DB              "3200",0',
        'DB              "BABB",0')) {
    if (-not $asmText.Contains($required)) { Fail "missing SEAL hex parser rail $required" }
}
$sharedHexInit = 'ASM_NEXT_TOKEN_HEX:\s+JSR\s+ASM_ADV_PARSE\s+BRA\s+ASM_NEXT_TOKEN_HEX_COMMON\s+ASM_NEXT_TOKEN_BARE_HEX:\s+ASM_NEXT_TOKEN_HEX_COMMON:.*?LDA\s+#\$01\s+STA\s+ASM_LEN\s+JSR\s+ASM_ZERO_VALUE\s+ASM_NEXT_HEX_LOOP:'
if (-not [regex]::IsMatch($asmText, $sharedHexInit,
        [Text.RegularExpressions.RegexOptions]::Singleline)) {
    Fail 'prefixed and bare hex must share the virtual-prefix length initialization'
}
if (([regex]::Matches($asmFlashText, 'JSR\s+ASM_PARSE_SEAL_EXPR')).Count -ne 3) {
    Fail 'flash wrapper must route all three operand parses through bare-hex mode'
}
if (([regex]::Matches($runtimePasteText, 'JSR\s+ASM_PARSE_SEAL_EXPR')).Count -ne 1) {
    Fail 'runtime-paste RELOCATE must use bare-hex mode'
}

# ASMF_PARSE_TWO_ARGS retains its first-token pointer while ASM_PARSE_EXPR may
# perform a symbol lookup.  Keep that wrapper-private pair outside the ASM core
# zero-page frame ($84-$AF), especially ASM_SYM_PTR at $84/$85.
$wrapperPtrLo = Read-Equ $asmFlashText 'ASMF_CMD_PTR_LO'
$wrapperPtrHi = Read-Equ $asmFlashText 'ASMF_CMD_PTR_HI'
if ($wrapperPtrHi -ne ($wrapperPtrLo + 1)) {
    Fail 'ASMF command pointer is not a contiguous zero-page pair'
}
if (($wrapperPtrLo -ge 0x84 -and $wrapperPtrLo -le 0xAF) -or
        ($wrapperPtrHi -ge 0x84 -and $wrapperPtrHi -le 0xAF)) {
    Fail ('ASMF command pointer ${0:X2}-${1:X2} overlaps the ASM core zero-page frame' -f
        $wrapperPtrLo, $wrapperPtrHi)
}

[byte[]]$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $PackagePath))
if ($bytes.Length -lt 31 -or $bytes.Length -gt 4096) { Fail 'package length is outside AP bounds' }
if ($bytes[0] -ne [byte][char]'A' -or $bytes[1] -ne [byte][char]'P') { Fail 'bad signature' }
if ($bytes[2] -ne 2) { Fail 'AP v1 is retired; version must be 2' }
if ((U16 $bytes 3) -ne $bytes.Length) { Fail 'header total length mismatch' }

$cursor = 5
$seal = Read-Section $bytes ([ref]$cursor) 'S'
if ($seal.Length -ne 11 -or $bytes[$seal.Start] -ne 1) { Fail 'invalid seal section' }
$sealedBase = U16 $bytes ($seal.Start + 1)
$sealedEnd = U16 $bytes ($seal.Start + 3)
$sealedLength = U16 $bytes ($seal.Start + 5)
if ((($sealedBase + $sealedLength) -band 0xFFFF) -ne $sealedEnd) { Fail 'seal base/end/length mismatch' }
$sealedHash = U32 $bytes ($seal.Start + 7)

$rel = Read-Section $bytes ([ref]$cursor) 'R'
if ($rel.Length -lt 1) { Fail 'empty relocation section' }
$relCount = [int]$bytes[$rel.Start]
if ($relCount -gt 64 -or $rel.Length -ne (1 + (5 * $relCount))) { Fail 'relocation count/length mismatch' }
$exp = Read-Section $bytes ([ref]$cursor) 'E'
$exportCount = Check-PublicSection $bytes $exp.Start $exp.Length $true
$imp = Read-Section $bytes ([ref]$cursor) 'I'
$importCount = Check-PublicSection $bytes $imp.Start $imp.Length $false
$body = Read-Section $bytes ([ref]$cursor) 'B'
if ($cursor -ne $bytes.Length -or $body.Length -lt 1 -or $body.Length -ne $sealedLength) { Fail 'BODY length mismatch' }
[byte[]]$bodyBytes = $bytes[$body.Start..($body.Start + $body.Length - 1)]
if ((Fnv32 $bodyBytes) -ne $sealedHash) { Fail 'BODY FNV mismatch' }

Write-Host ((('AP v2 check OK len=${0:X4} body=${1:X4} rel={2}/64 ' +
    'exp={3}/64 imp={4}/64 syms=128 pool=${5:X4} card-import-uses=64 ' +
    'sentinels=$7900-$7902 wrapper-zp=${6:X2}-${7:X2}') -f $bytes.Length,
    $body.Length, $relCount, $exportCount, $importCount, 2048, $wrapperPtrLo,
    $wrapperPtrHi))

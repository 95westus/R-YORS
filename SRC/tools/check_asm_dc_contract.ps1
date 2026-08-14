param(
    [string]$AsmSourcePath = "ASM/asm-v1-core.asm"
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "ASM compact DC contract: $Message"
}

function Emit-CompactDc([string]$Source) {
    $match = [regex]::Match(
        $Source,
        "^\s*DC\s*(?:(?<mode>[CHPchp])\s*)?'(?<text>[^']*)'\s*(?:;.*)?$"
    )
    if ($match.Success) {
        $mode = $match.Groups['mode'].Value.ToUpperInvariant()
    } else {
        $match = [regex]::Match(
            $Source,
            '^\s*DC\s+(?<mode>C|HB|P)\s*,\s*"(?<text>[^"]*)"\s*(?:;.*)?$',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        if (-not $match.Success) { Fail "BAD_OPER: $Source" }
        $mode = $match.Groups['mode'].Value.ToUpperInvariant()
        if ($mode -eq 'HB') { $mode = 'H' }
    }
    $chars = [System.Text.Encoding]::ASCII.GetBytes($match.Groups['text'].Value)
    $maxLength = if ($mode -eq 'C' -or $mode -eq 'P') { 254 } else { 255 }
    if ($chars.Length -gt $maxLength) { Fail "BAD_RANGE: $Source" }

    $bytes = New-Object System.Collections.Generic.List[byte]
    if ($mode -eq 'P') { $bytes.Add([byte]$chars.Length) }
    foreach ($char in $chars) { $bytes.Add($char) }
    if ($mode -eq 'C') {
        $bytes.Add([byte]0)
    } elseif ($mode -eq 'H') {
        if ($bytes.Count -eq 0) {
            $bytes.Add([byte]0x80)
        } else {
            $bytes[$bytes.Count - 1] = [byte]($bytes[$bytes.Count - 1] -bor 0x80)
        }
    }
    return [byte[]]$bytes.ToArray()
}

function Assert-Bytes([string]$Source, [byte[]]$Expected) {
    $actual = Emit-CompactDc $Source
    if (($actual -join ',') -ne ($Expected -join ',')) {
        Fail "byte mismatch for $Source; got $($actual -join ',')"
    }
}

function Assert-Fails([string]$Source, [string]$Status) {
    try {
        [void](Emit-CompactDc $Source)
    } catch {
        if ($_.Exception.Message -notmatch [regex]::Escape($Status)) { throw }
        return
    }
    Fail "expected ${Status}: $Source"
}

$success = @(
    @{ Source = "DC 'OK'"; Bytes = [byte[]](0x4F, 0x4B) },
    @{ Source = "DC C'OK'"; Bytes = [byte[]](0x4F, 0x4B, 0x00) },
    @{ Source = "DC H'OK'"; Bytes = [byte[]](0x4F, 0xCB) },
    @{ Source = "DC P'OK'"; Bytes = [byte[]](0x02, 0x4F, 0x4B) },
    @{ Source = " DC '' ; empty raw"; Bytes = [byte[]]@() },
    @{ Source = "DC C''"; Bytes = [byte[]](0x00) },
    @{ Source = "DC H''"; Bytes = [byte[]](0x80) },
    @{ Source = "DC P''"; Bytes = [byte[]](0x00) },
    @{ Source = 'DC C,"OK"'; Bytes = [byte[]](0x4F, 0x4B, 0x00) },
    @{ Source = 'DC HB,"OK"'; Bytes = [byte[]](0x4F, 0xCB) },
    @{ Source = 'DC P,"OK"'; Bytes = [byte[]](0x02, 0x4F, 0x4B) }
)
foreach ($case in $success) { Assert-Bytes $case.Source $case.Bytes }

$raw255 = 'A' * 255
$typed254 = 'A' * 254
Assert-Bytes "DC '$raw255'" ([byte[]]([System.Text.Encoding]::ASCII.GetBytes($raw255)))
$hb255 = [System.Text.Encoding]::ASCII.GetBytes($raw255)
$hb255[254] = [byte]($hb255[254] -bor 0x80)
Assert-Bytes "DC H'$raw255'" ([byte[]]$hb255)
$typed254Bytes = [System.Text.Encoding]::ASCII.GetBytes($typed254)
Assert-Bytes "DC C'$typed254'" ([byte[]]($typed254Bytes + [byte]0))
Assert-Bytes "DC P'$typed254'" ([byte[]](@([byte]254) + $typed254Bytes))

$failures = @(
    @{ Source = "DC 'NO"; Status = 'BAD_OPER' },
    @{ Source = "DC 'IT''S'"; Status = 'BAD_OPER' },
    @{ Source = "DC X'NO'"; Status = 'BAD_OPER' },
    @{ Source = 'DC "NO"'; Status = 'BAD_OPER' },
    @{ Source = "DC '$('A' * 256)'"; Status = 'BAD_RANGE' },
    @{ Source = "DC H'$('A' * 256)'"; Status = 'BAD_RANGE' },
    @{ Source = "DC C'$('A' * 255)'"; Status = 'BAD_RANGE' },
    @{ Source = "DC P'$('A' * 255)'"; Status = 'BAD_RANGE' }
)
foreach ($case in $failures) { Assert-Fails $case.Source $case.Status }

if (-not (Test-Path -LiteralPath $AsmSourcePath)) {
    Fail "source not found: $AsmSourcePath"
}
$asm = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $AsmSourcePath))
foreach ($required in @(
    'ASM_DCM_RAW',
    'CMP             ASM_DELIM',
    'ASM_EMIT_DC_HEAD_C',
    'ASM_EMIT_DC_HEAD_H',
    'ASM_DIRECT_DC_COMPACT_EXPECT',
    'ASM_DIRECT_DC_RAW_255',
    'ASM_DIRECT_DC_RAW_256',
    'ASM_DIRECT_LDA_CHAR'
)) {
    if (-not $asm.Contains($required)) { Fail "missing core proof marker: $required" }
}
if ($asm -match '(?m)^ASM_VID_(?:CSTR|HBSTR|PSTR)\b') {
    Fail 'compact forms must not consume vocabulary IDs'
}
$parseHead = [regex]::Match(
    $asm,
    '(?ms)^ASM_EMIT_DC_PARSE_HEAD:.*?(?=^ASM_EMIT_DC_BAD_OPER:)'
)
if (-not $parseHead.Success) { Fail 'missing DC parse-head block' }
if ($parseHead.Value -match 'JSR\s+ASM_NEXT_TOKEN') {
    Fail 'typed compact modes must bypass the general lexer apostrophe boundary'
}

Write-Host ("ASM compact DC contract OK: success={0} failure={1} boundaries=4" -f $success.Count, $failures.Count)

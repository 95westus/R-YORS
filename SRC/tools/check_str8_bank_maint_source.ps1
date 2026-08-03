param(
    [string]$SourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a",
    [string]$BuildDir = "BUILD/tmp/str8-bank-maint-check",
    [string]$Assembler = "wdc02as"
)

$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "STR8 bank-maint source check: $Message"
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    Fail-Check "missing source $SourcePath"
}

$lines = [System.IO.File]::ReadAllLines(
    (Resolve-Path -LiteralPath $SourcePath).Path
)
$symbols = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$localCount = 0
$maxLocalCount = 0
$currentScope = ''

for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $lineNumber = $index + 1
    $trimmed = $line.TrimStart()
    $code = ($line -split ';', 2)[0]

    if (-not $trimmed.StartsWith(';') -and $line.Length -gt 63) {
        Fail-Check "line $lineNumber exceeds 63 characters"
    }
    if ($code -match '^\s*(IMPORT|ENTRY)\b') {
        Fail-Check "line $lineNumber uses package-only $($matches[1])"
    }
    if ($code -match '\b[A-Za-z_][A-Za-z0-9_]*\s*\+\s*[0-9]') {
        Fail-Check "line $lineNumber uses unsupported symbol addend"
    }
    if ($code -match '^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
        [void]$symbols.Add($matches[1])
        $currentScope = $matches[1]
        $localCount = 0
    }
    if ($code -match '^([.?][A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
        if ([string]::IsNullOrEmpty($currentScope)) {
            Fail-Check "line $lineNumber has a local with no global scope"
        }
        if ($matches[1].Length -gt 15) {
            Fail-Check "line $lineNumber local name exceeds 15 characters"
        }
        $localCount++
        $maxLocalCount = [Math]::Max($maxLocalCount, $localCount)
        if ($localCount -gt 16) {
            Fail-Check "scope $currentScope exceeds 16 local labels"
        }
    }
}

if ($symbols.Count -gt 64) {
    Fail-Check "defines $($symbols.Count) symbols; ASM-F2 limit is 64"
}

$sourceText = $lines -join "`n"
$required = @(
    'STR8_SERVICE EQU $F003',
    'HIM_WRITE_BYTE EQU $7E08',
    'HIM_WRITE_CSTR EQU $7E0A',
    'HIM_READ_CSTR EQU $7E10',
    'LDA #$06',
    'LDA #$05',
    'CMP #$F0',
    'LDA #$08',
    'DEC $1B05',
    "CMP #'M'",
    "CMP #'Q'",
    'JMP $F000',
    'SEI'
)
foreach ($text in $required) {
    if (-not $sourceText.Contains($text)) {
        Fail-Check "missing maintenance gate: $text"
    }
}

$semanticGates = @(
    @{
        Name = 'copy destination rejects Bank 3'
        Pattern = 'BM_CDST.*?CMP #\$03.*?BCS BM_CDST'
    },
    @{
        Name = 'Bank 3 rejects sector F'
        Pattern = 'BM_EHEX.*?CMP #\$F0.*?BEQ BM_ECHECKF.*?CPX #\$03.*?BEQ BM_EBAD'
    },
    @{
        Name = 'Bank 3 all count is seven sectors'
        Pattern = 'BM_EALL.*?LDA #\$08.*?CMP #\$03.*?DEC \$1B05'
    },
    @{
        Name = 'Bank 3 skips post-erase dot output'
        Pattern = 'BM_ELOOP.*?CMP #\$03.*?BEQ BM_ENODOT.*?JSR BM_OUT'
    },
    @{
        Name = 'ALL uses the complete valid range'
        Pattern = 'BM_EALL.*?LDA #''A''.*?STA \$1B08.*?LDA #''L''.*?STA \$1B09.*?STA \$1B0A'
    },
    @{
        Name = 'X-Y validates and counts an ordered range'
        Pattern = 'BM_ENOTALL.*?CMP #''-''.*?LDA \$1C02.*?JSR BM_EHEX.*?CMP \$1B04.*?SBC \$1B04'
    },
    @{
        Name = 'single-sector path reaches confirmation'
        Pattern = 'BM_ESINGLE.*?STA \$1B0B.*?JMP BM_ECONF.*?BM_EHEX'
    },
    @{
        Name = 'M scans every bank sector through stage mode'
        Pattern = 'BM_MAP.*?STZ \$1B02.*?\?BANK.*?LDA #\$80.*?\?SECTOR.*?JSR BM_STAGE.*?CMP #\$FF'
    },
    @{
        Name = 'map restores entry bank with interrupts masked'
        Pattern = 'BM_MAIN.*?LDA \$7FEC.*?AND #\$EE.*?STA \$1B0C.*?BM_MAP.*?\?STAGE\s+PHP.*?SEI.*?JSR BM_STAGE.*?LDA #\$EE.*?TRB \$7FEC.*?LDA \$1B0C.*?TSB \$7FEC.*?PLP.*?\?SCAN'
    },
    @{
        Name = 'map protects and identifies Bank-3 sector F'
        Pattern = 'BM_MAP.*?CMP #\$03.*?CMP #\$F0.*?LDA #''P''.*?LDA #''E''.*?LDA #''U'''
    },
    @{
        Name = 'normal outcomes loop until Q'
        Pattern = 'BM_FAIL.*?JMP BM_MAIN.*?BM_SUCCESS.*?JMP BM_MAIN'
    }
)
foreach ($gate in $semanticGates) {
    if (-not [regex]::IsMatch(
        $sourceText,
        $gate.Pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )) {
        Fail-Check "missing semantic gate: $($gate.Name)"
    }
}

$assemblerCommand = Get-Command $Assembler -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
$testSource = Join-Path $BuildDir 'str8-bank-maint-2000.asm'
[System.IO.File]::WriteAllLines(
    $testSource,
    $lines,
    [System.Text.Encoding]::ASCII
)

& $assemblerCommand.Source -G -L -S -W $testSource
if ($LASTEXITCODE -ne 0) {
    Fail-Check "WDC assembler exited $LASTEXITCODE"
}

Write-Host (
    "STR8 BANK MAINT SOURCE = PASS; symbols={0}/64; locals-max={1}/16; B3 F protected; map restores entry bank" -f `
        $symbols.Count, $maxLocalCount
)

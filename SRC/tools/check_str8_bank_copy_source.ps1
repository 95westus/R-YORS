param(
    [string]$SourcePath = "../DOC/GUIDES/ASM/SAMPLES/str8-bank-copy-2000.a",
    [string]$BuildDir = "BUILD/tmp/str8-bank-copy-check",
    [string]$Assembler = "wdc02as"
)

$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "STR8 bank-copy source check: $Message"
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
    }
}

if ($symbols.Count -gt 64) {
    Fail-Check "defines $($symbols.Count) symbols; ASM-F2 limit is 64"
}

$sourceText = $lines -join "`n"
$required = @(
    'HIM_WRITE_BYTE EQU $7E08',
    'HIM_WRITE_CSTR EQU $7E0A',
    'HIM_READ_CSTR EQU $7E10'
)
foreach ($text in $required) {
    if (-not $sourceText.Contains($text)) {
        Fail-Check "missing published service binding: $text"
    }
}

$assemblerCommand = Get-Command $Assembler -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
$testSource = Join-Path $BuildDir 'str8-bank-copy-2000.asm'
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
    "STR8 BANK COPY SOURCE = PASS; symbols={0}/64 direct HIMON vectors" -f `
        $symbols.Count
)

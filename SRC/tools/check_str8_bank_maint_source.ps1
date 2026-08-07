param(
    [string]$SourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a",
    [string]$MutationWorkerS19Path = `
        "BUILD/s19/str8-mutation-worker-0200.s19",
    [string]$BuildDir = "BUILD/tmp/str8-bank-maint-check",
    [string]$Assembler = "wdc02as"
)

$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "STR8 bank-maint source check: $Message"
}

function Read-S19Memory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Check "missing mutation worker $Path"
    }
    [byte[]]$memory = New-Object byte[] 65536
    [bool[]]$seen = New-Object bool[] 65536
    foreach ($rawLine in [System.IO.File]::ReadAllLines(
        (Resolve-Path -LiteralPath $Path).Path
    )) {
        $line = $rawLine.Trim()
        if (-not $line.StartsWith('S1')) {
            continue
        }
        if ($line -notmatch '^S1[0-9A-Fa-f]+$') {
            Fail-Check 'malformed mutation-worker S1 record'
        }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        if ($line.Length -ne (4 + (2 * $count))) {
            Fail-Check 'mutation-worker S1 length mismatch'
        }
        $sum = $count
        for ($index = 0; $index -lt $count; $index++) {
            $sum += [Convert]::ToInt32(
                $line.Substring(4 + (2 * $index), 2),
                16
            )
        }
        if (($sum -band 0xFF) -ne 0xFF) {
            Fail-Check 'mutation-worker S1 checksum mismatch'
        }
        $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
        $dataLength = $count - 3
        for ($index = 0; $index -lt $dataLength; $index++) {
            $target = $address + $index
            if ($seen[$target]) {
                Fail-Check ('duplicate mutation byte at ${0:X4}' -f $target)
            }
            $memory[$target] = [Convert]::ToByte(
                $line.Substring(8 + (2 * $index), 2),
                16
            )
            $seen[$target] = $true
        }
    }
    for ($address = 0x0200; $address -le 0x042A; $address++) {
        if (-not $seen[$address]) {
            Fail-Check ('missing mutation byte at ${0:X4}' -f $address)
        }
    }
    return $memory
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
$globalDefinitions = [System.Collections.Generic.Dictionary[string,int]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$localDefinitions = [System.Collections.Generic.Dictionary[string,int]]::new(
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
        $globalDefinitions[$currentScope] = $index
        $localCount = 0
    }
    if ($code -match '^([.?][A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
        if ([string]::IsNullOrEmpty($currentScope)) {
            Fail-Check "line $lineNumber has a local with no global scope"
        }
        if ($matches[1].Length -gt 15) {
            Fail-Check "line $lineNumber local name exceeds 15 characters"
        }
        $localKey = $currentScope + '|' + $matches[1]
        $localDefinitions[$localKey] = $index
        $localCount++
        $maxLocalCount = [Math]::Max($maxLocalCount, $localCount)
        if ($localCount -gt 16) {
            Fail-Check "scope $currentScope exceeds 16 local labels"
        }
    }
    if ($code -match '#[<>]\$') {
        Fail-Check (
            "line $lineNumber uses ASM-F2-invalid numeric byte selector"
        )
    }
}

if ($symbols.Count -gt 64) {
    Fail-Check "defines $($symbols.Count) symbols; ASM-F2 limit is 64"
}

$sourceText = $lines -join "`n"
$required = @(
    'HIM_WRITE_BYTE EQU $7E08',
    'HIM_WRITE_CSTR EQU $7E0A',
    'HIM_READ_CSTR EQU $7E10',
    'LDA $3000,X',
    'STA $0200,X',
    'LDA $3200,X',
    'STA $0400,X',
    'LDA #$06',
    'LDA #$05',
    'JMP $0200',
    'CMP #$F0',
    'LDA #$08',
    'DEC $1B05',
    "CMP #'M'",
    "CMP #'Q'",
    'JSR BM_DIR',
    'LDA $FFB0,X',
    'STA $1D00,X',
    'BM_MDIR DB',
    'BM_MLEGEND DB',
    'ORG $3000',
    'JMP $F000',
    'SEI'
)
foreach ($text in $required) {
    if (-not $sourceText.Contains($text)) {
        Fail-Check "missing maintenance gate: $text"
    }
}

$codeText = ($lines | ForEach-Object {
    ($_ -split ';', 2)[0]
}) -join "`n"
if ($codeText.Contains('$F003')) {
    Fail-Check 'source still depends on the split-V1 $F003 doorway'
}

$forwardFixups = 0
$currentScope = ''
for ($index = 0; $index -lt $lines.Count; $index++) {
    $statement = ($lines[$index] -split ';', 2)[0]
    if ($statement -match '^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
        $currentScope = $matches[1]
        $statement = $statement.Substring($matches[0].Length)
    } elseif ($statement -match '^([.?][A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
        $statement = $statement.Substring($matches[0].Length)
    }
    $statement = [regex]::Replace($statement, "'[^']*'", '')
    foreach ($match in [regex]::Matches(
        $statement,
        '(?<![A-Za-z0-9_])[.?]?[A-Za-z_][A-Za-z0-9_]*'
    )) {
        $name = $match.Value
        if ($name.StartsWith('?') -or $name.StartsWith('.')) {
            $key = $currentScope + '|' + $name
            if ($localDefinitions.ContainsKey($key) -and `
                $localDefinitions[$key] -gt $index) {
                $forwardFixups++
            }
        } elseif ($globalDefinitions.ContainsKey($name) -and `
            $globalDefinitions[$name] -gt $index) {
            $forwardFixups++
        }
    }
}
if ($forwardFixups -gt 128) {
    Fail-Check (
        "requires $forwardFixups forward fixups; ASM-F2 limit is 128"
    )
}

$beginMarker = '; BEGIN GENERATED STR8 MUTATION WORKER'
$endMarker = '; END GENERATED STR8 MUTATION WORKER'
$beginIndexes = @(0..($lines.Count - 1) | Where-Object {
    $lines[$_] -eq $beginMarker
})
$endIndexes = @(0..($lines.Count - 1) | Where-Object {
    $lines[$_] -eq $endMarker
})
if ($beginIndexes.Count -ne 1 -or $endIndexes.Count -ne 1) {
    Fail-Check 'missing unique generated-worker marker pair'
}
$beginIndex = $beginIndexes[0]
$endIndex = $endIndexes[0]
if ($endIndex -le $beginIndex) {
    Fail-Check 'generated-worker markers are reversed'
}
$sawWorkerOrg = $false
$embedded = [System.Collections.Generic.List[byte]]::new()
for ($index = $beginIndex + 1; $index -lt $endIndex; $index++) {
    $code = (($lines[$index] -split ';', 2)[0]).Trim()
    if ([string]::IsNullOrEmpty($code)) {
        continue
    }
    if ($code -eq 'ORG $3000') {
        if ($sawWorkerOrg) {
            Fail-Check 'embedded worker has duplicate ORG'
        }
        $sawWorkerOrg = $true
        continue
    }
    if ($code -notmatch '^DB\s+(.+)$') {
        Fail-Check "unexpected embedded-worker line $($index + 1)"
    }
    foreach ($token in ($matches[1] -split ',')) {
        $value = $token.Trim()
        if ($value -notmatch '^\$([0-9A-Fa-f]{2})$') {
            Fail-Check "bad embedded byte on line $($index + 1)"
        }
        $embedded.Add([Convert]::ToByte($matches[1], 16))
    }
}
if (-not $sawWorkerOrg) {
    Fail-Check 'embedded worker does not start at $3000'
}
if ($embedded.Count -ne 0x022B) {
    Fail-Check "embedded worker is $($embedded.Count) bytes; expected 555"
}
[byte[]]$mutationMemory = Read-S19Memory $MutationWorkerS19Path
for ($index = 0; $index -lt $embedded.Count; $index++) {
    if ($embedded[$index] -ne $mutationMemory[0x0200 + $index]) {
        Fail-Check ('embedded worker mismatch at ${0:X4}' -f `
            (0x0200 + $index))
    }
}

$semanticGates = @(
    @{
        Name = 'carried mutation worker is copied into the low tray'
        Pattern = 'BM_MAIN.*?LDX #\$00.*?LDA \$3000,X.*?STA \$0200,X.*?LDA \$3100,X.*?STA \$0300,X.*?LDX #\$2A.*?LDA \$3200,X.*?STA \$0400,X'
    },
    @{
        Name = 'stage and program call the carried mutation worker'
        Pattern = 'BM_STAGE.*?LDA #\$06.*?STA \$1FF0.*?JMP \$0200.*?BM_PROGRAM.*?LDA #\$05.*?STA \$1FF0.*?JMP \$0200'
    },
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
        Name = 'map snapshots and prints the Bank-3 directory'
        Pattern = 'BM_MDIR.*?BM_DIR\s+BRA.*?SEI.*?LDA #\$EE.*?TSB \$7FEC.*?LDA \$FFB0,X.*?STA \$1D00,X.*?LDA \$1B0C.*?TSB \$7FEC.*?BM_MAP.*?\?DONE\s+LDX #<BM_MLEGEND.*?JSR BM_PUTS.*?JSR BM_DIR'
    },
    @{
        Name = 'map prints its rows before the legend'
        Pattern = 'BM_MAP.*?\?BANK.*?\?SECTOR.*?CMP #\$04.*?BCS \?DONE.*?\?DONE\s+LDX #<BM_MLEGEND.*?BM_MMAP.*?BM_MLEGEND'
    },
    @{
        Name = 'directory rows include type description entry journal'
        Pattern = 'BM_DIR.*?LDA \$1D00,X.*?\?DESC.*?LDA \$1D0B,X.*?LDA \$1D0A,X.*?\?JOURNAL.*?CMP #\$10'
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

$listingPath = [System.IO.Path]::ChangeExtension($testSource, '.lst')
if (-not (Test-Path -LiteralPath $listingPath)) {
    Fail-Check "assembler did not emit listing $listingPath"
}
$beforeWorker = $true
$bodyEnd = -1
foreach ($line in [System.IO.File]::ReadAllLines($listingPath)) {
    if ($line.Contains('ORG $3000')) {
        $beforeWorker = $false
        continue
    }
    if (-not $beforeWorker) {
        continue
    }
    if ($line -match '00:([0-9A-Fa-f]{4}):\s+((?:[0-9A-Fa-f]{2}\s*)+)') {
        $address = [Convert]::ToInt32($matches[1], 16)
        $byteCount = @($matches[2].Trim() -split '\s+').Count
        $bodyEnd = [Math]::Max($bodyEnd, $address + $byteCount - 1)
    }
}
if ($bodyEnd -lt 0) {
    Fail-Check 'could not determine assembled maintenance-body end'
}
if ($bodyEnd -ge 0x3000) {
    Fail-Check ('maintenance body overlaps worker image at ${0:X4}' -f `
        $bodyEnd)
}
$workerGap = 0x3000 - $bodyEnd - 1

Write-Host (
    "STR8 BANK MAINT SOURCE = PASS; symbols={0}/64; locals-max={1}/16; forward-fixups={2}/128; body-end=`${3:X4}; worker-gap=`${4:X}; carried worker exact; map+directory restore entry bank" -f `
        $symbols.Count, $maxLocalCount, $forwardFixups, $bodyEnd, $workerGap
)

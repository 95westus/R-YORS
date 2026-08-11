param(
    [string]$CrcSourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a",
    [string]$InventorySourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/OLD/str8-jump-inventory-v1-3000.a",
    [string]$ReadApSourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/flash-bank-read-ap-2000.a",
    [string]$DumpApSourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/flash-bank-dump-ap-2000.a",
    [string]$BuildDir = "BUILD/tmp/str8-readonly-bank-tools-check",
    [string]$Assembler = "wdc02as"
)

$ErrorActionPreference = 'Stop'

function Fail-Check([string]$Message) {
    throw "STR8 read-only bank tools check: $Message"
}

function Check-Source([string]$Path, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Check "missing $Name source $Path"
    }

    $sourceFile = (Resolve-Path -LiteralPath $Path).Path
    $lines = [System.IO.File]::ReadAllLines($sourceFile)
    $sourceText = $lines -join "`n"
    $codeText = ($lines | ForEach-Object {
        ($_ -split ';', 2)[0]
    }) -join "`n"

    if ($codeText.Contains('$F003') -or `
        $codeText.Contains('STR8_SERVICE') -or `
        $codeText.Contains('$7DF0')) {
        Fail-Check "$Name still requests the retired full-worker doorway"
    }

    foreach ($required in @(
        'BANK_SELECT EQU $F010',
        'BANK_SELECT_RAM EQU $0203',
        'JSR BANK_SELECT',
        'JSR BANK_SELECT_RAM',
        'PHP',
        'SEI',
        'LDA #$03',
        'STA (DSTLO),Y'
    )) {
        if (-not $sourceText.Contains($required)) {
            Fail-Check "$Name is missing $required"
        }
    }

    if (-not [regex]::IsMatch(
        $sourceText,
        'STAGE\s+PHP.*?SEI.*?LDA COPY_SRC.*?JSR BANK_SELECT_RAM.*?STA \(DSTLO\),Y.*?LDA #\$03.*?JSR BANK_SELECT_RAM.*?PLP.*?SEC.*?RTS',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )) {
        Fail-Check "$Name does not select, stage, restore Bank 3, and return"
    }

    $symbols = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($line in $lines) {
        $code = ($line -split ';', 2)[0]
        if ($code -match '^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
            [void]$symbols.Add($matches[1])
        }
    }
    if ($symbols.Count -gt 64) {
        Fail-Check "$Name uses $($symbols.Count) globals; ASM-F2 limit is 64"
    }

    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    $testSource = Join-Path $BuildDir ($Name + '.asm')
    [System.IO.File]::WriteAllLines(
        $testSource,
        $lines,
        [System.Text.Encoding]::ASCII
    )
    $assemblerCommand = Get-Command $Assembler -ErrorAction Stop
    & $assemblerCommand.Source -G -L -S -W $testSource | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Fail-Check "$Name WDC assembler exited $LASTEXITCODE"
    }

    return $symbols.Count
}

function Check-ApSource(
    [string]$Path,
    [string]$Name,
    [string[]]$Required,
    [string[]]$ExternalSymbols
) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Check "missing $Name source $Path"
    }

    $sourceFile = (Resolve-Path -LiteralPath $Path).Path
    $lines = [System.IO.File]::ReadAllLines($sourceFile)
    $sourceText = $lines -join "`n"
    $codeText = ($lines | ForEach-Object {
        ($_ -split ';', 2)[0]
    }) -join "`n"

    if ($codeText.Contains('$F003') -or `
        $codeText.Contains('STR8_SERVICE') -or `
        $codeText.Contains('$7DF0')) {
        Fail-Check "$Name still requests the retired full-worker doorway"
    }

    foreach ($item in $Required) {
        if (-not $sourceText.Contains($item)) {
            Fail-Check "$Name is missing $item"
        }
    }

    $symbols = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($line in $lines) {
        $code = ($line -split ';', 2)[0]
        if ($code.Length -gt 63) {
            Fail-Check "$Name has a code line over 63 characters: $code"
        }
        if ($code -match '^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\s|$)') {
            [void]$symbols.Add($matches[1])
        }
    }
    if ($symbols.Count -gt 64) {
        Fail-Check "$Name uses $($symbols.Count) globals; ASM-F2 limit is 64"
    }

    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    $testSource = Join-Path $BuildDir ($Name + '.asm')
    $hostLines = @($ExternalSymbols | ForEach-Object { "        XREF $_" })
    $hostLines += $lines | ForEach-Object {
        if ($_ -match '^\s*(?:IMPORT|ENTRY)\s+') {
            return
        }
        $_
    }
    [System.IO.File]::WriteAllLines(
        $testSource,
        $hostLines,
        [System.Text.Encoding]::ASCII
    )
    $assemblerCommand = Get-Command $Assembler -ErrorAction Stop
    & $assemblerCommand.Source -G -L -S -W $testSource | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Fail-Check "$Name WDC assembler exited $LASTEXITCODE"
    }

    return $symbols.Count
}

$crcSymbols = Check-Source $CrcSourcePath 'str8-bank-crc-all-3000'
$inventorySymbols = Check-Source `
    $InventorySourcePath `
    'archived str8-jump-inventory-v1-3000 proof fixture'
$readSymbols = Check-ApSource `
    $ReadApSourcePath `
    'flash-bank-read-ap-2000' `
    @('BANK_SELECT EQU $F010', 'BANK_SELECT_RAM EQU $0203', `
      'PHP', 'SEI', 'STA (DSTLO),Y', 'LDA #$03') `
    @('BIO_FTDI_PUT_CSTR', 'SYS_READ_CSTRING_ECHO_UPPER')
$dumpSymbols = Check-ApSource `
    $DumpApSourcePath `
    'flash-bank-dump-ap-2000' `
    @('JSR $F010', 'JSR $0203', 'FBD_STAGE_COPY', `
      'PHP', 'SEI', 'STA ($C6),Y', 'LDA #$03') `
    @('BIO_FTDI_WRITE_BYTE_BLOCK', `
      'SYS_READ_CSTRING_ECHO_UPPER', 'BIO_FTDI_PUT_CSTR')

Write-Host (
    'STR8 READ-ONLY BANK SOURCES = PASS; CRC={0}/64; archived inventory proof={1}/64; read AP={2}/64; dump AP={3}/64; $F010/$0203 only' -f `
        $crcSymbols, $inventorySymbols, $readSymbols, $dumpSymbols
)

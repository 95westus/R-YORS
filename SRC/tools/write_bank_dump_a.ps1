param(
    [Parameter(Mandatory = $true)][string]$AsmPath,
    [Parameter(Mandatory = $true)][string]$MapPath,
    [Parameter(Mandatory = $true)][string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $AsmPath))
$symbols = @{}
foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $MapPath))) {
    if ($line -match '^\s*([0-9A-Fa-f]{8})\s+([A-Z_][A-Z0-9_]*)\s*$') {
        $symbols[$matches[2]] = [Convert]::ToInt32($matches[1], 16) -band 0xFFFF
    }
}
if (-not $symbols.ContainsKey('BANKDUMP') -or
        -not $symbols.ContainsKey('_END_CODE')) {
    throw 'BANKDUMP linker symbols were not found'
}
$imports = @(
    'BIO_FTDI_PUT_CSTR',
    'SYS_READ_CSTRING_ECHO_UPPER',
    'BIO_FTDI_WRITE_BYTE_BLOCK'
)

function Normalize-Code([string]$Line) {
    # The selected EQU/shared regions contain no inline comments.  Do not use
    # a raw semicolon regex here: ASM character data may legitimately encode
    # $3B, and treating a quoted semicolon as a comment truncated three board
    # message definitions in the first candidate.
    $code = $Line.Trim()
    $code = $code -replace '^([A-Z_][A-Z0-9_]*):', '$1'
    $code = $code -replace '\s+', ' '
    return $code.Trim()
}

$constants = @{}
$inEqu = $false
foreach ($line in $lines) {
    if ($line -match '^STATUS\s+EQU\s+') { $inEqu = $true }
    if (-not $inEqu) { continue }
    $code = Normalize-Code $line
    if ($code -match '^([A-Z_][A-Z0-9_]*) EQU \$([0-9A-Fa-f]{2,4})$') {
        $constants[$matches[1]] = [Convert]::ToInt32($matches[2],16)
    }
    if ($line -match '^BUFFER_HI\s+EQU\s+') { break }
}
if (-not $constants.ContainsKey('STATUS') -or
        -not $constants.ContainsKey('BUFFER_HI')) {
    throw 'BANKDUMP EQU block was not found'
}

$body = [Collections.Generic.List[string]]::new()
$inside = $false
foreach ($line in $lines) {
    if ($line -match '^\s*;\s*BEGIN SHARED BANKDUMP BODY\s*$') {
        $inside = $true
        continue
    }
    if ($line -match '^\s*;\s*END SHARED BANKDUMP BODY\s*$') {
        $inside = $false
        break
    }
    if (-not $inside) { continue }
    $definedLabel = $null
    if ($line -match '^\s*([A-Z_][A-Z0-9_]*):') {
        $definedLabel = $matches[1]
    }
    $code = Normalize-Code $line
    if ($code.Length -eq 0) { continue }
    if ($definedLabel) {
        $code = $code.Substring($definedLabel.Length).TrimStart()
    }
    $code = [regex]::Replace($code, '#([<>])([A-Z_][A-Z0-9_]*)', {
        param($match)
        $name = $match.Groups[2].Value
        if (-not $symbols.ContainsKey($name)) { return $match.Value }
        $value = $symbols[$name]
        if ($match.Groups[1].Value -eq '>') { $value = ($value -shr 8) -band 0xFF }
        else { $value = $value -band 0xFF }
        return ('#${0:X2}' -f $value)
    })
    if (-not $code.StartsWith(';')) {
        $code = [regex]::Replace($code, '(?<![A-Z0-9_])[A-Z_][A-Z0-9_]*(?![A-Z0-9_])', {
            param($match)
            $name = $match.Value
            if ($constants.ContainsKey($name)) {
                $value = $constants[$name]
                if ($value -le 0xFF) { return ('${0:X2}' -f $value) }
                return ('${0:X4}' -f $value)
            }
            if ($name -ne 'BANKDUMP' -and
                    $imports -notcontains $name -and
                    $symbols.ContainsKey($name)) {
                return ('${0:X4}' -f $symbols[$name])
            }
            return $name
        })
    }
    if ($definedLabel -eq 'BANKDUMP') {
        $code = "BANKDUMP $code"
    }
    if ($code.Length -eq 0) { continue }
    if ($code.Length -gt 63) {
        throw "generated BANKDUMP line is $($code.Length) columns: $code"
    }
    $body.Add($code)
    if ($definedLabel -eq 'BANKDUMP') { $body.Add('ENTRY BANKDUMP') }
}
if ($inside -or $body.Count -eq 0 -or -not $body.Contains('ENTRY BANKDUMP')) {
    throw 'BANKDUMP shared body or ENTRY was not found'
}

$output = [Collections.Generic.List[string]]::new()
@(
    '; BANK-DUMP-2000.A',
    '; READ-ONLY FIXED-$2000 APC FOR PHYSICAL FLASH INSPECTION.',
    ';',
    '; ASM NEW',
    '; PASTE THIS WHOLE FILE',
    '; AT SEAL>: PACKAGE BANKDUMP $3000',
    '; AT SEAL>: INSTALL 3000 B2',
    '; AFTER RESET: AP B2 BANKDUMP',
    ';',
    '; M AT THE BANK PROMPT PRINTS THE READ-ONLY 4X8 BANK MAP.',
    '; H DECODES AN AP-V2 HEADER AND DUMPS ITS FIRST 256 BYTES.',
    '; P DUMPS ONE SELECTED 256-BYTE PAGE. A DUMPS ALL 4K.',
    '; THE FLASH SECTOR IS STAGED AT $4000 BEFORE DISPLAY.',
    '; BANK 3 IS RESTORED BEFORE ANY DUMP OUTPUT. NO FLASH WRITES.',
    '',
    'ORG $2000',
    '',
    'IMPORT BIO_FTDI_PUT_CSTR',
    'IMPORT SYS_READ_CSTRING_ECHO_UPPER',
    'IMPORT BIO_FTDI_WRITE_BYTE_BLOCK',
    ''
) | ForEach-Object { $output.Add($_) }
$output.Add('; BEGIN SHARED BANKDUMP BODY')
$body | ForEach-Object { $output.Add($_) }
$output.Add('; END SHARED BANKDUMP BODY')
$output.Add('')
$output.Add('END')

$text = ($output -join "`r`n") + "`r`n"
$parent = Split-Path -Parent $OutPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
if ((Test-Path -LiteralPath $OutPath) -and
        ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $OutPath)) -ceq $text)) {
    Write-Host "BANKDUMP onboard source unchanged: $OutPath"
    exit 0
}
[IO.File]::WriteAllText($OutPath, $text, [Text.Encoding]::ASCII)
Write-Host "BANKDUMP onboard source updated: $OutPath"

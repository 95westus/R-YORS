param(
    [Parameter(Mandatory = $true)][string]$AsmPath,
    [Parameter(Mandatory = $true)][string]$MapPath,
    [Parameter(Mandatory = $true)][string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceLines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $AsmPath))
$symbols = @{}
foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $MapPath))) {
    if ($line -match '^\s*([0-9A-Fa-f]{8})\s+([A-Za-z_][A-Za-z0-9_]*)\s*$') {
        $symbols[$matches[2].ToUpperInvariant()] =
            [Convert]::ToInt32($matches[1], 16) -band 0xFFFF
    }
}
foreach ($required in @('MICROCHESS','MICROCHESS_ENGINE_END','SYSKIN','SYSCHOUT','SYSHEXOUT')) {
    if (-not $symbols.ContainsKey($required)) {
        throw "MicroChess linker symbol '$required' was not found"
    }
}

$imports = @(
    'BIO_FTDI_READ_BYTE_BLOCK',
    'BIO_FTDI_WRITE_BYTE_BLOCK',
    'SYS_WRITE_HEX_BYTE'
)

function Remove-InlineComment([string]$Line) {
    $single = $false
    $double = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($c -eq "'" -and -not $double) { $single = -not $single; continue }
        if ($c -eq '"' -and -not $single) { $double = -not $double; continue }
        if ($c -eq ';' -and -not $single -and -not $double) {
            return $Line.Substring(0, $i)
        }
    }
    return $Line
}

function Replace-SymbolsOutsideQuotes([string]$Code) {
    $result = [Text.StringBuilder]::new()
    $plain = [Text.StringBuilder]::new()
    $quote = [char]0

    function Flush-Plain {
        param([Text.StringBuilder]$Buffer, [Text.StringBuilder]$Destination)
        if ($Buffer.Length -eq 0) { return }
        $segment = $Buffer.ToString()
        $segment = [regex]::Replace($segment, '(?i)(?<![A-Z0-9_$])([A-Z_][A-Z0-9_]*)(?![A-Z0-9_])', {
            param($match)
            $name = $match.Groups[1].Value.ToUpperInvariant()
            if ($imports -contains $name) { return $name }
            if (-not $symbols.ContainsKey($name)) { return $match.Value }
            $value = $symbols[$name]
            if ($value -le 0xFF) { return ('${0:X2}' -f $value) }
            return ('${0:X4}' -f $value)
        })
        [void]$Destination.Append($segment)
        [void]$Buffer.Clear()
    }

    foreach ($c in $Code.ToCharArray()) {
        if ($quote -eq [char]0) {
            if ($c -eq "'" -or $c -eq '"') {
                Flush-Plain $plain $result
                $quote = $c
                [void]$result.Append($c)
            }
            else { [void]$plain.Append($c) }
        }
        else {
            [void]$result.Append($c)
            if ($c -eq $quote) { $quote = [char]0 }
        }
    }
    Flush-Plain $plain $result
    return $result.ToString()
}

function Add-CodeLine {
    param([Collections.Generic.List[string]]$Lines, [string]$Code)
    if ($Code -match '^DB "([^"]*)"$') {
        $value = $matches[1]
        for ($i = 0; $i -lt $value.Length; $i += 50) {
            $count = [Math]::Min(50, $value.Length - $i)
            $Lines.Add(("DC '{0}'" -f $value.Substring($i, $count)))
        }
        return
    }
    if ($Code.Length -le 63) {
        $Lines.Add($Code)
        return
    }
    throw "generated MicroChess line exceeds 63 columns: $Code"
}

$license = @(
    '; MICROCHESS-2000.A - FIXED-$2000 AP-V2 SOURCE',
    ';',
    '; Kim-1 MicroChess (c) 1976-2005 Peter Jennings,',
    '; www.benlo.com',
    ';',
    '; All rights reserved.',
    ';',
    '; Redistribution and use in source and binary forms, with or',
    '; without modification, are permitted provided that the',
    '; following conditions are met:',
    '; 1. Redistributions of source code must retain the above',
    '; copyright notice, this list of conditions and the following',
    '; disclaimer.',
    '; 2. Redistributions in binary form must reproduce the above',
    '; copyright notice, this list of conditions and the following',
    '; disclaimer in the documentation and/or other materials',
    '; provided with the distribution.',
    '; 3. The name of the author may not be used to endorse or',
    '; promote products derived from this software without specific',
    '; prior written permission.',
    ';',
    '; THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''''AS IS'''' AND ANY',
    '; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,',
    '; THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A',
    '; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE',
    '; AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,',
    '; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT',
    '; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS',
    '; OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER',
    '; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,',
    '; STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)',
    '; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF',
    '; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.',
    ';',
    '; Serial-terminal adaptation: Daryl Rictor, August 2002.',
    '; OCR corrections: Bill Forster, August 2005.',
    '; R-YORS AP adaptation retains the engine and board UI.',
    '; This R-YORS adaptation was produced with assistance from',
    '; OpenAI Codex, an AI coding system. Independently review and',
    '; hardware-verify it. This does not alter upstream copyright',
    '; or license terms.',
    ';',
    '; HIMON: ASM NEW, THEN SEND THIS COMPLETE FILE.',
    '; SEAL>: SEAL',
    '; SEAL>: PACKAGE MICROCHESS $3000',
    '; OPTIONAL FLASH: SEAL>: INSTALL 3000 B1',
    '; SEAL>: .',
    '; HIMON: AP $3000 $2000',
    '; FLASH RUN: APS B1 MICROCHESS; AP B1 MICROCHESS',
    '; Q RETURNS TO HIMON WITH A=$AC AND CARRY SET.',
    ''
)

$output = [Collections.Generic.List[string]]::new()
$license | ForEach-Object { $output.Add($_) }
$output.Add('ORG $2000')
$output.Add('')
foreach ($import in $imports) { $output.Add("IMPORT $import") }
$output.Add('')

$inside = $false
$skipImportWord = $false
foreach ($raw in $sourceLines) {
    if ($raw -match '^MICROCHESS:') { $inside = $true }
    if (-not $inside) { continue }
    if ($raw -match '^MICROCHESS_ENGINE_END:') { break }

    $code = (Remove-InlineComment $raw).Trim()
    if ($code.Length -eq 0) { continue }
    $code = $code -replace '\s+', ' '

    $defined = $null
    if ($code -match '^([A-Za-z_][A-Za-z0-9_]*):(?:\s+(.*))?$') {
        $defined = $matches[1]
        $code = $matches[2]
    }
    elseif ($code -match '^([A-Za-z_][A-Za-z0-9_]*)\s+(.*)$' -and
            $symbols.ContainsKey($matches[1].ToUpperInvariant())) {
        $defined = $matches[1]
        $code = $matches[2]
    }

    if ($skipImportWord) {
        if ($defined -and $defined.ToUpperInvariant().StartsWith('MICROCHESS_IMP_')) {
            if ([string]::IsNullOrWhiteSpace($code)) { continue }
        }
        if ($code -match '^DW\s+\$FFFF$') {
            $skipImportWord = $false
            continue
        }
    }

    $definedUpper = if ($defined) { $defined.ToUpperInvariant() } else { '' }
    if ($definedUpper -eq 'SYSKIN') {
        Add-CodeLine $output 'JMP BIO_FTDI_READ_BYTE_BLOCK'
        $skipImportWord = $true
        continue
    }
    if ($definedUpper -eq 'SYSCHOUT') {
        Add-CodeLine $output 'JMP BIO_FTDI_WRITE_BYTE_BLOCK'
        $skipImportWord = $true
        continue
    }
    if ($definedUpper -eq 'SYSHEXOUT') {
        Add-CodeLine $output 'JMP SYS_WRITE_HEX_BYTE'
        $skipImportWord = $true
        continue
    }
    if ($definedUpper.StartsWith('MICROCHESS_IMP_')) { continue }
    if ([string]::IsNullOrWhiteSpace($code)) { continue }

    $code = Replace-SymbolsOutsideQuotes $code
    $code = $code -replace '\s+', ' '
    if ($code -match '^(ADC|AND|CMP|EOR|LDA|ORA|SBC|STA) \$([0-9A-Fa-f]{2}),Y$') {
        $code = '{0} $00{1},Y' -f $matches[1],$matches[2].ToUpperInvariant()
    }
    if ($definedUpper -eq 'MICROCHESS') {
        $code = "MICROCHESS $code"
        Add-CodeLine $output $code
        $output.Add('ENTRY MICROCHESS')
    }
    else { Add-CodeLine $output $code }
}

if (-not $inside -or -not $output.Contains('ENTRY MICROCHESS')) {
    throw 'MicroChess body or entry was not found'
}
$output.Add('')
$output.Add('END')

$text = ($output -join "`r`n") + "`r`n"
$parent = Split-Path -Parent $OutPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
if ((Test-Path -LiteralPath $OutPath) -and
        ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $OutPath)) -ceq $text)) {
    Write-Host "MicroChess onboard source unchanged: $OutPath"
    exit 0
}
[IO.File]::WriteAllText($OutPath, $text, [Text.Encoding]::ASCII)
Write-Host "MicroChess onboard source updated: $OutPath"

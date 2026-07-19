param(
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin",
    [string]$AsmMapPath = "BUILD/s19/asm-v1-flash-8000.map",
    [string]$Str8MapPath = "BUILD/s19/str8-f000.map",
    [string]$OutPath = "../DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a",
    [int]$SourceOffset = 0x7000,
    [int]$StageAddress = 0x0A00,
    [int]$ImageAddress = 0x4000,
    [int]$Length = 0x1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-HexByte([int]$Value) {
    return ('$' + (($Value -band 0xff).ToString('X2')))
}

function Format-HexWord([int]$Value) {
    return ('$' + (($Value -band 0xffff).ToString('X4')))
}

function Get-MapSymbol([string]$Path, [string]$Name) {
    $pattern = '^\s*([0-9A-Fa-f]{8})\s+' + [regex]::Escape($Name) + '\s*$'
    $match = Select-String -Path $Path -Pattern $pattern | Select-Object -First 1
    if (-not $match) {
        throw ("Symbol {0} not found in {1}" -f $Name, $Path)
    }
    return [Convert]::ToInt32($match.Matches[0].Groups[1].Value.Substring(4), 16)
}

function Assert-Bytes([byte[]]$Bytes, [int]$Offset, [int[]]$Expected, [string]$Name) {
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        $actual = [int]$Bytes[$Offset + $i]
        if ($actual -ne $Expected[$i]) {
            throw ("{0} mismatch at +{1:X4}: got {2:X2}, expected {3:X2}" -f $Name, ($Offset + $i), $actual, $Expected[$i])
        }
    }
}

if (-not (Test-Path -LiteralPath $BinPath)) {
    throw ("BIN not found: {0}" -f $BinPath)
}
if (-not (Test-Path -LiteralPath $AsmMapPath)) {
    throw ("ASM map not found: {0}" -f $AsmMapPath)
}
if (-not (Test-Path -LiteralPath $Str8MapPath)) {
    throw ("STR8 map not found: {0}" -f $Str8MapPath)
}

$bin = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $BinPath).Path)
if (($SourceOffset + $Length) -gt $bin.Length) {
    throw ("BIN too short for top-sector slice: len={0}, offset={1:X}, size={2:X}" -f $bin.Length, $SourceOffset, $Length)
}

$top = New-Object byte[] $Length
[Array]::Copy($bin, $SourceOffset, $top, 0, $Length)

$str8Start = Get-MapSymbol -Path $Str8MapPath -Name "START"
$str8Boot = Get-MapSymbol -Path $Str8MapPath -Name "STR8_BOOT_START"
$str8WorkerBody = Get-MapSymbol -Path $Str8MapPath -Name "STR8_RUN_WORKER_SERVICE_BODY"
$str8ApBody = Get-MapSymbol -Path $Str8MapPath -Name "STR8_AP_IMPORT_LINK_SERVICE_BODY"
$str8Nmi = Get-MapSymbol -Path $Str8MapPath -Name "STR8_IVY_ENTRY_NMI"
$str8Irq = Get-MapSymbol -Path $Str8MapPath -Name "STR8_IVY_ENTRY_IRQ_MASTER"
$str8Screen = Get-MapSymbol -Path $Str8MapPath -Name "MSG_SCREEN"
$str8Prompt = Get-MapSymbol -Path $Str8MapPath -Name "MSG_PROMPT"
if ($str8Start -ne 0xF000) {
    throw ("STR8 START is {0}; expected `$F000" -f (Format-HexWord $str8Start))
}

$screenOffset = $str8Screen - $str8Start
$promptOffset = $str8Prompt - $str8Start
Assert-Bytes -Bytes $top -Offset 0x0000 -Expected @(
    0x4C, ($str8Boot -band 0xFF), (($str8Boot -shr 8) -band 0xFF),
    0x4C, ($str8WorkerBody -band 0xFF), (($str8WorkerBody -shr 8) -band 0xFF),
    0x4C, ($str8ApBody -band 0xFF), (($str8ApBody -shr 8) -band 0xFF)
) -Name "top head"
Assert-Bytes -Bytes $top -Offset $promptOffset -Expected @(0x53,0x54,0x52,0x38,0x2D,0x4E,0xBE) -Name "STR8-N prompt"
Assert-Bytes -Bytes $top -Offset $screenOffset -Expected @(0x0D,0x0A,0x53,0x54,0x52,0x38,0x2D,0x4E,0x20,0x56,0x30,0x20,0x23,0x35,0x46,0x36,0x41,0x30,0x46,0x37,0x41,0x0D,0x0A) -Name "STR8-N FACE id"
Assert-Bytes -Bytes $top -Offset 0x0FFA -Expected @(
    ($str8Nmi -band 0xFF), (($str8Nmi -shr 8) -band 0xFF),
    ($str8Start -band 0xFF), (($str8Start -shr 8) -band 0xFF),
    ($str8Irq -band 0xFF), (($str8Irq -shr 8) -band 0xFF)
) -Name "vectors"

$cstr = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_WRITE_CSTRING"
$hexb = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_WRITE_HEX_BYTE"
$hexw = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_WRITE_HEX_WORD_AX"
$crlf = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_PRINT_CRLF"

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$Line) {
    $script:lines.Add($Line)
}

Add-Line '; STR8N-TOPWRITE-TRANSIENT-3000.A'
Add-Line '; SELF-CONTAINED STR8-N TOP-SECTOR WRITER.'
Add-Line '; ASSEMBLE WITH ASM-F2. NO SEPARATE STR8-TOP-STAGE S19 LOAD NEEDED.'
Add-Line ';'
Add-Line '; ENTRY POINTS AFTER ASSEMBLY:'
Add-Line ';   G 3000  COPY EMBEDDED IMAGE $4000-$4FFF TO $0A00-$19FF'
Add-Line ';   G 3003  ERASE/PROGRAM/VERIFY BANK 3 $F000-$FFFF FROM $0A00'
Add-Line ';'
Add-Line '; STATUS:'
Add-Line ';   $1A00 = MODE, $00 STAGE OR $01 PROGRAM'
Add-Line ';   $1A01 = $AC OK'
Add-Line ';   $1A01 = $E0 STAGE COPY/VERIFY MISMATCH'
Add-Line ';   $1A01 = $E1 ERASE TIMEOUT'
Add-Line ';   $1A01 = $E2 PROGRAM TIMEOUT'
Add-Line ';   $1A01 = $E3 VERIFY MISMATCH'
Add-Line ';   $1A02/$1A03 = FAIL ADDRESS WHEN AVAILABLE'
Add-Line ';'
Add-Line ('; FACE CHECK: ROM {0} MAPS TO RAM {1}.' -f (Format-HexWord $str8Screen), (Format-HexWord ($StageAddress + $screenOffset)))
Add-Line ('; PROMPT CHECK: ROM {0} MAPS TO RAM {1}.' -f (Format-HexWord $str8Prompt), (Format-HexWord ($StageAddress + $promptOffset)))
Add-Line ';'
Add-Line '        ORG $3000'
Add-Line ''
Add-Line 'STAGE   JMP TSTAGE'
Add-Line 'PROG    JMP TPROG'
Add-Line ''
Add-Line 'MODE    EQU $1A00'
Add-Line 'STAT    EQU $1A01'
Add-Line 'FLO     EQU $1A02'
Add-Line 'FHI     EQU $1A03'
Add-Line 'SPLO    EQU $C8'
Add-Line 'SPHI    EQU $C9'
Add-Line 'DPLO    EQU $CA'
Add-Line 'DPHI    EQU $CB'
Add-Line ''
Add-Line ('CSTR    EQU {0}' -f (Format-HexWord $cstr))
Add-Line ('HEXB    EQU {0}' -f (Format-HexWord $hexb))
Add-Line ('HEXW    EQU {0}' -f (Format-HexWord $hexw))
Add-Line ('CRLF    EQU {0}' -f (Format-HexWord $crlf))
Add-Line 'WTRAY   EQU $0200'
Add-Line ''
Add-Line 'TSTAGE  LDX #<MSTG'
Add-Line '        LDY #>MSTG'
Add-Line '        JSR PL'
Add-Line '        STZ MODE'
Add-Line '        STZ STAT'
Add-Line '        STZ FLO'
Add-Line '        STZ FHI'
Add-Line '        JSR COPYI'
Add-Line '        JSR VSTG'
Add-Line '        BCC STGERR'
Add-Line '        LDA #$AC'
Add-Line '        STA STAT'
Add-Line '        JMP PRSTAT'
Add-Line 'STGERR  LDA #$E0'
Add-Line '        STA STAT'
Add-Line '        JMP PRSTAT'
Add-Line ''
Add-Line 'TPROG   LDX #<MPRG'
Add-Line '        LDY #>MPRG'
Add-Line '        JSR PL'
Add-Line '        LDA #$01'
Add-Line '        STA MODE'
Add-Line '        STZ STAT'
Add-Line '        STZ FLO'
Add-Line '        STZ FHI'
Add-Line '        JSR CPYW'
Add-Line '        JSR WTRAY'
Add-Line '        JMP PRSTAT'
Add-Line ''
Add-Line 'COPYI   STZ SPLO'
Add-Line '        LDA #$40'
Add-Line '        STA SPHI'
Add-Line '        STZ DPLO'
Add-Line '        LDA #$0A'
Add-Line '        STA DPHI'
Add-Line '        LDX #$10'
Add-Line 'CIPAGE  LDY #$00'
Add-Line 'CIBYTE  LDA (SPLO),Y'
Add-Line '        STA (DPLO),Y'
Add-Line '        INY'
Add-Line '        BNE CIBYTE'
Add-Line '        INC SPHI'
Add-Line '        INC DPHI'
Add-Line '        DEX'
Add-Line '        BNE CIPAGE'
Add-Line '        RTS'
Add-Line ''
Add-Line 'VSTG    STZ SPLO'
Add-Line '        LDA #$40'
Add-Line '        STA SPHI'
Add-Line '        STZ DPLO'
Add-Line '        LDA #$0A'
Add-Line '        STA DPHI'
Add-Line '        LDX #$10'
Add-Line 'VSPAGE  LDY #$00'
Add-Line 'VSBYTE  LDA (SPLO),Y'
Add-Line '        CMP (DPLO),Y'
Add-Line '        BNE VSFAIL'
Add-Line '        INY'
Add-Line '        BNE VSBYTE'
Add-Line '        INC SPHI'
Add-Line '        INC DPHI'
Add-Line '        DEX'
Add-Line '        BNE VSPAGE'
Add-Line '        SEC'
Add-Line '        RTS'
Add-Line 'VSFAIL  TYA'
Add-Line '        STA FLO'
Add-Line '        LDA DPHI'
Add-Line '        STA FHI'
Add-Line '        CLC'
Add-Line '        RTS'
Add-Line ''
Add-Line 'CPYW    LDA #<WSTART'
Add-Line '        STA SPLO'
Add-Line '        LDA #>WSTART'
Add-Line '        STA SPHI'
Add-Line '        STZ DPLO'
Add-Line '        LDA #$02'
Add-Line '        STA DPHI'
Add-Line '        LDX #$02'
Add-Line 'CWPAGE  LDY #$00'
Add-Line 'CWBYTE  LDA (SPLO),Y'
Add-Line '        STA (DPLO),Y'
Add-Line '        INY'
Add-Line '        BNE CWBYTE'
Add-Line '        INC SPHI'
Add-Line '        INC DPHI'
Add-Line '        DEX'
Add-Line '        BNE CWPAGE'
Add-Line '        RTS'
Add-Line ''
Add-Line 'PRSTAT  LDA STAT'
Add-Line '        CMP #$AC'
Add-Line '        BNE PRERR'
Add-Line '        LDX #<MOK'
Add-Line '        LDY #>MOK'
Add-Line '        JSR PL'
Add-Line '        LDA STAT'
Add-Line '        SEC'
Add-Line '        RTS'
Add-Line 'PRERR   LDX #<MERR'
Add-Line '        LDY #>MERR'
Add-Line '        JSR PRC'
Add-Line '        LDA STAT'
Add-Line '        JSR HEXB'
Add-Line '        LDX #<MAT'
Add-Line '        LDY #>MAT'
Add-Line '        JSR PRC'
Add-Line '        LDA FHI'
Add-Line '        LDX FLO'
Add-Line '        JSR HEXW'
Add-Line '        JSR CRLF'
Add-Line '        LDA STAT'
Add-Line '        CLC'
Add-Line '        RTS'
Add-Line ''
Add-Line 'PL      JSR PRC'
Add-Line '        JMP CRLF'
Add-Line 'PRC     JMP CSTR'
Add-Line ''
Add-Line '; RAM worker copied to $0200. No ROM calls while flash is busy.'
Add-Line 'WSTART  PHP'
Add-Line '        SEI'
Add-Line '        LDA #$EE'
Add-Line '        TRB $7FEC'
Add-Line '        LDA #$EE'
Add-Line '        TSB $7FEC'
Add-Line ''
Add-Line '        STZ $D1'
Add-Line '        LDA #$F0'
Add-Line '        STA $D2'
Add-Line '        LDA #$AA'
Add-Line '        STA $D555'
Add-Line '        LDA #$55'
Add-Line '        STA $AAAA'
Add-Line '        LDA #$80'
Add-Line '        STA $D555'
Add-Line '        LDA #$AA'
Add-Line '        STA $D555'
Add-Line '        LDA #$55'
Add-Line '        STA $AAAA'
Add-Line '        LDA #$30'
Add-Line '        LDY #$00'
Add-Line '        STA ($D1),Y'
Add-Line ''
Add-Line '        STZ $D4'
Add-Line '        STZ $D5'
Add-Line '        LDA #$08'
Add-Line '        STA $D6'
Add-Line 'WEPOLL  LDY #$00'
Add-Line '        LDA ($D1),Y'
Add-Line '        CMP #$FF'
Add-Line '        BEQ WEROK'
Add-Line '        DEC $D4'
Add-Line '        BNE WEPOLL'
Add-Line '        DEC $D5'
Add-Line '        BNE WEPOLL'
Add-Line '        DEC $D6'
Add-Line '        BNE WEPOLL'
Add-Line '        LDA #$E1'
Add-Line '        STA STAT'
Add-Line '        LDA #$F0'
Add-Line '        STA $D555'
Add-Line '        LDA #$EE'
Add-Line '        TRB $7FEC'
Add-Line '        LDA #$EE'
Add-Line '        TSB $7FEC'
Add-Line '        PLP'
Add-Line '        RTS'
Add-Line ''
Add-Line 'WEROK   STZ $D1'
Add-Line '        LDA #$F0'
Add-Line '        STA $D2'
Add-Line '        STZ $CF'
Add-Line '        LDA #$0A'
Add-Line '        STA $D0'
Add-Line 'WPBYTE  LDY #$00'
Add-Line '        LDA ($CF),Y'
Add-Line '        CMP #$FF'
Add-Line '        BEQ WPNEXT'
Add-Line '        STA $D3'
Add-Line '        LDA #$AA'
Add-Line '        STA $D555'
Add-Line '        LDA #$55'
Add-Line '        STA $AAAA'
Add-Line '        LDA #$A0'
Add-Line '        STA $D555'
Add-Line '        LDA $D3'
Add-Line '        STA ($D1),Y'
Add-Line '        STZ $D4'
Add-Line '        STZ $D5'
Add-Line '        LDA #$02'
Add-Line '        STA $D6'
Add-Line 'WPPOLL  LDY #$00'
Add-Line '        LDA ($D1),Y'
Add-Line '        CMP $D3'
Add-Line '        BEQ WPNEXT'
Add-Line '        DEC $D4'
Add-Line '        BNE WPPOLL'
Add-Line '        DEC $D5'
Add-Line '        BNE WPPOLL'
Add-Line '        DEC $D6'
Add-Line '        BNE WPPOLL'
Add-Line '        LDA #$E2'
Add-Line '        STA STAT'
Add-Line '        LDA $D1'
Add-Line '        STA FLO'
Add-Line '        LDA $D2'
Add-Line '        STA FHI'
Add-Line '        BRA WRESET'
Add-Line ''
Add-Line 'WPNEXT  INC $D1'
Add-Line '        INC $CF'
Add-Line '        BNE WPBYTE'
Add-Line '        INC $D2'
Add-Line '        INC $D0'
Add-Line '        LDA $D0'
Add-Line '        CMP #$1A'
Add-Line '        BNE WPBYTE'
Add-Line ''
Add-Line '        STZ $D1'
Add-Line '        LDA #$F0'
Add-Line '        STA $D2'
Add-Line '        STZ $CF'
Add-Line '        LDA #$0A'
Add-Line '        STA $D0'
Add-Line 'WVPAGE  LDY #$00'
Add-Line 'WVBYTE  LDA ($D1),Y'
Add-Line '        CMP ($CF),Y'
Add-Line '        BNE WVFAIL'
Add-Line '        INY'
Add-Line '        BNE WVBYTE'
Add-Line '        INC $D2'
Add-Line '        INC $D0'
Add-Line '        LDA $D0'
Add-Line '        CMP #$1A'
Add-Line '        BNE WVPAGE'
Add-Line '        LDA #$AC'
Add-Line '        STA STAT'
Add-Line '        LDA #$F0'
Add-Line '        STA $D555'
Add-Line '        PLP'
Add-Line '        RTS'
Add-Line ''
Add-Line 'WVFAIL  LDA #$E3'
Add-Line '        STA STAT'
Add-Line '        TYA'
Add-Line '        STA FLO'
Add-Line '        LDA $D2'
Add-Line '        STA FHI'
Add-Line ''
Add-Line 'WRESET  LDA #$F0'
Add-Line '        STA $D555'
Add-Line '        LDA #$EE'
Add-Line '        TRB $7FEC'
Add-Line '        LDA #$EE'
Add-Line '        TSB $7FEC'
Add-Line '        PLP'
Add-Line '        RTS'
Add-Line ''
Add-Line 'MSTG    DB ''T'',''W'','' '',''S'',''T'',''G'',$00'
Add-Line 'MPRG    DB ''T'',''W'','' '',''P'',''R'',''G'',$00'
Add-Line 'MOK     DB ''T'',''W'','' '',''O'',''K'',$00'
Add-Line 'MERR    DB ''T'',''W'','' '',''E'',''R'',''R'',''='',''$'',$00'
Add-Line 'MAT     DB '' '',''@'',''='',''$'',$00'
Add-Line ''
Add-Line ('        ORG {0}' -f (Format-HexWord $ImageAddress))
Add-Line '; EMBEDDED TOP SECTOR IMAGE. ROM $F000-$FFFF.'

for ($i = 0; $i -lt $top.Length; $i += 8) {
    $end = [Math]::Min($i + 7, $top.Length - 1)
    $atoms = for ($j = $i; $j -le $end; $j++) { Format-HexByte ([int]$top[$j]) }
    Add-Line ('        DB ' + ($atoms -join ','))
}

Add-Line ''
Add-Line '        END'

$parent = Split-Path -Parent $OutPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

[System.IO.File]::WriteAllLines($OutPath, $lines, [System.Text.Encoding]::ASCII)
Write-Host ("STR8-N topwrite .a    = {0}" -f $OutPath)
Write-Host ("Embedded ROM range    = F000-FFFF")
Write-Host ("Embedded RAM range    = {0}-{1}" -f (Format-HexWord $ImageAddress), (Format-HexWord ($ImageAddress + $Length - 1)))
Write-Host ("Stage RAM range       = {0}-{1}" -f (Format-HexWord $StageAddress), (Format-HexWord ($StageAddress + $Length - 1)))
Write-Host ("FACE ROM/stage address = {0}/{1}" -f (Format-HexWord $str8Screen), (Format-HexWord ($StageAddress + $screenOffset)))
Write-Host ("Prompt ROM/stage addr  = {0}/{1}" -f (Format-HexWord $str8Prompt), (Format-HexWord ($StageAddress + $promptOffset)))

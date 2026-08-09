param(
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin",
    [string]$AsmMapPath = "BUILD/s19/asm-v1-flash-8000.map",
    [string]$Str8MapPath = "BUILD/s19/str8-f000.map",
    [string]$OutPath = "BUILD/generated/asm-samples/str8n-topwrite-transient-3000.a",
    [int]$SourceOffset = 0x7000,
    [int]$StageAddress = 0x0A00,
    [int]$ImageAddress = 0x4000,
    [int]$Length = 0x1000,
    [switch]$PreserveV1Directory
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
$str8RetiredF006 = Get-MapSymbol -Path $Str8MapPath -Name "STR8_RETIRED_F006"
$str8Nmi = Get-MapSymbol -Path $Str8MapPath -Name "STR8_IVY_ENTRY_NMI"
$str8Irq = Get-MapSymbol -Path $Str8MapPath -Name "STR8_IVY_ENTRY_IRQ_MASTER"
$str8Id = Get-MapSymbol -Path $Str8MapPath -Name "MSG_ID"
$str8Prompt = Get-MapSymbol -Path $Str8MapPath -Name "MSG_PROMPT"
if ($str8Start -ne 0xF000) {
    throw ("STR8 START is {0}; expected `$F000" -f (Format-HexWord $str8Start))
}
if ($str8RetiredF006 -ne 0xF006) {
    throw ("STR8 retired AP-link slot is {0}; expected `$F006" -f (Format-HexWord $str8RetiredF006))
}

$idOffset = $str8Id - $str8Start
$promptOffset = $str8Prompt - $str8Start
Assert-Bytes -Bytes $top -Offset 0x0000 -Expected @(
    0x4C, ($str8Boot -band 0xFF), (($str8Boot -shr 8) -band 0xFF),
    0x4C, ($str8WorkerBody -band 0xFF), (($str8WorkerBody -shr 8) -band 0xFF),
    0x18, 0x60, 0xEA
) -Name "top head"
Assert-Bytes -Bytes $top -Offset $promptOffset -Expected @(0x53,0x54,0x52,0x38,0x2D,0x4E,0xBE) -Name "STR8-N prompt"
$idEndOffset = $idOffset
while ($idEndOffset -lt ($idOffset + 64) -and $top[$idEndOffset] -ne 0x8A) {
    $idEndOffset++
}
if ($idEndOffset -ge ($idOffset + 64) -or $top[$idEndOffset] -ne 0x8A) {
    throw "STR8-N FACE id is not terminated within 64 bytes"
}
Assert-Bytes -Bytes $top -Offset $idOffset -Expected @(0x0D,0x0A) -Name "STR8-N FACE id prefix"
if ($top[$idEndOffset - 1] -ne 0x0D) {
    throw "STR8-N FACE id is missing its final CR"
}
$idText = [System.Text.Encoding]::ASCII.GetString($top, $idOffset + 2, $idEndOffset - $idOffset - 3)
if ($idText -notmatch '^STR8-N V 00\.\d{4}\(\d{4}\) \$F$') {
    throw ("STR8-N FACE id has unexpected text: {0}" -f $idText)
}
Assert-Bytes -Bytes $top -Offset 0x0FFA -Expected @(
    ($str8Nmi -band 0xFF), (($str8Nmi -shr 8) -band 0xFF),
    ($str8Start -band 0xFF), (($str8Start -shr 8) -band 0xFF),
    ($str8Irq -band 0xFF), (($str8Irq -shr 8) -band 0xFF)
) -Name "vectors"

$cstr = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_WRITE_CSTRING"
$read = Get-MapSymbol -Path $AsmMapPath -Name "ASM_RJ_READ_CSTRING"
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
if ($PreserveV1Directory) {
    Add-Line '; V1 REFRESH: COPIES LIVE $FFB0-$FFEF INTO THE EMBEDDED IMAGE.'
} else {
    Add-Line '; ARCHIVED REPLACEMENT/MIGRATION: OVERWRITES LIVE $FFB0-$FFEF.'
    Add-Line '; DO NOT USE ON INSTALLED V1; USE THE V1 REFRESH WRITER.'
}
Add-Line ';'
Add-Line '; ENTRY POINTS AFTER ASSEMBLY:'
Add-Line ';   G 3000  OPEN TEXT OPERATION MENU'
Add-Line ';   G 3003  ERASE/PROGRAM/VERIFY BANK 3 $F000-$FFFF FROM $0A00'
Add-Line ';'
Add-Line '; MENU OPERATIONS:'
Add-Line ';   S STAGE+VERIFY, V VERIFY STAGE, P PROGRAM, I STATUS, Q QUIT'
Add-Line ';   P FIRST VERIFIES THE STAGE, THEN REQUIRES THE WORD WRITE.'
Add-Line ';   G 3003 IS THE RAW COMPATIBILITY ENTRY AND HAS NO CONFIRMATION.'
Add-Line ';'
Add-Line '; STATUS:'
Add-Line ';   $1A00 = MODE, $00 STAGE, $01 PROGRAM, OR $02 VERIFY'
Add-Line ';   $1A01 = $AC OK'
Add-Line ';   $1A01 = $E0 STAGE COPY/VERIFY MISMATCH'
Add-Line ';   $1A01 = $E1 ERASE TIMEOUT'
Add-Line ';   $1A01 = $E2 PROGRAM TIMEOUT'
Add-Line ';   $1A01 = $E3 VERIFY MISMATCH'
Add-Line ';   $1A02/$1A03 = FAIL ADDRESS WHEN AVAILABLE'
Add-Line ';'
Add-Line ('; FACE CHECK: ROM {0} MAPS TO RAM {1}.' -f (Format-HexWord $str8Id), (Format-HexWord ($StageAddress + $idOffset)))
Add-Line ('; PROMPT CHECK: ROM {0} MAPS TO RAM {1}.' -f (Format-HexWord $str8Prompt), (Format-HexWord ($StageAddress + $promptOffset)))
Add-Line ';'
Add-Line '        ORG $3000'
Add-Line ''
Add-Line '        JMP TMENU'
Add-Line '        JMP TPROG'
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
Add-Line ('READ    EQU {0}' -f (Format-HexWord $read))
Add-Line ('HEXB    EQU {0}' -f (Format-HexWord $hexb))
Add-Line ('HEXW    EQU {0}' -f (Format-HexWord $hexw))
Add-Line ('CRLF    EQU {0}' -f (Format-HexWord $crlf))
Add-Line 'WTRAY   EQU $0200'
Add-Line ''
Add-Line 'TMENU   LDX #<MHELP'
Add-Line '        LDY #>MHELP'
Add-Line '        JSR PL'
Add-Line 'MLOOP   LDX #<MPMT'
Add-Line '        LDY #>MPMT'
Add-Line '        JSR CSTR'
Add-Line '        LDX #$10'
Add-Line '        LDY #$1A'
Add-Line '        JSR READ'
Add-Line '        BCC MLOOP'
Add-Line '        LDA $1A10'
Add-Line '        CMP #''S'''
Add-Line '        BEQ OPSTG'
Add-Line '        CMP #''V'''
Add-Line '        BEQ OPVFY'
Add-Line '        CMP #''P'''
Add-Line '        BEQ OPPRG'
Add-Line '        CMP #''I'''
Add-Line '        BEQ OPSTA'
Add-Line '        CMP #''Q'''
Add-Line '        BEQ MQUIT'
Add-Line 'MNO     LDX #<MHELP'
Add-Line '        LDY #>MHELP'
Add-Line '        JSR PL'
Add-Line '        BRA MLOOP'
Add-Line 'MQUIT   LDA STAT'
Add-Line '        CMP #$AC'
Add-Line '        RTS'
Add-Line 'OPSTG   JSR TSTAGE'
Add-Line '        BRA MLOOP'
Add-Line 'OPVFY   JSR TVERIFY'
Add-Line '        BRA MLOOP'
Add-Line 'OPSTA   JSR TINFO'
Add-Line '        BRA MLOOP'
Add-Line 'OPPRG   JSR TVERIFY'
Add-Line '        BCC MLOOP'
Add-Line '        LDX #<MCFM'
Add-Line '        LDY #>MCFM'
Add-Line '        JSR CSTR'
Add-Line '        LDX #$10'
Add-Line '        LDY #$1A'
Add-Line '        JSR READ'
Add-Line '        BCC NOGO'
Add-Line '        LDA $1A10'
Add-Line '        CMP #''W'''
Add-Line '        BNE NOGO'
Add-Line '        LDA $1A11'
Add-Line '        CMP #''R'''
Add-Line '        BNE NOGO'
Add-Line '        LDA $1A12'
Add-Line '        CMP #''I'''
Add-Line '        BNE NOGO'
Add-Line '        LDA $1A13'
Add-Line '        CMP #''T'''
Add-Line '        BNE NOGO'
Add-Line '        LDA $1A14'
Add-Line '        CMP #''E'''
Add-Line '        BNE NOGO'
Add-Line '        LDA $1A15'
Add-Line '        BNE NOGO'
Add-Line '        JSR TPROG'
Add-Line '        JMP MLOOP'
Add-Line 'NOGO    LDX #<MCAN'
Add-Line '        LDY #>MCAN'
Add-Line '        JSR PL'
Add-Line '        JMP MLOOP'
Add-Line ''
Add-Line 'TSTAGE  LDX #<MSTG'
Add-Line '        LDY #>MSTG'
Add-Line '        JSR PL'
Add-Line '        STZ MODE'
Add-Line '        STZ STAT'
Add-Line '        STZ FLO'
Add-Line '        STZ FHI'
if ($PreserveV1Directory) {
    Add-Line '        LDX #$3F'
    Add-Line 'CDIR    LDA $FFB0,X'
    Add-Line ('        STA {0},X' -f (Format-HexWord ($ImageAddress + 0x0FB0)))
    Add-Line '        DEX'
    Add-Line '        BPL CDIR'
}
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
Add-Line 'TVERIFY LDA #$02'
Add-Line '        STA MODE'
Add-Line '        STZ STAT'
Add-Line '        STZ FLO'
Add-Line '        STZ FHI'
Add-Line '        JSR VSTG'
Add-Line '        BCC VFYERR'
Add-Line '        LDA #$AC'
Add-Line '        STA STAT'
Add-Line '        JMP PRSTAT'
Add-Line 'VFYERR  LDA #$E0'
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
Add-Line '        JSR CSTR'
Add-Line '        LDA STAT'
Add-Line '        JSR HEXB'
Add-Line '        LDX #<MAT'
Add-Line '        LDY #>MAT'
Add-Line '        JSR CSTR'
Add-Line '        LDA FHI'
Add-Line '        LDX FLO'
Add-Line '        JSR HEXW'
Add-Line '        JSR CRLF'
Add-Line '        LDA STAT'
Add-Line '        CLC'
Add-Line '        RTS'
Add-Line ''
Add-Line 'TINFO   LDX #<MSTAT'
Add-Line '        LDY #>MSTAT'
Add-Line '        JSR CSTR'
Add-Line '        LDA MODE'
Add-Line '        JSR HEXB'
Add-Line '        LDX #<MRES'
Add-Line '        LDY #>MRES'
Add-Line '        JSR CSTR'
Add-Line '        LDA STAT'
Add-Line '        JSR HEXB'
Add-Line '        LDX #<MAT'
Add-Line '        LDY #>MAT'
Add-Line '        JSR CSTR'
Add-Line '        LDA FHI'
Add-Line '        LDX FLO'
Add-Line '        JSR HEXW'
Add-Line '        JSR CRLF'
Add-Line '        SEC'
Add-Line '        RTS'
Add-Line ''
Add-Line 'PL      JSR CSTR'
Add-Line '        JMP CRLF'
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
Add-Line 'MHELP   DB ''T'',''O'',''P'',''W'',''R'',''I'',''T'',''E'''
Add-Line '        DB ''R'',$0D,$0A,''S'','' '',''S'',''T'',''A'''
Add-Line '        DB ''G'',''E'',''+'',''V'',''E'',''R'',''I'',''F'''
Add-Line '        DB ''Y'',$0D,$0A,''V'','' '',''V'',''E'',''R'''
Add-Line '        DB ''I'',''F'',''Y'','' '',''S'',''T'',''A'',''G'''
Add-Line '        DB ''E'',$0D,$0A,''P'','' '',''P'',''R'',''O'''
Add-Line '        DB ''G'',''R'',''A'',''M'','' '',''B'',''A'',''N'''
Add-Line '        DB ''K'','' '',''3'',$0D,$0A,''I'','' '',''S'''
Add-Line '        DB ''T'',''A'',''T'',''U'',''S'',$0D,$0A,''Q'''
Add-Line '        DB '' '',''Q'',''U'',''I'',''T'',$00'
Add-Line 'MPMT    DB ''T'',''W'',''>'','' '',$00'
Add-Line 'MCFM    DB ''T'',''Y'',''P'',''E'','' '',''W'',''R'',''I'''
Add-Line '        DB ''T'',''E'','' '',''T'',''O'','' '',''P'',''R'''
Add-Line '        DB ''O'',''G'',''R'',''A'',''M'','' '',''B'',''3'''
Add-Line '        DB ''>'','' '',$00'
Add-Line 'MCAN    DB ''T'',''W'','' '',''C'',''A'',''N'',''C'',''E'''
Add-Line '        DB ''L'',$00'
Add-Line 'MSTG    DB ''T'',''W'','' '',''S'',''T'',''G'',$00'
Add-Line 'MPRG    DB ''T'',''W'','' '',''P'',''R'',''G'',$00'
Add-Line 'MOK     DB ''T'',''W'','' '',''O'',''K'',$00'
Add-Line 'MERR    DB ''T'',''W'','' '',''E'',''R'',''R'',''='',''$'',$00'
Add-Line 'MAT     DB '' '',''@'',''='',''$'',$00'
Add-Line 'MSTAT   DB ''T'',''W'','' '',''M'',''O'',''D'',''E'',''='''
Add-Line '        DB ''$'',$00'
Add-Line 'MRES    DB '' '',''R'',''E'',''S'',''='',''$'',$00'
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

$symbolCount = @($lines | Where-Object { $_ -match '^[A-Z][A-Z0-9]*\s+' }).Count
if ($symbolCount -gt 64) {
    throw ("Generated source uses {0} symbols; ASM-F2 limit is 64" -f $symbolCount)
}
if ($PreserveV1Directory) {
    $copyLines = @($lines | Where-Object { $_ -match '^CDIR\s+LDA \$FFB0,X$' })
    if ($copyLines.Count -ne 1) {
        throw 'Generated V1 refresh source is missing its live-directory copy loop'
    }
}

$longSourceLines = @(
    $lines | Where-Object {
        -not $_.StartsWith(';') -and $_.Length -gt 63
    }
)
if ($longSourceLines.Count -ne 0) {
    throw ("Generated source has {0} non-comment lines longer than 63 characters" -f $longSourceLines.Count)
}

$parent = Split-Path -Parent $OutPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

[System.IO.File]::WriteAllLines($OutPath, $lines, [System.Text.Encoding]::ASCII)
Write-Host ("STR8-N topwrite .a    = {0}" -f $OutPath)
Write-Host ("Embedded ROM range    = F000-FFFF")
Write-Host ("Embedded RAM range    = {0}-{1}" -f (Format-HexWord $ImageAddress), (Format-HexWord ($ImageAddress + $Length - 1)))
Write-Host ("Stage RAM range       = {0}-{1}" -f (Format-HexWord $StageAddress), (Format-HexWord ($StageAddress + $Length - 1)))
Write-Host ("FACE ROM/stage address = {0}/{1}" -f (Format-HexWord $str8Id), (Format-HexWord ($StageAddress + $idOffset)))
Write-Host ("Prompt ROM/stage addr  = {0}/{1}" -f (Format-HexWord $str8Prompt), (Format-HexWord ($StageAddress + $promptOffset)))
Write-Host ("V1 directory handling  = {0}" -f $(if ($PreserveV1Directory) { 'preserve live FFB0-FFEF' } else { 'use embedded image bytes' }))
Write-Host ("ASM-F2 symbols/limit   = {0}/64" -f $symbolCount)

param(
    [Parameter(Mandatory = $true)]
    [string]$UpstreamPath,
    [Parameter(Mandatory = $true)]
    [string]$OutPath
)

$ErrorActionPreference = 'Stop'
$text = Get-Content -LiteralPath $UpstreamPath -Raw

if ($text -notmatch 'Kim-1 MicroChess \(c\) 1976-2005 Peter Jennings' -or
    $text -notmatch 'Updated with corrections to earlier OCR errors by Bill Forster') {
    throw 'The input is not the expected corrected Peter Jennings/Daryl Rictor source.'
}

$start = $text.IndexOf(';***********************************************************************')
$body = $text.Substring($start)

# Translate the portable source notation into WDC Tools syntax.  Semantic
# adaptations are applied below and called out in the generated source.
$body = $body -replace '(?im)^\s*cpu\s+65c02\s*$', ''
$body = $body -replace '(?im)^\s*page\s+0,132\s*$', ''
$body = $body -replace '(?im)^\s*\*=\s*\$1000.*$', '                        CODE'
$body = $body -replace '(?im)^\s*\*=\s*\$1580\s*$', ''
$body = $body -replace '(?im)^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)', '$1 EQU $2'
$body = $body -replace '(?im)(^|\s)db\s+', '$1DB              '
$body = $body -replace '(?im)(^|\s)asc\s+', '$1DB              '
$body = $body -replace '#"(.)"', "#'`$1'"

$body = [regex]::Replace($body, '(?s); 6551 I/O Port Addresses.*?; page zero variables', { param($match) @'
; R-YORS AP adaptation
; ---------------------
; AI adaptation notice:
; The R-YORS-specific adaptation was produced with assistance from OpenAI
; Codex, an AI coding system.  Independently review and hardware-verify this
; port before relying on it.  This notice does not alter the upstream
; copyright or license terms above.
;
; The engine and serial board UI are retained.  Device-specific 6551 access
; is replaced by AP-imported HIMON/FTDI services, and Q restores the AP caller's
; hardware stack before returning.  The engine's zero-page placement and
; aliases are semantic: negative STATE indexing relies on 8-bit wraparound.
;
; AP runtime ownership:
;   $0050-$006F  board arrays
;   $00B0-$00FC  engine state/counters
;   $1B00        saved AP caller stack pointer
;   $0100-$01FF  caller stack plus Microchess alternate move stack
;
; engine zero-page variables
'@ })

$moduleHeader = @'
                        CHIP            65C02
                        PW              132

                        MODULE          MICROCHESS_AP
                        XDEF            MICROCHESS
                        XDEF            MICROCHESS_ENGINE_END
                        XDEF            MICROCHESS_IMP_READ
                        XDEF            MICROCHESS_IMP_WRITE_CHAR

'@
$body = $moduleHeader + $body

$body = [regex]::Replace($body, '(?m)^\s*LDA\s+#\$00\s*; REVERSE TOGGLE\s*$', { param($match) @'
MICROCHESS:             TSX
                        STX             CALLER_SP
                        LDA             #$00           ; reverse toggle
'@ })
$body = $body -replace '(?m)^\s*JSR\s+Init_6551\s*$', ''
$body = $body -replace '(?m)^DONE\s+JMP\s+\$FF00.*$', @'
DONE:                   LDX             CALLER_SP
                        TXS
                        LDA             #$AC
                        SEC
                        RTS
'@

# The KIM program reset both stack domains whenever CHESS was re-entered.  An
# AP must preserve the caller's return frame, but it must still discard the
# abandoned JSR GO frame and old permanent-move records on each command cycle.
# Derive SP2 at the original $37-byte separation below the caller's entry SP.
$body = $body -replace '(?ms)^CHESS\s+CLD\s*; INITIALIZE\s*\r?\n\s*LDX\s+#\$FF\s*; TWO STACKS\s*\r?\n\s*TXS\s*\r?\n\s*LDX\s+#\$C8\s*\r?\n\s*STX\s+SP2', @'
CHESS:
                        CLD
                        LDX             CALLER_SP
                        TXS                             ; preserve AP return frame
                        TXA
                        SEC
                        SBC             #$37           ; original $FF/$C8 separation
                        STA             SP2
'@

# Commands no longer pass through the old $4F mask.
$body = $body -replace '(?m)CMP\s+#\$43\s*; \[C\]', "CMP     #'C'            ; [C]"
$body = $body -replace '(?m)CMP\s+#\$45\s*; \[E\]', "CMP     #'E'            ; [E]"
$body = $body -replace '(?m)CMP\s+#\$40\s*; \[P\]', "CMP     #'P'            ; [P]"
$body = $body -replace '(?m)CMP\s+#\$41\s*; \[Q\]', "CMP     #'Q'            ; [Q]"
$body = $body -replace '(?i)BNE\s+NOGO\s+;\s*PLAY CHESS', 'BNE     NOHELP         ; PLAY CHESS'
$body = $body -replace '(?m)^NOGO([ \t]+CMP)', @'
NOHELP                 CMP             #'H'            ; [H]
                        BNE             NOGO
                        JSR             HELP
                        JMP             CHESS
NOGO$1
'@

# The serial board renderer labels this branch as unconditional but the
# upstream source encoded it as BNE and relied on the local output routine
# returning Z from the character in A.  Imported services promise carry and
# register results, not N/Z.  Use the W65C02's explicit unconditional branch.
$body = $body -replace '(?im)^(\s*)BNE(\s+POUT3\s*;\s*branch always)', '$1BRA$2'

$ioStart = $body.IndexOf('; 6551 I/O Support Routines')
$ioDataMatch = [regex]::Match($body.Substring($ioStart), '(?m)^Hexdigdata\s+DB\s+.*\r?\n')
$ioEnd = if ($ioDataMatch.Success) { $ioStart + $ioDataMatch.Index + $ioDataMatch.Length } else { -1 }
if ($ioStart -lt 0 -or $ioEnd -lt 0) { throw 'Could not locate the upstream 6551 routines.' }
$replacementIo = @'
; AP-v2 import adapters. The package loader replaces each $FFFF word.
;
;   MICROCHESS_IMP_READ       <- BIO_FTDI_READ_BYTE_BLOCK (EXEC)
;   MICROCHESS_IMP_WRITE_CHAR <- BIO_FTDI_WRITE_BYTE_BLOCK (EXEC)
;   MICROCHESS_IMP_WRITE_HEX  <- SYS_WRITE_HEX_BYTE (EXEC)
;
syskin:                 DB              $4C
MICROCHESS_IMP_READ:    DW              $FFFF
syschout:               DB              $4C
MICROCHESS_IMP_WRITE_CHAR:
                        DW              $FFFF
syshexout:              DB              $4C
MICROCHESS_IMP_WRITE_HEX:
                        DW              $FFFF

'@
$body = $body.Substring(0, $ioStart) + $replacementIo + $body.Substring($ioEnd)

$kinStart = $body.IndexOf('KIN ')
$kinEnd = $body.IndexOf('; AP-v2 import adapters', $kinStart)
if ($kinStart -lt 0 -or $kinEnd -lt 0) { throw 'Could not locate KIN.' }
$newKin = @'
KIN:                    LDA             #'?'
                        JSR             syschout
                        JSR             syskin
                        AND             #$7F
                        CMP             #'0'
                        BCC             KIN_ALPHA
                        CMP             #'8'
                        BCS             KIN_ALPHA
                        SEC
                        SBC             #'0'
                        RTS
KIN_ALPHA:              CMP             #'a'
                        BCC             KIN_DONE
                        CMP             #'z'+1
                        BCS             KIN_DONE
                        AND             #$DF
KIN_DONE:               RTS
HELP:                   LDX             #$00
HELP_LOOP:              LDA             help_text,X
                        BEQ             HELP_DONE
                        JSR             syschout
                        INX
                        BRA             HELP_LOOP
HELP_DONE:              RTS
;
'@
$body = $body.Substring(0, $kinStart) + $newKin + $body.Substring($kinEnd)

$body = $body -replace '(?m)^banner\s+DB\s+"[^"]*"\s*$', 'banner                  DB              "MicroChess (c) 1976 Peter Jennings benlo.com - R-YORS AP"'
$helpText = @'
help_text               DB              "H Help C New E Reverse P Play 0-7 FROMTO Enter Move Q Quit"
                        DB              $0D,$0A
                        DB              "(c) 1976 Peter Jennings benlo.com"
                        DB              $0D,$0A
                        DB              "R-YORS port AI-assisted with OpenAI Codex; review and hardware-verify."
                        DB              $0D,$0A,$00
'@
$body = [regex]::Replace($body, '(?m)^(banner\s+DB\s+"[^"]*"\s*)$', { param($match)
    $helpText + "`r`n" + $match.Groups[1].Value
})
$body = [regex]::Replace($body, '(?i)\bpout([0-9]*)\b', { param($match) $match.Value.ToUpperInvariant() })
$body = $body -replace '(?m)^; end of file\s*$', @'
MICROCHESS_ENGINE_END:
                        ENDMOD
                        END
; end of file
'@

# Keep the saved caller SP outside the engine's wrap-sensitive zero page.
$body = [regex]::Replace($body, '(?m)^temp\s+EQU.*$', { param($match)
    $match.Value + "`r`nCALLER_SP               EQU             `$1B00"
})

$outDirectory = Split-Path -Parent $OutPath
if ($outDirectory) { New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null }
Set-Content -LiteralPath $OutPath -Value $body -Encoding ascii

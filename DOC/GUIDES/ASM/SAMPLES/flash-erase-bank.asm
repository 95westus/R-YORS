; FLASH-ERASE-BANK.A
; INTERACTIVE BANKED SECTOR ERASE TOOL FOR ASM-F2.
; BOARD-PROVEN 2026-07-10: B1 SINGLE/ALL, B3 8-B, ABORT/REFUSE.
;
; ASSEMBLE WITH FLASH ASM, EXIT SEAL WITH '.', THEN RUN G 3000.
; ENTER BANK 0-3, THEN SECTOR 8-F OR ALL FOR $8000-$FFFF.
; THE TOOL REQUIRES THE EXACT WORD YES BEFORE IT CHANGES FLASH.
;
; USES THE STR8 RAM WORKER THROUGH $F003. EACH 4K STAGING
; IMAGE IS FILLED WITH $FF. PROGRAM-STAGED ERASES AND VERIFIES.
;
; WARNING: THIS DESTROYS THE SELECTED BANK AND SECTOR(S).
; BANK 3 IS LIMITED TO 8-B. C-F HOLD CODE THIS TOOL NEEDS.
;
; STATUS:
;   $1A00 = $AC OK
;   $1A00 = $E0 ABORTED
;   $1A00 = $E1 ERASE/VERIFY FAILED
;   $1A01 = SELECTED OR FAILING SECTOR HIGH BYTE
;   $1A02/$1A03 = STR8 FAIL ADDRESS WHEN AVAILABLE
;   $1A05 = SELECTED BANK

        ORG $3000
        BRA RUN

RUN     STZ $1A00
        STZ $1A01
        STZ $1A02
        STZ $1A03
        STZ $1A04
        STZ $1A05
        LDX #<MTITLE
        LDY #>MTITLE
        JSR PUTS

ASKBANK LDX #<MBANK
        LDY #>MBANK
        JSR PUTS
        JSR READ
        BCS HAVEBANK
        JMP ABORT
HAVEBANK CMP #$00
        BEQ ASKBANK
        JSR PARBANK
        BCS ASK
        LDX #<MBADBANK
        LDY #>MBADBANK
        JSR PUTS
        JMP ASKBANK

ASK     LDX #<MASK
        LDY #>MASK
        JSR PUTS
        JSR READ
        BCS HAVEIN
        JMP ABORT
HAVEIN  CMP #$00
        BEQ ASK
        JSR PARSE
        BCS PARSED
        JMP BAD

PARSED  JSR SAFE
        BCS SELECTED
        LDX #<MUNSAFE
        LDY #>MUNSAFE
        JSR PUTS
        JMP ASK

SELECTED LDA $1A04
        CMP #$08
        BNE WARNONE
        LDX #<MWARNALL
        LDY #>MWARNALL
        JSR PUTS
        JSR PRBANK
        LDX #<MALLRANGE
        LDY #>MALLRANGE
        JSR PUTS
        BRA CONFIRM

WARNONE LDX #<MWARNONE
        LDY #>MWARNONE
        JSR PUTS
        JSR PRBANK
        LDA #':'
        JSR OUT
        JSR PRANGE

CONFIRM LDX #<MCONFIRM
        LDY #>MCONFIRM
        JSR PUTS
        JSR READ
        BCS HAVECONF
        JMP ABORT
HAVECONF JSR ISYES
        BCS ERASEOK
        JMP ABORT

ERASEOK LDX #<MBEGIN
        LDY #>MBEGIN
        JSR PUTS
        JSR FILLFF

NEXT    LDX #<MERASE
        LDY #>MERASE
        JSR PUTS
        JSR PRBANK
        LDA #':'
        JSR OUT
        JSR PRANGE
        LDX #<MDOTS
        LDY #>MDOTS
        JSR PUTS

        LDA $1A05
        STA $1FEF
        LDA $1A01
        STA $1FE9
        LDA #$0A
        STA $1FF6
        LDA #$05
        STA $1FF0
        JSR $F003
        BCC FAIL

        LDX #<MOK
        LDY #>MOK
        JSR PUTS
        DEC $1A04
        BEQ DONE
        LDA $1A01
        CLC
        ADC #$10
        STA $1A01
        BRA NEXT

DONE    STZ $1A01
        LDA #$AC
        STA $1A00
        LDX #<MDONE
        LDY #>MDONE
        JSR PUTS
        JSR PRBANK
        LDX #<MCOMPLETE
        LDY #>MCOMPLETE
        JSR PUTS
        LDA $1A00
        RTS

FAIL    LDA #$E1
        STA $1A00
        LDA $1FEA
        STA $1A02
        LDA $1FEB
        STA $1A03
        LDX #<MFAIL
        LDY #>MFAIL
        JSR PUTS
        LDA $1A03
        JSR HEX
        LDA $1A02
        JSR HEX
        JSR CRLF
        LDA $1A00
        RTS

BAD     LDX #<MBAD
        LDY #>MBAD
        JSR PUTS
        JMP ASK

ABORT   LDA #$E0
        STA $1A00
        LDX #<MABORT
        LDY #>MABORT
        JSR PUTS
        LDA $1A00
        RTS

PARBANK LDA $1A11
        BNE PBBAD
        LDA $1A10
        CMP #'0'
        BCC PBBAD
        CMP #'4'
        BCS PBBAD
        SEC
        SBC #'0'
        STA $1A05
        SEC
        RTS
PBBAD   CLC
        RTS

PARSE   LDA $1A10
        CMP #'A'
        BNE ONE
        LDA $1A11
        CMP #'L'
        BNE ONE
        LDA $1A12
        CMP #'L'
        BNE ONE
        LDA $1A13
        BNE PBAD
        LDA #$80
        STA $1A01
        LDA #$08
        STA $1A04
        SEC
        RTS

ONE     LDA $1A11
        BNE PBAD
        LDA $1A10
        CMP #'8'
        BCC PBAD
        CMP #':'
        BCC PDIGIT
        CMP #'A'
        BCC PBAD
        CMP #'G'
        BCS PBAD
        SEC
        SBC #$37
        BRA PSHIFT

PDIGIT  SEC
        SBC #'0'
PSHIFT  ASL A
        ASL A
        ASL A
        ASL A
        STA $1A01
        LDA #$01
        STA $1A04
        SEC
        RTS
PBAD    CLC
        RTS

SAFE    LDA $1A05
        CMP #$03
        BNE SAFEOK
        LDA $1A04
        CMP #$08
        BEQ SAFEBAD
        LDA $1A01
        CMP #$C0
        BCS SAFEBAD
SAFEOK  SEC
        RTS
SAFEBAD CLC
        RTS

ISYES   LDA $1A10
        CMP #'Y'
        BNE NYES
        LDA $1A11
        CMP #'E'
        BNE NYES
        LDA $1A12
        CMP #'S'
        BNE NYES
        LDA $1A13
        BNE NYES
        SEC
        RTS
NYES    CLC
        RTS

FILLFF  STZ $CA
        LDA #$0A
        STA $CB
FPAGE   LDY #$00
        LDA #$FF
FBYTE   STA ($CA),Y
        INY
        BNE FBYTE
        INC $CB
        LDA $CB
        CMP #$1A
        BNE FPAGE
        RTS

PRANGE  LDA #'$'
        JSR OUT
        LDA $1A01
        JSR HEX
        LDA #'0'
        JSR OUT
        LDA #'0'
        JSR OUT
        LDA #'-'
        JSR OUT
        LDA #'$'
        JSR OUT
        LDA $1A01
        CLC
        ADC #$0F
        JSR HEX
        LDA #'F'
        JSR OUT
        LDA #'F'
        JSR OUT
        RTS

PRBANK  LDA $1A05
        CLC
        ADC #'0'
        JMP OUT

HEX     PHA
        LSR A
        LSR A
        LSR A
        LSR A
        JSR NIB
        PLA
        AND #$0F
NIB     CMP #$0A
        BCC NDIG
        CLC
        ADC #$37
        BRA OUT
NDIG    CLC
        ADC #'0'
OUT     JMP BIO_FTDI_WRITE_BYTE_BLOCK

READ    LDX #$10
        LDY #$1A
        JMP SYS_READ_CSTRING_ECHO_UPPER

PUTS    JMP BIO_FTDI_PUT_CSTR

CRLF    LDA #$0D
        JSR OUT
        LDA #$0A
        JMP OUT

MTITLE  DB $0D,$0A,'B','A','N','K','E','D',' '
        DB 'F','L','A','S','H'
        DB ' ','E','R','A','S','E',$0D,$0A,0
MBANK   DB 'B','A','N','K',' ','0','-','3','>',' ',0
MASK    DB 'S','E','C','T','O','R',' ','8','-','F',' ','O','R'
        DB ' ','A','L','L','>',' ',0
MWARNALL DB $0D,$0A,'W','A','R','N','I','N','G',':',' '
        DB 'E','R','A','S','E',' ','B',0
MALLRANGE DB ' ','$','8','0','0','0','-','$','F','F','F','F'
        DB $0D,$0A,0
MWARNONE DB $0D,$0A,'W','A','R','N','I','N','G',':',' '
        DB 'E','R','A','S','E',' ','B',0
MCONFIRM DB $0D,$0A,'T','Y','P','E',' ','Y','E','S',' ','T','O'
        DB ' ','E','R','A','S','E','>',' ',0
MBEGIN  DB $0D,$0A,'B','E','G','I','N',$0D,$0A,0
MERASE  DB 'E','R','A','S','E',' ','B',0
MDOTS   DB ' ','.','.','.',' ',0
MOK     DB 'O','K',$0D,$0A,0
MFAIL   DB 'F','A','I','L',' ','A','T',' ','$',0
MDONE   DB 'B','A','N','K',' ',0
MCOMPLETE DB ' ','E','R','A','S','E',' '
        DB 'C','O','M','P','L','E','T','E',$0D,$0A,0
MBAD    DB '?',' ','E','N','T','E','R',' ','8','-','F'
        DB ' ','O','R'
        DB ' ','A','L','L',$0D,$0A,0
MBADBANK DB '?',' ','E','N','T','E','R',' ','B','A','N','K'
        DB ' ','0','-','3',$0D,$0A,0
MUNSAFE DB '?',' ','B','3',' ','A','L','L','O','W','S',' '
        DB 'O','N','L','Y',' ','8','-','B',$0D,$0A,0
MABORT  DB 'A','B','O','R','T',' ','-',' ','N','O',' '
        DB 'F','L','A','S','H'
        DB ' ','W','R','I','T','E',$0D,$0A,0

        END

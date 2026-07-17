; ASM V1 BIORHYTHM-STYLE PHASE CHART. PASTE VIA FLASH ASM.
; RUN G 2000. TYPE DAY 0-255, Q OR . TO QUIT.
; USES RJOIN PUT_CSTR, READ_LINE, AND WRITE_BYTE ROUTINES.
; P/E/I PERIODS ARE 23/28/33; * IS DAY MOD PERIOD, | IS MIDPOINT.

        ORG $2000

        JMP MAIN

MTITLE  DB $0D,$0A,'B','I','O','R','H','Y','T','H','M'
        DB $0D,$0A,0
MPROMPT DB 'D','A','Y',' ','0','-','2','5','5',' ','O','R'
        DB ' ','Q','>',' ',0
MBAD    DB $0D,$0A,'?',$0D,$0A,0
MBYE    DB $0D,$0A,'B','Y','E',$0D,$0A,0
MDAY    DB $0D,$0A,'D','A','Y',' ','$',0
MP      DB 'P',' ',0
ME      DB 'E',' ',0
MI      DB 'I',' ',0
MCR     DB $0D,$0A,0

OUTA    JMP BIO_FTDI_WRITE_BYTE_BLOCK

CRLF    LDX #<MCR
        LDY #>MCR
        JMP BIO_FTDI_PUT_CSTR

NIB     CMP #$0A
        BCS .HEX
        CLC
        ADC #'0'
        JMP OUTA
.HEX    CLC
        ADC #$37
        JMP OUTA

HEX     PHA
        LSR A
        LSR A
        LSR A
        LSR A
        JSR NIB
        PLA
        AND #$0F
        JMP NIB

MOD     LDA $33
.LOOP   CMP $34
        BCC .DONE
        SEC
        SBC $34
        STA $33
        BRA .LOOP
.DONE   RTS

GRAPH   STZ $37
.LOOP   LDX $37
        LDA #'.'
        CPX $35
        BNE .NBAR
        LDA #'|'
.NBAR   CPX $33
        BNE .OUT
        LDA #'*'
.OUT    JSR OUTA
        INC $37
        LDA $37
        CMP $34
        BNE .LOOP
        JMP CRLF

CYCLE   LDA $30
        STA $33
        JSR MOD
        LDA $33
        CMP $35
        BCC .PLUS
        BEQ .ZERO
        LDA #'-'
        BRA .SIGN
.PLUS   LDA #'+'
        BRA .SIGN
.ZERO   LDA #'0'
.SIGN   JSR OUTA
        LDA #' '
        JSR OUTA
        JMP GRAPH

PHYS    LDX #<MP
        LDY #>MP
        JSR BIO_FTDI_PUT_CSTR
        LDA #$17
        STA $34
        LDA #$0B
        STA $35
        JMP CYCLE

EMOT    LDX #<ME
        LDY #>ME
        JSR BIO_FTDI_PUT_CSTR
        LDA #$1C
        STA $34
        LDA #$0E
        STA $35
        JMP CYCLE

INTEL   LDX #<MI
        LDY #>MI
        JSR BIO_FTDI_PUT_CSTR
        LDA #$21
        STA $34
        LDA #$10
        STA $35
        JMP CYCLE

RUN     LDX #<MDAY
        LDY #>MDAY
        JSR BIO_FTDI_PUT_CSTR
        LDA $30
        JSR HEX
        JSR CRLF
        JSR PHYS
        JSR EMOT
        JSR INTEL
        RTS

PARSE   STZ $30
        STZ $32
        LDX #$00
.LOOP   LDA $2600,X
        BEQ .DONE
        CMP #'0'
        BCC .DONE
        CMP #':'
        BCS .DONE
        SEC
        SBC #'0'
        STA $31
        LDA $30
        CMP #$1A
        BCS .BAD
        CMP #$19
        BNE .MUL
        LDA $31
        CMP #$06
        BCS .BAD
.MUL    LDA $30
        ASL A
        STA $36
        ASL A
        ASL A
        CLC
        ADC $36
        CLC
        ADC $31
        STA $30
        INC $32
        INX
        CPX #$03
        BNE .LOOP
.DONE   LDA $32
        BEQ .BAD
        SEC
        RTS
.BAD    CLC
        RTS

DONE    LDX #<MBYE
        LDY #>MBYE
        JSR BIO_FTDI_PUT_CSTR
        RTS

MAIN    LDX #<MTITLE
        LDY #>MTITLE
        JSR BIO_FTDI_PUT_CSTR
.LOOP   LDX #<MPROMPT
        LDY #>MPROMPT
        JSR BIO_FTDI_PUT_CSTR
        LDX #$00
        LDY #$26
        JSR SYS_READ_CSTRING_ECHO_UPPER
        BCC .LOOP
        LDA $2600
        BEQ .LOOP
        CMP #'Q'
        BEQ DONE
        CMP #'.'
        BEQ DONE
        JSR PARSE
        BCC .BAD
        JSR RUN
        BRA .LOOP
.BAD    LDX #<MBAD
        LDY #>MBAD
        JSR BIO_FTDI_PUT_CSTR
        BRA .LOOP

        ORG $2600
        DS $40

        END

; ASM V1 RJOIN HASH STATS. PASTE VIA ASM RT PASTE.
; RUN G 7200. TYPE Q OR . TO QUIT.

        ORG $7200
MTIT    EQU $7500
MP      EQU $7515
MSGL    EQU $751C
MSGX    EQU $7523
MSGH    EQU $7529
MCR     EQU $752F
MBYE    EQU $7532
BUF     EQU $7600
LEN     EQU $30
XSUM    EQU $31
IDX     EQU $32

MAIN    LDX #<MTIT
        LDY #>MTIT
        JSR BIO_FTDI_PUT_CSTR
.LOOP   LDX #<MP
        LDY #>MP
        JSR BIO_FTDI_PUT_CSTR
        LDX #<BUF
        LDY #>BUF
        JSR SYS_READ_CSTRING_ECHO_UPPER
        BCC .LOOP
        LDA BUF
        BEQ .BLANK
        CMP #'Q'
        BEQ DONE
        CMP #'.'
        BEQ DONE
        JSR HASH
        JSR SHOW
        BRA .LOOP
.BLANK  BRA .LOOP

DONE    LDX #<MBYE
        LDY #>MBYE
        JSR BIO_FTDI_PUT_CSTR
        RTS

HASH    STZ LEN
        STZ XSUM
        JSR FNV1A_INIT
        LDX #$00
.LOOP   LDA BUF,X
        BEQ .DONE
        STX IDX
        JSR FNV1A_UPDATE_A_FAST
        LDX IDX
        LDA BUF,X
        EOR XSUM
        STA XSUM
        INC LEN
        INX
        CPX #$3F
        BNE .LOOP
.DONE   RTS

NIB     CMP #$0A
        BCC .DIG
        CLC
        ADC #$37
        BRA .OUT
.DIG    CLC
        ADC #'0'
.OUT    JSR BIO_FTDI_WRITE_BYTE_BLOCK
        RTS

HEX     PHA
        LSR A
        LSR A
        LSR A
        LSR A
        JSR NIB
        PLA
        AND #$0F
        JMP NIB

SHOW    LDX #<MSGL
        LDY #>MSGL
        JSR BIO_FTDI_PUT_CSTR
        LDA LEN
        JSR HEX
        LDX #<MSGX
        LDY #>MSGX
        JSR BIO_FTDI_PUT_CSTR
        LDA XSUM
        JSR HEX
        LDX #<MSGH
        LDY #>MSGH
        JSR BIO_FTDI_PUT_CSTR
        LDA $B3
        JSR HEX
        LDA $B2
        JSR HEX
        LDA $B1
        JSR HEX
        LDA $B0
        JSR HEX
        LDX #<MCR
        LDY #>MCR
        JSR BIO_FTDI_PUT_CSTR
        RTS

        ORG $7500
        DB $0D,$0A,'R','J','O','I','N',' '
        DB 'H','A','S','H',' ','S','T','A','T','S'
        DB $0D,$0A,0
        DB 'T','E','X','T','>',' ',0
        DB $0D,$0A,'L','E','N','=',0
        DB ' ','X','O','R','=',0
        DB ' ','F','N','V','=',0
        DB $0D,$0A,0
        DB $0D,$0A,'B','Y','E',$0D,$0A,0

        ORG $7600
        DS $40

        END

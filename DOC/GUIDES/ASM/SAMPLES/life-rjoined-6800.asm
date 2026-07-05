; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
; RUN G 2000. N OR SPACE=NEXT, R=RANDOM, Q=QUIT.
; RANDOM SEED STIRS WHILE WAITING FOR A KEY.
; USES RJOIN PIN READ AND BIO WRITE BYTE ROUTINES.
; USES USER ZERO-PAGE $30-$3B.
; COMPUTES NEIGHBORS; NO TABLE ORG.
; FLASH ASM PROTECTS $6000-$7EFF.

        ORG $2000

        JMP MAIN

CRLF    LDA #$0D
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$0A
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        RTS

INIT    LDX #$00
ILOOP   STZ $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE ILOOP
        LDA #$01
        STA $7801
        STA $780A
        STA $7810
        STA $7811
        STA $7812
        LDA #$A5
        STA $34
        STZ $35
        RTS

COPY    LDX #$00
CLOOP   LDA $7840,X
        STA $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE CLOOP
        INC $35
        RTS

REND    JSR CRLF
        LDA #'G'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA $35
        CLC
        ADC #'0'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        JSR CRLF
        LDX #$00
        STX $30
        LDA #$08
        STA $31
RROW    LDA #$08
        STA $32
RCOL    LDX $30
        LDA $7800,X
        BEQ RDEAD
        LDA #'#'
        BRA RPUT
RDEAD   LDA #'.'
RPUT    JSR BIO_FTDI_WRITE_BYTE_BLOCK
        INC $30
        DEC $32
        BNE RCOL
        JSR CRLF
        DEC $31
        BNE RROW
        RTS

STEP    LDX #$00
SLOOP   STZ $33
        TXA
        AND #$38
        STA $36
        TXA
        AND #$07
        STA $37
        LDA $36
        SEC
        SBC #$08
        AND #$38
        STA $38
        LDA $36
        CLC
        ADC #$08
        AND #$38
        STA $39
        LDA $37
        SEC
        SBC #$01
        AND #$07
        STA $3A
        LDA $37
        CLC
        ADC #$01
        AND #$07
        STA $3B
        CLC
        LDA $38
        ORA $3A
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $38
        ORA $37
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $38
        ORA $3B
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $36
        ORA $3A
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $36
        ORA $3B
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $39
        ORA $3A
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $39
        ORA $37
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $39
        ORA $3B
        TAY
        LDA $33
        ADC $7800,Y
        STA $33
        LDA $7800,X
        BEQ BORN
        LDA $33
        CMP #$02
        BEQ LIVE
        CMP #$03
        BEQ LIVE
        LDA #$00
        BRA STORE
BORN    LDA $33
        CMP #$03
        BEQ LIVE
        LDA #$00
        BRA STORE
LIVE    LDA #$01
STORE   STA $7840,X
        INX
        CPX #$40
        BEQ SDONE
        JMP SLOOP
SDONE   RTS

PROMPT  JSR CRLF
        LDA #'N'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #'/'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #'R'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #'/'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #'Q'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #'>'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #' '
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        RTS

RAND    LDX #$00
RLOOP   JSR RAND8
        AND #$03
        BEQ RON
        LDA #$00
        BRA RSTORE
RON     LDA #$01
RSTORE  STA $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE RLOOP
        STZ $35
        RTS

RAND8   LDA $34
        ASL A
        BCC R8S
        EOR #$1D
R8S     STA $34
        RTS

MAIN    JSR INIT
        JSR REND
LOOP    JSR PROMPT
GETKEY  INC $34
        JSR PIN_FTDI_READ_BYTE_NONBLOCK
        BCC GETKEY
        AND #$7F
        CMP #$0D
        BEQ GETKEY
        CMP #$0A
        BEQ GETKEY
        CMP #$20
        BEQ NEXTC
        AND #$DF
        CMP #'Q'
        BEQ DONE
        CMP #'R'
        BEQ RANDC
        CMP #'N'
        BEQ NEXTC
        BRA LOOP
RANDC   JSR RAND
        JSR REND
        BRA LOOP
NEXTC   JSR STEP
        JSR COPY
        JSR REND
        BRA LOOP
DONE    RTS

        END

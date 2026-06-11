; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
; RUN G 2000. N OR SPACE=NEXT, R=RANDOM, Q=QUIT.
; RANDOM SEED STIRS WHILE WAITING FOR A KEY.
; USES RJOIN PIN READ AND BIO WRITE BYTE ROUTINES.

        ORG $2000

        JMP MAIN

CRLF    LDA #$0D
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$0A
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        RTS

INIT    LDX #$00
ILOOP   LDA $7200,X
        STA $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE ILOOP
        LDA #$A5
        STA $D4
        STZ $D5
        RTS

COPY    LDX #$00
CLOOP   LDA $7840,X
        STA $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE CLOOP
        INC $D5
        RTS

REND    JSR CRLF
        LDA #'G'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA $D5
        CLC
        ADC #'0'
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        JSR CRLF
        LDX #$00
        STX $D0
        LDA #$08
        STA $D1
RROW    LDA #$08
        STA $D2
RCOL    LDX $D0
        LDY $7800,X
        LDA $7240,Y
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        INC $D0
        DEC $D2
        BNE RCOL
        JSR CRLF
        DEC $D1
        BNE RROW
        RTS

STEP    LDX #$00
SLOOP   STZ $D3
        CLC
        LDY $7000,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $7040,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $7080,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $70C0,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $7100,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $7140,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $7180,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDY $71C0,X
        LDA $D3
        ADC $7800,Y
        STA $D3
        LDA $7800,X
        BEQ BORN
        LDA $D3
        CMP #$02
        BEQ LIVE
        CMP #$03
        BEQ LIVE
        LDA #$00
        BRA STORE
BORN    LDA $D3
        CMP #$03
        BEQ LIVE
        LDA #$00
        BRA STORE
LIVE    LDA #$01
STORE   STA $7840,X
        INX
        CPX #$40
        BNE SLOOP
        RTS

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
        TAY
        LDA $7242,Y
        STA $7800,X
        STZ $7840,X
        INX
        CPX #$40
        BNE RLOOP
        STZ $D5
        RTS

RAND8   LDA $D4
        ASL A
        BCC R8S
        EOR #$1D
R8S     STA $D4
        RTS

MAIN    JSR INIT
        JSR REND
LOOP    JSR PROMPT
GETKEY  INC $D4
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

        ORG $7000
        DB $3F,$38,$39,$3A,$3B,$3C,$3D,$3E
        DB $07,$00,$01,$02,$03,$04,$05,$06
        DB $0F,$08,$09,$0A,$0B,$0C,$0D,$0E
        DB $17,$10,$11,$12,$13,$14,$15,$16
        DB $1F,$18,$19,$1A,$1B,$1C,$1D,$1E
        DB $27,$20,$21,$22,$23,$24,$25,$26
        DB $2F,$28,$29,$2A,$2B,$2C,$2D,$2E
        DB $37,$30,$31,$32,$33,$34,$35,$36
        DB $38,$39,$3A,$3B,$3C,$3D,$3E,$3F
        DB $00,$01,$02,$03,$04,$05,$06,$07
        DB $08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        DB $10,$11,$12,$13,$14,$15,$16,$17
        DB $18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        DB $20,$21,$22,$23,$24,$25,$26,$27
        DB $28,$29,$2A,$2B,$2C,$2D,$2E,$2F
        DB $30,$31,$32,$33,$34,$35,$36,$37
        DB $39,$3A,$3B,$3C,$3D,$3E,$3F,$38
        DB $01,$02,$03,$04,$05,$06,$07,$00
        DB $09,$0A,$0B,$0C,$0D,$0E,$0F,$08
        DB $11,$12,$13,$14,$15,$16,$17,$10
        DB $19,$1A,$1B,$1C,$1D,$1E,$1F,$18
        DB $21,$22,$23,$24,$25,$26,$27,$20
        DB $29,$2A,$2B,$2C,$2D,$2E,$2F,$28
        DB $31,$32,$33,$34,$35,$36,$37,$30
        DB $07,$00,$01,$02,$03,$04,$05,$06
        DB $0F,$08,$09,$0A,$0B,$0C,$0D,$0E
        DB $17,$10,$11,$12,$13,$14,$15,$16
        DB $1F,$18,$19,$1A,$1B,$1C,$1D,$1E
        DB $27,$20,$21,$22,$23,$24,$25,$26
        DB $2F,$28,$29,$2A,$2B,$2C,$2D,$2E
        DB $37,$30,$31,$32,$33,$34,$35,$36
        DB $3F,$38,$39,$3A,$3B,$3C,$3D,$3E
        DB $01,$02,$03,$04,$05,$06,$07,$00
        DB $09,$0A,$0B,$0C,$0D,$0E,$0F,$08
        DB $11,$12,$13,$14,$15,$16,$17,$10
        DB $19,$1A,$1B,$1C,$1D,$1E,$1F,$18
        DB $21,$22,$23,$24,$25,$26,$27,$20
        DB $29,$2A,$2B,$2C,$2D,$2E,$2F,$28
        DB $31,$32,$33,$34,$35,$36,$37,$30
        DB $39,$3A,$3B,$3C,$3D,$3E,$3F,$38
        DB $0F,$08,$09,$0A,$0B,$0C,$0D,$0E
        DB $17,$10,$11,$12,$13,$14,$15,$16
        DB $1F,$18,$19,$1A,$1B,$1C,$1D,$1E
        DB $27,$20,$21,$22,$23,$24,$25,$26
        DB $2F,$28,$29,$2A,$2B,$2C,$2D,$2E
        DB $37,$30,$31,$32,$33,$34,$35,$36
        DB $3F,$38,$39,$3A,$3B,$3C,$3D,$3E
        DB $07,$00,$01,$02,$03,$04,$05,$06
        DB $08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        DB $10,$11,$12,$13,$14,$15,$16,$17
        DB $18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        DB $20,$21,$22,$23,$24,$25,$26,$27
        DB $28,$29,$2A,$2B,$2C,$2D,$2E,$2F
        DB $30,$31,$32,$33,$34,$35,$36,$37
        DB $38,$39,$3A,$3B,$3C,$3D,$3E,$3F
        DB $00,$01,$02,$03,$04,$05,$06,$07
        DB $09,$0A,$0B,$0C,$0D,$0E,$0F,$08
        DB $11,$12,$13,$14,$15,$16,$17,$10
        DB $19,$1A,$1B,$1C,$1D,$1E,$1F,$18
        DB $21,$22,$23,$24,$25,$26,$27,$20
        DB $29,$2A,$2B,$2C,$2D,$2E,$2F,$28
        DB $31,$32,$33,$34,$35,$36,$37,$30
        DB $39,$3A,$3B,$3C,$3D,$3E,$3F,$38
        DB $01,$02,$03,$04,$05,$06,$07,$00

        ORG $7200
        DB $00,$01,$00,$00,$00,$00,$00,$00
        DB $00,$00,$01,$00,$00,$00,$00,$00
        DB $01,$01,$01,$00,$00,$00,$00,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00

        ORG $7240
        DB $2E,$23
        DB $01,$00,$00,$00

        END

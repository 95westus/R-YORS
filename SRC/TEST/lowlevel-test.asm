                        XREF            PIN_FTDI_WRITE_BYTE_NONBLOCK
                        XREF            PIN_FTDI_INIT
                        XREF            PIN_FTDI_POLL_RX_READY
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_FLUSH_RX
                        XREF            BIO_FTDI_POLL_RX_READY
                        XREF            UTL_HEX_BYTE_TO_ASCII_YX
                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX


                        XREF            PIN_FTDI_CHECK_ENUMERATED


START:
                        lda #'A'
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
;                        BRK 00
                        lda #$0A
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #'B'
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #$0D
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #'C'
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        jsr PIN_FTDI_INIT
                        jsr BIG_DELAY

                        lda #'?'
?LOOP:
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        jsr MID_DELAY
                        jsr PIN_FTDI_POLL_RX_READY
                        bcc ?LOOP
                        JSR PIN_FTDI_READ_BYTE_NONBLOCK
                        PHA
                        LDA #'D'
                        JSR PIN_FTDI_WRITE_BYTE_NONBLOCK
                        PLA
                        JSR PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #$0D
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #$0A
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        jsr BIG_DELAY

                        LDA #'E'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK

                        JSR CRLF
?LOOP2:                 lda #'?'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC ?LOOP2
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR CRLF
                        LDA #'F'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR CRLF
                        LDA #'?'
                        JSR BIO_FTDI_READ_BYTE_BLOCK
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR CRLF   
                        JSR BIO_FTDI_FLUSH_RX
;                        BRK 01
                        JSR BIG_DELAY
                        JSR BIO_FTDI_FLUSH_RX
;                        BRK 02
                        LDA #'?'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR BIG_DELAY
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
?LOOP3:
                        jsr BIO_FTDI_POLL_RX_READY
                        BCC ?MINUS
?PLUS:                  LDA #'+'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR BIO_FTDI_READ_BYTE_BLOCK
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR CRLF
                        BRA ?around
?MINUS:                 LDA #'-'
                        JSR BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR MID_DELAY
                        BRA ?LOOP3
?around:                jsr CRLF
                        lda #'?'
                        jsr BIO_FTDI_WRITE_BYTE_BLOCK
                        jsr BIO_FTDI_READ_BYTE_BLOCK
                        jsr BIO_FTDI_WRITE_BYTE_BLOCK
                        jsr UTL_HEX_BYTE_TO_ASCII_YX
                        TYA 
                        jsr BIO_FTDI_WRITE_BYTE_BLOCK
                        TXA 
                        jsr BIO_FTDI_WRITE_BYTE_BLOCK
                        lda #'?'
                        jsr BIO_FTDI_WRITE_BYTE_BLOCK
                        jsr CRLF 
                        jsr COR_FTDI_INIT
                        jsr BIG_DELAY
                        jsr COR_FTDI_FLUSH_RX
                        brk $ff

                        wai



                        







CRLF:                   PHA
                        lda #$0D
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        lda #$0A
                        jsr PIN_FTDI_WRITE_BYTE_NONBLOCK
                        PLA
                        RTS 


SMALL_DELAY:            PHY
                        PHX
                        LDY #$FF
?DELAY_Y:               LDX #$FF
?DELAY_X:               DEX
                        BNE ?DELAY_X
                        DEY
                        BNE ?DELAY_Y
                        PLX
                        PLY
                        RTS

MID_DELAY:
                        PHX
                        PHY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY
                        JSR SMALL_DELAY


                        PLY
                        PLX
                        RTS

BIG_DELAY:              JSR MID_DELAY
                        JSR MID_DELAY

                        RTS


; ASM v1 paste sample for ASM RT PASTE.
; Run with G 7000. Lines echo back after "=> ".
; Type Q or . to return to HIMON.

        ORG $7000
LINE    EQU $7100

        BRA MAIN
DONE    RTS

MAIN    LDA #$3F
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$20
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDX #<LINE
        LDY #>LINE
        JSR SYS_READ_CSTRING_ECHO_UPPER
        BCC MAIN
        BEQ MAIN
        LDA LINE
        EOR #'Q'
        BEQ DONE
        LDA LINE
        EOR #'.'
        BEQ DONE
        LDA #$3D
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$3E
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$20
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDX #0
ECHO    LDA LINE,X
        BNE OUT
        LDA #$0D
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        LDA #$0A
        JSR BIO_FTDI_WRITE_BYTE_BLOCK
        BRA MAIN
OUT     JSR BIO_FTDI_WRITE_BYTE_BLOCK
        INX
        BRA ECHO

        END

; ----------------------------------------------------------------------------
; W65C02S mnemonic/operand print helpers for debug output.
; ----------------------------------------------------------------------------

DIS_PRINT_MNEM_ID:
                        SEC
                        SBC             #$01
                        STA             DBG_TMP_INDEX
                        STZ             CMDP_START_HI
                        ASL             A
                        ROL             CMDP_START_HI
                        ASL             A
                        ROL             CMDP_START_HI
                        CLC
                        ADC             #<ASM_MNEM_NAMES
                        STA             CMDP_START_LO
                        LDA             CMDP_START_HI
                        ADC             #>ASM_MNEM_NAMES
                        STA             CMDP_START_HI

                        LDY             #$00
DIS_PRINT_MNEM_LOOP:
                        LDA             (CMDP_START_LO),Y
                        PHA
                        AND             #$7F
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        PLA
                        BMI             DIS_PRINT_MNEM_DONE
                        INY
                        CPY             #$04
                        BCC             DIS_PRINT_MNEM_LOOP
DIS_PRINT_MNEM_DONE:
                        RTS

DIS_WRITE_SPACE:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

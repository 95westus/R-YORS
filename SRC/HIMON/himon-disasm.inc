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

DIS_PRINT_OPER_MODE:
                        CMP             #ASM_MODE_IMPL
                        BEQ             DIS_OPER_DONE
                        CMP             #ASM_MODE_ACC
                        BEQ             DIS_OPER_ACC
                        CMP             #ASM_MODE_IMM
                        BEQ             DIS_OPER_IMM
                        CMP             #ASM_MODE_ZP
                        BEQ             DIS_OPER_ZP
                        CMP             #ASM_MODE_ZPX
                        BEQ             DIS_OPER_ZPX
                        CMP             #ASM_MODE_ZPY
                        BEQ             DIS_OPER_ZPY
                        CMP             #ASM_MODE_ZPX_IND
                        BEQ             DIS_OPER_ZPX_IND
                        CMP             #ASM_MODE_ZP_IND
                        BEQ             DIS_OPER_ZP_IND
                        CMP             #ASM_MODE_ZP_IND_Y
                        BEQ             DIS_OPER_ZP_IND_Y_J
                        CMP             #ASM_MODE_ABS
                        BEQ             DIS_OPER_ABS_J
                        CMP             #ASM_MODE_ABSX
                        BEQ             DIS_OPER_ABSX_J
                        CMP             #ASM_MODE_ABSY
                        BEQ             DIS_OPER_ABSY_J
                        CMP             #ASM_MODE_ABS_IND
                        BEQ             DIS_OPER_ABS_IND_J
                        CMP             #ASM_MODE_ABSX_IND
                        BEQ             DIS_OPER_ABSX_IND_J
                        CMP             #ASM_MODE_REL
                        BEQ             DIS_OPER_REL
                        CMP             #ASM_MODE_ZP_REL
                        BEQ             DIS_OPER_ZP_REL_J
                        CMP             #ASM_MODE_BRK
                        BEQ             DIS_OPER_BRK
                        BRA             DIS_OPER_DONE
DIS_OPER_ABS_J:         JMP             DIS_OPER_ABS
DIS_OPER_ABSX_J:        JMP             DIS_OPER_ABSX
DIS_OPER_ABSY_J:        JMP             DIS_OPER_ABSY
DIS_OPER_ABS_IND_J:     JMP             DIS_OPER_ABS_IND
DIS_OPER_ABSX_IND_J:    JMP             DIS_OPER_ABSX_IND
DIS_OPER_ZP_REL_J:      JMP             DIS_OPER_ZP_REL
DIS_OPER_ZP_IND_Y_J:    JMP             DIS_OPER_ZP_IND_Y
DIS_OPER_DONE:
                        RTS

DIS_OPER_ACC:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'A'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_OPER_IMM:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'#'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_BYTE_OPER
                        RTS

DIS_OPER_ZP:
DIS_OPER_REL:
DIS_OPER_BRK:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_BYTE_OPER
                        RTS

DIS_OPER_ZPX:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_BYTE_OPER
                        JMP             DIS_WRITE_COMMA_X

DIS_OPER_ZPY:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_BYTE_OPER
                        JMP             DIS_WRITE_COMMA_Y

DIS_OPER_ZPX_IND:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'('
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_BYTE_OPER
                        JSR             DIS_WRITE_COMMA_X
                        LDA             #')'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_OPER_ZP_IND:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'('
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_BYTE_OPER
                        LDA             #')'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_OPER_ZP_IND_Y:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'('
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_BYTE_OPER
                        LDA             #')'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JMP             DIS_WRITE_COMMA_Y

DIS_OPER_ABS:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_ABS_OPER
                        RTS

DIS_OPER_ABSX:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_ABS_OPER
                        JMP             DIS_WRITE_COMMA_X

DIS_OPER_ABSY:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_ABS_OPER
                        JMP             DIS_WRITE_COMMA_Y

DIS_OPER_ABS_IND:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'('
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_ABS_OPER
                        LDA             #')'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_OPER_ABSX_IND:
                        JSR             DIS_WRITE_SPACE
                        LDA             #'('
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             DIS_PRINT_ABS_OPER
                        JSR             DIS_WRITE_COMMA_X
                        LDA             #')'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_OPER_ZP_REL:
                        JSR             DIS_WRITE_SPACE
                        JSR             DIS_PRINT_BYTE_OPER
                        LDA             #','
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$02
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

DIS_WRITE_SPACE:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_WRITE_COMMA_X:
                        LDA             #','
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'X'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_WRITE_COMMA_Y:
                        LDA             #','
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'Y'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

DIS_PRINT_BYTE_OPER:
                        LDA             #'$'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$01
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

DIS_PRINT_ABS_OPER:
                        LDA             #'$'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$02
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDY             #$01
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

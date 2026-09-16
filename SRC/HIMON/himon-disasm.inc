; ----------------------------------------------------------------------------
; W65C02S mnemonic print helpers for debug output.
; ----------------------------------------------------------------------------

; Private input: A = nonzero ASM_OP_MNEM_ID, DBG_TMP_OPCODE = source opcode.
; Names are three plain ASCII bytes; bit-operation IDs append opcode bits 4..6.
; Clobbers A/X/Y, flags, and DBG_TMP_INDEX. BIO preserves the loop's X/Y.
DIS_PRINT_MNEM_ID:
                        SEC
                        SBC             #$01
                        STA             DBG_TMP_INDEX
                        ASL             A
                        CLC
                        ADC             DBG_TMP_INDEX
                        TAX

                        LDY             #$03
DIS_PRINT_MNEM_LOOP:
                        LDA             ASM_MNEM_NAMES,X
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INX
                        DEY
                        BNE             DIS_PRINT_MNEM_LOOP
                        LDA             DBG_TMP_INDEX
                        CMP             #ASM_MNEM_NORMAL_COUNT
                        BCC             DIS_PRINT_MNEM_DONE
                        LDA             DBG_TMP_OPCODE
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        AND             #$07
                        ORA             #'0'
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK
DIS_PRINT_MNEM_DONE:
                        RTS

DIS_WRITE_SPACE:
                        LDA             #' '
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

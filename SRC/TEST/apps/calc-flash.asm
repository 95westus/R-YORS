; ----------------------------------------------------------------------------
; calc-flash.asm
; Tiny flash-resident FNV command test image, linked at $9A00.
;   $9A00-$9A07: FNV record for command CALC
;   $9A08:       command entry point
; ----------------------------------------------------------------------------

                        MODULE          CALC_FLASH_APP

                        XDEF            START

                        XREF            SYS_READ_CHAR_ECHO
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            UTL_HEX_ASCII_YX_TO_BYTE

CALC_A                  EQU             $E2
CALC_B                  EQU             $E3
CALC_OP                 EQU             $E4
CALC_RESULT             EQU             $E5

                        CODE

CALC_FNV:
                        DB              'F','N',('V'+$80),$14,$63,$43,$BA,$00
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             CALC_PRINT_LINE

CALC_LOOP:
                        LDX             #<MSG_A
                        LDY             #>MSG_A
                        JSR             CALC_PRINT
                        JSR             CALC_READ_HEX_BYTE
                        BCC             CALC_BAD
                        STA             CALC_A

                        LDX             #<MSG_OP
                        LDY             #>MSG_OP
                        JSR             CALC_PRINT
                        JSR             SYS_READ_CHAR_ECHO
                        STA             CALC_OP
                        JSR             SYS_WRITE_CRLF
                        CMP             #'Q'
                        BEQ             CALC_DONE

                        LDX             #<MSG_B
                        LDY             #>MSG_B
                        JSR             CALC_PRINT
                        JSR             CALC_READ_HEX_BYTE
                        BCC             CALC_BAD
                        STA             CALC_B

                        LDA             CALC_OP
                        CMP             #'+'
                        BEQ             CALC_ADD
                        CMP             #'-'
                        BEQ             CALC_SUB
                        CMP             #'&'
                        BEQ             CALC_AND
                        CMP             #'|'
                        BEQ             CALC_OR
                        CMP             #'^'
                        BEQ             CALC_XOR
                        BRA             CALC_BAD

CALC_ADD:
                        CLC
                        LDA             CALC_A
                        ADC             CALC_B
                        BRA             CALC_HAVE_RESULT
CALC_SUB:
                        SEC
                        LDA             CALC_A
                        SBC             CALC_B
                        BRA             CALC_HAVE_RESULT
CALC_AND:
                        LDA             CALC_A
                        AND             CALC_B
                        BRA             CALC_HAVE_RESULT
CALC_OR:
                        LDA             CALC_A
                        ORA             CALC_B
                        BRA             CALC_HAVE_RESULT
CALC_XOR:
                        LDA             CALC_A
                        EOR             CALC_B

CALC_HAVE_RESULT:
                        STA             CALC_RESULT
                        LDX             #<MSG_RESULT
                        LDY             #>MSG_RESULT
                        JSR             CALC_PRINT
                        LDA             CALC_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             CALC_LOOP

CALC_BAD:
                        LDX             #<MSG_BAD
                        LDY             #>MSG_BAD
                        JSR             CALC_PRINT_LINE
                        JMP             CALC_LOOP

CALC_DONE:
                        LDX             #<MSG_BYE
                        LDY             #>MSG_BYE
                        JSR             CALC_PRINT_LINE
                        RTS

CALC_READ_HEX_BYTE:
                        JSR             SYS_READ_CHAR_ECHO
                        TAY
                        JSR             SYS_READ_CHAR_ECHO
                        TAX
                        JSR             SYS_WRITE_CRLF
                        JSR             UTL_HEX_ASCII_YX_TO_BYTE
                        RTS

CALC_PRINT_LINE:
                        JSR             CALC_PRINT
                        JMP             SYS_WRITE_CRLF

CALC_PRINT:
                        JMP             SYS_WRITE_CSTRING

                        DATA
MSG_TITLE:              DB              "CALC HEX BYTE: + - & | ^, Q QUITS",0
MSG_A:                  DB              "A HEX? ",0
MSG_B:                  DB              "B HEX? ",0
MSG_OP:                 DB              "OP? ",0
MSG_RESULT:             DB              "= $",0
MSG_BAD:                DB              "BAD INPUT",0
MSG_BYE:                DB              "CALC DONE",0

                        END

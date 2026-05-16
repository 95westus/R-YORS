; ----------------------------------------------------------------------------
; rom-append-calc.asm
; Tiny ROM append proof image, linked at $B804.
;   $B804-$B80B: FNV record for command CALC
;   $B80C:       command entry point
; Current CALC ROM-append proof. Supersedes calc-9a00-fnv-proof.asm for active
; proof/load work and must continue to fit below the protected ROM region.
; ----------------------------------------------------------------------------

                        MODULE          ROM_APPEND_CALC_APP

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
CALC_CTRL_C             EQU             $03

                        CODE

CALC_FNV:
                        DB              'F','N',('V'+$80),$14,$63,$43,$BA,$00
; 2026-05-07T22:21-05:00        WLP2        CALC accepts ^C/Q quit from operator prompt.
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             CALC_PRINT_LINE

CALC_LOOP:
                        LDX             #<MSG_A
                        LDY             #>MSG_A
                        JSR             CALC_PRINT
                        JSR             CALC_READ_HEX_BYTE
                        BCS             ?A_OK
                        CMP             #CALC_CTRL_C
                        BNE             ?A_BAD
                        JMP             CALC_DONE
?A_BAD:
                        JMP             CALC_BAD
?A_OK:
                        STA             CALC_A

                        LDX             #<MSG_OP
                        LDY             #>MSG_OP
                        JSR             CALC_PRINT
                        JSR             SYS_READ_CHAR_ECHO
                        STA             CALC_OP
                        JSR             SYS_WRITE_CRLF
                        LDA             CALC_OP
                        CMP             #CALC_CTRL_C
                        BNE             ?OP_Q
                        JMP             CALC_DONE
?OP_Q:
                        AND             #$DF
                        CMP             #'Q'
                        BNE             ?OP_NOT_QUIT
                        JMP             CALC_DONE
?OP_NOT_QUIT:

                        LDX             #<MSG_B
                        LDY             #>MSG_B
                        JSR             CALC_PRINT
                        JSR             CALC_READ_HEX_BYTE
                        BCS             ?B_OK
                        CMP             #CALC_CTRL_C
                        BNE             ?B_BAD
                        JMP             CALC_DONE
?B_BAD:
                        JMP             CALC_BAD
?B_OK:
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

; 2026-05-07T22:21-05:00        WLP2        Hex input returns C=0/A=$03 when ^C aborts.
CALC_READ_HEX_BYTE:
                        JSR             SYS_READ_CHAR_ECHO
                        CMP             #CALC_CTRL_C
                        BEQ             ?QUIT
                        TAY
                        JSR             SYS_READ_CHAR_ECHO
                        CMP             #CALC_CTRL_C
                        BEQ             ?QUIT
                        TAX
                        JSR             SYS_WRITE_CRLF
                        JSR             UTL_HEX_ASCII_YX_TO_BYTE
                        BCS             ?DONE
                        LDA             #$00
                        CLC
?DONE:
                        RTS
?QUIT:
                        JSR             SYS_WRITE_CRLF
                        LDA             #CALC_CTRL_C
                        CLC
                        RTS

CALC_PRINT_LINE:
                        JSR             CALC_PRINT
                        JMP             SYS_WRITE_CRLF

CALC_PRINT:
                        JMP             SYS_WRITE_CSTRING

                        DATA
MSG_TITLE:              DB              "CALC HEX BYTE: + - & | ^, ^C QUITS",0
MSG_A:                  DB              "A HEX? ",0
MSG_B:                  DB              "B HEX? ",0
MSG_OP:                 DB              "OP? ",0
MSG_RESULT:             DB              "= $",0
MSG_BAD:                DB              "BAD INPUT",0
MSG_BYE:                DB              "CALC DONE",0

                        END

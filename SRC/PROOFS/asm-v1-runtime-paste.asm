; ----------------------------------------------------------------------------
; asm-v1-runtime-paste.asm
; RAM-loaded paste driver for the stripped ASM v1 runtime.
;
; Link this wrapper before asm-v1-runtime.obj so START remains at $2000 while
; the runtime is reached only through exported callable routines.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_RUNTIME_PASTE_APP

                        XDEF            START

                        XREF            ASM_BEGIN
                        XREF            ASM_ASSEMBLE_LINE
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_READ_CSTRING_ECHO_UPPER
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE

ASM_BEGINF_HAVE_PC     EQU             $01
ASMRP_TARGET_LO        EQU             $00
ASMRP_TARGET_HI        EQU             $70
ASMRP_RESULT           EQU             $67F2

ASMRP_STATUS_OK        EQU             $00
ASMRP_STATUS_BAD_MNEM  EQU             $01
ASMRP_STATUS_BAD_DIR   EQU             $02
ASMRP_STATUS_BAD_OPER  EQU             $03
ASMRP_STATUS_BAD_MODE  EQU             $04
ASMRP_STATUS_BAD_WIDTH EQU             $05
ASMRP_STATUS_BAD_RANGE EQU             $06
ASMRP_STATUS_BAD_LINE  EQU             $07
ASMRP_STATUS_BAD_SYM   EQU             $08
ASMRP_STATUS_BAD_FIX   EQU             $09
ASMRP_STATUS_LOCAL_NYI EQU             $0A
ASMRP_STATUS_RJOIN     EQU             $0B

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMRP_PRINT_LINE

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASMRP_TARGET_LO
                        LDY             #ASMRP_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASMRP_LOOP

                        STA             ASMRP_RESULT
                        JSR             ASMRP_PRINT_FAIL
                        CLC
                        RTS

ASMRP_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             ASMRP_PRINT

                        LDX             #<ASMRP_LINE_BUF
                        LDY             #>ASMRP_LINE_BUF
                        JSR             SYS_READ_CSTRING_ECHO_UPPER
                        BCS             ASMRP_READ_OK

                        STA             ASMRP_RESULT
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             ASMRP_PRINT_STATUS_LINE
                        CLC
                        RTS

ASMRP_READ_OK:
                        BEQ             ASMRP_LOOP
                        JSR             ASMRP_IS_DOT
                        BCC             ASMRP_ASSEMBLE

                        LDX             #<MSG_BYE
                        LDY             #>MSG_BYE
                        JSR             ASMRP_PRINT_LINE
                        SEC
                        RTS

ASMRP_ASSEMBLE:
                        LDX             #<ASMRP_LINE_BUF
                        LDY             #>ASMRP_LINE_BUF
                        JSR             ASM_ASSEMBLE_LINE
                        STX             ASMRP_PC_LO
                        STY             ASMRP_PC_HI
                        BCS             ASMRP_ACCEPTED

                        STA             ASMRP_RESULT
                        LDX             #<MSG_ERR
                        LDY             #>MSG_ERR
                        JSR             ASMRP_PRINT_STATUS_PC_LINE
                        JSR             ASMRP_RECOVER_AFTER_ERROR
                        BCS             ASMRP_LOOP
                        CLC
                        RTS

ASMRP_ACCEPTED:
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASMRP_PRINT_PC_LINE
                        JSR             ASMRP_IS_END
                        BCC             ASMRP_LOOP

                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             ASMRP_PRINT_LINE
                        SEC
                        RTS

ASMRP_PRINT_FAIL:
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JMP             ASMRP_PRINT_STATUS_LINE

ASMRP_PRINT_STATUS_LINE:
                        JSR             ASMRP_PRINT
                        LDA             ASMRP_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMRP_PRINT_STATUS_PC_LINE:
                        JSR             ASMRP_PRINT
                        LDA             ASMRP_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             ASMRP_PRINT_STATUS_NAME
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC
                        BRA             ASMRP_PRINT_PC_TAIL

ASMRP_PRINT_PC_LINE:
                        JSR             ASMRP_PRINT
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC
ASMRP_PRINT_PC_TAIL:
                        JSR             ASMRP_PRINT
                        LDA             ASMRP_PC_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             ASMRP_PC_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMRP_PRINT_LINE:
                        JSR             ASMRP_PRINT
                        JMP             SYS_WRITE_CRLF

ASMRP_PRINT:
                        JMP             SYS_WRITE_CSTRING

ASMRP_RECOVER_AFTER_ERROR:
                        JSR             SYS_FLUSH_RX

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASMRP_TARGET_LO
                        LDY             #ASMRP_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASMRP_RECOVER_OK

                        STA             ASMRP_RESULT
                        JSR             ASMRP_PRINT_FAIL
                        CLC
                        RTS
ASMRP_RECOVER_OK:
                        SEC
                        RTS

ASMRP_PRINT_STATUS_NAME:
                        LDA             ASMRP_RESULT
                        CMP             #ASMRP_STATUS_OK
                        BEQ             ASMRP_STATUS_NAME_OK
                        CMP             #ASMRP_STATUS_BAD_MNEM
                        BEQ             ASMRP_STATUS_NAME_BAD_MNEM
                        CMP             #ASMRP_STATUS_BAD_DIR
                        BEQ             ASMRP_STATUS_NAME_BAD_DIR
                        CMP             #ASMRP_STATUS_BAD_OPER
                        BEQ             ASMRP_STATUS_NAME_BAD_OPER
                        CMP             #ASMRP_STATUS_BAD_MODE
                        BEQ             ASMRP_STATUS_NAME_BAD_MODE
                        CMP             #ASMRP_STATUS_BAD_WIDTH
                        BEQ             ASMRP_STATUS_NAME_BAD_WIDTH
                        CMP             #ASMRP_STATUS_BAD_RANGE
                        BEQ             ASMRP_STATUS_NAME_BAD_RANGE
                        CMP             #ASMRP_STATUS_BAD_LINE
                        BEQ             ASMRP_STATUS_NAME_BAD_LINE
                        CMP             #ASMRP_STATUS_BAD_SYM
                        BEQ             ASMRP_STATUS_NAME_BAD_SYM
                        CMP             #ASMRP_STATUS_BAD_FIX
                        BEQ             ASMRP_STATUS_NAME_BAD_FIX
                        CMP             #ASMRP_STATUS_LOCAL_NYI
                        BEQ             ASMRP_STATUS_NAME_LOCAL_NYI
                        CMP             #ASMRP_STATUS_RJOIN
                        BEQ             ASMRP_STATUS_NAME_RJOIN
                        LDX             #<MSG_STATUS_UNKNOWN
                        LDY             #>MSG_STATUS_UNKNOWN
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_OK:
                        LDX             #<MSG_STATUS_OK
                        LDY             #>MSG_STATUS_OK
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_MNEM:
                        LDX             #<MSG_STATUS_BAD_MNEM
                        LDY             #>MSG_STATUS_BAD_MNEM
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_DIR:
                        LDX             #<MSG_STATUS_BAD_DIR
                        LDY             #>MSG_STATUS_BAD_DIR
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_OPER:
                        LDX             #<MSG_STATUS_BAD_OPER
                        LDY             #>MSG_STATUS_BAD_OPER
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_MODE:
                        LDX             #<MSG_STATUS_BAD_MODE
                        LDY             #>MSG_STATUS_BAD_MODE
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_WIDTH:
                        LDX             #<MSG_STATUS_BAD_WIDTH
                        LDY             #>MSG_STATUS_BAD_WIDTH
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_RANGE:
                        LDX             #<MSG_STATUS_BAD_RANGE
                        LDY             #>MSG_STATUS_BAD_RANGE
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_LINE:
                        LDX             #<MSG_STATUS_BAD_LINE
                        LDY             #>MSG_STATUS_BAD_LINE
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_SYM:
                        LDX             #<MSG_STATUS_BAD_SYM
                        LDY             #>MSG_STATUS_BAD_SYM
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_BAD_FIX:
                        LDX             #<MSG_STATUS_BAD_FIX
                        LDY             #>MSG_STATUS_BAD_FIX
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_LOCAL_NYI:
                        LDX             #<MSG_STATUS_LOCAL_NYI
                        LDY             #>MSG_STATUS_LOCAL_NYI
                        JMP             ASMRP_PRINT
ASMRP_STATUS_NAME_RJOIN:
                        LDX             #<MSG_STATUS_RJOIN
                        LDY             #>MSG_STATUS_RJOIN
                        JMP             ASMRP_PRINT

ASMRP_IS_DOT:
                        LDA             ASMRP_LINE_BUF
                        CMP             #'.'
                        BNE             ASMRP_DOT_NO
                        LDA             ASMRP_LINE_BUF+1
                        BNE             ASMRP_DOT_NO
                        SEC
                        RTS
ASMRP_DOT_NO:
                        CLC
                        RTS

ASMRP_IS_END:
                        LDY             #$00
ASMRP_END_SKIP:
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMRP_END_ADV
                        CMP             #$09
                        BNE             ASMRP_END_WORD
ASMRP_END_ADV:
                        INY
                        BRA             ASMRP_END_SKIP
ASMRP_END_WORD:
                        CMP             #'E'
                        BNE             ASMRP_NO
                        INY
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #'N'
                        BNE             ASMRP_NO
                        INY
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #'D'
                        BNE             ASMRP_NO
                        INY
                        LDA             ASMRP_LINE_BUF,Y
                        BEQ             ASMRP_YES
                        CMP             #' '
                        BEQ             ASMRP_YES
                        CMP             #$09
                        BEQ             ASMRP_YES
                        CMP             #';'
                        BEQ             ASMRP_YES
ASMRP_NO:
                        CLC
                        RTS
ASMRP_YES:
                        SEC
                        RTS

                        DATA
MSG_TITLE:              DB              "ASM RT PASTE",0
MSG_PROMPT:             DB              "ASM> ",0
MSG_OK:                 DB              "OK",0
MSG_ERR:                DB              "ERR=$",0
MSG_READ:               DB              "READ=$",0
MSG_FAIL:               DB              "BEGIN=$",0
MSG_PC:                 DB              " PC=$",0
MSG_DONE:               DB              "ASM RT PASTE OK",0
MSG_BYE:                DB              "ASM RT PASTE BYE",0
MSG_STATUS_OK:          DB              " OK",0
MSG_STATUS_BAD_MNEM:    DB              " BAD MNEM",0
MSG_STATUS_BAD_DIR:     DB              " BAD DIR",0
MSG_STATUS_BAD_OPER:    DB              " BAD OPER",0
MSG_STATUS_BAD_MODE:    DB              " BAD MODE",0
MSG_STATUS_BAD_WIDTH:   DB              " BAD WIDTH",0
MSG_STATUS_BAD_RANGE:   DB              " BAD RANGE",0
MSG_STATUS_BAD_LINE:    DB              " BAD LINE",0
MSG_STATUS_BAD_SYM:     DB              " BAD SYM",0
MSG_STATUS_BAD_FIX:     DB              " BAD FIX",0
MSG_STATUS_LOCAL_NYI:   DB              " LOCAL NYI",0
MSG_STATUS_RJOIN:       DB              " RJOIN",0
MSG_STATUS_UNKNOWN:     DB              " STATUS",0

ASMRP_PC_LO:            DB              $00
ASMRP_PC_HI:            DB              $00

ASMRP_LINE_BUF:         DS              $0100

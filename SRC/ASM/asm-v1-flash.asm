; ----------------------------------------------------------------------------
; asm-v1-flash.asm
; Flash-resident ASM v1 command wrapper.
;
; Link this wrapper before asm-v1-core built with ASM_RUNTIME_ONLY and
; ASM_FLASH_RUNTIME. CODE/DATA are written by HIMON L F; UDATA is RAM-only.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_FLASH_APP

                        XDEF            START

                        XREF            ASM_BEGIN
                        XREF            ASM_ASSEMBLE_LINE
                        XREF            ASM_PRINT_TABLES
                        XREF            ASM_SEAL_COMPUTE_FNV
                        XREF            ASM_SEAL_PRINT_RECORD
                        XREF            ASM_SEAL_RESOLVE_IMPORTS
                        XREF            ASM_SEAL_FLAGS
                        XREF            ASM_IMPORT_RESOLVE_COUNT
                        XREF            ASM_RJOIN_INIT_IO
                        XREF            ASM_RJ_READ_CSTRING
                        XREF            ASM_RJ_WRITE_CSTRING
                        XREF            ASM_RJ_WRITE_HEX_BYTE
                        XREF            ASM_RJ_PRINT_CRLF

ASM_BEGINF_HAVE_PC     EQU             $01
ASMF_TARGET_LO         EQU             $00
ASMF_TARGET_HI         EQU             $20

ASMF_STATUS_OK         EQU             $00
ASMF_STATUS_BAD_MNEM   EQU             $01
ASMF_STATUS_BAD_DIR    EQU             $02
ASMF_STATUS_BAD_OPER   EQU             $03
ASMF_STATUS_BAD_MODE   EQU             $04
ASMF_STATUS_BAD_WIDTH  EQU             $05
ASMF_STATUS_BAD_RANGE  EQU             $06
ASMF_STATUS_BAD_LINE   EQU             $07
ASMF_STATUS_BAD_SYM    EQU             $08
ASMF_STATUS_BAD_FIX    EQU             $09
ASMF_STATUS_LOCAL_NYI  EQU             $0A
ASMF_STATUS_RJOIN      EQU             $0B
ASMF_STATUS_NAME_UNKNOWN EQU           $0C
; Borrow ASM scratch ZP only inside wrapper command matching.
ASMF_CMD_PTR_LO        EQU             $84
ASMF_CMD_PTR_HI        EQU             $85

ASMF_FNV_SIG2          EQU             $D6
ASMF_KIND_EXEC_TEXT    EQU             $05

                        CODE
ASMF_FNV:
                        DB              'F','N',ASMF_FNV_SIG2
                        DB              $00,$74,$AD,$56
                        DB              ASMF_KIND_EXEC_TEXT
                        DW              START
                        DW              ASMF_TEXT

START:
                        JSR             ASM_RJOIN_INIT_IO
                        BCS             ASMF_IO_READY
                        LDA             #ASMF_STATUS_RJOIN
                        LDX             #$00
                        LDY             #$00
                        CLC
                        RTS

ASMF_IO_READY:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMF_PRINT_LINE

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASMF_TARGET_LO
                        LDY             #ASMF_TARGET_HI
                        JSR             ASM_BEGIN
                        STX             ASMF_PC_LO
                        STY             ASMF_PC_HI
                        STZ             ASMF_POST_FLAG
                        BCS             ASMF_LOOP

                        STA             ASMF_RESULT
                        JSR             ASMF_PRINT_FAIL
                        JMP             ASMF_RETURN_RESULT

ASMF_LOOP:
                        LDA             ASMF_POST_FLAG
                        BEQ             ASMF_PROMPT_ASM
                        LDX             #<MSG_SEAL_PROMPT
                        LDY             #>MSG_SEAL_PROMPT
                        BRA             ASMF_PROMPT_PRINT
ASMF_PROMPT_ASM:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
ASMF_PROMPT_PRINT:
                        JSR             ASMF_PRINT

                        LDX             #<ASMF_LINE_BUF
                        LDY             #>ASMF_LINE_BUF
                        JSR             ASM_RJ_READ_CSTRING
                        BCS             ASMF_READ_OK

                        STA             ASMF_RESULT
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_RETURN_RESULT

ASMF_READ_OK:
                        BEQ             ASMF_LOOP
                        JSR             ASMF_IS_DOT
                        BCS             ASMF_QUIT
                        LDA             ASMF_POST_FLAG
                        BEQ             ASMF_ASSEMBLE
                        LDX             #<ASMF_CMD_SEAL
                        LDY             #>ASMF_CMD_SEAL
                        JSR             ASMF_MATCH_STRICT_CMD
                        BCC             ASMF_POST_CHECK_NEW
                        JMP             ASMF_SEAL_CMD
ASMF_POST_CHECK_NEW:
                        LDX             #<ASMF_CMD_RESOLVE
                        LDY             #>ASMF_CMD_RESOLVE
                        JSR             ASMF_MATCH_STRICT_CMD
                        BCC             ASMF_POST_CHECK_NEW_2
                        JMP             ASMF_RESOLVE_CMD
ASMF_POST_CHECK_NEW_2:
                        LDX             #<ASMF_CMD_NEW
                        LDY             #>ASMF_CMD_NEW
                        JSR             ASMF_MATCH_STRICT_CMD
                        BCC             ASMF_POST_REJECT
                        JMP             ASMF_NEW_CMD
ASMF_POST_REJECT:
                        LDA             #ASMF_STATUS_BAD_OPER
                        STA             ASMF_RESULT
                        LDX             #<MSG_ERR
                        LDY             #>MSG_ERR
                        JSR             ASMF_PRINT_STATUS_PC_LINE
                        JMP             ASMF_LOOP

ASMF_QUIT:
                        LDX             #<MSG_BYE
                        LDY             #>MSG_BYE
                        JSR             ASMF_PRINT_LINE
                        SEC
                        RTS

ASMF_ASSEMBLE:
                        LDX             #<ASMF_LINE_BUF
                        LDY             #>ASMF_LINE_BUF
                        JSR             ASM_ASSEMBLE_LINE
                        STX             ASMF_PC_LO
                        STY             ASMF_PC_HI
                        BCS             ASMF_ACCEPTED

                        STA             ASMF_RESULT
                        LDX             #<MSG_ERR
                        LDY             #>MSG_ERR
                        JSR             ASMF_PRINT_STATUS_PC_LINE
                        JSR             ASMF_IS_END
                        BCC             ASMF_REJECT_CONTINUE
                        JMP             ASMF_ABORT_WITH_TABLES
ASMF_REJECT_CONTINUE:
                        JMP             ASMF_LOOP

ASMF_ACCEPTED:
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASMF_PRINT_PC_LINE
                        JSR             ASMF_IS_END
                        BCS             ASMF_ACCEPTED_END
                        JMP             ASMF_LOOP

ASMF_ACCEPTED_END:
                        LDA             #$01
                        STA             ASMF_POST_FLAG
                        JSR             ASMF_PRINT_TABLES_CMD
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             ASMF_PRINT_LINE
                        JMP             ASMF_LOOP

ASMF_SEAL_CMD:
                        JSR             ASM_SEAL_COMPUTE_FNV
                        BCS             ASMF_SEAL_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_SEAL_ERR
                        LDY             #>MSG_SEAL_ERR
                        JSR             ASMF_PRINT
                        LDA             ASMF_RESULT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASMF_PRINT_SEAL_FLAGS_TAIL
                        JMP             ASMF_LOOP
ASMF_SEAL_OK:
                        JSR             ASM_SEAL_PRINT_RECORD
                        JMP             ASMF_LOOP

ASMF_RESOLVE_CMD:
                        JSR             ASM_SEAL_RESOLVE_IMPORTS
                        BCS             ASMF_RESOLVE_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_RESOLVE_ERR
                        LDY             #>MSG_RESOLVE_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_RESOLVE_OK:
                        LDX             #<MSG_RESOLVE_OK
                        LDY             #>MSG_RESOLVE_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_IMPORT_RESOLVE_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP

ASMF_NEW_CMD:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             ASMF_PC_LO
                        LDY             ASMF_PC_HI
                        JSR             ASM_BEGIN
                        STX             ASMF_PC_LO
                        STY             ASMF_PC_HI
                        BCS             ASMF_NEW_OK
                        STA             ASMF_RESULT
                        JSR             ASMF_PRINT_FAIL
                        JMP             ASMF_RETURN_RESULT
ASMF_NEW_OK:
                        STZ             ASMF_POST_FLAG
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASMF_PRINT_PC_LINE
                        JMP             ASMF_LOOP

ASMF_PRINT_FAIL:
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JMP             ASMF_PRINT_STATUS_LINE

ASMF_PRINT_STATUS_LINE:
                        JSR             ASMF_PRINT
                        LDA             ASMF_RESULT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT_STATUS_PC_LINE:
                        JSR             ASMF_PRINT
                        LDA             ASMF_RESULT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASMF_PRINT_STATUS_NAME
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC
                        BRA             ASMF_PRINT_PC_TAIL

ASMF_PRINT_PC_LINE:
                        JSR             ASMF_PRINT
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC
ASMF_PRINT_PC_TAIL:
                        JSR             ASMF_PRINT
                        LDA             ASMF_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASMF_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT_LINE:
                        JSR             ASMF_PRINT
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT:
                        JMP             ASM_RJ_WRITE_CSTRING

ASMF_PRINT_SEAL_FLAGS_TAIL:
                        LDX             #<MSG_FLAGS
                        LDY             #>MSG_FLAGS
                        JSR             ASMF_PRINT
                        LDA             ASM_SEAL_FLAGS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_RETURN_RESULT:
                        LDA             ASMF_RESULT
                        LDX             ASMF_PC_LO
                        LDY             ASMF_PC_HI
                        CLC
                        RTS

ASMF_ABORT_WITH_TABLES:
                        JSR             ASMF_PRINT_TABLES_CMD
                        BRA             ASMF_RETURN_RESULT

ASMF_PRINT_STATUS_NAME:
                        LDA             ASMF_RESULT
                        CMP             #ASMF_STATUS_NAME_UNKNOWN
                        BCC             ASMF_STATUS_NAME_HAVE_INDEX
                        LDA             #ASMF_STATUS_NAME_UNKNOWN
ASMF_STATUS_NAME_HAVE_INDEX:
                        TAX
                        LDA             ASMF_STATUS_NAME_LO,X
                        PHA
                        LDA             ASMF_STATUS_NAME_HI,X
                        TAY
                        PLA
                        TAX
                        JMP             ASMF_PRINT

ASMF_PRINT_TABLES_CMD:
                        JSR             ASM_PRINT_TABLES
                        BCS             ASMF_TABLES_DONE
                        PHA
                        LDX             #<MSG_TABLE
                        LDY             #>MSG_TABLE
                        JSR             ASMF_PRINT
                        PLA
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF
ASMF_TABLES_DONE:
                        RTS

ASMF_IS_DOT:
                        LDA             ASMF_LINE_BUF
                        CMP             #'.'
                        BNE             ASMF_DOT_NO
                        LDA             ASMF_LINE_BUF+1
                        BNE             ASMF_DOT_NO
                        SEC
                        RTS
ASMF_DOT_NO:
                        CLC
                        RTS

ASMF_SKIP_COMMAND_HEAD:
                        LDY             #$00
ASMF_SKIP_COMMAND_HEAD_LOOP:
                        LDA             ASMF_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMF_SKIP_COMMAND_HEAD_ADV
                        CMP             #$09
                        BEQ             ASMF_SKIP_COMMAND_HEAD_ADV
                        RTS
ASMF_SKIP_COMMAND_HEAD_ADV:
                        INY
                        BRA             ASMF_SKIP_COMMAND_HEAD_LOOP

ASMF_MATCH_STRICT_TAIL:
                        LDA             ASMF_LINE_BUF,Y
                        BEQ             ASMF_YES
                        CMP             #';'
                        BEQ             ASMF_YES
                        CMP             #' '
                        BEQ             ASMF_MATCH_STRICT_TAIL_ADV
                        CMP             #$09
                        BNE             ASMF_NO
ASMF_MATCH_STRICT_TAIL_ADV:
                        INY
                        BRA             ASMF_MATCH_STRICT_TAIL

ASMF_MATCH_LOOSE_TAIL:
                        LDA             ASMF_LINE_BUF,Y
                        BEQ             ASMF_YES
                        CMP             #' '
                        BEQ             ASMF_YES
                        CMP             #$09
                        BEQ             ASMF_YES
                        CMP             #';'
                        BEQ             ASMF_YES
ASMF_NO:
                        CLC
                        RTS
ASMF_YES:
                        SEC
                        RTS

ASMF_MATCH_STRICT_CMD:
                        STX             ASMF_CMD_PTR_LO
                        STY             ASMF_CMD_PTR_HI
                        JSR             ASMF_SKIP_COMMAND_HEAD
                        TYA
                        TAX
                        LDY             #$00
ASMF_MATCH_STRICT_CMD_LOOP:
                        LDA             (ASMF_CMD_PTR_LO),Y
                        BEQ             ASMF_MATCH_STRICT_CMD_TAIL
                        CMP             ASMF_LINE_BUF,X
                        BNE             ASMF_NO
                        INX
                        INY
                        BRA             ASMF_MATCH_STRICT_CMD_LOOP
ASMF_MATCH_STRICT_CMD_TAIL:
                        TXA
                        TAY
                        JMP             ASMF_MATCH_STRICT_TAIL

ASMF_IS_END:
                        JSR             ASMF_SKIP_COMMAND_HEAD
                        CMP             #'E'
                        BNE             ASMF_NO
                        INY
                        LDA             ASMF_LINE_BUF,Y
                        CMP             #'N'
                        BNE             ASMF_NO
                        INY
                        LDA             ASMF_LINE_BUF,Y
                        CMP             #'D'
                        BNE             ASMF_NO
                        INY
                        BRA             ASMF_MATCH_LOOSE_TAIL

                        DATA
ASMF_TEXT:              DB              "ASM V",('1'+$80)
ASMF_CMD_SEAL:          DB              "SEAL",0
ASMF_CMD_RESOLVE:       DB              "RESOLVE",0
ASMF_CMD_NEW:           DB              "NEW",0
MSG_TITLE:              DB              "ASM FLASH",0
MSG_PROMPT:             DB              "ASM> ",0
MSG_SEAL_PROMPT:        DB              "SEAL> ",0
MSG_OK:                 DB              "OK",0
MSG_ERR:                DB              "ERR=$",0
MSG_READ:               DB              "READ=$",0
MSG_FAIL:               DB              "BEGIN=$",0
MSG_TABLE:              DB              "TABLE=$",0
MSG_PC:                 DB              " PC=$",0
MSG_SEAL_ERR:           DB              "SEAL ERR=$",0
MSG_RESOLVE_ERR:        DB              "RESOLVE ERR=$",0
MSG_RESOLVE_OK:         DB              "RESOLVE OK COUNT=$",0
MSG_FLAGS:              DB              " FLAGS=$",0
MSG_DONE:               DB              "ASM FLASH OK",0
MSG_BYE:                DB              "ASM FLASH BYE",0
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

ASMF_STATUS_NAME_LO:
                        DB              <MSG_STATUS_OK
                        DB              <MSG_STATUS_BAD_MNEM
                        DB              <MSG_STATUS_BAD_DIR
                        DB              <MSG_STATUS_BAD_OPER
                        DB              <MSG_STATUS_BAD_MODE
                        DB              <MSG_STATUS_BAD_WIDTH
                        DB              <MSG_STATUS_BAD_RANGE
                        DB              <MSG_STATUS_BAD_LINE
                        DB              <MSG_STATUS_BAD_SYM
                        DB              <MSG_STATUS_BAD_FIX
                        DB              <MSG_STATUS_LOCAL_NYI
                        DB              <MSG_STATUS_RJOIN
                        DB              <MSG_STATUS_UNKNOWN
ASMF_STATUS_NAME_HI:
                        DB              >MSG_STATUS_OK
                        DB              >MSG_STATUS_BAD_MNEM
                        DB              >MSG_STATUS_BAD_DIR
                        DB              >MSG_STATUS_BAD_OPER
                        DB              >MSG_STATUS_BAD_MODE
                        DB              >MSG_STATUS_BAD_WIDTH
                        DB              >MSG_STATUS_BAD_RANGE
                        DB              >MSG_STATUS_BAD_LINE
                        DB              >MSG_STATUS_BAD_SYM
                        DB              >MSG_STATUS_BAD_FIX
                        DB              >MSG_STATUS_LOCAL_NYI
                        DB              >MSG_STATUS_RJOIN
                        DB              >MSG_STATUS_UNKNOWN

                        UDATA
ASMF_RESULT:            DB              $00
ASMF_PC_LO:             DB              $00
ASMF_PC_HI:             DB              $00
ASMF_POST_FLAG:         DB              $00
ASMF_LINE_BUF:          DS              $0100

                        ENDMOD
                        END

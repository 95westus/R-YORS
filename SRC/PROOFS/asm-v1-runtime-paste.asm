; ----------------------------------------------------------------------------
; asm-v1-runtime-paste.asm
; RAM-loaded paste driver for the stripped ASM v1 runtime.
;
; Link this wrapper before asm-v1-runtime.obj so START remains at $2000 while
; the runtime is reached only through exported callable routines.
; CODE/DATA are loaded by HIMON L; UDATA is RAM-only wrapper state.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_RUNTIME_PASTE_APP

                        XDEF            START

                        XREF            ASM_BEGIN
                        XREF            ASM_ASSEMBLE_LINE
                        XREF            ASM_SEAL_COMPUTE_FNV
                        XREF            ASM_SEAL_PRINT_RECORD
                        XREF            ASM_SEAL_RESOLVE_IMPORTS
                        XREF            ASM_SEAL_RELOCATE
                        XREF            ASM_SEAL_FLAGS
                        XREF            ASM_IMPORT_RESOLVE_COUNT
                        XREF            ASM_RELOCATE_BASE_LO
                        XREF            ASM_RELOCATE_BASE_HI
                        XREF            ASM_RELOCATE_COUNT
                        XREF            ASM_PARSE_EXPR
                        XREF            ASM_PARSE_EXPR_REQUIRE_END
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE

ASM_BEGINF_HAVE_PC     EQU             $01
; Borrow HIMON CMD_BUF while ASM RT PASTE owns the console. HIMON overwrites
; this page on the next monitor command after the wrapper returns.
ASMRP_LINE_BUF         EQU             $7A00
ASMRP_QUENCH_IDLE_SLICES EQU           $02

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
ASMRP_STATUS_NAME_UNKNOWN EQU          $0C
; Borrow ASM scratch ZP only inside wrapper command matching.
ASMRP_CMD_PTR_LO       EQU             $84
ASMRP_CMD_PTR_HI       EQU             $85

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMRP_PRINT_LINE

                        LDA             #$00
                        JSR             ASM_BEGIN
                        STX             ASMRP_PC_LO
                        STY             ASMRP_PC_HI
                        STZ             ASMRP_POST_FLAG
                        BCS             ASMRP_LOOP

                        STA             ASMRP_RESULT
                        JSR             ASMRP_PRINT_FAIL
                        JMP             ASMRP_ABORT_WITH_RESULT

ASMRP_LOOP:
                        LDA             ASMRP_POST_FLAG
                        BEQ             ASMRP_PROMPT_ASM
                        LDX             #<MSG_SEAL_PROMPT
                        LDY             #>MSG_SEAL_PROMPT
                        BRA             ASMRP_PROMPT_PRINT
ASMRP_PROMPT_ASM:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
ASMRP_PROMPT_PRINT:
                        JSR             ASMRP_PRINT

                        LDX             #<ASMRP_LINE_BUF
                        LDY             #>ASMRP_LINE_BUF
                        JSR             SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        BCS             ASMRP_READ_OK

                        STA             ASMRP_RESULT
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             ASMRP_PRINT_STATUS_LINE
                        JMP             ASMRP_ABORT_WITH_RESULT

ASMRP_READ_OK:
                        BEQ             ASMRP_LOOP
                        JSR             ASMRP_IS_DOT
                        BCS             ASMRP_QUIT
                        LDA             ASMRP_POST_FLAG
                        BEQ             ASMRP_ASSEMBLE
                        LDX             #<ASMRP_CMD_SEAL
                        LDY             #>ASMRP_CMD_SEAL
                        JSR             ASMRP_MATCH_STRICT_CMD
                        BCC             ASMRP_POST_CHECK_NEW
                        JMP             ASMRP_SEAL_CMD
ASMRP_POST_CHECK_NEW:
                        LDX             #<ASMRP_CMD_RESOLVE
                        LDY             #>ASMRP_CMD_RESOLVE
                        JSR             ASMRP_MATCH_STRICT_CMD
                        BCC             ASMRP_POST_CHECK_NEW_2
                        JMP             ASMRP_RESOLVE_CMD
ASMRP_POST_CHECK_NEW_2:
                        LDX             #<ASMRP_CMD_RELOCATE
                        LDY             #>ASMRP_CMD_RELOCATE
                        JSR             ASMRP_MATCH_ARG_CMD
                        BCC             ASMRP_POST_CHECK_NEW_3
                        JMP             ASMRP_RELOCATE_CMD
ASMRP_POST_CHECK_NEW_3:
                        LDX             #<ASMRP_CMD_NEW
                        LDY             #>ASMRP_CMD_NEW
                        JSR             ASMRP_MATCH_STRICT_CMD
                        BCC             ASMRP_POST_REJECT
                        JMP             ASMRP_NEW_CMD
ASMRP_POST_REJECT:
                        LDA             #ASMRP_STATUS_BAD_OPER
                        STA             ASMRP_RESULT
                        LDX             #<MSG_ERR
                        LDY             #>MSG_ERR
                        JSR             ASMRP_PRINT_STATUS_PC_LINE
                        JMP             ASMRP_LOOP

ASMRP_QUIT:
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
                        JSR             ASMRP_IS_END
                        BCC             ASMRP_REJECT_CONTINUE
                        JMP             ASMRP_ABORT_WITH_TABLES
ASMRP_REJECT_CONTINUE:
                        JMP             ASMRP_LOOP

ASMRP_ACCEPTED:
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASMRP_PRINT_PC_LINE
                        JSR             ASMRP_IS_END
                        BCS             ASMRP_ACCEPTED_END
                        JMP             ASMRP_LOOP

ASMRP_ACCEPTED_END:
                        LDA             #$01
                        STA             ASMRP_POST_FLAG
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             ASMRP_PRINT_LINE
                        JMP             ASMRP_LOOP

ASMRP_SEAL_CMD:
                        JSR             ASM_SEAL_COMPUTE_FNV
                        BCS             ASMRP_SEAL_OK
                        STA             ASMRP_RESULT
                        LDX             #<MSG_SEAL_ERR
                        LDY             #>MSG_SEAL_ERR
                        JSR             ASMRP_PRINT
                        LDA             ASMRP_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             ASMRP_PRINT_SEAL_FLAGS_TAIL
                        JMP             ASMRP_LOOP
ASMRP_SEAL_OK:
                        JSR             ASM_SEAL_PRINT_RECORD
                        JMP             ASMRP_LOOP

ASMRP_RESOLVE_CMD:
                        JSR             ASM_SEAL_RESOLVE_IMPORTS
                        BCS             ASMRP_RESOLVE_OK
                        STA             ASMRP_RESULT
                        LDX             #<MSG_RESOLVE_ERR
                        LDY             #>MSG_RESOLVE_ERR
                        JSR             ASMRP_PRINT_STATUS_LINE
                        JMP             ASMRP_LOOP
ASMRP_RESOLVE_OK:
                        LDX             #<MSG_RESOLVE_OK
                        LDY             #>MSG_RESOLVE_OK
                        JSR             ASMRP_PRINT
                        LDA             ASM_IMPORT_RESOLVE_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             ASMRP_LOOP

ASMRP_RELOCATE_CMD:
                        JSR             ASMRP_PARSE_RELOCATE_ARG
                        BCS             ASMRP_RELOCATE_HAVE_ARG
                        STA             ASMRP_RESULT
                        LDX             #<MSG_RELOCATE_ERR
                        LDY             #>MSG_RELOCATE_ERR
                        JSR             ASMRP_PRINT_STATUS_LINE
                        JMP             ASMRP_LOOP
ASMRP_RELOCATE_HAVE_ARG:
                        JSR             ASM_SEAL_RELOCATE
                        BCS             ASMRP_RELOCATE_OK
                        STA             ASMRP_RESULT
                        LDX             #<MSG_RELOCATE_ERR
                        LDY             #>MSG_RELOCATE_ERR
                        JSR             ASMRP_PRINT_STATUS_LINE
                        JMP             ASMRP_LOOP
ASMRP_RELOCATE_OK:
                        LDX             #<MSG_RELOCATE_OK
                        LDY             #>MSG_RELOCATE_OK
                        JSR             ASMRP_PRINT
                        LDA             ASM_RELOCATE_BASE_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             ASM_RELOCATE_BASE_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_RELOCATE_COUNT
                        LDY             #>MSG_RELOCATE_COUNT
                        JSR             ASMRP_PRINT
                        LDA             ASM_RELOCATE_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             ASMRP_LOOP

ASMRP_NEW_CMD:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             ASMRP_PC_LO
                        LDY             ASMRP_PC_HI
                        JSR             ASM_BEGIN
                        STX             ASMRP_PC_LO
                        STY             ASMRP_PC_HI
                        BCS             ASMRP_NEW_OK
                        STA             ASMRP_RESULT
                        JSR             ASMRP_PRINT_FAIL
                        JMP             ASMRP_ABORT_WITH_RESULT
ASMRP_NEW_OK:
                        STZ             ASMRP_POST_FLAG
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASMRP_PRINT_PC_LINE
                        JMP             ASMRP_LOOP

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

ASMRP_PRINT_SEAL_FLAGS_TAIL:
                        LDX             #<MSG_FLAGS
                        LDY             #>MSG_FLAGS
                        JSR             ASMRP_PRINT
                        LDA             ASM_SEAL_FLAGS
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMRP_ABORT_WITH_RESULT:
                        JSR             ASMRP_QUENCH_RX
ASMRP_RETURN_RESULT:
                        LDA             ASMRP_RESULT
                        LDX             ASMRP_PC_LO
                        LDY             ASMRP_PC_HI
                        CLC
                        RTS

ASMRP_ABORT_WITH_TABLES:
                        JSR             ASMRP_QUENCH_RX
                        BRA             ASMRP_RETURN_RESULT

ASMRP_QUENCH_RX:
                        JSR             SYS_FLUSH_RX
                        LDA             #ASMRP_QUENCH_IDLE_SLICES
                        JSR             SYS_READ_CHAR_TIMEOUT_SPINDOWN
                        BCS             ASMRP_QUENCH_RX
                        RTS

ASMRP_PRINT_STATUS_NAME:
                        LDA             ASMRP_RESULT
                        CMP             #ASMRP_STATUS_NAME_UNKNOWN
                        BCC             ASMRP_STATUS_NAME_HAVE_INDEX
                        LDA             #ASMRP_STATUS_NAME_UNKNOWN
ASMRP_STATUS_NAME_HAVE_INDEX:
                        TAX
                        LDA             ASMRP_STATUS_NAME_LO,X
                        PHA
                        LDA             ASMRP_STATUS_NAME_HI,X
                        TAY
                        PLA
                        TAX
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

ASMRP_SKIP_COMMAND_HEAD:
                        LDY             #$00
ASMRP_SKIP_COMMAND_HEAD_LOOP:
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMRP_SKIP_COMMAND_HEAD_ADV
                        CMP             #$09
                        BEQ             ASMRP_SKIP_COMMAND_HEAD_ADV
                        RTS
ASMRP_SKIP_COMMAND_HEAD_ADV:
                        INY
                        BRA             ASMRP_SKIP_COMMAND_HEAD_LOOP

ASMRP_MATCH_STRICT_TAIL:
                        LDA             ASMRP_LINE_BUF,Y
                        BEQ             ASMRP_YES
                        CMP             #';'
                        BEQ             ASMRP_YES
                        CMP             #' '
                        BEQ             ASMRP_MATCH_STRICT_TAIL_ADV
                        CMP             #$09
                        BNE             ASMRP_NO
ASMRP_MATCH_STRICT_TAIL_ADV:
                        INY
                        BRA             ASMRP_MATCH_STRICT_TAIL

ASMRP_MATCH_LOOSE_TAIL:
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

ASMRP_MATCH_STRICT_CMD:
                        JSR             ASMRP_MATCH_CMD
                        BCS             ASMRP_MATCH_STRICT_CMD_TAIL
                        RTS
ASMRP_MATCH_STRICT_CMD_TAIL:
                        JMP             ASMRP_MATCH_STRICT_TAIL

ASMRP_MATCH_ARG_CMD:
                        JSR             ASMRP_MATCH_CMD
                        BCS             ASMRP_MATCH_ARG_CMD_TAIL
                        RTS
ASMRP_MATCH_ARG_CMD_TAIL:
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMRP_MATCH_ARG_CMD_SKIP
                        CMP             #$09
                        BEQ             ASMRP_MATCH_ARG_CMD_SKIP
                        CLC
                        RTS
ASMRP_MATCH_ARG_CMD_SKIP:
                        INY
                        LDA             ASMRP_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMRP_MATCH_ARG_CMD_SKIP
                        CMP             #$09
                        BEQ             ASMRP_MATCH_ARG_CMD_SKIP
                        TYA
                        CLC
                        ADC             #<ASMRP_LINE_BUF
                        TAX
                        LDA             #>ASMRP_LINE_BUF
                        ADC             #$00
                        TAY
                        SEC
                        RTS

ASMRP_MATCH_CMD:
                        STX             ASMRP_CMD_PTR_LO
                        STY             ASMRP_CMD_PTR_HI
                        JSR             ASMRP_SKIP_COMMAND_HEAD
                        TYA
                        TAX
                        LDY             #$00
ASMRP_MATCH_CMD_LOOP:
                        LDA             (ASMRP_CMD_PTR_LO),Y
                        BEQ             ASMRP_MATCH_CMD_TAIL
                        CMP             ASMRP_LINE_BUF,X
                        BNE             ASMRP_MATCH_CMD_NO
                        INX
                        INY
                        BRA             ASMRP_MATCH_CMD_LOOP
ASMRP_MATCH_CMD_TAIL:
                        TXA
                        TAY
                        SEC
                        RTS
ASMRP_MATCH_CMD_NO:
                        CLC
                        RTS

ASMRP_PARSE_RELOCATE_ARG:
                        JSR             ASM_PARSE_EXPR
                        BCS             ASMRP_PARSE_RELOCATE_EXPR_OK
                        RTS
ASMRP_PARSE_RELOCATE_EXPR_OK:
                        STX             ASMRP_RELOCATE_LO
                        STY             ASMRP_RELOCATE_HI
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASMRP_PARSE_RELOCATE_TAIL_OK
                        LDA             #ASMRP_STATUS_BAD_OPER
                        CLC
                        RTS
ASMRP_PARSE_RELOCATE_TAIL_OK:
                        LDX             ASMRP_RELOCATE_LO
                        LDY             ASMRP_RELOCATE_HI
                        SEC
                        RTS

ASMRP_IS_END:
                        LDX             #<ASMRP_CMD_END
                        LDY             #>ASMRP_CMD_END
                        JSR             ASMRP_MATCH_CMD
                        BCS             ASMRP_IS_END_TAIL
                        RTS
ASMRP_IS_END_TAIL:
                        JMP             ASMRP_MATCH_LOOSE_TAIL

                        DATA
ASMRP_CMD_SEAL:         DB              "SEAL",0
ASMRP_CMD_RESOLVE:      DB              "RESOLVE",0
ASMRP_CMD_RELOCATE:     DB              "RELOCATE",0
ASMRP_CMD_NEW:          DB              "NEW",0
ASMRP_CMD_END:          DB              "END",0
MSG_TITLE:              DB              "ASM RT PASTE",0
MSG_PROMPT:             DB              "ASM> ",0
MSG_SEAL_PROMPT:        DB              "SEAL> ",0
MSG_OK:                 DB              "OK",0
MSG_ERR:                DB              "ERR=$",0
MSG_READ:               DB              "READ=$",0
MSG_FAIL:               DB              "BEGIN=$",0
MSG_PC:                 DB              " PC=$",0
MSG_SEAL_ERR:           DB              "SEAL ERR=$",0
MSG_RESOLVE_ERR:        DB              "RESOLVE ERR=$",0
MSG_RESOLVE_OK:         DB              "RESOLVE OK COUNT=$",0
MSG_RELOCATE_ERR:       DB              "RELOCATE ERR=$",0
MSG_RELOCATE_OK:        DB              "RELOCATE OK BASE=$",0
MSG_RELOCATE_COUNT:     DB              " COUNT=$",0
MSG_FLAGS:              DB              " FLAGS=$",0
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

ASMRP_STATUS_NAME_LO:
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
ASMRP_STATUS_NAME_HI:
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
ASMRP_RESULT:           DB              $00
ASMRP_PC_LO:            DB              $00
ASMRP_PC_HI:            DB              $00
ASMRP_POST_FLAG:        DB              $00
ASMRP_RELOCATE_LO:      DB              $00
ASMRP_RELOCATE_HI:      DB              $00

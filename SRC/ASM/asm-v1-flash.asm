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
                        XREF            ASM_SEAL_COMPUTE_FNV
                        XREF            ASM_SEAL_RELOCATE
                        XREF            ASM_SEAL_PACKAGE
                        XREF            ASM_PACKAGE_LOAD
                        XREF            ASM_PACKAGE_INSTALL_SUGGEST
                        XREF            ASM_PACKAGE_PARSE_MIN
                        IF              ASM_PACKAGE_CHECK_ENABLED
                        XREF            ASM_SEAL_CHECK_PACKAGE
                        ENDIF
                        XREF            ASM_SEAL_FLAGS
                        XREF            ASM_RELOCATE_BASE_LO
                        XREF            ASM_RELOCATE_BASE_HI
                        XREF            ASM_RELOCATE_COUNT
                        XREF            ASM_PACKAGE_BASE_LO
                        XREF            ASM_PACKAGE_BASE_HI
                        XREF            ASM_PACKAGE_LEN_LO
                        XREF            ASM_PACKAGE_LEN_HI
                        XREF            ASM_PACKAGE_BODY_LEN_LO
                        XREF            ASM_PACKAGE_BODY_LEN_HI
                        XREF            ASM_INSTALL_BASE_LO
                        XREF            ASM_INSTALL_BASE_HI
                        XREF            ASM_PARSE_EXPR
                        XREF            ASM_PARSE_EXPR_REQUIRE_END
                        XREF            ASM_RJOIN_INIT_IO
                        XREF            ASM_RJ_READ_CSTRING
                        XREF            ASM_RJ_WRITE_HBSTRING
                        XREF            ASM_RJ_WRITE_HEX_BYTE
                        XREF            ASM_RJ_WRITE_HEX_WORD_AX
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

HIM_SVC_FLASH_INSTALL_LO EQU           $7E25
HIM_SVC_FLASH_INSTALL_HI EQU           $7E26
HIM_FLASH_SRC_LO       EQU             $7E27
HIM_FLASH_SRC_HI       EQU             $7E28
HIM_FLASH_DST_LO       EQU             $7E29
HIM_FLASH_DST_HI       EQU             $7E2A
HIM_FLASH_LEN_LO       EQU             $7E2B
HIM_FLASH_LEN_HI       EQU             $7E2C

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
                        JSR             ASMF_PRINT
                        LDA             ASMF_PC_HI
                        LDX             ASMF_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_PROMPT_TAIL
                        LDY             #>MSG_PROMPT_TAIL
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
                        BEQ             ASMF_SOURCE_CMD
                        LDX             #<ASMF_CMD_SEAL
                        LDY             #>ASMF_CMD_SEAL
                        JSR             ASMF_MATCH_STRICT_CMD
                        BCC             ASMF_POST_CHECK_NEW
                        JMP             ASMF_SEAL_CMD
ASMF_POST_CHECK_NEW:
                        LDX             #<ASMF_CMD_RELOCATE
                        LDY             #>ASMF_CMD_RELOCATE
                        JSR             ASMF_MATCH_ARG_CMD
                        BCC             ASMF_POST_CHECK_NEW_2
                        JMP             ASMF_RELOCATE_CMD
ASMF_POST_CHECK_NEW_2:
                        LDX             #<ASMF_CMD_PACKAGE
                        LDY             #>ASMF_CMD_PACKAGE
                        JSR             ASMF_MATCH_ARG_CMD
                        BCC             ASMF_POST_CHECK_NEW_3
                        JMP             ASMF_PACKAGE_CMD
ASMF_POST_CHECK_NEW_3:
                        LDX             #<ASMF_CMD_LOAD
                        LDY             #>ASMF_CMD_LOAD
                        JSR             ASMF_MATCH_ARG_CMD
                        BCC             ASMF_POST_CHECK_NEW_4
                        JMP             ASMF_LOAD_CMD
ASMF_POST_CHECK_NEW_4:
                        LDX             #<ASMF_CMD_INSTALL
                        LDY             #>ASMF_CMD_INSTALL
                        JSR             ASMF_MATCH_ARG_CMD
                        BCC             ASMF_POST_CHECK_NEW_5
                        JMP             ASMF_INSTALL_CMD
ASMF_POST_CHECK_NEW_5:
                        IF              ASM_PACKAGE_CHECK_ENABLED
                        LDX             #<ASMF_CMD_CHECK
                        LDY             #>ASMF_CMD_CHECK
                        JSR             ASMF_MATCH_ARG_CMD
                        BCC             ASMF_POST_CHECK_NEW_6
                        JMP             ASMF_CHECK_CMD
                        ENDIF
ASMF_POST_CHECK_NEW_6:
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
                        JMP             ASMF_RETURN_OK

ASMF_SOURCE_CMD:
                        LDX             #<ASMF_CMD_DOTP
                        LDY             #>ASMF_CMD_DOTP
                        JSR             ASMF_MATCH_STRICT_CMD
                        BCC             ASMF_ASSEMBLE
                        LDX             #<(MSG_PC+1)
                        LDY             #>(MSG_PC+1)
                        JSR             ASMF_PRINT_PC_TAIL
                        JMP             ASMF_LOOP

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
                        JSR             ASMF_IS_END
                        BCS             ASMF_ACCEPTED_END
                        JMP             ASMF_LOOP

ASMF_ACCEPTED_END:
                        LDA             #$01
                        STA             ASMF_POST_FLAG
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
                        LDX             #<MSG_SEAL_OK
                        LDY             #>MSG_SEAL_OK
                        JSR             ASMF_PRINT_LINE
                        JMP             ASMF_LOOP

ASMF_RELOCATE_CMD:
                        JSR             ASMF_PARSE_RELOCATE_ARG
                        BCS             ASMF_RELOCATE_HAVE_ARG
                        STA             ASMF_RESULT
                        LDX             #<MSG_RELOCATE_ERR
                        LDY             #>MSG_RELOCATE_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_RELOCATE_HAVE_ARG:
                        JSR             ASM_SEAL_RELOCATE
                        BCS             ASMF_RELOCATE_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_RELOCATE_ERR
                        LDY             #>MSG_RELOCATE_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_RELOCATE_OK:
                        LDX             #<MSG_RELOCATE_OK
                        LDY             #>MSG_RELOCATE_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_RELOCATE_BASE_HI
                        LDX             ASM_RELOCATE_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_RELOCATE_COUNT
                        LDY             #>MSG_RELOCATE_COUNT
                        JSR             ASMF_PRINT
                        LDA             ASM_RELOCATE_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP

ASMF_PACKAGE_CMD:
                        JSR             ASMF_PARSE_RELOCATE_ARG
                        BCS             ASMF_PACKAGE_HAVE_ARG
                        STA             ASMF_RESULT
                        LDX             #<MSG_PACKAGE_ERR
                        LDY             #>MSG_PACKAGE_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_PACKAGE_HAVE_ARG:
                        JSR             ASM_SEAL_PACKAGE
                        BCS             ASMF_PACKAGE_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_PACKAGE_ERR
                        LDY             #>MSG_PACKAGE_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_PACKAGE_OK:
                        LDX             #<MSG_PACKAGE_OK
                        LDY             #>MSG_PACKAGE_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_BASE_HI
                        LDX             ASM_PACKAGE_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_PACKAGE_LEN
                        LDY             #>MSG_PACKAGE_LEN
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_LEN_HI
                        LDX             ASM_PACKAGE_LEN_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP

ASMF_LOAD_CMD:
                        JSR             ASMF_PARSE_TWO_ARGS
                        BCS             ASMF_LOAD_HAVE_ARGS
                        STA             ASMF_RESULT
                        LDX             #<MSG_LOAD_ERR
                        LDY             #>MSG_LOAD_ERR
                        JSR             ASMF_PRINT_STATUS_NAMED_LINE
                        JMP             ASMF_LOOP
ASMF_LOAD_HAVE_ARGS:
                        LDA             ASMF_ARG1_LO
                        STA             ASM_RELOCATE_BASE_LO
                        LDA             ASMF_ARG1_HI
                        STA             ASM_RELOCATE_BASE_HI
                        LDX             ASMF_ARG0_LO
                        LDY             ASMF_ARG0_HI
                        JSR             ASM_PACKAGE_LOAD
                        BCS             ASMF_LOAD_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_LOAD_ERR
                        LDY             #>MSG_LOAD_ERR
                        JSR             ASMF_PRINT_STATUS_NAMED_LINE
                        JMP             ASMF_LOOP
ASMF_LOAD_OK:
                        LDX             #<MSG_LOAD_OK
                        LDY             #>MSG_LOAD_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_RELOCATE_BASE_HI
                        LDX             ASM_RELOCATE_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_PACKAGE_LEN
                        LDY             #>MSG_PACKAGE_LEN
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_BODY_LEN_HI
                        LDX             ASM_PACKAGE_BODY_LEN_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_RELOCATE_COUNT
                        LDY             #>MSG_RELOCATE_COUNT
                        JSR             ASMF_PRINT
                        LDA             ASM_RELOCATE_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP

ASMF_INSTALL_CMD:
                        JSR             ASMF_PARSE_TWO_ARGS
                        BCS             ASMF_INSTALL_HAVE_TWO_ARGS
                        LDX             ASMF_CMD_PTR_LO
                        LDY             ASMF_CMD_PTR_HI
                        JSR             ASMF_PARSE_RELOCATE_ARG
                        BCS             ASMF_INSTALL_HAVE_ARG
                        STA             ASMF_RESULT
                        LDX             #<MSG_INSTALL_ERR
                        LDY             #>MSG_INSTALL_ERR
                        JSR             ASMF_PRINT_STATUS_NAMED_LINE
                        JMP             ASMF_LOOP
ASMF_INSTALL_HAVE_TWO_ARGS:
                        LDA             ASMF_ARG1_LO
                        STA             ASM_INSTALL_BASE_LO
                        STA             HIM_FLASH_DST_LO
                        LDA             ASMF_ARG1_HI
                        STA             ASM_INSTALL_BASE_HI
                        STA             HIM_FLASH_DST_HI
                        LDA             ASMF_ARG0_LO
                        STA             ASM_PACKAGE_BASE_LO
                        LDA             ASMF_ARG0_HI
                        STA             ASM_PACKAGE_BASE_HI
                        LDX             ASMF_ARG0_LO
                        LDY             ASMF_ARG0_HI
                        JSR             ASM_PACKAGE_PARSE_MIN
                        BCC             ASMF_INSTALL_FAIL_A
                        LDA             ASM_PACKAGE_BASE_LO
                        STA             HIM_FLASH_SRC_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        STA             HIM_FLASH_SRC_HI
                        LDA             ASM_PACKAGE_LEN_LO
                        STA             HIM_FLASH_LEN_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        STA             HIM_FLASH_LEN_HI
                        LDA             HIM_SVC_FLASH_INSTALL_HI
                        CMP             #$C0
                        BCC             ASMF_INSTALL_BAD_RANGE
                        JSR             ASMF_FLASH_INSTALL
                        BCS             ASMF_INSTALL_OK
ASMF_INSTALL_BAD_RANGE:
                        LDA             #ASMF_STATUS_BAD_RANGE
ASMF_INSTALL_FAIL_A:
                        STA             ASMF_RESULT
                        LDX             #<MSG_INSTALL_ERR
                        LDY             #>MSG_INSTALL_ERR
                        JSR             ASMF_PRINT_STATUS_NAMED_LINE
                        JMP             ASMF_LOOP
ASMF_INSTALL_HAVE_ARG:
                        JSR             ASM_PACKAGE_INSTALL_SUGGEST
                        BCS             ASMF_INSTALL_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_INSTALL_ERR
                        LDY             #>MSG_INSTALL_ERR
                        JSR             ASMF_PRINT_STATUS_NAMED_LINE
                        JMP             ASMF_LOOP
ASMF_INSTALL_OK:
                        LDX             #<MSG_INSTALL_OK
                        LDY             #>MSG_INSTALL_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_INSTALL_BASE_HI
                        LDX             ASM_INSTALL_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_PACKAGE_LEN
                        LDY             #>MSG_PACKAGE_LEN
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_LEN_HI
                        LDX             ASM_PACKAGE_LEN_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP

                        IF              ASM_PACKAGE_CHECK_ENABLED
ASMF_CHECK_CMD:
                        JSR             ASMF_PARSE_RELOCATE_ARG
                        BCS             ASMF_CHECK_HAVE_ARG
                        STA             ASMF_RESULT
                        LDX             #<MSG_CHECK_ERR
                        LDY             #>MSG_CHECK_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_CHECK_HAVE_ARG:
                        JSR             ASM_SEAL_CHECK_PACKAGE
                        BCS             ASMF_CHECK_OK
                        STA             ASMF_RESULT
                        LDX             #<MSG_CHECK_ERR
                        LDY             #>MSG_CHECK_ERR
                        JSR             ASMF_PRINT_STATUS_LINE
                        JMP             ASMF_LOOP
ASMF_CHECK_OK:
                        LDX             #<MSG_CHECK_OK
                        LDY             #>MSG_CHECK_OK
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_BASE_HI
                        LDX             ASM_PACKAGE_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        LDX             #<MSG_PACKAGE_LEN
                        LDY             #>MSG_PACKAGE_LEN
                        JSR             ASMF_PRINT
                        LDA             ASM_PACKAGE_LEN_HI
                        LDX             ASM_PACKAGE_LEN_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        JSR             ASM_RJ_PRINT_CRLF
                        JMP             ASMF_LOOP
                        ENDIF

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

ASMF_PRINT_STATUS_NAMED_LINE:
                        JSR             ASMF_PRINT
                        LDA             ASMF_RESULT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASMF_PRINT_STATUS_NAME
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT_STATUS_PC_LINE:
                        JSR             ASMF_PRINT
                        LDA             ASMF_RESULT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASMF_PRINT_STATUS_NAME
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC

ASMF_PRINT_PC_TAIL:
                        JSR             ASMF_PRINT
                        LDA             ASMF_PC_HI
                        LDX             ASMF_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_WORD_AX
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT_LINE:
                        JSR             ASMF_PRINT
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_PRINT:
                        JMP             ASM_RJ_WRITE_HBSTRING

ASMF_PRINT_SEAL_FLAGS_TAIL:
                        LDX             #<MSG_FLAGS
                        LDY             #>MSG_FLAGS
                        JSR             ASMF_PRINT
                        LDA             ASM_SEAL_FLAGS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASMF_RETURN_RESULT:
                        LDA             ASMF_RESULT
                        CLC
                        BRA             ASMF_RETURN_WITH_A
ASMF_RETURN_OK:
                        LDA             #ASMF_STATUS_OK
                        SEC
ASMF_RETURN_WITH_A:
                        LDX             ASMF_PC_LO
                        LDY             ASMF_PC_HI
                        RTS

ASMF_FLASH_INSTALL:
                        JMP             (HIM_SVC_FLASH_INSTALL_LO)

ASMF_ABORT_WITH_TABLES:
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
                        JSR             ASMF_MATCH_CMD
                        BCS             ASMF_MATCH_STRICT_CMD_TAIL
                        RTS
ASMF_MATCH_STRICT_CMD_TAIL:
                        JMP             ASMF_MATCH_STRICT_TAIL

ASMF_MATCH_ARG_CMD:
                        JSR             ASMF_MATCH_CMD
                        BCS             ASMF_MATCH_ARG_CMD_TAIL
                        RTS
ASMF_MATCH_ARG_CMD_TAIL:
                        LDA             ASMF_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMF_MATCH_ARG_CMD_SKIP
                        CMP             #$09
                        BEQ             ASMF_MATCH_ARG_CMD_SKIP
                        CLC
                        RTS
ASMF_MATCH_ARG_CMD_SKIP:
                        INY
                        LDA             ASMF_LINE_BUF,Y
                        CMP             #' '
                        BEQ             ASMF_MATCH_ARG_CMD_SKIP
                        CMP             #$09
                        BEQ             ASMF_MATCH_ARG_CMD_SKIP
                        TYA
                        CLC
                        ADC             #<ASMF_LINE_BUF
                        TAX
                        LDA             #>ASMF_LINE_BUF
                        ADC             #$00
                        TAY
                        SEC
                        RTS

ASMF_MATCH_CMD:
                        STX             ASMF_CMD_PTR_LO
                        STY             ASMF_CMD_PTR_HI
                        JSR             ASMF_SKIP_COMMAND_HEAD
                        TYA
                        TAX
                        LDY             #$00
ASMF_MATCH_CMD_LOOP:
                        LDA             (ASMF_CMD_PTR_LO),Y
                        BEQ             ASMF_MATCH_CMD_TAIL
                        CMP             ASMF_LINE_BUF,X
                        BNE             ASMF_MATCH_CMD_NO
                        INX
                        INY
                        BRA             ASMF_MATCH_CMD_LOOP
ASMF_MATCH_CMD_TAIL:
                        TXA
                        TAY
                        SEC
                        RTS
ASMF_MATCH_CMD_NO:
                        CLC
                        RTS

ASMF_PARSE_RELOCATE_ARG:
                        JSR             ASM_PARSE_EXPR
                        BCS             ASMF_PARSE_RELOCATE_EXPR_OK
                        RTS
ASMF_PARSE_RELOCATE_EXPR_OK:
                        STX             ASMF_RELOCATE_LO
                        STY             ASMF_RELOCATE_HI
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASMF_PARSE_RELOCATE_TAIL_OK
                        LDA             #ASMF_STATUS_BAD_OPER
                        CLC
                        RTS
ASMF_PARSE_RELOCATE_TAIL_OK:
                        LDX             ASMF_RELOCATE_LO
                        LDY             ASMF_RELOCATE_HI
                        SEC
                        RTS

ASMF_PARSE_TWO_ARGS:
                        STX             ASMF_CMD_PTR_LO
                        STY             ASMF_CMD_PTR_HI
                        LDY             #$00
ASMF_PARSE_TWO_FIND_SPLIT:
                        LDA             (ASMF_CMD_PTR_LO),Y
                        BEQ             ASMF_PARSE_TWO_BAD_OPER
                        CMP             #';'
                        BEQ             ASMF_PARSE_TWO_BAD_OPER
                        CMP             #' '
                        BEQ             ASMF_PARSE_TWO_SPLIT
                        CMP             #$09
                        BEQ             ASMF_PARSE_TWO_SPLIT
                        INY
                        BRA             ASMF_PARSE_TWO_FIND_SPLIT
ASMF_PARSE_TWO_SPLIT:
                        STY             ASMF_SPLIT_OFF
                        STA             ASMF_SPLIT_CHAR
                        LDA             #$00
                        STA             (ASMF_CMD_PTR_LO),Y
                        LDX             ASMF_CMD_PTR_LO
                        LDY             ASMF_CMD_PTR_HI
                        JSR             ASM_PARSE_EXPR
                        BCS             ASMF_PARSE_TWO_FIRST_OK
                        PHA
                        JSR             ASMF_PARSE_TWO_RESTORE
                        PLA
                        CLC
                        RTS
ASMF_PARSE_TWO_FIRST_OK:
                        STX             ASMF_ARG0_LO
                        STY             ASMF_ARG0_HI
                        JSR             ASMF_PARSE_TWO_RESTORE
                        LDY             ASMF_SPLIT_OFF
ASMF_PARSE_TWO_SKIP:
                        INY
                        LDA             (ASMF_CMD_PTR_LO),Y
                        BEQ             ASMF_PARSE_TWO_BAD_OPER
                        CMP             #' '
                        BEQ             ASMF_PARSE_TWO_SKIP
                        CMP             #$09
                        BEQ             ASMF_PARSE_TWO_SKIP
                        CMP             #';'
                        BEQ             ASMF_PARSE_TWO_BAD_OPER
                        TYA
                        CLC
                        ADC             ASMF_CMD_PTR_LO
                        TAX
                        LDA             ASMF_CMD_PTR_HI
                        ADC             #$00
                        TAY
                        JSR             ASM_PARSE_EXPR
                        BCS             ASMF_PARSE_TWO_SECOND_OK
                        RTS
ASMF_PARSE_TWO_SECOND_OK:
                        STX             ASMF_ARG1_LO
                        STY             ASMF_ARG1_HI
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASMF_PARSE_TWO_DONE
                        LDA             #ASMF_STATUS_BAD_OPER
                        CLC
                        RTS
ASMF_PARSE_TWO_DONE:
                        LDX             ASMF_ARG0_LO
                        LDY             ASMF_ARG0_HI
                        SEC
                        RTS
ASMF_PARSE_TWO_BAD_OPER:
                        LDA             #ASMF_STATUS_BAD_OPER
                        CLC
                        RTS

ASMF_PARSE_TWO_RESTORE:
                        LDY             ASMF_SPLIT_OFF
                        LDA             ASMF_SPLIT_CHAR
                        STA             (ASMF_CMD_PTR_LO),Y
                        RTS

ASMF_IS_END:
                        LDX             #<ASMF_CMD_END
                        LDY             #>ASMF_CMD_END
                        JSR             ASMF_MATCH_CMD
                        BCS             ASMF_IS_END_TAIL
                        RTS
ASMF_IS_END_TAIL:
                        JMP             ASMF_MATCH_LOOSE_TAIL

                        DATA
ASMF_TEXT:              DB              "ASM V",('1'+$80)
ASMF_CMD_SEAL:          DB              "SEAL",0
ASMF_CMD_RELOCATE:      DB              "RELOCATE",0
ASMF_CMD_PACKAGE:       DB              "PACKAGE",0
ASMF_CMD_LOAD:          DB              "LOAD",0
ASMF_CMD_INSTALL:       DB              "INSTALL",0
                        IF              ASM_PACKAGE_CHECK_ENABLED
ASMF_CMD_CHECK:         DB              "CHECK",0
                        ENDIF
ASMF_CMD_NEW:           DB              "NEW",0
ASMF_CMD_END:           DB              "END",0
ASMF_CMD_DOTP:          DB              ".P",0
MSG_TITLE:              DB              "AS",('M'+$80)
MSG_PROMPT:             DB              "ASM>",('$'+$80)
MSG_PROMPT_TAIL:        DB              ":",(' '+$80)
MSG_SEAL_PROMPT:        DB              "SEAL>",(' '+$80)
MSG_ERR:                DB              "ERR=",('$'+$80)
MSG_READ:               DB              "READ=",('$'+$80)
MSG_FAIL:               DB              "BEGIN=",('$'+$80)
MSG_PC:                 DB              " PC=",('$'+$80)
MSG_SEAL_ERR:           DB              "SEAL ERR=",('$'+$80)
MSG_SEAL_OK:            DB              "SEAL O",('K'+$80)
MSG_RELOCATE_ERR:       DB              "REL ERR=",('$'+$80)
MSG_RELOCATE_OK:        DB              "REL OK BASE=",('$'+$80)
MSG_RELOCATE_COUNT:     DB              " C=",('$'+$80)
MSG_PACKAGE_ERR:        DB              "PKG ERR=",('$'+$80)
MSG_PACKAGE_OK:         DB              "PKG OK @=",('$'+$80)
MSG_PACKAGE_LEN:        DB              " L=",('$'+$80)
MSG_LOAD_ERR:           DB              "LOAD ERR=",('$'+$80)
MSG_LOAD_OK:            DB              "LOAD OK=",('$'+$80)
MSG_INSTALL_ERR:        DB              "INST ERR=",('$'+$80)
MSG_INSTALL_OK:         DB              "INST @=",('$'+$80)
                        IF              ASM_PACKAGE_CHECK_ENABLED
MSG_CHECK_ERR:          DB              "CHECK ERR=",('$'+$80)
MSG_CHECK_OK:           DB              "CHECK OK @=",('$'+$80)
                        ENDIF
MSG_FLAGS:              DB              " FLAGS=",('$'+$80)
MSG_DONE:               DB              "ASM O",('K'+$80)
MSG_BYE:                DB              "ASM BY",('E'+$80)
MSG_STATUS_OK:          DB              " O",('K'+$80)
MSG_STATUS_BAD_MNEM:    DB              " B",('M'+$80)
MSG_STATUS_BAD_DIR:     DB              " B",('D'+$80)
MSG_STATUS_BAD_OPER:    DB              " B",('O'+$80)
MSG_STATUS_BAD_MODE:    DB              " BM",('O'+$80)
MSG_STATUS_BAD_WIDTH:   DB              " B",('W'+$80)
MSG_STATUS_BAD_RANGE:   DB              " BAD RANG",('E'+$80)
MSG_STATUS_BAD_LINE:    DB              " B",('L'+$80)
MSG_STATUS_BAD_SYM:     DB              " B",('S'+$80)
MSG_STATUS_BAD_FIX:     DB              " BAD FI",('X'+$80)
MSG_STATUS_LOCAL_NYI:   DB              " NY",('I'+$80)
MSG_STATUS_RJOIN:       DB              " R",('J'+$80)
MSG_STATUS_UNKNOWN:     DB              " ",('?'+$80)

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
ASMF_RELOCATE_LO:       DB              $00
ASMF_RELOCATE_HI:       DB              $00
ASMF_ARG0_LO:           DB              $00
ASMF_ARG0_HI:           DB              $00
ASMF_ARG1_LO:           DB              $00
ASMF_ARG1_HI:           DB              $00
ASMF_SPLIT_OFF:         DB              $00
ASMF_SPLIT_CHAR:        DB              $00
ASMF_LINE_BUF:          DS              $0100

                        ENDMOD
                        END

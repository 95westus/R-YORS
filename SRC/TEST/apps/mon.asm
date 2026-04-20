; ----------------------------------------------------------------------------
; Monitor command and LOAD routines split out from himon.asm.
; ----------------------------------------------------------------------------

                        MODULE          MON_APP

                        XDEF            MON_CMD_DISPLAY
                        XDEF            MON_CMD_FILL
                        XDEF            MON_CMD_COPY
                        XDEF            MON_CMD_MODIFY
                        XDEF            MON_CMD_HELP
                        XDEF            MON_CMD_LOAD
                        XDEF            MON_CMD_KEYTEST
                        XDEF            MON_CMD_QUIT
                        XDEF            CMDP_GET_TOKEN_LEN
                        XDEF            CMDP_TBL_GET_ENTRY_LEN
                        XDEF            CMDP_TBL_MATCH_CURRENT
                        XDEF            CMDP_TBL_GET_ROUTINE_PTR
                        XDEF            CMDP_CALL_ROUTINE_PTR
                        XDEF            CMDP_TBL_ADVANCE_NEXT

                        XREF            SYS_FLUSH_RX
                        XREF            SYS_POLL_CHAR
                        XREF            SYS_READ_CHAR
                        XREF            SYS_READ_CSTRING_SILENT_UPPER
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HBLINE
                        XREF            SYS_WRITE_HBSTRING
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            UTL_CHAR_IS_PRINTABLE
                        XREF            CMDP_ADV_PTR
                        XREF            CMDP_INC_ADDR
                        XREF            CMDP_IS_DELIM_OR_NUL
                        XREF            CMDP_MSG_MOD_OK_1
                        XREF            CMDP_MSG_MOD_OK_2
                        XREF            CMDP_MSG_USAGE_COPY
                        XREF            CMDP_MSG_USAGE_DISPLAY
                        XREF            CMDP_MSG_USAGE_FILL
                        XREF            CMDP_MSG_USAGE_HELP
                        XREF            CMDP_MSG_USAGE_KEYTEST
                        XREF            CMDP_MSG_USAGE_LOAD
                        XREF            CMDP_MSG_USAGE_MODIFY
                        XREF            CMDP_MSG_USAGE_QUIT
                        XREF            CMDP_PARSE_HEX_BYTE_ADV
                        XREF            CMDP_PARSE_HEX_BYTE_TOKEN
                        XREF            CMDP_PARSE_HEX_WORD_TOKEN
                        XREF            CMDP_PEEK_CHAR
                        XREF            CMDP_REQUIRE_EOL
                        XREF            CMDP_SKIP_SPACES
                        XREF            CMDP_TO_UPPER_A
                        XREF            CMDP_USAGE_LINE_XY
                        XREF            MSG_HELP_1
                        XREF            MSG_HELP_2
                        XREF            MSG_HELP_3
                        XREF            MSG_HELP_4
                        XREF            MSG_HELP_5
                        XREF            MSG_HELP_6
                        XREF            MSG_HELP_7
                        XREF            MSG_KEYTEST_CHAR
                        XREF            MSG_KEYTEST_CLASS_CTRL
                        XREF            MSG_KEYTEST_CLASS_PRINT_DIGIT
                        XREF            MSG_KEYTEST_CLASS_PRINT_LOWER
                        XREF            MSG_KEYTEST_CLASS_PRINT_PUNCT
                        XREF            MSG_KEYTEST_CLASS_PRINT_SPACE
                        XREF            MSG_KEYTEST_CLASS_PRINT_UPPER
                        XREF            MSG_KEYTEST_ESCSEQ
                        XREF            MSG_KEYTEST_EXIT
                        XREF            MSG_KEYTEST_FALSE
                        XREF            MSG_KEYTEST_HDR
                        XREF            MSG_KEYTEST_HEX
                        XREF            MSG_KEYTEST_ISPRINT
                        XREF            MSG_KEYTEST_NONPRINT
                        XREF            MSG_KEYTEST_NOTE
                        XREF            MSG_KEYTEST_PROMPT
                        XREF            MSG_KEYTEST_TRUE
                        XREF            MSG_KEYTEST_TYPE
                        XREF            MSG_LOAD_ADDR_UNKNOWN
                        XREF            MSG_LOAD_DONE_LEN
                        XREF            MSG_LOAD_GO_EXEC
                        XREF            MSG_LOAD_GO_MISSING
                        XREF            MSG_LOAD_LINE_STATUS
                        XREF            MSG_LOAD_NO_GO
                        XREF            MSG_LOAD_PARSE_FAIL
                        XREF            MSG_LOAD_RANGE_HDR
                        XREF            MSG_LOAD_RANGE_OVF
                        XREF            MSG_LOAD_READY
                        XREF            MSG_LOAD_SUM_BYTES
                        XREF            MSG_LOAD_SUM_END
                        XREF            MSG_LOAD_SUM_GO
                        XREF            MSG_LOAD_SUM_IGNORED
                        XREF            MSG_LOAD_SUM_OK_START
                        XREF            MSG_LOAD_SUM_REC


                        INCLUDE         "TEST/apps/himon-shared-eq.inc"

                        CODE
CMDP_GET_TOKEN_LEN:
                        LDY             #$00
CMDP_GET_TOKEN_LEN_LOOP:
                        LDA             (CMDP_PTR_LO),Y
                        JSR             CMDP_IS_DELIM_OR_NUL
                        BCS             CMDP_GET_TOKEN_LEN_DONE
                        INY
                        BNE             CMDP_GET_TOKEN_LEN_LOOP
                        CLC
                        RTS
CMDP_GET_TOKEN_LEN_DONE:
                        TYA
                        SEC
                        RTS

CMDP_TBL_GET_ENTRY_LEN:
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        BEQ             CMDP_TBL_GET_ENTRY_LEN_FAIL
CMDP_TBL_GET_ENTRY_LEN_LOOP:
                        LDA             (CMDP_START_LO),Y
                        BMI             CMDP_TBL_GET_ENTRY_LEN_DONE
                        INY
                        BNE             CMDP_TBL_GET_ENTRY_LEN_LOOP
CMDP_TBL_GET_ENTRY_LEN_FAIL:
                        CLC
                        RTS
CMDP_TBL_GET_ENTRY_LEN_DONE:
                        INY
                        STY             CMDP_ENTRY_LEN
                        SEC
                        RTS

CMDP_TBL_MATCH_CURRENT:
                        LDA             CMDP_ENTRY_LEN
                        CMP             CMDP_TOKEN_LEN
                        BNE             CMDP_TBL_MATCH_FAIL
                        LDY             #$00
CMDP_TBL_MATCH_LOOP:
                        CPY             CMDP_TOKEN_LEN
                        BEQ             CMDP_TBL_MATCH_DONE
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_TO_UPPER_A
                        STA             CMDP_BYTE_TMP
                        LDA             (CMDP_START_LO),Y
                        AND             #$7F
                        CMP             CMDP_BYTE_TMP
                        BNE             CMDP_TBL_MATCH_FAIL
                        INY
                        BNE             CMDP_TBL_MATCH_LOOP
CMDP_TBL_MATCH_FAIL:
                        CLC
                        RTS
CMDP_TBL_MATCH_DONE:
                        LDA             CMDP_ADDR_LO
                        CLC
                        ADC             CMDP_TOKEN_LEN
                        STA             CMDP_PTR_LO
                        LDA             CMDP_ADDR_HI
                        ADC             #$00
                        STA             CMDP_PTR_HI
                        SEC
                        RTS

CMDP_TBL_GET_ROUTINE_PTR:
                        LDY             CMDP_ENTRY_LEN
                        LDA             (CMDP_START_LO),Y
                        STA             CMDP_ADDR_LO
                        INY
                        LDA             (CMDP_START_LO),Y
                        STA             CMDP_ADDR_HI
                        RTS

CMDP_CALL_ROUTINE_PTR:
                        JMP             (CMDP_ADDR_LO)

CMDP_TBL_ADVANCE_NEXT:
                        LDA             CMDP_START_LO
                        CLC
                        ADC             CMDP_ENTRY_LEN
                        ADC             #$02
                        STA             CMDP_START_LO
                        LDA             CMDP_START_HI
                        ADC             #$00
                        STA             CMDP_START_HI
                        SEC
                        RTS

MON_CMD_QUIT:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_QUIT_USAGE
                        BRK             $65
                        SEC
                        RTS

MON_CMD_QUIT_USAGE:
                        LDX             #<CMDP_MSG_USAGE_QUIT
                        LDY             #>CMDP_MSG_USAGE_QUIT
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_DISPLAY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_DISPLAY_USAGE
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_DISPLAY_USAGE

                        JSR             MON_DISPLAY_EXEC_256
                        SEC
                        RTS

MON_CMD_DISPLAY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_DISPLAY
                        LDY             #>CMDP_MSG_USAGE_DISPLAY
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_FILL:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_FILL_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CMD_FILL_USAGE
                        STA             CMDP_REMAIN
                        LDA             CMDP_REMAIN
                        BEQ             MON_CMD_FILL_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CMD_FILL_USAGE
                        STA             CMDP_BYTE_TMP
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_FILL_USAGE

MON_FILL_LOOP:
                        LDY             #$00
                        LDA             CMDP_BYTE_TMP
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        DEC             CMDP_REMAIN
                        BNE             MON_FILL_LOOP
                        SEC
                        RTS

MON_CMD_FILL_USAGE:
                        LDX             #<CMDP_MSG_USAGE_FILL
                        LDY             #>CMDP_MSG_USAGE_FILL
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_COPY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_COPY_USAGE
                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI

                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_COPY_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CMD_COPY_USAGE
                        STA             CMDP_REMAIN
                        LDA             CMDP_REMAIN
                        BEQ             MON_CMD_COPY_USAGE
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_COPY_USAGE

                        LDA             CMDP_ADDR_LO
                        ; dst ptr in CMDP_PTR
                        STA             CMDP_PTR_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_PTR_HI
                        LDA             CMDP_START_LO
                        ; src ptr in CMDP_ADDR
                        STA             CMDP_ADDR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_ADDR_HI

MON_COPY_LOOP:
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             (CMDP_PTR_LO),Y
                        JSR             CMDP_INC_ADDR
                        JSR             CMDP_ADV_PTR
                        DEC             CMDP_REMAIN
                        BNE             MON_COPY_LOOP
                        SEC
                        RTS

MON_CMD_COPY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_COPY
                        LDY             #>CMDP_MSG_USAGE_COPY
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_MODIFY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_MODIFY_USAGE

                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI
                        STZ             CMDP_MOD_COUNT

MON_MODIFY_PARSE_LOOP:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_MODIFY_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CMD_MODIFY_USAGE
                        LDY             #$00
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        INC             CMDP_MOD_COUNT
                        BRA             MON_MODIFY_PARSE_LOOP

MON_MODIFY_DONE:
                        LDA             CMDP_MOD_COUNT
                        BEQ             MON_CMD_MODIFY_USAGE

                        LDX             #<CMDP_MSG_MOD_OK_1
                        LDY             #>CMDP_MSG_MOD_OK_1
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMDP_MOD_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<CMDP_MSG_MOD_OK_2
                        LDY             #>CMDP_MSG_MOD_OK_2
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMDP_START_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_START_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        SEC
                        RTS

MON_CMD_MODIFY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_MODIFY
                        LDY             #>CMDP_MSG_USAGE_MODIFY
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_HELP:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_HELP_USAGE
                        LDX             #<MSG_HELP_1
                        LDY             #>MSG_HELP_1
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_2
                        LDY             #>MSG_HELP_2
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_3
                        LDY             #>MSG_HELP_3
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_4
                        LDY             #>MSG_HELP_4
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_5
                        LDY             #>MSG_HELP_5
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_6
                        LDY             #>MSG_HELP_6
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_7
                        LDY             #>MSG_HELP_7
                        JSR             SYS_WRITE_HBLINE
                        SEC
                        RTS

MON_CMD_HELP_USAGE:
                        LDX             #<CMDP_MSG_USAGE_HELP
                        LDY             #>CMDP_MSG_USAGE_HELP
                        JMP             CMDP_USAGE_LINE_XY

; ----------------------------------------------------------------------------
; ROUTINE: MON_CMD_KEYTEST
; TIER: APP-L5
; TAGS: APP-L5, KEYTEST, BLOCKING, READ, WRITE, CARRY-STATUS
; MEM : ZP: none; FIXED_RAM: KEYT_CHAR($7B27), KEYT_ESC_BYTE($7B28).
; PURPOSE: Interactive key classification loop for monitor input.
; IN : command token already matched to KEYTEST.
; OUT: C=1 on clean exit (Ctrl-C), C=0 on usage error.
; EXCEPTIONS/NOTES:
; - ESC-prefixed sequences dump all currently buffered bytes on one line.
; - After ESC sequence dump, normal class/char/hex/isprint reporting continues.
; ----------------------------------------------------------------------------
MON_CMD_KEYTEST:
                        JSR             CMDP_REQUIRE_EOL
                        BCS             MON_CMD_KEYTEST_ARGS_OK
                        JMP             MON_CMD_KEYTEST_USAGE
MON_CMD_KEYTEST_ARGS_OK:
                        LDX             #<MSG_KEYTEST_HDR
                        LDY             #>MSG_KEYTEST_HDR
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_KEYTEST_NOTE
                        LDY             #>MSG_KEYTEST_NOTE
                        JSR             SYS_WRITE_HBLINE
                        JSR             SYS_FLUSH_RX
MON_CMD_KEYTEST_LOOP:
                        LDX             #<MSG_KEYTEST_PROMPT
                        LDY             #>MSG_KEYTEST_PROMPT
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_READ_CHAR
                        CMP             #$03
                        BNE             MON_CMD_KEYTEST_STORE_CHAR
                        JMP             MON_CMD_KEYTEST_EXIT
MON_CMD_KEYTEST_STORE_CHAR:
                        STA             KEYT_CHAR

                        CMP             #$1B
                        BNE             MON_CMD_KEYTEST_REPORT
                        LDX             #<MSG_KEYTEST_ESCSEQ
                        LDY             #>MSG_KEYTEST_ESCSEQ
                        JSR             SYS_WRITE_HBSTRING
                        LDA             KEYT_CHAR
                        JSR             SYS_WRITE_HEX_BYTE
MON_CMD_KEYTEST_ESC_DRAIN:
                        JSR             SYS_POLL_CHAR
                        BCC             MON_CMD_KEYTEST_ESC_DONE
                        JSR             SYS_READ_CHAR
                        STA             KEYT_ESC_BYTE
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             KEYT_ESC_BYTE
                        JSR             SYS_WRITE_HEX_BYTE
                        BRA             MON_CMD_KEYTEST_ESC_DRAIN
MON_CMD_KEYTEST_ESC_DONE:
                        JSR             SYS_WRITE_CRLF

MON_CMD_KEYTEST_REPORT:
                        LDX             #<MSG_KEYTEST_TYPE
                        LDY             #>MSG_KEYTEST_TYPE
                        JSR             SYS_WRITE_HBSTRING
                        LDA             KEYT_CHAR
                        JSR             KEYTEST_WRITE_CLASS_TAG_A
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_KEYTEST_CHAR
                        LDY             #>MSG_KEYTEST_CHAR
                        JSR             SYS_WRITE_HBSTRING
                        LDA             KEYT_CHAR
                        CMP             #' '
                        BCC             MON_CMD_KEYTEST_NONPRINT
                        CMP             #$7F
                        BCS             MON_CMD_KEYTEST_NONPRINT
                        LDA             #$27
                        JSR             SYS_WRITE_CHAR
                        LDA             KEYT_CHAR
                        JSR             SYS_WRITE_CHAR
                        LDA             #$27
                        JSR             SYS_WRITE_CHAR
                        BRA             MON_CMD_KEYTEST_CHAR_DONE
MON_CMD_KEYTEST_NONPRINT:
                        LDX             #<MSG_KEYTEST_NONPRINT
                        LDY             #>MSG_KEYTEST_NONPRINT
                        JSR             SYS_WRITE_HBSTRING
MON_CMD_KEYTEST_CHAR_DONE:
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_KEYTEST_HEX
                        LDY             #>MSG_KEYTEST_HEX
                        JSR             SYS_WRITE_HBSTRING
                        LDA             KEYT_CHAR
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_KEYTEST_ISPRINT
                        LDY             #>MSG_KEYTEST_ISPRINT
                        JSR             SYS_WRITE_HBSTRING
                        LDA             KEYT_CHAR
                        JSR             UTL_CHAR_IS_PRINTABLE
                        BCC             MON_CMD_KEYTEST_ISPRINT_FALSE
                        LDX             #<MSG_KEYTEST_TRUE
                        LDY             #>MSG_KEYTEST_TRUE
                        BRA             MON_CMD_KEYTEST_ISPRINT_WRITE
MON_CMD_KEYTEST_ISPRINT_FALSE:
                        LDX             #<MSG_KEYTEST_FALSE
                        LDY             #>MSG_KEYTEST_FALSE
MON_CMD_KEYTEST_ISPRINT_WRITE:
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_CMD_KEYTEST_LOOP

MON_CMD_KEYTEST_EXIT:
                        LDX             #<MSG_KEYTEST_EXIT
                        LDY             #>MSG_KEYTEST_EXIT
                        JSR             SYS_WRITE_HBLINE
                        SEC
                        RTS

MON_CMD_KEYTEST_USAGE:
                        LDX             #<CMDP_MSG_USAGE_KEYTEST
                        LDY             #>CMDP_MSG_USAGE_KEYTEST
                        JMP             CMDP_USAGE_LINE_XY

; ----------------------------------------------------------------------------
; ROUTINE: KEYTEST_WRITE_CLASS_TAG_A
; TIER: APP-L5
; TAGS: APP-L5, CLASSIFY, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit class tag string for byte in A.
; IN : A = byte to classify
; OUT: class label printed, C = 1
; EXCEPTIONS/NOTES:
; - Tag buckets: CTRL, PRINT-SPACE, PRINT-DIGIT, PRINT-UPPER,
;   PRINT-LOWER, PRINT-PUNCT.
; ----------------------------------------------------------------------------
KEYTEST_WRITE_CLASS_TAG_A:
                        CMP             #$20
                        BCC             KEYTEST_TAG_CTRL
                        CMP             #$7F
                        BCS             KEYTEST_TAG_CTRL

                        CMP             #' '
                        BEQ             KEYTEST_TAG_PRINT_SPACE
                        CMP             #'0'
                        BCC             KEYTEST_TAG_PRINT_PUNCT
                        CMP             #':'
                        BCC             KEYTEST_TAG_PRINT_DIGIT
                        CMP             #'A'
                        BCC             KEYTEST_TAG_PRINT_PUNCT
                        CMP             #'['
                        BCC             KEYTEST_TAG_PRINT_UPPER
                        CMP             #'a'
                        BCC             KEYTEST_TAG_PRINT_PUNCT
                        CMP             #'{'
                        BCC             KEYTEST_TAG_PRINT_LOWER

KEYTEST_TAG_PRINT_PUNCT:
                        LDX             #<MSG_KEYTEST_CLASS_PRINT_PUNCT
                        LDY             #>MSG_KEYTEST_CLASS_PRINT_PUNCT
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS
KEYTEST_TAG_CTRL:
                        LDX             #<MSG_KEYTEST_CLASS_CTRL
                        LDY             #>MSG_KEYTEST_CLASS_CTRL
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS
KEYTEST_TAG_PRINT_SPACE:
                        LDX             #<MSG_KEYTEST_CLASS_PRINT_SPACE
                        LDY             #>MSG_KEYTEST_CLASS_PRINT_SPACE
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS
KEYTEST_TAG_PRINT_DIGIT:
                        LDX             #<MSG_KEYTEST_CLASS_PRINT_DIGIT
                        LDY             #>MSG_KEYTEST_CLASS_PRINT_DIGIT
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS
KEYTEST_TAG_PRINT_UPPER:
                        LDX             #<MSG_KEYTEST_CLASS_PRINT_UPPER
                        LDY             #>MSG_KEYTEST_CLASS_PRINT_UPPER
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS
KEYTEST_TAG_PRINT_LOWER:
                        LDX             #<MSG_KEYTEST_CLASS_PRINT_LOWER
                        LDY             #>MSG_KEYTEST_CLASS_PRINT_LOWER
                        JSR             SYS_WRITE_HBSTRING
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; Command table dispatch (HBSTR command names + DW handler addresses)
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; DISPLAY executor
; ----------------------------------------------------------------------------
MON_DISPLAY_EXEC_256:
                        LDA             #$10
                        STA             CMDP_REMAIN

MON_DISPLAY_LINE:
                        LDA             CMDP_REMAIN
                        BEQ             MON_DISPLAY_DONE

                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDA             #$10
                        STA             CMDP_LINE_REMAIN

MON_DISPLAY_BYTES:
                        LDA             CMDP_LINE_REMAIN
                        BEQ             MON_DISPLAY_END_LINE
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        JSR             CMDP_INC_ADDR
                        DEC             CMDP_LINE_REMAIN
                        BRA             MON_DISPLAY_BYTES

MON_DISPLAY_END_LINE:
                        JSR             SYS_WRITE_CRLF
                        DEC             CMDP_REMAIN
                        BRA             MON_DISPLAY_LINE

MON_DISPLAY_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; LOAD command family
; ----------------------------------------------------------------------------
MON_CMD_LOAD:
                        STZ             LOAD_AUTO_GO
                        JSR             MON_LOAD_VALIDATE_ARGS
                        BCC             MON_CMD_LOAD_USAGE
                        JSR             MON_LOAD_INIT
                        LDX             #<MSG_LOAD_READY
                        LDY             #>MSG_LOAD_READY
                        JSR             SYS_WRITE_HBLINE

MON_CMD_LOAD_SESSION_LOOP:
                        JSR             MON_LOAD_READ_LINE
                        BCC             MON_CMD_LOAD_LINE_FAIL
                        JSR             MON_LOAD_PARSE_RECORD
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_DATA
                        BEQ             MON_CMD_LOAD_HANDLE_DATA
                        CMP             #LOAD_REC_KIND_TERM
                        BEQ             MON_CMD_LOAD_HANDLE_TERM
                        LDA             LOAD_REC_TYPE
                        BEQ             MON_CMD_LOAD_SESSION_LOOP
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        BRA             MON_CMD_LOAD_SESSION_LOOP

MON_CMD_LOAD_HANDLE_DATA:
                        JSR             MON_LOAD_WRITE_RECORD_DATA
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_ACCUM_RECORD_AND_BYTES
                        JSR             MON_LOAD_TRACK_DATA_RANGE
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        BRA             MON_CMD_LOAD_SESSION_LOOP

MON_CMD_LOAD_HANDLE_TERM:
                        JSR             MON_LOAD_CAPTURE_GO
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        JSR             MON_LOAD_FINALIZE_RANGES
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_PRINT_SUMMARY
                        JSR             MON_LOAD_MAYBE_GO
                        RTS

MON_CMD_LOAD_USAGE:
                        LDX             #<CMDP_MSG_USAGE_LOAD
                        LDY             #>CMDP_MSG_USAGE_LOAD
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_LOAD_LINE_FAIL:
                        LDX             #<MSG_LOAD_LINE_STATUS
                        LDY             #>MSG_LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS

MON_CMD_LOAD_PARSE_FAIL:
                        LDX             #<MSG_LOAD_PARSE_FAIL
                        LDY             #>MSG_LOAD_PARSE_FAIL
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_REC_TYPE
                        BEQ             MON_CMD_LOAD_PARSE_FAIL_EOL
                        JSR             SYS_WRITE_CHAR
MON_CMD_LOAD_PARSE_FAIL_EOL:
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_MAYBE_GO  [HASH:7E72]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, CARRY-STATUS, NOSTACK
; PURPOSE: For `LOAD GO`, transfer control to captured GO address.
; OUT: C=1 when no auto-go requested; C=0 when requested but no GO available.
; ----------------------------------------------------------------------------
MON_LOAD_MAYBE_GO:
                        LDA             LOAD_AUTO_GO
                        BEQ             MON_LOAD_MAYBE_GO_DONE
                        LDA             LOAD_GO_VALID
                        BEQ             MON_LOAD_MAYBE_GO_MISSING
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             MON_LOAD_MAYBE_GO_EXEC
                        CLC
                        RTS
MON_LOAD_MAYBE_GO_MISSING:
                        LDX             #<MSG_LOAD_GO_MISSING
                        LDY             #>MSG_LOAD_GO_MISSING
                        JSR             SYS_WRITE_HBLINE
                        CLC
                        RTS
MON_LOAD_MAYBE_GO_EXEC:
                        LDA             LOAD_GO_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_GO_HI
                        STA             CMDP_ADDR_HI
                        LDX             #<MSG_LOAD_GO_EXEC
                        LDY             #>MSG_LOAD_GO_EXEC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             (CMDP_ADDR_LO)
MON_LOAD_MAYBE_GO_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_VALIDATE_ARGS  [HASH:5413]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, LOAD, NOSTACK
; PURPOSE: Validate LOAD args.
; ACCEPTS: LOAD
;          LOAD GO
;          LOAD S19
;          LOAD GO S19
; ----------------------------------------------------------------------------
MON_LOAD_VALIDATE_ARGS:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_VALIDATE_OK_NEAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'G'
                        BEQ             MON_LOAD_VALIDATE_AUTOGO_WORD
                        BRA             MON_LOAD_VALIDATE_FMT_START

MON_LOAD_VALIDATE_AUTOGO_WORD:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'O'
                        BNE             MON_LOAD_VALIDATE_FAIL_NEAR
                        JSR             CMDP_ADV_PTR
                        LDA             #$01
                        STA             LOAD_AUTO_GO
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_VALIDATE_OK_NEAR

MON_LOAD_VALIDATE_FMT_START:
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'S'
                        BNE             MON_LOAD_VALIDATE_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'1'
                        BEQ             MON_LOAD_VALIDATE_19
                        BNE             MON_LOAD_VALIDATE_FAIL_NEAR

MON_LOAD_VALIDATE_OK_NEAR:
                        JMP             MON_LOAD_VALIDATE_OK
MON_LOAD_VALIDATE_FAIL_NEAR:
                        JMP             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_19:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'9'
                        BNE             MON_LOAD_VALIDATE_FAIL
                        JSR             CMDP_ADV_PTR
                        BRA             MON_LOAD_VALIDATE_NEED_EOL

MON_LOAD_VALIDATE_NEED_EOL:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_OK:
                        SEC
                        RTS

MON_LOAD_VALIDATE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_INIT  [HASH:38C3]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Reset LOAD session counters and state.
; ----------------------------------------------------------------------------
MON_LOAD_INIT:
                        STZ             LOAD_LINE_STATUS
                        STZ             LOAD_REC_TYPE
                        STZ             LOAD_REC_KIND
                        STZ             LOAD_ADDR_LEN
                        STZ             LOAD_COUNT
                        STZ             LOAD_DATA_LEN
                        STZ             LOAD_SUM
                        STZ             LOAD_CHK
                        STZ             LOAD_DST_LO
                        STZ             LOAD_DST_HI
                        STZ             LOAD_GO_LO
                        STZ             LOAD_GO_HI
                        STZ             LOAD_GO_VALID
                        STZ             LOAD_TOTAL_LO
                        STZ             LOAD_TOTAL_HI
                        STZ             LOAD_REC_LO
                        STZ             LOAD_REC_HI
                        STZ             LOAD_HAVE_DATA
                        STZ             LOAD_FIRST_LO
                        STZ             LOAD_FIRST_HI
                        STZ             LOAD_LAST_LO
                        STZ             LOAD_LAST_HI
                        STZ             LOAD_CUR_START_LO
                        STZ             LOAD_CUR_START_HI
                        STZ             LOAD_CUR_END_LO
                        STZ             LOAD_CUR_END_HI
                        STZ             LOAD_RANGE_COUNT
                        STZ             LOAD_RANGE_OVF
                        STZ             LOAD_TMP_LO
                        STZ             LOAD_TMP_HI
                        STZ             LOAD_LEN_LO
                        STZ             LOAD_LEN_HI
                        STZ             LOAD_SPAN_LO
                        STZ             LOAD_SPAN_HI
                        STZ             LOAD_PRINT_COUNT
                        STZ             LOAD_CUR_VALID
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_READ_LINE  [HASH:192A]
; TIER: APP-L5
; TAGS: MON, APP-L5, READ, SREC, CARRY-STATUS, NOSTACK
; PURPOSE: Read one incoming S-record text line into LOAD_BUF.
; OUT: C=1 success, C=0 with LOAD_LINE_STATUS set.
; ----------------------------------------------------------------------------
MON_LOAD_READ_LINE:
                        LDX             #<LOAD_BUF
                        LDY             #>LOAD_BUF
                        JSR             SYS_READ_CSTRING_SILENT_UPPER
                        BCS             MON_LOAD_READ_LINE_OK
                        STA             LOAD_LINE_STATUS
                        CLC
                        RTS
MON_LOAD_READ_LINE_OK:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PARSE_RECORD  [HASH:3830]
; TIER: APP-L5
; TAGS: MON, APP-L5, UPPERCASE, SREC, PARSE, STACK
; PURPOSE: Parse one S19 line (S1 data, S9 termination).
; NOTES:
;   - S0/S5 are accepted as non-data records and skipped.
; OUT:
;   - C=1 parse OK.
;   - LOAD_REC_KIND = DATA / TERM / SKIP.
;   - LOAD_DST_HI:LOAD_DST_LO = resolved 16-bit address for DATA/TERM.
; ----------------------------------------------------------------------------
MON_LOAD_PARSE_RECORD:
                        JMP             MON_LOAD_PARSE_BEGIN
MON_LOAD_PARSE_BLANK_NEAR:
                        JMP             MON_LOAD_PARSE_BLANK
MON_LOAD_PARSE_FAIL_NEAR:
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_BEGIN:
                        STZ             LOAD_REC_TYPE
                        STZ             LOAD_REC_KIND
                        STZ             LOAD_ADDR_LEN
                        STZ             LOAD_COUNT
                        STZ             LOAD_DATA_LEN
                        STZ             LOAD_SUM
                        STZ             LOAD_CHK
                        STZ             LOAD_ADDR_B0
                        STZ             LOAD_ADDR_B1
                        STZ             LOAD_ADDR_B2
                        STZ             LOAD_ADDR_B3

                        LDX             #<LOAD_BUF
                        LDY             #>LOAD_BUF
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_PARSE_BLANK_NEAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'S'
                        BNE             MON_LOAD_PARSE_FAIL_NEAR
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_TO_UPPER_A
                        STA             LOAD_REC_TYPE
                        JSR             CMDP_ADV_PTR
                        JSR             MON_LOAD_CLASSIFY_TYPE
                        BCC             MON_LOAD_PARSE_FAIL_NEAR

                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        STA             LOAD_COUNT
                        STA             LOAD_SUM

                        LDA             LOAD_COUNT
                        SEC
                        SBC             LOAD_ADDR_LEN
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        SEC
                        SBC             #$01
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        STA             LOAD_DATA_LEN
                        CMP             #$41
                        BCS             MON_LOAD_PARSE_FAIL_NEAR

                        LDX             #$00
MON_LOAD_PARSE_ADDR_LOOP:
                        CPX             LOAD_ADDR_LEN
                        BEQ             MON_LOAD_PARSE_ADDR_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        PHA
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        PLA
                        STA             LOAD_ADDR_B0,X
                        INX
                        BRA             MON_LOAD_PARSE_ADDR_LOOP
MON_LOAD_PARSE_ADDR_DONE:

                        LDX             #$00
MON_LOAD_PARSE_DATA_LOOP:
                        CPX             LOAD_DATA_LEN
                        BEQ             MON_LOAD_PARSE_DATA_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCS             MON_LOAD_PARSE_DATA_HAVE_BYTE
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_DATA_HAVE_BYTE:
                        PHA
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        PLA
                        STA             LOAD_DATA_BUF,X
                        INX
                        BRA             MON_LOAD_PARSE_DATA_LOOP
MON_LOAD_PARSE_DATA_DONE:

                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCS             MON_LOAD_PARSE_HAVE_CHK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_HAVE_CHK:
                        STA             LOAD_CHK
                        CLC
                        ADC             LOAD_SUM
                        CMP             #$FF
                        BEQ             MON_LOAD_PARSE_CHK_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_CHK_OK:

                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_PARSE_TAIL_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_TAIL_OK:

                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_SKIP
                        BEQ             MON_LOAD_PARSE_OK
                        JSR             MON_LOAD_RESOLVE_ADDR16
                        BCS             MON_LOAD_PARSE_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_OK:
                        SEC
                        RTS

MON_LOAD_PARSE_BLANK:
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

MON_LOAD_PARSE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CLASSIFY_TYPE  [HASH:05C2]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Map S-record type to DATA/TERM/SKIP and expected address length.
; ----------------------------------------------------------------------------
MON_LOAD_CLASSIFY_TYPE:
                        LDA             LOAD_REC_TYPE
                        CMP             #'1'
                        BNE             MON_LOAD_CLASSIFY_NO_S1
                        LDA             #LOAD_REC_KIND_DATA
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S1:
                        CMP             #'9'
                        BNE             MON_LOAD_CLASSIFY_NO_S9
                        LDA             #LOAD_REC_KIND_TERM
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S9:
                        CMP             #'0'
                        BNE             MON_LOAD_CLASSIFY_NO_S0
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S0:
                        CMP             #'5'
                        BNE             MON_LOAD_CLASSIFY_NO_S5
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S5:
                        CLC
                        RTS
MON_LOAD_CLASSIFY_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_RESOLVE_ADDR16  [HASH:8B9C]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Resolve parsed record address into 16-bit target address.
; RULES:
;   - S1/S9: direct 16-bit.
;   - S2/S8: top byte must be 00.
;   - S3/S7: top two bytes must be 00.
; ----------------------------------------------------------------------------
MON_LOAD_RESOLVE_ADDR16:
                        LDA             LOAD_ADDR_LEN
                        CMP             #$02
                        BEQ             MON_LOAD_RESOLVE_16
                        CMP             #$03
                        BEQ             MON_LOAD_RESOLVE_24
                        CMP             #$04
                        BEQ             MON_LOAD_RESOLVE_32
                        CLC
                        RTS

MON_LOAD_RESOLVE_16:
                        LDA             LOAD_ADDR_B0
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B1
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_24:
                        LDA             LOAD_ADDR_B0
                        BNE             MON_LOAD_RESOLVE_FAIL
                        LDA             LOAD_ADDR_B1
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B2
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_32:
                        LDA             LOAD_ADDR_B0
                        ORA             LOAD_ADDR_B1
                        BNE             MON_LOAD_RESOLVE_FAIL
                        LDA             LOAD_ADDR_B2
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B3
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_WRITE_RECORD_DATA  [HASH:E185]
; TIER: APP-L5
; TAGS: MON, APP-L5, WRITE, NOSTACK
; PURPOSE: Write parsed record payload bytes to LOAD_DST address.
; ----------------------------------------------------------------------------
MON_LOAD_WRITE_RECORD_DATA:
                        LDA             LOAD_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             CMDP_ADDR_HI
                        LDX             #$00
MON_LOAD_WRITE_LOOP:
                        CPX             LOAD_DATA_LEN
                        BEQ             MON_LOAD_WRITE_DONE
                        LDA             LOAD_DATA_BUF,X
                        LDY             #$00
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        INX
                        BRA             MON_LOAD_WRITE_LOOP
MON_LOAD_WRITE_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_ACCUM_RECORD_ONLY / MON_LOAD_ACCUM_RECORD_AND_BYTES
; TIER: APP-L5
;   [HASH:B3F1]
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Maintain LOAD session counters.
; ----------------------------------------------------------------------------
MON_LOAD_ACCUM_RECORD_ONLY:
                        INC             LOAD_REC_LO
                        BNE             MON_LOAD_ACC_REC_DONE
                        INC             LOAD_REC_HI
MON_LOAD_ACC_REC_DONE:
                        RTS

MON_LOAD_ACCUM_RECORD_AND_BYTES:
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        CLC
                        LDA             LOAD_TOTAL_LO
                        ADC             LOAD_DATA_LEN
                        STA             LOAD_TOTAL_LO
                        LDA             LOAD_TOTAL_HI
                        ADC             #$00
                        STA             LOAD_TOTAL_HI
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_TRACK_DATA_RANGE  [HASH:0F0F]
; TIER: APP-L5
; TAGS: MON, APP-L5, NOSTACK
; PURPOSE: Track overall span and contiguous ranges for DATA records.
; ----------------------------------------------------------------------------
MON_LOAD_TRACK_DATA_RANGE:
                        LDA             LOAD_DATA_LEN
                        BNE             MON_LOAD_TRACK_HAVE_LEN
MON_LOAD_TRACK_EMPTY:
                        SEC
                        RTS

MON_LOAD_TRACK_HAVE_LEN:

                        ; tmp = record_end = LOAD_DST + LOAD_DATA_LEN - 1
                        CLC
                        LDA             LOAD_DST_LO
                        ADC             LOAD_DATA_LEN
                        STA             LOAD_TMP_LO
                        LDA             LOAD_DST_HI
                        ADC             #$00
                        STA             LOAD_TMP_HI
                        SEC
                        LDA             LOAD_TMP_LO
                        SBC             #$01
                        STA             LOAD_TMP_LO
                        LDA             LOAD_TMP_HI
                        SBC             #$00
                        STA             LOAD_TMP_HI

                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_TRACK_HAVE_DATA

                        ; First DATA record initializes all range state.
                        LDA             #$01
                        STA             LOAD_HAVE_DATA
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_LAST_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_LAST_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_HAVE_DATA:
                        ; first = min(first, current_record_start)
                        LDA             LOAD_DST_HI
                        CMP             LOAD_FIRST_HI
                        BCC             MON_LOAD_TRACK_SET_FIRST
                        BNE             MON_LOAD_TRACK_CHECK_LAST
                        LDA             LOAD_DST_LO
                        CMP             LOAD_FIRST_LO
                        BCC             MON_LOAD_TRACK_SET_FIRST
                        BRA             MON_LOAD_TRACK_CHECK_LAST

MON_LOAD_TRACK_SET_FIRST:
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI

MON_LOAD_TRACK_CHECK_LAST:
                        ; last = max(last, current_record_end)
                        LDA             LOAD_TMP_HI
                        CMP             LOAD_LAST_HI
                        BCC             MON_LOAD_TRACK_CHECK_CUR
                        BNE             MON_LOAD_TRACK_SET_LAST
                        LDA             LOAD_TMP_LO
                        CMP             LOAD_LAST_LO
                        BCC             MON_LOAD_TRACK_CHECK_CUR
                        BEQ             MON_LOAD_TRACK_CHECK_CUR

MON_LOAD_TRACK_SET_LAST:
                        LDA             LOAD_TMP_LO
                        STA             LOAD_LAST_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_LAST_HI

MON_LOAD_TRACK_CHECK_CUR:
                        LDA             LOAD_CUR_VALID
                        BNE             MON_LOAD_TRACK_GAP_CHECK
                        LDA             #$01
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_GAP_CHECK:
                        ; If start > (current_end + 1), commit current range
                        ;   and start new.
                        CLC
                        LDA             LOAD_CUR_END_LO
                        ADC             #$01
                        STA             LOAD_SPAN_LO
                        LDA             LOAD_CUR_END_HI
                        ADC             #$00
                        STA             LOAD_SPAN_HI

                        LDA             LOAD_DST_HI
                        CMP             LOAD_SPAN_HI
                        BCC             MON_LOAD_TRACK_SAME_RANGE
                        BNE             MON_LOAD_TRACK_NEW_RANGE
                        LDA             LOAD_DST_LO
                        CMP             LOAD_SPAN_LO
                        BCC             MON_LOAD_TRACK_SAME_RANGE
                        BEQ             MON_LOAD_TRACK_SAME_RANGE

MON_LOAD_TRACK_NEW_RANGE:
                        JSR             MON_LOAD_COMMIT_CURRENT_RANGE
                        LDA             #$01
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_SAME_RANGE:
                        ; Keep current start as the minimum.
                        LDA             LOAD_DST_HI
                        CMP             LOAD_CUR_START_HI
                        BCC             MON_LOAD_TRACK_SET_CUR_START
                        BNE             MON_LOAD_TRACK_CHECK_CUR_END
                        LDA             LOAD_DST_LO
                        CMP             LOAD_CUR_START_LO
                        BCC             MON_LOAD_TRACK_SET_CUR_START
                        BRA             MON_LOAD_TRACK_CHECK_CUR_END

MON_LOAD_TRACK_SET_CUR_START:
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI

MON_LOAD_TRACK_CHECK_CUR_END:
                        ; Keep current end as the maximum.
                        LDA             LOAD_TMP_HI
                        CMP             LOAD_CUR_END_HI
                        BCC             MON_LOAD_TRACK_DONE
                        BNE             MON_LOAD_TRACK_SET_CUR_END
                        LDA             LOAD_TMP_LO
                        CMP             LOAD_CUR_END_LO
                        BCC             MON_LOAD_TRACK_DONE
                        BEQ             MON_LOAD_TRACK_DONE

MON_LOAD_TRACK_SET_CUR_END:
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI

MON_LOAD_TRACK_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_COMMIT_CURRENT_RANGE  [HASH:DF62]
; TIER: APP-L5
; TAGS: MON, APP-L5, NOSTACK
; PURPOSE: Commit current open range into range list.
; ----------------------------------------------------------------------------
MON_LOAD_COMMIT_CURRENT_RANGE:
                        LDA             LOAD_CUR_VALID
                        BNE             MON_LOAD_COMMIT_HAVE_RANGE
                        SEC
                        RTS

MON_LOAD_COMMIT_HAVE_RANGE:
                        LDA             LOAD_RANGE_COUNT
                        CMP             #LOAD_RANGE_MAX
                        BCS             MON_LOAD_COMMIT_OVF
                        ASL             A
                        ASL             A
                        TAX
                        LDA             LOAD_CUR_START_HI
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_START_LO
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_END_HI
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_END_LO
                        STA             LOAD_RANGE_BASE,X
                        BRA             MON_LOAD_COMMIT_COUNT

MON_LOAD_COMMIT_OVF:
                        LDA             #$01
                        STA             LOAD_RANGE_OVF

MON_LOAD_COMMIT_COUNT:
                        INC             LOAD_RANGE_COUNT
                        STZ             LOAD_CUR_VALID
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_FINALIZE_RANGES  [HASH:BC84]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Close the last open range at end-of-load.
; ----------------------------------------------------------------------------
MON_LOAD_FINALIZE_RANGES:
                        JSR             MON_LOAD_COMMIT_CURRENT_RANGE
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CAPTURE_GO  [HASH:8A14]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Capture entry address from S7/S8/S9 termination record.
; ----------------------------------------------------------------------------
MON_LOAD_CAPTURE_GO:
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_TERM
                        BNE             MON_LOAD_CAPTURE_GO_FAIL
                        LDA             LOAD_DATA_LEN
                        BNE             MON_LOAD_CAPTURE_GO_FAIL
                        LDA             LOAD_DST_LO
                        STA             LOAD_GO_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_GO_HI
                        LDA             #$01
                        STA             LOAD_GO_VALID
                        SEC
                        RTS
MON_LOAD_CAPTURE_GO_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_ONE_RANGE  [HASH:191F]
; TIER: APP-L5
; TAGS: MON, APP-L5, STACK
; PURPOSE: Print one committed range line. IN: X = 0-based range index.
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_ONE_RANGE:
                        LDA             #'R'
                        JSR             SYS_WRITE_CHAR
                        TXA
                        CLC
                        ADC             #$01
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        PHX
                        TXA
                        ASL             A
                        ASL             A
                        TAY

                        LDA             LOAD_RANGE_BASE,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_RANGE_BASE+1,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #'-'
                        JSR             SYS_WRITE_CHAR
                        LDA             LOAD_RANGE_BASE+2,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_RANGE_BASE+3,Y
                        JSR             SYS_WRITE_HEX_BYTE

                        SEC
                        LDA             LOAD_RANGE_BASE+3,Y
                        SBC             LOAD_RANGE_BASE+1,Y
                        STA             LOAD_LEN_LO
                        LDA             LOAD_RANGE_BASE+2,Y
                        SBC             LOAD_RANGE_BASE,Y
                        STA             LOAD_LEN_HI
                        CLC
                        LDA             LOAD_LEN_LO
                        ADC             #$01
                        STA             LOAD_LEN_LO
                        LDA             LOAD_LEN_HI
                        ADC             #$00
                        STA             LOAD_LEN_HI
                        PLX

                        LDX             #<MSG_LOAD_DONE_LEN
                        LDY             #>MSG_LOAD_DONE_LEN
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_LEN_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_LEN_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_SUMMARY  [HASH:5581]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, STACK
; PURPOSE: Print one end-of-load summary (counters, ranges, GO).
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_SUMMARY:
                        LDX             #<MSG_LOAD_SUM_OK_START
                        LDY             #>MSG_LOAD_SUM_OK_START
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_SUMMARY_START_VALUE
                        LDX             #<MSG_LOAD_ADDR_UNKNOWN
                        LDY             #>MSG_LOAD_ADDR_UNKNOWN
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_END_LABEL
MON_LOAD_SUMMARY_START_VALUE:
                        LDA             LOAD_FIRST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_FIRST_LO
                        JSR             SYS_WRITE_HEX_BYTE

MON_LOAD_SUMMARY_END_LABEL:
                        LDX             #<MSG_LOAD_SUM_END
                        LDY             #>MSG_LOAD_SUM_END
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_SUMMARY_END_VALUE
                        LDX             #<MSG_LOAD_ADDR_UNKNOWN
                        LDY             #>MSG_LOAD_ADDR_UNKNOWN
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_BYTES_LABEL
MON_LOAD_SUMMARY_END_VALUE:
                        LDA             LOAD_LAST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_LAST_LO
                        JSR             SYS_WRITE_HEX_BYTE

MON_LOAD_SUMMARY_BYTES_LABEL:
                        LDX             #<MSG_LOAD_SUM_BYTES
                        LDY             #>MSG_LOAD_SUM_BYTES
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_TOTAL_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_TOTAL_LO
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_LOAD_SUM_GO
                        LDY             #>MSG_LOAD_SUM_GO
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_GO_VALID
                        BNE             MON_LOAD_SUMMARY_GO_VALUE
                        LDX             #<MSG_LOAD_NO_GO
                        LDY             #>MSG_LOAD_NO_GO
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_REC_LABEL
MON_LOAD_SUMMARY_GO_VALUE:
                        LDA             LOAD_GO_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             MON_LOAD_SUMMARY_REC_LABEL
                        LDX             #<MSG_LOAD_SUM_IGNORED
                        LDY             #>MSG_LOAD_SUM_IGNORED
                        JSR             SYS_WRITE_HBSTRING

MON_LOAD_SUMMARY_REC_LABEL:
                        LDX             #<MSG_LOAD_SUM_REC
                        LDY             #>MSG_LOAD_SUM_REC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_REC_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_REC_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDA             LOAD_RANGE_COUNT
                        CMP             #$02
                        BCS             MON_LOAD_SUMMARY_RANGES
                        LDA             LOAD_RANGE_OVF
                        BEQ             MON_LOAD_SUMMARY_DONE

MON_LOAD_SUMMARY_RANGES:
                        LDX             #<MSG_LOAD_RANGE_HDR
                        LDY             #>MSG_LOAD_RANGE_HDR
                        JSR             SYS_WRITE_HBLINE

                        LDA             LOAD_RANGE_COUNT
                        CMP             #LOAD_RANGE_MAX
                        BCC             MON_LOAD_SUMMARY_RANGE_COUNT_OK
                        LDA             #LOAD_RANGE_MAX
MON_LOAD_SUMMARY_RANGE_COUNT_OK:
                        STA             LOAD_PRINT_COUNT

                        LDX             #$00
MON_LOAD_SUMMARY_RANGE_LOOP:
                        CPX             LOAD_PRINT_COUNT
                        BEQ             MON_LOAD_SUMMARY_RANGE_DONE
                        JSR             MON_LOAD_PRINT_ONE_RANGE
                        INX
                        BRA             MON_LOAD_SUMMARY_RANGE_LOOP

MON_LOAD_SUMMARY_RANGE_DONE:
                        LDA             LOAD_RANGE_OVF
                        BEQ             MON_LOAD_SUMMARY_DONE
                        LDX             #<MSG_LOAD_RANGE_OVF
                        LDY             #>MSG_LOAD_RANGE_OVF
                        JSR             SYS_WRITE_HBLINE

MON_LOAD_SUMMARY_DONE:
                        RTS



                        ENDMOD

                        END

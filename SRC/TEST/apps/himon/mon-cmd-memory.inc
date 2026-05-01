MON_CMD_DISPLAY:
                        JSR             MON_PARSE_RANGE_DISPLAY
                        BCC             MON_CMD_DISPLAY_USAGE

                        JSR             MON_DISPLAY_EXEC_RANGE
                        LDA             CMDP_START_LO
                        CLC
                        ADC             #$01
                        STA             CMD_DISP_NEXT_LO
                        LDA             CMDP_START_HI
                        ADC             #$00
                        STA             CMD_DISP_NEXT_HI
                        SEC
                        RTS

MON_CMD_DISPLAY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_DISPLAY
                        LDY             #>CMDP_MSG_USAGE_DISPLAY
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_FILL:
                        JSR             MON_PARSE_RANGE_REQUIRED
                        BCC             MON_CMD_FILL_USAGE
                        JSR             MON_PARSE_PATTERN_INLINE_OR_INTERACTIVE
                        BCC             MON_CMD_FILL_USAGE
                        JSR             MON_WRITE_RANGE_PATTERN
                        BCC             MON_CMD_FILL_USAGE
                        SEC
                        RTS

MON_CMD_FILL_USAGE:
                        LDX             #<CMDP_MSG_USAGE_FILL
                        LDY             #>CMDP_MSG_USAGE_FILL
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_COPY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCS             MON_CMD_COPY_HAVE_SRC
                        JMP             MON_CMD_COPY_USAGE
MON_CMD_COPY_HAVE_SRC:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI

                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'+'
                        BEQ             MON_CMD_COPY_HAVE_PLUS
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCS             MON_CMD_COPY_HAVE_SRC_END
                        JMP             MON_CMD_COPY_USAGE

MON_CMD_COPY_HAVE_PLUS:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCS             MON_CMD_COPY_HAVE_PLUS_OK
                        JMP             MON_CMD_COPY_USAGE
MON_CMD_COPY_HAVE_PLUS_OK:
                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             CMDP_ADDR_HI
                        STA             CMDP_START_HI
                        BRA             MON_CMD_COPY_HAVE_RANGE_END

MON_CMD_COPY_HAVE_SRC_END:
                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI

MON_CMD_COPY_HAVE_RANGE_END:
                        LDA             CMDP_START_HI
                        CMP             CMD_RANGE_START_HI
                        BCS             MON_CMD_COPY_RANGE_HI_OK
                        JMP             MON_CMD_COPY_USAGE
MON_CMD_COPY_RANGE_HI_OK:
                        BNE             MON_CMD_COPY_PARSE_DST
                        LDA             CMDP_START_LO
                        CMP             CMD_RANGE_START_LO
                        BCS             MON_CMD_COPY_PARSE_DST

MON_CMD_COPY_PARSE_DST:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCS             MON_CMD_COPY_HAVE_DST
                        JMP             MON_CMD_COPY_USAGE

MON_CMD_COPY_HAVE_DST:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_END_HI
                        JSR             CMDP_REQUIRE_EOL
                        BCS             MON_CMD_COPY_ARGS_OK
                        JMP             MON_CMD_COPY_USAGE

MON_CMD_COPY_ARGS_OK:

                        LDA             CMD_RANGE_START_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMDP_ADDR_HI
                        LDA             CMD_RANGE_END_LO
                        STA             CMDP_PTR_LO
                        LDA             CMD_RANGE_END_HI
                        STA             CMDP_PTR_HI

                        ; length-1 = source_end - source_start
                        LDA             CMDP_START_LO
                        SEC
                        SBC             CMD_RANGE_START_LO
                        STA             CMD_RANGE_TMP_LO
                        LDA             CMDP_START_HI
                        SBC             CMD_RANGE_START_HI
                        STA             CMD_RANGE_TMP_HI

                        ; overlap check:
                        ; forward if dst <= src_start OR dst > src_end
                        ; backward otherwise (dst inside source range)
                        LDA             CMD_RANGE_END_HI
                        CMP             CMD_RANGE_START_HI
                        BCC             MON_COPY_FORWARD
                        BNE             MON_COPY_CHECK_END
                        LDA             CMD_RANGE_END_LO
                        CMP             CMD_RANGE_START_LO
                        BCC             MON_COPY_FORWARD
                        BEQ             MON_COPY_FORWARD

MON_COPY_CHECK_END:
                        LDA             CMD_RANGE_END_HI
                        CMP             CMDP_START_HI
                        BCC             MON_COPY_BACKWARD_SETUP
                        BNE             MON_COPY_FORWARD
                        LDA             CMD_RANGE_END_LO
                        CMP             CMDP_START_LO
                        BCC             MON_COPY_BACKWARD_SETUP
                        BEQ             MON_COPY_BACKWARD_SETUP
                        BRA             MON_COPY_FORWARD

MON_COPY_BACKWARD_SETUP:
                        ; src ptr = source_end
                        LDA             CMDP_START_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_ADDR_HI

                        ; dst ptr = dst_start + (length-1)
                        LDA             CMD_RANGE_END_LO
                        CLC
                        ADC             CMD_RANGE_TMP_LO
                        STA             CMDP_PTR_LO
                        LDA             CMD_RANGE_END_HI
                        ADC             CMD_RANGE_TMP_HI
                        STA             CMDP_PTR_HI

MON_COPY_BACKWARD:
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             (CMDP_PTR_LO),Y
                        LDA             CMDP_ADDR_HI
                        CMP             CMD_RANGE_START_HI
                        BNE             MON_COPY_BACKWARD_STEP
                        LDA             CMDP_ADDR_LO
                        CMP             CMD_RANGE_START_LO
                        BEQ             MON_COPY_DONE
MON_COPY_BACKWARD_STEP:
                        JSR             MON_DEC_ADDR
                        JSR             MON_DEC_PTR
                        BRA             MON_COPY_BACKWARD

MON_COPY_FORWARD:
MON_COPY_FORWARD_LOOP:
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             (CMDP_PTR_LO),Y
                        LDA             CMDP_ADDR_HI
                        CMP             CMDP_START_HI
                        BNE             MON_COPY_FORWARD_STEP
                        LDA             CMDP_ADDR_LO
                        CMP             CMDP_START_LO
                        BEQ             MON_COPY_DONE
MON_COPY_FORWARD_STEP:
                        JSR             CMDP_INC_ADDR
                        JSR             CMDP_ADV_PTR
                        BRA             MON_COPY_FORWARD_LOOP

MON_COPY_DONE:
                        SEC
                        RTS

MON_CMD_COPY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_COPY
                        LDY             #>CMDP_MSG_USAGE_COPY
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_MODIFY:
                        JSR             MON_PARSE_RANGE_REQUIRED
                        BCC             MON_CMD_MODIFY_USAGE
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI

                        JSR             MON_PARSE_PATTERN_INLINE_OR_INTERACTIVE
                        BCC             MON_CMD_MODIFY_USAGE
                        JSR             MON_WRITE_RANGE_PATTERN
                        BCC             MON_CMD_MODIFY_USAGE

                        LDA             CMDP_START_LO
                        SEC
                        SBC             CMD_RANGE_START_LO
                        STA             CMD_RANGE_TMP_LO
                        LDA             CMDP_START_HI
                        SBC             CMD_RANGE_START_HI
                        STA             CMD_RANGE_TMP_HI
                        INC             CMD_RANGE_TMP_LO
                        BNE             MON_MODIFY_COUNT_READY
                        INC             CMD_RANGE_TMP_HI
MON_MODIFY_COUNT_READY:

                        LDX             #<CMDP_MSG_MOD_OK_1
                        LDY             #>CMDP_MSG_MOD_OK_1
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<CMDP_MSG_MOD_OK_2
                        LDY             #>CMDP_MSG_MOD_OK_2
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMD_RANGE_START_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_START_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        SEC
                        RTS

MON_CMD_MODIFY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_MODIFY
                        LDY             #>CMDP_MSG_USAGE_MODIFY
                        JMP             CMDP_USAGE_LINE_XY

; ----------------------------------------------------------------------------
; Shared command helpers (range/pattern/write)
; ----------------------------------------------------------------------------
MON_PARSE_RANGE_REQUIRED:
                        ; mode bit0: allow omitted start address
                        ; mode bit1: default end = start + $FF
                        LDA             #$00
                        JMP             MON_PARSE_RANGE_CORE

MON_PARSE_RANGE_DISPLAY:
                        ; mode bit0: allow omitted start address
                        ; mode bit1: default end = start + $FF
                        LDA             #$03
                        JMP             MON_PARSE_RANGE_CORE

MON_PARSE_RANGE_CORE:
                        STA             CMD_IO_TMP
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_PARSE_RANGE_CORE_NO_START

                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_PARSE_RANGE_CORE_FAIL_NEAR_1
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI
                        BRA             MON_PARSE_RANGE_CORE_END_SELECT
MON_PARSE_RANGE_CORE_FAIL_NEAR_1:
                        JMP             MON_PARSE_RANGE_CORE_FAIL

MON_PARSE_RANGE_CORE_NO_START:
                        LDA             CMD_IO_TMP
                        AND             #$01
                        BEQ             MON_PARSE_RANGE_CORE_FAIL_NEAR_2
                        LDA             CMD_DISP_NEXT_LO
                        STA             CMD_RANGE_START_LO
                        LDA             CMD_DISP_NEXT_HI
                        STA             CMD_RANGE_START_HI
                        BRA             MON_PARSE_RANGE_CORE_DEFAULT_END
MON_PARSE_RANGE_CORE_FAIL_NEAR_2:
                        JMP             MON_PARSE_RANGE_CORE_FAIL

MON_PARSE_RANGE_CORE_END_SELECT:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_PARSE_RANGE_CORE_DEFAULT_END
                        CMP             #'+'
                        BNE             MON_PARSE_RANGE_CORE_END_ABS

                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_PARSE_RANGE_CORE_FAIL
                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             CMDP_ADDR_HI
                        STA             CMDP_START_HI
                        BRA             MON_PARSE_RANGE_CORE_SET_START

MON_PARSE_RANGE_CORE_END_ABS:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_PARSE_RANGE_CORE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI
                        BRA             MON_PARSE_RANGE_CORE_SET_START

MON_PARSE_RANGE_CORE_DEFAULT_END:
                        LDA             CMD_IO_TMP
                        AND             #$02
                        BEQ             MON_PARSE_RANGE_CORE_DEFAULT_SINGLE
                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             #$FF
                        STA             CMDP_START_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             #$00
                        STA             CMDP_START_HI
                        BRA             MON_PARSE_RANGE_CORE_SET_START

MON_PARSE_RANGE_CORE_DEFAULT_SINGLE:
                        LDA             CMD_RANGE_START_LO
                        STA             CMDP_START_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMDP_START_HI

MON_PARSE_RANGE_CORE_SET_START:
                        LDA             CMD_RANGE_START_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMDP_ADDR_HI

                        LDA             CMDP_START_HI
                        CMP             CMDP_ADDR_HI
                        BCC             MON_PARSE_RANGE_CORE_FAIL
                        BNE             MON_PARSE_RANGE_CORE_EOL
                        LDA             CMDP_START_LO
                        CMP             CMDP_ADDR_LO
                        BCC             MON_PARSE_RANGE_CORE_FAIL

                        ; Future DISPLAY format token (reserved, not active in this build):
                        ;   [1] = 1 byte/char view
                        ;   [2], [4], [8], [A], [H], [%] = future display formats
MON_PARSE_RANGE_CORE_EOL:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_PARSE_RANGE_CORE_FAIL
                        SEC
                        RTS
MON_PARSE_RANGE_CORE_FAIL:
                        CLC
                        RTS

MON_PARSE_PATTERN_INLINE_OR_INTERACTIVE:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_PARSE_PATTERN_INTERACTIVE
                        JMP             MON_PARSE_PATTERN_INLINE

MON_PARSE_PATTERN_INLINE:
                        LDX             #$00
MON_PARSE_PATTERN_INLINE_LOOP:
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_PARSE_PATTERN_INLINE_FAIL
                        CPX             #LOAD_DATA_MAX
                        BCS             MON_PARSE_PATTERN_INLINE_FAIL
                        STA             LOAD_DATA_BUF,X
                        INX
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_PARSE_PATTERN_INLINE_DONE
                        BRA             MON_PARSE_PATTERN_INLINE_LOOP
MON_PARSE_PATTERN_INLINE_DONE:
                        STX             CMD_PATTERN_COUNT
                        SEC
                        RTS
MON_PARSE_PATTERN_INLINE_FAIL:
                        CLC
                        RTS

MON_PARSE_PATTERN_INTERACTIVE:
                        LDX             #$00
MON_PARSE_PATTERN_WAIT_FIRST:
                        JSR             SYS_READ_CHAR
                        CMP             #$03
                        BEQ             MON_PARSE_PATTERN_INTERACTIVE_DONE
                        CMP             #'.'
                        BEQ             MON_PARSE_PATTERN_INTERACTIVE_DONE
                        CMP             #' '
                        BEQ             MON_PARSE_PATTERN_WAIT_FIRST
                        CMP             #$09
                        BEQ             MON_PARSE_PATTERN_WAIT_FIRST
                        CMP             #$0D
                        BEQ             MON_PARSE_PATTERN_WAIT_FIRST
                        CMP             #$0A
                        BEQ             MON_PARSE_PATTERN_WAIT_FIRST
                        JSR             MON_HEX_ASCII_TO_NIBBLE
                        BCC             MON_PARSE_PATTERN_INTERACTIVE_FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             CMD_IO_TMP
MON_PARSE_PATTERN_WAIT_SECOND:
                        JSR             SYS_READ_CHAR
                        CMP             #' '
                        BEQ             MON_PARSE_PATTERN_WAIT_SECOND
                        CMP             #$09
                        BEQ             MON_PARSE_PATTERN_WAIT_SECOND
                        CMP             #$0D
                        BEQ             MON_PARSE_PATTERN_WAIT_SECOND
                        CMP             #$0A
                        BEQ             MON_PARSE_PATTERN_WAIT_SECOND
                        JSR             MON_HEX_ASCII_TO_NIBBLE
                        BCC             MON_PARSE_PATTERN_INTERACTIVE_FAIL
                        ORA             CMD_IO_TMP
                        CPX             #LOAD_DATA_MAX
                        BCS             MON_PARSE_PATTERN_INTERACTIVE_FAIL
                        STA             LOAD_DATA_BUF,X
                        INX
                        BRA             MON_PARSE_PATTERN_WAIT_FIRST
MON_PARSE_PATTERN_INTERACTIVE_DONE:
                        CPX             #$00
                        BEQ             MON_PARSE_PATTERN_INTERACTIVE_FAIL
                        STX             CMD_PATTERN_COUNT
                        SEC
                        RTS
MON_PARSE_PATTERN_INTERACTIVE_FAIL:
                        CLC
                        RTS

MON_WRITE_RANGE_PATTERN:
                        LDA             CMD_PATTERN_COUNT
                        BEQ             MON_WRITE_RANGE_PATTERN_FAIL
                        STZ             CMD_PATTERN_INDEX
MON_WRITE_RANGE_PATTERN_LOOP:
                        JSR             MON_ADDR_GT_END
                        BCS             MON_WRITE_RANGE_PATTERN_DONE
                        LDY             CMD_PATTERN_INDEX
                        LDA             LOAD_DATA_BUF,Y
                        LDY             #$00
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        INC             CMD_PATTERN_INDEX
                        LDA             CMD_PATTERN_INDEX
                        CMP             CMD_PATTERN_COUNT
                        BCC             MON_WRITE_RANGE_PATTERN_LOOP
                        STZ             CMD_PATTERN_INDEX
                        BRA             MON_WRITE_RANGE_PATTERN_LOOP
MON_WRITE_RANGE_PATTERN_DONE:
                        SEC
                        RTS
MON_WRITE_RANGE_PATTERN_FAIL:
                        CLC
                        RTS

MON_ADDR_GT_END:
                        LDA             CMDP_ADDR_HI
                        CMP             CMDP_START_HI
                        BCC             MON_ADDR_GT_END_FALSE
                        BNE             MON_ADDR_GT_END_TRUE
                        LDA             CMDP_ADDR_LO
                        CMP             CMDP_START_LO
                        BCC             MON_ADDR_GT_END_FALSE
                        BEQ             MON_ADDR_GT_END_FALSE
MON_ADDR_GT_END_TRUE:
                        SEC
                        RTS
MON_ADDR_GT_END_FALSE:
                        CLC
                        RTS

MON_DEC_ADDR:
                        LDA             CMDP_ADDR_LO
                        BNE             MON_DEC_ADDR_ONLY_LO
                        DEC             CMDP_ADDR_HI
MON_DEC_ADDR_ONLY_LO:
                        DEC             CMDP_ADDR_LO
                        RTS

MON_DEC_PTR:
                        LDA             CMDP_PTR_LO
                        BNE             MON_DEC_PTR_ONLY_LO
                        DEC             CMDP_PTR_HI
MON_DEC_PTR_ONLY_LO:
                        DEC             CMDP_PTR_LO
                        RTS

MON_HEX_ASCII_TO_NIBBLE:
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'0'
                        BCC             MON_HEX_ASCII_TO_NIBBLE_FAIL
                        CMP             #':'
                        BCC             MON_HEX_ASCII_TO_NIBBLE_DIGIT
                        CMP             #'A'
                        BCC             MON_HEX_ASCII_TO_NIBBLE_FAIL
                        CMP             #'G'
                        BCS             MON_HEX_ASCII_TO_NIBBLE_FAIL
                        SEC
                        SBC             #$37
                        SEC
                        RTS
MON_HEX_ASCII_TO_NIBBLE_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
MON_HEX_ASCII_TO_NIBBLE_FAIL:
                        CLC
                        RTS

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
                        LDX             #<MSG_HELP_8
                        LDY             #>MSG_HELP_8
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HELP_9
                        LDY             #>MSG_HELP_9
                        JSR             SYS_WRITE_HBLINE
                        SEC
                        RTS

MON_CMD_HELP_USAGE:
                        LDX             #<CMDP_MSG_USAGE_HELP
                        LDY             #>CMDP_MSG_USAGE_HELP
                        JMP             CMDP_USAGE_LINE_XY

; ----------------------------------------------------------------------------
; ROUTINE: MON_CMD_KEYTEST  [HASH:37F57716]
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
; ROUTINE: KEYTEST_WRITE_CLASS_TAG_A  [HASH:4709F7F8]
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
                        LDA             CMDP_ADDR_LO
                        CLC
                        ADC             #$FF
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        ADC             #$00
                        STA             CMDP_START_HI
                        JMP             MON_DISPLAY_EXEC_RANGE

MON_DISPLAY_EXEC_RANGE:
MON_DISPLAY_LINE:
                        JSR             MON_ADDR_GT_END
                        BCS             MON_DISPLAY_DONE

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
                        JSR             MON_ADDR_GT_END
                        BCS             MON_DISPLAY_END_LINE
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
                        BRA             MON_DISPLAY_LINE

MON_DISPLAY_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; LOAD command family
; ----------------------------------------------------------------------------

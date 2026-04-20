
; ----------------------------------------------------------------------------
; Command monitor shell:
; - Reads one line at a time.
; - Parses and executes DISPLAY/FILL/COPY/MODIFY/QUIT in this file.
; ----------------------------------------------------------------------------

                        MODULE          CMD_APP

                        XDEF            START

                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            UTL_FIND_CHAR_CSTR
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_LINE_XY
                        XREF            SYS_WRITE_LINE_RTL_XY

CMD_BUF                    EQU             $7C00
CMD_LEN                    EQU             $7B00
CMD_LINE_STATUS            EQU             $7B01
CMDP_PTR_LO                EQU             $F0
CMDP_PTR_HI                EQU             $F1
CMDP_ADDR_LO               EQU             $F2
CMDP_ADDR_HI               EQU             $F3
CMDP_START_LO              EQU             $F4
CMDP_START_HI              EQU             $F5

CMDP_REMAIN                EQU             $7B20
CMDP_LINE_REMAIN           EQU             $7B21
CMDP_MOD_COUNT             EQU             $7B22
CMDP_NIB_HI                EQU             $7B23
CMDP_BYTE_TMP              EQU             $7B24

                        CODE
START:
                        JSR             COR_FTDI_INIT
                        JSR             COR_FTDI_FLUSH_RX
                        LDX             #<MSG_HDR_1
                        LDY             #>MSG_HDR_1
                        JSR             SYS_WRITE_LINE_XY
                        LDX             #<MSG_HDR_2
                        LDY             #>MSG_HDR_2
                        JSR             SYS_WRITE_LINE_RTL_XY
                        LDX             #<MSG_HDR_3
                        LDY             #>MSG_HDR_3
                        JSR             SYS_WRITE_LINE_XY

CMD_MAIN_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             SYS_WRITE_CSTRING

                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             COR_FTDI_READ_CSTRING_ECHO
                        BCS             CMD_HAVE_LINE

                        ; Handle C=0 statuses from line reader (BS/DEL/full),
                        ;   then retry.
                        STA             CMD_LINE_STATUS
                        LDX             #<MSG_LINE_STATUS
                        LDY             #>MSG_LINE_STATUS
                        JSR             SYS_WRITE_CSTRING
                        LDA             CMD_LINE_STATUS
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDX             #<MSG_RETRY
                        LDY             #>MSG_RETRY
                        JSR             SYS_WRITE_CSTRING
                        JSR             COR_FTDI_WRITE_CRLF
                        BRA             CMD_MAIN_LOOP

CMD_HAVE_LINE:
                        STA             CMD_LEN
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             CMD_PARSE_AND_EXECUTE
                        BRA             CMD_MAIN_LOOP


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE  [HASH:0818]
; TIER: APP-L5
; TAGS: CMD, APP-L5, NUL-TERM, PARSE, CARRY-STATUS, CALLS_COR, STACK
; PURPOSE: Parse and execute one command line.
; IN : X/Y = pointer to NUL-terminated command line
; OUT: C=1 command handled/success; C=0 unknown command or usage error
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE:
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             CMDP_EMPTY_OK

                        JSR             CMDP_MATCH_DISPLAY
                        BCS             CMDP_RUN_DISPLAY
                        JSR             CMDP_MATCH_FILL
                        BCC             CMDP_PARSE_NO_FILL
                        JMP             CMDP_RUN_FILL
CMDP_PARSE_NO_FILL:
                        JSR             CMDP_MATCH_COPY
                        BCC             CMDP_PARSE_NO_COPY
                        JMP             CMDP_RUN_COPY
CMDP_PARSE_NO_COPY:
                        JSR             CMDP_MATCH_MODIFY
                        BCC             CMDP_PARSE_NO_MODIFY
                        JMP             CMDP_RUN_MODIFY
CMDP_PARSE_NO_MODIFY:
                        JSR             CMDP_MATCH_QUIT
                        BCS             CMDP_RUN_QUIT

                        LDX             #<CMDP_MSG_ERR_UNKNOWN
                        LDY             #>CMDP_MSG_ERR_UNKNOWN
                        JSR             SYS_WRITE_LINE_XY
                        CLC
                        RTS

CMDP_EMPTY_OK:
                        SEC
                        RTS

CMDP_RUN_QUIT:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             CMDP_QUIT_USAGE
                        BRK             $65
                        SEC
                        RTS

CMDP_QUIT_USAGE:
                        LDX             #<CMDP_MSG_USAGE_QUIT
                        LDY             #>CMDP_MSG_USAGE_QUIT
                        JMP             CMDP_USAGE_LINE_XY

CMDP_RUN_DISPLAY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             CMDP_DISPLAY_USAGE
                        JSR             CMDP_REQUIRE_EOL
                        BCC             CMDP_DISPLAY_USAGE

                        JSR             CMDP_EXEC_DISPLAY_256
                        SEC
                        RTS

CMDP_DISPLAY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_DISPLAY
                        LDY             #>CMDP_MSG_USAGE_DISPLAY
                        JMP             CMDP_USAGE_LINE_XY

CMDP_RUN_FILL:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             CMDP_FILL_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             CMDP_FILL_USAGE
                        STA             CMDP_REMAIN
                        LDA             CMDP_REMAIN
                        BEQ             CMDP_FILL_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             CMDP_FILL_USAGE
                        STA             CMDP_BYTE_TMP
                        JSR             CMDP_REQUIRE_EOL
                        BCC             CMDP_FILL_USAGE

CMDP_FILL_LOOP:
                        LDY             #$00
                        LDA             CMDP_BYTE_TMP
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        DEC             CMDP_REMAIN
                        BNE             CMDP_FILL_LOOP
                        SEC
                        RTS

CMDP_FILL_USAGE:
                        LDX             #<CMDP_MSG_USAGE_FILL
                        LDY             #>CMDP_MSG_USAGE_FILL
                        JMP             CMDP_USAGE_LINE_XY

CMDP_RUN_COPY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             CMDP_COPY_USAGE
                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI

                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             CMDP_COPY_USAGE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             CMDP_COPY_USAGE
                        STA             CMDP_REMAIN
                        LDA             CMDP_REMAIN
                        BEQ             CMDP_COPY_USAGE
                        JSR             CMDP_REQUIRE_EOL
                        BCC             CMDP_COPY_USAGE

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

CMDP_COPY_LOOP:
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             (CMDP_PTR_LO),Y
                        JSR             CMDP_INC_ADDR
                        JSR             CMDP_ADV_PTR
                        DEC             CMDP_REMAIN
                        BNE             CMDP_COPY_LOOP
                        SEC
                        RTS

CMDP_COPY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_COPY
                        LDY             #>CMDP_MSG_USAGE_COPY
                        JMP             CMDP_USAGE_LINE_XY

CMDP_RUN_MODIFY:
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             CMDP_MODIFY_USAGE

                        LDA             CMDP_ADDR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMDP_START_HI
                        STZ             CMDP_MOD_COUNT

CMDP_MODIFY_PARSE_LOOP:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             CMDP_MODIFY_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             CMDP_MODIFY_USAGE
                        LDY             #$00
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        INC             CMDP_MOD_COUNT
                        BRA             CMDP_MODIFY_PARSE_LOOP

CMDP_MODIFY_DONE:
                        LDA             CMDP_MOD_COUNT
                        BEQ             CMDP_MODIFY_USAGE

                        LDX             #<CMDP_MSG_MOD_OK_1
                        LDY             #>CMDP_MSG_MOD_OK_1
                        JSR             SYS_WRITE_CSTRING
                        LDA             CMDP_MOD_COUNT
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDX             #<CMDP_MSG_MOD_OK_2
                        LDY             #>CMDP_MSG_MOD_OK_2
                        JSR             SYS_WRITE_CSTRING
                        LDA             CMDP_START_HI
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDA             CMDP_START_LO
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        JSR             COR_FTDI_WRITE_CRLF
                        SEC
                        RTS

CMDP_MODIFY_USAGE:
                        LDX             #<CMDP_MSG_USAGE_MODIFY
                        LDY             #>CMDP_MSG_USAGE_MODIFY
                        JMP             CMDP_USAGE_LINE_XY


; ----------------------------------------------------------------------------
; Command matching
; ----------------------------------------------------------------------------
CMDP_MATCH_DISPLAY:
                        LDX             #<CMDP_LIT_DISPLAY
                        LDY             #>CMDP_LIT_DISPLAY
                        JMP             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_FILL:
                        LDX             #<CMDP_LIT_FILL
                        LDY             #>CMDP_LIT_FILL
                        JMP             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_COPY:
                        LDX             #<CMDP_LIT_COPY
                        LDY             #>CMDP_LIT_COPY
                        JMP             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_MODIFY:
                        LDX             #<CMDP_LIT_MODIFY
                        LDY             #>CMDP_LIT_MODIFY
                        JMP             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_QUIT:
                        LDX             #<CMDP_LIT_QUIT
                        LDY             #>CMDP_LIT_QUIT
                        JMP             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_LITERAL_XY:
                        STX             CMDP_START_LO
                        STY             CMDP_START_HI
                        LDY             #$00
CMDP_MATCH_LITERAL_LOOP:
                        LDA             (CMDP_START_LO),Y
                        BEQ             CMDP_MATCH_LITERAL_DONE
                        STA             CMDP_BYTE_TMP
                        LDA             (CMDP_PTR_LO),Y
                        JSR             CMDP_TO_UPPER_A
                        CMP             CMDP_BYTE_TMP
                        BNE             CMDP_MATCH_LITERAL_FAIL
                        INY
                        BNE             CMDP_MATCH_LITERAL_LOOP
CMDP_MATCH_LITERAL_FAIL:
                        CLC
                        RTS
CMDP_MATCH_LITERAL_DONE:
                        LDA             (CMDP_PTR_LO),Y
                        JSR             CMDP_IS_DELIM_OR_NUL
                        BCC             CMDP_MATCH_LITERAL_FAIL
                        JSR             CMDP_ADV_PTR_TO_FOUND_DELIM
                        BCC             CMDP_MATCH_LITERAL_FAIL
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; DISPLAY executor
; ----------------------------------------------------------------------------
CMDP_EXEC_DISPLAY_256:
                        LDA             #$10
                        STA             CMDP_REMAIN

CMDP_DISPLAY_LINE:
                        LDA             CMDP_REMAIN
                        BEQ             CMDP_DISPLAY_DONE

                        LDA             CMDP_ADDR_HI
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR

                        LDA             #$10
                        STA             CMDP_LINE_REMAIN

CMDP_DISPLAY_BYTES:
                        LDA             CMDP_LINE_REMAIN
                        BEQ             CMDP_DISPLAY_END_LINE
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR
                        JSR             CMDP_INC_ADDR
                        DEC             CMDP_LINE_REMAIN
                        BRA             CMDP_DISPLAY_BYTES

CMDP_DISPLAY_END_LINE:
                        JSR             COR_FTDI_WRITE_CRLF
                        DEC             CMDP_REMAIN
                        BRA             CMDP_DISPLAY_LINE

CMDP_DISPLAY_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; Parse helpers
; ----------------------------------------------------------------------------
CMDP_REQUIRE_EOL:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             CMDP_REQUIRE_EOL_OK
                        CLC
                        RTS
CMDP_REQUIRE_EOL_OK:
                        SEC
                        RTS

CMDP_USAGE_LINE_XY:
                        JSR             SYS_WRITE_LINE_XY
                        CLC
                        RTS

CMDP_PARSE_HEX_WORD_TOKEN:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_SKIP_OPTIONAL_DOLLAR
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             CMDP_PARSE_HEX_WORD_FAIL
                        STA             CMDP_ADDR_HI
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             CMDP_PARSE_HEX_WORD_FAIL
                        STA             CMDP_ADDR_LO
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_IS_DELIM_OR_NUL
                        BCC             CMDP_PARSE_HEX_WORD_FAIL
                        SEC
                        RTS
CMDP_PARSE_HEX_WORD_FAIL:
                        CLC
                        RTS

CMDP_PARSE_HEX_BYTE_TOKEN:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_SKIP_OPTIONAL_DOLLAR
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             CMDP_PARSE_HEX_BYTE_TOKEN_FAIL
                        STA             CMDP_BYTE_TMP
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_IS_DELIM_OR_NUL
                        BCC             CMDP_PARSE_HEX_BYTE_TOKEN_FAIL
                        LDA             CMDP_BYTE_TMP
                        SEC
                        RTS
CMDP_PARSE_HEX_BYTE_TOKEN_FAIL:
                        CLC
                        RTS

CMDP_PARSE_HEX_BYTE_ADV:
                        JSR             CMDP_PARSE_HEX_NIBBLE_ADV
                        BCC             CMDP_PARSE_HEX_BYTE_ADV_FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             CMDP_NIB_HI
                        JSR             CMDP_PARSE_HEX_NIBBLE_ADV
                        BCC             CMDP_PARSE_HEX_BYTE_ADV_FAIL
                        ORA             CMDP_NIB_HI
                        SEC
                        RTS
CMDP_PARSE_HEX_BYTE_ADV_FAIL:
                        CLC
                        RTS

CMDP_PARSE_HEX_NIBBLE_ADV:
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_HEX_ASCII_TO_NIBBLE
                        BCC             CMDP_PARSE_HEX_NIBBLE_ADV_FAIL
                        PHA
                        JSR             CMDP_ADV_PTR
                        PLA
                        SEC
                        RTS
CMDP_PARSE_HEX_NIBBLE_ADV_FAIL:
                        CLC
                        RTS

CMDP_SKIP_OPTIONAL_DOLLAR:
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'$'
                        BNE             CMDP_SKIP_OPTIONAL_DOLLAR_DONE
                        JSR             CMDP_ADV_PTR
CMDP_SKIP_OPTIONAL_DOLLAR_DONE:
                        RTS


; ----------------------------------------------------------------------------
; Generic scanner helpers
; ----------------------------------------------------------------------------
CMDP_SKIP_SPACES:
                        JSR             CMDP_PEEK_CHAR
                        CMP             #' '
                        BEQ             CMDP_SKIP_SPACES_ADV
                        CMP             #$09
                        BEQ             CMDP_SKIP_SPACES_ADV
                        RTS
CMDP_SKIP_SPACES_ADV:
                        JSR             CMDP_ADV_PTR
                        BRA             CMDP_SKIP_SPACES

CMDP_PEEK_CHAR:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        RTS

CMDP_ADV_PTR:
                        INC             CMDP_PTR_LO
                        BNE             CMDP_ADV_PTR_DONE
                        INC             CMDP_PTR_HI
CMDP_ADV_PTR_DONE:
                        RTS

; IN : A = delimiter byte already verified present at/after CMDP_PTR
; OUT: CMDP_PTR advanced to:
;      - just after delimiter when delimiter != 0
;      - NUL terminator when delimiter == 0
;      C = 1 on success, C = 0 only on unexpected scan cap
CMDP_ADV_PTR_TO_FOUND_DELIM:
                        PHA
                        LDX             CMDP_PTR_LO
                        LDY             CMDP_PTR_HI
                        PLA
                        JSR             UTL_FIND_CHAR_CSTR
                        BCC             CMDP_ADV_PTR_TO_FOUND_DELIM_FAIL
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        SEC
                        RTS
CMDP_ADV_PTR_TO_FOUND_DELIM_FAIL:
                        CLC
                        RTS

CMDP_INC_ADDR:
                        INC             CMDP_ADDR_LO
                        BNE             CMDP_INC_ADDR_DONE
                        INC             CMDP_ADDR_HI
CMDP_INC_ADDR_DONE:
                        RTS

CMDP_IS_DELIM_OR_NUL:
                        CMP             #$00
                        BEQ             CMDP_IS_DELIM_TRUE
                        CMP             #' '
                        BEQ             CMDP_IS_DELIM_TRUE
                        CMP             #$09
                        BEQ             CMDP_IS_DELIM_TRUE
                        CLC
                        RTS
CMDP_IS_DELIM_TRUE:
                        SEC
                        RTS

CMDP_TO_UPPER_A:
                        CMP             #'a'
                        BCC             CMDP_TO_UPPER_DONE
                        CMP             #'{'
                        BCS             CMDP_TO_UPPER_DONE
                        AND             #$DF
CMDP_TO_UPPER_DONE:
                        RTS

CMDP_HEX_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             CMDP_HXN_BAD
                        CMP             #':'
                        BCC             CMDP_HXN_DIGIT
                        CMP             #'A'
                        BCC             CMDP_HXN_CHECK_LOWER
                        CMP             #'G'
                        BCC             CMDP_HXN_UPPER
CMDP_HXN_CHECK_LOWER:
                        CMP             #'a'
                        BCC             CMDP_HXN_BAD
                        CMP             #'g'
                        BCS             CMDP_HXN_BAD
                        SEC
                        SBC             #$57
                        SEC
                        RTS
CMDP_HXN_UPPER:
                        SEC
                        SBC             #$37
                        SEC
                        RTS
CMDP_HXN_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
CMDP_HXN_BAD:
                        CLC
                        RTS

                        DATA
CMDP_LIT_DISPLAY:        DB              "DISPLAY",$00
CMDP_LIT_FILL:           DB              "FILL",$00
CMDP_LIT_COPY:           DB              "COPY",$00
CMDP_LIT_MODIFY:         DB              "MODIFY",$00
CMDP_LIT_QUIT:           DB              "QUIT",$00
MSG_HDR_1:               DB              $0d, $0a,"R-YORS command monitor",$00
MSG_HDR_2:               DB              "DISPLAY FILL COPY MODIFY QUIT",$00
MSG_HDR_3:               DB              $00
MSG_PROMPT:              DB              "cmd> ",$00
MSG_LINE_STATUS:         DB              "line status=$",$00
MSG_RETRY:               DB              " (retry)",$00
CMDP_MSG_ERR_UNKNOWN:    DB              "ERR: unknown command",$00
CMDP_MSG_USAGE_DISPLAY:  DB              "usage: DISPLAY <addr16>",$00
CMDP_MSG_USAGE_FILL: DB "usage: FILL <addr16> <count8> <byte8>",$00
CMDP_MSG_USAGE_COPY: DB "usage: COPY <src16> <dst16> <count8>",$00
CMDP_MSG_USAGE_MODIFY: DB "usage: MODIFY <addr16> <byte8> [byte8 ...]",$00
CMDP_MSG_USAGE_QUIT:     DB              "usage: QUIT",$00
CMDP_MSG_MOD_OK_1:       DB              "modified $",$00
CMDP_MSG_MOD_OK_2:       DB              " bytes at $",$00

                        ENDMOD

                        END

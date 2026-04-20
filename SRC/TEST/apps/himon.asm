; ----------------------------------------------------------------------------
; Command monitor shell:
; - Reads one line at a time (C-string input, uppercase).
; - Dispatches commands through HBSTR `CMD_TBL` entries.
; - Executes DISPLAY/FILL/COPY/MODIFY/HELP/LOAD/QUIT handlers in this file.
; ----------------------------------------------------------------------------

                        MODULE          MONITOR_APP

                        XDEF            START
                        XDEF            CMDP_ADV_PTR
                        XDEF            CMDP_INC_ADDR
                        XDEF            CMDP_IS_DELIM_OR_NUL
                        XDEF            CMDP_MSG_MOD_OK_1
                        XDEF            CMDP_MSG_MOD_OK_2
                        XDEF            CMDP_MSG_USAGE_COPY
                        XDEF            CMDP_MSG_USAGE_DISPLAY
                        XDEF            CMDP_MSG_USAGE_FILL
                        XDEF            CMDP_MSG_USAGE_HELP
                        XDEF            CMDP_MSG_USAGE_KEYTEST
                        XDEF            CMDP_MSG_USAGE_LOAD
                        XDEF            CMDP_MSG_USAGE_MODIFY
                        XDEF            CMDP_MSG_USAGE_QUIT
                        XDEF            CMDP_PARSE_HEX_BYTE_ADV
                        XDEF            CMDP_PARSE_HEX_BYTE_TOKEN
                        XDEF            CMDP_PARSE_HEX_WORD_TOKEN
                        XDEF            CMDP_PEEK_CHAR
                        XDEF            CMDP_REQUIRE_EOL
                        XDEF            CMDP_SKIP_SPACES
                        XDEF            CMDP_TO_UPPER_A
                        XDEF            CMDP_USAGE_LINE_XY
                        XDEF            MSG_HELP_1
                        XDEF            MSG_HELP_2
                        XDEF            MSG_HELP_3
                        XDEF            MSG_HELP_4
                        XDEF            MSG_HELP_5
                        XDEF            MSG_HELP_6
                        XDEF            MSG_HELP_7
                        XDEF            MSG_KEYTEST_CHAR
                        XDEF            MSG_KEYTEST_CLASS_CTRL
                        XDEF            MSG_KEYTEST_CLASS_PRINT_DIGIT
                        XDEF            MSG_KEYTEST_CLASS_PRINT_LOWER
                        XDEF            MSG_KEYTEST_CLASS_PRINT_PUNCT
                        XDEF            MSG_KEYTEST_CLASS_PRINT_SPACE
                        XDEF            MSG_KEYTEST_CLASS_PRINT_UPPER
                        XDEF            MSG_KEYTEST_ESCSEQ
                        XDEF            MSG_KEYTEST_EXIT
                        XDEF            MSG_KEYTEST_FALSE
                        XDEF            MSG_KEYTEST_HDR
                        XDEF            MSG_KEYTEST_HEX
                        XDEF            MSG_KEYTEST_ISPRINT
                        XDEF            MSG_KEYTEST_NONPRINT
                        XDEF            MSG_KEYTEST_NOTE
                        XDEF            MSG_KEYTEST_PROMPT
                        XDEF            MSG_KEYTEST_TRUE
                        XDEF            MSG_KEYTEST_TYPE
                        XDEF            MSG_LOAD_ADDR_UNKNOWN
                        XDEF            MSG_LOAD_DONE_LEN
                        XDEF            MSG_LOAD_GO_EXEC
                        XDEF            MSG_LOAD_GO_MISSING
                        XDEF            MSG_LOAD_LINE_STATUS
                        XDEF            MSG_LOAD_NO_GO
                        XDEF            MSG_LOAD_PARSE_FAIL
                        XDEF            MSG_LOAD_RANGE_HDR
                        XDEF            MSG_LOAD_RANGE_OVF
                        XDEF            MSG_LOAD_READY
                        XDEF            MSG_LOAD_SUM_BYTES
                        XDEF            MSG_LOAD_SUM_END
                        XDEF            MSG_LOAD_SUM_GO
                        XDEF            MSG_LOAD_SUM_IGNORED
                        XDEF            MSG_LOAD_SUM_OK_START
                        XDEF            MSG_LOAD_SUM_REC

                        XREF            SYS_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            SYS_READ_CSTRING_SILENT_UPPER
                        XREF            SYS_READ_CHAR
                        XREF            SYS_POLL_CHAR
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HBSTRING
                        XREF            SYS_WRITE_HBLINE
                        XREF            UTL_CHAR_IS_PRINTABLE
                        XREF            MON_CMD_DISPLAY
                        XREF            MON_CMD_FILL
                        XREF            MON_CMD_COPY
                        XREF            MON_CMD_MODIFY
                        XREF            MON_CMD_HELP
                        XREF            MON_CMD_LOAD
                        XREF            MON_CMD_KEYTEST
                        XREF            MON_CMD_QUIT
                        XREF            CMDP_GET_TOKEN_LEN
                        XREF            CMDP_TBL_GET_ENTRY_LEN
                        XREF            CMDP_TBL_MATCH_CURRENT
                        XREF            CMDP_TBL_GET_ROUTINE_PTR
                        XREF            CMDP_CALL_ROUTINE_PTR
                        XREF            CMDP_TBL_ADVANCE_NEXT


                        INCLUDE         "TEST/apps/himon-shared-eq.inc"


                        CODE
START:
                        JSR             SYS_INIT
                        JSR             SYS_FLUSH_RX
                        LDX             #<MSG_HDR_1
                        LDY             #>MSG_HDR_1
                        JSR             SYS_WRITE_HBLINE
                        LDX             #<MSG_HDR_2
                        LDY             #>MSG_HDR_2
                        JSR             SYS_WRITE_HBLINE
                        JSR             SYS_WRITE_CRLF

CMD_MAIN_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             SYS_WRITE_HBSTRING

                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        BCS             CMD_HAVE_LINE

                        ; Handle C=0 statuses from line reader (BS/DEL/full),
                        ;   then retry.
                        STA             CMD_LINE_STATUS
                        LDX             #<MSG_LINE_STATUS
                        LDY             #>MSG_LINE_STATUS
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMD_LINE_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_RETRY
                        LDY             #>MSG_RETRY
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        BRA             CMD_MAIN_LOOP

CMD_HAVE_LINE:
                        STA             CMD_LEN
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             CMD_PARSE_AND_EXECUTE_ROUTER
                        BRA             CMD_MAIN_LOOP


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE_ROUTER  [HASH:567F]
; TIER: APP-L5
; TAGS: CMD, APP-L5, NOSTACK
; PURPOSE: Compatibility entrypoint retained for call-site stability.
;          Forwards directly to the HBSTR table-driven parser/dispatcher.
; IN : X/Y = pointer to command line
; OUT: C mirrors selected command path result.
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE_ROUTER:
                        JMP             CMD_PARSE_AND_EXECUTE


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE  [HASH:CDC9]
; TIER: APP-L5
; TAGS: CMD, APP-L5, VIA, NUL-TERM, PARSE, CARRY-STATUS, NOSTACK
; PURPOSE: Parse one command line and dispatch via HBSTR `CMD_TBL`.
;          Table format per entry: <HBSTR command><DW handler address>.
; IN : X/Y = pointer to NUL-terminated command line
; OUT: C=1 command handled/success; C=0 unknown command or usage error
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE:
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             CMDP_EMPTY_OK

                        LDA             CMDP_PTR_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_ADDR_HI
                        JSR             CMDP_GET_TOKEN_LEN
                        BCC             CMDP_PARSE_UNKNOWN
                        STA             CMDP_TOKEN_LEN
                        BEQ             CMDP_PARSE_UNKNOWN
                        LDA             #<CMD_TBL
                        STA             CMDP_START_LO
                        LDA             #>CMD_TBL
                        STA             CMDP_START_HI
CMDP_DISPATCH_LOOP:
                        JSR             CMDP_TBL_GET_ENTRY_LEN
                        BCC             CMDP_PARSE_UNKNOWN
                        JSR             CMDP_TBL_MATCH_CURRENT
                        BCC             CMDP_DISPATCH_NEXT
                        JSR             CMDP_TBL_GET_ROUTINE_PTR
                        JSR             CMDP_CALL_ROUTINE_PTR
                        RTS
CMDP_DISPATCH_NEXT:
                        JSR             CMDP_TBL_ADVANCE_NEXT
                        BCC             CMDP_PARSE_UNKNOWN
                        BRA             CMDP_DISPATCH_LOOP
CMDP_PARSE_UNKNOWN:
                        LDX             #<CMDP_MSG_ERR_UNKNOWN
                        LDY             #>CMDP_MSG_ERR_UNKNOWN
                        JSR             SYS_WRITE_HBLINE
                        CLC
                        RTS

CMDP_EMPTY_OK:
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
                        JSR             SYS_WRITE_HBLINE
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
CMD_TBL:
DISPLAY_HBSTR:           DB              "DISPLA",$D9
DISPLAY_ADDR:            DW              MON_CMD_DISPLAY
FILL_HBSTR:              DB              "FIL",$CC
FILL_ADDR:               DW              MON_CMD_FILL
COPY_HBSTR:              DB              "COP",$D9
COPY_ADDR:               DW              MON_CMD_COPY
MODIFY_HBSTR:            DB              "MODIF",$D9
MODIFY_ADDR:             DW              MON_CMD_MODIFY
HELP_HBSTR:              DB              "HEL",$D0
HELP_ADDR:               DW              MON_CMD_HELP
LOAD_HBSTR:              DB              "LOA",$C4
LOAD_ADDR:               DW              MON_CMD_LOAD
KEYTEST_HBSTR:           DB              "KEYTES",$D4
KEYTEST_ADDR:            DW              MON_CMD_KEYTEST
QUIT_HBSTR:              DB              "QUI",$D4
QUIT_ADDR:               DW              MON_CMD_QUIT
CMD_TBL_END:             DB              $00

MSG_HDR_1:               DB              $0d,$0a,"R-YORS command monito",$F2
MSG_HDR_2: DB "DISPLAY FILL COPY MODIFY HELP LOAD KEYTEST QUI",$D4
MSG_PROMPT:              DB              "cmd>",$A0
MSG_LINE_STATUS:         DB              "line status=",$A4
MSG_RETRY:               DB              " (retry",$A9
CMDP_MSG_ERR_UNKNOWN:    DB              "ERR: unknown comman",$E4
CMDP_MSG_USAGE_DISPLAY:  DB              "usage: DISPLAY <addr16",$BE
CMDP_MSG_USAGE_FILL: DB "usage: FILL <addr16> <count8> <byte8",$BE
CMDP_MSG_USAGE_COPY: DB "usage: COPY <src16> <dst16> <count8",$BE
CMDP_MSG_USAGE_MODIFY: DB "usage: MODIFY <addr16> <byte8> [byte8 ...",$DD
CMDP_MSG_USAGE_HELP:     DB              "usage: HEL",$D0
CMDP_MSG_USAGE_LOAD:     DB              "usage: LOAD [GO] [S19",$DD
CMDP_MSG_USAGE_KEYTEST:  DB              "usage: KEYTES",$D4
CMDP_MSG_USAGE_QUIT:     DB              "usage: QUI",$D4
CMDP_MSG_MOD_OK_1:       DB              "modified ",$A4
CMDP_MSG_MOD_OK_2:       DB              " bytes at ",$A4
MSG_HELP_1:              DB              "DISPLAY <addr16",$BE
MSG_HELP_2:              DB              "FILL <addr16> <count8> <byte8",$BE
MSG_HELP_3:              DB              "COPY <src16> <dst16> <count8",$BE
MSG_HELP_4: DB "MODIFY <addr16> <byte8> [byte8 ...",$DD
MSG_HELP_5:              DB              "LOAD [GO] [S19",$DD
MSG_HELP_6:              DB              "QUI",$D4
MSG_HELP_7:              DB              "KEYTES",$D4
MSG_LOAD_READY: DB "LOAD READY: paste S-record lines, end with S",$B9
MSG_LOAD_LINE_STATUS:    DB              "LOAD line status=",$A4
MSG_LOAD_PARSE_FAIL:     DB              "LOAD parse fail type",$BD
MSG_LOAD_SUM_OK_START:   DB              "LOAD OK START ",$A4
MSG_LOAD_SUM_END:        DB              " END ",$A4
MSG_LOAD_SUM_BYTES:      DB              " BYTES ",$A4
MSG_LOAD_SUM_GO:         DB              " GO ",$A4
MSG_LOAD_SUM_IGNORED:    DB              ", ignore",$E4
MSG_LOAD_SUM_REC:        DB              " REC ",$A4
MSG_LOAD_DONE_LEN:       DB              " len=",$BD
MSG_LOAD_RANGE_HDR:      DB              "LOAD ranges:",$BA
MSG_LOAD_RANGE_OVF: DB "LOAD ranges: additional ranges omitte",$E4
MSG_LOAD_NO_GO:          DB              "???",$BF
MSG_LOAD_ADDR_UNKNOWN:   DB              "????",$BF
MSG_LOAD_GO_EXEC:        DB              "LOAD GO jumping to ",$A4
MSG_LOAD_GO_MISSING: DB "LOAD GO requested but no GO address captured",$E4
MSG_KEYTEST_HDR:         DB              $0d,$0a,"KEYTEST: type keys, Ctrl-C to exi",$F4
MSG_KEYTEST_NOTE: DB "ESC-prefixed keys print one hex byte-sequence lin",$E5
MSG_KEYTEST_PROMPT:      DB              "key>",$A0
MSG_KEYTEST_ESCSEQ:      DB              "esc seq: ",$A0
MSG_KEYTEST_TYPE:        DB              "type: ",$A0
MSG_KEYTEST_CHAR:        DB              "char: ",$A0
MSG_KEYTEST_NONPRINT:    DB              "(non-printable)",$A0
MSG_KEYTEST_HEX:         DB              "hex: ",$A0
MSG_KEYTEST_ISPRINT:     DB              "isprint: ",$A0
MSG_KEYTEST_TRUE:        DB              "1",$B1
MSG_KEYTEST_FALSE:       DB              "0",$B0
MSG_KEYTEST_EXIT:        DB              "KEYTEST exi",$F4
MSG_KEYTEST_CLASS_CTRL:  DB              "CTRL",$CC
MSG_KEYTEST_CLASS_PRINT_SPACE: DB "PRINT-SPAC",$C5
MSG_KEYTEST_CLASS_PRINT_DIGIT: DB "PRINT-DIGI",$D4
MSG_KEYTEST_CLASS_PRINT_UPPER: DB "PRINT-UPPE",$D2
MSG_KEYTEST_CLASS_PRINT_LOWER: DB "PRINT-LOWE",$D2
MSG_KEYTEST_CLASS_PRINT_PUNCT: DB "PRINT-PUNC",$D4

                        ENDMOD

                        END

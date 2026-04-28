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
                        XDEF            MON_CMD_GO
                        XDEF            MON_CMD_R
                        XDEF            MON_CMD_RESUME
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
                        XREF            CMDP_MSG_USAGE_GO
                        XREF            CMDP_MSG_USAGE_R
                        XREF            CMDP_MSG_USAGE_RESUME
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
                        XREF            MSG_HELP_8
                        XREF            MSG_HELP_9
                        XREF            MSG_HELP_10
                        XREF            MSG_GO_EXEC
                        XREF            MSG_R_NONE
                        XREF            MSG_R_PC
                        XREF            MSG_R_A
                        XREF            MSG_R_X
                        XREF            MSG_R_Y
                        XREF            MSG_R_P
                        XREF            MSG_R_S
                        XREF            MSG_RESUME_EXEC
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


                        INCLUDE         "TEST/apps/himon/himon-shared-eq.inc"

                        CODE
                        INCLUDE         "TEST/apps/himon/mon-cmd-core.inc"
                        INCLUDE         "TEST/apps/himon/mon-cmd-debug.inc"
                        INCLUDE         "TEST/apps/himon/mon-cmd-memory.inc"
                        INCLUDE         "TEST/apps/himon/mon-cmd-load.inc"

                        ENDMOD

                        END

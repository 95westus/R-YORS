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
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             CMDP_START_LO
                        INY
                        LDA             (CMDP_ADDR_LO),Y
                        STA             CMDP_START_HI
                        LDA             CMDP_START_LO
                        ORA             CMDP_START_HI
                        BEQ             CMDP_CALL_ROUTINE_PTR_UNKNOWN
                        JMP             (CMDP_START_LO)
CMDP_CALL_ROUTINE_PTR_UNKNOWN:
                        LDA             CMD_HOOK_UNKNOWN_LO
                        ORA             CMD_HOOK_UNKNOWN_HI
                        BEQ             CMDP_CALL_ROUTINE_PTR_FAIL
                        JMP             (CMD_HOOK_UNKNOWN_LO)
CMDP_CALL_ROUTINE_PTR_FAIL:
                        CLC
                        RTS

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

MON_CMD_GO:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_CMD_GO_FROM_LOAD
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CMD_GO_USAGE
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_CMD_GO_USAGE
                        BRA             MON_CMD_GO_EXEC

MON_CMD_GO_FROM_LOAD:
                        LDA             LOAD_GO_VALID
                        BEQ             MON_CMD_GO_USAGE
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BEQ             MON_CMD_GO_USAGE
                        LDA             LOAD_GO_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_GO_HI
                        STA             CMDP_ADDR_HI

MON_CMD_GO_EXEC:
                        LDX             #<MSG_GO_EXEC
                        LDY             #>MSG_GO_EXEC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             (CMDP_ADDR_LO)

MON_CMD_GO_USAGE:
                        LDX             #<CMDP_MSG_USAGE_GO
                        LDY             #>CMDP_MSG_USAGE_GO
                        JMP             CMDP_USAGE_LINE_XY


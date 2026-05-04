MON_CMD_R:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCC             MON_CMD_R_DONE
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             MON_CMD_R_USAGE
                        JSR             MON_CTX_PRINT
MON_CMD_R_DONE:
                        SEC
                        RTS

MON_CMD_R_USAGE:
                        LDX             #<CMDP_MSG_USAGE_R
                        LDY             #>CMDP_MSG_USAGE_R
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_RESUME:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCC             MON_CMD_RESUME_FAIL
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             MON_CMD_RESUME_USAGE

                        LDX             #<MSG_RESUME_EXEC
                        LDY             #>MSG_RESUME_EXEC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_CTX_RESUME_RTI

MON_CMD_RESUME_FAIL:
                        CLC
                        RTS

MON_CMD_RESUME_USAGE:
                        LDX             #<CMDP_MSG_USAGE_RESUME
                        LDY             #>CMDP_MSG_USAGE_RESUME
                        JMP             CMDP_USAGE_LINE_XY

MON_CTX_REQUIRE_VALID:
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BEQ             MON_CTX_REQUIRE_VALID_OK
                        LDX             #<MSG_R_NONE
                        LDY             #>MSG_R_NONE
                        JSR             SYS_WRITE_HBLINE
                        CLC
                        RTS
MON_CTX_REQUIRE_VALID_OK:
                        SEC
                        RTS

MON_CTX_PARSE_ASSIGN_LIST:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_CTX_PARSE_ASSIGN_LIST_DONE
MON_CTX_PARSE_ASSIGN_LIST_LOOP:
                        JSR             MON_CTX_PARSE_ASSIGN
                        BCC             MON_CTX_PARSE_ASSIGN_LIST_FAIL
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BNE             MON_CTX_PARSE_ASSIGN_LIST_LOOP
MON_CTX_PARSE_ASSIGN_LIST_DONE:
                        SEC
                        RTS
MON_CTX_PARSE_ASSIGN_LIST_FAIL:
                        CLC
                        RTS

MON_CTX_PRINT:
                        LDX             #<MSG_R_PC
                        LDY             #>MSG_R_PC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_R_A
                        LDY             #>MSG_R_A
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_A
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_R_X
                        LDY             #>MSG_R_X
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_X
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_R_Y
                        LDY             #>MSG_R_Y
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_Y
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_R_P
                        LDY             #>MSG_R_P
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_P
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_R_S
                        LDY             #>MSG_R_S
                        JSR             SYS_WRITE_HBSTRING
                        LDA             NMI_CTX_S
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        SEC
                        RTS

MON_CTX_PARSE_ASSIGN:
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'A'
                        BEQ             MON_CTX_PARSE_A
                        CMP             #'X'
                        BEQ             MON_CTX_PARSE_X
                        CMP             #'Y'
                        BEQ             MON_CTX_PARSE_Y
                        CMP             #'S'
                        BEQ             MON_CTX_PARSE_S
                        CMP             #'P'
                        BEQ             MON_CTX_PARSE_P_OR_PC
                        CLC
                        RTS

MON_CTX_PARSE_A:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'='
                        BNE             MON_CTX_PARSE_A_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_A_FAIL
                        STA             NMI_CTX_A
                        SEC
                        RTS
MON_CTX_PARSE_A_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_X:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'='
                        BNE             MON_CTX_PARSE_X_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_X_FAIL
                        STA             NMI_CTX_X
                        SEC
                        RTS
MON_CTX_PARSE_X_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_Y:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'='
                        BNE             MON_CTX_PARSE_Y_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_Y_FAIL
                        STA             NMI_CTX_Y
                        SEC
                        RTS
MON_CTX_PARSE_Y_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_S:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'='
                        BNE             MON_CTX_PARSE_S_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_S_FAIL
                        STA             NMI_CTX_S
                        SEC
                        RTS
MON_CTX_PARSE_S_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_P_OR_PC:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'C'
                        BEQ             MON_CTX_PARSE_PC
                        CMP             #'='
                        BNE             MON_CTX_PARSE_P_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_P_FAIL
                        STA             NMI_CTX_P
                        SEC
                        RTS
MON_CTX_PARSE_P_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_PC:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'='
                        BNE             MON_CTX_PARSE_PC_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CTX_PARSE_PC_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             NMI_CTX_PCL
                        LDA             CMDP_ADDR_HI
                        STA             NMI_CTX_PCH
                        SEC
                        RTS
MON_CTX_PARSE_PC_FAIL:
                        JMP             MON_CTX_PARSE_ASSIGN_FAIL

MON_CTX_PARSE_ASSIGN_FAIL:
                        CLC
                        RTS

MON_CTX_RESUME_RTI:
                        SEI
                        LDY             NMI_CTX_S
                        LDA             NMI_CTX_P
                        STA             $00FE,Y
                        LDA             NMI_CTX_PCL
                        STA             $00FF,Y
                        LDA             NMI_CTX_PCH
                        STA             $0100,Y

                        TYA
                        SEC
                        SBC             #$03
                        TAX
                        TXS

                        STZ             NMI_CTX_FLAG
                        LDA             NMI_CTX_A
                        LDX             NMI_CTX_X
                        LDY             NMI_CTX_Y
                        RTI


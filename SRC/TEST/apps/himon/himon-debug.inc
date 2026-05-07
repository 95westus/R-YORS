; ----------------------------------------------------------------------------
; Himonia debug/breakpoint commands.
; ----------------------------------------------------------------------------

CMD_B_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$85,$FB,$0B,$C7,$00
CMD_B:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'L'
                        BEQ             CMD_B_LIST
                        CMP             #'C'
                        BEQ             CMD_B_CLEAR

                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_USAGE_B
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$04
                        BNE             CMD_USAGE_B
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_B
                        JSR             DBG_SET_BP
                        BCC             CMD_USAGE_B
                        LDX             #<MSG_BP_SET
                        LDY             #>MSG_BP_SET
                        JSR             HIM_WRITE_HBSTRING
                        JSR             DBG_PRINT_CMD_ADDR
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_B_CLEAR:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_USAGE_BC
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$04
                        BNE             CMD_USAGE_BC
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_BC
                        JSR             DBG_CLEAR_BP
                        BCC             CMD_USAGE_BC
                        LDX             #<MSG_BP_CLR
                        LDY             #>MSG_BP_CLR
                        JSR             HIM_WRITE_HBSTRING
                        JSR             DBG_PRINT_CMD_ADDR
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_B_LIST:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_BL
                        JSR             DBG_LIST_BP
                        RTS

CMD_USAGE_B:
                        LDX             #<MSG_USAGE_B
                        LDY             #>MSG_USAGE_B
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_USAGE_BC:
                        LDX             #<MSG_USAGE_BC
                        LDY             #>MSG_USAGE_BC
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_USAGE_BL:
                        LDX             #<MSG_USAGE_BL
                        LDY             #>MSG_USAGE_BL
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_S_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$22,$13,$0C,$D6,$00
CMD_S:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCS             CMD_S_HAVE_CTX
                        RTS
CMD_S_HAVE_CTX:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_S
                        JSR             DBG_STEP_ONCE
                        BCC             CMD_S_DONE
                        LDX             #<MSG_RESUME
                        LDY             #>MSG_RESUME
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_CTX_RESUME_RTI
CMD_S_DONE:
                        RTS

CMD_USAGE_S:
                        LDX             #<MSG_USAGE_S
                        LDY             #>MSG_USAGE_S
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

DBG_SET_BP:
                        JSR             DBG_FIND_BP_ADDR
                        BCS             DBG_SET_BP_OK
                        JSR             DBG_FIND_BP_FREE
                        BCC             DBG_SET_BP_FAIL
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_BP0_OP,X
                        LDA             CMDP_ADDR_LO
                        STA             DBG_BP0_LO,X
                        LDA             CMDP_ADDR_HI
                        STA             DBG_BP0_HI,X
                        LDA             #$00
                        STA             (CMDP_ADDR_LO),Y
                        LDA             #DBG_BPF_ACTIVE
                        STA             DBG_BP0_FLG,X
DBG_SET_BP_OK:
                        SEC
                        RTS
DBG_SET_BP_FAIL:
                        CLC
                        RTS

DBG_CLEAR_BP:
                        JSR             DBG_FIND_BP_ADDR
                        BCC             DBG_CLEAR_BP_FAIL
                        LDA             DBG_BP0_LO,X
                        STA             CMDP_ADDR_LO
                        LDA             DBG_BP0_HI,X
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             DBG_BP0_OP,X
                        STA             (CMDP_ADDR_LO),Y
                        STZ             DBG_BP0_FLG,X
                        SEC
                        RTS
DBG_CLEAR_BP_FAIL:
                        CLC
                        RTS

DBG_LIST_BP:
                        LDX             #$00
DBG_LIST_BP_LOOP:
                        LDA             DBG_BP0_FLG,X
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_LIST_BP_NEXT
                        STX             DBG_TMP_INDEX
                        LDA             DBG_BP0_HI,X
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             DBG_TMP_INDEX
                        LDA             DBG_BP0_LO,X
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDX             DBG_TMP_INDEX
                        LDA             DBG_BP0_OP,X
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        LDX             DBG_TMP_INDEX
DBG_LIST_BP_NEXT:
                        INX
                        INX
                        INX
                        INX
                        CPX             #(DBG_BP_MAX*DBG_BP_STRIDE)
                        BCC             DBG_LIST_BP_LOOP
                        RTS

DBG_FIND_BP_FREE:
                        LDX             #$00
DBG_FIND_BP_FREE_LOOP:
                        LDA             DBG_BP0_FLG,X
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_FIND_BP_FREE_HIT
                        INX
                        INX
                        INX
                        INX
                        CPX             #(DBG_BP_MAX*DBG_BP_STRIDE)
                        BCC             DBG_FIND_BP_FREE_LOOP
                        CLC
                        RTS
DBG_FIND_BP_FREE_HIT:
                        SEC
                        RTS

DBG_FIND_BP_ADDR:
                        LDX             #$00
DBG_FIND_BP_ADDR_LOOP:
                        LDA             DBG_BP0_FLG,X
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_FIND_BP_ADDR_NEXT
                        LDA             DBG_BP0_LO,X
                        CMP             CMDP_ADDR_LO
                        BNE             DBG_FIND_BP_ADDR_NEXT
                        LDA             DBG_BP0_HI,X
                        CMP             CMDP_ADDR_HI
                        BEQ             DBG_FIND_BP_ADDR_HIT
DBG_FIND_BP_ADDR_NEXT:
                        INX
                        INX
                        INX
                        INX
                        CPX             #(DBG_BP_MAX*DBG_BP_STRIDE)
                        BCC             DBG_FIND_BP_ADDR_LOOP
                        CLC
                        RTS
DBG_FIND_BP_ADDR_HIT:
                        SEC
                        RTS

DBG_HANDLE_BRK:
                        LDA             NMI_CTX_PCL
                        SEC
                        SBC             #$02
                        STA             DBG_TMP_LO
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        SBC             #$00
                        STA             DBG_TMP_HI
                        STA             CMDP_ADDR_HI

                        LDA             DBG_STEP_FLG
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_HANDLE_BRK_USER
                        LDA             DBG_STEP_LO
                        CMP             DBG_TMP_LO
                        BNE             DBG_HANDLE_BRK_USER
                        LDA             DBG_STEP_HI
                        CMP             DBG_TMP_HI
                        BNE             DBG_HANDLE_BRK_USER
                        LDY             #$00
                        LDA             DBG_STEP_OP
                        STA             (CMDP_ADDR_LO),Y
                        STZ             DBG_STEP_FLG
                        BRA             DBG_HANDLE_BRK_HIT

DBG_HANDLE_BRK_USER:
                        JSR             DBG_FIND_BP_ADDR
                        BCC             DBG_HANDLE_BRK_NONE
                        LDY             #$00
                        LDA             DBG_BP0_OP,X
                        STA             (CMDP_ADDR_LO),Y
                        STZ             DBG_BP0_FLG,X

DBG_HANDLE_BRK_HIT:
                        LDA             DBG_TMP_LO
                        STA             NMI_CTX_PCL
                        LDA             DBG_TMP_HI
                        STA             NMI_CTX_PCH
                        STZ             TRAP_BRK_SIG
                        SEC
                        RTS

DBG_HANDLE_BRK_NONE:
                        CLC
                        RTS

DBG_STEP_ONCE:
                        LDA             NMI_CTX_PCL
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_TMP_OPCODE
                        JSR             DBG_OPCODE_LEN
                        BCC             DBG_STEP_FAIL
                        STA             DBG_TMP_LEN
                        CLC
                        ADC             NMI_CTX_PCL
                        STA             DBG_STEP_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             DBG_STEP_HI
                        LDA             DBG_STEP_LO
                        STA             CMDP_ADDR_LO
                        LDA             DBG_STEP_HI
                        STA             CMDP_ADDR_HI
                        JSR             DBG_PRINT_STEP_INFO
                        JSR             DBG_FIND_BP_ADDR
                        BCS             DBG_STEP_BP_OVERLAP
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_STEP_OP
                        LDA             #$00
                        STA             (CMDP_ADDR_LO),Y
                        LDA             #DBG_BPF_ACTIVE
                        STA             DBG_STEP_FLG
                        SEC
                        RTS
DBG_STEP_BP_OVERLAP:
                        LDX             #<MSG_STEP_BP
                        LDY             #>MSG_STEP_BP
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS
DBG_STEP_FAIL:
                        CLC
                        RTS

DBG_PRINT_STEP_INFO:
                        LDX             #<MSG_STEP
                        LDY             #>MSG_STEP
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_STEP_OP
                        LDY             #>MSG_STEP_OP
                        JSR             HIM_WRITE_HBSTRING
                        LDA             DBG_TMP_OPCODE
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_STEP_LEN
                        LDY             #>MSG_STEP_LEN
                        JSR             HIM_WRITE_HBSTRING
                        LDA             DBG_TMP_LEN
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_STEP_NEXT
                        LDY             #>MSG_STEP_NEXT
                        JSR             HIM_WRITE_HBSTRING
                        LDA             DBG_STEP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             DBG_STEP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

DBG_OPCODE_LEN:
                        LDX             DBG_TMP_OPCODE
                        LDA             ASM_OP_MODE,X
                        CMP             #ASM_MODE_ZP_REL
                        BEQ             DBG_OPCODE_LEN_3
                        CMP             #ASM_MODE_BRK
                        BEQ             DBG_OPCODE_LEN_2
                        CMP             #ASM_MODE_REL
                        BEQ             DBG_OPCODE_LEN_2
                        CMP             #ASM_MODE_ABS
                        BCC             DBG_OPCODE_LEN_BYTE_OR_1
                        CMP             #ASM_MODE_REL
                        BCC             DBG_OPCODE_LEN_3
DBG_OPCODE_LEN_BYTE_OR_1:
                        CMP             #ASM_MODE_IMM
                        BCS             DBG_OPCODE_LEN_2
DBG_OPCODE_LEN_1:
                        LDA             #$01
                        SEC
                        RTS
DBG_OPCODE_LEN_3:
                        LDA             #$03
                        SEC
                        RTS
DBG_OPCODE_LEN_2:
                        LDA             #$02
                        SEC
                        RTS

DBG_PRINT_CMD_ADDR:
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

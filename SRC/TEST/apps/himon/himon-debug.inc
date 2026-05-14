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
                        JSR             DBG_REQUIRE_PATCHABLE_ADDR
                        BCC             CMD_B_DONE
                        JSR             DBG_SET_BP
                        BCC             CMD_B_FULL
                        LDX             #<MSG_BP_SET
                        LDY             #>MSG_BP_SET
                        JSR             HIM_WRITE_HBSTRING
                        JSR             DBG_PRINT_CMD_ADDR
                        JSR             SYS_WRITE_CRLF
                        RTS
CMD_B_DONE:
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
                        BCC             CMD_B_NF
                        LDX             #<MSG_BP_CLR
                        LDY             #>MSG_BP_CLR
                        JSR             HIM_WRITE_HBSTRING
                        JSR             DBG_PRINT_CMD_ADDR
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_B_FULL:
                        LDX             #<MSG_BP_FULL
                        LDY             #>MSG_BP_FULL
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_B_NF:
                        LDX             #<MSG_BP_NF
                        LDY             #>MSG_BP_NF
                        JSR             HIM_WRITE_HBSTRING
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

CMD_N_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$D1,$01,$0C,$CB,$00
CMD_N:
                        JMP             CMD_S

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
                        BNE             DBG_HANDLE_BRK_STEP_RESUME
                        LDA             DBG_STEP_HI
                        CMP             DBG_TMP_HI
                        BNE             DBG_HANDLE_BRK_STEP_RESUME
                        LDY             #$00
                        LDA             DBG_STEP_OP
                        STA             (CMDP_ADDR_LO),Y
                        STZ             DBG_STEP_FLG
                        BRA             DBG_HANDLE_BRK_HIT

DBG_HANDLE_BRK_STEP_RESUME:
                        LDA             DBG_STEP_LO
                        CMP             NMI_CTX_PCL
                        BNE             DBG_HANDLE_BRK_USER
                        LDA             DBG_STEP_HI
                        CMP             NMI_CTX_PCH
                        BNE             DBG_HANDLE_BRK_USER
; A real BRK can stop before executing the step trap at the BRK resume PC.
                        LDA             DBG_STEP_LO
                        STA             CMDP_ADDR_LO
                        LDA             DBG_STEP_HI
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             DBG_STEP_OP
                        STA             (CMDP_ADDR_LO),Y
                        STZ             DBG_STEP_FLG
                        CLC
                        RTS

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
                        LDA             #TRAP_CAUSE_DBG
                        STA             TRAP_CAUSE
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
                        JSR             DBG_STEP_RESOLVE_NEXT
                        LDA             DBG_STEP_LO
                        STA             CMDP_ADDR_LO
                        LDA             DBG_STEP_HI
                        STA             CMDP_ADDR_HI
                        JSR             DBG_REQUIRE_PATCHABLE_ADDR
                        BCC             DBG_STEP_FAIL
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
                        SEC
                        RTS
DBG_STEP_FAIL:
                        CLC
                        RTS

DBG_STEP_RESOLVE_NEXT:
                        CLC
                        LDA             NMI_CTX_PCL
                        ADC             DBG_TMP_LEN
                        STA             DBG_STEP_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             DBG_STEP_HI

                        LDA             DBG_TMP_OPCODE
                        CMP             #$80
                        BEQ             DBG_STEP_REL_TAKEN
                        CMP             #$4C
                        BNE             DBG_STEP_NOT_JMP_ABS
                        JMP             DBG_STEP_JMP_ABS
DBG_STEP_NOT_JMP_ABS:
                        CMP             #$10
                        BEQ             DBG_STEP_BPL
                        CMP             #$30
                        BEQ             DBG_STEP_BMI
                        CMP             #$50
                        BEQ             DBG_STEP_BVC
                        CMP             #$70
                        BEQ             DBG_STEP_BVS
                        CMP             #$90
                        BEQ             DBG_STEP_BCC
                        CMP             #$B0
                        BEQ             DBG_STEP_BCS
                        CMP             #$D0
                        BEQ             DBG_STEP_BNE
                        CMP             #$F0
                        BEQ             DBG_STEP_BEQ
                        RTS
DBG_STEP_BPL:
                        LDA             NMI_CTX_P
                        AND             #$80
                        BEQ             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BMI:
                        LDA             NMI_CTX_P
                        AND             #$80
                        BNE             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BVC:
                        LDA             NMI_CTX_P
                        AND             #$40
                        BEQ             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BVS:
                        LDA             NMI_CTX_P
                        AND             #$40
                        BNE             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BCC:
                        LDA             NMI_CTX_P
                        AND             #$01
                        BEQ             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BCS:
                        LDA             NMI_CTX_P
                        AND             #$01
                        BNE             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BNE:
                        LDA             NMI_CTX_P
                        AND             #$02
                        BEQ             DBG_STEP_REL_TAKEN
                        RTS
DBG_STEP_BEQ:
                        LDA             NMI_CTX_P
                        AND             #$02
                        BNE             DBG_STEP_REL_TAKEN
                        RTS

DBG_STEP_REL_TAKEN:
                        CLC
                        LDA             NMI_CTX_PCL
                        ADC             #$01
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_TMP_LO

                        CLC
                        LDA             NMI_CTX_PCL
                        ADC             #$02
                        STA             DBG_STEP_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             DBG_STEP_HI
                        LDA             DBG_TMP_LO
                        BPL             DBG_STEP_REL_ADD
                        DEC             DBG_STEP_HI
DBG_STEP_REL_ADD:
                        CLC
                        ADC             DBG_STEP_LO
                        STA             DBG_STEP_LO
                        BCC             DBG_STEP_REL_DONE
                        INC             DBG_STEP_HI
DBG_STEP_REL_DONE:
                        RTS

DBG_STEP_JMP_ABS:
                        CLC
                        LDA             NMI_CTX_PCL
                        ADC             #$01
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_STEP_LO
                        INY
                        LDA             (CMDP_ADDR_LO),Y
                        STA             DBG_STEP_HI
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
                        LDX             DBG_TMP_OPCODE
                        LDA             ASM_OP_MNEM_ID,X
                        BEQ             DBG_PRINT_STEP_NO_MNEM
                        STA             DBG_TMP_OP
                        JSR             DIS_WRITE_SPACE
                        LDA             DBG_TMP_OP
                        JSR             DIS_PRINT_MNEM_ID
                        LDA             NMI_CTX_PCL
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        STA             CMDP_ADDR_HI
                        LDX             DBG_TMP_OPCODE
                        LDA             ASM_OP_MODE,X
                        JSR             DIS_PRINT_OPER_MODE
DBG_PRINT_STEP_NO_MNEM:
                        LDA             DBG_TMP_OPCODE
                        BNE             DBG_PRINT_STEP_NO_BRK_SIG
                        LDX             #<MSG_STEP_SIG
                        LDY             #>MSG_STEP_SIG
                        JSR             HIM_WRITE_HBSTRING
                        CLC
                        LDA             NMI_CTX_PCL
                        ADC             #$01
                        STA             CMDP_START_LO
                        LDA             NMI_CTX_PCH
                        ADC             #$00
                        STA             CMDP_START_HI
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
DBG_PRINT_STEP_NO_BRK_SIG:
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
                        LDA             DBG_STEP_LO
                        STA             CMDP_ADDR_LO
                        LDA             DBG_STEP_HI
                        STA             CMDP_ADDR_HI
                        JMP             SYS_WRITE_CRLF

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

DBG_FORGET_ALL:
                        STZ             DBG_STEP_FLG
                        LDX             #$00
DBG_FORGET_ALL_LOOP:
                        STZ             DBG_BP0_FLG,X
                        INX
                        INX
                        INX
                        INX
                        CPX             #(DBG_BP_MAX*DBG_BP_STRIDE)
                        BCC             DBG_FORGET_ALL_LOOP
                        RTS

DBG_CLEAR_ALL:
                        LDA             DBG_STEP_FLG
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_CLEAR_ALL_BP
                        LDA             DBG_STEP_LO
                        STA             CMDP_ADDR_LO
                        LDA             DBG_STEP_HI
                        STA             CMDP_ADDR_HI
                        JSR             DBG_ADDR_PATCHABLE
                        BCC             DBG_CLEAR_ALL_STEP_DONE
                        LDY             #$00
                        LDA             DBG_STEP_OP
                        STA             (CMDP_ADDR_LO),Y
DBG_CLEAR_ALL_STEP_DONE:
                        STZ             DBG_STEP_FLG
DBG_CLEAR_ALL_BP:
                        LDX             #$00
DBG_CLEAR_ALL_LOOP:
                        LDA             DBG_BP0_FLG,X
                        AND             #DBG_BPF_ACTIVE
                        BEQ             DBG_CLEAR_ALL_NEXT
                        LDA             DBG_BP0_LO,X
                        STA             CMDP_ADDR_LO
                        LDA             DBG_BP0_HI,X
                        STA             CMDP_ADDR_HI
                        STX             DBG_TMP_INDEX
                        JSR             DBG_ADDR_PATCHABLE
                        LDX             DBG_TMP_INDEX
                        BCC             DBG_CLEAR_ALL_CLR
                        LDY             #$00
                        LDA             DBG_BP0_OP,X
                        STA             (CMDP_ADDR_LO),Y
DBG_CLEAR_ALL_CLR:
                        STZ             DBG_BP0_FLG,X
DBG_CLEAR_ALL_NEXT:
                        INX
                        INX
                        INX
                        INX
                        CPX             #(DBG_BP_MAX*DBG_BP_STRIDE)
                        BCC             DBG_CLEAR_ALL_LOOP
                        RTS

DBG_PRINT_CMD_ADDR:
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

DBG_ADDR_PATCHABLE:
                        LDA             CMDP_ADDR_HI
                        CMP             #>UPA_BASE
                        BCC             DBG_ADDR_PATCHABLE_FAIL
                        CMP             #>HIUPA
                        BCS             DBG_ADDR_PATCHABLE_FAIL
                        SEC
                        RTS
DBG_ADDR_PATCHABLE_FAIL:
                        CLC
                        RTS

DBG_REQUIRE_PATCHABLE_ADDR:
                        JSR             DBG_ADDR_PATCHABLE
                        BCS             DBG_REQUIRE_PATCHABLE_ADDR_OK
DBG_REQUIRE_PATCHABLE_ADDR_FAIL:
                        LDX             #<MSG_DBG_RAM
                        LDY             #>MSG_DBG_RAM
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS
DBG_REQUIRE_PATCHABLE_ADDR_OK:
                        SEC
                        RTS

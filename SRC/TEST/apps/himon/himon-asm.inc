; ----------------------------------------------------------------------------
; Full W65C02S one-line mini assembler command.
; A start MNEM [operand]
; A start prompts as "start: " and exits on Ctrl-C or ".".
; Operands are hexadecimal bytes/words. Branch operands are raw relative bytes.
; ----------------------------------------------------------------------------

CMD_A_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$CC,$F6,$0B,$C4,$00
CMD_A:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_USAGE_A
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_TMP_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_TMP_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_A_INTERACTIVE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             CMD_USAGE_A
CMD_A_INTERACTIVE:
                        JSR             ASM_INTERACTIVE
                        RTS

ASM_ASSEMBLE_LINE:
                        JSR             ASM_READ_MNEM
                        BCC             ASM_ASSEMBLE_LINE_FAIL
                        JSR             ASM_FIND_MNEM_ID
                        BCC             ASM_ASSEMBLE_LINE_FAIL
                        JSR             ASM_PARSE_OPERAND
                        BCC             ASM_ASSEMBLE_LINE_FAIL
                        JSR             ASM_FIND_OPCODE
                        BCC             ASM_ASSEMBLE_LINE_FAIL
                        JSR             ASM_EMIT
                        RTS
ASM_ASSEMBLE_LINE_FAIL:
                        CLC
                        RTS

ASM_INTERACTIVE:
                        LDA             CMD_RANGE_TMP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_ECHO_UPPER
                        BCC             ASM_INTERACTIVE_DONE
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             ASM_INTERACTIVE
                        CMP             #'.'
                        BEQ             ASM_INTERACTIVE_DONE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_INTERACTIVE
                        JSR             CMD_USAGE_A
                        BRA             ASM_INTERACTIVE
ASM_INTERACTIVE_DONE:
                        RTS

CMD_USAGE_A:
                        LDX             #<MSG_USAGE_A
                        LDY             #>MSG_USAGE_A
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

ASM_READ_MNEM:
                        JSR             CMD_SKIP_SPACES
                        JSR             ASM_READ_MNEM_CHAR
                        BCC             ASM_READ_MNEM_FAIL
                        STA             DBG_ASM_OP0
                        JSR             ASM_READ_MNEM_CHAR
                        BCC             ASM_READ_MNEM_FAIL
                        STA             DBG_ASM_OP1
                        JSR             ASM_READ_MNEM_CHAR
                        BCC             ASM_READ_MNEM_FAIL
                        STA             DBG_ASM_OP2
                        STZ             DBG_ASM_OP3
                        JSR             CMD_PEEK
                        CMP             #'0'
                        BCC             ASM_READ_MNEM_DELIM
                        CMP             #'8'
                        BCS             ASM_READ_MNEM_DELIM
                        STA             DBG_ASM_OP3
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
ASM_READ_MNEM_DELIM:
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCC             ASM_READ_MNEM_FAIL
                        SEC
                        RTS
ASM_READ_MNEM_FAIL:
                        CLC
                        RTS

ASM_READ_MNEM_CHAR:
                        JSR             CMD_PEEK
                        CMP             #'A'
                        BCC             ASM_READ_MNEM_CHAR_FAIL
                        CMP             #'Z'+1
                        BCS             ASM_READ_MNEM_CHAR_FAIL
                        PHA
                        JSR             CMD_ADV_PTR
                        PLA
                        SEC
                        RTS
ASM_READ_MNEM_CHAR_FAIL:
                        CLC
                        RTS

ASM_FIND_MNEM_ID:
                        LDA             #<ASM_MNEM_NAMES
                        STA             CMDP_START_LO
                        LDA             #>ASM_MNEM_NAMES
                        STA             CMDP_START_HI
                        LDA             #$01
                        STA             DBG_TMP_INDEX
ASM_FIND_MNEM_LOOP:
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        AND             #$7F
                        CMP             DBG_ASM_OP0
                        BNE             ASM_FIND_MNEM_NEXT
                        INY
                        LDA             (CMDP_START_LO),Y
                        AND             #$7F
                        CMP             DBG_ASM_OP1
                        BNE             ASM_FIND_MNEM_NEXT
                        INY
                        LDA             (CMDP_START_LO),Y
                        AND             #$7F
                        CMP             DBG_ASM_OP2
                        BNE             ASM_FIND_MNEM_NEXT
                        INY
                        LDA             (CMDP_START_LO),Y
                        AND             #$7F
                        CMP             DBG_ASM_OP3
                        BNE             ASM_FIND_MNEM_NEXT
                        LDA             DBG_TMP_INDEX
                        STA             DBG_TMP_OP
                        SEC
                        RTS
ASM_FIND_MNEM_NEXT:
                        LDA             CMDP_START_LO
                        CLC
                        ADC             #$04
                        STA             CMDP_START_LO
                        BCC             ASM_FIND_MNEM_NEXT2
                        INC             CMDP_START_HI
ASM_FIND_MNEM_NEXT2:
                        INC             DBG_TMP_INDEX
                        LDA             DBG_TMP_INDEX
                        CMP             #(ASM_MNEM_COUNT+1)
                        BCC             ASM_FIND_MNEM_LOOP
                        CLC
                        RTS

ASM_PARSE_OPERAND:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             ASM_PARSE_NONE
                        CMP             #'#'
                        BEQ             ASM_PARSE_IMM
                        CMP             #'A'
                        BEQ             ASM_PARSE_ACC
                        CMP             #'('
                        BEQ             ASM_PARSE_PAREN
                        JMP             ASM_PARSE_NUM

ASM_PARSE_NONE:
                        LDA             #ASM_SH_NONE
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_ACC:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCS             ASM_PARSE_ACC_EOL_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_ACC_EOL_OK:
                        LDA             #ASM_SH_ACC
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_IMM:
                        JSR             CMD_ADV_PTR
                        JSR             ASM_PARSE_HEX_BYTE_LOOSE
                        BCS             ASM_PARSE_IMM_BYTE_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_IMM_BYTE_OK:
                        JSR             CMD_REQUIRE_EOL
                        BCS             ASM_PARSE_IMM_EOL_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_IMM_EOL_OK:
                        LDA             #ASM_SH_IMM
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_PAREN:
                        JSR             CMD_ADV_PTR
                        JSR             ASM_PARSE_HEX_WORD_LOOSE
                        BCS             ASM_PARSE_PAREN_WORD_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_WORD_OK:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #','
                        BEQ             ASM_PARSE_PAREN_COMMA
                        CMP             #')'
                        BEQ             ASM_PARSE_PAREN_RPAREN_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_RPAREN_OK:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #','
                        BEQ             ASM_PARSE_PAREN_POST_COMMA
                        JSR             CMD_REQUIRE_EOL
                        BCS             ASM_PARSE_PAREN_EOL_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_EOL_OK:
                        LDA             #ASM_SH_PAREN_NUM
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_PAREN_COMMA:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'X'
                        BEQ             ASM_PARSE_PAREN_X_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_X_OK:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #')'
                        BEQ             ASM_PARSE_PAREN_X_RPAREN_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_X_RPAREN_OK:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCS             ASM_PARSE_PAREN_X_EOL_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_X_EOL_OK:
                        LDA             #ASM_SH_PAREN_NUM_X
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_PAREN_POST_COMMA:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'Y'
                        BEQ             ASM_PARSE_PAREN_Y_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_Y_OK:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCS             ASM_PARSE_PAREN_Y_EOL_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_PAREN_Y_EOL_OK:
                        LDA             #ASM_SH_PAREN_NUM_Y
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_NUM:
                        JSR             ASM_PARSE_HEX_WORD_LOOSE
                        BCS             ASM_PARSE_NUM_WORD_OK
                        JMP             ASM_PARSE_FAIL
ASM_PARSE_NUM_WORD_OK:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             ASM_PARSE_NUM_ONLY
                        CMP             #','
                        BEQ             ASM_PARSE_NUM_COMMA
                        CMP             #'$'
                        BEQ             ASM_PARSE_NUM_SECOND
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCS             ASM_PARSE_NUM_SECOND
                        JMP             ASM_PARSE_FAIL

ASM_PARSE_NUM_ONLY:
                        LDA             #ASM_SH_NUM
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_NUM_COMMA:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'X'
                        BEQ             ASM_PARSE_NUM_X
                        CMP             #'Y'
                        BEQ             ASM_PARSE_NUM_Y
                        JMP             ASM_PARSE_NUM_SECOND

ASM_PARSE_NUM_X:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCC             ASM_PARSE_FAIL
                        LDA             #ASM_SH_NUM_X
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_NUM_Y:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCC             ASM_PARSE_FAIL
                        LDA             #ASM_SH_NUM_Y
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_NUM_SECOND:
                        JSR             ASM_PARSE_HEX_BYTE_LOOSE
                        BCC             ASM_PARSE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMDP_ADDR_HI
                        JSR             CMD_REQUIRE_EOL
                        BCC             ASM_PARSE_FAIL
                        LDA             #ASM_SH_ZP_REL
                        STA             DBG_TMP_FLAGS
                        SEC
                        RTS

ASM_PARSE_FAIL:
                        CLC
                        RTS

ASM_PARSE_HEX_BYTE_LOOSE:
                        JSR             ASM_PARSE_HEX_WORD_LOOSE
                        BCC             ASM_PARSE_HEX_BYTE_LOOSE_FAIL
                        LDA             CMDP_ADDR_HI
                        BNE             ASM_PARSE_HEX_BYTE_LOOSE_FAIL
                        LDA             CMDP_ADDR_LO
                        SEC
                        RTS
ASM_PARSE_HEX_BYTE_LOOSE_FAIL:
                        CLC
                        RTS

ASM_PARSE_HEX_WORD_LOOSE:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_SKIP_OPTIONAL_DOLLAR
                        STZ             CMDP_ADDR_HI
                        STZ             CMDP_ADDR_LO
                        STZ             CMDP_TOKEN_LEN
ASM_PARSE_HEX_WORD_LOOSE_LOOP:
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             ASM_PARSE_HEX_WORD_LOOSE_DONE
                        STA             CMDP_NIB_HI
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$04
                        BCS             ASM_PARSE_HEX_WORD_LOOSE_FAIL
                        INC             CMDP_TOKEN_LEN

                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI

                        LDA             CMDP_ADDR_LO
                        ORA             CMDP_NIB_HI
                        STA             CMDP_ADDR_LO
                        JSR             CMD_ADV_PTR
                        BRA             ASM_PARSE_HEX_WORD_LOOSE_LOOP
ASM_PARSE_HEX_WORD_LOOSE_DONE:
                        LDA             CMDP_TOKEN_LEN
                        BEQ             ASM_PARSE_HEX_WORD_LOOSE_FAIL
                        SEC
                        RTS
ASM_PARSE_HEX_WORD_LOOSE_FAIL:
                        CLC
                        RTS

ASM_FIND_OPCODE:
                        STZ             DBG_TMP_OPCODE
ASM_FIND_OPCODE_LOOP:
                        LDX             DBG_TMP_OPCODE
                        LDA             ASM_OP_MNEM_ID,X
                        CMP             DBG_TMP_OP
                        BNE             ASM_FIND_OPCODE_NEXT
                        LDA             ASM_OP_MODE,X
                        STA             DBG_TMP_MODE
                        JSR             ASM_MODE_ACCEPTS
                        BCS             ASM_FIND_OPCODE_HIT
ASM_FIND_OPCODE_NEXT:
                        INC             DBG_TMP_OPCODE
                        BNE             ASM_FIND_OPCODE_LOOP
                        CLC
                        RTS
ASM_FIND_OPCODE_HIT:
                        SEC
                        RTS

ASM_MODE_ACCEPTS:
                        LDA             DBG_TMP_MODE
                        CMP             #ASM_MODE_IMPL
                        BEQ             ASM_ACCEPT_NONE
                        CMP             #ASM_MODE_ACC
                        BEQ             ASM_ACCEPT_ACC
                        CMP             #ASM_MODE_IMM
                        BEQ             ASM_ACCEPT_IMM
                        CMP             #ASM_MODE_ZP
                        BEQ             ASM_ACCEPT_ZP
                        CMP             #ASM_MODE_ZPX
                        BEQ             ASM_ACCEPT_ZPX_J
                        CMP             #ASM_MODE_ZPY
                        BEQ             ASM_ACCEPT_ZPY_J
                        CMP             #ASM_MODE_ZPX_IND
                        BEQ             ASM_ACCEPT_ZPX_IND_J
                        CMP             #ASM_MODE_ZP_IND
                        BEQ             ASM_ACCEPT_ZP_IND_J
                        CMP             #ASM_MODE_ZP_IND_Y
                        BEQ             ASM_ACCEPT_ZP_IND_Y_J
                        CMP             #ASM_MODE_ABS
                        BEQ             ASM_ACCEPT_ABS_J
                        CMP             #ASM_MODE_ABSX
                        BEQ             ASM_ACCEPT_ABSX_J
                        CMP             #ASM_MODE_ABSY
                        BEQ             ASM_ACCEPT_ABSY_J
                        CMP             #ASM_MODE_ABS_IND
                        BEQ             ASM_ACCEPT_ABS_IND_J
                        CMP             #ASM_MODE_ABSX_IND
                        BEQ             ASM_ACCEPT_ABSX_IND_J
                        CMP             #ASM_MODE_REL
                        BEQ             ASM_ACCEPT_REL_J
                        CMP             #ASM_MODE_ZP_REL
                        BEQ             ASM_ACCEPT_ZP_REL_J
                        CMP             #ASM_MODE_BRK
                        BEQ             ASM_ACCEPT_BRK_J
                        CLC
                        RTS
ASM_ACCEPT_ABS_J:       JMP             ASM_ACCEPT_ABS
ASM_ACCEPT_ABSX_J:      JMP             ASM_ACCEPT_ABSX
ASM_ACCEPT_ABSY_J:      JMP             ASM_ACCEPT_ABSY
ASM_ACCEPT_ABS_IND_J:   JMP             ASM_ACCEPT_ABS_IND
ASM_ACCEPT_ABSX_IND_J:  JMP             ASM_ACCEPT_ABSX_IND
ASM_ACCEPT_ZP_REL_J:    JMP             ASM_ACCEPT_ZP_REL
ASM_ACCEPT_BRK_J:       JMP             ASM_ACCEPT_BRK
ASM_ACCEPT_ZP_IND_J:    JMP             ASM_ACCEPT_ZP_IND
ASM_ACCEPT_ZP_IND_Y_J:  JMP             ASM_ACCEPT_ZP_IND_Y
ASM_ACCEPT_ZPX_IND_J:   JMP             ASM_ACCEPT_ZPX_IND
ASM_ACCEPT_REL_J:       JMP             ASM_ACCEPT_REL
ASM_ACCEPT_ZPY_J:       JMP             ASM_ACCEPT_ZPY
ASM_ACCEPT_ZPX_J:       JMP             ASM_ACCEPT_ZPX

ASM_ACCEPT_NONE:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NONE
                        BEQ             ASM_ACCEPT_OK_J
                        CLC
                        RTS
ASM_ACCEPT_ACC:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_ACC
                        BEQ             ASM_ACCEPT_OK_J
                        CLC
                        RTS
ASM_ACCEPT_IMM:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_IMM
                        BEQ             ASM_ACCEPT_OK_J
                        CLC
                        RTS
ASM_ACCEPT_OK_J:        JMP             ASM_ACCEPT_OK
ASM_ACCEPT_FAIL_J:      JMP             ASM_ACCEPT_FAIL
ASM_ACCEPT_ZP:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_ZPX:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM_X
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_ZPY:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM_Y
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_ZPX_IND:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_PAREN_NUM_X
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_ZP_IND:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_PAREN_NUM
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_ZP_IND_Y:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_PAREN_NUM_Y
                        BNE             ASM_ACCEPT_FAIL_J
                        JMP             ASM_ACCEPT_BYTE_ADDR
ASM_ACCEPT_REL:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM
                        BNE             ASM_ACCEPT_FAIL_J
ASM_ACCEPT_BYTE_ADDR:
                        LDA             CMDP_ADDR_HI
                        BNE             ASM_ACCEPT_FAIL_J
                        SEC
                        RTS
ASM_ACCEPT_ABS:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM
                        BEQ             ASM_ACCEPT_OK
                        CLC
                        RTS
ASM_ACCEPT_ABSX:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM_X
                        BEQ             ASM_ACCEPT_OK
                        CLC
                        RTS
ASM_ACCEPT_ABSY:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NUM_Y
                        BEQ             ASM_ACCEPT_OK
                        CLC
                        RTS
ASM_ACCEPT_ABS_IND:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_PAREN_NUM
                        BEQ             ASM_ACCEPT_OK
                        CLC
                        RTS
ASM_ACCEPT_ABSX_IND:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_PAREN_NUM_X
                        BEQ             ASM_ACCEPT_OK
                        CLC
                        RTS
ASM_ACCEPT_ZP_REL:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_ZP_REL
                        BNE             ASM_ACCEPT_FAIL
                        LDA             CMDP_ADDR_HI
                        BNE             ASM_ACCEPT_FAIL
                        SEC
                        RTS
ASM_ACCEPT_BRK:
                        LDA             DBG_TMP_FLAGS
                        CMP             #ASM_SH_NONE
                        BEQ             ASM_ACCEPT_BRK_ZERO
                        CMP             #ASM_SH_NUM
                        BNE             ASM_ACCEPT_FAIL
                        LDA             CMDP_ADDR_HI
                        BNE             ASM_ACCEPT_FAIL
                        SEC
                        RTS
ASM_ACCEPT_BRK_ZERO:
                        STZ             CMDP_ADDR_LO
                        STZ             CMDP_ADDR_HI
                        SEC
                        RTS
ASM_ACCEPT_OK:
                        SEC
                        RTS
ASM_ACCEPT_FAIL:
                        CLC
                        RTS

ASM_EMIT:
                        LDA             DBG_TMP_OPCODE
                        JSR             ASM_STORE_A_ADV
                        LDA             DBG_TMP_MODE
                        CMP             #ASM_MODE_IMPL
                        BEQ             ASM_EMIT_1_DONE
                        CMP             #ASM_MODE_ACC
                        BEQ             ASM_EMIT_1_DONE
                        CMP             #ASM_MODE_ZP_REL
                        BEQ             ASM_EMIT_ZP_REL
                        CMP             #ASM_MODE_ABS
                        BCC             ASM_EMIT_BYTE_OPER
                        CMP             #ASM_MODE_REL
                        BCC             ASM_EMIT_WORD_OPER
ASM_EMIT_BYTE_OPER:
                        LDA             CMDP_ADDR_LO
                        JSR             ASM_STORE_A_ADV
                        LDA             #$02
                        STA             DBG_TMP_LEN
                        SEC
                        RTS
ASM_EMIT_WORD_OPER:
                        LDA             CMDP_ADDR_LO
                        JSR             ASM_STORE_A_ADV
                        LDA             CMDP_ADDR_HI
                        JSR             ASM_STORE_A_ADV
                        LDA             #$03
                        STA             DBG_TMP_LEN
                        SEC
                        RTS
ASM_EMIT_ZP_REL:
                        LDA             CMDP_ADDR_LO
                        JSR             ASM_STORE_A_ADV
                        LDA             CMD_RANGE_END_LO
                        JSR             ASM_STORE_A_ADV
                        LDA             #$03
                        STA             DBG_TMP_LEN
                        SEC
                        RTS
ASM_EMIT_1_DONE:
                        LDA             #$01
                        STA             DBG_TMP_LEN
                        SEC
                        RTS

ASM_STORE_A_ADV:
                        PHA
                        LDA             CMD_RANGE_TMP_LO
                        STA             CMDP_START_LO
                        LDA             CMD_RANGE_TMP_HI
                        STA             CMDP_START_HI
                        PLA
                        LDY             #$00
                        STA             (CMDP_START_LO),Y
                        INC             CMD_RANGE_TMP_LO
                        BNE             ASM_STORE_A_ADV_DONE
                        INC             CMD_RANGE_TMP_HI
ASM_STORE_A_ADV_DONE:
                        RTS

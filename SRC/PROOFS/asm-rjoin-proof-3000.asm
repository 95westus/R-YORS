; ----------------------------------------------------------------------------
; asm-rjoin-proof-3000.asm
; RAM-loaded ASM/RJOIN proof, linked at $3000.
;
; This is not the existing A mini assembler.  A remains the numeric interactive
; assembler.  ASM is the hash/RJOIN proof lane: source-ish names become FNV32
; hashes, local symbols are checked first, resident runtime records are joined
; second, and only resolved executable references emit native W65C02S code.
; ----------------------------------------------------------------------------

                        MODULE          ASM_RJOIN_PROOF_APP

                        XDEF            START

; ----------------------------------------------------------------------------
; App-local zero page. HIMON treats $00-$AF as user/free while user code runs.
; ----------------------------------------------------------------------------
ASM_STR_LO             EQU             $00
ASM_STR_HI             EQU             $01
ASM_JOIN_LO            EQU             $02
ASM_JOIN_HI            EQU             $03
ASM_HASH_PTR_LO        EQU             $04
ASM_HASH_PTR_HI        EQU             $05
ASM_SCAN_LO            EQU             $06
ASM_SCAN_HI            EQU             $07
ASM_IMP_WRITE_LO       EQU             $08
ASM_IMP_WRITE_HI       EQU             $09
ASM_PC_LO              EQU             $0A
ASM_PC_HI              EQU             $0B
ASM_EMIT_LO            EQU             $0C
ASM_EMIT_HI            EQU             $0D
ASM_KIND               EQU             $0E
ASM_PAD                EQU             $0F
ASM_HASH0              EQU             $10
ASM_HASH1              EQU             $11
ASM_HASH2              EQU             $12
ASM_HASH3              EQU             $13
ASM_TERM0              EQU             $14
ASM_TERM1              EQU             $15
ASM_TERM2              EQU             $16
ASM_TERM3              EQU             $17
ASM_JOINER_LO          EQU             $18
ASM_JOINER_HI          EQU             $19
ASM_WORD_LO            EQU             $1A
ASM_WORD_HI            EQU             $1B
ASM_IMP_READ_LO        EQU             $1C
ASM_IMP_READ_HI        EQU             $1D
ASM_LINE_COUNT         EQU             $1E
ASM_PARSE_LO           EQU             $1F
ASM_PARSE_HI           EQU             $20
ASM_TOKEN_LO           EQU             $21
ASM_TOKEN_HI           EQU             $22
ASM_DELIM_SAVE         EQU             $23
ASM_SLOT               EQU             $24
ASM_NAME_LO            EQU             $25
ASM_NAME_HI            EQU             $26

ASM_HASH_SIG2          EQU             ('V'+$80)
ASM_KIND_EXEC          EQU             $01
ASM_KIND_CONFIRM       EQU             $02
ASM_KIND_TEXT          EQU             $04
ASM_KIND_EXEC_CONFIRM_TEXT EQU         (ASM_KIND_EXEC+ASM_KIND_CONFIRM)
ASM_KIND_EXEC_TEXT     EQU             (ASM_KIND_EXEC+ASM_KIND_TEXT)
ASM_SCAN_BASE_HI       EQU             $80
ASM_SYM_MAX            EQU             $10
ASM_FIX_MAX            EQU             $08
ASM_FIX_NAME_MAX       EQU             $20
ASM_FIX_NAME_BYTES     EQU             $0100
ASM_LINE_MAX           EQU             $3F
ASM_FIX_PENDING        EQU             $01
ASM_FIX_RESOLVED       EQU             $02

                        CODE
START:
                        JSR             ASM_JOIN_INIT
                        BCS             START_HAVE_WRITE
                        RTS

START_HAVE_WRITE:
                        STX             ASM_IMP_WRITE_LO
                        STY             ASM_IMP_WRITE_HI

                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASM_PRINT_LINE
                        LDX             #<MSG_NOTE
                        LDY             #>MSG_NOTE
                        JSR             ASM_PRINT_LINE

                        JSR             ASM_SEED_LOCAL_RECORDS
                        LDA             #<ASM_CODE_BUF
                        STA             ASM_PC_LO
                        LDA             #>ASM_CODE_BUF
                        STA             ASM_PC_HI
                        LDX             #<MSG_PC_START
                        LDY             #>MSG_PC_START
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_PC_ADDR
                        JSR             ASM_PRINT_CRLF

                        JSR             ASM_PROVE_POSITIVE
                        JSR             ASM_TEST_MISSING
                        JSR             ASM_TEST_NONEXEC
                        JSR             ASM_TEST_FORWARD_REF
                        JSR             ASM_INPUT_LOOP
                        JSR             ASM_PRINT_RESOLVED_FIXUPS
                        JSR             ASM_PRINT_UNRESOLVED_FIXUPS

                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             ASM_PRINT_LINE
                        RTS

; ----------------------------------------------------------------------------
; ASM_JOIN_INIT
; Bootstrap the resident join layer and first output dependency.
; OUT: C=1 with X/Y and ASM_JOIN_LO/HI = BIO_FTDI_WRITE_BYTE_BLOCK entry.
;      C=0 if the resident joiner, write, or read routine cannot be joined.
; ----------------------------------------------------------------------------
ASM_JOIN_INIT:
                        LDX             #<HASH_THE_JOIN_EXEC_XY
                        LDY             #>HASH_THE_JOIN_EXEC_XY
                        JSR             ASM_JOIN_EXEC_XY
                        BCC             ASM_JOIN_INIT_FAIL
                        STX             ASM_JOINER_LO
                        STY             ASM_JOINER_HI

                        LDX             #<HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             ASM_RJOIN_RESIDENT_XY
                        BCC             ASM_JOIN_INIT_FAIL
                        STX             ASM_IMP_WRITE_LO
                        STY             ASM_IMP_WRITE_HI

                        LDX             #<HASH_BIO_READ_BYTE_BLOCK
                        LDY             #>HASH_BIO_READ_BYTE_BLOCK
                        JSR             ASM_RJOIN_RESIDENT_XY
                        BCC             ASM_JOIN_INIT_FAIL
                        STX             ASM_IMP_READ_LO
                        STY             ASM_IMP_READ_HI

                        LDX             ASM_IMP_WRITE_LO
                        LDY             ASM_IMP_WRITE_HI
                        SEC
                        RTS
ASM_JOIN_INIT_FAIL:
                        CLC
                        RTS

ASM_SEED_LOCAL_RECORDS:
                        STZ             ASM_SYM_COUNT
                        STZ             ASM_FIX_COUNT
                        LDX             #<STR_NON_EXEC_RECORD
                        LDY             #>STR_NON_EXEC_RECORD
                        JSR             ASM_HASH_CSTRING_XY
                        JSR             ASM_COPY_HASH_TO_NONEXEC
                        LDA             #<ASM_NONEXEC_DATA
                        STA             ASM_NONEXEC_VAL_LO
                        LDA             #>ASM_NONEXEC_DATA
                        STA             ASM_NONEXEC_VAL_HI
                        STZ             ASM_NONEXEC_KIND
                        RTS

; ----------------------------------------------------------------------------
; Positive scripted proof:
;   START: JSR BIO_FTDI_WRITE_BYTE_BLOCK
; ----------------------------------------------------------------------------
ASM_PROVE_POSITIVE:
                        LDX             #<MSG_LINE_POS
                        LDY             #>MSG_LINE_POS
                        JSR             ASM_PRINT_LINE

                        LDX             #<STR_LABEL_START
                        LDY             #>STR_LABEL_START
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        JSR             ASM_DEFINE_LABEL_CURRENT

                        LDX             #<MSG_LABEL_START
                        LDY             #>MSG_LABEL_START
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_LABEL_START
                        LDY             #>STR_LABEL_START
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        LDX             #<MSG_VALUE_FIELD
                        LDY             #>MSG_VALUE_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_JOIN_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_JOIN_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_STORE_LOCAL
                        LDY             #>MSG_STORE_LOCAL
                        JSR             ASM_PRINT_LINE
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT

                        LDX             #<MSG_OP_JSR
                        LDY             #>MSG_OP_JSR
                        JSR             ASM_PRINT_LINE

                        LDX             #<STR_BIO_WRITE
                        LDY             #>STR_BIO_WRITE
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        LDX             #<MSG_OPERAND_BIO
                        LDY             #>MSG_OPERAND_BIO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_BIO_WRITE
                        LDY             #>STR_BIO_WRITE
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_LOCAL_LOOKUP_CURRENT
                        BCS             ASM_POS_LOCAL_UNEXPECTED
                        LDX             #<MSG_LOCAL_NO
                        LDY             #>MSG_LOCAL_NO
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_RJOIN_RESIDENT_CURRENT
                        BCC             ASM_POS_RJOIN_FAIL
                        LDX             #<MSG_RJOIN_FOUND
                        LDY             #>MSG_RJOIN_FOUND
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_ENTRY_FIELD
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASM_PRINT_LINE
                        JSR             ASM_EMIT_JSR_JOIN
                        JSR             ASM_RUN_GENERATED
                        RTS

ASM_POS_LOCAL_UNEXPECTED:
                        LDX             #<MSG_LOCAL_UNEXPECTED
                        LDY             #>MSG_LOCAL_UNEXPECTED
                        JMP             ASM_PRINT_LINE

ASM_POS_RJOIN_FAIL:
                        LDX             #<MSG_RJOIN_NO
                        LDY             #>MSG_RJOIN_NO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_ERROR_UNRESOLVED
                        LDY             #>MSG_ERROR_UNRESOLVED
                        JMP             ASM_PRINT_LINE

ASM_EMIT_JSR_ADVANCE:
                        LDA             ASM_PC_LO
                        STA             ASM_EMIT_LO
                        LDA             ASM_PC_HI
                        STA             ASM_EMIT_HI

                        LDY             #$00
                        LDA             #$20
                        STA             (ASM_EMIT_LO),Y
                        INY
                        LDA             ASM_JOIN_LO
                        STA             (ASM_EMIT_LO),Y
                        INY
                        LDA             ASM_JOIN_HI
                        STA             (ASM_EMIT_LO),Y

                        LDX             #<MSG_EMIT
                        LDY             #>MSG_EMIT
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_EMIT_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_EMIT_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_COLON_SPACE
                        LDY             #>MSG_COLON_SPACE
                        JSR             ASM_WRITE_CSTRING
                        LDA             #$20
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             ASM_JOIN_LO
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             ASM_JOIN_HI
                        JSR             ASM_WRITE_HEX_BYTE
                        JSR             ASM_ADVANCE_PC3
                        JSR             ASM_PRINT_PC_FIELD
                        JMP             ASM_PRINT_CRLF

ASM_EMIT_JSR_JOIN:
                        JSR             ASM_EMIT_JSR_ADVANCE
                        LDY             #$00
                        LDA             #$60
                        STA             (ASM_PC_LO),Y

                        LDX             #<MSG_HARNESS_RTS
                        LDY             #>MSG_HARNESS_RTS
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_PC_ADDR
                        JMP             ASM_PRINT_CRLF

ASM_ADVANCE_PC3:
                        CLC
                        LDA             ASM_PC_LO
                        ADC             #$03
                        STA             ASM_PC_LO
                        BCC             ASM_ADVANCE_PC3_NO_CARRY
                        INC             ASM_PC_HI
ASM_ADVANCE_PC3_NO_CARRY:
                        RTS

ASM_RUN_GENERATED:
                        LDX             #<MSG_RUN
                        LDY             #>MSG_RUN
                        JSR             ASM_WRITE_CSTRING
                        LDA             #'!'
                        JSR             ASM_CODE_BUF
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_RUN_OK
                        LDY             #>MSG_RUN_OK
                        JMP             ASM_PRINT_LINE

; ----------------------------------------------------------------------------
; Negative scripted proof:
;   JSR NO_SUCH_LABEL
; ----------------------------------------------------------------------------
ASM_TEST_MISSING:
                        LDX             #<MSG_LINE_MISSING
                        LDY             #>MSG_LINE_MISSING
                        JSR             ASM_PRINT_LINE
                        LDX             #<STR_NO_SUCH_LABEL
                        LDY             #>STR_NO_SUCH_LABEL
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        LDX             #<MSG_OPERAND_MISSING
                        LDY             #>MSG_OPERAND_MISSING
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_NO_SUCH_LABEL
                        LDY             #>STR_NO_SUCH_LABEL
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_LOCAL_LOOKUP_CURRENT
                        BCS             ASM_MISSING_BAD_LOCAL
                        LDX             #<MSG_LOCAL_NO
                        LDY             #>MSG_LOCAL_NO
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_RJOIN_RESIDENT_CURRENT
                        BCS             ASM_MISSING_BAD_RJOIN
                        LDX             #<MSG_RJOIN_NO
                        LDY             #>MSG_RJOIN_NO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_ERROR_UNRESOLVED
                        LDY             #>MSG_ERROR_UNRESOLVED
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_NO_EMIT_PC
                        JMP             ASM_PRINT_CRLF
ASM_MISSING_BAD_LOCAL:
                        LDX             #<MSG_LOCAL_UNEXPECTED
                        LDY             #>MSG_LOCAL_UNEXPECTED
                        JMP             ASM_PRINT_LINE
ASM_MISSING_BAD_RJOIN:
                        LDX             #<MSG_RJOIN_UNEXPECTED
                        LDY             #>MSG_RJOIN_UNEXPECTED
                        JMP             ASM_PRINT_LINE

; ----------------------------------------------------------------------------
; Negative scripted proof:
;   JSR NON_EXEC_RECORD
; ----------------------------------------------------------------------------
ASM_TEST_NONEXEC:
                        LDX             #<MSG_LINE_NONEXEC
                        LDY             #>MSG_LINE_NONEXEC
                        JSR             ASM_PRINT_LINE
                        LDX             #<STR_NON_EXEC_RECORD
                        LDY             #>STR_NON_EXEC_RECORD
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        LDX             #<MSG_OPERAND_NONEXEC
                        LDY             #>MSG_OPERAND_NONEXEC
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_NON_EXEC_RECORD
                        LDY             #>STR_NON_EXEC_RECORD
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_LOCAL_LOOKUP_CURRENT
                        BCC             ASM_NONEXEC_BAD_MISSING
                        STA             ASM_KIND
                        LDX             #<MSG_LOCAL_FOUND
                        LDY             #>MSG_LOCAL_FOUND
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_KIND_FIELD
                        LDY             #>MSG_KIND_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_KIND
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             ASM_KIND
                        AND             #ASM_KIND_EXEC
                        BNE             ASM_NONEXEC_BAD_EXEC
                        LDX             #<MSG_KIND_NOT_EXEC
                        LDY             #>MSG_KIND_NOT_EXEC
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_ERROR_NOT_EXEC
                        LDY             #>MSG_ERROR_NOT_EXEC
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_NO_EMIT_PC
                        JMP             ASM_PRINT_CRLF
ASM_NONEXEC_BAD_MISSING:
                        LDX             #<MSG_LOCAL_MISSING_BAD
                        LDY             #>MSG_LOCAL_MISSING_BAD
                        JMP             ASM_PRINT_LINE
ASM_NONEXEC_BAD_EXEC:
                        LDX             #<MSG_EXEC_UNEXPECTED
                        LDY             #>MSG_EXEC_UNEXPECTED
                        JMP             ASM_PRINT_LINE

; ----------------------------------------------------------------------------
; Forward-reference simulation:
;   JSR LATER_LABEL
;   LATER_LABEL: JSR BIO_FTDI_WRITE_BYTE_BLOCK
;
; This deliberately uses an RF-like pending patch site after the strict
; resolved/not-resolved tests above.
; ----------------------------------------------------------------------------
ASM_TEST_FORWARD_REF:
                        LDX             #<MSG_LINE_FWD
                        LDY             #>MSG_LINE_FWD
                        JSR             ASM_PRINT_LINE
                        LDX             #<STR_LATER_LABEL
                        LDY             #>STR_LATER_LABEL
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        LDX             #<MSG_OPERAND_LATER
                        LDY             #>MSG_OPERAND_LATER
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_LATER_LABEL
                        LDY             #>STR_LATER_LABEL
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_LOCAL_LOOKUP_CURRENT
                        BCS             ASM_FWD_BAD_EARLY
                        LDX             #<MSG_LOCAL_NO
                        LDY             #>MSG_LOCAL_NO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_RF_PENDING
                        LDY             #>MSG_RF_PENDING
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_EMIT_JSR_PENDING

                        LDX             #<MSG_LINE_FWD_DEF
                        LDY             #>MSG_LINE_FWD_DEF
                        JSR             ASM_PRINT_LINE
                        LDX             #<STR_LATER_LABEL
                        LDY             #>STR_LATER_LABEL
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        JSR             ASM_DEFINE_LABEL_CURRENT
                        LDX             #<MSG_LABEL_LATER
                        LDY             #>MSG_LABEL_LATER
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_LATER_LABEL
                        LDY             #>STR_LATER_LABEL
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        LDX             #<MSG_VALUE_FIELD
                        LDY             #>MSG_VALUE_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_JOIN_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_JOIN_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_STORE_LOCAL
                        LDY             #>MSG_STORE_LOCAL
                        JSR             ASM_PRINT_LINE
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT

                        LDX             #<STR_BIO_WRITE
                        LDY             #>STR_BIO_WRITE
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        LDX             #<MSG_OPERAND_BIO
                        LDY             #>MSG_OPERAND_BIO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<STR_BIO_WRITE
                        LDY             #>STR_BIO_WRITE
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_ASSEMBLE_JSR_CURRENT
                        RTS
ASM_FWD_BAD_EARLY:
                        LDX             #<MSG_FWD_BAD_EARLY
                        LDY             #>MSG_FWD_BAD_EARLY
                        JMP             ASM_PRINT_LINE

; ----------------------------------------------------------------------------
; Interactive proof loop. Lines are intentionally tiny:
;   [LABEL:] JSR OPERAND
; Blank lines do nothing. Ctrl-C exits. Every accepted instruction advances PC
; by three bytes, even when it becomes an RF SIM pending patch.
; ----------------------------------------------------------------------------
ASM_INPUT_LOOP:
                        LDX             #<MSG_INPUT_HELP
                        LDY             #>MSG_INPUT_HELP
                        JSR             ASM_PRINT_LINE
ASM_INPUT_PROMPT:
                        LDX             #<MSG_INPUT_PC
                        LDY             #>MSG_INPUT_PC
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_PC_ADDR
                        LDX             #<MSG_INPUT_PROMPT
                        LDY             #>MSG_INPUT_PROMPT
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_READ_LINE
                        BCC             ASM_INPUT_EXIT
                        LDA             ASM_LINE_COUNT
                        BEQ             ASM_INPUT_PROMPT
                        JSR             ASM_PARSE_LINE_BUF
                        BRA             ASM_INPUT_PROMPT
ASM_INPUT_EXIT:
                        LDX             #<MSG_CTRL_C_EXIT
                        LDY             #>MSG_CTRL_C_EXIT
                        JMP             ASM_PRINT_LINE

ASM_READ_LINE:
                        STZ             ASM_LINE_COUNT
ASM_READ_LINE_LOOP:
                        JSR             ASM_BIO_READ_BYTE_BLOCK
                        CMP             #$03
                        BEQ             ASM_READ_LINE_CTRL_C
                        CMP             #$0D
                        BEQ             ASM_READ_LINE_DONE
                        CMP             #$0A
                        BEQ             ASM_READ_LINE_DONE
                        CMP             #$08
                        BEQ             ASM_READ_LINE_BACKSPACE
                        CMP             #$7F
                        BEQ             ASM_READ_LINE_BACKSPACE
                        JSR             ASM_TO_UPPER
                        LDX             ASM_LINE_COUNT
                        CPX             #ASM_LINE_MAX
                        BCS             ASM_READ_LINE_TOO_LONG
                        STA             ASM_LINE_BUF,X
                        INC             ASM_LINE_COUNT
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        BRA             ASM_READ_LINE_LOOP
ASM_READ_LINE_BACKSPACE:
                        LDA             ASM_LINE_COUNT
                        BEQ             ASM_READ_LINE_LOOP
                        DEC             ASM_LINE_COUNT
                        LDX             ASM_LINE_COUNT
                        STZ             ASM_LINE_BUF,X
                        LDA             #$08
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             #$08
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        BRA             ASM_READ_LINE_LOOP
ASM_READ_LINE_DONE:
                        JSR             ASM_PRINT_CRLF
                        LDX             ASM_LINE_COUNT
                        STZ             ASM_LINE_BUF,X
                        SEC
                        RTS
ASM_READ_LINE_CTRL_C:
                        JSR             ASM_PRINT_CRLF
                        CLC
                        RTS
ASM_READ_LINE_TOO_LONG:
                        LDX             #<MSG_LINE_TOO_LONG
                        LDY             #>MSG_LINE_TOO_LONG
                        JSR             ASM_PRINT_LINE
ASM_READ_LINE_DRAIN:
                        JSR             ASM_BIO_READ_BYTE_BLOCK
                        CMP             #$03
                        BEQ             ASM_READ_LINE_CTRL_C
                        CMP             #$0D
                        BEQ             ASM_READ_LINE_DRAIN_DONE
                        CMP             #$0A
                        BNE             ASM_READ_LINE_DRAIN
ASM_READ_LINE_DRAIN_DONE:
                        STZ             ASM_LINE_COUNT
                        SEC
                        RTS

ASM_TO_UPPER:
                        CMP             #'a'
                        BCC             ASM_TO_UPPER_DONE
                        CMP             #'z'+1
                        BCS             ASM_TO_UPPER_DONE
                        SEC
                        SBC             #$20
ASM_TO_UPPER_DONE:
                        RTS

ASM_PARSE_LINE_BUF:
                        LDA             #<ASM_LINE_BUF
                        STA             ASM_PARSE_LO
                        LDA             #>ASM_LINE_BUF
                        STA             ASM_PARSE_HI
                        JSR             ASM_PARSE_GET_TOKEN
                        BCC             ASM_PARSE_BLANK
                        LDA             ASM_DELIM_SAVE
                        CMP             #':'
                        BEQ             ASM_PARSE_HAVE_LABEL
                        JSR             ASM_TOKEN_IS_JSR
                        BCS             ASM_PARSE_HAVE_OP
                        BRA             ASM_PARSE_HAVE_LABEL

ASM_PARSE_HAVE_LABEL:
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        JSR             ASM_DEFINE_LABEL_CURRENT
                        JSR             ASM_PRINT_LABEL_TOKEN_LINE
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT
                        JSR             ASM_PARSE_ADV_AFTER_DELIM
                        JSR             ASM_PARSE_GET_TOKEN
                        BCC             ASM_PARSE_LABEL_ONLY

ASM_PARSE_HAVE_OP:
                        JSR             ASM_TOKEN_IS_JSR
                        BCC             ASM_PARSE_BAD_OP
                        JSR             ASM_PARSE_ADV_AFTER_DELIM
                        JSR             ASM_PARSE_GET_TOKEN
                        BCC             ASM_PARSE_MISSING_OPERAND
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JSR             ASM_SET_NAME_XY
                        JSR             ASM_HASH_CSTRING_XY
                        JSR             ASM_PRINT_OPERAND_TOKEN_LINE
                        JMP             ASM_ASSEMBLE_JSR_CURRENT

ASM_PARSE_LABEL_ONLY:
                        LDX             #<MSG_LABEL_ONLY
                        LDY             #>MSG_LABEL_ONLY
                        JMP             ASM_PRINT_LINE
ASM_PARSE_BLANK:
                        RTS
ASM_PARSE_BAD_OP:
                        LDX             #<MSG_PARSE_BAD_OP
                        LDY             #>MSG_PARSE_BAD_OP
                        JMP             ASM_PRINT_LINE
ASM_PARSE_MISSING_OPERAND:
                        LDX             #<MSG_PARSE_MISSING_OPERAND
                        LDY             #>MSG_PARSE_MISSING_OPERAND
                        JMP             ASM_PRINT_LINE

ASM_PARSE_GET_TOKEN:
                        JSR             ASM_PARSE_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_LO),Y
                        BEQ             ASM_PARSE_GET_TOKEN_NONE
                        LDA             ASM_PARSE_LO
                        STA             ASM_TOKEN_LO
                        LDA             ASM_PARSE_HI
                        STA             ASM_TOKEN_HI
ASM_PARSE_GET_TOKEN_SCAN:
                        LDY             #$00
                        LDA             (ASM_PARSE_LO),Y
                        BEQ             ASM_PARSE_GET_TOKEN_END
                        CMP             #' '
                        BEQ             ASM_PARSE_GET_TOKEN_END
                        CMP             #$09
                        BEQ             ASM_PARSE_GET_TOKEN_END
                        CMP             #':'
                        BEQ             ASM_PARSE_GET_TOKEN_END
                        JSR             ASM_PARSE_ADV
                        BRA             ASM_PARSE_GET_TOKEN_SCAN
ASM_PARSE_GET_TOKEN_END:
                        STA             ASM_DELIM_SAVE
                        LDY             #$00
                        LDA             #$00
                        STA             (ASM_PARSE_LO),Y
                        SEC
                        RTS
ASM_PARSE_GET_TOKEN_NONE:
                        CLC
                        RTS

ASM_PARSE_SKIP_SPACES:
                        LDY             #$00
                        LDA             (ASM_PARSE_LO),Y
                        CMP             #' '
                        BEQ             ASM_PARSE_SKIP_ONE
                        CMP             #$09
                        BEQ             ASM_PARSE_SKIP_ONE
                        RTS
ASM_PARSE_SKIP_ONE:
                        JSR             ASM_PARSE_ADV
                        BRA             ASM_PARSE_SKIP_SPACES

ASM_PARSE_ADV_AFTER_DELIM:
                        LDA             ASM_DELIM_SAVE
                        BEQ             ASM_PARSE_ADV_AFTER_DONE
                        JSR             ASM_PARSE_ADV
ASM_PARSE_ADV_AFTER_DONE:
                        RTS

ASM_PARSE_ADV:
                        INC             ASM_PARSE_LO
                        BNE             ASM_PARSE_ADV_DONE
                        INC             ASM_PARSE_HI
ASM_PARSE_ADV_DONE:
                        RTS

ASM_TOKEN_IS_JSR:
                        LDY             #$00
                        LDA             (ASM_TOKEN_LO),Y
                        CMP             #'J'
                        BNE             ASM_TOKEN_IS_JSR_NO
                        INY
                        LDA             (ASM_TOKEN_LO),Y
                        CMP             #'S'
                        BNE             ASM_TOKEN_IS_JSR_NO
                        INY
                        LDA             (ASM_TOKEN_LO),Y
                        CMP             #'R'
                        BNE             ASM_TOKEN_IS_JSR_NO
                        INY
                        LDA             (ASM_TOKEN_LO),Y
                        BNE             ASM_TOKEN_IS_JSR_NO
                        SEC
                        RTS
ASM_TOKEN_IS_JSR_NO:
                        CLC
                        RTS

ASM_ASSEMBLE_JSR_CURRENT:
                        JSR             ASM_LOCAL_LOOKUP_CURRENT
                        BCC             ASM_ASSEMBLE_JSR_CHECK_RJOIN
                        STA             ASM_KIND
                        LDX             #<MSG_LOCAL_FOUND
                        LDY             #>MSG_LOCAL_FOUND
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_KIND_FIELD
                        LDY             #>MSG_KIND_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_KIND
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             ASM_KIND
                        AND             #ASM_KIND_EXEC
                        BEQ             ASM_ASSEMBLE_JSR_NOT_EXEC
                        LDX             #<MSG_KIND_EXEC
                        LDY             #>MSG_KIND_EXEC
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASM_PRINT_LINE
                        JMP             ASM_EMIT_JSR_ADVANCE
ASM_ASSEMBLE_JSR_NOT_EXEC:
                        LDX             #<MSG_KIND_NOT_EXEC
                        LDY             #>MSG_KIND_NOT_EXEC
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_ERROR_NOT_EXEC
                        LDY             #>MSG_ERROR_NOT_EXEC
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_NO_EMIT_PC
                        JMP             ASM_PRINT_CRLF
ASM_ASSEMBLE_JSR_CHECK_RJOIN:
                        LDX             #<MSG_LOCAL_NO
                        LDY             #>MSG_LOCAL_NO
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_RJOIN_RESIDENT_CURRENT
                        BCC             ASM_ASSEMBLE_JSR_FORWARD
                        LDX             #<MSG_RJOIN_FOUND
                        LDY             #>MSG_RJOIN_FOUND
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_ENTRY_FIELD
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             ASM_PRINT_LINE
                        JMP             ASM_EMIT_JSR_ADVANCE
ASM_ASSEMBLE_JSR_FORWARD:
                        LDX             #<MSG_RJOIN_NO
                        LDY             #>MSG_RJOIN_NO
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_RF_PENDING
                        LDY             #>MSG_RF_PENDING
                        JSR             ASM_WRITE_CSTRING
                        JMP             ASM_EMIT_JSR_PENDING

ASM_EMIT_JSR_PENDING:
                        LDA             ASM_PC_LO
                        STA             ASM_EMIT_LO
                        LDA             ASM_PC_HI
                        STA             ASM_EMIT_HI
                        LDY             #$00
                        LDA             #$20
                        STA             (ASM_EMIT_LO),Y
                        INY
                        LDA             #$00
                        STA             (ASM_EMIT_LO),Y
                        INY
                        STA             (ASM_EMIT_LO),Y
                        JSR             ASM_STORE_FIXUP_CURRENT
                        BCC             ASM_EMIT_PENDING_FULL
                        LDX             #<MSG_EMIT_PENDING
                        LDY             #>MSG_EMIT_PENDING
                        JSR             ASM_PRINT_LINE
                        JSR             ASM_PRINT_NAME_FIELD
                        LDX             #<MSG_SITE_FIELD
                        LDY             #>MSG_SITE_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_EMIT_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_EMIT_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_COLON_SPACE
                        LDY             #>MSG_COLON_SPACE
                        JSR             ASM_WRITE_CSTRING
                        LDA             #$20
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             #$00
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             #$00
                        JSR             ASM_WRITE_HEX_BYTE
                        JSR             ASM_ADVANCE_PC3
                        JSR             ASM_PRINT_PC_FIELD
                        JMP             ASM_PRINT_CRLF
ASM_EMIT_PENDING_FULL:
                        LDX             #<MSG_FIXUP_FULL
                        LDY             #>MSG_FIXUP_FULL
                        JMP             ASM_PRINT_LINE

ASM_DEFINE_LABEL_CURRENT:
                        LDA             ASM_PC_LO
                        STA             ASM_JOIN_LO
                        LDA             ASM_PC_HI
                        STA             ASM_JOIN_HI
                        LDA             #ASM_KIND_EXEC
                        STA             ASM_KIND
                        JSR             ASM_STORE_SYMBOL_CURRENT
                        BCC             ASM_DEFINE_LABEL_FULL
                        RTS
ASM_DEFINE_LABEL_FULL:
                        LDX             #<MSG_SYMBOL_FULL
                        LDY             #>MSG_SYMBOL_FULL
                        JMP             ASM_PRINT_LINE

ASM_SET_NAME_XY:
                        STX             ASM_NAME_LO
                        STY             ASM_NAME_HI
                        RTS

ASM_PRINT_LABEL_TOKEN_LINE:
                        LDX             #<MSG_LABEL_PREFIX
                        LDY             #>MSG_LABEL_PREFIX
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_FIELD_INDENT
                        LDY             #>MSG_FIELD_INDENT
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        LDX             #<MSG_VALUE_FIELD
                        LDY             #>MSG_VALUE_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_JOIN_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_JOIN_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_STORE_LOCAL
                        LDY             #>MSG_STORE_LOCAL
                        JMP             ASM_PRINT_LINE

ASM_PRINT_OPERAND_TOKEN_LINE:
                        LDX             #<MSG_OPERAND_PREFIX
                        LDY             #>MSG_OPERAND_PREFIX
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_FIELD_INDENT
                        LDY             #>MSG_FIELD_INDENT
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_TOKEN_LO
                        LDY             ASM_TOKEN_HI
                        JMP             ASM_PRINT_HASH_CURRENT_OF_XY

ASM_PRINT_NO_EMIT_PC:
                        LDX             #<MSG_EMIT_NO
                        LDY             #>MSG_EMIT_NO
                        JSR             ASM_WRITE_CSTRING
                        JMP             ASM_PRINT_PC_FIELD

; ----------------------------------------------------------------------------
; Local symbol/record lookup.
; IN : ASM_HASH0..3 = hash to find.
; OUT: found: C=1, A=kind, ASM_JOIN_LO/HI=value.
;      not found: C=0.
; ----------------------------------------------------------------------------
ASM_LOCAL_LOOKUP_CURRENT:
                        LDX             #$00
ASM_LOCAL_LOOKUP_SYM_LOOP:
                        CPX             ASM_SYM_COUNT
                        BCS             ASM_LOCAL_CHECK_NONEXEC
                        JSR             ASM_HASH_MATCH_SYM_X
                        BCS             ASM_LOCAL_LOOKUP_SYM_FOUND
                        INX
                        BRA             ASM_LOCAL_LOOKUP_SYM_LOOP
ASM_LOCAL_LOOKUP_SYM_FOUND:
                        LDA             ASM_SYM_VAL_LO,X
                        STA             ASM_JOIN_LO
                        LDA             ASM_SYM_VAL_HI,X
                        STA             ASM_JOIN_HI
                        LDA             ASM_SYM_KIND,X
                        SEC
                        RTS
ASM_LOCAL_CHECK_NONEXEC:
                        JSR             ASM_HASH_MATCH_NONEXEC
                        BCC             ASM_LOCAL_NOT_FOUND
                        LDA             ASM_NONEXEC_VAL_LO
                        STA             ASM_JOIN_LO
                        LDA             ASM_NONEXEC_VAL_HI
                        STA             ASM_JOIN_HI
                        LDA             ASM_NONEXEC_KIND
                        SEC
                        RTS
ASM_LOCAL_NOT_FOUND:
                        CLC
                        RTS

ASM_HASH_MATCH_SYM_X:
                        LDA             ASM_HASH0
                        CMP             ASM_SYM_HASH0,X
                        BNE             ASM_HASH_MATCH_NO
                        LDA             ASM_HASH1
                        CMP             ASM_SYM_HASH1,X
                        BNE             ASM_HASH_MATCH_NO
                        LDA             ASM_HASH2
                        CMP             ASM_SYM_HASH2,X
                        BNE             ASM_HASH_MATCH_NO
                        LDA             ASM_HASH3
                        CMP             ASM_SYM_HASH3,X
                        BNE             ASM_HASH_MATCH_NO
                        SEC
                        RTS

ASM_HASH_MATCH_NONEXEC:
                        LDX             #$03
ASM_HASH_MATCH_NONEXEC_LOOP:
                        LDA             ASM_HASH0,X
                        CMP             ASM_NONEXEC_HASH,X
                        BNE             ASM_HASH_MATCH_NO
                        DEX
                        BPL             ASM_HASH_MATCH_NONEXEC_LOOP
                        SEC
                        RTS
ASM_HASH_MATCH_NO:
                        CLC
                        RTS

ASM_STORE_SYMBOL_CURRENT:
                        LDX             ASM_SYM_COUNT
                        CPX             #ASM_SYM_MAX
                        BCS             ASM_STORE_SYMBOL_FULL
                        LDA             ASM_HASH0
                        STA             ASM_SYM_HASH0,X
                        LDA             ASM_HASH1
                        STA             ASM_SYM_HASH1,X
                        LDA             ASM_HASH2
                        STA             ASM_SYM_HASH2,X
                        LDA             ASM_HASH3
                        STA             ASM_SYM_HASH3,X
                        LDA             ASM_JOIN_LO
                        STA             ASM_SYM_VAL_LO,X
                        LDA             ASM_JOIN_HI
                        STA             ASM_SYM_VAL_HI,X
                        LDA             ASM_KIND
                        STA             ASM_SYM_KIND,X
                        INC             ASM_SYM_COUNT
                        SEC
                        RTS
ASM_STORE_SYMBOL_FULL:
                        CLC
                        RTS

ASM_COPY_HASH_TO_NONEXEC:
                        LDX             #$03
ASM_COPY_HASH_TO_NONEXEC_LOOP:
                        LDA             ASM_HASH0,X
                        STA             ASM_NONEXEC_HASH,X
                        DEX
                        BPL             ASM_COPY_HASH_TO_NONEXEC_LOOP
                        RTS

ASM_STORE_FIXUP_CURRENT:
                        LDX             ASM_FIX_COUNT
                        CPX             #ASM_FIX_MAX
                        BCS             ASM_STORE_FIXUP_FULL
                        LDA             ASM_HASH0
                        STA             ASM_FIX_HASH0,X
                        LDA             ASM_HASH1
                        STA             ASM_FIX_HASH1,X
                        LDA             ASM_HASH2
                        STA             ASM_FIX_HASH2,X
                        LDA             ASM_HASH3
                        STA             ASM_FIX_HASH3,X
                        LDA             ASM_EMIT_LO
                        STA             ASM_FIX_SITE_LO,X
                        LDA             ASM_EMIT_HI
                        STA             ASM_FIX_SITE_HI,X
                        LDA             #ASM_FIX_PENDING
                        STA             ASM_FIX_STATE,X
                        JSR             ASM_STORE_FIXUP_NAME_X
                        INC             ASM_FIX_COUNT
                        SEC
                        RTS
ASM_STORE_FIXUP_FULL:
                        CLC
                        RTS

ASM_STORE_FIXUP_NAME_X:
                        JSR             ASM_FIX_NAME_ADDR_X_TO_SCAN
                        LDY             #$00
ASM_STORE_FIXUP_NAME_LOOP:
                        CPY             #(ASM_FIX_NAME_MAX-1)
                        BCS             ASM_STORE_FIXUP_NAME_TERM
                        LDA             (ASM_NAME_LO),Y
                        BEQ             ASM_STORE_FIXUP_NAME_DONE
                        STA             (ASM_SCAN_LO),Y
                        INY
                        BRA             ASM_STORE_FIXUP_NAME_LOOP
ASM_STORE_FIXUP_NAME_TERM:
                        LDA             #$00
ASM_STORE_FIXUP_NAME_DONE:
                        STA             (ASM_SCAN_LO),Y
                        LDX             ASM_SLOT
                        RTS

ASM_FIX_NAME_ADDR_X_TO_SCAN:
                        STX             ASM_SLOT
                        TXA
                        ASL
                        ASL
                        ASL
                        ASL
                        ASL
                        CLC
                        ADC             #<ASM_FIX_NAME_TEXT
                        STA             ASM_SCAN_LO
                        LDA             #>ASM_FIX_NAME_TEXT
                        ADC             #$00
                        STA             ASM_SCAN_HI
                        LDX             ASM_SLOT
                        RTS

ASM_RESOLVE_FIXUPS_CURRENT:
                        LDX             #$00
ASM_RESOLVE_FIXUPS_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_RESOLVE_FIXUPS_DONE
                        STX             ASM_SLOT
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_RESOLVE_FIXUPS_NEXT
                        JSR             ASM_HASH_MATCH_FIX_X
                        BCC             ASM_RESOLVE_FIXUPS_NEXT
                        LDX             ASM_SLOT
                        JSR             ASM_PATCH_FIXUP_X
                        LDX             ASM_SLOT
                        LDA             #ASM_FIX_RESOLVED
                        STA             ASM_FIX_STATE,X
                        JSR             ASM_PRINT_FIXUP_RESOLVED_X
ASM_RESOLVE_FIXUPS_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_RESOLVE_FIXUPS_LOOP
ASM_RESOLVE_FIXUPS_DONE:
                        RTS

ASM_HASH_MATCH_FIX_X:
                        LDA             ASM_HASH0
                        CMP             ASM_FIX_HASH0,X
                        BNE             ASM_HASH_MATCH_FIX_NO
                        LDA             ASM_HASH1
                        CMP             ASM_FIX_HASH1,X
                        BNE             ASM_HASH_MATCH_FIX_NO
                        LDA             ASM_HASH2
                        CMP             ASM_FIX_HASH2,X
                        BNE             ASM_HASH_MATCH_FIX_NO
                        LDA             ASM_HASH3
                        CMP             ASM_FIX_HASH3,X
                        BNE             ASM_HASH_MATCH_FIX_NO
                        SEC
                        RTS
ASM_HASH_MATCH_FIX_NO:
                        CLC
                        RTS

ASM_PATCH_FIXUP_X:
                        LDA             ASM_FIX_SITE_LO,X
                        CLC
                        ADC             #$01
                        STA             ASM_EMIT_LO
                        LDA             ASM_FIX_SITE_HI,X
                        ADC             #$00
                        STA             ASM_EMIT_HI
                        LDY             #$00
                        LDA             ASM_JOIN_LO
                        STA             (ASM_EMIT_LO),Y
                        INY
                        LDA             ASM_JOIN_HI
                        STA             (ASM_EMIT_LO),Y
                        RTS

ASM_PRINT_FIXUP_RESOLVED_X:
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_WORD_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_WORD_HI
                        LDX             #<MSG_RF_RESOLVE
                        LDY             #>MSG_RF_RESOLVE
                        JSR             ASM_PRINT_LINE
                        JSR             ASM_PRINT_FIXUP_NAME_FIELD
                        LDX             #<MSG_SITE_FIELD
                        LDY             #>MSG_SITE_FIELD
                        JSR             ASM_WRITE_CSTRING
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_TARGET_FIELD
                        LDY             #>MSG_TARGET_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_JOIN_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_JOIN_HI
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        LDX             #<MSG_PATCH_OK
                        LDY             #>MSG_PATCH_OK
                        JMP             ASM_PRINT_LINE

ASM_COPY_FIXUP_HASH_X:
                        LDA             ASM_FIX_HASH0,X
                        STA             ASM_HASH0
                        LDA             ASM_FIX_HASH1,X
                        STA             ASM_HASH1
                        LDA             ASM_FIX_HASH2,X
                        STA             ASM_HASH2
                        LDA             ASM_FIX_HASH3,X
                        STA             ASM_HASH3
                        RTS

ASM_LOAD_FIXUP_TARGET_X:
                        LDA             ASM_FIX_SITE_LO,X
                        CLC
                        ADC             #$01
                        STA             ASM_SCAN_LO
                        LDA             ASM_FIX_SITE_HI,X
                        ADC             #$00
                        STA             ASM_SCAN_HI
                        LDY             #$00
                        LDA             (ASM_SCAN_LO),Y
                        STA             ASM_WORD_LO
                        INY
                        LDA             (ASM_SCAN_LO),Y
                        STA             ASM_WORD_HI
                        RTS

ASM_PRINT_RESOLVED_FIXUPS:
                        STZ             ASM_KIND
                        LDX             #$00
ASM_PRINT_RESOLVED_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_PRINT_RESOLVED_DONE
                        STX             ASM_SLOT
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_RESOLVED
                        BNE             ASM_PRINT_RESOLVED_NEXT
                        LDA             ASM_KIND
                        BNE             ASM_PRINT_RESOLVED_HAVE_HEAD
                        LDX             #<MSG_RESOLVED_RF
                        LDY             #>MSG_RESOLVED_RF
                        JSR             ASM_PRINT_LINE
                        LDA             #$01
                        STA             ASM_KIND
ASM_PRINT_RESOLVED_HAVE_HEAD:
                        JSR             ASM_PRINT_RESOLVED_FIXUP_X
ASM_PRINT_RESOLVED_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_PRINT_RESOLVED_LOOP
ASM_PRINT_RESOLVED_DONE:
                        RTS

ASM_PRINT_RESOLVED_FIXUP_X:
                        JSR             ASM_PRINT_CRLF
                        JSR             ASM_PRINT_UNRESOLVED_NAME_FIELD
                        LDX             ASM_SLOT
                        JSR             ASM_COPY_FIXUP_HASH_X
                        LDX             ASM_SLOT
                        JSR             ASM_FIX_NAME_ADDR_X_TO_SCAN
                        LDX             #<MSG_UNRESOLVED_INDENT
                        LDY             #>MSG_UNRESOLVED_INDENT
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SCAN_LO
                        LDY             ASM_SCAN_HI
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_UNRESOLVED_SITE
                        LDY             #>MSG_UNRESOLVED_SITE
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_WORD_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_RESOLVED_TARGET
                        LDY             #>MSG_RESOLVED_TARGET
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SLOT
                        JSR             ASM_LOAD_FIXUP_TARGET_X
                        JSR             ASM_PRINT_WORD
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_UNRESOLVED_WIDTH
                        LDY             #>MSG_UNRESOLVED_WIDTH
                        JMP             ASM_PRINT_LINE

ASM_PRINT_UNRESOLVED_FIXUPS:
                        STZ             ASM_KIND
                        LDX             #$00
ASM_PRINT_UNRESOLVED_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_PRINT_UNRESOLVED_DONE
                        STX             ASM_SLOT
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_PRINT_UNRESOLVED_NEXT
                        LDA             ASM_KIND
                        BNE             ASM_PRINT_UNRESOLVED_HAVE_HEAD
                        LDX             #<MSG_UNRESOLVED_RF
                        LDY             #>MSG_UNRESOLVED_RF
                        JSR             ASM_PRINT_LINE
                        LDA             #$01
                        STA             ASM_KIND
ASM_PRINT_UNRESOLVED_HAVE_HEAD:
                        JSR             ASM_PRINT_UNRESOLVED_FIXUP_X
ASM_PRINT_UNRESOLVED_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_PRINT_UNRESOLVED_LOOP
ASM_PRINT_UNRESOLVED_DONE:
                        RTS

ASM_PRINT_UNRESOLVED_FIXUP_X:
                        JSR             ASM_PRINT_CRLF
                        JSR             ASM_PRINT_UNRESOLVED_NAME_FIELD
                        LDX             ASM_SLOT
                        JSR             ASM_COPY_FIXUP_HASH_X
                        LDX             ASM_SLOT
                        JSR             ASM_FIX_NAME_ADDR_X_TO_SCAN
                        LDX             #<MSG_UNRESOLVED_INDENT
                        LDY             #>MSG_UNRESOLVED_INDENT
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SCAN_LO
                        LDY             ASM_SCAN_HI
                        JSR             ASM_PRINT_HASH_CURRENT_OF_XY
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_UNRESOLVED_SITE
                        LDY             #>MSG_UNRESOLVED_SITE
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_WORD_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_WORD_HI
                        JSR             ASM_PRINT_WORD
                        JSR             ASM_PRINT_CRLF
                        LDX             #<MSG_UNRESOLVED_WIDTH
                        LDY             #>MSG_UNRESOLVED_WIDTH
                        JMP             ASM_PRINT_LINE

; ----------------------------------------------------------------------------
; Resident/local hash record join scanner. This bootstraps THE_JOIN_EXEC_XY from
; ROM FNV records, then calls the resident joiner for ordinary operands.
; ----------------------------------------------------------------------------
ASM_JOIN_EXEC_XY:
                        JSR             ASM_FIND_XY
                        BCC             ASM_JOIN_FAIL
ASM_JOIN_EXEC_KIND:
                        AND             #ASM_KIND_EXEC
                        BEQ             ASM_JOIN_FAIL
ASM_JOIN_OK:
                        LDX             ASM_JOIN_LO
                        LDY             ASM_JOIN_HI
                        SEC
                        RTS
ASM_JOIN_FAIL:
                        CLC
                        RTS

ASM_FIND_XY:
                        STX             ASM_HASH_PTR_LO
                        STY             ASM_HASH_PTR_HI
                        STZ             ASM_SCAN_LO
                        LDA             #ASM_SCAN_BASE_HI
                        STA             ASM_SCAN_HI
ASM_FIND_LOOP:
                        JSR             ASM_FIND_AT_END
                        BCS             ASM_FIND_FAIL
                        JSR             ASM_FIND_IS_RECORD
                        BCC             ASM_FIND_ADV
                        JSR             ASM_FIND_MATCH
                        BCS             ASM_FIND_FOUND
ASM_FIND_ADV:
                        INC             ASM_SCAN_LO
                        BNE             ASM_FIND_LOOP
                        INC             ASM_SCAN_HI
                        BRA             ASM_FIND_LOOP

ASM_FIND_FOUND:
                        LDY             #$07
                        LDA             (ASM_SCAN_LO),Y
                        CMP             #ASM_KIND_EXEC_CONFIRM_TEXT
                        BEQ             ASM_FIND_FOUND_PTR_CONFIRM
                        CMP             #ASM_KIND_EXEC_TEXT
                        BEQ             ASM_FIND_FOUND_PTR_TEXT
                        CLC
                        LDA             ASM_SCAN_LO
                        ADC             #$08
                        STA             ASM_JOIN_LO
                        LDA             ASM_SCAN_HI
                        ADC             #$00
                        STA             ASM_JOIN_HI
                        LDY             #$07
                        LDA             (ASM_SCAN_LO),Y
                        SEC
                        RTS
ASM_FIND_FOUND_PTR_CONFIRM:
                        LDA             #ASM_KIND_EXEC_CONFIRM_TEXT
                        BRA             ASM_FIND_FOUND_PTR
ASM_FIND_FOUND_PTR_TEXT:
                        LDA             #ASM_KIND_EXEC_TEXT
ASM_FIND_FOUND_PTR:
                        PHA
                        LDY             #$08
                        LDA             (ASM_SCAN_LO),Y
                        STA             ASM_JOIN_LO
                        INY
                        LDA             (ASM_SCAN_LO),Y
                        STA             ASM_JOIN_HI
                        PLA
                        SEC
                        RTS

ASM_FIND_FAIL:
                        CLC
                        RTS

ASM_FIND_AT_END:
                        LDA             ASM_SCAN_HI
                        CMP             #$FF
                        BNE             ASM_FIND_NOT_END
                        LDA             ASM_SCAN_LO
                        CMP             #$F8
                        BCS             ASM_FIND_END
ASM_FIND_NOT_END:
                        CLC
                        RTS
ASM_FIND_END:
                        SEC
                        RTS

ASM_FIND_IS_RECORD:
                        LDY             #$00
                        LDA             (ASM_SCAN_LO),Y
                        CMP             #'F'
                        BNE             ASM_FIND_NO
                        INY
                        LDA             (ASM_SCAN_LO),Y
                        CMP             #'N'
                        BNE             ASM_FIND_NO
                        INY
                        LDA             (ASM_SCAN_LO),Y
                        CMP             #ASM_HASH_SIG2
                        BNE             ASM_FIND_NO
                        SEC
                        RTS
ASM_FIND_NO:
                        CLC
                        RTS

ASM_FIND_MATCH:
                        LDY             #$03
                        LDA             (ASM_SCAN_LO),Y
                        LDY             #$00
                        CMP             (ASM_HASH_PTR_LO),Y
                        BNE             ASM_FIND_NO
                        LDY             #$04
                        LDA             (ASM_SCAN_LO),Y
                        LDY             #$01
                        CMP             (ASM_HASH_PTR_LO),Y
                        BNE             ASM_FIND_NO
                        LDY             #$05
                        LDA             (ASM_SCAN_LO),Y
                        LDY             #$02
                        CMP             (ASM_HASH_PTR_LO),Y
                        BNE             ASM_FIND_NO
                        LDY             #$06
                        LDA             (ASM_SCAN_LO),Y
                        LDY             #$03
                        CMP             (ASM_HASH_PTR_LO),Y
                        BNE             ASM_FIND_NO
                        SEC
                        RTS

ASM_RJOIN_RESIDENT_CURRENT:
                        LDX             #<ASM_HASH0
                        LDY             #>ASM_HASH0
ASM_RJOIN_RESIDENT_XY:
                        STX             ASM_HASH_PTR_LO
                        STY             ASM_HASH_PTR_HI
                        JSR             ASM_CALL_JOINER
                        BCC             ASM_RJOIN_RESIDENT_FAIL
                        STX             ASM_JOIN_LO
                        STY             ASM_JOIN_HI
                        SEC
                        RTS
ASM_RJOIN_RESIDENT_FAIL:
                        CLC
                        RTS

ASM_CALL_JOINER:
                        JMP             (ASM_JOINER_LO)

ASM_BIO_WRITE_BYTE_BLOCK:
                        JMP             (ASM_IMP_WRITE_LO)

ASM_BIO_READ_BYTE_BLOCK:
                        JMP             (ASM_IMP_READ_LO)

; ----------------------------------------------------------------------------
; Runtime FNV-1a hashing for proof input names.
; ----------------------------------------------------------------------------
ASM_HASH_CSTRING_XY:
                        STX             ASM_STR_LO
                        STY             ASM_STR_HI
                        JSR             ASM_FNV1A_INIT
ASM_HASH_CSTRING_LOOP:
                        LDY             #$00
                        LDA             (ASM_STR_LO),Y
                        BEQ             ASM_HASH_CSTRING_DONE
                        AND             #$7F
                        JSR             ASM_FNV1A_UPDATE_A_FAST
                        INC             ASM_STR_LO
                        BNE             ASM_HASH_CSTRING_LOOP
                        INC             ASM_STR_HI
                        BRA             ASM_HASH_CSTRING_LOOP
ASM_HASH_CSTRING_DONE:
                        RTS

ASM_FNV1A_INIT:
                        LDX             #$03
ASM_FNV1A_INIT_LOOP:
                        LDA             ASM_FNV1A_OFFSET_BASIS,X
                        STA             ASM_HASH0,X
                        DEX
                        BPL             ASM_FNV1A_INIT_LOOP
                        RTS

ASM_FNV1A_UPDATE_A_FAST:
                        EOR             ASM_HASH0
                        STA             ASM_HASH0
                        JMP             ASM_FNV1A_MUL_PRIME_FAST

ASM_FNV1A_MUL_PRIME_FAST:
                        JSR             ASM_MATH_COPY_HASH_TO_TERM

                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        JSR             ASM_MATH_ADD_TERM_TO_HASH

                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        JSR             ASM_MATH_ADD_TERM_TO_HASH

                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        JSR             ASM_MATH_ADD_TERM_TO_HASH

                        ASL             ASM_TERM0
                        ROL             ASM_TERM1
                        ROL             ASM_TERM2
                        ROL             ASM_TERM3
                        JSR             ASM_MATH_ADD_TERM_TO_HASH
                        JMP             ASM_MATH_ADD_TERM1_TO_HASH3

ASM_MATH_COPY_HASH_TO_TERM:
                        LDX             #$03
ASM_MATH_COPY_HASH_LOOP:
                        LDA             ASM_HASH0,X
                        STA             ASM_TERM0,X
                        DEX
                        BPL             ASM_MATH_COPY_HASH_LOOP
                        RTS

ASM_MATH_ADD_TERM_TO_HASH:
                        CLC
                        LDA             ASM_HASH0
                        ADC             ASM_TERM0
                        STA             ASM_HASH0
                        LDA             ASM_HASH1
                        ADC             ASM_TERM1
                        STA             ASM_HASH1
                        LDA             ASM_HASH2
                        ADC             ASM_TERM2
                        STA             ASM_HASH2
                        LDA             ASM_HASH3
                        ADC             ASM_TERM3
                        STA             ASM_HASH3
                        RTS

ASM_MATH_ADD_TERM1_TO_HASH3:
                        LDA             ASM_HASH3
                        CLC
                        ADC             ASM_TERM1
                        STA             ASM_HASH3
                        RTS

ASM_FNV1A_OFFSET_BASIS:
                        DB              $C5,$9D,$1C,$81

; ----------------------------------------------------------------------------
; Output helpers.
; ----------------------------------------------------------------------------
ASM_PRINT_HASH_CURRENT:
                        LDX             #<ASM_HASH0
                        STX             ASM_HASH_PTR_LO
                        LDY             #>ASM_HASH0
                        STY             ASM_HASH_PTR_HI
ASM_PRINT_HASH_FIELD:
                        LDX             #<MSG_HASH_FIELD
                        LDY             #>MSG_HASH_FIELD
                        JSR             ASM_WRITE_CSTRING
                        BRA             ASM_PRINT_HASH_BYTES

ASM_PRINT_HASH_CURRENT_OF_XY:
                        STX             ASM_WORD_LO
                        STY             ASM_WORD_HI
                        LDX             #<ASM_HASH0
                        STX             ASM_HASH_PTR_LO
                        LDY             #>ASM_HASH0
                        STY             ASM_HASH_PTR_HI
                        LDX             #<MSG_HASH_OF_OPEN
                        LDY             #>MSG_HASH_OF_OPEN
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_WORD_LO
                        LDY             ASM_WORD_HI
                        JSR             ASM_WRITE_CSTRING
                        LDX             #<MSG_HASH_OF_CLOSE
                        LDY             #>MSG_HASH_OF_CLOSE
                        JSR             ASM_WRITE_CSTRING

ASM_PRINT_HASH_BYTES:
                        LDA             #'$'
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDY             #$03
                        LDA             (ASM_HASH_PTR_LO),Y
                        JSR             ASM_WRITE_HEX_BYTE
                        LDY             #$02
                        LDA             (ASM_HASH_PTR_LO),Y
                        JSR             ASM_WRITE_HEX_BYTE
                        LDY             #$01
                        LDA             (ASM_HASH_PTR_LO),Y
                        JSR             ASM_WRITE_HEX_BYTE
                        LDY             #$00
                        LDA             (ASM_HASH_PTR_LO),Y
                        JMP             ASM_WRITE_HEX_BYTE

ASM_PRINT_ENTRY_FIELD:
                        LDX             #<MSG_ENTRY_FIELD
                        LDY             #>MSG_ENTRY_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDA             ASM_JOIN_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_JOIN_HI
                        STA             ASM_WORD_HI
                        JMP             ASM_PRINT_WORD

ASM_PRINT_PC_FIELD:
                        LDX             #<MSG_PC_FIELD
                        LDY             #>MSG_PC_FIELD
                        JSR             ASM_WRITE_CSTRING
ASM_PRINT_PC_ADDR:
                        LDA             ASM_PC_LO
                        STA             ASM_WORD_LO
                        LDA             ASM_PC_HI
                        STA             ASM_WORD_HI
                        JMP             ASM_PRINT_WORD

ASM_PRINT_WORD:
                        LDA             #'$'
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             ASM_WORD_HI
                        JSR             ASM_WRITE_HEX_BYTE
                        LDA             ASM_WORD_LO
                        JMP             ASM_WRITE_HEX_BYTE

ASM_WRITE_HEX_BYTE:
                        PHA
                        LSR
                        LSR
                        LSR
                        LSR
                        JSR             ASM_WRITE_HEX_NIBBLE
                        PLA
                        AND             #$0F
                        JMP             ASM_WRITE_HEX_NIBBLE

ASM_WRITE_HEX_NIBBLE:
                        AND             #$0F
                        CMP             #$0A
                        BCC             ASM_WRITE_HEX_DIGIT
                        CLC
                        ADC             #$37
                        JMP             ASM_BIO_WRITE_BYTE_BLOCK
ASM_WRITE_HEX_DIGIT:
                        CLC
                        ADC             #'0'
                        JMP             ASM_BIO_WRITE_BYTE_BLOCK

ASM_PRINT_CRLF:
                        LDA             #$0D
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        LDA             #$0A
                        JMP             ASM_BIO_WRITE_BYTE_BLOCK

ASM_PRINT_LINE:
                        JSR             ASM_WRITE_CSTRING
                        JMP             ASM_PRINT_CRLF

ASM_WRITE_CSTRING:
                        STX             ASM_STR_LO
                        STY             ASM_STR_HI
ASM_WRITE_CSTRING_LOOP:
                        LDY             #$00
                        LDA             (ASM_STR_LO),Y
                        BEQ             ASM_WRITE_CSTRING_DONE
                        JSR             ASM_BIO_WRITE_BYTE_BLOCK
                        INC             ASM_STR_LO
                        BNE             ASM_WRITE_CSTRING_LOOP
                        INC             ASM_STR_HI
                        BRA             ASM_WRITE_CSTRING_LOOP
ASM_WRITE_CSTRING_DONE:
                        RTS

ASM_PRINT_NAME_FIELD:
                        LDX             #<MSG_NAME_FIELD
                        LDY             #>MSG_NAME_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_NAME_LO
                        LDY             ASM_NAME_HI
                        JMP             ASM_PRINT_LINE

ASM_PRINT_FIXUP_NAME_FIELD:
                        LDX             ASM_SLOT
                        JSR             ASM_FIX_NAME_ADDR_X_TO_SCAN
                        LDX             #<MSG_NAME_FIELD
                        LDY             #>MSG_NAME_FIELD
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SCAN_LO
                        LDY             ASM_SCAN_HI
                        JMP             ASM_PRINT_LINE

ASM_PRINT_UNRESOLVED_NAME_FIELD:
                        LDX             ASM_SLOT
                        JSR             ASM_FIX_NAME_ADDR_X_TO_SCAN
                        LDX             #<MSG_UNRESOLVED_NAME
                        LDY             #>MSG_UNRESOLVED_NAME
                        JSR             ASM_WRITE_CSTRING
                        LDX             ASM_SCAN_LO
                        LDY             ASM_SCAN_HI
                        JMP             ASM_PRINT_LINE

                        DATA
HASH_THE_JOIN_EXEC_XY:
                        DB              $F7,$15,$AF,$A9
HASH_BIO_WRITE_BYTE_BLOCK:
                        DB              $30,$E9,$9F,$37
HASH_BIO_READ_BYTE_BLOCK:
                        DB              $85,$5B,$28,$20

ASM_SYM_COUNT:         DB              $00
ASM_SYM_HASH0:         DS              ASM_SYM_MAX
ASM_SYM_HASH1:         DS              ASM_SYM_MAX
ASM_SYM_HASH2:         DS              ASM_SYM_MAX
ASM_SYM_HASH3:         DS              ASM_SYM_MAX
ASM_SYM_VAL_LO:        DS              ASM_SYM_MAX
ASM_SYM_VAL_HI:        DS              ASM_SYM_MAX
ASM_SYM_KIND:          DS              ASM_SYM_MAX

ASM_NONEXEC_HASH:
                        DB              $00,$00,$00,$00
ASM_NONEXEC_VAL_LO:    DB              $00
ASM_NONEXEC_VAL_HI:    DB              $00
ASM_NONEXEC_KIND:      DB              $00
ASM_NONEXEC_DATA:      DB              $00

ASM_FIX_COUNT:         DB              $00
ASM_FIX_HASH0:         DS              ASM_FIX_MAX
ASM_FIX_HASH1:         DS              ASM_FIX_MAX
ASM_FIX_HASH2:         DS              ASM_FIX_MAX
ASM_FIX_HASH3:         DS              ASM_FIX_MAX
ASM_FIX_SITE_LO:       DS              ASM_FIX_MAX
ASM_FIX_SITE_HI:       DS              ASM_FIX_MAX
ASM_FIX_STATE:         DS              ASM_FIX_MAX
ASM_FIX_NAME_TEXT:     DS              ASM_FIX_NAME_BYTES

ASM_LINE_BUF:          DS              $40

STR_LABEL_START:       DB              "START",0
STR_LATER_LABEL:       DB              "LATER_LABEL",0
STR_BIO_WRITE:         DB              "BIO_FTDI_WRITE_BYTE_BLOCK",0
STR_NO_SUCH_LABEL:     DB              "NO_SUCH_LABEL",0
STR_NON_EXEC_RECORD:   DB              "NON_EXEC_RECORD",0

MSG_TITLE:             DB              "ASM RJOIN PROOF $3000",0
MSG_NOTE:              DB              "A=MINI ASM; ASM=HASH/RJOIN PROOF",0
MSG_PC_START:          DB              "PC=",0
MSG_LINE_POS:          DB              $0D,$0A,"-- SOURCE: START: JSR BIO_FTDI_WRITE_BYTE_BLOCK",0
MSG_LABEL_START:       DB              "  LABEL   START",$0D,$0A,"    ",0
MSG_STORE_LOCAL:       DB              " STORE=LOCAL SYMBOL",0
MSG_OP_JSR:            DB              "  OP      JSR",$0D,$0A,"    MODE=ABS OPCODE=$20",0
MSG_OPERAND_BIO:       DB              "  OPERAND BIO_FTDI_WRITE_BYTE_BLOCK",$0D,$0A,"    ",0
MSG_OPERAND_LATER:     DB              "  OPERAND LATER_LABEL",$0D,$0A,"    ",0
MSG_OPERAND_MISSING:   DB              "  OPERAND NO_SUCH_LABEL",$0D,$0A,"    ",0
MSG_OPERAND_NONEXEC:   DB              "  OPERAND NON_EXEC_RECORD",$0D,$0A,"    ",0
MSG_LINE_MISSING:      DB              $0D,$0A,"-- SOURCE: JSR NO_SUCH_LABEL",0
MSG_LINE_NONEXEC:      DB              $0D,$0A,"-- SOURCE: JSR NON_EXEC_RECORD",0
MSG_LINE_FWD:          DB              $0D,$0A,"-- SOURCE: JSR LATER_LABEL",0
MSG_LINE_FWD_DEF:      DB              $0D,$0A,"-- SOURCE: LATER_LABEL: JSR BIO_FTDI_WRITE_BYTE_BLOCK",0
MSG_LABEL_LATER:       DB              "  LABEL   LATER_LABEL",$0D,$0A,"    ",0
MSG_LABEL_PREFIX:      DB              "  LABEL   ",0
MSG_OPERAND_PREFIX:    DB              "  OPERAND ",0
MSG_FIELD_INDENT:      DB              "    ",0
MSG_HASH_FIELD:        DB              "H=",0
MSG_HASH_OF_OPEN:      DB              "H(",0
MSG_HASH_OF_CLOSE:     DB              ")=",0
MSG_VALUE_FIELD:       DB              $0D,$0A,"    V=",0
MSG_ENTRY_FIELD:       DB              $0D,$0A,"    E=",0
MSG_PC_FIELD:          DB              $0D,$0A,"    PC=",0
MSG_KIND_FIELD:        DB              " K=$",0
MSG_KIND_EXEC:         DB              " EXEC",0
MSG_KIND_NOT_EXEC:     DB              " NOTEXEC",0
MSG_TARGET_FIELD:      DB              $0D,$0A,"    T=",0
MSG_NAME_FIELD:        DB              "    NAME=",0
MSG_SITE_FIELD:        DB              "    SITE=",0
MSG_RESOLVED_RF:       DB              $0D,$0A,"RESOLVED RF",0
MSG_RESOLVED_TARGET:   DB              "  T=",0
MSG_UNRESOLVED_RF:     DB              $0D,$0A,"UNRESOLVED RF",0
MSG_UNRESOLVED_INDENT: DB              "  ",0
MSG_UNRESOLVED_NAME:   DB              "  NAME=",0
MSG_UNRESOLVED_SITE:   DB              "  SITE=",0
MSG_UNRESOLVED_WIDTH:  DB              "  WIDTH=ABS16",0
MSG_LOCAL_NO:          DB              $0D,$0A,"    LOCAL=NO",0
MSG_LOCAL_FOUND:       DB              $0D,$0A,"    LOCAL=FOUND",0
MSG_RJOIN_FOUND:       DB              " RJOIN=FOUND K=$01 EXEC",0
MSG_RJOIN_NO:          DB              " RJOIN=NO",0
MSG_RF_PENDING:        DB              " RF=PENDING",$0D,$0A,0
MSG_RF_RESOLVE:        DB              "  RF      RESOLVE",0
MSG_PATCH_OK:          DB              " PATCH=OK",0
MSG_ERROR_UNRESOLVED:  DB              $0D,$0A,"    ERROR=UNRESOLVED",0
MSG_ERROR_NOT_EXEC:    DB              $0D,$0A,"    ERROR=NOT EXEC",0
MSG_EMIT_NO:           DB              $0D,$0A,"    EMIT=NO",0
MSG_EMIT_PENDING:      DB              "  EMIT   PENDING",0
MSG_EMIT:              DB              "  EMIT",$0D,$0A,"    SITE=",0
MSG_COLON_SPACE:       DB              " BYTES=",0
MSG_HARNESS_RTS:       DB              "  HARNESS",$0D,$0A,"    RTS=",0
MSG_RUN:               DB              "  RUN",$0D,$0A,"    SEND=",0
MSG_RUN_OK:            DB              "    OK",0
MSG_INPUT_HELP:        DB              $0D,$0A,"-- INTERACTIVE --",$0D,$0A,"ENTER [LABEL[:]] JSR OPERAND; CTRL-C EXIT",0
MSG_INPUT_PC:          DB              "PC=",0
MSG_INPUT_PROMPT:      DB              " ASM> ",0
MSG_CTRL_C_EXIT:       DB              "CTRL-C EXIT",0
MSG_LINE_TOO_LONG:     DB              "  LINE TOO LONG",0
MSG_LABEL_ONLY:        DB              "  LABEL ONLY",0
MSG_PARSE_BAD_OP:      DB              "  PARSE  BAD OP; ONLY JSR",0
MSG_PARSE_MISSING_OPERAND:
                        DB              "  PARSE  MISSING OPERAND",0
MSG_OK:                DB              " OK",0
MSG_DONE:              DB              "DONE",0
MSG_LOCAL_UNEXPECTED:  DB              "BAD: LOCAL HIT DURING RESIDENT TEST",0
MSG_LOCAL_MISSING_BAD: DB              "BAD: NON_EXEC_RECORD MISSING",0
MSG_RJOIN_UNEXPECTED:  DB              "BAD: RJOIN FOUND MISSING SYMBOL",0
MSG_EXEC_UNEXPECTED:   DB              "BAD: NON_EXEC_RECORD IS EXEC",0
MSG_FWD_BAD_EARLY:     DB              "BAD: FORWARD LABEL ALREADY RESOLVED",0
MSG_FIXUP_FULL:        DB              "BAD: FIXUP TABLE FULL",0
MSG_SYMBOL_FULL:       DB              "BAD: SYMBOL TABLE FULL",0

ASM_CODE_BUF:          DS              $0200

                        END

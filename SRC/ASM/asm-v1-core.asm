; ----------------------------------------------------------------------------
; asm-v1-core.asm
; First real ASM v1 code foothold.
;
; This is not HIMON's legacy A mini-assembler. This module starts the new
; hash-based ASM proper with small callable routines that match the ASM 1.xx
; contracts: session begin/end and line preparation.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_CORE

                        XDEF            START
                        XDEF            ASM_BEGIN
                        XDEF            ASM_END
                        XDEF            ASM_LEX_LINE
                        XDEF            ASM_NEXT_TOKEN
                        XDEF            ASM_LOOKUP_WORD
                        XDEF            ASM_PARSE_HEAD
                        XDEF            ASM_DISPATCH_STATEMENT
                        XDEF            ASM_LOOKUP_SYMBOL
                        XDEF            ASM_BIND_LABEL
                        XDEF            ASM_DEFINE_EQU

; ----------------------------------------------------------------------------
; ASM active zero-page frame, allocated downward from $AF.
; Keep in sync with DOC/GUIDES/ASM/HASHED_ASM.md.
; ----------------------------------------------------------------------------
ASM_LINE_PTR_LO        EQU             $AE
ASM_LINE_PTR_HI        EQU             $AF
ASM_PARSE_PTR_LO       EQU             $AC
ASM_PARSE_PTR_HI       EQU             $AD
ASM_TOKEN_PTR_LO       EQU             $AA
ASM_TOKEN_PTR_HI       EQU             $AB
ASM_SCAN_PTR_LO        EQU             $A8
ASM_SCAN_PTR_HI        EQU             $A9
ASM_EMIT_PTR_LO        EQU             $A6
ASM_EMIT_PTR_HI        EQU             $A7
ASM_NAME_PTR_LO        EQU             $A4
ASM_NAME_PTR_HI        EQU             $A5
ASM_HASH0              EQU             $A0
ASM_HASH1              EQU             $A1
ASM_HASH2              EQU             $A2
ASM_HASH3              EQU             $A3
ASM_HASH_TMP0          EQU             $9C
ASM_HASH_TMP1          EQU             $9D
ASM_HASH_TMP2          EQU             $9E
ASM_HASH_TMP3          EQU             $9F
ASM_VALUE_LO           EQU             $9A
ASM_VALUE_HI           EQU             $9B
ASM_CARE_LO            EQU             $98
ASM_CARE_HI            EQU             $99
ASM_BASE_LO            EQU             $96
ASM_BASE_HI            EQU             $97
ASM_MODE               EQU             $95
ASM_WIDTH              EQU             $94
ASM_FLAGS              EQU             $93
ASM_STATUS             EQU             $92
ASM_SLOT               EQU             $91
ASM_LEN                EQU             $90
ASM_DELIM              EQU             $8F
ASM_BIT                EQU             $8E
ASM_TMP0_LO            EQU             $8C
ASM_TMP0_HI            EQU             $8D
ASM_TMP1_LO            EQU             $8A
ASM_TMP1_HI            EQU             $8B
ASM_REF_PTR_LO         EQU             $88
ASM_REF_PTR_HI         EQU             $89
ASM_FIX_PTR_LO         EQU             $86
ASM_FIX_PTR_HI         EQU             $87
ASM_SYM_PTR_LO         EQU             $84
ASM_SYM_PTR_HI         EQU             $85

ASM_RJ_JOINER_LO      EQU             ASM_SYM_PTR_LO
ASM_RJ_JOINER_HI      EQU             ASM_SYM_PTR_HI
ASM_RJ_JOIN_LO        EQU             ASM_FIX_PTR_LO
ASM_RJ_JOIN_HI        EQU             ASM_FIX_PTR_HI
ASM_RJ_HASH_PTR_LO    EQU             ASM_REF_PTR_LO
ASM_RJ_HASH_PTR_HI    EQU             ASM_REF_PTR_HI
ASM_RJ_WRITE_LO       EQU             ASM_TMP1_LO
ASM_RJ_WRITE_HI       EQU             ASM_TMP1_HI
ASM_RJ_STR_LO         EQU             ASM_TMP0_LO
ASM_RJ_STR_HI         EQU             ASM_TMP0_HI
ASM_RJ_SCAN_LO        EQU             ASM_SCAN_PTR_LO
ASM_RJ_SCAN_HI        EQU             ASM_SCAN_PTR_HI

ASM_TOK_KIND          EQU             ASM_MODE
ASM_TOK_SUB           EQU             ASM_WIDTH
ASM_TOK_FLAGS         EQU             ASM_FLAGS
ASM_VOC_ID            EQU             ASM_VALUE_LO
ASM_VOC_DISP          EQU             ASM_VALUE_HI
ASM_VOC_FLAGS         EQU             ASM_CARE_LO
ASM_VOC_AUX           EQU             ASM_CARE_HI

; ----------------------------------------------------------------------------
; Status, session, and v1 proof limits.
; ----------------------------------------------------------------------------
ASM_STATUS_OK          EQU             $00
ASM_STATUS_BAD_MNEM    EQU             $01
ASM_STATUS_BAD_DIR     EQU             $02
ASM_STATUS_BAD_OPER    EQU             $03
ASM_STATUS_BAD_MODE    EQU             $04
ASM_STATUS_BAD_WIDTH   EQU             $05
ASM_STATUS_BAD_RANGE   EQU             $06
ASM_STATUS_BAD_LINE    EQU             $07
ASM_STATUS_BAD_SYM     EQU             $08
ASM_STATUS_BAD_FIX     EQU             $09
ASM_STATUS_LOCAL_NYI   EQU             $0A

ASM_BEGINF_HAVE_PC     EQU             $01

ASM_SESS_IDLE          EQU             $00
ASM_SESS_ACTIVE        EQU             $01
ASM_SESS_ENDED         EQU             $02
ASM_SESS_FAILED        EQU             $03

ASM_TOK_EOL           EQU             $00
ASM_TOK_WORD          EQU             $01
ASM_TOK_NUMBER        EQU             $02
ASM_TOK_CHAR          EQU             $03
ASM_TOK_PUNCT         EQU             $04

ASM_TSUB_NONE         EQU             $00
ASM_TSUB_DEC          EQU             $01
ASM_TSUB_HEX          EQU             $02
ASM_TSUB_BIN          EQU             $03
ASM_TSUB_MASK         EQU             $04

ASM_TF_HAS_COLON      EQU             $01
ASM_TF_HAS_XMASK      EQU             $02
ASM_TF_QUOTED         EQU             $04
ASM_TF_LOCAL_PREFIX   EQU             $08
ASM_TF_ERROR          EQU             $80

ASM_VOC_NONE          EQU             $00
ASM_VOC_MNEM          EQU             $01
ASM_VOC_DIR           EQU             $02
ASM_VOC_REG           EQU             $03
ASM_VOC_RESERVED      EQU             $04
ASM_VOC_ALIAS         EQU             $05

ASM_STMT_EMPTY        EQU             $00
ASM_STMT_LABEL_ONLY   EQU             $01
ASM_STMT_MNEM         EQU             $02
ASM_STMT_DIR          EQU             $03
ASM_STMT_ERROR        EQU             $04

ASM_STMTF_HAS_NAME    EQU             $01
ASM_STMTF_HAS_COLON   EQU             $02
ASM_STMTF_HAS_TAIL    EQU             $04
ASM_STMTF_BINDS_PC    EQU             $08
ASM_STMTF_BINDS_EQU   EQU             $10
ASM_STMTF_CONTROL     EQU             $20

ASM_SYM_LOOK_SESSION   EQU             $01
ASM_SYM_LOOK_MARK_USE  EQU             $04

ASM_SYM_STATE_EMPTY    EQU             $00
ASM_SYM_STATE_DEFINED  EQU             $01

ASM_SYMF_USED          EQU             $01
ASM_SYMF_HAS_TEXT      EQU             $02
ASM_SYMF_HAS_CARE      EQU             $04
ASM_SYMF_FROM_LABEL    EQU             $08
ASM_SYMF_FROM_EQU      EQU             $10

ASM_SYMK_VALUE         EQU             $00
ASM_SYMK_ADDR          EQU             $01
ASM_SYMK_MASK          EQU             $02

ASM_WIDTH_NONE         EQU             $00
ASM_WIDTH_BYTE         EQU             $01
ASM_WIDTH_WORD         EQU             $02
ASM_WIDTH_ZP           EQU             $03
ASM_WIDTH_ABS          EQU             $04
ASM_WIDTH_MASK8        EQU             $05
ASM_WIDTH_MASK16       EQU             $06

ASM_RJ_HASH_SIG2       EQU             ('V'+$80)
ASM_RJ_KIND_EXEC       EQU             $01
ASM_RJ_KIND_EXEC_TEXT  EQU             $05
ASM_RJ_KIND_EXEC_CONFIRM_TEXT EQU       $07
ASM_RJ_SCAN_BASE_HI    EQU             $80

ASM_LINE_MAX           EQU             $3F
ASM_SYM_MAX            EQU             $10
ASM_SYM_NAME_MAX       EQU             $20
ASM_FIX_MAX            EQU             $08
ASM_REF_MAX            EQU             $10
ASM_VOC_COUNT          EQU             $51

ASM_VID_DC             EQU             $18
ASM_VID_DS             EQU             $1C
ASM_VID_END            EQU             $1D
ASM_VID_EQU            EQU             $20
ASM_VID_ORG            EQU             $2D

                        CODE

; ----------------------------------------------------------------------------
; START
; Tiny smoke entry for the standalone S19 target.
; OUT: C=1 if ASM_BEGIN, lexer self-checks, one too-long-line rejection, and
;      ASM_END behaved as expected.
; ----------------------------------------------------------------------------
START:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             START_FAIL

                        LDX             #<ASM_SMOKE_LINE_OK
                        LDY             #>ASM_SMOKE_LINE_OK
                        JSR             ASM_LEX_LINE
                        BCC             START_FAIL
                        JSR             ASM_SMOKE_TOKENS
                        BCC             START_FAIL
                        JSR             ASM_SMOKE_VOCAB
                        BCC             START_FAIL
                        JSR             ASM_SMOKE_PARSE
                        BCC             START_FAIL
                        JSR             ASM_SMOKE_SYMBOLS
                        BCC             START_FAIL
                        JSR             ASM_RJOIN_INIT
                        BCC             START_FAIL
                        JSR             ASM_SMOKE_PRINT_PASS

                        LDX             #<ASM_SMOKE_LINE_LONG
                        LDY             #>ASM_SMOKE_LINE_LONG
                        JSR             ASM_LEX_LINE
                        BCS             START_FAIL
                        CMP             #ASM_STATUS_BAD_LINE
                        BNE             START_FAIL

                        JSR             ASM_END
                        BCC             START_FAIL
                        RTS
START_FAIL:
                        CLC
                        RTS

ASM_SMOKE_PRINT_PASS:
                        LDX             #<ASM_SMOKE_MSG_PASS
                        LDY             #>ASM_SMOKE_MSG_PASS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_RJ_WRITE_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_RJ_WRITE_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SMOKE_MSG_SYM
                        LDY             #>ASM_SMOKE_MSG_SYM
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SYM_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SMOKE_MSG_PC
                        LDY             #>ASM_SMOKE_MSG_PC
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_RJOIN_INIT:
                        LDX             #<ASM_HASH_THE_JOIN_EXEC_XY
                        LDY             #>ASM_HASH_THE_JOIN_EXEC_XY
                        JSR             ASM_RJ_JOIN_EXEC_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_JOINER_LO
                        STY             ASM_RJ_JOINER_HI

                        LDX             #<ASM_HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>ASM_HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_WRITE_LO
                        STY             ASM_RJ_WRITE_HI
                        SEC
                        RTS
ASM_RJOIN_INIT_FAIL:
                        CLC
                        RTS

ASM_RJ_JOIN_EXEC_XY:
                        JSR             ASM_RJ_FIND_XY
                        BCC             ASM_RJ_JOIN_FAIL
                        AND             #ASM_RJ_KIND_EXEC
                        BEQ             ASM_RJ_JOIN_FAIL
                        LDX             ASM_RJ_JOIN_LO
                        LDY             ASM_RJ_JOIN_HI
                        SEC
                        RTS
ASM_RJ_JOIN_FAIL:
                        CLC
                        RTS

ASM_RJ_RESIDENT_XY:
                        STX             ASM_RJ_HASH_PTR_LO
                        STY             ASM_RJ_HASH_PTR_HI
                        JSR             ASM_RJ_CALL_JOINER
                        BCC             ASM_RJ_RESIDENT_FAIL
                        STX             ASM_RJ_JOIN_LO
                        STY             ASM_RJ_JOIN_HI
                        SEC
                        RTS
ASM_RJ_RESIDENT_FAIL:
                        CLC
                        RTS

ASM_RJ_CALL_JOINER:
                        JMP             (ASM_RJ_JOINER_LO)

ASM_RJ_WRITE_BYTE:
                        JMP             (ASM_RJ_WRITE_LO)

ASM_RJ_WRITE_CSTRING:
                        STX             ASM_RJ_STR_LO
                        STY             ASM_RJ_STR_HI
ASM_RJ_WRITE_CSTRING_LOOP:
                        LDY             #$00
                        LDA             (ASM_RJ_STR_LO),Y
                        BEQ             ASM_RJ_WRITE_CSTRING_DONE
                        JSR             ASM_RJ_WRITE_BYTE
                        INC             ASM_RJ_STR_LO
                        BNE             ASM_RJ_WRITE_CSTRING_LOOP
                        INC             ASM_RJ_STR_HI
                        BRA             ASM_RJ_WRITE_CSTRING_LOOP
ASM_RJ_WRITE_CSTRING_DONE:
                        RTS

ASM_RJ_WRITE_HEX_BYTE:
                        PHA
                        LSR
                        LSR
                        LSR
                        LSR
                        JSR             ASM_RJ_WRITE_HEX_NIBBLE
                        PLA
                        AND             #$0F
                        JMP             ASM_RJ_WRITE_HEX_NIBBLE

ASM_RJ_WRITE_HEX_NIBBLE:
                        AND             #$0F
                        CMP             #$0A
                        BCC             ASM_RJ_WRITE_HEX_DIGIT
                        CLC
                        ADC             #$37
                        JMP             ASM_RJ_WRITE_BYTE
ASM_RJ_WRITE_HEX_DIGIT:
                        CLC
                        ADC             #'0'
                        JMP             ASM_RJ_WRITE_BYTE

ASM_RJ_PRINT_CRLF:
                        LDA             #$0D
                        JSR             ASM_RJ_WRITE_BYTE
                        LDA             #$0A
                        JMP             ASM_RJ_WRITE_BYTE

ASM_RJ_FIND_XY:
                        STX             ASM_RJ_HASH_PTR_LO
                        STY             ASM_RJ_HASH_PTR_HI
                        STZ             ASM_RJ_SCAN_LO
                        LDA             #ASM_RJ_SCAN_BASE_HI
                        STA             ASM_RJ_SCAN_HI
ASM_RJ_FIND_LOOP:
                        JSR             ASM_RJ_FIND_AT_END
                        BCS             ASM_RJ_FIND_FAIL
                        JSR             ASM_RJ_FIND_IS_RECORD
                        BCC             ASM_RJ_FIND_ADV
                        JSR             ASM_RJ_FIND_MATCH
                        BCS             ASM_RJ_FIND_FOUND
ASM_RJ_FIND_ADV:
                        INC             ASM_RJ_SCAN_LO
                        BNE             ASM_RJ_FIND_LOOP
                        INC             ASM_RJ_SCAN_HI
                        BRA             ASM_RJ_FIND_LOOP

ASM_RJ_FIND_FOUND:
                        LDY             #$07
                        LDA             (ASM_RJ_SCAN_LO),Y
                        CMP             #ASM_RJ_KIND_EXEC_TEXT
                        BEQ             ASM_RJ_FIND_FOUND_PTR
                        CMP             #ASM_RJ_KIND_EXEC_CONFIRM_TEXT
                        BEQ             ASM_RJ_FIND_FOUND_PTR
                        CLC
                        LDA             ASM_RJ_SCAN_LO
                        ADC             #$08
                        STA             ASM_RJ_JOIN_LO
                        LDA             ASM_RJ_SCAN_HI
                        ADC             #$00
                        STA             ASM_RJ_JOIN_HI
                        LDY             #$07
                        LDA             (ASM_RJ_SCAN_LO),Y
                        SEC
                        RTS
ASM_RJ_FIND_FOUND_PTR:
                        LDY             #$08
                        LDA             (ASM_RJ_SCAN_LO),Y
                        STA             ASM_RJ_JOIN_LO
                        INY
                        LDA             (ASM_RJ_SCAN_LO),Y
                        STA             ASM_RJ_JOIN_HI
                        LDY             #$07
                        LDA             (ASM_RJ_SCAN_LO),Y
                        SEC
                        RTS

ASM_RJ_FIND_FAIL:
                        CLC
                        RTS

ASM_RJ_FIND_AT_END:
                        LDA             ASM_RJ_SCAN_HI
                        CMP             #$FF
                        BNE             ASM_RJ_FIND_NOT_END
                        LDA             ASM_RJ_SCAN_LO
                        CMP             #$F8
                        BCS             ASM_RJ_FIND_END
ASM_RJ_FIND_NOT_END:
                        CLC
                        RTS
ASM_RJ_FIND_END:
                        SEC
                        RTS

ASM_RJ_FIND_IS_RECORD:
                        LDY             #$00
                        LDA             (ASM_RJ_SCAN_LO),Y
                        CMP             #'F'
                        BNE             ASM_RJ_FIND_NO
                        INY
                        LDA             (ASM_RJ_SCAN_LO),Y
                        CMP             #'N'
                        BNE             ASM_RJ_FIND_NO
                        INY
                        LDA             (ASM_RJ_SCAN_LO),Y
                        CMP             #ASM_RJ_HASH_SIG2
                        BNE             ASM_RJ_FIND_NO
                        SEC
                        RTS
ASM_RJ_FIND_NO:
                        CLC
                        RTS

ASM_RJ_FIND_MATCH:
                        LDY             #$03
                        LDA             (ASM_RJ_SCAN_LO),Y
                        LDY             #$00
                        CMP             (ASM_RJ_HASH_PTR_LO),Y
                        BNE             ASM_RJ_FIND_NO
                        LDY             #$04
                        LDA             (ASM_RJ_SCAN_LO),Y
                        LDY             #$01
                        CMP             (ASM_RJ_HASH_PTR_LO),Y
                        BNE             ASM_RJ_FIND_NO
                        LDY             #$05
                        LDA             (ASM_RJ_SCAN_LO),Y
                        LDY             #$02
                        CMP             (ASM_RJ_HASH_PTR_LO),Y
                        BNE             ASM_RJ_FIND_NO
                        LDY             #$06
                        LDA             (ASM_RJ_SCAN_LO),Y
                        LDY             #$03
                        CMP             (ASM_RJ_HASH_PTR_LO),Y
                        BNE             ASM_RJ_FIND_NO
                        SEC
                        RTS

ASM_SMOKE_FAIL_A:
                        JMP             ASM_SMOKE_FAIL

ASM_SMOKE_TOKENS:
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL_A
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_LEN
                        CMP             #$03
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_HASH0
                        CMP             #$79
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_HASH1
                        CMP             #$07
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_HASH2
                        CMP             #$F8
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_HASH3
                        CMP             #$DE
                        BNE             ASM_SMOKE_FAIL_A

                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL_A
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_HEX
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_VALUE_LO
                        CMP             #$00
                        BNE             ASM_SMOKE_FAIL_A
                        LDA             ASM_VALUE_HI
                        CMP             #$30
                        BNE             ASM_SMOKE_FAIL_A

                        LDX             #<ASM_SMOKE_LINE_TOKENS
                        LDY             #>ASM_SMOKE_LINE_TOKENS
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_FAIL_A

                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL_A
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_HAS_COLON
                        BEQ             ASM_SMOKE_FAIL

                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_SMOKE_FAIL

                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_SUB
                        CMP             #'#'
                        BNE             ASM_SMOKE_FAIL

                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_DEC
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_VALUE_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_FAIL

                        LDX             #<ASM_SMOKE_LINE_CHAR
                        LDY             #>ASM_SMOKE_LINE_CHAR
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_FAIL
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_CHAR
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_VALUE_LO
                        CMP             #'a'
                        BNE             ASM_SMOKE_FAIL

                        LDX             #<ASM_SMOKE_LINE_MASK
                        LDY             #>ASM_SMOKE_LINE_MASK
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_FAIL
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_MASK
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_VALUE_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_FAIL
                        LDA             ASM_CARE_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_FAIL

                        SEC
                        RTS

ASM_SMOKE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_VOCAB:
                        LDA             #ASM_VOC_MNEM
                        LDX             #<ASM_SMOKE_VOC_LDA
                        LDY             #>ASM_SMOKE_VOC_LDA
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_DIR
                        LDX             #<ASM_SMOKE_VOC_DC
                        LDY             #>ASM_SMOKE_VOC_DC
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_REG
                        LDX             #<ASM_SMOKE_VOC_A
                        LDY             #>ASM_SMOKE_VOC_A
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_RESERVED
                        LDX             #<ASM_SMOKE_VOC_START
                        LDY             #>ASM_SMOKE_VOC_START
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_NONE
                        LDX             #<ASM_SMOKE_VOC_FOO
                        LDY             #>ASM_SMOKE_VOC_FOO
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL
                        SEC
                        RTS

ASM_SMOKE_VOCAB_FAIL:
                        CLC
                        RTS

ASM_SMOKE_LOOKUP:
                        STA             ASM_TMP0_LO
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_LOOKUP_FAIL
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_SMOKE_LOOKUP_FAIL
                        JSR             ASM_LOOKUP_WORD
                        BCS             ASM_SMOKE_LOOKUP_FOUND
                        STZ             ASM_TMP1_LO
                        BRA             ASM_SMOKE_LOOKUP_HAVE
ASM_SMOKE_LOOKUP_FOUND:
                        LDA             #$01
                        STA             ASM_TMP1_LO
ASM_SMOKE_LOOKUP_HAVE:
                        TYA
                        CMP             ASM_TMP0_LO
                        BNE             ASM_SMOKE_LOOKUP_FAIL
                        LDA             ASM_TMP0_LO
                        BEQ             ASM_SMOKE_LOOKUP_EXPECT_NONE
                        LDA             ASM_TMP1_LO
                        BEQ             ASM_SMOKE_LOOKUP_FAIL
                        SEC
                        RTS
ASM_SMOKE_LOOKUP_EXPECT_NONE:
                        LDA             ASM_TMP1_LO
                        BNE             ASM_SMOKE_LOOKUP_FAIL
                        SEC
                        RTS
ASM_SMOKE_LOOKUP_FAIL:
                        CLC
                        RTS

ASM_SMOKE_PARSE_FAIL_A:
                        JMP             ASM_SMOKE_PARSE_FAIL

ASM_SMOKE_PARSE:
                        LDA             #ASM_STMT_EMPTY
                        LDX             #<ASM_SMOKE_PARSE_BLANK
                        LDY             #>ASM_SMOKE_PARSE_BLANK
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_A

                        LDA             #ASM_STMT_LABEL_ONLY
                        LDX             #<ASM_SMOKE_PARSE_LABEL
                        LDY             #>ASM_SMOKE_PARSE_LABEL
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_A

                        LDA             #ASM_STMT_LABEL_ONLY
                        LDX             #<ASM_SMOKE_PARSE_LABEL_COLON
                        LDY             #>ASM_SMOKE_PARSE_LABEL_COLON
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_COLON
                        BEQ             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_SMOKE_PARSE_LDA
                        LDY             #>ASM_SMOKE_PARSE_LDA
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_SMOKE_PARSE_LABEL_LDA
                        LDY             #>ASM_SMOKE_PARSE_LABEL_LDA
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_EQU
                        LDY             #>ASM_SMOKE_PARSE_EQU
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_ORG
                        LDY             #>ASM_SMOKE_PARSE_ORG
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_END
                        LDY             #>ASM_SMOKE_PARSE_END
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_SYM
                        LDX             #<ASM_SMOKE_PARSE_LABEL_ORG
                        LDY             #>ASM_SMOKE_PARSE_LABEL_ORG
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_END_TAIL
                        LDY             #>ASM_SMOKE_PARSE_END_TAIL
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_DIR
                        LDX             #<ASM_SMOKE_PARSE_START
                        LDY             #>ASM_SMOKE_PARSE_START
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL
                        SEC
                        RTS

ASM_SMOKE_PARSE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_PARSE_OK:
                        STA             ASM_TMP0_LO
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_PARSE_HELPER_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_PARSE_HELPER_FAIL
                        JSR             ASM_DISPATCH_STATEMENT
                        BCC             ASM_SMOKE_PARSE_HELPER_FAIL
                        LDA             ASM_STMT_KIND
                        CMP             ASM_TMP0_LO
                        BNE             ASM_SMOKE_PARSE_HELPER_FAIL
                        SEC
                        RTS

ASM_SMOKE_PARSE_ERR:
                        STA             ASM_TMP0_LO
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_PARSE_HELPER_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_PARSE_HAVE_ERR
                        JSR             ASM_DISPATCH_STATEMENT
                        BCS             ASM_SMOKE_PARSE_HELPER_FAIL
ASM_SMOKE_PARSE_HAVE_ERR:
                        CMP             ASM_TMP0_LO
                        BNE             ASM_SMOKE_PARSE_HELPER_FAIL
                        SEC
                        RTS

ASM_SMOKE_PARSE_HELPER_FAIL:
                        CLC
                        RTS

ASM_SMOKE_SYMBOLS_FAIL_A:
                        JMP             ASM_SMOKE_SYMBOLS_FAIL

ASM_SMOKE_SYMBOLS:
                        STZ             ASM_SYM_COUNT

                        LDX             #<ASM_SMOKE_SYM_LABEL
                        LDY             #>ASM_SMOKE_SYM_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_SYMBOLS_FAIL_A
                        JSR             ASM_SMOKE_INSTALL_COLLISION_ROW
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_SYMBOLS_FAIL_A
                        CPX             #$01
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_SYM_COUNT
                        CMP             #$02
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        JSR             ASM_LOAD_NAME_FROM_STMT
                        LDA             #ASM_SYM_LOOK_SESSION
                        JSR             ASM_LOOKUP_SYMBOL
                        BCC             ASM_SMOKE_SYMBOLS_FAIL_A
                        CPX             #$01
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_VALUE_LO
                        CMP             ASM_PC_LO
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_VALUE_HI
                        CMP             ASM_PC_HI
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A
                        JSR             ASM_BIND_LABEL
                        BCS             ASM_SMOKE_SYMBOLS_FAIL_A
                        CMP             #ASM_STATUS_BAD_SYM
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A

                        LDX             #<ASM_SMOKE_SYM_FOO_EQU
                        LDY             #>ASM_SMOKE_SYM_FOO_EQU
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_ZP
                        STA             ASM_WIDTH
                        LDA             #$12
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        LDA             #$FF
                        STA             ASM_CARE_LO
                        STA             ASM_CARE_HI
                        JSR             ASM_DEFINE_EQU
                        BCC             ASM_SMOKE_SYMBOLS_FAIL_A
                        LDA             ASM_SYM_WIDTH,X
                        CMP             #ASM_WIDTH_ZP
                        BNE             ASM_SMOKE_SYMBOLS_FAIL_A

                        LDX             #<ASM_SMOKE_SYM_ADDR_EQU
                        LDY             #>ASM_SMOKE_SYM_ADDR_EQU
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCS             ASM_SMOKE_SYMBOLS_ADDR_PARSED
                        JMP             ASM_SMOKE_SYMBOLS_FAIL
ASM_SMOKE_SYMBOLS_ADDR_PARSED:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_WIDTH
                        LDA             #$12
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        LDA             #$FF
                        STA             ASM_CARE_LO
                        STA             ASM_CARE_HI
                        JSR             ASM_DEFINE_EQU
                        BCS             ASM_SMOKE_SYMBOLS_ADDR_DEFINED
                        JMP             ASM_SMOKE_SYMBOLS_FAIL
ASM_SMOKE_SYMBOLS_ADDR_DEFINED:
                        LDA             ASM_SYM_WIDTH,X
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_SMOKE_SYMBOLS_ADDR_WIDTH_OK
                        JMP             ASM_SMOKE_SYMBOLS_FAIL
ASM_SMOKE_SYMBOLS_ADDR_WIDTH_OK:

                        LDX             #<ASM_SMOKE_SYM_COUNT_EQU
                        LDY             #>ASM_SMOKE_SYM_COUNT_EQU
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        LDA             #$0A
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        LDA             #$FF
                        STA             ASM_CARE_LO
                        STA             ASM_CARE_HI
                        JSR             ASM_DEFINE_EQU
                        BCC             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             ASM_SYM_KIND,X
                        CMP             #ASM_SYMK_VALUE
                        BNE             ASM_SMOKE_SYMBOLS_FAIL

                        LDX             #<ASM_SMOKE_SYM_ERR_EQU
                        LDY             #>ASM_SMOKE_SYM_ERR_EQU
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             #ASM_SYMK_MASK
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_MASK8
                        STA             ASM_WIDTH
                        LDA             #$01
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        LDA             #$01
                        STA             ASM_CARE_LO
                        STZ             ASM_CARE_HI
                        JSR             ASM_DEFINE_EQU
                        BCC             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             ASM_SYM_KIND,X
                        CMP             #ASM_SYMK_MASK
                        BNE             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             ASM_SYM_CARE_LO,X
                        CMP             #$01
                        BNE             ASM_SMOKE_SYMBOLS_FAIL

                        LDX             #<ASM_SMOKE_SYM_NOPE
                        LDY             #>ASM_SMOKE_SYM_NOPE
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_SYMBOLS_FAIL
                        JSR             ASM_LOAD_NAME_FROM_STMT
                        LDA             #ASM_SYM_LOOK_SESSION
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_SMOKE_SYMBOLS_FAIL
                        CPX             #$FF
                        BNE             ASM_SMOKE_SYMBOLS_FAIL
                        CPY             #$00
                        BNE             ASM_SMOKE_SYMBOLS_FAIL
                        LDA             #$06
                        CMP             ASM_SYM_COUNT
                        BNE             ASM_SMOKE_SYMBOLS_FAIL
                        SEC
                        RTS

ASM_SMOKE_SYMBOLS_FAIL:
                        CLC
                        RTS

ASM_SMOKE_PARSE_FOR_NAME:
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_PARSE_NAME_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_PARSE_NAME_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_SMOKE_PARSE_NAME_FAIL
                        SEC
                        RTS
ASM_SMOKE_PARSE_NAME_FAIL:
                        CLC
                        RTS

ASM_SMOKE_INSTALL_COLLISION_ROW:
                        LDA             #ASM_SYM_STATE_DEFINED
                        STA             ASM_SYM_STATE
                        LDA             #(ASM_SYMF_HAS_TEXT|ASM_SYMF_FROM_EQU)
                        STA             ASM_SYM_FLAGS
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_SYM_KIND
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_SYM_WIDTH
                        STZ             ASM_SYM_VAL_LO
                        STZ             ASM_SYM_VAL_HI
                        STZ             ASM_SYM_CARE_LO
                        STZ             ASM_SYM_CARE_HI
                        LDA             ASM_STMT_NAME_HASH0
                        STA             ASM_SYM_HASH0
                        LDA             ASM_STMT_NAME_HASH1
                        STA             ASM_SYM_HASH1
                        LDA             ASM_STMT_NAME_HASH2
                        STA             ASM_SYM_HASH2
                        LDA             ASM_STMT_NAME_HASH3
                        STA             ASM_SYM_HASH3
                        LDA             #$05
                        STA             ASM_SYM_NAME_LEN
                        STZ             ASM_SYM_USECNT
                        STZ             ASM_SYM_FIRSTREF_LO
                        STZ             ASM_SYM_FIRSTREF_HI
                        LDA             #'L'
                        STA             ASM_SYM_NAMES
                        LDA             #'A'
                        STA             ASM_SYM_NAMES+1
                        LDA             #'B'
                        STA             ASM_SYM_NAMES+2
                        LDA             #'E'
                        STA             ASM_SYM_NAMES+3
                        LDA             #'X'
                        STA             ASM_SYM_NAMES+4
                        STZ             ASM_SYM_NAMES+5
                        LDA             #$01
                        STA             ASM_SYM_COUNT
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_BEGIN
; IN : A bit0 set means X/Y carries explicit start PC.
;      A bit0 clear means use this module's scratch code buffer.
; OUT: C=1,A=OK,X/Y=current PC when session opened.
;      C=0,A=status on failure.
; MEM: ZP $80-$AF active ASM frame; RAM session state below.
; ----------------------------------------------------------------------------
ASM_BEGIN:
                        STA             ASM_FLAGS
                        STX             ASM_TMP0_LO
                        STY             ASM_TMP0_HI
                        JSR             ASM_CLEAR_SESSION

                        LDA             ASM_FLAGS
                        AND             #ASM_BEGINF_HAVE_PC
                        BEQ             ASM_BEGIN_DEFAULT_PC

                        LDA             ASM_TMP0_LO
                        STA             ASM_PC_LO
                        STA             ASM_START_PC_LO
                        LDA             ASM_TMP0_HI
                        STA             ASM_PC_HI
                        STA             ASM_START_PC_HI
                        BRA             ASM_BEGIN_HAVE_PC

ASM_BEGIN_DEFAULT_PC:
                        LDA             #<ASM_CODE_BUF
                        STA             ASM_PC_LO
                        STA             ASM_START_PC_LO
                        LDA             #>ASM_CODE_BUF
                        STA             ASM_PC_HI
                        STA             ASM_START_PC_HI

ASM_BEGIN_HAVE_PC:
                        LDA             ASM_PC_LO
                        STA             ASM_HIGH_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_HIGH_PC_HI
                        LDA             #ASM_SESS_ACTIVE
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_OK
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_END
; OUT: C=1,A=OK,X/Y=current PC if no required fixups remain.
;      C=0,A=BAD_FIX,X/Y=current PC if pending fixups remain.
; NOTE: Full fixup resolve/reporting lands in ASM 2.20/2.40.
; ----------------------------------------------------------------------------
ASM_END:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_END_FAILED

                        LDA             ASM_FIX_COUNT
                        BEQ             ASM_END_OK

                        LDA             #ASM_SESS_FAILED
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_BAD_FIX
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_END_OK:
                        LDA             #ASM_SESS_ENDED
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_OK
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

ASM_END_FAILED:
                        LDA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_LEX_LINE
; IN : X/Y = NUL, CR, or LF-terminated source line.
; OUT: C=1,A=OK,X/Y=parse pointer if line length <= ASM_LINE_MAX.
;      C=0,A=BAD_LINE,X/Y=parse pointer when line is too long.
; DOES: Stores line and parse pointers. Does not tokenize yet.
; ----------------------------------------------------------------------------
ASM_LEX_LINE:
                        STX             ASM_LINE_PTR_LO
                        STY             ASM_LINE_PTR_HI
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        STZ             ASM_LEN
                        LDY             #$00

ASM_LEX_LINE_LOOP:
                        LDA             (ASM_LINE_PTR_LO),Y
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0D
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0A
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #';'
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$27
                        BEQ             ASM_LEX_LINE_QUOTE

                        JSR             ASM_LEX_COUNT_CHAR
                        BCC             ASM_LEX_LINE_BAD
                        INY
                        BRA             ASM_LEX_LINE_LOOP

ASM_LEX_LINE_QUOTE:
                        JSR             ASM_LEX_COUNT_CHAR
                        BCC             ASM_LEX_LINE_BAD
                        INY
                        LDA             (ASM_LINE_PTR_LO),Y
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0D
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0A
                        BEQ             ASM_LEX_LINE_OK
                        JSR             ASM_LEX_COUNT_CHAR
                        BCC             ASM_LEX_LINE_BAD
                        INY
                        LDA             (ASM_LINE_PTR_LO),Y
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0D
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0A
                        BEQ             ASM_LEX_LINE_OK
                        JSR             ASM_LEX_COUNT_CHAR
                        BCC             ASM_LEX_LINE_BAD
                        INY
                        BRA             ASM_LEX_LINE_LOOP

ASM_LEX_LINE_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_PARSE_PTR_LO
                        LDY             ASM_PARSE_PTR_HI
                        SEC
                        RTS

ASM_LEX_LINE_BAD:
                        LDA             #ASM_STATUS_BAD_LINE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_PARSE_PTR_LO
                        LDY             ASM_PARSE_PTR_HI
                        CLC
                        RTS

ASM_LEX_COUNT_CHAR:
                        INC             ASM_LEN
                        LDA             ASM_LEN
                        CMP             #(ASM_LINE_MAX+1)
                        BCC             ASM_LEX_COUNT_OK
                        CLC
                        RTS
ASM_LEX_COUNT_OK:
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_NEXT_TOKEN
; IN : ASM_PARSE_PTR points at the next scan position after ASM_LEX_LINE.
; OUT: C=1,A=OK with token record in ASM_TOK_*/ASM_LEN/ASM_DELIM/value/hash.
;      C=0,A=status on malformed token.
; ----------------------------------------------------------------------------
ASM_NEXT_TOKEN:
                        JSR             ASM_CLEAR_TOKEN
                        JSR             ASM_SKIP_SPACES

                        LDA             ASM_PARSE_PTR_LO
                        STA             ASM_TOKEN_PTR_LO
                        LDA             ASM_PARSE_PTR_HI
                        STA             ASM_TOKEN_PTR_HI

                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        BEQ             ASM_NEXT_TOKEN_EOL
                        CMP             #$0D
                        BEQ             ASM_NEXT_TOKEN_EOL
                        CMP             #$0A
                        BEQ             ASM_NEXT_TOKEN_EOL
                        CMP             #';'
                        BEQ             ASM_NEXT_TOKEN_EOL
                        CMP             #$27
                        BEQ             ASM_NEXT_TOKEN_CHAR
                        CMP             #'%'
                        BNE             ASM_NEXT_NOT_BIN_START
                        JMP             ASM_NEXT_TOKEN_BIN
ASM_NEXT_NOT_BIN_START:
                        CMP             #'$'
                        BNE             ASM_NEXT_NOT_HEX_START
                        JMP             ASM_NEXT_TOKEN_HEX
ASM_NEXT_NOT_HEX_START:
                        CMP             #'.'
                        BEQ             ASM_NEXT_TOKEN_MAYBE_LOCAL
                        CMP             #'?'
                        BEQ             ASM_NEXT_TOKEN_MAYBE_LOCAL
                        JSR             ASM_IS_DIGIT
                        BCC             ASM_NEXT_NOT_DEC_START
                        JMP             ASM_NEXT_TOKEN_DEC
ASM_NEXT_NOT_DEC_START:
                        JSR             ASM_IS_WORD_HEAD
                        BCS             ASM_NEXT_TOKEN_WORD
                        JSR             ASM_IS_PUNCT
                        BCS             ASM_NEXT_TOKEN_PUNCT
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_MAYBE_LOCAL:
                        LDY             #$01
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_WORD_BODY
                        BCS             ASM_NEXT_TOKEN_WORD
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_PUNCT
                        BCS             ASM_NEXT_TOKEN_PUNCT
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_EOL:
                        LDA             #ASM_TOK_EOL
                        STA             ASM_TOK_KIND
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_TOKEN_PUNCT:
                        LDA             #ASM_TOK_PUNCT
                        STA             ASM_TOK_KIND
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_TOK_SUB
                        STA             ASM_DELIM
                        LDA             #$01
                        STA             ASM_LEN
                        JSR             ASM_ADV_PARSE
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_TOKEN_CHAR:
                        LDA             #ASM_TOK_CHAR
                        STA             ASM_TOK_KIND
                        LDA             #ASM_TF_QUOTED
                        STA             ASM_TOK_FLAGS
                        LDA             #$03
                        STA             ASM_LEN
                        JSR             ASM_ADV_PARSE
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_NEXT_CHAR_BAD
                        CMP             #$0D
                        BEQ             ASM_NEXT_CHAR_BAD
                        CMP             #$0A
                        BEQ             ASM_NEXT_CHAR_BAD
                        STA             ASM_VALUE_LO
                        JSR             ASM_ADV_PARSE
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        CMP             #$27
                        BNE             ASM_NEXT_CHAR_BAD
                        JSR             ASM_ADV_PARSE
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_CHAR_BAD:
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_WORD:
                        LDA             #ASM_TOK_WORD
                        STA             ASM_TOK_KIND
                        JSR             ASM_FNV1A_INIT
ASM_NEXT_WORD_LOOP:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        CMP             #':'
                        BEQ             ASM_NEXT_WORD_COLON
                        LDA             ASM_LEN
                        BEQ             ASM_NEXT_WORD_FIRST
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_WORD_BODY
                        BCS             ASM_NEXT_WORD_TAKE
                        BRA             ASM_NEXT_WORD_END_CHECK

ASM_NEXT_WORD_FIRST:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        CMP             #'.'
                        BEQ             ASM_NEXT_WORD_LOCAL
                        CMP             #'?'
                        BEQ             ASM_NEXT_WORD_LOCAL
                        JSR             ASM_IS_WORD_HEAD
                        BCC             ASM_NEXT_WORD_BAD
                        BRA             ASM_NEXT_WORD_TAKE

ASM_NEXT_WORD_LOCAL:
                        LDA             ASM_TOK_FLAGS
                        ORA             #ASM_TF_LOCAL_PREFIX
                        STA             ASM_TOK_FLAGS

ASM_NEXT_WORD_TAKE:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        INC             ASM_LEN
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        JSR             ASM_FNV1A_UPDATE_A_FAST
                        JSR             ASM_ADV_PARSE
                        BRA             ASM_NEXT_WORD_LOOP

ASM_NEXT_WORD_COLON:
                        LDA             ASM_LEN
                        BNE             ASM_NEXT_WORD_HAVE_COLON
                        JMP             ASM_NEXT_TOKEN_PUNCT
ASM_NEXT_WORD_HAVE_COLON:
                        LDA             ASM_TOK_FLAGS
                        ORA             #ASM_TF_HAS_COLON
                        STA             ASM_TOK_FLAGS
                        LDA             #':'
                        STA             ASM_DELIM
                        JSR             ASM_ADV_PARSE
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_WORD_END_CHECK:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_TOKEN_DELIM
                        BCC             ASM_NEXT_WORD_BAD
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_WORD_BAD:
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_HEX:
                        LDA             #ASM_TOK_NUMBER
                        STA             ASM_TOK_KIND
                        LDA             #ASM_TSUB_HEX
                        STA             ASM_TOK_SUB
                        LDA             #$01
                        STA             ASM_LEN
                        JSR             ASM_ZERO_VALUE
                        JSR             ASM_ADV_PARSE
ASM_NEXT_HEX_LOOP:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_HEX_TO_NIBBLE
                        BCS             ASM_NEXT_HEX_DIGIT
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_TOKEN_DELIM
                        BCC             ASM_NEXT_HEX_BAD_EXIT
                        LDA             ASM_BIT
                        BEQ             ASM_NEXT_HEX_BAD_EXIT
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_HEX_DIGIT:
                        STA             ASM_TMP0_LO
                        INC             ASM_BIT
                        LDA             ASM_BIT
                        CMP             #$05
                        BCS             ASM_NEXT_HEX_BAD_EXIT
                        JSR             ASM_VALUE_SHL4
                        LDA             ASM_VALUE_LO
                        ORA             ASM_TMP0_LO
                        STA             ASM_VALUE_LO
                        INC             ASM_LEN
                        JSR             ASM_ADV_PARSE
                        BRA             ASM_NEXT_HEX_LOOP

ASM_NEXT_HEX_BAD_EXIT:
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_DEC:
                        LDA             #ASM_TOK_NUMBER
                        STA             ASM_TOK_KIND
                        LDA             #ASM_TSUB_DEC
                        STA             ASM_TOK_SUB
                        JSR             ASM_ZERO_VALUE
ASM_NEXT_DEC_LOOP:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_DIGIT
                        BCC             ASM_NEXT_DEC_END_CHECK
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        SEC
                        SBC             #'0'
                        STA             ASM_TMP0_LO
                        INC             ASM_BIT
                        JSR             ASM_VALUE_MUL10_ADD_TMP0
                        INC             ASM_LEN
                        JSR             ASM_ADV_PARSE
                        BRA             ASM_NEXT_DEC_LOOP

ASM_NEXT_DEC_END_CHECK:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        JSR             ASM_IS_TOKEN_DELIM
                        BCC             ASM_NEXT_DEC_BAD_EXIT
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_DEC_BAD_EXIT:
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_TOKEN_BIN:
                        LDA             #ASM_TOK_NUMBER
                        STA             ASM_TOK_KIND
                        LDA             #ASM_TSUB_BIN
                        STA             ASM_TOK_SUB
                        LDA             #$01
                        STA             ASM_LEN
                        JSR             ASM_ZERO_VALUE
                        JSR             ASM_ADV_PARSE
ASM_NEXT_BIN_LOOP:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        CMP             #'0'
                        BEQ             ASM_NEXT_BIN_ZERO
                        CMP             #'1'
                        BEQ             ASM_NEXT_BIN_ONE
                        CMP             #'X'
                        BEQ             ASM_NEXT_BIN_X
                        CMP             #'x'
                        BEQ             ASM_NEXT_BIN_X
                        JSR             ASM_IS_TOKEN_DELIM
                        BCC             ASM_NEXT_BIN_BAD_EXIT
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_NEXT_BIN_WIDTH_OK
                        CMP             #$10
                        BNE             ASM_NEXT_BIN_BAD_EXIT
ASM_NEXT_BIN_WIDTH_OK:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_HAS_XMASK
                        BEQ             ASM_NEXT_BIN_STORE_DELIM
                        LDA             #ASM_TSUB_MASK
                        STA             ASM_TOK_SUB
ASM_NEXT_BIN_STORE_DELIM:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        STA             ASM_DELIM
                        JMP             ASM_NEXT_TOKEN_OK

ASM_NEXT_BIN_BAD_EXIT:
                        JMP             ASM_NEXT_TOKEN_BAD_OPER

ASM_NEXT_BIN_ZERO:
                        JSR             ASM_NEXT_BIN_SHIFT_CONCRETE
                        BCC             ASM_NEXT_BIN_BAD_EXIT
                        BRA             ASM_NEXT_BIN_TAKE

ASM_NEXT_BIN_ONE:
                        JSR             ASM_NEXT_BIN_SHIFT_CONCRETE
                        BCC             ASM_NEXT_BIN_BAD_EXIT
                        LDA             ASM_VALUE_LO
                        ORA             #$01
                        STA             ASM_VALUE_LO
                        BRA             ASM_NEXT_BIN_TAKE

ASM_NEXT_BIN_X:
                        LDA             ASM_BIT
                        CMP             #$10
                        BCS             ASM_NEXT_BIN_BAD_EXIT
                        INC             ASM_BIT
                        JSR             ASM_BIN_SHIFT
                        LDA             ASM_TOK_FLAGS
                        ORA             #ASM_TF_HAS_XMASK
                        STA             ASM_TOK_FLAGS

ASM_NEXT_BIN_TAKE:
                        INC             ASM_LEN
                        JSR             ASM_ADV_PARSE
                        BRA             ASM_NEXT_BIN_LOOP

ASM_NEXT_BIN_SHIFT_CONCRETE:
                        LDA             ASM_BIT
                        CMP             #$10
                        BCC             ASM_NEXT_BIN_SHIFT_OK
                        CLC
                        RTS
ASM_NEXT_BIN_SHIFT_OK:
                        INC             ASM_BIT
                        JSR             ASM_BIN_SHIFT
                        LDA             ASM_CARE_LO
                        ORA             #$01
                        STA             ASM_CARE_LO
                        SEC
                        RTS

ASM_NEXT_TOKEN_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_TOKEN_PTR_LO
                        LDY             ASM_TOKEN_PTR_HI
                        SEC
                        RTS

ASM_NEXT_TOKEN_BAD_OPER:
                        LDA             ASM_TOK_FLAGS
                        ORA             #ASM_TF_ERROR
                        STA             ASM_TOK_FLAGS
                        LDA             #ASM_STATUS_BAD_OPER
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_TOKEN_PTR_LO
                        LDY             ASM_TOKEN_PTR_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_LOOKUP_WORD
; IN : Current token record is normally WORD with ASM_HASH0..3 filled.
; OUT: C=1,A=OK,X=slot,Y=VOC_KIND when found.
;      C=0,A=OK,X=$FF,Y=VOC_NONE when not found.
; NOTE: For v1 this table has no runtime text compare; build/docs prove no
;       fixed-vocabulary hash collision.
; ----------------------------------------------------------------------------
ASM_LOOKUP_WORD:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_LOOKUP_WORD_NONE
                        LDX             #$00

ASM_LOOKUP_WORD_LOOP:
                        CPX             #ASM_VOC_COUNT
                        BEQ             ASM_LOOKUP_WORD_NONE
                        LDA             ASM_HASH0
                        CMP             ASM_VOC_HASH0,X
                        BNE             ASM_LOOKUP_WORD_NEXT
                        LDA             ASM_HASH1
                        CMP             ASM_VOC_HASH1,X
                        BNE             ASM_LOOKUP_WORD_NEXT
                        LDA             ASM_HASH2
                        CMP             ASM_VOC_HASH2,X
                        BNE             ASM_LOOKUP_WORD_NEXT
                        LDA             ASM_HASH3
                        CMP             ASM_VOC_HASH3,X
                        BNE             ASM_LOOKUP_WORD_NEXT

                        STX             ASM_SLOT
                        STX             ASM_VOC_ID
                        STZ             ASM_VOC_DISP
                        STZ             ASM_VOC_FLAGS
                        STZ             ASM_VOC_AUX
                        LDY             ASM_VOC_KIND_TAB,X
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS

ASM_LOOKUP_WORD_NEXT:
                        INX
                        BRA             ASM_LOOKUP_WORD_LOOP

ASM_LOOKUP_WORD_NONE:
                        LDX             #$FF
                        STX             ASM_SLOT
                        STZ             ASM_VOC_ID
                        STZ             ASM_VOC_DISP
                        STZ             ASM_VOC_FLAGS
                        STZ             ASM_VOC_AUX
                        LDY             #ASM_VOC_NONE
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_PARSE_HEAD
; IN : ASM_PARSE_PTR points at a prepared source line.
; OUT: C=1,A=OK with ASM_STMT_* filled.
;      C=0,A=status on top-level parse error.
; ----------------------------------------------------------------------------
ASM_PARSE_HEAD:
                        JSR             ASM_CLEAR_STMT
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_PARSE_HAVE_FIRST_TOKEN
                        JMP             ASM_PARSE_FAIL_A

ASM_PARSE_HAVE_FIRST_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_EOL
                        BEQ             ASM_PARSE_EMPTY_OK
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_PARSE_BAD_OPER

                        JSR             ASM_LOOKUP_WORD
                        BCC             ASM_PARSE_FIRST_NONE

                        CPY             #ASM_VOC_MNEM
                        BEQ             ASM_PARSE_FIRST_OP
                        CPY             #ASM_VOC_DIR
                        BEQ             ASM_PARSE_FIRST_OP
                        CPY             #ASM_VOC_RESERVED
                        BEQ             ASM_PARSE_BAD_DIR
                        JMP             ASM_PARSE_BAD_SYM

ASM_PARSE_FIRST_OP:
                        JSR             ASM_STORE_OP_FROM_LOOKUP
                        JMP             ASM_PARSE_OK

ASM_PARSE_FIRST_NONE:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BNE             ASM_PARSE_LOCAL_NYI
                        JSR             ASM_STORE_NAME_FROM_TOKEN
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_PARSE_FAIL_A
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_EOL
                        BEQ             ASM_PARSE_LABEL_ONLY_OK
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_PARSE_BAD_MNEM
                        JSR             ASM_LOOKUP_WORD
                        BCC             ASM_PARSE_BAD_MNEM
                        CPY             #ASM_VOC_MNEM
                        BEQ             ASM_PARSE_SECOND_OP
                        CPY             #ASM_VOC_DIR
                        BEQ             ASM_PARSE_SECOND_OP
                        CPY             #ASM_VOC_RESERVED
                        BEQ             ASM_PARSE_BAD_DIR
                        JMP             ASM_PARSE_BAD_MNEM

ASM_PARSE_SECOND_OP:
                        JSR             ASM_STORE_OP_FROM_LOOKUP
                        JMP             ASM_PARSE_OK

ASM_PARSE_EMPTY_OK:
                        LDA             #ASM_STMT_EMPTY
                        STA             ASM_STMT_KIND
                        JMP             ASM_PARSE_OK

ASM_PARSE_LABEL_ONLY_OK:
                        LDA             #ASM_STMT_LABEL_ONLY
                        STA             ASM_STMT_KIND
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_BINDS_PC
                        STA             ASM_STMT_FLAGS
                        JMP             ASM_PARSE_OK

ASM_PARSE_BAD_MNEM:
                        LDA             #ASM_STATUS_BAD_MNEM
                        BRA             ASM_PARSE_FAIL_A
ASM_PARSE_BAD_DIR:
                        LDA             #ASM_STATUS_BAD_DIR
                        BRA             ASM_PARSE_FAIL_A
ASM_PARSE_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_PARSE_FAIL_A
ASM_PARSE_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        BRA             ASM_PARSE_FAIL_A
ASM_PARSE_LOCAL_NYI:
                        LDA             #ASM_STATUS_LOCAL_NYI

ASM_PARSE_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        STA             ASM_STMT_STATUS
                        LDA             #ASM_STMT_ERROR
                        STA             ASM_STMT_KIND
                        LDA             ASM_STMT_STATUS
                        LDX             ASM_TOKEN_PTR_LO
                        LDY             ASM_TOKEN_PTR_HI
                        CLC
                        RTS

ASM_PARSE_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        STA             ASM_STMT_STATUS
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        SEC
                        RTS

ASM_STORE_NAME_FROM_TOKEN:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_STMT_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_STMT_NAME_PTR_HI
                        LDA             ASM_LEN
                        STA             ASM_STMT_NAME_LEN
                        LDA             ASM_HASH0
                        STA             ASM_STMT_NAME_HASH0
                        LDA             ASM_HASH1
                        STA             ASM_STMT_NAME_HASH1
                        LDA             ASM_HASH2
                        STA             ASM_STMT_NAME_HASH2
                        LDA             ASM_HASH3
                        STA             ASM_STMT_NAME_HASH3
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_HAS_NAME
                        STA             ASM_STMT_FLAGS
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_HAS_COLON
                        BEQ             ASM_STORE_NAME_DONE
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_HAS_COLON
                        STA             ASM_STMT_FLAGS
ASM_STORE_NAME_DONE:
                        RTS

ASM_STORE_OP_FROM_LOOKUP:
                        STX             ASM_STMT_VOC_SLOT
                        TYA
                        STA             ASM_STMT_OP_KIND
                        LDA             ASM_VOC_ID
                        STA             ASM_STMT_OP_ID
                        LDA             ASM_STMT_OP_KIND
                        CMP             #ASM_VOC_DIR
                        BEQ             ASM_STORE_OP_DIR
                        LDA             #ASM_STMT_MNEM
                        STA             ASM_STMT_KIND
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_BINDS_PC
                        STA             ASM_STMT_FLAGS
                        JMP             ASM_SET_TAIL_FROM_PARSE
ASM_STORE_OP_DIR:
                        LDA             #ASM_STMT_DIR
                        STA             ASM_STMT_KIND
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_CONTROL
                        STA             ASM_STMT_FLAGS
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_EQU
                        BNE             ASM_STORE_OP_DIR_NOT_EQU
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_BINDS_EQU
                        STA             ASM_STMT_FLAGS
                        BRA             ASM_STORE_OP_DIR_TAIL
ASM_STORE_OP_DIR_NOT_EQU:
                        CMP             #ASM_VID_DC
                        BEQ             ASM_STORE_OP_DIR_BINDS_PC
                        CMP             #ASM_VID_DS
                        BEQ             ASM_STORE_OP_DIR_BINDS_PC
                        BRA             ASM_STORE_OP_DIR_TAIL
ASM_STORE_OP_DIR_BINDS_PC:
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_BINDS_PC
                        STA             ASM_STMT_FLAGS
ASM_STORE_OP_DIR_TAIL:
                        JMP             ASM_SET_TAIL_FROM_PARSE

ASM_SET_TAIL_FROM_PARSE:
                        JSR             ASM_SKIP_SPACES
                        LDA             ASM_PARSE_PTR_LO
                        STA             ASM_STMT_TAIL_PTR_LO
                        LDA             ASM_PARSE_PTR_HI
                        STA             ASM_STMT_TAIL_PTR_HI
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_SET_TAIL_DONE
                        CMP             #$0D
                        BEQ             ASM_SET_TAIL_DONE
                        CMP             #$0A
                        BEQ             ASM_SET_TAIL_DONE
                        CMP             #';'
                        BEQ             ASM_SET_TAIL_DONE
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_HAS_TAIL
                        STA             ASM_STMT_FLAGS
ASM_SET_TAIL_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_DISPATCH_STATEMENT
; Current v1.60 dispatch only applies top-level statement policy. Later layers
; bind symbols, evaluate expressions, emit opcodes, and resolve fixups.
; ----------------------------------------------------------------------------
ASM_DISPATCH_STATEMENT:
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_ERROR
                        BEQ             ASM_DISPATCH_STORED_FAIL
                        CMP             #ASM_STMT_EMPTY
                        BEQ             ASM_DISPATCH_OK
                        CMP             #ASM_STMT_LABEL_ONLY
                        BEQ             ASM_DISPATCH_OK
                        CMP             #ASM_STMT_MNEM
                        BEQ             ASM_DISPATCH_OK
                        CMP             #ASM_STMT_DIR
                        BEQ             ASM_DISPATCH_DIR
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_DISPATCH_FAIL_A

ASM_DISPATCH_DIR:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_EQU
                        BEQ             ASM_DISPATCH_DIR_EQU
                        CMP             #ASM_VID_ORG
                        BEQ             ASM_DISPATCH_DIR_ORG
                        CMP             #ASM_VID_END
                        BEQ             ASM_DISPATCH_DIR_END
                        CMP             #ASM_VID_DC
                        BEQ             ASM_DISPATCH_DIR_DATA
                        CMP             #ASM_VID_DS
                        BEQ             ASM_DISPATCH_DIR_DATA
                        LDA             #ASM_STATUS_BAD_DIR
                        BRA             ASM_DISPATCH_FAIL_A

ASM_DISPATCH_DIR_EQU:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_BAD_SYM
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_DISPATCH_BAD_OPER
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_ORG:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BNE             ASM_DISPATCH_BAD_SYM
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_DISPATCH_BAD_OPER
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_END:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BNE             ASM_DISPATCH_BAD_SYM
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_BAD_OPER
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_DATA:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_DISPATCH_BAD_OPER
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        BRA             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_STORED_FAIL:
                        LDA             ASM_STMT_STATUS

ASM_DISPATCH_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        STA             ASM_STMT_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_DISPATCH_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        STA             ASM_STMT_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

ASM_CLEAR_STMT:
                        STZ             ASM_STMT_KIND
                        STZ             ASM_STMT_FLAGS
                        STZ             ASM_STMT_NAME_PTR_LO
                        STZ             ASM_STMT_NAME_PTR_HI
                        STZ             ASM_STMT_NAME_LEN
                        STZ             ASM_STMT_NAME_HASH0
                        STZ             ASM_STMT_NAME_HASH1
                        STZ             ASM_STMT_NAME_HASH2
                        STZ             ASM_STMT_NAME_HASH3
                        STZ             ASM_STMT_VOC_SLOT
                        STZ             ASM_STMT_OP_KIND
                        STZ             ASM_STMT_OP_ID
                        STZ             ASM_STMT_TAIL_PTR_LO
                        STZ             ASM_STMT_TAIL_PTR_HI
                        STZ             ASM_STMT_STATUS
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_LOOKUP_SYMBOL
; IN : ASM_NAME_PTR/ASM_LEN and ASM_HASH0..3 describe canonical source name.
;      A bit0=session table, bit2=mark use.
; OUT: C=1,A=OK,X=slot,Y=1 when found; C=0,A=OK,X=$FF,Y=0 when not found.
; ----------------------------------------------------------------------------
ASM_LOOKUP_SYMBOL:
                        STA             ASM_FLAGS
                        AND             #ASM_SYM_LOOK_SESSION
                        BNE             ASM_LOOKUP_SYMBOL_HAVE_SESSION
                        JMP             ASM_LOOKUP_SYMBOL_NONE

ASM_LOOKUP_SYMBOL_HAVE_SESSION:
                        LDX             #$00

ASM_LOOKUP_SYMBOL_LOOP:
                        CPX             ASM_SYM_COUNT
                        BNE             ASM_LOOKUP_SYMBOL_HAVE_SLOT
                        JMP             ASM_LOOKUP_SYMBOL_NONE

ASM_LOOKUP_SYMBOL_HAVE_SLOT:
                        LDA             ASM_SYM_STATE,X
                        CMP             #ASM_SYM_STATE_DEFINED
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        LDA             ASM_HASH0
                        CMP             ASM_SYM_HASH0,X
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        LDA             ASM_HASH1
                        CMP             ASM_SYM_HASH1,X
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        LDA             ASM_HASH2
                        CMP             ASM_SYM_HASH2,X
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        LDA             ASM_HASH3
                        CMP             ASM_SYM_HASH3,X
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        LDA             ASM_LEN
                        CMP             ASM_SYM_NAME_LEN,X
                        BNE             ASM_LOOKUP_SYMBOL_NEXT
                        JSR             ASM_SYM_TEXT_MATCH_X
                        BCC             ASM_LOOKUP_SYMBOL_NEXT

                        STX             ASM_SLOT
                        LDA             ASM_FLAGS
                        AND             #ASM_SYM_LOOK_MARK_USE
                        BEQ             ASM_LOOKUP_SYMBOL_LOAD
                        LDA             ASM_SYM_USECNT,X
                        BNE             ASM_LOOKUP_SYMBOL_MARK_INC
                        LDA             ASM_LINE_COUNT_LO
                        STA             ASM_SYM_FIRSTREF_LO,X
                        LDA             ASM_LINE_COUNT_HI
                        STA             ASM_SYM_FIRSTREF_HI,X
ASM_LOOKUP_SYMBOL_MARK_INC:
                        INC             ASM_SYM_USECNT,X
                        LDA             ASM_SYM_FLAGS,X
                        ORA             #ASM_SYMF_USED
                        STA             ASM_SYM_FLAGS,X

ASM_LOOKUP_SYMBOL_LOAD:
                        LDA             ASM_SYM_VAL_LO,X
                        STA             ASM_VALUE_LO
                        LDA             ASM_SYM_VAL_HI,X
                        STA             ASM_VALUE_HI
                        LDA             ASM_SYM_CARE_LO,X
                        STA             ASM_CARE_LO
                        LDA             ASM_SYM_CARE_HI,X
                        STA             ASM_CARE_HI
                        LDA             ASM_SYM_KIND,X
                        STA             ASM_MODE
                        LDA             ASM_SYM_WIDTH,X
                        STA             ASM_WIDTH
                        LDY             #$01
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS

ASM_LOOKUP_SYMBOL_NEXT:
                        INX
                        JMP             ASM_LOOKUP_SYMBOL_LOOP

ASM_LOOKUP_SYMBOL_NONE:
                        LDX             #$FF
                        STX             ASM_SLOT
                        LDY             #$00
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_BIND_LABEL
; Define the current statement name as ADDR/ABS at the current ASM PC.
; ----------------------------------------------------------------------------
ASM_BIND_LABEL:
                        JSR             ASM_LOAD_NAME_FROM_STMT
                        BCC             ASM_BIND_LABEL_BAD
                        LDA             #ASM_SYM_LOOK_SESSION
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_BIND_LABEL_BAD
                        LDX             ASM_SYM_COUNT
                        CPX             #ASM_SYM_MAX
                        BCS             ASM_BIND_LABEL_BAD
                        STX             ASM_SLOT
                        JSR             ASM_STORE_SYMBOL_NAME_X
                        LDA             #ASM_SYM_STATE_DEFINED
                        STA             ASM_SYM_STATE,X
                        LDA             #(ASM_SYMF_HAS_TEXT|ASM_SYMF_HAS_CARE|ASM_SYMF_FROM_LABEL)
                        STA             ASM_SYM_FLAGS,X
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_SYM_KIND,X
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_SYM_WIDTH,X
                        LDA             ASM_PC_LO
                        STA             ASM_SYM_VAL_LO,X
                        LDA             ASM_PC_HI
                        STA             ASM_SYM_VAL_HI,X
                        LDA             #$FF
                        STA             ASM_SYM_CARE_LO,X
                        STA             ASM_SYM_CARE_HI,X
                        STZ             ASM_SYM_USECNT,X
                        STZ             ASM_SYM_FIRSTREF_LO,X
                        STZ             ASM_SYM_FIRSTREF_HI,X
                        INC             ASM_SYM_COUNT
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDY             ASM_PC_HI
                        SEC
                        RTS
ASM_BIND_LABEL_BAD:
                        LDA             #ASM_STATUS_BAD_SYM
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_DEFINE_EQU
; Define the current statement name from resolved ASM_VALUE/CARE/MODE/WIDTH.
; ----------------------------------------------------------------------------
ASM_DEFINE_EQU:
                        JSR             ASM_LOAD_NAME_FROM_STMT
                        BCC             ASM_DEFINE_EQU_BAD_SYM
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_DEFINE_EQU_KIND_OK
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_DEFINE_EQU_KIND_OK
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_DEFINE_EQU_KIND_OK
                        LDA             #ASM_STATUS_BAD_WIDTH
                        BRA             ASM_DEFINE_EQU_FAIL_A

ASM_DEFINE_EQU_KIND_OK:
                        LDA             #ASM_SYM_LOOK_SESSION
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_DEFINE_EQU_BAD_SYM
                        LDX             ASM_SYM_COUNT
                        CPX             #ASM_SYM_MAX
                        BCS             ASM_DEFINE_EQU_BAD_SYM
                        STX             ASM_SLOT
                        JSR             ASM_STORE_SYMBOL_NAME_X
                        LDA             #ASM_SYM_STATE_DEFINED
                        STA             ASM_SYM_STATE,X
                        LDA             #(ASM_SYMF_HAS_TEXT|ASM_SYMF_HAS_CARE|ASM_SYMF_FROM_EQU)
                        STA             ASM_SYM_FLAGS,X
                        LDA             ASM_MODE
                        STA             ASM_SYM_KIND,X
                        LDA             ASM_WIDTH
                        STA             ASM_SYM_WIDTH,X
                        LDA             ASM_VALUE_LO
                        STA             ASM_SYM_VAL_LO,X
                        LDA             ASM_VALUE_HI
                        STA             ASM_SYM_VAL_HI,X
                        LDA             ASM_CARE_LO
                        STA             ASM_SYM_CARE_LO,X
                        LDA             ASM_CARE_HI
                        STA             ASM_SYM_CARE_HI,X
                        STZ             ASM_SYM_USECNT,X
                        STZ             ASM_SYM_FIRSTREF_LO,X
                        STZ             ASM_SYM_FIRSTREF_HI,X
                        INC             ASM_SYM_COUNT
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDY             ASM_SYM_WIDTH,X
                        SEC
                        RTS

ASM_DEFINE_EQU_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
ASM_DEFINE_EQU_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

ASM_LOAD_NAME_FROM_STMT:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_LOAD_NAME_BAD
                        LDA             ASM_STMT_NAME_LEN
                        BEQ             ASM_LOAD_NAME_BAD
                        CMP             #ASM_SYM_NAME_MAX
                        BCS             ASM_LOAD_NAME_BAD
                        STA             ASM_LEN
                        LDA             ASM_STMT_NAME_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_STMT_NAME_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_STMT_NAME_HASH0
                        STA             ASM_HASH0
                        LDA             ASM_STMT_NAME_HASH1
                        STA             ASM_HASH1
                        LDA             ASM_STMT_NAME_HASH2
                        STA             ASM_HASH2
                        LDA             ASM_STMT_NAME_HASH3
                        STA             ASM_HASH3
                        SEC
                        RTS
ASM_LOAD_NAME_BAD:
                        CLC
                        RTS

ASM_STORE_SYMBOL_NAME_X:
                        LDA             ASM_HASH0
                        STA             ASM_SYM_HASH0,X
                        LDA             ASM_HASH1
                        STA             ASM_SYM_HASH1,X
                        LDA             ASM_HASH2
                        STA             ASM_SYM_HASH2,X
                        LDA             ASM_HASH3
                        STA             ASM_SYM_HASH3,X
                        LDA             ASM_LEN
                        STA             ASM_SYM_NAME_LEN,X
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDY             #$00
ASM_STORE_SYMBOL_NAME_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_STORE_SYMBOL_NAME_TERM
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        STA             (ASM_SYM_PTR_LO),Y
                        INY
                        BRA             ASM_STORE_SYMBOL_NAME_LOOP
ASM_STORE_SYMBOL_NAME_TERM:
                        LDA             #$00
                        STA             (ASM_SYM_PTR_LO),Y
                        RTS

ASM_SYM_TEXT_MATCH_X:
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDY             #$00
ASM_SYM_TEXT_MATCH_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_SYM_TEXT_MATCH_YES
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        CMP             (ASM_SYM_PTR_LO),Y
                        BNE             ASM_SYM_TEXT_MATCH_NO
                        INY
                        BRA             ASM_SYM_TEXT_MATCH_LOOP
ASM_SYM_TEXT_MATCH_YES:
                        SEC
                        RTS
ASM_SYM_TEXT_MATCH_NO:
                        CLC
                        RTS

ASM_SET_SYM_NAME_PTR_X:
                        TXA
                        LSR
                        LSR
                        LSR
                        STA             ASM_TMP0_HI
                        TXA
                        AND             #$07
                        ASL
                        ASL
                        ASL
                        ASL
                        ASL
                        CLC
                        ADC             #<ASM_SYM_NAMES
                        STA             ASM_SYM_PTR_LO
                        LDA             #>ASM_SYM_NAMES
                        ADC             ASM_TMP0_HI
                        STA             ASM_SYM_PTR_HI
                        RTS

ASM_CLEAR_TOKEN:
                        STZ             ASM_TOK_KIND
                        STZ             ASM_TOK_SUB
                        STZ             ASM_TOK_FLAGS
                        STZ             ASM_LEN
                        STZ             ASM_DELIM
                        STZ             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        STZ             ASM_CARE_LO
                        STZ             ASM_CARE_HI
                        STZ             ASM_BIT
                        STZ             ASM_HASH0
                        STZ             ASM_HASH1
                        STZ             ASM_HASH2
                        STZ             ASM_HASH3
                        RTS

ASM_ZERO_VALUE:
                        STZ             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        STZ             ASM_CARE_LO
                        STZ             ASM_CARE_HI
                        STZ             ASM_BIT
                        RTS

ASM_SKIP_SPACES:
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        CMP             #' '
                        BEQ             ASM_SKIP_ONE
                        CMP             #$09
                        BEQ             ASM_SKIP_ONE
                        RTS
ASM_SKIP_ONE:
                        JSR             ASM_ADV_PARSE
                        BRA             ASM_SKIP_SPACES

ASM_ADV_PARSE:
                        INC             ASM_PARSE_PTR_LO
                        BNE             ASM_ADV_PARSE_DONE
                        INC             ASM_PARSE_PTR_HI
ASM_ADV_PARSE_DONE:
                        RTS

ASM_IS_TOKEN_DELIM:
                        CMP             #$00
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        CMP             #$0D
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        CMP             #$0A
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        CMP             #';'
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        CMP             #' '
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        CMP             #$09
                        BEQ             ASM_IS_TOKEN_DELIM_YES
                        JSR             ASM_IS_PUNCT
                        RTS
ASM_IS_TOKEN_DELIM_YES:
                        SEC
                        RTS

ASM_IS_PUNCT:
                        CMP             #'#'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #','
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'('
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #')'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'<'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'>'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'+'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'-'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'*'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'|'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'&'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'^'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #':'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'.'
                        BEQ             ASM_IS_PUNCT_YES
                        CMP             #'?'
                        BEQ             ASM_IS_PUNCT_YES
                        CLC
                        RTS
ASM_IS_PUNCT_YES:
                        SEC
                        RTS

ASM_IS_WORD_HEAD:
                        CMP             #'_'
                        BEQ             ASM_IS_WORD_YES
                        JSR             ASM_IS_ALPHA
                        RTS

ASM_IS_WORD_BODY:
                        JSR             ASM_IS_WORD_HEAD
                        BCS             ASM_IS_WORD_BODY_DONE
                        JSR             ASM_IS_DIGIT
ASM_IS_WORD_BODY_DONE:
                        RTS

ASM_IS_ALPHA:
                        CMP             #'A'
                        BCC             ASM_IS_ALPHA_LOWER
                        CMP             #'Z'+1
                        BCC             ASM_IS_WORD_YES
ASM_IS_ALPHA_LOWER:
                        CMP             #'a'
                        BCC             ASM_IS_WORD_NO
                        CMP             #'z'+1
                        BCS             ASM_IS_WORD_NO
ASM_IS_WORD_YES:
                        SEC
                        RTS
ASM_IS_WORD_NO:
                        CLC
                        RTS

ASM_IS_DIGIT:
                        CMP             #'0'
                        BCC             ASM_IS_DIGIT_NO
                        CMP             #'9'+1
                        BCS             ASM_IS_DIGIT_NO
                        SEC
                        RTS
ASM_IS_DIGIT_NO:
                        CLC
                        RTS

ASM_HEX_TO_NIBBLE:
                        CMP             #'0'
                        BCC             ASM_HEX_BAD
                        CMP             #'9'+1
                        BCC             ASM_HEX_DIGIT
                        CMP             #'A'
                        BCC             ASM_HEX_LOWER
                        CMP             #'F'+1
                        BCC             ASM_HEX_UPPER
ASM_HEX_LOWER:
                        CMP             #'a'
                        BCC             ASM_HEX_BAD
                        CMP             #'f'+1
                        BCS             ASM_HEX_BAD
                        SEC
                        SBC             #$57
                        SEC
                        RTS
ASM_HEX_UPPER:
                        SEC
                        SBC             #$37
                        SEC
                        RTS
ASM_HEX_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
ASM_HEX_BAD:
                        CLC
                        RTS

ASM_FOLD_UPPER_A:
                        CMP             #'a'
                        BCC             ASM_FOLD_UPPER_DONE
                        CMP             #'z'+1
                        BCS             ASM_FOLD_UPPER_DONE
                        SEC
                        SBC             #$20
ASM_FOLD_UPPER_DONE:
                        RTS

ASM_VALUE_SHL4:
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        RTS

ASM_BIN_SHIFT:
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_CARE_LO
                        ROL             ASM_CARE_HI
                        RTS

ASM_VALUE_MUL10_ADD_TMP0:
                        LDA             ASM_VALUE_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_TMP1_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_TMP1_LO
                        ROL             ASM_TMP1_HI
                        ASL             ASM_TMP1_LO
                        ROL             ASM_TMP1_HI
                        ASL             ASM_TMP1_LO
                        ROL             ASM_TMP1_HI
                        CLC
                        LDA             ASM_VALUE_LO
                        ADC             ASM_TMP1_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_VALUE_HI
                        ADC             ASM_TMP1_HI
                        STA             ASM_VALUE_HI
                        CLC
                        LDA             ASM_VALUE_LO
                        ADC             ASM_TMP0_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_VALUE_HI
                        ADC             #$00
                        STA             ASM_VALUE_HI
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
                        JSR             ASM_COPY_HASH_TO_TERM
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        JSR             ASM_ADD_TERM_TO_HASH
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        JSR             ASM_ADD_TERM_TO_HASH
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        JSR             ASM_ADD_TERM_TO_HASH
                        ASL             ASM_HASH_TMP0
                        ROL             ASM_HASH_TMP1
                        ROL             ASM_HASH_TMP2
                        ROL             ASM_HASH_TMP3
                        JSR             ASM_ADD_TERM_TO_HASH
                        JMP             ASM_ADD_TERM1_TO_HASH3

ASM_COPY_HASH_TO_TERM:
                        LDX             #$03
ASM_COPY_HASH_LOOP:
                        LDA             ASM_HASH0,X
                        STA             ASM_HASH_TMP0,X
                        DEX
                        BPL             ASM_COPY_HASH_LOOP
                        RTS

ASM_ADD_TERM_TO_HASH:
                        CLC
                        LDA             ASM_HASH0
                        ADC             ASM_HASH_TMP0
                        STA             ASM_HASH0
                        LDA             ASM_HASH1
                        ADC             ASM_HASH_TMP1
                        STA             ASM_HASH1
                        LDA             ASM_HASH2
                        ADC             ASM_HASH_TMP2
                        STA             ASM_HASH2
                        LDA             ASM_HASH3
                        ADC             ASM_HASH_TMP3
                        STA             ASM_HASH3
                        RTS

ASM_ADD_TERM1_TO_HASH3:
                        LDA             ASM_HASH3
                        CLC
                        ADC             ASM_HASH_TMP1
                        STA             ASM_HASH3
                        RTS

ASM_FNV1A_OFFSET_BASIS:
                        DB              $C5,$9D,$1C,$81

; ----------------------------------------------------------------------------
; Internal session clear.
; ----------------------------------------------------------------------------
ASM_CLEAR_SESSION:
                        STZ             ASM_SESSION_STATE
                        STZ             ASM_LAST_STATUS
                        STZ             ASM_LINE_COUNT_LO
                        STZ             ASM_LINE_COUNT_HI
                        STZ             ASM_SYM_COUNT
                        STZ             ASM_FIX_COUNT
                        STZ             ASM_REF_COUNT
                        STZ             ASM_REPORT_FLAGS
                        RTS

                        DATA

ASM_SESSION_STATE:     DB              $00
ASM_LAST_STATUS:       DB              $00
ASM_LINE_COUNT_LO:     DB              $00
ASM_LINE_COUNT_HI:     DB              $00
ASM_PC_LO:             DB              $00
ASM_PC_HI:             DB              $00
ASM_START_PC_LO:       DB              $00
ASM_START_PC_HI:       DB              $00
ASM_HIGH_PC_LO:        DB              $00
ASM_HIGH_PC_HI:        DB              $00
ASM_SYM_COUNT:         DB              $00
ASM_FIX_COUNT:         DB              $00
ASM_REF_COUNT:         DB              $00
ASM_REPORT_FLAGS:      DB              $00
ASM_STMT_KIND:         DB              $00
ASM_STMT_FLAGS:        DB              $00
ASM_STMT_NAME_PTR_LO:  DB              $00
ASM_STMT_NAME_PTR_HI:  DB              $00
ASM_STMT_NAME_LEN:     DB              $00
ASM_STMT_NAME_HASH0:   DB              $00
ASM_STMT_NAME_HASH1:   DB              $00
ASM_STMT_NAME_HASH2:   DB              $00
ASM_STMT_NAME_HASH3:   DB              $00
ASM_STMT_VOC_SLOT:     DB              $00
ASM_STMT_OP_KIND:      DB              $00
ASM_STMT_OP_ID:        DB              $00
ASM_STMT_TAIL_PTR_LO:  DB              $00
ASM_STMT_TAIL_PTR_HI:  DB              $00
ASM_STMT_STATUS:       DB              $00
ASM_SYM_STATE:         DS              ASM_SYM_MAX
ASM_SYM_FLAGS:         DS              ASM_SYM_MAX
ASM_SYM_KIND:          DS              ASM_SYM_MAX
ASM_SYM_WIDTH:         DS              ASM_SYM_MAX
ASM_SYM_VAL_LO:        DS              ASM_SYM_MAX
ASM_SYM_VAL_HI:        DS              ASM_SYM_MAX
ASM_SYM_CARE_LO:       DS              ASM_SYM_MAX
ASM_SYM_CARE_HI:       DS              ASM_SYM_MAX
ASM_SYM_HASH0:         DS              ASM_SYM_MAX
ASM_SYM_HASH1:         DS              ASM_SYM_MAX
ASM_SYM_HASH2:         DS              ASM_SYM_MAX
ASM_SYM_HASH3:         DS              ASM_SYM_MAX
ASM_SYM_NAME_LEN:      DS              ASM_SYM_MAX
ASM_SYM_USECNT:        DS              ASM_SYM_MAX
ASM_SYM_FIRSTREF_LO:   DS              ASM_SYM_MAX
ASM_SYM_FIRSTREF_HI:   DS              ASM_SYM_MAX
ASM_SYM_NAMES:         DS              (ASM_SYM_MAX*ASM_SYM_NAME_MAX)

ASM_SMOKE_LINE_OK:     DB              "ORG $3000",0
ASM_SMOKE_LINE_TOKENS: DB              "LABEL: LDA #1",0
ASM_SMOKE_LINE_CHAR:   DB              "'a'",0
ASM_SMOKE_LINE_MASK:   DB              "%XXXXXXX1",0
ASM_SMOKE_VOC_LDA:     DB              "LDA",0
ASM_SMOKE_VOC_DC:      DB              "DC",0
ASM_SMOKE_VOC_A:       DB              "A",0
ASM_SMOKE_VOC_START:   DB              "START",0
ASM_SMOKE_VOC_FOO:     DB              "FOO",0
ASM_SMOKE_PARSE_BLANK: DB              "   ; comment",0
ASM_SMOKE_PARSE_LABEL: DB              "LABEL",0
ASM_SMOKE_PARSE_LABEL_COLON:
                        DB              "LABEL:",0
ASM_SMOKE_PARSE_LDA:   DB              "LDA #1",0
ASM_SMOKE_PARSE_LABEL_LDA:
                        DB              "LABEL: LDA #1",0
ASM_SMOKE_PARSE_EQU:   DB              "NAME EQU $12",0
ASM_SMOKE_PARSE_ORG:   DB              "ORG $3000",0
ASM_SMOKE_PARSE_END:   DB              "END",0
ASM_SMOKE_PARSE_LABEL_ORG:
                        DB              "LABEL ORG $3000",0
ASM_SMOKE_PARSE_END_TAIL:
                        DB              "END X",0
ASM_SMOKE_PARSE_START: DB              "START",0
ASM_SMOKE_SYM_LABEL:   DB              "LABEL",0
ASM_SMOKE_SYM_FOO_EQU: DB              "FOO EQU $12",0
ASM_SMOKE_SYM_ADDR_EQU:
                        DB              "ADDR EQU $0012",0
ASM_SMOKE_SYM_COUNT_EQU:
                        DB              "COUNT EQU 10",0
ASM_SMOKE_SYM_ERR_EQU:
                        DB              "ERR EQU %XXXXXXX1",0
ASM_SMOKE_SYM_NOPE:    DB              "NOPE",0
ASM_HASH_THE_JOIN_EXEC_XY:
                        DB              $F7,$15,$AF,$A9
ASM_HASH_BIO_WRITE_BYTE_BLOCK:
                        DB              $30,$E9,$9F,$37
ASM_SMOKE_MSG_PASS:    DB              "ASM 1.70 RJOIN OK W=$",0
ASM_SMOKE_MSG_SYM:     DB              " SYM=$",0
ASM_SMOKE_MSG_PC:      DB              " PC=$",0
ASM_SMOKE_LINE_LONG:
                        DB              "12345678901234567890123456789012"
                        DB              "34567890123456789012345678901234",0

; Vocabulary slots are canonical-token sorted:
; A ADC AND ASL BBR BBS BCC BCS BEQ BIT BMI BNE BPL BRA BRK BVC BVS CLC
; CLD CLI CLV CMP CPX CPY DC DEC DEX DEY DS END ENTRY EOR EQU EXTRN INC
; INX INY JMP JSR LDA LDX LDY LSR NOP ORA ORG PHA PHP PHX PHY PLA PLP
; PLX PLY RMB ROL ROR RTI RTS SBC SEC SED SEI SMB STA START STP STX STY
; STZ TAX TAY TRB TSB TSX TXA TXS TYA WAI X Y.
ASM_VOC_HASH0:         DB              $CC,$41,$C6,$93,$35,$A2,$63,$33,$C3,$50,$43,$BC,$B9,$DC,$9A,$DE
                        DB              $0E,$1B,$FA,$A9,$A4,$47,$FA,$8D,$F0,$F3,$4E,$E1,$C0,$0A,$33,$1D
                        DB              $62,$F4,$67,$32,$C5,$E0,$48,$34,$FF,$6C,$4E,$5E,$9F,$79,$4C,$0F
                        DB              $A7,$14,$A8,$0B,$73,$E0,$1E,$66,$54,$0E,$20,$D9,$92,$B3,$04,$6D
                        DB              $39,$3F,$D6,$6E,$01,$48,$5A,$ED,$13,$76,$B8,$40,$96,$7D,$B4,$27
                        DB              $94
ASM_VOC_HASH1:         DB              $F6,$57,$6D,$75,$D2,$D0,$03,$EA,$77,$F6,$25,$6D,$54,$5A,$6A,$3D
                        DB              $57,$5E,$65,$54,$49,$F3,$21,$23,$73,$FA,$22,$23,$5A,$92,$1E,$F0
                        DB              $E2,$59,$B3,$8F,$90,$0A,$45,$D9,$B4,$B3,$7B,$41,$0A,$07,$BA,$D5
                        DB              $E1,$E0,$D0,$B9,$AC,$AA,$68,$10,$39,$3A,$11,$1B,$71,$69,$7B,$46
                        DB              $D4,$A6,$EB,$F8,$FA,$F5,$02,$03,$3C,$91,$81,$CF,$EB,$8E,$8F,$1E
                        DB              $1C
ASM_VOC_HASH2:         DB              $0B,$75,$66,$AD,$74,$74,$73,$72,$63,$81,$77,$7F,$97,$9C,$9C,$93
                        DB              $93,$6A,$6A,$6A,$6A,$6C,$25,$25,$CE,$0E,$0F,$0F,$CE,$43,$41,$45
                        DB              $4B,$21,$C3,$C3,$C3,$85,$80,$47,$47,$47,$5D,$EE,$F8,$F8,$F9,$F9
                        DB              $F9,$F9,$EF,$EF,$EF,$EF,$E2,$E8,$E8,$AA,$AA,$F0,$01,$01,$01,$15
                        DB              $25,$94,$25,$25,$25,$25,$34,$34,$58,$56,$56,$71,$71,$6E,$1F,$0C
                        DB              $0C
ASM_VOC_HASH3:         DB              $C4,$7C,$91,$57,$AD,$AC,$F4,$E4,$A2,$E5,$BA,$B6,$A3,$FA,$04,$E4
                        DB              $F4,$56,$5B,$50,$49,$8D,$47,$48,$35,$47,$60,$61,$25,$AF,$A2,$C3
                        DB              $B0,$6F,$EB,$D4,$D5,$48,$1A,$E4,$CD,$CC,$CD,$A7,$E0,$DE,$8E,$9F
                        DB              $A7,$A6,$F6,$E7,$DF,$DE,$B1,$6F,$89,$CC,$B2,$35,$3E,$39,$44,$6F
                        DB              $F8,$0D,$07,$0F,$10,$0D,$35,$36,$D5,$33,$29,$D2,$E4,$2E,$AF,$DD
                        DB              $DC
ASM_VOC_KIND_TAB:      DB              $03,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
                        DB              $01,$01,$01,$01,$01,$01,$01,$01,$02,$01,$01,$01,$02,$02,$04,$01
                        DB              $02,$04,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$01,$01
                        DB              $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
                        DB              $01,$04,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$03
                        DB              $03

ASM_CODE_BUF:          DS              $0200

                        ENDMOD
                        END

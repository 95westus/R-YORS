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

                        IF              ASM_RUNTIME_ONLY
                        ELSE
                        XDEF            START
                        XDEF            ASM_REPL
                        ENDIF
                        XDEF            ASM_BEGIN
                        XDEF            ASM_END
                        XDEF            ASM_ASSEMBLE_LINE
                        XDEF            ASM_LEX_LINE
                        XDEF            ASM_NEXT_TOKEN
                        XDEF            ASM_LOOKUP_WORD
                        XDEF            ASM_PARSE_HEAD
                        XDEF            ASM_DISPATCH_STATEMENT
                        XDEF            ASM_PARSE_EXPR
                        XDEF            ASM_CLASS_OPERAND
                        XDEF            ASM_EMIT_BYTE
                        XDEF            ASM_EMIT_WORD_LE
                        XDEF            ASM_FIND_OPCODE
                        XDEF            ASM_EMIT
                        XDEF            ASM_LOOKUP_SYMBOL
                        XDEF            ASM_BIND_LABEL
                        XDEF            ASM_DEFINE_EQU
                        XDEF            ASM_PRINT_TABLES
                        XDEF            ASM_SEAL_VALIDATE
                        XDEF            ASM_SEAL_COMPUTE_FNV
                        XDEF            ASM_SEAL_PRINT_RECORD
                        XDEF            ASM_SEAL_RESOLVE_IMPORTS
                        XDEF            ASM_SEAL_RELOCATE
                        IF              ASM_PACKAGE_ENABLED
                        XDEF            ASM_SEAL_PACKAGE
                        IF              ASM_PACKAGE_CHECK_ENABLED
                        XDEF            ASM_SEAL_CHECK_PACKAGE
                        ENDIF
                        ENDIF
                        XDEF            ASM_RJ_WRITE_CSTRING
                        XDEF            ASM_RJ_WRITE_HEX_BYTE
                        XDEF            ASM_RJ_PRINT_CRLF
                        XDEF            ASM_SEAL_REC
                        XDEF            ASM_SEAL_REC_END
                        XDEF            ASM_SEAL_FLAGS
                        XDEF            ASM_SEAL_BASE_LO
                        XDEF            ASM_SEAL_BASE_HI
                        XDEF            ASM_SEAL_END_LO
                        XDEF            ASM_SEAL_END_HI
                        XDEF            ASM_SEAL_LEN_LO
                        XDEF            ASM_SEAL_LEN_HI
                        XDEF            ASM_SEAL_FNV0
                        XDEF            ASM_SEAL_FNV1
                        XDEF            ASM_SEAL_FNV2
                        XDEF            ASM_SEAL_FNV3
                        XDEF            ASM_RELOC_REC
                        XDEF            ASM_RELOC_REC_END
                        XDEF            ASM_RELOC_COUNT
                        XDEF            ASM_RELOC_KIND
                        XDEF            ASM_RELOC_SITE_LO
                        XDEF            ASM_RELOC_SITE_HI
                        XDEF            ASM_RELOC_TARGET_LO
                        XDEF            ASM_RELOC_TARGET_HI
                        XDEF            ASM_EXPORT_REC
                        XDEF            ASM_EXPORT_REC_END
                        XDEF            ASM_EXPORT_REC_COUNT
                        XDEF            ASM_EXPORT_REC_LEN
                        XDEF            ASM_IMPORT_REC
                        XDEF            ASM_IMPORT_REC_END
                        XDEF            ASM_IMPORT_REC_COUNT
                        XDEF            ASM_IMPORT_REC_LEN
                        XDEF            ASM_IMPORT_RESOLVE_COUNT
                        XDEF            ASM_RELOCATE_BASE_LO
                        XDEF            ASM_RELOCATE_BASE_HI
                        XDEF            ASM_RELOCATE_COUNT
                        IF              ASM_PACKAGE_ENABLED
                        XDEF            ASM_PACKAGE_BASE_LO
                        XDEF            ASM_PACKAGE_BASE_HI
                        XDEF            ASM_PACKAGE_LEN_LO
                        XDEF            ASM_PACKAGE_LEN_HI
                        ENDIF
                        XDEF            ASM_PARSE_EXPR_REQUIRE_END
                        IF              ASM_RUNTIME_ONLY
                        IF              ASM_FLASH_RUNTIME
                        XDEF            ASM_RJOIN_INIT_IO
                        XDEF            ASM_RJ_READ_CSTRING
                        ENDIF
                        ELSE
                        XDEF            ASM_RJOIN_INIT_IO
                        XDEF            ASM_RJ_READ_CSTRING
                        ENDIF

; ----------------------------------------------------------------------------
; ASM active zero-page frame, allocated downward from $AF, plus shared FNV ZP.
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
ASM_HASH0              EQU             $B0
ASM_HASH1              EQU             $B1
ASM_HASH2              EQU             $B2
ASM_HASH3              EQU             $B3
ASM_HASH_TMP0          EQU             $C7
ASM_HASH_TMP1          EQU             $C8
ASM_HASH_TMP2          EQU             $C9
ASM_HASH_TMP3          EQU             $CA
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

ASM_RJ_JOIN_LO        EQU             ASM_FIX_PTR_LO
ASM_RJ_JOIN_HI        EQU             ASM_FIX_PTR_HI
ASM_RJ_HASH_PTR_LO    EQU             ASM_REF_PTR_LO
ASM_RJ_HASH_PTR_HI    EQU             ASM_REF_PTR_HI
ASM_RJ_STR_LO         EQU             ASM_TMP0_LO
ASM_RJ_STR_HI         EQU             ASM_TMP0_HI

ASM_SEED_HASH_ACQUIRE_LO EQU          $7E00
ASM_SEED_HASH_ACQUIRE_HI EQU          $7E01
ASM_SEED_ROM_MIN_HI      EQU          $C0

ASM_TOK_KIND          EQU             ASM_MODE
ASM_TOK_SUB           EQU             ASM_WIDTH
ASM_TOK_FLAGS         EQU             ASM_FLAGS
ASM_VOC_ID            EQU             ASM_VALUE_LO
ASM_VOC_DISP          EQU             ASM_VALUE_HI
ASM_VOC_FLAGS         EQU             ASM_CARE_LO
ASM_VOC_AUX           EQU             ASM_CARE_HI
ASM_PACKAGE_SEAL_LEN_LO EQU           ASM_CARE_LO
ASM_PACKAGE_SEAL_LEN_HI EQU           ASM_CARE_HI

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
ASM_STATUS_RJOIN       EQU             $0B

ASM_SEAL_STATUS_NO_END EQU             $01
ASM_SEAL_STATUS_BAD_FLAGS EQU          $02

ASM_STEP_BEGIN         EQU             $10
ASM_STEP_LEX_OK        EQU             $20
ASM_STEP_TOKENS        EQU             $30
ASM_STEP_VOCAB         EQU             $40
ASM_STEP_PARSE         EQU             $50
ASM_STEP_EXPR          EQU             $56
ASM_STEP_ASSEMBLE_LINE EQU             $58
ASM_STEP_EMIT          EQU             $59
ASM_STEP_OPERAND       EQU             $5A
ASM_STEP_OPCODE        EQU             $5B
ASM_STEP_FIXUPS        EQU             $5C
ASM_STEP_DIRECTIVE     EQU             $5D
ASM_STEP_REPORT        EQU             $5E
ASM_STEP_SYMBOLS       EQU             $60
ASM_STEP_ASMTEST       EQU             $70
ASM_STEP_RJOIN_JOINER  EQU             $71
ASM_STEP_RJOIN_WRITE   EQU             $72
ASM_STEP_RJOIN_READ    EQU             $73
ASM_STEP_RJOIN_FNV_INIT EQU            $74
ASM_STEP_RJOIN_FNV_UPDATE EQU          $75
ASM_STEP_RJOIN_HEX_NIB EQU             $76
ASM_STEP_LONG_LINE     EQU             $80
ASM_STEP_END           EQU             $90

ASM_BEGINF_HAVE_PC     EQU             $01

ASM_SMOKE_TARGET       EQU             $7000
ASM_SMOKE_TARGET_LO    EQU             $00
ASM_SMOKE_TARGET_HI    EQU             $70
ASM_SMOKE_TARGET_FWD_LO EQU            $10
ASM_SMOKE_TARGET_BACK_LO EQU           $0F
ASM_SMOKE_DATA_HI      EQU             $71
ASM_TARGET_LIMIT_HI    EQU             $7E
ASM_TARGET_MAX_HI      EQU             $7D
ASM_TARGET_THIRD_ADDR  EQU             $7DFD
ASM_TARGET_PENULT_ADDR EQU             $7DFE
ASM_TARGET_LAST_ADDR   EQU             $7DFF
ASM_TARGET_GUARD_LO    EQU             $00
                        IF              ASM_FLASH_RUNTIME
ASM_TARGET_GUARD_HI    EQU             $60
                        ELSE
ASM_TARGET_GUARD_HI    EQU             $20
                        ENDIF

ASM_SESS_IDLE          EQU             $00
ASM_SESS_ACTIVE        EQU             $01
ASM_SESS_ENDED         EQU             $02
ASM_SESS_FAILED        EQU             $03

ASM_REPORTF_ORG_SEEN   EQU             $01
ASM_REPORTF_WARN_DS_WRAP EQU           $02
ASM_REPORTF_PRINT_END  EQU             $04
ASM_REPORTF_PRINTED    EQU             $08
ASM_REPORTF_PRINT_FAIL EQU             $10
ASM_REPORTF_TRUNC      EQU             $20

ASM_SEALF_VALID        EQU             $01
ASM_SEALF_HOLE         EQU             $02
ASM_SEALF_UNOWNED      EQU             $04
ASM_SEALF_RELOC_TRUNC  EQU             $08
ASM_SEALF_RELOC_BAD    EQU             $10

ASM_SEAL_REC_BYTES     EQU             $0B
ASM_SEAL_REC_OFF_FLAGS EQU             $00
ASM_SEAL_REC_OFF_BASE  EQU             $01
ASM_SEAL_REC_OFF_END   EQU             $03
ASM_SEAL_REC_OFF_LEN   EQU             $05
ASM_SEAL_REC_OFF_FNV   EQU             $07
ASM_EXPORT_REC_OFF_COUNT EQU           $00
ASM_EXPORT_REC_OFF_LEN EQU             $01
ASM_EXPORT_REC_OFF_BODY EQU            $02
ASM_IMPORT_REC_OFF_COUNT EQU           $00
ASM_IMPORT_REC_OFF_LEN EQU             $01
ASM_IMPORT_REC_OFF_BODY EQU            $02
ASM_PACKAGE_HDR_BYTES  EQU             $05
ASM_PACKAGE_FIXED_BYTES EQU            $1B
ASM_PACKAGE_VERSION    EQU             $01
ASM_PACKAGE_SIG0       EQU             'A'
ASM_PACKAGE_SIG1       EQU             'P'
ASM_PACKAGE_TAG_SEAL   EQU             'S'
ASM_PACKAGE_TAG_RELOC  EQU             'R'
ASM_PACKAGE_TAG_EXPORT EQU             'E'
ASM_PACKAGE_TAG_IMPORT EQU             'I'
ASM_PACKAGE_TAG_BODY   EQU             'B'
ASM_PACKAGE_OFF_SIG0   EQU             $00
ASM_PACKAGE_OFF_SIG1   EQU             $01
ASM_PACKAGE_OFF_VER    EQU             $02
ASM_PACKAGE_OFF_TOTAL  EQU             $03

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
ASM_STMTF_LOCAL_NAME  EQU             $40

ASM_SYM_LOOK_SESSION   EQU             $01
ASM_SYM_LOOK_LOCAL     EQU             $02
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

ASM_OPM_NONE           EQU             $00
ASM_OPM_ACC            EQU             $01
ASM_OPM_IMM8           EQU             $02
ASM_OPM_ZP8            EQU             $03
ASM_OPM_ABS16          EQU             $04
ASM_OPM_ZP_X           EQU             $05
ASM_OPM_ABS_X          EQU             $06
ASM_OPM_REL8           EQU             $07
ASM_OPM_ZP_Y           EQU             $08
ASM_OPM_ABS_Y          EQU             $09
ASM_OPM_ZP_IND         EQU             $0A
ASM_OPM_ZP_X_IND       EQU             $0B
ASM_OPM_ZP_IND_Y       EQU             $0C
ASM_OPM_ABS_IND        EQU             $0D
ASM_OPM_ABS_X_IND      EQU             $0E
ASM_OPM_BIT_ZP         EQU             $0F
ASM_OPM_BIT_ZP_REL     EQU             $10

ASM_OPF_UNRESOLVED     EQU             $01
ASM_OPF_RELOC_INTERNAL EQU             $02

ASM_ATOM_REG           EQU             $80

ASM_FIX_SEL_FULL       EQU             $00
ASM_FIX_SEL_LO         EQU             $01
ASM_FIX_SEL_HI         EQU             $02
ASM_FIX_SEL_MASK       EQU             $03
ASM_FIXF_IMPORT        EQU             $40
ASM_FIXF_LOCAL         EQU             $80

ASM_FIX_PENDING        EQU             $01
ASM_FIX_RESOLVED       EQU             $02
ASM_FIX_IMPORTED       EQU             $04
ASM_FIX_FAILED         EQU             $80

ASM_LINE_MAX           EQU             $3F
ASM_SYM_MAX            EQU             $28
ASM_SYM_NAME_MAX       EQU             $20
ASM_FIX_MAX            EQU             $60
ASM_FIX_NAME_MAX       EQU             $20
ASM_FIX_NAME_BYTES     EQU             (ASM_FIX_MAX*ASM_FIX_NAME_MAX)
ASM_RELOC_MAX          EQU             $10
ASM_RELOC_ABS16_INTERNAL EQU           $01
ASM_RELOC_LO8_INTERNAL EQU             $02
ASM_RELOC_HI8_INTERNAL EQU             $03
ASM_RELOC_ABS16_IMPORT EQU             $04
ASM_RELOC_LO8_IMPORT EQU               $05
ASM_RELOC_HI8_IMPORT EQU               $06
ASM_EXPORT_MAX         EQU             $08
ASM_EXPORT_NAME_PACK_MAX EQU           $16
ASM_EXPORT_ROW_MAX     EQU             $19
ASM_EXPORT_REC_BODY_MAX EQU            (ASM_EXPORT_MAX*ASM_EXPORT_ROW_MAX)
ASM_IMPORT_MAX         EQU             $08
ASM_IMPORT_ROW_MAX     EQU             (1+ASM_EXPORT_NAME_PACK_MAX)
ASM_IMPORT_REC_BODY_MAX EQU            (ASM_IMPORT_MAX*ASM_IMPORT_ROW_MAX)
ASM_REF_MAX            EQU             $A0
ASM_LOCAL_MAX          EQU             $10
ASM_LOCAL_NAME_MAX     EQU             $10
ASM_LOCAL_NAME_BYTES   EQU             (ASM_LOCAL_MAX*ASM_LOCAL_NAME_MAX)
ASM_VOC_COUNT          EQU             $53

ASM_VID_DB             EQU             $18
ASM_VID_DC             EQU             $19
ASM_VID_DS             EQU             $1D
ASM_VID_DW             EQU             $1E
ASM_VID_END            EQU             $1F
ASM_VID_IMPORT         EQU             $20
ASM_VID_EXPORT         EQU             $23
ASM_VID_EQU            EQU             $22
ASM_VID_ORG            EQU             $2F
ASM_VID_ADC            EQU             $01
ASM_VID_AND            EQU             $02
ASM_VID_ASL            EQU             $03
ASM_VID_BBR            EQU             $04
ASM_VID_BBS            EQU             $05
ASM_VID_BCC            EQU             $06
ASM_VID_BCS            EQU             $07
ASM_VID_BEQ            EQU             $08
ASM_VID_BIT            EQU             $09
ASM_VID_BMI            EQU             $0A
ASM_VID_BNE            EQU             $0B
ASM_VID_BPL            EQU             $0C
ASM_VID_BRA            EQU             $0D
ASM_VID_BRK            EQU             $0E
ASM_VID_BVC            EQU             $0F
ASM_VID_BVS            EQU             $10
ASM_VID_CLC            EQU             $11
ASM_VID_CLD            EQU             $12
ASM_VID_CLI            EQU             $13
ASM_VID_CLV            EQU             $14
ASM_VID_CMP            EQU             $15
ASM_VID_CPX            EQU             $16
ASM_VID_CPY            EQU             $17
ASM_VID_DEC            EQU             $1A
ASM_VID_DEX            EQU             $1B
ASM_VID_DEY            EQU             $1C
ASM_VID_EOR            EQU             $21
ASM_VID_INC            EQU             $24
ASM_VID_INX            EQU             $25
ASM_VID_INY            EQU             $26
ASM_VID_JMP            EQU             $27
ASM_VID_JSR            EQU             $28
ASM_VID_LDA            EQU             $29
ASM_VID_LDX            EQU             $2A
ASM_VID_LDY            EQU             $2B
ASM_VID_LSR            EQU             $2C
ASM_VID_NOP            EQU             $2D
ASM_VID_ORA            EQU             $2E
ASM_VID_PHA            EQU             $30
ASM_VID_PHP            EQU             $31
ASM_VID_PHX            EQU             $32
ASM_VID_PHY            EQU             $33
ASM_VID_PLA            EQU             $34
ASM_VID_PLP            EQU             $35
ASM_VID_PLX            EQU             $36
ASM_VID_PLY            EQU             $37
ASM_VID_RMB            EQU             $38
ASM_VID_ROL            EQU             $39
ASM_VID_ROR            EQU             $3A
ASM_VID_RTI            EQU             $3B
ASM_VID_RTS            EQU             $3C
ASM_VID_SBC            EQU             $3D
ASM_VID_SEC            EQU             $3E
ASM_VID_SED            EQU             $3F
ASM_VID_SEI            EQU             $40
ASM_VID_SMB            EQU             $41
ASM_VID_STA            EQU             $42
ASM_VID_STP            EQU             $44
ASM_VID_STX            EQU             $45
ASM_VID_STY            EQU             $46
ASM_VID_STZ            EQU             $47
ASM_VID_TAX            EQU             $48
ASM_VID_TAY            EQU             $49
ASM_VID_TRB            EQU             $4A
ASM_VID_TSB            EQU             $4B
ASM_VID_TSX            EQU             $4C
ASM_VID_TXA            EQU             $4D
ASM_VID_TXS            EQU             $4E
ASM_VID_TYA            EQU             $4F
ASM_VID_WAI            EQU             $50
ASM_VID_REG_A          EQU             $00
ASM_VID_REG_X          EQU             $51
ASM_VID_REG_Y          EQU             $52

                        CODE

                        IF              ASM_RUNTIME_ONLY
                        ELSE

; ----------------------------------------------------------------------------
; START
; Tiny smoke entry for the standalone S19 target.
; OUT: C=1 if the standalone smoke ladder passes. A=OK, X/Y=current PC.
;      C=0 with A=stage, X=status, Y=slot when a stage fails.
; ----------------------------------------------------------------------------
START:
                        STZ             ASM_SMOKE_REPORT_FLAGS
                        LDA             #$01
                        STA             ASM_RJ_PROGRESS
                        JSR             ASM_RJOIN_INIT
                        BCS             START_RJOIN_OK
                        STZ             ASM_RJ_PROGRESS
                        LDA             #ASM_STATUS_RJOIN
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        JMP             START_FAIL
START_RJOIN_OK:
                        STZ             ASM_RJ_PROGRESS
                        LDX             #<ASM_SMOKE_MSG_RUN
                        LDY             #>ASM_SMOKE_MSG_RUN
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDA             #ASM_STEP_BEGIN
                        LDX             #<ASM_SMOKE_MSG_T_BEGIN
                        LDY             #>ASM_SMOKE_MSG_T_BEGIN
                        JSR             ASM_SMOKE_PROGRESS
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCS             START_BEGIN_OK
                        JMP             START_FAIL
START_BEGIN_OK:

                        LDA             #ASM_STEP_LEX_OK
                        LDX             #<ASM_SMOKE_MSG_T_LEX
                        LDY             #>ASM_SMOKE_MSG_T_LEX
                        JSR             ASM_SMOKE_PROGRESS
                        LDX             #<ASM_SMOKE_LINE_OK
                        LDY             #>ASM_SMOKE_LINE_OK
                        JSR             ASM_LEX_LINE
                        BCS             START_LEX_OK
                        JMP             START_FAIL
START_LEX_OK:
                        LDA             #ASM_STEP_TOKENS
                        LDX             #<ASM_SMOKE_MSG_T_TOKENS
                        LDY             #>ASM_SMOKE_MSG_T_TOKENS
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_TOKENS
                        BCS             START_TOKENS_OK
                        JMP             START_FAIL
START_TOKENS_OK:
                        LDA             #ASM_STEP_VOCAB
                        LDX             #<ASM_SMOKE_MSG_T_VOCAB
                        LDY             #>ASM_SMOKE_MSG_T_VOCAB
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_VOCAB
                        BCS             START_VOCAB_OK
                        JMP             START_FAIL
START_VOCAB_OK:
                        LDA             #ASM_STEP_PARSE
                        LDX             #<ASM_SMOKE_MSG_T_PARSE
                        LDY             #>ASM_SMOKE_MSG_T_PARSE
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_PARSE
                        BCS             START_PARSE_OK
                        JMP             START_FAIL
START_PARSE_OK:
                        LDA             #ASM_STEP_EXPR
                        LDX             #<ASM_SMOKE_MSG_T_EXPR
                        LDY             #>ASM_SMOKE_MSG_T_EXPR
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_EXPR
                        BCS             START_EXPR_OK
                        JMP             START_FAIL
START_EXPR_OK:
                        LDA             #ASM_STEP_ASSEMBLE_LINE
                        LDX             #<ASM_SMOKE_MSG_T_LINE
                        LDY             #>ASM_SMOKE_MSG_T_LINE
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_ASSEMBLE_LINE
                        BCS             START_ASSEMBLE_LINE_OK
                        JMP             START_FAIL
START_ASSEMBLE_LINE_OK:
                        LDA             #ASM_STEP_EMIT
                        LDX             #<ASM_SMOKE_MSG_T_EMIT
                        LDY             #>ASM_SMOKE_MSG_T_EMIT
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_EMIT
                        BCS             START_EMIT_OK
                        JMP             START_FAIL
START_EMIT_OK:
                        LDA             #ASM_STEP_OPERAND
                        LDX             #<ASM_SMOKE_MSG_T_OPER
                        LDY             #>ASM_SMOKE_MSG_T_OPER
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_OPERANDS
                        BCS             START_OPERAND_OK
                        JMP             START_FAIL
START_OPERAND_OK:
                        LDA             #ASM_STEP_OPCODE
                        LDX             #<ASM_SMOKE_MSG_T_OPCODE
                        LDY             #>ASM_SMOKE_MSG_T_OPCODE
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_OPCODE
                        BCS             START_OPCODE_OK
                        JMP             START_FAIL
START_OPCODE_OK:
                        LDA             #ASM_STEP_FIXUPS
                        LDX             #<ASM_SMOKE_MSG_T_FIXUPS
                        LDY             #>ASM_SMOKE_MSG_T_FIXUPS
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_FIXUPS
                        BCS             START_FIXUPS_OK
                        JMP             START_FAIL
START_FIXUPS_OK:
                        LDA             #ASM_STEP_DIRECTIVE
                        LDX             #<ASM_SMOKE_MSG_T_DIRECT
                        LDY             #>ASM_SMOKE_MSG_T_DIRECT
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_DIRECTIVES
                        BCS             START_DIRECTIVES_OK
                        JMP             START_FAIL
START_DIRECTIVES_OK:
                        LDA             #ASM_STEP_REPORT
                        LDX             #<ASM_SMOKE_MSG_T_REPORT
                        LDY             #>ASM_SMOKE_MSG_T_REPORT
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_REPORT
                        BCS             START_REPORT_OK
                        JMP             START_FAIL
START_REPORT_OK:
                        LDA             #ASM_STEP_SYMBOLS
                        LDX             #<ASM_SMOKE_MSG_T_SYMBOLS
                        LDY             #>ASM_SMOKE_MSG_T_SYMBOLS
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_SYMBOLS
                        BCS             START_SYMBOLS_OK
                        JMP             START_FAIL
START_SYMBOLS_OK:
                        LDA             #ASM_STEP_ASMTEST
                        LDX             #<ASM_SMOKE_MSG_T_ASMTEST
                        LDY             #>ASM_SMOKE_MSG_T_ASMTEST
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_SMOKE_ASMTEST_3000
                        BCS             START_ASMTEST_OK
                        JMP             START_FAIL
START_ASMTEST_OK:

                        LDA             #ASM_STEP_LONG_LINE
                        LDX             #<ASM_SMOKE_MSG_T_LONG
                        LDY             #>ASM_SMOKE_MSG_T_LONG
                        JSR             ASM_SMOKE_PROGRESS
                        LDX             #<ASM_SMOKE_LINE_LONG
                        LDY             #>ASM_SMOKE_LINE_LONG
                        JSR             ASM_LEX_LINE
                        BCC             START_LONG_REJECTED
                        JMP             START_FAIL
START_LONG_REJECTED:
                        CMP             #ASM_STATUS_BAD_LINE
                        BEQ             START_LONG_STATUS_OK
                        JMP             START_FAIL
START_LONG_STATUS_OK:

                        LDA             #ASM_STEP_END
                        LDX             #<ASM_SMOKE_MSG_T_END
                        LDY             #>ASM_SMOKE_MSG_T_END
                        JSR             ASM_SMOKE_PROGRESS
                        JSR             ASM_END
                        BCS             START_END_OK
                        JMP             START_FAIL
START_END_OK:
                        PHA
                        PHX
                        PHY
                        JSR             ASM_RJOIN_INIT
                        BCS             START_PRINT_READY
                        JMP             START_PRINT_FAIL
START_PRINT_READY:
                        JSR             ASM_SMOKE_PRINT_PASS
                        PLY
                        PLX
                        PLA
                        SEC
                        RTS
START_PRINT_FAIL:
                        PLY
                        PLX
                        PLA
                        BRA             START_FAIL
START_FAIL:
                        LDA             ASM_START_STEP
                        STA             ASM_FAIL_STEP
                        LDA             ASM_STATUS
                        STA             ASM_FAIL_STATUS
                        LDA             ASM_SLOT
                        STA             ASM_FAIL_SLOT
                        JSR             ASM_RJOIN_INIT
                        BCC             START_FAIL_RETURN
                        JSR             ASM_SMOKE_PRINT_FAIL
START_FAIL_RETURN:
                        LDA             ASM_FAIL_STEP
                        LDX             ASM_FAIL_STATUS
                        LDY             ASM_FAIL_SLOT
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ASM_REPL / ICO
; Resident Input-Calc-Output assembler console. Reads through the ROM edit-line
; service, assembles at ASM_SMOKE_TARGET, and prints the new PC plus emitted
; bytes. A single "." line exits.
; ----------------------------------------------------------------------------
ASM_REPL:
                        JSR             ASM_RJOIN_INIT_IO
                        BCS             ASM_REPL_IO_READY
                        JMP             ASM_REPL_IO_FAIL
ASM_REPL_IO_READY:
                        LDX             #<ASM_REPL_MSG_TITLE
                        LDY             #>ASM_REPL_MSG_TITLE
                        JSR             ASM_SMOKE_PRINT_LINE
                        JSR             ASM_REPL_BEGIN_TARGET
                        BCS             ASM_REPL_LOOP
                        CLC
                        RTS

ASM_REPL_LOOP:
                        JSR             ASM_RJOIN_INIT_IO
                        BCS             ASM_REPL_PROMPT
                        JMP             ASM_REPL_IO_FAIL
ASM_REPL_PROMPT:
                        LDX             #<ASM_REPL_MSG_PROMPT
                        LDY             #>ASM_REPL_MSG_PROMPT
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDX             #<ASM_REPL_LINE_BUF
                        LDY             #>ASM_REPL_LINE_BUF
                        JSR             ASM_RJ_READ_CSTRING
                        BCS             ASM_REPL_READ_OK
                        STA             ASM_REPL_STATUS
                        JSR             ASM_RJOIN_INIT_IO
                        BCC             ASM_REPL_RETURN_FAIL
                        JSR             ASM_REPL_PRINT_READ_FAIL
                        JMP             ASM_REPL_LOOP

ASM_REPL_READ_OK:
                        STA             ASM_REPL_LEN
                        BEQ             ASM_REPL_LOOP
                        LDA             ASM_REPL_LINE_BUF
                        CMP             #'.'
                        BNE             ASM_REPL_ASSEMBLE
                        LDA             ASM_REPL_LINE_BUF+1
                        BEQ             ASM_REPL_QUIT

ASM_REPL_ASSEMBLE:
                        STZ             ASM_FIX_RESOLVE_COUNT
                        LDA             ASM_PC_LO
                        STA             ASM_REPL_OLD_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_REPL_OLD_PC_HI
                        LDX             #<ASM_REPL_LINE_BUF
                        LDY             #>ASM_REPL_LINE_BUF
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_REPL_ASSEMBLE_OK
                        STA             ASM_REPL_STATUS
                        JSR             ASM_RJOIN_INIT_IO
                        BCC             ASM_REPL_RETURN_FAIL
                        JSR             ASM_REPL_PRINT_ERR
                        JSR             ASM_REPL_BEGIN_OLD_PC
                        JMP             ASM_REPL_LOOP

ASM_REPL_ASSEMBLE_OK:
                        JSR             ASM_RJOIN_INIT_IO
                        BCC             ASM_REPL_RETURN_FAIL
                        JSR             ASM_REPL_PRINT_OK
                        JSR             ASM_REPL_REOPEN_IF_NEEDED
                        JMP             ASM_REPL_LOOP

ASM_REPL_QUIT:
                        JSR             ASM_RJOIN_INIT_IO
                        BCC             ASM_REPL_RETURN_FAIL
                        LDX             #<ASM_REPL_MSG_BYE
                        LDY             #>ASM_REPL_MSG_BYE
                        JSR             ASM_SMOKE_PRINT_LINE
                        SEC
                        RTS
ASM_REPL_IO_FAIL:
                        JSR             ASM_RJOIN_INIT
                        BCC             ASM_REPL_RETURN_FAIL
                        LDA             #ASM_STATUS_RJOIN
                        STA             ASM_REPL_STATUS
                        JSR             ASM_REPL_PRINT_READ_FAIL
ASM_REPL_RETURN_FAIL:
                        CLC
                        RTS

ASM_REPL_BEGIN_TARGET:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JMP             ASM_BEGIN

ASM_REPL_BEGIN_OLD_PC:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             ASM_REPL_OLD_PC_LO
                        LDY             ASM_REPL_OLD_PC_HI
                        JMP             ASM_BEGIN

ASM_REPL_REOPEN_IF_NEEDED:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_REPL_REOPEN
                        SEC
                        RTS
ASM_REPL_REOPEN:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        JMP             ASM_BEGIN

ASM_REPL_PRINT_OK:
                        LDX             #<ASM_REPL_MSG_OK
                        LDY             #>ASM_REPL_MSG_OK
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_REPL_PRINT_BYTES
                        JSR             ASM_REPL_PRINT_DEF
                        JSR             ASM_REPL_PRINT_FIXUPS
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPL_PRINT_ERR:
                        LDX             #<ASM_REPL_MSG_ERR
                        LDY             #>ASM_REPL_MSG_ERR
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_REPL_STATUS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SMOKE_MSG_PC
                        LDY             #>ASM_SMOKE_MSG_PC
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_REPL_OLD_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_REPL_OLD_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPL_PRINT_READ_FAIL:
                        LDX             #<ASM_REPL_MSG_READ
                        LDY             #>ASM_REPL_MSG_READ
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_REPL_STATUS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPL_PRINT_BYTES:
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_MNEM
                        BEQ             ASM_REPL_BYTES_MAYBE
                        CMP             #ASM_STMT_DIR
                        BEQ             ASM_REPL_BYTES_CHECK_DIR
                        RTS
ASM_REPL_BYTES_CHECK_DIR:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_DB
                        BEQ             ASM_REPL_BYTES_MAYBE
                        CMP             #ASM_VID_DW
                        BEQ             ASM_REPL_BYTES_MAYBE
                        CMP             #ASM_VID_DS
                        BEQ             ASM_REPL_BYTES_MAYBE
                        RTS
ASM_REPL_BYTES_MAYBE:
                        LDA             ASM_PC_HI
                        CMP             ASM_REPL_OLD_PC_HI
                        BEQ             ASM_REPL_BYTES_SAME_PAGE
                        RTS
ASM_REPL_BYTES_SAME_PAGE:
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_REPL_OLD_PC_LO
                        BEQ             ASM_REPL_BYTES_DONE
                        CMP             #$11
                        BCC             ASM_REPL_BYTES_HAVE_DELTA
ASM_REPL_BYTES_DONE:
                        RTS
ASM_REPL_BYTES_HAVE_DELTA:
                        STA             ASM_REPL_DELTA
                        LDA             ASM_REPL_OLD_PC_LO
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_REPL_OLD_PC_HI
                        STA             ASM_EMIT_PTR_HI
                        STZ             ASM_REPL_BYTE_INDEX
                        LDX             #<ASM_REPL_MSG_BYTES
                        LDY             #>ASM_REPL_MSG_BYTES
                        JSR             ASM_RJ_WRITE_CSTRING
ASM_REPL_BYTES_LOOP:
                        LDA             ASM_REPL_BYTE_INDEX
                        CMP             ASM_REPL_DELTA
                        BEQ             ASM_REPL_BYTES_DONE
                        LDA             #' '
                        JSR             ASM_RJ_WRITE_BYTE
                        LDY             ASM_REPL_BYTE_INDEX
                        LDA             (ASM_EMIT_PTR_LO),Y
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        INC             ASM_REPL_BYTE_INDEX
                        BRA             ASM_REPL_BYTES_LOOP

ASM_REPL_PRINT_DEF:
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_BINDS_PC)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_BINDS_PC)
                        BNE             ASM_REPL_PRINT_DEF_DONE
                        LDX             #<ASM_REPORT_MSG_DEF
                        LDY             #>ASM_REPORT_MSG_DEF
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_REPL_OLD_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_REPL_OLD_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
ASM_REPL_PRINT_DEF_DONE:
                        RTS

ASM_REPL_PRINT_FIXUPS:
                        LDA             ASM_FIX_RESOLVE_COUNT
                        BEQ             ASM_REPL_PRINT_FIXUPS_DONE
                        LDX             #<ASM_REPL_MSG_FIX
                        LDY             #>ASM_REPL_MSG_FIX
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_FIX_LAST_SITE_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_FIX_LAST_SITE_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
ASM_REPL_PRINT_FIXUPS_DONE:
                        RTS

ASM_SMOKE_PRINT_PASS:
                        LDX             #<ASM_SMOKE_MSG_PASS
                        LDY             #>ASM_SMOKE_MSG_PASS
                        JSR             ASM_SMOKE_PRINT_LINE
                        JSR             ASM_SMOKE_PRINT_WARNINGS
                        LDX             #<ASM_SMOKE_MSG_W
                        LDY             #>ASM_SMOKE_MSG_W
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

ASM_SMOKE_PRINT_WARNINGS:
                        LDA             ASM_REPORT_FLAGS
                        ORA             ASM_SMOKE_REPORT_FLAGS
                        AND             #ASM_REPORTF_WARN_DS_WRAP
                        BEQ             ASM_SMOKE_PRINT_WARNINGS_DONE
                        LDX             #<ASM_SMOKE_MSG_WARN_DS_WRAP
                        LDY             #>ASM_SMOKE_MSG_WARN_DS_WRAP
                        JSR             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_WARNINGS_DONE:
                        RTS

ASM_SMOKE_PROGRESS:
                        STA             ASM_START_STEP
                        JMP             ASM_SMOKE_PRINT_LINE

                        ENDIF

ASM_SMOKE_PRINT_LINE:
                        JSR             ASM_RJ_WRITE_CSTRING
                        JMP             ASM_RJ_PRINT_CRLF

                        IF              ASM_RUNTIME_ONLY
                        ELSE

ASM_SMOKE_PRINT_FAIL:
                        LDX             #<ASM_SMOKE_MSG_FAIL_TITLE
                        LDY             #>ASM_SMOKE_MSG_FAIL_TITLE
                        JSR             ASM_RJ_WRITE_CSTRING
                        JSR             ASM_RJ_PRINT_CRLF
                        JSR             ASM_SMOKE_PRINT_FAIL_STAGE
                        JSR             ASM_SMOKE_PRINT_FAIL_DETAIL
                        LDX             #<ASM_SMOKE_MSG_FAIL_S
                        LDY             #>ASM_SMOKE_MSG_FAIL_S
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_FAIL_STEP
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SMOKE_MSG_FAIL_X
                        LDY             #>ASM_SMOKE_MSG_FAIL_X
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_FAIL_STATUS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SMOKE_MSG_FAIL_Y
                        LDY             #>ASM_SMOKE_MSG_FAIL_Y
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_FAIL_SLOT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_SMOKE_PRINT_FAIL_STAGE:
                        LDA             ASM_FAIL_STEP
                        CMP             #ASM_STEP_FIXUPS
                        BEQ             ASM_SMOKE_PRINT_FAIL_FIXUPS
                        CMP             #ASM_STEP_DIRECTIVE
                        BEQ             ASM_SMOKE_PRINT_FAIL_DIRECT
                        CMP             #ASM_STEP_REPORT
                        BEQ             ASM_SMOKE_PRINT_FAIL_REPORT
                        CMP             #ASM_STEP_ASMTEST
                        BEQ             ASM_SMOKE_PRINT_FAIL_ASMTEST
                        RTS
ASM_SMOKE_PRINT_FAIL_FIXUPS:
                        LDX             #<ASM_SMOKE_MSG_T_FIXUPS
                        LDY             #>ASM_SMOKE_MSG_T_FIXUPS
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIRECT:
                        LDX             #<ASM_SMOKE_MSG_T_DIRECT
                        LDY             #>ASM_SMOKE_MSG_T_DIRECT
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_REPORT:
                        LDX             #<ASM_SMOKE_MSG_T_REPORT
                        LDY             #>ASM_SMOKE_MSG_T_REPORT
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_ASMTEST:
                        LDX             #<ASM_SMOKE_MSG_T_ASMTEST
                        LDY             #>ASM_SMOKE_MSG_T_ASMTEST
                        JMP             ASM_SMOKE_PRINT_LINE

ASM_SMOKE_PRINT_FAIL_DETAIL:
                        LDA             ASM_FAIL_STEP
                        CMP             #ASM_STEP_FIXUPS
                        BEQ             ASM_SMOKE_PRINT_FAIL_FIX_DETAIL
                        CMP             #ASM_STEP_DIRECTIVE
                        BNE             ASM_SMOKE_PRINT_FAIL_DETAIL_DONE
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_DETAIL
ASM_SMOKE_PRINT_FAIL_DETAIL_DONE:
                        RTS
ASM_SMOKE_PRINT_FAIL_FIX_DETAIL:
                        LDA             ASM_FAIL_SLOT
                        CMP             #$A1
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A2
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A1
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A2:
                        CMP             #$A2
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A3
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A2
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A3:
                        CMP             #$A3
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A4
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A3
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A4:
                        CMP             #$A4
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A5
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A4
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A5:
                        CMP             #$A5
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A6
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A5
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A6:
                        CMP             #$A6
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_A7
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A6
ASM_SMOKE_PRINT_FAIL_FIX_CHK_A7:
                        CMP             #$A7
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_AC
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_A7
ASM_SMOKE_PRINT_FAIL_FIX_CHK_AC:
                        CMP             #$AC
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_AF
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_AC
ASM_SMOKE_PRINT_FAIL_FIX_CHK_AF:
                        CMP             #$AF
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B1
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_AF
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B1:
                        CMP             #$B1
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B2
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B1
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B2:
                        CMP             #$B2
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B3
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B2
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B3:
                        CMP             #$B3
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B4
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B3
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B4:
                        CMP             #$B4
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B5
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B4
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B5:
                        CMP             #$B5
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B6
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B5
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B6:
                        CMP             #$B6
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B7
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B6
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B7:
                        CMP             #$B7
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B8
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B7
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B8:
                        CMP             #$B8
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_B9
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B8
ASM_SMOKE_PRINT_FAIL_FIX_CHK_B9:
                        CMP             #$B9
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_BA
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_B9
ASM_SMOKE_PRINT_FAIL_FIX_CHK_BA:
                        CMP             #$BA
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_CHK_BB
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_BA
ASM_SMOKE_PRINT_FAIL_FIX_CHK_BB:
                        CMP             #$BB
                        BNE             ASM_SMOKE_PRINT_FAIL_FIX_NO_MATCH
                        JMP             ASM_SMOKE_PRINT_FAIL_FIX_BB
ASM_SMOKE_PRINT_FAIL_FIX_NO_MATCH:
                        RTS
ASM_SMOKE_PRINT_FAIL_FIX_A1:
                        LDX             #<ASM_SMOKE_MSG_FIX_A1
                        LDY             #>ASM_SMOKE_MSG_FIX_A1
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A2:
                        LDX             #<ASM_SMOKE_MSG_FIX_A2
                        LDY             #>ASM_SMOKE_MSG_FIX_A2
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A3:
                        LDX             #<ASM_SMOKE_MSG_FIX_A3
                        LDY             #>ASM_SMOKE_MSG_FIX_A3
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A4:
                        LDX             #<ASM_SMOKE_MSG_FIX_A4
                        LDY             #>ASM_SMOKE_MSG_FIX_A4
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A5:
                        LDX             #<ASM_SMOKE_MSG_FIX_A5
                        LDY             #>ASM_SMOKE_MSG_FIX_A5
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A6:
                        LDX             #<ASM_SMOKE_MSG_FIX_A6
                        LDY             #>ASM_SMOKE_MSG_FIX_A6
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_A7:
                        LDX             #<ASM_SMOKE_MSG_FIX_A7
                        LDY             #>ASM_SMOKE_MSG_FIX_A7
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_AC:
                        LDX             #<ASM_SMOKE_MSG_FIX_AC
                        LDY             #>ASM_SMOKE_MSG_FIX_AC
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_AF:
                        LDX             #<ASM_SMOKE_MSG_FIX_AF
                        LDY             #>ASM_SMOKE_MSG_FIX_AF
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B1:
                        LDX             #<ASM_SMOKE_MSG_FIX_B1
                        LDY             #>ASM_SMOKE_MSG_FIX_B1
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B2:
                        LDX             #<ASM_SMOKE_MSG_FIX_B2
                        LDY             #>ASM_SMOKE_MSG_FIX_B2
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B3:
                        LDX             #<ASM_SMOKE_MSG_FIX_B3
                        LDY             #>ASM_SMOKE_MSG_FIX_B3
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B4:
                        LDX             #<ASM_SMOKE_MSG_FIX_B4
                        LDY             #>ASM_SMOKE_MSG_FIX_B4
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B5:
                        LDX             #<ASM_SMOKE_MSG_FIX_B5
                        LDY             #>ASM_SMOKE_MSG_FIX_B5
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B6:
                        LDX             #<ASM_SMOKE_MSG_FIX_B6
                        LDY             #>ASM_SMOKE_MSG_FIX_B6
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B7:
                        LDX             #<ASM_SMOKE_MSG_FIX_B7
                        LDY             #>ASM_SMOKE_MSG_FIX_B7
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B8:
                        LDX             #<ASM_SMOKE_MSG_FIX_B8
                        LDY             #>ASM_SMOKE_MSG_FIX_B8
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_B9:
                        LDX             #<ASM_SMOKE_MSG_FIX_B9
                        LDY             #>ASM_SMOKE_MSG_FIX_B9
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_BA:
                        LDX             #<ASM_SMOKE_MSG_FIX_BA
                        LDY             #>ASM_SMOKE_MSG_FIX_BA
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_FIX_BB:
                        LDX             #<ASM_SMOKE_MSG_FIX_BB
                        LDY             #>ASM_SMOKE_MSG_FIX_BB
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_DETAIL:
                        LDA             ASM_FAIL_SLOT
                        CMP             #$C1
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C2
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C1
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C2:
                        CMP             #$C2
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C3
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C2
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C3:
                        CMP             #$C3
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C4
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C3
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C4:
                        CMP             #$C4
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C5
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C4
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C5:
                        CMP             #$C5
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C6
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C5
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C6:
                        CMP             #$C6
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C7
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C6
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C7:
                        CMP             #$C7
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C8
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C7
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C8:
                        CMP             #$C8
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_C9
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C8
ASM_SMOKE_PRINT_FAIL_DIR_CHK_C9:
                        CMP             #$C9
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CA
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_C9
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CA:
                        CMP             #$CA
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CB
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CA
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CB:
                        CMP             #$CB
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CC
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CB
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CC:
                        CMP             #$CC
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CD
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CC
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CD:
                        CMP             #$CD
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CE
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CD
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CE:
                        CMP             #$CE
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_CF
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CE
ASM_SMOKE_PRINT_FAIL_DIR_CHK_CF:
                        CMP             #$CF
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D0
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_CF
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D0:
                        CMP             #$D0
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D1
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D0
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D1:
                        CMP             #$D1
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D2
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D1
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D2:
                        CMP             #$D2
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D3
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D2
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D3:
                        CMP             #$D3
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D4
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D3
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D4:
                        CMP             #$D4
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D5
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D4
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D5:
                        CMP             #$D5
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D6
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D5
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D6:
                        CMP             #$D6
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D7
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D6
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D7:
                        CMP             #$D7
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D8
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D7
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D8:
                        CMP             #$D8
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_CHK_D9
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D8
ASM_SMOKE_PRINT_FAIL_DIR_CHK_D9:
                        CMP             #$D9
                        BNE             ASM_SMOKE_PRINT_FAIL_DIR_NO_MATCH
                        JMP             ASM_SMOKE_PRINT_FAIL_DIR_D9
ASM_SMOKE_PRINT_FAIL_DIR_NO_MATCH:
                        RTS
ASM_SMOKE_PRINT_FAIL_DIR_C1:
                        LDX             #<ASM_SMOKE_MSG_DIR_C1
                        LDY             #>ASM_SMOKE_MSG_DIR_C1
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C2:
                        LDX             #<ASM_SMOKE_MSG_DIR_C2
                        LDY             #>ASM_SMOKE_MSG_DIR_C2
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C3:
                        LDX             #<ASM_SMOKE_MSG_DIR_C3
                        LDY             #>ASM_SMOKE_MSG_DIR_C3
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C4:
                        LDX             #<ASM_SMOKE_MSG_DIR_C4
                        LDY             #>ASM_SMOKE_MSG_DIR_C4
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C5:
                        LDX             #<ASM_SMOKE_MSG_DIR_C5
                        LDY             #>ASM_SMOKE_MSG_DIR_C5
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C6:
                        LDX             #<ASM_SMOKE_MSG_DIR_C6
                        LDY             #>ASM_SMOKE_MSG_DIR_C6
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C7:
                        LDX             #<ASM_SMOKE_MSG_DIR_C7
                        LDY             #>ASM_SMOKE_MSG_DIR_C7
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C8:
                        LDX             #<ASM_SMOKE_MSG_DIR_C8
                        LDY             #>ASM_SMOKE_MSG_DIR_C8
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_C9:
                        LDX             #<ASM_SMOKE_MSG_DIR_C9
                        LDY             #>ASM_SMOKE_MSG_DIR_C9
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CA:
                        LDX             #<ASM_SMOKE_MSG_DIR_CA
                        LDY             #>ASM_SMOKE_MSG_DIR_CA
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CB:
                        LDX             #<ASM_SMOKE_MSG_DIR_CB
                        LDY             #>ASM_SMOKE_MSG_DIR_CB
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CC:
                        LDX             #<ASM_SMOKE_MSG_DIR_CC
                        LDY             #>ASM_SMOKE_MSG_DIR_CC
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CD:
                        LDX             #<ASM_SMOKE_MSG_DIR_CD
                        LDY             #>ASM_SMOKE_MSG_DIR_CD
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CE:
                        LDX             #<ASM_SMOKE_MSG_DIR_CE
                        LDY             #>ASM_SMOKE_MSG_DIR_CE
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_CF:
                        LDX             #<ASM_SMOKE_MSG_DIR_CF
                        LDY             #>ASM_SMOKE_MSG_DIR_CF
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D0:
                        LDX             #<ASM_SMOKE_MSG_DIR_D0
                        LDY             #>ASM_SMOKE_MSG_DIR_D0
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D1:
                        LDX             #<ASM_SMOKE_MSG_DIR_D1
                        LDY             #>ASM_SMOKE_MSG_DIR_D1
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D2:
                        LDX             #<ASM_SMOKE_MSG_DIR_D2
                        LDY             #>ASM_SMOKE_MSG_DIR_D2
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D3:
                        LDX             #<ASM_SMOKE_MSG_DIR_D3
                        LDY             #>ASM_SMOKE_MSG_DIR_D3
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D4:
                        LDX             #<ASM_SMOKE_MSG_DIR_D4
                        LDY             #>ASM_SMOKE_MSG_DIR_D4
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D5:
                        LDX             #<ASM_SMOKE_MSG_DIR_D5
                        LDY             #>ASM_SMOKE_MSG_DIR_D5
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D6:
                        LDX             #<ASM_SMOKE_MSG_DIR_D6
                        LDY             #>ASM_SMOKE_MSG_DIR_D6
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D7:
                        LDX             #<ASM_SMOKE_MSG_DIR_D7
                        LDY             #>ASM_SMOKE_MSG_DIR_D7
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D8:
                        LDX             #<ASM_SMOKE_MSG_DIR_D8
                        LDY             #>ASM_SMOKE_MSG_DIR_D8
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_SMOKE_PRINT_FAIL_DIR_D9:
                        LDX             #<ASM_SMOKE_MSG_DIR_D9
                        LDY             #>ASM_SMOKE_MSG_DIR_D9
                        JMP             ASM_SMOKE_PRINT_LINE

                        ENDIF

ASM_RJOIN_INIT:
                        IF              ASM_RUNTIME_ONLY
                        STZ             ASM_RJ_READY
                        ENDIF
                        LDA             ASM_RJ_READY
                        BEQ             ASM_RJOIN_INIT_SEED
                        LDA             ASM_RJ_JOINER_HI
                        BEQ             ASM_RJOIN_INIT_SEED
                        LDA             ASM_RJ_WRITE_HI
                        BEQ             ASM_RJOIN_INIT_SEED
                        LDA             ASM_RJ_HEX_NIB_HI
                        BEQ             ASM_RJOIN_INIT_SEED
                        LDA             ASM_RJ_FNV_INIT_HI
                        BEQ             ASM_RJOIN_INIT_SEED
                        LDA             ASM_RJ_FNV_UPDATE_HI
                        BEQ             ASM_RJOIN_INIT_SEED
                        SEC
                        RTS
ASM_RJOIN_INIT_SEED:
                        STZ             ASM_RJ_READY
                        LDA             #ASM_STEP_RJOIN_JOINER
                        STA             ASM_START_STEP
                        LDX             ASM_SEED_HASH_ACQUIRE_LO
                        LDY             ASM_SEED_HASH_ACQUIRE_HI
                        CPY             #ASM_SEED_ROM_MIN_HI
                        BCC             ASM_RJOIN_INIT_FAIL
                        CPY             #$FF
                        BNE             ASM_RJOIN_INIT_SEED_OK
                        CPX             #$FF
                        BEQ             ASM_RJOIN_INIT_FAIL
ASM_RJOIN_INIT_SEED_OK:
                        STX             ASM_RJ_JOINER_LO
                        STY             ASM_RJ_JOINER_HI
ASM_RJOIN_INIT_JOINER_READY:

                        LDA             #ASM_STEP_RJOIN_WRITE
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>ASM_HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_WRITE_LO
                        STY             ASM_RJ_WRITE_HI
                        IF              ASM_RUNTIME_ONLY
                        ELSE
                        LDA             ASM_RJ_PROGRESS
                        BEQ             ASM_RJOIN_INIT_NO_PROGRESS
                        LDX             #<ASM_SMOKE_MSG_T_RJOIN
                        LDY             #>ASM_SMOKE_MSG_T_RJOIN
                        JSR             ASM_SMOKE_PRINT_LINE
ASM_RJOIN_INIT_NO_PROGRESS:
                        ENDIF

                        LDA             #ASM_STEP_RJOIN_HEX_NIB
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>ASM_HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_HEX_NIB_LO
                        STY             ASM_RJ_HEX_NIB_HI

                        LDA             #ASM_STEP_RJOIN_FNV_INIT
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_FNV1A_INIT
                        LDY             #>ASM_HASH_FNV1A_INIT
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_FNV_INIT_LO
                        STY             ASM_RJ_FNV_INIT_HI

                        LDA             #ASM_STEP_RJOIN_FNV_UPDATE
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_FNV1A_UPDATE_A_FAST
                        LDY             #>ASM_HASH_FNV1A_UPDATE_A_FAST
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_FAIL
                        STX             ASM_RJ_FNV_UPDATE_LO
                        STY             ASM_RJ_FNV_UPDATE_HI
                        STZ             ASM_RJ_PROGRESS
                        LDA             #$01
                        STA             ASM_RJ_READY
                        SEC
                        RTS
ASM_RJOIN_INIT_FAIL:
                        STZ             ASM_RJ_READY
                        STZ             ASM_RJ_PROGRESS
                        CLC
                        RTS

                        IF              ASM_RUNTIME_ONLY
                        IF              ASM_FLASH_RUNTIME
ASM_RJOIN_INIT_IO:
                        STZ             ASM_RJ_READ_LO
                        STZ             ASM_RJ_READ_HI
                        JSR             ASM_RJOIN_INIT
                        BCC             ASM_RJOIN_INIT_IO_FAIL
                        LDA             ASM_RJ_READ_HI
                        BNE             ASM_RJOIN_INIT_IO_READY
                        LDA             #ASM_STEP_RJOIN_READ
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER
                        LDY             #>ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_IO_FAIL
                        STX             ASM_RJ_READ_LO
                        STY             ASM_RJ_READ_HI
ASM_RJOIN_INIT_IO_READY:
                        SEC
                        RTS
ASM_RJOIN_INIT_IO_FAIL:
                        CLC
                        RTS
                        ENDIF
                        ELSE
ASM_RJOIN_INIT_IO:
                        JSR             ASM_RJOIN_INIT
                        BCC             ASM_RJOIN_INIT_IO_FAIL
                        LDA             ASM_RJ_READ_HI
                        BNE             ASM_RJOIN_INIT_IO_READY
                        LDA             #ASM_STEP_RJOIN_READ
                        STA             ASM_START_STEP
                        LDX             #<ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER
                        LDY             #>ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_RJOIN_INIT_IO_FAIL
                        STX             ASM_RJ_READ_LO
                        STY             ASM_RJ_READ_HI
ASM_RJOIN_INIT_IO_READY:
                        SEC
                        RTS
ASM_RJOIN_INIT_IO_FAIL:
                        CLC
                        RTS
                        ENDIF

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

                        IF              ASM_RUNTIME_ONLY
                        IF              ASM_FLASH_RUNTIME
ASM_RJ_READ_CSTRING:
                        JMP             (ASM_RJ_READ_LO)
                        ENDIF
                        ELSE
ASM_RJ_READ_CSTRING:
                        JMP             (ASM_RJ_READ_LO)
                        ENDIF

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

                        IF              ASM_RUNTIME_ONLY
                        ELSE

ASM_SMOKE_FAIL_A:
                        JMP             ASM_SMOKE_FAIL

ASM_SMOKE_TOKENS:
                        LDX             #<ASM_SMOKE_LINE_OK
                        LDY             #>ASM_SMOKE_LINE_OK
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_FAIL_A
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
                        CMP             #ASM_SMOKE_TARGET_HI
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
                        LDX             #<ASM_SMOKE_VOC_DB
                        LDY             #>ASM_SMOKE_VOC_DB
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_DIR
                        LDX             #<ASM_SMOKE_VOC_DW
                        LDY             #>ASM_SMOKE_VOC_DW
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_RESERVED
                        LDX             #<ASM_SMOKE_VOC_DC
                        LDY             #>ASM_SMOKE_VOC_DC
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_DIR
                        LDX             #<ASM_SMOKE_VOC_IMPORT
                        LDY             #>ASM_SMOKE_VOC_IMPORT
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_REG
                        LDX             #<ASM_SMOKE_VOC_A
                        LDY             #>ASM_SMOKE_VOC_A
                        JSR             ASM_SMOKE_LOOKUP
                        BCC             ASM_SMOKE_VOCAB_FAIL

                        LDA             #ASM_VOC_REG
                        LDX             #<ASM_SMOKE_VOC_Y
                        LDY             #>ASM_SMOKE_VOC_Y
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
                        BCC             ASM_SMOKE_PARSE_FAIL_A
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_COLON
                        BEQ             ASM_SMOKE_PARSE_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_SMOKE_PARSE_LDA
                        LDY             #>ASM_SMOKE_PARSE_LDA
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_A
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_SMOKE_PARSE_FAIL_A
                        LDA             #'#'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_SMOKE_PARSE_LABEL_LDA_NC
                        LDY             #>ASM_SMOKE_PARSE_LABEL_LDA_NC
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_B
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL_B
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_COLON
                        BNE             ASM_SMOKE_PARSE_FAIL_B
                        LDA             #'#'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_B

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_SMOKE_PARSE_LABEL_LDA
                        LDY             #>ASM_SMOKE_PARSE_LABEL_LDA
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_B
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL_B
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_COLON
                        BEQ             ASM_SMOKE_PARSE_FAIL_B
                        LDA             #'#'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_B

                        BRA             ASM_SMOKE_PARSE_AFTER_FAIL_B
ASM_SMOKE_PARSE_FAIL_B:
                        JMP             ASM_SMOKE_PARSE_FAIL
ASM_SMOKE_PARSE_AFTER_FAIL_B:

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_EQU
                        LDY             #>ASM_SMOKE_PARSE_EQU
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_C
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL_C
                        LDA             #'$'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_C

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_DB
                        LDY             #>ASM_SMOKE_PARSE_DB
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_C
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL_C
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_BINDS_PC
                        BEQ             ASM_SMOKE_PARSE_FAIL_C
                        LDA             #'$'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_C

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_DW
                        LDY             #>ASM_SMOKE_PARSE_DW
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_C
                        LDA             ASM_STMT_FLAGS
                        AND             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        CMP             #(ASM_STMTF_HAS_NAME|ASM_STMTF_HAS_TAIL)
                        BNE             ASM_SMOKE_PARSE_FAIL_C
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_BINDS_PC
                        BEQ             ASM_SMOKE_PARSE_FAIL_C
                        LDA             #'$'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_C

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_ORG
                        LDY             #>ASM_SMOKE_PARSE_ORG
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_C
                        LDA             #'$'
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_C

                        BRA             ASM_SMOKE_PARSE_AFTER_FAIL_C
ASM_SMOKE_PARSE_FAIL_C:
                        JMP             ASM_SMOKE_PARSE_FAIL
ASM_SMOKE_PARSE_AFTER_FAIL_C:

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_SMOKE_PARSE_END
                        LDY             #>ASM_SMOKE_PARSE_END
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL_D
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_SMOKE_PARSE_FAIL_D
                        LDA             #$00
                        JSR             ASM_SMOKE_PARSE_TAIL_CHAR
                        BCC             ASM_SMOKE_PARSE_FAIL_D

                        BRA             ASM_SMOKE_PARSE_AFTER_FAIL_D
ASM_SMOKE_PARSE_FAIL_D:
                        JMP             ASM_SMOKE_PARSE_FAIL
ASM_SMOKE_PARSE_AFTER_FAIL_D:

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

                        LDA             #ASM_STATUS_BAD_SYM
                        LDX             #<ASM_SMOKE_PARSE_LABEL_END
                        LDY             #>ASM_SMOKE_PARSE_LABEL_END
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_ORG_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_ORG_EMPTY
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_EQU_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_EQU_EMPTY
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_DB_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_DB_EMPTY
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_DW_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_DW_EMPTY
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_SYM
                        LDX             #<ASM_SMOKE_PARSE_REG_LABEL
                        LDY             #>ASM_SMOKE_PARSE_REG_LABEL
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STMT_LABEL_ONLY
                        LDX             #<ASM_SMOKE_PARSE_LOCAL_LABEL
                        LDY             #>ASM_SMOKE_PARSE_LOCAL_LABEL
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_FAIL
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_LOCAL_NAME
                        BEQ             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_DIR
                        LDX             #<ASM_SMOKE_PARSE_DC
                        LDY             #>ASM_SMOKE_PARSE_DC
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        LDA             #ASM_STATUS_BAD_DIR
                        LDX             #<ASM_SMOKE_PARSE_START
                        LDY             #>ASM_SMOKE_PARSE_START
                        JSR             ASM_SMOKE_PARSE_ERR
                        BCC             ASM_SMOKE_PARSE_FAIL

                        JSR             ASM_SMOKE_PARSE_ASMTEST
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

ASM_SMOKE_PARSE_TAIL_CHAR:
                        STA             ASM_TMP0_LO
                        LDA             ASM_STMT_TAIL_PTR_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_STMT_TAIL_PTR_HI
                        STA             ASM_TMP1_HI
                        LDY             #$00
                        LDA             (ASM_TMP1_LO),Y
                        CMP             ASM_TMP0_LO
                        BNE             ASM_SMOKE_PARSE_TAIL_CHAR_FAIL
                        SEC
                        RTS
ASM_SMOKE_PARSE_TAIL_CHAR_FAIL:
                        CLC
                        RTS

ASM_SMOKE_PARSE_ASMTEST_FAIL_A:
                        JMP             ASM_SMOKE_PARSE_ASMTEST_FAIL

ASM_SMOKE_PARSE_ASMTEST:
                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_ORG
                        LDY             #>ASM_PARSE_AT_ORG
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_OUT_EQU
                        LDY             #>ASM_PARSE_AT_OUT_EQU
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_COUNT_EQU
                        LDY             #>ASM_PARSE_AT_COUNT_EQU
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_CLASS_SUM_EQU
                        LDY             #>ASM_CLASS_SUM_EQU
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_ASMTEST_LDX
                        LDY             #>ASM_PARSE_AT_ASMTEST_LDX
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_STZ
                        LDY             #>ASM_PARSE_AT_STZ
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_LOOP_LDA
                        LDY             #>ASM_PARSE_AT_LOOP_LDA
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL_A

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_STA_OUT_X
                        LDY             #>ASM_PARSE_AT_STA_OUT_X
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_EOR_SUM
                        LDY             #>ASM_PARSE_AT_EOR_SUM
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_STA_SUM
                        LDY             #>ASM_PARSE_AT_STA_SUM
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_INX
                        LDY             #>ASM_PARSE_AT_INX
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_CPX
                        LDY             #>ASM_PARSE_AT_CPX
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_BNE
                        LDY             #>ASM_PARSE_AT_BNE
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_MNEM
                        LDX             #<ASM_PARSE_AT_RTS
                        LDY             #>ASM_PARSE_AT_RTS
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_SEED_DB
                        LDY             #>ASM_PARSE_AT_SEED_DB
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_DB_CONT
                        LDY             #>ASM_PARSE_AT_DB_CONT
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL

                        LDA             #ASM_STMT_DIR
                        LDX             #<ASM_PARSE_AT_END
                        LDY             #>ASM_PARSE_AT_END
                        JSR             ASM_SMOKE_PARSE_OK
                        BCC             ASM_SMOKE_PARSE_ASMTEST_FAIL
                        SEC
                        RTS

ASM_SMOKE_PARSE_ASMTEST_FAIL:
                        CLC
                        RTS

ASM_SMOKE_EXPR:
                        LDX             #<ASM_SMOKE_EXPR_DEC
                        LDY             #>ASM_SMOKE_EXPR_DEC
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_DEC_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DEC_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_SMOKE_EXPR_DEC_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DEC_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_NONE
                        BEQ             ASM_SMOKE_EXPR_DEC_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DEC_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$0A
                        BEQ             ASM_SMOKE_EXPR_DEC_LO_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DEC_LO_OK:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_DEC_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DEC_OK:

                        LDX             #<ASM_SMOKE_EXPR_HEX_ZP
                        LDY             #>ASM_SMOKE_EXPR_HEX_ZP
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_ZP_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_SMOKE_EXPR_ZP_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_SMOKE_EXPR_ZP_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$12
                        BEQ             ASM_SMOKE_EXPR_ZP_LO_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_LO_OK:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_ZP_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_OK:

                        LDX             #<ASM_SMOKE_EXPR_HEX_ABS
                        LDY             #>ASM_SMOKE_EXPR_HEX_ABS
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_ABS_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_SMOKE_EXPR_ABS_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_SMOKE_EXPR_ABS_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$12
                        BEQ             ASM_SMOKE_EXPR_ABS_LO_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_LO_OK:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_ABS_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_OK:

                        LDX             #<ASM_SMOKE_EXPR_CHAR_A
                        LDY             #>ASM_SMOKE_EXPR_CHAR_A
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_CHAR_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_CHAR_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_SMOKE_EXPR_CHAR_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_CHAR_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_BYTE
                        BEQ             ASM_SMOKE_EXPR_CHAR_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_CHAR_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #'A'
                        BEQ             ASM_SMOKE_EXPR_CHAR_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_CHAR_OK:

                        LDX             #<ASM_SMOKE_EXPR_MASK
                        LDY             #>ASM_SMOKE_EXPR_MASK
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_MASK_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_MASK_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_SMOKE_EXPR_MASK_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_MASK_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_MASK8
                        BEQ             ASM_SMOKE_EXPR_MASK_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_MASK_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$01
                        BEQ             ASM_SMOKE_EXPR_MASK_VALUE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_MASK_VALUE_OK:
                        LDA             ASM_CARE_LO
                        CMP             #$01
                        BEQ             ASM_SMOKE_EXPR_MASK_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_MASK_OK:

                        LDA             #$34
                        STA             ASM_PC_LO
                        LDA             #$12
                        STA             ASM_PC_HI
                        LDX             #<ASM_SMOKE_EXPR_PC
                        LDY             #>ASM_SMOKE_EXPR_PC
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_PC_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_PC_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_SMOKE_EXPR_PC_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_PC_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_SMOKE_EXPR_PC_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_PC_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$34
                        BEQ             ASM_SMOKE_EXPR_PC_LO_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_PC_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             #$12
                        BEQ             ASM_SMOKE_EXPR_PC_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_PC_OK:

                        LDX             #<ASM_SMOKE_EXPR_ABS_PLUS
                        LDY             #>ASM_SMOKE_EXPR_ABS_PLUS
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_ABS_PLUS_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_PLUS_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_SMOKE_EXPR_ABS_PLUS_MODE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_PLUS_MODE_OK:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_SMOKE_EXPR_ABS_PLUS_WIDTH_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_PLUS_WIDTH_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$13
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_ABS_PLUS_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ABS_PLUS_OK:

                        LDX             #<ASM_SMOKE_EXPR_ZP_PLUS
                        LDY             #>ASM_SMOKE_EXPR_ZP_PLUS
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_ZP_PLUS_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_PLUS_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ZP
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_VALUE_LO
                        CMP             #$13
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_ZP_PLUS_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_PLUS_OK:

                        LDX             #<ASM_SMOKE_EXPR_ADDR_DELTA
                        LDY             #>ASM_SMOKE_EXPR_ADDR_DELTA
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_SMOKE_EXPR_DELTA_PARSED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DELTA_PARSED:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_VALUE
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_NONE
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_VALUE_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_EXPR_FAIL
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_EXPR_DELTA_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_DELTA_OK:

                        LDX             #<ASM_SMOKE_EXPR_ZP_RANGE
                        LDY             #>ASM_SMOKE_EXPR_ZP_RANGE
                        JSR             ASM_PARSE_EXPR
                        BCC             ASM_SMOKE_EXPR_ZP_RANGE_FAILED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_RANGE_FAILED:
                        CMP             #ASM_STATUS_BAD_RANGE
                        BEQ             ASM_SMOKE_EXPR_ZP_RANGE_OK
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_ZP_RANGE_OK:

                        LDX             #<ASM_SMOKE_EXPR_EXTRA
                        LDY             #>ASM_SMOKE_EXPR_EXTRA
                        JSR             ASM_PARSE_EXPR
                        BCC             ASM_SMOKE_EXPR_EXTRA_FAILED
                        JMP             ASM_SMOKE_EXPR_FAIL
ASM_SMOKE_EXPR_EXTRA_FAILED:
                        CMP             #ASM_STATUS_BAD_OPER
                        BEQ             ASM_SMOKE_EXPR_OK
                        JMP             ASM_SMOKE_EXPR_FAIL

ASM_SMOKE_EXPR_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS
ASM_SMOKE_EXPR_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FAIL

ASM_SMOKE_ASSEMBLE_LINE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

                        LDX             #<ASM_SMOKE_PARSE_BLANK
                        LDY             #>ASM_SMOKE_PARSE_BLANK
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_LINE_COUNT_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_LINE_COUNT_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

                        LDX             #<ASM_SMOKE_PARSE_ORG
                        LDY             #>ASM_SMOKE_PARSE_ORG
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_CHECK_PC_TARGET
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

                        LDX             #<ASM_SMOKE_SYM_NOPE
                        LDY             #>ASM_SMOKE_SYM_NOPE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

                        LDX             #<ASM_SMOKE_PARSE_LABEL_LDA_NC
                        LDY             #>ASM_SMOKE_PARSE_LABEL_LDA_NC
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_SMOKE_TARGET
                        CMP             #$A9
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_SMOKE_TARGET+1
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_PC_LO
                        CMP             #$02
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

                        LDX             #<ASM_SMOKE_PARSE_EQU
                        LDY             #>ASM_SMOKE_PARSE_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_CHECK_EQU
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A

ASM_SMOKE_ASSEMBLE_LINE_FAIL_B:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FAIL

ASM_SMOKE_ASSEMBLE_LINE_WIDTH:
                        LDX             #<ASM_SMOKE_PARSE_ZP0_EQU
                        LDY             #>ASM_SMOKE_PARSE_ZP0_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_ABS0_EQU
                        LDY             #>ASM_SMOKE_PARSE_ABS0_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_ZP_PLUS_EQU
                        LDY             #>ASM_SMOKE_PARSE_ZP_PLUS_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_ABS_PLUS_EQU
                        LDY             #>ASM_SMOKE_PARSE_ABS_PLUS_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_SIZE_EQU
                        LDY             #>ASM_SMOKE_PARSE_SIZE_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_LDA_ZP_PLUS
                        LDY             #>ASM_SMOKE_PARSE_LDA_ZP_PLUS
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_LDA_ABS_PLUS
                        LDY             #>ASM_SMOKE_PARSE_LDA_ABS_PLUS
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_CHECK_WIDTH
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B

                        LDX             #<ASM_SMOKE_PARSE_END
                        LDY             #>ASM_SMOKE_PARSE_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL_B
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ENDED
                        BEQ             ASM_SMOKE_ASSEMBLE_LINE_ENDED_OK
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FAIL_A
ASM_SMOKE_ASSEMBLE_LINE_ENDED_OK:

                        LDX             #<ASM_SMOKE_PARSE_LDA
                        LDY             #>ASM_SMOKE_PARSE_LDA
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_FAIL
                        CMP             #ASM_STATUS_BAD_OPER
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL
                        LDA             ASM_LINE_COUNT_LO
                        CMP             #$0E
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FAIL

                        JSR             ASM_SMOKE_ASSEMBLE_LINE_TXN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FAIL
                        SEC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_TXN:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL

                        LDX             #<ASM_SMOKE_TXN_BBR_RANGE
                        LDY             #>ASM_SMOKE_TXN_BBR_RANGE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_PC_LO
                        CMP             #ASM_SMOKE_TARGET_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_HIGH_PC_LO
                        CMP             #ASM_SMOKE_TARGET_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_SYM_COUNT
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_FIX_COUNT
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL

                        LDX             #<ASM_SMOKE_TXN_NOP
                        LDY             #>ASM_SMOKE_TXN_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_PC_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_TXN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_TXN_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_TXN:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             #$5A
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_LDA_IMM
                        LDY             #>ASM_SMOKE_TXN_LDA_IMM
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_PC_LO
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$5A
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A
                        LDA             #$6B
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DB_PAIR
                        LDY             #>ASM_SMOKE_TXN_DB_PAIR
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$6B
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A
                        LDA             #$7C
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DS_PAIR
                        LDY             #>ASM_SMOKE_TXN_DS_PAIR
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$7C
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE_FAIL
                        LDA             #$00
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DB_ONE
                        LDY             #>ASM_SMOKE_TXN_DB_ONE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$A5
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_ONE_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE_FAIL
                        LDA             #$00
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DS_ONE
                        LDY             #>ASM_SMOKE_TXN_DS_ONE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$5C
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_ONE_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL
                        STZ             ASM_TARGET_PENULT_ADDR
                        STZ             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_LDA_IMM
                        LDY             #>ASM_SMOKE_TXN_LDA_IMM
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$A9
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$12
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_TWO_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL
                        STZ             ASM_TARGET_PENULT_ADDR
                        STZ             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DB_PAIR
                        LDY             #>ASM_SMOKE_TXN_DB_PAIR
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$12
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$34
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_TWO_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL
                        LDA             #$A5
                        STA             ASM_TARGET_PENULT_ADDR
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DS_PAIR
                        LDY             #>ASM_SMOKE_TXN_DS_PAIR
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_TWO_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FD
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        STZ             ASM_TARGET_THIRD_ADDR
                        STZ             ASM_TARGET_PENULT_ADDR
                        STZ             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_CLASS_LDA_ABS
                        LDY             #>ASM_CLASS_LDA_ABS
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        LDA             ASM_TARGET_THIRD_ADDR
                        CMP             #$AD
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$12
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FD
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        STZ             ASM_TARGET_THIRD_ADDR
                        STZ             ASM_TARGET_PENULT_ADDR
                        STZ             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DB_THREE
                        LDY             #>ASM_SMOKE_TXN_DB_THREE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        LDA             ASM_TARGET_THIRD_ADDR
                        CMP             #$12
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$34
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$56
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FD
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        LDA             #$A5
                        STA             ASM_TARGET_THIRD_ADDR
                        STA             ASM_TARGET_PENULT_ADDR
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DS_THREE
                        LDY             #>ASM_SMOKE_TXN_DS_THREE
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        LDA             ASM_TARGET_THIRD_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDA             #$6D
                        STA             ASM_TARGET_PENULT_ADDR
                        LDA             #$7E
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_CLASS_LDA_ABS
                        LDY             #>ASM_CLASS_LDA_ABS
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$6D
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$7E
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDX             #<ASM_SMOKE_TXN_NOP
                        LDY             #>ASM_SMOKE_TXN_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$7E
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LDA_THREE_CROSS_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDA             #$6E
                        STA             ASM_TARGET_PENULT_ADDR
                        LDA             #$7F
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DB_THREE
                        LDY             #>ASM_SMOKE_TXN_DB_THREE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$6E
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$7F
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDX             #<ASM_SMOKE_TXN_NOP
                        LDY             #>ASM_SMOKE_TXN_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$7F
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DB_THREE_CROSS_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FE
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDA             #$70
                        STA             ASM_TARGET_PENULT_ADDR
                        LDA             #$81
                        STA             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_DS_THREE
                        LDY             #>ASM_SMOKE_TXN_DS_THREE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$70
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$81
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDX             #<ASM_SMOKE_TXN_NOP
                        LDY             #>ASM_SMOKE_TXN_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_PENULT_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$81
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_DS_THREE_CROSS_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$FF
                        LDY             #ASM_TARGET_MAX_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        STZ             ASM_TARGET_LAST_ADDR
                        LDX             #<ASM_SMOKE_TXN_NOP
                        LDY             #>ASM_SMOKE_TXN_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A

                        LDX             #<ASM_SMOKE_TXN_LDA_IMM
                        LDY             #>ASM_SMOKE_TXN_LDA_IMM
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_A

ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL

                        LDX             #<ASM_SMOKE_TXN_DB_ONE
                        LDY             #>ASM_SMOKE_TXN_DB_ONE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B

                        LDX             #<ASM_SMOKE_TXN_DS_ONE
                        LDY             #>ASM_SMOKE_TXN_DS_ONE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL_B
                        LDX             #<ASM_SMOKE_TXN_LIMIT_EQU
                        LDY             #>ASM_SMOKE_TXN_LIMIT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDX             #<ASM_SMOKE_TXN_LIMIT_EQU
                        LDY             #>ASM_SMOKE_TXN_LIMIT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        CMP             #ASM_STATUS_BAD_SYM
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_SYM_COUNT
                        CMP             #1
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDX             #<ASM_SMOKE_TXN_AFTER_LABEL
                        LDY             #>ASM_SMOKE_TXN_AFTER_LABEL
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDX             #<ASM_SMOKE_TXN_AFTER_LABEL
                        LDY             #>ASM_SMOKE_TXN_AFTER_LABEL
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        CMP             #ASM_STATUS_BAD_SYM
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_SYM_COUNT
                        CMP             #2
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDX             #<ASM_PARSE_AT_END
                        LDY             #>ASM_PARSE_AT_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ENDED
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_PC_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        LDA             ASM_TARGET_LAST_ADDR
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_STOP_FAIL:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL
                        LDA             ASM_PC_LO
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_CHECK_FAIL:
                        CLC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_CHECK:
                        LDA             ASM_SYM_COUNT
                        BEQ             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL
                        TAX
                        DEX
                        LDA             ASM_SYM_KIND,X
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL
                        LDA             ASM_SYM_WIDTH,X
                        CMP             #ASM_WIDTH_ABS
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL
                        LDA             ASM_SYM_VAL_LO,X
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL
                        LDA             ASM_SYM_VAL_HI,X
                        CMP             #ASM_TARGET_LIMIT_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_EQU_FAIL:
                        CLC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_CHECK:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL
                        LDA             ASM_PC_LO
                        CMP             #$FE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$FE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_TARGET_MAX_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_PENULT_FAIL:
                        CLC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_CHECK:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL
                        LDA             ASM_PC_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL
                        LDA             ASM_HIGH_PC_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_LIMIT_FAIL:
                        CLC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_BOUNDARY_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A

                        LDX             #<ASM_SMOKE_TXN_BNE_FOO
                        LDY             #>ASM_SMOKE_TXN_BNE_FOO
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_CODE_BUF
                        CMP             #$D0
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_PHASE2
ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL

ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_PHASE2:
                        LDX             #<ASM_SMOKE_TXN_FOO_STA_IMM
                        LDY             #>ASM_SMOKE_TXN_FOO_STA_IMM
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        CMP             #ASM_STATUS_BAD_MODE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_PC_LO
                        CMP             #$02
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_SYM_COUNT
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_A
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_PHASE3
ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B:
                        JMP             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL

ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_PHASE3:
                        LDX             #<ASM_SMOKE_TXN_FOO_NOP
                        LDY             #>ASM_SMOKE_TXN_FOO_NOP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_RESOLVED
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_CODE_BUF+1
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_CODE_BUF+2
                        CMP             #$EA
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_PC_LO
                        CMP             #$03
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL_B
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_FIX_TXN_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_CHECK_PC_TARGET:
                        LDA             ASM_PC_LO
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_CHECK_EQU:
                        LDA             ASM_SYM_COUNT
                        BEQ             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        TAX
                        DEX
                        LDA             ASM_SYM_KIND,X
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_WIDTH,X
                        CMP             #ASM_WIDTH_ZP
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_VAL_LO,X
                        CMP             #$12
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_VAL_HI,X
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_CHECK_WIDTH:
                        LDA             ASM_SYM_COUNT
                        BEQ             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        TAX
                        DEX
                        LDA             ASM_SYM_KIND,X
                        CMP             #ASM_SYMK_VALUE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_WIDTH,X
                        CMP             #ASM_WIDTH_NONE
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_VAL_LO,X
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SYM_VAL_HI,X
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SMOKE_TARGET+2
                        CMP             #$A5
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SMOKE_TARGET+3
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SMOKE_TARGET+4
                        CMP             #$AD
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SMOKE_TARGET+5
                        CMP             #$01
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_SMOKE_TARGET+6
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_PC_LO
                        CMP             #$07
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_ASSEMBLE_LINE_CHECK_FAIL:
                        CLC
                        RTS

ASM_SMOKE_ASMTEST_FAIL_A:
                        JMP             ASM_SMOKE_ASMTEST_FAIL

ASM_SMOKE_ASMTEST_3000:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_ORG
                        LDY             #>ASM_PARSE_AT_ORG
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_OUT_EQU
                        LDY             #>ASM_PARSE_AT_OUT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_CLASS_SUM_EQU
                        LDY             #>ASM_CLASS_SUM_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_COUNT_EQU
                        LDY             #>ASM_PARSE_AT_COUNT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_ASMTEST_LDX
                        LDY             #>ASM_PARSE_AT_ASMTEST_LDX
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_STZ
                        LDY             #>ASM_PARSE_AT_STZ
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_LOOP_LDA
                        LDY             #>ASM_PARSE_AT_LOOP_LDA
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_STA_OUT_X
                        LDY             #>ASM_PARSE_AT_STA_OUT_X
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_EOR_SUM
                        LDY             #>ASM_PARSE_AT_EOR_SUM
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_STA_SUM
                        LDY             #>ASM_PARSE_AT_STA_SUM
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_INX
                        LDY             #>ASM_PARSE_AT_INX
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_CPX
                        LDY             #>ASM_PARSE_AT_CPX
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_ASMTEST_FAIL_A

                        LDX             #<ASM_PARSE_AT_BNE
                        LDY             #>ASM_PARSE_AT_BNE
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASMTEST_BNE_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_BNE_OK:

                        LDX             #<ASM_PARSE_AT_RTS
                        LDY             #>ASM_PARSE_AT_RTS
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASMTEST_RTS_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_RTS_OK:

                        LDX             #<ASM_PARSE_AT_SEED_DB
                        LDY             #>ASM_PARSE_AT_SEED_DB
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASMTEST_SEED_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_SEED_OK:

                        LDX             #<ASM_PARSE_AT_DB_CONT
                        LDY             #>ASM_PARSE_AT_DB_CONT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASMTEST_DB_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_DB_OK:

                        LDX             #<ASM_PARSE_AT_END
                        LDY             #>ASM_PARSE_AT_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASMTEST_END_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_END_OK:

                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ENDED
                        BEQ             ASM_SMOKE_ASMTEST_ENDED_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_ENDED_OK:
                        JSR             ASM_SMOKE_ASMTEST_CHECK_BYTES
                        BCS             ASM_SMOKE_ASMTEST_BYTES_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_BYTES_OK:
                        JSR             ASM_SMOKE_ASMTEST_CHECK_PC
                        BCS             ASM_SMOKE_ASMTEST_PC_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_PC_OK:

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_ASMTEST_RESTORE_OK
                        JMP             ASM_SMOKE_ASMTEST_FAIL
ASM_SMOKE_ASMTEST_RESTORE_OK:
                        SEC
                        RTS

ASM_SMOKE_ASMTEST_CHECK_BYTES:
                        LDX             #$00
ASM_SMOKE_ASMTEST_CHECK_LOOP:
                        LDA             ASM_SMOKE_TARGET,X
                        CMP             ASM_ASMTEST_EXPECT,X
                        BEQ             ASM_SMOKE_ASMTEST_CHECK_BYTE_OK
                        JMP             ASM_SMOKE_ASMTEST_CHECK_FAIL
ASM_SMOKE_ASMTEST_CHECK_BYTE_OK:
                        INX
                        CPX             #$27
                        BNE             ASM_SMOKE_ASMTEST_CHECK_LOOP
                        SEC
                        RTS

ASM_SMOKE_ASMTEST_CHECK_PC:
                        LDA             ASM_PC_LO
                        CMP             #$27
                        BNE             ASM_SMOKE_ASMTEST_CHECK_FAIL
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASMTEST_CHECK_FAIL
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$27
                        BNE             ASM_SMOKE_ASMTEST_CHECK_FAIL
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_ASMTEST_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_ASMTEST_CHECK_FAIL:
ASM_SMOKE_ASMTEST_FAIL:
                        CLC
                        RTS

ASM_SMOKE_EMIT:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_EMIT_BEGIN_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_BEGIN_OK:

                        LDA             #$A2
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_SMOKE_EMIT_BYTE_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_BYTE_OK:
                        LDA             #$34
                        LDX             #$12
                        JSR             ASM_EMIT_WORD_LE
                        BCS             ASM_SMOKE_EMIT_WORD_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_WORD_OK:

                        LDA             ASM_CODE_BUF
                        CMP             #$A2
                        BEQ             ASM_SMOKE_EMIT_BUF0_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_BUF0_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             #$34
                        BEQ             ASM_SMOKE_EMIT_BUF1_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_BUF1_OK:
                        LDA             ASM_CODE_BUF+2
                        CMP             #$12
                        BEQ             ASM_SMOKE_EMIT_BUF2_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_BUF2_OK:

                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_EMIT_PC_HI_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_PC_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$03
                        BEQ             ASM_SMOKE_EMIT_PC_LO_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_PC_LO_OK:

                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_EMIT_HIGH_HI_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_HIGH_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$03
                        BEQ             ASM_SMOKE_EMIT_HIGH_LO_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_HIGH_LO_OK:

                        JSR             ASM_END
                        BCS             ASM_SMOKE_EMIT_END_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_END_OK:
                        LDA             #$00
                        JSR             ASM_EMIT_BYTE
                        BCC             ASM_SMOKE_EMIT_AFTER_END_ERR
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_AFTER_END_ERR:
                        CMP             #ASM_STATUS_BAD_OPER
                        BEQ             ASM_SMOKE_EMIT_AFTER_END_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_AFTER_END_OK:

                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_EMIT_RANGE_BEGIN_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_RANGE_BEGIN_OK:
                        LDA             #$FF
                        STA             ASM_PC_LO
                        STA             ASM_PC_HI
                        LDA             #$00
                        JSR             ASM_EMIT_BYTE
                        BCC             ASM_SMOKE_EMIT_RANGE_ERR
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_RANGE_ERR:
                        CMP             #ASM_STATUS_BAD_RANGE
                        BEQ             ASM_SMOKE_EMIT_RANGE_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_RANGE_OK:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_EMIT_CLEAN_OK
                        JMP             ASM_SMOKE_EMIT_FAIL
ASM_SMOKE_EMIT_CLEAN_OK:

                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS
ASM_SMOKE_EMIT_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPERANDS_FAIL_A:
                        JMP             ASM_SMOKE_OPERANDS_FAIL

ASM_SMOKE_OPERANDS:
                        JSR             ASM_SMOKE_OPERANDS_SETUP
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A

                        LDA             #ASM_OPM_NONE
                        LDX             #<ASM_PARSE_AT_RTS
                        LDY             #>ASM_PARSE_AT_RTS
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A

                        LDA             #ASM_OPM_NONE
                        LDX             #<ASM_PARSE_AT_INX
                        LDY             #>ASM_PARSE_AT_INX
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A

                        LDA             #ASM_OPM_ACC
                        LDX             #<ASM_CLASS_ASL_A
                        LDY             #>ASM_CLASS_ASL_A
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A

                        LDA             #ASM_OPM_IMM8
                        LDX             #<ASM_PARSE_AT_ASMTEST_LDX
                        LDY             #>ASM_PARSE_AT_ASMTEST_LDX
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A
                        LDA             ASM_VALUE_LO
                        BNE             ASM_SMOKE_OPERANDS_FAIL_A
                        LDA             ASM_VALUE_HI
                        BNE             ASM_SMOKE_OPERANDS_FAIL_A

                        LDA             #ASM_OPM_IMM8
                        LDX             #<ASM_PARSE_AT_CPX
                        LDY             #>ASM_PARSE_AT_CPX
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCC             ASM_SMOKE_OPERANDS_FAIL_A
                        LDA             ASM_VALUE_LO
                        CMP             #$10
                        BEQ             ASM_SMOKE_OPERANDS_CPX_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_CPX_LO_OK:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_OPERANDS_CPX_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_CPX_HI_OK:

                        LDA             #ASM_OPM_ZP8
                        LDX             #<ASM_CLASS_LDA_ZP
                        LDY             #>ASM_CLASS_LDA_ZP
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_ZP_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_ZP_OK:

                        LDA             #ASM_OPM_BIT_ZP
                        LDX             #<ASM_CLASS_RMB_ZP
                        LDY             #>ASM_CLASS_RMB_ZP
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_RMB_ZP_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_RMB_ZP_OK:
                        LDA             ASM_TMP1_LO
                        CMP             #$03
                        BEQ             ASM_SMOKE_OPERANDS_RMB_BIT_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_RMB_BIT_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$12
                        BEQ             ASM_SMOKE_OPERANDS_RMB_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_RMB_LO_OK:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_SMOKE_OPERANDS_RMB_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_RMB_HI_OK:

                        LDA             #ASM_OPM_BIT_ZP_REL
                        LDX             #<ASM_CLASS_BBR_ZP_REL
                        LDY             #>ASM_CLASS_BBR_ZP_REL
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_BBR_ZP_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BBR_ZP_OK:
                        LDA             ASM_TMP1_LO
                        CMP             #$03
                        BEQ             ASM_SMOKE_OPERANDS_BBR_BIT_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BBR_BIT_OK:
                        LDA             ASM_CARE_LO
                        CMP             #$12
                        BEQ             ASM_SMOKE_OPERANDS_BBR_ZP_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BBR_ZP_LO_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$10
                        BEQ             ASM_SMOKE_OPERANDS_BBR_TGT_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BBR_TGT_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             #$70
                        BEQ             ASM_SMOKE_OPERANDS_BBR_TGT_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BBR_TGT_HI_OK:

                        LDA             #ASM_OPM_ABS16
                        LDX             #<ASM_CLASS_LDA_ABS
                        LDY             #>ASM_CLASS_LDA_ABS
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_ABS_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_ABS_OK:

                        LDA             #ASM_OPM_ZP_IND
                        LDX             #<ASM_CLASS_LDA_ZP_IND
                        LDY             #>ASM_CLASS_LDA_ZP_IND
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_ZP_IND_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_ZP_IND_OK:

                        LDA             #ASM_OPM_ZP_X_IND
                        LDX             #<ASM_CLASS_LDA_ZPX_IND
                        LDY             #>ASM_CLASS_LDA_ZPX_IND
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_ZPX_IND_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_ZPX_IND_OK:

                        LDA             #ASM_OPM_ZP_IND_Y
                        LDX             #<ASM_CLASS_LDA_ZP_INDY
                        LDY             #>ASM_CLASS_LDA_ZP_INDY
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_ZP_INDY_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_ZP_INDY_OK:

                        LDA             #ASM_OPM_ABS_IND
                        LDX             #<ASM_OPCODE_JMP_IND
                        LDY             #>ASM_OPCODE_JMP_IND
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_JMP_IND_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_JMP_IND_OK:

                        LDA             #ASM_OPM_ABS_X_IND
                        LDX             #<ASM_OPCODE_JMP_ABSXIND
                        LDY             #>ASM_OPCODE_JMP_ABSXIND
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_JMP_ABSXIND_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_JMP_ABSXIND_OK:

                        LDA             #ASM_OPM_ABS16
                        LDX             #<ASM_PARSE_AT_STZ
                        LDY             #>ASM_PARSE_AT_STZ
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_STZ_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STZ_OK:

                        LDA             #ASM_OPM_ABS16
                        LDX             #<ASM_PARSE_AT_EOR_SUM
                        LDY             #>ASM_PARSE_AT_EOR_SUM
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_EOR_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_EOR_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$10
                        BEQ             ASM_SMOKE_OPERANDS_EOR_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_EOR_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             #ASM_SMOKE_DATA_HI
                        BEQ             ASM_SMOKE_OPERANDS_EOR_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_EOR_HI_OK:

                        LDA             #ASM_OPM_ABS16
                        LDX             #<ASM_PARSE_AT_STA_SUM
                        LDY             #>ASM_PARSE_AT_STA_SUM
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_STA_SUM_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_SUM_OK:
                        LDA             ASM_VALUE_LO
                        CMP             #$10
                        BEQ             ASM_SMOKE_OPERANDS_STA_SUM_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_SUM_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             #ASM_SMOKE_DATA_HI
                        BEQ             ASM_SMOKE_OPERANDS_STA_SUM_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_SUM_HI_OK:

                        LDA             #ASM_OPM_ABS_X
                        LDX             #<ASM_PARSE_AT_STA_OUT_X
                        LDY             #>ASM_PARSE_AT_STA_OUT_X
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_STA_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_OK:
                        LDA             ASM_VALUE_LO
                        BEQ             ASM_SMOKE_OPERANDS_STA_LO_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             #ASM_SMOKE_DATA_HI
                        BEQ             ASM_SMOKE_OPERANDS_STA_HI_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_STA_HI_OK:

                        LDA             #ASM_OPM_ABS_X
                        LDX             #<ASM_PARSE_AT_LOOP_LDA
                        LDY             #>ASM_PARSE_AT_LOOP_LDA
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_LDA_SEED_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_SEED_OK:
                        LDA             ASM_FLAGS
                        AND             #ASM_OPF_UNRESOLVED
                        BNE             ASM_SMOKE_OPERANDS_LDA_SEED_UNRES_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_SEED_UNRES_OK:

                        LDA             #ASM_OPM_REL8
                        LDX             #<ASM_PARSE_AT_BNE
                        LDY             #>ASM_PARSE_AT_BNE
                        JSR             ASM_SMOKE_CLASS_EXPECT
                        BCS             ASM_SMOKE_OPERANDS_BNE_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BNE_OK:
                        LDA             ASM_FLAGS
                        AND             #ASM_OPF_UNRESOLVED
                        BNE             ASM_SMOKE_OPERANDS_BNE_UNRES_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_BNE_UNRES_OK:

                        LDA             #ASM_STATUS_BAD_MODE
                        LDX             #<ASM_CLASS_LDA_A
                        LDY             #>ASM_CLASS_LDA_A
                        JSR             ASM_SMOKE_CLASS_ERR
                        BCS             ASM_SMOKE_OPERANDS_LDA_A_ERR_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_A_ERR_OK:

                        LDA             #ASM_STATUS_BAD_WIDTH
                        LDX             #<ASM_CLASS_LDA_DEC
                        LDY             #>ASM_CLASS_LDA_DEC
                        JSR             ASM_SMOKE_CLASS_ERR
                        BCS             ASM_SMOKE_OPERANDS_LDA_DEC_ERR_OK
                        JMP             ASM_SMOKE_OPERANDS_FAIL
ASM_SMOKE_OPERANDS_LDA_DEC_ERR_OK:

                        SEC
                        RTS

ASM_SMOKE_OPCODE_FAIL_A:
                        JMP             ASM_SMOKE_OPCODE_FAIL

ASM_SMOKE_OPCODE:
                        JSR             ASM_SMOKE_OPCODE_SETUP
                        BCC             ASM_SMOKE_OPCODE_FAIL_A

                        LDX             #<ASM_PARSE_AT_ASMTEST_LDX
                        LDY             #>ASM_PARSE_AT_ASMTEST_LDX
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_LDY
                        LDY             #>ASM_PARSE_AT_LDY
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_STZ
                        LDY             #>ASM_PARSE_AT_STZ
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_STA_OUT_X
                        LDY             #>ASM_PARSE_AT_STA_OUT_X
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_EOR_SUM
                        LDY             #>ASM_PARSE_AT_EOR_SUM
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_STA_SUM
                        LDY             #>ASM_PARSE_AT_STA_SUM
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_INX
                        LDY             #>ASM_PARSE_AT_INX
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_CPX
                        LDY             #>ASM_PARSE_AT_CPX
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_BNE
                        LDY             #>ASM_PARSE_AT_BNE
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_PARSE_AT_RTS
                        LDY             #>ASM_PARSE_AT_RTS
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_A
                        LDX             #<ASM_OPCODE_JMP_ABS
                        LDY             #>ASM_OPCODE_JMP_ABS
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        LDX             #<ASM_OPCODE_JMP_IND
                        LDY             #>ASM_OPCODE_JMP_IND
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        LDX             #<ASM_OPCODE_JMP_ABSXIND
                        LDY             #>ASM_OPCODE_JMP_ABSXIND
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        LDX             #<ASM_OPCODE_BRK_IMM
                        LDY             #>ASM_OPCODE_BRK_IMM
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        LDX             #<ASM_OPCODE_BRK_ZP
                        LDY             #>ASM_OPCODE_BRK_ZP
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        BRA             ASM_SMOKE_OPCODE_ROWS_CONT
ASM_SMOKE_OPCODE_FAIL_B:
                        JMP             ASM_SMOKE_OPCODE_FAIL
ASM_SMOKE_OPCODE_ROWS_CONT:
                        JSR             ASM_SMOKE_OPCODE_INDEX_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_SHIFT_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_BIT_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_BITMEM_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_BITBR_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_STORE_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_RMW_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_ALU_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_INDIRECT_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_ABSY_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_IMPLIED_ROWS
                        BCC             ASM_SMOKE_OPCODE_FAIL_B

                        JSR             ASM_SMOKE_OPCODE_CHECK_BYTES
                        BCC             ASM_SMOKE_OPCODE_FAIL_B
                        JSR             ASM_SMOKE_OPCODE_CHECK_PC
                        BCC             ASM_SMOKE_OPCODE_FAIL_B

                        LDA             #ASM_VID_STZ
                        STA             ASM_STMT_OP_ID
                        LDA             #ASM_OPM_IMM8
                        STA             ASM_MODE
                        JSR             ASM_FIND_OPCODE
                        BCC             ASM_SMOKE_OPCODE_BAD_MODE_RETURNED
                        JMP             ASM_SMOKE_OPCODE_FAIL
ASM_SMOKE_OPCODE_BAD_MODE_RETURNED:
                        CMP             #ASM_STATUS_BAD_MODE
                        BEQ             ASM_SMOKE_OPCODE_BAD_MODE_OK
                        JMP             ASM_SMOKE_OPCODE_FAIL
ASM_SMOKE_OPCODE_BAD_MODE_OK:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_OPCODE_RESTORE_OK
                        JMP             ASM_SMOKE_OPCODE_FAIL
ASM_SMOKE_OPCODE_RESTORE_OK:
                        SEC
                        RTS

ASM_SMOKE_OPCODE_SETUP:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        LDX             #<ASM_PARSE_AT_OUT_EQU
                        LDY             #>ASM_PARSE_AT_OUT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        LDX             #<ASM_PARSE_AT_COUNT_EQU
                        LDY             #>ASM_PARSE_AT_COUNT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        LDX             #<ASM_CLASS_SUM_EQU
                        LDY             #>ASM_CLASS_SUM_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        LDX             #<ASM_OPCODE_LOOP_LABEL
                        LDY             #>ASM_OPCODE_LOOP_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_OPCODE_SETUP_FAIL
                        SEC
                        RTS
ASM_SMOKE_OPCODE_SETUP_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_INDEX_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_INDEX_LOOP:
                        LDA             ASM_OPCODE_INDEX_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_INDEX_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_INDEX_FAIL
                        INX
                        CPX             #$0A
                        BNE             ASM_SMOKE_OPCODE_INDEX_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_INDEX_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_SHIFT_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_SHIFT_LOOP:
                        LDA             ASM_OPCODE_SHIFT_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_SHIFT_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_SHIFT_FAIL
                        INX
                        CPX             #$12
                        BNE             ASM_SMOKE_OPCODE_SHIFT_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_SHIFT_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_BIT_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_BIT_LOOP:
                        LDA             ASM_OPCODE_BIT_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_BIT_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_BIT_FAIL
                        INX
                        CPX             #$05
                        BNE             ASM_SMOKE_OPCODE_BIT_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_BIT_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_BITMEM_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_BITMEM_LOOP:
                        LDA             ASM_OPCODE_BITMEM_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_BITMEM_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_BITMEM_FAIL
                        INX
                        CPX             #$02
                        BNE             ASM_SMOKE_OPCODE_BITMEM_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_BITMEM_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_BITBR_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_BITBR_LOOP:
                        LDA             ASM_OPCODE_BITBR_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_BITBR_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_BITBR_FAIL
                        INX
                        CPX             #$02
                        BNE             ASM_SMOKE_OPCODE_BITBR_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_BITBR_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_STORE_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_STORE_LOOP:
                        LDA             ASM_OPCODE_STORE_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_STORE_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_STORE_FAIL
                        INX
                        CPX             #$0D
                        BNE             ASM_SMOKE_OPCODE_STORE_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_STORE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_RMW_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_RMW_LOOP:
                        LDA             ASM_OPCODE_RMW_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_RMW_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_RMW_FAIL
                        INX
                        CPX             #$0F
                        BNE             ASM_SMOKE_OPCODE_RMW_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_RMW_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_ALU_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_ALU_LOOP:
                        LDA             ASM_OPCODE_ALU_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_ALU_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_ALU_FAIL
                        INX
                        CPX             #$14
                        BNE             ASM_SMOKE_OPCODE_ALU_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_ALU_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_INDIRECT_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_INDIRECT_LOOP:
                        LDA             ASM_OPCODE_INDIRECT_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_INDIRECT_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_INDIRECT_FAIL
                        INX
                        CPX             #$19
                        BNE             ASM_SMOKE_OPCODE_INDIRECT_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_INDIRECT_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_ABSY_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_ABSY_LOOP:
                        LDA             ASM_OPCODE_ABSY_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_ABSY_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_ABSY_FAIL
                        INX
                        CPX             #$07
                        BNE             ASM_SMOKE_OPCODE_ABSY_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_ABSY_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_IMPLIED_ROWS:
                        LDX             #$00
ASM_SMOKE_OPCODE_IMPLIED_LOOP:
                        LDA             ASM_OPCODE_IMPLIED_PTR_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_OPCODE_IMPLIED_PTR_HI,X
                        STA             ASM_TMP0_HI
                        PHX
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        JSR             ASM_SMOKE_EMIT_LINE
                        PLX
                        BCC             ASM_SMOKE_OPCODE_IMPLIED_FAIL
                        INX
                        CPX             #$1C
                        BNE             ASM_SMOKE_OPCODE_IMPLIED_LOOP
                        SEC
                        RTS
ASM_SMOKE_OPCODE_IMPLIED_FAIL:
                        CLC
                        RTS

ASM_SMOKE_EMIT_LINE:
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_EMIT_LINE_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_EMIT_LINE_FAIL
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_MNEM
                        BNE             ASM_SMOKE_EMIT_LINE_FAIL
                        JSR             ASM_EMIT
                        BCC             ASM_SMOKE_EMIT_LINE_FAIL
                        SEC
                        RTS
ASM_SMOKE_EMIT_LINE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_EMIT_LINE_ERR:
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_EMIT_LINE_ERR_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_EMIT_LINE_ERR_FAIL
                        JSR             ASM_EMIT
                        BCS             ASM_SMOKE_EMIT_LINE_ERR_FAIL
                        CMP             #ASM_STATUS_BAD_FIX
                        BNE             ASM_SMOKE_EMIT_LINE_ERR_FAIL
                        SEC
                        RTS
ASM_SMOKE_EMIT_LINE_ERR_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_CHECK_BYTES:
                        LDX             #$00
ASM_SMOKE_OPCODE_CHECK_LOOP:
                        LDA             ASM_CODE_BUF,X
                        CMP             ASM_OPCODE_EXPECT,X
                        BEQ             ASM_SMOKE_OPCODE_CHECK_BYTE_OK
                        JMP             ASM_SMOKE_OPCODE_CHECK_FAIL
ASM_SMOKE_OPCODE_CHECK_BYTE_OK:
                        INX
                        CPX             #$FF
                        BNE             ASM_SMOKE_OPCODE_CHECK_LOOP
                        LDX             #$00
ASM_SMOKE_OPCODE_CHECK_LOOP_HI:
                        LDA             ASM_CODE_BUF+$FF,X
                        CMP             ASM_OPCODE_EXPECT+$FF,X
                        BEQ             ASM_SMOKE_OPCODE_CHECK_BYTE_HI_OK
                        JMP             ASM_SMOKE_OPCODE_CHECK_FAIL
ASM_SMOKE_OPCODE_CHECK_BYTE_HI_OK:
                        INX
                        CPX             #$4C
                        BNE             ASM_SMOKE_OPCODE_CHECK_LOOP_HI
                        SEC
                        RTS

ASM_SMOKE_OPCODE_CHECK_PC:
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        CMP             #$01
                        BNE             ASM_SMOKE_OPCODE_CHECK_FAIL
                        LDA             ASM_TMP0_LO
                        CMP             #$4B
                        BNE             ASM_SMOKE_OPCODE_CHECK_FAIL
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        CMP             #$01
                        BNE             ASM_SMOKE_OPCODE_CHECK_FAIL
                        LDA             ASM_TMP0_LO
                        CMP             #$4B
                        BNE             ASM_SMOKE_OPCODE_CHECK_FAIL
                        SEC
                        RTS
ASM_SMOKE_OPCODE_CHECK_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPCODE_FAIL:
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_FAIL_A:
                        JMP             ASM_SMOKE_FIXUPS_FAIL

ASM_SMOKE_FIXUPS:
                        JSR             ASM_SMOKE_FIXUPS_ABS16
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_REL8
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_BIT_ZP_REL
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_REL8_RANGE
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_SELECTED
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_NAME_SLOT8
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_LOCAL_LABELS
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_PENDING_END
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_IMPORT_ABS16
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_IMPORT_SELECTED
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_IMPORT_FORCE_DEFER
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        JSR             ASM_SMOKE_FIXUPS_RELOCATE
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_FAIL_A
                        SEC
                        RTS

ASM_SMOKE_FIXUPS_ABS16:
                        LDA             #$B1
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_FIXUPS_ABS16_BEGIN_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_BEGIN_OK:
                        LDA             #$B2
                        STA             ASM_SLOT
                        LDX             #<ASM_FIXUP_JSR_FOO
                        LDY             #>ASM_FIXUP_JSR_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_ABS16_EMIT_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_EMIT_OK:
                        LDA             #$B3
                        STA             ASM_SLOT
                        LDA             ASM_CODE_BUF
                        CMP             #$20
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_OP_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_OP_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_LO_PLACE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_LO_PLACE_OK:
                        LDA             ASM_CODE_BUF+2
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_HI_PLACE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_HI_PLACE_OK:
                        LDA             #$B4
                        STA             ASM_SLOT
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_COUNT_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_COUNT_OK:
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_PENDING
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_PENDING_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_PENDING_OK:
                        LDA             ASM_FIX_MODE
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_MODE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_MODE_OK:
                        LDA             #$B5
                        STA             ASM_SLOT
                        JSR             ASM_SMOKE_FIXUPS_CHECK_SITE1
                        BCS             ASM_SMOKE_FIXUPS_ABS16_SITE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_SITE_OK:
                        LDA             #$B6
                        STA             ASM_SLOT
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCS             ASM_SMOKE_FIXUPS_ABS16_PARSE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_PARSE_OK:
                        JSR             ASM_BIND_LABEL
                        BCS             ASM_SMOKE_FIXUPS_ABS16_BIND_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_BIND_OK:
                        LDA             #$B7
                        STA             ASM_SLOT
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_RESOLVED
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_RESOLVE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_RESOLVE_OK:
                        LDA             ASM_FIX_RESOLVE_COUNT
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_RESOLVE_COUNT_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_RESOLVE_COUNT_OK:
                        LDA             ASM_FIX_LAST_SITE_LO
                        CMP             ASM_FIX_SITE_LO
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_RESOLVE_SITE_LO_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_RESOLVE_SITE_LO_OK:
                        LDA             ASM_FIX_LAST_SITE_HI
                        CMP             ASM_FIX_SITE_HI
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_RESOLVE_SITE_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_RESOLVE_SITE_OK:
                        LDA             #$B8
                        STA             ASM_SLOT
                        LDA             ASM_CODE_BUF+1
                        CMP             ASM_PC_LO
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_PATCH_LO_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_PATCH_LO_OK:
                        LDA             #$B9
                        STA             ASM_SLOT
                        LDA             ASM_CODE_BUF+2
                        CMP             ASM_PC_HI
                        BEQ             ASM_SMOKE_FIXUPS_ABS16_PATCH_HI_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_PATCH_HI_OK:
                        LDA             #$BA
                        STA             ASM_SLOT
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_ABS16_END_OK
                        JMP             ASM_SMOKE_FIXUPS_ABS16_FAIL
ASM_SMOKE_FIXUPS_ABS16_END_OK:
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_ABS16_FAIL:
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_REL8:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDX             #<ASM_FIXUP_BNE_FOO
                        LDY             #>ASM_FIXUP_BNE_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$D0
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_FIX_MODE
                        CMP             #ASM_OPM_REL8
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_SITE1
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_BASE2
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_RESOLVED
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        LDA             ASM_CODE_BUF+1
                        BNE             ASM_SMOKE_FIXUPS_REL8_FAIL
                        JSR             ASM_END
                        BCC             ASM_SMOKE_FIXUPS_REL8_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_REL8_FAIL:
                        LDA             #$A2
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_BIT_ZP_REL:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDX             #<ASM_FIXUP_BBR_FOO
                        LDY             #>ASM_FIXUP_BBR_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$3F
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$12
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_CODE_BUF+2
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_FIX_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_SITE2
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_BASE3
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_RESOLVED
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        LDA             ASM_CODE_BUF+2
                        BNE             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        JSR             ASM_END
                        BCC             ASM_SMOKE_FIXUPS_BITREL_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_BITREL_FAIL:
                        LDA             #$A7
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_REL8_RANGE:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        LDX             #<ASM_FIXUP_BNE_FOO
                        LDY             #>ASM_FIXUP_BNE_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        LDA             ASM_START_PC_LO
                        STA             ASM_PC_LO
                        LDA             ASM_START_PC_HI
                        CLC
                        ADC             #$01
                        STA             ASM_PC_HI
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        JSR             ASM_BIND_LABEL
                        BCS             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        CMP             #ASM_STATUS_BAD_RANGE
                        BNE             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_RANGE_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_RANGE_FAIL:
                        LDA             #$A3
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_SELECTED:
                        JSR             ASM_SMOKE_FIXUPS_SELECTED_LO
                        BCC             ASM_SMOKE_FIXUPS_SELECTED_FAIL
                        JSR             ASM_SMOKE_FIXUPS_SELECTED_HI
                        BCC             ASM_SMOKE_FIXUPS_SELECTED_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_SELECTED_FAIL:
                        LDA             #$A4
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_SELECTED_LO:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDX             #<ASM_FIXUP_LDA_LO_FOO
                        LDY             #>ASM_FIXUP_LDA_LO_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$A9
                        BNE             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDA             ASM_FIX_MODE
                        CMP             #ASM_OPM_IMM8
                        BNE             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDA             ASM_FIX_SEL
                        CMP             #ASM_FIX_SEL_LO
                        BNE             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_SITE1
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             ASM_PC_LO
                        BNE             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        JSR             ASM_END
                        BCC             ASM_SMOKE_FIXUPS_SEL_LO_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_SEL_LO_FAIL:
                        LDA             #$A5
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_SELECTED_HI:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDX             #<ASM_FIXUP_LDA_HI_FOO
                        LDY             #>ASM_FIXUP_LDA_HI_FOO
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$A9
                        BNE             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDA             ASM_FIX_MODE
                        CMP             #ASM_OPM_IMM8
                        BNE             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDA             ASM_FIX_SEL
                        CMP             #ASM_FIX_SEL_HI
                        BNE             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        JSR             ASM_SMOKE_FIXUPS_CHECK_SITE1
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDX             #<ASM_FIXUP_FOO_LABEL
                        LDY             #>ASM_FIXUP_FOO_LABEL
                        JSR             ASM_SMOKE_PARSE_FOR_NAME
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             ASM_PC_HI
                        BNE             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        JSR             ASM_END
                        BCC             ASM_SMOKE_FIXUPS_SEL_HI_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_SEL_HI_FAIL:
                        LDA             #$A6
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_NAME_SLOT8:
                        LDX             #$00
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDA             ASM_FIX_PTR_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_FIX_PTR_HI
                        STA             ASM_TMP1_HI
                        LDX             #$08
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDA             ASM_FIX_PTR_LO
                        CMP             ASM_TMP1_LO
                        BNE             ASM_SMOKE_FIXUPS_NAME_SLOT8_FAIL
                        LDA             ASM_TMP1_HI
                        CLC
                        ADC             #$01
                        CMP             ASM_FIX_PTR_HI
                        BNE             ASM_SMOKE_FIXUPS_NAME_SLOT8_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_NAME_SLOT8_FAIL:
                        LDA             #$A8
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_LOCAL_LABELS:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_MAIN_BRA
                        LDY             #>ASM_FIXUP_LOCAL_MAIN_BRA
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_LDA
                        LDY             #>ASM_FIXUP_LOCAL_LDA
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_SKIP
                        LDY             #>ASM_FIXUP_LOCAL_SKIP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_NEXT
                        LDY             #>ASM_FIXUP_LOCAL_NEXT
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_PARSE_AT_END
                        LDY             #>ASM_PARSE_AT_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$80
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$02
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF+2
                        CMP             #$A9
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF+3
                        CMP             #$EE
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF+4
                        CMP             #$EA
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDA             ASM_CODE_BUF+5
                        CMP             #$EA
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL

                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_MISS
                        LDY             #>ASM_FIXUP_LOCAL_MISS
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        LDX             #<ASM_FIXUP_LOCAL_NEXT
                        LDY             #>ASM_FIXUP_LOCAL_NEXT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        CMP             #ASM_STATUS_BAD_FIX
                        BNE             ASM_SMOKE_FIXUPS_LOCAL_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_LOCAL_FAIL:
                        LDA             #$A9
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_PENDING_END:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_PENDING_FAIL
                        LDX             #<ASM_FIXUP_JSR_BAR
                        LDY             #>ASM_FIXUP_JSR_BAR
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_PENDING_FAIL
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_PENDING_FAIL
                        CMP             #ASM_STATUS_BAD_FIX
                        BNE             ASM_SMOKE_FIXUPS_PENDING_FAIL
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_PENDING_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_PENDING_FAIL:
                        LDA             #$A7
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_IMPORT_ABS16:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDX             #<ASM_DIRECT_IMPORT_EXT
                        LDY             #>ASM_DIRECT_IMPORT_EXT
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDX             #<ASM_FIXUP_JSR_EXT
                        LDY             #>ASM_FIXUP_JSR_EXT
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCC             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_CODE_BUF
                        CMP             #$20
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_CODE_BUF+2
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_FIX_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_FIX_SEL
                        AND             #ASM_FIXF_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        JSR             ASM_END
                        BCC             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_IMPORTED
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_COUNT
                        CMP             #$01
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_KIND
                        CMP             #ASM_RELOC_ABS16_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_SITE_LO
                        CMP             #$01
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_SITE_HI
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_TARGET_LO
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        LDA             ASM_RELOC_TARGET_HI
                        BNE             ASM_SMOKE_FIXUPS_IMPORT_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_IMPORT_FAIL:
                        LDA             #$AC
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_IMPORT_SELECTED:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_FIXUPS_IMP_SEL_BEGIN_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_BEGIN_OK:
                        LDX             #<ASM_DIRECT_IMPORT_EXT
                        LDY             #>ASM_DIRECT_IMPORT_EXT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_SEL_IMPORT_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_IMPORT_OK:
                        LDX             #<ASM_FIXUP_LDA_LO_EXT
                        LDY             #>ASM_FIXUP_LDA_LO_EXT
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_SEL_LDA_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_LDA_OK:
                        LDX             #<ASM_FIXUP_LDX_HI_EXT
                        LDY             #>ASM_FIXUP_LDX_HI_EXT
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_SEL_LDX_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_LDX_OK:
                        LDA             ASM_CODE_BUF
                        CMP             #$A9
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_B0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_B0_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_B1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_B1_OK:
                        LDA             ASM_CODE_BUF+2
                        CMP             #$A2
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_B2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_B2_OK:
                        LDA             ASM_CODE_BUF+3
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_B3_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_B3_OK:
                        LDA             ASM_FIX_COUNT
                        CMP             #$02
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_COUNT_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_COUNT_OK:
                        LDA             ASM_FIX_SEL
                        AND             #ASM_FIXF_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_F0_IMPORT
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_F0_IMPORT:
                        LDA             ASM_FIX_SEL
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_F0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_F0_OK:
                        LDA             ASM_FIX_SEL+1
                        AND             #ASM_FIXF_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_F1_IMPORT
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_F1_IMPORT:
                        LDA             ASM_FIX_SEL+1
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_F1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_F1_OK:
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_IMP_SEL_END_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_END_OK:
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_IMPORTED
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_ST0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_ST0_OK:
                        LDA             ASM_FIX_STATE+1
                        CMP             #ASM_FIX_IMPORTED
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_ST1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_ST1_OK:
                        LDA             ASM_RELOC_COUNT
                        CMP             #$02
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_RC_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_RC_OK:
                        LDA             ASM_RELOC_KIND
                        CMP             #ASM_RELOC_LO8_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_K0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_K0_OK:
                        LDA             ASM_RELOC_KIND+1
                        CMP             #ASM_RELOC_HI8_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_K1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_K1_OK:
                        LDA             ASM_RELOC_SITE_LO
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_S0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_S0_OK:
                        LDA             ASM_RELOC_SITE_HI
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_SH0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_SH0_OK:
                        LDA             ASM_RELOC_SITE_LO+1
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_S1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_S1_OK:
                        LDA             ASM_RELOC_SITE_HI+1
                        BEQ             ASM_SMOKE_FIXUPS_IMP_SEL_SH1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
ASM_SMOKE_FIXUPS_IMP_SEL_SH1_OK:
                        LDA             ASM_RELOC_TARGET_LO
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
                        LDA             ASM_RELOC_TARGET_HI
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
                        LDA             ASM_RELOC_TARGET_LO+1
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
                        LDA             ASM_RELOC_TARGET_HI+1
                        BNE             ASM_SMOKE_FIXUPS_IMP_SEL_FAIL
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_IMP_SEL_FAIL:
                        LDA             #$AC
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_IMPORT_FORCE_DEFER:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_BEGIN0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_BEGIN0_OK:
                        LDX             #<ASM_FIXUP_JSR_PUT_CSTR
                        LDY             #>ASM_FIXUP_JSR_PUT_CSTR
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_OK:
                        LDA             ASM_CODE_BUF
                        CMP             #$20
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_OP_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_OP_OK:
                        LDA             ASM_FIX_COUNT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_FIX_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_FIX_OK:
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_END_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_END_OK:
                        LDA             ASM_RELOC_COUNT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_REL_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PLAIN_REL_OK:
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_BEGIN1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_BEGIN1_OK:
                        LDX             #<ASM_DIRECT_IMPORT_PUT_CSTR
                        LDY             #>ASM_DIRECT_IMPORT_PUT_CSTR
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_IMPORT_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_IMPORT_OK:
                        LDA             ASM_IMPORT_COUNT
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_IC_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_IC_OK:
                        LDX             #<ASM_FIXUP_JSR_PUT_CSTR
                        LDY             #>ASM_FIXUP_JSR_PUT_CSTR
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_JSR_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_JSR_OK:
                        LDX             #<ASM_FIXUP_LDA_LO_PUT_CSTR
                        LDY             #>ASM_FIXUP_LDA_LO_PUT_CSTR
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_LDA_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_LDA_OK:
                        LDX             #<ASM_FIXUP_LDX_HI_PUT_CSTR
                        LDY             #>ASM_FIXUP_LDX_HI_PUT_CSTR
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_LDX_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_LDX_OK:
                        LDA             ASM_CODE_BUF
                        CMP             #$20
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B0_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B1_OK:
                        LDA             ASM_CODE_BUF+2
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B2_OK:
                        LDA             ASM_CODE_BUF+3
                        CMP             #$A9
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B3_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B3_OK:
                        LDA             ASM_CODE_BUF+4
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B4_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B4_OK:
                        LDA             ASM_CODE_BUF+5
                        CMP             #$A2
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B5_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B5_OK:
                        LDA             ASM_CODE_BUF+6
                        CMP             #$FF
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_B6_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_B6_OK:
                        LDA             ASM_FIX_COUNT
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_FC_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_FC_OK:
                        LDA             ASM_FIX_SEL
                        AND             #ASM_FIXF_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_F0_IMPORT
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F0_IMPORT:
                        LDA             ASM_FIX_SEL
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_FULL
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_F0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F0_OK:
                        LDA             ASM_FIX_SEL+1
                        AND             #ASM_FIXF_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_F1_IMPORT
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F1_IMPORT:
                        LDA             ASM_FIX_SEL+1
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_F1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F1_OK:
                        LDA             ASM_FIX_SEL+2
                        AND             #ASM_FIXF_IMPORT
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_F2_IMPORT
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F2_IMPORT:
                        LDA             ASM_FIX_SEL+2
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_F2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_F2_OK:
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_END_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_END_OK:
                        LDA             ASM_FIX_STATE
                        CMP             #ASM_FIX_IMPORTED
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_ST0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_ST0_OK:
                        LDA             ASM_FIX_STATE+1
                        CMP             #ASM_FIX_IMPORTED
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_ST1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_ST1_OK:
                        LDA             ASM_FIX_STATE+2
                        CMP             #ASM_FIX_IMPORTED
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_ST2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_ST2_OK:
                        LDA             ASM_RELOC_COUNT
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_RC_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_RC_OK:
                        LDA             ASM_RELOC_KIND
                        CMP             #ASM_RELOC_ABS16_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_K0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_K0_OK:
                        LDA             ASM_RELOC_KIND+1
                        CMP             #ASM_RELOC_LO8_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_K1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_K1_OK:
                        LDA             ASM_RELOC_KIND+2
                        CMP             #ASM_RELOC_HI8_IMPORT
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_K2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_K2_OK:
                        LDA             ASM_RELOC_SITE_LO
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_S0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_S0_OK:
                        LDA             ASM_RELOC_SITE_HI
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_SH0_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_SH0_OK:
                        LDA             ASM_RELOC_SITE_LO+1
                        CMP             #$04
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_S1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_S1_OK:
                        LDA             ASM_RELOC_SITE_HI+1
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_SH1_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_SH1_OK:
                        LDA             ASM_RELOC_SITE_LO+2
                        CMP             #$06
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_S2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_S2_OK:
                        LDA             ASM_RELOC_SITE_HI+2
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_SH2_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_SH2_OK:
                        LDA             ASM_RELOC_TARGET_LO
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        LDA             ASM_RELOC_TARGET_HI
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        LDA             ASM_RELOC_TARGET_LO+1
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        LDA             ASM_RELOC_TARGET_HI+1
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        LDA             ASM_RELOC_TARGET_LO+2
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        LDA             ASM_RELOC_TARGET_HI+2
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
                        JSR             ASM_SEAL_RESOLVE_IMPORTS
                        BCS             ASM_SMOKE_FIXUPS_IMP_DEF_RESOLVE_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_RESOLVE_OK:
                        LDA             ASM_IMPORT_RESOLVE_COUNT
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_RCNT_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_RCNT_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             ASM_CODE_BUF+4
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_LOW_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_LOW_OK:
                        LDA             ASM_CODE_BUF+2
                        CMP             ASM_CODE_BUF+6
                        BEQ             ASM_SMOKE_FIXUPS_IMP_DEF_HIGH_OK
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_HIGH_OK:
                        LDA             ASM_CODE_BUF+1
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_PATCHED
                        LDA             ASM_CODE_BUF+2
                        CMP             #$FF
                        BNE             ASM_SMOKE_FIXUPS_IMP_DEF_PATCHED
                        JMP             ASM_SMOKE_FIXUPS_IMP_DEF_FAIL
ASM_SMOKE_FIXUPS_IMP_DEF_PATCHED:
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_IMP_DEF_FAIL:
                        LDA             #$AC
                        STA             ASM_SLOT
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_RELOCATE:
                        LDA             #$BB
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_FIXUPS_RELOC_BEGIN_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_BEGIN_OK:
                        LDX             #<ASM_FIXUP_JSR_TARGET
                        LDY             #>ASM_FIXUP_JSR_TARGET
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_RELOC_JSR_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_JSR_OK:
                        LDX             #<ASM_FIXUP_LDA_LO_TARGET
                        LDY             #>ASM_FIXUP_LDA_LO_TARGET
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_RELOC_LDA_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_LDA_OK:
                        LDX             #<ASM_FIXUP_LDX_HI_TARGET
                        LDY             #>ASM_FIXUP_LDX_HI_TARGET
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_RELOC_LDX_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_LDX_OK:
                        LDX             #<ASM_FIXUP_TARGET_RTS
                        LDY             #>ASM_FIXUP_TARGET_RTS
                        JSR             ASM_SMOKE_EMIT_LINE
                        BCS             ASM_SMOKE_FIXUPS_RELOC_TARGET_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_TARGET_OK:
                        JSR             ASM_END
                        BCS             ASM_SMOKE_FIXUPS_RELOC_END_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_END_OK:
                        LDA             ASM_RELOC_COUNT
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_RC_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_RC_OK:
                        LDA             ASM_RELOC_KIND
                        CMP             #ASM_RELOC_ABS16_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_K0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_K0_OK:
                        LDA             ASM_RELOC_KIND+1
                        CMP             #ASM_RELOC_LO8_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_K1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_K1_OK:
                        LDA             ASM_RELOC_KIND+2
                        CMP             #ASM_RELOC_HI8_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_K2_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_K2_OK:
                        LDA             ASM_SEAL_END_LO
                        CLC
                        ADC             #$10
                        TAX
                        LDA             ASM_SEAL_END_HI
                        ADC             #$00
                        TAY
                        JSR             ASM_SEAL_RELOCATE
                        BCS             ASM_SMOKE_FIXUPS_RELOC_CALL_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_CALL_OK:
                        LDA             ASM_RELOCATE_COUNT
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_PC_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_PC_OK:
                        LDA             ASM_RELOCATE_BASE_LO
                        CLC
                        ADC             #$07
                        STA             ASM_TMP0_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_RELOCATE_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$20
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B0_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_LO
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B1_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_HI
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B2_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B2_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$A9
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B3_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B3_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_LO
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B4_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B4_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$A2
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B5_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B5_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_HI
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B6_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B6_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$60
                        BEQ             ASM_SMOKE_FIXUPS_RELOC_B7_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_RELOC_B7_OK:
                        IF              ASM_PACKAGE_ENABLED
                        LDA             ASM_RELOCATE_BASE_LO
                        CLC
                        ADC             #$20
                        TAX
                        LDA             ASM_RELOCATE_BASE_HI
                        ADC             #$00
                        TAY
                        JSR             ASM_SEAL_PACKAGE
                        BCS             ASM_SMOKE_FIXUPS_PACKAGE_CALL_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_CALL_OK:
                        LDA             ASM_PACKAGE_LEN_LO
                        CMP             #$37
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_LEN_LO_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_LEN_LO_OK:
                        LDA             ASM_PACKAGE_LEN_HI
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_LEN_HI_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_LEN_HI_OK:
                        LDA             ASM_PACKAGE_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDY             #ASM_PACKAGE_OFF_SIG0
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_SIG0
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_SIG0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_SIG0_OK:
                        LDY             #ASM_PACKAGE_OFF_SIG1
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_SIG1
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_SIG1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_SIG1_OK:
                        LDY             #ASM_PACKAGE_OFF_VER
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_VERSION
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_VER_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_VER_OK:
                        LDY             #ASM_PACKAGE_OFF_TOTAL
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$37
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_TOTAL_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_TOTAL_OK:
                        LDY             #$05
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_TAG_SEAL
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_SEAL_TAG_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_SEAL_TAG_OK:
                        LDY             #$12
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_TAG_RELOC
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_TAG_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_TAG_OK:
                        LDY             #$13
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$10
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_LEN_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_LEN_OK:
                        LDY             #$14
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$03
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_COUNT_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_COUNT_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_RELOC_ABS16_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_K0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_K0_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_RELOC_LO8_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_K1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_K1_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_RELOC_HI8_INTERNAL
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_K2_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_K2_OK:
                        LDY             #$18
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$01
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_S0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_S0_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$04
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_S1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_S1_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$06
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_REL_S2_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_REL_S2_OK:
                        LDA             ASM_SEAL_BASE_LO
                        CLC
                        ADC             #$07
                        STA             ASM_TMP0_LO
                        LDA             ASM_SEAL_BASE_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDY             #$2F
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #$20
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_BODY0_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_BODY0_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_LO
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_BODY1_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_BODY1_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_HI
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_BODY2_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_BODY2_OK:
                        IF              ASM_PACKAGE_CHECK_ENABLED
                        LDX             ASM_PACKAGE_BASE_LO
                        LDY             ASM_PACKAGE_BASE_HI
                        JSR             ASM_SEAL_CHECK_PACKAGE
                        BCS             ASM_SMOKE_FIXUPS_PACKAGE_CHECK_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_CHECK_OK:
                        LDA             ASM_PACKAGE_LEN_LO
                        CMP             #$37
                        BEQ             ASM_SMOKE_FIXUPS_PACKAGE_CHECK_LEN_OK
                        JMP             ASM_SMOKE_FIXUPS_RELOC_FAIL
ASM_SMOKE_FIXUPS_PACKAGE_CHECK_LEN_OK:
                        ENDIF
                        ENDIF
                        SEC
                        RTS
ASM_SMOKE_FIXUPS_RELOC_FAIL:
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_CHECK_SITE1:
                        LDA             ASM_START_PC_LO
                        CLC
                        ADC             #$01
                        STA             ASM_TMP0_LO
                        LDA             ASM_START_PC_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_TMP0_LO
                        CMP             ASM_FIX_SITE_LO
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        LDA             ASM_TMP0_HI
                        CMP             ASM_FIX_SITE_HI
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_FIXUPS_CHECK_BASE2:
                        LDA             ASM_START_PC_LO
                        CLC
                        ADC             #$02
                        STA             ASM_TMP0_LO
                        LDA             ASM_START_PC_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_TMP0_LO
                        CMP             ASM_FIX_BASE_LO
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        LDA             ASM_TMP0_HI
                        CMP             ASM_FIX_BASE_HI
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_FIXUPS_CHECK_SITE2:
                        LDA             ASM_START_PC_LO
                        CLC
                        ADC             #$02
                        STA             ASM_TMP0_LO
                        LDA             ASM_START_PC_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_TMP0_LO
                        CMP             ASM_FIX_SITE_LO
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        LDA             ASM_TMP0_HI
                        CMP             ASM_FIX_SITE_HI
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_FIXUPS_CHECK_BASE3:
                        LDA             ASM_START_PC_LO
                        CLC
                        ADC             #$03
                        STA             ASM_TMP0_LO
                        LDA             ASM_START_PC_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_TMP0_LO
                        CMP             ASM_FIX_BASE_LO
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        LDA             ASM_TMP0_HI
                        CMP             ASM_FIX_BASE_HI
                        BNE             ASM_SMOKE_FIXUPS_CHECK_FAIL
                        SEC
                        RTS

ASM_SMOKE_FIXUPS_CHECK_FAIL:
                        CLC
                        RTS

ASM_SMOKE_FIXUPS_FAIL:
                        CLC
                        RTS

ASM_SMOKE_DIRECTIVES:
                        LDA             #$D4
                        STA             ASM_SLOT
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #$00
                        LDY             #ASM_TARGET_LIMIT_HI
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_DIRECT_BEGIN_PROTECTED_ERR
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_BEGIN_PROTECTED_ERR:
                        CMP             #ASM_STATUS_BAD_RANGE
                        BEQ             ASM_SMOKE_DIRECT_BEGIN_PROTECTED_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_BEGIN_PROTECTED_OK:
                        LDA             #$C1
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_BEGIN_OK:
                        LDA             #$C2
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_ADDR_EQU
                        LDY             #>ASM_DIRECT_ADDR_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_ADDR_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ADDR_OK:
                        LDA             #$C3
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_DB_MIXED
                        LDY             #>ASM_DIRECT_DB_MIXED
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DB_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DB_OK:
                        LDA             #$C4
                        STA             ASM_SLOT
                        LDX             #$00
ASM_SMOKE_DIRECT_BYTES_LOOP:
                        LDA             ASM_CODE_BUF,X
                        CMP             ASM_DIRECT_DB_EXPECT,X
                        BEQ             ASM_SMOKE_DIRECT_BYTE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_BYTE_OK:
                        INX
                        CPX             #$07
                        BNE             ASM_SMOKE_DIRECT_BYTES_LOOP

                        LDA             #$C5
                        STA             ASM_SLOT
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_PC_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_PC_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$07
                        BEQ             ASM_SMOKE_DIRECT_PC_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_PC_LO_OK:
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_HIGH_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_HIGH_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$07
                        BEQ             ASM_SMOKE_DIRECT_HIGH_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_HIGH_LO_OK:

                        LDA             #$D6
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DW_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_BEGIN_OK:
                        LDX             #<ASM_DIRECT_DW_LIST
                        LDY             #>ASM_DIRECT_DW_LIST
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DW_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_OK:
                        LDA             #$D7
                        STA             ASM_SLOT
                        LDX             #$00
ASM_SMOKE_DIRECT_DW_BYTES_LOOP:
                        LDA             ASM_CODE_BUF,X
                        CMP             ASM_DIRECT_DW_EXPECT,X
                        BEQ             ASM_SMOKE_DIRECT_DW_BYTE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_BYTE_OK:
                        INX
                        CPX             #$08
                        BNE             ASM_SMOKE_DIRECT_DW_BYTES_LOOP

                        LDA             #$D8
                        STA             ASM_SLOT
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DW_PC_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_PC_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$08
                        BEQ             ASM_SMOKE_DIRECT_DW_PC_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_PC_LO_OK:
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DW_HIGH_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_HIGH_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$08
                        BEQ             ASM_SMOKE_DIRECT_DW_HIGH_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_HIGH_LO_OK:

                        LDA             #$D9
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DW_EMPTY_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_EMPTY_BEGIN_OK:
                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_DW_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_DW_EMPTY
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_DW_EMPTY_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DW_EMPTY_OK:

                        LDA             #$C6
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_EMPTY_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_EMPTY_BEGIN_OK:
                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_SMOKE_PARSE_DB_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_DB_EMPTY
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_EMPTY_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_EMPTY_OK:

                        LDA             #$C7
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_UNKNOWN_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_UNKNOWN_BEGIN_OK:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        LDX             #<ASM_DIRECT_DB_UNKNOWN
                        LDY             #>ASM_DIRECT_DB_UNKNOWN
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_UNKNOWN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_UNKNOWN_OK:
                        LDA             #$C8
                        STA             ASM_SLOT
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_ORG_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_BEGIN_OK:
                        LDX             #<ASM_DIRECT_ORG_CURRENT
                        LDY             #>ASM_DIRECT_ORG_CURRENT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_ORG_CURRENT_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_CURRENT_OK:
                        LDA             ASM_PC_LO
                        BNE             ASM_SMOKE_DIRECT_ORG_CURRENT_BAD
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_DIRECT_ORG_CURRENT_BAD
                        LDA             ASM_HIGH_PC_LO
                        BNE             ASM_SMOKE_DIRECT_ORG_CURRENT_BAD
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BEQ             ASM_SMOKE_DIRECT_ORG_CURRENT_PC_OK
ASM_SMOKE_DIRECT_ORG_CURRENT_BAD:
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_CURRENT_PC_OK:

                        LDA             #$C9
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_ORG_FORWARD
                        LDY             #>ASM_DIRECT_ORG_FORWARD
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_ORG_FORWARD_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_FORWARD_OK:
                        LDA             ASM_PC_LO
                        CMP             #ASM_SMOKE_TARGET_FWD_LO
                        BNE             ASM_SMOKE_DIRECT_ORG_FORWARD_BAD
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_DIRECT_ORG_FORWARD_BAD
                        LDA             ASM_HIGH_PC_LO
                        CMP             #ASM_SMOKE_TARGET_FWD_LO
                        BNE             ASM_SMOKE_DIRECT_ORG_FORWARD_BAD
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BEQ             ASM_SMOKE_DIRECT_ORG_FORWARD_PC_OK
ASM_SMOKE_DIRECT_ORG_FORWARD_BAD:
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_FORWARD_PC_OK:

                        LDA             #$CA
                        STA             ASM_SLOT
                        LDA             #ASM_STATUS_BAD_RANGE
                        LDX             #<ASM_DIRECT_ORG_BACKWARD
                        LDY             #>ASM_DIRECT_ORG_BACKWARD
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_ORG_BACK_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_BACK_OK:
                        LDA             #$D5
                        STA             ASM_SLOT
                        LDA             #ASM_STATUS_BAD_RANGE
                        LDX             #<ASM_DIRECT_ORG_PROTECTED
                        LDY             #>ASM_DIRECT_ORG_PROTECTED
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_ORG_PROTECTED_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_ORG_PROTECTED_OK:
                        LDA             #$CB
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DS_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_BEGIN_OK:
                        LDX             #<ASM_DIRECT_DS_FILL
                        LDY             #>ASM_DIRECT_DS_FILL
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DS_FILL_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_FILL_OK:
                        LDX             #<ASM_DIRECT_DS_TRUNC
                        LDY             #>ASM_DIRECT_DS_TRUNC
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DS_TRUNC_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_TRUNC_OK:
                        LDA             #$CC
                        STA             ASM_SLOT
                        LDX             #$00
ASM_SMOKE_DIRECT_DS_BYTES_LOOP:
                        LDA             ASM_CODE_BUF,X
                        CMP             ASM_DIRECT_DS_EXPECT,X
                        BEQ             ASM_SMOKE_DIRECT_DS_BYTE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_BYTE_OK:
                        INX
                        CPX             #$05
                        BNE             ASM_SMOKE_DIRECT_DS_BYTES_LOOP

                        LDA             #$CD
                        STA             ASM_SLOT
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DS_PC_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_PC_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$05
                        BEQ             ASM_SMOKE_DIRECT_DS_PC_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_PC_LO_OK:
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DS_HIGH_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_HIGH_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$05
                        BEQ             ASM_SMOKE_DIRECT_DS_HIGH_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_HIGH_LO_OK:

                        LDA             #$CE
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DS_EMPTY_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_EMPTY_BEGIN_OK:
                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_DIRECT_DS_EMPTY
                        LDY             #>ASM_DIRECT_DS_EMPTY
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_DS_EMPTY_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_EMPTY_OK:

                        LDA             #$CF
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DS_RANGE_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_RANGE_BEGIN_OK:
                        LDA             #ASM_STATUS_BAD_RANGE
                        LDX             #<ASM_DIRECT_DS_RANGE
                        LDY             #>ASM_DIRECT_DS_RANGE
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_DS_RANGE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_RANGE_OK:
                        LDA             #$D0
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_DS_LIST_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_BEGIN_OK:
                        LDX             #<ASM_DIRECT_DS_LIST
                        LDY             #>ASM_DIRECT_DS_LIST
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DS_LIST_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_OK:
                        LDX             #<ASM_DIRECT_DS_LIST_TRUNC
                        LDY             #>ASM_DIRECT_DS_LIST_TRUNC
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_DS_LIST_TRUNC_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_TRUNC_OK:
                        LDA             #$D1
                        STA             ASM_SLOT
                        LDX             #$00
ASM_SMOKE_DIRECT_DS_LIST_BYTES_LOOP:
                        LDA             ASM_CODE_BUF,X
                        CMP             ASM_DIRECT_DS_LIST_EXPECT,X
                        BEQ             ASM_SMOKE_DIRECT_DS_LIST_BYTE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_BYTE_OK:
                        INX
                        CPX             #$09
                        BNE             ASM_SMOKE_DIRECT_DS_LIST_BYTES_LOOP

                        LDA             #$D2
                        STA             ASM_SLOT
                        LDA             ASM_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DS_LIST_PC_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_PC_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$09
                        BEQ             ASM_SMOKE_DIRECT_DS_LIST_PC_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_PC_LO_OK:
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_DS_LIST_HIGH_HI_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_HIGH_HI_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$09
                        BEQ             ASM_SMOKE_DIRECT_DS_LIST_HIGH_LO_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_LIST_HIGH_LO_OK:
                        LDA             #$D3
                        STA             ASM_SLOT
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_WARN_DS_WRAP
                        BNE             ASM_SMOKE_DIRECT_DS_WRAP_WARN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_DS_WRAP_WARN_OK:
                        ORA             ASM_SMOKE_REPORT_FLAGS
                        STA             ASM_SMOKE_REPORT_FLAGS

                        LDA             #$DA
                        STA             ASM_SLOT
                        LDA             #$00
                        TAX
                        TAY
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_IMPORT_BEGIN_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_BEGIN_OK:
                        LDX             #<ASM_DIRECT_IMPORT_EXT
                        LDY             #>ASM_DIRECT_IMPORT_EXT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_DIRECT_IMPORT_EXT_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_EXT_OK:
                        LDA             ASM_IMPORT_COUNT
                        CMP             #$01
                        BEQ             ASM_SMOKE_DIRECT_IMPORT_COUNT_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_COUNT_OK:
                        LDA             ASM_FIX_COUNT
                        BEQ             ASM_SMOKE_DIRECT_IMPORT_FIX_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_FIX_OK:
                        LDA             ASM_PC_LO
                        CMP             ASM_START_PC_LO
                        BNE             ASM_SMOKE_DIRECT_IMPORT_PC_BAD
                        LDA             ASM_PC_HI
                        CMP             ASM_START_PC_HI
                        BEQ             ASM_SMOKE_DIRECT_IMPORT_PC_OK
ASM_SMOKE_DIRECT_IMPORT_PC_BAD:
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_PC_OK:
                        LDA             #ASM_STATUS_BAD_SYM
                        LDX             #<ASM_DIRECT_IMPORT_LDA
                        LDY             #>ASM_DIRECT_IMPORT_LDA
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_IMPORT_LDA_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_LDA_OK:
                        LDA             #ASM_STATUS_BAD_OPER
                        LDX             #<ASM_DIRECT_IMPORT_EXT_X
                        LDY             #>ASM_DIRECT_IMPORT_EXT_X
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_IMPORT_EXT_X_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_EXT_X_OK:
                        LDA             #ASM_STATUS_BAD_SYM
                        LDX             #<ASM_DIRECT_IMPORT_EXT
                        LDY             #>ASM_DIRECT_IMPORT_EXT
                        JSR             ASM_SMOKE_ASSEMBLE_LINE_ERR
                        BCS             ASM_SMOKE_DIRECT_IMPORT_DUP_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_IMPORT_DUP_OK:

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_DIRECT_RESTORE_OK
                        JMP             ASM_SMOKE_DIRECT_FAIL
ASM_SMOKE_DIRECT_RESTORE_OK:
                        SEC
                        RTS
ASM_SMOKE_DIRECT_FAIL:
                        CLC
                        RTS

ASM_SMOKE_REPORT:
                        LDA             #$E1
                        STA             ASM_SLOT
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_REPORT_BEGIN_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_BEGIN_OK:
                        LDA             #$E2
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_ORG_CURRENT
                        LDY             #>ASM_DIRECT_ORG_CURRENT
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_ORG_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_ORG_OK:
                        LDA             #$E3
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_ADDR_EQU
                        LDY             #>ASM_DIRECT_ADDR_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_EQU_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_EQU_OK:
                        LDA             #$E4
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_DB_MIXED
                        LDY             #>ASM_DIRECT_DB_MIXED
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_DB_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_DB_OK:
                        LDA             #$E5
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_DS_FILL
                        LDY             #>ASM_DIRECT_DS_FILL
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_DS_FILL_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_DS_FILL_OK:
                        LDA             #$E6
                        STA             ASM_SLOT
                        LDX             #<ASM_DIRECT_DS_TRUNC
                        LDY             #>ASM_DIRECT_DS_TRUNC
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_DS_TRUNC_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_DS_TRUNC_OK:
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_PRINT_END
                        STA             ASM_REPORT_FLAGS

                        LDA             #$E7
                        STA             ASM_SLOT
                        LDX             #<ASM_SMOKE_PARSE_END
                        LDY             #>ASM_SMOKE_PARSE_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_REPORT_END_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_END_OK:
                        LDA             #$E8
                        STA             ASM_SLOT
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ENDED
                        BNE             ASM_SMOKE_REPORT_FAIL_E8
                        LDA             ASM_STATUS
                        BNE             ASM_SMOKE_REPORT_FAIL_E8
                        LDA             ASM_LAST_STATUS
                        BNE             ASM_SMOKE_REPORT_FAIL_E8
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BEQ             ASM_SMOKE_REPORT_FAIL_E8
                        BRA             ASM_SMOKE_REPORT_CHECK_E9
ASM_SMOKE_REPORT_FAIL_E8:
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_E9:
                        LDA             #$E9
                        STA             ASM_SLOT
                        LDA             ASM_START_PC_LO
                        CMP             #ASM_SMOKE_TARGET_LO
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_START_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_PC_LO
                        CMP             #$0C
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_HIGH_PC_LO
                        CMP             #$0C
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_HIGH_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_FLAGS
                        CMP             #ASM_SEALF_VALID
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_BASE_LO
                        CMP             #ASM_SMOKE_TARGET_LO
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_BASE_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_END_LO
                        CMP             #$0C
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_END_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_LEN_LO
                        CMP             #$0C
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        LDA             ASM_SEAL_LEN_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_E9
                        BRA             ASM_SMOKE_REPORT_CHECK_EA
ASM_SMOKE_REPORT_FAIL_E9:
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_EA:
                        LDA             #$EA
                        STA             ASM_SLOT
                        LDA             ASM_LINE_COUNT_LO
                        CMP             #$06
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_LINE_COUNT_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_COUNT
                        CMP             #$03
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_FIX_COUNT
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_REF_COUNT
                        CMP             #$02
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_USECNT
                        CMP             #$02
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_FIRSTREF_LO
                        CMP             #$03
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_FIRSTREF_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_FLAGS
                        AND             #ASM_SYMF_USED
                        BEQ             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_LO
                        CMP             #$02
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_HI
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_LO+1
                        CMP             #$03
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_HI+1
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_FLAGS+1
                        AND             #ASM_SYMF_USED
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_LO+2
                        CMP             #$04
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_DEFLINE_HI+2
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        LDA             ASM_SYM_FLAGS+2
                        AND             #ASM_SYMF_USED
                        BNE             ASM_SMOKE_REPORT_FAIL_EA
                        BRA             ASM_SMOKE_REPORT_CHECK_EB
ASM_SMOKE_REPORT_FAIL_EA:
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_EB:
                        LDA             #$EB
                        STA             ASM_SLOT
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_ORG_SEEN
                        BEQ             ASM_SMOKE_REPORT_FAIL_EB
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_WARN_DS_WRAP
                        BNE             ASM_SMOKE_REPORT_FAIL_EB
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINT_END
                        BEQ             ASM_SMOKE_REPORT_FAIL_EB
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BEQ             ASM_SMOKE_REPORT_FAIL_EB
                        BRA             ASM_SMOKE_REPORT_CHECK_EC
ASM_SMOKE_REPORT_FAIL_EB:
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_EC:
                        LDA             #$EC
                        STA             ASM_SLOT
                        JSR             ASM_END
                        BCS             ASM_SMOKE_REPORT_SECOND_END_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_SECOND_END_OK:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BNE             ASM_SMOKE_REPORT_CHECK_ED
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_ED:
                        LDA             #$ED
                        STA             ASM_SLOT
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_REPORT_FAIL_BEGIN_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_BEGIN_OK:
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_PRINT_FAIL
                        STA             ASM_REPORT_FLAGS

                        LDA             #$EE
                        STA             ASM_SLOT
                        LDX             #<ASM_SMOKE_PARSE_ORG_EMPTY
                        LDY             #>ASM_SMOKE_PARSE_ORG_EMPTY
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_REPORT_FAIL_LINE_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_LINE_OK:
                        CMP             #ASM_STATUS_BAD_OPER
                        BEQ             ASM_SMOKE_REPORT_FAIL_STATUS_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_STATUS_OK:

                        LDA             #$EF
                        STA             ASM_SLOT
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_SMOKE_REPORT_FAIL_STATE_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_STATE_OK:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINT_FAIL
                        BNE             ASM_SMOKE_REPORT_FAIL_FLAG_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_FLAG_OK:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BNE             ASM_SMOKE_REPORT_FAIL_PRINT_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_PRINT_OK:
                        LDA             ASM_LINE_COUNT_LO
                        CMP             #$01
                        BEQ             ASM_SMOKE_REPORT_FAIL_LINE_COUNT_LO_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_LINE_COUNT_LO_OK:
                        LDA             ASM_LINE_COUNT_HI
                        BEQ             ASM_SMOKE_REPORT_FAIL_LINE_COUNT_HI_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_LINE_COUNT_HI_OK:
                        LDA             ASM_SYM_COUNT
                        BEQ             ASM_SMOKE_REPORT_FAIL_SYMS_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_SYMS_OK:
                        LDA             ASM_PC_LO
                        CMP             #ASM_SMOKE_TARGET_LO
                        BEQ             ASM_SMOKE_REPORT_FAIL_PC_LO_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_PC_LO_OK:
                        LDA             ASM_PC_HI
                        CMP             #ASM_SMOKE_TARGET_HI
                        BEQ             ASM_SMOKE_REPORT_FAIL_PC_HI_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAIL_PC_HI_OK:

                        LDA             #$F0
                        STA             ASM_SLOT
                        JSR             ASM_END
                        BCC             ASM_SMOKE_REPORT_FAILED_END_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAILED_END_OK:
                        CMP             #ASM_STATUS_BAD_OPER
                        BEQ             ASM_SMOKE_REPORT_FAILED_END_STATUS_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_FAILED_END_STATUS_OK:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BNE             ASM_SMOKE_REPORT_CHECK_F1
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_F1:
                        LDA             #$F1
                        STA             ASM_SLOT
                        LDA             #ASM_REF_MAX
                        STA             ASM_TMP0_LO
ASM_SMOKE_REPORT_REF_FILL_LOOP:
                        JSR             ASM_REPORT_NOTE_REF
                        BCS             ASM_SMOKE_REPORT_REF_FILL_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_REF_FILL_OK:
                        DEC             ASM_TMP0_LO
                        BNE             ASM_SMOKE_REPORT_REF_FILL_LOOP

                        LDA             #$F2
                        STA             ASM_SLOT
                        JSR             ASM_REPORT_NOTE_REF
                        BCC             ASM_SMOKE_REPORT_REF_OVERFLOW_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_REF_OVERFLOW_OK:
                        CMP             #ASM_STATUS_BAD_FIX
                        BEQ             ASM_SMOKE_REPORT_REF_STATUS_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_REF_STATUS_OK:
                        LDA             ASM_REF_COUNT
                        CMP             #ASM_REF_MAX
                        BEQ             ASM_SMOKE_REPORT_REF_COUNT_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_REF_COUNT_OK:
                        JSR             ASM_REPORT_COMPACT
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_TRUNC
                        BNE             ASM_SMOKE_REPORT_CHECK_F2
                        JMP             ASM_SMOKE_REPORT_FAIL

ASM_SMOKE_REPORT_CHECK_F2:
                        LDA             #$F3
                        STA             ASM_SLOT
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASM_SMOKE_TARGET_LO
                        LDY             #ASM_SMOKE_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASM_SMOKE_REPORT_RESTORE_OK
                        JMP             ASM_SMOKE_REPORT_FAIL
ASM_SMOKE_REPORT_RESTORE_OK:
                        SEC
                        RTS
ASM_SMOKE_REPORT_FAIL:
                        CLC
                        RTS

                        ENDIF

                        IF              ASM_RUNTIME_ONLY
                        ELSE

ASM_REPORT_COMPACT:
                        LDX             #<ASM_REPORT_MSG_TITLE
                        LDY             #>ASM_REPORT_MSG_TITLE
                        JSR             ASM_SMOKE_PRINT_LINE
                        JSR             ASM_REPORT_PRINT_STATUS
                        JSR             ASM_REPORT_PRINT_ERRLINE
                        JSR             ASM_REPORT_PRINT_START
                        JSR             ASM_REPORT_PRINT_PC
                        JSR             ASM_REPORT_PRINT_HIGH
                        JSR             ASM_REPORT_PRINT_BYTES
                        JSR             ASM_REPORT_PRINT_LINES
                        JSR             ASM_REPORT_PRINT_SYMS
                        JSR             ASM_REPORT_PRINT_FIXUPS
                        JSR             ASM_REPORT_PRINT_REFS
                        JSR             ASM_REPORT_PRINT_TRUNC
                        JSR             ASM_REPORT_PRINT_USED
                        JMP             ASM_REPORT_PRINT_UNUSED

ASM_REPORT_PRINT_STATUS:
                        LDX             #<ASM_REPORT_MSG_STATUS
                        LDY             #>ASM_REPORT_MSG_STATUS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_STATUS
                        BEQ             ASM_REPORT_PRINT_STATUS_OK
                        LDA             #'$'
                        JSR             ASM_RJ_WRITE_BYTE
                        LDA             ASM_STATUS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF
ASM_REPORT_PRINT_STATUS_OK:
                        LDX             #<ASM_REPORT_MSG_OK
                        LDY             #>ASM_REPORT_MSG_OK
                        JMP             ASM_SMOKE_PRINT_LINE

ASM_REPORT_PRINT_ERRLINE:
                        LDX             #<ASM_REPORT_MSG_ERRLINE
                        LDY             #>ASM_REPORT_MSG_ERRLINE
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_STATUS
                        BEQ             ASM_REPORT_PRINT_ERRLINE_ZERO
                        LDA             ASM_LINE_COUNT_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_LINE_COUNT_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF
ASM_REPORT_PRINT_ERRLINE_ZERO:
                        LDA             #$00
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             #$00
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_START:
                        LDX             #<ASM_REPORT_MSG_START
                        LDY             #>ASM_REPORT_MSG_START
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_START_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_START_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_PC:
                        LDX             #<ASM_REPORT_MSG_PC
                        LDY             #>ASM_REPORT_MSG_PC
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_HIGH:
                        LDX             #<ASM_REPORT_MSG_HIGH
                        LDY             #>ASM_REPORT_MSG_HIGH
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_HIGH_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_HIGH_PC_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_BYTES:
                        LDX             #<ASM_REPORT_MSG_BYTES
                        LDY             #>ASM_REPORT_MSG_BYTES
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_TMP0_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_LINES:
                        LDX             #<ASM_REPORT_MSG_LINES
                        LDY             #>ASM_REPORT_MSG_LINES
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_LINE_COUNT_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_LINE_COUNT_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_SYMS:
                        LDX             #<ASM_REPORT_MSG_SYMS
                        LDY             #>ASM_REPORT_MSG_SYMS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SYM_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_REPORT_PRINT_LIMIT_SEP
                        LDA             #ASM_SYM_MAX
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_FIXUPS:
                        LDX             #<ASM_REPORT_MSG_FIXUPS
                        LDY             #>ASM_REPORT_MSG_FIXUPS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_FIX_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_REPORT_PRINT_LIMIT_SEP
                        LDA             #ASM_FIX_MAX
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_REFS:
                        LDX             #<ASM_REPORT_MSG_REFS
                        LDY             #>ASM_REPORT_MSG_REFS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_REF_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_REPORT_PRINT_LIMIT_SEP
                        LDA             #ASM_REF_MAX
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_TRUNC:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_TRUNC
                        BEQ             ASM_REPORT_PRINT_TRUNC_NO
                        LDX             #<ASM_REPORT_MSG_TRUNC_YES
                        LDY             #>ASM_REPORT_MSG_TRUNC_YES
                        JMP             ASM_SMOKE_PRINT_LINE
ASM_REPORT_PRINT_TRUNC_NO:
                        LDX             #<ASM_REPORT_MSG_TRUNC_NO
                        LDY             #>ASM_REPORT_MSG_TRUNC_NO
                        JMP             ASM_SMOKE_PRINT_LINE

ASM_REPORT_PRINT_USED:
                        JSR             ASM_REPORT_HAS_USED_SYMBOL
                        BCC             ASM_REPORT_PRINT_USED_DONE
                        LDX             #<ASM_REPORT_MSG_USED
                        LDY             #>ASM_REPORT_MSG_USED
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #$00
ASM_REPORT_PRINT_USED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASM_REPORT_PRINT_USED_DONE
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_USED
                        BEQ             ASM_REPORT_PRINT_USED_NEXT
                        JSR             ASM_REPORT_PRINT_USED_ROW
                        LDX             ASM_SLOT
ASM_REPORT_PRINT_USED_NEXT:
                        INX
                        BRA             ASM_REPORT_PRINT_USED_LOOP
ASM_REPORT_PRINT_USED_DONE:
                        RTS

ASM_REPORT_HAS_USED_SYMBOL:
                        LDX             #$00
ASM_REPORT_HAS_USED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASM_REPORT_HAS_USED_NO
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_USED
                        BNE             ASM_REPORT_HAS_USED_YES
                        INX
                        BRA             ASM_REPORT_HAS_USED_LOOP
ASM_REPORT_HAS_USED_NO:
                        CLC
                        RTS
ASM_REPORT_HAS_USED_YES:
                        SEC
                        RTS

ASM_REPORT_PRINT_USED_ROW:
                        STX             ASM_SLOT
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDX             ASM_SYM_PTR_LO
                        LDY             ASM_SYM_PTR_HI
                        JSR             ASM_RJ_WRITE_CSTRING
                        JSR             ASM_REPORT_PRINT_DEF_LINE
                        LDX             #<ASM_REPORT_MSG_USED_REFS
                        LDY             #>ASM_REPORT_MSG_USED_REFS
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_USECNT,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_REPORT_MSG_USED_FIRST
                        LDY             #>ASM_REPORT_MSG_USED_FIRST
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_FIRSTREF_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_FIRSTREF_LO,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_UNUSED:
                        JSR             ASM_REPORT_HAS_UNUSED_SYMBOL
                        BCC             ASM_REPORT_PRINT_UNUSED_DONE
                        LDX             #<ASM_REPORT_MSG_UNUSED
                        LDY             #>ASM_REPORT_MSG_UNUSED
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #$00
ASM_REPORT_PRINT_UNUSED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASM_REPORT_PRINT_UNUSED_DONE
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_USED
                        BNE             ASM_REPORT_PRINT_UNUSED_NEXT
                        JSR             ASM_REPORT_PRINT_UNUSED_ROW
                        LDX             ASM_SLOT
ASM_REPORT_PRINT_UNUSED_NEXT:
                        INX
                        BRA             ASM_REPORT_PRINT_UNUSED_LOOP
ASM_REPORT_PRINT_UNUSED_DONE:
                        RTS

ASM_REPORT_HAS_UNUSED_SYMBOL:
                        LDX             #$00
ASM_REPORT_HAS_UNUSED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASM_REPORT_HAS_UNUSED_NO
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_USED
                        BEQ             ASM_REPORT_HAS_UNUSED_YES
                        INX
                        BRA             ASM_REPORT_HAS_UNUSED_LOOP
ASM_REPORT_HAS_UNUSED_NO:
                        CLC
                        RTS
ASM_REPORT_HAS_UNUSED_YES:
                        SEC
                        RTS

ASM_REPORT_PRINT_UNUSED_ROW:
                        STX             ASM_SLOT
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDX             ASM_SYM_PTR_LO
                        LDY             ASM_SYM_PTR_HI
                        JSR             ASM_RJ_WRITE_CSTRING
                        JSR             ASM_REPORT_PRINT_DEF_LINE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_REPORT_PRINT_DEF_LINE:
                        LDX             #<ASM_REPORT_MSG_DEF
                        LDY             #>ASM_REPORT_MSG_DEF
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_DEFLINE_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_DEFLINE_LO,X
                        JMP             ASM_RJ_WRITE_HEX_BYTE

ASM_REPORT_PRINT_LIMIT_SEP:
                        LDA             #'/'
                        JSR             ASM_RJ_WRITE_BYTE
                        LDA             #'$'
                        JMP             ASM_RJ_WRITE_BYTE

                        ENDIF

; ----------------------------------------------------------------------------
; ROUTINE: ASM_PRINT_TABLES
; Print the current RAM session symbol and fixup rows.
; OUT: C=1,A=OK when printed. C=0,A=RJOIN when resident output is unavailable.
; ----------------------------------------------------------------------------
ASM_PRINT_TABLES:
                        LDA             #ASM_STEP_REPORT
                        STA             ASM_START_STEP
                        JSR             ASM_RJOIN_INIT
                        BCS             ASM_PRINT_TABLES_READY
                        LDA             #ASM_STATUS_RJOIN
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

ASM_PRINT_TABLES_READY:
                        LDX             #<ASM_TABLE_MSG_TITLE
                        LDY             #>ASM_TABLE_MSG_TITLE
                        JSR             ASM_SMOKE_PRINT_LINE
                        JSR             ASM_PRINT_SYMBOL_TABLE
                        JSR             ASM_PRINT_FIXUP_TABLE
                        JSR             ASM_PRINT_RELOC_TABLE
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

ASM_PRINT_SYMBOL_TABLE:
                        LDX             #<ASM_TABLE_MSG_SYMBOLS
                        LDY             #>ASM_TABLE_MSG_SYMBOLS
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #<ASM_TABLE_MSG_SYM_HEAD
                        LDY             #>ASM_TABLE_MSG_SYM_HEAD
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #$00
ASM_PRINT_SYMBOL_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASM_PRINT_SYMBOL_DONE
                        JSR             ASM_PRINT_SYMBOL_ROW
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_PRINT_SYMBOL_LOOP
ASM_PRINT_SYMBOL_DONE:
                        RTS

ASM_PRINT_SYMBOL_ROW:
                        STX             ASM_SLOT
                        TXA
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_STATE,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_VAL_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_VAL_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JSR             ASM_TABLE_PRINT_SPACE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_KIND,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_WIDTH,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_FLAGS,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_DEFLINE_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_DEFLINE_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_USECNT,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JSR             ASM_TABLE_PRINT_SPACE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_FIRSTREF_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_FIRSTREF_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JSR             ASM_TABLE_PRINT_SPACE
                        LDX             ASM_SLOT
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDX             ASM_SYM_PTR_LO
                        LDY             ASM_SYM_PTR_HI
                        JSR             ASM_RJ_WRITE_CSTRING
                        JMP             ASM_RJ_PRINT_CRLF

ASM_PRINT_FIXUP_TABLE:
                        LDX             #<ASM_TABLE_MSG_FIXUPS
                        LDY             #>ASM_TABLE_MSG_FIXUPS
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #<ASM_TABLE_MSG_FIX_HEAD
                        LDY             #>ASM_TABLE_MSG_FIX_HEAD
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #$00
ASM_PRINT_FIXUP_LOOP:
                        CPX             ASM_FIX_COUNT
                        BEQ             ASM_PRINT_FIXUP_DONE
                        JSR             ASM_PRINT_FIXUP_ROW
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_PRINT_FIXUP_LOOP
ASM_PRINT_FIXUP_DONE:
                        RTS

ASM_PRINT_RELOC_TABLE:
                        LDX             #<ASM_TABLE_MSG_RELOCS
                        LDY             #>ASM_TABLE_MSG_RELOCS
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #<ASM_TABLE_MSG_RELOC_HEAD
                        LDY             #>ASM_TABLE_MSG_RELOC_HEAD
                        JSR             ASM_SMOKE_PRINT_LINE
                        LDX             #$00
ASM_PRINT_RELOC_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BEQ             ASM_PRINT_RELOC_DONE
                        JSR             ASM_PRINT_RELOC_ROW
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_PRINT_RELOC_LOOP
ASM_PRINT_RELOC_DONE:
                        RTS

ASM_PRINT_RELOC_ROW:
                        STX             ASM_SLOT
                        TXA
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_RELOC_SITE_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_RELOC_SITE_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_RELOC_TARGET_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_RELOC_TARGET_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JMP             ASM_RJ_PRINT_CRLF

ASM_PRINT_FIXUP_ROW:
                        STX             ASM_SLOT
                        TXA
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_STATE,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_MODE,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JSR             ASM_TABLE_PRINT_SPACE
                        JSR             ASM_TABLE_PRINT_SPACE
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SEL,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        JSR             ASM_TABLE_PRINT_SPACE
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SITE_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_SITE_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_BASE_HI,X
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             ASM_SLOT
                        LDA             ASM_FIX_BASE_LO,X
                        JSR             ASM_TABLE_PRINT_BYTE_FIELD
                        LDX             ASM_SLOT
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDX             ASM_FIX_PTR_LO
                        LDY             ASM_FIX_PTR_HI
                        JSR             ASM_RJ_WRITE_CSTRING
                        JMP             ASM_RJ_PRINT_CRLF

ASM_TABLE_PRINT_BYTE_FIELD:
                        JSR             ASM_RJ_WRITE_HEX_BYTE
ASM_TABLE_PRINT_SPACE:
                        LDA             #' '
                        JMP             ASM_RJ_WRITE_BYTE

                        IF              ASM_RUNTIME_ONLY
                        ELSE

ASM_SMOKE_ASSEMBLE_LINE_ERR:
                        STA             ASM_SMOKE_EXPECT_STATUS
                        JSR             ASM_ASSEMBLE_LINE
                        BCS             ASM_SMOKE_ASSEMBLE_LINE_ERR_FAIL
                        CMP             ASM_SMOKE_EXPECT_STATUS
                        BNE             ASM_SMOKE_ASSEMBLE_LINE_ERR_FAIL
                        SEC
                        RTS
ASM_SMOKE_ASSEMBLE_LINE_ERR_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPERANDS_SETUP:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             ASM_SMOKE_OPERANDS_SETUP_FAIL

                        LDX             #<ASM_PARSE_AT_ORG
                        LDY             #>ASM_PARSE_AT_ORG
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPERANDS_SETUP_FAIL

                        LDX             #<ASM_PARSE_AT_OUT_EQU
                        LDY             #>ASM_PARSE_AT_OUT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPERANDS_SETUP_FAIL

                        LDX             #<ASM_PARSE_AT_COUNT_EQU
                        LDY             #>ASM_PARSE_AT_COUNT_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPERANDS_SETUP_FAIL

                        LDX             #<ASM_CLASS_SUM_EQU
                        LDY             #>ASM_CLASS_SUM_EQU
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASM_SMOKE_OPERANDS_SETUP_FAIL
                        SEC
                        RTS
ASM_SMOKE_OPERANDS_SETUP_FAIL:
                        CLC
                        RTS

ASM_SMOKE_CLASS_EXPECT:
                        STA             ASM_SMOKE_EXPECT_MODE
                        JSR             ASM_SMOKE_CLASS_PARSE_LINE
                        BCC             ASM_SMOKE_CLASS_FAIL
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_CLASS_OPERAND
                        BCC             ASM_SMOKE_CLASS_FAIL
                        LDA             ASM_MODE
                        CMP             ASM_SMOKE_EXPECT_MODE
                        BNE             ASM_SMOKE_CLASS_FAIL
                        SEC
                        RTS

ASM_SMOKE_CLASS_ERR:
                        STA             ASM_SMOKE_EXPECT_STATUS
                        JSR             ASM_SMOKE_CLASS_PARSE_LINE
                        BCC             ASM_SMOKE_CLASS_FAIL
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_CLASS_OPERAND
                        BCS             ASM_SMOKE_CLASS_FAIL
                        CMP             ASM_SMOKE_EXPECT_STATUS
                        BNE             ASM_SMOKE_CLASS_FAIL
                        SEC
                        RTS

ASM_SMOKE_CLASS_PARSE_LINE:
                        JSR             ASM_LEX_LINE
                        BCC             ASM_SMOKE_CLASS_FAIL
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_SMOKE_CLASS_FAIL
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_MNEM
                        BNE             ASM_SMOKE_CLASS_FAIL
                        SEC
                        RTS

ASM_SMOKE_CLASS_FAIL:
                        CLC
                        RTS

ASM_SMOKE_OPERANDS_FAIL:
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
                        STZ             ASM_SYM_DEFLINE_LO
                        STZ             ASM_SYM_DEFLINE_HI
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

                        ENDIF

; ----------------------------------------------------------------------------
; ROUTINE: ASM_BEGIN
; IN : A bit0 set means X/Y carries explicit start PC.
;      A bit0 clear means use this module's scratch code buffer.
; OUT: C=1,A=OK,X/Y=current PC when session opened.
;      C=0,A=status on failure.
; MEM: ZP $80-$AF active ASM frame; shared FNV ZP $B0-$B3/$C7-$CA;
;      RAM session state below.
; ----------------------------------------------------------------------------
ASM_BEGIN:
                        STA             ASM_FLAGS
                        STX             ASM_TMP0_LO
                        STY             ASM_TMP0_HI
                        JSR             ASM_RJOIN_INIT
                        BCS             ASM_BEGIN_RJOIN_OK
                        LDA             #ASM_STATUS_RJOIN
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

ASM_BEGIN_RJOIN_OK:
                        JSR             ASM_CLEAR_SESSION

                        LDA             ASM_FLAGS
                        AND             #ASM_BEGINF_HAVE_PC
                        BEQ             ASM_BEGIN_DEFAULT_PC

                        LDA             ASM_TMP0_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCC             ASM_BEGIN_EXPLICIT_PC_OK
                        LDA             #ASM_STATUS_BAD_RANGE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        CLC
                        RTS
ASM_BEGIN_EXPLICIT_PC_OK:
                        LDA             ASM_TMP0_LO
                        LDX             ASM_TMP0_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCS             ASM_BEGIN_EXPLICIT_PC_SAFE
                        LDA             #ASM_STATUS_BAD_RANGE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_TMP0_LO
                        LDY             ASM_TMP0_HI
                        CLC
                        RTS
ASM_BEGIN_EXPLICIT_PC_SAFE:
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
; ----------------------------------------------------------------------------
ASM_END:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_END_FAILED

                        JSR             ASM_FIX_HAS_PENDING_REQUIRED
                        BCC             ASM_END_OK

                        JSR             ASM_SEAL_CLEAR
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
                        JSR             ASM_SEAL_CAPTURE_END_FACTS
                        JSR             ASM_REPORT_PRINT_END_IF_NEEDED
                        LDA             #ASM_STATUS_OK
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

                        IF              ASM_RUNTIME_ONLY

ASM_REPORT_PRINT_END_IF_NEEDED:
ASM_REPORT_PRINT_FAIL_IF_NEEDED:
                        RTS

                        ELSE

ASM_REPORT_PRINT_END_IF_NEEDED:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINT_END
                        BEQ             ASM_REPORT_PRINT_END_DONE
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BNE             ASM_REPORT_PRINT_END_DONE
                        LDA             #ASM_STEP_REPORT
                        STA             ASM_START_STEP
                        JSR             ASM_RJOIN_INIT
                        LDA             #ASM_STEP_REPORT
                        STA             ASM_START_STEP
                        BCC             ASM_REPORT_PRINT_END_DONE
                        JSR             ASM_REPORT_COMPACT
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_PRINTED
                        STA             ASM_REPORT_FLAGS
ASM_REPORT_PRINT_END_DONE:
                        RTS

ASM_REPORT_PRINT_FAIL_IF_NEEDED:
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINT_FAIL
                        BEQ             ASM_REPORT_PRINT_FAIL_DONE
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_PRINTED
                        BNE             ASM_REPORT_PRINT_FAIL_DONE
                        LDA             #ASM_STEP_REPORT
                        STA             ASM_START_STEP
                        JSR             ASM_RJOIN_INIT
                        LDA             #ASM_STEP_REPORT
                        STA             ASM_START_STEP
                        BCC             ASM_REPORT_PRINT_FAIL_DONE
                        JSR             ASM_REPORT_COMPACT
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_PRINTED
                        STA             ASM_REPORT_FLAGS
ASM_REPORT_PRINT_FAIL_DONE:
                        RTS

                        ENDIF

ASM_REPORT_NOTE_REF:
                        LDA             ASM_REF_COUNT
                        CMP             #ASM_REF_MAX
                        BCC             ASM_REPORT_NOTE_REF_HAVE_ROOM
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_TRUNC
                        STA             ASM_REPORT_FLAGS
                        LDA             #ASM_SESS_FAILED
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_BAD_FIX
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        JSR             ASM_SEAL_CLEAR
                        LDA             ASM_STATUS
                        CLC
                        RTS
ASM_REPORT_NOTE_REF_HAVE_ROOM:
                        INC             ASM_REF_COUNT
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_ASSEMBLE_LINE
; IN : X/Y = NUL, CR, or LF-terminated source line.
; OUT: C=1,A=OK,X/Y=current PC if the line was accepted.
;      C=0,A=status,X/Y=current PC if the line was rejected.
; NOTE: Parser/session spine. Active-line failures roll PC/table cursors back.
; ----------------------------------------------------------------------------
ASM_ASSEMBLE_LINE:
                        JSR             ASM_INC_LINE_COUNT
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BEQ             ASM_ASSEMBLE_LINE_ACTIVE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_ASSEMBLE_LINE_STORED_FAIL
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_ASSEMBLE_LINE_FATAL_FAIL_A

ASM_ASSEMBLE_LINE_ACTIVE:
                        JSR             ASM_LINE_SAVE
                        JSR             ASM_LEX_LINE
                        BCC             ASM_ASSEMBLE_LINE_FAIL_A
                        JSR             ASM_PARSE_HEAD
                        BCC             ASM_ASSEMBLE_LINE_FAIL_A
                        JSR             ASM_DISPATCH_STATEMENT
                        BCC             ASM_ASSEMBLE_LINE_FAIL_A
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_DIR
                        BNE             ASM_ASSEMBLE_LINE_OK
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_END
                        BNE             ASM_ASSEMBLE_LINE_OK
                        JMP             ASM_END

ASM_ASSEMBLE_LINE_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

ASM_ASSEMBLE_LINE_STORED_FAIL:
                        LDA             ASM_LAST_STATUS
                        BNE             ASM_ASSEMBLE_LINE_RETURN_FAIL
                        LDA             #ASM_STATUS_BAD_OPER
ASM_ASSEMBLE_LINE_RETURN_FAIL:
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_ASSEMBLE_LINE_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_ASSEMBLE_LINE_FAILED_FATAL
                        JSR             ASM_LINE_ROLLBACK
                        LDA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_ASSEMBLE_LINE_FATAL_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDA             #ASM_SESS_FAILED
                        STA             ASM_SESSION_STATE
ASM_ASSEMBLE_LINE_FAILED_FATAL:
                        JSR             ASM_SEAL_CLEAR
                        JSR             ASM_REPORT_PRINT_FAIL_IF_NEEDED
                        LDA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_LINE_SAVE:
                        LDA             ASM_PC_LO
                        STA             ASM_LINE_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_LINE_PC_HI
                        LDA             ASM_HIGH_PC_LO
                        STA             ASM_LINE_HIGH_PC_LO
                        LDA             ASM_HIGH_PC_HI
                        STA             ASM_LINE_HIGH_PC_HI
                        LDA             ASM_SYM_COUNT
                        STA             ASM_LINE_SYM_COUNT
                        LDA             ASM_FIX_COUNT
                        STA             ASM_LINE_FIX_COUNT
                        LDA             ASM_LOCAL_COUNT
                        STA             ASM_LINE_LOCAL_COUNT
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        STA             ASM_LINE_LOCAL_SCOPE_ACTIVE
                        LDA             ASM_REF_COUNT
                        STA             ASM_LINE_REF_COUNT
                        LDA             ASM_FIX_RESOLVE_COUNT
                        STA             ASM_LINE_FIX_RESOLVE_COUNT
                        LDA             ASM_FIX_LAST_SITE_LO
                        STA             ASM_LINE_FIX_LAST_SITE_LO
                        LDA             ASM_FIX_LAST_SITE_HI
                        STA             ASM_LINE_FIX_LAST_SITE_HI
                        LDA             ASM_REPORT_FLAGS
                        STA             ASM_LINE_REPORT_FLAGS
                        LDA             ASM_SEAL_FLAGS
                        STA             ASM_LINE_SEAL_FLAGS
                        LDA             ASM_RELOC_COUNT
                        STA             ASM_LINE_RELOC_COUNT
                        LDA             ASM_EXPORT_COUNT
                        STA             ASM_LINE_EXPORT_COUNT
                        LDA             ASM_IMPORT_COUNT
                        STA             ASM_LINE_IMPORT_COUNT
                        PHX
                        PHY
                        JSR             ASM_LINE_SAVE_FIXUPS
                        PLY
                        PLX
                        RTS

ASM_LINE_SAVE_FIXUPS:
                        LDX             #$00
ASM_LINE_SAVE_FIXUPS_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_LINE_SAVE_FIXUPS_DONE
                        LDA             ASM_FIX_STATE,X
                        STA             ASM_LINE_FIX_STATE,X
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_FIX_PTR_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_FIX_PTR_HI
                        LDY             #$00
                        LDA             (ASM_FIX_PTR_LO),Y
                        STA             ASM_LINE_FIX_BYTE0,X
                        INY
                        LDA             (ASM_FIX_PTR_LO),Y
                        STA             ASM_LINE_FIX_BYTE1,X
                        INX
                        BRA             ASM_LINE_SAVE_FIXUPS_LOOP
ASM_LINE_SAVE_FIXUPS_DONE:
                        RTS

ASM_LINE_ROLLBACK:
                        JSR             ASM_LINE_RESTORE_FIXUPS
                        LDA             ASM_LINE_PC_LO
                        STA             ASM_PC_LO
                        LDA             ASM_LINE_PC_HI
                        STA             ASM_PC_HI
                        LDA             ASM_LINE_HIGH_PC_LO
                        STA             ASM_HIGH_PC_LO
                        LDA             ASM_LINE_HIGH_PC_HI
                        STA             ASM_HIGH_PC_HI
                        LDA             ASM_LINE_SYM_COUNT
                        STA             ASM_SYM_COUNT
                        LDA             ASM_LINE_FIX_COUNT
                        STA             ASM_FIX_COUNT
                        LDA             ASM_LINE_LOCAL_COUNT
                        STA             ASM_LOCAL_COUNT
                        LDA             ASM_LINE_LOCAL_SCOPE_ACTIVE
                        STA             ASM_LOCAL_SCOPE_ACTIVE
                        LDA             ASM_LINE_REF_COUNT
                        STA             ASM_REF_COUNT
                        LDA             ASM_LINE_FIX_RESOLVE_COUNT
                        STA             ASM_FIX_RESOLVE_COUNT
                        LDA             ASM_LINE_FIX_LAST_SITE_LO
                        STA             ASM_FIX_LAST_SITE_LO
                        LDA             ASM_LINE_FIX_LAST_SITE_HI
                        STA             ASM_FIX_LAST_SITE_HI
                        LDA             ASM_LINE_REPORT_FLAGS
                        STA             ASM_REPORT_FLAGS
                        LDA             ASM_LINE_SEAL_FLAGS
                        STA             ASM_SEAL_FLAGS
                        LDA             ASM_LINE_RELOC_COUNT
                        STA             ASM_RELOC_COUNT
                        LDA             ASM_LINE_EXPORT_COUNT
                        STA             ASM_EXPORT_COUNT
                        LDA             ASM_LINE_IMPORT_COUNT
                        STA             ASM_IMPORT_COUNT
                        LDA             #ASM_SESS_ACTIVE
                        STA             ASM_SESSION_STATE
                        RTS

ASM_LINE_RESTORE_FIXUPS:
                        LDX             #$00
ASM_LINE_RESTORE_FIXUPS_LOOP:
                        CPX             ASM_LINE_FIX_COUNT
                        BCS             ASM_LINE_RESTORE_FIXUPS_DONE
                        LDA             ASM_LINE_FIX_STATE,X
                        STA             ASM_FIX_STATE,X
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_FIX_PTR_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_FIX_PTR_HI
                        LDY             #$00
                        LDA             ASM_LINE_FIX_BYTE0,X
                        STA             (ASM_FIX_PTR_LO),Y
                        INY
                        LDA             ASM_LINE_FIX_BYTE1,X
                        STA             (ASM_FIX_PTR_LO),Y
                        INX
                        BRA             ASM_LINE_RESTORE_FIXUPS_LOOP
ASM_LINE_RESTORE_FIXUPS_DONE:
                        RTS

ASM_INC_LINE_COUNT:
                        INC             ASM_LINE_COUNT_LO
                        BNE             ASM_INC_LINE_COUNT_DONE
                        INC             ASM_LINE_COUNT_HI
ASM_INC_LINE_COUNT_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT_BYTE
; IN : A = byte to write at current ASM PC.
; OUT: C=1,A=OK,X/Y=advanced PC. C=0,A=status,X/Y=current PC on failure.
; DOES: Writes to target RAM, advances PC, and updates the high-water PC.
; ----------------------------------------------------------------------------
ASM_EMIT_BYTE:
                        STA             ASM_TMP0_LO
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BEQ             ASM_EMIT_BYTE_ACTIVE
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_FAIL_A
ASM_EMIT_BYTE_ACTIVE:
                        LDA             #$01
                        JSR             ASM_EMIT_ROOM_FOR_A
                        BCS             ASM_EMIT_BYTE_ROOM
                        JMP             ASM_EMIT_FAIL_A
ASM_EMIT_BYTE_ROOM:
                        LDA             ASM_PC_LO
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_PC_HI
                        STA             ASM_EMIT_PTR_HI
                        LDY             #$00
                        LDA             ASM_TMP0_LO
                        STA             (ASM_EMIT_PTR_LO),Y
                        JSR             ASM_ADVANCE_PC_ONE
                        JSR             ASM_UPDATE_HIGH_PC
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT_WORD_LE
; IN : A = low byte, X = high byte.
; OUT: C=1,A=OK,X/Y=advanced PC. C=0,A=status,X/Y=current PC on failure.
; ----------------------------------------------------------------------------
ASM_EMIT_WORD_LE:
                        STA             ASM_TMP0_LO
                        STX             ASM_TMP0_HI
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_ACTIVE
                        BEQ             ASM_EMIT_WORD_ACTIVE
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_EMIT_FAIL_A
ASM_EMIT_WORD_ACTIVE:
                        LDA             #$02
                        JSR             ASM_EMIT_ROOM_FOR_A
                        BCS             ASM_EMIT_WORD_ROOM
                        BRA             ASM_EMIT_FAIL_A
ASM_EMIT_WORD_ROOM:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_WORD_LOW_OK
                        RTS
ASM_EMIT_WORD_LOW_OK:
                        LDA             ASM_TMP0_HI
                        JMP             ASM_EMIT_BYTE

ASM_ADVANCE_PC_ONE:
                        INC             ASM_PC_LO
                        BNE             ASM_ADVANCE_PC_ONE_DONE
                        INC             ASM_PC_HI
ASM_ADVANCE_PC_ONE_DONE:
                        RTS

ASM_UPDATE_HIGH_PC:
                        LDA             ASM_PC_HI
                        CMP             ASM_HIGH_PC_HI
                        BCC             ASM_UPDATE_HIGH_DONE
                        BNE             ASM_UPDATE_HIGH_SET
                        LDA             ASM_PC_LO
                        CMP             ASM_HIGH_PC_LO
                        BCC             ASM_UPDATE_HIGH_DONE
                        BEQ             ASM_UPDATE_HIGH_DONE
ASM_UPDATE_HIGH_SET:
                        LDA             ASM_PC_LO
                        STA             ASM_HIGH_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_HIGH_PC_HI
ASM_UPDATE_HIGH_DONE:
                        RTS

ASM_EMIT_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_FIND_OPCODE
; IN : ASM_STMT_OP_ID = mnemonic id, ASM_MODE = classified operand mode.
; OUT: C=1,A=opcode. C=0,A=BAD_MODE when this mnemonic/mode is unsupported.
; NOTE: ASM 2.10 keeps the first table explicit for auditability.
; ----------------------------------------------------------------------------
ASM_FIND_OPCODE:
                        JSR             ASM_FIND_OPCODE_NONE_TABLE
                        BCC             ASM_FIND_OPCODE_NOT_NONE_TABLE
                        RTS
ASM_FIND_OPCODE_NOT_NONE_TABLE:
                        CMP             #ASM_STATUS_BAD_MNEM
                        BEQ             ASM_FIND_OPCODE_CHECK_MODE_TABLE
                        JMP             ASM_FIND_OPCODE_FAIL_A
ASM_FIND_OPCODE_CHECK_MODE_TABLE:
                        JSR             ASM_FIND_OPCODE_MODE_TABLE
                        BCC             ASM_FIND_OPCODE_NOT_MODE_TABLE
                        RTS
ASM_FIND_OPCODE_NOT_MODE_TABLE:
                        CMP             #ASM_STATUS_BAD_MNEM
                        BEQ             ASM_FIND_OPCODE_DISPATCH_OP
                        JMP             ASM_FIND_OPCODE_FAIL_A
ASM_FIND_OPCODE_DISPATCH_OP:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_ASL
                        BNE             ASM_FIND_OPCODE_NOT_ASL
                        JMP             ASM_FIND_OPCODE_ASL
ASM_FIND_OPCODE_NOT_ASL:
                        CMP             #ASM_VID_LSR
                        BNE             ASM_FIND_OPCODE_NOT_LSR
                        JMP             ASM_FIND_OPCODE_LSR
ASM_FIND_OPCODE_NOT_LSR:
                        CMP             #ASM_VID_ROL
                        BNE             ASM_FIND_OPCODE_NOT_ROL
                        JMP             ASM_FIND_OPCODE_ROL
ASM_FIND_OPCODE_NOT_ROL:
                        CMP             #ASM_VID_ROR
                        BNE             ASM_FIND_OPCODE_NOT_ROR
                        JMP             ASM_FIND_OPCODE_ROR
ASM_FIND_OPCODE_NOT_ROR:
                        CMP             #ASM_VID_BBR
                        BNE             ASM_FIND_OPCODE_NOT_BBR
                        JMP             ASM_FIND_OPCODE_BBR
ASM_FIND_OPCODE_NOT_BBR:
                        CMP             #ASM_VID_BBS
                        BNE             ASM_FIND_OPCODE_NOT_BBS
                        JMP             ASM_FIND_OPCODE_BBS
ASM_FIND_OPCODE_NOT_BBS:
                        CMP             #ASM_VID_BNE
                        BNE             ASM_FIND_OPCODE_NOT_BNE
                        JMP             ASM_FIND_OPCODE_BNE
ASM_FIND_OPCODE_NOT_BNE:
                        CMP             #ASM_VID_BCC
                        BNE             ASM_FIND_OPCODE_NOT_BCC
                        JMP             ASM_FIND_OPCODE_BCC
ASM_FIND_OPCODE_NOT_BCC:
                        CMP             #ASM_VID_BCS
                        BNE             ASM_FIND_OPCODE_NOT_BCS
                        JMP             ASM_FIND_OPCODE_BCS
ASM_FIND_OPCODE_NOT_BCS:
                        CMP             #ASM_VID_BEQ
                        BNE             ASM_FIND_OPCODE_NOT_BEQ
                        JMP             ASM_FIND_OPCODE_BEQ
ASM_FIND_OPCODE_NOT_BEQ:
                        CMP             #ASM_VID_BMI
                        BNE             ASM_FIND_OPCODE_NOT_BMI
                        JMP             ASM_FIND_OPCODE_BMI
ASM_FIND_OPCODE_NOT_BMI:
                        CMP             #ASM_VID_BPL
                        BNE             ASM_FIND_OPCODE_NOT_BPL
                        JMP             ASM_FIND_OPCODE_BPL
ASM_FIND_OPCODE_NOT_BPL:
                        CMP             #ASM_VID_BRA
                        BNE             ASM_FIND_OPCODE_NOT_BRA
                        JMP             ASM_FIND_OPCODE_BRA
ASM_FIND_OPCODE_NOT_BRA:
                        CMP             #ASM_VID_BVC
                        BNE             ASM_FIND_OPCODE_NOT_BVC
                        JMP             ASM_FIND_OPCODE_BVC
ASM_FIND_OPCODE_NOT_BVC:
                        CMP             #ASM_VID_BVS
                        BNE             ASM_FIND_OPCODE_NOT_BVS
                        JMP             ASM_FIND_OPCODE_BVS
ASM_FIND_OPCODE_NOT_BVS:
                        CMP             #ASM_VID_RMB
                        BNE             ASM_FIND_OPCODE_NOT_RMB
                        JMP             ASM_FIND_OPCODE_RMB
ASM_FIND_OPCODE_NOT_RMB:
                        CMP             #ASM_VID_SMB
                        BNE             ASM_FIND_OPCODE_NOT_SMB
                        JMP             ASM_FIND_OPCODE_SMB
ASM_FIND_OPCODE_NOT_SMB:
                        LDA             #ASM_STATUS_BAD_MODE
                        JMP             ASM_FIND_OPCODE_FAIL_A

ASM_FIND_OPCODE_NONE_TABLE:
                        LDX             #$00
ASM_FIND_OPCODE_NONE_TABLE_LOOP:
                        LDA             ASM_FIND_OPCODE_NONE_ROWS,X
                        CMP             #$FF
                        BEQ             ASM_FIND_OPCODE_NONE_TABLE_MISS
                        CMP             ASM_STMT_OP_ID
                        BEQ             ASM_FIND_OPCODE_NONE_TABLE_HIT
                        INX
                        INX
                        BRA             ASM_FIND_OPCODE_NONE_TABLE_LOOP
ASM_FIND_OPCODE_NONE_TABLE_HIT:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_NONE
                        BEQ             ASM_FIND_OPCODE_NONE_TABLE_OK
                        LDA             #ASM_STATUS_BAD_MODE
                        CLC
                        RTS
ASM_FIND_OPCODE_NONE_TABLE_OK:
                        INX
                        LDA             ASM_FIND_OPCODE_NONE_ROWS,X
                        STA             ASM_TMP0_LO
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDA             ASM_TMP0_LO
                        SEC
                        RTS
ASM_FIND_OPCODE_NONE_TABLE_MISS:
                        LDA             #ASM_STATUS_BAD_MNEM
                        CLC
                        RTS

ASM_FIND_OPCODE_NONE_ROWS:
ASM_FIND_OPCODE_INX:
                        DB              ASM_VID_INX,$E8
ASM_FIND_OPCODE_RTS:
                        DB              ASM_VID_RTS,$60
ASM_FIND_OPCODE_CLC:
                        DB              ASM_VID_CLC,$18
ASM_FIND_OPCODE_CLD:
                        DB              ASM_VID_CLD,$D8
ASM_FIND_OPCODE_CLI:
                        DB              ASM_VID_CLI,$58
ASM_FIND_OPCODE_CLV:
                        DB              ASM_VID_CLV,$B8
ASM_FIND_OPCODE_SEC:
                        DB              ASM_VID_SEC,$38
ASM_FIND_OPCODE_SED:
                        DB              ASM_VID_SED,$F8
ASM_FIND_OPCODE_SEI:
                        DB              ASM_VID_SEI,$78
ASM_FIND_OPCODE_NOP:
                        DB              ASM_VID_NOP,$EA
ASM_FIND_OPCODE_DEX:
                        DB              ASM_VID_DEX,$CA
ASM_FIND_OPCODE_DEY:
                        DB              ASM_VID_DEY,$88
ASM_FIND_OPCODE_INY:
                        DB              ASM_VID_INY,$C8
ASM_FIND_OPCODE_TAX:
                        DB              ASM_VID_TAX,$AA
ASM_FIND_OPCODE_TAY:
                        DB              ASM_VID_TAY,$A8
ASM_FIND_OPCODE_TSX:
                        DB              ASM_VID_TSX,$BA
ASM_FIND_OPCODE_TXA:
                        DB              ASM_VID_TXA,$8A
ASM_FIND_OPCODE_TXS:
                        DB              ASM_VID_TXS,$9A
ASM_FIND_OPCODE_TYA:
                        DB              ASM_VID_TYA,$98
ASM_FIND_OPCODE_PHA:
                        DB              ASM_VID_PHA,$48
ASM_FIND_OPCODE_PHP:
                        DB              ASM_VID_PHP,$08
ASM_FIND_OPCODE_PHX:
                        DB              ASM_VID_PHX,$DA
ASM_FIND_OPCODE_PHY:
                        DB              ASM_VID_PHY,$5A
ASM_FIND_OPCODE_PLA:
                        DB              ASM_VID_PLA,$68
ASM_FIND_OPCODE_PLP:
                        DB              ASM_VID_PLP,$28
ASM_FIND_OPCODE_PLX:
                        DB              ASM_VID_PLX,$FA
ASM_FIND_OPCODE_PLY:
                        DB              ASM_VID_PLY,$7A
ASM_FIND_OPCODE_RTI:
                        DB              ASM_VID_RTI,$40
ASM_FIND_OPCODE_WAI:
                        DB              ASM_VID_WAI,$CB
ASM_FIND_OPCODE_STP:
                        DB              ASM_VID_STP,$DB
                        DB              $FF,$00

ASM_FIND_OPCODE_MODE_TABLE:
                        JSR             ASM_FIND_OPCODE_MODE_TABLE_A
                        BCC             ASM_FIND_OPCODE_MODE_TABLE_A_MISS
                        RTS
ASM_FIND_OPCODE_MODE_TABLE_A_MISS:
                        CMP             #ASM_STATUS_BAD_MNEM
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_B
                        CLC
                        RTS

; Keep all rows for a mnemonic in one shard; BAD_MODE does not fall through.
ASM_FIND_OPCODE_MODE_TABLE_A:
                        STZ             ASM_TMP0_HI
                        LDX             #$00
ASM_FIND_OPCODE_MODE_TABLE_LOOP:
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_A,X
                        CMP             #$FF
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_DONE
                        CMP             ASM_STMT_OP_ID
                        BNE             ASM_FIND_OPCODE_MODE_TABLE_NEXT
                        LDA             #$01
                        STA             ASM_TMP0_HI
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_A+1,X
                        CMP             ASM_MODE
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_HIT
ASM_FIND_OPCODE_MODE_TABLE_NEXT:
                        TXA
                        CLC
                        ADC             #$03
                        TAX
                        BRA             ASM_FIND_OPCODE_MODE_TABLE_LOOP
ASM_FIND_OPCODE_MODE_TABLE_HIT:
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_A+2,X
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_MODE_TABLE_DONE:
                        LDA             ASM_TMP0_HI
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_MISS
                        LDA             #ASM_STATUS_BAD_MODE
                        CLC
                        RTS
ASM_FIND_OPCODE_MODE_TABLE_MISS:
                        LDA             #ASM_STATUS_BAD_MNEM
                        CLC
                        RTS

ASM_FIND_OPCODE_MODE_TABLE_B:
                        STZ             ASM_TMP0_HI
                        LDX             #$00
ASM_FIND_OPCODE_MODE_TABLE_B_LOOP:
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_B,X
                        CMP             #$FF
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_B_DONE
                        CMP             ASM_STMT_OP_ID
                        BNE             ASM_FIND_OPCODE_MODE_TABLE_B_NEXT
                        LDA             #$01
                        STA             ASM_TMP0_HI
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_B+1,X
                        CMP             ASM_MODE
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_B_HIT
ASM_FIND_OPCODE_MODE_TABLE_B_NEXT:
                        TXA
                        CLC
                        ADC             #$03
                        TAX
                        BRA             ASM_FIND_OPCODE_MODE_TABLE_B_LOOP
ASM_FIND_OPCODE_MODE_TABLE_B_HIT:
                        LDA             ASM_FIND_OPCODE_MODE_ROWS_B+2,X
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_MODE_TABLE_B_DONE:
                        LDA             ASM_TMP0_HI
                        BEQ             ASM_FIND_OPCODE_MODE_TABLE_B_MISS
                        LDA             #ASM_STATUS_BAD_MODE
                        CLC
                        RTS
ASM_FIND_OPCODE_MODE_TABLE_B_MISS:
                        LDA             #ASM_STATUS_BAD_MNEM
                        CLC
                        RTS

ASM_FIND_OPCODE_MODE_ROWS_A:
ASM_FIND_OPCODE_LDX:
                        DB              ASM_VID_LDX,ASM_OPM_IMM8,$A2
                        DB              ASM_VID_LDX,ASM_OPM_ZP8,$A6
                        DB              ASM_VID_LDX,ASM_OPM_ABS16,$AE
                        DB              ASM_VID_LDX,ASM_OPM_ZP_Y,$B6
                        DB              ASM_VID_LDX,ASM_OPM_ABS_Y,$BE
ASM_FIND_OPCODE_LDY:
                        DB              ASM_VID_LDY,ASM_OPM_IMM8,$A0
                        DB              ASM_VID_LDY,ASM_OPM_ZP8,$A4
                        DB              ASM_VID_LDY,ASM_OPM_ABS16,$AC
                        DB              ASM_VID_LDY,ASM_OPM_ZP_X,$B4
                        DB              ASM_VID_LDY,ASM_OPM_ABS_X,$BC
ASM_FIND_OPCODE_CPX:
                        DB              ASM_VID_CPX,ASM_OPM_IMM8,$E0
                        DB              ASM_VID_CPX,ASM_OPM_ZP8,$E4
                        DB              ASM_VID_CPX,ASM_OPM_ABS16,$EC
ASM_FIND_OPCODE_CPY:
                        DB              ASM_VID_CPY,ASM_OPM_IMM8,$C0
                        DB              ASM_VID_CPY,ASM_OPM_ZP8,$C4
                        DB              ASM_VID_CPY,ASM_OPM_ABS16,$CC
ASM_FIND_OPCODE_INC:
                        DB              ASM_VID_INC,ASM_OPM_ACC,$1A
                        DB              ASM_VID_INC,ASM_OPM_ZP8,$E6
                        DB              ASM_VID_INC,ASM_OPM_ABS16,$EE
                        DB              ASM_VID_INC,ASM_OPM_ZP_X,$F6
                        DB              ASM_VID_INC,ASM_OPM_ABS_X,$FE
ASM_FIND_OPCODE_DEC:
                        DB              ASM_VID_DEC,ASM_OPM_ACC,$3A
                        DB              ASM_VID_DEC,ASM_OPM_ZP8,$C6
                        DB              ASM_VID_DEC,ASM_OPM_ABS16,$CE
                        DB              ASM_VID_DEC,ASM_OPM_ZP_X,$D6
                        DB              ASM_VID_DEC,ASM_OPM_ABS_X,$DE
ASM_FIND_OPCODE_STZ:
                        DB              ASM_VID_STZ,ASM_OPM_ZP8,$64
                        DB              ASM_VID_STZ,ASM_OPM_ABS16,$9C
                        DB              ASM_VID_STZ,ASM_OPM_ZP_X,$74
                        DB              ASM_VID_STZ,ASM_OPM_ABS_X,$9E
ASM_FIND_OPCODE_STX:
                        DB              ASM_VID_STX,ASM_OPM_ZP8,$86
                        DB              ASM_VID_STX,ASM_OPM_ABS16,$8E
                        DB              ASM_VID_STX,ASM_OPM_ZP_Y,$96
ASM_FIND_OPCODE_STY:
                        DB              ASM_VID_STY,ASM_OPM_ZP8,$84
                        DB              ASM_VID_STY,ASM_OPM_ABS16,$8C
                        DB              ASM_VID_STY,ASM_OPM_ZP_X,$94
ASM_FIND_OPCODE_BIT:
                        DB              ASM_VID_BIT,ASM_OPM_IMM8,$89
                        DB              ASM_VID_BIT,ASM_OPM_ZP8,$24
                        DB              ASM_VID_BIT,ASM_OPM_ABS16,$2C
                        DB              ASM_VID_BIT,ASM_OPM_ZP_X,$34
                        DB              ASM_VID_BIT,ASM_OPM_ABS_X,$3C
ASM_FIND_OPCODE_TRB:
                        DB              ASM_VID_TRB,ASM_OPM_ZP8,$14
                        DB              ASM_VID_TRB,ASM_OPM_ABS16,$1C
ASM_FIND_OPCODE_TSB:
                        DB              ASM_VID_TSB,ASM_OPM_ZP8,$04
                        DB              ASM_VID_TSB,ASM_OPM_ABS16,$0C
ASM_FIND_OPCODE_JSR:
                        DB              ASM_VID_JSR,ASM_OPM_ABS16,$20
                        DB              $FF,$00,$00
ASM_FIND_OPCODE_MODE_ROWS_B:
ASM_FIND_OPCODE_ADC:
                        DB              ASM_VID_ADC,ASM_OPM_IMM8,$69
                        DB              ASM_VID_ADC,ASM_OPM_ZP_X_IND,$61
                        DB              ASM_VID_ADC,ASM_OPM_ZP8,$65
                        DB              ASM_VID_ADC,ASM_OPM_ABS16,$6D
                        DB              ASM_VID_ADC,ASM_OPM_ZP_IND,$72
                        DB              ASM_VID_ADC,ASM_OPM_ZP_X,$75
                        DB              ASM_VID_ADC,ASM_OPM_ZP_IND_Y,$71
                        DB              ASM_VID_ADC,ASM_OPM_ABS_Y,$79
                        DB              ASM_VID_ADC,ASM_OPM_ABS_X,$7D
ASM_FIND_OPCODE_SBC:
                        DB              ASM_VID_SBC,ASM_OPM_IMM8,$E9
                        DB              ASM_VID_SBC,ASM_OPM_ZP_X_IND,$E1
                        DB              ASM_VID_SBC,ASM_OPM_ZP8,$E5
                        DB              ASM_VID_SBC,ASM_OPM_ABS16,$ED
                        DB              ASM_VID_SBC,ASM_OPM_ZP_IND,$F2
                        DB              ASM_VID_SBC,ASM_OPM_ZP_X,$F5
                        DB              ASM_VID_SBC,ASM_OPM_ZP_IND_Y,$F1
                        DB              ASM_VID_SBC,ASM_OPM_ABS_Y,$F9
                        DB              ASM_VID_SBC,ASM_OPM_ABS_X,$FD
ASM_FIND_OPCODE_AND:
                        DB              ASM_VID_AND,ASM_OPM_IMM8,$29
                        DB              ASM_VID_AND,ASM_OPM_ZP_X_IND,$21
                        DB              ASM_VID_AND,ASM_OPM_ZP8,$25
                        DB              ASM_VID_AND,ASM_OPM_ABS16,$2D
                        DB              ASM_VID_AND,ASM_OPM_ZP_IND,$32
                        DB              ASM_VID_AND,ASM_OPM_ZP_X,$35
                        DB              ASM_VID_AND,ASM_OPM_ZP_IND_Y,$31
                        DB              ASM_VID_AND,ASM_OPM_ABS_Y,$39
                        DB              ASM_VID_AND,ASM_OPM_ABS_X,$3D
ASM_FIND_OPCODE_ORA:
                        DB              ASM_VID_ORA,ASM_OPM_IMM8,$09
                        DB              ASM_VID_ORA,ASM_OPM_ZP_X_IND,$01
                        DB              ASM_VID_ORA,ASM_OPM_ZP8,$05
                        DB              ASM_VID_ORA,ASM_OPM_ABS16,$0D
                        DB              ASM_VID_ORA,ASM_OPM_ZP_IND,$12
                        DB              ASM_VID_ORA,ASM_OPM_ZP_X,$15
                        DB              ASM_VID_ORA,ASM_OPM_ZP_IND_Y,$11
                        DB              ASM_VID_ORA,ASM_OPM_ABS_Y,$19
                        DB              ASM_VID_ORA,ASM_OPM_ABS_X,$1D
ASM_FIND_OPCODE_EOR:
                        DB              ASM_VID_EOR,ASM_OPM_IMM8,$49
                        DB              ASM_VID_EOR,ASM_OPM_ZP_X_IND,$41
                        DB              ASM_VID_EOR,ASM_OPM_ZP8,$45
                        DB              ASM_VID_EOR,ASM_OPM_ABS16,$4D
                        DB              ASM_VID_EOR,ASM_OPM_ZP_IND,$52
                        DB              ASM_VID_EOR,ASM_OPM_ZP_X,$55
                        DB              ASM_VID_EOR,ASM_OPM_ZP_IND_Y,$51
                        DB              ASM_VID_EOR,ASM_OPM_ABS_Y,$59
                        DB              ASM_VID_EOR,ASM_OPM_ABS_X,$5D
ASM_FIND_OPCODE_CMP:
                        DB              ASM_VID_CMP,ASM_OPM_IMM8,$C9
                        DB              ASM_VID_CMP,ASM_OPM_ZP_X_IND,$C1
                        DB              ASM_VID_CMP,ASM_OPM_ZP8,$C5
                        DB              ASM_VID_CMP,ASM_OPM_ABS16,$CD
                        DB              ASM_VID_CMP,ASM_OPM_ZP_IND,$D2
                        DB              ASM_VID_CMP,ASM_OPM_ZP_X,$D5
                        DB              ASM_VID_CMP,ASM_OPM_ZP_IND_Y,$D1
                        DB              ASM_VID_CMP,ASM_OPM_ABS_Y,$D9
                        DB              ASM_VID_CMP,ASM_OPM_ABS_X,$DD
ASM_FIND_OPCODE_LDA:
                        DB              ASM_VID_LDA,ASM_OPM_IMM8,$A9
                        DB              ASM_VID_LDA,ASM_OPM_ZP_X_IND,$A1
                        DB              ASM_VID_LDA,ASM_OPM_ZP8,$A5
                        DB              ASM_VID_LDA,ASM_OPM_ABS16,$AD
                        DB              ASM_VID_LDA,ASM_OPM_ZP_IND,$B2
                        DB              ASM_VID_LDA,ASM_OPM_ZP_X,$B5
                        DB              ASM_VID_LDA,ASM_OPM_ZP_IND_Y,$B1
                        DB              ASM_VID_LDA,ASM_OPM_ABS_Y,$B9
                        DB              ASM_VID_LDA,ASM_OPM_ABS_X,$BD
ASM_FIND_OPCODE_STA:
                        DB              ASM_VID_STA,ASM_OPM_ZP_X_IND,$81
                        DB              ASM_VID_STA,ASM_OPM_ZP8,$85
                        DB              ASM_VID_STA,ASM_OPM_ABS16,$8D
                        DB              ASM_VID_STA,ASM_OPM_ZP_IND,$92
                        DB              ASM_VID_STA,ASM_OPM_ZP_X,$95
                        DB              ASM_VID_STA,ASM_OPM_ZP_IND_Y,$91
                        DB              ASM_VID_STA,ASM_OPM_ABS_Y,$99
                        DB              ASM_VID_STA,ASM_OPM_ABS_X,$9D
ASM_FIND_OPCODE_JMP:
                        DB              ASM_VID_JMP,ASM_OPM_ABS16,$4C
                        DB              ASM_VID_JMP,ASM_OPM_ABS_IND,$6C
                        DB              ASM_VID_JMP,ASM_OPM_ABS_X_IND,$7C
ASM_FIND_OPCODE_BRK:
                        DB              ASM_VID_BRK,ASM_OPM_IMM8,$00
                        DB              ASM_VID_BRK,ASM_OPM_ZP8,$00
                        DB              $FF,$00,$00

ASM_FIND_OPCODE_ASL:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_NONE
                        BEQ             ASM_FIND_OPCODE_ASL_ACC
                        CMP             #ASM_OPM_ACC
                        BEQ             ASM_FIND_OPCODE_ASL_ACC
                        CMP             #ASM_OPM_ZP8
                        BEQ             ASM_FIND_OPCODE_ASL_ZP
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_FIND_OPCODE_ASL_ABS
                        CMP             #ASM_OPM_ZP_X
                        BEQ             ASM_FIND_OPCODE_ASL_ZPX
                        CMP             #ASM_OPM_ABS_X
                        BEQ             ASM_FIND_OPCODE_ASL_ABSX
                        JMP             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_ASL_ACC:
                        LDA             #$0A
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ASL_ZP:
                        LDA             #$06
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ASL_ABS:
                        LDA             #$0E
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ASL_ZPX:
                        LDA             #$16
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ASL_ABSX:
                        LDA             #$1E
                        JMP             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_LSR:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_NONE
                        BEQ             ASM_FIND_OPCODE_LSR_ACC
                        CMP             #ASM_OPM_ACC
                        BEQ             ASM_FIND_OPCODE_LSR_ACC
                        CMP             #ASM_OPM_ZP8
                        BEQ             ASM_FIND_OPCODE_LSR_ZP
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_FIND_OPCODE_LSR_ABS
                        CMP             #ASM_OPM_ZP_X
                        BEQ             ASM_FIND_OPCODE_LSR_ZPX
                        CMP             #ASM_OPM_ABS_X
                        BEQ             ASM_FIND_OPCODE_LSR_ABSX
                        JMP             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_LSR_ACC:
                        LDA             #$4A
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_LSR_ZP:
                        LDA             #$46
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_LSR_ABS:
                        LDA             #$4E
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_LSR_ZPX:
                        LDA             #$56
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_LSR_ABSX:
                        LDA             #$5E
                        JMP             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_ROL:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_NONE
                        BEQ             ASM_FIND_OPCODE_ROL_ACC
                        CMP             #ASM_OPM_ACC
                        BEQ             ASM_FIND_OPCODE_ROL_ACC
                        CMP             #ASM_OPM_ZP8
                        BEQ             ASM_FIND_OPCODE_ROL_ZP
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_FIND_OPCODE_ROL_ABS
                        CMP             #ASM_OPM_ZP_X
                        BEQ             ASM_FIND_OPCODE_ROL_ZPX
                        CMP             #ASM_OPM_ABS_X
                        BEQ             ASM_FIND_OPCODE_ROL_ABSX
                        JMP             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_ROL_ACC:
                        LDA             #$2A
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROL_ZP:
                        LDA             #$26
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROL_ABS:
                        LDA             #$2E
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROL_ZPX:
                        LDA             #$36
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROL_ABSX:
                        LDA             #$3E
                        JMP             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_ROR:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_NONE
                        BEQ             ASM_FIND_OPCODE_ROR_ACC
                        CMP             #ASM_OPM_ACC
                        BEQ             ASM_FIND_OPCODE_ROR_ACC
                        CMP             #ASM_OPM_ZP8
                        BEQ             ASM_FIND_OPCODE_ROR_ZP
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_FIND_OPCODE_ROR_ABS
                        CMP             #ASM_OPM_ZP_X
                        BEQ             ASM_FIND_OPCODE_ROR_ZPX
                        CMP             #ASM_OPM_ABS_X
                        BEQ             ASM_FIND_OPCODE_ROR_ABSX
                        JMP             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_ROR_ACC:
                        LDA             #$6A
                        JMP             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROR_ZP:
                        LDA             #$66
                        BRA             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROR_ABS:
                        LDA             #$6E
                        BRA             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROR_ZPX:
                        LDA             #$76
                        BRA             ASM_FIND_OPCODE_OK_A
ASM_FIND_OPCODE_ROR_ABSX:
                        LDA             #$7E
                        BRA             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_BCC:
                        LDA             #$90
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BCS:
                        LDA             #$B0
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BEQ:
                        LDA             #$F0
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BMI:
                        LDA             #$30
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BNE:
                        LDA             #$D0
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BPL:
                        LDA             #$10
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BRA:
                        LDA             #$80
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BVC:
                        LDA             #$50
                        BRA             ASM_FIND_OPCODE_BRANCH_A
ASM_FIND_OPCODE_BVS:
                        LDA             #$70
ASM_FIND_OPCODE_BRANCH_A:
                        STA             ASM_TMP0_LO
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_REL8
                        BEQ             ASM_FIND_OPCODE_BRANCH_OK
                        BRA             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_BRANCH_OK:
                        LDA             ASM_TMP0_LO
                        BRA             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_BBR:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_FIND_OPCODE_BBR_BIT_ZP_REL
                        BRA             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_BBR_BIT_ZP_REL:
                        LDA             #$0F
                        BRA             ASM_FIND_OPCODE_BIT_ZP_A
ASM_FIND_OPCODE_BBS:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_FIND_OPCODE_BBS_BIT_ZP_REL
                        BRA             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_BBS_BIT_ZP_REL:
                        LDA             #$8F
                        BRA             ASM_FIND_OPCODE_BIT_ZP_A

ASM_FIND_OPCODE_RMB:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP
                        BEQ             ASM_FIND_OPCODE_RMB_BIT_ZP
                        BRA             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_RMB_BIT_ZP:
                        LDA             #$07
                        BRA             ASM_FIND_OPCODE_BIT_ZP_A
ASM_FIND_OPCODE_SMB:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP
                        BEQ             ASM_FIND_OPCODE_SMB_BIT_ZP
                        BRA             ASM_FIND_OPCODE_BAD_MODE
ASM_FIND_OPCODE_SMB_BIT_ZP:
                        LDA             #$87
ASM_FIND_OPCODE_BIT_ZP_A:
                        STA             ASM_TMP0_LO
                        LDA             ASM_TMP1_LO
                        ASL
                        ASL
                        ASL
                        ASL
                        CLC
                        ADC             ASM_TMP0_LO
                        BRA             ASM_FIND_OPCODE_OK_A

ASM_FIND_OPCODE_BAD_MODE:
                        LDA             #ASM_STATUS_BAD_MODE
ASM_FIND_OPCODE_FAIL_A:
                        STA             ASM_STATUS
                        CLC
                        RTS
ASM_FIND_OPCODE_OK_A:
                        STA             ASM_TMP0_LO
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDA             ASM_TMP0_LO
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT
; IN : Parsed mnemonic statement in ASM_STMT_*.
; OUT: C=1,A=OK,X/Y=advanced PC. C=0,A=status,X/Y=current PC on failure.
; NOTE: Unresolved operands emit placeholders and carry fixup rows.
; ----------------------------------------------------------------------------
ASM_EMIT:
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_MNEM
                        BEQ             ASM_EMIT_MNEM
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_MNEM:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_CLASS_OPERAND
                        BCS             ASM_EMIT_CLASS_OK
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_CLASS_OK:
                        JSR             ASM_FIND_OPCODE
                        BCS             ASM_EMIT_OPCODE_OK
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_OPCODE_OK:
                        STA             ASM_TMP0_LO
                        JSR             ASM_EMIT_MNEM_ROOM
                        BCS             ASM_EMIT_OPCODE_ROOM_OK
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_OPCODE_ROOM_OK:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_OPCODE_WRITTEN
                        RTS
ASM_EMIT_OPCODE_WRITTEN:
                        LDA             ASM_FLAGS
                        AND             #ASM_OPF_UNRESOLVED
                        BEQ             ASM_EMIT_RESOLVED_OPERAND
                        JMP             ASM_EMIT_UNRESOLVED_OPERAND
ASM_EMIT_RESOLVED_OPERAND:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_EMIT_BIT_ZP_REL_OPERAND
                        CMP             #ASM_OPM_REL8
                        BEQ             ASM_EMIT_REL8_OPERAND
                        JSR             ASM_MODE_PATCH_BYTES
                        BCS             ASM_EMIT_RESOLVED_SIZE_OK
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_RESOLVED_SIZE_OK:
                        BEQ             ASM_EMIT_OK
                        PHA
                        JSR             ASM_RELOC_NOTE_RESOLVED_OPERAND
                        PLA
                        CMP             #$01
                        BEQ             ASM_EMIT_BYTE_OPERAND
                        BRA             ASM_EMIT_WORD_OPERAND

ASM_EMIT_REL8_OPERAND:
                        JSR             ASM_PREP_REL8
                        BCS             ASM_EMIT_BYTE_OPERAND
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_BIT_ZP_REL_OPERAND:
                        LDA             ASM_CARE_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_BIT_ZP_REL_ZP_OK
                        RTS
ASM_EMIT_BIT_ZP_REL_ZP_OK:
                        JSR             ASM_PREP_REL8
                        BCS             ASM_EMIT_BYTE_OPERAND
                        JMP             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_BYTE_OPERAND:
                        LDA             ASM_VALUE_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_OK
                        RTS
ASM_EMIT_WORD_OPERAND:
                        LDA             ASM_VALUE_LO
                        LDX             ASM_VALUE_HI
                        JSR             ASM_EMIT_WORD_LE
                        BCS             ASM_EMIT_OK
                        RTS
ASM_EMIT_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

ASM_EMIT_MNEM_ROOM:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_EMIT_ROOM_THREE
                        JSR             ASM_MODE_PATCH_BYTES
                        BCS             ASM_EMIT_ROOM_SIZE_OK
                        RTS
ASM_EMIT_ROOM_SIZE_OK:
                        CLC
                        ADC             #$01
                        BRA             ASM_EMIT_ROOM_FOR_A
ASM_EMIT_ROOM_THREE:
                        LDA             #$03

ASM_EMIT_ROOM_FOR_A:
                        STA             ASM_ROOM_COUNT
                        BEQ             ASM_EMIT_ROOM_OK
                        LDA             ASM_PC_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_EMIT_ROOM_BAD_RANGE
                        LDA             ASM_PC_LO
                        LDX             ASM_PC_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_EMIT_ROOM_BAD_RANGE
                        LDA             ASM_ROOM_COUNT
                        SEC
                        SBC             #$01
                        CLC
                        ADC             ASM_PC_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_PC_HI
                        ADC             #$00
                        STA             ASM_TMP1_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_EMIT_ROOM_BAD_RANGE
                        LDA             ASM_TMP1_LO
                        LDX             ASM_TMP1_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_EMIT_ROOM_BAD_RANGE
                        BRA             ASM_EMIT_ROOM_OK
ASM_EMIT_ROOM_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_EMIT_ROOM_OK:
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_TARGET_ADDR_OK
; IN : A=address lo, X=address hi.
; OUT: C=1 when the address is outside the protected ASM runtime workspace.
;      C=0 when the address is inside [guard_start, ASM_CODE_BUF).
; NOTE: Runtime-paste ASM_CODE_BUF is a fallback buffer; flash ASM uses its
;       small high-RAM ASM_CODE_BUF only as the guard fence before I/O.
; ----------------------------------------------------------------------------
ASM_TARGET_ADDR_OK:
                        CPX             #ASM_TARGET_GUARD_HI
                        BCC             ASM_TARGET_ADDR_SAFE
                        BNE             ASM_TARGET_ADDR_CHECK_END
                        CMP             #ASM_TARGET_GUARD_LO
                        BCC             ASM_TARGET_ADDR_SAFE
ASM_TARGET_ADDR_CHECK_END:
                        CPX             #>ASM_CODE_BUF
                        BCC             ASM_TARGET_ADDR_GUARDED
                        BNE             ASM_TARGET_ADDR_SAFE
                        CMP             #<ASM_CODE_BUF
                        BCC             ASM_TARGET_ADDR_GUARDED
ASM_TARGET_ADDR_SAFE:
                        SEC
                        RTS
ASM_TARGET_ADDR_GUARDED:
                        CLC
                        RTS

ASM_MODE_PATCH_BYTES:
                        LDX             ASM_MODE
                        CPX             #(ASM_OPM_BIT_ZP_REL+1)
                        BCC             ASM_MODE_PATCH_BYTES_OK
                        LDA             #ASM_STATUS_BAD_MODE
                        CLC
                        RTS
ASM_MODE_PATCH_BYTES_OK:
                        LDA             ASM_OPM_PATCH_BYTES,X
                        SEC
                        RTS

ASM_PREP_REL8:
                        LDA             ASM_PC_LO
                        CLC
                        ADC             #$01
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        ADC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             ASM_TMP0_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_VALUE_HI
                        SBC             ASM_TMP0_HI
                        STA             ASM_TMP0_HI
                        BEQ             ASM_PREP_REL8_POS
                        CMP             #$FF
                        BEQ             ASM_PREP_REL8_NEG
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PREP_REL8_POS:
                        LDA             ASM_TMP0_LO
                        BMI             ASM_PREP_REL8_BAD_RANGE
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        SEC
                        RTS
ASM_PREP_REL8_NEG:
                        LDA             ASM_TMP0_LO
                        BMI             ASM_PREP_REL8_OK
ASM_PREP_REL8_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PREP_REL8_OK:
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        SEC
                        RTS

ASM_EMIT_UNRESOLVED_OPERAND:
                        LDA             ASM_MODE
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_EMIT_UNRESOLVED_BIT_ZP_REL
                        JSR             ASM_STORE_FIXUP_CURRENT
                        BCS             ASM_EMIT_FIXUP_STORED
                        BRA             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_UNRESOLVED_BIT_ZP_REL:
                        LDA             ASM_CARE_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_UNRESOLVED_BIT_ZP_OK
                        RTS
ASM_EMIT_UNRESOLVED_BIT_ZP_OK:
                        JSR             ASM_STORE_FIXUP_CURRENT
                        BCS             ASM_EMIT_UNRESOLVED_BIT_FIXUP_OK
                        BRA             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_UNRESOLVED_BIT_FIXUP_OK:
                        LDA             #$FF
                        JSR             ASM_EMIT_BYTE
                        BCC             ASM_EMIT_PLACEHOLDER_FAIL
                        JMP             ASM_EMIT_OK
ASM_EMIT_FIXUP_STORED:
                        JSR             ASM_MODE_PATCH_BYTES
                        BCS             ASM_EMIT_FIXUP_SIZE_OK
                        BRA             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_FIXUP_SIZE_OK:
                        BEQ             ASM_EMIT_FIXUP_BAD_MODE
                        CMP             #$02
                        BEQ             ASM_EMIT_PLACEHOLDER_WORD
ASM_EMIT_PLACEHOLDER_BYTE:
                        LDA             #$FF
                        JSR             ASM_EMIT_BYTE
                        BCC             ASM_EMIT_PLACEHOLDER_FAIL
                        JMP             ASM_EMIT_OK
ASM_EMIT_FIXUP_BAD_MODE:
                        LDA             #ASM_STATUS_BAD_MODE
                        BRA             ASM_EMIT_MNEM_FAIL_A
ASM_EMIT_PLACEHOLDER_FAIL:
                        RTS
ASM_EMIT_PLACEHOLDER_WORD:
                        LDA             #$FF
                        LDX             #$FF
                        JSR             ASM_EMIT_WORD_LE
                        BCC             ASM_EMIT_PLACEHOLDER_FAIL
                        JMP             ASM_EMIT_OK

ASM_EMIT_MNEM_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_STORE_FIXUP_CURRENT
; IN : ASM_NAME_PTR/ASM_LEN/ASM_HASH* name unresolved symbol.
;      ASM_MODE = emitted operand mode. ASM_PC = operand patch site.
; OUT: C=1 when a pending row was stored. C=0,A=BAD_FIX if full.
; ----------------------------------------------------------------------------
ASM_STORE_FIXUP_CURRENT:
                        LDX             ASM_FIX_COUNT
                        CPX             #ASM_FIX_MAX
                        BCC             ASM_STORE_FIXUP_HAVE_ROOM
                        LDA             #ASM_STATUS_BAD_FIX
                        CLC
                        RTS
ASM_STORE_FIXUP_HAVE_ROOM:
                        JSR             ASM_LOAD_FIX_PLAN_CURRENT
                        LDA             ASM_HASH0
                        STA             ASM_FIX_HASH0,X
                        LDA             ASM_HASH1
                        STA             ASM_FIX_HASH1,X
                        LDA             ASM_HASH2
                        STA             ASM_FIX_HASH2,X
                        LDA             ASM_HASH3
                        STA             ASM_FIX_HASH3,X
                        LDA             ASM_LEN
                        STA             ASM_FIX_NAME_LEN,X
                        LDA             ASM_MODE
                        STA             ASM_FIX_MODE,X
                        LDA             ASM_FIX_PLAN_SEL
                        STA             ASM_FIX_SEL,X
                        LDA             ASM_PC_LO
                        STA             ASM_FIX_SITE_LO,X
                        STA             ASM_FIX_BASE_LO,X
                        LDA             ASM_PC_HI
                        STA             ASM_FIX_SITE_HI,X
                        STA             ASM_FIX_BASE_HI,X
                        JSR             ASM_FIX_ADD_OPERAND_SIZE_X
                        LDA             #ASM_FIX_PENDING
                        STA             ASM_FIX_STATE,X
                        JSR             ASM_STORE_FIXUP_NAME_X
                        INC             ASM_FIX_COUNT
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS

ASM_FIX_ADD_OPERAND_SIZE_X:
                        PHX
                        LDA             ASM_FIX_MODE,X
                        TAX
                        LDA             ASM_OPM_PATCH_BYTES,X
                        PLX
                        CLC
                        ADC             ASM_FIX_BASE_LO,X
                        STA             ASM_FIX_BASE_LO,X
                        LDA             ASM_FIX_BASE_HI,X
                        ADC             #$00
                        STA             ASM_FIX_BASE_HI,X
                        RTS

ASM_STORE_FIXUP_NAME_X:
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDY             #$00
ASM_STORE_FIXUP_NAME_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_STORE_FIXUP_NAME_TERM
                        CPY             #(ASM_FIX_NAME_MAX-1)
                        BCS             ASM_STORE_FIXUP_NAME_TERM
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        STA             (ASM_FIX_PTR_LO),Y
                        INY
                        BRA             ASM_STORE_FIXUP_NAME_LOOP
ASM_STORE_FIXUP_NAME_TERM:
                        LDA             #$00
                        STA             (ASM_FIX_PTR_LO),Y
                        RTS

ASM_SET_FIX_NAME_PTR_X:
                        PHX
                        TXA
                        LSR
                        LSR
                        LSR
                        STA             ASM_TMP0_HI
                        TXA
                        ASL
                        ASL
                        ASL
                        ASL
                        ASL
                        CLC
                        ADC             #<ASM_FIX_NAME_TEXT
                        STA             ASM_FIX_PTR_LO
                        LDA             #>ASM_FIX_NAME_TEXT
                        ADC             ASM_TMP0_HI
                        STA             ASM_FIX_PTR_HI
                        PLX
                        RTS

ASM_FIX_HAS_PENDING:
                        LDX             #$00
ASM_FIX_HAS_PENDING_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_FIX_HAS_PENDING_NO
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BEQ             ASM_FIX_HAS_PENDING_YES
                        INX
                        BRA             ASM_FIX_HAS_PENDING_LOOP
ASM_FIX_HAS_PENDING_YES:
                        SEC
                        RTS
ASM_FIX_HAS_PENDING_NO:
                        CLC
                        RTS

ASM_FIX_HAS_PENDING_REQUIRED:
                        LDX             #$00
ASM_FIX_HAS_PENDING_REQ_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_FIX_HAS_PENDING_REQ_NO
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_FIX_HAS_PENDING_REQ_NEXT
                        JSR             ASM_FIX_IMPORT_RELOC_X
                        BCC             ASM_FIX_HAS_PENDING_REQ_YES
                        LDA             #ASM_FIX_IMPORTED
                        STA             ASM_FIX_STATE,X
ASM_FIX_HAS_PENDING_REQ_NEXT:
                        INX
                        BRA             ASM_FIX_HAS_PENDING_REQ_LOOP
ASM_FIX_HAS_PENDING_REQ_YES:
                        SEC
                        RTS
ASM_FIX_HAS_PENDING_REQ_NO:
                        CLC
                        RTS

ASM_FIX_HAS_PENDING_LOCAL:
                        LDX             #$00
ASM_FIX_HAS_PENDING_LOCAL_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_FIX_HAS_PENDING_LOCAL_NO
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_FIX_HAS_PENDING_LOCAL_NEXT
                        LDA             ASM_FIX_SEL,X
                        AND             #ASM_FIXF_LOCAL
                        BNE             ASM_FIX_HAS_PENDING_LOCAL_YES
ASM_FIX_HAS_PENDING_LOCAL_NEXT:
                        INX
                        BRA             ASM_FIX_HAS_PENDING_LOCAL_LOOP
ASM_FIX_HAS_PENDING_LOCAL_YES:
                        SEC
                        RTS
ASM_FIX_HAS_PENDING_LOCAL_NO:
                        CLC
                        RTS

ASM_RESOLVE_FIXUPS_CURRENT:
                        STZ             ASM_FIX_RESOLVE_COUNT
                        LDX             #$00
ASM_RESOLVE_FIXUPS_LOOP:
                        CPX             ASM_FIX_COUNT
                        BCS             ASM_RESOLVE_FIXUPS_DONE
                        LDA             ASM_FIX_STATE,X
                        CMP             #ASM_FIX_PENDING
                        BNE             ASM_RESOLVE_FIXUPS_NEXT
                        JSR             ASM_FIX_MATCH_CURRENT_X
                        BCC             ASM_RESOLVE_FIXUPS_NEXT
                        JSR             ASM_PATCH_FIXUP_X
                        BCS             ASM_RESOLVE_FIXUPS_PATCHED
                        STA             ASM_STATUS
                        CLC
                        RTS
ASM_RESOLVE_FIXUPS_PATCHED:
                        INC             ASM_FIX_RESOLVE_COUNT
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_FIX_LAST_SITE_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_FIX_LAST_SITE_HI
                        JSR             ASM_RELOC_NOTE_FIXUP_X
                        LDA             #ASM_FIX_RESOLVED
                        STA             ASM_FIX_STATE,X
ASM_RESOLVE_FIXUPS_NEXT:
                        INX
                        BRA             ASM_RESOLVE_FIXUPS_LOOP
ASM_RESOLVE_FIXUPS_DONE:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS

ASM_FIX_MATCH_CURRENT_X:
                        LDA             ASM_HASH0
                        CMP             ASM_FIX_HASH0,X
                        BNE             ASM_FIX_MATCH_NO
                        LDA             ASM_HASH1
                        CMP             ASM_FIX_HASH1,X
                        BNE             ASM_FIX_MATCH_NO
                        LDA             ASM_HASH2
                        CMP             ASM_FIX_HASH2,X
                        BNE             ASM_FIX_MATCH_NO
                        LDA             ASM_HASH3
                        CMP             ASM_FIX_HASH3,X
                        BNE             ASM_FIX_MATCH_NO
                        LDA             ASM_LEN
                        CMP             ASM_FIX_NAME_LEN,X
                        BNE             ASM_FIX_MATCH_NO
                        JSR             ASM_FIX_TEXT_MATCH_X
                        RTS
ASM_FIX_MATCH_NO:
                        CLC
                        RTS

ASM_FIX_TEXT_MATCH_X:
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDY             #$00
ASM_FIX_TEXT_MATCH_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_FIX_TEXT_MATCH_YES
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        STA             ASM_TMP0_LO
                        LDA             (ASM_FIX_PTR_LO),Y
                        CMP             ASM_TMP0_LO
                        BNE             ASM_FIX_TEXT_MATCH_NO
                        INY
                        BRA             ASM_FIX_TEXT_MATCH_LOOP
ASM_FIX_TEXT_MATCH_YES:
                        SEC
                        RTS
ASM_FIX_TEXT_MATCH_NO:
                        CLC
                        RTS

ASM_PATCH_FIXUP_X:
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_FIX_PTR_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_FIX_PTR_HI
                        LDA             ASM_FIX_MODE,X
                        CMP             #ASM_OPM_REL8
                        BEQ             ASM_PATCH_FIXUP_REL8
                        CMP             #ASM_OPM_BIT_ZP_REL
                        BEQ             ASM_PATCH_FIXUP_REL8
                        CMP             #ASM_OPM_IMM8
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP8
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP_X
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP_Y
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP_IND
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP_X_IND
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ZP_IND_Y
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_BIT_ZP
                        BEQ             ASM_PATCH_FIXUP_BYTE
                        CMP             #ASM_OPM_ABS16
                        BEQ             ASM_PATCH_FIXUP_WORD
                        CMP             #ASM_OPM_ABS_X
                        BEQ             ASM_PATCH_FIXUP_WORD
                        CMP             #ASM_OPM_ABS_Y
                        BEQ             ASM_PATCH_FIXUP_WORD
                        CMP             #ASM_OPM_ABS_IND
                        BEQ             ASM_PATCH_FIXUP_WORD
                        CMP             #ASM_OPM_ABS_X_IND
                        BEQ             ASM_PATCH_FIXUP_WORD
                        LDA             #ASM_STATUS_BAD_MODE
                        CLC
                        RTS

ASM_PATCH_FIXUP_BYTE:
                        LDA             ASM_FIX_SEL,X
                        AND             #ASM_FIX_SEL_MASK
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_PATCH_FIXUP_BYTE_LO
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_PATCH_FIXUP_BYTE_HI
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_PATCH_FIXUP_BYTE_RANGE_OK
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PATCH_FIXUP_BYTE_RANGE_OK:
ASM_PATCH_FIXUP_BYTE_LO:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_FIX_PTR_LO),Y
                        SEC
                        RTS
ASM_PATCH_FIXUP_BYTE_HI:
                        LDY             #$00
                        LDA             ASM_VALUE_HI
                        STA             (ASM_FIX_PTR_LO),Y
                        SEC
                        RTS

ASM_PATCH_FIXUP_WORD:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_FIX_PTR_LO),Y
                        INY
                        LDA             ASM_VALUE_HI
                        STA             (ASM_FIX_PTR_LO),Y
                        SEC
                        RTS

ASM_PATCH_FIXUP_REL8:
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             ASM_FIX_BASE_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_VALUE_HI
                        SBC             ASM_FIX_BASE_HI,X
                        STA             ASM_TMP0_HI
                        BEQ             ASM_PATCH_FIXUP_REL8_POS
                        CMP             #$FF
                        BEQ             ASM_PATCH_FIXUP_REL8_NEG
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PATCH_FIXUP_REL8_POS:
                        LDA             ASM_TMP0_LO
                        BMI             ASM_PATCH_FIXUP_REL8_BAD
                        BRA             ASM_PATCH_FIXUP_REL8_WRITE
ASM_PATCH_FIXUP_REL8_NEG:
                        LDA             ASM_TMP0_LO
                        BMI             ASM_PATCH_FIXUP_REL8_WRITE
ASM_PATCH_FIXUP_REL8_BAD:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PATCH_FIXUP_REL8_WRITE:
                        LDY             #$00
                        STA             (ASM_FIX_PTR_LO),Y
                        SEC
                        RTS

ASM_RELOC_NOTE_RESOLVED_OPERAND:
                        LDA             ASM_FLAGS
                        AND             #ASM_OPF_RELOC_INTERNAL
                        BEQ             ASM_RELOC_NOTE_RESOLVED_DONE
                        JSR             ASM_RELOC_KIND_FOR_CURRENT
                        BCC             ASM_RELOC_NOTE_RESOLVED_DONE
                        PHA
                        LDA             ASM_PC_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_PC_HI
                        STA             ASM_TMP0_HI
                        LDA             ASM_FIX_PLAN_SEL
                        AND             #ASM_FIX_SEL_MASK
                        BEQ             ASM_RELOC_NOTE_RESOLVED_VALUE
                        LDA             ASM_RELOC_PLAN_TARGET_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_RELOC_PLAN_TARGET_HI
                        STA             ASM_TMP1_HI
                        BRA             ASM_RELOC_NOTE_RESOLVED_STORE
ASM_RELOC_NOTE_RESOLVED_VALUE:
                        LDA             ASM_VALUE_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_TMP1_HI
ASM_RELOC_NOTE_RESOLVED_STORE:
                        PLA
                        JSR             ASM_RELOC_STORE_A
ASM_RELOC_NOTE_RESOLVED_DONE:
                        SEC
                        RTS

ASM_RELOC_NOTE_FIXUP_X:
                        PHX
                        LDA             ASM_RELOC_RESOLVE_FLAGS
                        AND             #ASM_OPF_RELOC_INTERNAL
                        BEQ             ASM_RELOC_NOTE_FIXUP_DONE
                        JSR             ASM_RELOC_KIND_FOR_FIXUP_X
                        BCC             ASM_RELOC_NOTE_FIXUP_DONE
                        PHA
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_TMP0_HI
                        LDA             ASM_VALUE_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_TMP1_HI
                        PLA
                        JSR             ASM_RELOC_STORE_A
ASM_RELOC_NOTE_FIXUP_DONE:
                        PLX
                        SEC
                        RTS

ASM_FIX_IMPORT_RELOC_X:
                        LDA             ASM_FIX_SEL,X
                        AND             #ASM_FIXF_IMPORT
                        BEQ             ASM_FIX_IMPORT_RELOC_NO
                        LDA             ASM_FIX_SEL,X
                        AND             #ASM_FIX_SEL_MASK
                        BEQ             ASM_FIX_IMPORT_RELOC_ABS16
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_FIX_IMPORT_RELOC_LO8
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_FIX_IMPORT_RELOC_HI8
                        BRA             ASM_FIX_IMPORT_RELOC_NO
ASM_FIX_IMPORT_RELOC_ABS16:
                        LDA             ASM_FIX_MODE,X
                        TAY
                        CPY             #(ASM_OPM_BIT_ZP_REL+1)
                        BCS             ASM_FIX_IMPORT_RELOC_NO
                        LDA             ASM_OPM_PATCH_BYTES,Y
                        CMP             #$02
                        BNE             ASM_FIX_IMPORT_RELOC_NO
                        LDA             #ASM_RELOC_ABS16_IMPORT
                        JMP             ASM_RELOC_NOTE_IMPORT_FIXUP_X
ASM_FIX_IMPORT_RELOC_LO8:
                        LDA             ASM_FIX_MODE,X
                        TAY
                        CPY             #(ASM_OPM_BIT_ZP_REL+1)
                        BCS             ASM_FIX_IMPORT_RELOC_NO
                        LDA             ASM_OPM_PATCH_BYTES,Y
                        CMP             #$01
                        BNE             ASM_FIX_IMPORT_RELOC_NO
                        LDA             #ASM_RELOC_LO8_IMPORT
                        JMP             ASM_RELOC_NOTE_IMPORT_FIXUP_X
ASM_FIX_IMPORT_RELOC_HI8:
                        LDA             ASM_FIX_MODE,X
                        TAY
                        CPY             #(ASM_OPM_BIT_ZP_REL+1)
                        BCS             ASM_FIX_IMPORT_RELOC_NO
                        LDA             ASM_OPM_PATCH_BYTES,Y
                        CMP             #$01
                        BNE             ASM_FIX_IMPORT_RELOC_NO
                        LDA             #ASM_RELOC_HI8_IMPORT
                        JMP             ASM_RELOC_NOTE_IMPORT_FIXUP_X
ASM_FIX_IMPORT_RELOC_NO:
                        CLC
                        RTS

ASM_RELOC_NOTE_IMPORT_FIXUP_X:
                        PHA
                        JSR             ASM_IMPORT_FIND_FIXUP_X
                        BCC             ASM_RELOC_NOTE_IMPORT_NO
                        PLA
                        STA             ASM_TMP1_LO
                        JSR             ASM_RELOC_STORE_IMPORT_X
                        SEC
                        RTS
ASM_RELOC_NOTE_IMPORT_NO:
                        PLA
                        CLC
                        RTS

ASM_IMPORT_FIND_FIXUP_X:
                        PHX
                        JSR             ASM_SET_FIX_NAME_PTR_X
                        LDA             ASM_FIX_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_FIX_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_FIX_NAME_LEN,X
                        STA             ASM_LEN
                        JSR             ASM_IMPORT_FIND_CURRENT
                        BCC             ASM_IMPORT_FIND_FIXUP_NO
                        STX             ASM_IMPORT_INDEX
                        PLX
                        SEC
                        RTS
ASM_IMPORT_FIND_FIXUP_NO:
                        PLX
                        CLC
                        RTS

ASM_RELOC_STORE_IMPORT_X:
                        PHX
                        LDA             ASM_FIX_SITE_LO,X
                        STA             ASM_TMP0_LO
                        LDA             ASM_FIX_SITE_HI,X
                        STA             ASM_TMP0_HI
                        LDX             ASM_RELOC_COUNT
                        CPX             #ASM_RELOC_MAX
                        BCC             ASM_RELOC_STORE_IMPORT_ROOM
                        JSR             ASM_SEAL_NOTE_RELOC_TRUNC
                        PLX
                        SEC
                        RTS
ASM_RELOC_STORE_IMPORT_ROOM:
                        LDA             ASM_TMP0_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_RELOC_SITE_LO,X
                        LDA             ASM_TMP0_HI
                        SBC             ASM_START_PC_HI
                        BCS             ASM_RELOC_STORE_IMPORT_SITE_OK
                        JSR             ASM_SEAL_NOTE_RELOC_BAD
                        PLX
                        SEC
                        RTS
ASM_RELOC_STORE_IMPORT_SITE_OK:
                        STA             ASM_RELOC_SITE_HI,X
                        LDA             ASM_IMPORT_INDEX
                        STA             ASM_RELOC_TARGET_LO,X
                        STZ             ASM_RELOC_TARGET_HI,X
                        LDA             ASM_TMP1_LO
                        STA             ASM_RELOC_KIND,X
                        INC             ASM_RELOC_COUNT
                        PLX
                        SEC
                        RTS

ASM_SEAL_RELOCATE:
                        STX             ASM_RELOCATE_BASE_LO
                        STY             ASM_RELOCATE_BASE_HI
                        STZ             ASM_RELOCATE_COUNT
                        JSR             ASM_SEAL_VALIDATE
                        BCS             ASM_SEAL_RELOCATE_HAVE_SEAL
                        RTS
ASM_SEAL_RELOCATE_HAVE_SEAL:
                        JSR             ASM_SEAL_RELOCATE_RANGE_OK
                        BCS             ASM_SEAL_RELOCATE_RANGE_SAFE
                        RTS
ASM_SEAL_RELOCATE_RANGE_SAFE:
                        JSR             ASM_SEAL_RELOCATE_COPY_BODY
                        LDX             #$00
ASM_SEAL_RELOCATE_PATCH_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_SEAL_RELOCATE_DONE
                        STX             ASM_SLOT
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASM_INTERNAL_RELOC_KIND_A
                        BCC             ASM_SEAL_RELOCATE_PATCH_NEXT
                        JSR             ASM_RELOCATE_PATCH_ROW_X
ASM_SEAL_RELOCATE_PATCH_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_SEAL_RELOCATE_PATCH_LOOP
ASM_SEAL_RELOCATE_DONE:
                        LDA             #ASM_STATUS_OK
                        LDX             ASM_RELOCATE_BASE_LO
                        LDY             ASM_RELOCATE_BASE_HI
                        SEC
                        RTS

ASM_INTERNAL_RELOC_KIND_A:
                        CMP             #ASM_RELOC_ABS16_INTERNAL
                        BEQ             ASM_INTERNAL_RELOC_KIND_YES
                        CMP             #ASM_RELOC_LO8_INTERNAL
                        BEQ             ASM_INTERNAL_RELOC_KIND_YES
                        CMP             #ASM_RELOC_HI8_INTERNAL
                        BEQ             ASM_INTERNAL_RELOC_KIND_YES
                        CLC
                        RTS
ASM_INTERNAL_RELOC_KIND_YES:
                        SEC
                        RTS

ASM_SEAL_RELOCATE_RANGE_OK:
                        LDA             ASM_SEAL_LEN_LO
                        ORA             ASM_SEAL_LEN_HI
                        BNE             ASM_SEAL_RELOCATE_RANGE_NONZERO
                        SEC
                        RTS
ASM_SEAL_RELOCATE_RANGE_NONZERO:
                        LDA             ASM_RELOCATE_BASE_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_SEAL_RELOCATE_RANGE_BAD
                        LDA             ASM_RELOCATE_BASE_LO
                        LDX             ASM_RELOCATE_BASE_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_SEAL_RELOCATE_RANGE_BAD
                        LDA             ASM_SEAL_LEN_LO
                        SEC
                        SBC             #$01
                        STA             ASM_TMP0_LO
                        LDA             ASM_SEAL_LEN_HI
                        SBC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_RELOCATE_BASE_LO
                        CLC
                        ADC             ASM_TMP0_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        ADC             ASM_TMP0_HI
                        BCS             ASM_SEAL_RELOCATE_RANGE_BAD
                        STA             ASM_TMP1_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_SEAL_RELOCATE_RANGE_BAD
                        LDA             ASM_TMP1_LO
                        LDX             ASM_TMP1_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_SEAL_RELOCATE_RANGE_BAD
                        SEC
                        RTS
ASM_SEAL_RELOCATE_RANGE_BAD:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS

ASM_SEAL_RELOCATE_COPY_BODY:
                        LDA             ASM_SEAL_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_SEAL_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_RELOCATE_BASE_LO
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        STA             ASM_EMIT_PTR_HI
                        LDA             ASM_SEAL_LEN_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_SEAL_LEN_HI
                        STA             ASM_VALUE_HI
                        ORA             ASM_VALUE_LO
                        BEQ             ASM_SEAL_RELOCATE_COPY_DONE
ASM_SEAL_RELOCATE_COPY_LOOP:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_SCAN_PTR_LO
                        BNE             ASM_SEAL_RELOCATE_COPY_DST
                        INC             ASM_SCAN_PTR_HI
ASM_SEAL_RELOCATE_COPY_DST:
                        INC             ASM_EMIT_PTR_LO
                        BNE             ASM_SEAL_RELOCATE_COPY_COUNT
                        INC             ASM_EMIT_PTR_HI
ASM_SEAL_RELOCATE_COPY_COUNT:
                        DEC             ASM_VALUE_LO
                        LDA             ASM_VALUE_LO
                        CMP             #$FF
                        BNE             ASM_SEAL_RELOCATE_COPY_MORE
                        DEC             ASM_VALUE_HI
ASM_SEAL_RELOCATE_COPY_MORE:
                        LDA             ASM_VALUE_LO
                        ORA             ASM_VALUE_HI
                        BNE             ASM_SEAL_RELOCATE_COPY_LOOP
ASM_SEAL_RELOCATE_COPY_DONE:
                        RTS

ASM_RELOCATE_PATCH_ROW_X:
                        LDA             ASM_RELOCATE_BASE_LO
                        CLC
                        ADC             ASM_RELOC_SITE_LO,X
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        ADC             ASM_RELOC_SITE_HI,X
                        STA             ASM_EMIT_PTR_HI
                        LDA             ASM_RELOCATE_BASE_LO
                        CLC
                        ADC             ASM_RELOC_TARGET_LO,X
                        STA             ASM_VALUE_LO
                        LDA             ASM_RELOCATE_BASE_HI
                        ADC             ASM_RELOC_TARGET_HI,X
                        STA             ASM_VALUE_HI
                        LDA             ASM_RELOC_KIND,X
                        CMP             #ASM_RELOC_ABS16_INTERNAL
                        BEQ             ASM_RELOCATE_PATCH_ABS16
                        CMP             #ASM_RELOC_LO8_INTERNAL
                        BEQ             ASM_RELOCATE_PATCH_LO8
                        CMP             #ASM_RELOC_HI8_INTERNAL
                        BEQ             ASM_RELOCATE_PATCH_HI8
                        RTS
ASM_RELOCATE_PATCH_ABS16:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_EMIT_PTR_LO),Y
                        INY
                        LDA             ASM_VALUE_HI
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_RELOCATE_COUNT
                        RTS
ASM_RELOCATE_PATCH_LO8:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_RELOCATE_COUNT
                        RTS
ASM_RELOCATE_PATCH_HI8:
                        LDY             #$00
                        LDA             ASM_VALUE_HI
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_RELOCATE_COUNT
                        RTS

                        IF              ASM_PACKAGE_ENABLED
ASM_SEAL_PACKAGE:
                        STX             ASM_PACKAGE_BASE_LO
                        STY             ASM_PACKAGE_BASE_HI
                        JSR             ASM_SEAL_COMPUTE_FNV
                        BCS             ASM_SEAL_PACKAGE_HAVE_SEAL
                        RTS
ASM_SEAL_PACKAGE_HAVE_SEAL:
                        JSR             ASM_PACKAGE_COMPUTE_LAYOUT
                        JSR             ASM_PACKAGE_RANGE_OK
                        BCS             ASM_SEAL_PACKAGE_RANGE_SAFE
                        RTS
ASM_SEAL_PACKAGE_RANGE_SAFE:
                        JSR             ASM_PACKAGE_WRITE
                        LDA             #ASM_STATUS_OK
                        LDX             ASM_PACKAGE_BASE_LO
                        LDY             ASM_PACKAGE_BASE_HI
                        SEC
                        RTS

ASM_PACKAGE_COMPUTE_LAYOUT:
                        LDA             ASM_RELOC_COUNT
                        ASL             A
                        ASL             A
                        CLC
                        ADC             ASM_RELOC_COUNT
                        CLC
                        ADC             #$01
                        STA             ASM_PACKAGE_REL_LEN
                        LDA             #ASM_PACKAGE_FIXED_BYTES
                        CLC
                        ADC             ASM_PACKAGE_REL_LEN
                        STA             ASM_PACKAGE_LEN_LO
                        LDA             #$00
                        ADC             #$00
                        STA             ASM_PACKAGE_LEN_HI
                        LDA             ASM_PACKAGE_LEN_LO
                        CLC
                        ADC             ASM_EXPORT_REC_LEN
                        STA             ASM_PACKAGE_LEN_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        ADC             #$00
                        STA             ASM_PACKAGE_LEN_HI
                        LDA             ASM_PACKAGE_LEN_LO
                        CLC
                        ADC             ASM_IMPORT_REC_LEN
                        STA             ASM_PACKAGE_LEN_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        ADC             #$00
                        STA             ASM_PACKAGE_LEN_HI
                        LDA             ASM_PACKAGE_LEN_LO
                        CLC
                        ADC             ASM_SEAL_LEN_LO
                        STA             ASM_PACKAGE_LEN_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        ADC             ASM_SEAL_LEN_HI
                        STA             ASM_PACKAGE_LEN_HI
                        RTS

ASM_PACKAGE_RANGE_OK:
                        LDA             ASM_PACKAGE_LEN_LO
                        ORA             ASM_PACKAGE_LEN_HI
                        BEQ             ASM_PACKAGE_RANGE_BAD
                        LDA             ASM_PACKAGE_BASE_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_PACKAGE_RANGE_BAD
                        LDA             ASM_PACKAGE_BASE_LO
                        LDX             ASM_PACKAGE_BASE_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_PACKAGE_RANGE_BAD
                        LDA             ASM_PACKAGE_BASE_LO
                        CLC
                        ADC             ASM_PACKAGE_LEN_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        ADC             ASM_PACKAGE_LEN_HI
                        BCS             ASM_PACKAGE_RANGE_BAD
                        STA             ASM_VALUE_HI
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             #$01
                        STA             ASM_TMP1_LO
                        LDA             ASM_VALUE_HI
                        SBC             #$00
                        STA             ASM_TMP1_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_PACKAGE_RANGE_BAD
                        LDA             ASM_TMP1_LO
                        LDX             ASM_TMP1_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_PACKAGE_RANGE_BAD
                        LDA             ASM_PACKAGE_BASE_HI
                        CMP             ASM_SEAL_END_HI
                        BCC             ASM_PACKAGE_RANGE_START_LT_END
                        BNE             ASM_PACKAGE_RANGE_OK_DONE
                        LDA             ASM_PACKAGE_BASE_LO
                        CMP             ASM_SEAL_END_LO
                        BCC             ASM_PACKAGE_RANGE_START_LT_END
                        BRA             ASM_PACKAGE_RANGE_OK_DONE
ASM_PACKAGE_RANGE_START_LT_END:
                        LDA             ASM_SEAL_BASE_HI
                        CMP             ASM_VALUE_HI
                        BCC             ASM_PACKAGE_RANGE_BAD
                        BNE             ASM_PACKAGE_RANGE_OK_DONE
                        LDA             ASM_SEAL_BASE_LO
                        CMP             ASM_VALUE_LO
                        BCC             ASM_PACKAGE_RANGE_BAD
ASM_PACKAGE_RANGE_OK_DONE:
                        SEC
                        RTS
ASM_PACKAGE_RANGE_BAD:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS

ASM_PACKAGE_WRITE:
                        LDA             ASM_PACKAGE_BASE_LO
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        STA             ASM_EMIT_PTR_HI
                        LDA             #ASM_PACKAGE_SIG0
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #ASM_PACKAGE_SIG1
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #ASM_PACKAGE_VERSION
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_PACKAGE_LEN_LO
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_PACKAGE_LEN_HI
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #ASM_PACKAGE_TAG_SEAL
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #ASM_SEAL_REC_BYTES
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #<ASM_SEAL_REC
                        STA             ASM_SCAN_PTR_LO
                        LDA             #>ASM_SEAL_REC
                        STA             ASM_SCAN_PTR_HI
                        LDA             #ASM_SEAL_REC_BYTES
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        JSR             ASM_PACKAGE_COPY_BYTES
                        LDA             #ASM_PACKAGE_TAG_RELOC
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_PACKAGE_REL_LEN
                        JSR             ASM_PACKAGE_WRITE_A
                        JSR             ASM_PACKAGE_WRITE_RELOC_REC
                        LDA             #ASM_PACKAGE_TAG_EXPORT
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_EXPORT_REC_LEN
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #<ASM_EXPORT_REC
                        STA             ASM_SCAN_PTR_LO
                        LDA             #>ASM_EXPORT_REC
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_EXPORT_REC_LEN
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        JSR             ASM_PACKAGE_COPY_BYTES
                        LDA             #ASM_PACKAGE_TAG_IMPORT
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_IMPORT_REC_LEN
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             #<ASM_IMPORT_REC
                        STA             ASM_SCAN_PTR_LO
                        LDA             #>ASM_IMPORT_REC
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_IMPORT_REC_LEN
                        STA             ASM_VALUE_LO
                        STZ             ASM_VALUE_HI
                        JSR             ASM_PACKAGE_COPY_BYTES
                        LDA             #ASM_PACKAGE_TAG_BODY
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_SEAL_LEN_LO
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_SEAL_LEN_HI
                        JSR             ASM_PACKAGE_WRITE_A
                        LDA             ASM_SEAL_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_SEAL_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_SEAL_LEN_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_SEAL_LEN_HI
                        STA             ASM_VALUE_HI
                        JMP             ASM_PACKAGE_COPY_BYTES

ASM_PACKAGE_WRITE_RELOC_REC:
                        LDA             ASM_RELOC_COUNT
                        JSR             ASM_PACKAGE_WRITE_A
                        LDX             #$00
ASM_PACKAGE_WRITE_RELOC_KIND:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_PACKAGE_WRITE_RELOC_SITE_LO
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASM_PACKAGE_WRITE_A
                        INX
                        BRA             ASM_PACKAGE_WRITE_RELOC_KIND
ASM_PACKAGE_WRITE_RELOC_SITE_LO:
                        LDX             #$00
ASM_PACKAGE_WRITE_RELOC_SITE_LO_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_PACKAGE_WRITE_RELOC_SITE_HI
                        LDA             ASM_RELOC_SITE_LO,X
                        JSR             ASM_PACKAGE_WRITE_A
                        INX
                        BRA             ASM_PACKAGE_WRITE_RELOC_SITE_LO_LOOP
ASM_PACKAGE_WRITE_RELOC_SITE_HI:
                        LDX             #$00
ASM_PACKAGE_WRITE_RELOC_SITE_HI_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_PACKAGE_WRITE_RELOC_TARGET_LO
                        LDA             ASM_RELOC_SITE_HI,X
                        JSR             ASM_PACKAGE_WRITE_A
                        INX
                        BRA             ASM_PACKAGE_WRITE_RELOC_SITE_HI_LOOP
ASM_PACKAGE_WRITE_RELOC_TARGET_LO:
                        LDX             #$00
ASM_PACKAGE_WRITE_RELOC_TARGET_LO_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_PACKAGE_WRITE_RELOC_TARGET_HI
                        LDA             ASM_RELOC_TARGET_LO,X
                        JSR             ASM_PACKAGE_WRITE_A
                        INX
                        BRA             ASM_PACKAGE_WRITE_RELOC_TARGET_LO_LOOP
ASM_PACKAGE_WRITE_RELOC_TARGET_HI:
                        LDX             #$00
ASM_PACKAGE_WRITE_RELOC_TARGET_HI_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_PACKAGE_WRITE_RELOC_DONE
                        LDA             ASM_RELOC_TARGET_HI,X
                        JSR             ASM_PACKAGE_WRITE_A
                        INX
                        BRA             ASM_PACKAGE_WRITE_RELOC_TARGET_HI_LOOP
ASM_PACKAGE_WRITE_RELOC_DONE:
                        RTS

ASM_PACKAGE_COPY_BYTES:
                        LDA             ASM_VALUE_LO
                        ORA             ASM_VALUE_HI
                        BEQ             ASM_PACKAGE_COPY_DONE
ASM_PACKAGE_COPY_LOOP:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        JSR             ASM_PACKAGE_WRITE_A
                        INC             ASM_SCAN_PTR_LO
                        BNE             ASM_PACKAGE_COPY_COUNT
                        INC             ASM_SCAN_PTR_HI
ASM_PACKAGE_COPY_COUNT:
                        DEC             ASM_VALUE_LO
                        LDA             ASM_VALUE_LO
                        CMP             #$FF
                        BNE             ASM_PACKAGE_COPY_MORE
                        DEC             ASM_VALUE_HI
ASM_PACKAGE_COPY_MORE:
                        LDA             ASM_VALUE_LO
                        ORA             ASM_VALUE_HI
                        BNE             ASM_PACKAGE_COPY_LOOP
ASM_PACKAGE_COPY_DONE:
                        RTS

ASM_PACKAGE_WRITE_A:
                        LDY             #$00
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_EMIT_PTR_LO
                        BNE             ASM_PACKAGE_WRITE_A_DONE
                        INC             ASM_EMIT_PTR_HI
ASM_PACKAGE_WRITE_A_DONE:
                        RTS

                        IF              ASM_PACKAGE_CHECK_ENABLED
ASM_SEAL_CHECK_PACKAGE:
                        STX             ASM_PACKAGE_BASE_LO
                        STY             ASM_PACKAGE_BASE_HI
                        LDA             #ASM_PACKAGE_HDR_BYTES
                        STA             ASM_PACKAGE_LEN_LO
                        STZ             ASM_PACKAGE_LEN_HI
                        JSR             ASM_PACKAGE_CHECK_RANGE_OK
                        BCS             ASM_PACKAGE_CHECK_HAVE_HEADER
                        RTS
ASM_PACKAGE_CHECK_HAVE_HEADER:
                        LDA             ASM_PACKAGE_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDY             #ASM_PACKAGE_OFF_SIG0
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_SIG0
                        BEQ             ASM_PACKAGE_CHECK_SIG0_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_SIG0_OK:
                        LDY             #ASM_PACKAGE_OFF_SIG1
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_SIG1
                        BEQ             ASM_PACKAGE_CHECK_SIG1_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_SIG1_OK:
                        LDY             #ASM_PACKAGE_OFF_VER
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_VERSION
                        BEQ             ASM_PACKAGE_CHECK_VER_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_VER_OK:
                        LDY             #ASM_PACKAGE_OFF_TOTAL
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_PACKAGE_LEN_LO
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_PACKAGE_LEN_HI
                        ORA             ASM_PACKAGE_LEN_LO
                        BNE             ASM_PACKAGE_CHECK_TOTAL_NONZERO
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_TOTAL_NONZERO:
                        JSR             ASM_PACKAGE_CHECK_RANGE_OK
                        BCS             ASM_PACKAGE_CHECK_RANGE_SAFE
                        RTS
ASM_PACKAGE_CHECK_RANGE_SAFE:
                        LDA             ASM_PACKAGE_BASE_LO
                        CLC
                        ADC             #ASM_PACKAGE_HDR_BYTES
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        ADC             #$00
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_PACKAGE_LEN_LO
                        SEC
                        SBC             #ASM_PACKAGE_HDR_BYTES
                        STA             ASM_VALUE_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        SBC             #$00
                        STA             ASM_VALUE_HI
                        BCS             ASM_PACKAGE_CHECK_SEAL
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE

ASM_PACKAGE_CHECK_SEAL:
                        LDA             #ASM_PACKAGE_TAG_SEAL
                        JSR             ASM_PACKAGE_CHECK_TAG_LEN
                        BCS             ASM_PACKAGE_CHECK_SEAL_TAG_OK
                        RTS
ASM_PACKAGE_CHECK_SEAL_TAG_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_SEAL_REC_BYTES
                        BEQ             ASM_PACKAGE_CHECK_SEAL_LEN_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_SEAL_LEN_OK:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_SEAL_ROOM_OK
                        RTS
ASM_PACKAGE_CHECK_SEAL_ROOM_OK:
                        LDY             #ASM_SEAL_REC_OFF_FLAGS
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_SEALF_VALID
                        BEQ             ASM_PACKAGE_CHECK_SEAL_FLAGS_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_SEAL_FLAGS_OK:
                        LDY             #ASM_SEAL_REC_OFF_LEN
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_PACKAGE_SEAL_LEN_LO
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_PACKAGE_SEAL_LEN_HI
                        LDA             ASM_TMP0_LO
                        JSR             ASM_PACKAGE_CHECK_ADVANCE_A
                        BCS             ASM_PACKAGE_CHECK_RELOC
                        RTS

ASM_PACKAGE_CHECK_RELOC:
                        LDA             #ASM_PACKAGE_TAG_RELOC
                        JSR             ASM_PACKAGE_CHECK_TAG_LEN
                        BCS             ASM_PACKAGE_CHECK_RELOC_TAG_OK
                        RTS
ASM_PACKAGE_CHECK_RELOC_TAG_OK:
                        LDA             ASM_TMP0_LO
                        BNE             ASM_PACKAGE_CHECK_RELOC_LEN_NONZERO
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_RELOC_LEN_NONZERO:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_RELOC_ROOM_OK
                        RTS
ASM_PACKAGE_CHECK_RELOC_ROOM_OK:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_SLOT
                        CMP             #(ASM_RELOC_MAX+1)
                        BCC             ASM_PACKAGE_CHECK_RELOC_COUNT_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_RELOC_COUNT_OK:
                        ASL             A
                        ASL             A
                        CLC
                        ADC             ASM_SLOT
                        CLC
                        ADC             #$01
                        CMP             ASM_TMP0_LO
                        BEQ             ASM_PACKAGE_CHECK_RELOC_SHAPE_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_RELOC_SHAPE_OK:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_PACKAGE_CHECK_ADVANCE_A
                        BCS             ASM_PACKAGE_CHECK_EXPORT
                        RTS

ASM_PACKAGE_CHECK_EXPORT:
                        LDA             #ASM_PACKAGE_TAG_EXPORT
                        JSR             ASM_PACKAGE_CHECK_REC_SECTION
                        BCS             ASM_PACKAGE_CHECK_IMPORT
                        RTS

ASM_PACKAGE_CHECK_IMPORT:
                        LDA             #ASM_PACKAGE_TAG_IMPORT
                        JSR             ASM_PACKAGE_CHECK_REC_SECTION
                        BCS             ASM_PACKAGE_CHECK_BODY
                        RTS

ASM_PACKAGE_CHECK_BODY:
                        LDA             #$03
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_BODY_HDR_OK
                        RTS
ASM_PACKAGE_CHECK_BODY_HDR_OK:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             #ASM_PACKAGE_TAG_BODY
                        BEQ             ASM_PACKAGE_CHECK_BODY_TAG_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_BODY_TAG_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_PACKAGE_SEAL_LEN_LO
                        BEQ             ASM_PACKAGE_CHECK_BODY_LO_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_BODY_LO_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_PACKAGE_SEAL_LEN_HI
                        BEQ             ASM_PACKAGE_CHECK_BODY_HI_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_BODY_HI_OK:
                        LDA             #$03
                        JSR             ASM_PACKAGE_CHECK_ADVANCE_A
                        BCS             ASM_PACKAGE_CHECK_BODY_LEFT_OK
                        RTS
ASM_PACKAGE_CHECK_BODY_LEFT_OK:
                        LDA             ASM_VALUE_LO
                        CMP             ASM_PACKAGE_SEAL_LEN_LO
                        BEQ             ASM_PACKAGE_CHECK_BODY_LEFT_LO_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_BODY_LEFT_LO_OK:
                        LDA             ASM_VALUE_HI
                        CMP             ASM_PACKAGE_SEAL_LEN_HI
                        BEQ             ASM_PACKAGE_CHECK_DONE
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_DONE:
                        LDA             #ASM_STATUS_OK
                        LDX             ASM_PACKAGE_BASE_LO
                        LDY             ASM_PACKAGE_BASE_HI
                        SEC
                        RTS

ASM_PACKAGE_CHECK_REC_SECTION:
                        JSR             ASM_PACKAGE_CHECK_TAG_LEN
                        BCS             ASM_PACKAGE_CHECK_REC_TAG_OK
                        RTS
ASM_PACKAGE_CHECK_REC_TAG_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #$02
                        BCS             ASM_PACKAGE_CHECK_REC_LEN_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_REC_LEN_OK:
                        LDA             ASM_TMP0_LO
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_REC_ROOM_OK
                        RTS
ASM_PACKAGE_CHECK_REC_ROOM_OK:
                        LDY             #$01
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP0_LO
                        BEQ             ASM_PACKAGE_CHECK_REC_SHAPE_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_REC_SHAPE_OK:
                        LDA             ASM_TMP0_LO
                        JMP             ASM_PACKAGE_CHECK_ADVANCE_A

ASM_PACKAGE_CHECK_TAG_LEN:
                        STA             ASM_TMP1_LO
                        LDA             #$02
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_TAG_ROOM_OK
                        RTS
ASM_PACKAGE_CHECK_TAG_ROOM_OK:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        CMP             ASM_TMP1_LO
                        BEQ             ASM_PACKAGE_CHECK_TAG_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_LINE
ASM_PACKAGE_CHECK_TAG_OK:
                        INY
                        LDA             (ASM_SCAN_PTR_LO),Y
                        STA             ASM_TMP0_LO
                        STZ             ASM_TMP0_HI
                        LDA             #$02
                        JMP             ASM_PACKAGE_CHECK_ADVANCE_A

ASM_PACKAGE_CHECK_ADVANCE_A:
                        STA             ASM_TMP1_HI
                        JSR             ASM_PACKAGE_CHECK_NEED_A
                        BCS             ASM_PACKAGE_CHECK_ADVANCE_ROOM
                        RTS
ASM_PACKAGE_CHECK_ADVANCE_ROOM:
                        LDA             ASM_SCAN_PTR_LO
                        CLC
                        ADC             ASM_TMP1_HI
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_SCAN_PTR_HI
                        ADC             #$00
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             ASM_TMP1_HI
                        STA             ASM_VALUE_LO
                        LDA             ASM_VALUE_HI
                        SBC             #$00
                        STA             ASM_VALUE_HI
                        SEC
                        RTS

ASM_PACKAGE_CHECK_NEED_A:
                        STA             ASM_TMP1_HI
                        LDA             ASM_VALUE_HI
                        BNE             ASM_PACKAGE_CHECK_NEED_OK
                        LDA             ASM_VALUE_LO
                        CMP             ASM_TMP1_HI
                        BCS             ASM_PACKAGE_CHECK_NEED_OK
                        JMP             ASM_PACKAGE_CHECK_BAD_RANGE
ASM_PACKAGE_CHECK_NEED_OK:
                        SEC
                        RTS

ASM_PACKAGE_CHECK_RANGE_OK:
                        LDA             ASM_PACKAGE_LEN_LO
                        ORA             ASM_PACKAGE_LEN_HI
                        BEQ             ASM_PACKAGE_CHECK_BAD_RANGE
                        LDA             ASM_PACKAGE_BASE_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_PACKAGE_CHECK_BAD_RANGE
                        LDA             ASM_PACKAGE_BASE_LO
                        LDX             ASM_PACKAGE_BASE_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_PACKAGE_CHECK_BAD_RANGE
                        LDA             ASM_PACKAGE_LEN_LO
                        SEC
                        SBC             #$01
                        STA             ASM_TMP0_LO
                        LDA             ASM_PACKAGE_LEN_HI
                        SBC             #$00
                        STA             ASM_TMP0_HI
                        LDA             ASM_PACKAGE_BASE_LO
                        CLC
                        ADC             ASM_TMP0_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_PACKAGE_BASE_HI
                        ADC             ASM_TMP0_HI
                        BCS             ASM_PACKAGE_CHECK_BAD_RANGE
                        STA             ASM_TMP1_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCS             ASM_PACKAGE_CHECK_BAD_RANGE
                        LDA             ASM_TMP1_LO
                        LDX             ASM_TMP1_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCC             ASM_PACKAGE_CHECK_BAD_RANGE
                        SEC
                        RTS
ASM_PACKAGE_CHECK_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PACKAGE_CHECK_BAD_LINE:
                        LDA             #ASM_STATUS_BAD_LINE
                        CLC
                        RTS
                        ENDIF

                        ENDIF

ASM_SEAL_RESOLVE_IMPORTS:
                        JSR             ASM_SEAL_VALIDATE
                        BCS             ASM_SEAL_RESOLVE_HAVE_SEAL
                        RTS
ASM_SEAL_RESOLVE_HAVE_SEAL:
                        STZ             ASM_IMPORT_RESOLVE_COUNT
                        LDX             #$00
ASM_IMPORT_RESOLVE_SCAN_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_IMPORT_RESOLVE_SCAN_DONE
                        STX             ASM_SLOT
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASM_IMPORT_RELOC_KIND_A
                        BCC             ASM_IMPORT_RESOLVE_SCAN_NEXT
                        JSR             ASM_IMPORT_RESOLVE_ROW_X
                        BCS             ASM_IMPORT_RESOLVE_SCAN_NEXT
                        RTS
ASM_IMPORT_RESOLVE_SCAN_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_IMPORT_RESOLVE_SCAN_LOOP
ASM_IMPORT_RESOLVE_SCAN_DONE:
                        LDX             #$00
ASM_IMPORT_RESOLVE_PATCH_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BCS             ASM_IMPORT_RESOLVE_DONE
                        STX             ASM_SLOT
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASM_IMPORT_RELOC_KIND_A
                        BCC             ASM_IMPORT_RESOLVE_PATCH_NEXT
                        JSR             ASM_IMPORT_RESOLVE_ROW_X
                        BCS             ASM_IMPORT_RESOLVE_PATCH_HAVE_ADDR
                        RTS
ASM_IMPORT_RESOLVE_PATCH_HAVE_ADDR:
                        JSR             ASM_IMPORT_PATCH_ROW_X
ASM_IMPORT_RESOLVE_PATCH_NEXT:
                        LDX             ASM_SLOT
                        INX
                        BRA             ASM_IMPORT_RESOLVE_PATCH_LOOP
ASM_IMPORT_RESOLVE_DONE:
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

ASM_IMPORT_RELOC_KIND_A:
                        CMP             #ASM_RELOC_ABS16_IMPORT
                        BEQ             ASM_IMPORT_RELOC_KIND_YES
                        CMP             #ASM_RELOC_LO8_IMPORT
                        BEQ             ASM_IMPORT_RELOC_KIND_YES
                        CMP             #ASM_RELOC_HI8_IMPORT
                        BEQ             ASM_IMPORT_RELOC_KIND_YES
                        CLC
                        RTS
ASM_IMPORT_RELOC_KIND_YES:
                        SEC
                        RTS

ASM_IMPORT_RESOLVE_ROW_X:
                        LDA             ASM_RELOC_TARGET_HI,X
                        BEQ             ASM_IMPORT_RESOLVE_ROW_SLOT_HI_OK
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_RESOLVE_ROW_SLOT_HI_OK:
                        LDA             ASM_RELOC_TARGET_LO,X
                        CMP             ASM_IMPORT_COUNT
                        BCC             ASM_IMPORT_RESOLVE_ROW_SLOT_OK
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_RESOLVE_ROW_SLOT_OK:
                        STA             ASM_IMPORT_INDEX
                        TAX
                        JSR             ASM_IMPORT_RESOLVE_SLOT_X
                        LDX             ASM_SLOT
                        RTS

ASM_IMPORT_RESOLVE_SLOT_X:
                        JSR             ASM_IMPORT_HASH_SLOT_X
                        BCS             ASM_IMPORT_RESOLVE_SLOT_HASH_OK
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_RESOLVE_SLOT_HASH_OK:
                        LDX             #<ASM_HASH0
                        LDY             #>ASM_HASH0
                        JSR             ASM_RJ_RESIDENT_XY
                        BCS             ASM_IMPORT_RESOLVE_SLOT_FOUND
                        LDA             #ASM_STATUS_RJOIN
                        CLC
                        RTS
ASM_IMPORT_RESOLVE_SLOT_FOUND:
                        STX             ASM_VALUE_LO
                        STY             ASM_VALUE_HI
                        SEC
                        RTS

ASM_IMPORT_PATCH_ROW_X:
                        LDA             ASM_SEAL_BASE_LO
                        CLC
                        ADC             ASM_RELOC_SITE_LO,X
                        STA             ASM_EMIT_PTR_LO
                        LDA             ASM_SEAL_BASE_HI
                        ADC             ASM_RELOC_SITE_HI,X
                        STA             ASM_EMIT_PTR_HI
                        LDA             ASM_RELOC_KIND,X
                        CMP             #ASM_RELOC_ABS16_IMPORT
                        BEQ             ASM_IMPORT_PATCH_ABS16
                        CMP             #ASM_RELOC_LO8_IMPORT
                        BEQ             ASM_IMPORT_PATCH_LO8
                        CMP             #ASM_RELOC_HI8_IMPORT
                        BEQ             ASM_IMPORT_PATCH_HI8
                        RTS
ASM_IMPORT_PATCH_ABS16:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_EMIT_PTR_LO),Y
                        INY
                        LDA             ASM_VALUE_HI
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_IMPORT_RESOLVE_COUNT
                        RTS
ASM_IMPORT_PATCH_LO8:
                        LDY             #$00
                        LDA             ASM_VALUE_LO
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_IMPORT_RESOLVE_COUNT
                        RTS
ASM_IMPORT_PATCH_HI8:
                        LDY             #$00
                        LDA             ASM_VALUE_HI
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_IMPORT_RESOLVE_COUNT
                        RTS

ASM_IMPORT_HASH_SLOT_X:
                        STX             ASM_IMPORT_INDEX
                        JSR             ASM_IMPORT_SET_PACK_SRC_X
                        LDX             ASM_IMPORT_INDEX
                        LDA             ASM_IMPORT_NAME_LEN,X
                        STA             ASM_LEN
                        JSR             ASM_FNV1A_INIT
                        STZ             ASM_EXPORT_NAME_INDEX
                        STZ             ASM_IMPORT_PACK_INDEX
ASM_IMPORT_HASH_SLOT_LOOP:
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_IMPORT_HASH_SLOT_DONE
                        JSR             ASM_IMPORT_UNPACK_NEXT3
                        BCC             ASM_IMPORT_HASH_SLOT_FAIL
                        LDA             ASM_P40_CODE0
                        JSR             ASM_IMPORT_HASH_CODE_A
                        BCC             ASM_IMPORT_HASH_SLOT_FAIL
                        INC             ASM_EXPORT_NAME_INDEX
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_IMPORT_HASH_SLOT_DONE
                        LDA             ASM_P40_CODE1
                        JSR             ASM_IMPORT_HASH_CODE_A
                        BCC             ASM_IMPORT_HASH_SLOT_FAIL
                        INC             ASM_EXPORT_NAME_INDEX
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_IMPORT_HASH_SLOT_DONE
                        LDA             ASM_P40_CODE2
                        JSR             ASM_IMPORT_HASH_CODE_A
                        BCC             ASM_IMPORT_HASH_SLOT_FAIL
                        INC             ASM_EXPORT_NAME_INDEX
                        BRA             ASM_IMPORT_HASH_SLOT_LOOP
ASM_IMPORT_HASH_SLOT_DONE:
                        SEC
                        RTS
ASM_IMPORT_HASH_SLOT_FAIL:
                        CLC
                        RTS

ASM_IMPORT_UNPACK_NEXT3:
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             (ASM_SYM_PTR_LO),Y
                        STA             ASM_VALUE_LO
                        INC             ASM_IMPORT_PACK_INDEX
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             (ASM_SYM_PTR_LO),Y
                        STA             ASM_VALUE_HI
                        INC             ASM_IMPORT_PACK_INDEX
                        STZ             ASM_P40_CODE0
ASM_IMPORT_UNPACK_CODE0_LOOP:
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             #$40
                        STA             ASM_TMP0_LO
                        LDA             ASM_VALUE_HI
                        SBC             #$06
                        BCC             ASM_IMPORT_UNPACK_CODE0_DONE
                        STA             ASM_VALUE_HI
                        LDA             ASM_TMP0_LO
                        STA             ASM_VALUE_LO
                        INC             ASM_P40_CODE0
                        BRA             ASM_IMPORT_UNPACK_CODE0_LOOP
ASM_IMPORT_UNPACK_CODE0_DONE:
                        STZ             ASM_P40_CODE1
ASM_IMPORT_UNPACK_CODE1_LOOP:
                        LDA             ASM_VALUE_LO
                        SEC
                        SBC             #$28
                        STA             ASM_TMP0_LO
                        LDA             ASM_VALUE_HI
                        SBC             #$00
                        BCC             ASM_IMPORT_UNPACK_CODE1_DONE
                        STA             ASM_VALUE_HI
                        LDA             ASM_TMP0_LO
                        STA             ASM_VALUE_LO
                        INC             ASM_P40_CODE1
                        BRA             ASM_IMPORT_UNPACK_CODE1_LOOP
ASM_IMPORT_UNPACK_CODE1_DONE:
                        LDA             ASM_VALUE_LO
                        CMP             #$28
                        BCC             ASM_IMPORT_UNPACK_CODE2_OK
                        CLC
                        RTS
ASM_IMPORT_UNPACK_CODE2_OK:
                        STA             ASM_P40_CODE2
                        SEC
                        RTS

ASM_IMPORT_HASH_CODE_A:
                        BEQ             ASM_IMPORT_HASH_CODE_FAIL
                        CMP             #$1B
                        BCS             ASM_IMPORT_HASH_CODE_DIGIT
                        CLC
                        ADC             #'@'
                        BRA             ASM_IMPORT_HASH_CODE_UPDATE
ASM_IMPORT_HASH_CODE_DIGIT:
                        CMP             #$25
                        BCS             ASM_IMPORT_HASH_CODE_SPECIAL
                        SEC
                        SBC             #$1B
                        CLC
                        ADC             #'0'
                        BRA             ASM_IMPORT_HASH_CODE_UPDATE
ASM_IMPORT_HASH_CODE_SPECIAL:
                        CMP             #$25
                        BEQ             ASM_IMPORT_HASH_CODE_UNDER
                        CMP             #$26
                        BEQ             ASM_IMPORT_HASH_CODE_Q
                        CMP             #$27
                        BEQ             ASM_IMPORT_HASH_CODE_DOT
ASM_IMPORT_HASH_CODE_FAIL:
                        CLC
                        RTS
ASM_IMPORT_HASH_CODE_UNDER:
                        LDA             #'_'
                        BRA             ASM_IMPORT_HASH_CODE_UPDATE
ASM_IMPORT_HASH_CODE_Q:
                        LDA             #'?'
                        BRA             ASM_IMPORT_HASH_CODE_UPDATE
ASM_IMPORT_HASH_CODE_DOT:
                        LDA             #'.'
ASM_IMPORT_HASH_CODE_UPDATE:
                        JSR             ASM_FNV1A_UPDATE_A_FAST
                        SEC
                        RTS

ASM_RELOC_KIND_FOR_CURRENT:
                        LDA             ASM_FIX_PLAN_SEL
                        AND             #ASM_FIX_SEL_MASK
                        JSR             ASM_RELOC_KIND_FOR_SEL_A
                        BCS             ASM_RELOC_KIND_CURRENT_DONE
                        LDA             ASM_MODE
                        JMP             ASM_RELOC_KIND_FOR_MODE_A
ASM_RELOC_KIND_CURRENT_DONE:
                        RTS

ASM_RELOC_KIND_FOR_FIXUP_X:
                        LDA             ASM_FIX_SEL,X
                        AND             #ASM_FIX_SEL_MASK
                        JSR             ASM_RELOC_KIND_FOR_SEL_A
                        BCS             ASM_RELOC_KIND_FIXUP_DONE
                        LDA             ASM_FIX_MODE,X
                        JMP             ASM_RELOC_KIND_FOR_MODE_A
ASM_RELOC_KIND_FIXUP_DONE:
                        RTS

ASM_RELOC_KIND_FOR_SEL_A:
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_RELOC_KIND_SEL_LO
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_RELOC_KIND_SEL_HI
                        CLC
                        RTS
ASM_RELOC_KIND_SEL_LO:
                        LDA             #ASM_RELOC_LO8_INTERNAL
                        SEC
                        RTS
ASM_RELOC_KIND_SEL_HI:
                        LDA             #ASM_RELOC_HI8_INTERNAL
                        SEC
                        RTS

ASM_RELOC_KIND_FOR_MODE_A:
                        TAY
                        CPY             #(ASM_OPM_BIT_ZP_REL+1)
                        BCS             ASM_RELOC_KIND_MODE_NO
                        LDA             ASM_OPM_PATCH_BYTES,Y
                        CMP             #$02
                        BEQ             ASM_RELOC_KIND_ABS16
ASM_RELOC_KIND_MODE_NO:
                        CLC
                        RTS
ASM_RELOC_KIND_ABS16:
                        LDA             #ASM_RELOC_ABS16_INTERNAL
                        SEC
                        RTS

ASM_RELOC_STORE_A:
                        PHA
                        LDX             ASM_RELOC_COUNT
                        CPX             #ASM_RELOC_MAX
                        BCC             ASM_RELOC_STORE_HAVE_ROOM
                        PLA
                        JSR             ASM_SEAL_NOTE_RELOC_TRUNC
                        SEC
                        RTS
ASM_RELOC_STORE_HAVE_ROOM:
                        LDA             ASM_TMP0_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_RELOC_SITE_LO,X
                        LDA             ASM_TMP0_HI
                        SBC             ASM_START_PC_HI
                        BCS             ASM_RELOC_STORE_SITE_OK
                        PLA
                        JSR             ASM_SEAL_NOTE_RELOC_BAD
                        SEC
                        RTS
ASM_RELOC_STORE_SITE_OK:
                        STA             ASM_RELOC_SITE_HI,X
                        LDA             ASM_TMP1_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_RELOC_TARGET_LO,X
                        LDA             ASM_TMP1_HI
                        SBC             ASM_START_PC_HI
                        BCS             ASM_RELOC_STORE_TARGET_OK
                        PLA
                        JSR             ASM_SEAL_NOTE_RELOC_BAD
                        SEC
                        RTS
ASM_RELOC_STORE_TARGET_OK:
                        STA             ASM_RELOC_TARGET_HI,X
                        PLA
                        STA             ASM_RELOC_KIND,X
                        INC             ASM_RELOC_COUNT
                        SEC
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
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_STORE_NAME_NOT_LOCAL
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_LOCAL_NAME
                        STA             ASM_STMT_FLAGS
ASM_STORE_NAME_NOT_LOCAL:
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
                        BRA             ASM_SET_TAIL_FROM_PARSE
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
                        CMP             #ASM_VID_DB
                        BEQ             ASM_STORE_OP_DIR_BINDS_PC
                        CMP             #ASM_VID_DW
                        BEQ             ASM_STORE_OP_DIR_BINDS_PC
                        CMP             #ASM_VID_DS
                        BEQ             ASM_STORE_OP_DIR_BINDS_PC
                        BRA             ASM_STORE_OP_DIR_TAIL
ASM_STORE_OP_DIR_BINDS_PC:
                        LDA             ASM_STMT_FLAGS
                        ORA             #ASM_STMTF_BINDS_PC
                        STA             ASM_STMT_FLAGS
ASM_STORE_OP_DIR_TAIL:

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
; Current dispatch applies top-level statement policy and resolved ORG/EQU
; expressions, binds PC labels, emits mnemonics/data, and resolves fixups.
; ----------------------------------------------------------------------------
ASM_DISPATCH_STATEMENT:
                        LDA             ASM_STMT_KIND
                        CMP             #ASM_STMT_ERROR
                        BNE             ASM_DISPATCH_NOT_ERROR
                        JMP             ASM_DISPATCH_STORED_FAIL
ASM_DISPATCH_NOT_ERROR:
                        CMP             #ASM_STMT_EMPTY
                        BNE             ASM_DISPATCH_NOT_EMPTY
                        JMP             ASM_DISPATCH_OK
ASM_DISPATCH_NOT_EMPTY:
                        CMP             #ASM_STMT_LABEL_ONLY
                        BNE             ASM_DISPATCH_NOT_LABEL_ONLY
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_DISPATCH_FAIL_NEAR
                        JMP             ASM_DISPATCH_OK
ASM_DISPATCH_NOT_LABEL_ONLY:
                        CMP             #ASM_STMT_MNEM
                        BNE             ASM_DISPATCH_NOT_MNEM
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_MNEM_NO_NAME
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_DISPATCH_FAIL_NEAR
ASM_DISPATCH_MNEM_NO_NAME:
                        JSR             ASM_EMIT
                        BCC             ASM_DISPATCH_FAIL_NEAR
                        JMP             ASM_DISPATCH_OK
ASM_DISPATCH_FAIL_NEAR:
                        JMP             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_NOT_MNEM:
                        CMP             #ASM_STMT_DIR
                        BEQ             ASM_DISPATCH_DIR
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_DISPATCH_FAIL_A

ASM_DISPATCH_DIR:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_EQU
                        BNE             ASM_DISPATCH_DIR_NOT_EQU
                        JMP             ASM_DISPATCH_DIR_EQU
ASM_DISPATCH_DIR_NOT_EQU:
                        CMP             #ASM_VID_EXPORT
                        BNE             ASM_DISPATCH_DIR_NOT_EXPORT
                        JMP             ASM_DISPATCH_DIR_EXPORT
ASM_DISPATCH_DIR_NOT_EXPORT:
                        CMP             #ASM_VID_IMPORT
                        BNE             ASM_DISPATCH_DIR_NOT_IMPORT
                        JMP             ASM_DISPATCH_DIR_IMPORT
ASM_DISPATCH_DIR_NOT_IMPORT:
                        CMP             #ASM_VID_ORG
                        BNE             ASM_DISPATCH_DIR_NOT_ORG
                        JMP             ASM_DISPATCH_DIR_ORG
ASM_DISPATCH_DIR_NOT_ORG:
                        CMP             #ASM_VID_END
                        BNE             ASM_DISPATCH_DIR_NOT_END
                        JMP             ASM_DISPATCH_DIR_END
ASM_DISPATCH_DIR_NOT_END:
                        CMP             #ASM_VID_DB
                        BNE             ASM_DISPATCH_DIR_NOT_DB
                        JMP             ASM_DISPATCH_DIR_DB
ASM_DISPATCH_DIR_NOT_DB:
                        CMP             #ASM_VID_DW
                        BNE             ASM_DISPATCH_DIR_NOT_DW
                        JMP             ASM_DISPATCH_DIR_DW
ASM_DISPATCH_DIR_NOT_DW:
                        CMP             #ASM_VID_DS
                        BNE             ASM_DISPATCH_DIR_NOT_DS
                        JMP             ASM_DISPATCH_DIR_DS
ASM_DISPATCH_DIR_NOT_DS:
                        LDA             #ASM_STATUS_BAD_DIR
                        JMP             ASM_DISPATCH_FAIL_A

ASM_DISPATCH_DIR_EQU:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BNE             ASM_DISPATCH_DIR_EQU_HAVE_NAME
                        JMP             ASM_DISPATCH_BAD_SYM
ASM_DISPATCH_DIR_EQU_HAVE_NAME:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_EQU_HAVE_TAIL
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_EQU_HAVE_TAIL:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_PARSE_EXPR
                        BCC             ASM_DISPATCH_FAIL_NEAR
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_DISPATCH_DIR_EQU_EXPR_END_OK
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_EQU_EXPR_END_OK:
                        JSR             ASM_DEFINE_EQU
                        BCC             ASM_DISPATCH_FAIL_NEAR
                        JMP             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_EXPORT:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_EXPORT_NO_NAME
                        JMP             ASM_DISPATCH_BAD_SYM
ASM_DISPATCH_DIR_EXPORT_NO_NAME:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_EXPORT_HAVE_TAIL
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_EXPORT_HAVE_TAIL:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_EXPORT_SYMBOL
                        BCS             ASM_DISPATCH_DIR_EXPORT_OK
                        JMP             ASM_DISPATCH_FAIL_NEAR
ASM_DISPATCH_DIR_EXPORT_OK:
                        JMP             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_IMPORT:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_IMPORT_NO_NAME
                        JMP             ASM_DISPATCH_BAD_SYM
ASM_DISPATCH_DIR_IMPORT_NO_NAME:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_IMPORT_HAVE_TAIL
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_IMPORT_HAVE_TAIL:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_IMPORT_SYMBOL
                        BCS             ASM_DISPATCH_DIR_IMPORT_OK
                        JMP             ASM_DISPATCH_FAIL_NEAR
ASM_DISPATCH_DIR_IMPORT_OK:
                        JMP             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_ORG:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_ORG_NO_NAME
                        JMP             ASM_DISPATCH_BAD_SYM
ASM_DISPATCH_DIR_ORG_NO_NAME:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_ORG_HAVE_TAIL
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_ORG_HAVE_TAIL:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_PARSE_EXPR
                        BCS             ASM_DISPATCH_DIR_ORG_EXPR_OK
                        JMP             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_DIR_ORG_EXPR_OK:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_DISPATCH_DIR_ORG_EXPR_END_OK
                        JMP             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_ORG_EXPR_END_OK:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_DISPATCH_DIR_ORG_ADDR
                        JMP             ASM_DISPATCH_BAD_WIDTH
ASM_DISPATCH_DIR_ORG_ADDR:
                        JSR             ASM_SET_PC_FROM_VALUE
                        BCS             ASM_DISPATCH_DIR_ORG_PC_OK
                        JMP             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_DIR_ORG_PC_OK:
                        JMP             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_END:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_END_NO_NAME
                        BRA             ASM_DISPATCH_BAD_SYM
ASM_DISPATCH_DIR_END_NO_NAME:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BEQ             ASM_DISPATCH_DIR_END_NO_TAIL
                        BRA             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_END_NO_TAIL:
                        JMP             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_DB:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_DB_HAVE_TAIL
                        BRA             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_DB_HAVE_TAIL:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_DB_NO_NAME
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_DIR_DB_NO_NAME:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_EMIT_DB
                        BCC             ASM_DISPATCH_FAIL_A
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_DW:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_DW_HAVE_TAIL
                        BRA             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_DW_HAVE_TAIL:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_DW_NO_NAME
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_DIR_DW_NO_NAME:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_EMIT_DW
                        BCC             ASM_DISPATCH_FAIL_A
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_DIR_DS:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_TAIL
                        BNE             ASM_DISPATCH_DIR_DS_HAVE_TAIL
                        BRA             ASM_DISPATCH_BAD_OPER
ASM_DISPATCH_DIR_DS_HAVE_TAIL:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_HAS_NAME
                        BEQ             ASM_DISPATCH_DIR_DS_NO_NAME
                        JSR             ASM_BIND_LABEL
                        BCC             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_DIR_DS_NO_NAME:
                        LDX             ASM_STMT_TAIL_PTR_LO
                        LDY             ASM_STMT_TAIL_PTR_HI
                        JSR             ASM_EMIT_DS
                        BCC             ASM_DISPATCH_FAIL_A
                        BRA             ASM_DISPATCH_OK

ASM_DISPATCH_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        BRA             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_DISPATCH_FAIL_A
ASM_DISPATCH_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
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

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EXPORT_SYMBOL
; IN : X/Y = EXPORT operand tail.
; OUT: C=1,A=OK when NAME is a defined global label and not already exported.
;      C=0,A=status on malformed tail, unknown/local name, duplicate, or full.
; ----------------------------------------------------------------------------
ASM_EXPORT_SYMBOL:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_EXPORT_HAVE_TOKEN
                        RTS
ASM_EXPORT_HAVE_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_EXPORT_HAVE_WORD
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_EXPORT_HAVE_WORD:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_EXPORT_NOT_LOCAL
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_EXPORT_NOT_LOCAL:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_HAS_COLON
                        BEQ             ASM_EXPORT_NO_COLON
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_EXPORT_NO_COLON:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_LEN
                        CMP             #ASM_SYM_NAME_MAX
                        BCC             ASM_EXPORT_LEN_OK
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_EXPORT_LEN_OK:
                        STA             ASM_LEN
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_EXPORT_TAIL_END_OK
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_EXPORT_TAIL_END_OK:
                        LDA             #ASM_SYM_LOOK_SESSION
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_EXPORT_FOUND
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_EXPORT_FOUND:
                        STX             ASM_SLOT
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_FROM_LABEL
                        BNE             ASM_EXPORT_IS_LABEL
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_EXPORT_IS_LABEL:
                        LDX             #$00
ASM_EXPORT_DUP_LOOP:
                        CPX             ASM_EXPORT_COUNT
                        BCS             ASM_EXPORT_NOT_DUP
                        LDA             ASM_EXPORT_SYM_SLOT,X
                        CMP             ASM_SLOT
                        BEQ             ASM_EXPORT_BAD_SYM
                        INX
                        BRA             ASM_EXPORT_DUP_LOOP
ASM_EXPORT_NOT_DUP:
                        LDX             ASM_EXPORT_COUNT
                        CPX             #ASM_EXPORT_MAX
                        BCS             ASM_EXPORT_BAD_SYM
                        LDA             ASM_SLOT
                        STA             ASM_EXPORT_SYM_SLOT,X
                        INC             ASM_EXPORT_COUNT
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS
ASM_EXPORT_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_IMPORT_SYMBOL
; IN : X/Y = IMPORT operand tail.
; OUT: C=1,A=OK when NAME is a global import name and not already imported.
;      C=0,A=status on malformed tail, local name, duplicate, or full.
; NOTE: This first pass records import metadata only. It does not resolve
;       external fixups.
; ----------------------------------------------------------------------------
ASM_IMPORT_SYMBOL:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_IMPORT_HAVE_TOKEN
                        RTS
ASM_IMPORT_HAVE_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_IMPORT_HAVE_WORD
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_HAVE_WORD:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_IMPORT_NOT_LOCAL
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_NOT_LOCAL:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_HAS_COLON
                        BEQ             ASM_IMPORT_NO_COLON
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_IMPORT_NO_COLON:
                        JSR             ASM_LOOKUP_WORD
                        BCC             ASM_IMPORT_NOT_RESERVED
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_NOT_RESERVED:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_LEN
                        CMP             #ASM_SYM_NAME_MAX
                        BCC             ASM_IMPORT_LEN_OK
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_IMPORT_LEN_OK:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_IMPORT_TAIL_END_OK
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_IMPORT_TAIL_END_OK:
                        LDX             ASM_IMPORT_COUNT
                        CPX             #ASM_IMPORT_MAX
                        BCS             ASM_IMPORT_BAD_SYM
                        JSR             ASM_IMPORT_PACK_TOKEN_X
                        BCC             ASM_IMPORT_BAD_SYM
                        JSR             ASM_IMPORT_DUP_CHECK
                        BCC             ASM_IMPORT_BAD_SYM
                        INC             ASM_IMPORT_COUNT
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS
ASM_IMPORT_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS

ASM_IMPORT_PACK_TOKEN_X:
                        STX             ASM_IMPORT_INDEX
                        LDA             ASM_LEN
                        STA             ASM_IMPORT_NAME_LEN,X
                        JSR             ASM_IMPORT_SET_PACK_PTR_X
                        JSR             ASM_IMPORT_CLEAR_PACK
                        LDA             ASM_NAME_PTR_LO
                        STA             ASM_SYM_PTR_LO
                        LDA             ASM_NAME_PTR_HI
                        STA             ASM_SYM_PTR_HI
                        STZ             ASM_EXPORT_NAME_INDEX
                        STZ             ASM_IMPORT_PACK_INDEX
ASM_IMPORT_PACK_LOOP:
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_IMPORT_PACK_DONE
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_PACK_FAIL
                        STA             ASM_P40_CODE0
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_PACK_FAIL
                        STA             ASM_P40_CODE1
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_PACK_FAIL
                        STA             ASM_P40_CODE2
                        LDA             ASM_P40_CODE0
                        LDX             ASM_P40_CODE1
                        LDY             ASM_P40_CODE2
                        JSR             ASM_PACK40_PACK3
                        BCC             ASM_IMPORT_PACK_FAIL
                        STY             ASM_TMP0_HI
                        LDY             ASM_IMPORT_PACK_INDEX
                        TXA
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_IMPORT_PACK_INDEX
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             ASM_TMP0_HI
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_IMPORT_PACK_INDEX
                        BRA             ASM_IMPORT_PACK_LOOP
ASM_IMPORT_PACK_DONE:
                        SEC
                        RTS
ASM_IMPORT_PACK_FAIL:
                        CLC
                        RTS

ASM_IMPORT_DUP_CHECK:
                        LDX             #$00
ASM_IMPORT_DUP_LOOP:
                        CPX             ASM_IMPORT_COUNT
                        BCS             ASM_IMPORT_DUP_NOT_FOUND
                        LDA             ASM_IMPORT_NAME_LEN,X
                        CMP             ASM_LEN
                        BNE             ASM_IMPORT_DUP_NEXT
                        STX             ASM_TMP1_LO
                        JSR             ASM_IMPORT_SET_PACK_SRC_X
                        LDY             #$00
ASM_IMPORT_DUP_BYTE_LOOP:
                        CPY             #ASM_EXPORT_NAME_PACK_MAX
                        BCS             ASM_IMPORT_DUP_FOUND
                        LDA             (ASM_SYM_PTR_LO),Y
                        CMP             (ASM_EMIT_PTR_LO),Y
                        BNE             ASM_IMPORT_DUP_RESTORE_NEXT
                        INY
                        BRA             ASM_IMPORT_DUP_BYTE_LOOP
ASM_IMPORT_DUP_RESTORE_NEXT:
                        LDX             ASM_TMP1_LO
ASM_IMPORT_DUP_NEXT:
                        INX
                        BRA             ASM_IMPORT_DUP_LOOP
ASM_IMPORT_DUP_FOUND:
                        CLC
                        RTS
ASM_IMPORT_DUP_NOT_FOUND:
                        SEC
                        RTS

ASM_IMPORT_FIND_CURRENT:
                        LDX             #$00
ASM_IMPORT_FIND_LOOP:
                        CPX             ASM_IMPORT_COUNT
                        BCS             ASM_IMPORT_FIND_NONE
                        LDA             ASM_IMPORT_NAME_LEN,X
                        CMP             ASM_LEN
                        BNE             ASM_IMPORT_FIND_NEXT
                        STX             ASM_IMPORT_INDEX
                        JSR             ASM_IMPORT_SET_PACK_PTR_X
                        LDA             ASM_NAME_PTR_LO
                        STA             ASM_SYM_PTR_LO
                        LDA             ASM_NAME_PTR_HI
                        STA             ASM_SYM_PTR_HI
                        STZ             ASM_EXPORT_NAME_INDEX
                        STZ             ASM_IMPORT_PACK_INDEX
ASM_IMPORT_FIND_PACK_LOOP:
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_IMPORT_FIND_FOUND
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_FIND_NEXT_RESTORE
                        STA             ASM_P40_CODE0
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_FIND_NEXT_RESTORE
                        STA             ASM_P40_CODE1
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_IMPORT_FIND_NEXT_RESTORE
                        STA             ASM_P40_CODE2
                        LDA             ASM_P40_CODE0
                        LDX             ASM_P40_CODE1
                        LDY             ASM_P40_CODE2
                        JSR             ASM_PACK40_PACK3
                        BCC             ASM_IMPORT_FIND_NEXT_RESTORE
                        STY             ASM_TMP0_HI
                        LDY             ASM_IMPORT_PACK_INDEX
                        TXA
                        CMP             (ASM_EMIT_PTR_LO),Y
                        BNE             ASM_IMPORT_FIND_NEXT_RESTORE
                        INC             ASM_IMPORT_PACK_INDEX
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             ASM_TMP0_HI
                        CMP             (ASM_EMIT_PTR_LO),Y
                        BNE             ASM_IMPORT_FIND_NEXT_RESTORE
                        INC             ASM_IMPORT_PACK_INDEX
                        BRA             ASM_IMPORT_FIND_PACK_LOOP
ASM_IMPORT_FIND_FOUND:
                        LDX             ASM_IMPORT_INDEX
                        SEC
                        RTS
ASM_IMPORT_FIND_NEXT_RESTORE:
                        LDX             ASM_IMPORT_INDEX
ASM_IMPORT_FIND_NEXT:
                        INX
                        BRA             ASM_IMPORT_FIND_LOOP
ASM_IMPORT_FIND_NONE:
                        CLC
                        RTS

ASM_IMPORT_SET_PACK_PTR_X:
                        LDA             #<ASM_IMPORT_NAME_PACKS
                        STA             ASM_EMIT_PTR_LO
                        LDA             #>ASM_IMPORT_NAME_PACKS
                        STA             ASM_EMIT_PTR_HI
                        BRA             ASM_IMPORT_ADV_PACK_PTR_X

ASM_IMPORT_SET_PACK_SRC_X:
                        LDA             #<ASM_IMPORT_NAME_PACKS
                        STA             ASM_SYM_PTR_LO
                        LDA             #>ASM_IMPORT_NAME_PACKS
                        STA             ASM_SYM_PTR_HI
                        BRA             ASM_IMPORT_ADV_PACK_SRC_X

ASM_IMPORT_ADV_PACK_PTR_X:
                        CPX             #$00
                        BEQ             ASM_IMPORT_PACK_PTR_DONE
ASM_IMPORT_PACK_PTR_LOOP:
                        LDA             ASM_EMIT_PTR_LO
                        CLC
                        ADC             #ASM_EXPORT_NAME_PACK_MAX
                        STA             ASM_EMIT_PTR_LO
                        BCC             ASM_IMPORT_PACK_PTR_NEXT
                        INC             ASM_EMIT_PTR_HI
ASM_IMPORT_PACK_PTR_NEXT:
                        DEX
                        BNE             ASM_IMPORT_PACK_PTR_LOOP
ASM_IMPORT_PACK_PTR_DONE:
                        RTS

ASM_IMPORT_ADV_PACK_SRC_X:
                        CPX             #$00
                        BEQ             ASM_IMPORT_PACK_SRC_DONE
ASM_IMPORT_PACK_SRC_LOOP:
                        LDA             ASM_SYM_PTR_LO
                        CLC
                        ADC             #ASM_EXPORT_NAME_PACK_MAX
                        STA             ASM_SYM_PTR_LO
                        BCC             ASM_IMPORT_PACK_SRC_NEXT
                        INC             ASM_SYM_PTR_HI
ASM_IMPORT_PACK_SRC_NEXT:
                        DEX
                        BNE             ASM_IMPORT_PACK_SRC_LOOP
ASM_IMPORT_PACK_SRC_DONE:
                        RTS

ASM_IMPORT_CLEAR_PACK:
                        LDY             #$00
ASM_IMPORT_CLEAR_PACK_LOOP:
                        CPY             #ASM_EXPORT_NAME_PACK_MAX
                        BEQ             ASM_IMPORT_CLEAR_PACK_DONE
                        LDA             #$00
                        STA             (ASM_EMIT_PTR_LO),Y
                        INY
                        BRA             ASM_IMPORT_CLEAR_PACK_LOOP
ASM_IMPORT_CLEAR_PACK_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT_DB
; IN : X/Y = DB operand tail.
; OUT: C=1,A=OK when every item emitted. C=0,A=status on failure.
; NOTE: ASM 2.30 supports resolved byte/word atoms only. DB fixups are later.
; ----------------------------------------------------------------------------
ASM_EMIT_DB:
                        STX             ASM_DB_TAIL_LO
                        STY             ASM_DB_TAIL_HI
                        STZ             ASM_DB_COUNT
                        LDA             #$01
                        STA             ASM_DB_COUNTING
                        JSR             ASM_EMIT_DB_PASS
                        BCC             ASM_EMIT_DB_RETURN
                        LDA             ASM_DB_COUNT
                        JSR             ASM_EMIT_ROOM_FOR_A
                        BCS             ASM_EMIT_DB_ROOM_OK
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_ROOM_OK:
                        STZ             ASM_DB_COUNTING
                        LDX             ASM_DB_TAIL_LO
                        LDY             ASM_DB_TAIL_HI
ASM_EMIT_DB_PASS:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
ASM_EMIT_DB_ITEM:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DB_BAD_OPER
                        CMP             #$0D
                        BEQ             ASM_EMIT_DB_BAD_OPER
                        CMP             #$0A
                        BEQ             ASM_EMIT_DB_BAD_OPER
                        CMP             #';'
                        BEQ             ASM_EMIT_DB_BAD_OPER
                        CMP             #','
                        BEQ             ASM_EMIT_DB_BAD_OPER

                        STZ             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_EMIT_DB_HAVE_TOKEN
                        RTS
ASM_EMIT_DB_HAVE_TOKEN:
                        JSR             ASM_EMIT_DB_ATOM_FROM_TOKEN
                        BCC             ASM_EMIT_DB_RETURN
                        JSR             ASM_EMIT_DB_VALUE
                        BCC             ASM_EMIT_DB_RETURN
                        JSR             ASM_EMIT_DB_AFTER_ITEM
                        BCC             ASM_EMIT_DB_RETURN
                        LDA             ASM_TMP1_HI
                        BNE             ASM_EMIT_DB_ITEM
                        SEC
ASM_EMIT_DB_RETURN:
                        BCS             ASM_EMIT_DB_RETURN_DONE
                        STZ             ASM_DB_COUNTING
ASM_EMIT_DB_RETURN_DONE:
                        RTS

ASM_EMIT_DB_AFTER_ITEM:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DB_DONE
                        CMP             #$0D
                        BEQ             ASM_EMIT_DB_DONE
                        CMP             #$0A
                        BEQ             ASM_EMIT_DB_DONE
                        CMP             #';'
                        BEQ             ASM_EMIT_DB_DONE
                        CMP             #','
                        BEQ             ASM_EMIT_DB_COMMA
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_COMMA:
                        JSR             ASM_ADV_PARSE
                        LDA             #$01
                        STA             ASM_TMP1_HI
                        SEC
                        RTS
ASM_EMIT_DB_DONE:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        STZ             ASM_TMP1_HI
                        SEC
                        RTS

ASM_EMIT_DB_ATOM_FROM_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BEQ             ASM_EMIT_DB_ATOM_NUMBER
                        CMP             #ASM_TOK_CHAR
                        BEQ             ASM_EMIT_DB_ATOM_CHAR
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_EMIT_DB_ATOM_WORD
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_EMIT_DB_BAD_OPER
                        JMP             ASM_EMIT_DB_ATOM_PUNCT
ASM_EMIT_DB_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DB_FAIL_A

ASM_EMIT_DB_ATOM_NUMBER:
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_DEC
                        BEQ             ASM_EMIT_DB_ATOM_DEC
                        CMP             #ASM_TSUB_HEX
                        BEQ             ASM_EMIT_DB_ATOM_HEX
                        CMP             #ASM_TSUB_BIN
                        BEQ             ASM_EMIT_DB_ATOM_BIN
                        CMP             #ASM_TSUB_MASK
                        BEQ             ASM_EMIT_DB_ATOM_MASK
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_ATOM_DEC:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS
ASM_EMIT_DB_ATOM_HEX:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             ASM_LEN
                        CMP             #$04
                        BCS             ASM_EMIT_DB_ATOM_HEX_ABS
                        LDA             #ASM_WIDTH_ZP
                        BRA             ASM_EMIT_DB_ATOM_HEX_WIDTH
ASM_EMIT_DB_ATOM_HEX_ABS:
                        LDA             #ASM_WIDTH_ABS
ASM_EMIT_DB_ATOM_HEX_WIDTH:
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS
ASM_EMIT_DB_ATOM_BIN:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_EMIT_DB_ATOM_BIN_BYTE
                        LDA             #ASM_WIDTH_WORD
                        BRA             ASM_EMIT_DB_ATOM_BIN_WIDTH
ASM_EMIT_DB_ATOM_BIN_BYTE:
                        LDA             #ASM_WIDTH_BYTE
ASM_EMIT_DB_ATOM_BIN_WIDTH:
                        STA             ASM_WIDTH
                        SEC
                        RTS
ASM_EMIT_DB_ATOM_MASK:
                        LDA             #ASM_SYMK_MASK
                        STA             ASM_MODE
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_EMIT_DB_ATOM_MASK8
                        LDA             #ASM_WIDTH_MASK16
                        BRA             ASM_EMIT_DB_ATOM_MASK_WIDTH
ASM_EMIT_DB_ATOM_MASK8:
                        LDA             #ASM_WIDTH_MASK8
ASM_EMIT_DB_ATOM_MASK_WIDTH:
                        STA             ASM_WIDTH
                        SEC
                        RTS

ASM_EMIT_DB_ATOM_CHAR:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS

ASM_EMIT_DB_ATOM_WORD:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_EMIT_DB_ATOM_WORD_GLOBAL
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        BEQ             ASM_EMIT_DB_ATOM_WORD_BAD_SYM
                        LDA             ASM_LEN
                        CMP             #ASM_LOCAL_NAME_MAX
                        BCS             ASM_EMIT_DB_ATOM_WORD_BAD_SYM
                        LDA             #ASM_SYM_LOOK_LOCAL
                        BRA             ASM_EMIT_DB_ATOM_WORD_LOOK
ASM_EMIT_DB_ATOM_WORD_GLOBAL:
                        LDA             ASM_DB_COUNTING
                        BEQ             ASM_EMIT_DB_ATOM_WORD_MARK
                        LDA             #ASM_SYM_LOOK_SESSION
                        BRA             ASM_EMIT_DB_ATOM_WORD_LOOK
ASM_EMIT_DB_ATOM_WORD_MARK:
                        LDA             #(ASM_SYM_LOOK_SESSION|ASM_SYM_LOOK_MARK_USE)
ASM_EMIT_DB_ATOM_WORD_LOOK:
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_EMIT_DB_ATOM_WORD_OK
                        CMP             #ASM_STATUS_OK
                        BEQ             ASM_EMIT_DB_ATOM_WORD_UNRESOLVED
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_ATOM_WORD_UNRESOLVED:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_ATOM_WORD_OK:
                        SEC
                        RTS
ASM_EMIT_DB_ATOM_WORD_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        JMP             ASM_EMIT_DB_FAIL_A

ASM_EMIT_DB_ATOM_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #'*'
                        BEQ             ASM_EMIT_DB_ATOM_PC
                        CMP             #'<'
                        BEQ             ASM_EMIT_DB_ATOM_SEL_LO
                        CMP             #'>'
                        BEQ             ASM_EMIT_DB_ATOM_SEL_HI
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_ATOM_PC:
                        LDA             ASM_PC_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_PC_HI
                        STA             ASM_VALUE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS
ASM_EMIT_DB_ATOM_SEL_LO:
                        LDA             #ASM_FIX_SEL_LO
                        BRA             ASM_EMIT_DB_ATOM_SEL_A
ASM_EMIT_DB_ATOM_SEL_HI:
                        LDA             #ASM_FIX_SEL_HI
ASM_EMIT_DB_ATOM_SEL_A:
                        STA             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_EMIT_DB_ATOM_SEL_TOKEN
                        RTS
ASM_EMIT_DB_ATOM_SEL_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BEQ             ASM_EMIT_DB_ATOM_SEL_PUNCT
                        JMP             ASM_EMIT_DB_ATOM_FROM_TOKEN
ASM_EMIT_DB_ATOM_SEL_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #'*'
                        BEQ             ASM_EMIT_DB_ATOM_PC
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DB_FAIL_A

ASM_EMIT_DB_VALUE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BNE             ASM_EMIT_DB_VALUE_KIND_OK
                        JMP             ASM_EMIT_DB_BAD_WIDTH
ASM_EMIT_DB_VALUE_KIND_OK:
                        JSR             ASM_EMIT_DB_VALUE_LEN
                        BCC             ASM_EMIT_DB_VALUE_LEN_FAIL
                        LDA             ASM_DB_COUNTING
                        BEQ             ASM_EMIT_DB_VALUE_EMIT
                        LDA             ASM_DB_COUNT
                        CLC
                        ADC             ASM_TMP0_LO
                        STA             ASM_DB_COUNT
                        SEC
                        RTS
ASM_EMIT_DB_VALUE_LEN_FAIL:
                        RTS
ASM_EMIT_DB_VALUE_EMIT:
                        LDA             ASM_TMP1_LO
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_EMIT_DB_VALUE_LO
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_EMIT_DB_VALUE_HI
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_EMIT_DB_VALUE_WORD
                        CMP             #ASM_WIDTH_WORD
                        BEQ             ASM_EMIT_DB_VALUE_WORD
                        CMP             #ASM_WIDTH_MASK8
                        BEQ             ASM_EMIT_DB_BAD_WIDTH
                        CMP             #ASM_WIDTH_MASK16
                        BEQ             ASM_EMIT_DB_BAD_WIDTH
                        CMP             #ASM_WIDTH_NONE
                        BNE             ASM_EMIT_DB_VALUE_LO
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_EMIT_DB_VALUE_LO
                        BRA             ASM_EMIT_DB_VALUE_WORD
ASM_EMIT_DB_VALUE_LO:
                        LDA             ASM_VALUE_LO
                        JMP             ASM_EMIT_BYTE
ASM_EMIT_DB_VALUE_HI:
                        LDA             ASM_VALUE_HI
                        JMP             ASM_EMIT_BYTE
ASM_EMIT_DB_VALUE_WORD:
                        LDA             ASM_VALUE_LO
                        LDX             ASM_VALUE_HI
                        JMP             ASM_EMIT_WORD_LE
ASM_EMIT_DB_VALUE_LEN:
                        LDA             ASM_TMP1_LO
                        CMP             #ASM_FIX_SEL_LO
                        BEQ             ASM_EMIT_DB_VALUE_LEN_BYTE
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_EMIT_DB_VALUE_LEN_BYTE
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_EMIT_DB_VALUE_LEN_WORD
                        CMP             #ASM_WIDTH_WORD
                        BEQ             ASM_EMIT_DB_VALUE_LEN_WORD
                        CMP             #ASM_WIDTH_MASK8
                        BEQ             ASM_EMIT_DB_VALUE_LEN_BAD_WIDTH
                        CMP             #ASM_WIDTH_MASK16
                        BEQ             ASM_EMIT_DB_VALUE_LEN_BAD_WIDTH
                        CMP             #ASM_WIDTH_NONE
                        BNE             ASM_EMIT_DB_VALUE_LEN_BYTE
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_EMIT_DB_VALUE_LEN_BYTE
ASM_EMIT_DB_VALUE_LEN_WORD:
                        LDA             #$02
                        STA             ASM_TMP0_LO
                        SEC
                        RTS
ASM_EMIT_DB_VALUE_LEN_BYTE:
                        LDA             #$01
                        STA             ASM_TMP0_LO
                        SEC
                        RTS
ASM_EMIT_DB_VALUE_LEN_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        JMP             ASM_EMIT_DB_FAIL_A
ASM_EMIT_DB_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
ASM_EMIT_DB_FAIL_A:
                        STZ             ASM_DB_COUNTING
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT_DW
; IN : X/Y = DW expression-list tail.
; OUT: C=1,A=OK when every expression emitted as little-endian word.
;      C=0,A=status on failure.
; ----------------------------------------------------------------------------
ASM_EMIT_DW:
                        STX             ASM_DB_TAIL_LO
                        STY             ASM_DB_TAIL_HI
                        STZ             ASM_DB_COUNT
                        LDA             #$01
                        STA             ASM_DB_COUNTING
                        JSR             ASM_EMIT_DW_PASS
                        BCC             ASM_EMIT_DW_RETURN
                        LDA             ASM_DB_COUNT
                        JSR             ASM_EMIT_ROOM_FOR_A
                        BCS             ASM_EMIT_DW_ROOM_OK
                        JMP             ASM_EMIT_DW_FAIL_A
ASM_EMIT_DW_ROOM_OK:
                        STZ             ASM_DB_COUNTING
                        LDX             ASM_DB_TAIL_LO
                        LDY             ASM_DB_TAIL_HI
ASM_EMIT_DW_PASS:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
ASM_EMIT_DW_ITEM:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DW_BAD_OPER
                        CMP             #$0D
                        BEQ             ASM_EMIT_DW_BAD_OPER
                        CMP             #$0A
                        BEQ             ASM_EMIT_DW_BAD_OPER
                        CMP             #';'
                        BEQ             ASM_EMIT_DW_BAD_OPER
                        CMP             #','
                        BEQ             ASM_EMIT_DW_BAD_OPER

                        LDX             ASM_PARSE_PTR_LO
                        LDY             ASM_PARSE_PTR_HI
                        JSR             ASM_PARSE_EXPR
                        BCC             ASM_EMIT_DW_RETURN
                        JSR             ASM_EMIT_DW_VALUE
                        BCC             ASM_EMIT_DW_RETURN
                        JSR             ASM_EMIT_DW_AFTER_ITEM
                        BCC             ASM_EMIT_DW_RETURN
                        LDA             ASM_TMP1_HI
                        BNE             ASM_EMIT_DW_ITEM
                        SEC
ASM_EMIT_DW_RETURN:
                        BCS             ASM_EMIT_DW_RETURN_DONE
                        STZ             ASM_DB_COUNTING
ASM_EMIT_DW_RETURN_DONE:
                        RTS

ASM_EMIT_DW_AFTER_ITEM:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DW_DONE
                        CMP             #$0D
                        BEQ             ASM_EMIT_DW_DONE
                        CMP             #$0A
                        BEQ             ASM_EMIT_DW_DONE
                        CMP             #';'
                        BEQ             ASM_EMIT_DW_DONE
                        CMP             #','
                        BEQ             ASM_EMIT_DW_COMMA
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DW_FAIL_A
ASM_EMIT_DW_COMMA:
                        JSR             ASM_ADV_PARSE
                        LDA             #$01
                        STA             ASM_TMP1_HI
                        SEC
                        RTS
ASM_EMIT_DW_DONE:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        STZ             ASM_TMP1_HI
                        SEC
                        RTS

ASM_EMIT_DW_VALUE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_EMIT_DW_BAD_WIDTH
                        LDA             ASM_DB_COUNTING
                        BEQ             ASM_EMIT_DW_VALUE_EMIT
                        LDA             ASM_DB_COUNT
                        CLC
                        ADC             #$02
                        BCS             ASM_EMIT_DW_BAD_RANGE
                        STA             ASM_DB_COUNT
                        SEC
                        RTS
ASM_EMIT_DW_VALUE_EMIT:
                        LDA             ASM_VALUE_LO
                        LDX             ASM_VALUE_HI
                        JMP             ASM_EMIT_WORD_LE

ASM_EMIT_DW_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_EMIT_DW_FAIL_A
ASM_EMIT_DW_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        BRA             ASM_EMIT_DW_FAIL_A
ASM_EMIT_DW_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
ASM_EMIT_DW_FAIL_A:
                        STZ             ASM_DB_COUNTING
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EMIT_DS
; IN : X/Y = DS operand tail.
; OUT: C=1,A=OK when storage was reserved/filled. C=0,A=status on failure.
; NOTE: ASM 2.36 accepts an 8-bit count and optional byte initializer list.
; ----------------------------------------------------------------------------
ASM_EMIT_DS:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DS_COUNT_BAD_OPER
                        CMP             #$0D
                        BEQ             ASM_EMIT_DS_COUNT_BAD_OPER
                        CMP             #$0A
                        BEQ             ASM_EMIT_DS_COUNT_BAD_OPER
                        CMP             #';'
                        BEQ             ASM_EMIT_DS_COUNT_BAD_OPER
                        CMP             #','
                        BNE             ASM_EMIT_DS_COUNT_HAS_OPER
ASM_EMIT_DS_COUNT_BAD_OPER:
                        JMP             ASM_EMIT_DS_BAD_OPER
ASM_EMIT_DS_COUNT_HAS_OPER:

                        STZ             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_EMIT_DS_COUNT_TOKEN_OK
                        RTS
ASM_EMIT_DS_COUNT_TOKEN_OK:
                        JSR             ASM_EMIT_DB_ATOM_FROM_TOKEN
                        BCC             ASM_EMIT_DS_RETURN
                        JSR             ASM_EMIT_DS_STORE_COUNT
                        BCC             ASM_EMIT_DS_RETURN
                        JSR             ASM_EMIT_DS_PARSE_INIT
                        BCC             ASM_EMIT_DS_RETURN
; Plain DS emits filler today, but the bytes are not source-owned for sealing.
                        LDA             ASM_DS_INIT_FLAG
                        BNE             ASM_EMIT_DS_OWNED
                        LDA             ASM_DS_COUNT
                        BEQ             ASM_EMIT_DS_OWNED
                        JSR             ASM_SEAL_NOTE_UNOWNED
ASM_EMIT_DS_OWNED:
                        JSR             ASM_EMIT_DS_FILL_LOOP
ASM_EMIT_DS_RETURN:
                        RTS

ASM_EMIT_DS_STORE_COUNT:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_EMIT_DS_BAD_WIDTH_NEAR
ASM_EMIT_DS_COUNT_MODE_OK:
                        LDA             ASM_TMP1_LO
                        BNE             ASM_EMIT_DS_BAD_WIDTH_NEAR
ASM_EMIT_DS_COUNT_SELECTOR_OK:
                        LDA             ASM_VALUE_HI
                        BNE             ASM_EMIT_DS_BAD_RANGE_NEAR
ASM_EMIT_DS_COUNT_RANGE_OK:
                        LDA             ASM_VALUE_LO
                        STA             ASM_DS_COUNT
                        JSR             ASM_EMIT_ROOM_FOR_A
                        BCC             ASM_EMIT_DS_BAD_RANGE_NEAR
ASM_EMIT_DS_COUNT_ROOM_OK:
                        STZ             ASM_DS_FILL
                        STZ             ASM_DS_INIT_FLAG
                        STZ             ASM_DS_INIT_LEN
                        SEC
                        RTS
ASM_EMIT_DS_BAD_WIDTH_NEAR:
                        JMP             ASM_EMIT_DS_BAD_WIDTH
ASM_EMIT_DS_BAD_RANGE_NEAR:
                        JMP             ASM_EMIT_DS_BAD_RANGE

ASM_EMIT_DS_PARSE_INIT:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DS_INIT_DONE
                        CMP             #$0D
                        BEQ             ASM_EMIT_DS_INIT_DONE
                        CMP             #$0A
                        BEQ             ASM_EMIT_DS_INIT_DONE
                        CMP             #';'
                        BEQ             ASM_EMIT_DS_INIT_DONE
                        CMP             #','
                        BEQ             ASM_EMIT_DS_HAVE_INIT
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DS_FAIL_A
ASM_EMIT_DS_HAVE_INIT:
                        LDA             #$01
                        STA             ASM_DS_INIT_FLAG
                        LDA             ASM_PC_LO
                        STA             ASM_DS_INIT_START_LO
                        LDA             ASM_PC_HI
                        STA             ASM_DS_INIT_START_HI
ASM_EMIT_DS_INIT_ITEM:
                        JSR             ASM_ADV_PARSE
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DS_INIT_BAD_OPER
                        CMP             #$0D
                        BEQ             ASM_EMIT_DS_INIT_BAD_OPER
                        CMP             #$0A
                        BEQ             ASM_EMIT_DS_INIT_BAD_OPER
                        CMP             #';'
                        BEQ             ASM_EMIT_DS_INIT_BAD_OPER
                        CMP             #','
                        BNE             ASM_EMIT_DS_INIT_HAS_OPER
ASM_EMIT_DS_INIT_BAD_OPER:
                        JMP             ASM_EMIT_DS_BAD_OPER
ASM_EMIT_DS_INIT_HAS_OPER:
                        STZ             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_EMIT_DS_INIT_TOKEN_OK
                        RTS
ASM_EMIT_DS_INIT_TOKEN_OK:
                        JSR             ASM_EMIT_DB_ATOM_FROM_TOKEN
                        BCS             ASM_EMIT_DS_INIT_ATOM_OK
                        RTS
ASM_EMIT_DS_INIT_ATOM_OK:
                        JSR             ASM_EMIT_DS_INIT_VALUE
                        BCS             ASM_EMIT_DS_INIT_VALUE_OK
                        RTS
ASM_EMIT_DS_INIT_VALUE_OK:
                        JSR             ASM_EMIT_DS_AFTER_INIT_ITEM
                        BCS             ASM_EMIT_DS_AFTER_INIT_OK
                        RTS
ASM_EMIT_DS_AFTER_INIT_OK:
                        LDA             ASM_TMP1_HI
                        BNE             ASM_EMIT_DS_INIT_ITEM
ASM_EMIT_DS_INIT_DONE:
                        SEC
                        RTS

ASM_EMIT_DS_INIT_VALUE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_EMIT_DS_BAD_WIDTH_NEAR
ASM_EMIT_DS_INIT_MODE_OK:
                        LDA             ASM_DS_COUNT
                        BEQ             ASM_EMIT_DS_INIT_VALUE_DONE
                        LDA             ASM_VALUE_LO
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_DS_INIT_BYTE_OK
                        RTS
ASM_EMIT_DS_INIT_BYTE_OK:
                        DEC             ASM_DS_COUNT
                        INC             ASM_DS_INIT_LEN
ASM_EMIT_DS_INIT_VALUE_DONE:
                        SEC
                        RTS

ASM_EMIT_DS_AFTER_INIT_ITEM:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_EMIT_DS_INIT_END
                        CMP             #$0D
                        BEQ             ASM_EMIT_DS_INIT_END
                        CMP             #$0A
                        BEQ             ASM_EMIT_DS_INIT_END
                        CMP             #';'
                        BEQ             ASM_EMIT_DS_INIT_END
                        CMP             #','
                        BEQ             ASM_EMIT_DS_INIT_MORE
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_EMIT_DS_FAIL_A
ASM_EMIT_DS_INIT_MORE:
                        LDA             #$01
                        STA             ASM_TMP1_HI
                        SEC
                        RTS
ASM_EMIT_DS_INIT_END:
                        STZ             ASM_TMP1_HI
                        SEC
                        RTS

ASM_EMIT_DS_FILL_LOOP:
                        LDA             ASM_DS_COUNT
                        BEQ             ASM_EMIT_DS_OK
                        LDA             ASM_DS_INIT_FLAG
                        BNE             ASM_EMIT_DS_LIST_FILL_LOOP
ASM_EMIT_DS_FILL_NEXT:
                        LDA             ASM_DS_FILL
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_DS_FILL_BYTE_OK
                        RTS
ASM_EMIT_DS_FILL_BYTE_OK:
                        DEC             ASM_DS_COUNT
                        BNE             ASM_EMIT_DS_FILL_NEXT
                        BRA             ASM_EMIT_DS_OK
ASM_EMIT_DS_LIST_FILL_LOOP:
                        LDA             ASM_DS_INIT_LEN
                        BEQ             ASM_EMIT_DS_BAD_OPER
                        LDA             ASM_DS_INIT_START_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_DS_INIT_START_HI
                        STA             ASM_TMP1_HI
                        STZ             ASM_DS_COPY_INDEX
ASM_EMIT_DS_LIST_FILL_NEXT:
                        LDY             #$00
                        LDA             (ASM_TMP1_LO),Y
                        JSR             ASM_EMIT_BYTE
                        BCS             ASM_EMIT_DS_LIST_FILL_BYTE_OK
                        RTS
ASM_EMIT_DS_LIST_FILL_BYTE_OK:
                        DEC             ASM_DS_COUNT
                        BNE             ASM_EMIT_DS_LIST_MORE
                        JSR             ASM_EMIT_DS_MAYBE_WARN_WRAP
                        BRA             ASM_EMIT_DS_OK
ASM_EMIT_DS_LIST_MORE:
                        INC             ASM_TMP1_LO
                        BNE             ASM_EMIT_DS_LIST_COPY_LO_OK
                        INC             ASM_TMP1_HI
ASM_EMIT_DS_LIST_COPY_LO_OK:
                        INC             ASM_DS_COPY_INDEX
                        LDA             ASM_DS_COPY_INDEX
                        CMP             ASM_DS_INIT_LEN
                        BNE             ASM_EMIT_DS_LIST_FILL_NEXT
                        STZ             ASM_DS_COPY_INDEX
                        LDA             ASM_DS_INIT_START_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_DS_INIT_START_HI
                        STA             ASM_TMP1_HI
                        BRA             ASM_EMIT_DS_LIST_FILL_NEXT
ASM_EMIT_DS_MAYBE_WARN_WRAP:
                        LDA             ASM_DS_INIT_LEN
                        SEC
                        SBC             #$01
                        CMP             ASM_DS_COPY_INDEX
                        BEQ             ASM_EMIT_DS_MAYBE_WARN_DONE
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_WARN_DS_WRAP
                        STA             ASM_REPORT_FLAGS
ASM_EMIT_DS_MAYBE_WARN_DONE:
                        RTS
ASM_EMIT_DS_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS
ASM_EMIT_DS_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_EMIT_DS_FAIL_A
ASM_EMIT_DS_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        BRA             ASM_EMIT_DS_FAIL_A
ASM_EMIT_DS_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
ASM_EMIT_DS_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_PARSE_EXPR
; IN : X/Y = expression tail; must end at NUL, CR, LF, or semicolon.
; OUT: C=1,A=OK with ASM_VALUE/ASM_CARE/ASM_MODE/ASM_WIDTH set.
;      C=0,A=status on malformed or unsupported expression.
; NOTE: v1.80 resolved + and - only. No forward EQU chains or addend fixups.
; ----------------------------------------------------------------------------
ASM_PARSE_EXPR_FAIL_NEAR:
                        JMP             ASM_PARSE_EXPR_FAIL_A
ASM_PARSE_EXPR:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_PARSE_EXPR_FAIL_NEAR
ASM_PARSE_EXPR_HAVE_TOKEN:
                        JSR             ASM_PARSE_EXPR_ATOM
                        BCC             ASM_PARSE_EXPR_FAIL_NEAR

ASM_PARSE_EXPR_LOOP:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_PARSE_EXPR_DONE
                        CMP             #$0D
                        BEQ             ASM_PARSE_EXPR_DONE
                        CMP             #$0A
                        BEQ             ASM_PARSE_EXPR_DONE
                        CMP             #';'
                        BEQ             ASM_PARSE_EXPR_DONE
                        CMP             #','
                        BEQ             ASM_PARSE_EXPR_DONE
                        CMP             #'+'
                        BEQ             ASM_PARSE_EXPR_OPERATOR
                        CMP             #'-'
                        BEQ             ASM_PARSE_EXPR_OPERATOR
                        LDA             #ASM_STATUS_BAD_OPER
                        JMP             ASM_PARSE_EXPR_FAIL_A

ASM_PARSE_EXPR_OPERATOR:
                        STA             ASM_EXPR_OP
                        JSR             ASM_PARSE_EXPR_SAVE_LEFT
                        JSR             ASM_ADV_PARSE
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_PARSE_EXPR_FAIL_NEAR
ASM_PARSE_EXPR_HAVE_RHS:
                        JSR             ASM_PARSE_EXPR_ATOM
                        BCC             ASM_PARSE_EXPR_FAIL_NEAR
ASM_PARSE_EXPR_APPLY:
                        JSR             ASM_PARSE_EXPR_APPLY_OP
                        BCC             ASM_PARSE_EXPR_FAIL_NEAR
                        BRA             ASM_PARSE_EXPR_LOOP

ASM_PARSE_EXPR_DONE:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_VALUE_LO
                        LDY             ASM_VALUE_HI
                        SEC
                        RTS

ASM_PARSE_EXPR_ATOM:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BEQ             ASM_PARSE_EXPR_NUMBER
                        CMP             #ASM_TOK_CHAR
                        BEQ             ASM_PARSE_EXPR_CHAR
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_PARSE_EXPR_WORD
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_PARSE_EXPR_NOT_PUNCT
                        JMP             ASM_PARSE_EXPR_PUNCT
ASM_PARSE_EXPR_NOT_PUNCT:
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS

ASM_PARSE_EXPR_NUMBER:
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_DEC
                        BEQ             ASM_PARSE_EXPR_DEC
                        CMP             #ASM_TSUB_HEX
                        BEQ             ASM_PARSE_EXPR_HEX
                        CMP             #ASM_TSUB_BIN
                        BEQ             ASM_PARSE_EXPR_BIN
                        CMP             #ASM_TSUB_MASK
                        BEQ             ASM_PARSE_EXPR_MASK
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS

ASM_PARSE_EXPR_DEC:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        JMP             ASM_PARSE_EXPR_ATOM_DONE

ASM_PARSE_EXPR_HEX:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             ASM_LEN
                        CMP             #$04
                        BCS             ASM_PARSE_EXPR_HEX_ABS
                        LDA             #ASM_WIDTH_ZP
                        BRA             ASM_PARSE_EXPR_HEX_WIDTH
ASM_PARSE_EXPR_HEX_ABS:
                        LDA             #ASM_WIDTH_ABS
ASM_PARSE_EXPR_HEX_WIDTH:
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        JMP             ASM_PARSE_EXPR_ATOM_DONE

ASM_PARSE_EXPR_BIN:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_PARSE_EXPR_BIN_BYTE
                        LDA             #ASM_WIDTH_WORD
                        BRA             ASM_PARSE_EXPR_BIN_WIDTH
ASM_PARSE_EXPR_BIN_BYTE:
                        LDA             #ASM_WIDTH_BYTE
ASM_PARSE_EXPR_BIN_WIDTH:
                        STA             ASM_WIDTH
                        JMP             ASM_PARSE_EXPR_ATOM_DONE

ASM_PARSE_EXPR_MASK:
                        LDA             #ASM_SYMK_MASK
                        STA             ASM_MODE
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_PARSE_EXPR_MASK8
                        LDA             #ASM_WIDTH_MASK16
                        BRA             ASM_PARSE_EXPR_MASK_WIDTH
ASM_PARSE_EXPR_MASK8:
                        LDA             #ASM_WIDTH_MASK8
ASM_PARSE_EXPR_MASK_WIDTH:
                        STA             ASM_WIDTH
                        JMP             ASM_PARSE_EXPR_ATOM_DONE

ASM_PARSE_EXPR_CHAR:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        JMP             ASM_PARSE_EXPR_ATOM_DONE

ASM_PARSE_EXPR_WORD:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_PARSE_EXPR_WORD_GLOBAL
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        BNE             ASM_PARSE_EXPR_WORD_LOCAL_ACTIVE
                        JMP             ASM_PARSE_EXPR_BAD_SYM
ASM_PARSE_EXPR_WORD_LOCAL_ACTIVE:
                        LDA             ASM_LEN
                        CMP             #ASM_LOCAL_NAME_MAX
                        BCC             ASM_PARSE_EXPR_WORD_LOCAL_LEN_OK
                        JMP             ASM_PARSE_EXPR_BAD_SYM
ASM_PARSE_EXPR_WORD_LOCAL_LEN_OK:
                        LDA             #ASM_SYM_LOOK_LOCAL
                        BRA             ASM_PARSE_EXPR_WORD_LOOK
ASM_PARSE_EXPR_WORD_GLOBAL:
                        LDA             ASM_DB_COUNTING
                        BEQ             ASM_PARSE_EXPR_WORD_MARK
                        LDA             #ASM_SYM_LOOK_SESSION
                        BRA             ASM_PARSE_EXPR_WORD_LOOK
ASM_PARSE_EXPR_WORD_MARK:
                        LDA             #(ASM_SYM_LOOK_SESSION|ASM_SYM_LOOK_MARK_USE)
ASM_PARSE_EXPR_WORD_LOOK:
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_PARSE_EXPR_WORD_FOUND
                        CMP             #ASM_STATUS_OK
                        BNE             ASM_PARSE_EXPR_WORD_STATUS
                        JMP             ASM_PARSE_EXPR_BAD_SYM
ASM_PARSE_EXPR_WORD_STATUS:
                        CLC
                        RTS
ASM_PARSE_EXPR_WORD_FOUND:
                        SEC
                        RTS

ASM_PARSE_EXPR_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #'*'
                        BEQ             ASM_PARSE_EXPR_PC
                        JMP             ASM_PARSE_EXPR_BAD_OPER

ASM_PARSE_EXPR_PC:
                        LDA             ASM_PC_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_PC_HI
                        STA             ASM_VALUE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE

ASM_PARSE_EXPR_ATOM_DONE:
                        SEC
                        RTS

ASM_PARSE_EXPR_SAVE_LEFT:
                        LDA             ASM_VALUE_LO
                        STA             ASM_EXPR_LEFT_VAL_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_EXPR_LEFT_VAL_HI
                        LDA             ASM_CARE_LO
                        STA             ASM_EXPR_LEFT_CARE_LO
                        LDA             ASM_CARE_HI
                        STA             ASM_EXPR_LEFT_CARE_HI
                        LDA             ASM_MODE
                        STA             ASM_EXPR_LEFT_MODE
                        LDA             ASM_WIDTH
                        STA             ASM_EXPR_LEFT_WIDTH
                        RTS

ASM_PARSE_EXPR_APPLY_OP:
                        JSR             ASM_PARSE_EXPR_CHECK_LEFT_CONCRETE
                        BCS             ASM_PARSE_EXPR_APPLY_LEFT_OK
                        RTS
ASM_PARSE_EXPR_APPLY_LEFT_OK:
                        JSR             ASM_PARSE_EXPR_CHECK_RIGHT_CONCRETE
                        BCS             ASM_PARSE_EXPR_APPLY_RIGHT_OK
                        RTS
ASM_PARSE_EXPR_APPLY_RIGHT_OK:
                        LDA             ASM_EXPR_OP
                        CMP             #'+'
                        BEQ             ASM_PARSE_EXPR_APPLY_ADD
                        CMP             #'-'
                        BEQ             ASM_PARSE_EXPR_APPLY_SUB
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS

ASM_PARSE_EXPR_APPLY_ADD:
                        LDA             ASM_EXPR_LEFT_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_PARSE_EXPR_ADD_LEFT_ADDR
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_ADD_LEFT_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_ADD_LEFT_ADDR:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_ADD_ADDR_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_ADD_LEFT_VALUE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_PARSE_EXPR_ADD_VALUE_ADDR
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_ADD_VALUE_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_ADD_ADDR_VALUE:
                        LDA             ASM_EXPR_LEFT_WIDTH
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_ADD_SAVED
                        BCS             ASM_PARSE_EXPR_ADD_ADDR_RANGE
                        JMP             ASM_PARSE_EXPR_SET_ADDR_RESULT
ASM_PARSE_EXPR_ADD_ADDR_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PARSE_EXPR_ADD_VALUE_ADDR:
                        JSR             ASM_PARSE_EXPR_ADD_SAVED
                        BCS             ASM_PARSE_EXPR_ADD_VALUE_ADDR_RANGE
                        JMP             ASM_PARSE_EXPR_SET_ADDR_RESULT
ASM_PARSE_EXPR_ADD_VALUE_ADDR_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PARSE_EXPR_ADD_VALUE_VALUE:
                        JSR             ASM_PARSE_EXPR_ADD_SAVED
                        JMP             ASM_PARSE_EXPR_SET_VALUE_RESULT

ASM_PARSE_EXPR_APPLY_SUB:
                        LDA             ASM_EXPR_LEFT_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_PARSE_EXPR_SUB_LEFT_ADDR
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_SUB_LEFT_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_SUB_LEFT_ADDR:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_PARSE_EXPR_SUB_ADDR_ADDR
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_SUB_ADDR_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_SUB_LEFT_VALUE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_PARSE_EXPR_SUB_LEFT_VALUE_NOT_ADDR
                        JMP             ASM_PARSE_EXPR_BAD_WIDTH
ASM_PARSE_EXPR_SUB_LEFT_VALUE_NOT_ADDR:
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_PARSE_EXPR_SUB_VALUE_VALUE
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_SUB_ADDR_ADDR:
                        JSR             ASM_PARSE_EXPR_SUB_SAVED
                        BCS             ASM_PARSE_EXPR_SET_VALUE_RESULT
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PARSE_EXPR_SUB_ADDR_VALUE:
                        LDA             ASM_EXPR_LEFT_WIDTH
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SUB_SAVED
                        BCS             ASM_PARSE_EXPR_SET_ADDR_RESULT
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PARSE_EXPR_SUB_VALUE_VALUE:
                        JSR             ASM_PARSE_EXPR_SUB_SAVED
                        JMP             ASM_PARSE_EXPR_SET_VALUE_RESULT

ASM_PARSE_EXPR_ADD_SAVED:
                        CLC
                        LDA             ASM_EXPR_LEFT_VAL_LO
                        ADC             ASM_VALUE_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_EXPR_LEFT_VAL_HI
                        ADC             ASM_VALUE_HI
                        STA             ASM_VALUE_HI
                        RTS

ASM_PARSE_EXPR_SUB_SAVED:
                        SEC
                        LDA             ASM_EXPR_LEFT_VAL_LO
                        SBC             ASM_VALUE_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_EXPR_LEFT_VAL_HI
                        SBC             ASM_VALUE_HI
                        STA             ASM_VALUE_HI
                        RTS

ASM_PARSE_EXPR_SET_VALUE_RESULT:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS

ASM_PARSE_EXPR_SET_ADDR_RESULT:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        JSR             ASM_PARSE_EXPR_CHECK_ADDR_RESULT
                        BCS             ASM_PARSE_EXPR_SET_ADDR_OK
                        RTS
ASM_PARSE_EXPR_SET_ADDR_OK:
                        JSR             ASM_PARSE_EXPR_SET_FULL_CARE
                        SEC
                        RTS

ASM_PARSE_EXPR_CHECK_ADDR_RESULT:
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_PARSE_EXPR_CHECK_ADDR_ZP
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_PARSE_EXPR_CHECK_ADDR_OK
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_PARSE_EXPR_CHECK_ADDR_ZP:
                        LDA             ASM_VALUE_HI
                        BEQ             ASM_PARSE_EXPR_CHECK_ADDR_OK
                        LDA             #ASM_STATUS_BAD_RANGE
                        CLC
                        RTS
ASM_PARSE_EXPR_CHECK_ADDR_OK:
                        SEC
                        RTS

ASM_PARSE_EXPR_CHECK_LEFT_CONCRETE:
                        LDA             ASM_EXPR_LEFT_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_PARSE_EXPR_BAD_WIDTH
                        LDA             ASM_EXPR_LEFT_CARE_LO
                        CMP             #$FF
                        BNE             ASM_PARSE_EXPR_BAD_WIDTH
                        LDA             ASM_EXPR_LEFT_CARE_HI
                        CMP             #$FF
                        BNE             ASM_PARSE_EXPR_BAD_WIDTH
                        SEC
                        RTS

ASM_PARSE_EXPR_CHECK_RIGHT_CONCRETE:
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_PARSE_EXPR_BAD_WIDTH
                        LDA             ASM_CARE_LO
                        CMP             #$FF
                        BNE             ASM_PARSE_EXPR_BAD_WIDTH
                        LDA             ASM_CARE_HI
                        CMP             #$FF
                        BNE             ASM_PARSE_EXPR_BAD_WIDTH
                        SEC
                        RTS

ASM_PARSE_EXPR_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        BRA             ASM_PARSE_EXPR_FAIL_A
ASM_PARSE_EXPR_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        BRA             ASM_PARSE_EXPR_FAIL_A
ASM_PARSE_EXPR_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
ASM_PARSE_EXPR_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_TOKEN_PTR_LO
                        LDY             ASM_TOKEN_PTR_HI
                        CLC
                        RTS

ASM_PARSE_EXPR_SET_FULL_CARE:
                        LDA             #$FF
                        STA             ASM_CARE_LO
                        STA             ASM_CARE_HI
                        RTS

ASM_PARSE_EXPR_REQUIRE_END:
                        JSR             ASM_SKIP_SPACES
                        LDY             #$00
                        LDA             (ASM_PARSE_PTR_LO),Y
                        BEQ             ASM_PARSE_EXPR_REQUIRE_END_OK
                        CMP             #$0D
                        BEQ             ASM_PARSE_EXPR_REQUIRE_END_OK
                        CMP             #$0A
                        BEQ             ASM_PARSE_EXPR_REQUIRE_END_OK
                        CMP             #';'
                        BEQ             ASM_PARSE_EXPR_REQUIRE_END_OK
                        CLC
                        RTS
ASM_PARSE_EXPR_REQUIRE_END_OK:
                        SEC
                        RTS

ASM_SET_PC_FROM_VALUE:
                        JSR             ASM_SET_PC_IS_PRISTINE
                        BCC             ASM_SET_PC_NOT_INITIAL
                        LDA             ASM_REPORT_FLAGS
                        AND             #ASM_REPORTF_ORG_SEEN
                        BNE             ASM_SET_PC_NOT_INITIAL
                        LDA             #$01
                        BRA             ASM_SET_PC_HAVE_INITIAL
ASM_SET_PC_NOT_INITIAL:
                        LDA             #$00
ASM_SET_PC_HAVE_INITIAL:
                        STA             ASM_TMP0_LO
                        BNE             ASM_SET_PC_APPLY
                        LDA             ASM_VALUE_HI
                        CMP             ASM_PC_HI
                        BCC             ASM_SET_PC_BACKWARD
                        BNE             ASM_SET_PC_APPLY
                        LDA             ASM_VALUE_LO
                        CMP             ASM_PC_LO
                        BCC             ASM_SET_PC_BACKWARD
ASM_SET_PC_APPLY:
                        LDA             ASM_VALUE_HI
                        CMP             #ASM_TARGET_LIMIT_HI
                        BCC             ASM_SET_PC_TARGET_OK
                        LDA             #ASM_STATUS_BAD_RANGE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS
ASM_SET_PC_TARGET_OK:
                        LDA             ASM_VALUE_LO
                        LDX             ASM_VALUE_HI
                        JSR             ASM_TARGET_ADDR_OK
                        BCS             ASM_SET_PC_TARGET_SAFE
                        LDA             #ASM_STATUS_BAD_RANGE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS
ASM_SET_PC_TARGET_SAFE:
                        LDA             ASM_TMP0_LO
                        BNE             ASM_SET_PC_NO_HOLE
                        LDA             ASM_VALUE_HI
                        CMP             ASM_PC_HI
                        BNE             ASM_SET_PC_MARK_HOLE
                        LDA             ASM_VALUE_LO
                        CMP             ASM_PC_LO
                        BEQ             ASM_SET_PC_NO_HOLE
ASM_SET_PC_MARK_HOLE:
                        JSR             ASM_SEAL_NOTE_HOLE
ASM_SET_PC_NO_HOLE:
                        LDA             ASM_VALUE_LO
                        STA             ASM_PC_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_PC_HI
                        LDA             ASM_TMP0_LO
                        BNE             ASM_SET_PC_APPLY_INITIAL
                        JSR             ASM_UPDATE_HIGH_PC
                        BRA             ASM_SET_PC_MARK_ORG
ASM_SET_PC_APPLY_INITIAL:
                        LDA             ASM_PC_LO
                        STA             ASM_START_PC_LO
                        STA             ASM_HIGH_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_START_PC_HI
                        STA             ASM_HIGH_PC_HI
ASM_SET_PC_MARK_ORG:
                        LDA             ASM_REPORT_FLAGS
                        ORA             #ASM_REPORTF_ORG_SEEN
                        STA             ASM_REPORT_FLAGS
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS
ASM_SET_PC_BACKWARD:
                        LDA             #ASM_STATUS_BAD_RANGE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

ASM_SET_PC_IS_PRISTINE:
                        LDA             ASM_PC_LO
                        CMP             ASM_START_PC_LO
                        BNE             ASM_SET_PC_NOT_PRISTINE
                        LDA             ASM_PC_HI
                        CMP             ASM_START_PC_HI
                        BNE             ASM_SET_PC_NOT_PRISTINE
                        LDA             ASM_HIGH_PC_LO
                        CMP             ASM_START_PC_LO
                        BNE             ASM_SET_PC_NOT_PRISTINE
                        LDA             ASM_HIGH_PC_HI
                        CMP             ASM_START_PC_HI
                        BNE             ASM_SET_PC_NOT_PRISTINE
                        SEC
                        RTS
ASM_SET_PC_NOT_PRISTINE:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_CLASS_OPERAND
; IN : ASM_STMT_OP_ID = mnemonic id, X/Y = operand tail pointer.
; OUT: C=1,A=OK with ASM_MODE=operand mode, ASM_WIDTH=operand width,
;      ASM_VALUE=resolved value or $FFFF placeholder, ASM_FLAGS bit0=unresolved.
;      C=0,A=status for unsupported or malformed operand shape.
; NOTE: v1.90 foothold: no emission and no fixup records yet.
; ----------------------------------------------------------------------------
ASM_CLASS_OPERAND:
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        STZ             ASM_TMP1_HI
                        STZ             ASM_FIX_PLAN_SEL
                        STZ             ASM_RELOC_PLAN_TARGET_LO
                        STZ             ASM_RELOC_PLAN_TARGET_HI
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_HAVE_TOKEN
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_HAVE_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_EOL
                        BEQ             ASM_CLASS_NONE
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_CLASS_NOT_IMMEDIATE
                        LDA             ASM_TOK_SUB
                        CMP             #'#'
                        BEQ             ASM_CLASS_IMMEDIATE
                        CMP             #'('
                        BEQ             ASM_CLASS_INDIRECT

ASM_CLASS_NOT_IMMEDIATE:
                        JSR             ASM_CLASS_LOAD_ATOM
                        BCS             ASM_CLASS_HAVE_ATOM
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_HAVE_ATOM:
                        JSR             ASM_IS_BRANCH_OP
                        BCS             ASM_CLASS_HAVE_BRANCH
                        JSR             ASM_IS_BIT_ZP_OP
                        BCC             ASM_CLASS_NOT_BIT_ZP
                        JMP             ASM_CLASS_BIT_ZP
ASM_CLASS_NOT_BIT_ZP:
                        JMP             ASM_CLASS_DIRECT
ASM_CLASS_HAVE_BRANCH:
                        JMP             ASM_CLASS_BRANCH

ASM_CLASS_NONE:
                        STZ             ASM_BASE_LO
                        STZ             ASM_BASE_HI
                        STZ             ASM_TMP1_HI
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_NONE
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_IMMEDIATE:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_IMM_HAVE_ATOM_TOKEN
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_IMM_HAVE_ATOM_TOKEN:
                        JSR             ASM_CLASS_LOAD_ATOM
                        BCS             ASM_CLASS_IMM_ATOM_OK
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_IMM_ATOM_OK:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_IMM_END_OK
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_IMM_END_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BNE             ASM_CLASS_IMM_NOT_REG
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_IMM_NOT_REG:
                        CMP             #ASM_SYMK_MASK
                        BNE             ASM_CLASS_IMM_NOT_MASK
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_IMM_NOT_MASK:
                        LDA             ASM_TMP1_HI
                        AND             #ASM_OPF_UNRESOLVED
                        BNE             ASM_CLASS_IMM_WIDTH_OK
                        LDA             ASM_BASE_HI
                        BEQ             ASM_CLASS_IMM_WIDTH_OK
                        JMP             ASM_CLASS_BAD_RANGE
ASM_CLASS_IMM_WIDTH_OK:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_IMM8
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_INDIRECT:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_INDIRECT_HAVE_ATOM
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_HAVE_ATOM:
                        JSR             ASM_CLASS_LOAD_ATOM
                        BCS             ASM_CLASS_INDIRECT_ATOM_OK
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_ATOM_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BNE             ASM_CLASS_INDIRECT_NOT_REG
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_INDIRECT_NOT_REG:
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_CLASS_INDIRECT_ADDR_OK
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_INDIRECT_ADDR_OK:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_INDIRECT_HAVE_SUFFIX
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_HAVE_SUFFIX:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BEQ             ASM_CLASS_INDIRECT_SUFFIX_PUNCT
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_SUFFIX_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #')'
                        BEQ             ASM_CLASS_INDIRECT_CLOSE
                        CMP             #','
                        BEQ             ASM_CLASS_INDIRECT_INNER_COMMA
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_INNER_COMMA:
                        JSR             ASM_CLASS_INDIRECT_PARSE_REG
                        BCS             ASM_CLASS_INDIRECT_INNER_REG_OK
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_INNER_REG_OK:
                        LDA             ASM_TMP1_LO
                        CMP             #ASM_VID_REG_X
                        BEQ             ASM_CLASS_INDIRECT_INNER_X
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_INDIRECT_INNER_X:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_INDIRECT_INNER_HAVE_CLOSE
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_INNER_HAVE_CLOSE:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_CLASS_INDIRECT_BAD_OPER_JMP
                        LDA             ASM_TOK_SUB
                        CMP             #')'
                        BEQ             ASM_CLASS_INDIRECT_INNER_CLOSE_OK
ASM_CLASS_INDIRECT_BAD_OPER_JMP:
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_INNER_CLOSE_OK:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_INDIRECT_X_WIDTH
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_X_WIDTH:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BNE             ASM_CLASS_INDIRECT_X_NOT_ZP
                        JMP             ASM_CLASS_INDIRECT_ZP_X
ASM_CLASS_INDIRECT_X_NOT_ZP:
                        CMP             #ASM_WIDTH_ABS
                        BNE             ASM_CLASS_INDIRECT_X_BAD_WIDTH
                        JMP             ASM_CLASS_INDIRECT_ABS_X
ASM_CLASS_INDIRECT_X_BAD_WIDTH:
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_INDIRECT_CLOSE:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_INDIRECT_AFTER_CLOSE
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_AFTER_CLOSE:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_EOL
                        BEQ             ASM_CLASS_INDIRECT_NO_INDEX
                        CMP             #ASM_TOK_PUNCT
                        BEQ             ASM_CLASS_INDIRECT_OUTER_PUNCT
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_OUTER_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #','
                        BEQ             ASM_CLASS_INDIRECT_OUTER_COMMA
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_OUTER_COMMA:
                        JSR             ASM_CLASS_INDIRECT_PARSE_REG
                        BCS             ASM_CLASS_INDIRECT_OUTER_REG_OK
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_OUTER_REG_OK:
                        LDA             ASM_TMP1_LO
                        CMP             #ASM_VID_REG_Y
                        BEQ             ASM_CLASS_INDIRECT_OUTER_Y
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_INDIRECT_OUTER_Y:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_INDIRECT_Y_WIDTH
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_INDIRECT_Y_WIDTH:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_INDIRECT_ZP_Y
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_INDIRECT_NO_INDEX:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_INDIRECT_ZP
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_CLASS_INDIRECT_ABS
                        JMP             ASM_CLASS_BAD_WIDTH

ASM_CLASS_INDIRECT_PARSE_REG:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_INDIRECT_PARSE_REG_TOKEN
                        RTS
ASM_CLASS_INDIRECT_PARSE_REG_TOKEN:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_CLASS_INDIRECT_PARSE_REG_WORD
                        LDA             #ASM_STATUS_BAD_MODE
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_PARSE_REG_WORD:
                        JSR             ASM_LOOKUP_WORD
                        BCS             ASM_CLASS_INDIRECT_PARSE_REG_LOOKUP
                        LDA             #ASM_STATUS_BAD_MODE
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_PARSE_REG_LOOKUP:
                        CPY             #ASM_VOC_REG
                        BEQ             ASM_CLASS_INDIRECT_PARSE_REG_OK
                        LDA             #ASM_STATUS_BAD_MODE
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_INDIRECT_PARSE_REG_OK:
                        LDA             ASM_VOC_ID
                        STA             ASM_TMP1_LO
                        SEC
                        RTS

ASM_CLASS_INDIRECT_ZP:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP_IND
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_INDIRECT_ZP_X:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP_X_IND
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_INDIRECT_ZP_Y:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP_IND_Y
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_INDIRECT_ABS:
                        LDA             #ASM_WIDTH_WORD
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ABS_IND
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_INDIRECT_ABS_X:
                        LDA             #ASM_WIDTH_WORD
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ABS_X_IND
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_BRANCH:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_BRANCH_END_OK
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_BRANCH_END_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BNE             ASM_CLASS_BRANCH_NOT_REG
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_BRANCH_NOT_REG:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_REL8
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_BIT_ZP:
                        LDA             ASM_TMP1_HI
                        AND             #ASM_OPF_UNRESOLVED
                        BEQ             ASM_CLASS_BIT_ZP_RESOLVED
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_BIT_ZP_RESOLVED:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BEQ             ASM_CLASS_BIT_ZP_BAD_MODE
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_CLASS_BIT_ZP_BAD_WIDTH
                        CMP             #ASM_SYMK_VALUE
                        BEQ             ASM_CLASS_BIT_ZP_KIND_OK
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_CLASS_BIT_ZP_KIND_OK
ASM_CLASS_BIT_ZP_BAD_WIDTH:
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_BIT_ZP_BAD_MODE:
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_BIT_ZP_KIND_OK:
                        LDA             ASM_BASE_HI
                        BEQ             ASM_CLASS_BIT_ZP_HI_OK
                        JMP             ASM_CLASS_BAD_RANGE
ASM_CLASS_BIT_ZP_HI_OK:
                        LDA             ASM_BASE_LO
                        CMP             #$08
                        BCC             ASM_CLASS_BIT_ZP_RANGE_OK
                        JMP             ASM_CLASS_BAD_RANGE
ASM_CLASS_BIT_ZP_RANGE_OK:
                        STA             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_BIT_ZP_HAVE_COMMA
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_HAVE_COMMA:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_CLASS_BIT_ZP_BAD_OPER
                        LDA             ASM_TOK_SUB
                        CMP             #','
                        BEQ             ASM_CLASS_BIT_ZP_COMMA_OK
ASM_CLASS_BIT_ZP_BAD_OPER:
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_BIT_ZP_COMMA_OK:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_BIT_ZP_HAVE_ADDR
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_HAVE_ADDR:
                        JSR             ASM_CLASS_LOAD_ATOM
                        BCS             ASM_CLASS_BIT_ZP_ADDR_OK
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_ADDR_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_CLASS_BIT_ZP_ADDR_KIND_OK
                        CMP             #ASM_ATOM_REG
                        BEQ             ASM_CLASS_BIT_ZP_BAD_MODE
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_BIT_ZP_ADDR_KIND_OK:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_BIT_ZP_ADDR_WIDTH_OK
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_BIT_ZP_ADDR_WIDTH_OK:
                        JSR             ASM_IS_BIT_ZP_REL_OP
                        BCC             ASM_CLASS_BIT_ZP_REQUIRE_END
                        JMP             ASM_CLASS_BIT_ZP_REL
ASM_CLASS_BIT_ZP_REQUIRE_END:
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_BIT_ZP_END_OK
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_BIT_ZP_END_OK:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_BIT_ZP
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_BIT_ZP_REL:
                        LDA             ASM_TMP1_HI
                        AND             #ASM_OPF_UNRESOLVED
                        BEQ             ASM_CLASS_BIT_ZP_REL_ZP_RESOLVED
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_BIT_ZP_REL_ZP_RESOLVED:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_BIT_ZP_REL_HAVE_COMMA
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_REL_HAVE_COMMA:
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_CLASS_BIT_ZP_REL_BAD_OPER
                        LDA             ASM_TOK_SUB
                        CMP             #','
                        BEQ             ASM_CLASS_BIT_ZP_REL_COMMA_OK
ASM_CLASS_BIT_ZP_REL_BAD_OPER:
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_BIT_ZP_REL_COMMA_OK:
                        JSR             ASM_NEXT_TOKEN
                        BCS             ASM_CLASS_BIT_ZP_REL_HAVE_TARGET
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_REL_HAVE_TARGET:
                        LDA             ASM_BASE_LO
                        PHA
                        JSR             ASM_CLASS_LOAD_ATOM
                        BCS             ASM_CLASS_BIT_ZP_REL_TARGET_OK
                        STA             ASM_TMP0_HI
                        PLA
                        LDA             ASM_TMP0_HI
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_BIT_ZP_REL_TARGET_OK:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BEQ             ASM_CLASS_BIT_ZP_REL_BAD_MODE_POP
                        CMP             #ASM_SYMK_MASK
                        BEQ             ASM_CLASS_BIT_ZP_REL_BAD_WIDTH_POP
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_BIT_ZP_REL_END_OK
                        PLA
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_BIT_ZP_REL_END_OK:
                        PLA
                        STA             ASM_CARE_LO
                        STZ             ASM_CARE_HI
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_BIT_ZP_REL
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_BIT_ZP_REL_BAD_MODE_POP:
                        PLA
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_BIT_ZP_REL_BAD_WIDTH_POP:
                        PLA
                        JMP             ASM_CLASS_BAD_WIDTH

ASM_CLASS_DIRECT:
                        JSR             ASM_CLASS_PARSE_OPTIONAL_INDEX
                        BCS             ASM_CLASS_DIRECT_HAVE_SUFFIX
                        JMP             ASM_CLASS_FAIL_A
ASM_CLASS_DIRECT_HAVE_SUFFIX:
                        LDA             ASM_TMP0_LO
                        CMP             #ASM_ATOM_REG
                        BEQ             ASM_CLASS_REG_OPERAND
                        CMP             #ASM_SYMK_ADDR
                        BEQ             ASM_CLASS_ADDR_OPERAND
                        JMP             ASM_CLASS_BAD_WIDTH

ASM_CLASS_REG_OPERAND:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_VID_REG_A
                        BEQ             ASM_CLASS_REG_IS_A
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_REG_IS_A:
                        JSR             ASM_CLASS_ACC_ALLOWED
                        BCS             ASM_CLASS_REG_ACC_ALLOWED
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_REG_ACC_ALLOWED:
                        LDA             ASM_TMP1_LO
                        BEQ             ASM_CLASS_REG_NO_INDEX
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_REG_NO_INDEX:
                        STZ             ASM_BASE_LO
                        STZ             ASM_BASE_HI
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ACC
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_ADDR_OPERAND:
                        LDA             ASM_TMP1_LO
                        BEQ             ASM_CLASS_ADDR_NO_INDEX
                        CMP             #ASM_VID_REG_X
                        BEQ             ASM_CLASS_ADDR_INDEX_X
                        CMP             #ASM_VID_REG_Y
                        BEQ             ASM_CLASS_ADDR_INDEX_Y
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_ADDR_INDEX_X:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_ADDR_ZP_X
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_CLASS_ADDR_ABS_X
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_ADDR_ABS_X:
                        LDA             #ASM_WIDTH_WORD
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ABS_X
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_ADDR_ZP_X:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP_X
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_ADDR_INDEX_Y:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_ADDR_ZP_Y
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_CLASS_ADDR_ABS_Y
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_ADDR_ABS_Y:
                        LDA             #ASM_WIDTH_WORD
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ABS_Y
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_ADDR_ZP_Y:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP_Y
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_ADDR_NO_INDEX:
                        LDA             ASM_TMP0_HI
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_ADDR_ZP
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_CLASS_ADDR_ABS
                        JMP             ASM_CLASS_BAD_WIDTH
ASM_CLASS_ADDR_ABS:
                        LDA             #ASM_WIDTH_WORD
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ABS16
                        JMP             ASM_CLASS_OK_A
ASM_CLASS_ADDR_ZP:
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_WIDTH
                        LDA             #ASM_OPM_ZP8
                        JMP             ASM_CLASS_OK_A

ASM_CLASS_PARSE_OPTIONAL_INDEX:
                        STZ             ASM_TMP1_LO
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_CLASS_PARSE_SUFFIX_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_EOL
                        BEQ             ASM_CLASS_PARSE_SUFFIX_OK
                        CMP             #ASM_TOK_PUNCT
                        BEQ             ASM_CLASS_PARSE_SUFFIX_PUNCT
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_PARSE_SUFFIX_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #','
                        BEQ             ASM_CLASS_PARSE_SUFFIX_COMMA
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_PARSE_SUFFIX_COMMA:
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_CLASS_PARSE_SUFFIX_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_CLASS_PARSE_SUFFIX_WORD
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_PARSE_SUFFIX_WORD:
                        JSR             ASM_LOOKUP_WORD
                        BCS             ASM_CLASS_PARSE_SUFFIX_LOOKUP
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_PARSE_SUFFIX_LOOKUP:
                        CPY             #ASM_VOC_REG
                        BEQ             ASM_CLASS_PARSE_SUFFIX_REG
                        JMP             ASM_CLASS_BAD_MODE
ASM_CLASS_PARSE_SUFFIX_REG:
                        LDA             ASM_VOC_ID
                        STA             ASM_TMP1_LO
                        JSR             ASM_PARSE_EXPR_REQUIRE_END
                        BCS             ASM_CLASS_PARSE_SUFFIX_OK
                        JMP             ASM_CLASS_BAD_OPER
ASM_CLASS_PARSE_SUFFIX_OK:
                        SEC
                        RTS
ASM_CLASS_PARSE_SUFFIX_FAIL:
                        RTS

ASM_CLASS_LOAD_ATOM:
                        STZ             ASM_TMP1_HI
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_NUMBER
                        BEQ             ASM_CLASS_LOAD_NUMBER
                        CMP             #ASM_TOK_CHAR
                        BEQ             ASM_CLASS_LOAD_CHAR
                        CMP             #ASM_TOK_WORD
                        BNE             ASM_CLASS_LOAD_NOT_WORD
                        JMP             ASM_CLASS_LOAD_WORD
ASM_CLASS_LOAD_NOT_WORD:
                        CMP             #ASM_TOK_PUNCT
                        BNE             ASM_CLASS_LOAD_NOT_PUNCT
                        JMP             ASM_CLASS_LOAD_PUNCT
ASM_CLASS_LOAD_NOT_PUNCT:
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS

ASM_CLASS_LOAD_NUMBER:
                        LDA             ASM_VALUE_LO
                        STA             ASM_BASE_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_BASE_HI
                        LDA             ASM_TOK_SUB
                        CMP             #ASM_TSUB_DEC
                        BEQ             ASM_CLASS_LOAD_DEC
                        CMP             #ASM_TSUB_HEX
                        BEQ             ASM_CLASS_LOAD_HEX
                        CMP             #ASM_TSUB_BIN
                        BEQ             ASM_CLASS_LOAD_BIN
                        CMP             #ASM_TSUB_MASK
                        BEQ             ASM_CLASS_LOAD_MASK
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_CLASS_LOAD_DEC:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_NONE
                        STA             ASM_TMP0_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_HEX:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_TMP0_LO
                        LDA             ASM_LEN
                        CMP             #$04
                        BNE             ASM_CLASS_LOAD_HEX_NOT_BAD_WIDTH
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS
ASM_CLASS_LOAD_HEX_NOT_BAD_WIDTH:
                        BCS             ASM_CLASS_LOAD_HEX_ABS
                        LDA             #ASM_WIDTH_ZP
                        BRA             ASM_CLASS_LOAD_HEX_WIDTH
ASM_CLASS_LOAD_HEX_ABS:
                        LDA             #ASM_WIDTH_ABS
ASM_CLASS_LOAD_HEX_WIDTH:
                        STA             ASM_TMP0_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_BIN:
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_TMP0_LO
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_CLASS_LOAD_BIN_BYTE
                        LDA             #ASM_WIDTH_WORD
                        BRA             ASM_CLASS_LOAD_BIN_WIDTH
ASM_CLASS_LOAD_BIN_BYTE:
                        LDA             #ASM_WIDTH_BYTE
ASM_CLASS_LOAD_BIN_WIDTH:
                        STA             ASM_TMP0_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_MASK:
                        LDA             #ASM_SYMK_MASK
                        STA             ASM_TMP0_LO
                        LDA             ASM_BIT
                        CMP             #$08
                        BEQ             ASM_CLASS_LOAD_MASK8
                        LDA             #ASM_WIDTH_MASK16
                        BRA             ASM_CLASS_LOAD_MASK_WIDTH
ASM_CLASS_LOAD_MASK8:
                        LDA             #ASM_WIDTH_MASK8
ASM_CLASS_LOAD_MASK_WIDTH:
                        STA             ASM_TMP0_HI
                        SEC
                        RTS

ASM_CLASS_LOAD_CHAR:
                        LDA             ASM_VALUE_LO
                        STA             ASM_BASE_LO
                        STZ             ASM_BASE_HI
                        LDA             #ASM_SYMK_VALUE
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_BYTE
                        STA             ASM_TMP0_HI
                        SEC
                        RTS

ASM_CLASS_LOAD_WORD:
                        JSR             ASM_LOOKUP_WORD
                        BCC             ASM_CLASS_LOAD_SYMBOL
                        CPY             #ASM_VOC_REG
                        BNE             ASM_CLASS_LOAD_SYMBOL
                        LDA             #ASM_ATOM_REG
                        STA             ASM_TMP0_LO
                        LDA             ASM_VOC_ID
                        STA             ASM_TMP0_HI
                        STZ             ASM_BASE_LO
                        STZ             ASM_BASE_HI
                        SEC
                        RTS

ASM_CLASS_LOAD_SYMBOL:
                        LDA             ASM_TOKEN_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_TOKEN_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_CLASS_LOAD_GLOBAL_SYMBOL
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        BEQ             ASM_CLASS_LOAD_SYMBOL_BAD_SYM
                        LDA             ASM_LEN
                        CMP             #ASM_LOCAL_NAME_MAX
                        BCS             ASM_CLASS_LOAD_SYMBOL_BAD_SYM
                        LDA             #(ASM_SYM_LOOK_LOCAL|ASM_SYM_LOOK_MARK_USE)
                        BRA             ASM_CLASS_LOAD_SYMBOL_LOOK
ASM_CLASS_LOAD_GLOBAL_SYMBOL:
                        LDA             #(ASM_SYM_LOOK_SESSION|ASM_SYM_LOOK_MARK_USE)
ASM_CLASS_LOAD_SYMBOL_LOOK:
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_CLASS_LOAD_SYMBOL_FOUND
                        CMP             #ASM_STATUS_OK
                        BEQ             ASM_CLASS_LOAD_SYMBOL_MISS
                        CLC
                        RTS
ASM_CLASS_LOAD_SYMBOL_MISS:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_CLASS_LOAD_SYMBOL_MISS_GLOBAL
                        JMP             ASM_CLASS_LOAD_UNRESOLVED
ASM_CLASS_LOAD_SYMBOL_MISS_GLOBAL:
                        JSR             ASM_IMPORT_FIND_CURRENT
                        BCC             ASM_CLASS_LOAD_SYMBOL_NOT_IMPORT
                        LDA             ASM_FIX_PLAN_SEL
                        ORA             #ASM_FIXF_IMPORT
                        STA             ASM_FIX_PLAN_SEL
                        JMP             ASM_CLASS_LOAD_UNRESOLVED
ASM_CLASS_LOAD_SYMBOL_NOT_IMPORT:
                        JSR             ASM_CLASS_LOAD_RESIDENT_EXEC
                        BCS             ASM_CLASS_LOAD_SYMBOL_RESIDENT
                        JMP             ASM_CLASS_LOAD_UNRESOLVED
ASM_CLASS_LOAD_SYMBOL_RESIDENT:
                        SEC
                        RTS
ASM_CLASS_LOAD_SYMBOL_FOUND:
                        LDA             ASM_VALUE_LO
                        STA             ASM_BASE_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_BASE_HI
                        LDA             ASM_MODE
                        STA             ASM_TMP0_LO
                        JSR             ASM_CLASS_MARK_RELOC_IF_LABEL
                        LDA             ASM_WIDTH
                        CMP             #ASM_WIDTH_ZP
                        BEQ             ASM_CLASS_LOAD_SYMBOL_WIDTH_OK
                        CMP             #ASM_WIDTH_ABS
                        BEQ             ASM_CLASS_LOAD_SYMBOL_WIDTH_OK
                        LDA             ASM_MODE
                        CMP             #ASM_SYMK_ADDR
                        BNE             ASM_CLASS_LOAD_SYMBOL_KEEP_WIDTH
                        LDA             #ASM_WIDTH_ABS
ASM_CLASS_LOAD_SYMBOL_WIDTH_OK:
                        STA             ASM_TMP0_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_SYMBOL_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        CLC
                        RTS
ASM_CLASS_LOAD_SYMBOL_KEEP_WIDTH:
                        LDA             ASM_WIDTH
                        STA             ASM_TMP0_HI
                        SEC
                        RTS

ASM_CLASS_MARK_RELOC_IF_LABEL:
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BNE             ASM_CLASS_MARK_RELOC_YES
                        LDA             ASM_SYM_FLAGS,X
                        AND             #ASM_SYMF_FROM_LABEL
                        BEQ             ASM_CLASS_MARK_RELOC_DONE
ASM_CLASS_MARK_RELOC_YES:
                        LDA             ASM_TMP1_HI
                        ORA             #ASM_OPF_RELOC_INTERNAL
                        STA             ASM_TMP1_HI
                        LDA             ASM_BASE_LO
                        STA             ASM_RELOC_PLAN_TARGET_LO
                        LDA             ASM_BASE_HI
                        STA             ASM_RELOC_PLAN_TARGET_HI
ASM_CLASS_MARK_RELOC_DONE:
                        RTS

ASM_CLASS_LOAD_RESIDENT_EXEC:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_JSR
                        BEQ             ASM_CLASS_LOAD_RESIDENT_CALL
                        CMP             #ASM_VID_JMP
                        BNE             ASM_CLASS_LOAD_RESIDENT_NO
ASM_CLASS_LOAD_RESIDENT_CALL:
                        LDX             #<ASM_HASH0
                        LDY             #>ASM_HASH0
                        JSR             ASM_RJ_RESIDENT_XY
                        BCC             ASM_CLASS_LOAD_RESIDENT_NO
                        STX             ASM_BASE_LO
                        STY             ASM_BASE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_TMP0_HI
                        STZ             ASM_TMP1_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_RESIDENT_NO:
                        CLC
                        RTS

ASM_CLASS_LOAD_UNRESOLVED:
                        JSR             ASM_CAPTURE_FIX_PLAN_CURRENT
                        LDA             #$FF
                        STA             ASM_BASE_LO
                        STA             ASM_BASE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_TMP0_HI
                        LDA             #ASM_OPF_UNRESOLVED
                        STA             ASM_TMP1_HI
                        SEC
                        RTS

ASM_CAPTURE_FIX_PLAN_CURRENT:
                        LDA             ASM_NAME_PTR_LO
                        STA             ASM_FIX_PLAN_NAME_PTR_LO
                        LDA             ASM_NAME_PTR_HI
                        STA             ASM_FIX_PLAN_NAME_PTR_HI
                        LDA             ASM_LEN
                        STA             ASM_FIX_PLAN_NAME_LEN
                        LDA             ASM_HASH0
                        STA             ASM_FIX_PLAN_HASH0
                        LDA             ASM_HASH1
                        STA             ASM_FIX_PLAN_HASH1
                        LDA             ASM_HASH2
                        STA             ASM_FIX_PLAN_HASH2
                        LDA             ASM_HASH3
                        STA             ASM_FIX_PLAN_HASH3
                        LDA             ASM_TOK_FLAGS
                        AND             #ASM_TF_LOCAL_PREFIX
                        BEQ             ASM_CAPTURE_FIX_PLAN_GLOBAL
                        LDA             ASM_FIX_PLAN_SEL
                        ORA             #ASM_FIXF_LOCAL
                        STA             ASM_FIX_PLAN_SEL
ASM_CAPTURE_FIX_PLAN_GLOBAL:
                        RTS

ASM_LOAD_FIX_PLAN_CURRENT:
                        LDA             ASM_FIX_PLAN_NAME_PTR_LO
                        STA             ASM_NAME_PTR_LO
                        LDA             ASM_FIX_PLAN_NAME_PTR_HI
                        STA             ASM_NAME_PTR_HI
                        LDA             ASM_FIX_PLAN_NAME_LEN
                        STA             ASM_LEN
                        LDA             ASM_FIX_PLAN_HASH0
                        STA             ASM_HASH0
                        LDA             ASM_FIX_PLAN_HASH1
                        STA             ASM_HASH1
                        LDA             ASM_FIX_PLAN_HASH2
                        STA             ASM_HASH2
                        LDA             ASM_FIX_PLAN_HASH3
                        STA             ASM_HASH3
                        RTS

ASM_CLASS_LOAD_PUNCT:
                        LDA             ASM_TOK_SUB
                        CMP             #'*'
                        BEQ             ASM_CLASS_LOAD_PC
                        CMP             #'<'
                        BEQ             ASM_CLASS_LOAD_SEL_LO
                        CMP             #'>'
                        BEQ             ASM_CLASS_LOAD_SEL_HI
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_CLASS_LOAD_PC:
                        LDA             ASM_PC_LO
                        STA             ASM_BASE_LO
                        LDA             ASM_PC_HI
                        STA             ASM_BASE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_TMP0_HI
                        SEC
                        RTS

ASM_CLASS_LOAD_SEL_LO:
                        LDA             #ASM_FIX_SEL_LO
                        BRA             ASM_CLASS_LOAD_SEL_A
ASM_CLASS_LOAD_SEL_HI:
                        LDA             #ASM_FIX_SEL_HI
ASM_CLASS_LOAD_SEL_A:
                        STA             ASM_FIX_PLAN_SEL
                        JSR             ASM_NEXT_TOKEN
                        BCC             ASM_CLASS_LOAD_SEL_FAIL
                        LDA             ASM_TOK_KIND
                        CMP             #ASM_TOK_WORD
                        BEQ             ASM_CLASS_LOAD_SEL_WORD
                        LDA             #ASM_STATUS_BAD_OPER
                        CLC
                        RTS
ASM_CLASS_LOAD_SEL_WORD:
                        JSR             ASM_CLASS_LOAD_SYMBOL
                        BCS             ASM_CLASS_LOAD_SEL_SYMBOL_OK
ASM_CLASS_LOAD_SEL_FAIL:
                        RTS
ASM_CLASS_LOAD_SEL_SYMBOL_OK:
                        LDA             ASM_TMP1_HI
                        AND             #ASM_OPF_UNRESOLVED
                        BNE             ASM_CLASS_LOAD_SEL_UNRESOLVED
                        LDA             ASM_FIX_PLAN_SEL
                        CMP             #ASM_FIX_SEL_HI
                        BEQ             ASM_CLASS_LOAD_SEL_RESOLVED_HI
                        STZ             ASM_BASE_HI
                        BRA             ASM_CLASS_LOAD_SEL_RESOLVED
ASM_CLASS_LOAD_SEL_RESOLVED_HI:
                        LDA             ASM_BASE_HI
                        STA             ASM_BASE_LO
                        STZ             ASM_BASE_HI
ASM_CLASS_LOAD_SEL_RESOLVED:
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_TMP0_LO
                        LDA             #ASM_WIDTH_ZP
                        STA             ASM_TMP0_HI
                        SEC
                        RTS
ASM_CLASS_LOAD_SEL_UNRESOLVED:
                        LDA             #ASM_WIDTH_ZP
                        STA             ASM_TMP0_HI
                        SEC
                        RTS

ASM_CLASS_LOAD_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        CLC
                        RTS

ASM_IS_BRANCH_OP:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_BCC
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BCS
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BEQ
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BMI
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BNE
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BPL
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BRA
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BVC
                        BEQ             ASM_IS_BRANCH_YES
                        CMP             #ASM_VID_BVS
                        BEQ             ASM_IS_BRANCH_YES
                        CLC
                        RTS
ASM_IS_BRANCH_YES:
                        SEC
                        RTS

ASM_IS_BIT_ZP_OP:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_BBR
                        BEQ             ASM_IS_BIT_ZP_YES
                        CMP             #ASM_VID_BBS
                        BEQ             ASM_IS_BIT_ZP_YES
                        CMP             #ASM_VID_RMB
                        BEQ             ASM_IS_BIT_ZP_YES
                        CMP             #ASM_VID_SMB
                        BEQ             ASM_IS_BIT_ZP_YES
                        CLC
                        RTS
ASM_IS_BIT_ZP_YES:
                        SEC
                        RTS

ASM_IS_BIT_ZP_REL_OP:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_BBR
                        BEQ             ASM_IS_BIT_ZP_REL_YES
                        CMP             #ASM_VID_BBS
                        BEQ             ASM_IS_BIT_ZP_REL_YES
                        CLC
                        RTS
ASM_IS_BIT_ZP_REL_YES:
                        SEC
                        RTS

ASM_CLASS_ACC_ALLOWED:
                        LDA             ASM_STMT_OP_ID
                        CMP             #ASM_VID_ASL
                        BEQ             ASM_CLASS_ACC_YES
                        CMP             #ASM_VID_LSR
                        BEQ             ASM_CLASS_ACC_YES
                        CMP             #ASM_VID_ROL
                        BEQ             ASM_CLASS_ACC_YES
                        CMP             #ASM_VID_ROR
                        BEQ             ASM_CLASS_ACC_YES
                        CMP             #ASM_VID_INC
                        BEQ             ASM_CLASS_ACC_YES
                        CMP             #ASM_VID_DEC
                        BEQ             ASM_CLASS_ACC_YES
                        CLC
                        RTS
ASM_CLASS_ACC_YES:
                        SEC
                        RTS

ASM_CLASS_BAD_OPER:
                        LDA             #ASM_STATUS_BAD_OPER
                        BRA             ASM_CLASS_FAIL_A
ASM_CLASS_BAD_MODE:
                        LDA             #ASM_STATUS_BAD_MODE
                        BRA             ASM_CLASS_FAIL_A
ASM_CLASS_BAD_WIDTH:
                        LDA             #ASM_STATUS_BAD_WIDTH
                        BRA             ASM_CLASS_FAIL_A
ASM_CLASS_BAD_RANGE:
                        LDA             #ASM_STATUS_BAD_RANGE

ASM_CLASS_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_TOKEN_PTR_LO
                        LDY             ASM_TOKEN_PTR_HI
                        CLC
                        RTS

ASM_CLASS_OK_A:
                        STA             ASM_MODE
                        LDA             ASM_BASE_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_BASE_HI
                        STA             ASM_VALUE_HI
                        LDA             ASM_TMP1_HI
                        STA             ASM_FLAGS
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_VALUE_LO
                        LDY             ASM_VALUE_HI
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
;      C=0,A=BAD_FIX when mark-use would overflow the report reference budget.
; ----------------------------------------------------------------------------
ASM_LOOKUP_SYMBOL:
                        STA             ASM_FLAGS
                        AND             #ASM_SYM_LOOK_LOCAL
                        BEQ             ASM_LOOKUP_SYMBOL_NOT_LOCAL
                        JMP             ASM_LOOKUP_LOCAL_SYMBOL
ASM_LOOKUP_SYMBOL_NOT_LOCAL:
                        LDA             ASM_FLAGS
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
                        JSR             ASM_REPORT_NOTE_REF
                        BCS             ASM_LOOKUP_SYMBOL_MARK_REF_OK
                        LDX             ASM_SLOT
                        LDY             #$00
                        CLC
                        RTS
ASM_LOOKUP_SYMBOL_MARK_REF_OK:
                        LDX             ASM_SLOT
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

ASM_LOOKUP_LOCAL_SYMBOL:
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        BEQ             ASM_LOOKUP_LOCAL_NONE
                        LDX             #$00
ASM_LOOKUP_LOCAL_LOOP:
                        CPX             ASM_LOCAL_COUNT
                        BEQ             ASM_LOOKUP_LOCAL_NONE
                        LDA             ASM_HASH0
                        CMP             ASM_LOCAL_HASH0,X
                        BNE             ASM_LOOKUP_LOCAL_NEXT
                        LDA             ASM_HASH1
                        CMP             ASM_LOCAL_HASH1,X
                        BNE             ASM_LOOKUP_LOCAL_NEXT
                        LDA             ASM_HASH2
                        CMP             ASM_LOCAL_HASH2,X
                        BNE             ASM_LOOKUP_LOCAL_NEXT
                        LDA             ASM_HASH3
                        CMP             ASM_LOCAL_HASH3,X
                        BNE             ASM_LOOKUP_LOCAL_NEXT
                        LDA             ASM_LEN
                        CMP             ASM_LOCAL_NAME_LEN,X
                        BNE             ASM_LOOKUP_LOCAL_NEXT
                        JSR             ASM_LOCAL_TEXT_MATCH_X
                        BCC             ASM_LOOKUP_LOCAL_NEXT
                        STX             ASM_SLOT
                        LDA             ASM_LOCAL_VAL_LO,X
                        STA             ASM_VALUE_LO
                        LDA             ASM_LOCAL_VAL_HI,X
                        STA             ASM_VALUE_HI
                        LDA             #$FF
                        STA             ASM_CARE_LO
                        STA             ASM_CARE_HI
                        LDA             #ASM_SYMK_ADDR
                        STA             ASM_MODE
                        LDA             #ASM_WIDTH_ABS
                        STA             ASM_WIDTH
                        LDY             #$01
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        SEC
                        RTS
ASM_LOOKUP_LOCAL_NEXT:
                        INX
                        BRA             ASM_LOOKUP_LOCAL_LOOP
ASM_LOOKUP_LOCAL_NONE:
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
                        BCS             ASM_BIND_LABEL_NAME_OK
                        JMP             ASM_BIND_LABEL_BAD
ASM_BIND_LABEL_NAME_OK:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_LOCAL_NAME
                        BEQ             ASM_BIND_GLOBAL_LABEL
                        JMP             ASM_BIND_LOCAL_LABEL
ASM_BIND_GLOBAL_LABEL:
                        JSR             ASM_CLOSE_LOCAL_SCOPE
                        BCS             ASM_BIND_GLOBAL_SCOPE_OK
                        BRA             ASM_BIND_LABEL_FAIL_A
ASM_BIND_GLOBAL_SCOPE_OK:
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
                        LDA             ASM_LINE_COUNT_LO
                        STA             ASM_SYM_DEFLINE_LO,X
                        LDA             ASM_LINE_COUNT_HI
                        STA             ASM_SYM_DEFLINE_HI,X
                        STZ             ASM_SYM_USECNT,X
                        STZ             ASM_SYM_FIRSTREF_LO,X
                        STZ             ASM_SYM_FIRSTREF_HI,X
                        INC             ASM_SYM_COUNT
                        LDA             ASM_PC_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_PC_HI
                        STA             ASM_VALUE_HI
                        LDA             #ASM_OPF_RELOC_INTERNAL
                        STA             ASM_RELOC_RESOLVE_FLAGS
                        PHX
                        PHY
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT
                        BCS             ASM_BIND_LABEL_RESOLVED_OK
                        STA             ASM_TMP0_LO
                        PLY
                        PLX
                        LDA             ASM_TMP0_LO
                        BRA             ASM_BIND_LABEL_FAIL_A
ASM_BIND_LABEL_RESOLVED_OK:
                        PLY
                        PLX
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDY             ASM_PC_HI
                        SEC
                        RTS
ASM_BIND_LABEL_BAD:
                        LDA             #ASM_STATUS_BAD_SYM
ASM_BIND_LABEL_FAIL_A:
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        CLC
                        RTS

ASM_BIND_LOCAL_LABEL:
                        LDA             ASM_LOCAL_SCOPE_ACTIVE
                        BEQ             ASM_BIND_LOCAL_BAD_SYM
                        LDA             ASM_LEN
                        CMP             #ASM_LOCAL_NAME_MAX
                        BCS             ASM_BIND_LOCAL_BAD_SYM
                        LDA             #ASM_SYM_LOOK_LOCAL
                        JSR             ASM_LOOKUP_SYMBOL
                        BCS             ASM_BIND_LOCAL_BAD_SYM
                        LDX             ASM_LOCAL_COUNT
                        CPX             #ASM_LOCAL_MAX
                        BCS             ASM_BIND_LOCAL_BAD_SYM
                        STX             ASM_SLOT
                        JSR             ASM_STORE_LOCAL_NAME_X
                        LDA             ASM_PC_LO
                        STA             ASM_LOCAL_VAL_LO,X
                        STA             ASM_VALUE_LO
                        LDA             ASM_PC_HI
                        STA             ASM_LOCAL_VAL_HI,X
                        STA             ASM_VALUE_HI
                        INC             ASM_LOCAL_COUNT
                        LDA             #ASM_OPF_RELOC_INTERNAL
                        STA             ASM_RELOC_RESOLVE_FLAGS
                        PHX
                        PHY
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT
                        BCS             ASM_BIND_LOCAL_RESOLVED_OK
                        STA             ASM_TMP0_LO
                        PLY
                        PLX
                        LDA             ASM_TMP0_LO
                        BRA             ASM_BIND_LABEL_FAIL_A
ASM_BIND_LOCAL_RESOLVED_OK:
                        PLY
                        PLX
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDY             ASM_PC_HI
                        SEC
                        RTS
ASM_BIND_LOCAL_BAD_SYM:
                        LDA             #ASM_STATUS_BAD_SYM
                        BRA             ASM_BIND_LABEL_FAIL_A

ASM_CLOSE_LOCAL_SCOPE:
                        JSR             ASM_FIX_HAS_PENDING_LOCAL
                        BCC             ASM_CLOSE_LOCAL_SCOPE_OK
                        LDA             #ASM_STATUS_BAD_FIX
                        CLC
                        RTS
ASM_CLOSE_LOCAL_SCOPE_OK:
                        STZ             ASM_LOCAL_COUNT
                        LDA             #$01
                        STA             ASM_LOCAL_SCOPE_ACTIVE
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_DEFINE_EQU
; Define the current statement name from resolved ASM_VALUE/CARE/MODE/WIDTH.
; ----------------------------------------------------------------------------
ASM_DEFINE_EQU:
                        JSR             ASM_LOAD_NAME_FROM_STMT
                        BCS             ASM_DEFINE_EQU_NAME_OK
                        JMP             ASM_DEFINE_EQU_BAD_SYM
ASM_DEFINE_EQU_NAME_OK:
                        LDA             ASM_STMT_FLAGS
                        AND             #ASM_STMTF_LOCAL_NAME
                        BEQ             ASM_DEFINE_EQU_NOT_LOCAL
                        JMP             ASM_DEFINE_EQU_BAD_SYM
ASM_DEFINE_EQU_NOT_LOCAL:
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
                        LDA             ASM_LINE_COUNT_LO
                        STA             ASM_SYM_DEFLINE_LO,X
                        LDA             ASM_LINE_COUNT_HI
                        STA             ASM_SYM_DEFLINE_HI,X
                        STZ             ASM_SYM_USECNT,X
                        STZ             ASM_SYM_FIRSTREF_LO,X
                        STZ             ASM_SYM_FIRSTREF_HI,X
                        INC             ASM_SYM_COUNT
                        STZ             ASM_RELOC_RESOLVE_FLAGS
                        PHX
                        PHY
                        JSR             ASM_RESOLVE_FIXUPS_CURRENT
                        BCS             ASM_DEFINE_EQU_RESOLVED_OK
                        STA             ASM_TMP0_LO
                        PLY
                        PLX
                        LDA             ASM_TMP0_LO
                        BRA             ASM_DEFINE_EQU_FAIL_A
ASM_DEFINE_EQU_RESOLVED_OK:
                        PLY
                        PLX
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

ASM_STORE_LOCAL_NAME_X:
                        LDA             ASM_HASH0
                        STA             ASM_LOCAL_HASH0,X
                        LDA             ASM_HASH1
                        STA             ASM_LOCAL_HASH1,X
                        LDA             ASM_HASH2
                        STA             ASM_LOCAL_HASH2,X
                        LDA             ASM_HASH3
                        STA             ASM_LOCAL_HASH3,X
                        LDA             ASM_LEN
                        STA             ASM_LOCAL_NAME_LEN,X
                        JSR             ASM_SET_LOCAL_NAME_PTR_X
                        LDY             #$00
ASM_STORE_LOCAL_NAME_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_STORE_LOCAL_NAME_TERM
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        STA             (ASM_SYM_PTR_LO),Y
                        INY
                        BRA             ASM_STORE_LOCAL_NAME_LOOP
ASM_STORE_LOCAL_NAME_TERM:
                        LDA             #$00
                        STA             (ASM_SYM_PTR_LO),Y
                        RTS

ASM_LOCAL_TEXT_MATCH_X:
                        JSR             ASM_SET_LOCAL_NAME_PTR_X
                        LDY             #$00
ASM_LOCAL_TEXT_MATCH_LOOP:
                        CPY             ASM_LEN
                        BEQ             ASM_LOCAL_TEXT_MATCH_YES
                        LDA             (ASM_NAME_PTR_LO),Y
                        AND             #$7F
                        JSR             ASM_FOLD_UPPER_A
                        CMP             (ASM_SYM_PTR_LO),Y
                        BNE             ASM_LOCAL_TEXT_MATCH_NO
                        INY
                        BRA             ASM_LOCAL_TEXT_MATCH_LOOP
ASM_LOCAL_TEXT_MATCH_YES:
                        SEC
                        RTS
ASM_LOCAL_TEXT_MATCH_NO:
                        CLC
                        RTS

ASM_SET_LOCAL_NAME_PTR_X:
                        TXA
                        ASL
                        ASL
                        ASL
                        ASL
                        CLC
                        ADC             #<ASM_LOCAL_NAMES
                        STA             ASM_SYM_PTR_LO
                        LDA             #>ASM_LOCAL_NAMES
                        ADC             #$00
                        STA             ASM_SYM_PTR_HI
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
                        JMP             (ASM_RJ_HEX_NIB_LO)

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
                        JMP             (ASM_RJ_FNV_INIT_LO)

ASM_FNV1A_UPDATE_A_FAST:
                        JMP             (ASM_RJ_FNV_UPDATE_LO)

; ----------------------------------------------------------------------------
; ROUTINE: ASM_EXPORT_BUILD_RECORD
; Build the compact sealed export record from live EXPORT symbol slots.
; Record shape:
;   +0 count
;   +1 total record length in bytes, including count/len header
;   +2 rows: offset_lo offset_hi name_len pack40_name_bytes...
; ----------------------------------------------------------------------------
ASM_EXPORT_BUILD_RECORD:
                        LDA             ASM_EXPORT_COUNT
                        STA             ASM_EXPORT_REC_COUNT
                        LDA             #ASM_EXPORT_REC_OFF_BODY
                        STA             ASM_EXPORT_REC_LEN
                        LDA             #<ASM_EXPORT_REC_BODY
                        STA             ASM_EMIT_PTR_LO
                        LDA             #>ASM_EXPORT_REC_BODY
                        STA             ASM_EMIT_PTR_HI
                        LDX             #$00
ASM_EXPORT_BUILD_LOOP:
                        CPX             ASM_EXPORT_COUNT
                        BEQ             ASM_EXPORT_BUILD_DONE
                        STX             ASM_EXPORT_INDEX
                        LDA             ASM_EXPORT_SYM_SLOT,X
                        TAX
                        STX             ASM_SLOT
                        LDA             ASM_SYM_VAL_LO,X
                        SEC
                        SBC             ASM_SEAL_BASE_LO
                        STA             ASM_TMP0_LO
                        LDA             ASM_SYM_VAL_HI,X
                        SBC             ASM_SEAL_BASE_HI
                        STA             ASM_TMP0_HI
                        LDA             ASM_TMP0_LO
                        JSR             ASM_EXPORT_REC_WRITE_A
                        LDA             ASM_TMP0_HI
                        JSR             ASM_EXPORT_REC_WRITE_A
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_NAME_LEN,X
                        JSR             ASM_EXPORT_REC_WRITE_A
                        LDX             ASM_SLOT
                        JSR             ASM_EXPORT_PACK_NAME_X
                        LDX             ASM_EXPORT_INDEX
                        INX
                        BRA             ASM_EXPORT_BUILD_LOOP
ASM_EXPORT_BUILD_DONE:
                        RTS

ASM_EXPORT_REC_WRITE_A:
                        LDY             #$00
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_EMIT_PTR_LO
                        BNE             ASM_EXPORT_REC_WRITE_LEN
                        INC             ASM_EMIT_PTR_HI
ASM_EXPORT_REC_WRITE_LEN:
                        INC             ASM_EXPORT_REC_LEN
                        RTS

ASM_EXPORT_PACK_NAME_X:
                        STX             ASM_SLOT
                        JSR             ASM_SET_SYM_NAME_PTR_X
                        LDX             ASM_SLOT
                        LDA             ASM_SYM_NAME_LEN,X
                        STA             ASM_LEN
                        STZ             ASM_EXPORT_NAME_INDEX
ASM_EXPORT_PACK_NAME_LOOP:
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCS             ASM_EXPORT_PACK_NAME_DONE
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_EXPORT_PACK_NAME_DONE
                        STA             ASM_P40_CODE0
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_EXPORT_PACK_NAME_DONE
                        STA             ASM_P40_CODE1
                        JSR             ASM_PACK40_READ_CODE
                        BCC             ASM_EXPORT_PACK_NAME_DONE
                        STA             ASM_P40_CODE2
                        LDA             ASM_P40_CODE0
                        LDX             ASM_P40_CODE1
                        LDY             ASM_P40_CODE2
                        JSR             ASM_PACK40_PACK3
                        STY             ASM_TMP0_HI
                        TXA
                        JSR             ASM_EXPORT_REC_WRITE_A
                        LDA             ASM_TMP0_HI
                        JSR             ASM_EXPORT_REC_WRITE_A
                        BRA             ASM_EXPORT_PACK_NAME_LOOP
ASM_EXPORT_PACK_NAME_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_IMPORT_BUILD_RECORD
; Build the compact sealed import record from live IMPORT names.
; Record shape:
;   +0 count
;   +1 total record length in bytes, including count/len header
;   +2 rows: name_len pack40_name_bytes...
; ----------------------------------------------------------------------------
ASM_IMPORT_BUILD_RECORD:
                        LDA             ASM_IMPORT_COUNT
                        STA             ASM_IMPORT_REC_COUNT
                        LDA             #ASM_IMPORT_REC_OFF_BODY
                        STA             ASM_IMPORT_REC_LEN
                        LDA             #<ASM_IMPORT_REC_BODY
                        STA             ASM_EMIT_PTR_LO
                        LDA             #>ASM_IMPORT_REC_BODY
                        STA             ASM_EMIT_PTR_HI
                        LDX             #$00
ASM_IMPORT_BUILD_LOOP:
                        CPX             ASM_IMPORT_COUNT
                        BEQ             ASM_IMPORT_BUILD_DONE
                        STX             ASM_IMPORT_INDEX
                        LDA             ASM_IMPORT_NAME_LEN,X
                        JSR             ASM_IMPORT_REC_WRITE_A
                        LDX             ASM_IMPORT_INDEX
                        JSR             ASM_IMPORT_SET_PACK_SRC_X
                        STZ             ASM_EXPORT_NAME_INDEX
                        STZ             ASM_IMPORT_PACK_INDEX
ASM_IMPORT_BUILD_COPY_LOOP:
                        LDX             ASM_IMPORT_INDEX
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_IMPORT_NAME_LEN,X
                        BCS             ASM_IMPORT_BUILD_NEXT
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             (ASM_SYM_PTR_LO),Y
                        JSR             ASM_IMPORT_REC_WRITE_A
                        INC             ASM_IMPORT_PACK_INDEX
                        LDY             ASM_IMPORT_PACK_INDEX
                        LDA             (ASM_SYM_PTR_LO),Y
                        JSR             ASM_IMPORT_REC_WRITE_A
                        INC             ASM_IMPORT_PACK_INDEX
                        LDA             ASM_EXPORT_NAME_INDEX
                        CLC
                        ADC             #$03
                        STA             ASM_EXPORT_NAME_INDEX
                        BRA             ASM_IMPORT_BUILD_COPY_LOOP
ASM_IMPORT_BUILD_NEXT:
                        LDX             ASM_IMPORT_INDEX
                        INX
                        BRA             ASM_IMPORT_BUILD_LOOP
ASM_IMPORT_BUILD_DONE:
                        RTS

ASM_IMPORT_REC_WRITE_A:
                        LDY             #$00
                        STA             (ASM_EMIT_PTR_LO),Y
                        INC             ASM_EMIT_PTR_LO
                        BNE             ASM_IMPORT_REC_WRITE_LEN
                        INC             ASM_EMIT_PTR_HI
ASM_IMPORT_REC_WRITE_LEN:
                        INC             ASM_IMPORT_REC_LEN
                        RTS

ASM_PACK40_READ_CODE:
                        LDA             ASM_EXPORT_NAME_INDEX
                        CMP             ASM_LEN
                        BCC             ASM_PACK40_READ_HAVE_CHAR
                        LDA             #$00
                        SEC
                        RTS
ASM_PACK40_READ_HAVE_CHAR:
                        TAY
                        LDA             (ASM_SYM_PTR_LO),Y
                        INC             ASM_EXPORT_NAME_INDEX
                        JSR             ASM_PACK40_ASCII_TO_CODE
                        RTS

ASM_PACK40_ASCII_TO_CODE:
                        AND             #$7F
                        BEQ             ASM_PACK40_ASCII_ZERO
                        JSR             ASM_FOLD_UPPER_A
                        CMP             #'A'
                        BCC             ASM_PACK40_ASCII_DIGIT
                        CMP             #'Z'+1
                        BCS             ASM_PACK40_ASCII_DIGIT
                        SEC
                        SBC             #'@'
                        SEC
                        RTS
ASM_PACK40_ASCII_DIGIT:
                        CMP             #'0'
                        BCC             ASM_PACK40_ASCII_UNDER
                        CMP             #'9'+1
                        BCS             ASM_PACK40_ASCII_UNDER
                        SEC
                        SBC             #'0'
                        CLC
                        ADC             #$1B
                        SEC
                        RTS
ASM_PACK40_ASCII_UNDER:
                        CMP             #'_'
                        BNE             ASM_PACK40_ASCII_Q
                        LDA             #$25
                        SEC
                        RTS
ASM_PACK40_ASCII_Q:
                        CMP             #'?'
                        BNE             ASM_PACK40_ASCII_DOT
                        LDA             #$26
                        SEC
                        RTS
ASM_PACK40_ASCII_DOT:
                        CMP             #'.'
                        BNE             ASM_PACK40_ASCII_FAIL
                        LDA             #$27
                        SEC
                        RTS
ASM_PACK40_ASCII_ZERO:
                        SEC
                        RTS
ASM_PACK40_ASCII_FAIL:
                        CLC
                        RTS

ASM_PACK40_PACK3:
                        STA             ASM_P40_CODE0
                        STX             ASM_P40_CODE1
                        STY             ASM_P40_CODE2
                        CMP             #$28
                        BCS             ASM_PACK40_PACK3_FAIL
                        CPX             #$28
                        BCS             ASM_PACK40_PACK3_FAIL
                        CPY             #$28
                        BCS             ASM_PACK40_PACK3_FAIL
                        STZ             ASM_VALUE_HI
                        STA             ASM_VALUE_LO
                        JSR             ASM_PACK40_MUL40
                        LDA             ASM_P40_CODE1
                        JSR             ASM_PACK40_ADD_A
                        JSR             ASM_PACK40_MUL40
                        LDA             ASM_P40_CODE2
                        JSR             ASM_PACK40_ADD_A
                        LDX             ASM_VALUE_LO
                        LDY             ASM_VALUE_HI
                        SEC
                        RTS
ASM_PACK40_PACK3_FAIL:
                        CLC
                        RTS

ASM_PACK40_ADD_A:
                        CLC
                        ADC             ASM_VALUE_LO
                        STA             ASM_VALUE_LO
                        BCC             ASM_PACK40_ADD_DONE
                        INC             ASM_VALUE_HI
ASM_PACK40_ADD_DONE:
                        RTS

ASM_PACK40_MUL40:
                        LDA             ASM_VALUE_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_VALUE_HI
                        STA             ASM_TMP1_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        ASL             ASM_VALUE_LO
                        ROL             ASM_VALUE_HI
                        LDX             #$05
ASM_PACK40_MUL40_SHIFT32:
                        ASL             ASM_TMP1_LO
                        ROL             ASM_TMP1_HI
                        DEX
                        BNE             ASM_PACK40_MUL40_SHIFT32
                        CLC
                        LDA             ASM_VALUE_LO
                        ADC             ASM_TMP1_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_VALUE_HI
                        ADC             ASM_TMP1_HI
                        STA             ASM_VALUE_HI
                        RTS

; ----------------------------------------------------------------------------
; Internal seal span facts.
; ----------------------------------------------------------------------------
; Minimal RAM record captured by clean END:
;   flags bit0 valid, bit1 hole, bit2 unowned bytes,
;   base=start_pc, end=high_water_pc exclusive, len=end-base,
;   fnv=FNV32 over bytes [base,end) after validation passes.
; ASM_SEAL_REC is the concrete byte record:
;   +$00 flags
;   +$01 base lo, +$02 base hi
;   +$03 end lo,  +$04 end hi
;   +$05 len lo,  +$06 len hi
;   +$07..+$0A FNV32 lo..hi
; ASM_RELOC_REC is separate RAM-only metadata:
;   +$00 count, then parallel arrays kind/site_offset/target_offset.
; First-pass kinds: $01 ABS16_INTERNAL, $02 LO8_INTERNAL, $03 HI8_INTERNAL.
; ASM_EXPORT_REC is separate compact RAM metadata:
;   +$00 count, +$01 record length, then variable rows:
;   offset_lo offset_hi name_len PACK40(name).
; ASM_IMPORT_REC is separate compact RAM metadata:
;   +$00 count, +$01 record length, then variable rows:
;   name_len PACK40(name).
; This is not flash publication and not a K bit.
ASM_SEAL_CAPTURE_END_FACTS:
                        LDA             ASM_START_PC_LO
                        STA             ASM_SEAL_BASE_LO
                        LDA             ASM_START_PC_HI
                        STA             ASM_SEAL_BASE_HI
                        LDA             ASM_HIGH_PC_LO
                        STA             ASM_SEAL_END_LO
                        LDA             ASM_HIGH_PC_HI
                        STA             ASM_SEAL_END_HI
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASM_SEAL_LEN_LO
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        STA             ASM_SEAL_LEN_HI
                        LDA             ASM_SEAL_FLAGS
                        ORA             #ASM_SEALF_VALID
                        STA             ASM_SEAL_FLAGS
                        RTS

ASM_SEAL_NOTE_HOLE:
                        LDA             ASM_SEAL_FLAGS
                        ORA             #ASM_SEALF_HOLE
                        STA             ASM_SEAL_FLAGS
                        RTS

ASM_SEAL_NOTE_UNOWNED:
                        LDA             ASM_SEAL_FLAGS
                        ORA             #ASM_SEALF_UNOWNED
                        STA             ASM_SEAL_FLAGS
                        RTS

ASM_SEAL_NOTE_RELOC_TRUNC:
                        LDA             ASM_SEAL_FLAGS
                        ORA             #ASM_SEALF_RELOC_TRUNC
                        STA             ASM_SEAL_FLAGS
                        RTS

ASM_SEAL_NOTE_RELOC_BAD:
                        LDA             ASM_SEAL_FLAGS
                        ORA             #ASM_SEALF_RELOC_BAD
                        STA             ASM_SEAL_FLAGS
                        RTS

ASM_SEAL_VALIDATE:
                        LDA             ASM_SEAL_FLAGS
                        AND             #ASM_SEALF_VALID
                        BNE             ASM_SEAL_VALIDATE_HAVE_END
                        LDA             #ASM_SEAL_STATUS_NO_END
                        CLC
                        RTS
ASM_SEAL_VALIDATE_HAVE_END:
                        LDA             ASM_SEAL_FLAGS
                        CMP             #ASM_SEALF_VALID
                        BEQ             ASM_SEAL_VALIDATE_OK
                        LDA             #ASM_SEAL_STATUS_BAD_FLAGS
                        CLC
                        RTS
ASM_SEAL_VALIDATE_OK:
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

ASM_SEAL_COMPUTE_FNV:
                        JSR             ASM_SEAL_VALIDATE
                        BCS             ASM_SEAL_COMPUTE_FNV_OK
                        RTS
ASM_SEAL_COMPUTE_FNV_OK:
                        JSR             ASM_FNV1A_INIT
                        LDA             ASM_SEAL_BASE_LO
                        STA             ASM_SCAN_PTR_LO
                        LDA             ASM_SEAL_BASE_HI
                        STA             ASM_SCAN_PTR_HI
                        LDA             ASM_SEAL_LEN_LO
                        STA             ASM_VALUE_LO
                        LDA             ASM_SEAL_LEN_HI
                        STA             ASM_VALUE_HI
                        ORA             ASM_VALUE_LO
                        BEQ             ASM_SEAL_COMPUTE_FNV_DONE
ASM_SEAL_COMPUTE_FNV_LOOP:
                        LDY             #$00
                        LDA             (ASM_SCAN_PTR_LO),Y
                        JSR             ASM_FNV1A_UPDATE_A_FAST
                        INC             ASM_SCAN_PTR_LO
                        BNE             ASM_SEAL_COMPUTE_FNV_COUNT
                        INC             ASM_SCAN_PTR_HI
ASM_SEAL_COMPUTE_FNV_COUNT:
                        DEC             ASM_VALUE_LO
                        LDA             ASM_VALUE_LO
                        CMP             #$FF
                        BNE             ASM_SEAL_COMPUTE_FNV_MORE
                        DEC             ASM_VALUE_HI
ASM_SEAL_COMPUTE_FNV_MORE:
                        LDA             ASM_VALUE_LO
                        ORA             ASM_VALUE_HI
                        BNE             ASM_SEAL_COMPUTE_FNV_LOOP
ASM_SEAL_COMPUTE_FNV_DONE:
                        LDA             ASM_HASH0
                        STA             ASM_SEAL_FNV0
                        LDA             ASM_HASH1
                        STA             ASM_SEAL_FNV1
                        LDA             ASM_HASH2
                        STA             ASM_SEAL_FNV2
                        LDA             ASM_HASH3
                        STA             ASM_SEAL_FNV3
                        JSR             ASM_EXPORT_BUILD_RECORD
                        JSR             ASM_IMPORT_BUILD_RECORD
                        LDA             #ASM_STATUS_OK
                        SEC
                        RTS

ASM_SEAL_PRINT_RECORD:
                        LDX             #<ASM_SEAL_MSG_OK
                        LDY             #>ASM_SEAL_MSG_OK
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SEAL_FLAGS
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_BASE
                        LDY             #>ASM_SEAL_MSG_BASE
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SEAL_BASE_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_BASE_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_END
                        LDY             #>ASM_SEAL_MSG_END
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SEAL_END_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_END_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        LDX             #<ASM_SEAL_MSG_REC
                        LDY             #>ASM_SEAL_MSG_REC
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             #>ASM_SEAL_REC
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             #<ASM_SEAL_REC
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_LEN
                        LDY             #>ASM_SEAL_MSG_LEN
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SEAL_LEN_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_LEN_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_FNV
                        LDY             #>ASM_SEAL_MSG_FNV
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_SEAL_FNV3
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_FNV2
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_FNV1
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_SEAL_FNV0
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        LDX             #<ASM_SEAL_MSG_REL
                        LDY             #>ASM_SEAL_MSG_REL
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             #>ASM_RELOC_REC
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             #<ASM_RELOC_REC
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_COUNT
                        LDY             #>ASM_SEAL_MSG_COUNT
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_RELOC_COUNT
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JSR             ASM_RJ_PRINT_CRLF
                        LDA             ASM_EXPORT_REC_COUNT
                        BNE             ASM_SEAL_PRINT_EXPORT
ASM_SEAL_PRINT_IMPORT_CHECK:
                        LDA             ASM_IMPORT_REC_COUNT
                        BNE             ASM_SEAL_PRINT_IMPORT
                        RTS
ASM_SEAL_PRINT_EXPORT:
                        LDA             #<ASM_EXPORT_REC
                        STA             ASM_TMP0_LO
                        LDA             #>ASM_EXPORT_REC
                        STA             ASM_TMP0_HI
                        LDX             #<ASM_SEAL_MSG_EXP
                        LDY             #>ASM_SEAL_MSG_EXP
                        JSR             ASM_SEAL_PRINT_NAMED_REC
                        BRA             ASM_SEAL_PRINT_IMPORT_CHECK
ASM_SEAL_PRINT_IMPORT:
                        LDA             #<ASM_IMPORT_REC
                        STA             ASM_TMP0_LO
                        LDA             #>ASM_IMPORT_REC
                        STA             ASM_TMP0_HI
                        LDX             #<ASM_SEAL_MSG_IMP
                        LDY             #>ASM_SEAL_MSG_IMP
                        JMP             ASM_SEAL_PRINT_NAMED_REC

ASM_SEAL_PRINT_NAMED_REC:
                        LDA             ASM_TMP0_LO
                        STA             ASM_TMP1_LO
                        LDA             ASM_TMP0_HI
                        STA             ASM_TMP1_HI
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             ASM_TMP1_HI
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDA             ASM_TMP1_LO
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_COUNT
                        LDY             #>ASM_SEAL_MSG_COUNT
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDY             #$00
                        LDA             (ASM_TMP1_LO),Y
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDX             #<ASM_SEAL_MSG_LEN
                        LDY             #>ASM_SEAL_MSG_LEN
                        JSR             ASM_RJ_WRITE_CSTRING
                        LDA             #$00
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        LDY             #$01
                        LDA             (ASM_TMP1_LO),Y
                        JSR             ASM_RJ_WRITE_HEX_BYTE
                        JMP             ASM_RJ_PRINT_CRLF

ASM_SEAL_CLEAR:
                        LDX             #(ASM_RELOC_COUNT-ASM_SEAL_REC)
ASM_SEAL_CLEAR_LOOP:
                        STZ             ASM_SEAL_REC,X
                        DEX
                        BPL             ASM_SEAL_CLEAR_LOOP
                        STZ             ASM_EXPORT_REC_COUNT
                        STZ             ASM_EXPORT_REC_LEN
                        STZ             ASM_IMPORT_REC_COUNT
                        STZ             ASM_IMPORT_REC_LEN
                        RTS

; ----------------------------------------------------------------------------
; Internal session clear.
; ----------------------------------------------------------------------------
ASM_CLEAR_SESSION:
                        JSR             ASM_SEAL_CLEAR
                        STZ             ASM_SESSION_STATE
                        STZ             ASM_LAST_STATUS
                        STZ             ASM_LINE_COUNT_LO
                        STZ             ASM_LINE_COUNT_HI
                        STZ             ASM_SYM_COUNT
                        STZ             ASM_FIX_COUNT
                        STZ             ASM_LOCAL_COUNT
                        STZ             ASM_LOCAL_SCOPE_ACTIVE
                        STZ             ASM_REF_COUNT
                        STZ             ASM_REPORT_FLAGS
                        STZ             ASM_FIX_PLAN_NAME_PTR_LO
                        STZ             ASM_FIX_PLAN_NAME_PTR_HI
                        STZ             ASM_FIX_PLAN_NAME_LEN
                        STZ             ASM_FIX_PLAN_HASH0
                        STZ             ASM_FIX_PLAN_HASH1
                        STZ             ASM_FIX_PLAN_HASH2
                        STZ             ASM_FIX_PLAN_HASH3
                        STZ             ASM_FIX_PLAN_SEL
                        STZ             ASM_RELOC_PLAN_TARGET_LO
                        STZ             ASM_RELOC_PLAN_TARGET_HI
                        STZ             ASM_RELOC_RESOLVE_FLAGS
                        STZ             ASM_FIX_RESOLVE_COUNT
                        STZ             ASM_DB_COUNTING
                        STZ             ASM_EXPORT_COUNT
                        STZ             ASM_IMPORT_COUNT
                        STZ             ASM_IMPORT_RESOLVE_COUNT
                        STZ             ASM_RELOCATE_BASE_LO
                        STZ             ASM_RELOCATE_BASE_HI
                        STZ             ASM_RELOCATE_COUNT
                        IF              ASM_PACKAGE_ENABLED
                        STZ             ASM_PACKAGE_BASE_LO
                        STZ             ASM_PACKAGE_BASE_HI
                        STZ             ASM_PACKAGE_LEN_LO
                        STZ             ASM_PACKAGE_LEN_HI
                        STZ             ASM_PACKAGE_REL_LEN
                        ENDIF
                        RTS

                        IF              ASM_RUNTIME_ONLY
                        UDATA
                        ELSE
                        IF              ASM_FLASH_RUNTIME
                        UDATA
                        ELSE
                        DATA
                        ENDIF
                        ENDIF

ASM_SESSION_STATE:     DB              $00
ASM_LAST_STATUS:       DB              $00
ASM_START_STEP:        DB              $00
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_FAIL_STEP:         DB              $00
ASM_FAIL_STATUS:       DB              $00
ASM_FAIL_SLOT:         DB              $00
                        ENDIF
ASM_LINE_COUNT_LO:     DB              $00
ASM_LINE_COUNT_HI:     DB              $00
ASM_PC_LO:             DB              $00
ASM_PC_HI:             DB              $00
ASM_START_PC_LO:       DB              $00
ASM_START_PC_HI:       DB              $00
ASM_HIGH_PC_LO:        DB              $00
ASM_HIGH_PC_HI:        DB              $00
ASM_SEAL_REC:
ASM_SEAL_FLAGS:        DB              $00
ASM_SEAL_BASE_LO:      DB              $00
ASM_SEAL_BASE_HI:      DB              $00
ASM_SEAL_END_LO:       DB              $00
ASM_SEAL_END_HI:       DB              $00
ASM_SEAL_LEN_LO:       DB              $00
ASM_SEAL_LEN_HI:       DB              $00
ASM_SEAL_FNV0:         DB              $00
ASM_SEAL_FNV1:         DB              $00
ASM_SEAL_FNV2:         DB              $00
ASM_SEAL_FNV3:         DB              $00
ASM_SEAL_REC_END:
ASM_RELOC_REC:
ASM_RELOC_COUNT:       DB              $00
ASM_RELOC_KIND:        DS              ASM_RELOC_MAX
ASM_RELOC_SITE_LO:     DS              ASM_RELOC_MAX
ASM_RELOC_SITE_HI:     DS              ASM_RELOC_MAX
ASM_RELOC_TARGET_LO:   DS              ASM_RELOC_MAX
ASM_RELOC_TARGET_HI:   DS              ASM_RELOC_MAX
ASM_RELOC_REC_END:
ASM_EXPORT_REC:
ASM_EXPORT_REC_COUNT:  DB              $00
ASM_EXPORT_REC_LEN:    DB              $00
ASM_EXPORT_REC_BODY:   DS              ASM_EXPORT_REC_BODY_MAX
ASM_EXPORT_REC_END:
ASM_IMPORT_REC:
ASM_IMPORT_REC_COUNT:  DB              $00
ASM_IMPORT_REC_LEN:    DB              $00
ASM_IMPORT_REC_BODY:   DS              ASM_IMPORT_REC_BODY_MAX
ASM_IMPORT_REC_END:
ASM_LINE_PC_LO:        DB              $00
ASM_LINE_PC_HI:        DB              $00
ASM_LINE_HIGH_PC_LO:   DB              $00
ASM_LINE_HIGH_PC_HI:   DB              $00
ASM_LINE_SYM_COUNT:    DB              $00
ASM_LINE_FIX_COUNT:    DB              $00
ASM_LINE_LOCAL_COUNT:  DB              $00
ASM_LINE_LOCAL_SCOPE_ACTIVE:
                        DB              $00
ASM_LINE_REF_COUNT:    DB              $00
ASM_LINE_FIX_RESOLVE_COUNT:
                        DB              $00
ASM_LINE_FIX_LAST_SITE_LO:
                        DB              $00
ASM_LINE_FIX_LAST_SITE_HI:
                        DB              $00
ASM_LINE_REPORT_FLAGS: DB              $00
ASM_LINE_SEAL_FLAGS:   DB              $00
ASM_LINE_RELOC_COUNT:  DB              $00
ASM_LINE_EXPORT_COUNT: DB              $00
ASM_LINE_IMPORT_COUNT: DB              $00
ASM_LINE_FIX_STATE:    DS              ASM_FIX_MAX
ASM_LINE_FIX_BYTE0:    DS              ASM_FIX_MAX
ASM_LINE_FIX_BYTE1:    DS              ASM_FIX_MAX
ASM_SYM_COUNT:         DB              $00
ASM_FIX_COUNT:         DB              $00
ASM_FIX_RESOLVE_COUNT: DB              $00
ASM_FIX_LAST_SITE_LO:  DB              $00
ASM_FIX_LAST_SITE_HI:  DB              $00
ASM_EXPORT_COUNT:      DB              $00
ASM_IMPORT_COUNT:      DB              $00
ASM_IMPORT_RESOLVE_COUNT:
                        DB              $00
ASM_RELOCATE_BASE_LO:  DB              $00
ASM_RELOCATE_BASE_HI:  DB              $00
ASM_RELOCATE_COUNT:    DB              $00
                        IF              ASM_PACKAGE_ENABLED
ASM_PACKAGE_BASE_LO:   DB              $00
ASM_PACKAGE_BASE_HI:   DB              $00
ASM_PACKAGE_LEN_LO:    DB              $00
ASM_PACKAGE_LEN_HI:    DB              $00
ASM_PACKAGE_REL_LEN:   DB              $00
                        ENDIF
ASM_REF_COUNT:         DB              $00
ASM_REPORT_FLAGS:      DB              $00
ASM_RJ_READY:          DB              $00
ASM_RJ_PROGRESS:       DB              $00
ASM_RJ_JOINER_LO:      DB              $00
ASM_RJ_JOINER_HI:      DB              $00
ASM_RJ_WRITE_LO:       DB              $00
ASM_RJ_WRITE_HI:       DB              $00
ASM_RJ_HEX_NIB_LO:     DB              $00
ASM_RJ_HEX_NIB_HI:     DB              $00
                        IF              ASM_RUNTIME_ONLY
                        IF              ASM_FLASH_RUNTIME
ASM_RJ_READ_LO:        DB              $00
ASM_RJ_READ_HI:        DB              $00
                        ENDIF
                        ELSE
ASM_RJ_READ_LO:        DB              $00
ASM_RJ_READ_HI:        DB              $00
                        ENDIF
ASM_RJ_FNV_INIT_LO:    DB              $00
ASM_RJ_FNV_INIT_HI:    DB              $00
ASM_RJ_FNV_UPDATE_LO:  DB              $00
ASM_RJ_FNV_UPDATE_HI:  DB              $00
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_REPL_STATUS:       DB              $00
ASM_REPL_LEN:          DB              $00
ASM_REPL_OLD_PC_LO:    DB              $00
ASM_REPL_OLD_PC_HI:    DB              $00
ASM_REPL_DELTA:        DB              $00
ASM_REPL_BYTE_INDEX:   DB              $00
                        ENDIF
ASM_EXPR_LEFT_VAL_LO:  DB              $00
ASM_EXPR_LEFT_VAL_HI:  DB              $00
ASM_EXPR_LEFT_CARE_LO: DB              $00
ASM_EXPR_LEFT_CARE_HI: DB              $00
ASM_EXPR_LEFT_MODE:    DB              $00
ASM_EXPR_LEFT_WIDTH:   DB              $00
ASM_EXPR_OP:           DB              $00
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
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_SMOKE_EXPECT_MODE: DB              $00
ASM_SMOKE_EXPECT_STATUS:
                        DB              $00
ASM_SMOKE_REPORT_FLAGS:
                        DB              $00
                        ENDIF
ASM_DB_COUNTING:       DB              $00
ASM_ROOM_COUNT:        DB              $00
ASM_EXPORT_INDEX:      DB              $00
ASM_EXPORT_NAME_INDEX: DB              $00
ASM_IMPORT_INDEX:      DB              $00
ASM_IMPORT_PACK_INDEX: DB              $00
ASM_P40_CODE0:         DB              $00
ASM_P40_CODE1:         DB              $00
ASM_P40_CODE2:         DB              $00
ASM_DB_COUNT:          DB              $00
ASM_DB_TAIL_LO:        DB              $00
ASM_DB_TAIL_HI:        DB              $00
ASM_DS_COUNT:          DB              $00
ASM_DS_FILL:           DB              $00
ASM_DS_INIT_FLAG:      DB              $00
ASM_DS_INIT_LEN:       DB              $00
ASM_DS_INIT_START_LO:  DB              $00
ASM_DS_INIT_START_HI:  DB              $00
ASM_DS_COPY_INDEX:     DB              $00
ASM_FIX_PLAN_NAME_PTR_LO:
                        DB              $00
ASM_FIX_PLAN_NAME_PTR_HI:
                        DB              $00
ASM_FIX_PLAN_NAME_LEN: DB              $00
ASM_FIX_PLAN_HASH0:    DB              $00
ASM_FIX_PLAN_HASH1:    DB              $00
ASM_FIX_PLAN_HASH2:    DB              $00
ASM_FIX_PLAN_HASH3:    DB              $00
ASM_FIX_PLAN_SEL:      DB              $00
ASM_RELOC_PLAN_TARGET_LO:
                        DB              $00
ASM_RELOC_PLAN_TARGET_HI:
                        DB              $00
ASM_RELOC_RESOLVE_FLAGS:
                        DB              $00
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
ASM_SYM_DEFLINE_LO:    DS              ASM_SYM_MAX
ASM_SYM_DEFLINE_HI:    DS              ASM_SYM_MAX
ASM_SYM_USECNT:        DS              ASM_SYM_MAX
ASM_SYM_FIRSTREF_LO:   DS              ASM_SYM_MAX
ASM_SYM_FIRSTREF_HI:   DS              ASM_SYM_MAX
ASM_SYM_NAMES:         DS              (ASM_SYM_MAX*ASM_SYM_NAME_MAX)
ASM_EXPORT_SYM_SLOT:   DS              ASM_EXPORT_MAX
ASM_IMPORT_NAME_LEN:   DS              ASM_IMPORT_MAX
ASM_IMPORT_NAME_PACKS: DS              (ASM_IMPORT_MAX*ASM_EXPORT_NAME_PACK_MAX)
ASM_LOCAL_COUNT:       DB              $00
ASM_LOCAL_SCOPE_ACTIVE:
                        DB              $00
ASM_LOCAL_NAME_LEN:    DS              ASM_LOCAL_MAX
ASM_LOCAL_VAL_LO:      DS              ASM_LOCAL_MAX
ASM_LOCAL_VAL_HI:      DS              ASM_LOCAL_MAX
ASM_LOCAL_HASH0:       DS              ASM_LOCAL_MAX
ASM_LOCAL_HASH1:       DS              ASM_LOCAL_MAX
ASM_LOCAL_HASH2:       DS              ASM_LOCAL_MAX
ASM_LOCAL_HASH3:       DS              ASM_LOCAL_MAX
ASM_LOCAL_NAMES:       DS              ASM_LOCAL_NAME_BYTES
ASM_FIX_STATE:         DS              ASM_FIX_MAX
ASM_FIX_MODE:          DS              ASM_FIX_MAX
ASM_FIX_SEL:           DS              ASM_FIX_MAX
ASM_FIX_SITE_LO:       DS              ASM_FIX_MAX
ASM_FIX_SITE_HI:       DS              ASM_FIX_MAX
ASM_FIX_BASE_LO:       DS              ASM_FIX_MAX
ASM_FIX_BASE_HI:       DS              ASM_FIX_MAX
ASM_FIX_HASH0:         DS              ASM_FIX_MAX
ASM_FIX_HASH1:         DS              ASM_FIX_MAX
ASM_FIX_HASH2:         DS              ASM_FIX_MAX
ASM_FIX_HASH3:         DS              ASM_FIX_MAX
ASM_FIX_NAME_LEN:      DS              ASM_FIX_MAX
ASM_FIX_NAME_TEXT:     DS              ASM_FIX_NAME_BYTES

                        DATA

ASM_OPM_PATCH_BYTES:
                        DB              $00,$00,$01,$01,$02,$01,$02,$01
                        DB              $01,$02,$01,$01,$01,$02,$02,$01
                        DB              $01
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_REPL_LINE_BUF:     DS              $0100

ASM_SMOKE_LINE_OK:     DB              "ORG $7000",0
ASM_SMOKE_LINE_TOKENS: DB              "LABEL: LDA #1",0
ASM_SMOKE_LINE_CHAR:   DB              "'a'",0
ASM_SMOKE_LINE_MASK:   DB              "%XXXXXXX1",0
ASM_SMOKE_VOC_LDA:     DB              "LDA",0
ASM_SMOKE_VOC_DB:      DB              "DB",0
ASM_SMOKE_VOC_DW:      DB              "DW",0
ASM_SMOKE_VOC_DC:      DB              "DC",0
ASM_SMOKE_VOC_IMPORT:  DB              "IMPORT",0
ASM_SMOKE_VOC_A:       DB              "A",0
ASM_SMOKE_VOC_Y:       DB              "Y",0
ASM_SMOKE_VOC_START:   DB              "START",0
ASM_SMOKE_VOC_FOO:     DB              "FOO",0
ASM_SMOKE_PARSE_BLANK: DB              "   ; comment",0
ASM_SMOKE_PARSE_LABEL: DB              "LABEL",0
ASM_SMOKE_PARSE_LABEL_COLON:
                        DB              "LABEL:",0
ASM_SMOKE_PARSE_LDA:   DB              "LDA #1",0
ASM_SMOKE_PARSE_LABEL_LDA_NC:
                        DB              "LABEL LDA #1",0
ASM_SMOKE_PARSE_LABEL_LDA:
                        DB              "LABEL: LDA #1",0
ASM_SMOKE_PARSE_EQU:   DB              "NAME EQU $12",0
ASM_SMOKE_PARSE_ZP0_EQU:
                        DB              "ZP_OFFSET0 EQU $00",0
ASM_SMOKE_PARSE_ABS0_EQU:
                        DB              "ABS_OFFSET0 EQU $0000",0
ASM_SMOKE_PARSE_ZP_PLUS_EQU:
                        DB              "ZP_PLUS EQU ZP_OFFSET0+1",0
ASM_SMOKE_PARSE_ABS_PLUS_EQU:
                        DB              "ABS_PLUS EQU ABS_OFFSET0+1",0
ASM_SMOKE_PARSE_SIZE_EQU:
                        DB              "SIZE EQU ABS_PLUS-ABS_OFFSET0",0
ASM_SMOKE_PARSE_LDA_ZP_PLUS:
                        DB              "LDA ZP_PLUS",0
ASM_SMOKE_PARSE_LDA_ABS_PLUS:
                        DB              "LDA ABS_PLUS",0
ASM_SMOKE_PARSE_DB:    DB              "SEED DB $52",0
ASM_SMOKE_PARSE_DW:    DB              "SEED DW $1234",0
ASM_SMOKE_PARSE_ORG:   DB              "ORG $7000",0
ASM_SMOKE_PARSE_END:   DB              "END",0
ASM_SMOKE_PARSE_LABEL_ORG:
                        DB              "LABEL ORG $7000",0
ASM_SMOKE_PARSE_LABEL_END:
                        DB              "LABEL END",0
ASM_SMOKE_PARSE_ORG_EMPTY:
                        DB              "ORG",0
ASM_SMOKE_PARSE_EQU_EMPTY:
                        DB              "NAME EQU",0
ASM_SMOKE_PARSE_DB_EMPTY:
                        DB              "SEED DB",0
ASM_SMOKE_PARSE_DW_EMPTY:
                        DB              "SEED DW",0
ASM_SMOKE_PARSE_REG_LABEL:
                        DB              "A LDA #1",0
ASM_SMOKE_PARSE_LOCAL_LABEL:
                        DB              ".LOOP",0
ASM_SMOKE_PARSE_END_TAIL:
                        DB              "END X",0
ASM_SMOKE_PARSE_DC:    DB              "DC $52",0
ASM_SMOKE_PARSE_START: DB              "START",0
ASM_PARSE_AT_ORG:      DB              "        ORG $7000",0
ASM_PARSE_AT_OUT_EQU:  DB              "OUT EQU $7100",0
ASM_PARSE_AT_COUNT_EQU:
                        DB              "COUNT EQU 16",0
ASM_PARSE_AT_ASMTEST_LDX:
                        DB              "ASMTEST LDX #0",0
ASM_PARSE_AT_LDY:      DB              "        LDY #$4D",0
ASM_PARSE_AT_STZ:      DB              "        STZ SUM",0
ASM_PARSE_AT_LOOP_LDA:
                        DB              "LOOP    LDA SEED,X",0
ASM_PARSE_AT_STA_OUT_X:
                        DB              "        STA OUT,X",0
ASM_PARSE_AT_EOR_SUM:  DB              "        EOR SUM",0
ASM_PARSE_AT_STA_SUM:  DB              "        STA SUM",0
ASM_PARSE_AT_INX:      DB              "        INX",0
ASM_PARSE_AT_CPX:      DB              "        CPX #COUNT",0
ASM_PARSE_AT_BNE:      DB              "        BNE LOOP",0
ASM_PARSE_AT_RTS:      DB              "        RTS",0
ASM_PARSE_AT_SEED_DB:
                        DB              "SEED    DB $52,$2D,$59,$4F,$52,$53,$20,$41",0
ASM_PARSE_AT_DB_CONT:
                        DB              "        DB $53,$4D,$20,$54,$45,$53,$54,$2E",0
ASM_PARSE_AT_END:      DB              "        END",0
ASM_CLASS_SUM_EQU:     DB              "SUM EQU $7110",0
ASM_CLASS_LDA_ZP:      DB              "        LDA $12",0
ASM_CLASS_RMB_ZP:      DB              "        RMB 3,$12",0
ASM_CLASS_BBR_ZP_REL:  DB              "        BBR 3,$12,$7010",0
ASM_CLASS_LDA_ABS:     DB              "        LDA $0012",0
ASM_CLASS_LDA_ZP_IND:  DB              "        LDA ($12)",0
ASM_CLASS_LDA_ZPX_IND: DB              "        LDA ($12,X)",0
ASM_CLASS_LDA_ZP_INDY: DB              "        LDA ($12),Y",0
ASM_CLASS_ASL_A:       DB              "        ASL A",0
ASM_CLASS_LDA_A:       DB              "        LDA A",0
ASM_CLASS_LDA_DEC:     DB              "        LDA 12",0
ASM_OPCODE_LOOP_LABEL: DB              "LOOP",0
ASM_OPCODE_JSR_FOO:    DB              "        JSR FOO",0
ASM_OPCODE_JMP_ABS:    DB              "        JMP $0012",0
ASM_OPCODE_JMP_IND:    DB              "        JMP ($0012)",0
ASM_OPCODE_JMP_ABSXIND:
                        DB              "        JMP ($0012,X)",0
ASM_OPCODE_BRK_IMM:    DB              "        BRK #$12",0
ASM_OPCODE_BRK_ZP:     DB              "        BRK $12",0
ASM_OPCODE_LDX_ZP:     DB              "        LDX $12",0
ASM_OPCODE_LDX_ABS:    DB              "        LDX $0012",0
ASM_OPCODE_LDX_ZPY:    DB              "        LDX $12,Y",0
ASM_OPCODE_LDX_ABSY:   DB              "        LDX $0012,Y",0
ASM_OPCODE_LDY_ZP:     DB              "        LDY $12",0
ASM_OPCODE_LDY_ABS:    DB              "        LDY $0012",0
ASM_OPCODE_LDY_ZPX:    DB              "        LDY $12,X",0
ASM_OPCODE_LDY_ABSX:   DB              "        LDY $0012,X",0
ASM_OPCODE_CPX_ZP:     DB              "        CPX $12",0
ASM_OPCODE_CPX_ABS:    DB              "        CPX $0012",0
ASM_OPCODE_LSR_NONE:   DB              "        LSR",0
ASM_OPCODE_LSR_A:      DB              "        LSR A",0
ASM_OPCODE_LSR_ZP:     DB              "        LSR $12",0
ASM_OPCODE_LSR_ABS:    DB              "        LSR $0012",0
ASM_OPCODE_LSR_ZPX:    DB              "        LSR $12,X",0
ASM_OPCODE_LSR_ABSX:   DB              "        LSR $0012,X",0
ASM_OPCODE_ROL_NONE:   DB              "        ROL",0
ASM_OPCODE_ROL_A:      DB              "        ROL A",0
ASM_OPCODE_ROL_ZP:     DB              "        ROL $12",0
ASM_OPCODE_ROL_ABS:    DB              "        ROL $0012",0
ASM_OPCODE_ROL_ZPX:    DB              "        ROL $12,X",0
ASM_OPCODE_ROL_ABSX:   DB              "        ROL $0012,X",0
ASM_OPCODE_ROR_NONE:   DB              "        ROR",0
ASM_OPCODE_ROR_A:      DB              "        ROR A",0
ASM_OPCODE_ROR_ZP:     DB              "        ROR $12",0
ASM_OPCODE_ROR_ABS:    DB              "        ROR $0012",0
ASM_OPCODE_ROR_ZPX:    DB              "        ROR $12,X",0
ASM_OPCODE_ROR_ABSX:   DB              "        ROR $0012,X",0
ASM_OPCODE_BIT_IMM:    DB              "        BIT #$12",0
ASM_OPCODE_BIT_ZP:     DB              "        BIT $12",0
ASM_OPCODE_BIT_ABS:    DB              "        BIT $0012",0
ASM_OPCODE_BIT_ZPX:    DB              "        BIT $12,X",0
ASM_OPCODE_BIT_ABSX:   DB              "        BIT $0012,X",0
ASM_OPCODE_RMB3_ZP:    DB              "        RMB 3,$12",0
ASM_OPCODE_SMB3_ZP:    DB              "        SMB 3,$12",0
ASM_OPCODE_BBR3_ZP_REL:
                        DB              "        BBR 3,$12,*",0
ASM_OPCODE_BBS3_ZP_REL:
                        DB              "        BBS 3,$12,*",0
ASM_OPCODE_STX_ZP:     DB              "        STX $12",0
ASM_OPCODE_STX_ABS:    DB              "        STX $0012",0
ASM_OPCODE_STX_ZPY:    DB              "        STX $12,Y",0
ASM_OPCODE_STY_ZP:     DB              "        STY $12",0
ASM_OPCODE_STY_ABS:    DB              "        STY $0012",0
ASM_OPCODE_STY_ZPX:    DB              "        STY $12,X",0
ASM_OPCODE_TRB_ZP:     DB              "        TRB $12",0
ASM_OPCODE_TRB_ABS:    DB              "        TRB $0012",0
ASM_OPCODE_TSB_ZP:     DB              "        TSB $12",0
ASM_OPCODE_TSB_ABS:    DB              "        TSB $0012",0
ASM_OPCODE_CPY_IMM:    DB              "        CPY #$12",0
ASM_OPCODE_CPY_ZP:     DB              "        CPY $12",0
ASM_OPCODE_CPY_ABS:    DB              "        CPY $0012",0
ASM_OPCODE_INC_A:      DB              "        INC A",0
ASM_OPCODE_INC_ZP:     DB              "        INC $12",0
ASM_OPCODE_INC_ABS:    DB              "        INC $0012",0
ASM_OPCODE_INC_ZPX:    DB              "        INC $12,X",0
ASM_OPCODE_INC_ABSX:   DB              "        INC $0012,X",0
ASM_OPCODE_DEC_A:      DB              "        DEC A",0
ASM_OPCODE_DEC_ZP:     DB              "        DEC $12",0
ASM_OPCODE_DEC_ABS:    DB              "        DEC $0012",0
ASM_OPCODE_DEC_ZPX:    DB              "        DEC $12,X",0
ASM_OPCODE_DEC_ABSX:   DB              "        DEC $0012,X",0
ASM_OPCODE_CMP_IMM:    DB              "        CMP #$12",0
ASM_OPCODE_CMP_ZP:     DB              "        CMP $12",0
ASM_OPCODE_CMP_ABS:    DB              "        CMP $0012",0
ASM_OPCODE_CMP_ZPX:    DB              "        CMP $12,X",0
ASM_OPCODE_CMP_ABSX:   DB              "        CMP $0012,X",0
ASM_OPCODE_ADC_IMM:    DB              "        ADC #$12",0
ASM_OPCODE_ADC_ZP:     DB              "        ADC $12",0
ASM_OPCODE_ADC_ABS:    DB              "        ADC $0012",0
ASM_OPCODE_ADC_ZPX:    DB              "        ADC $12,X",0
ASM_OPCODE_ADC_ABSX:   DB              "        ADC $0012,X",0
ASM_OPCODE_SBC_IMM:    DB              "        SBC #$12",0
ASM_OPCODE_SBC_ZP:     DB              "        SBC $12",0
ASM_OPCODE_SBC_ABS:    DB              "        SBC $0012",0
ASM_OPCODE_SBC_ZPX:    DB              "        SBC $12,X",0
ASM_OPCODE_SBC_ABSX:   DB              "        SBC $0012,X",0
ASM_OPCODE_AND_IMM:    DB              "        AND #$12",0
ASM_OPCODE_AND_ZP:     DB              "        AND $12",0
ASM_OPCODE_AND_ABS:    DB              "        AND $0012",0
ASM_OPCODE_AND_ZPX:    DB              "        AND $12,X",0
ASM_OPCODE_AND_ABSX:   DB              "        AND $0012,X",0
ASM_OPCODE_ORA_IMM:    DB              "        ORA #$12",0
ASM_OPCODE_ORA_ZP:     DB              "        ORA $12",0
ASM_OPCODE_ORA_ABS:    DB              "        ORA $0012",0
ASM_OPCODE_ORA_ZPX:    DB              "        ORA $12,X",0
ASM_OPCODE_ORA_ABSX:   DB              "        ORA $0012,X",0
ASM_OPCODE_ORA_ABSY:   DB              "        ORA $0012,Y",0
ASM_OPCODE_ADC_ZPXIND: DB              "        ADC ($12,X)",0
ASM_OPCODE_ADC_ZPIND:  DB              "        ADC ($12)",0
ASM_OPCODE_ADC_ZPINDY: DB              "        ADC ($12),Y",0
ASM_OPCODE_SBC_ZPXIND: DB              "        SBC ($12,X)",0
ASM_OPCODE_SBC_ZPIND:  DB              "        SBC ($12)",0
ASM_OPCODE_SBC_ZPINDY: DB              "        SBC ($12),Y",0
ASM_OPCODE_AND_ZPXIND: DB              "        AND ($12,X)",0
ASM_OPCODE_AND_ZPIND:  DB              "        AND ($12)",0
ASM_OPCODE_AND_ZPINDY: DB              "        AND ($12),Y",0
ASM_OPCODE_ORA_ZPXIND: DB              "        ORA ($12,X)",0
ASM_OPCODE_ORA_ZPIND:  DB              "        ORA ($12)",0
ASM_OPCODE_ORA_ZPINDY: DB              "        ORA ($12),Y",0
ASM_OPCODE_EOR_ZPXIND: DB              "        EOR ($12,X)",0
ASM_OPCODE_EOR_ZPIND:  DB              "        EOR ($12)",0
ASM_OPCODE_EOR_ZPINDY: DB              "        EOR ($12),Y",0
ASM_OPCODE_CMP_ZPXIND: DB              "        CMP ($12,X)",0
ASM_OPCODE_CMP_ZPIND:  DB              "        CMP ($12)",0
ASM_OPCODE_CMP_ZPINDY: DB              "        CMP ($12),Y",0
ASM_OPCODE_LDA_ZPXIND: DB              "        LDA ($12,X)",0
ASM_OPCODE_LDA_ZPIND:  DB              "        LDA ($12)",0
ASM_OPCODE_LDA_ZPINDY: DB              "        LDA ($12),Y",0
ASM_OPCODE_STA_ZPXIND: DB              "        STA ($12,X)",0
ASM_OPCODE_STA_ZPIND:  DB              "        STA ($12)",0
ASM_OPCODE_STA_ZPINDY: DB              "        STA ($12),Y",0
ASM_OPCODE_STA_ABSY:   DB              "        STA $0012,Y",0
ASM_OPCODE_AND_ABSY:   DB              "        AND $0012,Y",0
ASM_OPCODE_EOR_ABSY:   DB              "        EOR $0012,Y",0
ASM_OPCODE_ADC_ABSY:   DB              "        ADC $0012,Y",0
ASM_OPCODE_LDA_ABSY:   DB              "        LDA $0012,Y",0
ASM_OPCODE_CMP_ABSY:   DB              "        CMP $0012,Y",0
ASM_OPCODE_SBC_ABSY:   DB              "        SBC $0012,Y",0
ASM_OPCODE_CLC:        DB              "        CLC",0
ASM_OPCODE_CLD:        DB              "        CLD",0
ASM_OPCODE_CLI:        DB              "        CLI",0
ASM_OPCODE_CLV:        DB              "        CLV",0
ASM_OPCODE_SEC:        DB              "        SEC",0
ASM_OPCODE_SED:        DB              "        SED",0
ASM_OPCODE_SEI:        DB              "        SEI",0
ASM_OPCODE_NOP:        DB              "        NOP",0
ASM_OPCODE_DEX:        DB              "        DEX",0
ASM_OPCODE_DEY:        DB              "        DEY",0
ASM_OPCODE_INY:        DB              "        INY",0
ASM_OPCODE_TAX:        DB              "        TAX",0
ASM_OPCODE_TAY:        DB              "        TAY",0
ASM_OPCODE_TSX:        DB              "        TSX",0
ASM_OPCODE_TXA:        DB              "        TXA",0
ASM_OPCODE_TXS:        DB              "        TXS",0
ASM_OPCODE_TYA:        DB              "        TYA",0
ASM_OPCODE_PHA:        DB              "        PHA",0
ASM_OPCODE_PHP:        DB              "        PHP",0
ASM_OPCODE_PHX:        DB              "        PHX",0
ASM_OPCODE_PHY:        DB              "        PHY",0
ASM_OPCODE_PLA:        DB              "        PLA",0
ASM_OPCODE_PLP:        DB              "        PLP",0
ASM_OPCODE_PLX:        DB              "        PLX",0
ASM_OPCODE_PLY:        DB              "        PLY",0
ASM_OPCODE_RTI:        DB              "        RTI",0
ASM_OPCODE_WAI:        DB              "        WAI",0
ASM_OPCODE_STP:        DB              "        STP",0
ASM_OPCODE_INDEX_PTR_LO:
                        DB              <ASM_OPCODE_LDX_ZP,<ASM_OPCODE_LDX_ABS
                        DB              <ASM_OPCODE_LDX_ZPY,<ASM_OPCODE_LDX_ABSY
                        DB              <ASM_OPCODE_LDY_ZP,<ASM_OPCODE_LDY_ABS
                        DB              <ASM_OPCODE_LDY_ZPX,<ASM_OPCODE_LDY_ABSX
                        DB              <ASM_OPCODE_CPX_ZP,<ASM_OPCODE_CPX_ABS
ASM_OPCODE_INDEX_PTR_HI:
                        DB              >ASM_OPCODE_LDX_ZP,>ASM_OPCODE_LDX_ABS
                        DB              >ASM_OPCODE_LDX_ZPY,>ASM_OPCODE_LDX_ABSY
                        DB              >ASM_OPCODE_LDY_ZP,>ASM_OPCODE_LDY_ABS
                        DB              >ASM_OPCODE_LDY_ZPX,>ASM_OPCODE_LDY_ABSX
                        DB              >ASM_OPCODE_CPX_ZP,>ASM_OPCODE_CPX_ABS
ASM_OPCODE_SHIFT_PTR_LO:
                        DB              <ASM_OPCODE_LSR_NONE,<ASM_OPCODE_LSR_A
                        DB              <ASM_OPCODE_LSR_ZP,<ASM_OPCODE_LSR_ABS
                        DB              <ASM_OPCODE_LSR_ZPX,<ASM_OPCODE_LSR_ABSX
                        DB              <ASM_OPCODE_ROL_NONE,<ASM_OPCODE_ROL_A
                        DB              <ASM_OPCODE_ROL_ZP,<ASM_OPCODE_ROL_ABS
                        DB              <ASM_OPCODE_ROL_ZPX,<ASM_OPCODE_ROL_ABSX
                        DB              <ASM_OPCODE_ROR_NONE,<ASM_OPCODE_ROR_A
                        DB              <ASM_OPCODE_ROR_ZP,<ASM_OPCODE_ROR_ABS
                        DB              <ASM_OPCODE_ROR_ZPX,<ASM_OPCODE_ROR_ABSX
ASM_OPCODE_SHIFT_PTR_HI:
                        DB              >ASM_OPCODE_LSR_NONE,>ASM_OPCODE_LSR_A
                        DB              >ASM_OPCODE_LSR_ZP,>ASM_OPCODE_LSR_ABS
                        DB              >ASM_OPCODE_LSR_ZPX,>ASM_OPCODE_LSR_ABSX
                        DB              >ASM_OPCODE_ROL_NONE,>ASM_OPCODE_ROL_A
                        DB              >ASM_OPCODE_ROL_ZP,>ASM_OPCODE_ROL_ABS
                        DB              >ASM_OPCODE_ROL_ZPX,>ASM_OPCODE_ROL_ABSX
                        DB              >ASM_OPCODE_ROR_NONE,>ASM_OPCODE_ROR_A
                        DB              >ASM_OPCODE_ROR_ZP,>ASM_OPCODE_ROR_ABS
                        DB              >ASM_OPCODE_ROR_ZPX,>ASM_OPCODE_ROR_ABSX
ASM_OPCODE_BIT_PTR_LO:
                        DB              <ASM_OPCODE_BIT_IMM,<ASM_OPCODE_BIT_ZP
                        DB              <ASM_OPCODE_BIT_ABS,<ASM_OPCODE_BIT_ZPX
                        DB              <ASM_OPCODE_BIT_ABSX
ASM_OPCODE_BIT_PTR_HI:
                        DB              >ASM_OPCODE_BIT_IMM,>ASM_OPCODE_BIT_ZP
                        DB              >ASM_OPCODE_BIT_ABS,>ASM_OPCODE_BIT_ZPX
                        DB              >ASM_OPCODE_BIT_ABSX
ASM_OPCODE_BITMEM_PTR_LO:
                        DB              <ASM_OPCODE_RMB3_ZP,<ASM_OPCODE_SMB3_ZP
ASM_OPCODE_BITMEM_PTR_HI:
                        DB              >ASM_OPCODE_RMB3_ZP,>ASM_OPCODE_SMB3_ZP
ASM_OPCODE_BITBR_PTR_LO:
                        DB              <ASM_OPCODE_BBR3_ZP_REL
                        DB              <ASM_OPCODE_BBS3_ZP_REL
ASM_OPCODE_BITBR_PTR_HI:
                        DB              >ASM_OPCODE_BBR3_ZP_REL
                        DB              >ASM_OPCODE_BBS3_ZP_REL
ASM_OPCODE_STORE_PTR_LO:
                        DB              <ASM_OPCODE_STX_ZP,<ASM_OPCODE_STX_ABS
                        DB              <ASM_OPCODE_STX_ZPY,<ASM_OPCODE_STY_ZP
                        DB              <ASM_OPCODE_STY_ABS,<ASM_OPCODE_STY_ZPX
                        DB              <ASM_OPCODE_TRB_ZP,<ASM_OPCODE_TRB_ABS
                        DB              <ASM_OPCODE_TSB_ZP,<ASM_OPCODE_TSB_ABS
                        DB              <ASM_OPCODE_CPY_IMM,<ASM_OPCODE_CPY_ZP
                        DB              <ASM_OPCODE_CPY_ABS
ASM_OPCODE_STORE_PTR_HI:
                        DB              >ASM_OPCODE_STX_ZP,>ASM_OPCODE_STX_ABS
                        DB              >ASM_OPCODE_STX_ZPY,>ASM_OPCODE_STY_ZP
                        DB              >ASM_OPCODE_STY_ABS,>ASM_OPCODE_STY_ZPX
                        DB              >ASM_OPCODE_TRB_ZP,>ASM_OPCODE_TRB_ABS
                        DB              >ASM_OPCODE_TSB_ZP,>ASM_OPCODE_TSB_ABS
                        DB              >ASM_OPCODE_CPY_IMM,>ASM_OPCODE_CPY_ZP
                        DB              >ASM_OPCODE_CPY_ABS
ASM_OPCODE_RMW_PTR_LO:
                        DB              <ASM_OPCODE_INC_A,<ASM_OPCODE_INC_ZP
                        DB              <ASM_OPCODE_INC_ABS,<ASM_OPCODE_INC_ZPX
                        DB              <ASM_OPCODE_INC_ABSX
                        DB              <ASM_OPCODE_DEC_A,<ASM_OPCODE_DEC_ZP
                        DB              <ASM_OPCODE_DEC_ABS,<ASM_OPCODE_DEC_ZPX
                        DB              <ASM_OPCODE_DEC_ABSX
                        DB              <ASM_OPCODE_CMP_IMM,<ASM_OPCODE_CMP_ZP
                        DB              <ASM_OPCODE_CMP_ABS,<ASM_OPCODE_CMP_ZPX
                        DB              <ASM_OPCODE_CMP_ABSX
ASM_OPCODE_RMW_PTR_HI:
                        DB              >ASM_OPCODE_INC_A,>ASM_OPCODE_INC_ZP
                        DB              >ASM_OPCODE_INC_ABS,>ASM_OPCODE_INC_ZPX
                        DB              >ASM_OPCODE_INC_ABSX
                        DB              >ASM_OPCODE_DEC_A,>ASM_OPCODE_DEC_ZP
                        DB              >ASM_OPCODE_DEC_ABS,>ASM_OPCODE_DEC_ZPX
                        DB              >ASM_OPCODE_DEC_ABSX
                        DB              >ASM_OPCODE_CMP_IMM,>ASM_OPCODE_CMP_ZP
                        DB              >ASM_OPCODE_CMP_ABS,>ASM_OPCODE_CMP_ZPX
                        DB              >ASM_OPCODE_CMP_ABSX
ASM_OPCODE_ALU_PTR_LO:
                        DB              <ASM_OPCODE_ADC_IMM,<ASM_OPCODE_ADC_ZP
                        DB              <ASM_OPCODE_ADC_ABS,<ASM_OPCODE_ADC_ZPX
                        DB              <ASM_OPCODE_ADC_ABSX
                        DB              <ASM_OPCODE_SBC_IMM,<ASM_OPCODE_SBC_ZP
                        DB              <ASM_OPCODE_SBC_ABS,<ASM_OPCODE_SBC_ZPX
                        DB              <ASM_OPCODE_SBC_ABSX
                        DB              <ASM_OPCODE_AND_IMM,<ASM_OPCODE_AND_ZP
                        DB              <ASM_OPCODE_AND_ABS,<ASM_OPCODE_AND_ZPX
                        DB              <ASM_OPCODE_AND_ABSX
                        DB              <ASM_OPCODE_ORA_IMM,<ASM_OPCODE_ORA_ZP
                        DB              <ASM_OPCODE_ORA_ABS,<ASM_OPCODE_ORA_ZPX
                        DB              <ASM_OPCODE_ORA_ABSX
ASM_OPCODE_ALU_PTR_HI:
                        DB              >ASM_OPCODE_ADC_IMM,>ASM_OPCODE_ADC_ZP
                        DB              >ASM_OPCODE_ADC_ABS,>ASM_OPCODE_ADC_ZPX
                        DB              >ASM_OPCODE_ADC_ABSX
                        DB              >ASM_OPCODE_SBC_IMM,>ASM_OPCODE_SBC_ZP
                        DB              >ASM_OPCODE_SBC_ABS,>ASM_OPCODE_SBC_ZPX
                        DB              >ASM_OPCODE_SBC_ABSX
                        DB              >ASM_OPCODE_AND_IMM,>ASM_OPCODE_AND_ZP
                        DB              >ASM_OPCODE_AND_ABS,>ASM_OPCODE_AND_ZPX
                        DB              >ASM_OPCODE_AND_ABSX
                        DB              >ASM_OPCODE_ORA_IMM,>ASM_OPCODE_ORA_ZP
                        DB              >ASM_OPCODE_ORA_ABS,>ASM_OPCODE_ORA_ZPX
                        DB              >ASM_OPCODE_ORA_ABSX
ASM_OPCODE_INDIRECT_PTR_LO:
                        DB              <ASM_OPCODE_ADC_ZPXIND,<ASM_OPCODE_ADC_ZPIND
                        DB              <ASM_OPCODE_ADC_ZPINDY
                        DB              <ASM_OPCODE_SBC_ZPXIND,<ASM_OPCODE_SBC_ZPIND
                        DB              <ASM_OPCODE_SBC_ZPINDY
                        DB              <ASM_OPCODE_AND_ZPXIND,<ASM_OPCODE_AND_ZPIND
                        DB              <ASM_OPCODE_AND_ZPINDY
                        DB              <ASM_OPCODE_ORA_ZPXIND,<ASM_OPCODE_ORA_ZPIND
                        DB              <ASM_OPCODE_ORA_ZPINDY
                        DB              <ASM_OPCODE_EOR_ZPXIND,<ASM_OPCODE_EOR_ZPIND
                        DB              <ASM_OPCODE_EOR_ZPINDY
                        DB              <ASM_OPCODE_CMP_ZPXIND,<ASM_OPCODE_CMP_ZPIND
                        DB              <ASM_OPCODE_CMP_ZPINDY
                        DB              <ASM_OPCODE_LDA_ZPXIND,<ASM_OPCODE_LDA_ZPIND
                        DB              <ASM_OPCODE_LDA_ZPINDY
                        DB              <ASM_OPCODE_STA_ZPXIND,<ASM_OPCODE_STA_ZPIND
                        DB              <ASM_OPCODE_STA_ZPINDY,<ASM_OPCODE_STA_ABSY
ASM_OPCODE_INDIRECT_PTR_HI:
                        DB              >ASM_OPCODE_ADC_ZPXIND,>ASM_OPCODE_ADC_ZPIND
                        DB              >ASM_OPCODE_ADC_ZPINDY
                        DB              >ASM_OPCODE_SBC_ZPXIND,>ASM_OPCODE_SBC_ZPIND
                        DB              >ASM_OPCODE_SBC_ZPINDY
                        DB              >ASM_OPCODE_AND_ZPXIND,>ASM_OPCODE_AND_ZPIND
                        DB              >ASM_OPCODE_AND_ZPINDY
                        DB              >ASM_OPCODE_ORA_ZPXIND,>ASM_OPCODE_ORA_ZPIND
                        DB              >ASM_OPCODE_ORA_ZPINDY
                        DB              >ASM_OPCODE_EOR_ZPXIND,>ASM_OPCODE_EOR_ZPIND
                        DB              >ASM_OPCODE_EOR_ZPINDY
                        DB              >ASM_OPCODE_CMP_ZPXIND,>ASM_OPCODE_CMP_ZPIND
                        DB              >ASM_OPCODE_CMP_ZPINDY
                        DB              >ASM_OPCODE_LDA_ZPXIND,>ASM_OPCODE_LDA_ZPIND
                        DB              >ASM_OPCODE_LDA_ZPINDY
                        DB              >ASM_OPCODE_STA_ZPXIND,>ASM_OPCODE_STA_ZPIND
                        DB              >ASM_OPCODE_STA_ZPINDY,>ASM_OPCODE_STA_ABSY
ASM_OPCODE_ABSY_PTR_LO:
                        DB              <ASM_OPCODE_ORA_ABSY,<ASM_OPCODE_AND_ABSY
                        DB              <ASM_OPCODE_EOR_ABSY,<ASM_OPCODE_ADC_ABSY
                        DB              <ASM_OPCODE_LDA_ABSY,<ASM_OPCODE_CMP_ABSY
                        DB              <ASM_OPCODE_SBC_ABSY
ASM_OPCODE_ABSY_PTR_HI:
                        DB              >ASM_OPCODE_ORA_ABSY,>ASM_OPCODE_AND_ABSY
                        DB              >ASM_OPCODE_EOR_ABSY,>ASM_OPCODE_ADC_ABSY
                        DB              >ASM_OPCODE_LDA_ABSY,>ASM_OPCODE_CMP_ABSY
                        DB              >ASM_OPCODE_SBC_ABSY
ASM_OPCODE_IMPLIED_PTR_LO:
                        DB              <ASM_OPCODE_CLC,<ASM_OPCODE_CLD
                        DB              <ASM_OPCODE_CLI,<ASM_OPCODE_CLV
                        DB              <ASM_OPCODE_SEC,<ASM_OPCODE_SED
                        DB              <ASM_OPCODE_SEI
                        DB              <ASM_OPCODE_NOP,<ASM_OPCODE_DEX
                        DB              <ASM_OPCODE_DEY,<ASM_OPCODE_INY
                        DB              <ASM_OPCODE_TAX,<ASM_OPCODE_TAY
                        DB              <ASM_OPCODE_TSX,<ASM_OPCODE_TXA
                        DB              <ASM_OPCODE_TXS,<ASM_OPCODE_TYA
                        DB              <ASM_OPCODE_PHA,<ASM_OPCODE_PHP
                        DB              <ASM_OPCODE_PHX,<ASM_OPCODE_PHY
                        DB              <ASM_OPCODE_PLA,<ASM_OPCODE_PLP
                        DB              <ASM_OPCODE_PLX,<ASM_OPCODE_PLY
                        DB              <ASM_OPCODE_RTI,<ASM_OPCODE_WAI
                        DB              <ASM_OPCODE_STP
ASM_OPCODE_IMPLIED_PTR_HI:
                        DB              >ASM_OPCODE_CLC,>ASM_OPCODE_CLD
                        DB              >ASM_OPCODE_CLI,>ASM_OPCODE_CLV
                        DB              >ASM_OPCODE_SEC,>ASM_OPCODE_SED
                        DB              >ASM_OPCODE_SEI
                        DB              >ASM_OPCODE_NOP,>ASM_OPCODE_DEX
                        DB              >ASM_OPCODE_DEY,>ASM_OPCODE_INY
                        DB              >ASM_OPCODE_TAX,>ASM_OPCODE_TAY
                        DB              >ASM_OPCODE_TSX,>ASM_OPCODE_TXA
                        DB              >ASM_OPCODE_TXS,>ASM_OPCODE_TYA
                        DB              >ASM_OPCODE_PHA,>ASM_OPCODE_PHP
                        DB              >ASM_OPCODE_PHX,>ASM_OPCODE_PHY
                        DB              >ASM_OPCODE_PLA,>ASM_OPCODE_PLP
                        DB              >ASM_OPCODE_PLX,>ASM_OPCODE_PLY
                        DB              >ASM_OPCODE_RTI,>ASM_OPCODE_WAI
                        DB              >ASM_OPCODE_STP
ASM_FIXUP_JSR_FOO:     DB              "        JSR FOO",0
ASM_FIXUP_JSR_EXT:     DB              "        JSR EXT",0
ASM_FIXUP_BNE_FOO:     DB              "        BNE FOO",0
ASM_FIXUP_BBR_FOO:     DB              "        BBR 3,$12,FOO",0
ASM_SMOKE_TXN_BBR_RANGE:
                        DB              "        BBR 3,$12,$9000",0
ASM_SMOKE_TXN_NOP:     DB              "        NOP",0
ASM_SMOKE_TXN_LDA_IMM: DB              "        LDA #$12",0
ASM_SMOKE_TXN_DB_PAIR: DB              "        DB $12,$34",0
ASM_SMOKE_TXN_DS_PAIR: DB              "        DS 2,$00",0
ASM_SMOKE_TXN_DB_ONE:  DB              "        DB $A5",0
ASM_SMOKE_TXN_DS_ONE:  DB              "        DS 1,$5C",0
ASM_SMOKE_TXN_DB_THREE:
                        DB              "        DB $12,$34,$56",0
ASM_SMOKE_TXN_DS_THREE:
                        DB              "        DS 3,$00",0
ASM_SMOKE_TXN_BNE_FOO: DB              "        BNE FOO",0
ASM_SMOKE_TXN_FOO_STA_IMM:
                        DB              "FOO STA #$12",0
ASM_SMOKE_TXN_FOO_NOP: DB              "FOO NOP",0
ASM_SMOKE_TXN_LIMIT_EQU:
                        DB              "LIMIT EQU *",0
ASM_SMOKE_TXN_AFTER_LABEL:
                        DB              "AFTER",0
ASM_FIXUP_LDA_LO_FOO:  DB              "        LDA #<FOO",0
ASM_FIXUP_LDA_HI_FOO:  DB              "        LDA #>FOO",0
ASM_FIXUP_LDA_LO_EXT:  DB              "        LDA #<EXT",0
ASM_FIXUP_LDX_HI_EXT:  DB              "        LDX #>EXT",0
ASM_FIXUP_LOCAL_MAIN_BRA:
                        DB              "MAIN BRA .SKIP",0
ASM_FIXUP_LOCAL_LDA:   DB              "        LDA #$EE",0
ASM_FIXUP_LOCAL_SKIP:  DB              ".SKIP NOP",0
ASM_FIXUP_LOCAL_NEXT:  DB              "NEXT NOP",0
ASM_FIXUP_LOCAL_MISS:  DB              "MAIN BRA .MISS",0
ASM_FIXUP_JSR_BAR:     DB              "        JSR BAR",0
ASM_FIXUP_FOO_LABEL:   DB              "FOO",0
ASM_DIRECT_ADDR_EQU:   DB              "ADDR EQU $1234",0
ASM_DIRECT_DB_MIXED:   DB              "SEED DB $FF,10,'A',$1234,<ADDR,>ADDR",0
ASM_DIRECT_DB_UNKNOWN:
                        DB              "        DB NOPE",0
ASM_DIRECT_DW_LIST:    DB              "WORD DW $1234,$12,10+1,'A'",0
ASM_DIRECT_ORG_CURRENT:
                        DB              "        ORG *",0
ASM_DIRECT_ORG_FORWARD:
                        DB              "        ORG $7010",0
ASM_DIRECT_ORG_BACKWARD:
                        DB              "        ORG $700F",0
ASM_DIRECT_ORG_PROTECTED:
                        DB              "        ORG $7E00",0
ASM_DIRECT_DS_FILL:    DB              "BUF DS 3,$AA",0
ASM_DIRECT_DS_TRUNC:   DB              "        DS 2,$1234",0
ASM_DIRECT_DS_EMPTY:   DB              "BUF DS",0
ASM_DIRECT_DS_RANGE:   DB              "        DS $0100",0
ASM_DIRECT_DS_LIST:    DB              "PAT DS 6,$AA,$55,'A','5'",0
ASM_DIRECT_DS_LIST_TRUNC:
                        DB              "        DS 3,$11,$22,$33,$44",0
ASM_DIRECT_IMPORT_EXT: DB              "        IMPORT EXT",0
ASM_DIRECT_IMPORT_LDA: DB              "        IMPORT LDA",0
ASM_DIRECT_IMPORT_EXT_X:
                        DB              "        IMPORT EXT X",0
ASM_DIRECT_IMPORT_PUT_CSTR:
                        DB              "        IMPORT BIO_FTDI_PUT_CSTR",0
ASM_FIXUP_JSR_PUT_CSTR:
                        DB              "        JSR BIO_FTDI_PUT_CSTR",0
ASM_FIXUP_LDA_LO_PUT_CSTR:
                        DB              "        LDA #<BIO_FTDI_PUT_CSTR",0
ASM_FIXUP_LDX_HI_PUT_CSTR:
                        DB              "        LDX #>BIO_FTDI_PUT_CSTR",0
ASM_FIXUP_JSR_TARGET:  DB              "        JSR TARGET",0
ASM_FIXUP_LDA_LO_TARGET:
                        DB              "        LDA #<TARGET",0
ASM_FIXUP_LDX_HI_TARGET:
                        DB              "        LDX #>TARGET",0
ASM_FIXUP_TARGET_RTS:  DB              "TARGET RTS",0
ASM_OPCODE_EXPECT:     DB              $A2,$00,$A0,$4D,$9C,$10,$71,$9D
                        DB              $00,$71
                        DB              $4D,$10,$71,$8D,$10,$71,$E8,$E0
                        DB              $10,$D0,$EB,$60
                        DB              $4C,$12,$00
                        DB              $6C,$12,$00,$7C,$12,$00
                        DB              $00,$12,$00,$12
                        DB              $A6,$12,$AE,$12,$00,$B6,$12
                        DB              $BE,$12,$00
                        DB              $A4,$12,$AC,$12,$00,$B4,$12
                        DB              $BC,$12,$00
                        DB              $E4,$12,$EC,$12,$00
                        DB              $4A,$4A,$46,$12,$4E,$12,$00
                        DB              $56,$12,$5E,$12,$00
                        DB              $2A,$2A,$26,$12,$2E,$12,$00
                        DB              $36,$12,$3E,$12,$00
                        DB              $6A,$6A,$66,$12,$6E,$12,$00
                        DB              $76,$12,$7E,$12,$00
                        DB              $89,$12,$24,$12,$2C,$12,$00
                        DB              $34,$12,$3C,$12,$00
                        DB              $37,$12,$B7,$12
                        DB              $3F,$12,$FD,$BF,$12,$FD
                        DB              $86,$12,$8E,$12,$00,$96,$12
                        DB              $84,$12,$8C,$12,$00,$94,$12
                        DB              $14,$12,$1C,$12,$00
                        DB              $04,$12,$0C,$12,$00
                        DB              $C0,$12,$C4,$12,$CC,$12,$00
                        DB              $1A,$E6,$12,$EE,$12,$00
                        DB              $F6,$12,$FE,$12,$00
                        DB              $3A,$C6,$12,$CE,$12,$00
                        DB              $D6,$12,$DE,$12,$00
                        DB              $C9,$12,$C5,$12,$CD,$12,$00
                        DB              $D5,$12,$DD,$12,$00
                        DB              $69,$12,$65,$12,$6D,$12,$00
                        DB              $75,$12,$7D,$12,$00
                        DB              $E9,$12,$E5,$12,$ED,$12,$00
                        DB              $F5,$12,$FD,$12,$00
                        DB              $29,$12,$25,$12,$2D,$12,$00
                        DB              $35,$12,$3D,$12,$00
                        DB              $09,$12,$05,$12,$0D,$12,$00
                        DB              $15,$12,$1D,$12,$00
                        DB              $61,$12,$72,$12,$71,$12
                        DB              $E1,$12,$F2,$12,$F1,$12
                        DB              $21,$12,$32,$12,$31,$12
                        DB              $01,$12,$12,$12,$11,$12
                        DB              $41,$12,$52,$12,$51,$12
                        DB              $C1,$12,$D2,$12,$D1,$12
                        DB              $A1,$12,$B2,$12,$B1,$12
                        DB              $81,$12,$92,$12,$91,$12
                        DB              $99,$12,$00
                        DB              $19,$12,$00,$39,$12,$00
                        DB              $59,$12,$00,$79,$12,$00
                        DB              $B9,$12,$00,$D9,$12,$00
                        DB              $F9,$12,$00
                        DB              $18,$D8,$58,$B8,$38,$F8,$78
                        DB              $EA,$CA,$88,$C8,$AA,$A8,$BA,$8A
                        DB              $9A,$98,$48,$08,$DA,$5A,$68,$28
                        DB              $FA,$7A,$40,$CB,$DB
ASM_ASMTEST_EXPECT:    DB              $A2,$00,$9C,$10,$71,$BD,$17,$70
                        DB              $9D,$00,$71,$4D,$10,$71,$8D,$10
                        DB              $71,$E8,$E0,$10,$D0,$EF,$60,$52
                        DB              $2D,$59,$4F,$52,$53,$20,$41,$53
                        DB              $4D,$20,$54,$45,$53,$54,$2E
ASM_DIRECT_DB_EXPECT:  DB              $FF,$0A,$41,$34,$12,$34,$12
ASM_DIRECT_DW_EXPECT:  DB              $34,$12,$12,$00,$0B,$00,$41,$00
ASM_DIRECT_DS_EXPECT:  DB              $AA,$AA,$AA,$34,$34
ASM_DIRECT_DS_LIST_EXPECT:
                        DB              $AA,$55,$41,$35,$AA,$55,$11,$22
                        DB              $33
ASM_SMOKE_EXPR_DEC:    DB              "10",0
ASM_SMOKE_EXPR_HEX_ZP:
                        DB              "$12",0
ASM_SMOKE_EXPR_HEX_ABS:
                        DB              "$0012",0
ASM_SMOKE_EXPR_CHAR_A:
                        DB              "'A'",0
ASM_SMOKE_EXPR_MASK:   DB              "%XXXXXXX1",0
ASM_SMOKE_EXPR_PC:     DB              "*",0
ASM_SMOKE_EXPR_ABS_PLUS:
                        DB              "$0012+1",0
ASM_SMOKE_EXPR_ZP_PLUS:
                        DB              "$12+1",0
ASM_SMOKE_EXPR_ADDR_DELTA:
                        DB              "$0012-$0011",0
ASM_SMOKE_EXPR_ZP_RANGE:
                        DB              "$FF+1",0
ASM_SMOKE_EXPR_EXTRA:  DB              "$12 $34",0
ASM_SMOKE_SYM_LABEL:   DB              "LABEL",0
ASM_SMOKE_SYM_FOO_EQU: DB              "FOO EQU $12",0
ASM_SMOKE_SYM_ADDR_EQU:
                        DB              "ADDR EQU $0012",0
ASM_SMOKE_SYM_COUNT_EQU:
                        DB              "COUNT EQU 10",0
ASM_SMOKE_SYM_ERR_EQU:
                        DB              "ERR EQU %XXXXXXX1",0
ASM_SMOKE_SYM_NOPE:    DB              "NOPE",0
                        ENDIF
ASM_HASH_BIO_WRITE_BYTE_BLOCK:
                        DB              $30,$E9,$9F,$37
ASM_HASH_UTL_HEX_ASCII_TO_NIBBLE:
                        DB              $B1,$14,$D7,$AD
                        IF              ASM_RUNTIME_ONLY
                        IF              ASM_FLASH_RUNTIME
ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER:
                        DB              $AF,$10,$DD,$E2
                        ENDIF
                        ELSE
ASM_HASH_SYS_READ_CSTRING_ECHO_UPPER:
                        DB              $AF,$10,$DD,$E2
                        ENDIF
ASM_HASH_FNV1A_INIT:
                        DB              $1E,$EE,$9A,$4B
ASM_HASH_FNV1A_UPDATE_A_FAST:
                        DB              $14,$23,$80,$A8
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_REPL_MSG_TITLE:    DB              "ASM 2.65 ICO",0
ASM_REPL_MSG_PROMPT:   DB              "ASM> ",0
ASM_REPL_MSG_OK:       DB              "OK PC=$",0
ASM_REPL_MSG_ERR:      DB              "ERR=$",0
ASM_REPL_MSG_READ:     DB              "READ=$",0
ASM_REPL_MSG_BYTES:    DB              " BYTES=",0
ASM_REPL_MSG_FIX:      DB              " FIX=$",0
ASM_REPL_MSG_BYE:      DB              "BYE",0
ASM_SMOKE_MSG_RUN:     DB              "ASM 2.65 RUN",0
ASM_SMOKE_MSG_PASS:    DB              "ASM 2.65 TESTS OK",0
ASM_SMOKE_MSG_FAIL_TITLE:
                        DB              "ASM 2.65 TESTS FAIL",0
ASM_SMOKE_MSG_FAIL_S:  DB              "S=$",0
ASM_SMOKE_MSG_FAIL_X:  DB              " X=$",0
ASM_SMOKE_MSG_FAIL_Y:  DB              " Y=$",0
ASM_SMOKE_MSG_FIX_A1:  DB              " A1 ABS16",0
ASM_SMOKE_MSG_FIX_A2:  DB              " A2 REL8",0
ASM_SMOKE_MSG_FIX_A3:  DB              " A3 REL8 RANGE",0
ASM_SMOKE_MSG_FIX_A4:  DB              " A4 SELECT",0
ASM_SMOKE_MSG_FIX_A5:  DB              " A5 LO8",0
ASM_SMOKE_MSG_FIX_A6:  DB              " A6 HI8",0
ASM_SMOKE_MSG_FIX_A7:  DB              " A7 PENDING END",0
ASM_SMOKE_MSG_FIX_AC:  DB              " AC IMPORT",0
ASM_SMOKE_MSG_FIX_AF:  DB              " AF SITE/BASE",0
ASM_SMOKE_MSG_FIX_B1:  DB              " B1 ABS16 BEGIN",0
ASM_SMOKE_MSG_FIX_B2:  DB              " B2 ABS16 EMIT",0
ASM_SMOKE_MSG_FIX_B3:  DB              " B3 ABS16 BYTES",0
ASM_SMOKE_MSG_FIX_B4:  DB              " B4 ABS16 ROW",0
ASM_SMOKE_MSG_FIX_B5:  DB              " B5 ABS16 SITE",0
ASM_SMOKE_MSG_FIX_B6:  DB              " B6 ABS16 BIND",0
ASM_SMOKE_MSG_FIX_B7:  DB              " B7 ABS16 RESOLVE",0
ASM_SMOKE_MSG_FIX_B8:  DB              " B8 ABS16 PATCH LO",0
ASM_SMOKE_MSG_FIX_B9:  DB              " B9 ABS16 PATCH HI",0
ASM_SMOKE_MSG_FIX_BA:  DB              " BA ABS16 END",0
ASM_SMOKE_MSG_FIX_BB:  DB              " BB RELOCATE",0
ASM_SMOKE_MSG_DIR_C1:  DB              " C1 DB BEGIN",0
ASM_SMOKE_MSG_DIR_C2:  DB              " C2 DB ADDR EQU",0
ASM_SMOKE_MSG_DIR_C3:  DB              " C3 DB EMIT",0
ASM_SMOKE_MSG_DIR_C4:  DB              " C4 DB BYTES",0
ASM_SMOKE_MSG_DIR_C5:  DB              " C5 DB PC",0
ASM_SMOKE_MSG_DIR_C6:  DB              " C6 DB EMPTY",0
ASM_SMOKE_MSG_DIR_C7:  DB              " C7 DB UNKNOWN",0
ASM_SMOKE_MSG_DIR_C8:  DB              " C8 ORG CURRENT",0
ASM_SMOKE_MSG_DIR_C9:  DB              " C9 ORG FORWARD",0
ASM_SMOKE_MSG_DIR_CA:  DB              " CA ORG BACK",0
ASM_SMOKE_MSG_DIR_CB:  DB              " CB DS EMIT",0
ASM_SMOKE_MSG_DIR_CC:  DB              " CC DS BYTES",0
ASM_SMOKE_MSG_DIR_CD:  DB              " CD DS PC",0
ASM_SMOKE_MSG_DIR_CE:  DB              " CE DS EMPTY",0
ASM_SMOKE_MSG_DIR_CF:  DB              " CF DS RANGE",0
ASM_SMOKE_MSG_DIR_D0:  DB              " D0 DS LIST EMIT",0
ASM_SMOKE_MSG_DIR_D1:  DB              " D1 DS LIST BYTES",0
ASM_SMOKE_MSG_DIR_D2:  DB              " D2 DS LIST PC",0
ASM_SMOKE_MSG_DIR_D3:  DB              " D3 WARN_DS_WRAP",0
ASM_SMOKE_MSG_DIR_D4:  DB              " D4 BEGIN HIGH",0
ASM_SMOKE_MSG_DIR_D5:  DB              " D5 ORG HIGH",0
ASM_SMOKE_MSG_DIR_D6:  DB              " D6 DW EMIT",0
ASM_SMOKE_MSG_DIR_D7:  DB              " D7 DW BYTES",0
ASM_SMOKE_MSG_DIR_D8:  DB              " D8 DW PC",0
ASM_SMOKE_MSG_DIR_D9:  DB              " D9 DW EMPTY",0
ASM_SMOKE_MSG_WARN_DS_WRAP:
                        DB              "WARN WARN_DS_WRAP",0
ASM_SMOKE_MSG_T_RJOIN: DB              " 00 RJOIN",0
ASM_SMOKE_MSG_T_BEGIN: DB              " 10 BEGIN",0
ASM_SMOKE_MSG_T_LEX:   DB              " 20 LEX LINE",0
ASM_SMOKE_MSG_T_TOKENS:
                        DB              " 30 TOKENS",0
ASM_SMOKE_MSG_T_VOCAB: DB              " 40 VOCAB",0
ASM_SMOKE_MSG_T_PARSE: DB              " 50 PARSER",0
ASM_SMOKE_MSG_T_EXPR:  DB              " 56 EXPR",0
ASM_SMOKE_MSG_T_LINE:  DB              " 58 LINE",0
ASM_SMOKE_MSG_T_EMIT:  DB              " 59 EMIT",0
ASM_SMOKE_MSG_T_OPER:  DB              " 5A OPERAND",0
ASM_SMOKE_MSG_T_OPCODE:
                        DB              " 5B OPCODE",0
ASM_SMOKE_MSG_T_FIXUPS:
                        DB              " 5C FIXUPS",0
ASM_SMOKE_MSG_T_DIRECT:
                        DB              " 5D DIRECT",0
ASM_SMOKE_MSG_T_REPORT:
                        DB              " 5E REPORT",0
ASM_SMOKE_MSG_T_SYMBOLS:
                        DB              " 60 SYMBOLS",0
ASM_SMOKE_MSG_T_ASMTEST:
                        DB              " 70 ASMTEST",0
ASM_SMOKE_MSG_T_LONG:  DB              " 80 LONG LINE",0
ASM_SMOKE_MSG_T_END:   DB              " 90 END",0
ASM_SMOKE_MSG_W:       DB              "W=$",0
ASM_SMOKE_MSG_SYM:     DB              " SYM=$",0
ASM_SMOKE_MSG_PC:      DB              " PC=$",0
                        ENDIF
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_REPORT_MSG_TITLE:  DB              "ASM REPORT",0
ASM_REPORT_MSG_STATUS: DB              "STATUS=",0
ASM_REPORT_MSG_OK:     DB              "OK",0
ASM_REPORT_MSG_ERRLINE:
                        DB              "ERRLINE=$",0
ASM_REPORT_MSG_START:  DB              "START=$",0
ASM_REPORT_MSG_PC:     DB              "PC=$",0
ASM_REPORT_MSG_HIGH:   DB              "HIGH=$",0
ASM_REPORT_MSG_BYTES:  DB              "BYTES=$",0
ASM_REPORT_MSG_LINES:  DB              "LINES=$",0
ASM_REPORT_MSG_SYMS:   DB              "SYMS=$",0
ASM_REPORT_MSG_FIXUPS: DB              "FIXUPS=$",0
ASM_REPORT_MSG_REFS:   DB              "REFS=$",0
ASM_REPORT_MSG_TRUNC_YES:
                        DB              "TRUNC=YES",0
ASM_REPORT_MSG_TRUNC_NO:
                        DB              "TRUNC=NO",0
ASM_REPORT_MSG_USED:   DB              "USED",0
ASM_REPORT_MSG_UNUSED: DB              "UNUSED",0
ASM_REPORT_MSG_DEF:    DB              " DEF=$",0
ASM_REPORT_MSG_USED_REFS:
                        DB              " REFS=$",0
ASM_REPORT_MSG_USED_FIRST:
                        DB              " FIRST=$",0
                        ENDIF
ASM_SEAL_MSG_OK:       DB              "SEAL OK FLAGS=$",0
ASM_SEAL_MSG_BASE:     DB              " BASE=$",0
ASM_SEAL_MSG_END:      DB              " END=$",0
ASM_SEAL_MSG_REC:      DB              "SEAL REC @=$",0
ASM_SEAL_MSG_LEN:      DB              " LEN=$",0
ASM_SEAL_MSG_FNV:      DB              " FNV=$",0
ASM_SEAL_MSG_REL:      DB              "SEAL REL @=$",0
ASM_SEAL_MSG_EXP:      DB              "SEAL EXP @=$",0
ASM_SEAL_MSG_IMP:      DB              "SEAL IMP @=$",0
ASM_SEAL_MSG_COUNT:    DB              " COUNT=$",0
ASM_TABLE_MSG_TITLE:   DB              "ASM TABLES",0
ASM_TABLE_MSG_SYMBOLS: DB              "SYMBOLS",0
ASM_TABLE_MSG_SYM_HEAD:
                        DB              "SL ST VALUE K  W  FL DEF  USE FIRST NAME",0
ASM_TABLE_MSG_FIXUPS:  DB              "FIXUPS",0
ASM_TABLE_MSG_FIX_HEAD:
                        DB              "SL ST MODE SEL SITE BASE NAME",0
ASM_TABLE_MSG_RELOCS:  DB              "RELOCS",0
ASM_TABLE_MSG_RELOC_HEAD:
                        DB              "SL K  SITE TARG",0
                        IF              ASM_RUNTIME_ONLY
                        ELSE
ASM_SMOKE_LINE_LONG:
                        DB              "12345678901234567890123456789012"
                        DB              "34567890123456789012345678901234",0
                        ENDIF

; Vocabulary slots are canonical-token sorted except IMPORT, which deliberately
; reuses the old ENTRY parked slot so existing opcode ids do not shift.
; A ADC AND ASL BBR BBS BCC BCS BEQ BIT BMI BNE BPL BRA BRK BVC BVS CLC
; CLD CLI CLV CMP CPX CPY DB DC DEC DEX DEY DS DW END IMPORT EOR EQU EXPORT
; INC
; INX INY JMP JSR LDA LDX LDY LSR NOP ORA ORG PHA PHP PHX PHY PLA PLP
; PLX PLY RMB ROL ROR RTI RTS SBC SEC SED SEI SMB STA START STP STX STY
; STZ TAX TAY TRB TSB TSX TXA TXS TYA WAI X Y.
ASM_VOC_HASH0:         DB              $CC,$41,$C6,$93,$35,$A2,$63,$33,$C3,$50,$43,$BC,$B9,$DC,$9A,$DE
                        DB              $0E,$1B,$FA,$A9,$A4,$47,$FA,$8D,$83,$F0,$F3,$4E,$E1,$C0,$0C,$0A
                        DB              $D4,$1D,$62,$B3,$67,$32,$C5,$E0,$48,$34,$FF,$6C,$4E,$5E,$9F,$79
                        DB              $4C,$0F,$A7,$14,$A8,$0B,$73,$E0,$1E,$66,$54,$0E,$20,$D9,$92,$B3
                        DB              $04,$6D,$39,$3F,$D6,$6E,$01,$48,$5A,$ED,$13,$76,$B8,$40,$96,$7D
                        DB              $B4,$27,$94
ASM_VOC_HASH1:         DB              $F6,$57,$6D,$75,$D2,$D0,$03,$EA,$77,$F6,$25,$6D,$54,$5A,$6A,$3D
                        DB              $57,$5E,$65,$54,$49,$F3,$21,$23,$75,$73,$FA,$22,$23,$5A,$61,$92
                        DB              $94,$F0,$E2,$77,$B3,$8F,$90,$0A,$45,$D9,$B4,$B3,$7B,$41,$0A,$07
                        DB              $BA,$D5,$E1,$E0,$D0,$B9,$AC,$AA,$68,$10,$39,$3A,$11,$1B,$71,$69
                        DB              $7B,$46,$D4,$A6,$EB,$F8,$FA,$F5,$02,$03,$3C,$91,$81,$CF,$EB,$8E
                        DB              $8F,$1E,$1C
ASM_VOC_HASH2:         DB              $0B,$75,$66,$AD,$74,$74,$73,$72,$63,$81,$77,$7F,$97,$9C,$9C,$93
                        DB              $93,$6A,$6A,$6A,$6A,$6C,$25,$25,$CE,$CE,$0E,$0F,$0F,$CE,$CE,$43
                        DB              $65,$45,$4B,$F4,$C3,$C3,$C3,$85,$80,$47,$47,$47,$5D,$EE,$F8,$F8
                        DB              $F9,$F9,$F9,$F9,$EF,$EF,$EF,$EF,$E2,$E8,$E8,$AA,$AA,$F0,$01,$01
                        DB              $01,$15,$25,$94,$25,$25,$25,$25,$34,$34,$58,$56,$56,$71,$71,$6E
                        DB              $1F,$0C,$0C
ASM_VOC_HASH3:         DB              $C4,$7C,$91,$57,$AD,$AC,$F4,$E4,$A2,$E5,$BA,$B6,$A3,$FA,$04,$E4
                        DB              $F4,$56,$5B,$50,$49,$8D,$47,$48,$36,$35,$47,$60,$61,$25,$29,$AF
                        DB              $76,$C3,$B0,$A5,$EB,$D4,$D5,$48,$1A,$E4,$CD,$CC,$CD,$A7,$E0,$DE
                        DB              $8E,$9F,$A7,$A6,$F6,$E7,$DF,$DE,$B1,$6F,$89,$CC,$B2,$35,$3E,$39
                        DB              $44,$6F,$F8,$0D,$07,$0F,$10,$0D,$35,$36,$D5,$33,$29,$D2,$E4,$2E
                        DB              $AF,$DD,$DC
ASM_VOC_KIND_TAB:      DB              $03,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
                        DB              $01,$01,$01,$01,$01,$01,$01,$01,$02,$04,$01,$01,$01,$02,$02,$02
                        DB              $02,$01,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02
                        DB              $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
                        DB              $01,$01,$01,$04,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
                        DB              $01,$03,$03

                        IF              ASM_RUNTIME_ONLY
                        UDATA
                        IF              ASM_FLASH_RUNTIME
ASM_CODE_BUF:           DS              $0008
                        ELSE
ASM_CODE_BUF:           DS              $0100
                        ENDIF
                        ELSE
                        IF              ASM_FLASH_RUNTIME
                        UDATA
                        ENDIF
ASM_CODE_BUF:           DS              $0200
                        ENDIF

                        ENDMOD
                        END

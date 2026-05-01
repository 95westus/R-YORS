; ----------------------------------------------------------------------------
; Shared fixed-address workspace/constants for Himonia monitor builds.
; Grouped by usage and packed to coalesce low free space.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; User program area and high-RAM ownership boundaries.
; ----------------------------------------------------------------------------
UPA_BASE                   EQU             $2000
UPA_END                    EQU             $77FF
HIUPA                      EQU             $7800
HIUPA_END                  EQU             $79FF

; ----------------------------------------------------------------------------
; Group A: NMI trap/resume context (8 bytes)
; ----------------------------------------------------------------------------
NMI_CTX_FLAG               EQU             $7EF0
NMI_CTX_A                  EQU             $7EF1
NMI_CTX_X                  EQU             $7EF2
NMI_CTX_Y                  EQU             $7EF3
NMI_CTX_P                  EQU             $7EF4
NMI_CTX_PCL                EQU             $7EF5
NMI_CTX_PCH                EQU             $7EF6
NMI_CTX_S                  EQU             $7EF7

; high-state blocks are allocated in other modules:
; - PIA state/lock: $7EE0-$7EE5
; - reset signature $7EE6-$7EE9
; - trap/reserve:   $7EEA-$7EEF
; - NMI context:    $7EF0-$7EF7
; - RAM vectors:    $7EF8-$7EFF

RESET_SIG0                EQU             $7EE6
RESET_SIG1                EQU             $7EE7
RESET_SIG2                EQU             $7EE8
RESET_SIG3                EQU             $7EE9

; ----------------------------------------------------------------------------
; Group D: monitor/parser/load workspace (packed into the high 7E page)
; ----------------------------------------------------------------------------
; 7E page map:
; - $7E00-$7E45 free buffer spill/scratch after page buffers
; - $7E46-$7E65 debugger/assembler workspace
; - $7E66-$7E75 hash/exec metadata
; - $7E76-$7E94 command/parser/keytest workspace
; - $7E95-$7EDD loader workspace and range table
; - $7EDE-$7EDF delay helper fixed RAM
; - $7EE0-$7EFF PIA/reset/trap/NMI/vector state
; ----------------------------------------------------------------------------
CMD_LEN                    EQU             $7E76
CMD_LINE_STATUS            EQU             $7E77
CMD_HOOK_DISPLAY_LO        EQU             $7E78
CMD_HOOK_DISPLAY_HI        EQU             $7E79
CMD_HOOK_FILL_LO           EQU             $7E7A
CMD_HOOK_FILL_HI           EQU             $7E7B
CMD_HOOK_COPY_LO           EQU             $7E7C
CMD_HOOK_COPY_HI           EQU             $7E7D
CMD_HOOK_MODIFY_LO         EQU             $7E7E
CMD_HOOK_MODIFY_HI         EQU             $7E7F
CMD_HOOK_HELP_LO           EQU             $7E80
CMD_HOOK_HELP_HI           EQU             $7E81
CMD_HOOK_LOAD_LO           EQU             $7E82
CMD_HOOK_LOAD_HI           EQU             $7E83
CMD_HOOK_KEYTEST_LO        EQU             $7E84
CMD_HOOK_KEYTEST_HI        EQU             $7E85
CMD_HOOK_QUIT_LO           EQU             $7E86
CMD_HOOK_QUIT_HI           EQU             $7E87
CMD_HOOK_UNKNOWN_LO        EQU             $7E88
CMD_HOOK_UNKNOWN_HI        EQU             $7E89
CMD_DISP_NEXT_LO           EQU             $7E8A
CMD_DISP_NEXT_HI           EQU             $7E8B
CMD_RANGE_START_LO         EQU             $7E8C
CMD_RANGE_START_HI         EQU             $7E8D
CMD_RANGE_END_LO           EQU             $7E8E
CMD_RANGE_END_HI           EQU             $7E8F
CMD_RANGE_TMP_LO           EQU             $7E90
CMD_RANGE_TMP_HI           EQU             $7E91

; ----------------------------------------------------------------------------
; Monitor/parser hot ZP window (function-grouped, off the old $F0-$F5 set)
; ----------------------------------------------------------------------------
CMD_PATTERN_INDEX          EQU             $F0
CMD_PATTERN_COUNT          EQU             $F1
CMD_IO_TMP                 EQU             $F2
CMD_FLAGS                  EQU             $F3
CMDP_LINE_REMAIN           EQU             $F4
CMDP_REMAIN                EQU             $F5
CMDP_NIB_HI                EQU             $F6
CMDP_BYTE_TMP              EQU             $F7
CMDP_ENTRY_LEN             EQU             $F8
CMDP_TOKEN_LEN             EQU             $F9
CMDP_START_LO              EQU             $FA
CMDP_START_HI              EQU             $FB
CMDP_ADDR_LO               EQU             $FC
CMDP_ADDR_HI               EQU             $FD
CMDP_PTR_LO                EQU             $FE
CMDP_PTR_HI                EQU             $FF

CMDP_MOD_COUNT             EQU             $7E92
KEYT_CHAR                  EQU             $7E93
KEYT_ESC_BYTE              EQU             $7E94

; ----------------------------------------------------------------------------
; LOAD (S-Record) workspace
; ----------------------------------------------------------------------------
LOAD_LINE_STATUS           EQU             $7E95
LOAD_REC_TYPE              EQU             $7E96
LOAD_FLASH_MODE            EQU             $7E96
LOAD_REC_KIND              EQU             $7E97
LOAD_ADDR_LEN              EQU             $7E98
LOAD_FAIL_CODE             EQU             $7E98
LOAD_COUNT                 EQU             $7E99
LOAD_DATA_LEN              EQU             $7E9A
LOAD_SUM                   EQU             $7E9B
LOAD_CHK                   EQU             $7E9C
LOAD_FLASH_OLD             EQU             $7E9C
LOAD_DST_LO                EQU             $7E9D
LOAD_DST_HI                EQU             $7E9E
LOAD_GO_LO                 EQU             $7E9F
LOAD_GO_HI                 EQU             $7EA0
LOAD_GO_VALID              EQU             $7EA1
LOAD_TOTAL_LO              EQU             $7EA2
LOAD_TOTAL_HI              EQU             $7EA3
LOAD_REC_LO                EQU             $7EA4
LOAD_REC_HI                EQU             $7EA5
LOAD_FAIL_ADDR_LO          EQU             $7EA4
LOAD_FAIL_ADDR_HI          EQU             $7EA5
LOAD_ADDR_B0               EQU             $7EA6
LOAD_ADDR_B1               EQU             $7EA7
LOAD_ADDR_B2               EQU             $7EA8
LOAD_ADDR_B3               EQU             $7EA9
LOAD_ABORT_MODE            EQU             $7EA6
LOAD_WRITE_OK              EQU             $7EA7
LOAD_SKIP_LO               EQU             $7EA8
LOAD_SKIP_HI               EQU             $7EA9
LOAD_AUTO_GO               EQU             $7EAA
LOAD_HAVE_DATA             EQU             $7EAB
LOAD_FIRST_LO              EQU             $7EAC
LOAD_FIRST_HI              EQU             $7EAD
LOAD_LAST_LO               EQU             $7EAE
LOAD_LAST_HI               EQU             $7EAF
LOAD_CUR_START_LO          EQU             $7EB0
LOAD_CUR_START_HI          EQU             $7EB1
LOAD_CUR_END_LO            EQU             $7EB2
LOAD_CUR_END_HI            EQU             $7EB3
LOAD_RANGE_COUNT           EQU             $7EB4
LOAD_RANGE_OVF             EQU             $7EB5
LOAD_TMP_LO                EQU             $7EB6
LOAD_TMP_HI                EQU             $7EB7
LOAD_LEN_LO                EQU             $7EB8
LOAD_LEN_HI                EQU             $7EB9
LOAD_SPAN_LO               EQU             $7EBA
LOAD_SPAN_HI               EQU             $7EBB
LOAD_PRINT_COUNT           EQU             $7EBC
LOAD_CUR_VALID             EQU             $7EBD

LOAD_REC_KIND_DATA         EQU             $01
LOAD_REC_KIND_TERM         EQU             $02
LOAD_REC_KIND_SKIP         EQU             $03

LOAD_FAIL_NONE             EQU             $00
LOAD_FAIL_PARSE            EQU             $01
LOAD_FAIL_PROTECT          EQU             $02
LOAD_FAIL_ERASE            EQU             $03
LOAD_FAIL_WRITE            EQU             $04
LOAD_FAIL_NEED_FLASH       EQU             $05

LOAD_RANGE_MAX             EQU             $08
LOAD_DATA_MAX              EQU             $40
LOAD_RANGE_BASE            EQU             $7EBE

; ----------------------------------------------------------------------------
; Group F: Himonia debugger workspace
; ----------------------------------------------------------------------------
DBG_BP_MAX                 EQU             $04
DBG_BP_STRIDE              EQU             $04
DBG_BP_BASE                EQU             $7E46
DBG_BP0_LO                 EQU             $7E46
DBG_BP0_HI                 EQU             $7E47
DBG_BP0_OP                 EQU             $7E48
DBG_BP0_FLG                EQU             $7E49
DBG_STEP_LO                EQU             $7E56
DBG_STEP_HI                EQU             $7E57
DBG_STEP_OP                EQU             $7E58
DBG_STEP_FLG               EQU             $7E59
DBG_TMP_LO                 EQU             $7E5A
DBG_TMP_HI                 EQU             $7E5B
DBG_TMP_OP                 EQU             $7E5C
DBG_TMP_MODE               EQU             $7E5D
DBG_TMP_LEN                EQU             $7E5E
DBG_TMP_OPCODE             EQU             $7E5F
DBG_TMP_FLAGS              EQU             $7E60
DBG_TMP_INDEX              EQU             $7E61
DBG_ASM_OP0                EQU             $7E62
DBG_ASM_OP1                EQU             $7E63
DBG_ASM_OP2                EQU             $7E64
DBG_ASM_OP3                EQU             $7E65

DBG_BPF_ACTIVE             EQU             $01

ASM_MODE_INVALID           EQU             $00
ASM_MODE_IMPL              EQU             $01
ASM_MODE_ACC               EQU             $02
ASM_MODE_IMM               EQU             $03
ASM_MODE_ZP                EQU             $04
ASM_MODE_ZPX               EQU             $05
ASM_MODE_ZPY               EQU             $06
ASM_MODE_ZPX_IND           EQU             $07
ASM_MODE_ZP_IND            EQU             $08
ASM_MODE_ZP_IND_Y          EQU             $09
ASM_MODE_ABS               EQU             $0A
ASM_MODE_ABSX              EQU             $0B
ASM_MODE_ABSY              EQU             $0C
ASM_MODE_ABS_IND           EQU             $0D
ASM_MODE_ABSX_IND          EQU             $0E
ASM_MODE_REL               EQU             $0F
ASM_MODE_ZP_REL            EQU             $10
ASM_MODE_BRK               EQU             $11

ASM_SH_NONE                EQU             $00
ASM_SH_ACC                 EQU             $01
ASM_SH_IMM                 EQU             $02
ASM_SH_NUM                 EQU             $03
ASM_SH_NUM_X               EQU             $04
ASM_SH_NUM_Y               EQU             $05
ASM_SH_PAREN_NUM           EQU             $06
ASM_SH_PAREN_NUM_X         EQU             $07
ASM_SH_PAREN_NUM_Y         EQU             $08
ASM_SH_ZP_REL              EQU             $09

ASM_MNEM_COUNT             EQU             $62

; ----------------------------------------------------------------------------
; Group E: page-aligned buffers
; ----------------------------------------------------------------------------
SCRATCH_BUF                EQU             $7A00
CMD_BUF                    EQU             $7B00
LOAD_BUF                   EQU             $7C00
LOAD_DATA_BUF              EQU             $7D00

; keep reserved:
; - $0300-$12FF low 4K reserve (no live allocations)
; - $1300-$13FF flash transient / RAM worker page
; - $1400-$1FFF system scratch and transient metadata
; - UPA_BASE-UPA_END user program area
; - HIUPA-HIUPA_END high UPA/scratch area before page buffers

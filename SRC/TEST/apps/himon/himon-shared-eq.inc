; ----------------------------------------------------------------------------
; Shared fixed-address workspace/constants for himon.asm and mon.asm
; Grouped by usage and packed to coalesce low free space.
; ----------------------------------------------------------------------------

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
; - HW reserve:     $7EEA-$7EEF
; - NMI context:    $7EF0-$7EF7
; - RAM vectors:    $7EF8-$7EFF

RESET_SIG0                EQU             $7EE6
RESET_SIG1                EQU             $7EE7
RESET_SIG2                EQU             $7EE8
RESET_SIG3                EQU             $7EE9

; ----------------------------------------------------------------------------
; Group D: monitor/parser/load workspace (moved to high 7E page)
; ----------------------------------------------------------------------------
CMD_LEN                    EQU             $7E60
CMD_LINE_STATUS            EQU             $7E61
CMD_HOOK_DISPLAY_LO        EQU             $7E62
CMD_HOOK_DISPLAY_HI        EQU             $7E63
CMD_HOOK_FILL_LO           EQU             $7E64
CMD_HOOK_FILL_HI           EQU             $7E65
CMD_HOOK_COPY_LO           EQU             $7E66
CMD_HOOK_COPY_HI           EQU             $7E67
CMD_HOOK_MODIFY_LO         EQU             $7E68
CMD_HOOK_MODIFY_HI         EQU             $7E69
CMD_HOOK_HELP_LO           EQU             $7E6A
CMD_HOOK_HELP_HI           EQU             $7E6B
CMD_HOOK_LOAD_LO           EQU             $7E6C
CMD_HOOK_LOAD_HI           EQU             $7E6D
CMD_HOOK_KEYTEST_LO        EQU             $7E6E
CMD_HOOK_KEYTEST_HI        EQU             $7E6F
CMD_HOOK_QUIT_LO           EQU             $7E70
CMD_HOOK_QUIT_HI           EQU             $7E71
CMD_HOOK_UNKNOWN_LO        EQU             $7E72
CMD_HOOK_UNKNOWN_HI        EQU             $7E73
CMD_DISP_NEXT_LO           EQU             $7E74
CMD_DISP_NEXT_HI           EQU             $7E75
CMD_RANGE_START_LO         EQU             $7E76
CMD_RANGE_START_HI         EQU             $7E77
CMD_RANGE_END_LO           EQU             $7E78
CMD_RANGE_END_HI           EQU             $7E79
CMD_RANGE_TMP_LO           EQU             $7E7A
CMD_RANGE_TMP_HI           EQU             $7E7B

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

CMDP_MOD_COUNT             EQU             $7E82
KEYT_CHAR                  EQU             $7E87
KEYT_ESC_BYTE              EQU             $7E88

; ----------------------------------------------------------------------------
; LOAD (S-Record) workspace
; ----------------------------------------------------------------------------
LOAD_LINE_STATUS           EQU             $7E90
LOAD_REC_TYPE              EQU             $7E91
LOAD_REC_KIND              EQU             $7E92
LOAD_ADDR_LEN              EQU             $7E93
LOAD_COUNT                 EQU             $7E94
LOAD_DATA_LEN              EQU             $7E95
LOAD_SUM                   EQU             $7E96
LOAD_CHK                   EQU             $7E97
LOAD_DST_LO                EQU             $7E98
LOAD_DST_HI                EQU             $7E99
LOAD_GO_LO                 EQU             $7E9A
LOAD_GO_HI                 EQU             $7E9B
LOAD_GO_VALID              EQU             $7E9C
LOAD_TOTAL_LO              EQU             $7E9D
LOAD_TOTAL_HI              EQU             $7E9E
LOAD_REC_LO                EQU             $7E9F
LOAD_REC_HI                EQU             $7EA0
LOAD_ADDR_B0               EQU             $7EA1
LOAD_ADDR_B1               EQU             $7EA2
LOAD_ADDR_B2               EQU             $7EA3
LOAD_ADDR_B3               EQU             $7EA4
LOAD_AUTO_GO               EQU             $7EA5
LOAD_HAVE_DATA             EQU             $7EA6
LOAD_FIRST_LO              EQU             $7EA7
LOAD_FIRST_HI              EQU             $7EA8
LOAD_LAST_LO               EQU             $7EA9
LOAD_LAST_HI               EQU             $7EAA
LOAD_CUR_START_LO          EQU             $7EAB
LOAD_CUR_START_HI          EQU             $7EAC
LOAD_CUR_END_LO            EQU             $7EAD
LOAD_CUR_END_HI            EQU             $7EAE
LOAD_RANGE_COUNT           EQU             $7EAF
LOAD_RANGE_OVF             EQU             $7EB0
LOAD_TMP_LO                EQU             $7EB1
LOAD_TMP_HI                EQU             $7EB2
LOAD_LEN_LO                EQU             $7EB3
LOAD_LEN_HI                EQU             $7EB4
LOAD_SPAN_LO               EQU             $7EB5
LOAD_SPAN_HI               EQU             $7EB6
LOAD_PRINT_COUNT           EQU             $7EB7
LOAD_CUR_VALID             EQU             $7EB8

LOAD_REC_KIND_DATA         EQU             $01
LOAD_REC_KIND_TERM         EQU             $02
LOAD_REC_KIND_SKIP         EQU             $03

LOAD_RANGE_MAX             EQU             $08
LOAD_DATA_MAX              EQU             $40
LOAD_RANGE_BASE            EQU             $7EC0

; hole (low in 7E page for coalesced free space): $7E00-$7E5F

; ----------------------------------------------------------------------------
; Group F: Himonia debugger workspace in the low $7E hole
; ----------------------------------------------------------------------------
DBG_BP_MAX                 EQU             $04
DBG_BP_STRIDE              EQU             $04
DBG_BP_BASE                EQU             $7E00
DBG_BP0_LO                 EQU             $7E00
DBG_BP0_HI                 EQU             $7E01
DBG_BP0_OP                 EQU             $7E02
DBG_BP0_FLG                EQU             $7E03
DBG_STEP_LO                EQU             $7E10
DBG_STEP_HI                EQU             $7E11
DBG_STEP_OP                EQU             $7E12
DBG_STEP_FLG               EQU             $7E13
DBG_TMP_LO                 EQU             $7E14
DBG_TMP_HI                 EQU             $7E15
DBG_TMP_OP                 EQU             $7E16
DBG_TMP_MODE               EQU             $7E17
DBG_TMP_LEN                EQU             $7E18
DBG_TMP_OPCODE             EQU             $7E19
DBG_TMP_FLAGS              EQU             $7E1A
DBG_TMP_INDEX              EQU             $7E1B
DBG_ASM_OP0                EQU             $7E1C
DBG_ASM_OP1                EQU             $7E1D
DBG_ASM_OP2                EQU             $7E1E
DBG_ASM_OP3                EQU             $7E1F

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
CMD_BUF                    EQU             $7B00
LOAD_BUF                   EQU             $7C00
LOAD_DATA_BUF              EQU             $7D00

; keep reserved:
; - $0300-$12FF low 4K reserve (no live allocations)

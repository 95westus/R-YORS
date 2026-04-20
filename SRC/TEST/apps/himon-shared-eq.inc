; ----------------------------------------------------------------------------
; Shared fixed-address workspace/constants for himon.asm and mon.asm
; ----------------------------------------------------------------------------
CMD_BUF                    EQU             $7C00
CMD_LEN                    EQU             $7B00
CMD_LINE_STATUS            EQU             $7B01
CMDP_PTR_LO                EQU             $F0
CMDP_PTR_HI                EQU             $F1
CMDP_ADDR_LO               EQU             $F2
CMDP_ADDR_HI               EQU             $F3
CMDP_START_LO              EQU             $F4
CMDP_START_HI              EQU             $F5

CMDP_REMAIN                EQU             $7B20
CMDP_LINE_REMAIN           EQU             $7B21
CMDP_MOD_COUNT             EQU             $7B22
CMDP_NIB_HI                EQU             $7B23
CMDP_BYTE_TMP              EQU             $7B24
CMDP_TOKEN_LEN             EQU             $7B25
CMDP_ENTRY_LEN             EQU             $7B26
KEYT_CHAR                  EQU             $7B27
KEYT_ESC_BYTE              EQU             $7B28

; ----------------------------------------------------------------------------
; LOAD (S-Record) workspace
; ----------------------------------------------------------------------------
LOAD_LINE_STATUS           EQU             $7B30
LOAD_REC_TYPE              EQU             $7B31
LOAD_REC_KIND              EQU             $7B32
LOAD_ADDR_LEN              EQU             $7B33
LOAD_COUNT                 EQU             $7B34
LOAD_DATA_LEN              EQU             $7B35
LOAD_SUM                   EQU             $7B36
LOAD_CHK                   EQU             $7B37
LOAD_DST_LO                EQU             $7B38
LOAD_DST_HI                EQU             $7B39
LOAD_GO_LO                 EQU             $7B3A
LOAD_GO_HI                 EQU             $7B3B
LOAD_GO_VALID              EQU             $7B3C
LOAD_TOTAL_LO              EQU             $7B3D
LOAD_TOTAL_HI              EQU             $7B3E
LOAD_REC_LO                EQU             $7B3F
LOAD_REC_HI                EQU             $7B40
LOAD_ADDR_B0               EQU             $7B41
LOAD_ADDR_B1               EQU             $7B42
LOAD_ADDR_B2               EQU             $7B43
LOAD_ADDR_B3               EQU             $7B44
LOAD_AUTO_GO               EQU             $7B45
LOAD_HAVE_DATA             EQU             $7B46
LOAD_FIRST_LO              EQU             $7B47
LOAD_FIRST_HI              EQU             $7B48
LOAD_LAST_LO               EQU             $7B49
LOAD_LAST_HI               EQU             $7B4A
LOAD_CUR_START_LO          EQU             $7B4B
LOAD_CUR_START_HI          EQU             $7B4C
LOAD_CUR_END_LO            EQU             $7B4D
LOAD_CUR_END_HI            EQU             $7B4E
LOAD_RANGE_COUNT           EQU             $7B4F
LOAD_RANGE_OVF             EQU             $7B50
LOAD_TMP_LO                EQU             $7B51
LOAD_TMP_HI                EQU             $7B52
LOAD_LEN_LO                EQU             $7B53
LOAD_LEN_HI                EQU             $7B54
LOAD_SPAN_LO               EQU             $7B55
LOAD_SPAN_HI               EQU             $7B56
LOAD_PRINT_COUNT           EQU             $7B57
LOAD_CUR_VALID             EQU             $7B58

LOAD_REC_KIND_DATA         EQU             $01
LOAD_REC_KIND_TERM         EQU             $02
LOAD_REC_KIND_SKIP         EQU             $03

LOAD_RANGE_MAX             EQU             $08
LOAD_DATA_MAX              EQU             $40
LOAD_BUF                   EQU             $7D00
LOAD_DATA_BUF              EQU             $7E00
LOAD_RANGE_BASE            EQU             $7B60

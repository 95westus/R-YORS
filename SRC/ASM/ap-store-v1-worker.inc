; ----------------------------------------------------------------------------
; AP Store V1 transient single-sector worker contract.
;
; This is not part of ASM ABI v1.  The worker is a foreground tool loaded at
; $7000 and owns this portion of the existing STR8 High Tool Overlay only for
; the duration of PREPARE/EXECUTE.  It allocates no permanent RAM.
; ----------------------------------------------------------------------------

APSW_LOAD_BASE              EQU             $7000
APSW_PREPARE_ENTRY          EQU             $7000
APSW_EXECUTE_ENTRY          EQU             $7003
APSW_LIMIT_EXCLUSIVE        EQU             $7C00

APSW_CARD_BASE              EQU             STR8_HIGH_TOOL_BASE
APSW_OP                     EQU             APSW_CARD_BASE+$00
APSW_BANK                   EQU             APSW_CARD_BASE+$01
APSW_SECTOR                 EQU             APSW_CARD_BASE+$02
APSW_CONFIRM                EQU             APSW_CARD_BASE+$03
APSW_PREP_CRC_LO            EQU             APSW_CARD_BASE+$04
APSW_PREP_CRC_HI            EQU             APSW_CARD_BASE+$05
APSW_STATUS                 EQU             APSW_CARD_BASE+$06
APSW_CLASS                  EQU             APSW_CARD_BASE+$07
APSW_FLAGS                  EQU             APSW_CARD_BASE+$08
APSW_GENERATION_LO          EQU             APSW_CARD_BASE+$09
APSW_GENERATION_HI          EQU             APSW_CARD_BASE+$0A
APSW_FAIL_PHASE             EQU             APSW_CARD_BASE+$0B
APSW_FAIL_ADDR_LO           EQU             APSW_CARD_BASE+$0C
APSW_FAIL_ADDR_HI           EQU             APSW_CARD_BASE+$0D
APSW_CURRENT_CRC_LO         EQU             APSW_CARD_BASE+$0E
APSW_CURRENT_CRC_HI         EQU             APSW_CARD_BASE+$0F
APSW_HEADER_BASE            EQU             APSW_CARD_BASE+$10
APSW_PRIVATE_BASE           EQU             APSW_CARD_BASE+$20
APSW_PREP_OP                EQU             APSW_PRIVATE_BASE+$00
APSW_PREP_BANK              EQU             APSW_PRIVATE_BASE+$01
APSW_PREP_SECTOR            EQU             APSW_PRIVATE_BASE+$02
APSW_PREP_CLASS             EQU             APSW_PRIVATE_BASE+$03
APSW_PREP_FLAGS             EQU             APSW_PRIVATE_BASE+$04
APSW_PREP_GENERATION_LO     EQU             APSW_PRIVATE_BASE+$05
APSW_PREP_GENERATION_HI     EQU             APSW_PRIVATE_BASE+$06
APSW_HASH0                  EQU             APSW_PRIVATE_BASE+$08
APSW_HASH1                  EQU             APSW_PRIVATE_BASE+$09
APSW_HASH2                  EQU             APSW_PRIVATE_BASE+$0A
APSW_HASH3                  EQU             APSW_PRIVATE_BASE+$0B
APSW_TERM0                  EQU             APSW_PRIVATE_BASE+$0C
APSW_TERM1                  EQU             APSW_PRIVATE_BASE+$0D
APSW_TERM2                  EQU             APSW_PRIVATE_BASE+$0E
APSW_TERM3                  EQU             APSW_PRIVATE_BASE+$0F
APSW_CARD_END               EQU             APSW_CARD_BASE+$2F

APSW_OP_CLAIM               EQU             $01
APSW_OP_CONVERT             EQU             $02
APSW_OP_FORMAT              EQU             $03
APSW_CONFIRM_EXECUTE        EQU             $A5

APSW_STATUS_IDLE            EQU             $00
APSW_STATUS_PREPARED        EQU             $A0
APSW_STATUS_OK              EQU             $AC
APSW_STATUS_BAD_REQUEST     EQU             $E0
APSW_STATUS_SELECT_FAILED   EQU             $E1
APSW_STATUS_OCCUPIED        EQU             $E2
APSW_STATUS_NOT_MANAGED     EQU             $E3
APSW_STATUS_SECTOR_IN_USE   EQU             $E4
APSW_STATUS_GEN_EXHAUSTED   EQU             $E5
APSW_STATUS_MEDIA_CHANGED   EQU             $E6
APSW_STATUS_NOT_CONFIRMED   EQU             $E7
APSW_STATUS_ERASE_FAILED    EQU             $E8
APSW_STATUS_PROGRAM_FAILED  EQU             $E9
APSW_STATUS_VERIFY_FAILED   EQU             $EA
APSW_STATUS_RESTORE_FAILED  EQU             $EB
APSW_STATUS_ALREADY_MANAGED EQU             $EC
APSW_STATUS_NOT_OCCUPIED    EQU             $ED

APSW_CLASS_HEADER_FF        EQU             $00
APSW_CLASS_OPAQUE           EQU             $01
APSW_CLASS_CORRUPT          EQU             $02
APSW_CLASS_STAGED           EQU             $03
APSW_CLASS_ACTIVE           EQU             $04
APSW_CLASS_RETIRED          EQU             $05
APSW_CLASS_BAD              EQU             $06
APSW_CLASS_RETIRED_BAD      EQU             $07

APSW_FLAG_FULL_ERASED       EQU             $01
APSW_FLAG_TAIL_ERASED       EQU             $02

APSW_PHASE_NONE             EQU             $00
APSW_PHASE_SCAN             EQU             $01
APSW_PHASE_POLICY           EQU             $02
APSW_PHASE_ERASE            EQU             $03
APSW_PHASE_ERASE_VERIFY     EQU             $04
APSW_PHASE_HEADER_WRITE     EQU             $05
APSW_PHASE_HEADER_VERIFY    EQU             $06
APSW_PHASE_COMMIT           EQU             $07
APSW_PHASE_RESTORE          EQU             $08

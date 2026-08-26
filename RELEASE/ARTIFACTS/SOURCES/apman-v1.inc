; ----------------------------------------------------------------------------
; APMAN V1 request/result card shared by HIMON, ASM-F2, and the carrier.
;
; APMAN is a fixed-load AP body at $7000. HIMON owns discovery/loading; the
; manager owns carrier lookup, load/execute, status, and sector installation.
; The card is foreground scratch, not persistent media and not an ABI promise
; to STR8-N.
; ----------------------------------------------------------------------------

APMAN_ENTRY                EQU             $7000
APMAN_LIMIT_EXCLUSIVE      EQU             $7C00

APMAN_CARD_BASE            EQU             $7C60
APMAN_MODE                 EQU             APMAN_CARD_BASE+$00
APMAN_STATUS               EQU             APMAN_CARD_BASE+$01
APMAN_INSTALL_SRC_LO       EQU             APMAN_CARD_BASE+$02
APMAN_INSTALL_SRC_HI       EQU             APMAN_CARD_BASE+$03
APMAN_INSTALL_BANK         EQU             APMAN_CARD_BASE+$04
APMAN_CONFIRM              EQU             APMAN_CARD_BASE+$05
APMAN_FOUND_BANK           EQU             APMAN_CARD_BASE+$06
APMAN_FOUND_SECTOR_HI      EQU             APMAN_CARD_BASE+$07
APMAN_FOUND_PKG_LEN_LO     EQU             APMAN_CARD_BASE+$08
APMAN_FOUND_PKG_LEN_HI     EQU             APMAN_CARD_BASE+$09
APMAN_FOUND_LOAD_LO        EQU             APMAN_CARD_BASE+$0A
APMAN_FOUND_LOAD_HI        EQU             APMAN_CARD_BASE+$0B
APMAN_FOUND_ENTRY_LO       EQU             APMAN_CARD_BASE+$0C
APMAN_FOUND_ENTRY_HI       EQU             APMAN_CARD_BASE+$0D
APMAN_FAIL_PHASE           EQU             APMAN_CARD_BASE+$0E
APMAN_MATCH_COUNT          EQU             APMAN_CARD_BASE+$0F
APMAN_NAME_HASH0           EQU             APMAN_CARD_BASE+$10
APMAN_NAME_HASH1           EQU             APMAN_CARD_BASE+$11
APMAN_NAME_HASH2           EQU             APMAN_CARD_BASE+$12
APMAN_NAME_HASH3           EQU             APMAN_CARD_BASE+$13

APMAN_MODE_AP              EQU             $01
APMAN_MODE_APS             EQU             $02
APMAN_MODE_INSTALL         EQU             $03

APMAN_CONFIRM_INSTALL      EQU             $A5

APMAN_STATUS_IDLE          EQU             $00
APMAN_STATUS_OK            EQU             $AC
APMAN_STATUS_BAD_COMMAND   EQU             $D0
APMAN_STATUS_NOT_FOUND     EQU             $D1
APMAN_STATUS_DUPLICATE     EQU             $D2
APMAN_STATUS_BAD_PACKAGE   EQU             $D3
APMAN_STATUS_BAD_RANGE     EQU             $D4
APMAN_STATUS_NO_SPACE      EQU             $D5
APMAN_STATUS_PROTECTED     EQU             $D6
APMAN_STATUS_NOT_CONFIRMED EQU             $D7
APMAN_STATUS_PROGRAM_FAIL  EQU             $D8
APMAN_STATUS_RESTORE_FAIL  EQU             $D9
APMAN_STATUS_NO_MANAGER    EQU             $DA
APMAN_STATUS_SELF          EQU             $DB

APMAN_PHASE_NONE           EQU             $00
APMAN_PHASE_PARSE          EQU             $01
APMAN_PHASE_SCAN           EQU             $02
APMAN_PHASE_LOAD           EQU             $03
APMAN_PHASE_INSTALL_SCAN   EQU             $04
APMAN_PHASE_PROGRAM        EQU             $05
APMAN_PHASE_RESTORE        EQU             $06

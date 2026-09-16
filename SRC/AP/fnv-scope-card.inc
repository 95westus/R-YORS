; Private foreground scoped-search card. Not a published service ABI.
; Lifetime/overlay contract: DOC/GUIDES/AP/HIMON_AP_SCOPED_RAM_CONTRACT.md.
; Shared by the resident finder and its live APMAN candidate callback.
FNV_SCOPE_BASE           EQU             $7D40
FNV_REQUEST_BANKS        EQU             FNV_SCOPE_BASE+$00
FNV_ALLOWED_BANKS        EQU             FNV_SCOPE_BASE+$01
FNV_EFFECTIVE_BANKS      EQU             FNV_SCOPE_BASE+$02
FNV_BANK_WINDOWS         EQU             FNV_SCOPE_BASE+$03
FNV_RAM_ENABLE           EQU             FNV_SCOPE_BASE+$04
FNV_RAM_WINDOWS          EQU             FNV_SCOPE_BASE+$05
FNV_FORMAT               EQU             FNV_SCOPE_BASE+$06
FNV_WANTED_HASH0         EQU             FNV_SCOPE_BASE+$07
FNV_MATCH_COUNT          EQU             FNV_SCOPE_BASE+$0B
FNV_FOUND_SOURCE         EQU             FNV_SCOPE_BASE+$0C
FNV_FOUND_BANK           EQU             FNV_SCOPE_BASE+$0D
FNV_FOUND_WINDOW         EQU             FNV_SCOPE_BASE+$0E
FNV_FOUND_ADDR_LO        EQU             FNV_SCOPE_BASE+$0F
FNV_FOUND_ADDR_HI        EQU             FNV_SCOPE_BASE+$10
FNV_SCAN_BANK            EQU             FNV_SCOPE_BASE+$11
FNV_SCAN_WINDOW          EQU             FNV_SCOPE_BASE+$12
FNV_NAME_LO              EQU             FNV_SCOPE_BASE+$13
FNV_NAME_HI              EQU             FNV_SCOPE_BASE+$14
FNV_NAME_LEN             EQU             FNV_SCOPE_BASE+$15
FNV_VALIDATE_LO          EQU             FNV_SCOPE_BASE+$16
FNV_VALIDATE_HI          EQU             FNV_SCOPE_BASE+$17
FNV_SCOPE_END            EQU             FNV_SCOPE_BASE+$20
FNV_FORMAT_AP_EXPORT    EQU             $01
FNV_SCOPE_FIND_OP        EQU             $06
FNV_SCOPE_MANAGER_OP     EQU             $07
; APMAN foreground cursors and entry-row pointer, preserved by resident PARSE.
FNV_ACTIVE_BANK         EQU             $A7
FNV_ACTIVE_SECTOR       EQU             $A8
FNV_ROW_LO              EQU             $AC
FNV_ROW_HI              EQU             $AD

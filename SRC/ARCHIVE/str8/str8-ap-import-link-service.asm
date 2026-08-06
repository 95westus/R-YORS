; ----------------------------------------------------------------------------
; Retired STR8 AP import-link compatibility doorway
;
; Removed from active STR8 during the V1 journaled-I split-worker work. AP
; parsing, FNV import resolution, and relocation remain HIMON responsibilities.
; This source is preserved for later reference; it is not part of a build.
; ----------------------------------------------------------------------------

                        XDEF            STR8_AP_IMPORT_LINK_SERVICE

HIM_SVC_AP_LO           EQU             $7E2D
HIM_AP_OP               EQU             $7E2F
HIM_AP_OP_LINK          EQU             $03

; Former fixed doorway at $F006.
STR8_AP_IMPORT_LINK_SERVICE:
                        JMP             STR8_AP_IMPORT_LINK_SERVICE_BODY

; Former eight-byte resident adapter body.
STR8_AP_IMPORT_LINK_SERVICE_BODY:
                        LDA             #HIM_AP_OP_LINK
                        STA             HIM_AP_OP
                        JMP             (HIM_SVC_AP_LO)

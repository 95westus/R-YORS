; ROUTINE: HIM_AP_LINK_RESOLVE_SLOT_X
; PURPOSE: Convert a validated AP import slot through HIMON's resident catalog.
; Kept at its original assembly position by AP/ap-link.inc; no wrapper bytes.
; IN: X = validated import slot; HIM_AP_IMPORT_LO/HI = parsed imports section.
; OUT: C=1 and HIM_AP_LINK_RES_LO/HI = address; C=0 on missing/wrong kind, result pair unchanged.
; Uses AP's row walker, then translates its EXEC/DATA kind through HIMON's
; private catalog. A/X/Y/flags and shared resolver/FNV scratch are volatile.
; Caller owns import-count/slot bounds and signed-addend application.
; This static interface is not a new public vector or an external AP ABI.

HIM_AP_LINK_RESOLVE_SLOT_X:
                        JSR             HIM_AP_LINK_IMPORT_ROW_PTR_X
                        BCC             HIM_AP_LINK_RESOLVE_SLOT_FAIL
                        LDY             #$00
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        AND             #HIM_AP_KIND_MASK
                        STA             HIM_AP_LINK_TMP_HI
                        INY
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        STA             FNV_HASH0
                        INY
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        STA             FNV_HASH1
                        INY
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        STA             FNV_HASH2
                        INY
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        STA             FNV_HASH3
                        JSR             THE_JOIN_FIND
                        BCC             HIM_AP_LINK_RESOLVE_SLOT_FAIL
                        PHA
                        LDA             HIM_AP_LINK_TMP_HI
                        CMP             #HIM_AP_KIND_EXEC
                        BEQ             HIM_AP_LINK_REQUIRE_EXEC
                        PLA
                        AND             #CMD_HASH_KIND_EXEC
                        BNE             HIM_AP_LINK_RESOLVE_SLOT_FAIL
                        BRA             HIM_AP_LINK_RESOLVE_SLOT_FOUND
HIM_AP_LINK_REQUIRE_EXEC:
                        PLA
                        AND             #CMD_HASH_KIND_EXEC
                        BEQ             HIM_AP_LINK_RESOLVE_SLOT_FAIL
HIM_AP_LINK_RESOLVE_SLOT_FOUND:
                        LDA             CMDP_ADDR_LO
                        STA             HIM_AP_LINK_RES_LO
                        LDA             CMDP_ADDR_HI
                        STA             HIM_AP_LINK_RES_HI
                        SEC
                        RTS
HIM_AP_LINK_RESOLVE_SLOT_FAIL:
                        CLC
                        RTS

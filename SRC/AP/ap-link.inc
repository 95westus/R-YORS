HIM_AP_IMPORT_LINK:
                        STZ             HIM_AP_STATUS
                        JSR             HIM_AP_LINK_RELOAD_REL_PTR
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_LINK_RELOC_COUNT
                        LDA             HIM_AP_IMPORT_COUNT
                        STA             HIM_AP_LINK_IMPORT_COUNT
                        LDX             #$00
HIM_AP_LINK_VALIDATE:
                        CPX             HIM_AP_LINK_RELOC_COUNT
                        BCS             HIM_AP_LINK_PATCH_START
                        STX             HIM_AP_LINK_INDEX
                        JSR             HIM_AP_LINK_RELOAD_REL_PTR
                        JSR             HIM_AP_RELOC_KIND_X
                        JSR             HIM_AP_IMPORT_KIND_A
                        BCC             HIM_AP_LINK_VALIDATE_NEXT
                        JSR             HIM_AP_RELOC_SITE_OK_X
                        BCC             HIM_AP_LINK_FAIL
                        JSR             HIM_AP_LINK_RESOLVE_ROW_X
                        BCC             HIM_AP_LINK_FAIL
HIM_AP_LINK_VALIDATE_NEXT:
                        LDX             HIM_AP_LINK_INDEX
                        INX
                        BRA             HIM_AP_LINK_VALIDATE

HIM_AP_LINK_PATCH_START:
                        LDX             #$00
HIM_AP_LINK_PATCH:
                        CPX             HIM_AP_LINK_RELOC_COUNT
                        BCS             HIM_AP_LINK_DONE
                        STX             HIM_AP_LINK_INDEX
                        JSR             HIM_AP_LINK_RELOAD_REL_PTR
                        JSR             HIM_AP_RELOC_KIND_X
                        JSR             HIM_AP_IMPORT_KIND_A
                        BCC             HIM_AP_LINK_PATCH_NEXT
                        JSR             HIM_AP_LINK_CAPTURE_ROW_X
                        JSR             HIM_AP_LINK_RESOLVE_ROW_X
                        BCC             HIM_AP_LINK_FAIL
                        JSR             HIM_AP_LINK_PATCH_CAPTURED
HIM_AP_LINK_PATCH_NEXT:
                        LDX             HIM_AP_LINK_INDEX
                        INX
                        BRA             HIM_AP_LINK_PATCH
HIM_AP_LINK_DONE:
                        JSR             HIM_AP_LINK_RESTORE_COUNTS
                        SEC
                        RTS

HIM_AP_LINK_FAIL:
                        JSR             HIM_AP_LINK_RESTORE_COUNTS
                        LDA             #HIM_AP_STATUS_BAD_FIX
                        STA             HIM_AP_STATUS
                        CLC
                        RTS

HIM_AP_LINK_RESTORE_COUNTS:
                        LDA             HIM_AP_LINK_RELOC_COUNT
                        STA             HIM_AP_RELOC_COUNT
                        LDA             HIM_AP_LINK_IMPORT_COUNT
                        STA             HIM_AP_IMPORT_COUNT
                        RTS

HIM_AP_LINK_RELOAD_REL_PTR:
                        LDA             HIM_AP_REL_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_REL_HI
                        STA             CMDP_PTR_HI
                        RTS

HIM_AP_LINK_RESOLVE_ROW_X:
                        JSR             HIM_AP_RELOC_TARGET_LO_X
                        CMP             HIM_AP_LINK_IMPORT_COUNT
                        BCS             HIM_AP_LINK_RESOLVE_ROW_FAIL
                        TAX
                        JSR             HIM_AP_LINK_RESOLVE_SLOT_X
                        BCC             HIM_AP_LINK_RESOLVE_ROW_FAIL
                        LDX             HIM_AP_LINK_INDEX
                        JSR             HIM_AP_LINK_RELOAD_REL_PTR
                        JSR             HIM_AP_RELOC_TARGET_HI_X
                        STA             HIM_AP_LINK_TMP_LO
                        CLC
                        ADC             HIM_AP_LINK_RES_LO
                        STA             HIM_AP_LINK_RES_LO
                        LDA             HIM_AP_LINK_TMP_LO
                        BMI             HIM_AP_LINK_RESOLVE_ADD_NEG
                        LDA             HIM_AP_LINK_RES_HI
                        ADC             #$00
                        BRA             HIM_AP_LINK_RESOLVE_ADD_DONE
HIM_AP_LINK_RESOLVE_ADD_NEG:
                        LDA             HIM_AP_LINK_RES_HI
                        ADC             #$FF
HIM_AP_LINK_RESOLVE_ADD_DONE:
                        STA             HIM_AP_LINK_RES_HI
                        SEC
                        RTS
HIM_AP_LINK_RESOLVE_ROW_FAIL:
                        LDX             HIM_AP_LINK_INDEX
                        CLC
                        RTS

; HIMON owns catalog lookup and resident-kind translation for this AP slot.
                        INCLUDE         "HIMON/himon-ap-resolver.inc"

HIM_AP_LINK_IMPORT_ROW_PTR_X:
                        LDA             HIM_AP_IMPORT_LO
                        STA             HIM_AP_LINK_IMP_PTR_LO
                        LDA             HIM_AP_IMPORT_HI
                        STA             HIM_AP_LINK_IMP_PTR_HI
                        INC             HIM_AP_LINK_IMP_PTR_LO
                        BNE             HIM_AP_LINK_IMPORT_ROW_BODY
                        INC             HIM_AP_LINK_IMP_PTR_HI
HIM_AP_LINK_IMPORT_ROW_BODY:
HIM_AP_LINK_IMPORT_ROW_LOOP:
                        CPX             #$00
                        BEQ             HIM_AP_LINK_IMPORT_ROW_FOUND
                        LDY             #$05
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        JSR             HIM_AP_LINK_IMPORT_ROW_BYTES_A
                        BCC             HIM_AP_LINK_IMPORT_ROW_FAIL
                        CLC
                        ADC             HIM_AP_LINK_IMP_PTR_LO
                        STA             HIM_AP_LINK_IMP_PTR_LO
                        BCC             HIM_AP_LINK_IMPORT_ROW_NEXT
                        INC             HIM_AP_LINK_IMP_PTR_HI
HIM_AP_LINK_IMPORT_ROW_NEXT:
                        DEX
                        BRA             HIM_AP_LINK_IMPORT_ROW_LOOP
HIM_AP_LINK_IMPORT_ROW_FOUND:
                        SEC
                        RTS
HIM_AP_LINK_IMPORT_ROW_FAIL:
                        CLC
                        RTS

HIM_AP_LINK_IMPORT_ROW_BYTES_A:
                        BEQ             HIM_AP_LINK_IMPORT_ROW_BYTES_FAIL
                        STA             HIM_AP_LINK_TMP_LO
                        LDA             #$06
HIM_AP_LINK_IMPORT_ROW_BYTES_LOOP:
                        CLC
                        ADC             #$02
                        DEC             HIM_AP_LINK_TMP_LO
                        BEQ             HIM_AP_LINK_IMPORT_ROW_BYTES_OK
                        DEC             HIM_AP_LINK_TMP_LO
                        BEQ             HIM_AP_LINK_IMPORT_ROW_BYTES_OK
                        DEC             HIM_AP_LINK_TMP_LO
                        BNE             HIM_AP_LINK_IMPORT_ROW_BYTES_LOOP
HIM_AP_LINK_IMPORT_ROW_BYTES_OK:
                        SEC
                        RTS
HIM_AP_LINK_IMPORT_ROW_BYTES_FAIL:
                        CLC
                        RTS

HIM_AP_LINK_CAPTURE_ROW_X:
                        JSR             HIM_AP_RELOC_KIND_X
                        STA             HIM_AP_LINK_PATCH_KIND
                        JSR             HIM_AP_RELOC_SITE_LO_X
                        STA             HIM_AP_LINK_TMP_LO
                        JSR             HIM_AP_RELOC_SITE_HI_X
                        STA             HIM_AP_LINK_TMP_HI
                        LDA             HIM_AP_DST_LO
                        CLC
                        ADC             HIM_AP_LINK_TMP_LO
                        STA             HIM_AP_LINK_PATCH_LO
                        LDA             HIM_AP_DST_HI
                        ADC             HIM_AP_LINK_TMP_HI
                        STA             HIM_AP_LINK_PATCH_HI
                        RTS

HIM_AP_LINK_PATCH_CAPTURED:
                        LDA             HIM_AP_LINK_PATCH_LO
                        STA             HIM_AP_LINK_ADDR_LO
                        LDA             HIM_AP_LINK_PATCH_HI
                        STA             HIM_AP_LINK_ADDR_HI
                        LDA             HIM_AP_LINK_PATCH_KIND
                        CMP             #HIM_AP_RELOC_ABS16_IMPORT
                        BEQ             HIM_AP_LINK_PATCH_ABS16
                        CMP             #HIM_AP_RELOC_LO8_IMPORT
                        BEQ             HIM_AP_LINK_PATCH_LO8
                        CMP             #HIM_AP_RELOC_HI8_IMPORT
                        BEQ             HIM_AP_LINK_PATCH_HI8
                        RTS
HIM_AP_LINK_PATCH_ABS16:
                        LDY             #$00
                        LDA             HIM_AP_LINK_RES_LO
                        STA             (HIM_AP_LINK_ADDR_LO),Y
                        INY
                        LDA             HIM_AP_LINK_RES_HI
                        STA             (HIM_AP_LINK_ADDR_LO),Y
                        RTS
HIM_AP_LINK_PATCH_LO8:
                        LDY             #$00
                        LDA             HIM_AP_LINK_RES_LO
                        STA             (HIM_AP_LINK_ADDR_LO),Y
                        RTS
HIM_AP_LINK_PATCH_HI8:
                        LDY             #$00
                        LDA             HIM_AP_LINK_RES_HI
                        STA             (HIM_AP_LINK_ADDR_LO),Y
                        RTS

; Private AP operation 6. The live manager installs its candidate callback.
; Traversal and identity are resident; stage/entry-row representation is APMAN's.
; No flash writes. Only AP_EXPORT and disabled RAM are supported in this slice.
HIM_FNV_FIND:
                        LDA             FNV_FORMAT
                        CMP             #FNV_FORMAT_AP_EXPORT
                        BNE             HIM_FNV_BAD_REQUEST
                        LDA             FNV_RAM_ENABLE
                        BEQ             HIM_FNV_REQUEST_OK
HIM_FNV_BAD_REQUEST:     LDA             #APMAN_STATUS_BAD_RANGE
                        CLC
                        RTS
HIM_FNV_REQUEST_OK:
                        STZ             HIM_ASM_SESSION_RESUME
                        LDA             STR8_CONFIG_FNV_POLICY
                        LDX             FNV_REQUEST_BANKS
                        JSR             FNV_SCOPE_POLICY
                        STZ             FNV_MATCH_COUNT
                        LDA             #$02
                        STA             FNV_ACTIVE_BANK
HIM_FNV_BANK:
                        LDX             FNV_ACTIVE_BANK
                        LDA             HIM_FNV_BANK_BITS,X
                        AND             FNV_EFFECTIVE_BANKS
                        BEQ             HIM_FNV_NEXT_BANK
                        LDA             #$80
                        STA             FNV_ACTIVE_SECTOR
                        LDA             #$01
                        STA             FNV_SCAN_WINDOW
HIM_FNV_SECTOR:
                        LDA             FNV_SCAN_WINDOW
                        AND             FNV_BANK_WINDOWS
                        BEQ             HIM_FNV_NEXT_SECTOR
                        JSR             HIM_FNV_CANDIDATE
                        BCS             HIM_FNV_MATCH
                        LDA             HIM_AP_STATUS
                        CMP             #APMAN_STATUS_RESTORE_FAIL
                        BNE             HIM_FNV_NEXT_SECTOR
                        CLC
                        RTS
HIM_FNV_MATCH:
                        LDA             FNV_MATCH_COUNT
                        CMP             #$02
                        BCS             HIM_FNV_NEXT_SECTOR
                        TAX
                        INC             FNV_MATCH_COUNT
                        TXA
                        BNE             HIM_FNV_NEXT_SECTOR
HIM_FNV_SAVE_MATCH:
                        LDA             FNV_ACTIVE_BANK
                        STA             FNV_FOUND_BANK
                        LDA             FNV_ACTIVE_SECTOR
                        STA             FNV_FOUND_WINDOW
HIM_FNV_NEXT_SECTOR:
                        LDA             FNV_ACTIVE_SECTOR
                        CLC
                        ADC             #$10
                        STA             FNV_ACTIVE_SECTOR
                        ASL             FNV_SCAN_WINDOW
                        BNE             HIM_FNV_SECTOR
HIM_FNV_NEXT_BANK:
                        DEC             FNV_ACTIVE_BANK
                        BPL             HIM_FNV_BANK
                        LDA             FNV_MATCH_COUNT
                        STA             APMAN_MATCH_COUNT
                        BEQ             HIM_FNV_NOT_FOUND
                        CMP             #$01
                        BNE             HIM_FNV_DUPLICATE
                        LDA             FNV_FOUND_BANK
                        STA             FNV_ACTIVE_BANK
                        LDA             FNV_FOUND_WINDOW
                        STA             FNV_ACTIVE_SECTOR
                        JSR             HIM_FNV_CANDIDATE
                        BCC             HIM_FNV_NOT_FOUND
                        RTS
HIM_FNV_DUPLICATE:       LDA             #APMAN_STATUS_DUPLICATE
                        BRA             HIM_FNV_FAIL
HIM_FNV_NOT_FOUND:       LDA             #APMAN_STATUS_NOT_FOUND
HIM_FNV_FAIL:            CLC
                        RTS
HIM_FNV_CANDIDATE:       JSR             HIM_FNV_CALLBACK
                        BCC             HIM_FNV_CANDIDATE_FAIL
                        LDY             #$03
                        LDX             #$00
?HASH:                  LDA             (FNV_ROW_LO),Y
                        CMP             FNV_WANTED_HASH0,X
                        BNE             HIM_FNV_CANDIDATE_FAIL
                        INY
                        INX
                        CPX             #$04
                        BNE             ?HASH
                        JMP             HIM_FNV_MATCH_NAME
HIM_FNV_CANDIDATE_FAIL:  CLC
                        RTS
HIM_FNV_CALLBACK:        JMP             (FNV_VALIDATE_LO)
HIM_FNV_BANK_BITS:       DB              $01,$02,$04

; Parsed entry row at $AC/$AD. Bounds and canonical PACK40 comparison prevent
; a forged hash or out-of-BODY entry from becoming an executable provider.
HIM_FNV_MATCH_NAME:     LDY             #$07
                        LDA             (FNV_ROW_LO),Y
                        CMP             FNV_NAME_LEN
                        BNE             ?FAIL
                        LDA             FNV_NAME_LO
                        STA             HIM_AP_LINK_IMP_PTR_LO
                        LDA             FNV_NAME_HI
                        STA             HIM_AP_LINK_IMP_PTR_HI
                        STZ             HIM_AP_LINK_NAME_INDEX
                        LDA             #$08
                        STA             HIM_AP_LINK_TMP_LO
?GROUP:                 STZ             HIM_P40_VALUE_LO
                        STZ             HIM_P40_VALUE_HI
                        LDA             #$03
                        STA             HIM_AP_LINK_TMP_HI
?CHAR:                  LDY             HIM_AP_LINK_NAME_INDEX
                        CPY             FNV_NAME_LEN
                        BCS             ?PAD
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        JSR             HIM_PACK40_ASCII_TO_CODE
                        BCC             ?FAIL
                        INC             HIM_AP_LINK_NAME_INDEX
                        BRA             ?ADD
?PAD:                   LDA             #$00
?ADD:                   PHA
                        JSR             HIM_PACK40_MUL40
                        PLA
                        JSR             HIM_PACK40_ADD_A
                        DEC             HIM_AP_LINK_TMP_HI
                        BNE             ?CHAR
                        LDY             HIM_AP_LINK_TMP_LO
                        LDA             (FNV_ROW_LO),Y
                        CMP             HIM_P40_VALUE_LO
                        BNE             ?FAIL
                        INY
                        LDA             (FNV_ROW_LO),Y
                        CMP             HIM_P40_VALUE_HI
                        BNE             ?FAIL
                        INY
                        STY             HIM_AP_LINK_TMP_LO
                        LDA             HIM_AP_LINK_NAME_INDEX
                        CMP             FNV_NAME_LEN
                        BCC             ?GROUP
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS

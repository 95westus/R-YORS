HIM_AP_SERVICE:
                        LDA             #HIM_AP_STATUS_OK
                        STA             HIM_AP_STATUS
                        LDA             HIM_AP_OP
                        CMP             #HIM_AP_OP_PARSE
                        BEQ             HIM_AP_SERVICE_PARSE
                        CMP             #HIM_AP_OP_LOAD
                        BEQ             HIM_AP_SERVICE_LOAD
                        CMP             #HIM_AP_OP_TAKEOVER
                        BEQ             HIM_AP_SERVICE_LOAD
                        CMP             #HIM_AP_OP_SUGGEST
                        BNE             HIM_AP_SERVICE_CHECK_LINK
                        JMP             HIM_AP_SERVICE_SUGGEST
HIM_AP_SERVICE_CHECK_LINK:
                        CMP             #HIM_AP_OP_LINK
                        BNE             HIM_AP_SERVICE_CHECK_MANAGER
                        JMP             HIM_AP_SERVICE_LINK
HIM_AP_SERVICE_CHECK_MANAGER:
                        CMP             #HIM_AP_OP_MANAGER
                        BNE             HIM_AP_SERVICE_BAD_OP
                        JMP             HIM_APMAN_BOOTSTRAP
HIM_AP_SERVICE_BAD_OP:
                        JMP             HIM_AP_BAD_LINE

HIM_AP_SERVICE_PARSE:
                        JMP             HIM_AP_PARSE_MIN

; Compatibility target for STR8's stable $F006 doorway. New HIMON load paths
; call the same resident linker directly and leave HIM_AP_OP as LOAD.
HIM_AP_SERVICE_LINK:
                        JMP             HIM_AP_IMPORT_LINK

HIM_AP_SERVICE_LOAD:
                        JSR             HIM_AP_PARSE_MIN
                        BCS             HIM_AP_LOAD_PARSED
                        RTS
HIM_AP_LOAD_PARSED:
                        JSR             HIM_AP_LOAD_RANGE_OK
                        BCS             HIM_AP_LOAD_RANGE_SAFE
                        RTS
HIM_AP_LOAD_RANGE_SAFE:
                        LDA             HIM_AP_SRC_HI
                        CMP             #HIM_AP_RAM_BASE_HI
                        BCC             HIM_AP_LOAD_NO_OVERLAP
                        CMP             #HIM_AP_SOURCE_LIMIT_HI
                        BCS             HIM_AP_LOAD_NO_OVERLAP
                        LDA             HIM_AP_TMP2_HI
                        CMP             HIM_AP_SRC_HI
                        BCC             HIM_AP_LOAD_NO_OVERLAP
                        BNE             HIM_AP_LOAD_CHECK_AFTER
                        LDA             HIM_AP_TMP2_LO
                        CMP             HIM_AP_SRC_LO
                        BCC             HIM_AP_LOAD_NO_OVERLAP
HIM_AP_LOAD_CHECK_AFTER:
                        LDA             CMDP_PTR_LO
                        CLC
                        ADC             HIM_AP_BODY_LEN_LO
                        TAX
                        LDA             CMDP_PTR_HI
                        ADC             HIM_AP_BODY_LEN_HI
                        CMP             HIM_AP_DST_HI
                        BCC             HIM_AP_LOAD_NO_OVERLAP
                        BNE             HIM_AP_LOAD_OVERLAP_BAD
                        CPX             HIM_AP_DST_LO
                        BCC             HIM_AP_LOAD_NO_OVERLAP
                        BEQ             HIM_AP_LOAD_NO_OVERLAP
HIM_AP_LOAD_OVERLAP_BAD:
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_LOAD_NO_OVERLAP:
                        LDA             HIM_AP_OP
                        CMP             #HIM_AP_OP_TAKEOVER
                        BNE             HIM_AP_LOAD_COPY
                        STZ             HIM_ASM_SESSION_RESUME
HIM_AP_LOAD_COPY:
                        JSR             HIM_AP_COPY_BODY_TO_DST
                        JSR             HIM_AP_IMPORT_LINK
                        BCS             HIM_AP_LOAD_IMPORTS_OK
                        RTS
HIM_AP_LOAD_IMPORTS_OK:
                        LDA             HIM_AP_REL_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_REL_HI
                        STA             CMDP_PTR_HI
                        LDX             #$00
HIM_AP_LOAD_PATCH_LOOP:
                        CPX             HIM_AP_RELOC_COUNT
                        BCS             HIM_AP_LOAD_DONE
                        JSR             HIM_AP_RELOC_KIND_X
                        JSR             HIM_AP_INTERNAL_KIND_A
                        BCS             HIM_AP_LOAD_PATCH_ROW
                        JSR             HIM_AP_IMPORT_KIND_A
                        BCS             HIM_AP_LOAD_PATCH_NEXT
                        JMP             HIM_AP_BAD_FIX
HIM_AP_LOAD_PATCH_ROW:
                        JSR             HIM_AP_RELOC_SITE_OK_X
                        BCS             HIM_AP_LOAD_PATCH_SITE_OK
                        RTS
HIM_AP_LOAD_PATCH_SITE_OK:
                        JSR             HIM_AP_RELOC_PATCH_ROW_X
HIM_AP_LOAD_PATCH_NEXT:
                        INX
                        BRA             HIM_AP_LOAD_PATCH_LOOP
HIM_AP_LOAD_DONE:
                        LDA             #HIM_AP_STATUS_OK
                        STA             HIM_AP_STATUS
                        LDX             HIM_AP_DST_LO
                        LDY             HIM_AP_DST_HI
                        SEC
                        RTS

HIM_AP_SERVICE_SUGGEST:
                        JSR             HIM_AP_PARSE_MIN
                        BCS             HIM_AP_SUGGEST_PARSED
                        RTS
HIM_AP_SUGGEST_PARSED:
                        JSR             HIM_AP_FIND_HOLE
                        BCS             HIM_AP_SUGGEST_FOUND
                        RTS
HIM_AP_SUGGEST_FOUND:
                        LDA             #HIM_AP_STATUS_OK
                        STA             HIM_AP_STATUS
                        LDX             HIM_AP_INSTALL_LO
                        LDY             HIM_AP_INSTALL_HI
                        SEC
                        RTS

HIM_AP_PARSE_MIN:
; BODY pointer/length and relocation/import counts occupy six adjacent cells.
; X is volatile on failure; successful parsing returns the source in X/Y.
                        LDX             #(HIM_AP_IMPORT_COUNT-HIM_AP_BODY_LO)
HIM_AP_PARSE_CLEAR_BODY:
                        STZ             HIM_AP_BODY_LO,X
                        DEX
                        BPL             HIM_AP_PARSE_CLEAR_BODY
                        STZ             HIM_AP_REL_LO
                        STZ             HIM_AP_REL_HI
                        STZ             HIM_AP_IMPORT_LO
                        STZ             HIM_AP_IMPORT_HI
HIM_AP_PARSE_CLEAR_DONE:
                        LDA             #HIM_AP_HDR_BYTES
                        STA             HIM_AP_PKG_LEN_LO
                        STZ             HIM_AP_PKG_LEN_HI
                        JSR             HIM_AP_SOURCE_RANGE_OK
                        BCS             HIM_AP_PARSE_HEADER_RANGE
                        RTS
HIM_AP_PARSE_HEADER_RANGE:
                        LDA             HIM_AP_SRC_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_SRC_HI
                        STA             CMDP_PTR_HI
                        LDY             #HIM_AP_OFF_SIG0
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #HIM_AP_SIG0
                        BEQ             HIM_AP_PARSE_SIG0_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_SIG0_OK:
                        LDY             #HIM_AP_OFF_SIG1
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #HIM_AP_SIG1
                        BEQ             HIM_AP_PARSE_SIG1_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_SIG1_OK:
                        LDY             #HIM_AP_OFF_VER
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #HIM_AP_VERSION
                        BEQ             HIM_AP_PARSE_VER_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_VER_OK:
                        LDY             #HIM_AP_OFF_TOTAL
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_PKG_LEN_LO
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_PKG_LEN_HI
                        ORA             HIM_AP_PKG_LEN_LO
                        BNE             HIM_AP_PARSE_LEN_NONZERO
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_LEN_NONZERO:
                        JSR             HIM_AP_SOURCE_RANGE_OK
                        BCS             HIM_AP_PARSE_RANGE_SAFE
                        RTS
HIM_AP_PARSE_RANGE_SAFE:
                        LDA             HIM_AP_SRC_LO
                        CLC
                        ADC             #HIM_AP_HDR_BYTES
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_SRC_HI
                        ADC             #$00
                        STA             CMDP_PTR_HI
                        LDA             HIM_AP_PKG_LEN_LO
                        SEC
                        SBC             #HIM_AP_HDR_BYTES
                        STA             LOAD_LEN_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        SBC             #$00
                        STA             LOAD_LEN_HI
                        BCS             HIM_AP_PARSE_SEAL
                        JMP             HIM_AP_BAD_LINE

HIM_AP_PARSE_SEAL:
                        LDA             #HIM_AP_TAG_SEAL
                        JSR             HIM_AP_TAG_LEN
                        BCS             HIM_AP_PARSE_SEAL_TAG_OK
                        RTS
HIM_AP_PARSE_SEAL_TAG_OK:
                        LDA             HIM_AP_TMP_HI
                        BNE             HIM_AP_PARSE_SEAL_LEN_BAD
                        LDA             HIM_AP_TMP_LO
                        CMP             #HIM_AP_SEAL_REC_BYTES
                        BEQ             HIM_AP_PARSE_SEAL_LEN_OK
HIM_AP_PARSE_SEAL_LEN_BAD:
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_SEAL_LEN_OK:
                        LDY             #HIM_AP_SEAL_OFF_FLAGS
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #$01
                        BEQ             HIM_AP_PARSE_SEAL_FLAGS_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_SEAL_FLAGS_OK:
                        LDY             #HIM_AP_SEAL_OFF_LEN
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_TMP2_LO
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_TMP2_HI
                        LDY             #HIM_AP_SEAL_OFF_BASE
                        LDA             (CMDP_PTR_LO),Y
                        CLC
                        ADC             HIM_AP_TMP2_LO
                        STA             CMDP_ADDR_LO
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        ADC             HIM_AP_TMP2_HI
                        BCS             HIM_AP_PARSE_SEAL_BAD
                        STA             CMDP_ADDR_HI
                        LDY             #HIM_AP_SEAL_OFF_END
                        LDA             (CMDP_PTR_LO),Y
                        CMP             CMDP_ADDR_LO
                        BNE             HIM_AP_PARSE_SEAL_BAD
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        CMP             CMDP_ADDR_HI
                        BEQ             HIM_AP_PARSE_SEAL_SHAPE_OK
HIM_AP_PARSE_SEAL_BAD:
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_SEAL_SHAPE_OK:
                        JSR             HIM_AP_ADVANCE_TMP
                        BCS             HIM_AP_PARSE_RELOC
                        RTS

HIM_AP_PARSE_RELOC:
                        LDA             #HIM_AP_TAG_RELOC
                        JSR             HIM_AP_TAG_LEN
                        BCS             HIM_AP_PARSE_RELOC_TAG_OK
                        RTS
HIM_AP_PARSE_RELOC_TAG_OK:
                        LDA             HIM_AP_TMP_LO
                        ORA             HIM_AP_TMP_HI
                        BNE             HIM_AP_PARSE_RELOC_LEN_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_RELOC_LEN_OK:
                        JSR             HIM_AP_NEED_TMP
                        BCS             HIM_AP_PARSE_RELOC_ROOM_OK
                        RTS
HIM_AP_PARSE_RELOC_ROOM_OK:
                        LDA             CMDP_PTR_LO
                        STA             HIM_AP_REL_LO
                        LDA             CMDP_PTR_HI
                        STA             HIM_AP_REL_HI
                        JSR             HIM_AP_CHECK_RELOC_REC
                        BCS             HIM_AP_PARSE_RELOC_SHAPE_OK
                        RTS
HIM_AP_PARSE_RELOC_SHAPE_OK:
                        JSR             HIM_AP_ADVANCE_TMP
                        BCS             HIM_AP_PARSE_EXPORT
                        RTS

HIM_AP_PARSE_EXPORT:
                        LDA             #HIM_AP_TAG_EXPORT
                        JSR             HIM_AP_TAG_LEN
                        BCS             HIM_AP_PARSE_EXPORT_TAG_OK
                        RTS
HIM_AP_PARSE_EXPORT_TAG_OK:
                        LDA             HIM_AP_TMP_LO
                        ORA             HIM_AP_TMP_HI
                        BNE             HIM_AP_PARSE_EXPORT_LEN_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_EXPORT_LEN_OK:
                        JSR             HIM_AP_NEED_TMP
                        BCC             HIM_AP_PARSE_EXPORT_FAIL
                        JSR             HIM_AP_CHECK_EXPORT_REC
                        BCC             HIM_AP_PARSE_EXPORT_FAIL
                        JSR             HIM_AP_ADVANCE_TMP
                        BCS             HIM_AP_PARSE_IMPORT
HIM_AP_PARSE_EXPORT_FAIL:
                        RTS

HIM_AP_PARSE_IMPORT:
                        LDA             #HIM_AP_TAG_IMPORT
                        JSR             HIM_AP_TAG_LEN
                        BCS             HIM_AP_PARSE_IMPORT_TAG_OK
                        RTS
HIM_AP_PARSE_IMPORT_TAG_OK:
                        LDA             HIM_AP_TMP_LO
                        ORA             HIM_AP_TMP_HI
                        BNE             HIM_AP_PARSE_IMPORT_LEN_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_IMPORT_LEN_OK:
                        JSR             HIM_AP_NEED_TMP
                        BCS             HIM_AP_PARSE_IMPORT_ROOM_OK
                        RTS
HIM_AP_PARSE_IMPORT_ROOM_OK:
                        LDY             #HIM_AP_IMPORT_REC_OFF_COUNT
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_IMPORT_COUNT
                        LDA             CMDP_PTR_LO
                        STA             HIM_AP_IMPORT_LO
                        LDA             CMDP_PTR_HI
                        STA             HIM_AP_IMPORT_HI
                        JSR             HIM_AP_CHECK_IMPORT_REC
                        BCC             HIM_AP_PARSE_IMPORT_FAIL
                        JSR             HIM_AP_ADVANCE_TMP
                        BCS             HIM_AP_PARSE_BODY
HIM_AP_PARSE_IMPORT_FAIL:
                        RTS

HIM_AP_PARSE_BODY:
                        LDA             #$03
                        JSR             HIM_AP_NEED_A
                        BCS             HIM_AP_PARSE_BODY_HDR_ROOM
                        RTS
HIM_AP_PARSE_BODY_HDR_ROOM:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #HIM_AP_TAG_BODY
                        BEQ             HIM_AP_PARSE_BODY_TAG_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_BODY_TAG_OK:
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_BODY_LEN_LO
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_BODY_LEN_HI
                        LDA             #$03
                        JSR             HIM_AP_ADVANCE_A
                        BCS             HIM_AP_PARSE_BODY_LEFT_OK
                        RTS
HIM_AP_PARSE_BODY_LEFT_OK:
                        LDA             LOAD_LEN_LO
                        CMP             HIM_AP_BODY_LEN_LO
                        BEQ             HIM_AP_PARSE_BODY_LEFT_LO_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_BODY_LEFT_LO_OK:
                        LDA             LOAD_LEN_HI
                        CMP             HIM_AP_BODY_LEN_HI
                        BEQ             HIM_AP_PARSE_BODY_SAVE
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_BODY_SAVE:
                        LDA             HIM_AP_BODY_LEN_LO
                        ORA             HIM_AP_BODY_LEN_HI
                        BNE             HIM_AP_PARSE_BODY_NONZERO
                        JMP             HIM_AP_BAD_LINE
HIM_AP_PARSE_BODY_NONZERO:
                        LDA             CMDP_PTR_LO
                        STA             HIM_AP_BODY_LO
                        LDA             CMDP_PTR_HI
                        STA             HIM_AP_BODY_HI
                        JSR             HIM_AP_VERIFY_SEAL_BODY
                        BCS             HIM_AP_PARSE_BODY_VERIFIED
                        RTS
HIM_AP_PARSE_BODY_VERIFIED:
                        LDA             #HIM_AP_STATUS_OK
                        STA             HIM_AP_STATUS
                        LDX             HIM_AP_SRC_LO
                        LDY             HIM_AP_SRC_HI
                        SEC
                        RTS

HIM_AP_VERIFY_SEAL_BODY:
                        LDA             HIM_AP_SRC_LO
                        CLC
                        ADC             #(HIM_AP_HDR_BYTES+$03)
                        STA             CMDP_ADDR_LO
                        LDA             HIM_AP_SRC_HI
                        ADC             #$00
                        STA             CMDP_ADDR_HI
                        LDY             #HIM_AP_SEAL_OFF_LEN
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             HIM_AP_BODY_LEN_LO
                        BNE             HIM_AP_VERIFY_SEAL_BAD
                        INY
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             HIM_AP_BODY_LEN_HI
                        BNE             HIM_AP_VERIFY_SEAL_BAD
; HIM_AP_PARSE_BODY_NONZERO leaves CMDP_PTR at BODY and LOAD_LEN equal to its
; checked length. This private verifier consumes that pointer/count directly.
                        JSR             FNV1A_INIT
HIM_AP_VERIFY_SEAL_LOOP:
                        LDA             LOAD_LEN_LO
                        ORA             LOAD_LEN_HI
                        BEQ             HIM_AP_VERIFY_SEAL_HASH
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        JSR             FNV1A_UPDATE_A_FAST
                        INC             CMDP_PTR_LO
                        BNE             HIM_AP_VERIFY_SEAL_COUNT
                        INC             CMDP_PTR_HI
HIM_AP_VERIFY_SEAL_COUNT:
                        DEC             LOAD_LEN_LO
                        LDA             LOAD_LEN_LO
                        CMP             #$FF
                        BNE             HIM_AP_VERIFY_SEAL_LOOP
                        DEC             LOAD_LEN_HI
                        BRA             HIM_AP_VERIFY_SEAL_LOOP
HIM_AP_VERIFY_SEAL_HASH:
; FNV init/update use only their hash/term scratch and preserve the seal pointer
; in CMDP_ADDR throughout the BODY hash loop.
                        LDY             #HIM_AP_SEAL_OFF_FNV
                        LDX             #$00
HIM_AP_VERIFY_SEAL_HASH_LOOP:
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             FNV_HASH0,X
                        BNE             HIM_AP_VERIFY_SEAL_BAD
                        INY
                        INX
                        CPX             #$04
                        BNE             HIM_AP_VERIFY_SEAL_HASH_LOOP
                        LDA             HIM_AP_BODY_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_BODY_HI
                        STA             CMDP_PTR_HI
                        SEC
                        RTS
HIM_AP_VERIFY_SEAL_BAD:
                        JMP             HIM_AP_BAD_LINE

HIM_AP_CHECK_RELOC_REC:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_RELOC_COUNT
                        CMP             #(HIM_AP_RELOC_MAX+1)
                        BCC             HIM_AP_CHECK_RELOC_COUNT_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_CHECK_RELOC_COUNT_OK:
                        STA             HIM_AP_TMP2_LO
                        STZ             HIM_AP_TMP2_HI
                        LDX             #$04
HIM_AP_CHECK_RELOC_LEN_LOOP:
                        LDA             HIM_AP_TMP2_LO
                        CLC
                        ADC             HIM_AP_RELOC_COUNT
                        STA             HIM_AP_TMP2_LO
                        LDA             HIM_AP_TMP2_HI
                        ADC             #$00
                        STA             HIM_AP_TMP2_HI
                        DEX
                        BNE             HIM_AP_CHECK_RELOC_LEN_LOOP
                        INC             HIM_AP_TMP2_LO
                        BNE             HIM_AP_CHECK_RELOC_LEN_READY
                        INC             HIM_AP_TMP2_HI
HIM_AP_CHECK_RELOC_LEN_READY:
                        LDA             HIM_AP_TMP2_LO
                        CMP             HIM_AP_TMP_LO
                        BNE             HIM_AP_CHECK_RELOC_SHAPE_BAD
                        LDA             HIM_AP_TMP2_HI
                        CMP             HIM_AP_TMP_HI
                        BEQ             HIM_AP_CHECK_RELOC_SHAPE_OK
HIM_AP_CHECK_RELOC_SHAPE_BAD:
                        JMP             HIM_AP_BAD_LINE
HIM_AP_CHECK_RELOC_SHAPE_OK:
                        LDX             #$00
HIM_AP_CHECK_RELOC_KIND_LOOP:
                        CPX             HIM_AP_RELOC_COUNT
                        BCS             HIM_AP_CHECK_RELOC_KINDS_OK
                        JSR             HIM_AP_RELOC_KIND_X
                        CMP             #HIM_AP_RELOC_ABS16_INTERNAL
                        BCC             HIM_AP_CHECK_RELOC_SHAPE_BAD
                        CMP             #(HIM_AP_RELOC_HI8_IMPORT+1)
                        BCS             HIM_AP_CHECK_RELOC_SHAPE_BAD
                        INX
                        BRA             HIM_AP_CHECK_RELOC_KIND_LOOP
HIM_AP_CHECK_RELOC_KINDS_OK:
                        SEC
                        RTS

HIM_AP_CHECK_EXPORT_REC:
                        LDA             #$08
                        STA             HIM_AP_LINK_TMP_LO
                        LDA             #(HIM_AP_KIND_MASK+HIM_AP_FLAG_ENTRY)
                        STA             HIM_AP_LINK_TMP_HI
                        BRA             HIM_AP_CHECK_PUBLIC_REC

HIM_AP_CHECK_IMPORT_REC:
                        LDA             #$06
                        STA             HIM_AP_LINK_TMP_LO
                        LDA             #HIM_AP_KIND_MASK
                        STA             HIM_AP_LINK_TMP_HI

HIM_AP_CHECK_PUBLIC_REC:
                        LDA             HIM_AP_TMP_LO
                        STA             HIM_AP_LINK_VALUE_LO
                        LDA             HIM_AP_TMP_HI
                        STA             HIM_AP_LINK_VALUE_HI
                        LDA             CMDP_PTR_LO
                        STA             HIM_AP_LINK_IMP_PTR_LO
                        LDA             CMDP_PTR_HI
                        STA             HIM_AP_LINK_IMP_PTR_HI
                        LDY             #$00
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        CMP             #(HIM_AP_PUBLIC_MAX+1)
                        BCC             HIM_AP_CHECK_PUBLIC_COUNT_OK
                        JMP             HIM_AP_CHECK_PUBLIC_FAIL
HIM_AP_CHECK_PUBLIC_COUNT_OK:
                        STA             HIM_AP_LINK_CODE2
                        STZ             HIM_AP_LINK_CODE1
                        STZ             HIM_AP_LINK_CODE0
                        LDA             #$01
                        JSR             HIM_AP_CHECK_PUBLIC_ADVANCE_A
                        BCS             HIM_AP_CHECK_PUBLIC_LOOP
                        JMP             HIM_AP_CHECK_PUBLIC_FAIL
HIM_AP_CHECK_PUBLIC_LOOP:
                        LDA             HIM_AP_LINK_CODE1
                        CMP             HIM_AP_LINK_CODE2
                        BCS             HIM_AP_CHECK_PUBLIC_DONE
HIM_AP_CHECK_PUBLIC_MORE:
                        LDA             HIM_AP_LINK_VALUE_HI
                        BNE             HIM_AP_CHECK_PUBLIC_HAVE_FIXED
                        LDA             HIM_AP_LINK_VALUE_LO
                        CMP             HIM_AP_LINK_TMP_LO
                        BCC             HIM_AP_CHECK_PUBLIC_FAIL
HIM_AP_CHECK_PUBLIC_HAVE_FIXED:
                        LDY             #$00
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        STA             HIM_AP_LINK_ADDR_HI
                        AND             HIM_AP_LINK_TMP_HI
                        CMP             HIM_AP_LINK_ADDR_HI
                        BNE             HIM_AP_CHECK_PUBLIC_FAIL
                        LDA             HIM_AP_LINK_ADDR_HI
                        AND             #HIM_AP_KIND_MASK
                        CMP             #HIM_AP_KIND_EXEC
                        BEQ             HIM_AP_CHECK_PUBLIC_KIND_OK
                        CMP             #HIM_AP_KIND_DATA
                        BNE             HIM_AP_CHECK_PUBLIC_FAIL
HIM_AP_CHECK_PUBLIC_KIND_OK:
                        LDA             HIM_AP_LINK_ADDR_HI
                        AND             #HIM_AP_FLAG_ENTRY
                        BEQ             HIM_AP_CHECK_PUBLIC_NAME
                        LDA             HIM_AP_LINK_TMP_HI
                        CMP             #(HIM_AP_KIND_MASK+HIM_AP_FLAG_ENTRY)
                        BNE             HIM_AP_CHECK_PUBLIC_FAIL
                        LDA             HIM_AP_LINK_ADDR_HI
                        AND             #HIM_AP_KIND_MASK
                        CMP             #HIM_AP_KIND_EXEC
                        BNE             HIM_AP_CHECK_PUBLIC_FAIL
                        INC             HIM_AP_LINK_CODE0
                        LDA             HIM_AP_LINK_CODE0
                        CMP             #$02
                        BCS             HIM_AP_CHECK_PUBLIC_FAIL
HIM_AP_CHECK_PUBLIC_NAME:
                        LDY             HIM_AP_LINK_TMP_LO
                        DEY
                        LDA             (HIM_AP_LINK_IMP_PTR_LO),Y
                        BEQ             HIM_AP_CHECK_PUBLIC_FAIL
                        CMP             #$20
                        BCS             HIM_AP_CHECK_PUBLIC_FAIL
                        STA             HIM_AP_LINK_ADDR_HI
                        LDA             HIM_AP_LINK_TMP_LO
                        STA             HIM_AP_LINK_ADDR_LO
HIM_AP_CHECK_PUBLIC_PACK_LOOP:
                        LDA             HIM_AP_LINK_ADDR_HI
                        BEQ             HIM_AP_CHECK_PUBLIC_ROW_READY
                        INC             HIM_AP_LINK_ADDR_LO
                        INC             HIM_AP_LINK_ADDR_LO
                        CMP             #$04
                        BCC             HIM_AP_CHECK_PUBLIC_PACK_LAST
                        SEC
                        SBC             #$03
                        STA             HIM_AP_LINK_ADDR_HI
                        BRA             HIM_AP_CHECK_PUBLIC_PACK_LOOP
HIM_AP_CHECK_PUBLIC_PACK_LAST:
                        STZ             HIM_AP_LINK_ADDR_HI
                        BRA             HIM_AP_CHECK_PUBLIC_PACK_LOOP
HIM_AP_CHECK_PUBLIC_ROW_READY:
                        LDA             HIM_AP_LINK_ADDR_LO
                        JSR             HIM_AP_CHECK_PUBLIC_ADVANCE_A
                        BCC             HIM_AP_CHECK_PUBLIC_FAIL
                        INC             HIM_AP_LINK_CODE1
                        BRA             HIM_AP_CHECK_PUBLIC_LOOP
HIM_AP_CHECK_PUBLIC_DONE:
                        LDA             HIM_AP_LINK_VALUE_LO
                        ORA             HIM_AP_LINK_VALUE_HI
                        BNE             HIM_AP_CHECK_PUBLIC_FAIL
                        SEC
                        RTS
HIM_AP_CHECK_PUBLIC_FAIL:
                        JMP             HIM_AP_BAD_LINE

HIM_AP_CHECK_PUBLIC_ADVANCE_A:
                        STA             HIM_AP_LINK_ADDR_LO
                        LDA             HIM_AP_LINK_VALUE_HI
                        BNE             HIM_AP_CHECK_PUBLIC_ADVANCE_ROOM
                        LDA             HIM_AP_LINK_VALUE_LO
                        CMP             HIM_AP_LINK_ADDR_LO
                        BCC             HIM_AP_CHECK_PUBLIC_ADVANCE_FAIL
HIM_AP_CHECK_PUBLIC_ADVANCE_ROOM:
                        LDA             HIM_AP_LINK_IMP_PTR_LO
                        CLC
                        ADC             HIM_AP_LINK_ADDR_LO
                        STA             HIM_AP_LINK_IMP_PTR_LO
                        BCC             HIM_AP_CHECK_PUBLIC_ADVANCE_PTR_OK
                        INC             HIM_AP_LINK_IMP_PTR_HI
HIM_AP_CHECK_PUBLIC_ADVANCE_PTR_OK:
                        LDA             HIM_AP_LINK_VALUE_LO
                        SEC
                        SBC             HIM_AP_LINK_ADDR_LO
                        STA             HIM_AP_LINK_VALUE_LO
                        LDA             HIM_AP_LINK_VALUE_HI
                        SBC             #$00
                        STA             HIM_AP_LINK_VALUE_HI
                        SEC
                        RTS
HIM_AP_CHECK_PUBLIC_ADVANCE_FAIL:
                        CLC
                        RTS

HIM_AP_TAG_LEN:
                        STA             HIM_AP_TMP2_LO
                        LDA             #$03
                        JSR             HIM_AP_NEED_A
                        BCS             HIM_AP_TAG_LEN_ROOM_OK
                        RTS
HIM_AP_TAG_LEN_ROOM_OK:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        CMP             HIM_AP_TMP2_LO
                        BEQ             HIM_AP_TAG_LEN_TAG_OK
                        JMP             HIM_AP_BAD_LINE
HIM_AP_TAG_LEN_TAG_OK:
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_TMP_LO
                        INY
                        LDA             (CMDP_PTR_LO),Y
                        STA             HIM_AP_TMP_HI
                        LDA             #$03
                        JMP             HIM_AP_ADVANCE_A

HIM_AP_ADVANCE_TMP:
                        JSR             HIM_AP_NEED_TMP
                        BCC             HIM_AP_ADVANCE_TMP_FAIL
                        LDA             CMDP_PTR_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_PTR_HI
                        ADC             HIM_AP_TMP_HI
                        STA             CMDP_PTR_HI
                        LDA             LOAD_LEN_LO
                        SEC
                        SBC             HIM_AP_TMP_LO
                        STA             LOAD_LEN_LO
                        LDA             LOAD_LEN_HI
                        SBC             HIM_AP_TMP_HI
                        STA             LOAD_LEN_HI
                        SEC
                        RTS
HIM_AP_ADVANCE_TMP_FAIL:
                        CLC
                        RTS

HIM_AP_NEED_TMP:
                        LDA             LOAD_LEN_HI
                        CMP             HIM_AP_TMP_HI
                        BCC             HIM_AP_NEED_TMP_FAIL
                        BNE             HIM_AP_NEED_TMP_OK
                        LDA             LOAD_LEN_LO
                        CMP             HIM_AP_TMP_LO
                        BCC             HIM_AP_NEED_TMP_FAIL
HIM_AP_NEED_TMP_OK:
                        SEC
                        RTS
HIM_AP_NEED_TMP_FAIL:
                        JMP             HIM_AP_BAD_RANGE

HIM_AP_ADVANCE_A:
                        STA             HIM_AP_TMP2_HI
                        JSR             HIM_AP_NEED_A
                        BCS             HIM_AP_ADVANCE_ROOM
                        RTS
HIM_AP_ADVANCE_ROOM:
                        LDA             CMDP_PTR_LO
                        CLC
                        ADC             HIM_AP_TMP2_HI
                        STA             CMDP_PTR_LO
                        LDA             CMDP_PTR_HI
                        ADC             #$00
                        STA             CMDP_PTR_HI
                        LDA             LOAD_LEN_LO
                        SEC
                        SBC             HIM_AP_TMP2_HI
                        STA             LOAD_LEN_LO
                        LDA             LOAD_LEN_HI
                        SBC             #$00
                        STA             LOAD_LEN_HI
                        SEC
                        RTS

HIM_AP_NEED_A:
                        STA             HIM_AP_TMP2_HI
                        LDA             LOAD_LEN_HI
                        BNE             HIM_AP_NEED_OK
                        LDA             LOAD_LEN_LO
                        CMP             HIM_AP_TMP2_HI
                        BCS             HIM_AP_NEED_OK
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_NEED_OK:
                        SEC
                        RTS

HIM_AP_SOURCE_RANGE_OK:
                        LDA             HIM_AP_PKG_LEN_LO
                        ORA             HIM_AP_PKG_LEN_HI
                        BNE             HIM_AP_SOURCE_LEN_NONZERO
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_LEN_NONZERO:
                        JSR             HIM_AP_SOURCE_BASE_OK
                        BCS             HIM_AP_SOURCE_BASE_SAFE
                        RTS
HIM_AP_SOURCE_BASE_SAFE:
                        LDA             HIM_AP_PKG_LEN_LO
                        SEC
                        SBC             #$01
                        STA             HIM_AP_TMP_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        SBC             #$00
                        STA             HIM_AP_TMP_HI
                        LDA             HIM_AP_SRC_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             HIM_AP_TMP2_LO
                        LDA             HIM_AP_SRC_HI
                        ADC             HIM_AP_TMP_HI
                        BCC             HIM_AP_SOURCE_LAST_NO_CARRY
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_LAST_NO_CARRY:
                        STA             HIM_AP_TMP2_HI
                        LDA             HIM_AP_SRC_HI
                        CMP             #HIM_AP_RAM_BASE_HI
                        BCC             HIM_AP_SOURCE_STAGE_RANGE
                        CMP             #HIM_AP_SOURCE_LIMIT_HI
                        BCC             HIM_AP_SOURCE_RAM_RANGE
                        LDA             HIM_AP_TMP2_HI
                        CMP             #HIM_AP_FLASH_LIMIT_HI
                        BCC             HIM_AP_SOURCE_RANGE_GOOD
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_STAGE_RANGE:
                        LDA             HIM_AP_TMP2_HI
                        CMP             #AP_STAGE_BUF_END_HI
                        BCC             HIM_AP_SOURCE_RANGE_GOOD
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_RAM_RANGE:
                        LDA             HIM_AP_TMP2_HI
                        CMP             #HIM_AP_SOURCE_LIMIT_HI
                        BCC             HIM_AP_SOURCE_RANGE_GOOD
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_RANGE_GOOD:
                        SEC
                        RTS

HIM_AP_SOURCE_BASE_OK:
                        LDA             HIM_AP_SRC_HI
                        CMP             #AP_STAGE_BUF_HI
                        BCC             HIM_AP_SOURCE_BASE_BAD
                        CMP             #AP_STAGE_BUF_END_HI
                        BCC             HIM_AP_SOURCE_BASE_GOOD
                        CMP             #HIM_AP_RAM_BASE_HI
                        BCS             HIM_AP_SOURCE_BASE_GE_20
HIM_AP_SOURCE_BASE_BAD:
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_SOURCE_BASE_GE_20:
                        CMP             #HIM_AP_SOURCE_LIMIT_HI
                        BCC             HIM_AP_SOURCE_BASE_GOOD
                        CMP             #HIM_AP_FLASH_BASE_HI
                        BCC             HIM_AP_SOURCE_BASE_BAD
HIM_AP_SOURCE_BASE_GE_80:
                        CMP             #HIM_AP_FLASH_LIMIT_HI
                        BCS             HIM_AP_SOURCE_BASE_BAD
HIM_AP_SOURCE_BASE_GOOD:
                        SEC
                        RTS

HIM_AP_LOAD_RANGE_OK:
                        LDA             HIM_AP_BODY_LEN_LO
                        ORA             HIM_AP_BODY_LEN_HI
                        BEQ             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_LEN_NONZERO:
                        LDA             HIM_AP_DST_HI
                        CMP             #HIM_AP_RAM_BASE_HI
                        BCC             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_BASE_GE_20:
                        LDX             HIM_AP_OP
                        CPX             #HIM_AP_OP_TAKEOVER
                        BNE             HIM_AP_LOAD_ORDINARY
                        CMP             #HIM_AP_TAKEOVER_LIMIT_HI
                        BCC             HIM_AP_LOAD_BASE_LT_50
                        BCS             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_ORDINARY:
                        CMP             #HIM_AP_LOAD_LIMIT_HI
                        BCC             HIM_AP_LOAD_BASE_LT_50
                        CMP             #HIM_AP_TOOL_BASE_HI
                        BCC             HIM_AP_LOAD_BASE_BAD
                        CMP             #HIM_AP_TOOL_LIMIT_HI
                        BCC             HIM_AP_LOAD_BASE_LT_50
HIM_AP_LOAD_BASE_BAD:
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_LOAD_BASE_LT_50:
                        LDA             HIM_AP_BODY_LEN_LO
                        SEC
                        SBC             #$01
                        STA             HIM_AP_TMP_LO
                        LDA             HIM_AP_BODY_LEN_HI
                        SBC             #$00
                        STA             HIM_AP_TMP_HI
                        LDA             HIM_AP_DST_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             HIM_AP_TMP2_LO
                        LDA             HIM_AP_DST_HI
                        ADC             HIM_AP_TMP_HI
                        BCS             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_LAST_NO_CARRY:
                        STA             HIM_AP_TMP2_HI
                        LDX             HIM_AP_OP
                        CPX             #HIM_AP_OP_TAKEOVER
                        BEQ             HIM_AP_LOAD_TAKEOVER_LAST
                        LDA             HIM_AP_DST_HI
                        CMP             #HIM_AP_LOAD_LIMIT_HI
                        LDA             HIM_AP_TMP2_HI
                        BCS             HIM_AP_LOAD_TOOL_LAST
                        CMP             #HIM_AP_LOAD_LIMIT_HI
                        BCC             HIM_AP_LOAD_RANGE_GOOD
                        BRA             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_TOOL_LAST:
                        CMP             #HIM_AP_TOOL_LIMIT_HI
                        BCC             HIM_AP_LOAD_RANGE_GOOD
                        BRA             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_TAKEOVER_LAST:
                        CMP             #HIM_AP_TAKEOVER_LIMIT_HI
                        BCS             HIM_AP_LOAD_BASE_BAD
HIM_AP_LOAD_RANGE_GOOD:
                        SEC
                        RTS

HIM_AP_COPY_BODY_TO_DST:
                        LDA             HIM_AP_BODY_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_BODY_HI
                        STA             CMDP_PTR_HI
                        LDA             HIM_AP_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             HIM_AP_DST_HI
                        STA             CMDP_ADDR_HI
                        LDA             HIM_AP_BODY_LEN_LO
                        STA             LOAD_LEN_LO
                        LDA             HIM_AP_BODY_LEN_HI
                        STA             LOAD_LEN_HI
                        ORA             LOAD_LEN_LO
                        BEQ             HIM_AP_COPY_BODY_DONE
HIM_AP_COPY_BODY_LOOP:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        STA             (CMDP_ADDR_LO),Y
                        INC             CMDP_PTR_LO
                        BNE             HIM_AP_COPY_BODY_DST
                        INC             CMDP_PTR_HI
HIM_AP_COPY_BODY_DST:
                        INC             CMDP_ADDR_LO
                        BNE             HIM_AP_COPY_BODY_COUNT
                        INC             CMDP_ADDR_HI
HIM_AP_COPY_BODY_COUNT:
                        DEC             LOAD_LEN_LO
                        LDA             LOAD_LEN_LO
                        CMP             #$FF
                        BNE             HIM_AP_COPY_BODY_MORE
                        DEC             LOAD_LEN_HI
HIM_AP_COPY_BODY_MORE:
                        LDA             LOAD_LEN_LO
                        ORA             LOAD_LEN_HI
                        BNE             HIM_AP_COPY_BODY_LOOP
HIM_AP_COPY_BODY_DONE:
                        RTS

HIM_AP_RELOC_KIND_X:
                        TXA
                        CLC
                        ADC             #$01
                        TAY
                        LDA             (CMDP_PTR_LO),Y
                        RTS

HIM_AP_RELOC_SITE_LO_X:
                        LDA             HIM_AP_RELOC_COUNT
                        STA             HIM_AP_TMP2_LO
                        TXA
                        CLC
                        ADC             HIM_AP_TMP2_LO
                        CLC
                        ADC             #$01
                        TAY
                        LDA             (CMDP_PTR_LO),Y
                        RTS

HIM_AP_RELOC_SITE_HI_X:
                        LDA             HIM_AP_RELOC_COUNT
                        ASL             A
                        STA             HIM_AP_TMP2_LO
                        TXA
                        CLC
                        ADC             HIM_AP_TMP2_LO
                        CLC
                        ADC             #$01
                        TAY
                        LDA             (CMDP_PTR_LO),Y
                        RTS

HIM_AP_RELOC_TARGET_LO_X:
                        LDA             HIM_AP_RELOC_COUNT
                        ASL             A
                        CLC
                        ADC             HIM_AP_RELOC_COUNT
                        STA             HIM_AP_TMP2_LO
                        TXA
                        CLC
                        ADC             HIM_AP_TMP2_LO
                        CLC
                        ADC             #$01
                        TAY
                        BCC             HIM_AP_RELOC_FETCH_Y
                        BRA             HIM_AP_RELOC_FETCH_Y_PAGE

HIM_AP_RELOC_TARGET_HI_X:
                        TXA
                        CLC
                        ADC             #$01
                        STA             HIM_AP_TMP2_LO
                        LDA             HIM_AP_RELOC_COUNT
                        ASL             A
                        ASL             A
                        PHP
                        CLC
                        ADC             HIM_AP_TMP2_LO
                        TAY
                        BCS             HIM_AP_RELOC_TARGET_HI_ADD_PAGE
                        PLP
                        BCC             HIM_AP_RELOC_FETCH_Y
                        BRA             HIM_AP_RELOC_FETCH_Y_PAGE
HIM_AP_RELOC_TARGET_HI_ADD_PAGE:
                        PLP
HIM_AP_RELOC_FETCH_Y_PAGE:
; A 64-row AP v2 relocation payload is $0141 bytes. Its target-low lane can
; reach offset $0100, and its target-high lane occupies $0101-$0140. Adjust
; the record pointer for those second-page bytes instead of wrapping Y and
; reading the relocation-kind lane as an address high byte.
                        INC             CMDP_PTR_HI
                        LDA             (CMDP_PTR_LO),Y
                        DEC             CMDP_PTR_HI
                        RTS
HIM_AP_RELOC_FETCH_Y:
                        LDA             (CMDP_PTR_LO),Y
                        RTS

HIM_AP_INTERNAL_KIND_A:
                        CMP             #HIM_AP_RELOC_ABS16_INTERNAL
                        BEQ             HIM_AP_INTERNAL_KIND_YES
                        CMP             #HIM_AP_RELOC_LO8_INTERNAL
                        BEQ             HIM_AP_INTERNAL_KIND_YES
                        CMP             #HIM_AP_RELOC_HI8_INTERNAL
                        BEQ             HIM_AP_INTERNAL_KIND_YES
                        CLC
                        RTS
HIM_AP_INTERNAL_KIND_YES:
                        SEC
                        RTS

HIM_AP_IMPORT_KIND_A:
                        CMP             #HIM_AP_RELOC_ABS16_IMPORT
                        BEQ             HIM_AP_IMPORT_KIND_YES
                        CMP             #HIM_AP_RELOC_LO8_IMPORT
                        BEQ             HIM_AP_IMPORT_KIND_YES
                        CMP             #HIM_AP_RELOC_HI8_IMPORT
                        BEQ             HIM_AP_IMPORT_KIND_YES
                        CLC
                        RTS
HIM_AP_IMPORT_KIND_YES:
                        SEC
                        RTS

HIM_AP_RELOC_SITE_OK_X:
                        JSR             HIM_AP_RELOC_KIND_X
                        STA             HIM_AP_TMP2_HI
                        CMP             #HIM_AP_RELOC_ABS16_INTERNAL
                        BEQ             HIM_AP_RELOC_SITE_WORD
                        CMP             #HIM_AP_RELOC_ABS16_IMPORT
                        BEQ             HIM_AP_RELOC_SITE_WORD
                        LDA             #$00
                        BRA             HIM_AP_RELOC_SITE_HAVE_ADD
HIM_AP_RELOC_SITE_WORD:
                        LDA             #$01
HIM_AP_RELOC_SITE_HAVE_ADD:
                        PHA
                        JSR             HIM_AP_RELOC_SITE_LO_X
                        STA             HIM_AP_TMP_LO
                        JSR             HIM_AP_RELOC_SITE_HI_X
                        STA             HIM_AP_TMP_HI
                        PLA
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             HIM_AP_TMP_LO
                        LDA             HIM_AP_TMP_HI
                        ADC             #$00
                        BCC             HIM_AP_RELOC_SITE_NO_CARRY
                        JMP             HIM_AP_BAD_FIX
HIM_AP_RELOC_SITE_NO_CARRY:
                        STA             HIM_AP_TMP_HI
                        CMP             HIM_AP_BODY_LEN_HI
                        BCC             HIM_AP_RELOC_SITE_GOOD
                        BEQ             HIM_AP_RELOC_SITE_HI_EQ
                        JMP             HIM_AP_BAD_FIX
HIM_AP_RELOC_SITE_HI_EQ:
                        LDA             HIM_AP_TMP_LO
                        CMP             HIM_AP_BODY_LEN_LO
                        BCC             HIM_AP_RELOC_SITE_GOOD
                        JMP             HIM_AP_BAD_FIX
HIM_AP_RELOC_SITE_GOOD:
                        SEC
                        RTS

HIM_AP_RELOC_PATCH_ROW_X:
                        JSR             HIM_AP_RELOC_SITE_LO_X
                        STA             HIM_AP_TMP_LO
                        JSR             HIM_AP_RELOC_SITE_HI_X
                        STA             HIM_AP_TMP_HI
                        LDA             HIM_AP_DST_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             CMDP_ADDR_LO
                        LDA             HIM_AP_DST_HI
                        ADC             HIM_AP_TMP_HI
                        STA             CMDP_ADDR_HI
                        JSR             HIM_AP_RELOC_TARGET_LO_X
                        STA             HIM_AP_TMP_LO
                        JSR             HIM_AP_RELOC_TARGET_HI_X
                        STA             HIM_AP_TMP_HI
                        LDA             HIM_AP_DST_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             HIM_AP_TMP_LO
                        LDA             HIM_AP_DST_HI
                        ADC             HIM_AP_TMP_HI
                        STA             HIM_AP_TMP_HI
                        LDA             HIM_AP_TMP2_HI
                        CMP             #HIM_AP_RELOC_ABS16_INTERNAL
                        BEQ             HIM_AP_RELOC_PATCH_ABS16
                        CMP             #HIM_AP_RELOC_LO8_INTERNAL
                        BEQ             HIM_AP_RELOC_PATCH_LO8
                        CMP             #HIM_AP_RELOC_HI8_INTERNAL
                        BEQ             HIM_AP_RELOC_PATCH_HI8
                        RTS
HIM_AP_RELOC_PATCH_ABS16:
                        LDY             #$00
                        LDA             HIM_AP_TMP_LO
                        STA             (CMDP_ADDR_LO),Y
                        INY
                        LDA             HIM_AP_TMP_HI
                        STA             (CMDP_ADDR_LO),Y
                        RTS
HIM_AP_RELOC_PATCH_LO8:
                        LDY             #$00
                        LDA             HIM_AP_TMP_LO
                        STA             (CMDP_ADDR_LO),Y
                        RTS
HIM_AP_RELOC_PATCH_HI8:
                        LDY             #$00
                        LDA             HIM_AP_TMP_HI
                        STA             (CMDP_ADDR_LO),Y
                        RTS

; ----------------------------------------------------------------------------
; AP resident import linker
;
; Validate every imported relocation and resolve every import before changing
; the copied body. A second pass resolves again and patches the captured site,
; preserving the existing all-or-nothing validation behavior of the former
; STR8-N implementation while sharing HIMON's AP/FNV/RJOIN primitives.
; ----------------------------------------------------------------------------

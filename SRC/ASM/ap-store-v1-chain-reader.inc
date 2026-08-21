; ----------------------------------------------------------------------------
; AP Store V1 Slice 5 reader: bank-wide discovery, canonical reconstruction,
; AP-v2 validation, and load/run. Included only in the reader image.
; ----------------------------------------------------------------------------

                        IF              APSC_READER_COMMON_ONLY
                        ELSE

APSC_MATCH_ACTION:
                        INC             APSC_TMP_FOUND
                        LDA             APSC_CHUNK_COUNT
                        CMP             #APS_OBJECT_MAX_CHUNKS
                        BCC             APSC_MATCH_ROOM
                        LDA             #APSC_STATUS_TOO_MANY
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS
APSC_MATCH_ROOM:
                        LDA             APSC_ZP_SECTOR
                        SEC
                        SBC             #$08
                        TAX
                        LDA             #$01
APSC_MATCH_BIT_LOOP:
                        CPX             #$00
                        BEQ             APSC_MATCH_BIT_READY
                        ASL             A
                        DEX
                        BRA             APSC_MATCH_BIT_LOOP
APSC_MATCH_BIT_READY:
                        STA             APSC_TMP_BIT
                        AND             APSC_USED_MASK
                        BEQ             APSC_MATCH_NEW_SECTOR
                        LDA             #APSC_STATUS_CONFLICT
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS
APSC_MATCH_NEW_SECTOR:
                        LDA             APSC_USED_MASK
                        ORA             APSC_TMP_BIT
                        STA             APSC_USED_MASK
                        LDY             #APSC_PLAN_SECTOR
                        LDA             APSC_ZP_SECTOR
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        STA             (APSC_ZP_ROW_LO),Y
                        LDA             APSC_TMP_TAIL_LO
                        SEC
                        SBC             #APS_RECORD_HEADER_BYTES
                        INY
                        STA             (APSC_ZP_ROW_LO),Y
                        LDA             APSC_TMP_TAIL_HI
                        SBC             #$00
                        INY
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV+1
                        STA             (APSC_ZP_ROW_LO),Y
                        INC             APSC_CHUNK_COUNT
                        JSR             APSC_READER_NEXT_ROW
                        SEC
                        RTS

APSC_LIST_BODY:
                        JSR             APSC_VALIDATE_BODY
                        BCS             APSC_LIST_VALID
                        JMP             APSC_READER_RETURN_ERROR
APSC_LIST_VALID:
                        LDX             #<APSC_MSG_ROW
                        LDY             #>APSC_MSG_ROW
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSC_OBJECT_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSC_OBJECT_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        LDX             #<APSC_MSG_GEN
                        LDY             #>APSC_MSG_GEN
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSC_OBJECT_GEN_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSC_OBJECT_GEN_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        LDX             #<APSC_MSG_LEN
                        LDY             #>APSC_MSG_LEN
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSC_PACKAGE_LEN_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSC_PACKAGE_LEN_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        JSR             APSC_WRITE_CRLF
                        LDX             #<APSC_MSG_OK
                        LDY             #>APSC_MSG_OK
                        JSR             APSC_WRITE_CSTRING
                        JSR             APSC_WRITE_CRLF
                        LDA             #APSC_STATUS_OK
                        SEC
                        RTS

APSC_VALIDATE_BODY:
                        CLD
                        JSR             APSC_CLEAR_RESULT
                        JSR             APSC_VALIDATE_REQUEST
                        BCS             APSC_READER_REQUEST_OK
                        JMP             APSC_READER_RETURN_ERROR
APSC_READER_REQUEST_OK:
                        JSR             APSC_VALIDATE_SERVICES
                        BCS             APSC_READER_SERVICES_OK
                        JMP             APSC_READER_RETURN_ERROR
APSC_READER_SERVICES_OK:
                        JSR             APSC_BOOT_SELECTOR
                        BCS             APSC_READER_SELECTOR_OK
                        JMP             APSC_READER_RETURN_ERROR
APSC_READER_SELECTOR_OK:
                        STZ             APSC_CHUNK_COUNT
                        STZ             APSC_USED_MASK
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSC_READER_SCAN_LOOP:
                        JSR             APSC_SCAN_SECTOR
                        BCS             APSC_READER_SCAN_OK
                        JMP             APSC_READER_RETURN_ERROR
APSC_READER_SCAN_OK:
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSC_READER_SCAN_LOOP
                        LDA             APSC_CHUNK_COUNT
                        BNE             APSC_READER_FOUND
                        LDA             #APSC_STATUS_NOT_FOUND
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        JMP             APSC_READER_RETURN_ERROR
APSC_READER_FOUND:
                        JSR             APSC_SORT_ROWS
                        JSR             APSC_VALIDATE_CHAIN
                        BCC             APSC_READER_RETURN_ERROR
                        JSR             APSC_RECONSTRUCT
                        BCC             APSC_READER_RETURN_ERROR
                        JSR             APSC_PARSE_BUFFER
                        BCC             APSC_READER_RETURN_ERROR
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_FAIL_SECTOR
                        LDA             #APSC_STATUS_OK
                        SEC
                        RTS

APSC_LOAD_BODY:
                        JSR             APSC_VALIDATE_BODY
                        BCS             APSC_LOAD_VALID
                        JMP             APSC_READER_RETURN_ERROR
APSC_LOAD_VALID:
                        LDA             #<APSC_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC
                        LDA             #>APSC_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC+1
                        LDA             APSC_DEST_LO
                        STA             ASM_ABI_AP_DST
                        LDA             APSC_DEST_HI
                        STA             ASM_ABI_AP_DST+1
                        LDA             #ASM_ABI_AP_OP_LOAD
                        STA             ASM_ABI_AP_OP
                        JSR             APSC_CALL_AP_SERVICE
                        BCS             APSC_LOAD_SERVICE_OK
                        LDA             APSC_STATUS
                        CMP             #APSC_STATUS_SERVICE_FAILED
                        BEQ             APSC_READER_RETURN_ERROR
                        JMP             APSC_READER_AP_INVALID
APSC_LOAD_SERVICE_OK:
                        STX             APSC_ENTRY_LO
                        STY             APSC_ENTRY_HI
                        JSR             APSC_RUN_ENTRY
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        SEC
                        RTS
APSC_RUN_ENTRY:
                        JMP             (APSC_ENTRY_LO)

APSC_READER_RETURN_ERROR:
                        LDA             APSC_STATUS
                        CLC
                        RTS

                        ENDIF

APSC_READER_NEXT_ROW:
                        LDA             APSC_ZP_ROW_LO
                        CLC
                        ADC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_ROW_LO
                        BCC             APSC_READER_NEXT_ROW_DONE
                        INC             APSC_ZP_ROW_HI
APSC_READER_NEXT_ROW_DONE:
                        RTS

; Stable bubble sort by 16-bit logical offset. At most eight ten-byte rows.
APSC_SORT_ROWS:
                        LDA             APSC_CHUNK_COUNT
                        CMP             #$02
                        BCC             APSC_SORT_DONE
                        DEC             A
                        STA             APSC_TMP_TMO0
APSC_SORT_PASS:
                        STZ             APSC_TMP_TMO2
                        STZ             APSC_TMP_TMO1
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
APSC_SORT_PAIR:
                        LDA             APSC_ZP_ROW_LO
                        CLC
                        ADC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_DST_LO
                        LDA             APSC_ZP_ROW_HI
                        ADC             #$00
                        STA             APSC_ZP_DST_HI
                        LDY             #APSC_PLAN_LOGICAL_HI
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             (APSC_ZP_DST_LO),Y
                        BCC             APSC_SORT_NO_SWAP
                        BNE             APSC_SORT_SWAP
                        DEY
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             (APSC_ZP_DST_LO),Y
                        BCC             APSC_SORT_NO_SWAP
                        BEQ             APSC_SORT_NO_SWAP
APSC_SORT_SWAP:
                        LDY             #$00
APSC_SORT_SWAP_BYTE:
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_TMP_SWAP
                        LDA             (APSC_ZP_DST_LO),Y
                        STA             (APSC_ZP_ROW_LO),Y
                        LDA             APSC_TMP_SWAP
                        STA             (APSC_ZP_DST_LO),Y
                        INY
                        CPY             #APSC_PLAN_ROW_BYTES
                        BNE             APSC_SORT_SWAP_BYTE
                        INC             APSC_TMP_TMO2
APSC_SORT_NO_SWAP:
                        LDA             APSC_ZP_DST_LO
                        STA             APSC_ZP_ROW_LO
                        LDA             APSC_ZP_DST_HI
                        STA             APSC_ZP_ROW_HI
                        INC             APSC_TMP_TMO1
                        LDA             APSC_TMP_TMO1
                        CMP             APSC_TMP_TMO0
                        BCC             APSC_SORT_PAIR
                        LDA             APSC_TMP_TMO2
                        BEQ             APSC_SORT_DONE
                        DEC             APSC_TMP_TMO0
                        BNE             APSC_SORT_PASS
APSC_SORT_DONE:
                        RTS

APSC_VALIDATE_CHAIN:
                        STZ             APSC_TMP_LOGICAL_LO
                        STZ             APSC_TMP_LOGICAL_HI
                        STZ             APSC_TMP_TMO1
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
APSC_VALIDATE_CHAIN_ROW:
                        LDY             #APSC_PLAN_LOGICAL_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_TMP_LOGICAL_LO
                        BNE             APSC_CHAIN_POSITION_BAD
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_TMP_LOGICAL_HI
                        BNE             APSC_CHAIN_POSITION_BAD
                        LDY             #APSC_PLAN_FLAGS
                        LDA             (APSC_ZP_ROW_LO),Y
                        LDX             APSC_TMP_TMO1
                        BNE             APSC_CHAIN_NOT_FIRST_ROW
                        AND             #APS_RECORD_FLAG_FIRST
                        BEQ             APSC_CHAIN_INCOMPLETE
                        BRA             APSC_CHAIN_FIRST_OK
APSC_CHAIN_NOT_FIRST_ROW:
                        AND             #APS_RECORD_FLAG_FIRST
                        BNE             APSC_CHAIN_CONFLICT
APSC_CHAIN_FIRST_OK:
                        LDX             APSC_TMP_TMO1
                        INX
                        CPX             APSC_CHUNK_COUNT
                        BNE             APSC_CHAIN_NOT_LAST_ROW
                        LDY             #APSC_PLAN_FLAGS
                        LDA             (APSC_ZP_ROW_LO),Y
                        AND             #APS_RECORD_FLAG_LAST
                        BEQ             APSC_CHAIN_INCOMPLETE
                        BRA             APSC_CHAIN_LAST_OK
APSC_CHAIN_NOT_LAST_ROW:
                        LDY             #APSC_PLAN_FLAGS
                        LDA             (APSC_ZP_ROW_LO),Y
                        AND             #APS_RECORD_FLAG_LAST
                        BNE             APSC_CHAIN_CONFLICT
APSC_CHAIN_LAST_OK:
                        LDY             #APSC_PLAN_LENGTH_LO
                        LDA             APSC_TMP_LOGICAL_LO
                        CLC
                        ADC             (APSC_ZP_ROW_LO),Y
                        STA             APSC_TMP_LOGICAL_LO
                        INY
                        LDA             APSC_TMP_LOGICAL_HI
                        ADC             (APSC_ZP_ROW_LO),Y
                        STA             APSC_TMP_LOGICAL_HI
                        CMP             #$10
                        BCC             APSC_CHAIN_SIZE_OK
                        BNE             APSC_CHAIN_CONFLICT
                        LDA             APSC_TMP_LOGICAL_LO
                        BNE             APSC_CHAIN_CONFLICT
APSC_CHAIN_SIZE_OK:
                        JSR             APSC_READER_NEXT_ROW
                        INC             APSC_TMP_TMO1
                        LDA             APSC_TMP_TMO1
                        CMP             APSC_CHUNK_COUNT
                        BCC             APSC_VALIDATE_CHAIN_ROW
                        LDA             APSC_TMP_LOGICAL_LO
                        STA             APSC_PACKAGE_LEN_LO
                        LDA             APSC_TMP_LOGICAL_HI
                        STA             APSC_PACKAGE_LEN_HI
                        SEC
                        RTS
APSC_CHAIN_POSITION_BAD:
                        LDY             #APSC_PLAN_LOGICAL_HI
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_TMP_LOGICAL_HI
                        BCC             APSC_CHAIN_CONFLICT
                        BNE             APSC_CHAIN_INCOMPLETE
                        DEY
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_TMP_LOGICAL_LO
                        BCC             APSC_CHAIN_CONFLICT
APSC_CHAIN_INCOMPLETE:
                        LDA             #APSC_STATUS_INCOMPLETE
                        BRA             APSC_CHAIN_SET_ERROR
APSC_CHAIN_CONFLICT:
                        LDA             #APSC_STATUS_CONFLICT
APSC_CHAIN_SET_ERROR:
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS

APSC_RECONSTRUCT:
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        LDX             APSC_CHUNK_COUNT
APSC_RECONSTRUCT_ROW:
                        PHX
                        LDY             #APSC_PLAN_SECTOR
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_SECTOR
                        LDA             APSC_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_RECONSTRUCT_RESTORE_ERROR
                        LDY             #APSC_PLAN_RECORD_OFF_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES
                        STA             APSW_PTR_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        ADC             #$00
                        STA             APSC_TMP_COMMIT_HI
                        LDA             APSC_ZP_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             APSC_TMP_COMMIT_HI
                        STA             APSW_PTR_HI
                        LDY             #APSC_PLAN_LOGICAL_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        CLC
                        ADC             #<APSC_PACKAGE_BUFFER
                        STA             APSC_ZP_DST_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        ADC             #>APSC_PACKAGE_BUFFER
                        STA             APSC_ZP_DST_HI
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_COUNT_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_COUNT_HI
APSC_RECONSTRUCT_BYTE:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSC_RECONSTRUCT_ROW_DONE
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        STA             (APSC_ZP_DST_LO),Y
                        JSR             APSC_INC_PTR
                        INC             APSC_ZP_DST_LO
                        BNE             APSC_RECONSTRUCT_DST_OK
                        INC             APSC_ZP_DST_HI
APSC_RECONSTRUCT_DST_OK:
                        JSR             APSC_DEC_COUNT
                        BRA             APSC_RECONSTRUCT_BYTE
APSC_RECONSTRUCT_ROW_DONE:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_RECONSTRUCT_RESTORE_FAIL
                        JSR             APSC_READER_NEXT_ROW
                        PLX
                        DEX
                        BNE             APSC_RECONSTRUCT_ROW
                        SEC
                        RTS
APSC_RECONSTRUCT_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
APSC_RECONSTRUCT_RESTORE_FAIL:
                        JSR             APSC_FORCE_BANK3
                        LDA             #APSC_STATUS_RESTORE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_RESTORE
                        STA             APSC_FAIL_PHASE
                        PLX
                        CLC
                        RTS

APSC_PARSE_BUFFER:
                        LDA             #<APSC_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC
                        LDA             #>APSC_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC+1
                        LDA             #ASM_ABI_AP_OP_PARSE
                        STA             ASM_ABI_AP_OP
                        JSR             APSC_CALL_AP_SERVICE
                        BCC             APSC_READER_AP_INVALID
                        LDA             ASM_ABI_AP_PACKAGE_LEN
                        CMP             APSC_PACKAGE_LEN_LO
                        BNE             APSC_READER_AP_INVALID
                        LDA             ASM_ABI_AP_PACKAGE_LEN+1
                        CMP             APSC_PACKAGE_LEN_HI
                        BNE             APSC_READER_AP_INVALID
                        SEC
                        RTS
APSC_READER_AP_INVALID:
                        LDA             #APSC_STATUS_AP_INVALID
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS

                        IF              APSC_WRITER_BUILD
APSC_WRITE_CSTRING:
                        LDA             APSW_SVC_WRITE_CSTRING
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_CSTRING+1
                        STA             APSW_CALL_HI
                        JMP             (APSW_CALL_LO)
APSC_WRITE_HEX_BYTE:
                        PHA
                        LDA             APSW_SVC_WRITE_HEX_BYTE
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_HEX_BYTE+1
                        STA             APSW_CALL_HI
                        PLA
                        JMP             (APSW_CALL_LO)
APSC_WRITE_CRLF:
                        LDA             APSW_SVC_WRITE_CRLF
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_CRLF+1
                        STA             APSW_CALL_HI
                        JMP             (APSW_CALL_LO)
                        ENDIF

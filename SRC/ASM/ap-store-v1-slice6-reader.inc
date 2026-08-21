; ----------------------------------------------------------------------------
; AP Store V1 Slice 6 read-only catalog, newest/exact resolver, space report,
; and delete planner.  The destructive executor is a separate fixed AP.
; ----------------------------------------------------------------------------

APSC_MATCH_ACTION:
                        IF              APSC_SLICE6_READER_BUILD
                        LDA             APSD_MODE
                        CMP             #APSD_MODE_FIND
                        BEQ             APSD_MATCH_FIND
                        ELSE
                        LDA             APSD_MODE
                        CMP             #APSD_MODE_REPORT
                        BEQ             APSD_MATCH_REPORT
                        ENDIF
                        CMP             #APSD_MODE_INSPECT
                        BEQ             APSD_MATCH_OK
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_TOMBSTONE
                        BNE             APSD_MATCH_CHUNK
                        INC             APSC_TMP_REMAIN_LO
                        INC             APSC_TMP_FOUND
APSD_MATCH_OK:          SEC
                        RTS

                        IF              APSC_SLICE6_READER_BUILD
APSD_MATCH_FIND:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        CMP             APSD_CEILING_HI
                        BCC             APSD_FIND_ABOVE_CURRENT
                        BNE             APSD_MATCH_OK
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        CMP             APSD_CEILING_LO
                        BCC             APSD_FIND_ABOVE_CURRENT
                        BNE             APSD_MATCH_OK
APSD_FIND_ABOVE_CURRENT:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        CMP             APSD_RESOLVED_GEN_HI
                        BCC             APSD_MATCH_OK
                        BNE             APSD_FIND_SAVE
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        CMP             APSD_RESOLVED_GEN_LO
                        BCC             APSD_MATCH_OK
                        BEQ             APSD_MATCH_OK
APSD_FIND_SAVE:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        STA             APSD_RESOLVED_GEN_LO
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        STA             APSD_RESOLVED_GEN_HI
                        BRA             APSD_MATCH_OK
                        ENDIF

                        IF              APSC_SLICE6_READER_BUILD
                        ELSE
APSD_MATCH_REPORT:
                        LDX             #<APSD_STALE_LO
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_CHUNK
                        BNE             APSD_REPORT_ADD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        CMP             APSD_RESOLVED_GEN_LO
                        BNE             APSD_REPORT_ADD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        CMP             APSD_RESOLVED_GEN_HI
                        BNE             APSD_REPORT_ADD
                        LDX             #<APSD_LIVE_LO
APSD_REPORT_ADD:
                        LDA             $7C00,X
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES+APS_RECORD_TRAILER_BYTES
                        ADC             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             $7C00,X
                        LDA             $7C01,X
                        ADC             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             $7C01,X
                        BRA             APSD_MATCH_OK
                        ENDIF

APSD_MATCH_CHUNK:
                        INC             APSC_TMP_FOUND
                        LDA             APSC_CHUNK_COUNT
                        CMP             #APS_OBJECT_MAX_CHUNKS
                        BCC             APSD_MATCH_ROOM
                        LDA             #APSC_STATUS_TOO_MANY
                        BRA             APSD_MATCH_ERROR
APSD_MATCH_ROOM:
                        LDA             APSC_ZP_SECTOR
                        SEC
                        SBC             #$08
                        TAX
                        LDA             #$01
APSD_MATCH_BIT:
                        CPX             #$00
                        BEQ             APSD_MATCH_BIT_READY
                        ASL             A
                        DEX
                        BRA             APSD_MATCH_BIT
APSD_MATCH_BIT_READY:
                        STA             APSC_TMP_BIT
                        AND             APSC_USED_MASK
                        BEQ             APSD_MATCH_NEW_SECTOR
                        LDA             #APSC_STATUS_CONFLICT
APSD_MATCH_ERROR:
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS
APSD_MATCH_NEW_SECTOR:
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
                        LDX             #$00
APSD_MATCH_COPY_BODY:
                        INY
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL,X
                        STA             (APSC_ZP_ROW_LO),Y
                        INX
                        CPX             #$04
                        BNE             APSD_MATCH_COPY_BODY
                        INY
                        LDA             #$00
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        STA             (APSC_ZP_ROW_LO),Y
                        INC             APSC_CHUNK_COUNT
                        JSR             APSC_READER_NEXT_ROW
                        SEC
                        RTS

APSD_CLEAR_PLAN:
                        STZ             APSC_CHUNK_COUNT
                        STZ             APSC_USED_MASK
                        STZ             APSC_TMP_REMAIN_LO
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        RTS

; Scan all eight sectors. Exact scans also attach the full-sector CRC to the
; row captured in that sector, giving the executor a compact media snapshot.
APSD_SCAN_ALL:
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSD_SCAN_ALL_LOOP:
                        JSR             APSC_SCAN_SECTOR
                        BCC             APSD_SCAN_FAIL
                        LDA             APSD_MODE
                        BNE             APSD_SCAN_NEXT
                        JSR             APSD_SAVE_ROW_CRC
APSD_SCAN_NEXT:
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSD_SCAN_ALL_LOOP
                        SEC
APSD_SCAN_FAIL:         RTS

APSD_SAVE_ROW_CRC:
                        LDX             APSC_CHUNK_COUNT
                        BEQ             APSD_SAVE_CRC_DONE
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
APSD_SAVE_CRC_ROW:
                        LDY             #APSC_PLAN_SECTOR
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_ZP_SECTOR
                        BNE             APSD_SAVE_CRC_NEXT
                        LDY             #APSC_PLAN_MEDIA_CRC_LO
                        LDA             APSW_CRC_LO
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSW_CRC_HI
                        STA             (APSC_ZP_ROW_LO),Y
                        JSR             APSC_READER_NEXT_ROW
APSD_SAVE_CRC_DONE:     RTS
APSD_SAVE_CRC_NEXT:
                        JSR             APSC_READER_NEXT_ROW
                        DEX
                        BNE             APSD_SAVE_CRC_ROW
                        RTS

APSD_VALIDATE_BODY:
                        CLD
                        JSR             APSC_CLEAR_RESULT
                        JSR             APSC_VALIDATE_REQUEST
                        BCC             APSD_VALIDATE_EARLY_ERROR
                        JSR             APSC_VALIDATE_SERVICES
                        BCC             APSD_VALIDATE_EARLY_ERROR
                        JSR             APSC_BOOT_SELECTOR
                        BCS             APSD_VALIDATE_BOOTED
APSD_VALIDATE_EARLY_ERROR:
                        JMP             APSD_RETURN_ERROR
APSD_VALIDATE_BOOTED:
                        IF              APSC_SLICE6_READER_BUILD
                        LDA             APSC_OBJECT_GEN_LO
                        ORA             APSC_OBJECT_GEN_HI
                        BNE             APSD_EXACT_REQUEST
                        INC             APSC_TMP_REMAIN_HI
                        LDA             #$FF
                        STA             APSD_CEILING_LO
                        STA             APSD_CEILING_HI
APSD_NEWEST_RETRY:
                        STZ             APSD_RESOLVED_GEN_LO
                        STZ             APSD_RESOLVED_GEN_HI
                        LDA             #APSD_MODE_FIND
                        STA             APSD_MODE
                        JSR             APSD_SCAN_ALL
                        BCS             APSD_NEWEST_FIND_OK
                        JMP             APSD_RETURN_ERROR
APSD_NEWEST_FIND_OK:
                        LDA             APSD_RESOLVED_GEN_LO
                        ORA             APSD_RESOLVED_GEN_HI
                        BNE             APSD_NEWEST_FOUND
                        JMP             APSD_NOT_FOUND
APSD_NEWEST_FOUND:
                        LDA             APSD_RESOLVED_GEN_LO
                        STA             APSC_OBJECT_GEN_LO
                        LDA             APSD_RESOLVED_GEN_HI
                        STA             APSC_OBJECT_GEN_HI
                        JSR             APSD_EXACT_SCAN
                        BCC             APSD_NEWEST_SCAN_ERROR
                        LDA             APSC_TMP_REMAIN_LO
                        BNE             APSD_NEWEST_LOWER
                        JSR             APSC_SORT_ROWS
                        JSR             APSC_VALIDATE_CHAIN
                        BCC             APSD_NEWEST_CHAIN_ERROR
                        BRA             APSD_RECONSTRUCT
APSD_NEWEST_SCAN_ERROR:
                        JMP             APSD_RESTORE_NEWEST_ERROR
APSD_NEWEST_CHAIN_ERROR:
                        LDA             APSC_STATUS
                        CMP             #APSC_STATUS_INCOMPLETE
                        BEQ             APSD_NEWEST_LOWER
                        JMP             APSD_RESTORE_NEWEST_ERROR
APSD_NEWEST_LOWER:
                        LDA             APSD_RESOLVED_GEN_LO
                        BNE             APSD_LOWER_LO
                        DEC             APSD_RESOLVED_GEN_HI
APSD_LOWER_LO:          DEC             APSD_RESOLVED_GEN_LO
                        LDA             APSD_RESOLVED_GEN_LO
                        STA             APSD_CEILING_LO
                        LDA             APSD_RESOLVED_GEN_HI
                        STA             APSD_CEILING_HI
                        STZ             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_OBJECT_GEN_LO
                        STZ             APSC_OBJECT_GEN_HI
                        JMP             APSD_NEWEST_RETRY
                        ELSE
                        JMP             APSD_EXACT_REQUEST
                        ENDIF

APSD_EXACT_REQUEST:
                        LDA             APSC_OBJECT_GEN_LO
                        STA             APSD_RESOLVED_GEN_LO
                        LDA             APSC_OBJECT_GEN_HI
                        STA             APSD_RESOLVED_GEN_HI
                        JSR             APSD_EXACT_SCAN
                        BCC             APSD_RETURN_ERROR
                        LDA             APSC_TMP_REMAIN_LO
                        BNE             APSD_ALREADY_DELETED
                        LDA             APSC_CHUNK_COUNT
                        BEQ             APSD_NOT_FOUND
                        JSR             APSC_SORT_ROWS
                        JSR             APSC_VALIDATE_CHAIN
                        BCC             APSD_RETURN_ERROR
APSD_RECONSTRUCT:
                        JSR             APSC_RECONSTRUCT
                        BCC             APSD_RETURN_ERROR
                        JSR             APSC_PARSE_BUFFER
                        BCC             APSD_RETURN_ERROR
                        LDA             APSC_CHUNK_COUNT
                        STA             APSD_PREP_CHUNK_COUNT
                        IF              APSC_SLICE6_READER_BUILD
                        ELSE
                        JSR             APSD_REPORT_SPACE
                        BCC             APSD_RETURN_ERROR
                        ENDIF
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_FAIL_SECTOR
                        LDA             APSC_TMP_REMAIN_HI
                        BEQ             APSD_VALIDATE_OK
                        STZ             APSC_OBJECT_GEN_LO
                        STZ             APSC_OBJECT_GEN_HI
APSD_VALIDATE_OK:       LDA             #APSC_STATUS_OK
                        SEC
                        RTS

APSD_EXACT_SCAN:
                        JSR             APSD_CLEAR_PLAN
                        STZ             APSD_MODE
                        JMP             APSD_SCAN_ALL

                        IF              APSC_SLICE6_READER_BUILD
APSD_RESTORE_NEWEST_ERROR:
                        STZ             APSC_OBJECT_GEN_LO
                        STZ             APSC_OBJECT_GEN_HI
                        BRA             APSD_RETURN_ERROR
                        ENDIF
APSD_NOT_FOUND:
                        LDA             #APSC_STATUS_NOT_FOUND
                        BRA             APSD_SET_VALIDATE_ERROR
APSD_ALREADY_DELETED:
                        LDA             #APSC_STATUS_ALREADY_DELETED
APSD_SET_VALIDATE_ERROR:
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
APSD_RETURN_ERROR:      LDA             APSC_STATUS
                        IF              APSC_SLICE6_READER_BUILD
                        PHA
                        LDA             APSC_TMP_REMAIN_HI
                        BEQ             APSD_RETURN_ERROR_EXACT
                        STZ             APSC_OBJECT_GEN_LO
                        STZ             APSC_OBJECT_GEN_HI
APSD_RETURN_ERROR_EXACT:
                        PLA
                        ENDIF
                        CLC
                        RTS

                        IF              APSC_SLICE6_READER_BUILD
                        ELSE
APSD_REPORT_SPACE:
                        STZ             APSD_LIVE_LO
                        STZ             APSD_LIVE_HI
                        STZ             APSD_STALE_LO
                        STZ             APSD_STALE_HI
                        STZ             APSD_FREE_LO
                        STZ             APSD_FREE_HI
                        STZ             APSD_BLOCKED_LO
                        STZ             APSD_BLOCKED_HI
                        LDA             #APSD_MODE_REPORT
                        STA             APSD_MODE
                        LDA             #$01
                        STA             APSC_TMP_BIT
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSD_REPORT_SECTOR:
                        LDA             APSC_TMP_BIT
                        AND             APSC_SECTOR_MASK
                        BEQ             APSD_REPORT_NEXT
                        JSR             APSC_SCAN_SECTOR
                        BCC             APSD_REPORT_FAIL
                        LDA             APSC_TMP_ACTIVE
                        BEQ             APSD_REPORT_NEXT
                        CMP             #$01
                        BEQ             APSD_REPORT_FREE
                        LDX             #<APSD_BLOCKED_LO
                        BRA             APSD_REPORT_TAIL
APSD_REPORT_FREE:       LDX             #<APSD_FREE_LO
APSD_REPORT_TAIL:
                        LDA             $7C00,X
                        SEC
                        SBC             APSC_TMP_TAIL_LO
                        STA             $7C00,X
                        LDA             $7C01,X
                        SBC             APSC_TMP_TAIL_HI
                        CLC
                        ADC             #$10
                        STA             $7C01,X
APSD_REPORT_NEXT:
                        ASL             APSC_TMP_BIT
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSD_REPORT_SECTOR
                        SEC
APSD_REPORT_FAIL:       RTS

APSD_DELETE_PLAN_BODY:
                        LDA             APSC_OBJECT_GEN_LO
                        ORA             APSC_OBJECT_GEN_HI
                        BEQ             APSD_BAD_PLAN_REQUEST
                        JSR             APSD_VALIDATE_BODY
                        BCS             APSD_PLAN_VALID
                        JMP             APSD_RETURN_ERROR
APSD_PLAN_VALID:
                        JSR             APSD_SAVE_PREP
                        LDA             #APSD_MODE_INSPECT
                        STA             APSD_MODE
                        LDA             #$01
                        STA             APSC_TMP_BIT
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSD_PLAN_SECTOR:
                        LDA             APSC_TMP_BIT
                        AND             APSC_SECTOR_MASK
                        BEQ             APSD_PLAN_NEXT
                        JSR             APSC_SCAN_SECTOR
                        BCS             APSD_PLAN_SCAN_OK
                        JMP             APSD_RETURN_ERROR
APSD_PLAN_SCAN_OK:
                        LDA             APSC_TMP_ACTIVE
                        CMP             #$01
                        BNE             APSD_PLAN_NEXT
                        LDA             APSC_TMP_TAIL_LO
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES+APS_RECORD_TRAILER_BYTES
                        STA             APSC_TMP_COMMIT_LO
                        LDA             APSC_TMP_TAIL_HI
                        ADC             #$00
                        CMP             #$10
                        BCC             APSD_PLAN_FOUND
APSD_PLAN_NEXT:
                        ASL             APSC_TMP_BIT
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSD_PLAN_SECTOR
                        LDA             #APSC_STATUS_NO_SPACE
                        BRA             APSD_PLAN_ERROR
APSD_PLAN_FOUND:
                        LDA             APSC_ZP_SECTOR
                        STA             APSD_TARGET_SECTOR
                        LDA             APSC_TMP_TAIL_LO
                        STA             APSD_TARGET_OFF_LO
                        LDA             APSC_TMP_TAIL_HI
                        STA             APSD_TARGET_OFF_HI
                        LDA             APSW_CRC_LO
                        STA             APSD_TARGET_CRC_LO
                        LDA             APSW_CRC_HI
                        STA             APSD_TARGET_CRC_HI
                        LDA             #APSC_STATUS_PREPARED
                        STA             APSC_STATUS
                        LDA             #APSC_STATUS_PREPARED
                        SEC
                        RTS
APSD_BAD_PLAN_REQUEST:  LDA             #APSC_STATUS_BAD_REQUEST
APSD_PLAN_ERROR:        STA             APSC_STATUS
                        LDA             #APSC_PHASE_PLAN
                        STA             APSC_FAIL_PHASE
                        JMP             APSD_RETURN_ERROR

APSD_SAVE_PREP:
                        LDA             APSC_BANK
                        STA             APSD_PREP_BANK
                        LDA             APSC_SECTOR_MASK
                        STA             APSD_PREP_MASK
                        LDX             #$03
APSD_SAVE_PREP_FIELDS:
                        LDA             APSC_OBJECT_LO,X
                        STA             APSD_PREP_OBJECT_LO,X
                        DEX
                        BPL             APSD_SAVE_PREP_FIELDS
                        LDA             APSC_PACKAGE_LEN_LO
                        STA             APSD_PREP_LENGTH_LO
                        LDA             APSC_PACKAGE_LEN_HI
                        STA             APSD_PREP_LENGTH_HI
                        RTS

                        ENDIF

                        IF              APSC_SLICE6_READER_BUILD
APSD_LIST_BODY:
                        JSR             APSD_VALIDATE_BODY
                        BCS             APSD_LIST_VALID
                        JMP             APSD_RETURN_ERROR
APSD_LIST_VALID:
                        LDX             #<APSD_MSG_ROW
                        LDY             #>APSD_MSG_ROW
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSC_OBJECT_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSC_OBJECT_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        LDX             #<APSD_MSG_GEN
                        LDY             #>APSD_MSG_GEN
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSD_RESOLVED_GEN_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSD_RESOLVED_GEN_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        LDX             #<APSD_MSG_LEN
                        LDY             #>APSD_MSG_LEN
                        JSR             APSC_WRITE_CSTRING
                        LDA             APSC_PACKAGE_LEN_HI
                        JSR             APSC_WRITE_HEX_BYTE
                        LDA             APSC_PACKAGE_LEN_LO
                        JSR             APSC_WRITE_HEX_BYTE
                        JSR             APSC_WRITE_CRLF
                        LDX             #<APSD_MSG_OK
                        LDY             #>APSD_MSG_OK
                        JSR             APSC_WRITE_CSTRING
                        JSR             APSC_WRITE_CRLF
                        LDA             #APSC_STATUS_OK
                        SEC
                        RTS

APSD_LOAD_BODY:
                        JSR             APSD_VALIDATE_BODY
                        BCS             APSD_LOAD_VALID
                        JMP             APSD_RETURN_ERROR
APSD_LOAD_VALID:
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
                        BCS             APSD_LOAD_SERVICE_OK
                        JMP             APSC_READER_AP_INVALID
APSD_LOAD_SERVICE_OK:
                        STX             APSC_ENTRY_LO
                        STY             APSC_ENTRY_HI
                        JSR             APSD_RUN_ENTRY
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        SEC
                        RTS
APSD_RUN_ENTRY:         JMP             (APSC_ENTRY_LO)
                        ENDIF

                        INCLUDE         "ASM/ap-store-v1-chain-reader.inc"

; ----------------------------------------------------------------------------
; AP Store V1 Slice 6 tombstone executor.  The read-only planner has already
; validated the AP and saved one full-sector CRC per chunk sector.  EXECUTE
; rechecks the entire named bank and writes only a 20-byte header plus commit.
; ----------------------------------------------------------------------------

APSC_MATCH_ACTION:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_TOMBSTONE
                        BNE             APSD_EXEC_MATCH_CHUNK
                        LDA             #APSC_STATUS_ALREADY_DELETED
                        STA             APSC_STATUS
                        CLC
                        RTS
APSD_EXEC_MATCH_CHUNK:
                        JSR             APSD_EXEC_FIND_ROW
                        BCC             APSD_EXEC_MATCH_CHANGED
                        INC             APSC_TMP_REMAIN_LO
                        INC             APSC_TMP_FOUND
                        SEC
                        RTS
APSD_EXEC_MATCH_CHANGED:
                        LDA             #APSC_STATUS_MEDIA_CHANGED
                        STA             APSC_STATUS
                        CLC
                        RTS

APSD_EXEC_FIND_ROW:
                        LDX             APSD_PREP_CHUNK_COUNT
                        BEQ             APSD_EXEC_ROW_MISS
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
APSD_EXEC_FIND_ROW_LOOP:
                        LDY             #APSC_PLAN_SECTOR
                        LDA             (APSC_ZP_ROW_LO),Y
                        CMP             APSC_ZP_SECTOR
                        BEQ             APSD_EXEC_ROW_FOUND
                        JSR             APSD_EXEC_NEXT_ROW
                        DEX
                        BNE             APSD_EXEC_FIND_ROW_LOOP
APSD_EXEC_ROW_MISS:     CLC
                        RTS
APSD_EXEC_ROW_FOUND:    SEC
                        RTS

APSD_DELETE_EXECUTE_BODY:
                        CLD
                        LDA             APSC_CONFIRM
                        CMP             #APSC_CONFIRM_EXECUTE
                        BEQ             APSD_EXEC_CONFIRMED
                        STZ             APSC_CONFIRM
                        LDA             #APSC_STATUS_NOT_CONFIRMED
                        BRA             APSD_EXEC_POLICY_ERROR
APSD_EXEC_CONFIRMED:
                        STZ             APSC_CONFIRM
                        LDA             APSC_STATUS
                        CMP             #APSC_STATUS_PREPARED
                        BNE             APSD_EXEC_CHANGED
                        JSR             APSC_VALIDATE_REQUEST
                        BCC             APSD_EXEC_RETURN_ERROR
                        JSR             APSD_EXEC_COMPARE_REQUEST
                        BCC             APSD_EXEC_CHANGED
                        JSR             APSC_BOOT_SELECTOR
                        BCC             APSD_EXEC_RETURN_ERROR
                        STZ             APSC_TMP_REMAIN_LO
                        STZ             APSC_TMP_REMAIN_HI
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSD_EXEC_SCAN_LOOP:
                        JSR             APSC_SCAN_SECTOR
                        BCC             APSD_EXEC_RETURN_ERROR
                        LDA             APSC_TMP_FOUND
                        BEQ             APSD_EXEC_CHECK_TARGET
                        JSR             APSD_EXEC_COMPARE_ROW_CRC
                        BCC             APSD_EXEC_CHANGED
APSD_EXEC_CHECK_TARGET:
                        LDA             APSC_ZP_SECTOR
                        CMP             APSD_TARGET_SECTOR
                        BNE             APSD_EXEC_SCAN_NEXT
                        JSR             APSD_EXEC_COMPARE_TARGET
                        BCC             APSD_EXEC_CHANGED
                        INC             APSC_TMP_REMAIN_HI
APSD_EXEC_SCAN_NEXT:
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSD_EXEC_SCAN_LOOP
                        LDA             APSC_TMP_REMAIN_LO
                        CMP             APSD_PREP_CHUNK_COUNT
                        BNE             APSD_EXEC_CHANGED
                        LDA             APSC_TMP_REMAIN_HI
                        CMP             #$01
                        BNE             APSD_EXEC_CHANGED
                        JSR             APSD_EXEC_BUILD_HEADER
                        JSR             APSD_EXEC_PROGRAM
                        BCC             APSD_EXEC_RETURN_ERROR
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_FAIL_SECTOR
                        LDA             #APSC_STATUS_OK
                        SEC
                        RTS
APSD_EXEC_CHANGED:
                        LDA             #APSC_STATUS_MEDIA_CHANGED
APSD_EXEC_POLICY_ERROR:
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_POLICY
                        STA             APSC_FAIL_PHASE
APSD_EXEC_RETURN_ERROR:
                        LDA             APSC_STATUS
                        CLC
                        RTS

APSD_EXEC_COMPARE_REQUEST:
                        LDA             APSC_BANK
                        CMP             APSD_PREP_BANK
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDA             APSC_SECTOR_MASK
                        CMP             APSD_PREP_MASK
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDX             #$03
APSD_EXEC_COMPARE_ID:
                        LDA             APSC_OBJECT_LO,X
                        CMP             APSD_PREP_OBJECT_LO,X
                        BNE             APSD_EXEC_COMPARE_BAD
                        DEX
                        BPL             APSD_EXEC_COMPARE_ID
                        SEC
                        RTS
APSD_EXEC_COMPARE_BAD:  CLC
                        RTS

APSD_EXEC_COMPARE_ROW_CRC:
                        JSR             APSD_EXEC_FIND_ROW
                        BCC             APSD_EXEC_COMPARE_BAD
                        LDY             #APSC_PLAN_MEDIA_CRC_LO
                        LDA             APSW_CRC_LO
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSD_EXEC_COMPARE_BAD
                        INY
                        LDA             APSW_CRC_HI
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSD_EXEC_COMPARE_BAD
                        SEC
                        RTS

APSD_EXEC_COMPARE_TARGET:
                        LDA             APSC_TMP_ACTIVE
                        CMP             #$01
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDA             APSC_TMP_TAIL_LO
                        CMP             APSD_TARGET_OFF_LO
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDA             APSC_TMP_TAIL_HI
                        CMP             APSD_TARGET_OFF_HI
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDA             APSW_CRC_LO
                        CMP             APSD_TARGET_CRC_LO
                        BNE             APSD_EXEC_COMPARE_BAD
                        LDA             APSW_CRC_HI
                        CMP             APSD_TARGET_CRC_HI
                        BNE             APSD_EXEC_COMPARE_BAD
                        SEC
                        RTS

APSD_EXEC_NEXT_ROW:
                        LDA             APSC_ZP_ROW_LO
                        CLC
                        ADC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_ROW_LO
                        BCC             APSD_EXEC_NEXT_ROW_DONE
                        INC             APSC_ZP_ROW_HI
APSD_EXEC_NEXT_ROW_DONE:
                        RTS

APSD_EXEC_BUILD_HEADER:
                        LDA             #$FF
                        LDX             #APS_RECORD_HEADER_BYTES-1
APSD_EXEC_HEADER_FILL:
                        STA             APSC_RECORD_HEADER_BASE,X
                        DEX
                        BPL             APSD_EXEC_HEADER_FILL
                        LDA             #APS_RECORD_SIG0
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG
                        LDA             #APS_RECORD_SIG1
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG+1
                        LDA             #APS_RECORD_VERSION
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_VERSION
                        LDA             #APS_RECORD_TOMBSTONE
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        STZ             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        STZ             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        STZ             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        STZ             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STZ             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        LDX             #$03
APSD_EXEC_HEADER_ID:
                        LDA             APSC_OBJECT_LO,X
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT,X
                        DEX
                        BPL             APSD_EXEC_HEADER_ID
                        LDA             #$C5
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV
                        LDA             #$9D
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV+1
                        LDA             #$1C
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV+2
                        LDA             #$81
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV+3
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDY             #$00
APSD_EXEC_HEADER_CRC:
                        LDA             APSC_RECORD_HEADER_BASE,Y
                        JSR             APSC_CRC16_BYTE
                        INY
                        CPY             #APS_RH_OFF_CRC16
                        BNE             APSD_EXEC_HEADER_CRC
                        LDA             APSW_CRC_LO
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16
                        LDA             APSW_CRC_HI
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16+1
                        RTS

APSD_EXEC_PROGRAM:
                        PHP
                        SEI
                        LDA             APSD_TARGET_SECTOR
                        STA             APSC_FAIL_SECTOR
                        LDA             APSC_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSD_EXEC_PROGRAM_RESTORE_ERROR
                        LDA             APSD_TARGET_OFF_LO
                        STA             APSW_PTR_LO
                        LDA             APSD_TARGET_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             APSD_TARGET_OFF_HI
                        STA             APSW_PTR_HI
                        LDA             #<APSC_RECORD_HEADER_BASE
                        STA             APSC_ZP_SRC_LO
                        LDA             #>APSC_RECORD_HEADER_BASE
                        STA             APSC_ZP_SRC_HI
                        LDA             #APS_RECORD_HEADER_BYTES
                        STA             APSC_ZP_COUNT_LO
                        STZ             APSC_ZP_COUNT_HI
                        LDA             #APSC_PHASE_HEADER
                        STA             APSC_FAIL_PHASE
                        JSR             APSD_EXEC_PROGRAM_BYTES
                        BCC             APSD_EXEC_PROGRAM_FAILED
                        LDA             #APSC_PHASE_COMMIT
                        STA             APSC_FAIL_PHASE
                        LDA             #APS_RECORD_COMMIT
                        LDY             #$00
                        JSR             APSD_EXEC_FLASH_BYTE
                        BCC             APSD_EXEC_PROGRAM_FAILED
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSD_EXEC_PROGRAM_RESTORE_FAIL
                        PLP
                        SEC
                        RTS
APSD_EXEC_PROGRAM_FAILED:
                        LDA             #APSC_STATUS_PROGRAM_FAILED
                        STA             APSC_STATUS
APSD_EXEC_PROGRAM_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSD_EXEC_PROGRAM_RESTORE_FAIL
                        PLP
                        CLC
                        RTS
APSD_EXEC_PROGRAM_RESTORE_FAIL:
                        JSR             APSC_FORCE_BANK3
                        LDA             #APSC_STATUS_RESTORE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_RESTORE
                        STA             APSC_FAIL_PHASE
                        PLP
                        CLC
                        RTS

APSD_EXEC_PROGRAM_BYTES:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSD_EXEC_PROGRAM_DONE
                        LDY             #$00
                        LDA             (APSC_ZP_SRC_LO),Y
                        JSR             APSD_EXEC_FLASH_BYTE
                        BCC             APSD_EXEC_PROGRAM_FAIL
                        JSR             APSC_INC_PTR
                        INC             APSC_ZP_SRC_LO
                        BNE             APSD_EXEC_SOURCE_OK
                        INC             APSC_ZP_SRC_HI
APSD_EXEC_SOURCE_OK:
                        JSR             APSC_DEC_COUNT
                        BRA             APSD_EXEC_PROGRAM_BYTES
APSD_EXEC_PROGRAM_DONE: SEC
                        RTS
APSD_EXEC_PROGRAM_FAIL: CLC
                        RTS

APSD_EXEC_FLASH_BYTE:
                        STA             APSW_BYTE
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSD_EXEC_WRITE_OK
                        AND             APSW_BYTE
                        CMP             APSW_BYTE
                        BNE             APSD_EXEC_WRITE_FAIL
                        LDA             #$AA
                        STA             APSW_FLASH_UNLOCK1
                        LDA             #$55
                        STA             APSW_FLASH_UNLOCK2
                        LDA             #$A0
                        STA             APSW_FLASH_UNLOCK1
                        LDA             APSW_BYTE
                        STA             (APSW_PTR_LO),Y
                        STZ             APSC_TMP_TMO0
                        STZ             APSC_TMP_TMO1
                        LDA             #APSW_WRITE_TIMEOUT_HI
                        STA             APSC_TMP_TMO2
APSD_EXEC_WRITE_POLL:
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSD_EXEC_WRITE_OK
                        DEC             APSC_TMP_TMO0
                        BNE             APSD_EXEC_WRITE_POLL
                        DEC             APSC_TMP_TMO1
                        BNE             APSD_EXEC_WRITE_POLL
                        DEC             APSC_TMP_TMO2
                        BNE             APSD_EXEC_WRITE_POLL
                        LDA             #$F0
                        STA             APSW_FLASH_UNLOCK1
APSD_EXEC_WRITE_FAIL:   CLC
                        RTS
APSD_EXEC_WRITE_OK:     SEC
                        RTS

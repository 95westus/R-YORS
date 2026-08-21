; ----------------------------------------------------------------------------
; AP Store V1 Slice 5 arbitrary-sector chain tools.
;
; Built twice from ap-store-v1-sector-tool.asm.  The installer and reader are
; mutually exclusive fixed AP v2 images in the $7000-$79FF transient tray.
; They use only transient ZP $A0-$AF and private card $7C80-$7D3F.
; ----------------------------------------------------------------------------

APSC_ZP_SECTOR          EQU             $A5
APSC_ZP_ROW_LO          EQU             $A6
APSC_ZP_ROW_HI          EQU             $A7
APSC_ZP_COUNT_LO        EQU             $A8
APSC_ZP_COUNT_HI        EQU             $A9
APSC_ZP_SRC_LO          EQU             $AC
APSC_ZP_SRC_HI          EQU             $AD
APSC_ZP_DST_LO          EQU             $AE
APSC_ZP_DST_HI          EQU             $AF

APSC_TMP_TAIL_LO        EQU             APSC_RECORD_HEADER_BASE+$14
APSC_TMP_TAIL_HI        EQU             APSC_RECORD_HEADER_BASE+$15
APSC_TMP_LOGICAL_LO     EQU             APSC_RECORD_HEADER_BASE+$16
APSC_TMP_LOGICAL_HI     EQU             APSC_RECORD_HEADER_BASE+$17
APSC_TMP_REMAIN_LO      EQU             APSC_RECORD_HEADER_BASE+$18
APSC_TMP_REMAIN_HI      EQU             APSC_RECORD_HEADER_BASE+$19
APSC_TMP_LENGTH_LO      EQU             APSC_RECORD_HEADER_BASE+$1A
APSC_TMP_LENGTH_HI      EQU             APSC_RECORD_HEADER_BASE+$1B
APSC_TMP_BIT            EQU             APSC_RECORD_HEADER_BASE+$1C
APSC_TMP_FOUND          EQU             APSC_RECORD_HEADER_BASE+$1D
APSC_TMP_ACTIVE         EQU             APSC_RECORD_HEADER_BASE+$1E
APSC_TMP_END_HI         EQU             APSC_RECORD_HEADER_BASE+$1F
APSC_HASH0              EQU             APSC_RECORD_HEADER_BASE+$20
APSC_HASH1              EQU             APSC_RECORD_HEADER_BASE+$21
APSC_HASH2              EQU             APSC_RECORD_HEADER_BASE+$22
APSC_HASH3              EQU             APSC_RECORD_HEADER_BASE+$23
APSC_TERM0              EQU             APSC_RECORD_HEADER_BASE+$24
APSC_TERM1              EQU             APSC_RECORD_HEADER_BASE+$25
APSC_TERM2              EQU             APSC_RECORD_HEADER_BASE+$26
APSC_TERM3              EQU             APSC_RECORD_HEADER_BASE+$27
APSC_TMP_COMMIT_LO      EQU             APSC_RECORD_HEADER_BASE+$28
APSC_TMP_COMMIT_HI      EQU             APSC_RECORD_HEADER_BASE+$29
APSC_TMP_TMO0           EQU             APSC_RECORD_HEADER_BASE+$2A
APSC_TMP_TMO1           EQU             APSC_RECORD_HEADER_BASE+$2B
APSC_TMP_TMO2           EQU             APSC_RECORD_HEADER_BASE+$2C
APSC_TMP_SWAP           EQU             APSC_RECORD_HEADER_BASE+$30

APSC_PACKAGE_BUFFER     EQU             $0A00

START:
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
APSD_SAFE:              RTS
                        NOP
                        NOP
APSD_DELETE_EXECUTE:    JMP             APSD_DELETE_EXECUTE_BODY
                        ELSE
                        IF              APSC_SLICE6_READER_BUILD
APSD_LIST:              JMP             APSD_LIST_BODY
APSD_VALIDATE:          JMP             APSD_VALIDATE_BODY
APSD_LOAD:              JMP             APSD_LOAD_BODY
                        ELSE
APSD_SAFE:              RTS
                        NOP
                        NOP
APSD_DELETE_PLAN:       JMP             APSD_DELETE_PLAN_BODY
                        ENDIF
                        ENDIF
                        ELSE
                        IF              APSC_CHAIN_READER_BUILD
APSC_LIST:              JMP             APSC_LIST_BODY
APSC_VALIDATE:          JMP             APSC_VALIDATE_BODY
APSC_LOAD:              JMP             APSC_LOAD_BODY
                        ELSE
APSC_INSTALL_PLAN:      JMP             APSC_INSTALL_PLAN_BODY
APSC_INSTALL_EXECUTE:   JMP             APSC_INSTALL_EXECUTE_BODY
                        ENDIF
                        ENDIF

; ----------------------------------------------------------------------------
; Shared service, hashing, selector, and read-only catalog primitives.
; ----------------------------------------------------------------------------

APSC_CLEAR_RESULT:
                        LDX             #APSC_CARD_END-APSC_CONFIRM
APSC_CLEAR_RESULT_LOOP:
                        STZ             APSC_CONFIRM,X
                        DEX
                        BPL             APSC_CLEAR_RESULT_LOOP
                        RTS

APSC_VALIDATE_REQUEST:
                        LDA             APSC_BANK
                        CMP             #$03
                        BCS             APSC_BAD_REQUEST
                        LDA             APSC_OBJECT_LO
                        ORA             APSC_OBJECT_HI
                        BEQ             APSC_BAD_REQUEST
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
                        LDA             APSC_OBJECT_GEN_LO
                        ORA             APSC_OBJECT_GEN_HI
                        BEQ             APSC_BAD_REQUEST
                        ENDIF
                        ELSE
                        LDA             APSC_OBJECT_GEN_LO
                        ORA             APSC_OBJECT_GEN_HI
                        BEQ             APSC_BAD_REQUEST
                        ENDIF
                        SEC
                        RTS
APSC_BAD_REQUEST:
                        LDA             #APSC_STATUS_BAD_REQUEST
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_POLICY
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS

APSC_VALIDATE_SERVICES:
                        LDA             ASM_ABI_SVC_SIG0
                        CMP             #ASM_ABI_SVC_SIG0_VALUE
                        BNE             APSC_SERVICES_BAD
                        LDA             ASM_ABI_SVC_SIG1
                        CMP             #ASM_ABI_SVC_SIG1_VALUE
                        BNE             APSC_SERVICES_BAD
                        LDA             ASM_ABI_SVC_VERSION
                        CMP             #ASM_ABI_SVC_VERSION_VALUE
                        BNE             APSC_SERVICES_BAD
                        LDA             ASM_ABI_SVC_COUNT
                        CMP             #ASM_ABI_SVC_VECTOR_COUNT
                        BCC             APSC_SERVICES_BAD
                        LDA             #$00
                        LDX             #ASM_ABI_SVC_CHECKSUM-ASM_ABI_SVC_SIG0-1
APSC_SERVICES_CHECKSUM:
                        EOR             ASM_ABI_SVC_SIG0,X
                        DEX
                        BPL             APSC_SERVICES_CHECKSUM
                        CMP             ASM_ABI_SVC_CHECKSUM
                        BNE             APSC_SERVICES_BAD
                        SEC
                        RTS
APSC_SERVICES_BAD:
                        LDA             #APSC_STATUS_SERVICE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_VALIDATE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS

APSC_BOOT_SELECTOR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_SERVICE
                        BCS             APSC_BOOT_OK
                        LDA             #APSC_STATUS_SERVICE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_CATALOG
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS
APSC_BOOT_OK:
                        SEC
                        RTS

APSC_FORCE_BANK3:
                        LDA             #STR8_BANK_STATE_MASK
                        TRB             STR8_BANK_STATE_BYTE
                        LDA             #STR8_BANK_STATE_MASK
                        TSB             STR8_BANK_STATE_BYTE
                        RTS

APSC_CALL_AP_SERVICE:
                        LDA             ASM_ABI_AP_SERVICE
                        STA             APSW_CALL_LO
                        LDA             ASM_ABI_AP_SERVICE+1
                        STA             APSW_CALL_HI
                        ORA             APSW_CALL_LO
                        BEQ             APSC_SERVICES_BAD
                        JMP             (APSW_CALL_LO)

APSC_PARSE_SOURCE:
                        LDA             APSC_SOURCE_LO
                        STA             ASM_ABI_AP_SRC
                        LDA             APSC_SOURCE_HI
                        STA             ASM_ABI_AP_SRC+1
                        LDA             #ASM_ABI_AP_OP_PARSE
                        STA             ASM_ABI_AP_OP
                        JSR             APSC_CALL_AP_SERVICE
                        BCS             APSC_SOURCE_PARSED
                        LDA             APSC_STATUS
                        CMP             #APSC_STATUS_SERVICE_FAILED
                        BEQ             APSC_PARSE_RETURN
                        LDA             #APSC_STATUS_AP_INVALID
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_SOURCE
                        STA             APSC_FAIL_PHASE
                        CLC
                        RTS
APSC_SOURCE_PARSED:
                        LDA             ASM_ABI_AP_PACKAGE_LEN
                        STA             APSC_PACKAGE_LEN_LO
                        LDA             ASM_ABI_AP_PACKAGE_LEN+1
                        STA             APSC_PACKAGE_LEN_HI
                        LDA             APSC_SOURCE_LO
                        STA             APSW_PTR_LO
                        LDA             APSC_SOURCE_HI
                        STA             APSW_PTR_HI
                        LDA             APSC_PACKAGE_LEN_LO
                        STA             APSC_ZP_COUNT_LO
                        LDA             APSC_PACKAGE_LEN_HI
                        STA             APSC_ZP_COUNT_HI
                        JSR             APSC_FNV_INIT
APSC_HASH_SOURCE_LOOP:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSC_HASH_SOURCE_DONE
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSC_FNV_UPDATE
                        JSR             APSC_INC_PTR
                        JSR             APSC_DEC_COUNT
                        BRA             APSC_HASH_SOURCE_LOOP
APSC_HASH_SOURCE_DONE:
                        LDX             #$03
APSC_HASH_SOURCE_SAVE:
                        LDA             APSC_HASH0,X
                        STA             APSC_PACKAGE_FNV0,X
                        DEX
                        BPL             APSC_HASH_SOURCE_SAVE
                        SEC
APSC_PARSE_RETURN:
                        RTS

APSC_FNV_INIT:
                        LDA             #$C5
                        STA             APSC_HASH0
                        LDA             #$9D
                        STA             APSC_HASH1
                        LDA             #$1C
                        STA             APSC_HASH2
                        LDA             #$81
                        STA             APSC_HASH3
                        RTS

APSC_FNV_UPDATE:
                        EOR             APSC_HASH0
                        STA             APSC_HASH0
                        LDX             #$03
APSC_FNV_COPY:
                        LDA             APSC_HASH0,X
                        STA             APSC_TERM0,X
                        DEX
                        BPL             APSC_FNV_COPY
                        LDX             #$01
                        JSR             APSC_FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             APSC_FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             APSC_FNV_SHIFT_ADD
                        LDX             #$01
                        JSR             APSC_FNV_SHIFT_ADD
                        LDA             APSC_HASH3
                        CLC
                        ADC             APSC_TERM1
                        STA             APSC_HASH3
                        RTS

APSC_FNV_SHIFT_ADD:
                        ASL             APSC_TERM0
                        ROL             APSC_TERM1
                        ROL             APSC_TERM2
                        ROL             APSC_TERM3
                        DEX
                        BNE             APSC_FNV_SHIFT_ADD
                        CLC
                        LDA             APSC_HASH0
                        ADC             APSC_TERM0
                        STA             APSC_HASH0
                        LDA             APSC_HASH1
                        ADC             APSC_TERM1
                        STA             APSC_HASH1
                        LDA             APSC_HASH2
                        ADC             APSC_TERM2
                        STA             APSC_HASH2
                        LDA             APSC_HASH3
                        ADC             APSC_TERM3
                        STA             APSC_HASH3
                        RTS

APSC_CRC16_BYTE:
                        EOR             APSW_CRC_HI
                        STA             APSW_CRC_HI
                        PHX
                        LDX             #$08
APSC_CRC16_BIT:
                        ASL             APSW_CRC_LO
                        ROL             APSW_CRC_HI
                        BCC             APSC_CRC16_NEXT
                        LDA             APSW_CRC_LO
                        EOR             #$21
                        STA             APSW_CRC_LO
                        LDA             APSW_CRC_HI
                        EOR             #$10
                        STA             APSW_CRC_HI
APSC_CRC16_NEXT:
                        DEX
                        BNE             APSC_CRC16_BIT
                        PLX
                        RTS

APSC_INC_PTR:
                        INC             APSW_PTR_LO
                        BNE             APSC_INC_PTR_DONE
                        INC             APSW_PTR_HI
APSC_INC_PTR_DONE:
                        RTS

APSC_DEC_COUNT:
                        LDA             APSC_ZP_COUNT_LO
                        BNE             APSC_DEC_COUNT_LO
                        DEC             APSC_ZP_COUNT_HI
APSC_DEC_COUNT_LO:
                        DEC             APSC_ZP_COUNT_LO
                        RTS

APSC_PTR_FROM_OFFSET:
                        LDA             APSC_TMP_TAIL_LO
                        STA             APSW_PTR_LO
                        LDA             APSC_ZP_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             APSC_TMP_TAIL_HI
                        STA             APSW_PTR_HI
                        RTS

; Return C=1 with TMP_ACTIVE=1 and a validated append tail for ACTIVE AS1.
; Opaque/erased/non-active sectors return C=1 with TMP_ACTIVE=0. A malformed
; AS1 header or committed log returns C=0. Full-sector CRC remains in A2:A3.
APSC_SCAN_SECTOR:
                        PHP
                        SEI
                        STZ             APSC_TMP_ACTIVE
                        STZ             APSC_TMP_FOUND
                        LDA             APSC_ZP_SECTOR
                        STA             APSC_FAIL_SECTOR
                        LDA             APSC_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCS             APSC_SCAN_SELECTED
                        JMP             APSC_SCAN_SELECT_ERROR
APSC_SCAN_SELECTED:
                        STZ             APSW_PTR_LO
                        LDA             APSC_ZP_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        LDY             #$00
APSC_COPY_SECTOR_HEADER:
                        LDA             (APSW_PTR_LO),Y
                        STA             APSC_RECORD_HEADER_BASE,Y
                        INY
                        CPY             #APS_SECTOR_HEADER_BYTES
                        BNE             APSC_COPY_SECTOR_HEADER
                        LDA             APSC_RECORD_HEADER_BASE+APS_SH_OFF_SIG
                        CMP             #APS_SECTOR_SIG0
                        BEQ             APSC_SCAN_SIG0_OK
                        JMP             APSC_SCAN_OPAQUE
APSC_SCAN_SIG0_OK:
                        LDA             APSC_RECORD_HEADER_BASE+APS_SH_OFF_SIG+1
                        CMP             #APS_SECTOR_SIG1
                        BEQ             APSC_SCAN_SIG1_OK
                        JMP             APSC_SCAN_OPAQUE
APSC_SCAN_SIG1_OK:
                        LDA             APSC_RECORD_HEADER_BASE+APS_SH_OFF_SIG+2
                        CMP             #APS_SECTOR_SIG2
                        BEQ             APSC_SCAN_SIG2_OK
                        JMP             APSC_SCAN_OPAQUE
APSC_SCAN_SIG2_OK:
                        LDA             APSC_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             APSC_ZP_SECTOR
                        CMP             APSC_RECORD_HEADER_BASE+APS_SH_OFF_LOCATION
                        BEQ             APSC_SCAN_LOCATION_OK
                        JMP             APSC_SCAN_AS1_BAD
APSC_SCAN_LOCATION_OK:
                        LDX             #$04
APSC_SCAN_RESERVED:
                        LDA             APSC_RECORD_HEADER_BASE+APS_SH_OFF_RESERVED,X
                        CMP             #$FF
                        BEQ             APSC_SCAN_RESERVED_OK
                        JMP             APSC_SCAN_AS1_BAD
APSC_SCAN_RESERVED_OK:
                        DEX
                        BPL             APSC_SCAN_RESERVED
                        JSR             APSC_FNV_INIT
                        LDY             #$00
APSC_SCAN_HEADER_FNV:
                        LDA             APSC_RECORD_HEADER_BASE,Y
                        JSR             APSC_FNV_UPDATE
                        INY
                        CPY             #APS_SH_OFF_FNV
                        BNE             APSC_SCAN_HEADER_FNV
                        LDX             #$03
APSC_SCAN_HEADER_FNV_COMPARE:
                        LDA             APSC_HASH0,X
                        CMP             APSC_RECORD_HEADER_BASE+APS_SH_OFF_FNV,X
                        BEQ             APSC_SCAN_HEADER_FNV_OK
                        JMP             APSC_SCAN_AS1_BAD
APSC_SCAN_HEADER_FNV_OK:
                        DEX
                        BPL             APSC_SCAN_HEADER_FNV_COMPARE
                        LDA             APSC_RECORD_HEADER_BASE+APS_SH_OFF_STATE
                        CMP             #APS_SECTOR_STATE_ACTIVE
                        BEQ             APSC_SCAN_ACTIVE
                        JMP             APSC_SCAN_OPAQUE
APSC_SCAN_ACTIVE:
                        INC             APSC_TMP_ACTIVE
                        LDA             #APS_SECTOR_HEADER_BYTES
                        STA             APSC_TMP_TAIL_LO
                        STZ             APSC_TMP_TAIL_HI
APSC_SCAN_RECORD:
                        LDA             APSC_TMP_TAIL_HI
                        CMP             #$10
                        BCC             APSC_SCAN_RECORD_IN_RANGE
                        JMP             APSC_SCAN_LOG_FULL
APSC_SCAN_RECORD_IN_RANGE:
                        JSR             APSC_PTR_FROM_OFFSET
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BNE             APSC_SCAN_RECORD_PRESENT
                        JMP             APSC_SCAN_TAIL
APSC_SCAN_RECORD_PRESENT:
                        LDA             APSC_TMP_TAIL_LO
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES
                        STA             APSC_TMP_COMMIT_LO
                        LDA             APSC_TMP_TAIL_HI
                        ADC             #$00
                        STA             APSC_TMP_COMMIT_HI
                        CMP             #$10
                        BCC             APSC_SCAN_HEADER_FITS
                        JMP             APSC_SCAN_LOG_BAD
APSC_SCAN_HEADER_FITS:
                        LDY             #$00
APSC_COPY_RECORD_HEADER:
                        LDA             (APSW_PTR_LO),Y
                        STA             APSC_RECORD_HEADER_BASE,Y
                        INY
                        CPY             #APS_RECORD_HEADER_BYTES
                        BNE             APSC_COPY_RECORD_HEADER
                        JSR             APSC_VALIDATE_RECORD_HEADER
                        BCS             APSC_SCAN_RECORD_VALID
                        IF              APSC_SLICE6_BUILD
                        JMP             APSC_SCAN_CLOSED
                        ELSE
                        JMP             APSC_SCAN_LOG_BAD
                        ENDIF
APSC_SCAN_RECORD_VALID:
                        LDA             APSC_TMP_COMMIT_LO
                        CLC
                        ADC             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             APSC_TMP_COMMIT_LO
                        LDA             APSC_TMP_COMMIT_HI
                        ADC             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             APSC_TMP_COMMIT_HI
                        CMP             #$10
                        BCC             APSC_SCAN_PAYLOAD_FITS
                        JMP             APSC_SCAN_LOG_BAD
APSC_SCAN_PAYLOAD_FITS:
                        LDA             APSC_TMP_TAIL_LO
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES
                        STA             APSC_TMP_TAIL_LO
                        LDA             APSC_TMP_TAIL_HI
                        ADC             #$00
                        STA             APSC_TMP_TAIL_HI
                        JSR             APSC_PTR_FROM_OFFSET
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             APSC_ZP_COUNT_LO
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             APSC_ZP_COUNT_HI
                        JSR             APSC_FNV_INIT
APSC_SCAN_PAYLOAD:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSC_SCAN_COMMIT
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSC_FNV_UPDATE
                        JSR             APSC_INC_PTR
                        JSR             APSC_DEC_COUNT
                        BRA             APSC_SCAN_PAYLOAD
APSC_SCAN_COMMIT:
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #APS_RECORD_COMMIT
                        IF              APSC_SLICE6_BUILD
                        BNE             APSC_SCAN_UNCOMMITTED
                        ELSE
                        BNE             APSC_SCAN_CLOSED
                        ENDIF
                        LDX             #$03
APSC_SCAN_PAYLOAD_COMPARE:
                        LDA             APSC_HASH0,X
                        CMP             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV,X
                        BEQ             APSC_SCAN_PAYLOAD_BYTE_OK
                        JMP             APSC_SCAN_LOG_BAD
APSC_SCAN_PAYLOAD_BYTE_OK:
                        DEX
                        BPL             APSC_SCAN_PAYLOAD_COMPARE
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        CMP             APSC_OBJECT_LO
                        BNE             APSC_SCAN_NOT_TARGET
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        CMP             APSC_OBJECT_HI
                        BNE             APSC_SCAN_NOT_TARGET
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
                        ELSE
                        LDA             APSD_MODE
                        BNE             APSC_SCAN_TARGET_ACTION
                        ENDIF
                        ENDIF
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        CMP             APSC_OBJECT_GEN_LO
                        BNE             APSC_SCAN_NOT_TARGET
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        CMP             APSC_OBJECT_GEN_HI
                        BNE             APSC_SCAN_NOT_TARGET
APSC_SCAN_TARGET_ACTION:
                        JSR             APSC_MATCH_ACTION
                        BCS             APSC_SCAN_NOT_TARGET
                        JMP             APSC_SCAN_LOG_BAD
APSC_SCAN_NOT_TARGET:
                        LDA             APSC_TMP_COMMIT_LO
                        CLC
                        ADC             #APS_RECORD_TRAILER_BYTES
                        STA             APSC_TMP_TAIL_LO
                        LDA             APSC_TMP_COMMIT_HI
                        ADC             #$00
                        STA             APSC_TMP_TAIL_HI
                        JMP             APSC_SCAN_RECORD

APSC_SCAN_CLOSED:
                        LDA             #$02
                        STA             APSC_TMP_ACTIVE
                        IF              APSC_SLICE6_BUILD
                        BRA             APSC_SCAN_CRC
                        ELSE
                        BRA             APSC_SCAN_NO_APPEND
                        ENDIF
                        IF              APSC_SLICE6_BUILD
APSC_SCAN_UNCOMMITTED:
                        LDA             APSC_TMP_TAIL_LO
                        SEC
                        SBC             #APS_RECORD_HEADER_BYTES
                        STA             APSC_TMP_TAIL_LO
                        LDA             APSC_TMP_TAIL_HI
                        SBC             #$00
                        STA             APSC_TMP_TAIL_HI
                        BRA             APSC_SCAN_CLOSED
                        ENDIF
APSC_SCAN_LOG_FULL:
APSC_SCAN_NO_APPEND:
                        LDA             #$00
                        STA             APSC_TMP_TAIL_LO
                        LDA             #$10
                        STA             APSC_TMP_TAIL_HI
                        BRA             APSC_SCAN_CRC

APSC_SCAN_TAIL:
                        LDA             APSC_ZP_SECTOR
                        INC             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSC_TMP_END_HI
                        JSR             APSC_PTR_FROM_OFFSET
APSC_SCAN_TAIL_BYTE:
                        LDA             APSW_PTR_LO
                        BNE             APSC_SCAN_TAIL_READ
                        LDA             APSW_PTR_HI
                        CMP             APSC_TMP_END_HI
                        BEQ             APSC_SCAN_CRC
APSC_SCAN_TAIL_READ:
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BNE             APSC_SCAN_LOG_BAD
                        JSR             APSC_INC_PTR
                        BRA             APSC_SCAN_TAIL_BYTE

APSC_SCAN_OPAQUE:
                        STZ             APSC_TMP_TAIL_LO
                        STZ             APSC_TMP_TAIL_HI
APSC_SCAN_CRC:
                        STZ             APSW_PTR_LO
                        LDA             APSC_ZP_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDX             #$10
APSC_SCAN_CRC_PAGE:
                        LDY             #$00
APSC_SCAN_CRC_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSC_CRC16_BYTE
                        INY
                        BNE             APSC_SCAN_CRC_BYTE
                        INC             APSW_PTR_HI
                        DEX
                        BNE             APSC_SCAN_CRC_PAGE
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_SCAN_RESTORE_FAIL
                        PLP
                        SEC
                        RTS

APSC_SCAN_AS1_BAD:
APSC_SCAN_LOG_BAD:
                        LDA             APSC_STATUS
                        BEQ             APSC_SCAN_SET_LOG_BAD
                        JMP             APSC_SCAN_RESTORE_ERROR
APSC_SCAN_SET_LOG_BAD:
                        LDA             #APSC_STATUS_LOG_CORRUPT
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_CATALOG
                        STA             APSC_FAIL_PHASE
                        BRA             APSC_SCAN_RESTORE_ERROR
APSC_SCAN_SELECT_ERROR:
                        LDA             #APSC_STATUS_SERVICE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_CATALOG
                        STA             APSC_FAIL_PHASE
APSC_SCAN_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_SCAN_RESTORE_FAIL
                        PLP
                        CLC
                        RTS
APSC_SCAN_RESTORE_FAIL:
                        JSR             APSC_FORCE_BANK3
                        LDA             #APSC_STATUS_RESTORE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_RESTORE
                        STA             APSC_FAIL_PHASE
                        PLP
                        CLC
                        RTS

APSC_VALIDATE_RECORD_HEADER:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG
                        CMP             #APS_RECORD_SIG0
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG+1
                        CMP             #APS_RECORD_SIG1
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_VERSION
                        CMP             #APS_RECORD_VERSION
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_CHUNK
                        IF              APSC_SLICE6_BUILD
                        BEQ             APSC_RECORD_CHUNK_TYPE
                        CMP             #APS_RECORD_TOMBSTONE
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        ORA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        ORA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        BNE             APSC_RECORD_BAD
                        BRA             APSC_RECORD_ID
                        ELSE
                        BNE             APSC_RECORD_BAD
                        ENDIF
APSC_RECORD_BAD:        CLC
                        RTS
APSC_RECORD_CHUNK_TYPE:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        AND             #$FC
                        BNE             APSC_RECORD_BAD
APSC_RECORD_ID:
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_RESERVED
                        CMP             #$FF
                        BNE             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        ORA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        BEQ             APSC_RECORD_BAD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        ORA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        BEQ             APSC_RECORD_BAD
                        IF              APSC_SLICE6_BUILD
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_TOMBSTONE
                        BEQ             APSC_RECORD_COMMON
                        ENDIF
                        LDA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        ORA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        BEQ             APSC_RECORD_BAD
APSC_RECORD_COMMON:
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDY             #$00
APSC_RECORD_CRC:
                        LDA             APSC_RECORD_HEADER_BASE,Y
                        JSR             APSC_CRC16_BYTE
                        INY
                        CPY             #APS_RH_OFF_CRC16
                        BNE             APSC_RECORD_CRC
                        LDA             APSW_CRC_LO
                        CMP             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16
                        BNE             APSC_RECORD_BAD
                        LDA             APSW_CRC_HI
                        CMP             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16+1
                        BNE             APSC_RECORD_BAD
                        SEC
                        RTS
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
                        INCLUDE         "ASM/ap-store-v1-slice6-delete.inc"
                        ELSE
                        INCLUDE         "ASM/ap-store-v1-slice6-reader.inc"
                        ENDIF
                        ELSE
                        IF              APSC_CHAIN_READER_BUILD
                        INCLUDE         "ASM/ap-store-v1-chain-reader.inc"
                        ELSE

; ----------------------------------------------------------------------------
; Installer PLAN/EXECUTE.
; ----------------------------------------------------------------------------

APSC_MATCH_ACTION:
                        INC             APSC_TMP_FOUND
                        SEC
                        RTS

APSC_INSTALL_PLAN_BODY:
                        CLD
                        JSR             APSC_CLEAR_RESULT
                        JSR             APSC_VALIDATE_REQUEST
                        BCS             APSC_PLAN_REQUEST_OK
                        JMP             APSC_RETURN_ERROR
APSC_PLAN_REQUEST_OK:
                        LDA             APSC_SECTOR_MASK
                        BNE             APSC_PLAN_MASK_OK
                        JMP             APSC_BAD_REQUEST_RETURN
APSC_PLAN_MASK_OK:
                        JSR             APSC_VALIDATE_SERVICES
                        BCS             APSC_PLAN_SERVICES_OK
                        JMP             APSC_RETURN_ERROR
APSC_PLAN_SERVICES_OK:
                        JSR             APSC_BOOT_SELECTOR
                        BCS             APSC_PLAN_SELECTOR_OK
                        JMP             APSC_RETURN_ERROR
APSC_PLAN_SELECTOR_OK:
                        LDA             #APSC_PHASE_SOURCE
                        STA             APSC_FAIL_PHASE
                        JSR             APSC_PARSE_SOURCE
                        BCS             APSC_PLAN_SOURCE_OK
                        JMP             APSC_RETURN_ERROR
APSC_PLAN_SOURCE_OK:
                        LDA             APSC_PACKAGE_LEN_LO
                        STA             APSC_TMP_REMAIN_LO
                        LDA             APSC_PACKAGE_LEN_HI
                        STA             APSC_TMP_REMAIN_HI
                        STZ             APSC_TMP_LOGICAL_LO
                        STZ             APSC_TMP_LOGICAL_HI
                        STZ             APSC_CHUNK_COUNT
                        STZ             APSC_USED_MASK
                        STZ             APSC_CAPACITY_LO
                        STZ             APSC_CAPACITY_HI
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        LDA             #$01
                        STA             APSC_TMP_BIT
                        LDA             #$08
                        STA             APSC_ZP_SECTOR
APSC_PLAN_SCAN_LOOP:
                        JSR             APSC_SCAN_SECTOR
                        BCC             APSC_RETURN_ERROR
                        LDA             APSC_TMP_FOUND
                        BNE             APSC_DUPLICATE
                        LDA             APSC_SECTOR_MASK
                        AND             APSC_TMP_BIT
                        BEQ             APSC_PLAN_NEXT_SECTOR
                        LDA             APSC_TMP_ACTIVE
                        BNE             APSC_PLAN_ACTIVE
                        LDA             #APSC_STATUS_NOT_MANAGED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_CATALOG
                        STA             APSC_FAIL_PHASE
                        BRA             APSC_RETURN_ERROR
APSC_PLAN_ACTIVE:
                        LDA             APSC_TMP_ACTIVE
                        CMP             #$01
                        BEQ             APSC_PLAN_APPENDABLE
                        LDA             #APSC_STATUS_LOG_CORRUPT
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_CATALOG
                        STA             APSC_FAIL_PHASE
                        JMP             APSC_RETURN_ERROR
APSC_PLAN_APPENDABLE:
                        JSR             APSC_CALC_CAPACITY
                        JSR             APSC_ADD_CAPACITY
                        LDA             APSC_TMP_REMAIN_LO
                        ORA             APSC_TMP_REMAIN_HI
                        BEQ             APSC_PLAN_NEXT_SECTOR
                        LDA             APSC_TMP_LENGTH_LO
                        ORA             APSC_TMP_LENGTH_HI
                        BEQ             APSC_PLAN_NEXT_SECTOR
                        JSR             APSC_LIMIT_CHUNK
                        JSR             APSC_STORE_PLAN_ROW
APSC_PLAN_NEXT_SECTOR:
                        ASL             APSC_TMP_BIT
                        INC             APSC_ZP_SECTOR
                        LDA             APSC_ZP_SECTOR
                        CMP             #$10
                        BCC             APSC_PLAN_SCAN_LOOP
                        LDA             APSC_TMP_REMAIN_LO
                        ORA             APSC_TMP_REMAIN_HI
                        BNE             APSC_NO_SPACE
                        LDA             APSC_CHUNK_COUNT
                        BEQ             APSC_NO_SPACE
                        JSR             APSC_MARK_LAST_ROW
                        JSR             APSC_SAVE_PREPARED
                        LDA             #APSC_STATUS_PREPARED
                        STA             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_FAIL_SECTOR
                        LDA             #APSC_STATUS_PREPARED
                        SEC
                        RTS
APSC_BAD_REQUEST_RETURN:
                        JSR             APSC_BAD_REQUEST
APSC_RETURN_ERROR:
                        LDA             APSC_STATUS
                        CLC
                        RTS
APSC_DUPLICATE:
                        LDA             #APSC_STATUS_DUPLICATE
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_POLICY
                        STA             APSC_FAIL_PHASE
                        BRA             APSC_RETURN_ERROR
APSC_NO_SPACE:
                        LDA             #APSC_STATUS_NO_SPACE
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_PLAN
                        STA             APSC_FAIL_PHASE
                        BRA             APSC_RETURN_ERROR

APSC_CALC_CAPACITY:
                        STZ             APSC_TMP_LENGTH_LO
                        STZ             APSC_TMP_LENGTH_HI
                        LDA             APSC_TMP_TAIL_HI
                        CMP             #$0F
                        BCC             APSC_CAPACITY_SUBTRACT
                        BNE             APSC_CAPACITY_DONE
                        LDA             APSC_TMP_TAIL_LO
                        CMP             #$EC
                        BCS             APSC_CAPACITY_DONE
APSC_CAPACITY_SUBTRACT:
                        LDA             #$EB
                        SEC
                        SBC             APSC_TMP_TAIL_LO
                        STA             APSC_TMP_LENGTH_LO
                        LDA             #$0F
                        SBC             APSC_TMP_TAIL_HI
                        STA             APSC_TMP_LENGTH_HI
APSC_CAPACITY_DONE:
                        RTS

APSC_ADD_CAPACITY:
                        LDA             APSC_CAPACITY_LO
                        CLC
                        ADC             APSC_TMP_LENGTH_LO
                        STA             APSC_CAPACITY_LO
                        LDA             APSC_CAPACITY_HI
                        ADC             APSC_TMP_LENGTH_HI
                        STA             APSC_CAPACITY_HI
                        RTS

APSC_LIMIT_CHUNK:
                        LDA             APSC_TMP_REMAIN_HI
                        CMP             APSC_TMP_LENGTH_HI
                        BCC             APSC_USE_REMAIN
                        BNE             APSC_LIMIT_DONE
                        LDA             APSC_TMP_REMAIN_LO
                        CMP             APSC_TMP_LENGTH_LO
                        BCC             APSC_USE_REMAIN
                        BEQ             APSC_USE_REMAIN
APSC_LIMIT_DONE:
                        RTS
APSC_USE_REMAIN:
                        LDA             APSC_TMP_REMAIN_LO
                        STA             APSC_TMP_LENGTH_LO
                        LDA             APSC_TMP_REMAIN_HI
                        STA             APSC_TMP_LENGTH_HI
                        RTS

APSC_STORE_PLAN_ROW:
                        LDY             #APSC_PLAN_SECTOR
                        LDA             APSC_ZP_SECTOR
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_CHUNK_COUNT
                        BEQ             APSC_PLAN_FIRST
                        LDA             #$00
                        BRA             APSC_PLAN_NOT_FIRST
APSC_PLAN_FIRST:
                        LDA             #APS_RECORD_FLAG_FIRST
APSC_PLAN_NOT_FIRST:
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_TAIL_LO
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_TAIL_HI
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_LOGICAL_LO
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_LOGICAL_HI
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_LENGTH_LO
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSC_TMP_LENGTH_HI
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSW_CRC_LO
                        STA             (APSC_ZP_ROW_LO),Y
                        INY
                        LDA             APSW_CRC_HI
                        STA             (APSC_ZP_ROW_LO),Y
                        LDA             APSC_USED_MASK
                        ORA             APSC_TMP_BIT
                        STA             APSC_USED_MASK
                        LDA             APSC_TMP_LOGICAL_LO
                        CLC
                        ADC             APSC_TMP_LENGTH_LO
                        STA             APSC_TMP_LOGICAL_LO
                        LDA             APSC_TMP_LOGICAL_HI
                        ADC             APSC_TMP_LENGTH_HI
                        STA             APSC_TMP_LOGICAL_HI
                        LDA             APSC_TMP_REMAIN_LO
                        SEC
                        SBC             APSC_TMP_LENGTH_LO
                        STA             APSC_TMP_REMAIN_LO
                        LDA             APSC_TMP_REMAIN_HI
                        SBC             APSC_TMP_LENGTH_HI
                        STA             APSC_TMP_REMAIN_HI
                        INC             APSC_CHUNK_COUNT
                        LDA             APSC_ZP_ROW_LO
                        CLC
                        ADC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_ROW_LO
                        BCC             APSC_STORE_ROW_DONE
                        INC             APSC_ZP_ROW_HI
APSC_STORE_ROW_DONE:
                        RTS

APSC_MARK_LAST_ROW:
                        LDA             APSC_ZP_ROW_LO
                        SEC
                        SBC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_ROW_LO
                        BCS             APSC_MARK_LAST_PTR
                        DEC             APSC_ZP_ROW_HI
APSC_MARK_LAST_PTR:
                        LDY             #APSC_PLAN_FLAGS
                        LDA             (APSC_ZP_ROW_LO),Y
                        ORA             #APS_RECORD_FLAG_LAST
                        STA             (APSC_ZP_ROW_LO),Y
                        RTS

APSC_SAVE_PREPARED:
                        LDX             #$05
APSC_SAVE_REQUEST_LOOP:
                        LDA             APSC_BANK,X
                        STA             APSC_PREP_BANK,X
                        DEX
                        BPL             APSC_SAVE_REQUEST_LOOP
                        LDX             #$05
APSC_SAVE_SOURCE_LOOP:
                        LDA             APSC_PACKAGE_LEN_LO,X
                        STA             APSC_PREP_PACKAGE_LEN_LO,X
                        DEX
                        BPL             APSC_SAVE_SOURCE_LOOP
                        RTS

APSC_COMPARE_PREPARED:
                        LDX             #$05
APSC_COMPARE_REQUEST_LOOP:
                        LDA             APSC_BANK,X
                        CMP             APSC_PREP_BANK,X
                        BNE             APSC_COMPARE_BAD
                        DEX
                        BPL             APSC_COMPARE_REQUEST_LOOP
                        LDX             #$05
APSC_COMPARE_SOURCE_LOOP:
                        LDA             APSC_PACKAGE_LEN_LO,X
                        CMP             APSC_PREP_PACKAGE_LEN_LO,X
                        BNE             APSC_COMPARE_BAD
                        DEX
                        BPL             APSC_COMPARE_SOURCE_LOOP
                        SEC
                        RTS
APSC_COMPARE_BAD:
                        CLC
                        RTS

APSC_INSTALL_EXECUTE_BODY:
                        CLD
                        LDA             APSC_CONFIRM
                        CMP             #APSC_CONFIRM_EXECUTE
                        BEQ             APSC_EXEC_CONFIRMED
                        JMP             APSC_NOT_CONFIRMED
APSC_EXEC_CONFIRMED:
                        STZ             APSC_CONFIRM
                        LDA             APSC_STATUS
                        CMP             #APSC_STATUS_PREPARED
                        BEQ             APSC_EXEC_PREPARED
                        JMP             APSC_MEDIA_CHANGED
APSC_EXEC_PREPARED:
                        JSR             APSC_VALIDATE_REQUEST
                        BCS             APSC_EXEC_REQUEST_OK
                        JMP             APSC_RETURN_ERROR
APSC_EXEC_REQUEST_OK:
                        JSR             APSC_PARSE_SOURCE
                        BCS             APSC_EXEC_SOURCE_OK
                        JMP             APSC_RETURN_ERROR
APSC_EXEC_SOURCE_OK:
                        JSR             APSC_COMPARE_PREPARED
                        BCC             APSC_MEDIA_CHANGED
                        JSR             APSC_BOOT_SELECTOR
                        BCS             APSC_EXEC_SELECTOR_OK
                        JMP             APSC_RETURN_ERROR
APSC_EXEC_SELECTOR_OK:
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        LDX             APSC_CHUNK_COUNT
APSC_EXEC_RESCAN_LOOP:
                        PHX
                        LDY             #APSC_PLAN_SECTOR
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_SECTOR
                        JSR             APSC_SCAN_SECTOR
                        BCC             APSC_EXEC_RESCAN_FAIL
                        LDA             APSC_TMP_ACTIVE
                        BEQ             APSC_EXEC_RESCAN_CHANGED
                        LDA             APSC_TMP_FOUND
                        BNE             APSC_EXEC_RESCAN_CHANGED
                        LDY             #APSC_PLAN_RECORD_OFF_LO
                        LDA             APSC_TMP_TAIL_LO
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSC_EXEC_RESCAN_CHANGED
                        INY
                        LDA             APSC_TMP_TAIL_HI
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSC_EXEC_RESCAN_CHANGED
                        LDY             #APSC_PLAN_MEDIA_CRC_LO
                        LDA             APSW_CRC_LO
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSC_EXEC_RESCAN_CHANGED
                        INY
                        LDA             APSW_CRC_HI
                        CMP             (APSC_ZP_ROW_LO),Y
                        BNE             APSC_EXEC_RESCAN_CHANGED
                        JSR             APSC_NEXT_ROW
                        PLX
                        DEX
                        BNE             APSC_EXEC_RESCAN_LOOP
                        LDA             #<APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_LO
                        LDA             #>APSC_PLAN_BASE
                        STA             APSC_ZP_ROW_HI
                        LDX             APSC_CHUNK_COUNT
APSC_EXEC_PROGRAM_LOOP:
                        PHX
                        JSR             APSC_BUILD_RECORD_HEADER
                        JSR             APSC_PROGRAM_ROW
                        BCC             APSC_EXEC_PROGRAM_FAIL
                        JSR             APSC_NEXT_ROW
                        PLX
                        DEX
                        BNE             APSC_EXEC_PROGRAM_LOOP
                        LDA             #APSC_STATUS_OK
                        STA             APSC_STATUS
                        STZ             APSC_FAIL_PHASE
                        STZ             APSC_FAIL_SECTOR
                        LDA             #APSC_STATUS_OK
                        SEC
                        RTS
APSC_EXEC_RESCAN_FAIL:
APSC_EXEC_PROGRAM_FAIL:
                        PLX
                        JMP             APSC_RETURN_ERROR
APSC_EXEC_RESCAN_CHANGED:
                        PLX
APSC_MEDIA_CHANGED:
                        LDA             #APSC_STATUS_MEDIA_CHANGED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_POLICY
                        STA             APSC_FAIL_PHASE
                        JMP             APSC_RETURN_ERROR
APSC_NOT_CONFIRMED:
                        STZ             APSC_CONFIRM
                        LDA             #APSC_STATUS_NOT_CONFIRMED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_POLICY
                        STA             APSC_FAIL_PHASE
                        JMP             APSC_RETURN_ERROR

APSC_NEXT_ROW:
                        LDA             APSC_ZP_ROW_LO
                        CLC
                        ADC             #APSC_PLAN_ROW_BYTES
                        STA             APSC_ZP_ROW_LO
                        BCC             APSC_NEXT_ROW_DONE
                        INC             APSC_ZP_ROW_HI
APSC_NEXT_ROW_DONE:
                        RTS

APSC_BUILD_RECORD_HEADER:
                        LDA             #$FF
                        LDX             #APS_RECORD_HEADER_BYTES-1
APSC_BUILD_HEADER_FILL:
                        STA             APSC_RECORD_HEADER_BASE,X
                        DEX
                        BPL             APSC_BUILD_HEADER_FILL
                        LDA             #APS_RECORD_SIG0
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG
                        LDA             #APS_RECORD_SIG1
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_SIG+1
                        LDA             #APS_RECORD_VERSION
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_VERSION
                        LDA             #APS_RECORD_CHUNK
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        LDY             #APSC_PLAN_FLAGS
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        LDA             APSC_OBJECT_LO
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        LDA             APSC_OBJECT_HI
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        LDA             APSC_OBJECT_GEN_LO
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        LDA             APSC_OBJECT_GEN_HI
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        LDY             #APSC_PLAN_LOGICAL_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             APSC_ZP_COUNT_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             APSC_ZP_COUNT_HI
                        JSR             APSC_SOURCE_FOR_ROW
                        JSR             APSC_FNV_INIT
APSC_BUILD_PAYLOAD_HASH:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSC_BUILD_PAYLOAD_HASH_DONE
                        LDY             #$00
                        LDA             (APSC_ZP_SRC_LO),Y
                        JSR             APSC_FNV_UPDATE
                        INC             APSC_ZP_SRC_LO
                        BNE             APSC_BUILD_SOURCE_OK
                        INC             APSC_ZP_SRC_HI
APSC_BUILD_SOURCE_OK:
                        JSR             APSC_DEC_COUNT
                        BRA             APSC_BUILD_PAYLOAD_HASH
APSC_BUILD_PAYLOAD_HASH_DONE:
                        LDX             #$03
APSC_BUILD_PAYLOAD_FNV:
                        LDA             APSC_HASH0,X
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_FNV,X
                        DEX
                        BPL             APSC_BUILD_PAYLOAD_FNV
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDY             #$00
APSC_BUILD_HEADER_CRC:
                        LDA             APSC_RECORD_HEADER_BASE,Y
                        JSR             APSC_CRC16_BYTE
                        INY
                        CPY             #APS_RH_OFF_CRC16
                        BNE             APSC_BUILD_HEADER_CRC
                        LDA             APSW_CRC_LO
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16
                        LDA             APSW_CRC_HI
                        STA             APSC_RECORD_HEADER_BASE+APS_RH_OFF_CRC16+1
                        RTS

APSC_SOURCE_FOR_ROW:
                        LDY             #APSC_PLAN_LOGICAL_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        CLC
                        ADC             APSC_SOURCE_LO
                        STA             APSC_ZP_SRC_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        ADC             APSC_SOURCE_HI
                        STA             APSC_ZP_SRC_HI
                        RTS

APSC_PROGRAM_ROW:
                        PHP
                        SEI
                        LDY             #APSC_PLAN_SECTOR
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_SECTOR
                        LDA             APSC_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_PROGRAM_RESTORE_ERROR
                        LDY             #APSC_PLAN_RECORD_OFF_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSW_PTR_LO
                        INY
                        LDA             APSC_ZP_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             (APSC_ZP_ROW_LO),Y
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
                        JSR             APSC_PROGRAM_BYTES
                        BCC             APSC_PROGRAM_FAILED
                        JSR             APSC_SOURCE_FOR_ROW
                        LDY             #APSC_PLAN_LENGTH_LO
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_COUNT_LO
                        INY
                        LDA             (APSC_ZP_ROW_LO),Y
                        STA             APSC_ZP_COUNT_HI
                        LDA             #APSC_PHASE_PAYLOAD
                        STA             APSC_FAIL_PHASE
                        JSR             APSC_PROGRAM_BYTES
                        BCC             APSC_PROGRAM_FAILED
                        LDA             #APSC_PHASE_COMMIT
                        STA             APSC_FAIL_PHASE
                        LDA             #APS_RECORD_COMMIT
                        LDY             #$00
                        JSR             APSC_FLASH_WRITE_BYTE
                        BCC             APSC_PROGRAM_FAILED
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_PROGRAM_RESTORE_FAIL
                        PLP
                        SEC
                        RTS
APSC_PROGRAM_FAILED:
                        LDA             #APSC_STATUS_PROGRAM_FAILED
                        STA             APSC_STATUS
APSC_PROGRAM_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSC_PROGRAM_RESTORE_FAIL
                        PLP
                        CLC
                        RTS
APSC_PROGRAM_RESTORE_FAIL:
                        JSR             APSC_FORCE_BANK3
                        LDA             #APSC_STATUS_RESTORE_FAILED
                        STA             APSC_STATUS
                        LDA             #APSC_PHASE_RESTORE
                        STA             APSC_FAIL_PHASE
                        PLP
                        CLC
                        RTS

APSC_PROGRAM_BYTES:
                        LDA             APSC_ZP_COUNT_LO
                        ORA             APSC_ZP_COUNT_HI
                        BEQ             APSC_PROGRAM_BYTES_DONE
                        LDY             #$00
                        LDA             (APSC_ZP_SRC_LO),Y
                        JSR             APSC_FLASH_WRITE_BYTE
                        BCC             APSC_PROGRAM_BYTES_FAIL
                        JSR             APSC_INC_PTR
                        INC             APSC_ZP_SRC_LO
                        BNE             APSC_PROGRAM_SOURCE_OK
                        INC             APSC_ZP_SRC_HI
APSC_PROGRAM_SOURCE_OK:
                        JSR             APSC_DEC_COUNT
                        BRA             APSC_PROGRAM_BYTES
APSC_PROGRAM_BYTES_DONE:
                        SEC
                        RTS
APSC_PROGRAM_BYTES_FAIL:
                        CLC
                        RTS

APSC_FLASH_WRITE_BYTE:
                        STA             APSW_BYTE
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSC_WRITE_OK
                        AND             APSW_BYTE
                        CMP             APSW_BYTE
                        BNE             APSC_WRITE_FAIL
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
APSC_WRITE_POLL:
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSC_WRITE_OK
                        DEC             APSC_TMP_TMO0
                        BNE             APSC_WRITE_POLL
                        DEC             APSC_TMP_TMO1
                        BNE             APSC_WRITE_POLL
                        DEC             APSC_TMP_TMO2
                        BNE             APSC_WRITE_POLL
                        LDA             #$F0
                        STA             APSW_FLASH_UNLOCK1
APSC_WRITE_FAIL:
                        CLC
                        RTS
APSC_WRITE_OK:
                        SEC
                        RTS

                        ENDIF
                        ENDIF

                        DATA
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
                        ELSE
                        IF              APSC_SLICE6_READER_BUILD
APSD_MSG_ROW:           DB              "APNEW O=",0
APSD_MSG_GEN:           DB              " G=",0
APSD_MSG_LEN:           DB              " L=",0
APSD_MSG_OK:            DB              "APNEW OK",0
                        ENDIF
                        ENDIF
                        ELSE
                        IF              APSC_CHAIN_READER_BUILD
APSC_MSG_ROW:           DB              "APCHAIN O=",0
APSC_MSG_GEN:           DB              " G=",0
APSC_MSG_LEN:           DB              " L=",0
APSC_MSG_OK:            DB              "APCHAIN OK",0
                        ENDIF
                        ENDIF
APSC_IMAGE_SENTINEL:    DB              $FF

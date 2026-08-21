; ----------------------------------------------------------------------------
; AP Store V1 transient single-sector tools.
;
; APSO_OBJECT_BUILD=0 produces the hardware-proven CLAIM/CONVERT/FORMAT worker.
; APSO_OBJECT_BUILD=1 produces the Slice 4 append/list/validate/load worker.
; Both are separate fixed AP v2 images loaded at $7000; neither allocates
; permanent RAM.
; This foreground tool is terminal for an ASM session and is mutually
; exclusive with the $7000 ASM session reporter.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          AP_STORE_V1_SECTOR_TOOL

                        XDEF            START
                        IF              APSC_CHAIN_BUILD
                        IF              APSC_SLICE6_BUILD
                        IF              APSC_DELETE_EXECUTOR_BUILD
                        XDEF            APSD_SAFE
                        XDEF            APSD_DELETE_EXECUTE
                        ELSE
                        IF              APSC_SLICE6_READER_BUILD
                        XDEF            APSD_LIST
                        XDEF            APSD_VALIDATE
                        XDEF            APSD_LOAD
                        ELSE
                        XDEF            APSD_SAFE
                        XDEF            APSD_DELETE_PLAN
                        ENDIF
                        ENDIF
                        ELSE
                        IF              APSC_CHAIN_READER_BUILD
                        XDEF            APSC_LIST
                        XDEF            APSC_VALIDATE
                        XDEF            APSC_LOAD
                        ELSE
                        XDEF            APSC_INSTALL_PLAN
                        XDEF            APSC_INSTALL_EXECUTE
                        ENDIF
                        ENDIF
                        ELSE
                        IF              APSO_OBJECT_BUILD
                        XDEF            APSO_LIST
                        XDEF            APSO_INSTALL_PREPARE
                        XDEF            APSO_INSTALL_EXECUTE
                        XDEF            APSO_VALIDATE
                        XDEF            APSO_LOAD
                        ELSE
                        XDEF            APSW_INVENTORY
                        XDEF            APSW_PREPARE
                        XDEF            APSW_EXECUTE
                        ENDIF
                        ENDIF

                        INCLUDE         "str8n-public.inc"
                        INCLUDE         "ASM/asm-abi-v1.inc"
                        INCLUDE         "ASM/ap-store-v1.inc"
                        INCLUDE         "ASM/ap-store-v1-worker.inc"

APSW_PTR_LO             EQU             $A0
APSW_PTR_HI             EQU             $A1
APSW_CRC_LO             EQU             $A2
APSW_CRC_HI             EQU             $A3
APSW_BYTE               EQU             $A4
APSW_TMO0               EQU             $A5
APSW_TMO1               EQU             $A6
APSW_TMO2               EQU             $A7
APSW_PAGE               EQU             $A8
APSW_TMP                EQU             $A9
APSW_CALL_LO            EQU             $AA
APSW_CALL_HI            EQU             $AB
APSO_COUNT_LO           EQU             $AC
APSO_COUNT_HI           EQU             $AD
APSO_SRC_TMP_LO         EQU             $AE
APSO_SRC_TMP_HI         EQU             $AF

APSW_SVC_WRITE_BYTE     EQU             ASM_ABI_SVC_FIRST_VECTOR+$02
APSW_SVC_WRITE_CSTRING  EQU             ASM_ABI_SVC_FIRST_VECTOR+$04
APSW_SVC_WRITE_HEX_BYTE EQU             ASM_ABI_SVC_FIRST_VECTOR+$06
APSW_SVC_WRITE_CRLF     EQU             ASM_ABI_SVC_FIRST_VECTOR+$08

APSW_FLASH_UNLOCK1      EQU             $D555
APSW_FLASH_UNLOCK2      EQU             $AAAA
APSW_ERASE_TIMEOUT_HI   EQU             $08
APSW_WRITE_TIMEOUT_HI   EQU             $02

                        CODE

                        IF              APSC_CHAIN_BUILD
                        INCLUDE         "ASM/ap-store-v1-chain-tool.inc"
                        ELSE

START:
                        IF              APSO_OBJECT_BUILD
APSO_LIST:              JMP             APSO_LIST_BODY
APSO_INSTALL_PREPARE:   JMP             APSO_INSTALL_PREPARE_BODY
APSO_INSTALL_EXECUTE:   JMP             APSO_INSTALL_EXECUTE_BODY
APSO_VALIDATE:          JMP             APSO_VALIDATE_BODY
APSO_LOAD:              JMP             APSO_LOAD_BODY
                        ELSE
APSW_INVENTORY:         JMP             APSW_INVENTORY_BODY
                        JMP             APSW_PREPARE
                        JMP             APSW_EXECUTE
                        ENDIF

; APSTORE's AP v2 export enters here.  Each full-sector scan restores Bank 3
; before the row is printed.  The loop visits exactly B0:8 through B2:F and
; has no path to the flash mutation routines.
                        IF              APSO_OBJECT_BUILD
                        ELSE
APSW_INVENTORY_BODY:
                        CLD
                        STZ             APSW_CONFIRM
                        JSR             APSW_CLEAR_RESULT
                        JSR             APSW_VALIDATE_SERVICES
                        BCC             APSW_INVENTORY_RETURN_ERROR
                        JSR             APSW_BOOT_SELECTOR
                        BCC             APSW_INVENTORY_PRINT_ERROR
                        STZ             APSW_BANK
                        LDA             #$08
                        STA             APSW_SECTOR
APSW_INVENTORY_SCAN:
                        JSR             APSW_SCAN_SECTOR
                        BCC             APSW_INVENTORY_PRINT_ERROR
                        JSR             APSW_CLASSIFY_HEADER
                        JSR             APSW_PRINT_ROW
                        INC             APSW_SECTOR
                        LDA             APSW_SECTOR
                        CMP             #$10
                        BCC             APSW_INVENTORY_SCAN
                        LDA             #$08
                        STA             APSW_SECTOR
                        INC             APSW_BANK
                        LDA             APSW_BANK
                        CMP             #$03
                        BCC             APSW_INVENTORY_SCAN

                        LDA             #APSW_STATUS_OK
                        STA             APSW_STATUS
                        LDX             #<APSW_MSG_OK
                        LDY             #>APSW_MSG_OK
                        JSR             APSW_PRINT_LINE
                        LDA             #APSW_STATUS_OK
                        SEC
                        RTS

APSW_INVENTORY_PRINT_ERROR:
                        LDX             #<APSW_MSG_ERROR
                        LDY             #>APSW_MSG_ERROR
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSW_STATUS
                        JSR             APSW_WRITE_HEX_BYTE
                        LDX             #<APSW_MSG_PHASE
                        LDY             #>APSW_MSG_PHASE
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSW_FAIL_PHASE
                        JSR             APSW_WRITE_HEX_BYTE
                        JSR             APSW_WRITE_CRLF
APSW_INVENTORY_RETURN_ERROR:
                        LDA             APSW_STATUS
                        CLC
                        RTS
                        ENDIF

APSW_VALIDATE_SERVICES:
                        LDA             ASM_ABI_SVC_SIG0
                        CMP             #ASM_ABI_SVC_SIG0_VALUE
                        BNE             APSW_SERVICES_BAD
                        LDA             ASM_ABI_SVC_SIG1
                        CMP             #ASM_ABI_SVC_SIG1_VALUE
                        BNE             APSW_SERVICES_BAD
                        LDA             ASM_ABI_SVC_VERSION
                        CMP             #ASM_ABI_SVC_VERSION_VALUE
                        BNE             APSW_SERVICES_BAD
                        LDA             ASM_ABI_SVC_COUNT
                        CMP             #ASM_ABI_SVC_VECTOR_COUNT
                        BCC             APSW_SERVICES_BAD
                        LDA             #$00
                        LDX             #ASM_ABI_SVC_CHECKSUM-ASM_ABI_SVC_SIG0-1
APSW_SERVICES_CHECKSUM:
                        EOR             ASM_ABI_SVC_SIG0,X
                        DEX
                        BPL             APSW_SERVICES_CHECKSUM
                        CMP             ASM_ABI_SVC_CHECKSUM
                        BNE             APSW_SERVICES_BAD
                        SEC
                        RTS
APSW_SERVICES_BAD:
                        LDA             #APSW_STATUS_SERVICE_FAILED
                        STA             APSW_STATUS
                        CLC
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
APSW_PRINT_ROW:
                        LDA             APSW_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             APSW_SECTOR
                        PHA
                        LDX             #<APSW_MSG_PREFIX
                        LDY             #>APSW_MSG_PREFIX
                        JSR             APSW_WRITE_CSTRING
                        PLA
                        JSR             APSW_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             APSW_WRITE_BYTE
                        LDX             APSW_CLASS
                        LDA             APSW_CLASS_TEXT_LO,X
                        PHA
                        LDY             APSW_CLASS_TEXT_HI,X
                        PLA
                        TAX
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_STAGED
                        BCC             APSW_PRINT_ROW_EOL
                        LDX             #<APSW_MSG_GENERATION
                        LDY             #>APSW_MSG_GENERATION
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSW_GENERATION_HI
                        JSR             APSW_WRITE_HEX_BYTE
                        LDA             APSW_GENERATION_LO
                        JSR             APSW_WRITE_HEX_BYTE
APSW_PRINT_ROW_EOL:
                        JMP             APSW_WRITE_CRLF
                        ENDIF

APSW_PRINT_LINE:
                        JSR             APSW_WRITE_CSTRING
                        JMP             APSW_WRITE_CRLF

; Tail-call through the frozen HIMON service-vector card.  The target RTS
; returns directly to the original JSR caller.
APSW_WRITE_BYTE:
                        PHA
                        LDA             APSW_SVC_WRITE_BYTE
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_BYTE+1
                        STA             APSW_CALL_HI
                        PLA
                        JMP             (APSW_CALL_LO)

APSW_WRITE_CSTRING:
                        LDA             APSW_SVC_WRITE_CSTRING
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_CSTRING+1
                        STA             APSW_CALL_HI
                        JMP             (APSW_CALL_LO)

APSW_WRITE_HEX_BYTE:
                        PHA
                        LDA             APSW_SVC_WRITE_HEX_BYTE
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_HEX_BYTE+1
                        STA             APSW_CALL_HI
                        PLA
                        JMP             (APSW_CALL_LO)

APSW_WRITE_CRLF:
                        LDA             APSW_SVC_WRITE_CRLF
                        STA             APSW_CALL_LO
                        LDA             APSW_SVC_WRITE_CRLF+1
                        STA             APSW_CALL_HI
                        JMP             (APSW_CALL_LO)

; PREPARE is strictly read-only.  It freezes the request, classification,
; flags, generation, and full-sector CRC used by EXECUTE's media-change gate.
                        IF              APSO_OBJECT_BUILD
                        ELSE
APSW_PREPARE:
                        CLD
                        STZ             APSW_CONFIRM
                        JSR             APSW_CLEAR_RESULT
                        JSR             APSW_VALIDATE_REQUEST
                        BCC             APSW_PREPARE_ERROR
                        JSR             APSW_BOOT_SELECTOR
                        BCC             APSW_PREPARE_ERROR
                        JSR             APSW_SCAN_SECTOR
                        BCC             APSW_PREPARE_ERROR
                        JSR             APSW_CLASSIFY_HEADER
                        JSR             APSW_APPLY_POLICY
                        BCC             APSW_PREPARE_ERROR

                        LDA             APSW_OP
                        STA             APSW_PREP_OP
                        LDA             APSW_BANK
                        STA             APSW_PREP_BANK
                        LDA             APSW_SECTOR
                        STA             APSW_PREP_SECTOR
                        LDA             APSW_CLASS
                        STA             APSW_PREP_CLASS
                        LDA             APSW_FLAGS
                        STA             APSW_PREP_FLAGS
                        LDA             APSW_GENERATION_LO
                        STA             APSW_PREP_GENERATION_LO
                        LDA             APSW_GENERATION_HI
                        STA             APSW_PREP_GENERATION_HI
                        LDA             APSW_CURRENT_CRC_LO
                        STA             APSW_PREP_CRC_LO
                        LDA             APSW_CURRENT_CRC_HI
                        STA             APSW_PREP_CRC_HI
                        LDA             #APSW_STATUS_PREPARED
                        STA             APSW_STATUS
                        SEC
                        RTS
APSW_PREPARE_ERROR:
                        JMP             APSW_RETURN_ERROR

; EXECUTE is one-shot: confirmation is consumed before any bank switch.  The
; whole sector is rescanned and compared with PREPARE before mutation begins.
APSW_EXECUTE:
                        CLD
                        LDA             APSW_CONFIRM
                        CMP             #APSW_CONFIRM_EXECUTE
                        BNE             APSW_NOT_CONFIRMED
                        STZ             APSW_CONFIRM
                        JSR             APSW_VALIDATE_REQUEST
                        BCC             APSW_EXECUTE_ERROR
                        LDA             APSW_OP
                        CMP             APSW_PREP_OP
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_BANK
                        CMP             APSW_PREP_BANK
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_SECTOR
                        CMP             APSW_PREP_SECTOR
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_STATUS
                        CMP             #APSW_STATUS_PREPARED
                        BNE             APSW_MEDIA_CHANGED

                        JSR             APSW_BOOT_SELECTOR
                        BCC             APSW_RETURN_ERROR
                        JSR             APSW_SCAN_SECTOR
                        BCC             APSW_RETURN_ERROR
                        JSR             APSW_CLASSIFY_HEADER
                        LDA             APSW_CURRENT_CRC_LO
                        CMP             APSW_PREP_CRC_LO
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_CURRENT_CRC_HI
                        CMP             APSW_PREP_CRC_HI
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_CLASS
                        CMP             APSW_PREP_CLASS
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_FLAGS
                        CMP             APSW_PREP_FLAGS
                        BNE             APSW_MEDIA_CHANGED
                        JSR             APSW_APPLY_POLICY
                        BCC             APSW_MEDIA_CHANGED
                        LDA             APSW_GENERATION_LO
                        CMP             APSW_PREP_GENERATION_LO
                        BNE             APSW_MEDIA_CHANGED
                        LDA             APSW_GENERATION_HI
                        CMP             APSW_PREP_GENERATION_HI
                        BNE             APSW_MEDIA_CHANGED

                        JSR             APSW_BUILD_HEADER
                        JSR             APSW_MUTATE_SECTOR
                        BCC             APSW_RETURN_ERROR
                        LDA             #APSW_STATUS_OK
                        STA             APSW_STATUS
                        STZ             APSW_FAIL_PHASE
                        SEC
                        RTS
APSW_EXECUTE_ERROR:
                        JMP             APSW_RETURN_ERROR

APSW_NOT_CONFIRMED:
                        LDA             #APSW_STATUS_NOT_CONFIRMED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_POLICY
                        STA             APSW_FAIL_PHASE
                        BRA             APSW_RETURN_ERROR

APSW_MEDIA_CHANGED:
                        LDA             #APSW_STATUS_MEDIA_CHANGED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_POLICY
                        STA             APSW_FAIL_PHASE

APSW_RETURN_ERROR:
                        LDA             APSW_STATUS
                        CLC
                        RTS

APSW_CLEAR_RESULT:
                        STZ             APSW_STATUS
                        STZ             APSW_CLASS
                        STZ             APSW_FLAGS
                        STZ             APSW_FAIL_PHASE
                        STZ             APSW_FAIL_ADDR_LO
                        STZ             APSW_FAIL_ADDR_HI
                        STZ             APSW_CURRENT_CRC_LO
                        STZ             APSW_CURRENT_CRC_HI
                        LDA             #$FF
                        STA             APSW_GENERATION_LO
                        STA             APSW_GENERATION_HI
                        RTS

APSW_VALIDATE_REQUEST:
                        LDA             APSW_OP
                        CMP             #APSW_OP_CLAIM
                        BCC             APSW_BAD_REQUEST
                        CMP             #APSW_OP_FORMAT+1
                        BCS             APSW_BAD_REQUEST
                        LDA             APSW_BANK
                        CMP             #$03
                        BCS             APSW_BAD_REQUEST
                        LDA             APSW_SECTOR
                        CMP             #$08
                        BCC             APSW_BAD_REQUEST
                        CMP             #$10
                        BCS             APSW_BAD_REQUEST
                        SEC
                        RTS
APSW_BAD_REQUEST:
                        LDA             #APSW_STATUS_BAD_REQUEST
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_POLICY
                        STA             APSW_FAIL_PHASE
                        CLC
                        RTS
                        ENDIF

APSW_BOOT_SELECTOR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_SERVICE
                        BCS             APSW_BOOT_OK
                        LDA             #APSW_STATUS_SELECT_FAILED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_SCAN
                        STA             APSW_FAIL_PHASE
                        CLC
                        RTS
APSW_BOOT_OK:
                        SEC
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
; Scan all 4096 bytes while executing in RAM.  The scan copies the 16-byte
; header, computes CRC16/CCITT-FALSE, and distinguishes full/tail erased state.
APSW_SCAN_SECTOR:
                        PHP
                        SEI
                        LDA             APSW_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_SCAN_SELECT_FAIL

                        STZ             APSW_PTR_LO
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDA             #APSW_FLAG_FULL_ERASED|APSW_FLAG_TAIL_ERASED
                        STA             APSW_FLAGS
                        STZ             APSW_PAGE
                        LDX             #$10
APSW_SCAN_PAGE:
                        LDY             #$00
APSW_SCAN_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        STA             APSW_BYTE
                        CMP             #$FF
                        BEQ             APSW_SCAN_COPY
                        LDA             APSW_FLAGS
                        AND             #($FF-APSW_FLAG_FULL_ERASED)
                        STA             APSW_FLAGS
                        LDA             APSW_PAGE
                        BNE             APSW_SCAN_CLEAR_TAIL
                        CPY             #APS_SECTOR_HEADER_BYTES
                        BCC             APSW_SCAN_COPY
APSW_SCAN_CLEAR_TAIL:
                        LDA             APSW_FLAGS
                        AND             #($FF-APSW_FLAG_TAIL_ERASED)
                        STA             APSW_FLAGS
APSW_SCAN_COPY:
                        LDA             APSW_PAGE
                        BNE             APSW_SCAN_CRC
                        CPY             #APS_SECTOR_HEADER_BYTES
                        BCS             APSW_SCAN_CRC
                        LDA             APSW_BYTE
                        STA             APSW_HEADER_BASE,Y
APSW_SCAN_CRC:
                        LDA             APSW_BYTE
                        JSR             APSW_CRC16_BYTE
                        INY
                        BNE             APSW_SCAN_BYTE
                        INC             APSW_PTR_HI
                        INC             APSW_PAGE
                        DEX
                        BNE             APSW_SCAN_PAGE

                        LDA             APSW_CRC_LO
                        STA             APSW_CURRENT_CRC_LO
                        LDA             APSW_CRC_HI
                        STA             APSW_CURRENT_CRC_HI
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_SCAN_RESTORE_FAIL
                        PLP
                        SEC
                        RTS

APSW_SCAN_SELECT_FAIL:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_SCAN_RESTORE_FAIL
                        LDA             #APSW_STATUS_SELECT_FAILED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_SCAN
                        STA             APSW_FAIL_PHASE
                        PLP
                        CLC
                        RTS
APSW_SCAN_RESTORE_FAIL:
                        JSR             APSW_FORCE_BANK3
                        LDA             #APSW_STATUS_RESTORE_FAILED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_RESTORE
                        STA             APSW_FAIL_PHASE
                        PLP
                        CLC
                        RTS
                        ENDIF

APSW_CRC16_BYTE:
                        EOR             APSW_CRC_HI
                        STA             APSW_CRC_HI
                        PHX
                        LDX             #$08
APSW_CRC16_BIT:
                        ASL             APSW_CRC_LO
                        ROL             APSW_CRC_HI
                        BCC             APSW_CRC16_NEXT
                        LDA             APSW_CRC_LO
                        EOR             #$21
                        STA             APSW_CRC_LO
                        LDA             APSW_CRC_HI
                        EOR             #$10
                        STA             APSW_CRC_HI
APSW_CRC16_NEXT:
                        DEX
                        BNE             APSW_CRC16_BIT
                        PLX
                        RTS

APSW_CLASSIFY_HEADER:
                        LDA             #$FF
                        STA             APSW_GENERATION_LO
                        STA             APSW_GENERATION_HI
                        LDX             #APS_SECTOR_HEADER_BYTES-1
APSW_CLASS_ALL_FF:
                        LDA             APSW_HEADER_BASE,X
                        CMP             #$FF
                        BNE             APSW_CLASS_SIGNATURE
                        DEX
                        BPL             APSW_CLASS_ALL_FF
                        LDA             #APSW_CLASS_HEADER_FF
                        JMP             APSW_CLASS_DONE

APSW_CLASS_SIGNATURE:
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_SIG
                        CMP             #APS_SECTOR_SIG0
                        BNE             APSW_CLASS_OPAQUE_SET
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_SIG+1
                        CMP             #APS_SECTOR_SIG1
                        BNE             APSW_CLASS_OPAQUE_SET
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_SIG+2
                        CMP             #APS_SECTOR_SIG2
                        BNE             APSW_CLASS_OPAQUE_SET
                        LDA             APSW_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             APSW_SECTOR
                        CMP             APSW_HEADER_BASE+APS_SH_OFF_LOCATION
                        BNE             APSW_CLASS_CORRUPT_SET
                        LDX             #$04
APSW_CLASS_RESERVED:
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_RESERVED,X
                        CMP             #$FF
                        BNE             APSW_CLASS_CORRUPT_SET
                        DEX
                        BPL             APSW_CLASS_RESERVED
                        JSR             APSW_FNV_INIT
                        LDY             #$00
APSW_CLASS_FNV:
                        LDA             APSW_HEADER_BASE,Y
                        JSR             APSW_FNV_UPDATE
                        INY
                        CPY             #APS_SH_OFF_FNV
                        BNE             APSW_CLASS_FNV
                        LDX             #$03
APSW_CLASS_FNV_COMPARE:
                        LDA             APSW_HASH0,X
                        CMP             APSW_HEADER_BASE+APS_SH_OFF_FNV,X
                        BNE             APSW_CLASS_CORRUPT_SET
                        DEX
                        BPL             APSW_CLASS_FNV_COMPARE
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_GENERATION
                        STA             APSW_GENERATION_LO
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_GENERATION+1
                        STA             APSW_GENERATION_HI
                        LDA             APSW_HEADER_BASE+APS_SH_OFF_STATE
                        CMP             #APS_SECTOR_STATE_STAGED
                        BEQ             APSW_CLASS_STAGED_SET
                        CMP             #APS_SECTOR_STATE_ACTIVE
                        BEQ             APSW_CLASS_ACTIVE_SET
                        CMP             #APS_SECTOR_STATE_RETIRED
                        BEQ             APSW_CLASS_RETIRED_SET
                        CMP             #APS_SECTOR_STATE_BAD
                        BEQ             APSW_CLASS_BAD_SET
                        CMP             #APS_SECTOR_STATE_RETIRED_BAD
                        BEQ             APSW_CLASS_RETIRED_BAD_SET
APSW_CLASS_CORRUPT_SET:
                        LDA             #APSW_CLASS_CORRUPT
                        BRA             APSW_CLASS_DONE
APSW_CLASS_OPAQUE_SET:
                        LDA             #APSW_CLASS_OPAQUE
                        BRA             APSW_CLASS_DONE
APSW_CLASS_STAGED_SET:
                        LDA             #APSW_CLASS_STAGED
                        BRA             APSW_CLASS_DONE
APSW_CLASS_ACTIVE_SET:
                        LDA             #APSW_CLASS_ACTIVE
                        BRA             APSW_CLASS_DONE
APSW_CLASS_RETIRED_SET:
                        LDA             #APSW_CLASS_RETIRED
                        BRA             APSW_CLASS_DONE
APSW_CLASS_BAD_SET:
                        LDA             #APSW_CLASS_BAD
                        BRA             APSW_CLASS_DONE
APSW_CLASS_RETIRED_BAD_SET:
                        LDA             #APSW_CLASS_RETIRED_BAD
APSW_CLASS_DONE:
                        STA             APSW_CLASS
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
; Conservative Slice 3 policy. FORMAT permits only committed managed sectors
; with no programmed bytes after the header.
APSW_APPLY_POLICY:
                        LDA             APSW_OP
                        CMP             #APSW_OP_CLAIM
                        BEQ             APSW_POLICY_CLAIM
                        CMP             #APSW_OP_CONVERT
                        BEQ             APSW_POLICY_CONVERT
APSW_POLICY_FORMAT:
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BCC             APSW_POLICY_NOT_MANAGED
                        LDA             APSW_FLAGS
                        AND             #APSW_FLAG_TAIL_ERASED
                        BEQ             APSW_POLICY_IN_USE
                        LDA             APSW_GENERATION_LO
                        CMP             #$FF
                        BNE             APSW_POLICY_INC_GEN
                        LDA             APSW_GENERATION_HI
                        CMP             #$FF
                        BEQ             APSW_POLICY_GEN_EXHAUSTED
APSW_POLICY_INC_GEN:
                        INC             APSW_GENERATION_LO
                        BNE             APSW_POLICY_OK
                        INC             APSW_GENERATION_HI
                        BRA             APSW_POLICY_OK

APSW_POLICY_CLAIM:
                        LDA             APSW_FLAGS
                        AND             #APSW_FLAG_FULL_ERASED
                        BEQ             APSW_POLICY_OCCUPIED
APSW_POLICY_GEN_ONE:
                        LDA             #$01
                        STA             APSW_GENERATION_LO
                        STZ             APSW_GENERATION_HI
                        BRA             APSW_POLICY_OK

APSW_POLICY_CONVERT:
                        LDA             APSW_FLAGS
                        AND             #APSW_FLAG_FULL_ERASED
                        BNE             APSW_POLICY_NOT_OCCUPIED
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BCS             APSW_POLICY_ALREADY_MANAGED
                        BRA             APSW_POLICY_GEN_ONE

APSW_POLICY_OCCUPIED:
                        LDA             #APSW_STATUS_OCCUPIED
                        BRA             APSW_POLICY_FAIL
APSW_POLICY_NOT_MANAGED:
                        LDA             #APSW_STATUS_NOT_MANAGED
                        BRA             APSW_POLICY_FAIL
APSW_POLICY_IN_USE:
                        LDA             #APSW_STATUS_SECTOR_IN_USE
                        BRA             APSW_POLICY_FAIL
APSW_POLICY_GEN_EXHAUSTED:
                        LDA             #APSW_STATUS_GEN_EXHAUSTED
                        BRA             APSW_POLICY_FAIL
APSW_POLICY_ALREADY_MANAGED:
                        LDA             #APSW_STATUS_ALREADY_MANAGED
                        BRA             APSW_POLICY_FAIL
APSW_POLICY_NOT_OCCUPIED:
                        LDA             #APSW_STATUS_NOT_OCCUPIED
APSW_POLICY_FAIL:
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_POLICY
                        STA             APSW_FAIL_PHASE
                        CLC
                        RTS
APSW_POLICY_OK:
                        SEC
                        RTS

APSW_BUILD_HEADER:
                        LDA             #$FF
                        LDX             #APS_SECTOR_HEADER_BYTES-1
APSW_BUILD_FILL:
                        STA             APSW_HEADER_BASE,X
                        DEX
                        BPL             APSW_BUILD_FILL
                        LDA             #APS_SECTOR_SIG0
                        STA             APSW_HEADER_BASE+APS_SH_OFF_SIG
                        LDA             #APS_SECTOR_SIG1
                        STA             APSW_HEADER_BASE+APS_SH_OFF_SIG+1
                        LDA             #APS_SECTOR_SIG2
                        STA             APSW_HEADER_BASE+APS_SH_OFF_SIG+2
                        LDA             APSW_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             APSW_SECTOR
                        STA             APSW_HEADER_BASE+APS_SH_OFF_LOCATION
                        LDA             APSW_GENERATION_LO
                        STA             APSW_HEADER_BASE+APS_SH_OFF_GENERATION
                        LDA             APSW_GENERATION_HI
                        STA             APSW_HEADER_BASE+APS_SH_OFF_GENERATION+1
                        JSR             APSW_FNV_INIT
                        LDY             #$00
APSW_BUILD_FNV:
                        LDA             APSW_HEADER_BASE,Y
                        JSR             APSW_FNV_UPDATE
                        INY
                        CPY             #APS_SH_OFF_FNV
                        BNE             APSW_BUILD_FNV
                        LDX             #$03
APSW_BUILD_HASH_COPY:
                        LDA             APSW_HASH0,X
                        STA             APSW_HEADER_BASE+APS_SH_OFF_FNV,X
                        DEX
                        BPL             APSW_BUILD_HASH_COPY
                        RTS
                        ENDIF

APSW_FNV_INIT:
                        LDA             #$C5
                        STA             APSW_HASH0
                        LDA             #$9D
                        STA             APSW_HASH1
                        LDA             #$1C
                        STA             APSW_HASH2
                        LDA             #$81
                        STA             APSW_HASH3
                        RTS

APSW_FNV_UPDATE:
                        EOR             APSW_HASH0
                        STA             APSW_HASH0
                        LDX             #$03
APSW_FNV_COPY:
                        LDA             APSW_HASH0,X
                        STA             APSW_TERM0,X
                        DEX
                        BPL             APSW_FNV_COPY
                        LDX             #$01
                        JSR             APSW_FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             APSW_FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             APSW_FNV_SHIFT_ADD
                        LDX             #$01
                        JSR             APSW_FNV_SHIFT_ADD
                        LDA             APSW_HASH3
                        CLC
                        ADC             APSW_TERM1
                        STA             APSW_HASH3
                        RTS

APSW_FNV_SHIFT_ADD:
                        ASL             APSW_TERM0
                        ROL             APSW_TERM1
                        ROL             APSW_TERM2
                        ROL             APSW_TERM3
                        DEX
                        BNE             APSW_FNV_SHIFT_ADD
                        CLC
                        LDA             APSW_HASH0
                        ADC             APSW_TERM0
                        STA             APSW_HASH0
                        LDA             APSW_HASH1
                        ADC             APSW_TERM1
                        STA             APSW_HASH1
                        LDA             APSW_HASH2
                        ADC             APSW_TERM2
                        STA             APSW_HASH2
                        LDA             APSW_HASH3
                        ADC             APSW_TERM3
                        STA             APSW_HASH3
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
; All flash command sequences below run from this RAM image. No ROM calls are
; made until Bank 3 has been restored through the RAM selector.
APSW_MUTATE_SECTOR:
                        PHP
                        SEI
                        LDA             APSW_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_MUTATE_SELECT_FAIL
                        STZ             APSW_PTR_LO
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI

                        LDA             APSW_OP
                        CMP             #APSW_OP_CLAIM
                        BEQ             APSW_MUTATE_WRITE_HEADER
                        LDA             #APSW_PHASE_ERASE
                        STA             APSW_FAIL_PHASE
                        JSR             APSW_FLASH_ERASE
                        BCC             APSW_MUTATE_ERASE_FAIL
                        LDA             #APSW_PHASE_ERASE_VERIFY
                        STA             APSW_FAIL_PHASE
                        JSR             APSW_VERIFY_ERASED
                        BCC             APSW_MUTATE_VERIFY_FAIL

APSW_MUTATE_WRITE_HEADER:
                        LDA             #APSW_PHASE_HEADER_WRITE
                        STA             APSW_FAIL_PHASE
                        LDY             #$00
APSW_MUTATE_HEADER_BYTE:
                        LDA             APSW_HEADER_BASE,Y
                        JSR             APSW_FLASH_WRITE_BYTE
                        BCC             APSW_MUTATE_PROGRAM_FAIL
                        INY
                        CPY             #APS_SH_OFF_STATE
                        BNE             APSW_MUTATE_HEADER_BYTE
                        LDA             #APSW_PHASE_HEADER_VERIFY
                        STA             APSW_FAIL_PHASE
                        JSR             APSW_VERIFY_HEADER_STAGED
                        BCC             APSW_MUTATE_VERIFY_FAIL
                        LDA             #APSW_PHASE_COMMIT
                        STA             APSW_FAIL_PHASE
                        LDY             #APS_SH_OFF_STATE
                        LDA             #APS_SECTOR_STATE_ACTIVE
                        JSR             APSW_FLASH_WRITE_BYTE
                        BCC             APSW_MUTATE_PROGRAM_FAIL
                        LDA             (APSW_PTR_LO),Y
                        CMP             #APS_SECTOR_STATE_ACTIVE
                        BNE             APSW_MUTATE_VERIFY_FAIL
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_MUTATE_RESTORE_FAIL
                        PLP
                        SEC
                        RTS

APSW_MUTATE_SELECT_FAIL:
                        LDA             #APSW_STATUS_SELECT_FAILED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_SCAN
                        STA             APSW_FAIL_PHASE
                        BRA             APSW_MUTATE_RESTORE_ERROR
APSW_MUTATE_ERASE_FAIL:
                        LDA             #APSW_STATUS_ERASE_FAILED
                        STA             APSW_STATUS
                        BRA             APSW_MUTATE_SAVE_ADDR
APSW_MUTATE_PROGRAM_FAIL:
                        LDA             #APSW_STATUS_PROGRAM_FAILED
                        STA             APSW_STATUS
                        BRA             APSW_MUTATE_SAVE_ADDR
APSW_MUTATE_VERIFY_FAIL:
                        LDA             #APSW_STATUS_VERIFY_FAILED
                        STA             APSW_STATUS
APSW_MUTATE_SAVE_ADDR:
                        TYA
                        STA             APSW_FAIL_ADDR_LO
                        LDA             APSW_PTR_HI
                        STA             APSW_FAIL_ADDR_HI
APSW_MUTATE_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSW_MUTATE_RESTORE_FAIL
                        PLP
                        CLC
                        RTS
APSW_MUTATE_RESTORE_FAIL:
                        JSR             APSW_FORCE_BANK3
                        LDA             #APSW_STATUS_RESTORE_FAILED
                        STA             APSW_STATUS
                        LDA             #APSW_PHASE_RESTORE
                        STA             APSW_FAIL_PHASE
                        PLP
                        CLC
                        RTS
                        ENDIF

; A valid selector request is expected to succeed. If it reports failure,
; force the published Bank-3 latch pattern from RAM before returning an error.
APSW_FORCE_BANK3:
                        LDA             #STR8_BANK_STATE_MASK
                        TRB             STR8_BANK_STATE_BYTE
                        LDA             #STR8_BANK_STATE_MASK
                        TSB             STR8_BANK_STATE_BYTE
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
APSW_FLASH_ERASE:
                        LDA             #$AA
                        STA             APSW_FLASH_UNLOCK1
                        LDA             #$55
                        STA             APSW_FLASH_UNLOCK2
                        LDA             #$80
                        STA             APSW_FLASH_UNLOCK1
                        LDA             #$AA
                        STA             APSW_FLASH_UNLOCK1
                        LDA             #$55
                        STA             APSW_FLASH_UNLOCK2
                        LDA             #$30
                        LDY             #$00
                        STA             (APSW_PTR_LO),Y
                        STZ             APSW_TMO0
                        STZ             APSW_TMO1
                        LDA             #APSW_ERASE_TIMEOUT_HI
                        STA             APSW_TMO2
APSW_ERASE_POLL:
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BEQ             APSW_ERASE_OK
                        DEC             APSW_TMO0
                        BNE             APSW_ERASE_POLL
                        DEC             APSW_TMO1
                        BNE             APSW_ERASE_POLL
                        DEC             APSW_TMO2
                        BNE             APSW_ERASE_POLL
                        LDA             #$F0
                        STA             APSW_FLASH_UNLOCK1
                        CLC
                        RTS
APSW_ERASE_OK:
                        SEC
                        RTS
                        ENDIF

APSW_FLASH_WRITE_BYTE:
                        STA             APSW_BYTE
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSW_WRITE_OK
                        AND             APSW_BYTE
                        CMP             APSW_BYTE
                        BNE             APSW_WRITE_FAIL
                        LDA             #$AA
                        STA             APSW_FLASH_UNLOCK1
                        LDA             #$55
                        STA             APSW_FLASH_UNLOCK2
                        LDA             #$A0
                        STA             APSW_FLASH_UNLOCK1
                        LDA             APSW_BYTE
                        STA             (APSW_PTR_LO),Y
                        STZ             APSW_TMO0
                        STZ             APSW_TMO1
                        LDA             #APSW_WRITE_TIMEOUT_HI
                        STA             APSW_TMO2
APSW_WRITE_POLL:
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_BYTE
                        BEQ             APSW_WRITE_OK
                        DEC             APSW_TMO0
                        BNE             APSW_WRITE_POLL
                        DEC             APSW_TMO1
                        BNE             APSW_WRITE_POLL
                        DEC             APSW_TMO2
                        BNE             APSW_WRITE_POLL
                        LDA             #$F0
                        STA             APSW_FLASH_UNLOCK1
APSW_WRITE_FAIL:
                        CLC
                        RTS
APSW_WRITE_OK:
                        SEC
                        RTS

                        IF              APSO_OBJECT_BUILD
                        ELSE
APSW_VERIFY_ERASED:
                        STZ             APSW_PTR_LO
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        LDX             #$10
APSW_VERIFY_ERASED_PAGE:
                        LDY             #$00
APSW_VERIFY_ERASED_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BNE             APSW_VERIFY_FAIL
                        INY
                        BNE             APSW_VERIFY_ERASED_BYTE
                        INC             APSW_PTR_HI
                        DEX
                        BNE             APSW_VERIFY_ERASED_PAGE
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        SEC
                        RTS

APSW_VERIFY_HEADER_STAGED:
                        LDY             #$00
APSW_VERIFY_HEADER_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        CMP             APSW_HEADER_BASE,Y
                        BNE             APSW_VERIFY_FAIL
                        INY
                        CPY             #APS_SH_OFF_STATE
                        BNE             APSW_VERIFY_HEADER_BYTE
                        LDA             (APSW_PTR_LO),Y
                        CMP             #APS_SECTOR_STATE_STAGED
                        BNE             APSW_VERIFY_FAIL
                        SEC
                        RTS
APSW_VERIFY_FAIL:
                        CLC
                        RTS
                        ENDIF

; ----------------------------------------------------------------------------
; Slice 4: single-sector AP object append/list/validate/load.
;
; The selected 4K sector is mirrored at $2000. A reconstructed AP v2 envelope
; uses the existing $0A00 package staging area. Resident HIMON's published
; $7E2D AP service performs source validation and final load/link validation.
; ----------------------------------------------------------------------------

                        IF              APSO_OBJECT_BUILD
APSO_LIST_BODY:
                        CLD
                        JSR             APSO_CLEAR_RESULT
                        JSR             APSO_VALIDATE_LOCATION
                        BCS             APSO_LIST_LOCATION_OK
                        JMP             APSO_RETURN_ERROR
APSO_LIST_LOCATION_OK:
                        JSR             APSO_STAGE_AND_INSPECT
                        BCS             APSO_LIST_STAGE_OK
                        JMP             APSO_RETURN_ERROR
APSO_LIST_STAGE_OK:
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BEQ             APSO_FIND_MANAGED
                        JMP             APSO_NOT_MANAGED
APSO_FIND_MANAGED:
                        LDA             #APSO_SCAN_LIST
                        STA             APSO_SCAN_MODE
                        JSR             APSO_SCAN_LOG
                        BCS             APSO_LIST_SCAN_OK
                        JMP             APSO_RETURN_ERROR
APSO_LIST_SCAN_OK:
                        LDA             #APSO_STATUS_OK
                        STA             APSO_STATUS
                        LDX             #<APSO_MSG_LIST_OK
                        LDY             #>APSO_MSG_LIST_OK
                        JSR             APSW_PRINT_LINE
                        LDA             #APSO_STATUS_OK
                        SEC
                        RTS

APSO_INSTALL_PREPARE_BODY:
                        CLD
                        JSR             APSO_CLEAR_RESULT
                        JSR             APSO_VALIDATE_OBJECT_REQUEST
                        BCS             APSO_PREP_REQUEST_OK
                        JMP             APSO_RETURN_ERROR
APSO_PREP_REQUEST_OK:
                        LDA             #APSO_PHASE_SOURCE
                        STA             APSO_FAIL_PHASE
                        JSR             APSO_VALIDATE_SOURCE
                        BCS             APSO_PREP_SOURCE_OK
                        JMP             APSO_RETURN_ERROR
APSO_PREP_SOURCE_OK:
                        JSR             APSO_STAGE_AND_INSPECT
                        BCS             APSO_PREP_STAGE_OK
                        JMP             APSO_RETURN_ERROR
APSO_PREP_STAGE_OK:
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BEQ             APSO_PREP_MANAGED
                        JMP             APSO_NOT_MANAGED
APSO_PREP_MANAGED:
                        LDA             #APSO_SCAN_PREPARE
                        STA             APSO_SCAN_MODE
                        JSR             APSO_SCAN_LOG
                        BCS             APSO_PREP_SCAN_OK
                        JMP             APSO_RETURN_ERROR
APSO_PREP_SCAN_OK:
                        JSR             APSO_CHECK_SPACE
                        BCS             APSO_PREP_SPACE_OK
                        JMP             APSO_RETURN_ERROR
APSO_PREP_SPACE_OK:
                        JSR             APSO_BUILD_RECORD_HEADER
                        JSR             APSO_SAVE_PREPARED
                        LDA             #APSO_STATUS_PREPARED
                        STA             APSO_STATUS
                        STZ             APSO_FAIL_PHASE
                        SEC
                        RTS

APSO_INSTALL_EXECUTE_BODY:
                        CLD
                        LDA             APSO_CONFIRM
                        CMP             #APSO_CONFIRM_EXECUTE
                        BEQ             APSO_EXEC_CONFIRMED
                        JMP             APSO_NOT_CONFIRMED
APSO_EXEC_CONFIRMED:
                        STZ             APSO_CONFIRM
                        JSR             APSO_COMPARE_REQUEST
                        BCS             APSO_EXEC_REQUEST_OK
                        JMP             APSO_MEDIA_CHANGED
APSO_EXEC_REQUEST_OK:
                        LDA             #APSO_PHASE_SOURCE
                        STA             APSO_FAIL_PHASE
                        JSR             APSO_VALIDATE_SOURCE
                        BCS             APSO_EXEC_SOURCE_OK
                        JMP             APSO_RETURN_ERROR
APSO_EXEC_SOURCE_OK:
                        JSR             APSO_COMPARE_SOURCE
                        BCS             APSO_EXEC_SOURCE_SAME
                        JMP             APSO_MEDIA_CHANGED
APSO_EXEC_SOURCE_SAME:
                        JSR             APSO_STAGE_AND_INSPECT
                        BCS             APSO_EXEC_STAGE_OK
                        JMP             APSO_RETURN_ERROR
APSO_EXEC_STAGE_OK:
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BEQ             APSO_EXEC_MANAGED
                        JMP             APSO_MEDIA_CHANGED
APSO_EXEC_MANAGED:
                        LDA             #APSO_SCAN_PREPARE
                        STA             APSO_SCAN_MODE
                        JSR             APSO_SCAN_LOG
                        BCS             APSO_EXEC_SCAN_OK
                        JMP             APSO_RETURN_ERROR
APSO_EXEC_SCAN_OK:
                        JSR             APSO_COMPARE_MEDIA
                        BCS             APSO_EXEC_MEDIA_SAME
                        JMP             APSO_MEDIA_CHANGED
APSO_EXEC_MEDIA_SAME:
                        JSR             APSO_BUILD_RECORD_HEADER
                        JSR             APSO_PROGRAM_RECORD
                        BCS             APSO_EXEC_PROGRAM_OK
                        JMP             APSO_RETURN_ERROR
APSO_EXEC_PROGRAM_OK:
                        LDA             #APSO_STATUS_OK
                        STA             APSO_STATUS
                        STZ             APSO_FAIL_PHASE
                        SEC
                        RTS

APSO_VALIDATE_BODY:
                        CLD
                        JSR             APSO_CLEAR_RESULT
                        JSR             APSO_VALIDATE_OBJECT_REQUEST_NO_SOURCE
                        BCS             APSO_VALIDATE_REQUEST_OK
                        JMP             APSO_RETURN_ERROR
APSO_VALIDATE_REQUEST_OK:
                        JSR             APSO_FIND_AND_RECONSTRUCT
                        BCS             APSO_VALIDATE_FOUND
                        JMP             APSO_RETURN_ERROR
APSO_VALIDATE_FOUND:
                        LDA             #APSO_PHASE_VALIDATE
                        STA             APSO_FAIL_PHASE
                        JSR             APSO_VALIDATE_BUFFER
                        BCS             APSO_VALIDATE_BUFFER_OK
                        JMP             APSO_RETURN_ERROR
APSO_VALIDATE_BUFFER_OK:
                        LDA             #APSO_STATUS_OK
                        STA             APSO_STATUS
                        STZ             APSO_FAIL_PHASE
                        SEC
                        RTS

APSO_LOAD_BODY:
                        JSR             APSO_VALIDATE_BODY
                        BCS             APSO_LOAD_VALID
                        JMP             APSO_RETURN_ERROR
APSO_LOAD_VALID:
                        LDA             #<APSO_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC
                        LDA             #>APSO_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC+1
                        LDA             APSO_DEST_LO
                        STA             ASM_ABI_AP_DST
                        LDA             APSO_DEST_HI
                        STA             ASM_ABI_AP_DST+1
                        LDA             #ASM_ABI_AP_OP_LOAD
                        STA             ASM_ABI_AP_OP
                        JSR             APSO_CALL_AP_SERVICE
                        BCS             APSO_LOAD_SERVICE_OK
                        LDA             APSO_STATUS
                        CMP             #APSO_STATUS_SERVICE_FAILED
                        BEQ             APSO_LOAD_SERVICE_ERROR
                        JMP             APSO_AP_INVALID
APSO_LOAD_SERVICE_ERROR:
                        JMP             APSO_RETURN_ERROR
APSO_LOAD_SERVICE_OK:
                        STX             APSO_ENTRY_LO
                        STY             APSO_ENTRY_HI
                        JSR             APSO_RUN_ENTRY
                        LDA             #APSO_STATUS_OK
                        STA             APSO_STATUS
                        SEC
                        RTS

APSO_RUN_ENTRY:
                        JMP             (APSO_ENTRY_LO)

APSO_CLEAR_RESULT:
                        LDX             #APSO_CARD_END-APSO_CONFIRM
APSO_CLEAR_RESULT_LOOP:
                        STZ             APSO_CONFIRM,X
                        DEX
                        BPL             APSO_CLEAR_RESULT_LOOP
                        RTS

APSO_VALIDATE_LOCATION:
                        LDA             APSW_BANK
                        CMP             #$03
                        BCS             APSO_BAD_REQUEST
                        LDA             APSW_SECTOR
                        CMP             #$08
                        BCC             APSO_BAD_REQUEST
                        CMP             #$10
                        BCS             APSO_BAD_REQUEST
                        SEC
                        RTS

APSO_VALIDATE_OBJECT_REQUEST:
                        JSR             APSO_VALIDATE_OBJECT_REQUEST_NO_SOURCE
                        BCC             APSO_VALIDATE_OBJECT_RETURN
                        LDA             APSO_SOURCE_LO
                        ORA             APSO_SOURCE_HI
                        BEQ             APSO_BAD_REQUEST
                        SEC
APSO_VALIDATE_OBJECT_RETURN:
                        RTS

APSO_VALIDATE_OBJECT_REQUEST_NO_SOURCE:
                        JSR             APSO_VALIDATE_LOCATION
                        BCC             APSO_VALIDATE_OBJECT_RETURN
                        LDA             APSO_OBJECT_LO
                        ORA             APSO_OBJECT_HI
                        BEQ             APSO_BAD_REQUEST
                        LDA             APSO_OBJECT_GEN_LO
                        ORA             APSO_OBJECT_GEN_HI
                        BEQ             APSO_BAD_REQUEST
                        SEC
                        RTS

APSO_BAD_REQUEST:
                        LDA             #APSO_STATUS_BAD_REQUEST
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS

APSO_NOT_MANAGED:
                        LDA             #APSO_STATUS_NOT_MANAGED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_SCAN
                        STA             APSO_FAIL_PHASE
                        JMP             APSO_RETURN_ERROR

APSO_NOT_CONFIRMED:
                        STZ             APSO_CONFIRM
                        LDA             #APSO_STATUS_NOT_CONFIRMED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        JMP             APSO_RETURN_ERROR

APSO_MEDIA_CHANGED:
                        LDA             #APSO_STATUS_MEDIA_CHANGED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        JMP             APSO_RETURN_ERROR

APSO_AP_INVALID:
                        LDA             #APSO_STATUS_AP_INVALID
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_VALIDATE
                        STA             APSO_FAIL_PHASE
                        JMP             APSO_RETURN_ERROR

APSO_RETURN_ERROR:
                        LDA             APSO_STATUS
                        CLC
                        RTS

APSO_CALL_AP_SERVICE:
                        LDA             ASM_ABI_AP_SERVICE
                        STA             APSW_CALL_LO
                        LDA             ASM_ABI_AP_SERVICE+1
                        STA             APSW_CALL_HI
                        ORA             APSW_CALL_LO
                        BEQ             APSO_CALL_AP_MISSING
                        JMP             (APSW_CALL_LO)
APSO_CALL_AP_MISSING:
                        LDA             #APSO_STATUS_SERVICE_FAILED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_VALIDATE
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS

APSO_VALIDATE_SOURCE:
                        LDA             APSO_SOURCE_LO
                        STA             ASM_ABI_AP_SRC
                        LDA             APSO_SOURCE_HI
                        STA             ASM_ABI_AP_SRC+1
                        LDA             #ASM_ABI_AP_OP_PARSE
                        STA             ASM_ABI_AP_OP
                        JSR             APSO_CALL_AP_SERVICE
                        BCS             APSO_VALIDATE_SOURCE_PARSED
                        LDA             APSO_STATUS
                        CMP             #APSO_STATUS_SERVICE_FAILED
                        BEQ             APSO_VALIDATE_SOURCE_RETURN
                        JMP             APSO_AP_INVALID
APSO_VALIDATE_SOURCE_PARSED:
                        LDA             ASM_ABI_AP_PACKAGE_LEN
                        STA             APSO_PACKAGE_LEN_LO
                        LDA             ASM_ABI_AP_PACKAGE_LEN+1
                        STA             APSO_PACKAGE_LEN_HI
                        LDA             APSO_SOURCE_LO
                        STA             APSW_PTR_LO
                        LDA             APSO_SOURCE_HI
                        STA             APSW_PTR_HI
                        JSR             APSO_HASH_PACKAGE
                        SEC
APSO_VALIDATE_SOURCE_RETURN:
                        RTS

APSO_VALIDATE_BUFFER:
                        LDA             #<APSO_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC
                        LDA             #>APSO_PACKAGE_BUFFER
                        STA             ASM_ABI_AP_SRC+1
                        LDA             #ASM_ABI_AP_OP_PARSE
                        STA             ASM_ABI_AP_OP
                        JSR             APSO_CALL_AP_SERVICE
                        BCS             APSO_VALIDATE_BUFFER_PARSED
                        LDA             APSO_STATUS
                        CMP             #APSO_STATUS_SERVICE_FAILED
                        BEQ             APSO_VALIDATE_BUFFER_RETURN
                        JMP             APSO_AP_INVALID
APSO_VALIDATE_BUFFER_PARSED:
                        SEC
APSO_VALIDATE_BUFFER_RETURN:
                        RTS

APSO_HASH_PACKAGE:
                        LDA             APSO_PACKAGE_LEN_LO
                        STA             APSO_COUNT_LO
                        LDA             APSO_PACKAGE_LEN_HI
                        STA             APSO_COUNT_HI
                        JSR             APSW_FNV_INIT
APSO_HASH_PACKAGE_LOOP:
                        LDA             APSO_COUNT_LO
                        ORA             APSO_COUNT_HI
                        BEQ             APSO_HASH_PACKAGE_DONE
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSW_FNV_UPDATE
                        JSR             APSO_INC_PTR
                        JSR             APSO_DEC_COUNT
                        BRA             APSO_HASH_PACKAGE_LOOP
APSO_HASH_PACKAGE_DONE:
                        LDX             #$03
APSO_HASH_PACKAGE_SAVE:
                        LDA             APSW_HASH0,X
                        STA             APSO_PACKAGE_FNV0,X
                        DEX
                        BPL             APSO_HASH_PACKAGE_SAVE
                        RTS

APSO_STAGE_AND_INSPECT:
                        JSR             APSW_VALIDATE_SERVICES
                        BCC             APSO_STAGE_SERVICE_BAD
                        JSR             APSW_BOOT_SELECTOR
                        BCC             APSO_STAGE_SELECT_BAD
                        JSR             APSO_STAGE_SECTOR
                        BCC             APSO_STAGE_SELECT_BAD
                        JSR             APSO_INSPECT_BUFFER
                        SEC
                        RTS
APSO_STAGE_SERVICE_BAD:
                        LDA             #APSO_STATUS_SERVICE_FAILED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_SCAN
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS
APSO_STAGE_SELECT_BAD:
                        LDA             #APSO_STATUS_SERVICE_FAILED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_SCAN
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS

APSO_STAGE_SECTOR:
                        PHP
                        SEI
                        LDA             APSW_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSO_STAGE_RESTORE_ERROR
                        STZ             APSW_PTR_LO
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             APSW_PTR_HI
                        LDA             #<APSO_SECTOR_BUFFER
                        STA             APSO_SRC_TMP_LO
                        LDA             #>APSO_SECTOR_BUFFER
                        STA             APSO_SRC_TMP_HI
                        LDX             #$10
APSO_STAGE_PAGE:
                        LDY             #$00
APSO_STAGE_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        STA             (APSO_SRC_TMP_LO),Y
                        INY
                        BNE             APSO_STAGE_BYTE
                        INC             APSW_PTR_HI
                        INC             APSO_SRC_TMP_HI
                        DEX
                        BNE             APSO_STAGE_PAGE
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSO_STAGE_RESTORE_FAIL
                        PLP
                        SEC
                        RTS
APSO_STAGE_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
APSO_STAGE_RESTORE_FAIL:
                        JSR             APSW_FORCE_BANK3
                        PLP
                        CLC
                        RTS

APSO_INSPECT_BUFFER:
                        LDY             #$00
APSO_INSPECT_HEADER:
                        LDA             APSO_SECTOR_BUFFER,Y
                        STA             APSW_HEADER_BASE,Y
                        INY
                        CPY             #APS_SECTOR_HEADER_BYTES
                        BNE             APSO_INSPECT_HEADER
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDA             #<APSO_SECTOR_BUFFER
                        STA             APSW_PTR_LO
                        LDA             #>APSO_SECTOR_BUFFER
                        STA             APSW_PTR_HI
                        LDX             #$10
APSO_INSPECT_PAGE:
                        LDY             #$00
APSO_INSPECT_BYTE:
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSW_CRC16_BYTE
                        INY
                        BNE             APSO_INSPECT_BYTE
                        INC             APSW_PTR_HI
                        DEX
                        BNE             APSO_INSPECT_PAGE
                        LDA             APSW_CRC_LO
                        STA             APSO_MEDIA_CRC_LO
                        LDA             APSW_CRC_HI
                        STA             APSO_MEDIA_CRC_HI
                        JSR             APSW_CLASSIFY_HEADER
                        RTS

APSO_SCAN_LOG:
                        LDA             #APS_SECTOR_HEADER_BYTES
                        STA             APSO_RECORD_OFF_LO
                        STZ             APSO_RECORD_OFF_HI
                        STZ             APSO_RECORD_COUNT
                        STZ             APSO_FOUND_COUNT
APSO_SCAN_NEXT:
                        JSR             APSO_PTR_FROM_RECORD_OFFSET
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BEQ             APSO_SCAN_TAIL
                        JSR             APSO_COPY_RECORD_HEADER
                        JSR             APSO_VALIDATE_RECORD_HEADER
                        BCC             APSO_LOG_CORRUPT
                        JSR             APSO_VALIDATE_RECORD_PAYLOAD
                        BCC             APSO_LOG_CORRUPT
                        INC             APSO_RECORD_COUNT
                        JSR             APSO_RECORD_MATCHES_REQUEST
                        BCC             APSO_SCAN_NOT_MATCH
                        INC             APSO_FOUND_COUNT
                        LDA             APSO_RECORD_OFF_LO
                        STA             APSO_FOUND_OFF_LO
                        LDA             APSO_RECORD_OFF_HI
                        STA             APSO_FOUND_OFF_HI
APSO_SCAN_NOT_MATCH:
                        LDA             APSO_SCAN_MODE
                        BNE             APSO_SCAN_NO_PRINT
                        JSR             APSO_PRINT_OBJECT_ROW
APSO_SCAN_NO_PRINT:
                        JSR             APSO_ADVANCE_RECORD_OFFSET
                        BCC             APSO_LOG_CORRUPT
                        BRA             APSO_SCAN_NEXT

APSO_SCAN_TAIL:
                        JSR             APSO_VERIFY_BUFFER_TAIL
                        BCC             APSO_LOG_CORRUPT
                        LDA             APSO_SCAN_MODE
                        CMP             #APSO_SCAN_PREPARE
                        BEQ             APSO_SCAN_PREPARE_DONE
                        CMP             #APSO_SCAN_FIND
                        BNE             APSO_SCAN_OK
                        LDA             APSO_FOUND_COUNT
                        BEQ             APSO_NOT_FOUND
                        CMP             #$01
                        BNE             APSO_LOG_CORRUPT
                        LDA             APSO_FOUND_OFF_LO
                        STA             APSO_RECORD_OFF_LO
                        LDA             APSO_FOUND_OFF_HI
                        STA             APSO_RECORD_OFF_HI
                        JSR             APSO_PTR_FROM_RECORD_OFFSET
                        JSR             APSO_COPY_RECORD_HEADER
                        BRA             APSO_SCAN_OK
APSO_SCAN_PREPARE_DONE:
                        LDA             APSO_FOUND_COUNT
                        BNE             APSO_DUPLICATE
APSO_SCAN_OK:
                        SEC
                        RTS

APSO_LOG_CORRUPT:
                        LDA             #APSO_STATUS_LOG_CORRUPT
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_SCAN
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS
APSO_DUPLICATE:
                        LDA             #APSO_STATUS_DUPLICATE
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS
APSO_NOT_FOUND:
                        LDA             #APSO_STATUS_NOT_FOUND
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS

APSO_PTR_FROM_RECORD_OFFSET:
                        LDA             APSO_RECORD_OFF_LO
                        STA             APSW_PTR_LO
                        LDA             APSO_RECORD_OFF_HI
                        CLC
                        ADC             #>APSO_SECTOR_BUFFER
                        STA             APSW_PTR_HI
                        RTS

APSO_COPY_RECORD_HEADER:
                        LDY             #$00
APSO_COPY_RECORD_HEADER_LOOP:
                        LDA             (APSW_PTR_LO),Y
                        STA             APSO_RECORD_HEADER_BASE,Y
                        INY
                        CPY             #APS_RECORD_HEADER_BYTES
                        BNE             APSO_COPY_RECORD_HEADER_LOOP
                        RTS

APSO_VALIDATE_RECORD_HEADER:
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_SIG
                        CMP             #APS_RECORD_SIG0
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_SIG+1
                        CMP             #APS_RECORD_SIG1
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_VERSION
                        CMP             #APS_RECORD_VERSION
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        CMP             #APS_RECORD_CHUNK
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        CMP             #(APS_RECORD_FLAG_FIRST+APS_RECORD_FLAG_LAST)
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_RESERVED
                        CMP             #$FF
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        ORA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        BEQ             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        ORA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        BEQ             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        ORA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        ORA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        BEQ             APSO_RECORD_HEADER_BAD
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDY             #$00
APSO_RECORD_HEADER_CRC:
                        LDA             APSO_RECORD_HEADER_BASE,Y
                        JSR             APSW_CRC16_BYTE
                        INY
                        CPY             #APS_RH_OFF_CRC16
                        BNE             APSO_RECORD_HEADER_CRC
                        LDA             APSW_CRC_LO
                        CMP             APSO_RECORD_HEADER_BASE+APS_RH_OFF_CRC16
                        BNE             APSO_RECORD_HEADER_BAD
                        LDA             APSW_CRC_HI
                        CMP             APSO_RECORD_HEADER_BASE+APS_RH_OFF_CRC16+1
                        BNE             APSO_RECORD_HEADER_BAD
                        SEC
                        RTS
APSO_RECORD_HEADER_BAD:
                        CLC
                        RTS

APSO_VALIDATE_RECORD_PAYLOAD:
                        JSR             APSO_PTR_ADD_RECORD_HEADER
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             APSO_COUNT_LO
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             APSO_COUNT_HI
                        LDA             APSW_PTR_HI
                        CLC
                        ADC             APSO_COUNT_HI
                        CMP             #>(APSO_SECTOR_BUFFER+APS_SECTOR_BYTES)
                        BCS             APSO_RECORD_PAYLOAD_BAD
                        JSR             APSW_FNV_INIT
APSO_RECORD_PAYLOAD_HASH:
                        LDA             APSO_COUNT_LO
                        ORA             APSO_COUNT_HI
                        BEQ             APSO_RECORD_PAYLOAD_COMMIT
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        JSR             APSW_FNV_UPDATE
                        JSR             APSO_INC_PTR
                        LDA             APSW_PTR_HI
                        CMP             #>(APSO_SECTOR_BUFFER+APS_SECTOR_BYTES)
                        BCS             APSO_RECORD_PAYLOAD_BAD
                        JSR             APSO_DEC_COUNT
                        BRA             APSO_RECORD_PAYLOAD_HASH
APSO_RECORD_PAYLOAD_COMMIT:
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #APS_RECORD_COMMIT
                        BNE             APSO_RECORD_PAYLOAD_BAD
                        LDX             #$03
APSO_RECORD_PAYLOAD_COMPARE:
                        LDA             APSW_HASH0,X
                        CMP             APSO_RECORD_HEADER_BASE+APS_RH_OFF_FNV,X
                        BNE             APSO_RECORD_PAYLOAD_BAD
                        DEX
                        BPL             APSO_RECORD_PAYLOAD_COMPARE
                        SEC
                        RTS
APSO_RECORD_PAYLOAD_BAD:
                        CLC
                        RTS

APSO_PTR_ADD_RECORD_HEADER:
                        LDA             APSW_PTR_LO
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES
                        STA             APSW_PTR_LO
                        BCC             APSO_PTR_ADD_RECORD_DONE
                        INC             APSW_PTR_HI
APSO_PTR_ADD_RECORD_DONE:
                        RTS

APSO_ADVANCE_RECORD_OFFSET:
                        JSR             APSO_INC_PTR
                        LDA             APSW_PTR_HI
                        CMP             #>(APSO_SECTOR_BUFFER+APS_SECTOR_BYTES)
                        BCS             APSO_ADVANCE_RECORD_BAD
                        SEC
                        SBC             #>APSO_SECTOR_BUFFER
                        STA             APSO_RECORD_OFF_HI
                        LDA             APSW_PTR_LO
                        STA             APSO_RECORD_OFF_LO
                        SEC
                        RTS
APSO_ADVANCE_RECORD_BAD:
                        CLC
                        RTS

APSO_VERIFY_BUFFER_TAIL:
APSO_VERIFY_BUFFER_TAIL_LOOP:
                        LDA             APSW_PTR_HI
                        CMP             #>(APSO_SECTOR_BUFFER+APS_SECTOR_BYTES)
                        BEQ             APSO_VERIFY_BUFFER_TAIL_OK
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        CMP             #$FF
                        BNE             APSO_VERIFY_BUFFER_TAIL_BAD
                        JSR             APSO_INC_PTR
                        BRA             APSO_VERIFY_BUFFER_TAIL_LOOP
APSO_VERIFY_BUFFER_TAIL_OK:
                        SEC
                        RTS
APSO_VERIFY_BUFFER_TAIL_BAD:
                        CLC
                        RTS

APSO_RECORD_MATCHES_REQUEST:
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        CMP             APSO_OBJECT_LO
                        BNE             APSO_RECORD_NOT_MATCH
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        CMP             APSO_OBJECT_HI
                        BNE             APSO_RECORD_NOT_MATCH
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        CMP             APSO_OBJECT_GEN_LO
                        BNE             APSO_RECORD_NOT_MATCH
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        CMP             APSO_OBJECT_GEN_HI
                        BNE             APSO_RECORD_NOT_MATCH
                        SEC
                        RTS
APSO_RECORD_NOT_MATCH:
                        CLC
                        RTS

APSO_PRINT_OBJECT_ROW:
                        LDX             #<APSO_MSG_ROW
                        LDY             #>APSO_MSG_ROW
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        JSR             APSW_WRITE_HEX_BYTE
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        JSR             APSW_WRITE_HEX_BYTE
                        LDX             #<APSO_MSG_OBJECT_GEN
                        LDY             #>APSO_MSG_OBJECT_GEN
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        JSR             APSW_WRITE_HEX_BYTE
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        JSR             APSW_WRITE_HEX_BYTE
                        LDX             #<APSO_MSG_LENGTH
                        LDY             #>APSO_MSG_LENGTH
                        JSR             APSW_WRITE_CSTRING
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        JSR             APSW_WRITE_HEX_BYTE
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        JSR             APSW_WRITE_HEX_BYTE
                        JMP             APSW_WRITE_CRLF

APSO_CHECK_SPACE:
                        LDA             APSO_RECORD_OFF_LO
                        CLC
                        ADC             #APS_RECORD_HEADER_BYTES+APS_RECORD_TRAILER_BYTES
                        STA             APSO_COUNT_LO
                        LDA             APSO_RECORD_OFF_HI
                        ADC             #$00
                        STA             APSO_COUNT_HI
                        LDA             APSO_COUNT_LO
                        CLC
                        ADC             APSO_PACKAGE_LEN_LO
                        STA             APSO_COUNT_LO
                        LDA             APSO_COUNT_HI
                        ADC             APSO_PACKAGE_LEN_HI
                        CMP             #$10
                        BCS             APSO_NO_SPACE
                        SEC
                        RTS
APSO_NO_SPACE:
                        LDA             #APSO_STATUS_NO_SPACE
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_POLICY
                        STA             APSO_FAIL_PHASE
                        CLC
                        RTS

APSO_BUILD_RECORD_HEADER:
                        LDA             #$FF
                        LDX             #APS_RECORD_HEADER_BYTES-1
APSO_BUILD_RECORD_FILL:
                        STA             APSO_RECORD_HEADER_BASE,X
                        DEX
                        BPL             APSO_BUILD_RECORD_FILL
                        LDA             #APS_RECORD_SIG0
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_SIG
                        LDA             #APS_RECORD_SIG1
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_SIG+1
                        LDA             #APS_RECORD_VERSION
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_VERSION
                        LDA             #APS_RECORD_CHUNK
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_TYPE
                        LDA             #(APS_RECORD_FLAG_FIRST+APS_RECORD_FLAG_LAST)
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_FLAGS
                        LDA             APSO_OBJECT_LO
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT
                        LDA             APSO_OBJECT_HI
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_OBJECT+1
                        LDA             APSO_OBJECT_GEN_LO
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION
                        LDA             APSO_OBJECT_GEN_HI
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_GENERATION+1
                        STZ             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL
                        STZ             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LOGICAL+1
                        LDA             APSO_PACKAGE_LEN_LO
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        LDA             APSO_PACKAGE_LEN_HI
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        LDX             #$03
APSO_BUILD_RECORD_FNV:
                        LDA             APSO_PACKAGE_FNV0,X
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_FNV,X
                        DEX
                        BPL             APSO_BUILD_RECORD_FNV
                        LDA             #$FF
                        STA             APSW_CRC_LO
                        STA             APSW_CRC_HI
                        LDY             #$00
APSO_BUILD_RECORD_CRC:
                        LDA             APSO_RECORD_HEADER_BASE,Y
                        JSR             APSW_CRC16_BYTE
                        INY
                        CPY             #APS_RH_OFF_CRC16
                        BNE             APSO_BUILD_RECORD_CRC
                        LDA             APSW_CRC_LO
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_CRC16
                        LDA             APSW_CRC_HI
                        STA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_CRC16+1
                        RTS

APSO_SAVE_PREPARED:
                        LDA             APSW_BANK
                        STA             APSO_PREP_BANK
                        LDA             APSW_SECTOR
                        STA             APSO_PREP_SECTOR
                        LDX             #$03
APSO_SAVE_PREP_OBJECT:
                        LDA             APSO_OBJECT_LO,X
                        STA             APSO_PREP_OBJECT_LO,X
                        DEX
                        BPL             APSO_SAVE_PREP_OBJECT
                        LDA             APSO_RECORD_OFF_LO
                        STA             APSO_PREP_RECORD_OFF_LO
                        LDA             APSO_RECORD_OFF_HI
                        STA             APSO_PREP_RECORD_OFF_HI
                        LDA             APSO_PACKAGE_LEN_LO
                        STA             APSO_PREP_PACKAGE_LEN_LO
                        LDA             APSO_PACKAGE_LEN_HI
                        STA             APSO_PREP_PACKAGE_LEN_HI
                        LDX             #$03
APSO_SAVE_PREP_FNV:
                        LDA             APSO_PACKAGE_FNV0,X
                        STA             APSO_PREP_PACKAGE_FNV0,X
                        DEX
                        BPL             APSO_SAVE_PREP_FNV
                        LDA             APSO_MEDIA_CRC_LO
                        STA             APSO_PREP_MEDIA_CRC_LO
                        LDA             APSO_MEDIA_CRC_HI
                        STA             APSO_PREP_MEDIA_CRC_HI
                        RTS

APSO_COMPARE_REQUEST:
                        LDA             APSW_BANK
                        CMP             APSO_PREP_BANK
                        BNE             APSO_COMPARE_BAD
                        LDA             APSW_SECTOR
                        CMP             APSO_PREP_SECTOR
                        BNE             APSO_COMPARE_BAD
                        LDX             #$03
APSO_COMPARE_REQUEST_LOOP:
                        LDA             APSO_OBJECT_LO,X
                        CMP             APSO_PREP_OBJECT_LO,X
                        BNE             APSO_COMPARE_BAD
                        DEX
                        BPL             APSO_COMPARE_REQUEST_LOOP
                        SEC
                        RTS
APSO_COMPARE_BAD:
                        CLC
                        RTS

APSO_COMPARE_SOURCE:
                        LDA             APSO_PACKAGE_LEN_LO
                        CMP             APSO_PREP_PACKAGE_LEN_LO
                        BNE             APSO_COMPARE_BAD
                        LDA             APSO_PACKAGE_LEN_HI
                        CMP             APSO_PREP_PACKAGE_LEN_HI
                        BNE             APSO_COMPARE_BAD
                        LDX             #$03
APSO_COMPARE_SOURCE_LOOP:
                        LDA             APSO_PACKAGE_FNV0,X
                        CMP             APSO_PREP_PACKAGE_FNV0,X
                        BNE             APSO_COMPARE_BAD
                        DEX
                        BPL             APSO_COMPARE_SOURCE_LOOP
                        SEC
                        RTS

APSO_COMPARE_MEDIA:
                        LDA             APSO_RECORD_OFF_LO
                        CMP             APSO_PREP_RECORD_OFF_LO
                        BNE             APSO_COMPARE_BAD
                        LDA             APSO_RECORD_OFF_HI
                        CMP             APSO_PREP_RECORD_OFF_HI
                        BNE             APSO_COMPARE_BAD
                        LDA             APSO_MEDIA_CRC_LO
                        CMP             APSO_PREP_MEDIA_CRC_LO
                        BNE             APSO_COMPARE_BAD
                        LDA             APSO_MEDIA_CRC_HI
                        CMP             APSO_PREP_MEDIA_CRC_HI
                        BNE             APSO_COMPARE_BAD
                        SEC
                        RTS

APSO_PROGRAM_RECORD:
                        PHP
                        SEI
                        LDA             APSW_BANK
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSO_PROGRAM_RESTORE_ERROR
                        LDA             APSO_RECORD_OFF_LO
                        STA             APSW_PTR_LO
                        LDA             APSW_SECTOR
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             APSO_RECORD_OFF_HI
                        STA             APSW_PTR_HI
                        LDA             #<APSO_RECORD_HEADER_BASE
                        STA             APSO_SRC_TMP_LO
                        LDA             #>APSO_RECORD_HEADER_BASE
                        STA             APSO_SRC_TMP_HI
                        LDA             #APS_RECORD_HEADER_BYTES
                        STA             APSO_COUNT_LO
                        STZ             APSO_COUNT_HI
                        LDA             #APSO_PHASE_HEADER
                        STA             APSO_FAIL_PHASE
                        JSR             APSO_PROGRAM_BYTES
                        BCC             APSO_PROGRAM_FAILED
                        LDA             APSO_SOURCE_LO
                        STA             APSO_SRC_TMP_LO
                        LDA             APSO_SOURCE_HI
                        STA             APSO_SRC_TMP_HI
                        LDA             APSO_PACKAGE_LEN_LO
                        STA             APSO_COUNT_LO
                        LDA             APSO_PACKAGE_LEN_HI
                        STA             APSO_COUNT_HI
                        LDA             #APSO_PHASE_PAYLOAD
                        STA             APSO_FAIL_PHASE
                        JSR             APSO_PROGRAM_BYTES
                        BCC             APSO_PROGRAM_FAILED
                        LDA             #APSO_PHASE_COMMIT
                        STA             APSO_FAIL_PHASE
                        LDA             #APS_RECORD_COMMIT
                        LDY             #$00
                        JSR             APSW_FLASH_WRITE_BYTE
                        BCC             APSO_PROGRAM_FAILED
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSO_PROGRAM_RESTORE_FAIL
                        PLP
                        SEC
                        RTS
APSO_PROGRAM_FAILED:
                        LDA             #APSO_STATUS_PROGRAM_FAILED
                        STA             APSO_STATUS
                        BRA             APSO_PROGRAM_RESTORE_ERROR
APSO_PROGRAM_RESTORE_ERROR:
                        LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             APSO_PROGRAM_RESTORE_FAIL
                        PLP
                        CLC
                        RTS
APSO_PROGRAM_RESTORE_FAIL:
                        JSR             APSW_FORCE_BANK3
                        LDA             #APSO_STATUS_RESTORE_FAILED
                        STA             APSO_STATUS
                        LDA             #APSO_PHASE_RESTORE
                        STA             APSO_FAIL_PHASE
                        PLP
                        CLC
                        RTS

APSO_PROGRAM_BYTES:
                        LDA             APSO_COUNT_LO
                        ORA             APSO_COUNT_HI
                        BEQ             APSO_PROGRAM_BYTES_DONE
                        LDY             #$00
                        LDA             (APSO_SRC_TMP_LO),Y
                        JSR             APSW_FLASH_WRITE_BYTE
                        BCC             APSO_PROGRAM_BYTES_FAIL
                        JSR             APSO_INC_PTR
                        INC             APSO_SRC_TMP_LO
                        BNE             APSO_PROGRAM_SOURCE_OK
                        INC             APSO_SRC_TMP_HI
APSO_PROGRAM_SOURCE_OK:
                        JSR             APSO_DEC_COUNT
                        BRA             APSO_PROGRAM_BYTES
APSO_PROGRAM_BYTES_DONE:
                        SEC
                        RTS
APSO_PROGRAM_BYTES_FAIL:
                        CLC
                        RTS

APSO_FIND_AND_RECONSTRUCT:
                        JSR             APSO_STAGE_AND_INSPECT
                        BCC             APSO_FIND_RETURN
                        LDA             APSW_CLASS
                        CMP             #APSW_CLASS_ACTIVE
                        BEQ             APSO_RECONSTRUCT_MANAGED
                        JMP             APSO_NOT_MANAGED
APSO_RECONSTRUCT_MANAGED:
                        LDA             #APSO_SCAN_FIND
                        STA             APSO_SCAN_MODE
                        JSR             APSO_SCAN_LOG
                        BCC             APSO_FIND_RETURN
                        JSR             APSO_PTR_FROM_RECORD_OFFSET
                        JSR             APSO_PTR_ADD_RECORD_HEADER
                        LDA             #<APSO_PACKAGE_BUFFER
                        STA             APSO_SRC_TMP_LO
                        LDA             #>APSO_PACKAGE_BUFFER
                        STA             APSO_SRC_TMP_HI
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH
                        STA             APSO_COUNT_LO
                        STA             APSO_PACKAGE_LEN_LO
                        LDA             APSO_RECORD_HEADER_BASE+APS_RH_OFF_LENGTH+1
                        STA             APSO_COUNT_HI
                        STA             APSO_PACKAGE_LEN_HI
APSO_RECONSTRUCT_LOOP:
                        LDA             APSO_COUNT_LO
                        ORA             APSO_COUNT_HI
                        BEQ             APSO_RECONSTRUCT_DONE
                        LDY             #$00
                        LDA             (APSW_PTR_LO),Y
                        STA             (APSO_SRC_TMP_LO),Y
                        JSR             APSO_INC_PTR
                        INC             APSO_SRC_TMP_LO
                        BNE             APSO_RECONSTRUCT_DST_OK
                        INC             APSO_SRC_TMP_HI
APSO_RECONSTRUCT_DST_OK:
                        JSR             APSO_DEC_COUNT
                        BRA             APSO_RECONSTRUCT_LOOP
APSO_RECONSTRUCT_DONE:
                        SEC
APSO_FIND_RETURN:
                        RTS

APSO_INC_PTR:
                        INC             APSW_PTR_LO
                        BNE             APSO_INC_PTR_DONE
                        INC             APSW_PTR_HI
APSO_INC_PTR_DONE:
                        RTS

APSO_DEC_COUNT:
                        LDA             APSO_COUNT_LO
                        BNE             APSO_DEC_COUNT_LO
                        DEC             APSO_COUNT_HI
APSO_DEC_COUNT_LO:
                        DEC             APSO_COUNT_LO
                        RTS
                        ENDIF

                        DATA

                        IF              APSO_OBJECT_BUILD
APSO_MSG_ROW:           DB              "APOBJ O=",0
APSO_MSG_OBJECT_GEN:    DB              " G=",0
APSO_MSG_LENGTH:        DB              " L=",0
APSO_MSG_LIST_OK:       DB              "APOBJ OK",0
                        ELSE
APSW_MSG_PREFIX:        DB              "APSTORE B/S=",0
APSW_MSG_GENERATION:    DB              " G=",0
APSW_MSG_OK:            DB              "APSTORE OK",0
APSW_MSG_ERROR:         DB              "APSTORE ERR $",0
APSW_MSG_PHASE:         DB              " P$",0
APSW_TEXT_HEADER_FF:    DB              "HEADER-FF",0
APSW_TEXT_OPAQUE:       DB              "OPAQUE",0
APSW_TEXT_CORRUPT:      DB              "CORRUPT",0
APSW_TEXT_STAGED:       DB              "STAGED",0
APSW_TEXT_ACTIVE:       DB              "ACTIVE",0
APSW_TEXT_RETIRED:      DB              "RETIRED",0
APSW_TEXT_BAD:          DB              "BAD",0
APSW_TEXT_RETIRED_BAD:  DB              "RETIRED+BAD",0
APSW_CLASS_TEXT_LO:     DB              <APSW_TEXT_HEADER_FF,<APSW_TEXT_OPAQUE
                        DB              <APSW_TEXT_CORRUPT,<APSW_TEXT_STAGED
                        DB              <APSW_TEXT_ACTIVE,<APSW_TEXT_RETIRED
                        DB              <APSW_TEXT_BAD,<APSW_TEXT_RETIRED_BAD
APSW_CLASS_TEXT_HI:     DB              >APSW_TEXT_HEADER_FF,>APSW_TEXT_OPAQUE
                        DB              >APSW_TEXT_CORRUPT,>APSW_TEXT_STAGED
                        DB              >APSW_TEXT_ACTIVE,>APSW_TEXT_RETIRED
                        DB              >APSW_TEXT_BAD,>APSW_TEXT_RETIRED_BAD
                        ENDIF

                        ENDIF

                        ENDMOD
                        END

; ----------------------------------------------------------------------------
; AP Store V1 transient single-sector CLAIM/CONVERT/FORMAT worker.
;
; Load at $7000.  Inventory enters at $7000.  For mutation, configure the
; request card at $7C00, call PREPARE ($7003), inspect the result/CRC, set
; $7C03=$A5, then call EXECUTE ($7006).
; This foreground tool is terminal for an ASM session and is mutually
; exclusive with the $7000 ASM session reporter.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          AP_STORE_V1_SECTOR_TOOL

                        XDEF            START
                        XDEF            APSW_INVENTORY
                        XDEF            APSW_PREPARE
                        XDEF            APSW_EXECUTE

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

APSW_SVC_WRITE_BYTE     EQU             ASM_ABI_SVC_FIRST_VECTOR+$02
APSW_SVC_WRITE_CSTRING  EQU             ASM_ABI_SVC_FIRST_VECTOR+$04
APSW_SVC_WRITE_HEX_BYTE EQU             ASM_ABI_SVC_FIRST_VECTOR+$06
APSW_SVC_WRITE_CRLF     EQU             ASM_ABI_SVC_FIRST_VECTOR+$08

APSW_FLASH_UNLOCK1      EQU             $D555
APSW_FLASH_UNLOCK2      EQU             $AAAA
APSW_ERASE_TIMEOUT_HI   EQU             $08
APSW_WRITE_TIMEOUT_HI   EQU             $02

                        CODE

START:
APSW_INVENTORY:
                        JMP             APSW_INVENTORY_BODY
                        JMP             APSW_PREPARE
                        JMP             APSW_EXECUTE

; APSTORE's AP v2 export enters here.  Each full-sector scan restores Bank 3
; before the row is printed.  The loop visits exactly B0:8 through B2:F and
; has no path to the flash mutation routines.
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

; A valid selector request is expected to succeed. If it reports failure,
; force the published Bank-3 latch pattern from RAM before returning an error.
APSW_FORCE_BANK3:
                        LDA             #STR8_BANK_STATE_MASK
                        TRB             STR8_BANK_STATE_BYTE
                        LDA             #STR8_BANK_STATE_MASK
                        TSB             STR8_BANK_STATE_BYTE
                        RTS

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

                        DATA

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

                        ENDMOD
                        END

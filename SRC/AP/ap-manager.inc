; Discover the APMAN carrier at a sector base in Banks 2, 1, then 0. Every
; candidate is fully parsed before its four-byte body identity is inspected.
; The command page is shadowed at $1A00 before loading because the manager may
; use the complete $6C00-$7BFF tool tray. Direct `AP pkg dst` remains the
; recovery route when no installed manager can be found.
HIM_APMAN_BOOTSTRAP:
; Reject unstable INSTALL input before command-shadow/selector/staging writes.
; PARSE then checks the complete envelope span in ordinary RAM or B3 flash.
                        LDA             APMAN_MODE
                        CMP             #APMAN_MODE_INSTALL
                        BNE             HIM_APMAN_BEGIN
                        LDA             APMAN_INSTALL_SRC_LO
                        STA             HIM_AP_SRC_LO
                        LDA             APMAN_INSTALL_SRC_HI
                        STA             HIM_AP_SRC_HI
                        CMP             #HIM_AP_RAM_BASE_HI
                        BCC             HIM_APMAN_SOURCE_BAD
                        JSR             HIM_AP_PARSE_MIN
                        BCS             HIM_APMAN_BEGIN
HIM_APMAN_SOURCE_BAD:
                        LDA             #APMAN_STATUS_BAD_RANGE
                        STA             APMAN_STATUS
                        STA             HIM_AP_STATUS
                        INCLUDE         "HIMON/himon-ap-manager-source-error.inc"
                        LDA             APMAN_STATUS
                        CLC
                        RTS
HIM_APMAN_BEGIN:
                        LDA             STR8_CONFIG_FNV_POLICY
                        LDX             FNV_REQUEST_BANKS
                        JSR             FNV_SCOPE_POLICY
                        LDA             FNV_ALLOWED_BANKS
                        BNE             HIM_APMAN_POLICY_OK
                        JMP             HIM_APMAN_NOT_FOUND
HIM_APMAN_POLICY_OK:
                        STZ             HIM_ASM_SESSION_RESUME
                        INCLUDE         "HIMON/himon-ap-manager-shadow.inc"
                        LDA             #$02
                        STA             CMD_IO_TMP
?BANK:                  LDX             CMD_IO_TMP
                        LDA             HIM_FNV_BANK_BITS,X
                        AND             FNV_ALLOWED_BANKS
                        BEQ             ?NEXT_BANK
                        LDA             #$80
                        STA             CMDP_START_HI
?SECTOR:                LDA             CMDP_START_HI
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        STA             CMDP_ADDR_LO
                        LDA             CMD_IO_TMP
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             CMDP_ADDR_LO
                        CMP             $FFF0
                        BEQ             ?NEXT
                        CMP             $FFF1
                        BEQ             ?NEXT
                        STZ             CMDP_START_LO
                        JSR             HIM_AP_STAGE_BANK_SOURCE
                        BCC             ?NEXT
                        LDA             #HIM_AP_OP_PARSE
                        STA             HIM_AP_OP
                        JSR             HIM_AP_SERVICE
                        BCC             ?NEXT
                        LDA             HIM_AP_BODY_LEN_HI
                        CMP             #$10
                        BCC             ?SIZE_OK
                        BNE             ?NEXT
                        LDA             HIM_AP_BODY_LEN_LO
                        BNE             ?NEXT
?SIZE_OK:               JSR             HIM_AP_IS_MANAGER
                        BCC             ?NEXT
                        STZ             HIM_AP_DST_LO
                        LDA             #>APMAN_ENTRY
                        STA             HIM_AP_DST_HI
                        LDA             #HIM_AP_OP_LOAD
                        STA             HIM_AP_OP
                        JSR             HIM_AP_SERVICE
                        BCC             ?NEXT
                        JMP             APMAN_ENTRY
?NEXT:                  LDA             CMDP_START_HI
                        CLC
                        ADC             #$10
                        STA             CMDP_START_HI
                        BNE             ?SECTOR
?NEXT_BANK:
                        DEC             CMD_IO_TMP
                        BPL             ?BANK
HIM_APMAN_NOT_FOUND:
                        INCLUDE         "HIMON/himon-ap-manager-missing.inc"
                        LDA             #APMAN_STATUS_NO_MANAGER
                        STA             APMAN_STATUS
                        STA             HIM_AP_STATUS
                        CLC
                        RTS

; Shared manager identity check after PARSE; never read beyond a short BODY.
HIM_AP_IS_MANAGER:
                        LDA             HIM_AP_BODY_LEN_HI
                        BNE             HIM_AP_MANAGER_ID_BODY
                        LDA             HIM_AP_BODY_LEN_LO
                        CMP             #$06
                        BCC             HIM_AP_MANAGER_ID_FAIL
HIM_AP_MANAGER_ID_BODY:
                        LDA             HIM_AP_BODY_LO
                        STA             CMDP_PTR_LO
                        LDA             HIM_AP_BODY_HI
                        STA             CMDP_PTR_HI
                        LDY             #$05
?BYTE:                  LDA             (CMDP_PTR_LO),Y
                        CMP             HIM_AP_MANAGER_ID-2,Y
                        BNE             HIM_AP_MANAGER_ID_FAIL
                        DEY
                        CPY             #$01
                        BNE             ?BYTE
                        SEC
                        RTS
HIM_AP_MANAGER_ID_FAIL: CLC
                        RTS

HIM_AP_MANAGER_ID:      DB              'A','M','0','3'

HIM_AP_STAGE_BANK_SOURCE:
                        LDA             CMDP_START_HI
                        CMP             #$80
                        BCC             HIM_AP_STAGE_BANK_BAD
                        LDA             CMD_IO_TMP
                        CMP             #$03
                        BCS             HIM_AP_STAGE_BANK_BAD
; $F010 may return only to RAM after selecting another bank. Copy this small
; read-only caller above its $0200-$0290 trampoline before making the call.
                        LDX             #HIM_AP_BANK_STAGE_CODE_SIZE-1
?COPY_RAM:             LDA             HIM_AP_BANK_STAGE_CODE,X
                        STA             HIM_AP_BANK_STAGE_RAM,X
                        DEX
                        BPL             ?COPY_RAM
                        JSR             HIM_AP_BANK_STAGE_RAM
                        BCC             HIM_AP_STAGE_BANK_BAD
                        LDA             CMDP_START_LO
                        STA             HIM_AP_SRC_LO
                        LDA             CMDP_START_HI
                        AND             #$0F
                        CLC
                        ADC             #AP_STAGE_BUF_HI
                        STA             HIM_AP_SRC_HI
                        SEC
                        RTS
HIM_AP_STAGE_BANK_BAD:
                        JMP             HIM_AP_BAD_RANGE

; Relocatable RAM body. Relative branches remain valid after the copy; the
; only absolute calls are the published $F010 bootstrap and $0203 trampoline.
; Bank 3 is restored before every return to the flash-resident HIMON caller.
HIM_AP_BANK_STAGE_CODE:
                        PHP
                        SEI
                        LDA             CMD_IO_TMP
                        JSR             STR8_BANK_SELECT_SERVICE
                        BCC             ?SELECT_FAIL
                        STZ             HIM_AP_STAGE_SRC_LO
                        LDA             CMDP_START_HI
                        AND             #$F0
                        STA             HIM_AP_STAGE_SRC_HI
                        STZ             HIM_AP_STAGE_DST_LO
                        LDA             #AP_STAGE_BUF_HI
                        STA             HIM_AP_STAGE_DST_HI
                        LDX             #$10
?PAGE:                 LDY             #$00
?BYTE:                 LDA             (HIM_AP_STAGE_SRC_LO),Y
                        STA             (HIM_AP_STAGE_DST_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             HIM_AP_STAGE_SRC_HI
                        INC             HIM_AP_STAGE_DST_HI
                        DEX
                        BNE             ?PAGE
?RESTORE:              LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             ?RESTORE
                        PLP
                        SEC
                        RTS
?SELECT_FAIL:          PLP
                        CLC
                        RTS
HIM_AP_BANK_STAGE_CODE_END:
HIM_AP_BANK_STAGE_CODE_SIZE EQU          HIM_AP_BANK_STAGE_CODE_END-HIM_AP_BANK_STAGE_CODE

; Relocatable AP Store header reader. It copies exactly 16 bytes from one
; selected sector boundary into the High Tool Overlay, then restores Bank 3.
; The body performs no bank-window writes.
                        IF              0
HIM_APS_HEADER_READ_CODE:
                        PHP
                        SEI
                        LDA             HIM_APS_BANK
                        JSR             STR8_BANK_SELECT_SERVICE
                        BCC             ?SELECT_FAIL
                        STZ             HIM_AP_STAGE_SRC_LO
                        LDA             HIM_APS_SECTOR_HI
                        STA             HIM_AP_STAGE_SRC_HI
                        STZ             HIM_AP_STAGE_DST_LO
                        LDA             #>HIM_APS_HEADER_BASE
                        STA             HIM_AP_STAGE_DST_HI
                        LDX             #APS_SECTOR_HEADER_BYTES
                        LDY             #$00
?BYTE:                 LDA             (HIM_AP_STAGE_SRC_LO),Y
                        STA             (HIM_AP_STAGE_DST_LO),Y
                        INY
                        DEX
                        BNE             ?BYTE
?RESTORE:              LDA             #$03
                        JSR             STR8_BANK_SELECT_RAM
                        BCC             ?RESTORE
                        PLP
                        SEC
                        RTS
?SELECT_FAIL:          PLP
                        CLC
                        RTS
HIM_APS_HEADER_READ_CODE_END:
HIM_APS_HEADER_READ_CODE_SIZE EQU       HIM_APS_HEADER_READ_CODE_END-HIM_APS_HEADER_READ_CODE
                        ENDIF

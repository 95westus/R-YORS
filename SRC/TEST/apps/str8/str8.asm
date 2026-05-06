; ----------------------------------------------------------------------------
; str8.asm
; STR8 V0 simulation/proof stub.
; - F800 build is print-only.
; - RAM proof build enables bank select, blank check, backup copy, and marker writes.
; - F800 B/0/1/2 only print copy plans.
; - Uses BIO byte I/O directly; no SYS layer, no FNV/catalog path.
; ----------------------------------------------------------------------------

                        MODULE          STR8_APP

                        XDEF            START

                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        IF              STR8_RAM_PROOF
                        XREF            FLSH_BANK_SELECT_A
                        XREF            FLSH_BANK_SELECT_3
                        XREF            FLSH_WINDOW_ERASED_AX
                        XREF            FLASH_SECTOR_ERASE_RAW_XY
                        XREF            FLASH_WRITE_BYTE_RAW_AXY
                        ENDIF

STR8_PROT_START_HI      EQU             $F8
STR8_PTR_LO             EQU             $CD
STR8_PTR_HI             EQU             $CE
STR8_COPY_PTR_LO        EQU             $CF
STR8_COPY_PTR_HI        EQU             $D0
STR8_MARK_BANK          EQU             $0310
STR8_MARK_SECTOR_HI     EQU             $0311
STR8_MARK_ADDR_LO       EQU             $0312
STR8_MARK_ADDR_HI       EQU             $0313
STR8_MARK_MODE          EQU             $0314
STR8_SELECTED_BANK      EQU             $0315
STR8_COPY_BUF_LO        EQU             $0316
STR8_COPY_BUF_HI        EQU             $0317
STR8_COPY_SRC_BANK      EQU             $0318
STR8_COPY_DST_BANK      EQU             $0319
STR8_SECTOR_BUF_HI      EQU             $40
STR8_SECTOR_BUF_END_HI  EQU             $50

                        CODE
START:
                        JSR             STR8_INIT
                        JSR             STR8_PRINT_SCREEN
                        JMP             STR8_CMD_LOOP

; ----------------------------------------------------------------------------
; STR8 lifecycle
; ----------------------------------------------------------------------------
STR8_INIT:
                        IF              STR8_RAM_PROOF
                        LDA             #$03
                        STA             STR8_SELECTED_BANK
                        ENDIF
                        RTS

STR8_PRINT_SCREEN:
                        LDX             #<MSG_SCREEN
                        LDY             #>MSG_SCREEN
                        JMP             STR8_PRINT_XY

STR8_CMD_LOOP:
                        JSR             STR8_PRINT_PROMPT
                        JSR             STR8_READ_COMMAND
                        JSR             STR8_DISPATCH_A
                        BRA             STR8_CMD_LOOP

STR8_READ_COMMAND:
                        JSR             STR8_READ_BYTE
                        CMP             #$0D
                        BEQ             STR8_READ_COMMAND
                        CMP             #$0A
                        BEQ             STR8_READ_COMMAND
                        RTS

; ----------------------------------------------------------------------------
; Command dispatch
; ----------------------------------------------------------------------------
STR8_DISPATCH_A:
                        CMP             #'0'
                        BEQ             STR8_CMD_RESTORE_0
                        CMP             #'1'
                        BEQ             STR8_CMD_RESTORE_1
                        CMP             #'2'
                        BEQ             STR8_CMD_RESTORE_2
                        CMP             #'?'
                        BNE             ?NOT_ID
                        JMP             STR8_CMD_ID
?NOT_ID:

                        AND             #$DF
                        CMP             #'B'
                        BEQ             STR8_CMD_BACKUP
                        CMP             #'G'
                        BEQ             STR8_CMD_G_HIMON
                        IF              STR8_RAM_PROOF
                        CMP             #'C'
                        BNE             ?NOT_CHECK
                        JMP             STR8_CMD_WINDOW_CHECK
?NOT_CHECK:
                        CMP             #'L'
                        BNE             ?NOT_LIVE_BACKUP
                        JMP             STR8_CMD_COPY_B3_TO_B2
?NOT_LIVE_BACKUP:
                        CMP             #'M'
                        BNE             ?NOT_MARK
                        JMP             STR8_CMD_MARK_BANKS
?NOT_MARK:
                        ENDIF
                        CMP             #'R'
                        BEQ             STR8_CMD_RESET_STUB
                        IF              STR8_RAM_PROOF
                        CMP             #'S'
                        BEQ             STR8_CMD_SELECT_BANK
                        ENDIF
                        CMP             #'V'
                        BEQ             STR8_CMD_VERIFY_STUB
                        JMP             STR8_CMD_UNKNOWN

STR8_CMD_BACKUP:
                        IF              STR8_RAM_PROOF
                        JMP             STR8_CMD_COPY_B2_TO_B1
                        ELSE
                        JSR             STR8_PRINT_BACKUP_PLAN
                        RTS
                        ENDIF

STR8_CMD_RESTORE_0:
                        LDX             #<MSG_RESTORE_0
                        LDY             #>MSG_RESTORE_0
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_RESTORE_1:
                        LDX             #<MSG_RESTORE_1
                        LDY             #>MSG_RESTORE_1
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_RESTORE_2:
                        LDX             #<MSG_RESTORE_2
                        LDY             #>MSG_RESTORE_2
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_G_HIMON:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        LDX             #<MSG_G_HIMON
                        LDY             #>MSG_G_HIMON
                        JSR             STR8_PRINT_XY
                        RTS

STR8_CMD_RESET_STUB:
                        LDX             #<MSG_RESET_STUB
                        LDY             #>MSG_RESET_STUB
                        JMP             STR8_PRINT_XY

STR8_CMD_VERIFY_STUB:
                        LDX             #<MSG_VERIFY_STUB
                        LDY             #>MSG_VERIFY_STUB
                        JMP             STR8_PRINT_XY

                        IF              STR8_RAM_PROOF
STR8_CMD_SELECT_BANK:
                        LDX             #<MSG_BANK_PROMPT
                        LDY             #>MSG_BANK_PROMPT
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        CMP             #'0'
                        BCC             ?BAD
                        CMP             #'4'
                        BCS             ?BAD
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        SEC
                        SBC             #'0'
                        STA             STR8_SELECTED_BANK
                        JSR             FLSH_BANK_SELECT_A
                        LDX             #<MSG_BANK_OK
                        LDY             #>MSG_BANK_OK
                        JMP             STR8_PRINT_XY
?BAD:                   LDX             #<MSG_BANK_BAD
                        LDY             #>MSG_BANK_BAD
                        JMP             STR8_PRINT_XY

STR8_CMD_WINDOW_CHECK:
                        LDX             #<MSG_CHECK_BANK
                        LDY             #>MSG_CHECK_BANK
                        JSR             STR8_PRINT_XY
                        LDA             STR8_SELECTED_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_CHECK_WINDOW
                        LDY             #>MSG_CHECK_WINDOW
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        CMP             #'0'
                        BCC             ?BAD
                        CMP             #'8'
                        BCS             ?BAD
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        SEC
                        SBC             #'0'
                        TAX
                        LDA             STR8_SELECTED_BANK
                        JSR             FLSH_WINDOW_ERASED_AX
                        PHP
                        JSR             STR8_SELECT_BANK_3
                        PLP
                        BCS             ?BLANK
                        LDX             #<MSG_NOT_BLANK
                        LDY             #>MSG_NOT_BLANK
                        JMP             STR8_PRINT_XY
?BLANK:                 LDX             #<MSG_BLANK
                        LDY             #>MSG_BLANK
                        JMP             STR8_PRINT_XY
?BAD:                   JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_WINDOW_BAD
                        LDY             #>MSG_WINDOW_BAD
                        JMP             STR8_PRINT_XY

STR8_CMD_COPY_B2_TO_B1:
                        LDA             #$02
                        STA             STR8_COPY_SRC_BANK
                        LDA             #$01
                        STA             STR8_COPY_DST_BANK
                        LDX             #<MSG_COPY_21_WARN
                        LDY             #>MSG_COPY_21_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        AND             #$DF
                        CMP             #'Y'
                        BEQ             ?YES
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JMP             STR8_PRINT_XY
?YES:                   JSR             STR8_COPY_BANKS
                        BCC             ?FAIL
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_COPY_OK
                        LDY             #>MSG_COPY_OK
                        JMP             STR8_PRINT_XY
?FAIL:                  JSR             STR8_SELECT_BANK_3
                        JMP             STR8_PRINT_COPY_FAIL

STR8_CMD_COPY_B3_TO_B2:
                        LDA             #$03
                        STA             STR8_COPY_SRC_BANK
                        LDA             #$02
                        STA             STR8_COPY_DST_BANK
                        LDX             #<MSG_COPY_32_WARN
                        LDY             #>MSG_COPY_32_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        AND             #$DF
                        CMP             #'Y'
                        BEQ             ?YES
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JMP             STR8_PRINT_XY
?YES:                   JSR             STR8_COPY_BANKS
                        BCC             ?FAIL
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_COPY_OK
                        LDY             #>MSG_COPY_OK
                        JMP             STR8_PRINT_XY
?FAIL:                  JSR             STR8_SELECT_BANK_3
                        JMP             STR8_PRINT_COPY_FAIL

STR8_CMD_MARK_BANKS:
                        LDA             STR8_SELECTED_BANK
                        CMP             #$03
                        BCS             ?BAD_BANK
                        LDX             #<MSG_MARK_BANK
                        LDY             #>MSG_MARK_BANK
                        JSR             STR8_PRINT_XY
                        LDA             STR8_SELECTED_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_MARK_MODE
                        LDY             #>MSG_MARK_MODE
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        CMP             #'1'
                        BEQ             ?HEAD
                        CMP             #'4'
                        BEQ             ?FULL
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_MARK_BAD
                        LDY             #>MSG_MARK_BAD
                        JMP             STR8_PRINT_XY
?HEAD:                  STZ             STR8_MARK_MODE
                        LDX             #<MSG_MARK_HEAD_WARN
                        LDY             #>MSG_MARK_HEAD_WARN
                        BRA             ?CONFIRM
?FULL:                  LDA             #$01
                        STA             STR8_MARK_MODE
                        LDX             #<MSG_MARK_FULL_WARN
                        LDY             #>MSG_MARK_FULL_WARN
?CONFIRM:               JSR             STR8_PRINT_XY
                        JSR             STR8_READ_COMMAND
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        AND             #$DF
                        CMP             #'Y'
                        BEQ             ?YES
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JMP             STR8_PRINT_XY
?YES:                   LDA             STR8_MARK_MODE
                        BEQ             ?DO_HEAD
                        JSR             STR8_MARK_BANK_FULL
                        BRA             ?DONE
?DO_HEAD:               JSR             STR8_MARK_BANK_HEADS
?DONE:
                        BCC             ?FAIL
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_MARK_OK
                        LDY             #>MSG_MARK_OK
                        JMP             STR8_PRINT_XY
?FAIL:                  JSR             STR8_SELECT_BANK_3
                        JMP             STR8_PRINT_MARK_FAIL
?BAD_BANK:              LDX             #<MSG_MARK_BANK_BAD
                        LDY             #>MSG_MARK_BANK_BAD
                        JMP             STR8_PRINT_XY
                        ENDIF

STR8_CMD_ID:
                        LDX             #<MSG_ID
                        LDY             #>MSG_ID
                        JMP             STR8_PRINT_XY

STR8_CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JMP             STR8_PRINT_XY

; ----------------------------------------------------------------------------
; Simulation plan printers
; ----------------------------------------------------------------------------
STR8_PRINT_BACKUP_PLAN:
                        LDX             #<MSG_BACKUP_0
                        LDY             #>MSG_BACKUP_0
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_HOLD_B0
                        LDY             #>MSG_HOLD_B0
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_COPY_21
                        LDY             #>MSG_COPY_21
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_COPY_32
                        LDY             #>MSG_COPY_32
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_VERIFY_PLAN
                        LDY             #>MSG_VERIFY_PLAN
                        JMP             STR8_PRINT_XY

STR8_PRINT_RESTORE_COMMON:
                        LDX             #<MSG_SKIP_STR8
                        LDY             #>MSG_SKIP_STR8
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_VERIFY_PLAN
                        LDY             #>MSG_VERIFY_PLAN
                        JMP             STR8_PRINT_XY

                        IF              STR8_RAM_PROOF
; ----------------------------------------------------------------------------
; Destructive RAM-only marker proof
; ----------------------------------------------------------------------------
STR8_COPY_BANKS:
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
?SECTOR:               JSR             STR8_STAGE_SRC_SECTOR
                        JSR             STR8_ERASE_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8_PROGRAM_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8_VERIFY_DST_SECTOR
                        BCC             ?FAIL
                        LDA             #'.'
                        JSR             STR8_WRITE_BYTE
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_STAGE_SRC_SECTOR:
                        LDA             STR8_COPY_SRC_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_PTR_HI
?PAGE:                 LDY             #$00
?BYTE:                 LDA             (STR8_PTR_LO),Y
                        STA             (STR8_COPY_PTR_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        LDA             STR8_COPY_PTR_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        RTS

STR8_ERASE_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_MARK_ADDR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_MARK_ADDR_HI
                        LDX             #$00
                        LDY             STR8_MARK_SECTOR_HI
                        JMP             FLASH_SECTOR_ERASE_RAW_XY

STR8_PROGRAM_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_MARK_ADDR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_MARK_ADDR_HI
                        STZ             STR8_COPY_BUF_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_BUF_HI
?BYTE:                 LDA             STR8_COPY_BUF_LO
                        STA             STR8_PTR_LO
                        LDA             STR8_COPY_BUF_HI
                        STA             STR8_PTR_HI
                        LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BEQ             ?NEXT
                        LDX             STR8_MARK_ADDR_LO
                        LDY             STR8_MARK_ADDR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCC             ?FAIL
?NEXT:                 INC             STR8_MARK_ADDR_LO
                        INC             STR8_COPY_BUF_LO
                        BNE             ?BYTE
                        INC             STR8_MARK_ADDR_HI
                        INC             STR8_COPY_BUF_HI
                        LDA             STR8_COPY_BUF_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?BYTE
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_VERIFY_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_PTR_HI
?PAGE:                 LDY             #$00
?BYTE:                 LDA             (STR8_PTR_LO),Y
                        CMP             (STR8_COPY_PTR_LO),Y
                        BNE             ?FAIL
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        LDA             STR8_COPY_PTR_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        SEC
                        RTS
?FAIL:                 TYA
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8_PTR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS

STR8_MARK_BANK_HEADS:
                        LDA             STR8_SELECTED_BANK
                        STA             STR8_MARK_BANK
                        JSR             FLSH_BANK_SELECT_A
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
?SECTOR:               STZ             STR8_MARK_ADDR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_MARK_ADDR_HI
                        LDA             STR8_MARK_BANK
                        LDX             #$00
                        LDY             STR8_MARK_SECTOR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCC             ?FAIL
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_MARK_BANK_FULL:
                        LDA             STR8_SELECTED_BANK
                        STA             STR8_MARK_BANK
                        JSR             FLSH_BANK_SELECT_A
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
?SECTOR:               LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_MARK_ADDR_HI
                        STZ             STR8_MARK_ADDR_LO
?BYTE:                 LDA             STR8_MARK_BANK
                        LDX             STR8_MARK_ADDR_LO
                        LDY             STR8_MARK_ADDR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCC             ?FAIL
                        INC             STR8_MARK_ADDR_LO
                        BNE             ?BYTE
                        INC             STR8_MARK_ADDR_HI
                        LDA             STR8_MARK_ADDR_HI
                        SEC
                        SBC             STR8_MARK_SECTOR_HI
                        CMP             #$10
                        BNE             ?BYTE
                        LDA             #'.'
                        JSR             STR8_WRITE_BYTE
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_SELECT_BANK_3:
                        JSR             FLSH_BANK_SELECT_3
                        LDA             #$03
                        STA             STR8_SELECTED_BANK
                        RTS

STR8_PRINT_COPY_FAIL:
                        LDX             #<MSG_COPY_FAIL_AT
                        LDY             #>MSG_COPY_FAIL_AT
                        JSR             STR8_PRINT_XY
                        LDA             STR8_MARK_ADDR_HI
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDA             STR8_MARK_ADDR_LO
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JMP             STR8_PRINT_XY

STR8_PRINT_MARK_FAIL:
                        LDX             #<MSG_MARK_FAIL_B
                        LDY             #>MSG_MARK_FAIL_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_MARK_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_MARK_FAIL_AT
                        LDY             #>MSG_MARK_FAIL_AT
                        JSR             STR8_PRINT_XY
                        LDA             STR8_MARK_ADDR_HI
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDA             STR8_MARK_ADDR_LO
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JMP             STR8_PRINT_XY

STR8_WRITE_DEC_DIGIT_A:
                        AND             #$0F
                        CLC
                        ADC             #'0'
                        JMP             STR8_WRITE_BYTE

STR8_WRITE_HEX_BYTE_A:
                        PHA
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        JSR             STR8_WRITE_HEX_NIBBLE_A
                        PLA
                        AND             #$0F
STR8_WRITE_HEX_NIBBLE_A:
                        CMP             #$0A
                        BCC             ?DIGIT
                        CLC
                        ADC             #$37
                        JMP             STR8_WRITE_BYTE
?DIGIT:                CLC
                        ADC             #'0'
                        JMP             STR8_WRITE_BYTE
                        RTS
                        ENDIF

; ----------------------------------------------------------------------------
; Tiny I/O
; ----------------------------------------------------------------------------
STR8_PRINT_PROMPT:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JMP             STR8_PRINT_XY

STR8_PRINT_XY:
                        STX             STR8_PTR_LO
                        STY             STR8_PTR_HI
                        LDY             #$00
?LOOP:                  LDA             (STR8_PTR_LO),Y
                        BMI             ?LAST
                        JSR             STR8_WRITE_BYTE
                        INY
                        BNE             ?LOOP
                        INC             STR8_PTR_HI
                        BRA             ?LOOP
?LAST:                  AND             #$7F
                        JMP             STR8_WRITE_BYTE

STR8_READ_BYTE:
                        JMP             BIO_FTDI_READ_BYTE_BLOCK

STR8_WRITE_BYTE:
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

                        DATA
MSG_SCREEN:             DB              $0D,$0A,"STR8 V0",$0D,$0A
                        IF              STR8_RAM_PROOF
                        DB              "RAM $3000 BUF $4000-$5FFF",$0D,$0A
                        DB              "B B2>B1  L B3>B2",$0D,$0A
                        DB              "C CHECK  M MARK",$0D,$0A,$0D,$0A
                        ELSE
                        DB              "B3 OK  STR8 $F800-$FFFF",$0D,$0A,$0D,$0A
                        ENDIF
                        DB              "0 PLAT 1 PREV 2 LAST",$0D,$0A
                        IF              STR8_RAM_PROOF
                        DB              "S BANK  V VER  G HIMON",$0D,$8A
                        ELSE
                        DB              "B BACK V VER  G HIMON",$0D,$8A
                        ENDIF
MSG_PROMPT:             DB              "STR8",('>'+$80)
MSG_BACKUP_0:           DB              $0D,$0A,"B BACK SIM",$0D,$8A
MSG_HOLD_B0:            DB              "B0 FACTORY HOLD",$0D,$8A
MSG_COPY_21:            DB              "COPY B2 -> B1  PLAN",$0D,$8A
MSG_COPY_32:            DB              "COPY B3 -> B2  PLAN",$0D,$8A
MSG_VERIFY_PLAN:        DB              "VERIFY         PLAN",$0D,$8A
MSG_RESTORE_0:          DB              $0D,$0A,"RESTORE B0 -> B3  PLAN",$0D,$8A
MSG_RESTORE_1:          DB              $0D,$0A,"RESTORE B1 -> B3  PLAN",$0D,$8A
MSG_RESTORE_2:          DB              $0D,$0A,"RESTORE B2 -> B3  PLAN",$0D,$8A
MSG_SKIP_STR8:          DB              "SKIP STR8 $F800-$FFFF",$0D,$8A
MSG_G_HIMON:            DB              $0D,$0A,"G HIMON",$0D,$8A
MSG_RESET_STUB:         DB              $0D,$0A,"RESET STUB",$0D,$8A
MSG_VERIFY_STUB:        DB              $0D,$0A,"VERIFY STUB",$0D,$8A
                        IF              STR8_RAM_PROOF
MSG_BANK_PROMPT:        DB              $0D,$0A,"BANK 0-3:",$A0
MSG_BANK_OK:            DB              $0D,$0A,"BANK SELECT OK",$0D,$8A
MSG_BANK_BAD:           DB              $0D,$0A,"BANK? 0-3",$0D,$8A
MSG_COPY_21_WARN:       DB              $0D,$0A,"COPY B2->B1 ERASE B1. TYPE Y:",$A0
MSG_COPY_32_WARN:       DB              $0D,$0A,"COPY B3->B2 ERASE B2. TYPE Y:",$A0
MSG_COPY_OK:            DB              $0D,$0A,"COPY OK",$0D,$8A
MSG_COPY_FAIL_AT:       DB              $0D,$0A,"COPY FAIL @ ",('$'+$80)
MSG_CHECK_BANK:         DB              $0D,$0A,"CHECK ",('B'+$80)
MSG_CHECK_WINDOW:       DB              " W0-7:",$A0
MSG_WINDOW_BAD:         DB              $0D,$0A,"WINDOW? 0-7",$0D,$8A
MSG_BLANK:              DB              $0D,$0A,"BLANK $FF",$0D,$8A
MSG_NOT_BLANK:          DB              $0D,$0A,"NOT BLANK",$0D,$8A
MSG_MARK_BANK:          DB              $0D,$0A,"MARK ",('B'+$80)
MSG_MARK_MODE:          DB              " 1=HEAD 4=4K:",$A0
MSG_MARK_HEAD_WARN:     DB              $0D,$0A,"HEAD BYTE ONLY. TYPE Y:",$A0
MSG_MARK_FULL_WARN:     DB              $0D,$0A,"FULL 4K EACH SECTOR. TYPE Y:",$A0
MSG_MARK_BAD:           DB              $0D,$0A,"MARK? 1/4",$0D,$8A
MSG_MARK_BANK_BAD:      DB              $0D,$0A,"SELECT BANK 0-2 FIRST",$0D,$8A
MSG_ABORT:              DB              $0D,$0A,"ABORT",$0D,$8A
MSG_MARK_OK:            DB              $0D,$0A,"MARK OK",$0D,$8A
MSG_MARK_FAIL_B:        DB              $0D,$0A,"MARK FAIL ",('B'+$80)
MSG_MARK_FAIL_AT:       DB              " @ ",('$'+$80)
MSG_CRLF:               DB              $0D,$8A
                        ENDIF
                        IF              STR8_RAM_PROOF
MSG_ID:                 DB              $0D,$0A,"STR8 V0 RAM $3000",$0D,$8A
                        ELSE
MSG_ID:                 DB              $0D,$0A,"STR8 V0 SIM $F800",$0D,$8A
                        ENDIF
MSG_UNKNOWN:            DB              $0D,$0A,"?",$0D,$8A

                        END

; ----------------------------------------------------------------------------
; str8-worker.asm
; RAM-resident STR8 bank-copy worker.
;
; This image links for $0200, must fit in the $0200-$09FF STR8 RAM worker tray,
; is stored in high flash packed against $FFEF, and is copied to $0200 before
; destructive STR8 bank operations. Keep it independent: once running, it must
; not call ROM code because it switches flash banks and may erase bank 3's top
; sector.
; ----------------------------------------------------------------------------

                        MODULE          STR8_WORKER_APP

                        XDEF            START
                        XDEF            STR8_WORKER_END

; 2026-05-07T22:58-05:00        WLP2        Combined ROM layout moves STR8 to $F000.
; 2026-05-17T21:20-05:00        WLP2        Worker source storage formerly moved to $FC00.
; 2026-05-21T23:55-05:00        WLP2        Worker source is now packed down from $FFEF.
STR8_PROT_START_HI      EQU             $F0
STR8_PROT_BUF_HI        EQU             $40

STR8_COPY_MODE_RESTORE  EQU             $01
STR8_COPY_MODE_ENROLL   EQU             $02
STR8_COPY_MODE_RESTORE_FLASH_HI EQU     $03
STR8_COPY_MODE_PROGRAM_STAGED EQU        $05
STR8_COPY_MODE_STAGE_BANK_SECTOR EQU    $06
STR8_RESTORE_PROT_START_HI EQU          $C0

STR8_CFG_FLAGS_ADDR     EQU             $FFF0
STR8_CFG_FLAGS_LO       EQU             $F0
STR8_CFG_FLAGS_HI       EQU             $FF
STR8_CFG_B0_ROT_MASK    EQU             $01
STR8_RESET_VECTOR       EQU             $FFFC

STR8W_PTR_LO            EQU             $CD
STR8W_PTR_HI            EQU             $CE
STR8W_BUF_LO            EQU             $CF
STR8W_BUF_HI            EQU             $D0
STR8W_ADDR_LO           EQU             $D1
STR8W_ADDR_HI           EQU             $D2
STR8W_DATA              EQU             $D3
STR8W_TMO0              EQU             $D4
STR8W_TMO1              EQU             $D5
STR8W_TMO2              EQU             $D6

STR8_STATE_BASE         EQU             $1FE9
STR8_STATE_END          EQU             $1FFF
STR8_MARK_SECTOR_HI     EQU             $1FE9
STR8_MARK_ADDR_LO       EQU             $1FEA
STR8_MARK_ADDR_HI       EQU             $1FEB
STR8_COPY_SRC_BANK      EQU             $1FEE
STR8_COPY_DST_BANK      EQU             $1FEF
STR8_COPY_MODE          EQU             $1FF0
STR8_STAGE_BUF_HI       EQU             $1FF6

STR8_SECTOR_BUF_HI      EQU             $40
STR8_SECTOR_BUF_END_HI  EQU             $50

STR8_FTDI_VIA_PCR       EQU             $7FEC
STR8_BANK_PCR_MASK      EQU             $EE

STR8_FLASH_UNLOCK1      EQU             $D555
STR8_FLASH_UNLOCK2      EQU             $AAAA
STR8_FLASH_ERASE_TMO_HI EQU             $08
STR8_FLASH_WRITE_TMO_HI EQU             $02

                        CODE
; 2026-05-07T19:14-05:00        WLP2        Restore-high mode resets through bank 3.
START:
                        PHP
                        SEI
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_ENROLL
                        BEQ             ?ENROLL
                        CMP             #STR8_COPY_MODE_PROGRAM_STAGED
                        BEQ             ?PROGRAM_STAGED
                        CMP             #STR8_COPY_MODE_STAGE_BANK_SECTOR
                        BEQ             ?STAGE_BANK_SECTOR
                        JSR             STR8W_COPY_BANKS
                        BRA             ?DONE
?ENROLL:
                        JSR             STR8W_SET_B0_ENROLLED
                        BRA             ?DONE
?PROGRAM_STAGED:
                        JSR             STR8W_PROGRAM_STAGED_SECTOR
                        BRA             ?DONE
?STAGE_BANK_SECTOR:
                        JSR             STR8W_STAGE_BANK_SECTOR
?DONE:
                        BCC             ?FAIL
                        JSR             STR8W_SELECT_BANK3
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE_FLASH_HI
                        BEQ             ?RESET
                        PLP
                        SEC
                        RTS
?RESET:
                        PLP
                        JMP             (STR8_RESET_VECTOR)
?FAIL:
                        JSR             STR8W_SELECT_BANK3
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE_FLASH_HI
                        BEQ             ?TOP_FAIL
                        PLP
                        CLC
                        RTS
?TOP_FAIL:
                        PLP
                        JMP             STR8W_TOP_FAIL_HALT

; 2026-05-07T19:14-05:00        WLP2        Restore skips protected high sectors by mode.
STR8W_COPY_BANKS:
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
?SECTOR:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE
                        BNE             ?COPY_SECTOR
                        LDA             STR8_MARK_SECTOR_HI
                        CMP             #STR8_RESTORE_PROT_START_HI
                        BCS             ?NEXT_SECTOR
?COPY_SECTOR:
                        JSR             STR8W_STAGE_SRC_SECTOR
                        JSR             STR8W_PRESERVE_IF_RESTORE
                        JSR             STR8W_ERASE_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8W_PROGRAM_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8W_VERIFY_DST_SECTOR
                        BCC             ?FAIL
?NEXT_SECTOR:
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8W_SET_B0_ENROLLED:
                        JSR             STR8W_SELECT_BANK3
                        LDA             STR8_CFG_FLAGS_ADDR
                        AND             #($FF-STR8_CFG_B0_ROT_MASK)
                        STA             STR8W_DATA
                        LDA             #STR8_CFG_FLAGS_LO
                        STA             STR8W_ADDR_LO
                        LDA             #STR8_CFG_FLAGS_HI
                        STA             STR8W_ADDR_HI
                        JSR             STR8W_FLASH_WRITE
                        BCC             ?FAIL
                        JSR             STR8W_SELECT_BANK3
                        LDA             STR8_CFG_FLAGS_ADDR
                        AND             #STR8_CFG_B0_ROT_MASK
                        BEQ             ?OK
?FAIL:
                        CLC
                        RTS
?OK:
                        SEC
                        RTS

STR8W_PROGRAM_STAGED_SECTOR:
                        JSR             STR8W_ERASE_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8W_PROGRAM_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8W_VERIFY_DST_SECTOR
                        BCC             ?FAIL
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8W_STAGE_BANK_SECTOR:
                        LDA             STR8_COPY_SRC_BANK
                        JSR             STR8W_BANK_SELECT_A
                        STZ             STR8W_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8W_PTR_HI
                        STZ             STR8W_BUF_LO
                        JSR             STR8W_ACTIVE_BUF_HI
                        STA             STR8W_BUF_HI
                        JMP             STR8W_COPY_PTR_TO_ACTIVE_BUF

STR8W_STAGE_SRC_SECTOR:
                        LDA             STR8_COPY_SRC_BANK
                        JSR             STR8W_BANK_SELECT_A
                        STZ             STR8W_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8W_PTR_HI
                        STZ             STR8W_BUF_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8W_BUF_HI
                        JMP             STR8W_COPY_PTR_TO_BUF

; 2026-05-07T19:14-05:00        WLP2        Restore-high mode bypasses top-sector preserve.
; 2026-05-07T22:58-05:00        WLP2        Worker source now sits inside protected F sector.
STR8W_PRESERVE_IF_RESTORE:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE
                        BEQ             ?RESTORE
                        CMP             #STR8_COPY_MODE_RESTORE_FLASH_HI
                        BNE             ?DONE
?RESTORE:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE_FLASH_HI
                        BEQ             ?DONE
                        LDA             STR8_MARK_SECTOR_HI
                        CMP             #$F0
                        BEQ             ?PRESERVE_STR8
?DONE:
                        RTS
?PRESERVE_STR8:
                        JSR             STR8W_SELECT_BANK3
                        STZ             STR8W_PTR_LO
                        LDA             #STR8_PROT_START_HI
                        STA             STR8W_PTR_HI
                        STZ             STR8W_BUF_LO
                        LDA             #STR8_PROT_BUF_HI
                        STA             STR8W_BUF_HI
                        JMP             STR8W_COPY_PTR_TO_BUF

STR8W_COPY_PTR_TO_BUF:
?PAGE:
                        LDY             #$00
?BYTE:
                        LDA             (STR8W_PTR_LO),Y
                        STA             (STR8W_BUF_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8W_PTR_HI
                        INC             STR8W_BUF_HI
                        LDA             STR8W_BUF_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        RTS

STR8W_COPY_PTR_TO_ACTIVE_BUF:
?PAGE:
                        LDY             #$00
?BYTE:
                        LDA             (STR8W_PTR_LO),Y
                        STA             (STR8W_BUF_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8W_PTR_HI
                        INC             STR8W_BUF_HI
                        JSR             STR8W_ACTIVE_BUF_END_REACHED
                        BNE             ?PAGE
                        RTS

; 2026-05-07T19:14-05:00        WLP2        Skip erased sectors and verify erase completion.
STR8W_ERASE_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             STR8W_BANK_SELECT_A
                        JSR             STR8W_DST_SECTOR_ERASED
                        BCS             ?OK
                        LDA             STR8_MARK_ADDR_LO
                        STA             STR8W_ADDR_LO
                        LDA             STR8_MARK_ADDR_HI
                        STA             STR8W_ADDR_HI
                        JSR             STR8W_FLASH_ERASE
                        BCC             ?FAIL
                        JSR             STR8W_DST_SECTOR_ERASED
                        BCS             ?OK
?FAIL:
                        CLC
                        RTS
?OK:
                        SEC
                        RTS

; OUT: C=1 if the selected destination sector is all $FF.
;      C=0 and STR8_MARK_ADDR_* names the first non-erased byte otherwise.
STR8W_DST_SECTOR_ERASED:
                        STZ             STR8W_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8W_PTR_HI
?PAGE:
                        LDY             #$00
?BYTE:
                        LDA             (STR8W_PTR_LO),Y
                        CMP             #$FF
                        BNE             ?NOT_ERASED
                        INY
                        BNE             ?BYTE
                        INC             STR8W_PTR_HI
                        LDA             STR8W_PTR_HI
                        SEC
                        SBC             STR8_MARK_SECTOR_HI
                        CMP             #$10
                        BNE             ?PAGE
                        SEC
                        RTS
?NOT_ERASED:
                        TYA
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8W_PTR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS

STR8W_PROGRAM_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             STR8W_BANK_SELECT_A
                        STZ             STR8W_ADDR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8W_ADDR_HI
                        STZ             STR8W_BUF_LO
                        JSR             STR8W_ACTIVE_BUF_HI
                        STA             STR8W_BUF_HI
?BYTE:
                        LDY             #$00
                        LDA             (STR8W_BUF_LO),Y
                        CMP             #$FF
                        BEQ             ?NEXT
                        STA             STR8W_DATA
                        JSR             STR8W_FLASH_WRITE
                        BCS             ?NEXT
                        LDA             STR8W_ADDR_LO
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8W_ADDR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS
?NEXT:
                        INC             STR8W_ADDR_LO
                        INC             STR8W_BUF_LO
                        BNE             ?BYTE
                        INC             STR8W_ADDR_HI
                        INC             STR8W_BUF_HI
                        JSR             STR8W_ACTIVE_BUF_END_REACHED
                        BNE             ?BYTE
                        SEC
                        RTS

STR8W_VERIFY_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             STR8W_BANK_SELECT_A
                        STZ             STR8W_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8W_PTR_HI
                        STZ             STR8W_BUF_LO
                        JSR             STR8W_ACTIVE_BUF_HI
                        STA             STR8W_BUF_HI
?PAGE:
                        LDY             #$00
?BYTE:
                        LDA             (STR8W_PTR_LO),Y
                        CMP             (STR8W_BUF_LO),Y
                        BNE             ?FAIL
                        INY
                        BNE             ?BYTE
                        INC             STR8W_PTR_HI
                        INC             STR8W_BUF_HI
                        JSR             STR8W_ACTIVE_BUF_END_REACHED
                        BNE             ?PAGE
                        SEC
                        RTS
?FAIL:
                        TYA
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8W_PTR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS

STR8W_ACTIVE_BUF_HI:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_PROGRAM_STAGED
                        BEQ             ?STAGED
                        CMP             #STR8_COPY_MODE_STAGE_BANK_SECTOR
                        BEQ             ?STAGED
                        LDA             #STR8_SECTOR_BUF_HI
                        RTS
?STAGED:
                        LDA             STR8_STAGE_BUF_HI
                        RTS

STR8W_ACTIVE_BUF_END_REACHED:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_PROGRAM_STAGED
                        BEQ             ?STAGED
                        CMP             #STR8_COPY_MODE_STAGE_BANK_SECTOR
                        BEQ             ?STAGED
                        LDA             STR8W_BUF_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        RTS
?STAGED:
                        LDA             STR8_STAGE_BUF_HI
                        CLC
                        ADC             #$10
                        CMP             STR8W_BUF_HI
                        RTS

STR8W_FLASH_ERASE:
                        LDA             #$AA
                        STA             STR8_FLASH_UNLOCK1
                        LDA             #$55
                        STA             STR8_FLASH_UNLOCK2
                        LDA             #$80
                        STA             STR8_FLASH_UNLOCK1
                        LDA             #$AA
                        STA             STR8_FLASH_UNLOCK1
                        LDA             #$55
                        STA             STR8_FLASH_UNLOCK2
                        LDA             #$30
                        LDY             #$00
                        STA             (STR8W_ADDR_LO),Y
                        STZ             STR8W_TMO0
                        STZ             STR8W_TMO1
                        LDA             #STR8_FLASH_ERASE_TMO_HI
                        STA             STR8W_TMO2
?POLL:
                        LDY             #$00
                        LDA             (STR8W_ADDR_LO),Y
                        CMP             #$FF
                        BEQ             ?OK
                        DEC             STR8W_TMO0
                        BNE             ?POLL
                        DEC             STR8W_TMO1
                        BNE             ?POLL
                        DEC             STR8W_TMO2
                        BNE             ?POLL
                        BRA             STR8W_FLASH_RESET_FAIL
?OK:
                        SEC
                        RTS

STR8W_FLASH_WRITE:
                        LDY             #$00
                        LDA             (STR8W_ADDR_LO),Y
                        CMP             STR8W_DATA
                        BEQ             ?OK
                        AND             STR8W_DATA
                        CMP             STR8W_DATA
                        BNE             STR8W_FLASH_RESET_FAIL
                        LDA             #$AA
                        STA             STR8_FLASH_UNLOCK1
                        LDA             #$55
                        STA             STR8_FLASH_UNLOCK2
                        LDA             #$A0
                        STA             STR8_FLASH_UNLOCK1
                        LDA             STR8W_DATA
                        STA             (STR8W_ADDR_LO),Y
                        STZ             STR8W_TMO0
                        STZ             STR8W_TMO1
                        LDA             #STR8_FLASH_WRITE_TMO_HI
                        STA             STR8W_TMO2
?POLL:
                        LDY             #$00
                        LDA             (STR8W_ADDR_LO),Y
                        CMP             STR8W_DATA
                        BEQ             ?OK
                        DEC             STR8W_TMO0
                        BNE             ?POLL
                        DEC             STR8W_TMO1
                        BNE             ?POLL
                        DEC             STR8W_TMO2
                        BNE             ?POLL
                        BRA             STR8W_FLASH_RESET_FAIL
?OK:
                        SEC
                        RTS

STR8W_FLASH_RESET_FAIL:
                        LDA             #$F0
                        STA             STR8_FLASH_UNLOCK1
                        CLC
                        RTS

STR8W_TOP_FAIL_HALT:
                        LDA             #$F0
                        STA             STR8_FLASH_UNLOCK1
                        SEI
?HALT_LOOP:
                        BRA             ?HALT_LOOP

STR8W_SELECT_BANK3:
                        LDA             #$03
STR8W_BANK_SELECT_A:
                        AND             #$03
                        TAX
                        LDA             STR8W_BANK_BIT_TABLE,X
                        PHA
                        LDA             #STR8_BANK_PCR_MASK
                        TRB             STR8_FTDI_VIA_PCR
                        PLA
                        TSB             STR8_FTDI_VIA_PCR
                        RTS

STR8W_BANK_BIT_TABLE:
                        DB              $CC,$CE,$EC,$EE

STR8_WORKER_END:
                        ENDMOD

                        END

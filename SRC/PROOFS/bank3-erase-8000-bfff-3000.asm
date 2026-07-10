; ----------------------------------------------------------------------------
; bank3-erase-8000-bfff-3000.asm
; RAM-loaded bank 3 low-flash erase tool, linked at $3000.
;
; Erases physical bank 3 $8000-$BFFF, four 4K sectors, by reusing the
; resident STR8 RAM worker service at $F003. The program fills $0A00-$19FF
; with $FF, then invokes STR8 program-staged mode for sectors $80/$90/$A0/$B0.
; With an all-$FF stage buffer, program-staged is erase + verify only.
;
; Status:
;   $1A00 = $AC OK
;   $1A00 = $E1 erase/verify failed
;   $1A01 = failing sector high byte ($80/$90/$A0/$B0)
;   $1A02/$1A03 = STR8 fail address when available
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          BANK3_ERASE_8000_BFFF_APP

                        XDEF            START

BANK3_BANK              EQU             $03
BANK3_FIRST_SECTOR_HI   EQU             $80
BANK3_LIMIT_SECTOR_HI   EQU             $C0

BANK3_STATUS            EQU             $1A00
BANK3_FAIL_SECTOR_HI    EQU             $1A01
BANK3_FAIL_ADDR_LO      EQU             $1A02
BANK3_FAIL_ADDR_HI      EQU             $1A03
BANK3_DST_PTR_LO        EQU             $CA
BANK3_DST_PTR_HI        EQU             $CB

STR8_SERVICE            EQU             $F003
STR8_MARK_SECTOR_HI     EQU             $1FE9
STR8_MARK_ADDR_LO       EQU             $1FEA
STR8_MARK_ADDR_HI       EQU             $1FEB
STR8_COPY_DST_BANK      EQU             $1FEF
STR8_COPY_MODE          EQU             $1FF0
STR8_STAGE_BUF_HI       EQU             $1FF6
STR8_MODE_PROGRAM_STAGED EQU            $05

                        CODE
START:
                        STZ             BANK3_STATUS
                        STZ             BANK3_FAIL_SECTOR_HI
                        STZ             BANK3_FAIL_ADDR_LO
                        STZ             BANK3_FAIL_ADDR_HI
                        JSR             BANK3_FILL_STAGE_FF

                        LDA             #BANK3_FIRST_SECTOR_HI
                        STA             BANK3_FAIL_SECTOR_HI

BANK3_ERASE_SECTOR:
                        LDA             #BANK3_BANK
                        STA             STR8_COPY_DST_BANK
                        LDA             BANK3_FAIL_SECTOR_HI
                        STA             STR8_MARK_SECTOR_HI
                        LDA             #$0A
                        STA             STR8_STAGE_BUF_HI
                        LDA             #STR8_MODE_PROGRAM_STAGED
                        STA             STR8_COPY_MODE
                        JSR             STR8_SERVICE
                        BCC             BANK3_FAIL

                        LDA             BANK3_FAIL_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             BANK3_FAIL_SECTOR_HI
                        CMP             #BANK3_LIMIT_SECTOR_HI
                        BNE             BANK3_ERASE_SECTOR

                        STZ             BANK3_FAIL_SECTOR_HI
                        LDA             #$AC
                        STA             BANK3_STATUS
                        RTS

BANK3_FAIL:
                        LDA             #$E1
                        STA             BANK3_STATUS
                        LDA             STR8_MARK_ADDR_LO
                        STA             BANK3_FAIL_ADDR_LO
                        LDA             STR8_MARK_ADDR_HI
                        STA             BANK3_FAIL_ADDR_HI
                        LDA             BANK3_STATUS
                        RTS

BANK3_FILL_STAGE_FF:
                        STZ             BANK3_DST_PTR_LO
                        LDA             #$0A
                        STA             BANK3_DST_PTR_HI
BANK3_FILL_PAGE:
                        LDY             #$00
                        LDA             #$FF
BANK3_FILL_BYTE:
                        STA             (BANK3_DST_PTR_LO),Y
                        INY
                        BNE             BANK3_FILL_BYTE
                        INC             BANK3_DST_PTR_HI
                        LDA             BANK3_DST_PTR_HI
                        CMP             #$1A
                        BNE             BANK3_FILL_PAGE
                        RTS

                        END

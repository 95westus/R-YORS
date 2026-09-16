; Read-only sector staging for the local BSO2 Bank-2 installation archive.
; Enter from HIMON G $2000 with Bank 3 visible and the STR8-N 1.34 ABI.
; $2100=bank 0-3, $2101=sector high byte $80,$90,...,$F0.
; $2102=$AC on success, $E1 for invalid parameters, $E2 for selector failure.
; Copies exactly 4096 flash bytes to $4000-$4FFF and restores Bank 3.
; Preserves A/X/Y/P and ZP $A2-$A5. The selector owns $0200-$0226.
; Do not assert NMI or RESET while a different bank is selected.

                        CHIP            65C02
                        PW              132
                        MODULE          BANK_STAGE
                        XDEF            START
                        XDEF            _END_CODE

BANK_NO                 EQU             $2100
SECTOR_HI               EQU             $2101
RESULT                  EQU             $2102
SRC_LO                  EQU             $A2
SRC_HI                  EQU             $A3
DST_LO                  EQU             $A4
DST_HI                  EQU             $A5
BANK_SELECT             EQU             $F010
BANK_SELECT_RAM         EQU             $0203

                        CODE
START:                  PHP
                        SEI
                        PHA
                        PHX
                        PHY
                        LDX             #$03
SAVE_ZP:                LDA             SRC_LO,X
                        PHA
                        DEX
                        BPL             SAVE_ZP
                        LDA             #$E1
                        STA             RESULT
                        LDA             BANK_NO
                        CMP             #$04
                        BCS             DONE
                        LDA             SECTOR_HI
                        CMP             #$80
                        BCC             DONE
                        AND             #$0F
                        BNE             DONE
                        LDA             #$E2
                        STA             RESULT
                        LDA             #$03
                        JSR             BANK_SELECT
; Failed bootstrap leaves Bank 3 selected; do not call an unverified prefix.
                        BCC             DONE
                        LDA             BANK_NO
                        JSR             BANK_SELECT_RAM
                        BCC             RESTORE_BANK
                        STZ             SRC_LO
                        LDA             SECTOR_HI
                        STA             SRC_HI
                        STZ             DST_LO
                        LDA             #$40
                        STA             DST_HI
                        LDX             #$10
COPY_PAGE:              LDY             #$00
COPY_BYTE:              LDA             (SRC_LO),Y
                        STA             (DST_LO),Y
                        INY
                        BNE             COPY_BYTE
                        INC             SRC_HI
                        INC             DST_HI
                        DEX
                        BNE             COPY_PAGE
                        LDA             #$AC
                        STA             RESULT
RESTORE_BANK:           LDA             #$03
                        JSR             BANK_SELECT_RAM
                        BCS             DONE
; Never return through HIMON's ROM while bank restoration has failed.
                        LDA             #$E2
                        STA             RESULT
HALT:                   BRA             HALT
DONE:                   LDX             #$00
RESTORE_ZP:             PLA
                        STA             SRC_LO,X
                        INX
                        CPX             #$04
                        BNE             RESTORE_ZP
                        PLY
                        PLX
                        PLA
                        PLP
                        RTS
_END_CODE:
                        ENDMOD
                        END

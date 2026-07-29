; ----------------------------------------------------------------------------
; flsh-drv.asm
; Raw flash-bank latch driver for the SXB-style bank hardware.
; - Direct VIA PCR hardware access only.
; - No flash erase/write policy.
; ----------------------------------------------------------------------------

                        MODULE          FLSH_DRV

                        XDEF            FLSH_BANK_GET_A
                        XDEF            FLSH_BANK_SELECT_A
                        XDEF            FLSH_BANK_SELECT_3

FLSH_FTDI_VIA_PCR       EQU             $7FEC
FLSH_BANK_PCR_MASK      EQU             $EE

                        CODE
; ----------------------------------------------------------------------------
; ROUTINE: FLSH_BANK_GET_A
; TIER: L0
; TAGS: FLASH, BANK, DRIVER, VIA-PCR, W65C02
; PURPOSE: Decode the explicit SXB flash-bank latch mode from VIA PCR.
; IN : none
; OUT: recognized: A = bank 0-3, C=1
;      unknown:    A = raw masked PCR state, C=0
; CLOBBERS: X
; EXCEPTIONS/NOTES:
; - PCR reset/input mode is not an explicit output pattern. Board pull-ups
;   physically select Bank 3 in that state, but this routine returns C=0.
; - Call FLSH_BANK_SELECT_3 first when software needs a canonical readable
;   Bank-3 output pattern.
; ----------------------------------------------------------------------------
FLSH_BANK_GET_A:
                        LDA             FLSH_FTDI_VIA_PCR
                        AND             #FLSH_BANK_PCR_MASK
                        LDX             #$03
?MATCH:
                        CMP             FLSH_BANK_BIT_TABLE,X
                        BEQ             ?FOUND
                        DEX
                        BPL             ?MATCH
                        CLC
                        RTS
?FOUND:
                        TXA
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FLSH_BANK_SELECT_A  [HASH:ED3AF020]
; TIER: L0
; TAGS: FLASH, BANK, DRIVER, VIA-PCR, W65C02
; PURPOSE: Select visible flash bank 0-3 through the raw SXB bank latch.
; IN : A = bank number, low two bits used
; OUT: A/X clobbered; selected flash bank changes
; EXCEPTIONS/NOTES:
; - Directly touches the FTDI/VIA PCR bank-latch bits at $7FEC.
; - This routine owns no flash erase/write policy.
; ----------------------------------------------------------------------------
FLSH_BANK_SELECT_A:
                        AND             #$03
                        TAX
                        LDA             FLSH_BANK_BIT_TABLE,X
                        PHA
                        LDA             #FLSH_BANK_PCR_MASK
                        TRB             FLSH_FTDI_VIA_PCR
                        PLA
                        TSB             FLSH_FTDI_VIA_PCR
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FLSH_BANK_SELECT_3  [HASH:9F3A7556]
; TIER: L0
; TAGS: FLASH, BANK, DRIVER, VIA-PCR, W65C02
; PURPOSE: Convenience wrapper to restore the live boot bank latch.
; IN : none
; OUT: A/X clobbered; bank 3 selected
; ----------------------------------------------------------------------------
FLSH_BANK_SELECT_3:
                        LDA             #$03
                        BRA             FLSH_BANK_SELECT_A

                        DATA
; CA2 drives FA15; CB2 drives FAMS. Flash bank numbers follow the physical
; address-line state: 00, 01, 10, 11. Pull-ups/default reset select bank 3.
FLSH_BANK_BIT_TABLE:
                        DB              $CC,$CE,$EC,$EE

                        END

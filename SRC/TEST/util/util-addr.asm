                        MODULE          UTL_ADDR16_GET_BAND
                        XDEF            UTL_ADDR16_GET_BAND

; ----------------------------------------------------------------------------
; Address band classifier for 16-bit addresses.
; In : X = low byte, Y = high byte of address
; Out: A = band id (see constants below), C = 1
; Note: X/Y preserved, low byte is not used (all boundaries are page-aligned).
; ----------------------------------------------------------------------------

UTL_ADDR_BAND_ZP           EQU             $00
UTL_ADDR_BAND_STACK        EQU             $01
UTL_ADDR_BAND_LOW_RAM      EQU             $02
UTL_ADDR_BAND_MAIN_RAM     EQU             $03
UTL_ADDR_BAND_IO_WINDOW    EQU             $04
UTL_ADDR_BAND_HI_IO_WINDOW EQU             $05
UTL_ADDR_BAND_ROM_LO       EQU             $06
UTL_ADDR_BAND_ROM_MID      EQU             $07
UTL_ADDR_BAND_ROM_HI       EQU             $08

; ----------------------------------------------------------------------------
; ROUTINE: UTL_ADDR16_GET_BAND  [HASH:46C4C4F0]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CLASSIFY, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Classify 16-bit address into one of project-defined memory bands.
; IN : X = low byte, Y = high byte of address
; OUT: A = band id:
;      $00 : $0000-$00FF
;      $01 : $0100-$01FF
;      $02 : $0200-$0FFF
;      $03 : $1000-$77FF
;      $04 : $7800-$7EFF
;      $05 : $7F00-$7FFF
;      $06 : $8000-$BFFF
;      $07 : $C000-$EFFF
;      $08 : $F000-$FFFF
;      C = 1 (always)
; EXCEPTIONS/NOTES:
; - Range split is based on high byte only (page boundaries).
; - X is accepted for a consistent addr16 calling convention.
; ----------------------------------------------------------------------------
UTL_ADDR16_GET_BAND:
                        TYA
                        BEQ             ?BAND_ZP
                        CMP             #$01
                        BEQ             ?BAND_STACK
                        CMP             #$10
                        BCC             ?BAND_LOW_RAM
                        CMP             #$78
                        BCC             ?BAND_MAIN_RAM
                        CMP             #$7F
                        BCC             ?BAND_IO_WINDOW
                        BEQ             ?BAND_HI_IO_WINDOW
                        CMP             #$C0
                        BCC             ?BAND_ROM_LO
                        CMP             #$F0
                        BCC             ?BAND_ROM_MID
                        LDA             #UTL_ADDR_BAND_ROM_HI
                        SEC
                        RTS
?BAND_ZP:
                        LDA             #UTL_ADDR_BAND_ZP
                        SEC
                        RTS
?BAND_STACK:
                        LDA             #UTL_ADDR_BAND_STACK
                        SEC
                        RTS
?BAND_LOW_RAM:
                        LDA             #UTL_ADDR_BAND_LOW_RAM
                        SEC
                        RTS
?BAND_MAIN_RAM:
                        LDA             #UTL_ADDR_BAND_MAIN_RAM
                        SEC
                        RTS
?BAND_IO_WINDOW:
                        LDA             #UTL_ADDR_BAND_IO_WINDOW
                        SEC
                        RTS
?BAND_HI_IO_WINDOW:
                        LDA             #UTL_ADDR_BAND_HI_IO_WINDOW
                        SEC
                        RTS
?BAND_ROM_LO:
                        LDA             #UTL_ADDR_BAND_ROM_LO
                        SEC
                        RTS
?BAND_ROM_MID:
                        LDA             #UTL_ADDR_BAND_ROM_MID
                        SEC
                        RTS
                        ENDMOD

                        MODULE          UTL_ADDR16_GET_PAGE_BAND
                        XDEF            UTL_ADDR16_GET_PAGE_BAND

; ----------------------------------------------------------------------------
; ROUTINE: UTL_ADDR16_GET_PAGE_BAND  [HASH:9CB79B22]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Return 256-byte page band for a 16-bit address.
; IN : X = low byte, Y = high byte of address
; OUT: A = page band ($00..$FF), C = 1
; EXCEPTIONS/NOTES:
; - For 256-byte bands, high byte is the band id directly.
; - X is ignored but accepted for consistent addr16 call shape.
; ----------------------------------------------------------------------------
UTL_ADDR16_GET_PAGE_BAND:
                        TYA
                        SEC
                        RTS
                        ENDMOD

                        MODULE          UTL_GET_CALLSITE_NEXT16
                        XDEF            UTL_GET_CALLSITE_NEXT16

; ----------------------------------------------------------------------------
; ROUTINE: UTL_GET_CALLSITE_NEXT16  [HASH:59886F2E]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, NO-ZP, NO-RAM, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Fetch caller return address +1 (next instruction address).
; IN : none
; OUT: X = low byte, Y = high byte, C = 1
; EXCEPTIONS/NOTES:
; - For a caller using JSR, stack holds (JSR+2); this routine returns (JSR+3).
; ----------------------------------------------------------------------------
UTL_GET_CALLSITE_NEXT16:
                        TSX
                        LDA             $0101,X
                        CLC
                        ADC             #$01
                        PHA
                        LDA             $0102,X
                        ADC             #$00
                        TAY
                        PLA
                        TAX
                        SEC
                        RTS
                        ENDMOD

                        MODULE          UTL_GET_CALLSITE_BAND
                        XDEF            UTL_GET_CALLSITE_BAND
                        XREF            UTL_GET_CALLSITE_NEXT16
                        XREF            UTL_ADDR16_GET_BAND

; ----------------------------------------------------------------------------
; ROUTINE: UTL_GET_CALLSITE_BAND  [HASH:F7DDEB7B]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Return project band id for caller next-instruction address.
; IN : none
; OUT: A = band id from UTL_ADDR16_GET_BAND, C = 1
; EXCEPTIONS/NOTES:
; - Uses UTL_GET_CALLSITE_NEXT16 then UTL_ADDR16_GET_BAND.
; ----------------------------------------------------------------------------
UTL_GET_CALLSITE_BAND:
                        JSR             UTL_GET_CALLSITE_NEXT16
                        JSR             UTL_ADDR16_GET_BAND
                        RTS
                        ENDMOD

                        END

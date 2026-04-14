; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-common.asm  -> pure utility routines, no hardware access.
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
;
; ZP ALLOCATION POLICY
; - See ZP_MAP.md for reserved/scratch ownership.
; - Add/update labels in ZP_MAP.md before claiming new ZP bytes.
;
; THIS FILE: L2 COMMON UTILITIES.
; - Pure conversions/classification helpers.
; - Callable by any layer; must not depend on hardware or higher layers.
; -------------------------------------------------------------------------

                        MODULE          UTL_HEX_NIBBLE_TO_ASCII
                        XDEF            UTL_HEX_NIBBLE_TO_ASCII

                    ; -------------------------------------------------------------------------
                    ; I/O / SUBROUTINE CONVENTION (used across this repo):
                    ; - A is the primary input/output register for data.
                    ; - Carry (C) is the standard status bit:
                    ;     C=1 means success/ready/valid, C=0 means fail/not-ready/not-valid.
                    ; - X and Y are scratch/call-clobbered unless a routine explicitly states
                    ;   otherwise (caller must save them if needed).
                    ; -------------------------------------------------------------------------

                        CODE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_NIBBLE_TO_ASCII  [RHID:21EF]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert low nibble in A (0..15) to uppercase ASCII hex.
; IN : A = source byte (only low nibble used)
; OUT: A = ASCII character '0'..'F', C = 1
; EXCEPTIONS/NOTES:
; - High nibble of input is ignored.
; - Always returns success (SEC).
; ----------------------------------------------------------------------------
UTL_HEX_NIBBLE_TO_ASCII:

                        AND             #$0F                    ; Ensure only low nibble is processed
                        CMP             #10
                        BCC             ?ASC_0
                        ADC             #$06
?ASC_0:                 ADC             #'0'
                        sec
                        RTS
                        ENDMOD


                        MODULE          UTL_HEX_BYTE_TO_ASCII_YX
                        XDEF            UTL_HEX_BYTE_TO_ASCII_YX
                        XREF            UTL_HEX_NIBBLE_TO_ASCII

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_BYTE_TO_ASCII_YX  [RHID:604F]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert byte in A to uppercase ASCII hex pair.
; IN : A = source byte
; OUT: A = source byte (preserved), Y = high hex ASCII, X = low hex ASCII, C=1
; EXCEPTIONS/NOTES:
; - Always returns success (SEC).
; - X/Y are call-clobbered.
; ----------------------------------------------------------------------------
UTL_HEX_BYTE_TO_ASCII_YX:
                        PHA
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        JSR             UTL_HEX_NIBBLE_TO_ASCII
                        TAY
                        PLA
                        PHA
                        JSR             UTL_HEX_NIBBLE_TO_ASCII
                        TAX
                        PLA
                        SEC
                        RTS
                        ENDMOD


                        MODULE          UTL_HEX_ASCII_TO_NIBBLE
                        XDEF            UTL_HEX_ASCII_TO_NIBBLE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_ASCII_TO_NIBBLE
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert ASCII hex character to nibble.
; IN : A = ASCII '0'..'9', 'A'..'F', or 'a'..'f'
; OUT: C = 1 and A = nibble (0..15) on success
;      C = 0 and A unchanged on invalid input
; EXCEPTIONS/NOTES:
; - Accepts uppercase and lowercase input.
; ----------------------------------------------------------------------------
UTL_HEX_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             ?FAIL
                        CMP             #':'
                        BCC             ?DIGIT
                        CMP             #'A'
                        BCC             ?CHECK_LOWER
                        CMP             #'G'
                        BCC             ?UPPER
?CHECK_LOWER:
                        CMP             #'a'
                        BCC             ?FAIL
                        CMP             #'g'
                        BCS             ?FAIL
                        SEC
                        SBC             #$57                    ; 'a' - 10
                        SEC
                        RTS
?UPPER:
                        SEC
                        SBC             #$37                    ; 'A' - 10
                        SEC
                        RTS
?DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS
                        ENDMOD


                        MODULE          UTL_HEX_ASCII_YX_TO_BYTE
                        XDEF            UTL_HEX_ASCII_YX_TO_BYTE
                        XREF            UTL_HEX_ASCII_TO_NIBBLE

UTL_CONV_TMP_A          EQU             $F6

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_ASCII_YX_TO_BYTE
; MEM : ZP: UTL_CONV_TMP_A($F6); FIXED_RAM: none.
; PURPOSE: Convert two ASCII hex chars (Y=high, X=low) into one byte.
; IN : Y = high nibble ASCII, X = low nibble ASCII
; OUT: C = 1 and A = combined byte on success
;      C = 0 on invalid nibble input
; EXCEPTIONS/NOTES:
; - Uses UTL_HEX_ASCII_TO_NIBBLE for validation/conversion.
; - X/Y are call-clobbered.
; ----------------------------------------------------------------------------
UTL_HEX_ASCII_YX_TO_BYTE:
                        TXA
                        JSR             UTL_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        STA             UTL_CONV_TMP_A
                        TYA
                        JSR             UTL_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ORA             UTL_CONV_TMP_A
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS
                        ENDMOD

                        MODULE          UTL_CHAR_IN_RANGE
                        XDEF            UTL_CHAR_IN_RANGE

CHAR_CLASS_TMP_A        EQU             $F6

; ----------------------------------------------------------------------------
; ASCII character classifiers.
; In : A = character to test
; Out: C = 1 when predicate is true, C = 0 when false
; Note: A is preserved by all routines.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IN_RANGE  [RHID:D44C]
; MEM : ZP: CHAR_CLASS_TMP_A($F6); FIXED_RAM: none.
; PURPOSE: Check whether character A is in half-open interval [X, Y).
; IN : A = character, X = low bound (inclusive), Y = high bound (exclusive)
; OUT: C = 1 when X <= A < Y, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A/X/Y are preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IN_RANGE:
                        STA             CHAR_CLASS_TMP_A
                        CPX             CHAR_CLASS_TMP_A
                        BCC             ?LOW_OK
                        BEQ             ?LOW_OK
                        CLC
                        RTS
?LOW_OK:
                        CPY             CHAR_CLASS_TMP_A
                        BCC             ?FALSE
                        BEQ             ?FALSE
                        SEC
                        RTS
?FALSE:
                        CLC
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_PRINTABLE
                        XDEF            UTL_CHAR_IS_PRINTABLE
                        XREF            UTL_CHAR_IN_RANGE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_PRINTABLE  [RHID:87B3]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE; FIXED_RAM: none.
; PURPOSE: Check for printable ASCII character (space through '~').
; IN : A = character
; OUT: C = 1 if printable, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_PRINTABLE:
                        LDX             #$20
                        LDY             #$7F
                        JSR             UTL_CHAR_IN_RANGE
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_CONTROL
                        XDEF            UTL_CHAR_IS_CONTROL
                        XREF            UTL_CHAR_IN_RANGE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_CONTROL  [RHID:5040]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE; FIXED_RAM: none.
; PURPOSE: Check for ASCII control character.
; IN : A = character
; OUT: C = 1 if control (0x00..0x1F or 0x7F), C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_CONTROL:
                        CMP             #$7F
                        BEQ             ?TRUE
                        LDX             #$00
                        LDY             #$20
                        JSR             UTL_CHAR_IN_RANGE
                        RTS
?TRUE:
                        SEC
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_PUNCT
                        XDEF            UTL_CHAR_IS_PUNCT
                        XREF            UTL_CHAR_IS_PRINTABLE
                        XREF            UTL_CHAR_IS_DIGIT
                        XREF            UTL_CHAR_IS_ALPHA

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_PUNCT  [RHID:A4D7]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE/CHAR_* helpers; FIXED_RAM: none.
; PURPOSE: Check for printable punctuation (not space, not alnum).
; IN : A = character
; OUT: C = 1 if punctuation, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_PUNCT:
                        JSR             UTL_CHAR_IS_PRINTABLE
                        BCC             ?FALSE
                        CMP             #' '
                        BEQ             ?FALSE
                        JSR             UTL_CHAR_IS_DIGIT
                        BCS             ?FALSE
                        JSR             UTL_CHAR_IS_ALPHA
                        BCS             ?FALSE
                        SEC
                        RTS
?FALSE:
                        CLC
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_DIGIT
                        XDEF            UTL_CHAR_IS_DIGIT
                        XREF            UTL_CHAR_IN_RANGE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_DIGIT  [RHID:63B0]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE; FIXED_RAM: none.
; PURPOSE: Check for ASCII decimal digit.
; IN : A = character
; OUT: C = 1 if '0'..'9', C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_DIGIT:
                        LDX             #'0'
                        LDY             #':'
                        JSR             UTL_CHAR_IN_RANGE
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_ALPHA
                        XDEF            UTL_CHAR_IS_ALPHA
                        XREF            UTL_CHAR_IS_UPPER
                        XREF            UTL_CHAR_IS_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_ALPHA  [RHID:97ED]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IS_UPPER/UTL_CHAR_IS_LOWER; FIXED_RAM: none.
; PURPOSE: Check for ASCII alphabetic letter.
; IN : A = character
; OUT: C = 1 if 'A'..'Z' or 'a'..'z', C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_ALPHA:
                        JSR             UTL_CHAR_IS_UPPER
                        BCS             ?TRUE
                        JSR             UTL_CHAR_IS_LOWER
                        BCS             ?TRUE
?FALSE:
                        CLC
                        RTS
?TRUE:
                        SEC
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_LOWER
                        XDEF            UTL_CHAR_IS_LOWER
                        XREF            UTL_CHAR_IN_RANGE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_LOWER  [RHID:CA35]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE; FIXED_RAM: none.
; PURPOSE: Check for lowercase ASCII letter.
; IN : A = character
; OUT: C = 1 if 'a'..'z', C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_LOWER:
                        LDX             #'a'
                        LDY             #'{'
                        JSR             UTL_CHAR_IN_RANGE
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_IS_UPPER
                        XDEF            UTL_CHAR_IS_UPPER
                        XREF            UTL_CHAR_IN_RANGE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IS_UPPER  [RHID:C8D3]
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE; FIXED_RAM: none.
; PURPOSE: Check for uppercase ASCII letter.
; IN : A = character
; OUT: C = 1 if 'A'..'Z', C = 0 otherwise
; EXCEPTIONS/NOTES:
; - A is preserved.
; ----------------------------------------------------------------------------
UTL_CHAR_IS_UPPER:
                        LDX             #'A'
                        LDY             #'['
                        JSR             UTL_CHAR_IN_RANGE
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_TO_UPPER
                        XDEF            UTL_CHAR_TO_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_TO_UPPER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert lowercase ASCII letter to uppercase.
; IN : A = source character
; OUT: A = uppercase if input was 'a'..'z', otherwise unchanged; C = 1
; EXCEPTIONS/NOTES:
; - Non-lowercase input passes through unchanged.
; ----------------------------------------------------------------------------
UTL_CHAR_TO_UPPER:
                        CMP             #'a'
                        BCC             ?DONE
                        CMP             #'{'
                        BCS             ?DONE
                        AND             #$DF
?DONE:
                        SEC
                        RTS
                        ENDMOD


                        MODULE          UTL_CHAR_TO_LOWER
                        XDEF            UTL_CHAR_TO_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_TO_LOWER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert uppercase ASCII letter to lowercase.
; IN : A = source character
; OUT: A = lowercase if input was 'A'..'Z', otherwise unchanged; C = 1
; EXCEPTIONS/NOTES:
; - Non-uppercase input passes through unchanged.
; ----------------------------------------------------------------------------
UTL_CHAR_TO_LOWER:
                        CMP             #'A'
                        BCC             ?DONE
                        CMP             #'['
                        BCS             ?DONE
                        ORA             #$20
?DONE:
                        SEC
                        RTS
                        ENDMOD

                        MODULE          UTL_ADDR16_GET_BAND
                        XDEF            UTL_ADDR16_GET_BAND

; ----------------------------------------------------------------------------
; Address band classifier for 16-bit addresses.
; In : X = low byte, Y = high byte of address
; Out: A = band id (see constants below), C = 1
; Note: X/Y preserved, low byte is not used (all boundaries are page-aligned).
; ----------------------------------------------------------------------------

UTL_ADDR_BAND_ZP            EQU         $00
UTL_ADDR_BAND_STACK         EQU         $01
UTL_ADDR_BAND_LOW_RAM       EQU         $02
UTL_ADDR_BAND_MAIN_RAM      EQU         $03
UTL_ADDR_BAND_IO_WINDOW     EQU         $04
UTL_ADDR_BAND_HI_IO_WINDOW  EQU         $05
UTL_ADDR_BAND_ROM_LO        EQU         $06
UTL_ADDR_BAND_ROM_MID       EQU         $07
UTL_ADDR_BAND_ROM_HI        EQU         $08

; ----------------------------------------------------------------------------
; ROUTINE: UTL_ADDR16_GET_BAND  [RHID:98C1]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Classify 16-bit address into one of project-defined memory bands.
; IN : X = low byte, Y = high byte of address
; OUT: A = band id:
;      $00 : $0000-$00FF
;      $01 : $0100-$01FF
;      $02 : $0200-$0FFF
;      $03 : $1000-$6FFF
;      $04 : $7000-$7EFF
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
                        CMP             #$70
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
; ROUTINE: UTL_ADDR16_GET_PAGE_BAND  [RHID:4A31]
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
; ROUTINE: UTL_GET_CALLSITE_NEXT16  [RHID:6C8E]
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
; ROUTINE: UTL_GET_CALLSITE_BAND  [RHID:74D2]
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


                        MODULE          UTL_STRING_SCAN
                        XDEF            UTL_FIND_CHAR_CSTR

UTL_FCS_PTR_LO          EQU             $F0
UTL_FCS_PTR_HI          EQU             $F1
UTL_FCS_NEEDLE          EQU             $F7

; ----------------------------------------------------------------------------
; ROUTINE: UTL_FIND_CHAR_CSTR  [RHID:E2C4]
; MEM : ZP: UTL_FCS_PTR_LO($F0), UTL_FCS_PTR_HI($F1), UTL_FCS_NEEDLE($F7); FIXED_RAM: none.
; PURPOSE: Scan C-string for first occurrence of byte in A.
; IN : A = needle byte, X/Y = haystack pointer (NUL-terminated)
; OUT: Found: C = 1
;      Not found/cap: C = 0
;      X/Y = first unconsumed byte pointer:
;            - needle != 0 and found: points just after matched byte
;            - needle == 0 and found: points at NUL terminator
;            - not found: points at NUL terminator
;            - cap reached: points at start+255 (first unscanned byte)
;      A = bytes consumed (0..255)
; EXCEPTIONS/NOTES:
; - Uses fixed 255-byte safety cap if no NUL is encountered.
; - Byte at offset +255 is not inspected by this routine.
; ----------------------------------------------------------------------------
UTL_FIND_CHAR_CSTR:
                        STA             UTL_FCS_NEEDLE
                        STX             UTL_FCS_PTR_LO
                        STY             UTL_FCS_PTR_HI
                        LDY             #$00

?SCAN_LOOP:
                        CPY             #$FF
                        BEQ             ?CAP_REACHED
                        LDA             (UTL_FCS_PTR_LO),Y
                        CMP             UTL_FCS_NEEDLE
                        BEQ             ?FOUND
                        CMP             #$00
                        BEQ             ?NOT_FOUND
                        INY
                        BRA             ?SCAN_LOOP

?FOUND:
                        LDA             UTL_FCS_NEEDLE
                        BEQ             ?FOUND_AT_NUL
                        INY
?FOUND_AT_NUL:
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FCS_PTR_LO
                        TAX
                        LDA             UTL_FCS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        SEC
                        RTS

?NOT_FOUND:
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FCS_PTR_LO
                        TAX
                        LDA             UTL_FCS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        CLC
                        RTS

?CAP_REACHED:
                        LDY             #$FF
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FCS_PTR_LO
                        TAX
                        LDA             UTL_FCS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        CLC
                        RTS
                        ENDMOD

                        MODULE          UTL_STRING_SCAN_HIBIT
                        XDEF            UTL_FIND_CHAR_HBSTR

UTL_FHS_PTR_LO          EQU             $F0
UTL_FHS_PTR_HI          EQU             $F1
UTL_FHS_NEEDLE          EQU             $F7
UTL_FHS_CUR             EQU             $F8

; ----------------------------------------------------------------------------
; ROUTINE: UTL_FIND_CHAR_HBSTR  [RHID:2E39]
; MEM : ZP: UTL_FHS_PTR_LO($F0), UTL_FHS_PTR_HI($F1), UTL_FHS_NEEDLE($F7), UTL_FHS_CUR($F8); FIXED_RAM: none.
; PURPOSE: Scan HIBIT-string for first occurrence of byte in A (7-bit compare).
; IN : A = needle byte (low 7 bits used), X/Y = haystack pointer (HIBIT-terminated)
; OUT: Found: C = 1
;      Not found/cap: C = 0
;      X/Y = first unconsumed byte pointer:
;            - found before final byte: points just after matched byte
;            - found at final byte: points at final byte
;            - not found: points at final byte
;            - cap reached: points at start+255 (first unscanned byte)
;      A = bytes consumed (0..255)
; EXCEPTIONS/NOTES:
; - HIBIT-string terminates at first byte with bit7=1.
; - Matching ignores bit7 on both needle and haystack bytes.
; - Uses fixed 255-byte safety cap; byte at offset +255 is not inspected.
; ----------------------------------------------------------------------------
UTL_FIND_CHAR_HBSTR:
                        AND             #$7F
                        STA             UTL_FHS_NEEDLE
                        STX             UTL_FHS_PTR_LO
                        STY             UTL_FHS_PTR_HI
                        LDY             #$00

?SCAN_LOOP:
                        CPY             #$FF
                        BEQ             ?CAP_REACHED
                        LDA             (UTL_FHS_PTR_LO),Y
                        STA             UTL_FHS_CUR
                        AND             #$7F
                        CMP             UTL_FHS_NEEDLE
                        BEQ             ?FOUND
                        LDA             UTL_FHS_CUR
                        BMI             ?NOT_FOUND
                        INY
                        BRA             ?SCAN_LOOP

?FOUND:
                        LDA             UTL_FHS_CUR
                        BMI             ?FOUND_AT_FINAL
                        INY
?FOUND_AT_FINAL:
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FHS_PTR_LO
                        TAX
                        LDA             UTL_FHS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        SEC
                        RTS

?NOT_FOUND:
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FHS_PTR_LO
                        TAX
                        LDA             UTL_FHS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        CLC
                        RTS

?CAP_REACHED:
                        LDY             #$FF
                        TYA
                        PHA
                        CLC
                        ADC             UTL_FHS_PTR_LO
                        TAX
                        LDA             UTL_FHS_PTR_HI
                        ADC             #$00
                        TAY
                        PLA
                        CLC
                        RTS
                        ENDMOD

                        END



                        MODULE          UTL_STRING_SCAN
                        XDEF            UTL_FIND_CHAR_CSTR

UTL_FCS_PTR_LO             EQU             $E0
UTL_FCS_PTR_HI             EQU             $E1
UTL_FCS_NEEDLE             EQU             $E7

; ----------------------------------------------------------------------------
; ROUTINE: UTL_FIND_CHAR_CSTR  [HASH:B6A44824]
; TIER: APP-L5
; TAGS: UTL, APP-L5, NUL-TERM, CARRY-STATUS, USES-ZP, NO-RAM, STACK
; MEM : ZP: UTL_FCS_PTR_LO($F0), UTL_FCS_PTR_HI($F1), UTL_FCS_NEEDLE($F7);
;   FIXED_RAM: none.
; PURPOSE: Scan C-string for first occurrence of byte in A.
; IN : A = needle byte, X/Y = haystack pointer (NUL-terminated)
; OUT: Found: C = 1
;      Not found/cap: C = 0
;      X/Y = first unconsumed byte pointer:
;      A = bytes consumed (0..255)
; EXCEPTIONS/NOTES:
;            - needle != 0 and found: points just after matched byte
;            - needle == 0 and found: points at NUL terminator
;            - not found: points at NUL terminator
;            - cap reached: points at start+255 (first unscanned byte)
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

UTL_FHS_PTR_LO             EQU             $E0
UTL_FHS_PTR_HI             EQU             $E1
UTL_FHS_NEEDLE             EQU             $E7
UTL_FHS_CUR                EQU             $E8

; ----------------------------------------------------------------------------
; ROUTINE: UTL_FIND_CHAR_HBSTR  [HASH:A687FBC1]
; TIER: APP-L5
; TAGS: UTL, APP-L5, HIBIT-TERM, CARRY-STATUS, USES-ZP, NO-RAM, STACK
; MEM : ZP: UTL_FHS_PTR_LO($F0), UTL_FHS_PTR_HI($F1), UTL_FHS_NEEDLE($F7),
;   UTL_FHS_CUR($F8); FIXED_RAM: none.
; PURPOSE: Scan HIBIT-string for first occurrence of byte in A (7-bit
;   compare).
; IN : A = needle byte (low 7 bits used), X/Y = haystack pointer
;   (HIBIT-terminated)
; OUT: Found: C = 1
;      Not found/cap: C = 0
;      X/Y = first unconsumed byte pointer:
;      A = bytes consumed (0..255)
; EXCEPTIONS/NOTES:
;            - found before final byte: points just after matched byte
;            - found at final byte: points at final byte
;            - not found: points at final byte
;            - cap reached: points at start+255 (first unscanned byte)
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

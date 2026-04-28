                        MODULE          UTL_CHAR_IN_RANGE
                        XDEF            UTL_CHAR_IN_RANGE

CHAR_CLASS_TMP_A           EQU             $E6

; ----------------------------------------------------------------------------
; ASCII character classifiers.
; In : A = character to test
; Out: C = 1 when predicate is true, C = 0 when false
; Note: A is preserved by all routines.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; ROUTINE: UTL_CHAR_IN_RANGE  [HASH:A491]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_IS_PRINTABLE  [HASH:40A0]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_IS_CONTROL  [HASH:72B6]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_IS_PUNCT  [HASH:B4D3]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IN_RANGE/CHAR_* helpers;
;   FIXED_RAM: none.
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
; ROUTINE: UTL_CHAR_IS_DIGIT  [HASH:0CC6]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_IS_ALPHA  [HASH:44F7]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
; MEM : ZP: CHAR_CLASS_TMP_A($F6) via UTL_CHAR_IS_UPPER/UTL_CHAR_IS_LOWER;
;   FIXED_RAM: none.
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
; ROUTINE: UTL_CHAR_IS_LOWER  [HASH:BE9A]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_IS_UPPER  [HASH:EC3B]
; TIER: APP-L5
; TAGS: UTL, APP-L5, VIA, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_TO_UPPER  [HASH:ECCC]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK
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
; ROUTINE: UTL_CHAR_TO_LOWER  [HASH:BF2B]
; TIER: APP-L5
; TAGS: UTL, APP-L5, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK
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

                        END

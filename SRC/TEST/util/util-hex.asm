                        MODULE          UTL_HEX_NIBBLE_TO_ASCII
                        XDEF            UTL_HEX_NIBBLE_TO_ASCII

                    ; --------------------------------------------------------
                    ;   -----------------
                    ; I/O / SUBROUTINE CONVENTION (used across this repo):
                    ; - A is the primary input/output register for data.
                    ; - Carry (C) is the standard status bit:
                    ; C=1 means success/ready/valid, C=0 means
                    ;   fail/not-ready/not-valid.
                    ; - X and Y are scratch/call-clobbered unless a routine
                    ;   explicitly states
                    ;   otherwise (caller must save them if needed).
                    ; --------------------------------------------------------
                    ;   -----------------

                        CODE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_NIBBLE_TO_ASCII  [HASH:D4C88B87]
; TIER: APP-L5
; TAGS: UTL, APP-L5, HEX, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK,
;   PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert low nibble in A (0..15) to uppercase ASCII hex.
; IN : A = source byte (only low nibble used)
; OUT: A = ASCII character '0'..'F', C = 1
; EXCEPTIONS/NOTES:
; - High nibble of input is ignored.
; - Always returns success (SEC).
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry. Existing callers must continue to call `UTL_HEX_NIBBLE_TO_ASCII`,
;   not the `_FNV` label.
; ----------------------------------------------------------------------------
                        XDEF            UTL_HEX_NIBBLE_TO_ASCII_FNV
UTL_HEX_NIBBLE_TO_ASCII_FNV:
                        DB              'F','N',('V'+$80),$87,$8B,$C8,$D4,$00 ; UTL_HEX_NIBBLE_TO_ASCII $D4C88B87 EXEC
UTL_HEX_NIBBLE_TO_ASCII:

                        AND             #$0F
                        ; Ensure only low nibble is processed
                        CMP             #10
                        BCC             ?ASC_0
                        ADC             #$06
?ASC_0:                 ADC             #'0'
                        SEC
                        RTS
                        ENDMOD

                        MODULE          UTL_HEX_BYTE_TO_ASCII_YX
                        XDEF            UTL_HEX_BYTE_TO_ASCII_YX
                        XREF            UTL_HEX_NIBBLE_TO_ASCII

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_BYTE_TO_ASCII_YX  [HASH:7142DD21]
; TIER: APP-L5
; TAGS: UTL, APP-L5, HEX, CARRY-STATUS, NO-ZP, NO-RAM, STACK,
;   PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert byte in A to uppercase ASCII hex pair.
; IN : A = source byte
; OUT: A = source byte (preserved), Y = high hex ASCII, X = low hex ASCII, C=1
; EXCEPTIONS/NOTES:
; - Always returns success (SEC).
; - X/Y are call-clobbered.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry. Existing callers must continue to call `UTL_HEX_BYTE_TO_ASCII_YX`,
;   not the `_FNV` label.
; ----------------------------------------------------------------------------
                        XDEF            UTL_HEX_BYTE_TO_ASCII_YX_FNV
UTL_HEX_BYTE_TO_ASCII_YX_FNV:
                        DB              'F','N',('V'+$80),$21,$DD,$42,$71,$00 ; UTL_HEX_BYTE_TO_ASCII_YX $7142DD21 EXEC
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
; ROUTINE: UTL_HEX_ASCII_TO_NIBBLE  [HASH:ADD714B1]
; TIER: APP-L5
; TAGS: UTL, APP-L5, HEX, CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK,
;   PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert ASCII hex character to nibble.
; IN : A = ASCII '0'..'9', 'A'..'F', or 'a'..'f'
; OUT: C = 1 and A = nibble (0..15) on success
;      C = 0 and A unchanged on invalid input
; EXCEPTIONS/NOTES:
; - Accepts uppercase and lowercase input.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry. Existing callers must continue to call `UTL_HEX_ASCII_TO_NIBBLE`,
;   not the `_FNV` label.
; ----------------------------------------------------------------------------
                        XDEF            UTL_HEX_ASCII_TO_NIBBLE_FNV
UTL_HEX_ASCII_TO_NIBBLE_FNV:
                        DB              'F','N',('V'+$80),$B1,$14,$D7,$AD,$00 ; UTL_HEX_ASCII_TO_NIBBLE $ADD714B1 EXEC
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

UTL_CONV_TMP_A             EQU             $E6

; ----------------------------------------------------------------------------
; ROUTINE: UTL_HEX_ASCII_YX_TO_BYTE  [HASH:EA0B3E6D]
; TIER: APP-L5
; TAGS: UTL, APP-L5, HEX, CARRY-STATUS, USES-ZP, NO-RAM, NOSTACK,
;   PROMOTED, FNV, HASH-SIG
; MEM : ZP: UTL_CONV_TMP_A($E6); FIXED_RAM: none.
; PURPOSE: Convert two ASCII hex chars (Y=high, X=low) into one byte.
; IN : Y = high nibble ASCII, X = low nibble ASCII
; OUT: C = 1 and A = combined byte on success
;      C = 0 on invalid nibble input
; EXCEPTIONS/NOTES:
; - Uses UTL_HEX_ASCII_TO_NIBBLE for validation/conversion.
; - X/Y are call-clobbered.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry. Existing callers must continue to call `UTL_HEX_ASCII_YX_TO_BYTE`,
;   not the `_FNV` label.
; ----------------------------------------------------------------------------
                        XDEF            UTL_HEX_ASCII_YX_TO_BYTE_FNV
UTL_HEX_ASCII_YX_TO_BYTE_FNV:
                        DB              'F','N',('V'+$80),$6D,$3E,$0B,$EA,$00 ; UTL_HEX_ASCII_YX_TO_BYTE $EA0B3E6D EXEC
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

                        END

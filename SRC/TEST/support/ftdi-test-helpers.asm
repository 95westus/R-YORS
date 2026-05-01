; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-*.asm       -> pure utility routines, no hardware access.
; L3 (Access): lock/access-policy -> capability gates, lock/unlock, privilege
;   checks.
; L4 (Sys):    sys-*.asm        -> device-neutral I/O API (SYS_*), calls
;   L3/L2.
; L5 (App):    app/*.asm        -> monitor/app entry points.
; TEST (Out-of-band): test/*.asm -> test harnesses (not part of layer ABI).
;
; THIS FILE: L2 BACKEND HELPER ROUTINES FOR CHAR/STRING TEST REPORTING.
; - Shared "routine of routines" helpers used by backend test harnesses.
; - Uses backend output calls only (`COR_FTDI_*`) so it remains device-layer
;   safe.
; -------------------------------------------------------------------------

                        MODULE          COR_FTDI_TEST_HELPERS

                        XDEF            COR_FTDI_WRITE_CLASS_TAG_A
                        XDEF            COR_FTDI_WRITE_VISIBLE_BUFFER
                        XDEF            COR_FTDI_WRITE_CLASSIFIED_BUFFER

                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF

TH_PTR_LO                  EQU             $E8
TH_PTR_HI                  EQU             $E9
TH_LEN                     EQU             $EA
TH_CHAR                    EQU             $EB

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CLASS_TAG_A  [HASH:65998121]
; TIER: APP-L5
; TAGS: COR, APP-L5, UPPERCASE, LOWERCASE, CLASSIFY, CARRY-STATUS, NO-ZP,
;   NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit class tag string for byte in A.
; IN : A = byte to classify
; OUT: class label printed, C = 1
; EXCEPTIONS/NOTES:
; - Tag buckets: CTRL, PRINT-SPACE, PRINT-DIGIT, PRINT-UPPER,
;   PRINT-LOWER, PRINT-PUNCT.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CLASS_TAG_A:
                        CMP             #$20
                        BCC             TH_TAG_CTRL
                        CMP             #$7F
                        BCS             TH_TAG_CTRL

                        CMP             #' '
                        BEQ             TH_TAG_PRINT_SPACE
                        CMP             #'0'
                        BCC             TH_TAG_PRINT_PUNCT
                        CMP             #':'
                        BCC             TH_TAG_PRINT_DIGIT
                        CMP             #'A'
                        BCC             TH_TAG_PRINT_PUNCT
                        CMP             #'['
                        BCC             TH_TAG_PRINT_UPPER
                        CMP             #'a'
                        BCC             TH_TAG_PRINT_PUNCT
                        CMP             #'{'
                        BCC             TH_TAG_PRINT_LOWER

TH_TAG_PRINT_PUNCT:
                        LDX             #<TH_MSG_CLASS_PRINT_PUNCT
                        LDY             #>TH_MSG_CLASS_PRINT_PUNCT
                        JSR             TH_PUTS_XY
                        SEC
                        RTS
TH_TAG_CTRL:
                        LDX             #<TH_MSG_CLASS_CTRL
                        LDY             #>TH_MSG_CLASS_CTRL
                        JSR             TH_PUTS_XY
                        SEC
                        RTS
TH_TAG_PRINT_SPACE:
                        LDX             #<TH_MSG_CLASS_PRINT_SPACE
                        LDY             #>TH_MSG_CLASS_PRINT_SPACE
                        JSR             TH_PUTS_XY
                        SEC
                        RTS
TH_TAG_PRINT_DIGIT:
                        LDX             #<TH_MSG_CLASS_PRINT_DIGIT
                        LDY             #>TH_MSG_CLASS_PRINT_DIGIT
                        JSR             TH_PUTS_XY
                        SEC
                        RTS
TH_TAG_PRINT_UPPER:
                        LDX             #<TH_MSG_CLASS_PRINT_UPPER
                        LDY             #>TH_MSG_CLASS_PRINT_UPPER
                        JSR             TH_PUTS_XY
                        SEC
                        RTS
TH_TAG_PRINT_LOWER:
                        LDX             #<TH_MSG_CLASS_PRINT_LOWER
                        LDY             #>TH_MSG_CLASS_PRINT_LOWER
                        JSR             TH_PUTS_XY
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_VISIBLE_BUFFER  [HASH:DB0DB4C3]
; TIER: APP-L5
; TAGS: COR, APP-L5, CARRY-STATUS, USES-ZP, NO-RAM, CALLS_COR, STACK
; MEM : ZP: TH_PTR_LO/HI($F8/$F9), TH_LEN($FA); FIXED_RAM: none.
; PURPOSE: Emit a text view of a byte buffer, rendering non-printables as '.'.
; IN : A = length (0..255), X/Y = pointer to source bytes
; OUT: view printed, C = 1
; EXCEPTIONS/NOTES:
; - Length 0 prints "(empty)".
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_VISIBLE_BUFFER:
                        STX             TH_PTR_LO
                        STY             TH_PTR_HI
                        STA             TH_LEN

                        LDA             TH_LEN
                        BNE             TH_VIS_HAS_DATA
                        LDX             #<TH_MSG_EMPTY
                        LDY             #>TH_MSG_EMPTY
                        JSR             TH_PUTS_XY
                        SEC
                        RTS

TH_VIS_HAS_DATA:
                        LDY             #$00
TH_VIS_LOOP:
                        CPY             TH_LEN
                        BEQ             TH_VIS_DONE
                        LDA             (TH_PTR_LO),Y
                        CMP             #' '
                        BCC             TH_VIS_DOT
                        CMP             #$7F
                        BCS             TH_VIS_DOT
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        BRA             TH_VIS_NEXT
TH_VIS_DOT:
                        LDA             #'.'
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
TH_VIS_NEXT:
                        INY
                        BRA             TH_VIS_LOOP

TH_VIS_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CLASSIFIED_BUFFER  [HASH:8A2DED14]
; TIER: APP-L5
; TAGS: COR, APP-L5, CARRY-STATUS, USES-ZP, NO-RAM, CALLS_COR, STACK
; MEM : ZP: TH_PTR_LO/HI($F8/$F9), TH_LEN($FA), TH_CHAR($FB); FIXED_RAM: none.
; PURPOSE: Emit one classification row per byte.
; IN : A = length (0..255), X/Y = pointer to source bytes
; OUT: lines printed in form `[ii] $bb -> <class>`, C = 1
; EXCEPTIONS/NOTES:
; - Length 0 prints "(empty)" and a newline.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CLASSIFIED_BUFFER:
                        STX             TH_PTR_LO
                        STY             TH_PTR_HI
                        STA             TH_LEN

                        LDA             TH_LEN
                        BNE             TH_CL_HAS_DATA
                        LDX             #<TH_MSG_EMPTY
                        LDY             #>TH_MSG_EMPTY
                        JSR             TH_PUTS_XY
                        JSR             COR_FTDI_WRITE_CRLF
                        SEC
                        RTS

TH_CL_HAS_DATA:
                        LDY             #$00
TH_CL_LOOP:
                        CPY             TH_LEN
                        BEQ             TH_CL_DONE

                        LDA             #'['
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        PHY
                        TYA
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        PLY
                        LDA             #']'
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        LDA             #' '
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        LDA             #'$'
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY

                        LDA             (TH_PTR_LO),Y
                        STA             TH_CHAR
                        PHY
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        PLY

                        PHY
                        LDX             #<TH_MSG_ARROW
                        LDY             #>TH_MSG_ARROW
                        JSR             TH_PUTS_XY
                        PLY

                        LDA             TH_CHAR
                        PHY
                        JSR             COR_FTDI_WRITE_CLASS_TAG_A
                        PLY
                        PHY
                        JSR             COR_FTDI_WRITE_CRLF
                        PLY
                        INY
                        BRA             TH_CL_LOOP

TH_CL_DONE:
                        SEC
                        RTS


TH_PUTS_XY:
                        ; Preserve helper pointer scratch ($F8/$F9) because
                        ; COR_FTDI_WRITE_CSTRING reuses the same ZP bytes.
                        LDA             TH_PTR_LO
                        PHA
                        LDA             TH_PTR_HI
                        PHA
                        JSR             COR_FTDI_WRITE_CSTRING
                        PLA
                        STA             TH_PTR_HI
                        PLA
                        STA             TH_PTR_LO
                        RTS

TH_MSG_EMPTY:           DB              "(empty)",$00
TH_MSG_ARROW:           DB              " -> ",$00
TH_MSG_CLASS_CTRL:      DB              "CTRL",$00
TH_MSG_CLASS_PRINT_SPACE: DB            "PRINT-SPACE",$00
TH_MSG_CLASS_PRINT_DIGIT: DB            "PRINT-DIGIT",$00
TH_MSG_CLASS_PRINT_UPPER: DB            "PRINT-UPPER",$00
TH_MSG_CLASS_PRINT_LOWER: DB            "PRINT-LOWER",$00
TH_MSG_CLASS_PRINT_PUNCT: DB            "PRINT-PUNCT",$00

                        ENDMOD
                        END

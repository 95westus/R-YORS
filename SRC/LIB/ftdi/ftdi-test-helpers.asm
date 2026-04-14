; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-*.asm       -> pure utility routines, no hardware access.
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
;
; THIS FILE: L2 BACKEND HELPER ROUTINES FOR CHAR/STRING TEST REPORTING.
; - Shared "routine of routines" helpers used by backend test harnesses.
; - Uses backend output calls only (`COR_FTDI_*`) so it remains device-layer safe.
; -------------------------------------------------------------------------

                        MODULE          COR_FTDI_TEST_HELPERS

                        XDEF            COR_FTDI_WRITE_CLASS_TAG_A
                        XDEF            COR_FTDI_WRITE_VISIBLE_BUFFER
                        XDEF            COR_FTDI_WRITE_CLASSIFIED_BUFFER

                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF

TH_PTR_LO               EQU             $F8
TH_PTR_HI               EQU             $F9
TH_LEN                  EQU             $FA
TH_CHAR                 EQU             $FB

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CLASS_TAG_A  [RHID:4537]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit class tag string for byte in A.
; IN : A = byte to classify
; OUT: class label printed, C = 1
; EXCEPTIONS/NOTES:
; - Tag buckets: CTRL, PRINT-SPACE, PRINT-DIGIT, PRINT-UPPER,
;   PRINT-LOWER, PRINT-PUNCT.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CLASS_TAG_A:
                        cmp             #$20
                        bcc             TH_TAG_CTRL
                        cmp             #$7F
                        bcs             TH_TAG_CTRL

                        cmp             #' '
                        beq             TH_TAG_PRINT_SPACE
                        cmp             #'0'
                        bcc             TH_TAG_PRINT_PUNCT
                        cmp             #':'
                        bcc             TH_TAG_PRINT_DIGIT
                        cmp             #'A'
                        bcc             TH_TAG_PRINT_PUNCT
                        cmp             #'['
                        bcc             TH_TAG_PRINT_UPPER
                        cmp             #'a'
                        bcc             TH_TAG_PRINT_PUNCT
                        cmp             #'{'
                        bcc             TH_TAG_PRINT_LOWER

TH_TAG_PRINT_PUNCT:
                        ldx             #<TH_MSG_CLASS_PRINT_PUNCT
                        ldy             #>TH_MSG_CLASS_PRINT_PUNCT
                        jsr             TH_PUTS_XY
                        sec
                        rts
TH_TAG_CTRL:
                        ldx             #<TH_MSG_CLASS_CTRL
                        ldy             #>TH_MSG_CLASS_CTRL
                        jsr             TH_PUTS_XY
                        sec
                        rts
TH_TAG_PRINT_SPACE:
                        ldx             #<TH_MSG_CLASS_PRINT_SPACE
                        ldy             #>TH_MSG_CLASS_PRINT_SPACE
                        jsr             TH_PUTS_XY
                        sec
                        rts
TH_TAG_PRINT_DIGIT:
                        ldx             #<TH_MSG_CLASS_PRINT_DIGIT
                        ldy             #>TH_MSG_CLASS_PRINT_DIGIT
                        jsr             TH_PUTS_XY
                        sec
                        rts
TH_TAG_PRINT_UPPER:
                        ldx             #<TH_MSG_CLASS_PRINT_UPPER
                        ldy             #>TH_MSG_CLASS_PRINT_UPPER
                        jsr             TH_PUTS_XY
                        sec
                        rts
TH_TAG_PRINT_LOWER:
                        ldx             #<TH_MSG_CLASS_PRINT_LOWER
                        ldy             #>TH_MSG_CLASS_PRINT_LOWER
                        jsr             TH_PUTS_XY
                        sec
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_VISIBLE_BUFFER  [RHID:6E7A]
; MEM : ZP: TH_PTR_LO/HI($F8/$F9), TH_LEN($FA); FIXED_RAM: none.
; PURPOSE: Emit a text view of a byte buffer, rendering non-printables as '.'.
; IN : A = length (0..255), X/Y = pointer to source bytes
; OUT: view printed, C = 1
; EXCEPTIONS/NOTES:
; - Length 0 prints "(empty)".
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_VISIBLE_BUFFER:
                        stx             TH_PTR_LO
                        sty             TH_PTR_HI
                        sta             TH_LEN

                        lda             TH_LEN
                        bne             TH_VIS_HAS_DATA
                        ldx             #<TH_MSG_EMPTY
                        ldy             #>TH_MSG_EMPTY
                        jsr             TH_PUTS_XY
                        sec
                        rts

TH_VIS_HAS_DATA:
                        ldy             #$00
TH_VIS_LOOP:
                        cpy             TH_LEN
                        beq             TH_VIS_DONE
                        lda             (TH_PTR_LO),y
                        cmp             #' '
                        bcc             TH_VIS_DOT
                        cmp             #$7F
                        bcs             TH_VIS_DOT
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        bra             TH_VIS_NEXT
TH_VIS_DOT:
                        lda             #'.'
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
TH_VIS_NEXT:
                        iny
                        bra             TH_VIS_LOOP

TH_VIS_DONE:
                        sec
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CLASSIFIED_BUFFER  [RHID:382C]
; MEM : ZP: TH_PTR_LO/HI($F8/$F9), TH_LEN($FA), TH_CHAR($FB); FIXED_RAM: none.
; PURPOSE: Emit one classification row per byte.
; IN : A = length (0..255), X/Y = pointer to source bytes
; OUT: lines printed in form `[ii] $bb -> <class>`, C = 1
; EXCEPTIONS/NOTES:
; - Length 0 prints "(empty)" and a newline.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CLASSIFIED_BUFFER:
                        stx             TH_PTR_LO
                        sty             TH_PTR_HI
                        sta             TH_LEN

                        lda             TH_LEN
                        bne             TH_CL_HAS_DATA
                        ldx             #<TH_MSG_EMPTY
                        ldy             #>TH_MSG_EMPTY
                        jsr             TH_PUTS_XY
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

TH_CL_HAS_DATA:
                        ldy             #$00
TH_CL_LOOP:
                        cpy             TH_LEN
                        beq             TH_CL_DONE

                        lda             #'['
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        phy
                        tya
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ply
                        lda             #']'
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        lda             #' '
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        lda             #'$'
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply

                        lda             (TH_PTR_LO),y
                        sta             TH_CHAR
                        phy
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ply

                        phy
                        ldx             #<TH_MSG_ARROW
                        ldy             #>TH_MSG_ARROW
                        jsr             TH_PUTS_XY
                        ply

                        lda             TH_CHAR
                        phy
                        jsr             COR_FTDI_WRITE_CLASS_TAG_A
                        ply
                        phy
                        jsr             COR_FTDI_WRITE_CRLF
                        ply
                        iny
                        bra             TH_CL_LOOP

TH_CL_DONE:
                        sec
                        rts


TH_PUTS_XY:
                        ; Preserve helper pointer scratch ($F8/$F9) because
                        ; COR_FTDI_WRITE_CSTRING reuses the same ZP bytes.
                        lda             TH_PTR_LO
                        pha
                        lda             TH_PTR_HI
                        pha
                        jsr             COR_FTDI_WRITE_CSTRING
                        pla
                        sta             TH_PTR_HI
                        pla
                        sta             TH_PTR_LO
                        rts

TH_MSG_EMPTY:           db              "(empty)",$00
TH_MSG_ARROW:           db              " -> ",$00
TH_MSG_CLASS_CTRL:      db              "CTRL",$00
TH_MSG_CLASS_PRINT_SPACE: db            "PRINT-SPACE",$00
TH_MSG_CLASS_PRINT_DIGIT: db            "PRINT-DIGIT",$00
TH_MSG_CLASS_PRINT_UPPER: db            "PRINT-UPPER",$00
TH_MSG_CLASS_PRINT_LOWER: db            "PRINT-LOWER",$00
TH_MSG_CLASS_PRINT_PUNCT: db            "PRINT-PUNCT",$00

                        ENDMOD
                        END


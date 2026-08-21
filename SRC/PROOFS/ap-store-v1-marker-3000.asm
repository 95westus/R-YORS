; ----------------------------------------------------------------------------
; AP Store V1 Slice 4 golden single-sector payload.
; Loaded through AP v2 at $3000, it leaves an unmistakable marker in the
; documented user-free low RAM range and returns success.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          AP_STORE_V1_MARKER

                        XDEF            START

                        CODE

START:
                        LDA             #$A4
                        STA             $1A00
                        LDA             #$AC
                        SEC
                        RTS

                        ENDMOD

                        END

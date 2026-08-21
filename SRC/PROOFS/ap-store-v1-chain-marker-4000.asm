; AP Store V1 Slice 5 exact-4096-byte AP v2 fixture BODY.

                        CHIP            65C02
                        PW              132

                        MODULE          AP_STORE_V1_CHAIN_MARKER
                        XDEF            START

                        CODE
START:
                        LDA             #$C5
                        STA             $1A01
                        LDA             #$AC
                        SEC
                        RTS
                        DS              4040

                        DATA
MARKER_SENTINEL:        DB              $EA

                        ENDMOD
                        END

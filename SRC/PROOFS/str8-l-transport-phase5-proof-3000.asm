; ----------------------------------------------------------------------------
; str8-l-transport-phase5-proof-3000.asm
; Non-destructive Phase-5 serial transport proof, linked at $3000.
;
; This image is exactly 128 contiguous bytes: eight 16-byte S1 data records,
; followed by S9 $3000. Each data record is 42 printable S19 characters,
; matching the maximum-length records in the RAM erase fixture whose direct
; transfer was rejected during Phase 4. It writes only RAM $4900 and returns
; A=$A5. It contains no STR8 service calls and cannot program or erase flash.
;
; Board entry: L G, then send the generated .s19 file unchanged.
; Pass: L OK=0080 GO=3000, normal return A=A5, and $4900=A5.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          STR8_L_TRANSPORT_PHASE5_PROOF_APP

                        XDEF            START

P5_RESULT               EQU             $4900

                        CODE
START:
                        LDA             #$A5
                        STA             P5_RESULT
                        RTS

; Pad the image to 128 bytes without introducing any operation beyond the
; return above. Six bytes of code plus 122 NOPs equals eight S1 records.
P5_PAD:
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA
                        DB              $EA,$EA

                        END

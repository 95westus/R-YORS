; ----------------------------------------------------------------------------
; crc16-notable.asm
; Standalone W65C02S CRC-16/CCITT no-table helpers.
;
; Based on Greg Cook's "More CRC Calculations" no-table CRC-16 routine,
; contributed to 6502.org. Local changes: R-YORS labels, fixed RAM aliases,
; and small init/result helper routines.
;
; Default workspace consumes two bytes from the high end of the reserved
; STR8/HIMON ZP expansion lane. Because CRC16_LO/HI are zero-page addresses,
; CRC16_UPDATE_A keeps Cook's 36-byte, 62-cycle fast form.
;
; Test vector: init $FFFF, update bytes $01,$02,$03,$04 -> CRC16 $89C3.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          CRC16_NOTABLE

                        XDEF            CRC16_INIT_FFFF
                        XDEF            CRC16_UPDATE_A
                        XDEF            CRC16_GET_XY

CRC16_LO                EQU             $CB
CRC16_HI                EQU             $CC

; ----------------------------------------------------------------------------
; ROUTINE: CRC16_INIT_FFFF
; OUT: CRC16_LO=$FF, CRC16_HI=$FF
; MEM : ZP: $CB-$CC by default.
; CLOBBERS: A,P
; ----------------------------------------------------------------------------
CRC16_INIT_FFFF:
                        LDA             #$FF
                        STA             CRC16_LO
                        STA             CRC16_HI
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: CRC16_UPDATE_A
; IN : A = next input byte
; OUT: CRC16_LO/CRC16_HI updated as CRC-16/CCITT, low byte first
; MEM : ZP: $CB-$CC by default.
; CLOBBERS: A,X,Y,P
; NOTE: No tables. Adapted from Greg Cook's fast constant-time CRC-16 routine.
; ----------------------------------------------------------------------------
CRC16_UPDATE_A:
                        EOR             CRC16_HI
                        STA             CRC16_HI
                        LSR
                        LSR
                        LSR
                        LSR
                        TAX
                        ASL
                        EOR             CRC16_LO
                        STA             CRC16_LO
                        TXA
                        EOR             CRC16_HI
                        STA             CRC16_HI
                        ASL
                        ASL
                        ASL
                        TAX
                        ASL
                        ASL
                        EOR             CRC16_HI
                        TAY
                        TXA
                        ROL
                        EOR             CRC16_LO
                        STA             CRC16_HI
                        STY             CRC16_LO
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: CRC16_GET_XY
; OUT: X = CRC16 low byte
;      Y = CRC16 high byte
;      C = 1
; MEM : ZP: $CB-$CC by default.
; CLOBBERS: X,Y,P
; ----------------------------------------------------------------------------
CRC16_GET_XY:
                        LDX             CRC16_LO
                        LDY             CRC16_HI
                        SEC
                        RTS

                        ENDMOD

                        END

; ---------------------------------------------------------------------------
; Host-built counterpart of DOC/GUIDES/ASM/SAMPLES/pia-led-show-2000.a.
; The shared body must remain instruction-for-instruction identical. The
; `pia-led-show-check` target enforces that and builds the board-loadable S19.
; ---------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          PIA_LED_SHOW
                        XDEF            MAIN
                        XDEF            _END_CODE

PIA_PORTA               EQU             $7FA1
PIA_DDRA                EQU             $7FA3

                        CODE

; BEGIN SHARED LED BODY
MAIN:                   BRA             RUN

RUN:                    LDA             PIA_DDRA
                        PHA
                        LDA             PIA_PORTA
                        PHA
                        LDA             #$FF
                        STA             PIA_DDRA
                        LDX             #$00

NEXT:                   LDA             PATTERNS,X
                        JSR             SHOW
                        INX
                        CPX             #$10
                        BNE             NEXT

                        PLA
                        STA             PIA_PORTA
                        PLA
                        STA             PIA_DDRA
                        LDA             #$AC
                        SEC
                        RTS

SHOW:                   STA             PIA_PORTA
                        JSR             DELAY40
                        JSR             DELAY40
                        JSR             DELAY40
                        JSR             DELAY40
                        RTS

DELAY40:                PHX
                        PHY
                        LDX             #$00
DLY1:                   LDY             #$00
DLY2:                   DEY
                        BNE             DLY2
                        DEX
                        BNE             DLY1
                        PLY
                        PLX
                        RTS

PATTERNS:               DB              $01,$02,$04,$08,$0F,$00,$10,$20
                        DB              $40,$80,$F0,$00,$55,$AA,$FF,$00
; END SHARED LED BODY

_END_CODE:
                        ENDMOD
                        END

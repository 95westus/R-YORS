; ---------------------------------------------------------------------------
; Host-built counterpart of DOC/GUIDES/ASM/SAMPLES/pia-led-show-2000.a.
; The shared body must remain instruction-for-instruction identical. The
; `pia-led-show-check` target enforces that and builds the board-loadable S19.
; ---------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          PIA_LED_SHOW
                        XDEF            PIALED
                        XDEF            _END_CODE

; W65C21 RS1/RS0=00 at $7FA0 selects DDRA when CRA bit 2 is clear
; and the Port-A peripheral interface when CRA bit 2 is set.
PIA_PORTA_DDRA          EQU             $7FA0
PIA_CRA                 EQU             $7FA1

                        CODE

; BEGIN SHARED LED BODY
PIALED:                 BRA             RUN

RUN:                    LDA             PIA_CRA
                        PHA
                        ORA             #$04
                        STA             PIA_CRA
                        LDA             PIA_PORTA_DDRA
                        PHA
                        LDA             PIA_CRA
                        AND             #$FB
                        STA             PIA_CRA
                        LDA             PIA_PORTA_DDRA
                        PHA
                        LDA             #$FF
                        STA             PIA_PORTA_DDRA
                        LDA             PIA_CRA
                        ORA             #$04
                        STA             PIA_CRA
                        LDX             #$00

NEXT:                   LDA             PATTERNS,X
                        JSR             SHOW
                        INX
                        CPX             #$10
                        BNE             NEXT

                        LDA             PIA_CRA
                        AND             #$FB
                        STA             PIA_CRA
                        PLA
                        STA             PIA_PORTA_DDRA
                        LDA             PIA_CRA
                        ORA             #$04
                        STA             PIA_CRA
                        PLA
                        STA             PIA_PORTA_DDRA
                        PLA
                        STA             PIA_CRA
                        LDA             #$AC
                        SEC
                        RTS

SHOW:                   STA             PIA_PORTA_DDRA
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

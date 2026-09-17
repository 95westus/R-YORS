                        CHIP 65C02
                        ORG $6000
START:                  CLD
                        STZ $7E31
                        LDA #$40
                        STA $7E32
                        STZ $7E33
                        LDA #$70
                        STA $7E34
                        LDA #$01
                        STA $7E2F
                        JSR AP
                        BCC CAPTURE
                        LDX #$1F
COPY_CARD:              LDA $6200,X
                        STA $7D40,X
                        DEX
                        BPL COPY_CARD
                        STZ $6900
                        JSR $5000
CAPTURE:                STA $6800
                        PHP
                        PLA
                        STA $6801
                        LDA $6900
                        STA $6802
                        LDA $7E30
                        STA $6803
                        RTS
AP:                     JMP ($7E2D)
                        END

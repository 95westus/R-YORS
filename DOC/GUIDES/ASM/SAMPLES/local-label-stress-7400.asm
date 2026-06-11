; ASM V1 LOCAL LABEL STRESS. PASTE VIA ASM RT PASTE.
; RUN G 7400. D 7100 710C SHOULD SHOW THE ORACLE.

        ORG $7400

MAIN    BRA .A
        LDA #$E0
        STA $710F
        RTS
.A      LDA #$A1
        STA $7100
        BRA .B
.B      LDA #$B2
        STA $7101
        BRA .C
.C      LDA #$C3
        STA $7102
        BRA .D
.D      LDA #$D4
        STA $7103
        BRA .E
.E      LDA #$E5
        STA $7104
        BRA .F
.F      LDA #$F6
        STA $7105
        BRA .G
.G      LDA #$07
        STA $7106
        BRA .ABCDEFGHIJKLMN
.ABCDEFGHIJKLMN
        LDA #$8F
        STA $7107
        JSR ONE
        JSR TWO
        JSR ALT
        LDA #$5C
        STA $710C
        RTS

ONE     LDX #$00
        STZ $7108
.LOOP   INX
        STX $7108
        CPX #$03
        BNE .LOOP
        BRA .DONE
        LDA #$E1
        STA $7108
.DONE   RTS

TWO     LDY #$05
.LOOP   DEY
        STY $7109
        BNE .LOOP
        BRA .DONE
        LDA #$E2
        STA $7109
.DONE   LDA #$2A
        STA $710A
        RTS

ALT     STZ $710B
        BRA ?FWD
?LOOP   INC $710B
        LDA $710B
        CMP #$03
        BNE ?LOOP
        RTS
?FWD    BRA ?LOOP

        END

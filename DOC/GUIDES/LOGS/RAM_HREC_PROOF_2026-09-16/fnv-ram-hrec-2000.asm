; Private RAM-only HREC inspection proof. No dispatch and no bank switching.
; Caller initializes $7D40-$7D5F; request banks=0, RAM enable!=0,
; RAM windows=$08, format=$00. Wanted hash is at card+$07.
; C=1/A=$AC: unique shaped record; C=0/A=$D1 miss, $D2 duplicate,
; $D4 unsupported request. This is metadata, NOT execution authorization.
; Result: count +$0B, source +$0C=1, bank +$0D=$FF, window +$0E=3,
; record +$0F/10, entry +$18/19, extra +$1A/1B, kind +$1C.
; Supports K=1 inline, K=3 confirm+pointer, K=5 text+pointer.
; Pointer records require both pointers inside $3000-$3FFF and terminated
; printable high-bit text. Confirmation semantics are retained, not bypassed.
; Volatile A/X/Y, flags, ZP $A0-$A8. Foreground, Bank 3, decimal clear.
                        CHIP            65C02
                        ORG             $2000
RAM_HREC_FIND:
                        LDX             #$07
?CLEAR:                 STZ             $7D58,X
                        STZ             $7D4B,X
                        DEX
                        BPL             ?CLEAR
                        LDA             $7D40
                        ORA             $7D46
                        BNE             RAM_HREC_BAD
                        LDA             $7D44
                        BEQ             RAM_HREC_BAD
                        LDA             $7D45
                        CMP             #$08
                        BNE             RAM_HREC_BAD
                        STZ             $7E6A
                        STZ             $A0
                        LDA             #$30
                        STA             $A1
RAM_HREC_SCAN:
                        JSR             RAM_HREC_CANDIDATE
                        BCC             RAM_HREC_NEXT
                        LDA             $7D4B
                        CMP             #$02
                        BCS             RAM_HREC_NEXT
                        INC             $7D4B
RAM_HREC_NEXT:
                        INC             $A0
                        BNE             ?BOUND
                        INC             $A1
?BOUND:                 LDA             $A1
                        CMP             #$3F
                        BCC             RAM_HREC_SCAN
                        LDA             $A0
                        CMP             #$F8
                        BCC             RAM_HREC_SCAN
                        LDA             $7D4B
                        BEQ             RAM_HREC_MISS
                        CMP             #$01
                        BNE             RAM_HREC_DUP
; Revalidate the unique location before publishing metadata.
                        LDA             $7D4F
                        STA             $A0
                        LDA             $7D50
                        STA             $A1
                        JSR             RAM_HREC_CANDIDATE
                        BCC             RAM_HREC_MISS
                        LDA             #$01
                        STA             $7D4C
                        LDA             #$FF
                        STA             $7D4D
                        LDA             #$03
                        STA             $7D4E
                        LDX             #$03
?RESULT:                LDA             $A2,X
                        STA             $7D58,X
                        DEX
                        BPL             ?RESULT
                        LDA             $A8
                        STA             $7D5C
                        LDA             #$AC
                        SEC
                        RTS
RAM_HREC_BAD:           LDA             #$D4
                        BRA             RAM_HREC_FAIL
RAM_HREC_DUP:           LDA             #$D2
                        BRA             RAM_HREC_FAIL
RAM_HREC_MISS:          LDA             #$D1
RAM_HREC_FAIL:          STZ             $7D4F
                        STZ             $7D50
                        CLC
                        RTS

RAM_HREC_CANDIDATE:
                        LDY             #$00
                        LDA             ($A0),Y
                        CMP             #'F'
                        BNE             RAM_HREC_NO
                        INY
                        LDA             ($A0),Y
                        CMP             #'N'
                        BNE             RAM_HREC_NO
                        INY
                        LDA             ($A0),Y
                        CMP             #$D6
                        BNE             RAM_HREC_NO
                        INY
                        LDX             #$00
?HASH:                  LDA             ($A0),Y
                        CMP             $7D47,X
                        BNE             RAM_HREC_NO
                        INY
                        INX
                        CPX             #$04
                        BNE             ?HASH
                        LDA             ($A0),Y
                        STA             $A8
                        CMP             #$01
                        BEQ             RAM_HREC_INLINE
                        CMP             #$03
                        BEQ             RAM_HREC_POINTER
                        CMP             #$05
                        BEQ             RAM_HREC_POINTER
RAM_HREC_NO:            CLC
                        RTS
RAM_HREC_INLINE:        LDA             $A0
                        CLC
                        ADC             #$08
                        STA             $A2
                        LDA             $A1
                        ADC             #$00
                        STA             $A3
                        STZ             $A4
                        STZ             $A5
                        BRA             RAM_HREC_YES
RAM_HREC_POINTER:       LDA             $A1
                        CMP             #$3F
                        BNE             ?READ
                        LDA             $A0
                        CMP             #$F5
                        BCS             RAM_HREC_NO
?READ:                  LDY             #$08
                        LDX             #$00
?PTR:                   LDA             ($A0),Y
                        STA             $A2,X
                        INY
                        INX
                        CPX             #$04
                        BNE             ?PTR
                        LDA             $A3
                        JSR             RAM_HREC_IN_WINDOW
                        BCC             RAM_HREC_NO
                        LDA             $A5
                        JSR             RAM_HREC_IN_WINDOW
                        BCC             RAM_HREC_NO
                        LDA             $A4
                        STA             $A6
                        LDA             $A5
                        STA             $A7
?TEXT:                  LDY             #$00
                        LDA             ($A6),Y
                        TAX
                        AND             #$7F
                        CMP             #$20
                        BCC             RAM_HREC_NO
                        CMP             #$7F
                        BCS             RAM_HREC_NO
                        TXA
                        BMI             RAM_HREC_YES
                        INC             $A6
                        BNE             ?TEXT
                        INC             $A7
                        LDA             $A7
                        CMP             #$40
                        BCC             ?TEXT
                        CLC
                        RTS
RAM_HREC_YES:           LDA             $7D4B
                        BNE             ?DONE
                        LDA             $A0
                        STA             $7D4F
                        LDA             $A1
                        STA             $7D50
?DONE:                  SEC
                        RTS
RAM_HREC_IN_WINDOW:     CMP             #$30
                        BCC             ?NO
                        CMP             #$40
                        BCS             ?NO
                        SEC
                        RTS
?NO:                    CLC
                        RTS
RAM_HREC_END:
                        END

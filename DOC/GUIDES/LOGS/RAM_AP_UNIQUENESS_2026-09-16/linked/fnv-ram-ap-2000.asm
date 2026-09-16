; Private, image-pinned AP metadata proof. Loaded AM02 required.
; $7D40 card: format=1, stable name at $2F00 (length 1..31), requested
; banks/windows as installed finder; RAM enable nonzero requires windows=$08.
; Code $2000..., state $2E00-$2E0F, name $2F00-$2F1E, providers $3000-$3FFF.
; Staging $0A00-$19FF, AM02 $7000...; foreground Bank 3, decimal clear.
; No provider load/link/entry. C=1/A=$AC unique metadata; D1 miss, D2 duplicate,
; D4 request, D9 restore failure. +$18/19 entry OFFSET, +$1A/1B BODY length.
; Found source 1=RAM, 2=bank; bank=$FF for RAM; window=3 or sector high byte.
                        CHIP            65C02
                        INCLUDE         "image-addresses.inc"
                        ORG             $2000
RAM_AP_FIND:
                        JSR             RAM_AP_CLEAR
                        STZ             $7D4B
                        STZ             $2E00
                        LDA             $7D46
                        CMP             #$01
                        BNE             RAM_AP_BAD
                        LDA             $7D53
                        BNE             RAM_AP_BAD
                        LDA             $7D54
                        CMP             #$2F
                        BNE             RAM_AP_BAD
                        LDA             $7D55
                        BEQ             RAM_AP_BAD
                        CMP             #$20
                        BCS             RAM_AP_BAD
                        LDA             $7D44
                        STA             $2E01
                        BEQ             RAM_AP_BANKS
                        LDA             $7D45
                        CMP             #$08
                        BNE             RAM_AP_BAD
                        STZ             $7E6A
                        STZ             $2E02
                        LDA             #$30
                        STA             $2E03
RAM_AP_SCAN:
                        JSR             RAM_AP_CANDIDATE
                        BCC             RAM_AP_NEXT
                        LDA             $2E00
                        CMP             #$02
                        BCS             RAM_AP_NEXT
                        INC             $2E00
                        CMP             #$00
                        BNE             RAM_AP_NEXT
                        LDA             $2E02
                        STA             $2E04
                        LDA             $2E03
                        STA             $2E05
RAM_AP_NEXT:
                        INC             $2E02
                        BNE             ?BOUND
                        INC             $2E03
?BOUND:                 LDA             $2E03
                        CMP             #$3F
                        BCC             RAM_AP_SCAN
                        LDA             $2E02
                        CMP             #$FC
                        BCC             RAM_AP_SCAN
                        BRA             RAM_AP_BANKS
RAM_AP_BAD:             LDA             #$D4
                        JMP             RAM_AP_FAIL
RAM_AP_BANKS:
; Installed bank-only finder owns policy intersection and restores Bank 3.
                        STZ             $7D44
                        LDA             #<APMAN_SCOPE_CANDIDATE
                        STA             $7D56
                        LDA             #>APMAN_SCOPE_CANDIDATE
                        STA             $7D57
                        LDA             #$06
                        STA             $7E2F
                        JSR             RAM_AP_SERVICE
                        STA             $2E0A
                        PHP
                        LDA             $2E01
                        STA             $7D44
                        PLP
                        BCS             RAM_AP_COMBINE
                        LDA             $2E0A
                        CMP             #$D2
                        BEQ             RAM_AP_DUPLICATE
                        CMP             #$D1
                        BNE             RAM_AP_FAIL
; A failed unique revalidation is not an empty bank set.
                        LDA             $7D4B
                        BNE             RAM_AP_MISS
RAM_AP_COMBINE:
                        LDA             $7D4B
                        CLC
                        ADC             $2E00
                        BEQ             RAM_AP_MISS
                        CMP             #$02
                        BCS             RAM_AP_DUPLICATE
                        STA             $7D4B
                        LDA             $2E00
                        BEQ             RAM_AP_BANK_RESULT
                        LDA             $2E04
                        STA             $2E02
                        LDA             $2E05
                        STA             $2E03
                        JSR             RAM_AP_CANDIDATE
                        BCC             RAM_AP_MISS
                        LDA             #$01
                        STA             $7D4C
                        LDA             #$FF
                        STA             $7D4D
                        LDA             #$03
                        STA             $7D4E
                        LDA             $2E04
                        STA             $7D4F
                        LDA             $2E05
                        STA             $7D50
                        BRA             RAM_AP_METADATA
RAM_AP_BANK_RESULT:    LDA             #$02
                        STA             $7D4C
                        STZ             $7D4F
                        LDA             $7D4E
                        STA             $7D50
RAM_AP_METADATA:        LDY             #$01
                        LDA             ($AC),Y
                        STA             $7D58
                        INY
                        LDA             ($AC),Y
                        STA             $7D59
                        LDA             $7E39
                        STA             $7D5A
                        LDA             $7E3A
                        STA             $7D5B
                        LDA             #$AC
                        SEC
                        RTS
RAM_AP_DUPLICATE:       LDA             #$02
                        STA             $7D4B
                        LDA             #$D2
                        BRA             RAM_AP_FAIL
RAM_AP_MISS:            LDA             #$D1
RAM_AP_FAIL:            PHA
                        JSR             RAM_AP_CLEAR
                        PLA
                        CLC
                        RTS
RAM_AP_CLEAR:           LDX             #$07
?RESERVED:              STZ             $7D58,X
                        DEX
                        BPL             ?RESERVED
                        LDX             #$04
?LOCATION:              STZ             $7D4C,X
                        DEX
                        BPL             ?LOCATION
                        RTS
RAM_AP_SERVICE:         JMP             ($7E2D)

; Require the entire envelope to fit before copying or invoking resident PARSE.
RAM_AP_CANDIDATE:
                        LDA             $2E02
                        STA             $A0
                        LDA             $2E03
                        STA             $A1
                        LDY             #$00
                        LDA             ($A0),Y
                        CMP             #'A'
                        BEQ             ?SIGNATURE
                        CLC
                        RTS
?SIGNATURE:             INY
                        LDA             ($A0),Y
                        CMP             #'P'
                        BNE             RAM_AP_INVALID
                        INY
                        LDA             ($A0),Y
                        CMP             #$02
                        BNE             RAM_AP_INVALID
                        INY
                        LDA             ($A0),Y
                        STA             $A4
                        INY
                        LDA             ($A0),Y
                        STA             $A5
                        BNE             ?END
                        LDA             $A4
                        CMP             #$05
                        BCC             RAM_AP_INVALID
?END:                   LDA             $A0
                        CLC
                        ADC             $A4
                        TAX
                        LDA             $A1
                        ADC             $A5
                        BCS             RAM_AP_INVALID
                        CMP             #$40
                        BCC             ?COPY
                        BNE             RAM_AP_INVALID
                        CPX             #$00
                        BNE             RAM_AP_INVALID
?COPY:                  STZ             $A2
                        LDA             #$0A
                        STA             $A3
                        LDY             #$00
?BYTE:                  LDA             ($A0),Y
                        STA             ($A2),Y
                        INC             $A0
                        BNE             ?DEST
                        INC             $A1
?DEST:                  INC             $A2
                        BNE             ?COUNT
                        INC             $A3
?COUNT:                 LDA             $A4
                        BNE             ?DEC
                        DEC             $A5
?DEC:                   DEC             $A4
                        LDA             $A4
                        ORA             $A5
                        BNE             ?BYTE
                        STZ             $7E31
                        LDA             #$0A
                        STA             $7E32
                        STZ             $7E2F
                        JSR             RAM_AP_SERVICE
                        BCC             RAM_AP_INVALID
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCC             RAM_AP_INVALID
                        LDY             #$03
                        LDX             #$00
?HASH:                  LDA             ($AC),Y
                        CMP             $7D47,X
                        BNE             RAM_AP_INVALID
                        INY
                        INX
                        CPX             #$04
                        BNE             ?HASH
                        JMP             HIM_FNV_MATCH_NAME
RAM_AP_INVALID:         CLC
                        RTS
RAM_AP_END:
                        END

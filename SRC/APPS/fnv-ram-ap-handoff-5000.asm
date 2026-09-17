; Private, image-pinned safe AP handoff proof.
; Requires fnv-ram-ap-2000 at $2000, stable name at $2F00, optional provider
; at $3000-$3FFF, matching loaded manager overlay, and initialized $7D40 card.
; Repeats discovery, compares the exact unique result, loads/links only from
; the validated $0A00 stage into $2000, revalidates the canonical entry row,
; retires discovery state, then enters the child. Child RTS returns through
; this handoff to its caller; A and flags on successful return are child-owned.
; Pre-entry failure: C=0, A=status. No provider or flash writes.
                        CHIP            65C02
                        INCLUDE         "image-addresses.inc"

HIM_AP_OP               EQU             $7E2F
HIM_AP_STATUS           EQU             $7E30
HIM_AP_SRC_LO           EQU             $7E31
HIM_AP_SRC_HI           EQU             $7E32
HIM_AP_DST_LO           EQU             $7E33
HIM_AP_DST_HI           EQU             $7E34
HIM_AP_BODY_LEN_LO      EQU             $7E39
HIM_AP_BODY_LEN_HI      EQU             $7E3A
HIM_ASM_SESSION_RESUME  EQU             $7E6A

HANDOFF_STATE           EQU             $5400
HANDOFF_RESULT0         EQU             HANDOFF_STATE+$00
HANDOFF_RESULT1         EQU             HANDOFF_STATE+$01
HANDOFF_RESULT2         EQU             HANDOFF_STATE+$02
HANDOFF_RESULT3         EQU             HANDOFF_STATE+$03
HANDOFF_RESULT4         EQU             HANDOFF_STATE+$04
HANDOFF_RESULT5         EQU             HANDOFF_STATE+$05
HANDOFF_ENTRY_LO        EQU             HANDOFF_STATE+$06
HANDOFF_ENTRY_HI        EQU             HANDOFF_STATE+$07
HANDOFF_BODY_LO         EQU             HANDOFF_STATE+$08
HANDOFF_BODY_HI         EQU             HANDOFF_STATE+$09
HANDOFF_STATE_END       EQU             HANDOFF_STATE+$10

                        ORG             $5000
RAM_AP_HANDOFF:
                        CLD
                        STZ             HIM_ASM_SESSION_RESUME
                        JSR             RAM_AP_FIND
                        BCS             HANDOFF_FIRST_OK
                        JMP             HANDOFF_FAIL_A
HANDOFF_FIRST_OK:       CMP             #$AC
                        BEQ             ?FIRST_STATUS_OK
                        JMP             HANDOFF_NOT_FOUND
?FIRST_STATUS_OK:
                        LDA             $7D4B
                        CMP             #$01
                        BEQ             ?FIRST_COUNT_OK
                        JMP             HANDOFF_NOT_FOUND
?FIRST_COUNT_OK:
                        LDX             #$05
?SAVE_LOCATION:         LDA             $7D4B,X
                        STA             HANDOFF_RESULT0,X
                        DEX
                        BPL             ?SAVE_LOCATION
                        LDX             #$03
?SAVE_ENTRY:            LDA             $7D58,X
                        STA             HANDOFF_ENTRY_LO,X
                        DEX
                        BPL             ?SAVE_ENTRY
; A whole linked BODY must fit $2000-$2FFF; $3000 remains the provider floor.
                        LDA             HANDOFF_BODY_LO
                        ORA             HANDOFF_BODY_HI
                        BNE             ?BODY_NONZERO
                        JMP             HANDOFF_BAD_RANGE
?BODY_NONZERO:
                        LDA             HANDOFF_BODY_HI
                        CMP             #$10
                        BCC             HANDOFF_RANGE_OK
                        BEQ             ?BODY_HIGH_LIMIT
                        JMP             HANDOFF_BAD_RANGE
?BODY_HIGH_LIMIT:
                        LDA             HANDOFF_BODY_LO
                        BEQ             HANDOFF_RANGE_OK
                        JMP             HANDOFF_BAD_RANGE
HANDOFF_RANGE_OK:
; Re-run the full uniqueness search. It leaves the unique candidate in $0A00.
                        JSR             RAM_AP_FIND
                        BCS             ?SECOND_FOUND
                        JMP             HANDOFF_FAIL_A
?SECOND_FOUND:
                        CMP             #$AC
                        BEQ             ?SECOND_STATUS_OK
                        JMP             HANDOFF_NOT_FOUND
?SECOND_STATUS_OK:
                        LDX             #$05
?CHECK_LOCATION:        LDA             $7D4B,X
                        CMP             HANDOFF_RESULT0,X
                        BEQ             ?LOCATION_MATCH
                        JMP             HANDOFF_CHANGED
?LOCATION_MATCH:
                        DEX
                        BPL             ?CHECK_LOCATION
                        LDX             #$03
?CHECK_ENTRY:           LDA             $7D58,X
                        CMP             HANDOFF_ENTRY_LO,X
                        BEQ             ?ENTRY_MATCH
                        JMP             HANDOFF_CHANGED
?ENTRY_MATCH:
                        DEX
                        BPL             ?CHECK_ENTRY
; The second scan's validated staging copy is the only load source.
                        STZ             HIM_AP_SRC_LO
                        LDA             #$0A
                        STA             HIM_AP_SRC_HI
                        STZ             HIM_AP_DST_LO
                        LDA             #$20
                        STA             HIM_AP_DST_HI
                        LDA             #$01
                        STA             HIM_AP_OP
                        JSR             HANDOFF_AP_SERVICE
                        BCC             HANDOFF_AP_ERROR
                        CPX             #$00
                        BNE             HANDOFF_CHANGED
                        CPY             #$20
                        BNE             HANDOFF_CHANGED
                        LDA             HIM_AP_BODY_LEN_LO
                        CMP             HANDOFF_BODY_LO
                        BNE             HANDOFF_CHANGED
                        LDA             HIM_AP_BODY_LEN_HI
                        CMP             HANDOFF_BODY_HI
                        BNE             HANDOFF_CHANGED
; LOAD reparsed and linked the same stage. Recheck its public identity/offset.
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCC             HANDOFF_CHANGED
                        JSR             HIM_FNV_MATCH_NAME
                        BCC             HANDOFF_CHANGED
                        LDY             #$01
                        LDA             ($AC),Y
                        CMP             HANDOFF_ENTRY_LO
                        BNE             HANDOFF_CHANGED
                        INY
                        LDA             ($AC),Y
                        CMP             HANDOFF_ENTRY_HI
                        BNE             HANDOFF_CHANGED
; Re-prove offset < BODY and form the final address without wrap.
                        LDA             HANDOFF_ENTRY_HI
                        CMP             HANDOFF_BODY_HI
                        BCC             HANDOFF_ENTRY_IN_BODY
                        BNE             HANDOFF_BAD_RANGE
                        LDA             HANDOFF_ENTRY_LO
                        CMP             HANDOFF_BODY_LO
                        BCS             HANDOFF_BAD_RANGE
HANDOFF_ENTRY_IN_BODY:  LDA             HANDOFF_ENTRY_LO
                        CLC
                        ADC             #$00
                        STA             $A0
                        LDA             HANDOFF_ENTRY_HI
                        ADC             #$20
                        BCS             HANDOFF_BAD_RANGE
                        STA             $A1
                        JSR             HANDOFF_RETIRE
; Manufacture a normal subroutine return edge, then tail-enter the child.
                        LDA             #>(HANDOFF_CHILD_RETURN-1)
                        PHA
                        LDA             #<(HANDOFF_CHILD_RETURN-1)
                        PHA
                        JMP             ($A0)
HANDOFF_CHILD_RETURN:   RTS

HANDOFF_AP_ERROR:       LDA             HIM_AP_STATUS
                        BRA             HANDOFF_FAIL_A
HANDOFF_NOT_FOUND:
HANDOFF_CHANGED:        LDA             #$D1
                        BRA             HANDOFF_FAIL_A
HANDOFF_BAD_RANGE:      LDA             #$D4
HANDOFF_FAIL_A:         PHA
                        JSR             HANDOFF_RETIRE
                        PLA
                        CLC
                        RTS
HANDOFF_AP_SERVICE:     JMP             ($7E2D)

; Remove every discovery-owned byte before child entry or failure return.
; Keep $A0/$A1: they hold the final child entry on success.
HANDOFF_RETIRE:         LDX             #$1F
?CARD:                  STZ             $7D40,X
                        DEX
                        BPL             ?CARD
                        LDX             #$1F
?NAME:                  STZ             $2F00,X
                        DEX
                        BPL             ?NAME
                        STZ             $A2
                        LDA             #$0A
                        STA             $A3
                        LDX             #$10
?STAGE_PAGE:            LDY             #$00
                        LDA             #$00
?STAGE_BYTE:            STA             ($A2),Y
                        INY
                        BNE             ?STAGE_BYTE
                        INC             $A3
                        DEX
                        BNE             ?STAGE_PAGE
                        LDX             #(HANDOFF_STATE_END-HANDOFF_STATE-1)
?STATE:                 STZ             HANDOFF_STATE,X
                        DEX
                        BPL             ?STATE
                        RTS
RAM_AP_HANDOFF_END:
                        END

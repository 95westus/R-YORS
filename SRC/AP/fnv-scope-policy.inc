; Shared policy primitive; no bank-window access here.
; A = policy byte captured while B3 selected; X = requested banks.
; Writes only REQUEST/ALLOWED/EFFECTIVE. Returns A = effective mask;
; preserves X, clobbers Y/flags. No bank selection or configuration access.
FNV_SCOPE_POLICY:       STX             FNV_REQUEST_BANKS
                        TAY
                        AND             #$F8
                        CMP             #$A0
                        BNE             ?DISABLED
                        TYA
                        AND             #$07
                        BRA             ?MASK
?DISABLED:              LDA             #$00
?MASK:                  STA             FNV_ALLOWED_BANKS
                        TXA
                        AND             FNV_ALLOWED_BANKS
                        STA             FNV_EFFECTIVE_BANKS
                        RTS

; ASM v1 smoke test. Paste/load as ASM source.
; Run at $3000, then display $3100-$3110.
; Expected: $3100-$310F seed, $3110 checksum $0F.

ORG $3000

OUT EQU $3100
SUM EQU $3110
COUNT EQU 16

ASMTEST LDX #0
        STZ SUM
LOOP    LDA SEED,X
        STA OUT,X
        EOR SUM
        STA SUM
        INX
        CPX #COUNT
        BNE LOOP
        RTS

SEED    DC $52,$2D,$59,$4F,$52,$53,$20,$41
        DC $53,$4D,$20,$54,$45,$53,$54,$2E
END

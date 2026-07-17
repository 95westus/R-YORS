; ASM v1 smoke test. Paste/load as ASM source.
; Run at $6800, then display $6900-$6910.
; Expected: $6900-$690F seed, $6910 checksum $0F.

        ORG $6800

OUT EQU $6900
SUM EQU $6910
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

SEED    DB $52,$2D,$59,$4F,$52,$53,$20,$41
        DB $53,$4D,$20,$54,$45,$53,$54,$2E
        END

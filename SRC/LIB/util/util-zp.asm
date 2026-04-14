; -------------------------------------------------------------------------
; Zero-page shared reservations.
; -------------------------------------------------------------------------
;
; Purpose:
; - Provide globally linkable labels for reserved zero-page workspace.
; - Keep allocations centralized so modules do not collide.
;
; Naming:
; - `*_ADDR16` labels point at low byte (6502 pointer convention).
; - `*_LO` / `*_HI` aliases are provided for clarity.
;
; Allocation policy:
; - Update `ZP_MAP.md` whenever this file changes.
; -------------------------------------------------------------------------

                        XDEF            START_ADDR16
                        XDEF            START_ADDR16_LO
                        XDEF            START_ADDR16_HI
                        XDEF            START_ADDR_BANK
                        XDEF            END_ADDR16
                        XDEF            END_ADDR16_LO
                        XDEF            END_ADDR16_HI
                        XDEF            END_ADDR_BANK
                        XDEF            LEN_ADDR16
                        XDEF            LEN_ADDR16_LO
                        XDEF            LEN_ADDR16_HI
                        XDEF            LEN_ADDR_BANK

START_ADDR_BANK         EQU             $E0
END_ADDR_BANK           EQU             $E1
LEN_ADDR_BANK           EQU             $E2

START_ADDR16            EQU             $F0
START_ADDR16_LO         EQU             START_ADDR16
START_ADDR16_HI         EQU             START_ADDR16+1

END_ADDR16              EQU             $F2
END_ADDR16_LO           EQU             END_ADDR16
END_ADDR16_HI           EQU             END_ADDR16+1

LEN_ADDR16              EQU             $F4
LEN_ADDR16_LO           EQU             LEN_ADDR16
LEN_ADDR16_HI           EQU             LEN_ADDR16+1

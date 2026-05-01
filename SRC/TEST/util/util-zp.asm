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
                        XDEF            ZP_PARAM0_LO
                        XDEF            ZP_PARAM0_HI
                        XDEF            ZP_PARAM1_LO
                        XDEF            ZP_PARAM1_HI
                        XDEF            ZP_PARAM2_LO
                        XDEF            ZP_PARAM2_HI
                        XDEF            ZP_TMP_A
                        XDEF            ZP_SCRATCH0
                        XDEF            ZP_SHARED_PTR_LO
                        XDEF            ZP_SHARED_PTR_HI
                        XDEF            ZP_SHARED_LEN
                        XDEF            ZP_SHARED_B0
                        XDEF            ZP_SHARED_B1
                        XDEF            ZP_SHARED_FLAG0
                        XDEF            ZP_SHARED_TMP0
                        XDEF            ZP_SHARED_MODE
                        XDEF            ZP_EXT16_BASE
                        XDEF            ZP_EXT16_END
                        XDEF            ZP_EXT16_B0
                        XDEF            ZP_EXT16_B1
                        XDEF            ZP_EXT16_B2
                        XDEF            ZP_EXT16_B3
                        XDEF            ZP_EXT16_B4
                        XDEF            ZP_EXT16_B5
                        XDEF            ZP_EXT16_B6
                        XDEF            ZP_EXT16_B7
                        XDEF            ZP_EXT16_B8
                        XDEF            ZP_EXT16_B9
                        XDEF            ZP_EXT16_BA
                        XDEF            ZP_EXT16_BB
                        XDEF            ZP_EXT16_BC
                        XDEF            ZP_EXT16_BD
                        XDEF            ZP_EXT16_BE
                        XDEF            ZP_EXT16_BF
                        INCLUDE         "TEST/util/util-zp.inc"

                        END

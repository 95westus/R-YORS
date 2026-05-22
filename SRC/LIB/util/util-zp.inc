; -------------------------------------------------------------------------
; Shared zero-page map (authoritative EQU source for all modules).
; -------------------------------------------------------------------------

START_ADDR_BANK            EQU             $DF
END_ADDR_BANK              EQU             $DE
LEN_ADDR_BANK              EQU             $DD

; Reserved 16-byte expansion window for upcoming banked-ROM state/trampolines.
; Placed below active shared/backend ZP lanes.
ZP_EXT16_BASE              EQU             $CD
ZP_EXT16_END               EQU             $DC
ZP_EXT16_B0                EQU             ZP_EXT16_BASE+$00
ZP_EXT16_B1                EQU             ZP_EXT16_BASE+$01
ZP_EXT16_B2                EQU             ZP_EXT16_BASE+$02
ZP_EXT16_B3                EQU             ZP_EXT16_BASE+$03
ZP_EXT16_B4                EQU             ZP_EXT16_BASE+$04
ZP_EXT16_B5                EQU             ZP_EXT16_BASE+$05
ZP_EXT16_B6                EQU             ZP_EXT16_BASE+$06
ZP_EXT16_B7                EQU             ZP_EXT16_BASE+$07
ZP_EXT16_B8                EQU             ZP_EXT16_BASE+$08
ZP_EXT16_B9                EQU             ZP_EXT16_BASE+$09
ZP_EXT16_BA                EQU             ZP_EXT16_BASE+$0A
ZP_EXT16_BB                EQU             ZP_EXT16_BASE+$0B
ZP_EXT16_BC                EQU             ZP_EXT16_BASE+$0C
ZP_EXT16_BD                EQU             ZP_EXT16_BASE+$0D
ZP_EXT16_BE                EQU             ZP_EXT16_BASE+$0E
ZP_EXT16_BF                EQU             ZP_EXT16_BASE+$0F

START_ADDR16               EQU             $E0
START_ADDR16_LO            EQU             START_ADDR16
START_ADDR16_HI            EQU             START_ADDR16+1

END_ADDR16                 EQU             $E2
END_ADDR16_LO              EQU             END_ADDR16
END_ADDR16_HI              EQU             END_ADDR16+1

LEN_ADDR16                 EQU             $E4
LEN_ADDR16_LO              EQU             LEN_ADDR16
LEN_ADDR16_HI              EQU             LEN_ADDR16+1

; Shared compact ZP lanes grouped by function:
; - PARAM*: argument/working 16-bit lanes
; - TMP/SCRATCH: single-byte temporaries
; - SHARED_*: high-churn pointer/len/flags lane reused by non-reentrant helpers
ZP_PARAM0_LO               EQU             START_ADDR16_LO
ZP_PARAM0_HI               EQU             START_ADDR16_HI
ZP_PARAM1_LO               EQU             END_ADDR16_LO
ZP_PARAM1_HI               EQU             END_ADDR16_HI
ZP_PARAM2_LO               EQU             LEN_ADDR16_LO
ZP_PARAM2_HI               EQU             LEN_ADDR16_HI

ZP_TMP_A                   EQU             $E6
ZP_SCRATCH0                EQU             $E7
ZP_SHARED_PTR_LO           EQU             $E8
ZP_SHARED_PTR_HI           EQU             $E9
ZP_SHARED_LEN              EQU             $EA
ZP_SHARED_B0               EQU             $EB
ZP_SHARED_B1               EQU             $EC
ZP_SHARED_FLAG0            EQU             $ED
ZP_SHARED_TMP0             EQU             $EE
ZP_SHARED_MODE             EQU             $EF

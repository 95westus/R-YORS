; ----------------------------------------------------------------------------
; fnv1a-fold.asm
; Standalone W65C02S FNV-1a fold helpers.
;
; These routines do not hash strings and do not know HBSTR/CSTR/PSTR formats.
; Call the appropriate canonical 32-bit FNV-1a routine first, then pass X/Y as
; a pointer to four little-endian hash bytes: hash0, hash1, hash2, hash3.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          FNV1A_FOLD8_XY_A

                        XDEF            FNV1A_FOLD8_XY_A

FNV8_PTR_LO             EQU             $E8
FNV8_PTR_HI             EQU             $E9

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_FOLD8_XY_A  [HASH:632A38DD]
; IN : X/Y = pointer to hash0..hash3, little-endian
; OUT: A = folded hash8, C=1
;      X/Y preserved
; MEM : ZP: $E8-$E9; FIXED_RAM: none.
; ----------------------------------------------------------------------------
FNV1A_FOLD8_XY_A:
                        STX             FNV8_PTR_LO
                        STY             FNV8_PTR_HI
                        PHY
                        LDY             #$00
                        LDA             (FNV8_PTR_LO),Y
                        INY
                        EOR             (FNV8_PTR_LO),Y
                        INY
                        EOR             (FNV8_PTR_LO),Y
                        INY
                        EOR             (FNV8_PTR_LO),Y
                        PLY
                        SEC
                        RTS
                        ENDMOD

                        MODULE          FNV1A_FOLD16_XY_A8

                        XDEF            FNV1A_FOLD16_XY_A8

FNV16_PTR_LO            EQU             $E8
FNV16_PTR_HI            EQU             $E9
FNV16_LO                EQU             $EB
FNV16_HI                EQU             $EC

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_FOLD16_XY_A8  [HASH:E52B90E6]
; IN : X/Y = pointer to hash0..hash3, little-endian
; OUT: X = folded hash16 low byte
;      Y = folded hash16 high byte
;      A = folded hash8, C=1
; MEM : ZP: $E8-$E9,$EB-$EC; FIXED_RAM: none.
; ----------------------------------------------------------------------------
FNV1A_FOLD16_XY_A8:
                        STX             FNV16_PTR_LO
                        STY             FNV16_PTR_HI
                        LDY             #$00
                        LDA             (FNV16_PTR_LO),Y
                        INY
                        INY
                        EOR             (FNV16_PTR_LO),Y
                        STA             FNV16_LO
                        DEY
                        LDA             (FNV16_PTR_LO),Y
                        INY
                        INY
                        EOR             (FNV16_PTR_LO),Y
                        STA             FNV16_HI
                        EOR             FNV16_LO
                        LDX             FNV16_LO
                        LDY             FNV16_HI
                        SEC
                        RTS
                        ENDMOD

                        MODULE          FNV1A_FOLD32_XY

                        XDEF            FNV1A_FOLD32_XY

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_FOLD32_XY  [HASH:9F48B1D8]
; IN : X/Y = pointer to hash0..hash3, little-endian
; OUT: X/Y unchanged, C=1
; MEM : ZP: none; FIXED_RAM: none.
; NOTE: Identity helper for width-dispatch tables that select full hash32.
; ----------------------------------------------------------------------------
FNV1A_FOLD32_XY:
                        SEC
                        RTS
                        ENDMOD

                        END

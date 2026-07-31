; ----------------------------------------------------------------------------
; str8-jump-eq.inc
; Shared resident/worker constants for non-destructive J0-J2 handoff.
; ----------------------------------------------------------------------------

STR8_COPY_MODE_JUMP_BANK EQU           $08

STR8_JUMP_BANK          EQU             $1FF2
STR8_JUMP_VEC_LO        EQU             $1FF3
STR8_JUMP_VEC_HI        EQU             $1FF4
STR8_JUMP_STATUS        EQU             $1FF5

; Published Bank Jump Record at the tail of the STR8 Recovery State Capsule.
; The worker commits this only after bank selection and vector validation,
; immediately before the final jump. HIMON cold clear preserves a valid row.
STR8_BANK_JUMP_SIG0     EQU             $1FFD
STR8_BANK_JUMP_SIG1     EQU             $1FFE
STR8_BANK_LAST_JUMP     EQU             $1FFF

STR8_BANK_JUMP_SIG0_VALUE EQU           'B'
STR8_BANK_JUMP_SIG1_VALUE EQU           'J'
STR8_BANK_NONE          EQU             $FF

STR8_JUMP_STATUS_NONE   EQU             $00
STR8_JUMP_STATUS_BANK   EQU             $01
STR8_JUMP_STATUS_LOW    EQU             $02
STR8_JUMP_STATUS_ERASED EQU             $03
STR8_JUMP_STATUS_GO     EQU             $80

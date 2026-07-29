; ----------------------------------------------------------------------------
; str8-jump-eq.inc
; Shared resident/worker constants for non-destructive J0-J2 handoff.
; ----------------------------------------------------------------------------

STR8_COPY_MODE_JUMP_BANK EQU           $08

STR8_JUMP_BANK          EQU             $1FF2
STR8_JUMP_VEC_LO        EQU             $1FF3
STR8_JUMP_VEC_HI        EQU             $1FF4
STR8_JUMP_STATUS        EQU             $1FF5

STR8_JUMP_STATUS_NONE   EQU             $00
STR8_JUMP_STATUS_BANK   EQU             $01
STR8_JUMP_STATUS_LOW    EQU             $02
STR8_JUMP_STATUS_ERASED EQU             $03
STR8_JUMP_STATUS_GO     EQU             $80

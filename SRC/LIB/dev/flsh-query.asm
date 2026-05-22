; ----------------------------------------------------------------------------
; flsh-query.asm
; Banked flash read/query helpers for STR8-style 4K windows.
; - Calls the raw bank latch driver.
; - No flash erase/write commands.
; ----------------------------------------------------------------------------

                        MODULE          FLSH_QUERY

                        XDEF            FLSH_WINDOW_ERASED_AX

                        XREF            FLSH_BANK_SELECT_A
                        XREF            FLSH_BANK_SELECT_3

FLSH_Q_PTR_LO           EQU             $CD
FLSH_Q_PTR_HI           EQU             $CE
FLSH_Q_WINDOW_HI        EQU             $CF
FLSH_Q_BANK             EQU             $D0

                        CODE
; ----------------------------------------------------------------------------
; ROUTINE: FLSH_WINDOW_ERASED_AX  [HASH:8EE55BC0]
; TIER: TEST
; TAGS: FLASH, BANK, WINDOW, ERASED-CHECK, READ-ONLY, CARRY-STATUS
; MEM : ZP: ZP_EXT16_B0..B3.
; PURPOSE: Check whether a 4K window in a selected flash bank is all $FF.
; IN : A = bank number 0-3, X = window number 0-7
;      window 0=$8000-$8FFF ... window 7=$F000-$FFFF
; OUT: C = 1 if every byte in the window is $FF
;      C = 0 if bank/window is out of range or any byte is not $FF
;      A/X/Y clobbered; bank 3 selected before return
; EXCEPTIONS/NOTES:
; - Read-only query; it does not issue flash command sequences.
; - Caller must run from RAM or another bank-stable execution region when
;   checking a bank other than the currently executing bank.
; - Restores hardware bank 3 on all returns so callers do not remain parked in
;   a non-boot bank after scanning vectors or code bytes.
; ----------------------------------------------------------------------------
FLSH_WINDOW_ERASED_AX:
                        CMP             #$04
                        BCS             ?BAD
                        CPX             #$08
                        BCS             ?BAD
                        STA             FLSH_Q_BANK
                        TXA
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             #$80
                        STA             FLSH_Q_WINDOW_HI
                        STA             FLSH_Q_PTR_HI
                        STZ             FLSH_Q_PTR_LO

                        LDA             FLSH_Q_BANK
                        JSR             FLSH_BANK_SELECT_A
?LOOP:                 LDY             #$00
                        LDA             (FLSH_Q_PTR_LO),Y
                        CMP             #$FF
                        BNE             ?NOT_ERASED
                        INC             FLSH_Q_PTR_LO
                        BNE             ?LOOP
                        INC             FLSH_Q_PTR_HI
                        LDA             FLSH_Q_PTR_HI
                        SEC
                        SBC             FLSH_Q_WINDOW_HI
                        CMP             #$10
                        BNE             ?LOOP
                        JSR             FLSH_BANK_SELECT_3
                        SEC
                        RTS
?NOT_ERASED:           JSR             FLSH_BANK_SELECT_3
                        CLC
                        RTS
?BAD:                   JSR             FLSH_BANK_SELECT_3
                        CLC
                        RTS

                        END

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WDC MODULE/ENDMOD guidelines for this file:
; - Use MODULE/ENDMOD around each logical unit that should export symbols.
; - XDEF = symbols this module provides to other modules.
; - XREF = symbols that come from outside this module.
; - Hardware register/constants can be local EQUs inside a module; avoid
;   repeating the same global symbol name in multiple modules unless using
;   unique names, because wdclib tracks symbols in a global module dictionary.
; - make rom rebuilds only when source modules changed; make/test links
;   test.obj against rom.lib.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-common.asm  -> pure utility routines, no hardware access.
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
;
; ZP ALLOCATION POLICY
; - See ZP_MAP.md for reserved/scratch ownership.
; - Add/update labels in ZP_MAP.md before claiming new ZP bytes.
;
; THIS FILE: L0 DRIVER.
; - May be called by L1+.
; - Must not call higher layers.
; Naming convention:
; - L0 driver exports use `PIN_<DEVICE>_*` (this file: `PIN_FTDI_*`).
;
; PLATINUM CODE POLICY:
; - This file is designated PLATINUM.
; - Exported `PIN_FTDI_*` behavioral contracts are frozen.
; - Allowed changes: bug fixes, timing-safe hardware fixes, and docs/comments.
; - Any intentional contract change must update `SRC/PLATINUM_CODE.md`.
; -------------------------------------------------------------------------


                        MODULE          PIN_FTDI_INIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_INIT  [RHID:4238]
; TIER: PLATINUM (behavior frozen)
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Initialize VIA pins for FTDI FIFO interface.
; IN : A = preserved
; OUT: FTDI control/data direction registers configured, A preserved
; EXCEPTIONS/NOTES:
; - Assumes VIA base addresses and pin mapping constants in this module.
; - X/Y unchanged by implementation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_INIT

FTDI_INIT_VIA_CTRL      EQU             $7FE0
FTDI_INIT_VIA_DDRB      EQU             $7FE2
FTDI_INIT_VIA_DDRA      EQU             $7FE3
FTDI_INIT_PN_CTRL_INIT  EQU             $0C
FTDI_INIT_PN_CTRL_INIT_DDR EQU          $0C

PIN_FTDI_INIT:
?INIT:                  PHA
                        LDA             #FTDI_INIT_PN_CTRL_INIT
                        STA             FTDI_INIT_VIA_CTRL
                        LDA             #FTDI_INIT_PN_CTRL_INIT_DDR
                        STA             FTDI_INIT_VIA_DDRB
                        STZ             FTDI_INIT_VIA_DDRA
                        PLA
                        RTS
                        ENDMOD


                        MODULE          PIN_FTDI_POLL_RX_READY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_POLL_RX_READY  [RHID:55EA]
; TIER: PLATINUM (behavior frozen)
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check FTDI RXF# line for pending receive byte.
; IN : none (A preserved)
; OUT: C = 1 if byte ready, C = 0 if not ready, A preserved
; EXCEPTIONS/NOTES:
; - Reads active-low RXF# bit from VIA control register.
; - X/Y unchanged by implementation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_POLL_RX_READY

FTDI_BR_VIA_CTRL        EQU             $7FE0
FTDI_BR_PN_RXF          EQU             $02

PIN_FTDI_POLL_RX_READY:
                        PHA
                        LDA             FTDI_BR_VIA_CTRL
                        AND             #FTDI_BR_PN_RXF
                        BNE             ?NO
?YES:                   SEC                                     ; THIS IS WHERE YES COUNTER GOES
                        PLA
                        RTS
?NO:                    CLC                                     ; THIS IS WHERE NO COUNTER GOES
                        PLA
                        RTS
                        ENDMOD


                        MODULE          PIN_FTDI_READ_BYTE_NONBLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_READ_BYTE_NONBLOCK  [RHID:755B]
; TIER: PLATINUM (behavior frozen)
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking read of one byte from FTDI FIFO.
; IN : none
; OUT: C = 1 and A = byte when ready; C = 0 and A = 0 when not ready
; EXCEPTIONS/NOTES:
; - Temporarily asserts RD# to sample FIFO data bus.
; - X/Y unchanged by implementation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_READ_BYTE_NONBLOCK
FTDI_RBNB_VIA_DDRA      EQU             $7FE3
FTDI_RBNB_VIA_CTRL      EQU             $7FE0
FTDI_RBNB_VIA_DATA      EQU             $7FE1
FTDI_RBNB_PN_RXF        EQU             $02
FTDI_RBNB_PN_RD         EQU             $08

PIN_FTDI_READ_BYTE_NONBLOCK:
                        STZ             FTDI_RBNB_VIA_DDRA
                        LDA             #FTDI_RBNB_PN_RXF
                        BIT             FTDI_RBNB_VIA_CTRL
                        BNE             ?NO_BYTE_READY
?BYTE_READY:            LDA             #FTDI_RBNB_PN_RD
                        TRB             FTDI_RBNB_VIA_CTRL
                        NOP
                        NOP
                        LDA             FTDI_RBNB_VIA_DATA
                        PHA
                        LDA             #FTDI_RBNB_PN_RD
                        TSB             FTDI_RBNB_VIA_CTRL
                        PLA
                        SEC
                        RTS
?NO_BYTE_READY:         LDA             #$00
                        CLC
                        RTS
                        ENDMOD


                        MODULE          PIN_FTDI_WRITE_BYTE_NONBLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_WRITE_BYTE_NONBLOCK  [RHID:6142]
; TIER: PLATINUM (behavior frozen)
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking write of one byte to FTDI FIFO with timeout spin.
; IN : A = byte to transmit
; OUT: C = 1 on success; C = 0 on timeout, A preserved
; EXCEPTIONS/NOTES:
; - On timeout, X reaches `FTDI_WB_WR_SPIN_LIMIT`.
; - X is clobbered by local spin counter; Y unchanged.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_WRITE_BYTE_NONBLOCK
FTDI_WB_VIA_DDRA        EQU             $7FE3
FTDI_WB_VIA_DATA        EQU             $7FE1
FTDI_WB_VIA_CTRL        EQU             $7FE0
FTDI_WB_PN_TXE          EQU             $01
FTDI_WB_PN_WR           EQU             $04
FTDI_WB_WR_SPIN_LIMIT   EQU             $30; $50

PIN_FTDI_WRITE_BYTE_NONBLOCK:
                        PHA
                        SEC
                        STZ             FTDI_WB_VIA_DDRA
                        STA             FTDI_WB_VIA_DATA
                        nop
                        nop
                        ldx             #$00
                        LDA             #FTDI_WB_PN_TXE
?TX_SPIN:               BIT             FTDI_WB_VIA_CTRL
                        BEQ             ?WR_STROBE
                        inx
                        cpx             #FTDI_WB_WR_SPIN_LIMIT
                        bne             ?TX_SPIN
                        clc
                        bra             ?WR_DEASSERT
?WR_STROBE:             LDA             #FTDI_WB_PN_WR
                        TSB             FTDI_WB_VIA_CTRL
                        LDA             #$FF
                        STA             FTDI_WB_VIA_DDRA
                        NOP
                        NOP
?WR_DEASSERT:           LDA             #FTDI_WB_PN_WR
                        TRB             FTDI_WB_VIA_CTRL
                        STZ             FTDI_WB_VIA_DDRA
                        PLA
                        RTS
                        ENDMOD


                        MODULE          PIN_FTDI_CHECK_ENUMERATED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_CHECK_ENUMERATED  [RHID:6F9E]
; TIER: PLATINUM (behavior frozen)
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check whether FTDI USB FIFO reports host enumeration via PWE#.
; IN : none
; OUT: C = 1 and A = 1 when enumerated; C = 0 and A = 0 when not enumerated
; EXCEPTIONS/NOTES:
; - PWE# is active-low and read directly from VIA control register.
; - Returned A value is currently placeholder device-status encoding.
; - X/Y unchanged by implementation.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_CHECK_ENUMERATED

FTDI_ISE_PN_PWE         EQU             $20
FTDI_ISE_VIA_CTRL       EQU             $7FE0

PIN_FTDI_CHECK_ENUMERATED:
                        LDA             #FTDI_ISE_PN_PWE        ; mask for PB5 (PWE# bit)
                        BIT             FTDI_ISE_VIA_CTRL       ; test bit 5
                        BEQ             ?ENUMERATED             ; if Z=1, bit 5 is clear (PWE# low = enumerated)
                        ; else PWE# is high (not enumerated)
                        lda             #$00                    ; not enumerated: A = 0, carry clear
                        clc
                        rts
?ENUMERATED:
                        lda             #$01                    ; enumerated: A = device type/status (placeholder)
                        sec                                     ; carry set
                        rts
                        ENDMOD



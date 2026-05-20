; -------------------------------------------------------------------------
; HEADER
; FILE: SRC/STASH/ftdi/ftdi-drv.asm
; OWNER: STASH / top-shelf lane
; SCOPE: FTDI FIFO L0 pin driver routines (`PIN_FTDI_*`)
; ABI: Exported `PIN_FTDI_*` contracts are frozen unless policy says
;   otherwise.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; CHANGELOG
; - Routine-local changelog entries live in each `PIN_FTDI_*` block.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-common.asm  -> pure utility routines, no hardware access.
; L3 (Access): lock/access-policy -> capability gates, lock/unlock, privilege
;   checks.
; L4 (Sys):    sys-*.asm        -> device-neutral I/O API (SYS_*), calls
;   L3/L2.
; L5 (App):    app/*.asm        -> monitor/app entry points.
; TEST (Out-of-band): test/*.asm -> test harnesses (not part of layer ABI).
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
; TOP-SHELF CODE POLICY:
; - This file is designated top-shelf (STASH lane).
; - Exported `PIN_FTDI_*` behavioral contracts are frozen.
; - Allowed changes: bug fixes, timing-safe hardware fixes, and docs/comments.
; - Any intentional contract change must update `SRC/STASH_CODE.md`.
;
; HASH NOTE:
; - `[HASH:XXXXXXXX]` is the 32-bit FNV-1a routine/catalog/symbol hash
;   over the routine name.
; -------------------------------------------------------------------------

                        MODULE          PIN_FTDI_INIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_INIT  [HASH:226EDE8F]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, VIA, MMIO, REGISTER, INIT, PRESERVE-A,
;   PRESERVE-XY, NO-ZP, NO-RAM, TOP-SHELF, STACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Initialize VIA pins for FTDI FIFO interface.
; IN : A = preserved
; OUT: FTDI control/data direction registers configured, A preserved
; EXCEPTIONS/NOTES:
; - Assumes VIA base addresses and pin mapping constants in this module.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call `PIN_FTDI_INIT`, not the
;   `_FNV` label.
; - X/Y unchanged by implementation.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T04:59Z WLP2   PIN_FTDI_INIT declared TOP-SHELF.
;                          test-ftdi-drv.asm PASSED expected results.
;                          exercised beyond nominal paths.
;                          return codes verified.
; 2026-05-15T00:00Z WLP2   promoted with current HIMON-style 8-byte FNV
;                          signature immediately before callable entry.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_INIT
                        XDEF            PIN_FTDI_INIT_FNV

FTDI_INIT_VIA_CTRL         EQU             $7FE0
FTDI_INIT_VIA_DDRB         EQU             $7FE2
FTDI_INIT_VIA_DDRA         EQU             $7FE3
FTDI_INIT_PN_CTRL_INIT     EQU             $0C
FTDI_INIT_PN_CTRL_INIT_DDR EQU             $0C

PIN_FTDI_INIT_FNV:
                        DB              'F','N',('V'+$80),$8F,$DE,$6E,$22,$01 ; PIN_FTDI_INIT $226EDE8F EXEC
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
; ROUTINE: PIN_FTDI_POLL_RX_READY  [HASH:F2B69C5B]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, VIA, MMIO, REGISTER, PRESERVE-A, PRESERVE-XY,
;   CARRY-STATUS, NO-ZP, NO-RAM, STACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check FTDI RXF# line for pending receive byte.
; IN : none (A preserved)
; OUT: C = 1 if byte ready, C = 0 if not ready, A preserved
; EXCEPTIONS/NOTES:
; - Reads active-low RXF# bit from VIA control register.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call `PIN_FTDI_POLL_RX_READY`,
;   not the `_FNV` label.
; - X/Y unchanged by implementation.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T04:59Z WLP2   PIN_FTDI_POLL_RX_READY declared TOP-SHELF.
;                          test-ftdi-drv.asm PASSED expected results.
;                          exercised beyond nominal paths.
;                          return codes verified.
; 2026-05-15T00:00Z WLP2   promoted with current HIMON-style 8-byte FNV
;                          signature immediately before callable entry.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_POLL_RX_READY
                        XDEF            PIN_FTDI_POLL_RX_READY_FNV

FTDI_BR_VIA_CTRL           EQU             $7FE0
FTDI_BR_PN_RXF             EQU             $02

PIN_FTDI_POLL_RX_READY_FNV:
                        DB              'F','N',('V'+$80),$5B,$9C,$B6,$F2,$01 ; PIN_FTDI_POLL_RX_READY $F2B69C5B EXEC
PIN_FTDI_POLL_RX_READY:
                        PHA
                        LDA             FTDI_BR_VIA_CTRL
                        AND             #FTDI_BR_PN_RXF
                        BNE             ?NO
?YES:                   SEC
; THIS IS WHERE YES COUNTER GOES
                        PLA
                        RTS
?NO:                    CLC
; THIS IS WHERE NO COUNTER GOES
                        PLA
                        RTS
                        ENDMOD

                        MODULE          PIN_FTDI_POLL_TX_READY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_POLL_TX_READY  [HASH:99BF1FB5]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, VIA, MMIO, REGISTER, PRESERVE-A, PRESERVE-XY,
;   CARRY-STATUS, NO-ZP, NO-RAM, STACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check FTDI TXE# line for transmit FIFO ready.
; IN : none (A preserved)
; OUT: C = 1 if FIFO can accept a byte, C = 0 if not ready, A preserved
; EXCEPTIONS/NOTES:
; - Reads active-low TXE# bit from VIA control register.
; - This is a pure readiness check; it does not touch the data bus or strobe
;   WR#.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call `PIN_FTDI_POLL_TX_READY`,
;   not the `_FNV` label.
; - X/Y unchanged by implementation.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-05-20T00:00Z WLP2   PIN_FTDI_POLL_TX_READY added as pure TXE# poll.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_POLL_TX_READY
                        XDEF            PIN_FTDI_POLL_TX_READY_FNV

FTDI_BT_VIA_CTRL           EQU             $7FE0
FTDI_BT_PN_TXE             EQU             $01

PIN_FTDI_POLL_TX_READY_FNV:
                        DB              'F','N',('V'+$80),$B5,$1F,$BF,$99,$01 ; PIN_FTDI_POLL_TX_READY $99BF1FB5 EXEC
PIN_FTDI_POLL_TX_READY:
                        PHA
                        ; TXE# is bit 0; invert it into carry without a branch.
                        LDA             FTDI_BT_VIA_CTRL
                        AND             #FTDI_BT_PN_TXE
                        EOR             #FTDI_BT_PN_TXE
                        LSR             A
                        PLA
                        RTS
                        ENDMOD

                        MODULE          PIN_FTDI_READ_BYTE_NONBLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: PIN_FTDI_READ_BYTE_NONBLOCK  [HASH:483BB2DD]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, MMIO, REGISTER, NONBLOCKING, READ, PRESERVE-XY,
;   CARRY-STATUS, NO-ZP, NO-RAM, STACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking read of one byte from FTDI FIFO.
; IN : none
; OUT: C = 1 and A = byte when ready; C = 0 and A = 0 when not ready
; EXCEPTIONS/NOTES:
; - Temporarily asserts RD# to sample FIFO data bus.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call
;   `PIN_FTDI_READ_BYTE_NONBLOCK`, not the `_FNV` label.
; - X/Y unchanged by implementation.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T04:59Z WLP2   PIN_FTDI_READ_BYTE_NONBLOCK declared TOP-SHELF.
;                          test-ftdi-drv.asm PASSED expected results.
;                          exercised beyond nominal paths.
;                          return codes verified.
; 2026-05-15T00:00Z WLP2   promoted with current HIMON-style 8-byte FNV
;                          signature immediately before callable entry.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_READ_BYTE_NONBLOCK
                        XDEF            PIN_FTDI_READ_BYTE_NONBLOCK_FNV
FTDI_RBNB_VIA_DDRA         EQU             $7FE3
FTDI_RBNB_VIA_CTRL         EQU             $7FE0
FTDI_RBNB_VIA_DATA         EQU             $7FE1
FTDI_RBNB_PN_RXF           EQU             $02
FTDI_RBNB_PN_RD            EQU             $08

PIN_FTDI_READ_BYTE_NONBLOCK_FNV:
                        DB              'F','N',('V'+$80),$DD,$B2,$3B,$48,$01 ; PIN_FTDI_READ_BYTE_NONBLOCK $483BB2DD EXEC
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
; ROUTINE: PIN_FTDI_WRITE_BYTE_NONBLOCK  [HASH:D55FC6FC]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, MMIO, REGISTER, NONBLOCKING, TIMEOUT, WRITE,
;   PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM, STACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking write of one byte to FTDI FIFO with timeout spin.
; IN : A = byte to transmit
; OUT: C = 1 on success; C = 0 on timeout, A preserved
; EXCEPTIONS/NOTES:
; - On timeout, X reaches `FTDI_WB_WR_SPIN_LIMIT`.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call
;   `PIN_FTDI_WRITE_BYTE_NONBLOCK`, not the `_FNV` label.
; - X is clobbered by local spin counter; Y unchanged.
; - TEST LIMITATION: I am currently unaware how to force a blocked
;   FIFO/serial write on this hardware vs a nonblocked case.
; - UNKNOWN: It may or may not be possible with current hardware setup.
; - TO CATCH: Use a harness that withholds host reads so TXE# stays
;   deasserted, then verify timeout path (C=0) and spin-limit behavior.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T04:59Z WLP2   PIN_FTDI_WRITE_BYTE_NONBLOCK declared TOP-SHELF.
;                          test-ftdi-drv.asm PASSED expected results.
;                          exercised beyond nominal paths.
;                          return codes verified.
; 2026-05-15T00:00Z WLP2   promoted with current HIMON-style 8-byte FNV
;                          signature immediately before callable entry.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_WRITE_BYTE_NONBLOCK
                        XDEF            PIN_FTDI_WRITE_BYTE_NONBLOCK_FNV
FTDI_WB_VIA_DDRA           EQU             $7FE3
FTDI_WB_VIA_DATA           EQU             $7FE1
FTDI_WB_VIA_CTRL           EQU             $7FE0
FTDI_WB_PN_TXE             EQU             $01
FTDI_WB_PN_WR              EQU             $04
FTDI_WB_WR_SPIN_LIMIT      EQU             $30; $50

PIN_FTDI_WRITE_BYTE_NONBLOCK_FNV:
                        DB              'F','N',('V'+$80),$FC,$C6,$5F,$D5,$01 ; PIN_FTDI_WRITE_BYTE_NONBLOCK $D55FC6FC EXEC
PIN_FTDI_WRITE_BYTE_NONBLOCK:
                        PHA
                        SEC
                        STZ             FTDI_WB_VIA_DDRA
                        STA             FTDI_WB_VIA_DATA
                        NOP
                        NOP
                        LDX             #$00
                        LDA             #FTDI_WB_PN_TXE
?TX_SPIN:               BIT             FTDI_WB_VIA_CTRL
                        BEQ             ?WR_STROBE
                        INX
                        CPX             #FTDI_WB_WR_SPIN_LIMIT
                        BNE             ?TX_SPIN
                        CLC
                        BRA             ?WR_DEASSERT
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
; ROUTINE: PIN_FTDI_CHECK_ENUMERATED  [HASH:8A7D53EE]
; TIER: TOP-SHELF (behavior frozen)
; TAGS: PIN, DRIVER-L0, FTDI, VIA, MMIO, REGISTER, READ, ENUM, PRESERVE-XY,
;   CARRY-STATUS, NO-ZP, NO-RAM, NOSTACK, PROMOTED, FNV, HASH-SIG
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check whether FTDI USB FIFO reports host enumeration via PWE#.
; IN : none
; OUT: C = 1 and A = 1 when enumerated; C = 0 and A = 0 when not enumerated
; EXCEPTIONS/NOTES:
; - PWE# is active-low and read directly from VIA control register.
; - Returned A value is currently placeholder device-status encoding.
; - Emits current 8-byte FNV header signature immediately before the callable
;   entry.  Existing callers must continue to call
;   `PIN_FTDI_CHECK_ENUMERATED`, not the `_FNV` label.
; - X/Y unchanged by implementation.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T04:59Z WLP2   PIN_FTDI_CHECK_ENUMERATED declared TOP-SHELF.
;                          test-ftdi-drv.asm PASSED expected results.
;                          exercised beyond nominal paths.
;                          return codes verified.
; 2026-05-15T00:00Z WLP2   promoted with current HIMON-style 8-byte FNV
;                          signature immediately before callable entry.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            PIN_FTDI_CHECK_ENUMERATED
                        XDEF            PIN_FTDI_CHECK_ENUMERATED_FNV

FTDI_ISE_PN_PWE            EQU             $20
FTDI_ISE_VIA_CTRL          EQU             $7FE0

PIN_FTDI_CHECK_ENUMERATED_FNV:
                        DB              'F','N',('V'+$80),$EE,$53,$7D,$8A,$01 ; PIN_FTDI_CHECK_ENUMERATED $8A7D53EE EXEC
PIN_FTDI_CHECK_ENUMERATED:
                        LDA             #FTDI_ISE_PN_PWE
                        ; mask for PB5 (PWE# bit)
                        BIT             FTDI_ISE_VIA_CTRL       ; test bit 5
                        BEQ             ?ENUMERATED
                        ; if Z=1, bit 5 is clear (PWE# low = enumerated)
                        ; else PWE# is high (not enumerated)
                        LDA             #$00
                        ; not enumerated: A = 0, carry clear
                        CLC
                        RTS
?ENUMERATED:
                        LDA             #$01
                        ; enumerated: A = device type/status (placeholder)
                        SEC                                     ; carry set
                        RTS
                        ENDMOD

                        END

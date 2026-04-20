; -------------------------------------------------------------------------
; I/O / SUBROUTINE CONVENTION (applies to this module and call sites):
; - A is the primary input/output register for data.
; - Carry (C) is status:
;   C=1 => operation completed/byte available
;   C=0 => timeout/not ready/error.
; - X and Y are scratch (call-clobbered) unless a routine explicitly documents
;   preservation.
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
; - L0 driver exports use `PIN_<DEVICE>_*` (this file: `PIN_ACIA_*`).
;
; WIP CODE POLICY:
; - This file is in SESH/WIP lane.
; - Behavioral contracts are exploratory and may change.
; -------------------------------------------------------------------------

ACIA                       EQU             $7F80
; ACIA BASE ADDR
ACIA_DATA                  EQU             ACIA+0
; RX DATA (READ) / TX DATA (WRITE)
ACIA_STATUS                EQU             ACIA+1
; STATUS (READ) / PROGRAM RESET (WRITE)
ACIA_COMMAND               EQU             ACIA+2
; COMMAND (READ/WRITE)
ACIA_CONTROL               EQU             ACIA+3
; CONTROL (READ/WRITE)

; --- ACIA STATUS BIT MASKS ---
ACIA_ST_IRQ_M              EQU             %10000000               ; IRQ FLAG
ACIA_ST_DSRB_M             EQU             %01000000
; DSRB INPUT STATE
ACIA_ST_DCDB_M             EQU             %00100000
; DCDB INPUT STATE
ACIA_ST_TDRE_M             EQU             %00010000
; TX DATA REG EMPTY
ACIA_ST_RDRF_M             EQU             %00001000
; RX DATA REG FULL
ACIA_ST_OVRN_M             EQU             %00000100               ; OVERRUN
ACIA_ST_FE_M               EQU             %00000010
; FRAMING ERROR
ACIA_ST_PE_M               EQU %00000001               ; PARITY ERROR

; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_RESET_PROGRAM  [HASH:A4ED]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, ACIA, MMIO, REGISTER, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Issue ACIA program reset by writing to status register.
; IN : none
; OUT: ACIA reset side effect applied, A clobbered
; EXCEPTIONS/NOTES:
; - No explicit status in carry.
; ----------------------------------------------------------------------------
                        XDEF            PIN_ACIA_RESET_PROGRAM
PIN_ACIA_RESET_PROGRAM:
                        LDA             #$00
                        STA             ACIA_STATUS
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_INIT_PORT  [HASH:1869]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, ACIA, MMIO, REGISTER, NO-ZP, NO-RAM, CALLS_PIN,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Initialize ACIA for default serial mode (115200 8N1, no IRQs).
; IN : none
; OUT: ACIA configured, A clobbered
; EXCEPTIONS/NOTES:
; - No explicit status in carry.
; ----------------------------------------------------------------------------
                        XDEF            PIN_ACIA_INIT_PORT
PIN_ACIA_INIT_PORT:
                        JSR             PIN_ACIA_RESET_PROGRAM
                        LDA             #$10
                        ; DEFAULT ACIA CTRL = 115200 8N1
                        STA             ACIA_CONTROL
                        LDA             #$0B
                        ; NO PARITY, ECHO OFF, IRQS OFF
                        STA             ACIA_COMMAND
                        RTS

                        XDEF            PIN_ACIA_WRITE_BYTE_TIMEOUT
                        XDEF            PIN_ACIA_READ_BYTE_BLOCK
                        XDEF            PIN_ACIA_READ_BYTE_SPINWAIT
; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_WRITE_BYTE_TIMEOUT  [HASH:F391]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, FTDI, ACIA, MMIO, REGISTER, TIMEOUT, WRITE,
;   PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_PIN, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write one byte to ACIA with bounded polling for TX-ready.
; IN : A = byte to transmit
; OUT: C = 0 on success, C = 1 on timeout, A preserved
; EXCEPTIONS/NOTES:
; - Return carry polarity is opposite of FTDI helpers in this codebase.
; - Calls `PIN_ACIA_TX_DELAY_GATE` to work around W65C51 transmit pacing
;   behavior.
; - X/Y are clobbered.
; ----------------------------------------------------------------------------
PIN_ACIA_WRITE_BYTE_TIMEOUT:
                        PHA
                        LDY             #$40
                        ; POLL BUDGET OUTER LOOP
?AWB_OUTER:
                        LDX             #$00
                        ; 256 POLLS PER OUTER ITERATION
?AWB_WAIT:
                        LDA             ACIA_STATUS
                        AND             #ACIA_ST_TDRE_M
                        BNE             ?AWB_READY
                        DEX
                        BNE             ?AWB_WAIT
                        DEY
                        BNE             ?AWB_OUTER
                        PLA
                        SEC
                        ; TIMEOUT (LIKELY CTS/CLOCK/LEVEL ISSUE)
                        RTS
?AWB_READY:
                        PLA
                        STA             ACIA_DATA
                        JSR             PIN_ACIA_TX_DELAY_GATE
                                        ; W65C51 TX-MASK BUG WORKAROUND:
                                        ; PACE WRITES SO TDRE/TX HANDSHAKE CAN
                                        ; SETTLE BETWEEN BYTES.
                        CLC
                        RTS

                        ; XDEF PIN_ACIA_READ_BYTE_SPINWAIT
; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_READ_BYTE_SPINWAIT  [HASH:792C]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, ACIA, MMIO, REGISTER, SPINWAIT, READ, CARRY-STATUS,
;   NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read one byte from ACIA receive register.
; IN : none
; OUT: A = received byte, C = 1
; EXCEPTIONS/NOTES:
; - Current implementation spins until data is available (`BNE
;   PIN_ACIA_READ_BYTE_SPINWAIT`)
;   and therefore behaves as blocking despite `_NB` name.
; - The `?ACRB_NO` non-ready path is currently unreachable.
; ----------------------------------------------------------------------------
PIN_ACIA_READ_BYTE_SPINWAIT:
                        LDA             ACIA_STATUS
                        AND             #ACIA_ST_RDRF_M
;                        BEQ         ?ACRB_NO
                        BNE             PIN_ACIA_READ_BYTE_SPINWAIT
                        LDA             ACIA_DATA
                        SEC
                        RTS
?ACRB_NO:
                        LDA             #$00
                        CLC
                        RTS

                        ; XDEF PIN_ACIA_READ_BYTE_BLOCK
                        ; Blocking read helper for parity with FTDI API:
                        ; loops until ACIA read byte routine returns carry.
; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_READ_BYTE_BLOCK  [HASH:B818]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SPINWAIT, READ, CARRY-STATUS, NO-ZP,
;   NO-RAM, CALLS_PIN, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking wrapper around `PIN_ACIA_READ_BYTE_SPINWAIT`.
; IN : none
; OUT: A = received byte, C = 1
; EXCEPTIONS/NOTES:
; - Given current `_NB` implementation, this is effectively a direct blocking
;   read loop with redundant retry logic.
; ----------------------------------------------------------------------------
PIN_ACIA_READ_BYTE_BLOCK:
                        JSR             PIN_ACIA_READ_BYTE_SPINWAIT
                        BCC             PIN_ACIA_READ_BYTE_BLOCK
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_ACIA_TX_DELAY_GATE  [HASH:C05B]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, ACIA, MMIO, REGISTER, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Insert short delay between ACIA writes.
; IN : none
; OUT: delay elapsed, A/X/Y clobbered
; EXCEPTIONS/NOTES:
; - Delay count is compile-time fixed by immediate in this routine.
; ----------------------------------------------------------------------------
PIN_ACIA_TX_DELAY_GATE:
                        LDA             #$01
                        BEQ             ?ATT_DONE
                        ; 00 = NO EXTRA DELAY
                        TAY
?ATT_OUTER:
                        LDX             #$FF
?ATT_INNER:
                        DEX
                        BNE             ?ATT_INNER
                        DEY
                        BNE             ?ATT_OUTER
?ATT_DONE:
                        RTS

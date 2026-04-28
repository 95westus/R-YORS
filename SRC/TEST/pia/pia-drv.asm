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
; - L0 driver exports use `PIN_<DEVICE>_*` (this file: `PIN_PIA_*`).
;
; WIP CODE POLICY:
; - This file is in SESH/WIP lane.
; - Behavioral contracts are exploratory and may change.
; -------------------------------------------------------------------------

PIA_BASE                   EQU             $7FA0
PIA_PORTB                  EQU             PIA_BASE+0
PIA_PORTA                  EQU             PIA_BASE+1
PIA_DDRB                   EQU             PIA_BASE+2
PIA_DDRA                   EQU             PIA_BASE+3

PIA_STATE_TMP              EQU             $7EE0
PIA_STATE_PB_SHADOW        EQU             $7EE1
PIA_STATE_PA_SHADOW        EQU             $7EE2

                        XDEF            PIN_PIA_INIT_SHADOWS
                        XDEF            PIN_PIA_WRITE_DDRA
                        XDEF            PIN_PIA_WRITE_DDRB
                        XDEF            PIN_PIA_WRITE_PORTA
                        XDEF            PIN_PIA_WRITE_PORTB
                        XDEF            PIN_PIA_WRITE_PORTA_MASKED
                        XDEF            PIN_PIA_WRITE_PORTB_MASKED
                        XDEF            PIN_PIA_READ_PORTA_RAW
                        XDEF            PIN_PIA_READ_PORTB_RAW
                        XDEF            PIN_PIA_READ_PORTA_SHADOW
                        XDEF            PIN_PIA_READ_PORTB_SHADOW

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_INIT_SHADOWS  [HASH:098A]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, DDR, CARRY-STATUS, NO-ZP,
;   USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PA_SHADOW($7EE2),
;   PIA_STATE_PB_SHADOW($7EE1).
; PURPOSE: Seed software shadows from current hardware port states.
; IN : none
; OUT: C = 1, shadows initialized from PIA_PORTA/PIA_PORTB
; EXCEPTIONS/NOTES:
; - Does not modify DDRA/DDRB.
; ----------------------------------------------------------------------------
PIN_PIA_INIT_SHADOWS:
                        LDA             PIA_PORTA
                        STA             PIA_STATE_PA_SHADOW
                        LDA             PIA_PORTB
                        STA             PIA_STATE_PB_SHADOW
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_DDRA  [HASH:1335]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, PIA, MMIO, REGISTER, DDR, WRITE, CARRY-STATUS, NO-ZP,
;   NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Set PIA port A direction mask.
; IN : A = DDRA value (1=output, 0=input)
; OUT: C = 1
; EXCEPTIONS/NOTES:
; - A is clobbered by write side effect.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_DDRA:
                        STA             PIA_DDRA
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_DDRB  [HASH:1336]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, PIA, MMIO, REGISTER, DDR, WRITE, CARRY-STATUS, NO-ZP,
;   NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Set PIA port B direction mask.
; IN : A = DDRB value (1=output, 0=input)
; OUT: C = 1
; EXCEPTIONS/NOTES:
; - A is clobbered by write side effect.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_DDRB:
                        STA             PIA_DDRB
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_PORTA  [HASH:701A]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, WRITE, IRQ, PRESERVE-A,
;   CARRY-STATUS, NO-ZP, USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PA_SHADOW($7EE2).
; PURPOSE: Write full byte to port A and update shadow.
; IN : A = output byte
; OUT: C = 1, A preserved
; EXCEPTIONS/NOTES:
; - No IRQ masking in this revision.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_PORTA:
                        STA             PIA_STATE_PA_SHADOW
                        STA             PIA_PORTA
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_PORTB  [HASH:701B]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, WRITE, IRQ, PRESERVE-A,
;   CARRY-STATUS, NO-ZP, USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PB_SHADOW($7EE1).
; PURPOSE: Write full byte to port B and update shadow.
; IN : A = output byte
; OUT: C = 1, A preserved
; EXCEPTIONS/NOTES:
; - No IRQ masking in this revision.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_PORTB:
                        STA             PIA_STATE_PB_SHADOW
                        STA             PIA_PORTB
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_PORTA_MASKED  [HASH:1850]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, WRITE, IRQ, CARRY-STATUS,
;   NO-ZP, USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PA_SHADOW($7EE2), PIA_STATE_TMP($7EE0).
; PURPOSE: Masked port-A write using software shadow.
; IN : A = desired bits, X = mask (1 bits in mask are updated)
; OUT: A = resulting port byte, C = 1
; EXCEPTIONS/NOTES:
; - No IRQ masking in this revision.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_PORTA_MASKED:
                        STA             PIA_STATE_TMP
                        TXA
                        AND             PIA_STATE_TMP
                        STA             PIA_STATE_TMP
                        TXA
                        EOR             #$FF
                        AND             PIA_STATE_PA_SHADOW
                        ORA             PIA_STATE_TMP
                        STA             PIA_STATE_PA_SHADOW
                        STA             PIA_PORTA
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_WRITE_PORTB_MASKED  [HASH:452F]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, WRITE, IRQ, CARRY-STATUS,
;   NO-ZP, USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PB_SHADOW($7EE1), PIA_STATE_TMP($7EE0).
; PURPOSE: Masked port-B write using software shadow.
; IN : A = desired bits, X = mask (1 bits in mask are updated)
; OUT: A = resulting port byte, C = 1
; EXCEPTIONS/NOTES:
; - No IRQ masking in this revision.
; ----------------------------------------------------------------------------
PIN_PIA_WRITE_PORTB_MASKED:
                        STA             PIA_STATE_TMP
                        TXA
                        AND             PIA_STATE_TMP
                        STA             PIA_STATE_TMP
                        TXA
                        EOR             #$FF
                        AND             PIA_STATE_PB_SHADOW
                        ORA             PIA_STATE_TMP
                        STA             PIA_STATE_PB_SHADOW
                        STA             PIA_PORTB
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_READ_PORTA_RAW  [HASH:18C6]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, READ, RAW, CARRY-STATUS, NO-ZP,
;   NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read physical state of port A.
; IN : none
; OUT: A = raw port state, C = 1
; ----------------------------------------------------------------------------
PIN_PIA_READ_PORTA_RAW:
                        LDA             PIA_PORTA
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_READ_PORTB_RAW  [HASH:3047]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, READ, RAW, CARRY-STATUS, NO-ZP,
;   NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read physical state of port B.
; IN : none
; OUT: A = raw port state, C = 1
; ----------------------------------------------------------------------------
PIN_PIA_READ_PORTB_RAW:
                        LDA             PIA_PORTB
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_READ_PORTA_SHADOW  [HASH:6FA2]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, READ, CARRY-STATUS, NO-ZP,
;   USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PA_SHADOW($7EE2).
; PURPOSE: Read software shadow for port A (intended output state).
; IN : none
; OUT: A = shadow state, C = 1
; ----------------------------------------------------------------------------
PIN_PIA_READ_PORTA_SHADOW:
                        LDA             PIA_STATE_PA_SHADOW
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PIN_PIA_READ_PORTB_SHADOW  [HASH:9C81]
; TIER: DRIVER-L0
; TAGS: PIN, DRIVER-L0, MMIO, REGISTER, SHADOW, READ, CARRY-STATUS, NO-ZP,
;   USES-FIXED-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: PIA_STATE_PB_SHADOW($7EE1).
; PURPOSE: Read software shadow for port B (intended output state).
; IN : none
; OUT: A = shadow state, C = 1
; ----------------------------------------------------------------------------
PIN_PIA_READ_PORTB_SHADOW:
                        LDA             PIA_STATE_PB_SHADOW
                        SEC
                        RTS

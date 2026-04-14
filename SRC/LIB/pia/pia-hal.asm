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
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
;
; ZP ALLOCATION POLICY
; - See ZP_MAP.md for reserved/scratch ownership.
; - Add/update labels in ZP_MAP.md before claiming new ZP bytes.
;
; THIS FILE: L1 HAL.
; - Unified PIA gate for lock/access control and LED/GPIO APIs.
; - Calls only L0 driver symbols.
; Naming convention:
; - L1 HAL exports use `BIO_PIA_*`.
; - L1 calls L0 `PIN_PIA_*` symbols.
; -------------------------------------------------------------------------

                        XDEF            BIO_PIA_INIT
                        XDEF            BIO_PIA_LOCK
                        XDEF            BIO_PIA_UNLOCK
                        XDEF            BIO_PIA_LED_INIT_PROFILE
                        XDEF            BIO_PIA_LED_INIT_RAW
                        XDEF            BIO_PIA_LED_INIT_EDU
                        XDEF            BIO_PIA_LED_WRITE
                        XDEF            BIO_PIA_LED_SET_MASK
                        XDEF            BIO_PIA_LED_CLEAR_MASK
                        XDEF            BIO_PIA_LED_XOR_MASK
                        XDEF            BIO_PIA_LED_TOGGLE_MASK
                        XDEF            BIO_PIA_LED_READ_SHADOW
                        XDEF            BIO_PIA_LED_READ_RAW
                        XDEF            BIO_PIA_GPIO_CONFIG_DDRA
                        XDEF            BIO_PIA_GPIO_CONFIG_DDRB
                        XDEF            BIO_PIA_GPIO_WRITE_PORTA_MASKED
                        XDEF            BIO_PIA_GPIO_WRITE_PORTB_MASKED
                        XDEF            BIO_PIA_GPIO_READ_PORTA_RAW
                        XDEF            BIO_PIA_GPIO_READ_PORTB_RAW
                        XDEF            BIO_PIA_GPIO_READ_PORTA_SHADOW
                        XDEF            BIO_PIA_GPIO_READ_PORTB_SHADOW

                        XREF            PIN_PIA_INIT_SHADOWS
                        XREF            PIN_PIA_WRITE_DDRA
                        XREF            PIN_PIA_WRITE_DDRB
                        XREF            PIN_PIA_WRITE_PORTA
                        XREF            PIN_PIA_WRITE_PORTA_MASKED
                        XREF            PIN_PIA_WRITE_PORTB_MASKED
                        XREF            PIN_PIA_READ_PORTA_RAW
                        XREF            PIN_PIA_READ_PORTB_RAW
                        XREF            PIN_PIA_READ_PORTA_SHADOW
                        XREF            PIN_PIA_READ_PORTB_SHADOW

PIA_LED_PROFILE_RAW     EQU             $00
PIA_LED_PROFILE_EDU     EQU             $01

PIA_BIO_LOCK_DEPTH      EQU             $0208
PIA_BIO_LED_PROFILE     EQU             $0209
PIA_BIO_TMP_A           EQU             $020A

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_INIT  [RHID:70E9]
; MEM : ZP: none; FIXED_RAM: PIA_BIO_LOCK_DEPTH($0208), PIA_BIO_LED_PROFILE($0209).
; PURPOSE: Initialize HAL gate state and seed driver shadows.
; IN : none
; OUT: C = 1 on success
; EXCEPTIONS/NOTES:
; - Default LED profile is RAW (A=$00).
; ----------------------------------------------------------------------------
BIO_PIA_INIT:
                        STZ             PIA_BIO_LOCK_DEPTH
                        LDA             #PIA_LED_PROFILE_RAW
                        STA             PIA_BIO_LED_PROFILE
                        JSR             PIN_PIA_INIT_SHADOWS
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LOCK  [RHID:EB11]
; MEM : ZP: none; FIXED_RAM: PIA_BIO_LOCK_DEPTH($0208).
; PURPOSE: Enter PIA critical section (software-only in this revision).
; IN : none
; OUT: C = 1 on success, C = 0 on lock-depth overflow
; EXCEPTIONS/NOTES:
; - Does not mask IRQ in this revision.
; ----------------------------------------------------------------------------
BIO_PIA_LOCK:
                        LDA             PIA_BIO_LOCK_DEPTH
                        CMP             #$FF
                        BEQ             PIA_LOCK_FAIL
                        INC             PIA_BIO_LOCK_DEPTH
                        SEC
                        RTS
PIA_LOCK_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_UNLOCK  [RHID:182A]
; MEM : ZP: none; FIXED_RAM: PIA_BIO_LOCK_DEPTH($0208).
; PURPOSE: Exit PIA critical section.
; IN : none
; OUT: C = 1 on success, C = 0 if unlock attempted while unlocked
; EXCEPTIONS/NOTES:
; - Does not restore IRQ state in this revision.
; ----------------------------------------------------------------------------
BIO_PIA_UNLOCK:
                        LDA             PIA_BIO_LOCK_DEPTH
                        BEQ             PIA_UNLOCK_FAIL
                        DEC             PIA_BIO_LOCK_DEPTH
                        SEC
                        RTS
PIA_UNLOCK_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_INIT_PROFILE  [RHID:CEC1]
; MEM : ZP: none; FIXED_RAM: PIA_BIO_LED_PROFILE($0209).
; PURPOSE: Configure LED profile and set PA to output mode.
; IN : A = LED profile (0=RAW, 1=EDU)
; OUT: C = 1 on success, C = 0 on lock failure
; EXCEPTIONS/NOTES:
; - Clears PA output to $00 after configuring DDRA=$FF.
; ----------------------------------------------------------------------------
BIO_PIA_LED_INIT_PROFILE:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_LED_INIT_FAIL_POP
                        PLA
                        STA             PIA_BIO_LED_PROFILE
                        LDA             #$FF
                        JSR             PIN_PIA_WRITE_DDRA
                        LDA             #$00
                        JSR             PIN_PIA_WRITE_PORTA
                        JSR             BIO_PIA_UNLOCK
                        SEC
                        RTS
PIA_LED_INIT_FAIL_POP:
                        PLA
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_INIT_RAW  [RHID:F643]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience wrapper for RAW LED profile.
; IN : none
; OUT: C follows BIO_PIA_LED_INIT_PROFILE
; ----------------------------------------------------------------------------
BIO_PIA_LED_INIT_RAW:
                        LDA             #PIA_LED_PROFILE_RAW
                        JSR             BIO_PIA_LED_INIT_PROFILE
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_INIT_EDU  [RHID:9EE5]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience wrapper for EDU LED profile.
; IN : none
; OUT: C follows BIO_PIA_LED_INIT_PROFILE
; ----------------------------------------------------------------------------
BIO_PIA_LED_INIT_EDU:
                        LDA             #PIA_LED_PROFILE_EDU
                        JSR             BIO_PIA_LED_INIT_PROFILE
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_WRITE  [RHID:8B60]
; MEM : ZP: none; FIXED_RAM: PIA_BIO_LED_PROFILE($0209), PIA_BIO_TMP_A($020A).
; PURPOSE: Write logical LED byte through current profile mapping.
; IN : A = logical LED state byte
; OUT: C = 1 on success, C = 0 on lock failure
; EXCEPTIONS/NOTES:
; - Current RAW and EDU profiles both map directly to PA bit positions.
; ----------------------------------------------------------------------------
BIO_PIA_LED_WRITE:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_LED_WRITE_FAIL_POP
                        PLA
                        STA             PIA_BIO_TMP_A
                        LDA             PIA_BIO_LED_PROFILE
                        CMP             #PIA_LED_PROFILE_EDU
                        BNE             PIA_LED_WRITE_RAW
                        LDA             PIA_BIO_TMP_A
                        AND             #$FF
                        BRA             PIA_LED_WRITE_DO
PIA_LED_WRITE_RAW:
                        LDA             PIA_BIO_TMP_A
PIA_LED_WRITE_DO:
                        JSR             PIN_PIA_WRITE_PORTA
                        JSR             BIO_PIA_UNLOCK
                        SEC
                        RTS
PIA_LED_WRITE_FAIL_POP:
                        PLA
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_SET_MASK  [RHID:3510]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Set (drive high) selected LED bits on PA.
; IN : A = mask of LED bits to set
; OUT: A = resulting PA/LED state, C = 1 on success, C = 0 on lock failure
; EXCEPTIONS/NOTES:
; - Implemented via masked PA write helper through unified gate.
; ----------------------------------------------------------------------------
BIO_PIA_LED_SET_MASK:
                        TAX
                        TXA
                        JSR             BIO_PIA_GPIO_WRITE_PORTA_MASKED
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_CLEAR_MASK  [RHID:B507]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Clear (drive low) selected LED bits on PA.
; IN : A = mask of LED bits to clear
; OUT: A = resulting PA/LED state, C = 1 on success, C = 0 on lock failure
; EXCEPTIONS/NOTES:
; - Implemented via masked PA write helper with desired bits forced low.
; ----------------------------------------------------------------------------
BIO_PIA_LED_CLEAR_MASK:
                        TAX
                        LDA             #$00
                        JSR             BIO_PIA_GPIO_WRITE_PORTA_MASKED
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_XOR_MASK  [RHID:CA7A]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: XOR selected LED bits on PA (toggle where mask bit=1).
; IN : A = mask of LED bits to XOR
; OUT: A = resulting PA/LED state, C = 1 on success, C = 0 on lock failure
; EXCEPTIONS/NOTES:
; - Uses lock around read-shadow + write sequence for atomicity within HAL.
; ----------------------------------------------------------------------------
BIO_PIA_LED_XOR_MASK:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_LED_XOR_MASK_FAIL_POP
                        PLA
                        STA             PIA_BIO_TMP_A
                        JSR             PIN_PIA_READ_PORTA_SHADOW
                        EOR             PIA_BIO_TMP_A
                        JSR             PIN_PIA_WRITE_PORTA
                        PHA
                        JSR             BIO_PIA_UNLOCK
                        PLA
                        SEC
                        RTS
PIA_LED_XOR_MASK_FAIL_POP:
                        PLA
                        LDA             #$00
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_TOGGLE_MASK  [RHID:0F9D]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Alias for BIO_PIA_LED_XOR_MASK.
; IN : A = mask of LED bits to toggle
; OUT: A/C follow BIO_PIA_LED_XOR_MASK
; ----------------------------------------------------------------------------
BIO_PIA_LED_TOGGLE_MASK:
                        JMP             BIO_PIA_LED_XOR_MASK

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_READ_SHADOW  [RHID:B1F0]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read intended LED state (software shadow).
; IN : none
; OUT: A = logical LED state, C = 1
; EXCEPTIONS/NOTES:
; - Returns intended state, not electrical pin sample.
; ----------------------------------------------------------------------------
BIO_PIA_LED_READ_SHADOW:
                        JSR             PIN_PIA_READ_PORTA_SHADOW
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_LED_READ_RAW  [RHID:E2AC]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read raw electrical state from PA pins.
; IN : none
; OUT: A = raw PA state, C = 1
; ----------------------------------------------------------------------------
BIO_PIA_LED_READ_RAW:
                        JSR             PIN_PIA_READ_PORTA_RAW
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_CONFIG_DDRA  [RHID:910E]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Configure DDRA through unified PIA gate.
; IN : A = DDRA value
; OUT: C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_CONFIG_DDRA:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_CFG_DDRA_FAIL_POP
                        PLA
                        JSR             PIN_PIA_WRITE_DDRA
                        JSR             BIO_PIA_UNLOCK
                        SEC
                        RTS
PIA_GPIO_CFG_DDRA_FAIL_POP:
                        PLA
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_CONFIG_DDRB  [RHID:626A]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Configure DDRB through unified PIA gate.
; IN : A = DDRB value
; OUT: C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_CONFIG_DDRB:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_CFG_DDRB_FAIL_POP
                        PLA
                        JSR             PIN_PIA_WRITE_DDRB
                        JSR             BIO_PIA_UNLOCK
                        SEC
                        RTS
PIA_GPIO_CFG_DDRB_FAIL_POP:
                        PLA
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_WRITE_PORTA_MASKED  [RHID:5F28]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Masked PA write through unified PIA gate.
; IN : A = desired bits, X = mask
; OUT: A = resulting PA byte, C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_WRITE_PORTA_MASKED:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_WRITE_A_MASKED_FAIL_POP
                        PLA
                        JSR             PIN_PIA_WRITE_PORTA_MASKED
                        PHA
                        JSR             BIO_PIA_UNLOCK
                        PLA
                        SEC
                        RTS
PIA_GPIO_WRITE_A_MASKED_FAIL_POP:
                        PLA
                        LDA             #$00
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_WRITE_PORTB_MASKED  [RHID:5DD5]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Masked PB write through unified PIA gate.
; IN : A = desired bits, X = mask
; OUT: A = resulting PB byte, C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_WRITE_PORTB_MASKED:
                        PHA
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_WRITE_B_MASKED_FAIL_POP
                        PLA
                        JSR             PIN_PIA_WRITE_PORTB_MASKED
                        PHA
                        JSR             BIO_PIA_UNLOCK
                        PLA
                        SEC
                        RTS
PIA_GPIO_WRITE_B_MASKED_FAIL_POP:
                        PLA
                        LDA             #$00
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_READ_PORTA_RAW  [RHID:799B]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read raw PA through unified PIA gate.
; IN : none
; OUT: A = raw PA state, C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_READ_PORTA_RAW:
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_READ_A_RAW_FAIL
                        JSR             PIN_PIA_READ_PORTA_RAW
                        PHA
                        JSR             BIO_PIA_UNLOCK
                        PLA
                        SEC
                        RTS
PIA_GPIO_READ_A_RAW_FAIL:
                        LDA             #$00
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_READ_PORTB_RAW  [RHID:5816]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read raw PB through unified PIA gate.
; IN : none
; OUT: A = raw PB state, C = 1 on success, C = 0 on lock failure
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_READ_PORTB_RAW:
                        JSR             BIO_PIA_LOCK
                        BCC             PIA_GPIO_READ_B_RAW_FAIL
                        JSR             PIN_PIA_READ_PORTB_RAW
                        PHA
                        JSR             BIO_PIA_UNLOCK
                        PLA
                        SEC
                        RTS
PIA_GPIO_READ_B_RAW_FAIL:
                        LDA             #$00
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_READ_PORTA_SHADOW  [RHID:07B5]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read PA intended/shadow state through unified gate.
; IN : none
; OUT: A = PA shadow, C = 1
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_READ_PORTA_SHADOW:
                        JSR             PIN_PIA_READ_PORTA_SHADOW
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: BIO_PIA_GPIO_READ_PORTB_SHADOW  [RHID:5CE5]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read PB intended/shadow state through unified gate.
; IN : none
; OUT: A = PB shadow, C = 1
; ----------------------------------------------------------------------------
BIO_PIA_GPIO_READ_PORTB_SHADOW:
                        JSR             PIN_PIA_READ_PORTB_SHADOW
                        RTS


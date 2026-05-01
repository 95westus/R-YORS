; -------------------------------------------------------------------------
; I/O / SUBROUTINE CONVENTION (applies to this module and call sites):
; - A is the primary input/output register for data.
; - Carry (C) is status:
;   C=1 => operation completed/byte available
;   C=0 => timeout/not ready/not available.
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
; THIS FILE: L2 BACKEND (FTDI).
; - Calls L1 HAL and L2-common helpers.
; - Exports backend-scoped symbols (`COR_FTDI_*`) for adapter layer.
; Naming convention:
; - L2 backend exports use `COR_<DEVICE>_*` (this file: `COR_FTDI_*`).
; - Backend targets L1 `<DEVICE>_*`; where no HAL wrapper exists yet,
;   backend may call L0 `PIN_<DEVICE>_*` directly.
; -------------------------------------------------------------------------


                        MODULE          COR_FTDI_CVN_WRITE_LINE_RTL_XY

                        XDEF            COR_FTDI_CVN_WRITE_LINE_RTL_XY
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CRLF

FTDI_WRTL_PTR_LO           EQU             $E8
FTDI_WRTL_PTR_HI           EQU             $E9
FTDI_WRTL_LEN              EQU             $EA

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_LINE_RTL_XY  [HASH:8D4A111F]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, NUL-TERM, CRLF, CARRY-STATUS, USES-ZP, NO-RAM,
;   CALLS_COR, STACK
; MEM : ZP: FTDI_WRTL_PTR_LO($F8), FTDI_WRTL_PTR_HI($F9), FTDI_WRTL_LEN($FA);
;   FIXED_RAM: none.
; PURPOSE: Convenience line writer with right-to-left reveal.
; IN : X/Y = pointer to NUL-terminated source text
; OUT: C = 1 on full success (spaces + backfill + CRLF), C = 0 on failure
;   BS, char, BS for each position.
; EXCEPTIONS/NOTES:
; - Source text is NOT reversed in memory.
; - For each source character, emits one space while scanning forward.
; - At NUL terminator, backfills from right to left:
; - Limits scan to 255 chars; returns C=0 if no NUL found before wrap.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_WRITE_LINE_RTL_XY:
                        STX             FTDI_WRTL_PTR_LO
                        STY             FTDI_WRTL_PTR_HI
                        LDY             #$00

?SCAN:                  LDA             (FTDI_WRTL_PTR_LO),Y
                        BEQ             ?HAVE_LEN
                        PHY
                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        BCC             ?FAIL
                        INY
                        BNE             ?SCAN
                        CLC
                        RTS

?HAVE_LEN:              STY             FTDI_WRTL_LEN
                        LDA             FTDI_WRTL_LEN
                        BEQ             ?CRLF

?BACKFILL:              DEC             FTDI_WRTL_LEN
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        LDY             FTDI_WRTL_LEN
                        LDA             (FTDI_WRTL_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        LDA             FTDI_WRTL_LEN
                        BNE             ?BACKFILL

?CRLF:                  JSR             COR_FTDI_WRITE_CRLF
                        RTS

?FAIL:                  CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CSTRING

                        XDEF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CHAR

FTDI_PCS_PTR_LO            EQU             $E8
FTDI_PCS_PTR_HI            EQU             $E9

; in:  X = ptr low, Y = ptr high
;      (A is currently ignored by backend policy.)
; out: C = 1 if NUL terminator reached, C = 0 if fixed cap reached
;      A = chars written (0..255)
; note: Caller-owned max-length policy is intentionally handled above backend.
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CSTRING  [HASH:692F7342]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, WRITE, NUL-TERM, CARRY-STATUS, USES-ZP,
;   NO-RAM, CALLS_COR, STACK
; MEM : ZP: FTDI_PCS_PTR_LO($F8), FTDI_PCS_PTR_HI($F9); FIXED_RAM: none.
; PURPOSE: Write NUL-terminated string over FTDI with fixed backend cap.
; IN : X/Y = source pointer
; OUT: A = chars written, C = 1 on full string, C = 0 on truncation
; EXCEPTIONS/NOTES:
; - A is ignored (reserved for caller-layer policy/compatibility).
; - Stops after 255 bytes if no NUL terminator is found.
; - Stops early on NUL terminator.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CSTRING:
                        STX             FTDI_PCS_PTR_LO
                        STY             FTDI_PCS_PTR_HI

                        LDY             #$00

?LOOP:                  LDA             (FTDI_PCS_PTR_LO),Y
                        BEQ             ?FULL_DONE
                        CPY             #$FF  
                        BEQ             ?TRUNC_DONE
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        INY
                        BNE             ?LOOP

?TRUNC_DONE:            TYA
                        CLC
                        RTS

?FULL_DONE:             TYA
                        SEC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_HBSTRING

                        XDEF            COR_FTDI_WRITE_HBSTRING
                        XREF            COR_FTDI_WRITE_CHAR

FTDI_PHB_PTR_LO            EQU             $E8
FTDI_PHB_PTR_HI            EQU             $E9
FTDI_PHB_CUR               EQU             $E7

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_HBSTRING  [HASH:D06D9799]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, WRITE, HIBIT-TERM, CARRY-STATUS, USES-ZP,
;   NO-RAM, CALLS_COR, STACK
; MEM : ZP: FTDI_PHB_PTR_LO($E8), FTDI_PHB_PTR_HI($E9), FTDI_PHB_CUR($E7);
;   FIXED_RAM: none.
; PURPOSE: Write HIBIT-terminated string over FTDI with fixed backend cap.
; IN : X/Y = source pointer
; OUT: A = chars written, C = 1 on full string, C = 0 on truncation
; EXCEPTIONS/NOTES:
; - Bit7 marks terminal byte in source; terminal byte is emitted before
;   return.
; - Emitted bytes are masked to 7-bit ASCII (`AND #$7F`) before write.
; - Stops after 255 bytes if no terminal byte is encountered.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_HBSTRING:
                        STX             FTDI_PHB_PTR_LO
                        STY             FTDI_PHB_PTR_HI

                        LDY             #$00

?HB_LOOP:               CPY             #$FF
                        BEQ             ?HB_TRUNC_DONE
                        LDA             (FTDI_PHB_PTR_LO),Y
                        STA             FTDI_PHB_CUR
                        AND             #$7F
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        PLY
                        LDA             FTDI_PHB_CUR
                        BMI             ?HB_FULL_DONE
                        INY
                        BNE             ?HB_LOOP

?HB_TRUNC_DONE:         TYA
                        CLC
                        RTS

?HB_FULL_DONE:          TYA
                        CLC
                        ADC             #$01
                        SEC
                        RTS
                        ENDMOD

                        END

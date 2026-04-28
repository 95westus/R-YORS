; -------------------------------------------------------------------------
; Device-neutral character I/O adapter.
; Current backend: FTDI backend layer symbols (`COR_FTDI_*`).
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
; THIS FILE: L4 SYS API.
; - Exports stable `SYS_*` API to application/test code.
; - Should call L3 access-policy symbols when present, else backend symbols.
; Naming convention:
; - L4 sys exports use `SYS_*`.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; APP-FACING TIMING/WAIT API (current):
; - `SYS_READ_CHAR_TIMEOUT_SPINDOWN`
;   IN : A=timeout slices, each slice ~= 28.39 ms at 8 MHz
;   OUT: Success C=1/A=byte/X=remaining slices; Timeout C=0/A=$FD/X=$00
; - `SYS_READ_CHAR_SPINCOUNT`
;   IN : none
;   OUT: C=1/A=byte, X/Y=elapsed spin-slice count (unbounded wrap)
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; SYS BACKEND SELECTOR POINT (compile-time for now)
; - `SYS_*` is the selector seam for device/backend routing.
; - Current selection is fixed to FTDI, so SYS delegates directly to
;   `COR_FTDI_*`.
; - Future backends should switch dispatch policy here first.
; -------------------------------------------------------------------------
SYS_BACKEND_FTDI           EQU             $00
SYS_BACKEND_SELECTED       EQU             SYS_BACKEND_FTDI

                        MODULE          SYS_DEBUG_JSR_SNAPSHOT

                        XDEF            SYS_DEBUG_JSR_SNAPSHOT
                        XREF            COR_FTDI_DEBUG_JSR_SNAPSHOT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_DEBUG_JSR_SNAPSHOT  [HASH:9536]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, FTDI, REGISTER, IRQ, NMI, NO-ZP, NO-RAM, CALLS_COR,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral entry for FTDI-backed JSR debug snapshot output.
; IN : A/X/Y = caller register values at debug call site
; OUT: A/X/Y restored by backend debug helper
; FLAGS: carry follows backend debug routine output path
; EXCEPTIONS/NOTES:
; - Delegates to FTDI backend debug helper `COR_FTDI_DEBUG_JSR_SNAPSHOT`.
; - Scope is intentionally limited to JSR snapshots (no IRQ/NMI/BRK handling).
; ----------------------------------------------------------------------------
SYS_DEBUG_JSR_SNAPSHOT:
                        JSR             COR_FTDI_DEBUG_JSR_SNAPSHOT
                        RTS
                        ENDMOD

                        END

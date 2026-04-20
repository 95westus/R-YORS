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

                        MODULE          SYS_READ_CSTRING

                        XDEF            SYS_READ_CSTRING
                        XREF            COR_FTDI_READ_CSTRING_ECHO

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING  [HASH:1CFF]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, COOKED, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral cooked line input into caller buffer.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics follow backend line reader contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CSTRING_ECHO`.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING:
                        JSR             COR_FTDI_READ_CSTRING_ECHO
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_MODE

                        XDEF            SYS_READ_CSTRING_MODE
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_MODE  [HASH:14E3]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, COOKED, ECHO, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral configurable cooked line input wrapper.
; IN : A = mode bitfield (bit0 echo, bit1 uppercase, bit2 lowercase), X/Y =
;   destination pointer
; OUT: C/A semantics follow backend line reader contract.
; EXCEPTIONS/NOTES:
; - If both uppercase+lowercase bits are set, uppercase conversion wins.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_MODE:
                        JSR             COR_FTDI_READ_CSTRING_MODE
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_EDIT_MODE

                        XDEF            SYS_READ_CSTRING_EDIT_MODE
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_EDIT_MODE  [HASH:DF78]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, COOKED, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral configurable cooked line input with edit keys.
; IN : A = mode bitfield, X/Y = destination pointer
; OUT: C/A semantics follow backend edit-line contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_EDIT_MODE:
                        JSR             COR_FTDI_READ_CSTRING_EDIT_MODE
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_EDIT_ECHO_UPPER

                        XDEF            SYS_READ_CSTRING_EDIT_ECHO_UPPER
        XREF COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_EDIT_ECHO_UPPER  [HASH:6FFD]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for editable echoed uppercase
;   line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend edit-line contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_EDIT_ECHO_UPPER:
        JSR COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_SILENT

                        XDEF            SYS_READ_CSTRING_SILENT
                        XREF            COR_FTDI_READ_CSTRING_SILENT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_SILENT  [HASH:9B95]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, COOKED, ECHO, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for no-echo cooked line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_SILENT:
                        JSR             COR_FTDI_READ_CSTRING_SILENT
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_ECHO_UPPER

                        XDEF            SYS_READ_CSTRING_ECHO_UPPER
                        XREF            COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_ECHO_UPPER  [HASH:A928]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for echoed uppercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_ECHO_UPPER:
                        JSR             COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_ECHO_LOWER

                        XDEF            SYS_READ_CSTRING_ECHO_LOWER
                        XREF            COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_ECHO_LOWER  [HASH:7B87]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for echoed lowercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_ECHO_LOWER:
                        JSR             COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_SILENT_UPPER

                        XDEF            SYS_READ_CSTRING_SILENT_UPPER
                        XREF            COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_SILENT_UPPER  [HASH:9B58]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, SILENT, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for silent uppercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_SILENT_UPPER:
                        JSR             COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CSTRING_SILENT_LOWER

                        XDEF            SYS_READ_CSTRING_SILENT_LOWER
                        XREF            COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_SILENT_LOWER  [HASH:6DB7]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, SILENT, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for silent lowercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_SILENT_LOWER:
                        JSR             COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        RTS
                        ENDMOD

                        END

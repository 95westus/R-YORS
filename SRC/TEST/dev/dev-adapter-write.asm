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

                        MODULE          SYS_WRITE_CHAR_PLUS_CRLF

                        XDEF            SYS_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR_PLUS_CRLF  [HASH:776A]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, CRLF, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking write of payload byte followed by CRLF.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CHAR_PLUS_CRLF`.
; ----------------------------------------------------------------------------
SYS_WRITE_CHAR_PLUS_CRLF:
                        JSR             COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_BYTES_AXY

                        XDEF            SYS_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_BYTES_AXY  [HASH:BE89]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, PRESERVE-XY, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking write of three explicit bytes: A, X, Y.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_BYTES_AXY`.
; ----------------------------------------------------------------------------
SYS_WRITE_BYTES_AXY:
                        JSR             COR_FTDI_WRITE_BYTES_AXY
                        RTS
                        ENDMOD

                        MODULE          SYS_CVN_WRITE_CHAR_PLUS_CRLF

                        XDEF            SYS_CVN_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_WRITE_CHAR_PLUS_CRLF  [HASH:546E]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, CRLF, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for payload-plus-CRLF output.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF`.
; ----------------------------------------------------------------------------
SYS_CVN_WRITE_CHAR_PLUS_CRLF:
                        JSR             COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF
                        RTS
                        ENDMOD

                        MODULE          SYS_CVN_WRITE_BYTES_AXY

                        XDEF            SYS_CVN_WRITE_BYTES_AXY
                        XREF            COR_FTDI_CVN_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_WRITE_BYTES_AXY  [HASH:CF05]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, PRESERVE-XY, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for 3-byte A/X/Y sequence.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_BYTES_AXY`.
; ----------------------------------------------------------------------------
SYS_CVN_WRITE_BYTES_AXY:
                        JSR             COR_FTDI_CVN_WRITE_BYTES_AXY
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_LINE_RTL_XY

                        XDEF            SYS_WRITE_LINE_RTL_XY
                        XREF            COR_FTDI_CVN_WRITE_LINE_RTL_XY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_LINE_RTL_XY  [HASH:C27C]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, NUL-TERM, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience line writer with right-to-left reveal.
; IN : X/Y = pointer to NUL-terminated source text
; OUT: C = 1 on full success, C = 0 on failure
; EXCEPTIONS/NOTES:
; - Source text remains in normal order (not reversed in memory).
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_LINE_RTL_XY`.
; ----------------------------------------------------------------------------
SYS_WRITE_LINE_RTL_XY:
                        JSR             COR_FTDI_CVN_WRITE_LINE_RTL_XY
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_CSTRING

                        XDEF            SYS_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CSTRING

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CSTRING  [HASH:DE4F]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, FTDI, WRITE, NUL-TERM, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of NUL-terminated string.
; IN : X/Y = source pointer (A currently ignored by FTDI backend)
; OUT: A = chars written, C = 1 on full string, C = 0 on truncation
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CSTRING`.
; - Backend applies a fixed 255-byte safety cap.
; - Caller-owned max-length policy belongs above adapter/backend.
; ----------------------------------------------------------------------------
SYS_WRITE_CSTRING:
                        JSR             COR_FTDI_WRITE_CSTRING
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_HBSTRING

                        XDEF            SYS_WRITE_HBSTRING
                        XREF            COR_FTDI_WRITE_HBSTRING

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_HBSTRING  [HASH:38B0]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, HIBIT-TERM, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of HIBIT-terminated string.
; IN : X/Y = source pointer
; OUT: A = chars written, C = 1 on full string, C = 0 on truncation
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_HBSTRING`.
; - Backend masks emitted bytes to 7-bit ASCII before write.
; - Backend applies a fixed 255-byte safety cap.
; ----------------------------------------------------------------------------
SYS_WRITE_HBSTRING:
                        JSR             COR_FTDI_WRITE_HBSTRING
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_HBLINE

                        XDEF            SYS_WRITE_HBLINE
                        XREF            SYS_WRITE_HBSTRING
                        XREF            SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_HBLINE  [HASH:2853]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, HIBIT-TERM, CRLF, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of HIBIT-terminated string followed by CRLF.
; IN : X/Y = source pointer
; OUT: C follows trailing CRLF write path
; ----------------------------------------------------------------------------
SYS_WRITE_HBLINE:
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_LINE_XY

                        XDEF            SYS_WRITE_LINE_XY
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_LINE_XY  [HASH:5B67]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, NUL-TERM, CRLF, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of NUL-terminated string followed by CRLF.
; IN : X/Y = source pointer
; OUT: C follows trailing CRLF write path
; EXCEPTIONS/NOTES:
; - Convenience adapter routine for app-layer line output.
; ----------------------------------------------------------------------------
SYS_WRITE_LINE_XY:
                        JSR             SYS_WRITE_CSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_HEX_BYTE

                        XDEF            SYS_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_HEX_BYTE

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_HEX_BYTE  [HASH:1EF1]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, HEX, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of byte as two ASCII hex characters.
; IN : A = source byte
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_HEX_BYTE`.
; ----------------------------------------------------------------------------
SYS_WRITE_HEX_BYTE:
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_CRLF

                        XDEF            SYS_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CRLF  [HASH:0BCE]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, CRLF, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral CRLF writer.
; IN : none
; OUT: C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CRLF`.
; ----------------------------------------------------------------------------
SYS_WRITE_CRLF:
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS
                        ENDMOD

                        END

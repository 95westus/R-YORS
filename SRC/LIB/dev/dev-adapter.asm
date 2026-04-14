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
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
;
; ZP ALLOCATION POLICY
; - See ZP_MAP.md for reserved/scratch ownership.
; - Add/update labels in ZP_MAP.md before claiming new ZP bytes.
;
; THIS FILE: L3 ADAPTER.
; - Exports stable `SYS_*` API to application/test code.
; - Should only call backend symbols (`COR_FTDI_*`).
; Naming convention:
; - L3 adapter exports use `SYS_*`.
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

                        MODULE          SYS_INIT

                        XDEF            SYS_INIT
                        XREF            COR_FTDI_INIT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_INIT  [RHID:9BEF]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral initialization entry point.
; IN : none
; OUT: active backend initialized
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_INIT`.
; ----------------------------------------------------------------------------
SYS_INIT:
                        jsr             COR_FTDI_INIT
                        rts
                        ENDMOD


                        MODULE          SYS_FLUSH_RX

                        XDEF            SYS_FLUSH_RX
                        XREF            COR_FTDI_FLUSH_RX

; ----------------------------------------------------------------------------
; ROUTINE: SYS_FLUSH_RX  [RHID:345E]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral input flush.
; IN : none
; OUT: C = 1 when flush completes
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_FLUSH_RX`.
; ----------------------------------------------------------------------------
SYS_FLUSH_RX:
                        jsr             COR_FTDI_FLUSH_RX
                        rts
                        ENDMOD


                        MODULE          SYS_CHECK_ENUMERATED

                        XDEF            SYS_CHECK_ENUMERATED
                        XREF            COR_FTDI_CHECK_ENUMERATED

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CHECK_ENUMERATED  [RHID:5456]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral host/enumeration status check.
; IN : none
; OUT: C/A semantics follow backend enumeration contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CHECK_ENUMERATED`.
; ----------------------------------------------------------------------------
SYS_CHECK_ENUMERATED:
                        jsr             COR_FTDI_CHECK_ENUMERATED
                        rts
                        ENDMOD


                        MODULE          SYS_READ_CHAR

                        XDEF            SYS_READ_CHAR
                        XREF            COR_FTDI_READ_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR  [RHID:6E99]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking character read.
; IN : none
; OUT: A = received byte, C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR:
                        jsr             COR_FTDI_READ_CHAR
                        rts
                        ENDMOD


                        MODULE          SYS_READ_CHAR_SPINCOUNT

                        XDEF            SYS_READ_CHAR_SPINCOUNT
                        XREF            COR_FTDI_READ_CHAR_SPINCOUNT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_SPINCOUNT  [RHID:6436]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking read with elapsed spin-slice count.
; IN : none
; OUT: C = 1, A = received byte, X/Y = elapsed slices
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_SPINCOUNT`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_SPINCOUNT:
                        jsr             COR_FTDI_READ_CHAR_SPINCOUNT
                        rts
                        ENDMOD


                        MODULE          SYS_READ_CHAR_TIMEOUT_SPINDOWN

                        XDEF            SYS_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_TIMEOUT_SPINDOWN  [RHID:5134]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral timed read with countdown state.
; IN : A = timeout slices (0..255), each slice ~= 28.39 ms at 8 MHz
; OUT: Success: C = 1, A = received byte, X = slices remaining
;      Timeout: C = 0, A = $FD, X = $00
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_TIMEOUT_SPINDOWN:
                        jsr             COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN
                        rts
                        ENDMOD


                        MODULE          SYS_POLL_CHAR

                        XDEF            SYS_POLL_CHAR
                        XREF            COR_FTDI_POLL_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_POLL_CHAR  [RHID:2968]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral non-blocking readiness check for input byte.
; IN : none
; OUT: C = 1 if a byte is available, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_POLL_CHAR`.
; ----------------------------------------------------------------------------
SYS_POLL_CHAR:
                        jsr             COR_FTDI_POLL_CHAR
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_CHAR

                        XDEF            SYS_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR  [RHID:32E9]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking character write.
; IN : A = byte to send
; OUT: C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CHAR`.
; ----------------------------------------------------------------------------
SYS_WRITE_CHAR:
                        jsr             COR_FTDI_WRITE_CHAR
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_CHAR_REPEAT

                        XDEF            SYS_WRITE_CHAR_REPEAT
                        XREF            COR_FTDI_WRITE_CHAR_REPEAT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR_REPEAT  [RHID:27B3]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral repeated character write.
; IN : A = byte to send, X = repeat count (0..255)
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - X=0 performs no output and returns success.
; - Delegates to backend routine `COR_FTDI_WRITE_CHAR_REPEAT`.
; - X is clobbered by backend countdown.
; ----------------------------------------------------------------------------
SYS_WRITE_CHAR_REPEAT:
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_CHAR_PLUS_CRLF

                        XDEF            SYS_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR_PLUS_CRLF  [RHID:C351]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking write of payload byte followed by CRLF.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CHAR_PLUS_CRLF`.
; ----------------------------------------------------------------------------
SYS_WRITE_CHAR_PLUS_CRLF:
                        jsr             COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_BYTES_AXY

                        XDEF            SYS_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_BYTES_AXY  [RHID:9B78]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking write of three explicit bytes: A, X, Y.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_BYTES_AXY`.
; ----------------------------------------------------------------------------
SYS_WRITE_BYTES_AXY:
                        jsr             COR_FTDI_WRITE_BYTES_AXY
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_WRITE_CHAR_PLUS_CRLF

                        XDEF            SYS_CVN_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_WRITE_CHAR_PLUS_CRLF  [RHID:C7D9]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for payload-plus-CRLF output.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF`.
; ----------------------------------------------------------------------------
SYS_CVN_WRITE_CHAR_PLUS_CRLF:
                        jsr             COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_WRITE_BYTES_AXY

                        XDEF            SYS_CVN_WRITE_BYTES_AXY
                        XREF            COR_FTDI_CVN_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_WRITE_BYTES_AXY  [RHID:0515]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for 3-byte A/X/Y sequence.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_BYTES_AXY`.
; ----------------------------------------------------------------------------
SYS_CVN_WRITE_BYTES_AXY:
                        jsr             COR_FTDI_CVN_WRITE_BYTES_AXY
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_WRITE_LINE_RTL_XY

                        XDEF            SYS_CVN_WRITE_LINE_RTL_XY
                        XREF            COR_FTDI_CVN_WRITE_LINE_RTL_XY

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_WRITE_LINE_RTL_XY
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience line writer with right-to-left reveal.
; IN : X/Y = pointer to NUL-terminated source text
; OUT: C = 1 on full success, C = 0 on failure
; EXCEPTIONS/NOTES:
; - Source text remains in normal order (not reversed in memory).
; - Delegates to backend routine `COR_FTDI_CVN_WRITE_LINE_RTL_XY`.
; ----------------------------------------------------------------------------
SYS_CVN_WRITE_LINE_RTL_XY:
                        jsr             COR_FTDI_CVN_WRITE_LINE_RTL_XY
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_CSTRING

                        XDEF            SYS_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CSTRING

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CSTRING  [RHID:21DC]
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
                        jsr             COR_FTDI_WRITE_CSTRING
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_HBSTRING

                        XDEF            SYS_WRITE_HBSTRING
                        XREF            COR_FTDI_WRITE_HBSTRING

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_HBSTRING  [RHID:7C18]
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
                        jsr             COR_FTDI_WRITE_HBSTRING
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_LINE_XY

                        XDEF            SYS_WRITE_LINE_XY
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_LINE_XY
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of NUL-terminated string followed by CRLF.
; IN : X/Y = source pointer
; OUT: C follows trailing CRLF write path
; EXCEPTIONS/NOTES:
; - Convenience adapter routine for app-layer line output.
; ----------------------------------------------------------------------------
SYS_WRITE_LINE_XY:
                        jsr             SYS_WRITE_CSTRING
                        jsr             SYS_WRITE_CRLF
                        rts
                        ENDMOD


;                        MODULE          SYS_WRITE_CRLF
;
;                        XDEF            SYS_WRITE_CRLF
;                        XREF            SYS_WRITE_CSTRING
;                        XREF            SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CRLF  [RHID:F6B8]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write C-string followed by CRLF.
; IN : X/Y = source pointer (A currently ignored by SYS_WRITE_CSTRING path)
; OUT: A = chars written by string phase, C = string phase status
; EXCEPTIONS/NOTES:
; - Always attempts CRLF write after the string phase.
; - Restores carry from `SYS_WRITE_CSTRING` so truncation/full status is preserved.
; ----------------------------------------------------------------------------
;SYS_WRITE_CRLF:
;                        jsr             SYS_WRITE_CSTRING
;                        php
;                        jsr             SYS_WRITE_CRLF
;                        plp
;                        rts
;                        ENDMOD


                        MODULE          SYS_READ_CSTRING

                        XDEF            SYS_READ_CSTRING
                        XREF            COR_FTDI_READ_CSTRING_ECHO

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING  [RHID:E441]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral cooked line input into caller buffer.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics follow backend line reader contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CSTRING_ECHO`.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING:
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_MODE

                        XDEF            SYS_CVN_READ_CSTRING_MODE
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_MODE
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral configurable cooked line input wrapper.
; IN : A = mode bitfield (bit0 echo, bit1 uppercase, bit2 lowercase), X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; EXCEPTIONS/NOTES:
; - If both uppercase+lowercase bits are set, uppercase conversion wins.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_MODE:
                        jsr             COR_FTDI_READ_CSTRING_MODE
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_SILENT

                        XDEF            SYS_CVN_READ_CSTRING_SILENT
                        XREF            COR_FTDI_READ_CSTRING_SILENT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_SILENT
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for no-echo cooked line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_SILENT:
                        jsr             COR_FTDI_READ_CSTRING_SILENT
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_ECHO_UPPER

                        XDEF            SYS_CVN_READ_CSTRING_ECHO_UPPER
                        XREF            COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_ECHO_UPPER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for echoed uppercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_ECHO_UPPER:
                        jsr             COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_ECHO_LOWER

                        XDEF            SYS_CVN_READ_CSTRING_ECHO_LOWER
                        XREF            COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_ECHO_LOWER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for echoed lowercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_ECHO_LOWER:
                        jsr             COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_SILENT_UPPER

                        XDEF            SYS_CVN_READ_CSTRING_SILENT_UPPER
                        XREF            COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_SILENT_UPPER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for silent uppercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_SILENT_UPPER:
                        jsr             COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        rts
                        ENDMOD


                        MODULE          SYS_CVN_READ_CSTRING_SILENT_LOWER

                        XDEF            SYS_CVN_READ_CSTRING_SILENT_LOWER
                        XREF            COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CVN_READ_CSTRING_SILENT_LOWER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral convenience wrapper for silent lowercase line input.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow backend line reader contract.
; ----------------------------------------------------------------------------
SYS_CVN_READ_CSTRING_SILENT_LOWER:
                        jsr             COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_HEX_BYTE

                        XDEF            SYS_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_HEX_BYTE

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_HEX_BYTE  [RHID:80D8]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral write of byte as two ASCII hex characters.
; IN : A = source byte
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_HEX_BYTE`.
; ----------------------------------------------------------------------------
SYS_WRITE_HEX_BYTE:
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        rts
                        ENDMOD


                        MODULE          SYS_WRITE_CRLF

                        XDEF            SYS_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CRLF  [RHID:F6B8]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral CRLF writer.
; IN : none
; OUT: C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CRLF`.
; ----------------------------------------------------------------------------
SYS_WRITE_CRLF:
                        jsr             COR_FTDI_WRITE_CRLF
                        rts
                        ENDMOD


                        MODULE          SYS_READ_CHAR_COOKED_ECHO

                        XDEF            SYS_READ_CHAR_COOKED_ECHO
                        XREF            COR_FTDI_READ_CHAR_COOKED_ECHO

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_COOKED_ECHO  [RHID:AE91]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral cooked single-char input with echo policy.
; IN : none
; OUT: C/A semantics follow backend cooked-char contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_COOKED_ECHO`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_COOKED_ECHO:
                        jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        rts
                        ENDMOD


                        MODULE          SYS_DEBUG_JSR_SNAPSHOT

                        XDEF            SYS_DEBUG_JSR_SNAPSHOT
                        XREF            COR_FTDI_DEBUG_JSR_SNAPSHOT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_DEBUG_JSR_SNAPSHOT  [RHID:E51D]
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
                        jsr             COR_FTDI_DEBUG_JSR_SNAPSHOT
                        rts
                        ENDMOD



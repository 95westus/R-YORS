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

                        MODULE          SYS_INIT

                        XDEF            SYS_INIT
                        XREF            COR_FTDI_INIT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_INIT  [HASH:2D2F]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral initialization entry point.
; IN : none
; OUT: active backend initialized
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_INIT`.
; ----------------------------------------------------------------------------
SYS_INIT:
                        JSR             COR_FTDI_INIT
                        RTS
                        ENDMOD

                        MODULE          SYS_FLUSH_RX

                        XDEF            SYS_FLUSH_RX
                        XREF            COR_FTDI_FLUSH_RX

; ----------------------------------------------------------------------------
; ROUTINE: SYS_FLUSH_RX  [HASH:3A20]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, FLUSH, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral input flush.
; IN : none
; OUT: C = 1 when flush completes
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_FLUSH_RX`.
; ----------------------------------------------------------------------------
SYS_FLUSH_RX:
                        JSR             COR_FTDI_FLUSH_RX
                        RTS
                        ENDMOD

                        MODULE          SYS_CHECK_ENUMERATED

                        XDEF            SYS_CHECK_ENUMERATED
                        XREF            COR_FTDI_CHECK_ENUMERATED

; ----------------------------------------------------------------------------
; ROUTINE: SYS_CHECK_ENUMERATED  [HASH:23D6]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, ENUM, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral host/enumeration status check.
; IN : none
; OUT: C/A semantics follow backend enumeration contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_CHECK_ENUMERATED`.
; ----------------------------------------------------------------------------
SYS_CHECK_ENUMERATED:
                        JSR             COR_FTDI_CHECK_ENUMERATED
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CHAR

                        XDEF            SYS_READ_CHAR
                        XREF            COR_FTDI_READ_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR  [HASH:EBA0]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, READ, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking character read.
; IN : none
; OUT: A = received byte, C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR:
                        JSR             COR_FTDI_READ_CHAR
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CHAR_SPINCOUNT

                        XDEF            SYS_READ_CHAR_SPINCOUNT
                        XREF            COR_FTDI_READ_CHAR_SPINCOUNT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_SPINCOUNT  [HASH:200E]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, READ, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking read with elapsed spin-slice count.
; IN : none
; OUT: C = 1, A = received byte, X/Y = elapsed slices
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_SPINCOUNT`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_SPINCOUNT:
                        JSR             COR_FTDI_READ_CHAR_SPINCOUNT
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CHAR_TIMEOUT_SPINDOWN

                        XDEF            SYS_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_TIMEOUT_SPINDOWN  [HASH:77E1]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, SPINDOWN, TIMEOUT, READ, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral timed read with countdown state.
; IN : A = timeout slices (0..255), each slice ~= 28.39 ms at 8 MHz
; OUT: Success: C = 1, A = received byte, X = slices remaining
;      Timeout: C = 0, A = $FD, X = $00
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_TIMEOUT_SPINDOWN:
                        JSR             COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN
                        RTS
                        ENDMOD

                        MODULE          SYS_POLL_CHAR

                        XDEF            SYS_POLL_CHAR
                        XREF            COR_FTDI_POLL_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_POLL_CHAR  [HASH:1F17]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral non-blocking readiness check for input byte.
; IN : none
; OUT: C = 1 if a byte is available, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_POLL_CHAR`.
; ----------------------------------------------------------------------------
SYS_POLL_CHAR:
                        JSR             COR_FTDI_POLL_CHAR
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_CHAR

                        XDEF            SYS_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR  [HASH:E0B5]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral blocking character write.
; IN : A = byte to send
; OUT: C = 1 on success
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_WRITE_CHAR`.
; ----------------------------------------------------------------------------
SYS_WRITE_CHAR:
                        JSR             COR_FTDI_WRITE_CHAR
                        RTS
                        ENDMOD

                        MODULE          SYS_WRITE_CHAR_REPEAT

                        XDEF            SYS_WRITE_CHAR_REPEAT
                        XREF            COR_FTDI_WRITE_CHAR_REPEAT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_WRITE_CHAR_REPEAT  [HASH:F865]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, WRITE, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
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
                        JSR             COR_FTDI_WRITE_CHAR_REPEAT
                        RTS
                        ENDMOD

                        MODULE          SYS_READ_CHAR_COOKED_ECHO

                        XDEF            SYS_READ_CHAR_COOKED_ECHO
                        XREF            COR_FTDI_READ_CHAR_COOKED_ECHO

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CHAR_COOKED_ECHO  [HASH:8F5E]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, COOKED, ECHO, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Device-neutral cooked single-char input with echo policy.
; IN : none
; OUT: C/A semantics follow backend cooked-char contract
; EXCEPTIONS/NOTES:
; - Delegates to backend routine `COR_FTDI_READ_CHAR_COOKED_ECHO`.
; ----------------------------------------------------------------------------
SYS_READ_CHAR_COOKED_ECHO:
                        JSR             COR_FTDI_READ_CHAR_COOKED_ECHO
                        RTS
                        ENDMOD

                        END

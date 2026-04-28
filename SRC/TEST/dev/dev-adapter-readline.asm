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
; ROUTINE: SYS_READ_CSTRING  [HASH:0D00]
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
; ROUTINE: SYS_READ_CSTRING_MODE  [HASH:FD82]
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
; ROUTINE: SYS_READ_CSTRING_EDIT_MODE  [HASH:8239]
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
; ROUTINE: SYS_READ_CSTRING_EDIT_ECHO_UPPER  [HASH:3DFE]
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
; ROUTINE: SYS_READ_CSTRING_SILENT  [HASH:D874]
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
; ROUTINE: SYS_READ_CSTRING_ECHO_UPPER  [HASH:5E87]
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
; ROUTINE: SYS_READ_CSTRING_ECHO_LOWER  [HASH:30E6]
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
; ROUTINE: SYS_READ_CSTRING_SILENT_UPPER  [HASH:74F7]
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
; ROUTINE: SYS_READ_CSTRING_SILENT_LOWER  [HASH:4756]
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

                        MODULE          SYS_READ_STRING_CTRL_C_ECHO

                        XDEF            SYS_READ_CSTRING_CTRL_C_ECHO
                        XDEF            SYS_READ_HBSTRING_CTRL_C_ECHO
                        XREF            SYS_READ_CHAR
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_CRLF

SYS_RCCE_PTR_LO           EQU             $E8
SYS_RCCE_PTR_HI           EQU             $E9
SYS_RCCE_LEN              EQU             $EA
SYS_RCCE_MODE             EQU             $EB

SYS_RCCE_MODE_CSTR        EQU             $00
SYS_RCCE_MODE_HBSTR       EQU             $01
SYS_RCCE_MAX_CSTR         EQU             $FE
SYS_RCCE_MAX_HBSTR        EQU             $FF
SYS_RCCE_FULL_CODE        EQU             $FE
SYS_RCCE_CTRL_C           EQU             $03

; ----------------------------------------------------------------------------
; ROUTINE: SYS_READ_CSTRING_CTRL_C_ECHO / SYS_READ_HBSTRING_CTRL_C_ECHO
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, READ, ECHO, CTRL-C, CSTRING, HIBIT-TERM, CARRY-STATUS,
;   USES-ZP, NO-RAM, STACK
; MEM : ZP: SYS_RCCE_PTR_LO($E8), SYS_RCCE_PTR_HI($E9), SYS_RCCE_LEN($EA),
;   SYS_RCCE_MODE($EB); FIXED_RAM: none.
; PURPOSE: Device-neutral blocking line input with printable echo and Ctrl-C
;   abort status.
; IN : X/Y = destination pointer
; OUT: C=1, A=len on CR/LF completion
;      C=0, A=$03 on Ctrl-C
;      C=0, A=$FE on full buffer
; EXCEPTIONS/NOTES:
; - Printable bytes $20-$7E are stored and echoed.
; - Other controls are ignored except CR/LF and Ctrl-C.
; - CSTR capacity is 254 bytes (+ trailing NUL).
; - HBSTR capacity is 255 bytes (final stored byte has bit7 set).
; - C-string output stores a trailing NUL.
; - HBSTR output sets bit 7 on the final character. Empty HBSTR input stores
;   $80 as an application-readable empty sentinel.
; ----------------------------------------------------------------------------
SYS_READ_CSTRING_CTRL_C_ECHO:
                        LDA             #SYS_RCCE_MODE_CSTR
                        BRA             SYS_READ_STRING_CTRL_C_ECHO

SYS_READ_HBSTRING_CTRL_C_ECHO:
                        LDA             #SYS_RCCE_MODE_HBSTR

SYS_READ_STRING_CTRL_C_ECHO:
                        STX             SYS_RCCE_PTR_LO
                        STY             SYS_RCCE_PTR_HI
                        STA             SYS_RCCE_MODE
                        STZ             SYS_RCCE_LEN

SYS_RCCE_LOOP:
                        JSR             SYS_READ_CHAR
                        CMP             #SYS_RCCE_CTRL_C
                        BEQ             SYS_RCCE_ABORT
                        CMP             #$0D
                        BEQ             SYS_RCCE_DONE
                        CMP             #$0A
                        BEQ             SYS_RCCE_DONE
                        CMP             #$20
                        BCC             SYS_RCCE_LOOP
                        CMP             #$7F
                        BCS             SYS_RCCE_LOOP

                        PHA
                        LDY             SYS_RCCE_LEN
                        LDA             SYS_RCCE_MODE
                        CMP             #SYS_RCCE_MODE_HBSTR
                        BEQ             SYS_RCCE_CHECK_MAX_HBSTR
                        CPY             #SYS_RCCE_MAX_CSTR
                        BEQ             SYS_RCCE_FULL_POP
                        BRA             SYS_RCCE_STORE_CHAR
SYS_RCCE_CHECK_MAX_HBSTR:
                        CPY             #SYS_RCCE_MAX_HBSTR
                        BEQ             SYS_RCCE_FULL_POP
SYS_RCCE_STORE_CHAR:
                        PLA
                        STA             (SYS_RCCE_PTR_LO),Y
                        JSR             SYS_WRITE_CHAR
                        INC             SYS_RCCE_LEN
                        BRA             SYS_RCCE_LOOP
SYS_RCCE_FULL_POP:
                        PLA
                        BRA             SYS_RCCE_FULL

SYS_RCCE_DONE:
                        JSR             SYS_RCCE_TERMINATE
                        JSR             SYS_WRITE_CRLF
                        LDA             SYS_RCCE_LEN
                        SEC
                        RTS

SYS_RCCE_ABORT:
                        JSR             SYS_WRITE_CRLF
                        LDA             #SYS_RCCE_CTRL_C
                        CLC
                        RTS

SYS_RCCE_FULL:
                        JSR             SYS_RCCE_TERMINATE
                        JSR             SYS_WRITE_CRLF
                        LDA             #SYS_RCCE_FULL_CODE
                        CLC
                        RTS

SYS_RCCE_TERMINATE:
                        LDA             SYS_RCCE_MODE
                        CMP             #SYS_RCCE_MODE_HBSTR
                        BEQ             SYS_RCCE_TERM_HBSTR

                        LDY             SYS_RCCE_LEN
                        LDA             #$00
                        STA             (SYS_RCCE_PTR_LO),Y
                        RTS

SYS_RCCE_TERM_HBSTR:
                        LDY             SYS_RCCE_LEN
                        BNE             SYS_RCCE_TERM_HBSTR_NONEMPTY
                        LDA             #$80
                        STA             (SYS_RCCE_PTR_LO),Y
                        RTS

SYS_RCCE_TERM_HBSTR_NONEMPTY:
                        DEY
                        LDA             (SYS_RCCE_PTR_LO),Y
                        ORA             #$80
                        STA             (SYS_RCCE_PTR_LO),Y
                        RTS

                        ENDMOD

                        END

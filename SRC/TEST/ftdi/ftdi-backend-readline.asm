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


                        MODULE          COR_FTDI_READ_CSTRING_ECHO
                        XDEF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ROUTINE FAMILY:
; - `COR_FTDI_READ_CSTRING_ECHO`               : echo enabled, no case
;   conversion
; - `COR_FTDI_READ_CSTRING_SILENT`             : echo disabled, no case
;   conversion
; - `COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER`     : echo + force uppercase
; - `COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER`     : echo + force lowercase
; - `COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER`   : silent + force uppercase
; - `COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER`   : silent + force lowercase
; - `COR_FTDI_READ_CSTRING_CORE`               : compatibility wrapper (carry
;   -> mode)
; - `COR_FTDI_READ_CSTRING_MODE`               : shared mode-driven engine
;
; MODE bitfield (`A` input for `COR_FTDI_READ_CSTRING_MODE`):
; - bit0 ($01): echo characters (and EOL CRLF)
; - bit1 ($02): convert printable input to uppercase
; - bit2 ($04): convert printable input to lowercase (ignored when bit1 set)
;
; in:  X = ptr low, Y = ptr high (A ignored by this wrapper)
; out: C = 1 on EOL/complete, C = 0 on special/full
;      When C=1: A = chars read (0..254), line is NUL-terminated
; When C=0 and A=$08/$7F: BS/DEL encountered (buffer still NUL-terminated)
;      When C=0 and A=$FE: buffer full before EOL (buffer NUL-terminated)
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_ECHO  [HASH:AFA5DCB7]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, COOKED, ECHO, CRLF, USES-ZP, NO-RAM, NOSTACK
; MEM : ZP: FTDI_GCS_PTR_LO($F8), FTDI_GCS_PTR_HI($F9), FTDI_GCS_MAX($FA),
;   FTDI_GCS_LEN($FB), FTDI_GCS_PB_CH($FC), FTDI_GCS_PB_VALID($FD),
;   FTDI_GCS_EOL($FE), FTDI_GCS_MODE($FF); FIXED_RAM: none.
; PURPOSE: Echo-enabled cooked line input wrapper over
;   `COR_FTDI_READ_CSTRING_MODE`.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics documented above in detail.
; EXCEPTIONS/NOTES:
; - Returns C=0 for special cases (BS/DEL/full), same as core routine.
; - Swallows paired CRLF/LFCR terminators using one-byte pushback state.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_ECHO:
                        LDA             #$01
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_READ_CSTRING_SILENT
                        XDEF            COR_FTDI_READ_CSTRING_SILENT
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_SILENT  [HASH:DC1D7147]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: No-echo cooked line input wrapper over
;   `COR_FTDI_READ_CSTRING_MODE`.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Read semantics are identical to echo variant, except no character echo.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_SILENT:
                        LDA             #$00
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER  [HASH:837FAA72]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with echo and uppercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Printable letters 'a'..'z' are normalized to uppercase before store/echo.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER:
                        LDA             #$03
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER  [HASH:2F8CC313]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with echo and lowercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Printable letters 'A'..'Z' are normalized to lowercase before store/echo.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER:
                        LDA             #$05
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER  [HASH:3133183A]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with no echo and uppercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER:
                        LDA             #$02
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER  [HASH:8AE0FF1B]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with no echo and lowercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER:
                        LDA             #$04
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_READ_CSTRING_CORE
                        XDEF            COR_FTDI_READ_CSTRING_CORE
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_CORE  [HASH:B10FE9C9]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, VIA, ECHO, NO-ZP, NO-RAM, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Compatibility wrapper mapping carry echo-mode into mode bitfield.
; IN : C = 1 echo enabled, C = 0 echo disabled, X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Preserved for existing callers that pass mode via carry.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_CORE:
                        BCC             ?NO_ECHO
                        LDA             #$01
                        JMP             COR_FTDI_READ_CSTRING_MODE
?NO_ECHO:
                        LDA             #$00
                        JMP             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD

                        MODULE          COR_FTDI_READ_CSTRING_MODE
                        XDEF            COR_FTDI_READ_CSTRING_MODE
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            UTL_CHAR_TO_UPPER
                        XREF            UTL_CHAR_TO_LOWER

FTDI_GCS_PTR_LO            EQU             $E8
FTDI_GCS_PTR_HI            EQU             $E9
FTDI_GCS_MAX               EQU             $EA
FTDI_GCS_LEN               EQU             $EB
FTDI_GCS_PB_CH             EQU             $EC
FTDI_GCS_PB_VALID          EQU             $ED
FTDI_GCS_EOL               EQU             $EE
FTDI_GCS_MODE              EQU             $EF

FTDI_GCS_MODE_ECHO         EQU             $01
FTDI_GCS_MODE_UPPER        EQU             $02
FTDI_GCS_MODE_LOWER        EQU             $04

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_MODE  [HASH:E73324BD]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, COOKED, ECHO, UPPERCASE, LOWERCASE, CRLF,
;   CARRY-STATUS, USES-ZP, NO-RAM, CALLS_COR, STACK
; MEM : ZP: FTDI_GCS_PTR_LO($F8), FTDI_GCS_PTR_HI($F9), FTDI_GCS_MAX($FA),
;   FTDI_GCS_LEN($FB), FTDI_GCS_PB_CH($FC), FTDI_GCS_PB_VALID($FD),
;   FTDI_GCS_EOL($FE as EOL scratch), FTDI_GCS_MODE($FF as mode flag);
;   FIXED_RAM: none.
; PURPOSE: Shared cooked line reader with configurable echo/case policy.
; IN : A = mode bitfield (echo/upper/lower), X/Y = destination pointer
; OUT: C = 1 on EOL/complete, C = 0 on BS/DEL/full
;      A = chars read on C=1, or reason code on C=0 (08/7F/FE)
; EXCEPTIONS/NOTES:
; - Fixed capacity: 254 data bytes plus trailing NUL.
; - Swallows paired CRLF/LFCR terminators using one-byte pushback state.
; - If both upper+lower bits are set, uppercase conversion wins.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_MODE:
                        STX             FTDI_GCS_PTR_LO
                        STY             FTDI_GCS_PTR_HI
                        STA             FTDI_GCS_MODE

                        LDA             FTDI_GCS_PB_VALID
                        CMP             #$01
                        BEQ             ?PB_STATE_OK
                        STZ             FTDI_GCS_PB_VALID
?PB_STATE_OK:
                        LDA             #$FE
                        STA             FTDI_GCS_MAX
                        STZ             FTDI_GCS_LEN

?READ_LOOP:
                        LDA             FTDI_GCS_PB_VALID
                        BEQ             ?READ_CHAR
                        STZ             FTDI_GCS_PB_VALID
                        LDA             FTDI_GCS_PB_CH
                        BRA             ?CLASSIFY

?READ_CHAR:             JSR             COR_FTDI_READ_CHAR

?CLASSIFY:
                        CMP             #$0D
                        BEQ             ?EOL
                        CMP             #$0A
                        BEQ             ?EOL
                        CMP             #$08
                        BEQ             ?RET_BS
                        CMP             #$7F
                        BEQ             ?RET_DEL
                        CMP             #$20
                        BCC             ?READ_LOOP
                        ; ignore other control chars
                        CMP             #$7F
                        BCS             ?READ_LOOP
                        ; ignore non-printable 0x7F+

                        PHA
                        LDA             FTDI_GCS_MODE
                        AND             #FTDI_GCS_MODE_UPPER
                        BEQ             ?CHECK_LOWER
                        PLA
                        JSR             UTL_CHAR_TO_UPPER
                        PHA
                        BRA             ?CASE_READY
?CHECK_LOWER:
                        LDA             FTDI_GCS_MODE
                        AND             #FTDI_GCS_MODE_LOWER
                        BEQ             ?CASE_READY
                        PLA
                        JSR             UTL_CHAR_TO_LOWER
                        PHA

?CASE_READY:
                        LDA             FTDI_GCS_LEN
                        CMP             FTDI_GCS_MAX
                        BEQ             ?FULL_POP
                        TAY
                        PLA
                        STA             (FTDI_GCS_PTR_LO),Y
                        PHY
                        PHA
                        ; keep printable char for optional echo
                        LDA             FTDI_GCS_MODE
                        AND             #FTDI_GCS_MODE_ECHO
                        BEQ             ?NO_ECHO_CHAR
                        PLA
                        JSR             COR_FTDI_WRITE_CHAR
                        BRA             ?ECHO_CHAR_DONE
?NO_ECHO_CHAR:          PLA
?ECHO_CHAR_DONE:
                        PLY
                        INC             FTDI_GCS_LEN
                        BRA             ?READ_LOOP

?FULL_POP:              PLA
?FULL:                  LDA             FTDI_GCS_LEN
                        TAY
                        LDA             #$00
                        STA             (FTDI_GCS_PTR_LO),Y
                        LDA             FTDI_GCS_MAX
                        CLC
                        RTS

?RET_BS:                LDA             FTDI_GCS_LEN
                        TAY
                        LDA             #$00
                        STA             (FTDI_GCS_PTR_LO),Y
                        LDA             #$08
                        CLC
                        RTS

?RET_DEL:               LDA             FTDI_GCS_LEN
                        TAY
                        LDA             #$00
                        STA             (FTDI_GCS_PTR_LO),Y
                        LDA             #$7F
                        CLC
                        RTS

?EOL:                   PHA
; preserve first EOL byte while checking mode
                        LDA             FTDI_GCS_MODE
                        AND             #FTDI_GCS_MODE_ECHO
                        BEQ             ?NO_ECHO_EOL
                        LDA             #$0D
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             #$0A
                        JSR             COR_FTDI_WRITE_CHAR
?NO_ECHO_EOL:           PLA
                        STA             FTDI_GCS_EOL
                        ; now store first EOL for pair swallow logic
                        JSR             COR_FTDI_POLL_CHAR
                        BCC             ?TERM_OK
                        JSR             COR_FTDI_READ_CHAR

                        LDX             FTDI_GCS_EOL
                        CPX             #$0D
                        BEQ             ?FIRST_CR
                        CMP             #$0D
                        BEQ             ?TERM_OK                 ; LFCR pair
                        BRA             ?PUSHBACK

?FIRST_CR:              CMP             #$0A
                        BEQ             ?TERM_OK                 ; CRLF pair

?PUSHBACK:              STA             FTDI_GCS_PB_CH
                        LDA             #$01
                        STA             FTDI_GCS_PB_VALID

?TERM_OK:               LDA             FTDI_GCS_LEN
                        TAY
                        LDA             #$00
                        STA             (FTDI_GCS_PTR_LO),Y
                        LDA             FTDI_GCS_LEN
                        SEC
                        RTS
                        ENDMOD

                        END

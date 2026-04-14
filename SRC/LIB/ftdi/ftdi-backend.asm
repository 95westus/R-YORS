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
; L3 (Adapter):dev-adapter.asm  -> device-neutral API, calls backend only.
; L4 (App):    test.asm         -> app/test entry points.
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


                        MODULE          COR_FTDI_INIT

                        XDEF            COR_FTDI_INIT
                        XREF            PIN_FTDI_INIT

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_INIT  [RHID:A64B]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend initialization entry for FTDI stack.
; IN : none
; OUT: backend/HAL initialized
; EXCEPTIONS/NOTES:
; - Thin wrapper over `PIN_FTDI_INIT`.
; ----------------------------------------------------------------------------
COR_FTDI_INIT:
                        jsr             PIN_FTDI_INIT
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_FLUSH_RX

                        XDEF            COR_FTDI_FLUSH_RX
                        XREF            BIO_FTDI_FLUSH_RX

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_FLUSH_RX  [RHID:4C44]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend input flush entry for FTDI stack.
; IN : none
; OUT: C = 1 when flush completes
; EXCEPTIONS/NOTES:
; - Thin wrapper over `BIO_FTDI_FLUSH_RX`.
; ----------------------------------------------------------------------------
COR_FTDI_FLUSH_RX:
                        jsr             BIO_FTDI_FLUSH_RX
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_CHECK_ENUMERATED

                        XDEF            COR_FTDI_CHECK_ENUMERATED
                        XREF            PIN_FTDI_CHECK_ENUMERATED

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CHECK_ENUMERATED  [RHID:C5BA]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend USB-enumeration status check.
; IN : none
; OUT: C/A semantics follow `PIN_FTDI_CHECK_ENUMERATED`
; EXCEPTIONS/NOTES:
; - Thin wrapper over `PIN_FTDI_CHECK_ENUMERATED`.
; ----------------------------------------------------------------------------
COR_FTDI_CHECK_ENUMERATED:
                        jsr             PIN_FTDI_CHECK_ENUMERATED
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_POLL_CHAR

                        XDEF            COR_FTDI_POLL_CHAR
                        XREF            BIO_FTDI_POLL_RX_READY

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_POLL_CHAR  [RHID:0A6E]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking check for available FTDI input byte.
; IN : none
; OUT: C = 1 if byte available, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - Thin wrapper over `BIO_FTDI_POLL_RX_READY`.
; - Register preservation follows callee behavior.
; ----------------------------------------------------------------------------
COR_FTDI_POLL_CHAR:
                        jsr             BIO_FTDI_POLL_RX_READY
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CHAR

                        XDEF            COR_FTDI_READ_CHAR
                        XREF            BIO_FTDI_READ_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR  [RHID:7A51]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI character read.
; IN : none
; OUT: A = received byte, C = 1
; EXCEPTIONS/NOTES:
; - Delegates to blocking HAL routine `BIO_FTDI_READ_BYTE_BLOCK`.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR:
                        jsr             BIO_FTDI_READ_BYTE_BLOCK
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CHAR_TIMEOUT

                        XDEF            COR_FTDI_READ_CHAR_TIMEOUT
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GCT_TMO_SLICE_X    EQU             $B6
FTDI_GCT_TMO_SLICE_Y    EQU             $F8
FTDI_GCT_TMO_CODE       EQU             $FD

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_TIMEOUT  [RHID:4AA5]
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($020B), DELAY_AXY_Y_INIT($020C) via UTL_DELAY_AXY_8MHZ.
; PURPOSE: Timed FTDI character read with bounded wait.
; IN : A = timeout slices (0..255), each slice ~= 28.39 ms at 8 MHz
; OUT: C = 1, A = received byte on success
;      C = 0, A = $FD on timeout
; EXCEPTIONS/NOTES:
; - A=0 performs immediate non-blocking check (no wait slice).
; - Polls availability (`COR_FTDI_POLL_CHAR`) before each wait slice.
; - On availability, reads byte via `COR_FTDI_READ_CHAR`.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_TIMEOUT:
                        pha                                             ; stack-local countdown byte
?POLL:                  jsr             COR_FTDI_POLL_CHAR
                        bcs             ?READ
                        pla
                        beq             ?TIMEOUT
                        dec             a
                        pha
                        lda             #$01
                        ldx             #FTDI_GCT_TMO_SLICE_X
                        ldy             #FTDI_GCT_TMO_SLICE_Y
                        jsr             UTL_DELAY_AXY_8MHZ
                        bra             ?POLL

?READ:                  pla                                             ; discard countdown
                        jsr             COR_FTDI_READ_CHAR
                        rts

?TIMEOUT:               lda             #FTDI_GCT_TMO_CODE
                        clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CHAR_SPINCOUNT

                        XDEF            COR_FTDI_READ_CHAR_SPINCOUNT
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GSC_SLICE_X        EQU             $B6
FTDI_GSC_SLICE_Y        EQU             $F8

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_SPINCOUNT  [RHID:554C]
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($020B), DELAY_AXY_Y_INIT($020C) via UTL_DELAY_AXY_8MHZ.
; PURPOSE: Wait for FTDI character and return elapsed spin-slice count.
; IN : none
; OUT: C = 1, A = received byte
;      X = elapsed slices low byte, Y = elapsed slices high byte
; EXCEPTIONS/NOTES:
; - Uses same slice interval as `COR_FTDI_READ_CHAR_TIMEOUT` (~28.39 ms at 8 MHz).
; - Wait is unbounded; X/Y wraps naturally after 65535 slices.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_SPINCOUNT:
                        ldx             #$00
                        ldy             #$00
?POLL:                  jsr             COR_FTDI_POLL_CHAR
                        bcs             ?READ
                        phx
                        phy
                        lda             #$01
                        ldx             #FTDI_GSC_SLICE_X
                        ldy             #FTDI_GSC_SLICE_Y
                        jsr             UTL_DELAY_AXY_8MHZ
                        ply
                        plx
                        inx
                        bne             ?POLL
                        iny
                        bra             ?POLL

?READ:                  phx
                        phy
                        jsr             COR_FTDI_READ_CHAR
                        ply
                        plx
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN

                        XDEF            COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GTS_SLICE_X        EQU             $B6
FTDI_GTS_SLICE_Y        EQU             $F8
FTDI_GTS_TMO_CODE       EQU             $FD

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN  [RHID:B5B3]
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($020B), DELAY_AXY_Y_INIT($020C) via UTL_DELAY_AXY_8MHZ.
; PURPOSE: Timed FTDI character read with visible countdown state.
; IN : A = timeout slices (0..255), each slice ~= 28.39 ms at 8 MHz
; OUT: Success: C = 1, A = received byte, X = slices remaining (0..255)
;      Timeout: C = 0, A = $FD, X = $00
; EXCEPTIONS/NOTES:
; - Uses same slice interval as `COR_FTDI_READ_CHAR_TIMEOUT`.
; - A=0 performs immediate non-blocking check.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN:
                        tax                                             ; X = countdown state
?POLL:                  jsr             COR_FTDI_POLL_CHAR
                        bcs             ?READ
                        cpx             #$00
                        beq             ?TIMEOUT
                        dex
                        phx
                        lda             #$01
                        ldx             #FTDI_GTS_SLICE_X
                        ldy             #FTDI_GTS_SLICE_Y
                        jsr             UTL_DELAY_AXY_8MHZ
                        plx
                        bra             ?POLL

?READ:                  phx
                        jsr             COR_FTDI_READ_CHAR
                        plx
                        rts

?TIMEOUT:               lda             #FTDI_GTS_TMO_CODE
                        clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_CHAR

                        XDEF            COR_FTDI_WRITE_CHAR
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR  [RHID:8F40]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI character write.
; IN : A = byte to send
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Delegates to blocking HAL routine `BIO_FTDI_WRITE_BYTE_BLOCK`.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CHAR:
                        jsr             BIO_FTDI_WRITE_BYTE_BLOCK
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_CHAR_REPEAT

                        XDEF            COR_FTDI_WRITE_CHAR_REPEAT
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR_REPEAT  [RHID:13B6]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write character in A, repeated X times.
; IN : A = byte to send, X = repeat count (0..255)
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - X=0 performs no output and returns success.
; - X is clobbered (countdown to zero).
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CHAR_REPEAT:
                        cpx             #$00
                        beq             ?DONE
?LOOP:                  jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        dex
                        bne             ?LOOP
?DONE:                  sec
                        rts
?FAIL:                  clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_CHAR_PLUS_CRLF

                        XDEF            COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR_PLUS_CRLF  [RHID:76CF]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking write of payload byte in A, then CRLF.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Sequence emitted is exactly: A, $0D, $0A.
; - C=0 can be returned if lower write path reports failure.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CHAR_PLUS_CRLF:
                        pha
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        lda             #$0A
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        pla
                        sec
                        rts
?FAIL:                  pla
                        clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_BYTES_AXY

                        XDEF            COR_FTDI_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_BYTES_AXY  [RHID:62D4]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking write of three explicit bytes in order: A, X, Y.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - This is a compact fast-path emitter for fixed 3-byte sequences.
; - Sequence emitted is exactly: A, X, Y.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_BYTES_AXY:
                        pha
                        phx
                        phy
                        jsr             COR_FTDI_WRITE_CHAR            ; emit A
                        bcc             ?FAIL
                        txa
                        jsr             COR_FTDI_WRITE_CHAR            ; emit X
                        bcc             ?FAIL
                        tya
                        jsr             COR_FTDI_WRITE_CHAR            ; emit Y
                        bcc             ?FAIL
                        ply
                        plx
                        pla
                        sec
                        rts
?FAIL:                  ply
                        plx
                        pla
                        clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF

                        XDEF            COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF  [RHID:1F77]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience wrapper for blocking payload-plus-CRLF output.
; IN : A = payload byte
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A preserved
; EXCEPTIONS/NOTES:
; - Delegates to `COR_FTDI_WRITE_CHAR_PLUS_CRLF`.
; - `CVN_*` routines are opinionated sequence helpers.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF:
                        jsr             COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_CVN_WRITE_BYTES_AXY

                        XDEF            COR_FTDI_CVN_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_BYTES_AXY  [RHID:03DB]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience wrapper for blocking 3-byte A/X/Y sequence output.
; IN : A = payload byte, X = byte1, Y = byte2
; OUT: C = 1 on full sequence success, C = 0 on write failure
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - Delegates to `COR_FTDI_WRITE_BYTES_AXY`.
; - `CVN_*` routines are opinionated sequence helpers.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_WRITE_BYTES_AXY:
                        jsr             COR_FTDI_WRITE_BYTES_AXY
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_CVN_WRITE_LINE_RTL_XY

                        XDEF            COR_FTDI_CVN_WRITE_LINE_RTL_XY
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CRLF

FTDI_WRTL_PTR_LO        EQU             $F8
FTDI_WRTL_PTR_HI        EQU             $F9
FTDI_WRTL_LEN           EQU             $FA

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_LINE_RTL_XY
; MEM : ZP: FTDI_WRTL_PTR_LO($F8), FTDI_WRTL_PTR_HI($F9), FTDI_WRTL_LEN($FA); FIXED_RAM: none.
; PURPOSE: Convenience line writer with right-to-left reveal.
; IN : X/Y = pointer to NUL-terminated source text
; OUT: C = 1 on full success (spaces + backfill + CRLF), C = 0 on failure
; EXCEPTIONS/NOTES:
; - Source text is NOT reversed in memory.
; - For each source character, emits one space while scanning forward.
; - At NUL terminator, backfills from right to left:
;   BS, char, BS for each position.
; - Limits scan to 255 chars; returns C=0 if no NUL found before wrap.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_WRITE_LINE_RTL_XY:
                        stx             FTDI_WRTL_PTR_LO
                        sty             FTDI_WRTL_PTR_HI
                        ldy             #$00

?SCAN:                  lda             (FTDI_WRTL_PTR_LO),y
                        beq             ?HAVE_LEN
                        phy
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        bcc             ?FAIL
                        iny
                        bne             ?SCAN
                        clc
                        rts

?HAVE_LEN:              sty             FTDI_WRTL_LEN
                        lda             FTDI_WRTL_LEN
                        beq             ?CRLF

?BACKFILL:              dec             FTDI_WRTL_LEN
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        ldy             FTDI_WRTL_LEN
                        lda             (FTDI_WRTL_PTR_LO),y
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        bcc             ?FAIL
                        lda             FTDI_WRTL_LEN
                        bne             ?BACKFILL

?CRLF:                  jsr             COR_FTDI_WRITE_CRLF
                        rts

?FAIL:                  clc
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_CSTRING

                        XDEF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CHAR

FTDI_PCS_PTR_LO         EQU             $F8
FTDI_PCS_PTR_HI         EQU             $F9

; in:  X = ptr low, Y = ptr high
;      (A is currently ignored by backend policy.)
; out: C = 1 if NUL terminator reached, C = 0 if fixed cap reached
;      A = chars written (0..255)
; note: Caller-owned max-length policy is intentionally handled above backend.
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CSTRING  [RHID:A357]
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
                        stx             FTDI_PCS_PTR_LO
                        sty             FTDI_PCS_PTR_HI

                        ldy             #$00

?LOOP:                  lda             (FTDI_PCS_PTR_LO),y
                        beq             ?FULL_DONE
                        cpy             #$FF  
                        beq             ?TRUNC_DONE
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        iny
                        bne             ?LOOP

?TRUNC_DONE:            tya
                        clc
                        rts

?FULL_DONE:             tya
                        sec
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_HBSTRING

                        XDEF            COR_FTDI_WRITE_HBSTRING
                        XREF            COR_FTDI_WRITE_CHAR

FTDI_PHB_PTR_LO         EQU             $F8
FTDI_PHB_PTR_HI         EQU             $F9
FTDI_PHB_CUR            EQU             $F7

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_HBSTRING  [RHID:4E9A]
; MEM : ZP: FTDI_PHB_PTR_LO($F8), FTDI_PHB_PTR_HI($F9), FTDI_PHB_CUR($F7); FIXED_RAM: none.
; PURPOSE: Write HIBIT-terminated string over FTDI with fixed backend cap.
; IN : X/Y = source pointer
; OUT: A = chars written, C = 1 on full string, C = 0 on truncation
; EXCEPTIONS/NOTES:
; - Bit7 marks terminal byte in source; terminal byte is emitted before return.
; - Emitted bytes are masked to 7-bit ASCII (`AND #$7F`) before write.
; - Stops after 255 bytes if no terminal byte is encountered.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_HBSTRING:
                        stx             FTDI_PHB_PTR_LO
                        sty             FTDI_PHB_PTR_HI

                        ldy             #$00

?HB_LOOP:               cpy             #$FF
                        beq             ?HB_TRUNC_DONE
                        lda             (FTDI_PHB_PTR_LO),y
                        sta             FTDI_PHB_CUR
                        and             #$7F
                        phy
                        jsr             COR_FTDI_WRITE_CHAR
                        ply
                        lda             FTDI_PHB_CUR
                        bmi             ?HB_FULL_DONE
                        iny
                        bne             ?HB_LOOP

?HB_TRUNC_DONE:         tya
                        clc
                        rts

?HB_FULL_DONE:          tya
                        clc
                        adc             #$01
                        sec
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_ECHO
                        XDEF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ROUTINE FAMILY:
; - `COR_FTDI_READ_CSTRING_ECHO`               : echo enabled, no case conversion
; - `COR_FTDI_READ_CSTRING_SILENT`             : echo disabled, no case conversion
; - `COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER`     : echo + force uppercase
; - `COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER`     : echo + force lowercase
; - `COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER`   : silent + force uppercase
; - `COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER`   : silent + force lowercase
; - `COR_FTDI_READ_CSTRING_CORE`               : compatibility wrapper (carry -> mode)
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
;      When C=0 and A=$08/$7F: BS/DEL encountered (buffer still NUL-terminated)
;      When C=0 and A=$FE: buffer full before EOL (buffer NUL-terminated)
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_ECHO  [RHID:D266]
; MEM : ZP: FTDI_GCS_PTR_LO($F8), FTDI_GCS_PTR_HI($F9), FTDI_GCS_MAX($FA), FTDI_GCS_LEN($FB), FTDI_GCS_PB_CH($FC), FTDI_GCS_PB_VALID($FD), FTDI_GCS_EOL($FE), FTDI_GCS_MODE($FF); FIXED_RAM: none.
; PURPOSE: Echo-enabled cooked line input wrapper over `COR_FTDI_READ_CSTRING_MODE`.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics documented above in detail.
; EXCEPTIONS/NOTES:
; - Returns C=0 for special cases (BS/DEL/full), same as core routine.
; - Swallows paired CRLF/LFCR terminators using one-byte pushback state.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_ECHO:
                        lda             #$01
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_SILENT
                        XDEF            COR_FTDI_READ_CSTRING_SILENT
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_SILENT  [RHID:1F6F]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: No-echo cooked line input wrapper over `COR_FTDI_READ_CSTRING_MODE`.
; IN : X/Y = destination pointer (A ignored)
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Read semantics are identical to echo variant, except no character echo.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_SILENT:
                        lda             #$00
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with echo and uppercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Printable letters 'a'..'z' are normalized to uppercase before store/echo.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_ECHO_UPPER:
                        lda             #$03
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with echo and lowercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Printable letters 'A'..'Z' are normalized to lowercase before store/echo.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_ECHO_LOWER:
                        lda             #$05
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with no echo and uppercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_SILENT_UPPER:
                        lda             #$02
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convenience cooked line read with no echo and lowercase conversion.
; IN : X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_SILENT_LOWER:
                        lda             #$04
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_CORE
                        XDEF            COR_FTDI_READ_CSTRING_CORE
                        XREF            COR_FTDI_READ_CSTRING_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_CORE  [RHID:59B4]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Compatibility wrapper mapping carry echo-mode into mode bitfield.
; IN : C = 1 echo enabled, C = 0 echo disabled, X/Y = destination pointer
; OUT: C/A semantics follow `COR_FTDI_READ_CSTRING_MODE`.
; EXCEPTIONS/NOTES:
; - Preserved for existing callers that pass mode via carry.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_CORE:
                        bcc             ?NO_ECHO
                        lda             #$01
                        jmp             COR_FTDI_READ_CSTRING_MODE
?NO_ECHO:
                        lda             #$00
                        jmp             COR_FTDI_READ_CSTRING_MODE
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_MODE
                        XDEF            COR_FTDI_READ_CSTRING_MODE
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            UTL_CHAR_TO_UPPER
                        XREF            UTL_CHAR_TO_LOWER

FTDI_GCS_PTR_LO         EQU             $F8
FTDI_GCS_PTR_HI         EQU             $F9
FTDI_GCS_MAX            EQU             $FA
FTDI_GCS_LEN            EQU             $FB
FTDI_GCS_PB_CH          EQU             $FC
FTDI_GCS_PB_VALID       EQU             $FD
FTDI_GCS_EOL            EQU             $FE
FTDI_GCS_MODE           EQU             $FF

FTDI_GCS_MODE_ECHO      EQU             $01
FTDI_GCS_MODE_UPPER     EQU             $02
FTDI_GCS_MODE_LOWER     EQU             $04

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_MODE
; MEM : ZP: FTDI_GCS_PTR_LO($F8), FTDI_GCS_PTR_HI($F9), FTDI_GCS_MAX($FA), FTDI_GCS_LEN($FB), FTDI_GCS_PB_CH($FC), FTDI_GCS_PB_VALID($FD), FTDI_GCS_EOL($FE as EOL scratch), FTDI_GCS_MODE($FF as mode flag); FIXED_RAM: none.
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
                        stx             FTDI_GCS_PTR_LO
                        sty             FTDI_GCS_PTR_HI
                        sta             FTDI_GCS_MODE

                        lda             FTDI_GCS_PB_VALID
                        cmp             #$01
                        beq             ?PB_STATE_OK
                        stz             FTDI_GCS_PB_VALID
?PB_STATE_OK:
                        lda             #$FE
                        sta             FTDI_GCS_MAX
                        stz             FTDI_GCS_LEN

?READ_LOOP:
                        lda             FTDI_GCS_PB_VALID
                        beq             ?READ_CHAR
                        stz             FTDI_GCS_PB_VALID
                        lda             FTDI_GCS_PB_CH
                        bra             ?CLASSIFY

?READ_CHAR:             jsr             COR_FTDI_READ_CHAR

?CLASSIFY:
                        cmp             #$0D
                        beq             ?EOL
                        cmp             #$0A
                        beq             ?EOL
                        cmp             #$08
                        beq             ?RET_BS
                        cmp             #$7F
                        beq             ?RET_DEL
                        cmp             #$20
                        bcc             ?READ_LOOP               ; ignore other control chars
                        cmp             #$7F
                        bcs             ?READ_LOOP               ; ignore non-printable 0x7F+

                        pha
                        lda             FTDI_GCS_MODE
                        and             #FTDI_GCS_MODE_UPPER
                        beq             ?CHECK_LOWER
                        pla
                        jsr             UTL_CHAR_TO_UPPER
                        pha
                        bra             ?CASE_READY
?CHECK_LOWER:
                        lda             FTDI_GCS_MODE
                        and             #FTDI_GCS_MODE_LOWER
                        beq             ?CASE_READY
                        pla
                        jsr             UTL_CHAR_TO_LOWER
                        pha

?CASE_READY:
                        lda             FTDI_GCS_LEN
                        cmp             FTDI_GCS_MAX
                        beq             ?FULL_POP
                        tay
                        pla
                        sta             (FTDI_GCS_PTR_LO),y
                        phy
                        pha                                             ; keep printable char for optional echo
                        lda             FTDI_GCS_MODE
                        and             #FTDI_GCS_MODE_ECHO
                        beq             ?NO_ECHO_CHAR
                        pla
                        jsr             COR_FTDI_WRITE_CHAR
                        bra             ?ECHO_CHAR_DONE
?NO_ECHO_CHAR:          pla
?ECHO_CHAR_DONE:
                        ply
                        inc             FTDI_GCS_LEN
                        bra             ?READ_LOOP

?FULL_POP:              pla
?FULL:                  lda             FTDI_GCS_LEN
                        tay
                        lda             #$00
                        sta             (FTDI_GCS_PTR_LO),y
                        lda             FTDI_GCS_MAX
                        clc
                        rts

?RET_BS:                lda             FTDI_GCS_LEN
                        tay
                        lda             #$00
                        sta             (FTDI_GCS_PTR_LO),y
                        lda             #$08
                        clc
                        rts

?RET_DEL:               lda             FTDI_GCS_LEN
                        tay
                        lda             #$00
                        sta             (FTDI_GCS_PTR_LO),y
                        lda             #$7F
                        clc
                        rts

?EOL:                   pha                                             ; preserve first EOL byte while checking mode
                        lda             FTDI_GCS_MODE
                        and             #FTDI_GCS_MODE_ECHO
                        beq             ?NO_ECHO_EOL
                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #$0A
                        jsr             COR_FTDI_WRITE_CHAR
?NO_ECHO_EOL:           pla
                        sta             FTDI_GCS_EOL                    ; now store first EOL for pair swallow logic
                        jsr             COR_FTDI_POLL_CHAR
                        bcc             ?TERM_OK
                        jsr             COR_FTDI_READ_CHAR

                        ldx             FTDI_GCS_EOL
                        cpx             #$0D
                        beq             ?FIRST_CR
                        cmp             #$0D
                        beq             ?TERM_OK                 ; LFCR pair
                        bra             ?PUSHBACK

?FIRST_CR:              cmp             #$0A
                        beq             ?TERM_OK                 ; CRLF pair

?PUSHBACK:              sta             FTDI_GCS_PB_CH
                        lda             #$01
                        sta             FTDI_GCS_PB_VALID

?TERM_OK:               lda             FTDI_GCS_LEN
                        tay
                        lda             #$00
                        sta             (FTDI_GCS_PTR_LO),y
                        lda             FTDI_GCS_LEN
                        sec
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_EDIT_ECHO
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_ECHO
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_ECHO
; PURPOSE: Line-editor read wrapper (echo, no case conversion).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; NOTES:
; - Supports BS ($08/$7F), DEL (ESC[3~), and ANSI arrows ESC[A/ESC[C/ESC[D plus ESCOA/ESCOC/ESCOD.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_ECHO:
                        lda             #$01
                        jmp             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_EDIT_SILENT
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_SILENT
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_SILENT
; PURPOSE: Line-editor read wrapper (no echo, no case conversion).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_SILENT:
                        lda             #$00
                        jmp             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD


                        MODULE          COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
                        XDEF            COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
; PURPOSE: Line-editor read wrapper (echo + force uppercase).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER:
                        lda             #$03
                        jmp             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD


                        MODULE          COR_FTDI_READ_CSTRING_EDIT_MODE
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_MODE
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            UTL_CHAR_TO_UPPER
                        XREF            UTL_CHAR_TO_LOWER

FTDI_GCE_ESC            EQU             $1B
FTDI_GCE_PTR_LO         EQU             $F8
FTDI_GCE_PTR_HI         EQU             $F9
FTDI_GCE_MAX            EQU             $FA
FTDI_GCE_LEN            EQU             $FB
FTDI_GCE_PB_CH          EQU             $FC
FTDI_GCE_PB_VALID       EQU             $FD
FTDI_GCE_EOL            EQU             $FE
FTDI_GCE_MODE           EQU             $FF
FTDI_GCE_MODE_ECHO      EQU             $01
FTDI_GCE_MODE_UPPER     EQU             $02
FTDI_GCE_MODE_LOWER     EQU             $04

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_MODE
; PURPOSE: Mode-driven line editor with insert/delete and cursor movement.
; IN : A = mode bitfield (same bits as COR_FTDI_READ_CSTRING_MODE)
;      X/Y = destination pointer
; OUT: C=1, A=len on EOL completion (buffer NUL-terminated)
;      C=0, A=$FE on full buffer (buffer NUL-terminated)
; NOTES:
; - Handles BS/DEL in-buffer edits instead of returning retry statuses.
; - Treats BS as either $08 or $7F (common terminal backspace variants).
; - Handles ANSI arrow sequences: ESC[A / ESCOA (up), ESC[C / ESCOC (right), ESC[D / ESCOD (left).
; - Handles ANSI Delete key sequence ESC[3~ as forward delete at cursor.
; - Echo behavior applies to both typed characters and in-line edits.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_MODE:
                        stx             FTDI_GCE_PTR_LO
                        sty             FTDI_GCE_PTR_HI
                        sta             FTDI_GCE_MODE

                        lda             FTDI_GCE_PB_VALID
                        cmp             #$01
                        beq             ?GCE_PB_STATE_OK
                        stz             FTDI_GCE_PB_VALID
?GCE_PB_STATE_OK:
                        lda             #$FE
                        sta             FTDI_GCE_MAX
                        stz             FTDI_GCE_LEN
                        stz             FTDI_GCE_EOL                ; cursor index
                        ldy             #$00
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y

?GCE_READ_LOOP:
                        jsr             ?GCE_GET_RAW_CHAR
                        cmp             #$0D
                        bne             ?GCE_NOT_CR
                        jmp             ?GCE_HANDLE_EOL
?GCE_NOT_CR:
                        cmp             #$0A
                        bne             ?GCE_NOT_LF
                        jmp             ?GCE_HANDLE_EOL
?GCE_NOT_LF:
                        cmp             #FTDI_GCE_ESC
                        bne             ?GCE_NOT_ESC
                        jmp             ?GCE_HANDLE_ESC
?GCE_NOT_ESC:
                        cmp             #$08
                        bne             ?GCE_NOT_BS
                        jmp             ?GCE_HANDLE_BS
?GCE_NOT_BS:
                        cmp             #$7F
                        bne             ?GCE_NOT_BS7F
                        jmp             ?GCE_HANDLE_BS
?GCE_NOT_BS7F:
                        cmp             #$20
                        bcc             ?GCE_READ_LOOP              ; ignore other controls
                        cmp             #$7F
                        bcs             ?GCE_READ_LOOP              ; ignore non-printable 0x7F+

                        pha
                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_UPPER
                        beq             ?GCE_CHECK_LOWER
                        pla
                        jsr             UTL_CHAR_TO_UPPER
                        pha
                        bra             ?GCE_CASE_READY
?GCE_CHECK_LOWER:
                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_LOWER
                        beq             ?GCE_CASE_READY
                        pla
                        jsr             UTL_CHAR_TO_LOWER
                        pha
?GCE_CASE_READY:
                        lda             FTDI_GCE_LEN
                        cmp             FTDI_GCE_MAX
                        beq             ?GCE_FULL_POP

                        lda             FTDI_GCE_EOL
                        cmp             FTDI_GCE_LEN
                        bcs             ?GCE_STORE_CHAR

                        ldx             FTDI_GCE_LEN
?GCE_SHIFT_RIGHT_LOOP:
                        cpx             FTDI_GCE_EOL
                        beq             ?GCE_STORE_CHAR
                        dex
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        iny
                        sta             (FTDI_GCE_PTR_LO),y
                        bra             ?GCE_SHIFT_RIGHT_LOOP

?GCE_STORE_CHAR:
                        pla
                        ldy             FTDI_GCE_EOL
                        sta             (FTDI_GCE_PTR_LO),y
                        inc             FTDI_GCE_LEN
                        ldy             FTDI_GCE_LEN
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y

                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        beq             ?GCE_NO_ECHO_INSERT
                        ldx             FTDI_GCE_EOL
?GCE_ECHO_INSERT_LOOP:
                        cpx             FTDI_GCE_LEN
                        beq             ?GCE_ECHO_INSERT_DONE
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        jsr             COR_FTDI_WRITE_CHAR
                        inx
                        bra             ?GCE_ECHO_INSERT_LOOP
?GCE_ECHO_INSERT_DONE:
?GCE_NO_ECHO_INSERT:
                        inc             FTDI_GCE_EOL

                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        bne             ?GCE_INSERT_HAVE_ECHO
                        jmp             ?GCE_READ_LOOP
?GCE_INSERT_HAVE_ECHO:
                        lda             FTDI_GCE_LEN
                        sec
                        sbc             FTDI_GCE_EOL
                        tax
?GCE_INSERT_BS_LOOP:
                        cpx             #$00
                        bne             ?GCE_INSERT_BS_HAVE_COUNT
                        jmp             ?GCE_READ_LOOP
?GCE_INSERT_BS_HAVE_COUNT:
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        dex
                        bra             ?GCE_INSERT_BS_LOOP

?GCE_FULL_POP:
                        pla
                        lda             FTDI_GCE_LEN
                        tay
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y
                        lda             FTDI_GCE_MAX
                        clc
                        rts

?GCE_HANDLE_BS:
                        lda             FTDI_GCE_EOL
                        bne             ?GCE_BS_HAVE_CURSOR
                        jmp             ?GCE_READ_LOOP
?GCE_BS_HAVE_CURSOR:
                        dec             FTDI_GCE_EOL
                        ldx             FTDI_GCE_EOL
?GCE_BS_SHIFT_LEFT:
                        inx
                        cpx             FTDI_GCE_LEN
                        beq             ?GCE_BS_SHIFT_DONE
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        dex
                        tay
                        sta             (FTDI_GCE_PTR_LO),y
                        inx
                        bra             ?GCE_BS_SHIFT_LEFT
?GCE_BS_SHIFT_DONE:
                        dec             FTDI_GCE_LEN
                        ldy             FTDI_GCE_LEN
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y

                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        bne             ?GCE_BS_HAVE_ECHO
                        jmp             ?GCE_READ_LOOP
?GCE_BS_HAVE_ECHO:
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        ldx             FTDI_GCE_EOL
?GCE_BS_ECHO_TAIL:
                        cpx             FTDI_GCE_LEN
                        beq             ?GCE_BS_ECHO_SPACE
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        jsr             COR_FTDI_WRITE_CHAR
                        inx
                        bra             ?GCE_BS_ECHO_TAIL
?GCE_BS_ECHO_SPACE:
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             FTDI_GCE_LEN
                        sec
                        sbc             FTDI_GCE_EOL
                        clc
                        adc             #$01
                        tax
?GCE_BS_ECHO_BACK:
                        cpx             #$00
                        bne             ?GCE_BS_BACK_HAVE_COUNT
                        jmp             ?GCE_READ_LOOP
?GCE_BS_BACK_HAVE_COUNT:
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        dex
                        bra             ?GCE_BS_ECHO_BACK

?GCE_HANDLE_DEL:
                        lda             FTDI_GCE_EOL
                        cmp             FTDI_GCE_LEN
                        bcc             ?GCE_DEL_HAVE_CURSOR
                        jmp             ?GCE_READ_LOOP
?GCE_DEL_HAVE_CURSOR:
                        ldx             FTDI_GCE_EOL
?GCE_DEL_SHIFT_LEFT:
                        inx
                        cpx             FTDI_GCE_LEN
                        beq             ?GCE_DEL_SHIFT_DONE
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        dex
                        tay
                        sta             (FTDI_GCE_PTR_LO),y
                        inx
                        bra             ?GCE_DEL_SHIFT_LEFT
?GCE_DEL_SHIFT_DONE:
                        dec             FTDI_GCE_LEN
                        ldy             FTDI_GCE_LEN
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y

                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        bne             ?GCE_DEL_HAVE_ECHO
                        jmp             ?GCE_READ_LOOP
?GCE_DEL_HAVE_ECHO:
                        ldx             FTDI_GCE_EOL
?GCE_DEL_ECHO_TAIL:
                        cpx             FTDI_GCE_LEN
                        beq             ?GCE_DEL_ECHO_SPACE
                        txa
                        tay
                        lda             (FTDI_GCE_PTR_LO),y
                        jsr             COR_FTDI_WRITE_CHAR
                        inx
                        bra             ?GCE_DEL_ECHO_TAIL
?GCE_DEL_ECHO_SPACE:
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             FTDI_GCE_LEN
                        sec
                        sbc             FTDI_GCE_EOL
                        clc
                        adc             #$01
                        tax
?GCE_DEL_ECHO_BACK:
                        cpx             #$00
                        bne             ?GCE_DEL_BACK_HAVE_COUNT
                        jmp             ?GCE_READ_LOOP
?GCE_DEL_BACK_HAVE_COUNT:
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        dex
                        bra             ?GCE_DEL_ECHO_BACK

?GCE_HANDLE_ESC:
                        jsr             ?GCE_GET_RAW_CHAR
                        cmp             #'['
                        beq             ?GCE_ESC_HAS_BRACKET
                        cmp             #'O'
                        beq             ?GCE_ESC_HAS_O
                        jmp             ?GCE_READ_LOOP
?GCE_ESC_HAS_BRACKET:
                        jsr             ?GCE_GET_RAW_CHAR
                        cmp             #'A'
                        beq             ?GCE_ESC_UP
                        cmp             #'C'
                        beq             ?GCE_ESC_RIGHT
                        cmp             #'D'
                        beq             ?GCE_ESC_LEFT
                        cmp             #'3'
                        beq             ?GCE_ESC_DEL_PARAM
                        jmp             ?GCE_READ_LOOP

?GCE_ESC_DEL_PARAM:
                        jsr             ?GCE_GET_RAW_CHAR
                        cmp             #'~'
                        bne             ?GCE_ESC_DEL_NOT_TILDE
                        jmp             ?GCE_HANDLE_DEL
?GCE_ESC_DEL_NOT_TILDE:
                        jmp             ?GCE_READ_LOOP

?GCE_ESC_HAS_O:
                        jsr             ?GCE_GET_RAW_CHAR
                        cmp             #'A'
                        beq             ?GCE_ESC_UP
                        cmp             #'C'
                        beq             ?GCE_ESC_RIGHT
                        cmp             #'D'
                        beq             ?GCE_ESC_LEFT
                        jmp             ?GCE_READ_LOOP

?GCE_ESC_UP:            jmp             ?GCE_READ_LOOP               ; hook for command history

?GCE_ESC_LEFT:
                        lda             FTDI_GCE_EOL
                        bne             ?GCE_ESC_LEFT_HAVE_CURSOR
                        jmp             ?GCE_READ_LOOP
?GCE_ESC_LEFT_HAVE_CURSOR:
                        dec             FTDI_GCE_EOL
                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        bne             ?GCE_ESC_LEFT_HAVE_ECHO
                        jmp             ?GCE_READ_LOOP
?GCE_ESC_LEFT_HAVE_ECHO:
                        lda             #$08
                        jsr             COR_FTDI_WRITE_CHAR
                        jmp             ?GCE_READ_LOOP

?GCE_ESC_RIGHT:
                        lda             FTDI_GCE_EOL
                        cmp             FTDI_GCE_LEN
                        bcc             ?GCE_ESC_RIGHT_HAVE_CURSOR
                        jmp             ?GCE_READ_LOOP
?GCE_ESC_RIGHT_HAVE_CURSOR:
                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        beq             ?GCE_ESC_RIGHT_ADV
                        ldy             FTDI_GCE_EOL
                        lda             (FTDI_GCE_PTR_LO),y
                        jsr             COR_FTDI_WRITE_CHAR
?GCE_ESC_RIGHT_ADV:
                        inc             FTDI_GCE_EOL
                        jmp             ?GCE_READ_LOOP

?GCE_HANDLE_EOL:
                        pha
                        lda             FTDI_GCE_MODE
                        and             #FTDI_GCE_MODE_ECHO
                        beq             ?GCE_NO_ECHO_EOL
                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #$0A
                        jsr             COR_FTDI_WRITE_CHAR
?GCE_NO_ECHO_EOL:
                        pla
                        tax
                        jsr             COR_FTDI_POLL_CHAR
                        bcc             ?GCE_TERM_OK
                        jsr             COR_FTDI_READ_CHAR
                        cpx             #$0D
                        beq             ?GCE_FIRST_CR
                        cmp             #$0D
                        beq             ?GCE_TERM_OK
                        bra             ?GCE_PUSHBACK
?GCE_FIRST_CR:
                        cmp             #$0A
                        beq             ?GCE_TERM_OK
?GCE_PUSHBACK:
                        sta             FTDI_GCE_PB_CH
                        lda             #$01
                        sta             FTDI_GCE_PB_VALID
?GCE_TERM_OK:
                        ldy             FTDI_GCE_LEN
                        lda             #$00
                        sta             (FTDI_GCE_PTR_LO),y
                        lda             FTDI_GCE_LEN
                        sec
                        rts

?GCE_GET_RAW_CHAR:
                        lda             FTDI_GCE_PB_VALID
                        beq             ?GCE_GET_RAW_READ
                        stz             FTDI_GCE_PB_VALID
                        lda             FTDI_GCE_PB_CH
                        rts
?GCE_GET_RAW_READ:
                        jsr             COR_FTDI_READ_CHAR
                        rts
                        ENDMOD


                        MODULE          COR_FTDI_WRITE_HEX_BYTE

                        XDEF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            UTL_HEX_BYTE_TO_ASCII_YX
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_HEX_BYTE  [RHID:6774]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit byte in A as two uppercase ASCII hex characters.
; IN : A = source byte
; OUT: C = 1 on successful writes, A preserved
; EXCEPTIONS/NOTES:
; - Uses `UTL_HEX_BYTE_TO_ASCII_YX` for nibble-to-ASCII conversion.
; - Performs two blocking writes through `BIO_FTDI_WRITE_BYTE_BLOCK`.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_HEX_BYTE:
                        PHA
                        JSR             UTL_HEX_BYTE_TO_ASCII_YX      ; Y=hi ASCII, X=lo ASCII, A preserved
                        TYA                                     ; save low nibble ASCII across first write
                        jsr             BIO_FTDI_WRITE_BYTE_BLOCK
                        TXA 
                        jsr             BIO_FTDI_WRITE_BYTE_BLOCK
                        PLA
                        rts
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CRLF

                        XDEF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CRLF  [RHID:10DC]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write CRLF sequence over FTDI.
; IN : none (A preserved)
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Calls blocking `COR_FTDI_WRITE_CHAR` twice.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CRLF:
                        PHA
                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #$0A
                        jsr             COR_FTDI_WRITE_CHAR
                        PLA
                        RTS

                        ENDMOD


                        MODULE          COR_FTDI_READ_CHAR_COOKED_ECHO

                        XDEF            COR_FTDI_READ_CHAR_COOKED_ECHO
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR

NUL                     EQU             $00
SOH                     EQU             $01
STX                     EQU             $02
ETX                     EQU             $03
EOT                     EQU             $04
ENQ                     EQU             $05
ACK                     EQU             $06
BEL                     EQU             $07
BS                      EQU             $08
HT                      EQU             $09
LF                      EQU             $0A
VT                      EQU             $0B
FF                      EQU             $0C
CR                      EQU             $0D
SO                      EQU             $0E
SI                      EQU             $0F
DLE                     EQU             $10
DC1                     EQU             $11
DC2                     EQU             $12
DC3                     EQU             $13
DC4                     EQU             $14
NAK                     EQU             $15
SYN                     EQU             $16
ETB                     EQU             $17
CAN                     EQU             $18
EM                      EQU             $19
SUB                     EQU             $1A
ESC                     EQU             $1B
FS                      EQU             $1C
GS                      EQU             $1D
RS                      EQU             $1E
US                      EQU             $1F
DEL                     EQU             $7F

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_COOKED_ECHO  [RHID:082A]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read one char, echo printable chars, normalize EOL behavior.
; IN : none
; OUT: On printable/EOL, C = 1 with normalized char in A.
;      On ignored control, C = 0.
;      On BS/DEL, C = 0 and A = BS.
; EXCEPTIONS/NOTES:
; - CR/LF are normalized to CR and echoed as CRLF.
; - Non-printable control chars (except BS/DEL/CR/LF) are ignored.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_COOKED_ECHO:
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #CR
                        beq             ?EOL
                        cmp             #LF
                        beq             ?EOL
                        CMP             #BS
                        BEQ             ?BS
                        CMP             #DEL
                        BEQ             ?BS

                        CMP             #' '
                        BCC             ?DO_NOTHING
                        CMP             #DEL
                        BCS             ?DO_NOTHING
                        JSR             COR_FTDI_WRITE_CHAR
                        sec
                        RTS

?DO_NOTHING:            clc
                        RTS 

?BS:                    CLC
                        LDA             #BS
                        RTS

?EOL:                                                           ; normalize newline echo to CRLF
                        lda             #CR
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #LF
                        jsr             COR_FTDI_WRITE_CHAR
                        SEC
                        LDA             #CR
                        rts

                        ENDMOD



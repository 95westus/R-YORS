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


                        MODULE          COR_FTDI_INIT

                        XDEF            COR_FTDI_INIT
                        XREF            BIO_FTDI_INIT

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_INIT  [HASH:FCDD]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, NO-ZP, NO-RAM, CALLS_BIO, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend initialization entry for FTDI stack.
; IN : none
; OUT: backend/HAL initialized
; EXCEPTIONS/NOTES:
; - Thin wrapper over `BIO_FTDI_INIT`.
; ----------------------------------------------------------------------------
COR_FTDI_INIT:
                        JSR             BIO_FTDI_INIT
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_FLUSH_RX

                        XDEF            COR_FTDI_FLUSH_RX
                        XREF            BIO_FTDI_FLUSH_RX

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_FLUSH_RX  [HASH:82CE]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, FLUSH, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_BIO,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend input flush entry for FTDI stack.
; IN : none
; OUT: C = 1 when flush completes
; EXCEPTIONS/NOTES:
; - Thin wrapper over `BIO_FTDI_FLUSH_RX`.
; ----------------------------------------------------------------------------
COR_FTDI_FLUSH_RX:
                        JSR             BIO_FTDI_FLUSH_RX
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_CHECK_ENUMERATED

                        XDEF            COR_FTDI_CHECK_ENUMERATED
                        XREF            PIN_FTDI_CHECK_ENUMERATED

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CHECK_ENUMERATED  [HASH:DE84]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, ENUM, NO-ZP, NO-RAM, CALLS_PIN, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Backend USB-enumeration status check.
; IN : none
; OUT: C/A semantics follow `PIN_FTDI_CHECK_ENUMERATED`
; EXCEPTIONS/NOTES:
; - Thin wrapper over `PIN_FTDI_CHECK_ENUMERATED`.
; ----------------------------------------------------------------------------
COR_FTDI_CHECK_ENUMERATED:
                        JSR             PIN_FTDI_CHECK_ENUMERATED
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_POLL_CHAR

                        XDEF            COR_FTDI_POLL_CHAR
                        XREF            BIO_FTDI_POLL_RX_READY

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_POLL_CHAR  [HASH:EC29]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, REGISTER, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_BIO, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Non-blocking check for available FTDI input byte.
; IN : none
; OUT: C = 1 if byte available, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - Thin wrapper over `BIO_FTDI_POLL_RX_READY`.
; - Register preservation follows callee behavior.
; ----------------------------------------------------------------------------
COR_FTDI_POLL_CHAR:
                        JSR             BIO_FTDI_POLL_RX_READY
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_READ_CHAR

                        XDEF            COR_FTDI_READ_CHAR
                        XREF            BIO_FTDI_READ_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR  [HASH:B8B2]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, READ, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_BIO,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI character read.
; IN : none
; OUT: A = received byte, C = 1
; EXCEPTIONS/NOTES:
; - Delegates to blocking HAL routine `BIO_FTDI_READ_BYTE_BLOCK`.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR:
                        JSR             BIO_FTDI_READ_BYTE_BLOCK
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_READ_CHAR_TIMEOUT

                        XDEF            COR_FTDI_READ_CHAR_TIMEOUT
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GCT_TMO_SLICE_X       EQU             $B6
FTDI_GCT_TMO_SLICE_Y       EQU             $F8
FTDI_GCT_TMO_CODE          EQU             $FD

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_TIMEOUT  [HASH:66B4]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, VIA, TIMEOUT, READ, CARRY-STATUS, NO-ZP,
;   USES-FIXED-RAM, CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($7BF9), DELAY_AXY_Y_INIT($7BF8)
;   via UTL_DELAY_AXY_8MHZ.
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
                        PHA
                        ; stack-local countdown byte
?POLL:                  JSR             COR_FTDI_POLL_CHAR
                        BCS             ?READ
                        PLA
                        BEQ             ?TIMEOUT
                        DEC             A
                        PHA
                        LDA             #$01
                        LDX             #FTDI_GCT_TMO_SLICE_X
                        LDY             #FTDI_GCT_TMO_SLICE_Y
                        JSR             UTL_DELAY_AXY_8MHZ
                        BRA             ?POLL

?READ:                  PLA
; discard countdown
                        JSR             COR_FTDI_READ_CHAR
                        RTS

?TIMEOUT:               LDA             #FTDI_GCT_TMO_CODE
                        CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_READ_CHAR_SPINCOUNT

                        XDEF            COR_FTDI_READ_CHAR_SPINCOUNT
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GSC_SLICE_X           EQU             $B6
FTDI_GSC_SLICE_Y           EQU             $F8

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_SPINCOUNT  [HASH:3EA0]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, VIA, TIMEOUT, CARRY-STATUS, NO-ZP,
;   USES-FIXED-RAM, CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($7BF9), DELAY_AXY_Y_INIT($7BF8)
;   via UTL_DELAY_AXY_8MHZ.
; PURPOSE: Wait for FTDI character and return elapsed spin-slice count.
; IN : none
; OUT: C = 1, A = received byte
;      X = elapsed slices low byte, Y = elapsed slices high byte
; EXCEPTIONS/NOTES:
; - Uses same slice interval as `COR_FTDI_READ_CHAR_TIMEOUT` (~28.39 ms at 8
;   MHz).
; - Wait is unbounded; X/Y wraps naturally after 65535 slices.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_SPINCOUNT:
                        LDX             #$00
                        LDY             #$00
?POLL:                  JSR             COR_FTDI_POLL_CHAR
                        BCS             ?READ
                        PHX
                        PHY
                        LDA             #$01
                        LDX             #FTDI_GSC_SLICE_X
                        LDY             #FTDI_GSC_SLICE_Y
                        JSR             UTL_DELAY_AXY_8MHZ
                        PLY
                        PLX
                        INX
                        BNE             ?POLL
                        INY
                        BRA             ?POLL

?READ:                  PHX
                        PHY
                        JSR             COR_FTDI_READ_CHAR
                        PLY
                        PLX
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN

                        XDEF            COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            UTL_DELAY_AXY_8MHZ

FTDI_GTS_SLICE_X           EQU             $B6
FTDI_GTS_SLICE_Y           EQU             $F8
FTDI_GTS_TMO_CODE          EQU             $FD

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN  [HASH:310F]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, VIA, SPINDOWN, TIMEOUT, READ, CARRY-STATUS,
;   NO-ZP, USES-FIXED-RAM, CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT($7BF9), DELAY_AXY_Y_INIT($7BF8)
;   via UTL_DELAY_AXY_8MHZ.
; PURPOSE: Timed FTDI character read with visible countdown state.
; IN : A = timeout slices (0..255), each slice ~= 28.39 ms at 8 MHz
; OUT: Success: C = 1, A = received byte, X = slices remaining (0..255)
;      Timeout: C = 0, A = $FD, X = $00
; EXCEPTIONS/NOTES:
; - Uses same slice interval as `COR_FTDI_READ_CHAR_TIMEOUT`.
; - A=0 performs immediate non-blocking check.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN:
                        TAX
                        ; X = countdown state
?POLL:                  JSR             COR_FTDI_POLL_CHAR
                        BCS             ?READ
                        CPX             #$00
                        BEQ             ?TIMEOUT
                        DEX
                        PHX
                        LDA             #$01
                        LDX             #FTDI_GTS_SLICE_X
                        LDY             #FTDI_GTS_SLICE_Y
                        JSR             UTL_DELAY_AXY_8MHZ
                        PLX
                        BRA             ?POLL

?READ:                  PHX
                        JSR             COR_FTDI_READ_CHAR
                        PLX
                        RTS

?TIMEOUT:               LDA             #FTDI_GTS_TMO_CODE
                        CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CHAR

                        XDEF            COR_FTDI_WRITE_CHAR
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR  [HASH:B5E3]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, WRITE, PRESERVE-A, CARRY-STATUS, NO-ZP,
;   NO-RAM, CALLS_BIO, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI character write.
; IN : A = byte to send
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Delegates to blocking HAL routine `BIO_FTDI_WRITE_BYTE_BLOCK`.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CHAR:
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CHAR_REPEAT

                        XDEF            COR_FTDI_WRITE_CHAR_REPEAT
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR_REPEAT  [HASH:9377]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write character in A, repeated X times.
; IN : A = byte to send, X = repeat count (0..255)
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - X=0 performs no output and returns success.
; - X is clobbered (countdown to zero).
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CHAR_REPEAT:
                        CPX             #$00
                        BEQ             ?DONE
?LOOP:                  JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        DEX
                        BNE             ?LOOP
?DONE:                  SEC
                        RTS
?FAIL:                  CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CHAR_PLUS_CRLF

                        XDEF            COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CHAR_PLUS_CRLF  [HASH:4652]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, LOWERCASE, CRLF, PRESERVE-A, CARRY-STATUS,
;   NO-ZP, NO-RAM, CALLS_COR, STACK
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
                        PHA
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        LDA             #$0D
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        LDA             #$0A
                        JSR             COR_FTDI_WRITE_CHAR
                        BCC             ?FAIL
                        PLA
                        SEC
                        RTS
?FAIL:                  PLA
                        CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_BYTES_AXY

                        XDEF            COR_FTDI_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_BYTES_AXY  [HASH:3EA1]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, PRESERVE-XY, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, STACK
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
                        PHA
                        PHX
                        PHY
                        JSR             COR_FTDI_WRITE_CHAR
                        ; emit A
                        BCC             ?FAIL
                        TXA
                        JSR             COR_FTDI_WRITE_CHAR
                        ; emit X
                        BCC             ?FAIL
                        TYA
                        JSR             COR_FTDI_WRITE_CHAR
                        ; emit Y
                        BCC             ?FAIL
                        PLY
                        PLX
                        PLA
                        SEC
                        RTS
?FAIL:                  PLY
                        PLX
                        PLA
                        CLC
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF

                        XDEF            COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF
                        XREF            COR_FTDI_WRITE_CHAR_PLUS_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_CHAR_PLUS_CRLF  [HASH:6F56]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, CRLF, PRESERVE-A, CARRY-STATUS, NO-ZP,
;   NO-RAM, CALLS_COR, NOSTACK
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
                        JSR             COR_FTDI_WRITE_CHAR_PLUS_CRLF
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_CVN_WRITE_BYTES_AXY

                        XDEF            COR_FTDI_CVN_WRITE_BYTES_AXY
                        XREF            COR_FTDI_WRITE_BYTES_AXY

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_WRITE_BYTES_AXY  [HASH:831D]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, PRESERVE-XY, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
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
                        JSR             COR_FTDI_WRITE_BYTES_AXY
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_HEX_BYTE

                        XDEF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            UTL_HEX_BYTE_TO_ASCII_YX
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_HEX_BYTE  [HASH:3BD9]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, HEX, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_BIO, STACK
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
                        JSR             UTL_HEX_BYTE_TO_ASCII_YX
                        ; Y=hi ASCII, X=lo ASCII, A preserved
                        TYA
                        ; save low nibble ASCII across first write
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        TXA 
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        PLA
                        RTS
                        ENDMOD

                        MODULE          COR_FTDI_WRITE_CRLF

                        XDEF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_WRITE_CRLF  [HASH:DCB6]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, WRITE, CRLF, PRESERVE-A, CARRY-STATUS, NO-ZP,
;   NO-RAM, CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write CRLF sequence over FTDI.
; IN : none (A preserved)
; OUT: C = 1 on success, A preserved
; EXCEPTIONS/NOTES:
; - Calls blocking `COR_FTDI_WRITE_CHAR` twice.
; ----------------------------------------------------------------------------
COR_FTDI_WRITE_CRLF:
                        PHA
                        LDA             #$0D
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             #$0A
                        JSR             COR_FTDI_WRITE_CHAR
                        PLA
                        RTS

                        ENDMOD

                        MODULE          COR_FTDI_READ_CHAR_COOKED_ECHO

                        XDEF            COR_FTDI_READ_CHAR_COOKED_ECHO
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR

NUL                        EQU             $00
SOH                        EQU             $01
STX                        EQU             $02
ETX                        EQU             $03
EOT                        EQU             $04
ENQ                        EQU             $05
ACK                        EQU             $06
BEL                        EQU             $07
BS                         EQU             $08
HT                         EQU             $09
LF                         EQU             $0A
VT                         EQU             $0B
FF                         EQU             $0C
CR                         EQU             $0D
SO                         EQU             $0E
SI                         EQU             $0F
DLE                        EQU             $10
DC1                        EQU             $11
DC2                        EQU             $12
DC3                        EQU             $13
DC4                        EQU             $14
NAK                        EQU             $15
SYN                        EQU             $16
ETB                        EQU             $17
CAN                        EQU             $18
EM                         EQU             $19
SUB                        EQU             $1A
ESC                        EQU             $1B
FS                         EQU             $1C
GS                         EQU             $1D
RS                         EQU             $1E
US                         EQU             $1F
DEL                        EQU             $7F

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CHAR_COOKED_ECHO  [HASH:5170]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, ECHO, CRLF, CARRY-STATUS, NO-ZP, NO-RAM,
;   CALLS_COR, NOSTACK
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
                        JSR             COR_FTDI_READ_CHAR
                        CMP             #CR
                        BEQ             ?EOL
                        CMP             #LF
                        BEQ             ?EOL
                        CMP             #BS
                        BEQ             ?BS
                        CMP             #DEL
                        BEQ             ?BS

                        CMP             #' '
                        BCC             ?DO_NOTHING
                        CMP             #DEL
                        BCS             ?DO_NOTHING
                        JSR             COR_FTDI_WRITE_CHAR
                        SEC
                        RTS

?DO_NOTHING:            CLC
                        RTS 

?BS:                    CLC
                        LDA             #BS
                        RTS

?EOL:
; normalize newline echo to CRLF
                        LDA             #CR
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             #LF
                        JSR             COR_FTDI_WRITE_CHAR
                        SEC
                        LDA             #CR
                        RTS

                        ENDMOD

                        END

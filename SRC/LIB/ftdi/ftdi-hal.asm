;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; I/O / SUBROUTINE CONVENTION (applies to this module and call sites):
; - A is the primary input/output register for data.
; - Carry (C) is status:
;   C=1 => operation completed/byte available
;   C=0 => timeout/not ready/not available.
; - X and Y are scratch (call-clobbered) unless a routine explicitly documents
;   preservation.

; WDC MODULE/ENDMOD guidelines for this file:
; - Use MODULE/ENDMOD around each logical unit that should export symbols.
; - XDEF = symbols this module provides to other modules.
; - XREF = symbols that come from outside this module.
; - Hardware register/constants should be local unless truly shared.
; - If symbols are shared across modules, keep names unique to avoid wdclib
;   dictionary collisions.
; - make rom rebuilds the library from module sources; make/test links
;   test.obj against rom.lib.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
; THIS FILE: L1 HAL.
; - Calls only L0 driver symbols.
; - Should not call L3/L4 symbols.
; Naming convention:
; - L1 HAL exports use `BIO_<DEVICE>_*` (this file: `BIO_FTDI_*`).
; - L1 calls L0 `PIN_<DEVICE>_*` symbols.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; PLANNED TIMEOUT API (design contract, not yet implemented):
; - HAL routine name: `BIO_FTDI_READ_BYTE_TIMEOUT`
; - IN :
;     X = timeout budget magnitude
;     Y = timeout unit/profile selector
; - OUT:
;     Success: C=1, A=received byte
;     Timeout: C=0, A=$00
; - Budget semantics:
;     X=0      => immediate return (no waiting)
;     X=1..255 => bounded timeout by unit/profile in Y
; - Unit/profile semantics:
;     Y=0 => tight poll (no delay loop)
;     Y=1 => X microseconds
;     Y=2 => X milliseconds
;     Y=3 => X seconds
;     Y>=4 => reserved (implementation should clamp or treat as invalid)
; - Notes:
;   - `_NB` remains single-check non-blocking API.
;   - Existing `BIO_FTDI_READ_BYTE_BLOCK` remains unbounded blocking API.
; -------------------------------------------------------------------------


                        MODULE          BIO_FTDI_READ_BYTE_BLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_READ_BYTE_BLOCK  [RHID:78DA]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI receive wrapper.
; IN : none
; OUT: C = 1, A = received byte
; EXCEPTIONS/NOTES:
; - Retries until `PIN_FTDI_READ_BYTE_NONBLOCK` reports ready.
; - X/Y preservation follows callee behavior.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK

BIO_FTDI_READ_BYTE_BLOCK:
                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC             BIO_FTDI_READ_BYTE_BLOCK
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_WRITE_BYTE_BLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_WRITE_BYTE_BLOCK  [RHID:B8A7]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI transmit wrapper.
; IN : A = byte to transmit
; OUT: C = 1 when byte accepted by FIFO, A preserved
; EXCEPTIONS/NOTES:
; - Retries until `PIN_FTDI_WRITE_BYTE_NONBLOCK` succeeds.
; - X preserved.
; - Y preservation follows callee behavior.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            PIN_FTDI_WRITE_BYTE_NONBLOCK

BIO_FTDI_WRITE_BYTE_BLOCK:
                        PHX
?LOOP:                  JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        BCC             ?LOOP
                        PLX
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_FLUSH_RX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_FLUSH_RX  [RHID:5A85]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Drain all currently buffered FTDI RX bytes.
; IN : none
; OUT: C = 1 when flush loop completes, A preserved
; EXCEPTIONS/NOTES:
; - Reads and discards bytes until `PIN_FTDI_POLL_RX_READY` reports empty.
; - X is clobbered as a local byte counter/rollover tracker.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                        XDEF            BIO_FTDI_FLUSH_RX
                        XREF            PIN_FTDI_POLL_RX_READY
                        XREF            BIO_FTDI_READ_BYTE_BLOCK

BIO_FTDI_FLUSH_RX:
                        PHA
                        LDX             #$00
?LOOP:                  JSR             PIN_FTDI_POLL_RX_READY
                        BCC             ?END
                        JSR             BIO_FTDI_READ_BYTE_BLOCK
                        INX
                        BNE             ?LOOP
                        DEX
                        BRA             ?LOOP
?END:                   PLA
                        SEC
                        RTS
                        ENDMOD

                        MODULE          BIO_FTDI_POLL_RX_READY

                        XDEF            BIO_FTDI_POLL_RX_READY
                        XREF            PIN_FTDI_POLL_RX_READY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_POLL_RX_READY  [RHID:1DCD]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level alias wrapper for byte-ready check.
; IN : none
; OUT: C = 1 if byte available, C = 0 otherwise
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_POLL_RX_READY`.
; - Register preservation follows callee behavior.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BIO_FTDI_POLL_RX_READY:
                        jsr             PIN_FTDI_POLL_RX_READY
                        rts
                        ENDMOD




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; I/O / SUBROUTINE CONVENTION (applies to this module and call sites):
; - A is the primary input/output register for data.
; - Carry (C) is status:
;   C=1 => operation completed/byte available
;   C=0 => timeout/not ready/not available.
; - X and Y are scratch (call-clobbered) unless a routine explicitly documents
;   preservation.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
; THIS FILE: L1 HAL.
; - Calls only L0 driver symbols.
; - Should not call L3/L4 symbols.
; Naming convention:
; - L1 HAL exports use `BIO_<DEVICE>_*` (this file: `BIO_FTDI_*`).
; - L1 calls L0 `PIN_<DEVICE>_*` symbols.
;
; NUGGET CLASS (chat naming only):
; - PUFF-PASS: direct pass-through wrapper to one PIN routine.
; - PUFF-PLUS: adds HAL policy/logic around PIN calls.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; TIMEOUT API (design contract):
; - HAL routine name: `BIO_FTDI_READ_BYTE_TMO`
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
;     Y=$00 => tight poll (no delay loop)
;     Y=$01 => 1 us slice (approximate at target clock)
;     Y=$02 => 10 us slice
;     Y=$04 => 100 us slice
;     Y=$08 => 1 ms slice
;     Y=$10 => 10 ms slice
;     Y=$20 => 100 ms slice
;     Y=$40 => 1 s slice
;     Y=$80 and non-one-hot values => invalid profile (treated as tight poll)
; - Notes:
;   - `_NB` remains single-check non-blocking API.
;   - Existing `BIO_FTDI_READ_BYTE_BLOCK` remains unbounded blocking API.
; -------------------------------------------------------------------------


                        MODULE          BIO_FTDI_INIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_INIT  [HASH:5B8E]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, INIT, NO-ZP, NO-RAM, CALLS_PIN, NOSTACK, PUFF-PASS
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level FTDI initialization wrapper.
; IN : none
; OUT: FTDI pin interface initialized
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_INIT`.
; - NUGGET CLASS (chat): PUFF-PASS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-19T00:00Z WLP2   BIO_FTDI_INIT promoted as direct PIN-pass-through.
;                          wrapper-only behavior accepted for frozen use.
                        XDEF            BIO_FTDI_INIT
                        XREF            PIN_FTDI_INIT

BIO_FTDI_INIT:
                        JSR             PIN_FTDI_INIT
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_READ_BYTE_NONBLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_READ_BYTE_NONBLOCK  [HASH:B24C]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, NONBLOCKING, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PASS,
;   CALLS_PIN, NOSTACK, RETURNS-A, BYTE, CHAR
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level non-blocking FTDI receive wrapper.
; IN : none
; OUT: C = 1 and A = received byte when ready; C = 0 and A = 0 otherwise
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_READ_BYTE_NONBLOCK`.
; - NUGGET CLASS (chat): PUFF-PASS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_READ_BYTE_NONBLOCK added as HAL alias.
;                          delegates to PIN layer non-blocking read.
; 2026-04-19T00:00Z WLP2   promoted as direct PIN-pass-through.
;                          no HAL policy added beyond driver contract.
                        XDEF            BIO_FTDI_READ_BYTE_NONBLOCK
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK
BIO_FTDI_READ_BYTE_NONBLOCK:
                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_WRITE_BYTE_NONBLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_WRITE_BYTE_NONBLOCK  [HASH:F079]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, NONBLOCKING, PRESERVE-A, CARRY-STATUS, NO-ZP, PUFF-PASS,
;   NO-RAM, CALLS_PIN, NOSTACK, BYTE, CHAR
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level non-blocking FTDI transmit wrapper.
; IN : A = byte to transmit
; OUT: C = 1 on success; C = 0 when not accepted/timeout, A preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_WRITE_BYTE_NONBLOCK`.
; - NUGGET CLASS (chat): PUFF-PASS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_WRITE_BYTE_NONBLOCK added as HAL alias.
;                          delegates to PIN layer non-blocking write.
; 2026-04-19T00:00Z WLP2   promoted as direct PIN-pass-through.
;                          no HAL policy added beyond driver contract.
                        XDEF            BIO_FTDI_WRITE_BYTE_NONBLOCK
                        XREF            PIN_FTDI_WRITE_BYTE_NONBLOCK
BIO_FTDI_WRITE_BYTE_NONBLOCK:
                        JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_CHECK_ENUMERATED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_CHECK_ENUMERATED  [HASH:BBB5]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, ENUM, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_PIN, PUFF-PASS,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level wrapper for FTDI host-enumeration state check.
; IN : none
; OUT: C = 1 and A = 1 when enumerated; C = 0 and A = 0 otherwise
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_CHECK_ENUMERATED`.
; - NUGGET CLASS (chat): PUFF-PASS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_CHECK_ENUMERATED added as HAL alias.
;                          delegates to PIN enumeration-state check.
; 2026-04-19T00:00Z WLP2   promoted as direct PIN-pass-through.
;                          no HAL policy added beyond driver contract.
                        XDEF            BIO_FTDI_CHECK_ENUMERATED
                        XREF            PIN_FTDI_CHECK_ENUMERATED
BIO_FTDI_CHECK_ENUMERATED:
                        JSR             PIN_FTDI_CHECK_ENUMERATED
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_TMO_DELAY_PROFILE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_TMO_DELAY_PROFILE  [HASH:9966]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, TIMEOUT, DELAY, PROFILE, CARRY-STATUS, NO-ZP, PUFF-PLUS,
;   NO-RAM, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Apply one timeout-delay slice selected by one-hot profile in Y.
; IN :
;   Y = one-hot profile selector:
;     $00=0us, $01=1us, $02=10us, $04=100us, $08=1ms,
;     $10=10ms, $20=100ms, $40=1s.
; OUT:
;   Delay elapsed for valid profile; invalid profiles act as tight/no-delay.
;   A/X/Y preserved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delay magnitudes are calibrated/approximate at target clock.
; - Invalid values (including multi-bit and $80) resolve to no delay.
; - NUGGET CLASS (chat): PUFF-PLUS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T23:02Z WLP2   BIO_FTDI_TMO_DELAY_PROFILE added.
;                          one-hot timeout profile scaffold centralized.
                        XDEF            BIO_FTDI_TMO_DELAY_PROFILE
BIO_FTDI_TMO_DELAY_PROFILE:
                        CPY             #$00
                        BEQ             ?DONE
                        PHA
                        PHX
                        PHY
                        CPY             #$01
                        BEQ             ?D1US
                        CPY             #$02
                        BEQ             ?D10US
                        CPY             #$04
                        BEQ             ?D100US
                        CPY             #$08
                        BEQ             ?D1MS
                        CPY             #$10
                        BEQ             ?D10MS
                        CPY             #$20
                        BEQ             ?D100MS
                        CPY             #$40
                        BEQ             ?D1S
                        BRA             ?RESTORE
?D1US:                  NOP
                        BRA             ?RESTORE
?D10US:                 LDA             #$02
                        LDX             #$04
                        JSR             ?SPIN_AX
                        BRA             ?RESTORE
?D100US:                LDA             #$10
                        LDX             #$08
                        JSR             ?SPIN_AX
                        BRA             ?RESTORE
?D1MS:                  LDA             #$20
                        LDX             #$28
                        JSR             ?SPIN_AX
                        BRA             ?RESTORE
?D10MS:                 LDA             #$40
                        LDX             #$78
                        JSR             ?SPIN_AX
                        BRA             ?RESTORE
?D100MS:                LDY             #$0A
?D100MS_LOOP:           PHY
                        LDA             #$40
                        LDX             #$78
                        JSR             ?SPIN_AX
                        PLY
                        DEY
                        BNE             ?D100MS_LOOP
                        BRA             ?RESTORE
?D1S:                   LDY             #$64
?D1S_LOOP:              PHY
                        LDA             #$40
                        LDX             #$78
                        JSR             ?SPIN_AX
                        PLY
                        DEY
                        BNE             ?D1S_LOOP
?RESTORE:               PLY
                        PLX
                        PLA
?DONE:                  RTS

; IN : A=inner-count seed, X=outer-count
; OUT: A preserved, X/Y clobbered
?SPIN_AX:               TAY
?SPIN_OUTER:            DEY
                        BNE             ?SPIN_OUTER
                        DEX
                        BEQ             ?SPIN_DONE
                        TAY
                        BRA             ?SPIN_OUTER
?SPIN_DONE:             RTS
                        ENDMOD


                        MODULE          BIO_FTDI_READ_BYTE_TMO
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_READ_BYTE_TMO  [HASH:C10A]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, TIMEOUT, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_PIN, PUFF-PLUS,
;   RETURNS-A, BYTE, CHAR, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Bounded FTDI receive using non-blocking read retries.
; IN :
;   X = timeout budget magnitude (0 = immediate single-check)
;   Y = one-hot timeout profile ($00,$01,$02,$04,$08,$10,$20,$40)
; OUT:
;   Success: C = 1, A = received byte
;   Timeout: C = 0, A = 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Uses centralized one-hot delay profile helper between retries.
; - X/Y are scratch by convention.
; - NUGGET CLASS (chat): PUFF-PLUS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_READ_BYTE_TMO added.
;                          bounded non-blocking read retry API.
; 2026-04-18T23:02Z WLP2   delay profile logic centralized via helper.
                        XDEF            BIO_FTDI_READ_BYTE_TMO
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK
                        XREF            BIO_FTDI_TMO_DELAY_PROFILE
BIO_FTDI_READ_BYTE_TMO:
                        CPX             #$00
                        BNE             ?LOOP
                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        RTS
?LOOP:                  JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCS             ?SUCCESS
                        DEX
                        BEQ             ?TIMEOUT
                        JSR             BIO_FTDI_TMO_DELAY_PROFILE
                        BRA             ?LOOP
?SUCCESS:               RTS
?TIMEOUT:               LDA             #$00
                        CLC
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_WRITE_BYTE_TMO
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_WRITE_BYTE_TMO  [HASH:9ABD]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, TIMEOUT, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, STACK, BYTE, CHAR
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Bounded FTDI transmit using non-blocking write retries.
; IN :
;   A = byte to transmit
;   X = timeout budget magnitude (0 = immediate single-check)
;   Y = one-hot timeout profile ($00,$01,$02,$04,$08,$10,$20,$40)
; OUT:
;   Success: C = 1, A preserved
;   Timeout: C = 0, A preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Uses centralized one-hot delay profile helper between retries.
; - X/Y are scratch by convention.
; - NUGGET CLASS (chat): PUFF-PLUS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_WRITE_BYTE_TMO added.
;                          bounded non-blocking write retry API.
; 2026-04-18T23:02Z WLP2   delay profile logic centralized via helper.
                        XDEF            BIO_FTDI_WRITE_BYTE_TMO
                        XREF            PIN_FTDI_WRITE_BYTE_NONBLOCK
                        XREF            BIO_FTDI_TMO_DELAY_PROFILE
BIO_FTDI_WRITE_BYTE_TMO:
                        CPX             #$00
                        BNE             ?LOOP
                        JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        RTS
?LOOP:                  JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        BCS             ?SUCCESS
                        DEX
                        BEQ             ?TIMEOUT
                        JSR             BIO_FTDI_TMO_DELAY_PROFILE
                        BRA             ?LOOP
?SUCCESS:               RTS
?TIMEOUT:               CLC
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_WAIT_RX_READY_TMO
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_WAIT_RX_READY_TMO  [HASH:E64D]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, WAIT, TIMEOUT, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Wait for RX-ready state without consuming data.
; IN :
;   X = timeout budget magnitude (0 = immediate single-check)
;   Y = one-hot timeout profile ($00,$01,$02,$04,$08,$10,$20,$40)
; OUT:
;   Ready:   C = 1
;   Timeout: C = 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Uses centralized one-hot delay profile helper between polls.
; - X/Y are scratch by convention.
; - NUGGET CLASS (chat): PUFF-PLUS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_WAIT_RX_READY_TMO added.
;                          bounded wait-for-ready API without consume.
; 2026-04-18T23:02Z WLP2   delay profile logic centralized via helper.
                        XDEF            BIO_FTDI_WAIT_RX_READY_TMO
                        XREF            PIN_FTDI_POLL_RX_READY
                        XREF            BIO_FTDI_TMO_DELAY_PROFILE
BIO_FTDI_WAIT_RX_READY_TMO:
                        CPX             #$00
                        BNE             ?LOOP
                        JSR             PIN_FTDI_POLL_RX_READY
                        RTS
?LOOP:                  JSR             PIN_FTDI_POLL_RX_READY
                        BCS             ?SUCCESS
                        DEX
                        BEQ             ?TIMEOUT
                        JSR             BIO_FTDI_TMO_DELAY_PROFILE
                        BRA             ?LOOP
?SUCCESS:               RTS
?TIMEOUT:               CLC
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_DRAIN_RX_MAX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_DRAIN_RX_MAX  [HASH:A890]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, FLUSH, DRAIN, BOUNDED, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, RETURNS-A, REGISTER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Drain up to X currently buffered RX bytes (bounded flush).
; IN : X = max bytes to drain (0..255)
; OUT: C = 1, A = drained-byte count (0..X)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Stops early when `PIN_FTDI_READ_BYTE_NONBLOCK` reports empty.
; - If X bytes are drained, routine returns without checking for additional data.
; - NUGGET CLASS (chat): PUFF-PLUS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-18T22:02Z WLP2   BIO_FTDI_DRAIN_RX_MAX added.
;                          bounded RX drain API with count return.
                        XDEF            BIO_FTDI_DRAIN_RX_MAX
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK
BIO_FTDI_DRAIN_RX_MAX:
                        CPX             #$00
                        BEQ             ?DONE_EMPTY
                        LDY             #$00
?LOOP:                  JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC             ?DONE
                        INY
                        DEX
                        BNE             ?LOOP
?DONE:                  TYA
                        SEC
                        RTS
?DONE_EMPTY:            LDA             #$00
                        SEC
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_READ_BYTE_BLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_READ_BYTE_BLOCK  [HASH:9381]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, BLOCKING, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, NOSTACK, RETURNS-A, BYTE, CHAR
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI receive wrapper.
; IN : none
; OUT: C = 1, A = received byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Retries until `PIN_FTDI_READ_BYTE_NONBLOCK` reports ready.(BLOCK FOREVER)
; - X/Y preservation follows callee behavior.
; - At this time, only a BYTE being read or an interrupt will get us out of
; - this.
; - Should this routine set a long timeout and return C=0
; - NUGGET CLASS (chat): PUFF-PLUS.

                        XDEF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK

BIO_FTDI_READ_BYTE_BLOCK:
                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC             BIO_FTDI_READ_BYTE_BLOCK
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_WRITE_BYTE_BLOCK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_WRITE_BYTE_BLOCK  [HASH:CC74]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, BLOCKING, PRESERVE-A, CARRY-STATUS, NO-ZP, PUFF-PLUS,
;   NO-RAM, STACK, BYTE, CHAR
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Blocking FTDI transmit wrapper.
; IN : A = byte to transmit
; OUT: C = 1 when byte accepted by FIFO, A preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Retries until `PIN_FTDI_WRITE_BYTE_NONBLOCK` succeeds.
; - X preserved.
; - Y preservation follows callee behavior.
; - A hardware fault/configuration/driver error might prevent us from
; - returning. Should we spin here for a while?
; - NUGGET CLASS (chat): PUFF-PLUS.

                        XDEF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            PIN_FTDI_WRITE_BYTE_NONBLOCK

BIO_FTDI_WRITE_BYTE_BLOCK:
                        PHX
?LOOP:                  JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        BCC             ?LOOP
                        PLX
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_FLUSH_RX_COUNT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_FLUSH_RX_COUNT  [HASH:E1AF]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, FLUSH, COUNT, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, REGISTER
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Drain buffered FTDI RX bytes and return flushed-byte count.
; IN : none
; OUT: C = 1 on completion, A = 8-bit flush count (0-FF, saturates)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Reads/discards bytes via `PIN_FTDI_READ_BYTE_NONBLOCK` until FIFO empty.
; - Y preservation follows callee behavior.
; - Returns when non-blocking read reports no byte available (C=0).
; - NUGGET CLASS (chat): PUFF-PLUS.

                        XDEF            BIO_FTDI_FLUSH_RX_COUNT
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK

BIO_FTDI_FLUSH_RX_COUNT:
                        LDX             #$00
?COUNT_LOOP:            JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC             ?COUNT_END
                        INX
                        BNE             ?COUNT_LOOP
                        DEX
                        BRA             ?COUNT_LOOP
?COUNT_END:             SEC
                        TXA
                        RTS
                        ENDMOD


                        MODULE          BIO_FTDI_FLUSH_RX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_FLUSH_RX  [HASH:20FF]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, FTDI, FLUSH, PRESERVE-A, CARRY-STATUS, NO-ZP, NO-RAM, PUFF-PLUS,
;   CALLS_PIN, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Drain all currently buffered FTDI RX bytes.
; IN : none
; OUT: C = 1 when flush loop completes, A preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Independent flush loop; does not call `BIO_FTDI_FLUSH_RX_COUNT`.
; - Use `BIO_FTDI_FLUSH_RX_COUNT` when the drained-byte count is needed.
; - Drains bytes via `PIN_FTDI_READ_BYTE_NONBLOCK` until FIFO empty (C=0).
; - NUGGET CLASS (chat): PUFF-PLUS.
                        XDEF            BIO_FTDI_FLUSH_RX
                        XREF            PIN_FTDI_READ_BYTE_NONBLOCK
BIO_FTDI_FLUSH_RX:
                        PHA
?LOOP:                  JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCC             ?FLUSH_END
                        BRA             ?LOOP
?FLUSH_END:             PLA
                        SEC
                        RTS
                        ENDMOD

                        MODULE          BIO_FTDI_POLL_RX_READY

                        XDEF            BIO_FTDI_POLL_RX_READY
                        XREF            PIN_FTDI_POLL_RX_READY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ROUTINE: BIO_FTDI_POLL_RX_READY  [HASH:5A0C]
; TIER: HAL-L1
; TAGS: BIO, HAL-L1, REGISTER, CARRY-STATUS, NO-ZP, NO-RAM, CALLS_PIN, NOSTACK, PUFF-PASS
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: HAL-level alias wrapper for byte-ready check.
; IN : none
; OUT: C = 1 if byte available, C = 0 otherwise
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXCEPTIONS/NOTES:
; - Delegates directly to `PIN_FTDI_POLL_RX_READY`.
; - Register preservation follows callee behavior.
; - NUGGET CLASS (chat): PUFF-PASS.
;
; CHANGELOG:
; YYYY-MM-DDTHH:MMZ AUTHOR SUMMARY
; 2026-04-19T00:00Z WLP2   BIO_FTDI_POLL_RX_READY promoted as direct
;                          PIN-pass-through wrapper.
BIO_FTDI_POLL_RX_READY:
                        JSR             PIN_FTDI_POLL_RX_READY
                        RTS
                        ENDMOD




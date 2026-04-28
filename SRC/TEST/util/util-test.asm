; -------------------------------------------------------------------------
; Test utility helpers shared by interactive harness code.
; Kept in rom.lib via Makefile wildcard `util-*.asm` (single-lib workflow).
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-*.asm       -> reusable helpers.
; L3 (Access): lock/access-policy -> capability gates, lock/unlock, privilege
;   checks.
; L4 (Sys):    sys-*.asm        -> device-neutral I/O API (SYS_*), calls
;   L3/L2.
; L5 (App):    app/*.asm        -> monitor/app entry points.
; TEST (Out-of-band): test/*.asm -> test harnesses (not part of layer ABI).
; -------------------------------------------------------------------------

                        MODULE          TST_PUTS_XY

                        XDEF            TST_PUTS_XY
                        XREF            COR_FTDI_WRITE_CSTRING

; ----------------------------------------------------------------------------
; ROUTINE: TST_PUTS_XY  [HASH:5745]
; TIER: APP-L5
; TAGS: TST, APP-L5, NUL-TERM, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit NUL-terminated string at X/Y through backend string writer.
; IN : X/Y = pointer to NUL-terminated string
; OUT: C/A semantics follow `COR_FTDI_WRITE_CSTRING`
; EXCEPTIONS/NOTES:
; - Test/reporting helper; intentionally test-scoped (`TST_*`).
; ----------------------------------------------------------------------------
TST_PUTS_XY:
                        JSR             COR_FTDI_WRITE_CSTRING
                        RTS
                        ENDMOD


                        MODULE          TST_PUTS_HB_XY

                        XDEF            TST_PUTS_HB_XY
                        XREF            COR_FTDI_WRITE_HBSTRING

; ----------------------------------------------------------------------------
; ROUTINE: TST_PUTS_HB_XY  [HASH:29A2]
; TIER: APP-L5
; TAGS: TST, APP-L5, HIBIT-TERM, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit HIBIT-terminated string at X/Y through backend string writer.
; IN : X/Y = pointer to HIBIT-terminated string
; OUT: C/A semantics follow `COR_FTDI_WRITE_HBSTRING`
; EXCEPTIONS/NOTES:
; - Test/reporting helper; intentionally test-scoped (`TST_*`).
; ----------------------------------------------------------------------------
TST_PUTS_HB_XY:
                        JSR             COR_FTDI_WRITE_HBSTRING
                        RTS
                        ENDMOD


                        MODULE          TST_PRINT_LINE_XY

                        XDEF            TST_PRINT_LINE_XY
                        XREF            TST_PUTS_XY
                        XREF            COR_FTDI_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: TST_PRINT_LINE_XY  [HASH:6A23]
; TIER: APP-L5
; TAGS: TST, APP-L5, WRITE, NUL-TERM, CRLF, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit NUL-terminated string at X/Y followed by CRLF.
; IN : X/Y = pointer to NUL-terminated string
; OUT: C follows trailing CRLF write path
; EXCEPTIONS/NOTES:
; - Test/reporting helper; intentionally test-scoped (`TST_*`).
; ----------------------------------------------------------------------------
TST_PRINT_LINE_XY:
                        JSR             TST_PUTS_XY
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS
                        ENDMOD


                        MODULE          TST_PRINT_CARRY_BIT_A

                        XDEF            TST_PRINT_CARRY_BIT_A
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: TST_PRINT_CARRY_BIT_A  [HASH:B4A2]
; TIER: APP-L5
; TAGS: TST, APP-L5, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Print low bit of A as ASCII '0' or '1'.
; IN : A = value whose bit0 is printed
; OUT: one ASCII bit emitted
; EXCEPTIONS/NOTES:
; - Uses `COR_FTDI_WRITE_CHAR` for output.
; ----------------------------------------------------------------------------
TST_PRINT_CARRY_BIT_A:
                        AND             #$01
                        ORA             #'0'
                        JSR             COR_FTDI_WRITE_CHAR
                        RTS
                        ENDMOD


                        MODULE          TST_PRINT_CARRY_FROM_LAST_C

                        XDEF            TST_PRINT_CARRY_FROM_LAST_C
                        XREF            COR_FTDI_WRITE_CHAR

; ----------------------------------------------------------------------------
; ROUTINE: TST_PRINT_CARRY_FROM_LAST_C  [HASH:E002]
; TIER: APP-L5
; TAGS: TST, APP-L5, NO-ZP, NO-RAM, CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Print current carry flag as ASCII '0' or '1'.
; IN : carry flag from previous operation
; OUT: one ASCII bit emitted
; EXCEPTIONS/NOTES:
; - Preserves original A by extracting carry through stack flags.
; ----------------------------------------------------------------------------
TST_PRINT_CARRY_FROM_LAST_C:
                        PHP
                        PLA
                        AND             #$01
                        ORA             #'0'
                        JSR             COR_FTDI_WRITE_CHAR
                        RTS
                        ENDMOD

                        END

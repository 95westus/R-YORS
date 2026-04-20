; -------------------------------------------------------------------------
; FTDI JSR debug helper (minimal port from bso2 monitor debug path).
;
; Scope intentionally limited:
; - FTDI output only.
; - JSR-call context only.
; - No IRQ/NMI/BRK hooks, no disassembly output.
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
; THIS FILE: L2 BACKEND (FTDI-DEBUG).
; - Exports FTDI-specific debug helper for JSR context.
; -------------------------------------------------------------------------

                        MODULE          COR_FTDI_DEBUG_JSR_SNAPSHOT

                        XDEF            COR_FTDI_DEBUG_JSR_SNAPSHOT
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_HEX_BYTE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_DEBUG_JSR_SNAPSHOT  [HASH:9DB3]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, REGISTER, WRITE, IRQ, NMI, NO-ZP, NO-RAM,
;   CALLS_COR, STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Emit a compact JSR debug snapshot over FTDI.
; IN : A/X/Y = caller register values at debug call site
; OUT: A/X/Y restored to caller-entry values
; FLAGS: carry follows final backend character-write path
;   "stop: JSR  pc:HHLL"
;   "regs: A=HH X=HH Y=HH P=HH S=HH [NV-BDIZC]"
; EXCEPTIONS/NOTES:
; - Prints:
; - Captures JSR return address from stack and reports next PC (= return+1).
; - Deliberately does not hook or decode IRQ/NMI/BRK context.
; ----------------------------------------------------------------------------
COR_FTDI_DEBUG_JSR_SNAPSHOT:
                        PHA
                        ; Save caller A
                        TXA
                        PHA
                        ; Save caller X
                        TYA
                        PHA
                        ; Save caller Y
                        PHP
                        PLA
                        PHA
                        ; Save caller P snapshot

                        JSR             COR_FTDI_WRITE_CRLF
                        LDX             #<DBG_STR_STOP_JSR_PC
                        LDY             #>DBG_STR_STOP_JSR_PC
                        JSR             COR_FTDI_DEBUG_WRITE_STR

                        TSX
                        ; Stack after 4 pushes:
                                                                ; +1=P +2=Y
                                                                ;   +3=X +4=A
                                                                ;   +5=retL
                                                                ;   +6=retH
                        LDA             $105,X                  ; return low
                        CLC
                        ADC             #$01                    ; next PC low
                        PHA
                        ; temporary save low byte
                        LDA             $106,X                  ; return high
                        ADC             #$00                    ; next PC high
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        PLA
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        JSR             COR_FTDI_WRITE_CRLF
                        LDX             #<DBG_STR_REGS_A
                        LDY             #>DBG_STR_REGS_A
                        JSR             COR_FTDI_DEBUG_WRITE_STR
                        TSX
                        LDA             $104,X
                        ; saved caller A
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        LDX             #<DBG_STR_X_EQ
                        LDY             #>DBG_STR_X_EQ
                        JSR             COR_FTDI_DEBUG_WRITE_STR
                        TSX
                        LDA             $103,X
                        ; saved caller X
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        LDX             #<DBG_STR_Y_EQ
                        LDY             #>DBG_STR_Y_EQ
                        JSR             COR_FTDI_DEBUG_WRITE_STR
                        TSX
                        LDA             $102,X
                        ; saved caller Y
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        LDX             #<DBG_STR_P_EQ
                        LDY             #>DBG_STR_P_EQ
                        JSR             COR_FTDI_DEBUG_WRITE_STR
                        TSX
                        LDA             $101,X
                        ; saved caller P
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        LDX             #<DBG_STR_S_EQ
                        LDY             #>DBG_STR_S_EQ
                        JSR             COR_FTDI_DEBUG_WRITE_STR
                        TSX
                        TXA
                        CLC
                        ADC             #$06
                        ; reconstruct SP before JSR
                        JSR             COR_FTDI_WRITE_HEX_BYTE

                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR
                        TSX
                        LDA             $101,X
                        ; saved caller P
                        JSR             COR_FTDI_DEBUG_WRITE_FLAGS_A
                        JSR             COR_FTDI_WRITE_CRLF

                        PLA
                        ; discard saved P snapshot
                        PLA
                        TAY
                        ; restore caller Y
                        PLA
                        TAX
                        ; restore caller X
                        PLA
                        ; restore caller A
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_DEBUG_WRITE_STR  [HASH:9F98]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, FTDI, WRITE, NUL-TERM, NO-ZP, NO-RAM, CALLS_COR,
;   NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Write NUL-terminated literal string at X/Y over FTDI.
; IN : X/Y = pointer to string
; OUT: C follows COR_FTDI_WRITE_CSTRING status
; FLAGS: carry follows COR_FTDI_WRITE_CSTRING
;   fixed 255-byte cap.
;   caller-side length policy.
; EXCEPTIONS/NOTES:
; - Backend currently ignores A for max-length policy and enforces its own
; - `LDA #$7F` is retained here as a documentation breadcrumb for intended
; ----------------------------------------------------------------------------
COR_FTDI_DEBUG_WRITE_STR:
                        LDA             #$7F
                        JSR             COR_FTDI_WRITE_CSTRING
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_DEBUG_WRITE_FLAGS_A  [HASH:4670]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, WRITE, NO-ZP, NO-RAM, CALLS_COR, NOSTACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Print flags byte A as bracketed "NV-BDIZC" with lowercase when
;   clear.
; IN : A = status byte
; OUT: C follows final character write
; FLAGS: carry follows final COR_FTDI_WRITE_CHAR call
; EXCEPTIONS/NOTES:
; - X is clobbered.
; ----------------------------------------------------------------------------
COR_FTDI_DEBUG_WRITE_FLAGS_A:
                        TAX

                        LDA             #'['
                        JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$80
                        BEQ             ?NEG_CLR
                        LDA             #'N'
                        BRA             ?NEG_OUT
?NEG_CLR:               LDA             #'n'
?NEG_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$40
                        BEQ             ?OVF_CLR
                        LDA             #'V'
                        BRA             ?OVF_OUT
?OVF_CLR:               LDA             #'v'
?OVF_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        LDA             #'-'
                        JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$10
                        BEQ             ?BRK_CLR
                        LDA             #'B'
                        BRA             ?BRK_OUT
?BRK_CLR:               LDA             #'b'
?BRK_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$08
                        BEQ             ?DEC_CLR
                        LDA             #'D'
                        BRA             ?DEC_OUT
?DEC_CLR:               LDA             #'d'
?DEC_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$04
                        BEQ             ?IRQ_CLR
                        LDA             #'I'
                        BRA             ?IRQ_OUT
?IRQ_CLR:               LDA             #'i'
?IRQ_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$02
                        BEQ             ?ZER_CLR
                        LDA             #'Z'
                        BRA             ?ZER_OUT
?ZER_CLR:               LDA             #'z'
?ZER_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        TXA
                        AND             #$01
                        BEQ             ?CAR_CLR
                        LDA             #'C'
                        BRA             ?CAR_OUT
?CAR_CLR:               LDA             #'c'
?CAR_OUT:               JSR             COR_FTDI_WRITE_CHAR

                        LDA             #']'
                        JSR             COR_FTDI_WRITE_CHAR
                        RTS

DBG_STR_STOP_JSR_PC:    DB              "stop: JSR  pc:", 0
DBG_STR_REGS_A:         DB              "regs: A=", 0
DBG_STR_X_EQ:           DB              " X=", 0
DBG_STR_Y_EQ:           DB              " Y=", 0
DBG_STR_P_EQ:           DB              " P=", 0
DBG_STR_S_EQ:           DB              " S=", 0

                        ENDMOD

; -------------------------------------------------------------------------
; Device-neutral vector dispatch and patch API.
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
; THIS FILE: L4 SYS VECTOR/TRAP CORE.
; - Exposes entry stubs to be targeted by ROM vectors at FFFA-FFFF.
; - Maintains patchable RAM vectors for RESET/NMI/IRQ-BRK/IRQ-NONBRK.
; - Keeps IRQ master dispatch straight-line and short.
; -------------------------------------------------------------------------

                        MODULE          SYS_VEC_INIT

VEC_RESET_LO              EQU             $7EF8
VEC_RESET_HI              EQU             $7EF9
VEC_NMI_LO                EQU             $7EFA
VEC_NMI_HI                EQU             $7EFB
VEC_IRQ_BRK_LO            EQU             $7EFC
VEC_IRQ_BRK_HI            EQU             $7EFD
VEC_IRQ_NONBRK_LO         EQU             $7EFE
VEC_IRQ_NONBRK_HI         EQU             $7EFF

                        XDEF            SYS_VEC_INIT
                        XDEF            SYS_VEC_ENTRY_RESET
                        XDEF            SYS_VEC_ENTRY_NMI
                        XDEF            SYS_VEC_ENTRY_IRQ_MASTER
                        XDEF            SYS_VEC_SET_RESET_XY
                        XDEF            SYS_VEC_SET_NMI_XY
                        XDEF            SYS_VEC_SET_IRQ_BRK_XY
                        XDEF            SYS_VEC_SET_IRQ_NONBRK_XY
                        XDEF            SYS_VEC_DEFAULT_RESET
                        XDEF            SYS_VEC_DEFAULT_NMI
                        XDEF            SYS_VEC_DEFAULT_IRQ_BRK
                        XDEF            SYS_VEC_DEFAULT_IRQ_NONBRK
                        XREF            SYS_DEBUG_JSR_SNAPSHOT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_INIT  [HASH:C5FE6C62]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, RESET, IRQ, NMI, BRK, FIXED-RAM, IRQ, NOSTACK
; PURPOSE: Seed patchable vector cells with safe default handlers.
; IN : none
; OUT: vector table cells initialized
; FLAGS: restored to caller entry state
; EXCEPTIONS/NOTES:
; - Uses PHP/SEI/PLP so vector writes are atomic against IRQ arrival.
; ----------------------------------------------------------------------------
SYS_VEC_INIT:
                        PHP
                        SEI

                        LDA             #<SYS_VEC_DEFAULT_RESET
                        STA             VEC_RESET_LO
                        LDA             #>SYS_VEC_DEFAULT_RESET
                        STA             VEC_RESET_HI

                        LDA             #<SYS_VEC_DEFAULT_NMI
                        STA             VEC_NMI_LO
                        LDA             #>SYS_VEC_DEFAULT_NMI
                        STA             VEC_NMI_HI

                        LDA             #<SYS_VEC_DEFAULT_IRQ_BRK
                        STA             VEC_IRQ_BRK_LO
                        LDA             #>SYS_VEC_DEFAULT_IRQ_BRK
                        STA             VEC_IRQ_BRK_HI

                        LDA             #<SYS_VEC_DEFAULT_IRQ_NONBRK
                        STA             VEC_IRQ_NONBRK_LO
                        LDA             #>SYS_VEC_DEFAULT_IRQ_NONBRK
                        STA             VEC_IRQ_NONBRK_HI

                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_ENTRY_RESET  [HASH:4EA53CFC]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, RESET, NOSTACK
; PURPOSE: RESET vector entry stub. Jumps through patchable RESET target.
; IN : CPU RESET context
; OUT: transfer to current RESET target
; ----------------------------------------------------------------------------
SYS_VEC_ENTRY_RESET:
                        JMP             (VEC_RESET_LO)

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_ENTRY_NMI  [HASH:F8F789CB]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, NMI, NOSTACK
; PURPOSE: NMI vector entry stub. Jumps through patchable NMI target.
; IN : CPU NMI context
; OUT: transfer to current NMI target
; ----------------------------------------------------------------------------
SYS_VEC_ENTRY_NMI:
                        JMP             (VEC_NMI_LO)

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_ENTRY_IRQ_MASTER  [HASH:72D99F9C]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, IRQ, BRK, NOSTACK
; PURPOSE: IRQ master dispatch. Splits BRK vs non-BRK and jumps via patchable
;   targets.
; IN : CPU IRQ/BRK context (stack frame already pushed by CPU)
; OUT: transfer to current BRK or non-BRK IRQ target
; EXCEPTIONS/NOTES:
; - Preserves interrupted A/X across BRK-vs-IRQ split.
; - B flag test uses bit 4 from stacked status byte.
; ----------------------------------------------------------------------------
SYS_VEC_ENTRY_IRQ_MASTER:
                        PHA
                        PHX
                        TSX
                        LDA             $0103,X
                        AND             #$10
                        BEQ             SYS_VEC_IRQ_MASTER_NONBRK
                        PLX
                        PLA
                        JMP             (VEC_IRQ_BRK_LO)
SYS_VEC_IRQ_MASTER_NONBRK:
                        PLX
                        PLA
                        JMP             (VEC_IRQ_NONBRK_LO)

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_SET_RESET_XY  [HASH:90CB06AA]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, RESET, IRQ, FIXED-RAM, NOSTACK
; PURPOSE: Atomically patch RESET target vector.
; IN : X/Y = target address low/high
; OUT: RESET patch cell updated
; FLAGS: restored to caller entry state
; ----------------------------------------------------------------------------
SYS_VEC_SET_RESET_XY:
                        PHP
                        SEI
                        TXA
                        STA             VEC_RESET_LO
                        TYA
                        STA             VEC_RESET_HI
                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_SET_NMI_XY  [HASH:2EEF6FC3]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, NMI, IRQ, FIXED-RAM, NOSTACK
; PURPOSE: Atomically patch NMI target vector.
; IN : X/Y = target address low/high
; OUT: NMI patch cell updated
; FLAGS: restored to caller entry state
; ----------------------------------------------------------------------------
SYS_VEC_SET_NMI_XY:
                        PHP
                        SEI
                        TXA
                        STA             VEC_NMI_LO
                        TYA
                        STA             VEC_NMI_HI
                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_SET_IRQ_BRK_XY  [HASH:0DFCEEC3]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, IRQ, BRK, FIXED-RAM, NOSTACK
; PURPOSE: Atomically patch IRQ BRK breakout target vector.
; IN : X/Y = target address low/high
; OUT: IRQ BRK patch cell updated
; FLAGS: restored to caller entry state
; ----------------------------------------------------------------------------
SYS_VEC_SET_IRQ_BRK_XY:
                        PHP
                        SEI
                        TXA
                        STA             VEC_IRQ_BRK_LO
                        TYA
                        STA             VEC_IRQ_BRK_HI
                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_SET_IRQ_NONBRK_XY  [HASH:14E4B2B4]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, IRQ, FIXED-RAM, NOSTACK
; PURPOSE: Atomically patch IRQ non-BRK breakout target vector.
; IN : X/Y = target address low/high
; OUT: IRQ non-BRK patch cell updated
; FLAGS: restored to caller entry state
; ----------------------------------------------------------------------------
SYS_VEC_SET_IRQ_NONBRK_XY:
                        PHP
                        SEI
                        TXA
                        STA             VEC_IRQ_NONBRK_LO
                        TYA
                        STA             VEC_IRQ_NONBRK_HI
                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_DEFAULT_RESET  [HASH:DE3C6189]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, RESET, NOSTACK
; PURPOSE: Fail-safe default RESET target until board-specific patching.
; IN : transfer from SYS_VEC_ENTRY_RESET
; OUT: none (halts in-place)
; ----------------------------------------------------------------------------
SYS_VEC_DEFAULT_RESET:
                        SEI
SYS_VEC_DEFAULT_RESET_HALT:
                        BRA             SYS_VEC_DEFAULT_RESET_HALT

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_DEFAULT_NMI  [HASH:B589D492]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, NMI, NOSTACK
; PURPOSE: Default NMI target: enter debug snapshot, then return from NMI.
; ----------------------------------------------------------------------------
SYS_VEC_DEFAULT_NMI:
                        JSR             SYS_DEBUG_JSR_SNAPSHOT
                        RTI

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_DEFAULT_IRQ_BRK  [HASH:BC9E454E]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, IRQ, BRK, NOSTACK
; PURPOSE: Default BRK breakout target: return until monitor patch is installed.
; ----------------------------------------------------------------------------
SYS_VEC_DEFAULT_IRQ_BRK:
                        RTI

; ----------------------------------------------------------------------------
; ROUTINE: SYS_VEC_DEFAULT_IRQ_NONBRK  [HASH:777DCE1D]
; TIER: SYS-L4
; TAGS: SYS, SYS-L4, VECTOR, IRQ, NOSTACK
; PURPOSE: Default non-BRK IRQ breakout target: return until IRQ owner patches.
; ----------------------------------------------------------------------------
SYS_VEC_DEFAULT_IRQ_NONBRK:
                        RTI

                        ENDMOD

                        END

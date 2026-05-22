; -------------------------------------------------------------------------
; Basic flash programming primitives for the currently visible ROM bank.
; -------------------------------------------------------------------------
;
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-*.asm       -> pure utility routines, no hardware access.
; L3 (Access): lock/access-policy -> capability gates, lock/unlock, privilege
;   checks.
; L4 (Sys):    sys-*.asm        -> device-neutral I/O API (SYS_*), calls
;   L3/L2.
; L5 (App):    app/*.asm        -> monitor/app entry points.
; TEST (Out-of-band): test/*.asm -> test harnesses (not part of layer ABI).
;
; ZP ALLOCATION POLICY
; - Uses the reserved ZP_EXT16 window as volatile flash-call workspace.
;
; THIS FILE: low-level flash service.
; - Public wrappers execute from ROM only while copying/setup is safe.
; - Actual erase/program command sequences execute from RAM at $1300.
; - Erase API granularity is one 4K sector per call. Code that needs to erase
;   $8xxx and $9xxx must call FLASH_SECTOR_ERASE_XY twice.
; - The protected monitor region is $D000-$FFFF; public entry points only
;   accept targets in $8000-$CFFF.
; - Bank selection is intentionally out of scope here.
; -------------------------------------------------------------------------

                        MODULE          FLASH_CORE

                        XDEF            FLASH_ADDR_ALLOWED_XY
                        XDEF            FLASH_SECTOR_ERASE_XY
                        XDEF            FLASH_SECTOR_ERASE_RAW_XY
                        XDEF            FLASH_WRITE_BYTE_AXY
                        XDEF            FLASH_WRITE_BYTE_RAW_AXY

FLASH_RAM_WORKER          EQU             $1300
FLASH_TARGET_MIN_HI       EQU             $80
FLASH_PROTECT_HI          EQU             $D0
FLASH_UNLOCK1             EQU             $D555
FLASH_UNLOCK2             EQU             $AAAA

FLASH_OP_WRITE_BYTE       EQU             $01
FLASH_OP_ERASE_SECTOR     EQU             $02
FLASH_ERASE_TIMEOUT_HI    EQU             $08
FLASH_WRITE_TIMEOUT_HI    EQU             $02

FLASH_ADDR_LO             EQU             $CD
FLASH_ADDR_HI             EQU             $CE
FLASH_DATA                EQU             $CF
FLASH_OP                  EQU             $D0
FLASH_TMO0                EQU             $D1
FLASH_TMO1                EQU             $D2
FLASH_TMO2                EQU             $D3
FLASH_COPY_SRC_LO         EQU             $D4
FLASH_COPY_SRC_HI         EQU             $D5
FLASH_COPY_DST_LO         EQU             $D6
FLASH_COPY_DST_HI         EQU             $D7
FLASH_COPY_LEN_LO         EQU             $D8
FLASH_COPY_LEN_HI         EQU             $D9

; ----------------------------------------------------------------------------
; ROUTINE: FLASH_ADDR_ALLOWED_XY  [HASH:772EAC50]
; TIER: SYS-L4
; TAGS: FLASH, ADDRESS, GUARD, CARRY-STATUS, NO-RAM, NO-STACK
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Check whether X/Y names a writable flash target in the current bank.
; IN : X/Y = target address low/high
; OUT: C = 1 if target is $8000-$CFFF, C = 0 otherwise
;      A/X/Y preserved
; EXCEPTIONS/NOTES:
; - $D000-$FFFF is protected because Himonia and hardware vectors live there.
; ----------------------------------------------------------------------------
FLASH_ADDR_ALLOWED_XY:
                        CPY             #FLASH_TARGET_MIN_HI
                        BCC             ?NO
                        CPY             #FLASH_PROTECT_HI
                        BCS             ?NO
                        SEC
                        RTS
?NO:                    CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FLASH_SECTOR_ERASE_XY  [HASH:C3099165]
; TIER: SYS-L4
; TAGS: FLASH, SECTOR-ERASE, RAM-STAGED, CARRY-STATUS, USES-ZP, STACK
; MEM : ZP: ZP_EXT16_B0..B6 and copy temporaries B7..BC.
; PURPOSE: Erase the 4K sector containing target X/Y in the current flash bank.
; IN : X/Y = any address in target sector
; OUT: C = 1 if command completed and target reads $FF, C = 0 on guard/timeout
;      A/X/Y clobbered
; EXCEPTIONS/NOTES:
; - Refuses targets outside $8000-$CFFF.
; - Erases exactly one 4K sector per call. Callers own any multi-sector loop.
; - Runs the flash command/poll worker from RAM at $1300.
; - IRQs are masked during the command window; NMI must not be asserted.
; ----------------------------------------------------------------------------
FLASH_SECTOR_ERASE_XY:
                        STX             FLASH_ADDR_LO
                        STY             FLASH_ADDR_HI
                        JSR             FLASH_ADDR_ALLOWED_XY
                        BCC             ?FAIL
                        LDA             #FLASH_OP_ERASE_SECTOR
                        STA             FLASH_OP
                        JMP             FLASH_RUN_RAM_WORKER
?FAIL:                  CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FLASH_SECTOR_ERASE_RAW_XY  [HASH:F23F864E]
; TIER: TEST
; TAGS: FLASH, SECTOR-ERASE, RAW, NO-RANGE-GUARD, RAM-STAGED
; MEM : ZP: ZP_EXT16_B0..B6 and copy temporaries B7..BC.
; PURPOSE: Erase one 4K sector without checking the target address range.
; IN : X/Y = any address in target sector
; OUT: C = 1 if command completed and target reads $FF, C = 0 on timeout
;      A/X/Y clobbered
; EXCEPTIONS/NOTES:
; - Test-only escape hatch: intentionally bypasses FLASH_ADDR_ALLOWED_XY.
; - Caller accepts all consequences of touching the supplied sector.
; ----------------------------------------------------------------------------
FLASH_SECTOR_ERASE_RAW_XY:
                        STX             FLASH_ADDR_LO
                        STY             FLASH_ADDR_HI
                        LDA             #FLASH_OP_ERASE_SECTOR
                        STA             FLASH_OP
                        JMP             FLASH_RUN_RAM_WORKER

; ----------------------------------------------------------------------------
; ROUTINE: FLASH_WRITE_BYTE_AXY  [HASH:103B070B]
; TIER: SYS-L4
; TAGS: FLASH, BYTE-PROGRAM, RAM-STAGED, AXY, CARRY-STATUS, USES-ZP, STACK
; MEM : ZP: ZP_EXT16_B0..B6 and copy temporaries B7..BC.
; PURPOSE: Program one byte in the current flash bank.
; IN : A = byte to program, X/Y = target address low/high
; OUT: C = 1 if target verifies, C = 0 on guard/timeout/illegal 0->1 write
;      A/X/Y clobbered
; EXCEPTIONS/NOTES:
; - Refuses targets outside $8000-$CFFF.
; - Flash must already be erased enough for requested 1->0 bit transitions.
; - Runs the flash command/poll worker from RAM at $1300.
; - IRQs are masked during the command window; NMI must not be asserted.
; ----------------------------------------------------------------------------
FLASH_WRITE_BYTE_AXY:
                        STX             FLASH_ADDR_LO
                        STY             FLASH_ADDR_HI
                        STA             FLASH_DATA
                        JSR             FLASH_ADDR_ALLOWED_XY
                        BCC             ?FAIL
                        LDA             #FLASH_OP_WRITE_BYTE
                        STA             FLASH_OP
                        JMP             FLASH_RUN_RAM_WORKER
?FAIL:                  CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FLASH_WRITE_BYTE_RAW_AXY  [HASH:510FD332]
; TIER: TEST
; TAGS: FLASH, BYTE-PROGRAM, RAW, NO-RANGE-GUARD, RAM-STAGED, AXY
; MEM : ZP: ZP_EXT16_B0..B6 and copy temporaries B7..BC.
; PURPOSE: Program one byte without checking the target address range.
; IN : A = byte to program, X/Y = target address low/high
; OUT: C = 1 if target verifies, C = 0 on timeout/illegal 0->1 write
;      A/X/Y clobbered
; EXCEPTIONS/NOTES:
; - Test-only escape hatch: intentionally bypasses FLASH_ADDR_ALLOWED_XY.
; - Caller accepts all consequences of touching the supplied address.
; ----------------------------------------------------------------------------
FLASH_WRITE_BYTE_RAW_AXY:
                        STX             FLASH_ADDR_LO
                        STY             FLASH_ADDR_HI
                        STA             FLASH_DATA
                        LDA             #FLASH_OP_WRITE_BYTE
                        STA             FLASH_OP
                        JMP             FLASH_RUN_RAM_WORKER

FLASH_RUN_RAM_WORKER:
                        PHP
                        SEI
                        JSR             FLASH_COPY_WORKER
                        JSR             FLASH_RAM_WORKER
                        BCS             ?OK
                        PLP
                        CLC
                        RTS
?OK:                    PLP
                        SEC
                        RTS

FLASH_COPY_WORKER:
                        LDA             #<FLASH_WORKER_BEGIN
                        STA             FLASH_COPY_SRC_LO
                        LDA             #>FLASH_WORKER_BEGIN
                        STA             FLASH_COPY_SRC_HI
                        LDA             #<FLASH_RAM_WORKER
                        STA             FLASH_COPY_DST_LO
                        LDA             #>FLASH_RAM_WORKER
                        STA             FLASH_COPY_DST_HI
                        LDA             #<FLASH_WORKER_SIZE
                        STA             FLASH_COPY_LEN_LO
                        LDA             #>FLASH_WORKER_SIZE
                        STA             FLASH_COPY_LEN_HI
                        LDY             #$00
?LOOP:                  LDA             (FLASH_COPY_SRC_LO),Y
                        STA             (FLASH_COPY_DST_LO),Y
                        INC             FLASH_COPY_SRC_LO
                        BNE             ?SRC_OK
                        INC             FLASH_COPY_SRC_HI
?SRC_OK:                INC             FLASH_COPY_DST_LO
                        BNE             ?DST_OK
                        INC             FLASH_COPY_DST_HI
?DST_OK:                LDA             FLASH_COPY_LEN_LO
                        BNE             ?DEC_LO
                        DEC             FLASH_COPY_LEN_HI
?DEC_LO:                DEC             FLASH_COPY_LEN_LO
                        LDA             FLASH_COPY_LEN_LO
                        ORA             FLASH_COPY_LEN_HI
                        BNE             ?LOOP
                        RTS

; ----------------------------------------------------------------------------
; RAM worker. Keep internal control flow relative; this block is copied verbatim
; to FLASH_RAM_WORKER and executed there.
; ----------------------------------------------------------------------------
FLASH_WORKER_BEGIN:
                        LDA             FLASH_OP
                        CMP             #FLASH_OP_WRITE_BYTE
                        BEQ             ?WRITE
                        CMP             #FLASH_OP_ERASE_SECTOR
                        BEQ             ?ERASE
                        BRA             ?FAIL_RESET

?WRITE:                 LDY             #$00
                        LDA             (FLASH_ADDR_LO),Y
                        CMP             FLASH_DATA
                        BEQ             ?OK
                        AND             FLASH_DATA
                        CMP             FLASH_DATA
                        BNE             ?FAIL_RESET

                        LDA             #$AA
                        STA             FLASH_UNLOCK1
                        LDA             #$55
                        STA             FLASH_UNLOCK2
                        LDA             #$A0
                        STA             FLASH_UNLOCK1
                        LDA             FLASH_DATA
                        STA             (FLASH_ADDR_LO),Y

                        STZ             FLASH_TMO0
                        STZ             FLASH_TMO1
                        LDA             #FLASH_WRITE_TIMEOUT_HI
                        STA             FLASH_TMO2
?WRITE_POLL:            LDY             #$00
                        LDA             (FLASH_ADDR_LO),Y
                        CMP             FLASH_DATA
                        BEQ             ?OK
                        DEC             FLASH_TMO0
                        BNE             ?WRITE_POLL
                        DEC             FLASH_TMO1
                        BNE             ?WRITE_POLL
                        DEC             FLASH_TMO2
                        BNE             ?WRITE_POLL
                        BRA             ?FAIL_RESET

?ERASE:                 LDA             #$AA
                        STA             FLASH_UNLOCK1
                        LDA             #$55
                        STA             FLASH_UNLOCK2
                        LDA             #$80
                        STA             FLASH_UNLOCK1
                        LDA             #$AA
                        STA             FLASH_UNLOCK1
                        LDA             #$55
                        STA             FLASH_UNLOCK2
                        LDA             #$30
                        LDY             #$00
                        STA             (FLASH_ADDR_LO),Y

                        STZ             FLASH_TMO0
                        STZ             FLASH_TMO1
                        LDA             #FLASH_ERASE_TIMEOUT_HI
                        STA             FLASH_TMO2
?ERASE_POLL:            LDY             #$00
                        LDA             (FLASH_ADDR_LO),Y
                        CMP             #$FF
                        BEQ             ?OK
                        DEC             FLASH_TMO0
                        BNE             ?ERASE_POLL
                        DEC             FLASH_TMO1
                        BNE             ?ERASE_POLL
                        DEC             FLASH_TMO2
                        BNE             ?ERASE_POLL

?FAIL_RESET:            LDA             #$F0
                        STA             FLASH_UNLOCK1
                        CLC
                        RTS
?OK:                    SEC
                        RTS
FLASH_WORKER_END:
FLASH_WORKER_SIZE        EQU             FLASH_WORKER_END-FLASH_WORKER_BEGIN

                        ENDMOD

                        END

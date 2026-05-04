; ----------------------------------------------------------------------------
; str8.asm
; STR8 V0 simulation stub, linked at the first protected-window target $F800.
; - No flash writes.
; - B/0/1/2 only print copy plans.
; - Uses BIO byte I/O directly; no SYS layer, no FNV/catalog path.
; ----------------------------------------------------------------------------

                        MODULE          STR8_APP

                        XDEF            START

                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK

STR8_PROT_START_HI      EQU             $F8
STR8_PTR_LO             EQU             $CD
STR8_PTR_HI             EQU             $CE

                        CODE
START:
                        JSR             STR8_INIT
                        JSR             STR8_PRINT_SCREEN
                        JMP             STR8_CMD_LOOP

; ----------------------------------------------------------------------------
; STR8 lifecycle
; ----------------------------------------------------------------------------
STR8_INIT:
                        RTS

STR8_PRINT_SCREEN:
                        LDX             #<MSG_SCREEN
                        LDY             #>MSG_SCREEN
                        JMP             STR8_PRINT_XY

STR8_CMD_LOOP:
                        JSR             STR8_PRINT_PROMPT
                        JSR             STR8_READ_COMMAND
                        JSR             STR8_DISPATCH_A
                        BRA             STR8_CMD_LOOP

STR8_READ_COMMAND:
                        JSR             STR8_READ_BYTE
                        CMP             #$0D
                        BEQ             STR8_READ_COMMAND
                        CMP             #$0A
                        BEQ             STR8_READ_COMMAND
                        RTS

; ----------------------------------------------------------------------------
; Command dispatch
; ----------------------------------------------------------------------------
STR8_DISPATCH_A:
                        CMP             #'0'
                        BEQ             STR8_CMD_RESTORE_0
                        CMP             #'1'
                        BEQ             STR8_CMD_RESTORE_1
                        CMP             #'2'
                        BEQ             STR8_CMD_RESTORE_2
                        CMP             #'?'
                        BEQ             STR8_CMD_ID

                        AND             #$DF
                        CMP             #'B'
                        BEQ             STR8_CMD_BACKUP
                        CMP             #'G'
                        BEQ             STR8_CMD_G_HIMON
                        CMP             #'R'
                        BEQ             STR8_CMD_RESET_STUB
                        CMP             #'V'
                        BEQ             STR8_CMD_VERIFY_STUB
                        JMP             STR8_CMD_UNKNOWN

STR8_CMD_BACKUP:
                        JSR             STR8_PRINT_BACKUP_PLAN
                        RTS

STR8_CMD_RESTORE_0:
                        LDX             #<MSG_RESTORE_0
                        LDY             #>MSG_RESTORE_0
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_RESTORE_1:
                        LDX             #<MSG_RESTORE_1
                        LDY             #>MSG_RESTORE_1
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_RESTORE_2:
                        LDX             #<MSG_RESTORE_2
                        LDY             #>MSG_RESTORE_2
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_RESTORE_COMMON

STR8_CMD_G_HIMON:
                        LDX             #<MSG_G_HIMON
                        LDY             #>MSG_G_HIMON
                        JSR             STR8_PRINT_XY
                        RTS

STR8_CMD_RESET_STUB:
                        LDX             #<MSG_RESET_STUB
                        LDY             #>MSG_RESET_STUB
                        JMP             STR8_PRINT_XY

STR8_CMD_VERIFY_STUB:
                        LDX             #<MSG_VERIFY_STUB
                        LDY             #>MSG_VERIFY_STUB
                        JMP             STR8_PRINT_XY

STR8_CMD_ID:
                        LDX             #<MSG_ID
                        LDY             #>MSG_ID
                        JMP             STR8_PRINT_XY

STR8_CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JMP             STR8_PRINT_XY

; ----------------------------------------------------------------------------
; Simulation plan printers
; ----------------------------------------------------------------------------
STR8_PRINT_BACKUP_PLAN:
                        LDX             #<MSG_BACKUP_0
                        LDY             #>MSG_BACKUP_0
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_COPY_10
                        LDY             #>MSG_COPY_10
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_COPY_21
                        LDY             #>MSG_COPY_21
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_COPY_32
                        LDY             #>MSG_COPY_32
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_VERIFY_PLAN
                        LDY             #>MSG_VERIFY_PLAN
                        JMP             STR8_PRINT_XY

STR8_PRINT_RESTORE_COMMON:
                        LDX             #<MSG_SKIP_STR8
                        LDY             #>MSG_SKIP_STR8
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_VERIFY_PLAN
                        LDY             #>MSG_VERIFY_PLAN
                        JMP             STR8_PRINT_XY

; ----------------------------------------------------------------------------
; Tiny I/O
; ----------------------------------------------------------------------------
STR8_PRINT_PROMPT:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JMP             STR8_PRINT_XY

STR8_PRINT_XY:
                        STX             STR8_PTR_LO
                        STY             STR8_PTR_HI
                        LDY             #$00
?LOOP:                  LDA             (STR8_PTR_LO),Y
                        BMI             ?LAST
                        JSR             STR8_WRITE_BYTE
                        INY
                        BNE             ?LOOP
                        INC             STR8_PTR_HI
                        BRA             ?LOOP
?LAST:                  AND             #$7F
                        JMP             STR8_WRITE_BYTE

STR8_READ_BYTE:
                        JMP             BIO_FTDI_READ_BYTE_BLOCK

STR8_WRITE_BYTE:
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

                        DATA
MSG_SCREEN:             DB              $0D,$0A,"STR8 V0",$0D,$0A
                        DB              "B3 OK  STR8 $F800-$FFFF",$0D,$0A,$0D,$0A
                        DB              "0 PLAT 1 PREV 2 LAST",$0D,$0A
                        DB              "B BACK V VER  G HIMON",$0D,$8A
MSG_PROMPT:             DB              "STR8",('>'+$80)
MSG_BACKUP_0:           DB              $0D,$0A,"B BACK SIM",$0D,$8A
MSG_COPY_10:            DB              "COPY B1 -> B0  PLAN",$0D,$8A
MSG_COPY_21:            DB              "COPY B2 -> B1  PLAN",$0D,$8A
MSG_COPY_32:            DB              "COPY B3 -> B2  PLAN",$0D,$8A
MSG_VERIFY_PLAN:        DB              "VERIFY         PLAN",$0D,$8A
MSG_RESTORE_0:          DB              $0D,$0A,"RESTORE B0 -> B3  PLAN",$0D,$8A
MSG_RESTORE_1:          DB              $0D,$0A,"RESTORE B1 -> B3  PLAN",$0D,$8A
MSG_RESTORE_2:          DB              $0D,$0A,"RESTORE B2 -> B3  PLAN",$0D,$8A
MSG_SKIP_STR8:          DB              "SKIP STR8 $F800-$FFFF",$0D,$8A
MSG_G_HIMON:            DB              $0D,$0A,"G HIMON",$0D,$8A
MSG_RESET_STUB:         DB              $0D,$0A,"RESET STUB",$0D,$8A
MSG_VERIFY_STUB:        DB              $0D,$0A,"VERIFY STUB",$0D,$8A
MSG_ID:                 DB              $0D,$0A,"STR8 V0 SIM $F800",$0D,$8A
MSG_UNKNOWN:            DB              $0D,$0A,"?",$0D,$8A

                        END

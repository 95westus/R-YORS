; ----------------------------------------------------------------------------
; str8.asm
; STR8 V0 small recovery proof.
;
; Command surface:
;   ?  print tiny ID/state
;   B  backup rotation, with read-back verify built in
;   E  enroll bank 0 into backup rotation, one-way in-flash flag
;   M  map bank/sector erased or used status
;   U  update HIMON from S19, fixed gate $C000-$EFFF
;   0  restore bank 0 -> bank 3, preserving selected STR8 window
;   1  restore bank 1 -> bank 3, preserving selected STR8 window
;   2  restore bank 2 -> bank 3, preserving selected STR8 window
;   G  go HIMON
;   R  reset through the live bank 3 reset vector
;
; The RAM proof build performs destructive bank copies directly from RAM. The
; resident ROM build copies a worker from high flash to $0200, then runs
; destructive copy/erase/write/verify and one-way config writes from RAM.
; ----------------------------------------------------------------------------

                        MODULE          STR8_APP

                        XDEF            START
                        XDEF            STR8_IVY_ENTRY_NMI
                        XDEF            STR8_IVY_ENTRY_IRQ_MASTER
                        XDEF            STR8_ID_MARKER_BYTES

                        XREF            UTL_DELAY_AXY_8MHZ
                        IF              STR8_RAM_PROOF
                        XREF            FLSH_BANK_SELECT_A
                        XREF            FLSH_BANK_SELECT_3
                        XREF            FLASH_SECTOR_ERASE_RAW_XY
                        XREF            FLASH_WRITE_BYTE_RAW_AXY
                        ENDIF

; 2026-05-07T22:58-05:00        WLP2        Combined ROM layout moves STR8 to $F000.
; 2026-05-17T21:20-05:00        WLP2        Worker storage formerly moved to $FC00 to make room for U/HIMON update.
; 2026-05-21T23:55-05:00        WLP2        Worker now packs down from $FFEF so the free hole is contiguous.
STR8_PROT_START_HI      EQU             $F0
STR8_PROT_BUF_HI        EQU             $40
STR8_CFG_FLAGS_ADDR     EQU             $FFF0
STR8_CFG_FLAGS_LO       EQU             $F0
STR8_CFG_FLAGS_HI       EQU             $FF
STR8_CFG_B0_ROT_MASK    EQU             $01
; STR8 identity marker. The source phrase is private.
STR8_ID_MARKER0         EQU             $7A
STR8_ID_MARKER1         EQU             $0F
STR8_ID_MARKER2         EQU             $6A
STR8_ID_MARKER3         EQU             $5F
STR8_RESET_VECTOR       EQU             $FFFC
STR8_HIMON_START        EQU             $C000
STR8_HIMON_RESET_SIG0   EQU             $7EE6
STR8_HIMON_RESET_SIG1   EQU             $7EE7
STR8_HIMON_RESET_SIG2   EQU             $7EE8
STR8_HIMON_RESET_SIG3   EQU             $7EE9
STR8_IVY_SIG0           EQU             $7EED
STR8_IVY_SIG1           EQU             $7EEE
STR8_IVY_SIG2           EQU             $7EEF
STR8_IVY_SIG0_VAL       EQU             'I'
STR8_IVY_SIG1_VAL       EQU             'V'
STR8_IVY_SIG2_VAL       EQU             'Y'
STR8_IVY_VEC_RESET_LO   EQU             $7EF8
STR8_IVY_VEC_RESET_HI   EQU             $7EF9
STR8_IVY_VEC_NMI_LO     EQU             $7EFA
STR8_IVY_VEC_NMI_HI     EQU             $7EFB
STR8_IVY_VEC_BRK_LO     EQU             $7EFC
STR8_IVY_VEC_BRK_HI     EQU             $7EFD
STR8_IVY_VEC_IRQ_LO     EQU             $7EFE
STR8_IVY_VEC_IRQ_HI     EQU             $7EFF
STR8_WORKER_RUN         EQU             $0200
STR8_WORKER_RUN_HI      EQU             $02
STR8_WORKER_STORE_LO    EQU             $1E
STR8_WORKER_STORE_HI    EQU             $FD
STR8_WORKER_COPY_LEN_LO EQU             $D2
STR8_WORKER_COPY_LEN_HI EQU             $02
STR8_DELAY_TICKS        EQU             $03
STR8_DELAY_TICK_A       EQU             $26
STR8_DELAY_FIRST_A      EQU             $27
STR8_DELAY_TICK_X       EQU             $B6
STR8_DELAY_TICK_Y       EQU             $F8
STR8_SPLASH_DELAY_A     EQU             $13

STR8_COPY_MODE_FULL     EQU             $00
STR8_COPY_MODE_RESTORE  EQU             $01
STR8_COPY_MODE_ENROLL   EQU             $02
STR8_COPY_MODE_RESTORE_FLASH_HI EQU     $03
STR8_COPY_MODE_MAP      EQU             $04
STR8_COPY_MODE_PROGRAM_STAGED EQU        $05
STR8_RESTORE_PROT_START_HI EQU          $C0

STR8_PTR_LO             EQU             $CD
STR8_PTR_HI             EQU             $CE
STR8_COPY_PTR_LO        EQU             $CF
STR8_COPY_PTR_HI        EQU             $D0
STR8_MARK_SECTOR_HI     EQU             $0A00
STR8_MARK_ADDR_LO       EQU             $0A01
STR8_MARK_ADDR_HI       EQU             $0A02
STR8_COPY_BUF_LO        EQU             $0A03
STR8_COPY_BUF_HI        EQU             $0A04
STR8_COPY_SRC_BANK      EQU             $0A05
STR8_COPY_DST_BANK      EQU             $0A06
STR8_COPY_MODE          EQU             $0A07
STR8_BOOT_KEY_ENABLE    EQU             $0A08
STR8_MAP_B0             EQU             $0A09
STR8_MAP_B1             EQU             $0A0A
STR8_MAP_B2             EQU             $0A0B
STR8_MAP_B3             EQU             $0A0C
STR8_STAGE_BUF_HI       EQU             $0A0D
STR8_UPD_MASK           EQU             $0A0E
STR8_UPD_COUNT          EQU             $0A0F
STR8_UPD_DATA_LEN       EQU             $0A10
STR8_UPD_SUM            EQU             $0A11
STR8_UPD_DST_LO         EQU             $0A12
STR8_UPD_DST_HI         EQU             $0A13
STR8_UPD_TMP            EQU             $0A14
STR8_UPD_TOTAL_LO       EQU             $0A15
STR8_UPD_TOTAL_HI       EQU             $0A16
STR8_SECTOR_BUF_HI      EQU             $40
STR8_SECTOR_BUF_END_HI  EQU             $50

STR8_CON_VIA_CTRL       EQU             $7FE0
STR8_CON_VIA_DATA       EQU             $7FE1
STR8_CON_VIA_DDRB       EQU             $7FE2
STR8_CON_VIA_DDRA       EQU             $7FE3
STR8_CON_PN_TXE         EQU             $01
STR8_CON_PN_RXF         EQU             $02
STR8_CON_PN_WR          EQU             $04
STR8_CON_PN_RD          EQU             $08
STR8_CON_PN_CTRL_INIT   EQU             $0C
STR8_CON_TX_SPIN_LIMIT  EQU             $30
STR8_CON_FLUSH_RX_MAX   EQU             $FF

                        CODE
; 2026-05-07T19:14-05:00        WLP2        Timeout enters HIMON warm; S/s takes STR8.
; 2026-05-14T00:00-05:00        WLP2        Timeout enters HIMON cold after half delay.
START:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        JSR             STR8_IVY_INIT
                        JSR             STR8_INIT
                        IF              STR8_RAM_PROOF
                        ELSE
                        JSR             STR8_SPLASH_DELAY
                        JSR             STR8_PRINT_BANNER
                        JSR             STR8_STARTUP_DELAY
                        BCS             ?STR8_TAKEOVER
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_HIMON_COLD
?STR8_TAKEOVER:
                        ENDIF
                        JSR             STR8_PRINT_SCREEN
                        JMP             STR8_CMD_LOOP

; ----------------------------------------------------------------------------
; STR8 lifecycle
; ----------------------------------------------------------------------------
; 2026-05-07T19:14-05:00        WLP2        Init flushes RX and gates boot-key polling.
STR8_INIT:
                        JSR             STR8_CON_INIT
                        JSR             STR8_CON_FLUSH_RX
                        LDA             #$00
                        BCC             ?KEY_FLAG
                        LDA             #$01
?KEY_FLAG:             STA             STR8_BOOT_KEY_ENABLE
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        RTS

; ----------------------------------------------------------------------------
; IVI vector front door. IVI is pronounced IVY; LEAF is the later product surface.
; ----------------------------------------------------------------------------
; Hardware RESET lands in STR8. Hardware NMI and IRQ/BRK land in these STR8
; top-sector stubs, which dispatch through RAM vector cells once initialized.
STR8_IVY_INIT:
                        PHP
                        SEI
                        STZ             STR8_IVY_SIG0

                        LDA             #<START
                        STA             STR8_IVY_VEC_RESET_LO
                        LDA             #>START
                        STA             STR8_IVY_VEC_RESET_HI

                        LDA             #<STR8_IVY_DEFAULT_RTI
                        STA             STR8_IVY_VEC_NMI_LO
                        STA             STR8_IVY_VEC_BRK_LO
                        STA             STR8_IVY_VEC_IRQ_LO
                        LDA             #>STR8_IVY_DEFAULT_RTI
                        STA             STR8_IVY_VEC_NMI_HI
                        STA             STR8_IVY_VEC_BRK_HI
                        STA             STR8_IVY_VEC_IRQ_HI

                        JSR             STR8_IVY_MARK_VALID
                        PLP
                        RTS

STR8_IVY_MARK_VALID:
                        LDA             #STR8_IVY_SIG1_VAL
                        STA             STR8_IVY_SIG1
                        LDA             #STR8_IVY_SIG2_VAL
                        STA             STR8_IVY_SIG2
                        LDA             #STR8_IVY_SIG0_VAL
                        STA             STR8_IVY_SIG0
                        RTS

STR8_IVY_SIG_OK:
                        LDA             STR8_IVY_SIG0
                        CMP             #STR8_IVY_SIG0_VAL
                        BNE             ?NO
                        LDA             STR8_IVY_SIG1
                        CMP             #STR8_IVY_SIG1_VAL
                        BNE             ?NO
                        LDA             STR8_IVY_SIG2
                        CMP             #STR8_IVY_SIG2_VAL
                        BNE             ?NO
                        SEC
                        RTS
?NO:                   CLC
                        RTS

STR8_IVY_ENTRY_NMI:
                        PHA
                        JSR             STR8_IVY_SIG_OK
                        BCC             ?RTI
                        LDA             STR8_IVY_VEC_NMI_LO
                        ORA             STR8_IVY_VEC_NMI_HI
                        BEQ             ?RTI
                        PLA
                        JMP             (STR8_IVY_VEC_NMI_LO)
?RTI:                  PLA
STR8_IVY_DEFAULT_RTI:   RTI

STR8_IVY_ENTRY_IRQ_MASTER:
                        PHA
                        PHX
                        TSX
                        LDA             $0103,X
                        AND             #$10
                        BEQ             ?IRQ
?BRK:                  JSR             STR8_IVY_SIG_OK
                        BCC             ?BRK_RTI
                        LDA             STR8_IVY_VEC_BRK_LO
                        ORA             STR8_IVY_VEC_BRK_HI
                        BEQ             ?BRK_RTI
                        PLX
                        PLA
                        JMP             (STR8_IVY_VEC_BRK_LO)
?BRK_RTI:              PLX
                        PLA
                        RTI
?IRQ:                  JSR             STR8_IVY_SIG_OK
                        BCC             ?IRQ_RTI
                        LDA             STR8_IVY_VEC_IRQ_LO
                        ORA             STR8_IVY_VEC_IRQ_HI
                        BEQ             ?IRQ_RTI
                        PLX
                        PLA
                        JMP             (STR8_IVY_VEC_IRQ_LO)
?IRQ_RTI:              PLX
                        PLA
                        RTI

STR8_ENTER_HIMON_COLD:
                        STZ             STR8_HIMON_RESET_SIG0
                        STZ             STR8_HIMON_RESET_SIG1
                        STZ             STR8_HIMON_RESET_SIG2
                        STZ             STR8_HIMON_RESET_SIG3
                        JMP             STR8_HIMON_START

STR8_ENTER_HIMON_WARM:
                        LDA             #$A5
                        STA             STR8_HIMON_RESET_SIG0
                        LDA             #$5A
                        STA             STR8_HIMON_RESET_SIG1
                        LDA             #$C3
                        STA             STR8_HIMON_RESET_SIG2
                        LDA             #$3C
                        STA             STR8_HIMON_RESET_SIG3
                        JMP             STR8_HIMON_START

                        IF              STR8_RAM_PROOF
                        ELSE
STR8_SPLASH_DELAY:
                        LDA             #STR8_SPLASH_DELAY_A
                        LDX             #STR8_DELAY_TICK_X
                        LDY             #STR8_DELAY_TICK_Y
                        JMP             UTL_DELAY_AXY_8MHZ

STR8_PRINT_BANNER:
                        LDX             #<MSG_BOOT_BANNER
                        LDY             #>MSG_BOOT_BANNER
                        JMP             STR8_PRINT_XY

; OUT: C=1 if S/s was consumed; C=0 if the timeout elapsed.
; 2026-05-07T19:14-05:00        WLP2        Countdown split into poll, print, and tick helpers.
STR8_STARTUP_DELAY:
                        LDX             #<MSG_BOOT_PROMPT
                        LDY             #>MSG_BOOT_PROMPT
                        JSR             STR8_PRINT_XY
                        LDA             #STR8_DELAY_TICKS
?TICK:
                        PHA
                        JSR             STR8_BOOT_KEY_POLL_IF_ENABLED
                        BCS             ?KEY_PRESSED
                        PLA
                        PHA
                        JSR             STR8_PRINT_COUNTDOWN_A
                        PLA
                        PHA
                        JSR             STR8_DELAY_COUNTDOWN_TICK_A
                        JSR             STR8_BOOT_KEY_POLL_IF_ENABLED
                        BCS             ?KEY_PRESSED
                        PLA
                        DEC             A
                        BNE             ?TICK
                        CLC
                        RTS
?KEY_PRESSED:          PLA
                        SEC
                        RTS

STR8_BOOT_KEY_POLL_IF_ENABLED:
                        LDA             STR8_BOOT_KEY_ENABLE
                        BEQ             ?NO
                        JMP             STR8_BOOT_KEY_POLL
?NO:                   CLC
                        RTS

STR8_PRINT_COUNTDOWN_A:
                        PHA
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        PLA
                        CMP             #$01
                        BEQ             ?DONE
                        LDA             #' '
                        JSR             STR8_WRITE_BYTE
?DONE:                 RTS

; One $27 tick plus five $26 ticks equals the utility's $E5 6.502s profile.
STR8_DELAY_COUNTDOWN_TICK_A:
                        CMP             #STR8_DELAY_TICKS
                        BEQ             ?FIRST
                        LDA             #STR8_DELAY_TICK_A
                        BRA             ?WAIT
?FIRST:                LDA             #STR8_DELAY_FIRST_A
?WAIT:                 LDX             #STR8_DELAY_TICK_X
                        LDY             #STR8_DELAY_TICK_Y
                        JMP             UTL_DELAY_AXY_8MHZ

STR8_BOOT_KEY_POLL:
                        JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCC             ?NO
                        AND             #$DF
                        CMP             #'S'
                        BEQ             ?YES
?NO:                   CLC
                        RTS
?YES:                  SEC
                        RTS
                        ENDIF

STR8_PRINT_SCREEN:
                        LDX             #<MSG_SCREEN
                        LDY             #>MSG_SCREEN
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_B0_STATE

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
; 2026-05-07T20:35-05:00        WLP2        M dispatch reports physical flash map.
STR8_DISPATCH_A:
                        CMP             #'0'
                        BNE             ?NOT_0
                        LDA             #$00
                        JMP             STR8_CMD_RESTORE_A
?NOT_0:
                        CMP             #'1'
                        BNE             ?NOT_1
                        LDA             #$01
                        JMP             STR8_CMD_RESTORE_A
?NOT_1:
                        CMP             #'2'
                        BNE             ?NOT_2
                        LDA             #$02
                        JMP             STR8_CMD_RESTORE_A
?NOT_2:
                        CMP             #'?'
                        BNE             ?NOT_ID
                        JMP             STR8_CMD_ID
?NOT_ID:

                        AND             #$DF
                        CMP             #'B'
                        BEQ             STR8_CMD_BACKUP
                        CMP             #'E'
                        BEQ             STR8_CMD_ENROLL_B0
                        CMP             #'G'
                        BNE             ?NOT_G
                        JMP             STR8_CMD_G_HIMON
?NOT_G:
                        CMP             #'M'
                        BNE             ?NOT_M
                        JMP             STR8_CMD_M
?NOT_M:
                        CMP             #'U'
                        BNE             ?NOT_U
                        JMP             STR8_CMD_UPDATE_HIMON
?NOT_U:
                        CMP             #'R'
                        BNE             ?NOT_R
                        JMP             STR8_CMD_RESET
?NOT_R:
                        JMP             STR8_CMD_UNKNOWN

STR8_CMD_ID:
                        LDX             #<MSG_ID
                        LDY             #>MSG_ID
                        JSR             STR8_PRINT_XY
                        JMP             STR8_PRINT_B0_STATE

STR8_CMD_BACKUP:
                        JSR             STR8_CFG_B0_ENROLLED
                        BCS             ?WITH_B0
                        LDX             #<MSG_BACKUP_WARN
                        LDY             #>MSG_BACKUP_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?DO_21
                        JMP             STR8_CMD_ABORT
?DO_21:
                        JSR             STR8_COPY_FULL_2_TO_1
                        BCS             ?DO_32
                        JMP             STR8_CMD_COPY_FAIL
?DO_32:
                        JSR             STR8_COPY_FULL_3_TO_2
                        BCS             ?BACK_OK
                        JMP             STR8_CMD_COPY_FAIL
?BACK_OK:
                        JMP             STR8_CMD_OK
?WITH_B0:
                        LDX             #<MSG_BACKUP_B0_WARN
                        LDY             #>MSG_BACKUP_B0_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?DO_10
                        JMP             STR8_CMD_ABORT
?DO_10:
                        JSR             STR8_COPY_FULL_1_TO_0
                        BCS             ?DO_B0_21
                        JMP             STR8_CMD_COPY_FAIL
?DO_B0_21:
                        JSR             STR8_COPY_FULL_2_TO_1
                        BCS             ?DO_B0_32
                        JMP             STR8_CMD_COPY_FAIL
?DO_B0_32:
                        JSR             STR8_COPY_FULL_3_TO_2
                        BCS             ?BACK_B0_OK
                        JMP             STR8_CMD_COPY_FAIL
?BACK_B0_OK:
                        JMP             STR8_CMD_OK

STR8_CMD_ENROLL_B0:
                        JSR             STR8_CFG_B0_ENROLLED
                        BCC             ?NEED_ENROLL
                        LDX             #<MSG_ALREADY_ROT
                        LDY             #>MSG_ALREADY_ROT
                        JMP             STR8_PRINT_XY
?NEED_ENROLL:
                        LDX             #<MSG_ENROLL_WARN
                        LDY             #>MSG_ENROLL_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?CONFIRMED
                        JMP             STR8_CMD_ABORT
?CONFIRMED:
                        JSR             STR8_CFG_SET_B0_ENROLLED
                        BCS             ?CFG_OK
                        JMP             STR8_CMD_CFG_FAIL
?CFG_OK:
                        JMP             STR8_CMD_OK

; 2026-05-07T19:14-05:00        WLP2        Restore can optionally include high flash.
; 2026-05-07T22:16-05:00        WLP2        Restore flushes RX between double confirmations.
STR8_CMD_RESTORE_A:
                        STA             STR8_COPY_SRC_BANK
                        LDX             #<MSG_RESTORE_B
                        LDY             #>MSG_RESTORE_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_COPY_SRC_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_RESTORE_WARN
                        LDY             #>MSG_RESTORE_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?CONFIRMED
                        JMP             STR8_CMD_ABORT
?CONFIRMED:
                        JSR             STR8_CON_FLUSH_RX
                        LDX             #<MSG_FLASH_HI_WARN
                        LDY             #>MSG_FLASH_HI_WARN
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?FLASH_HI
                        LDA             #STR8_COPY_MODE_RESTORE
                        BRA             ?SET_MODE
?FLASH_HI:             LDA             #STR8_COPY_MODE_RESTORE_FLASH_HI
?SET_MODE:             STA             STR8_COPY_MODE
                        LDA             #$03
                        STA             STR8_COPY_DST_BANK
                        JSR             STR8_RUN_COPY
                        BCC             STR8_CMD_COPY_FAIL
                        JMP             STR8_CMD_OK

STR8_CMD_M:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SCAN_MAP
                        ELSE
                        LDA             #STR8_COPY_MODE_MAP
                        STA             STR8_COPY_MODE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        ENDIF
                        BCC             STR8_CMD_COPY_FAIL
                        JMP             STR8_PRINT_MAP

; 2026-05-17T21:20-05:00        WLP2        U is the first fixed-gate HIMON S19 update.
STR8_CMD_UPDATE_HIMON:
                        IF              STR8_RAM_PROOF
                        LDX             #<MSG_UPDATE_ROM_ONLY
                        LDY             #>MSG_UPDATE_ROM_ONLY
                        JMP             STR8_PRINT_XY
                        ELSE
                        LDX             #<MSG_UPDATE_HIMON
                        LDY             #>MSG_UPDATE_HIMON
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCC             STR8_CMD_ABORT
                        JSR             STR8_STAGE_HIMON_BLANK
                        JSR             STR8_UPD_INIT
                        LDX             #<MSG_UPDATE_SEND_S19
                        LDY             #>MSG_UPDATE_SEND_S19
                        JSR             STR8_PRINT_XY
                        JSR             STR8_READ_HIMON_S19
                        BCC             STR8_CMD_UPDATE_S19_FAIL
                        LDA             STR8_UPD_MASK
                        BEQ             STR8_CMD_UPDATE_NO_DATA
                        LDX             #<MSG_UPDATE_WRITE
                        LDY             #>MSG_UPDATE_WRITE
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCC             STR8_CMD_ABORT
                        JSR             STR8_PROGRAM_HIMON_UPDATE
                        BCC             STR8_CMD_COPY_FAIL
                        JMP             STR8_CMD_OK
                        ENDIF

STR8_CMD_UPDATE_S19_FAIL:
                        JSR             STR8_CON_FLUSH_RX
                        LDX             #<MSG_S19_FAIL
                        LDY             #>MSG_S19_FAIL
                        JMP             STR8_PRINT_XY

STR8_CMD_UPDATE_NO_DATA:
                        LDX             #<MSG_S19_NO_DATA
                        LDY             #>MSG_S19_NO_DATA
                        JMP             STR8_PRINT_XY

; 2026-05-07T19:14-05:00        WLP2        G uses warm-entry signature before HIMON handoff.
STR8_CMD_G_HIMON:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        LDX             #<MSG_G_HIMON
                        LDY             #>MSG_G_HIMON
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_HIMON_WARM
                        ELSE
                        LDX             #<MSG_G_HIMON
                        LDY             #>MSG_G_HIMON
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_HIMON_WARM
                        ENDIF

STR8_CMD_RESET:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        JMP             (STR8_RESET_VECTOR)

STR8_CMD_OK:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             STR8_PRINT_XY

STR8_CMD_ABORT:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JMP             STR8_PRINT_XY

STR8_CMD_COPY_FAIL:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        JMP             STR8_PRINT_COPY_FAIL

STR8_CMD_CFG_FAIL:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        LDX             #<MSG_CFG_FAIL
                        LDY             #>MSG_CFG_FAIL
                        JMP             STR8_PRINT_XY

STR8_CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JMP             STR8_PRINT_XY

; ----------------------------------------------------------------------------
; Tiny state/config
; ----------------------------------------------------------------------------
STR8_CFG_B0_ENROLLED:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        LDA             STR8_CFG_FLAGS_ADDR
                        AND             #STR8_CFG_B0_ROT_MASK
                        BEQ             ?YES
                        CLC
                        RTS
?YES:                   SEC
                        RTS

STR8_PRINT_B0_STATE:
                        JSR             STR8_CFG_B0_ENROLLED
                        BCS             ?ROT
                        LDX             #<MSG_B0_HOLD
                        LDY             #>MSG_B0_HOLD
                        JMP             STR8_PRINT_XY
?ROT:                   LDX             #<MSG_B0_ROT
                        LDY             #>MSG_B0_ROT
                        JMP             STR8_PRINT_XY

STR8_CFG_SET_B0_ENROLLED:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        LDA             STR8_CFG_FLAGS_ADDR
                        AND             #($FF-STR8_CFG_B0_ROT_MASK)
                        LDX             #STR8_CFG_FLAGS_LO
                        LDY             #STR8_CFG_FLAGS_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCC             ?FAIL
                        JSR             STR8_CFG_B0_ENROLLED
                        BCC             ?FAIL
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS
                        ELSE
                        LDA             #STR8_COPY_MODE_ENROLL
                        STA             STR8_COPY_MODE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        BCC             ?FAIL
                        JSR             STR8_CFG_B0_ENROLLED
                        BCC             ?FAIL
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS
                        ENDIF

; ----------------------------------------------------------------------------
; Bank copy entry points
; ----------------------------------------------------------------------------
STR8_COPY_FULL_1_TO_0:
                        LDA             #$01
                        STA             STR8_COPY_SRC_BANK
                        LDA             #$00
                        STA             STR8_COPY_DST_BANK
                        STZ             STR8_COPY_MODE
                        JMP             STR8_RUN_COPY

STR8_COPY_FULL_2_TO_1:
                        LDA             #$02
                        STA             STR8_COPY_SRC_BANK
                        LDA             #$01
                        STA             STR8_COPY_DST_BANK
                        STZ             STR8_COPY_MODE
                        JMP             STR8_RUN_COPY

STR8_COPY_FULL_3_TO_2:
                        LDA             #$03
                        STA             STR8_COPY_SRC_BANK
                        LDA             #$02
                        STA             STR8_COPY_DST_BANK
                        STZ             STR8_COPY_MODE
                        JMP             STR8_RUN_COPY

STR8_RUN_COPY:
                        JSR             STR8_PRINT_COPY_PAIR
                        IF              STR8_RAM_PROOF
                        JSR             STR8_COPY_BANKS
                        RTS
                        ELSE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        RTS
                        ENDIF

                        IF              STR8_RAM_PROOF
; ----------------------------------------------------------------------------
; Destructive RAM proof copy/verify routines
; ----------------------------------------------------------------------------
STR8_SCAN_MAP:
                        STZ             STR8_COPY_SRC_BANK
?BANK:                 LDA             STR8_COPY_SRC_BANK
                        JSR             FLSH_BANK_SELECT_A
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
                        STZ             STR8_COPY_BUF_LO
?SECTOR:               JSR             STR8_DST_SECTOR_ERASED
                        BCS             ?ERASED
                        SEC
                        BRA             ?SHIFT
?ERASED:               CLC
?SHIFT:                ROL             STR8_COPY_BUF_LO
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        LDX             STR8_COPY_SRC_BANK
                        LDA             STR8_COPY_BUF_LO
                        STA             STR8_MAP_B0,X
                        INC             STR8_COPY_SRC_BANK
                        LDA             STR8_COPY_SRC_BANK
                        CMP             #$04
                        BNE             ?BANK
                        JSR             STR8_SELECT_BANK_3
                        SEC
                        RTS

; 2026-05-07T19:14-05:00        WLP2        Restore skips protected high sectors by mode.
STR8_COPY_BANKS:
                        LDA             #$80
                        STA             STR8_MARK_SECTOR_HI
?SECTOR:                LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE
                        BNE             ?COPY_SECTOR
                        LDA             STR8_MARK_SECTOR_HI
                        CMP             #STR8_RESTORE_PROT_START_HI
                        BCS             ?NEXT_SECTOR
?COPY_SECTOR:           JSR             STR8_STAGE_SRC_SECTOR
                        JSR             STR8_PRESERVE_STR8_IF_RESTORE
                        JSR             STR8_ERASE_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8_PROGRAM_DST_SECTOR
                        BCC             ?FAIL
                        JSR             STR8_VERIFY_DST_SECTOR
                        BCC             ?FAIL
                        LDA             #'.'
                        JSR             STR8_WRITE_BYTE
?NEXT_SECTOR:
                        LDA             STR8_MARK_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_MARK_SECTOR_HI
                        BNE             ?SECTOR
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS

STR8_STAGE_SRC_SECTOR:
                        LDA             STR8_COPY_SRC_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_PTR_HI
?PAGE:                  LDY             #$00
?BYTE:                  LDA             (STR8_PTR_LO),Y
                        STA             (STR8_COPY_PTR_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        LDA             STR8_COPY_PTR_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        RTS

STR8_PRESERVE_STR8_IF_RESTORE:
                        LDA             STR8_COPY_MODE
                        CMP             #STR8_COPY_MODE_RESTORE
                        BNE             ?DONE
                        LDA             STR8_MARK_SECTOR_HI
                        CMP             #$F0
                        BNE             ?DONE
                        JSR             STR8_STAGE_B3_PROTECTED
?DONE:                  RTS

STR8_STAGE_B3_PROTECTED:
                        JSR             STR8_SELECT_BANK_3
                        STZ             STR8_PTR_LO
                        LDA             #STR8_PROT_START_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_PROT_BUF_HI
                        STA             STR8_COPY_PTR_HI
?PAGE:                  LDY             #$00
?BYTE:                  LDA             (STR8_PTR_LO),Y
                        STA             (STR8_COPY_PTR_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        LDA             STR8_COPY_PTR_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        RTS

; 2026-05-07T19:14-05:00        WLP2        Skip erased sectors and verify erase completion.
STR8_ERASE_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        JSR             STR8_DST_SECTOR_ERASED
                        BCS             ?OK
                        LDX             STR8_MARK_ADDR_LO
                        LDY             STR8_MARK_ADDR_HI
                        JSR             FLASH_SECTOR_ERASE_RAW_XY
                        BCC             ?FAIL
                        JSR             STR8_DST_SECTOR_ERASED
                        BCS             ?OK
?FAIL:                 CLC
                        RTS
?OK:                   SEC
                        RTS

; OUT: C=1 if the selected destination sector is all $FF.
;      C=0 and STR8_MARK_ADDR_* names the first non-erased byte otherwise.
STR8_DST_SECTOR_ERASED:
                        STZ             STR8_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_PTR_HI
?PAGE:                  LDY             #$00
?BYTE:                  LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BNE             ?NOT_ERASED
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        LDA             STR8_PTR_HI
                        SEC
                        SBC             STR8_MARK_SECTOR_HI
                        CMP             #$10
                        BNE             ?PAGE
                        SEC
                        RTS
?NOT_ERASED:           TYA
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8_PTR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS

STR8_PROGRAM_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_MARK_ADDR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_MARK_ADDR_HI
                        STZ             STR8_COPY_BUF_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_BUF_HI
?BYTE:                  LDA             STR8_COPY_BUF_LO
                        STA             STR8_PTR_LO
                        LDA             STR8_COPY_BUF_HI
                        STA             STR8_PTR_HI
                        LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BEQ             ?NEXT
                        LDX             STR8_MARK_ADDR_LO
                        LDY             STR8_MARK_ADDR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCC             ?FAIL
?NEXT:                  INC             STR8_MARK_ADDR_LO
                        INC             STR8_COPY_BUF_LO
                        BNE             ?BYTE
                        INC             STR8_MARK_ADDR_HI
                        INC             STR8_COPY_BUF_HI
                        LDA             STR8_COPY_BUF_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?BYTE
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS

STR8_VERIFY_DST_SECTOR:
                        LDA             STR8_COPY_DST_BANK
                        JSR             FLSH_BANK_SELECT_A
                        STZ             STR8_PTR_LO
                        LDA             STR8_MARK_SECTOR_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_SECTOR_BUF_HI
                        STA             STR8_COPY_PTR_HI
?PAGE:                  LDY             #$00
?BYTE:                  LDA             (STR8_PTR_LO),Y
                        CMP             (STR8_COPY_PTR_LO),Y
                        BNE             ?FAIL
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        LDA             STR8_COPY_PTR_HI
                        CMP             #STR8_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        SEC
                        RTS
?FAIL:                  TYA
                        STA             STR8_MARK_ADDR_LO
                        LDA             STR8_PTR_HI
                        STA             STR8_MARK_ADDR_HI
                        CLC
                        RTS

STR8_SELECT_BANK_3:
                        JSR             FLSH_BANK_SELECT_3
                        RTS
                        ENDIF

STR8_CONFIRM_Y:
                        JSR             STR8_READ_COMMAND
                        PHA
                        JSR             STR8_WRITE_BYTE
                        PLA
                        AND             #$DF
                        CMP             #'Y'
                        BEQ             ?YES
                        CLC
                        RTS
?YES:                   SEC
                        RTS

STR8_PRINT_COPY_PAIR:
                        LDX             #<MSG_COPY_B
                        LDY             #>MSG_COPY_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_COPY_SRC_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_TO_B
                        LDY             #>MSG_TO_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_COPY_DST_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JMP             STR8_PRINT_XY

                        IF              STR8_RAM_PROOF
                        ELSE
STR8_COPY_WORKER_TO_RAM:
; 2026-05-21T23:55-05:00        WLP2        Worker source packs against $FFEF and copies exact length.
; 2026-05-17T21:20-05:00        WLP2        Worker source formerly copied from $FC00.
; 2026-05-07T23:19-05:00        WLP2        Worker copy target moves into STR8's $0200 tray.
                        LDA             #STR8_WORKER_STORE_LO
                        STA             STR8_PTR_LO
                        LDA             #STR8_WORKER_STORE_HI
                        STA             STR8_PTR_HI
                        STZ             STR8_COPY_PTR_LO
                        LDA             #STR8_WORKER_RUN_HI
                        STA             STR8_COPY_PTR_HI
                        LDX             #STR8_WORKER_COPY_LEN_HI
                        BEQ             ?TAIL_START
?PAGE:
                        LDY             #$00
?BYTE:
                        LDA             (STR8_PTR_LO),Y
                        STA             (STR8_COPY_PTR_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        INC             STR8_COPY_PTR_HI
                        DEX
                        BNE             ?PAGE
?TAIL_START:
                        LDY             #$00
?TAIL:
                        CPY             #STR8_WORKER_COPY_LEN_LO
                        BEQ             ?DONE
                        LDA             (STR8_PTR_LO),Y
                        STA             (STR8_COPY_PTR_LO),Y
                        INY
                        BRA             ?TAIL
?DONE:
                        RTS
                        ENDIF

                        IF              STR8_RAM_PROOF
                        ELSE
; ----------------------------------------------------------------------------
; Fixed-gate HIMON update: receive S1/S9, stage blank C/D/E, then program C/D/E.
; ----------------------------------------------------------------------------
STR8_UPD_INIT:
                        STZ             STR8_UPD_MASK
                        STZ             STR8_UPD_TOTAL_LO
                        STZ             STR8_UPD_TOTAL_HI
                        RTS

STR8_STAGE_HIMON_BLANK:
                        STZ             STR8_PTR_LO
                        LDA             #$40
                        STA             STR8_PTR_HI
?PAGE:
                        LDY             #$00
                        LDA             #$FF
?BYTE:
                        STA             (STR8_PTR_LO),Y
                        INY
                        BNE             ?BYTE
                        INC             STR8_PTR_HI
                        LDA             STR8_PTR_HI
                        CMP             #$70
                        BNE             ?PAGE
                        RTS

STR8_READ_HIMON_S19:
?RECORD:
                        JSR             STR8_S19_READ_START
                        BCC             ?FAIL
                        CMP             #'0'
                        BEQ             ?SKIP
                        CMP             #'1'
                        BEQ             ?DATA
                        CMP             #'9'
                        BEQ             ?TERM
                        BRA             ?FAIL
?SKIP:
                        JSR             STR8_S19_PARSE_SKIP
                        BCC             ?FAIL
                        BRA             ?RECORD
?DATA:
                        JSR             STR8_S19_PARSE_S1
                        BCC             ?FAIL
                        LDA             #'.'
                        JSR             STR8_WRITE_BYTE
                        BRA             ?RECORD
?TERM:
                        JSR             STR8_S19_PARSE_SKIP
                        BCC             ?FAIL
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_S19_READ_START:
?READ:
                        JSR             STR8_READ_BYTE
                        CMP             #$0D
                        BEQ             ?READ
                        CMP             #$0A
                        BEQ             ?READ
                        AND             #$DF
                        CMP             #'S'
                        BNE             ?FAIL
                        JSR             STR8_READ_BYTE
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_S19_PARSE_SKIP:
                        JSR             STR8_S19_BEGIN_COUNT
                        BCC             ?FAIL
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        LDA             STR8_UPD_COUNT
                        SEC
                        SBC             #$03
                        BCC             ?FAIL
                        STA             STR8_UPD_DATA_LEN
?DATA:
                        LDA             STR8_UPD_DATA_LEN
                        BNE             ?MORE_DATA
                        JMP             STR8_S19_VERIFY_CHECKSUM
?MORE_DATA:
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        DEC             STR8_UPD_DATA_LEN
                        BRA             ?DATA
?FAIL:
                        CLC
                        RTS

STR8_S19_PARSE_S1:
                        JSR             STR8_S19_BEGIN_COUNT
                        BCC             ?FAIL
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        STA             STR8_UPD_DST_HI
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        STA             STR8_UPD_DST_LO
                        LDA             STR8_UPD_COUNT
                        SEC
                        SBC             #$03
                        BCC             ?FAIL
                        STA             STR8_UPD_DATA_LEN
?DATA:
                        LDA             STR8_UPD_DATA_LEN
                        BNE             ?MORE_DATA
                        JMP             STR8_S19_VERIFY_CHECKSUM
?MORE_DATA:
                        JSR             STR8_READ_HEX_BYTE
                        BCC             ?FAIL
                        STA             STR8_UPD_TMP
                        JSR             STR8_S19_SUM_ADD_A
                        LDA             STR8_UPD_TMP
                        JSR             STR8_STAGE_HIMON_BYTE
                        BCC             ?FAIL
                        INC             STR8_UPD_DST_LO
                        BNE             ?COUNT
                        INC             STR8_UPD_DST_HI
?COUNT:
                        INC             STR8_UPD_TOTAL_LO
                        BNE             ?NEXT
                        INC             STR8_UPD_TOTAL_HI
?NEXT:
                        DEC             STR8_UPD_DATA_LEN
                        BRA             ?DATA
?FAIL:
                        CLC
                        RTS

STR8_STAGE_HIMON_BYTE:
                        STA             STR8_UPD_TMP
                        LDA             STR8_UPD_DST_HI
                        CMP             #$C0
                        BCC             ?FAIL
                        CMP             #$F0
                        BCS             ?FAIL
                        SEC
                        SBC             #$80
                        STA             STR8_PTR_HI
                        LDA             STR8_UPD_DST_LO
                        STA             STR8_PTR_LO
                        LDY             #$00
                        LDA             STR8_UPD_TMP
                        STA             (STR8_PTR_LO),Y
                        JSR             STR8_MARK_HIMON_SECTOR
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_MARK_HIMON_SECTOR:
                        LDA             STR8_UPD_DST_HI
                        CMP             #$D0
                        BCC             ?C
                        CMP             #$E0
                        BCC             ?D
                        LDA             #$04
                        BRA             ?SET
?D:
                        LDA             #$02
                        BRA             ?SET
?C:
                        LDA             #$01
?SET:
                        TSB             STR8_UPD_MASK
                        RTS

STR8_S19_BEGIN_COUNT:
                        STZ             STR8_UPD_SUM
                        JSR             STR8_S19_READ_SUM_BYTE
                        BCC             ?FAIL
                        STA             STR8_UPD_COUNT
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_S19_READ_SUM_BYTE:
                        JSR             STR8_READ_HEX_BYTE
                        BCC             ?FAIL
                        PHA
                        JSR             STR8_S19_SUM_ADD_A
                        PLA
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_S19_SUM_ADD_A:
                        CLC
                        ADC             STR8_UPD_SUM
                        STA             STR8_UPD_SUM
                        RTS

STR8_S19_VERIFY_CHECKSUM:
                        JSR             STR8_READ_HEX_BYTE
                        BCC             ?FAIL
                        JSR             STR8_S19_SUM_ADD_A
                        LDA             STR8_UPD_SUM
                        CMP             #$FF
                        BNE             ?FAIL
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_READ_HEX_BYTE:
                        JSR             STR8_READ_BYTE
                        JSR             STR8_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             STR8_UPD_TMP
                        JSR             STR8_READ_BYTE
                        JSR             STR8_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ORA             STR8_UPD_TMP
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_HEX_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             ?FAIL
                        CMP             #'9'+1
                        BCC             ?DIGIT
                        AND             #$DF
                        CMP             #'A'
                        BCC             ?FAIL
                        CMP             #'F'+1
                        BCS             ?FAIL
                        SEC
                        SBC             #('A'-10)
                        SEC
                        RTS
?DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_PROGRAM_HIMON_UPDATE:
                        LDA             #$C0
                        LDX             #$40
                        JSR             STR8_PROGRAM_HIMON_SECTOR_AX
                        BCC             ?FAIL
                        LDA             #$D0
                        LDX             #$50
                        JSR             STR8_PROGRAM_HIMON_SECTOR_AX
                        BCC             ?FAIL
                        LDA             #$E0
                        LDX             #$60
                        JSR             STR8_PROGRAM_HIMON_SECTOR_AX
                        BCC             ?FAIL
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_PROGRAM_HIMON_SECTOR_AX:
                        STA             STR8_MARK_SECTOR_HI
                        STX             STR8_STAGE_BUF_HI
                        LDA             #$03
                        STA             STR8_COPY_DST_BANK
                        LDA             #STR8_COPY_MODE_PROGRAM_STAGED
                        STA             STR8_COPY_MODE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        BCC             ?FAIL
                        LDA             #'.'
                        JSR             STR8_WRITE_BYTE
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS
                        ENDIF

STR8_PRINT_COPY_FAIL:
                        IF              STR8_RAM_PROOF
                        LDX             #<MSG_COPY_FAIL_AT
                        LDY             #>MSG_COPY_FAIL_AT
                        JSR             STR8_PRINT_XY
                        LDA             STR8_MARK_ADDR_HI
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDA             STR8_MARK_ADDR_LO
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JMP             STR8_PRINT_XY
                        ELSE
                        LDX             #<MSG_COPY_FAIL
                        LDY             #>MSG_COPY_FAIL
                        JMP             STR8_PRINT_XY
                        ENDIF

STR8_WRITE_DEC_DIGIT_A:
                        AND             #$0F
                        CLC
                        ADC             #'0'
                        JMP             STR8_WRITE_BYTE

STR8_PRINT_MAP:
                        LDX             #<MSG_MAP_HEADER
                        LDY             #>MSG_MAP_HEADER
                        JSR             STR8_PRINT_XY
                        STZ             STR8_COPY_SRC_BANK
?BANK:                 LDX             STR8_COPY_SRC_BANK
                        LDA             STR8_MAP_B0,X
                        JSR             STR8_PRINT_MAP_MASK_A
                        INC             STR8_COPY_SRC_BANK
                        LDA             STR8_COPY_SRC_BANK
                        CMP             #$04
                        BEQ             ?DONE
                        JSR             STR8_PRINT_TWO_SPACES
                        BRA             ?BANK
?DONE:                 LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_MAP_GRID_HEADER
                        LDY             #>MSG_MAP_GRID_HEADER
                        JSR             STR8_PRINT_XY
                        STZ             STR8_COPY_SRC_BANK
?GRID_BANK:            JSR             STR8_PRINT_MAP_ROW
                        INC             STR8_COPY_SRC_BANK
                        LDA             STR8_COPY_SRC_BANK
                        CMP             #$04
                        BNE             ?GRID_BANK
                        LDX             #<MSG_MAP_GRID_FOOTER
                        LDY             #>MSG_MAP_GRID_FOOTER
                        JMP             STR8_PRINT_XY

STR8_PRINT_MAP_MASK_A:
                        STA             STR8_COPY_BUF_LO
                        LDA             #$08
                        STA             STR8_COPY_BUF_HI
?BIT:                  ASL             STR8_COPY_BUF_LO
                        LDA             #'-'
                        BCC             ?PRINT
                        LDA             #'+'
?PRINT:                JSR             STR8_WRITE_BYTE
                        DEC             STR8_COPY_BUF_HI
                        BNE             ?BIT
                        RTS

STR8_PRINT_MAP_ROW:
                        LDA             #'B'
                        JSR             STR8_WRITE_BYTE
                        LDA             STR8_COPY_SRC_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_MAP_ROW_MID
                        LDY             #>MSG_MAP_ROW_MID
                        JSR             STR8_PRINT_XY
                        LDX             STR8_COPY_SRC_BANK
                        LDA             STR8_MAP_B0,X
                        JSR             STR8_PRINT_MAP_STARS_A
                        LDX             #<MSG_MAP_ROW_END
                        LDY             #>MSG_MAP_ROW_END
                        JMP             STR8_PRINT_XY

STR8_PRINT_MAP_STARS_A:
                        STA             STR8_COPY_BUF_LO
                        LDA             #$08
                        STA             STR8_COPY_BUF_HI
?BIT:                  ASL             STR8_COPY_BUF_LO
                        LDA             #'.'
                        BCC             ?PRINT
                        LDA             #'*'
?PRINT:                JSR             STR8_WRITE_BYTE
                        DEC             STR8_COPY_BUF_HI
                        BEQ             ?DONE
                        LDA             #' '
                        JSR             STR8_WRITE_BYTE
                        BRA             ?BIT
?DONE:                 RTS

STR8_PRINT_TWO_SPACES:
                        LDA             #' '
                        JSR             STR8_WRITE_BYTE
                        LDA             #' '
                        JMP             STR8_WRITE_BYTE

                        IF              STR8_RAM_PROOF
STR8_WRITE_HEX_BYTE_A:
                        PHA
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        JSR             STR8_WRITE_HEX_NIBBLE_A
                        PLA
                        AND             #$0F
STR8_WRITE_HEX_NIBBLE_A:
                        CMP             #$0A
                        BCC             ?DIGIT
                        CLC
                        ADC             #$37
                        JMP             STR8_WRITE_BYTE
?DIGIT:                 CLC
                        ADC             #'0'
                        JMP             STR8_WRITE_BYTE
                        ENDIF

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
                        JMP             STR8_CON_READ_BYTE_BLOCK

STR8_WRITE_BYTE:
                        JMP             STR8_CON_WRITE_BYTE_BLOCK

STR8_CON_INIT:
                        PHA
                        LDA             #STR8_CON_PN_CTRL_INIT
                        STA             STR8_CON_VIA_CTRL
                        STA             STR8_CON_VIA_DDRB
                        STZ             STR8_CON_VIA_DDRA
                        PLA
                        RTS

STR8_CON_FLUSH_RX:
                        PHA
                        PHX
                        LDX             #STR8_CON_FLUSH_RX_MAX
?LOOP:                  JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCC             ?EMPTY
                        DEX
                        BNE             ?LOOP
                        PLX
                        PLA
                        CLC
                        RTS
?EMPTY:                 PLX
                        PLA
                        SEC
                        RTS

STR8_CON_READ_BYTE_BLOCK:
                        JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCC             STR8_CON_READ_BYTE_BLOCK
                        RTS

STR8_CON_READ_BYTE_NONBLOCK:
                        STZ             STR8_CON_VIA_DDRA
                        LDA             #STR8_CON_PN_RXF
                        BIT             STR8_CON_VIA_CTRL
                        BNE             ?NO_BYTE_READY
?BYTE_READY:            LDA             #STR8_CON_PN_RD
                        TRB             STR8_CON_VIA_CTRL
                        NOP
                        NOP
                        LDA             STR8_CON_VIA_DATA
                        PHA
                        LDA             #STR8_CON_PN_RD
                        TSB             STR8_CON_VIA_CTRL
                        PLA
                        SEC
                        RTS
?NO_BYTE_READY:         LDA             #$00
                        CLC
                        RTS

STR8_CON_WRITE_BYTE_BLOCK:
                        PHX
?LOOP:                  JSR             STR8_CON_WRITE_BYTE_NONBLOCK
                        BCC             ?LOOP
                        PLX
                        RTS

STR8_CON_POLL_TX_READY:
                        PHA
                        ; TXE# is bit 0; invert it into carry without a branch.
                        LDA             STR8_CON_VIA_CTRL
                        AND             #STR8_CON_PN_TXE
                        EOR             #STR8_CON_PN_TXE
                        LSR             A
                        PLA
                        RTS

STR8_CON_WRITE_BYTE_NONBLOCK:
                        PHA
                        SEC
                        STZ             STR8_CON_VIA_DDRA
                        STA             STR8_CON_VIA_DATA
                        NOP
                        NOP
                        LDX             #$00
                        LDA             #STR8_CON_PN_TXE
?TX_SPIN:               BIT             STR8_CON_VIA_CTRL
                        BEQ             ?WR_STROBE
                        INX
                        CPX             #STR8_CON_TX_SPIN_LIMIT
                        BNE             ?TX_SPIN
                        CLC
                        BRA             ?WR_DEASSERT
?WR_STROBE:             LDA             #STR8_CON_PN_WR
                        TSB             STR8_CON_VIA_CTRL
                        LDA             #$FF
                        STA             STR8_CON_VIA_DDRA
                        NOP
                        NOP
                        SEC
?WR_DEASSERT:           LDA             #STR8_CON_PN_WR
                        TRB             STR8_CON_VIA_CTRL
                        STZ             STR8_CON_VIA_DDRA
                        PLA
                        RTS

                        DATA
STR8_ID_MARKER_BYTES:   DB              STR8_ID_MARKER0,STR8_ID_MARKER1
                        DB              STR8_ID_MARKER2,STR8_ID_MARKER3

MSG_SCREEN:             DB              $0D,$0A,"STR8 V0 #5F6A0F7A",$0D,$0A
                        IF              STR8_RAM_PROOF
                        DB              "RAM $0200 BUF $4000-$4FFF",$0D,$0A
                        ELSE
                        DB              "ROM $F000",$0D,$0A
                        ENDIF
                        DB              "? B E M U 0 1 2 G R",$0D,$8A
MSG_PROMPT:             DB              "STR8",('>'+$80)
                        IF              STR8_RAM_PROOF
                        ELSE
MSG_BOOT_BANNER:       DB              $0D,$0A
                        DB              "____      ____    ____   ____      ____",$0D,$0A
                        DB              "|   \    /   |   /    \  |   \    /",$0D,$0A
                        DB              "|___/    |___|  |      | |___/    \___",$0D,$0A
                        DB              "|   \    /   |  |      | |   \        \",$0D,$0A
                        DB              "|    \  /    |   \____/  |    \   ____/",$0D,$8A
MSG_BOOT_PROMPT:        DB              $0D,$0A,"HIMON IN 3S. S=STR8 ",$A0
                        ENDIF

MSG_ID:                 DB              $0D,$0A,"STR8 V0 #5F6A0F7A",$0D,$8A
MSG_B0_HOLD:            DB              "B0 HOLD",$0D,$8A
MSG_B0_ROT:             DB              "B0 ROT",$0D,$8A
MSG_UNKNOWN:            DB              $0D,$0A,"?",$0D,$8A
MSG_OK:                 DB              $0D,$0A,"OK",$0D,$8A
MSG_ABORT:              DB              $0D,$0A,"ABORT",$0D,$8A
MSG_CFG_FAIL:           DB              $0D,$0A,"CFG FAIL",$0D,$8A
MSG_COPY_FAIL:          DB              $0D,$0A,"COPY FAIL",$0D,$8A
MSG_UPDATE_ROM_ONLY:    DB              $0D,$0A,"U ROM ONLY",$0D,$8A
MSG_UPDATE_HIMON:       DB              $0D,$0A,"UPDATE HIMON C000-EFFF? Y:",$A0
MSG_UPDATE_SEND_S19:    DB              $0D,$0A,"SEND S19 C000-EFFF",$0D,$8A
MSG_UPDATE_WRITE:       DB              $0D,$0A,"PROGRAM C000-EFFF? Y:",$A0
MSG_S19_FAIL:           DB              $0D,$0A,"S19 FAIL",$0D,$8A
MSG_S19_NO_DATA:        DB              $0D,$0A,"NO S19 DATA",$0D,$8A
MSG_G_HIMON:            DB              $0D,$0A,"G HIMON",$0D,$8A
MSG_MAP_HEADER:         DB              $0D,$0A,"BANK0     BANK1     BANK2     BOOT",$0D,$8A
MSG_MAP_GRID_HEADER:    DB              "     8 9 A B C D E F",$0D,$0A,"   +---------------+",$0D,$8A
MSG_MAP_ROW_MID:        DB              " |",$A0
MSG_MAP_ROW_END:        DB              " |",$0D,$8A
MSG_MAP_GRID_FOOTER:    DB              "   +---------------+",$0D,$8A

MSG_RESTORE_B:          DB              $0D,$0A,"RESTORE ",('B'+$80)
MSG_ALREADY_ROT:        DB              $0D,$0A,"B0 ALREADY ROT",$0D,$8A

MSG_BACKUP_WARN:        DB              $0D,$0A,"BACKUP ERASE B1/B2. Y:",$A0
MSG_BACKUP_B0_WARN:     DB              $0D,$0A,"BACKUP ERASE B0/B1/B2. Y:",$A0
MSG_ENROLL_WARN:        DB              $0D,$0A,"B0 ROT ON. NEXT B ERASES B0. Y:",$A0
MSG_RESTORE_WARN:       DB              "->B3? Y:",$A0
MSG_FLASH_HI_WARN:      DB              $0D,$0A,"WARN: MAY NOT BOOT",$0D,$0A,"FLASH C000-FFFF? Y:",$A0
MSG_COPY_B:             DB              $0D,$0A,"COPY ",('B'+$80)
MSG_TO_B:               DB              "->",('B'+$80)
                        IF              STR8_RAM_PROOF
MSG_COPY_FAIL_AT:       DB              $0D,$0A,"COPY FAIL @ ",('$'+$80)
                        ENDIF
MSG_CRLF:               DB              $0D,$8A

                        END

; ----------------------------------------------------------------------------
; str8.asm
; STR8 V0 small recovery proof.
;
; Command surface:
;   U  update HIMON from S19, fixed gate $C000-$EFFF
;   J0/J1/J2/J3  non-destructive reset-vector handoff to bank 0/1/2/3
;   G  go HIMON
;   R  reset through the live bank reset vector
;   invalid input prints the current command help
;
; Reset shows the attach progress, flushes RX, then opens a 6-second selector.
; Timeout cold-starts the local $C000 target; 3 warm-starts it to preserve RAM.
; An erased $C000 entry face falls into the STR8 menu. S enters STR8; 0-2
; announce the selected bank, wait about 3 more seconds, then reuse the
; non-destructive J handoff.
;
; The RAM proof build performs destructive bank copies directly from RAM. The
; resident ROM build copies a worker from high flash to $0200, then runs
; destructive stage/erase/write/verify and one-way config writes from RAM.
; ----------------------------------------------------------------------------

                        MODULE          STR8_APP

                        XDEF            START
                        XDEF            STR8_RUN_WORKER_SERVICE
                        XDEF            STR8_AP_IMPORT_LINK_SERVICE
                        XDEF            STR8_RECORD_SERVICE_ENTRY
                        XDEF            STR8_RECORD_SERVICE_SIGNATURE
                        XDEF            STR8_BANK_SELECT_SERVICE_ENTRY
                        XDEF            STR8_BANK_SELECT_SERVICE_BODY
                        XDEF            STR8_DIR_VALIDATE_BANK_A
                        XDEF            STR8_DIR_SCAN_JOURNAL
                        IF              STR8_V1_LAYOUT
                        XDEF            STR8_DIR_WRITE_BYTES
                        XDEF            STR8_READ_LINE
                        XDEF            STR8_CMD_INSTALL_PREVIEW
                        IF              STR8_V1_INSTALLER_DRY
                        XDEF            STR8_I_RECEIVE_DENSE
                        XDEF            STR8_I_STAGE_SECTOR_READY
                        ENDIF
                        ENDIF
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

                        INCLUDE         "STR8/str8-record-eq.inc"
                        INCLUDE         "STR8/str8-jump-eq.inc"
                        INCLUDE         "STR8/str8-directory-eq.inc"

; 2026-05-07T22:58-05:00        WLP2        Combined ROM layout moves STR8 to $F000.
; 2026-05-17T21:20-05:00        WLP2        Worker storage formerly moved to $FC00 to make room for U/HIMON update.
; 2026-05-21T23:55-05:00        WLP2        Worker now packs down from $FFEF so the free hole is contiguous.
; 2026-07-23T13:07-05:00        Codex       Size pass shares resident paths and repacks the smaller worker.
; 2026-07-23T17:27-05:00        Codex       B selects one destination; E/enrollment is removed.
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
STR8_WORKER_TRAY_SIZE   EQU             $0800
STR8_WORKER_TRAY_END    EQU             $09FF
                        IF              STR8_V1_LAYOUT
STR8_WORKER_STORE_LO    EQU             $1F
STR8_WORKER_STORE_HI    EQU             $FD
                        ELSE
STR8_WORKER_STORE_LO    EQU             $5F
STR8_WORKER_STORE_HI    EQU             $FD
                        ENDIF
STR8_WORKER_COPY_LEN_LO EQU             $91
STR8_WORKER_COPY_LEN_HI EQU             $02
STR8_DELAY_TICKS        EQU             $06
STR8_DELAY_TICK_A       EQU             $23    ; 0.994s at 8 MHz
STR8_DELAY_FIRST_A      EQU             $24    ; 1.022s at 8 MHz
STR8_DELAY_TICK_X       EQU             $B6
STR8_DELAY_TICK_Y       EQU             $F8
STR8_ATTACH_DELAY_TICKS EQU             $10
STR8_ATTACH_TICK_A      EQU             $0D    ; 0.369s at 8 MHz
STR8_ATTACH_LONG_MIN    EQU             $0E    ; first three ticks are long
STR8_ATTACH_LONG_A      EQU             $0E    ; 0.398s at 8 MHz
STR8_BANK_BOOT_DELAY_A  EQU             $6A    ; 3.010s at 8 MHz

STR8_COPY_MODE_PROGRAM_STAGED EQU        $05
STR8_COPY_MODE_STAGE_BANK_SECTOR EQU    $06

HIM_SVC_AP_LO           EQU             $7E2D
HIM_AP_OP               EQU             $7E2F
HIM_AP_OP_LINK          EQU             $03

STR8_PTR_LO             EQU             $CD
STR8_PTR_HI             EQU             $CE
STR8_COPY_PTR_LO        EQU             $CF
STR8_COPY_PTR_HI        EQU             $D0
STR8_REC_WORK_REMAIN    EQU             $D1
STR8_REC_WORK_SUM       EQU             $D2
STR8_REC_WORK_COUNT     EQU             $D3
STR8_REC_WORK_TMP       EQU             $D4
STR8_REC_WORK_TYPE      EQU             $D5
STR8_LINE_LIMIT         EQU             $D1
STR8_INSTALL_BANK       EQU             $1A00
STR8_INSTALL_TYPE       EQU             $1A01
STR8_INSTALL_DESC       EQU             $1A02
STR8_INSTALL_STATE      EQU             $1A07
STR8_INSTALL_PAIR       EQU             $1A08
STR8_INSTALL_ENTRY_LO   EQU             $1A09
STR8_INSTALL_ENTRY_HI   EQU             $1A0A
STR8_INSTALL_EXPECT_LO  EQU             $1A0B
STR8_INSTALL_EXPECT_HI  EQU             $1A0C
STR8_INSTALL_LIMIT_HI   EQU             $1A0D
STR8_INSTALL_PHASE      EQU             $1A0E
STR8_INSTALL_SECTOR_HI  EQU             $1A0F
STR8_INSTALL_STATUS     EQU             $1A10
STR8_INSTALL_DENSE      EQU             $10
STR8_INSTALL_ENTRY      EQU             $11
STR8_INSTALL_TRAILING   EQU             $13
; The resident directory validator and S19 record parser run serially and
; intentionally share this small zero-page work set.
STR8_DIR_BANK_WORK      EQU             $D1
STR8_DIR_OPEN_WORK      EQU             $D2
STR8_DIR_PACKED_WORK    EQU             $D3
STR8_DIR_LEFT_WORK      EQU             $D4
STR8_DIR_RESULT_PAIR    EQU             $D5
STR8_DIR_PAIR_WORK      EQU             $D6
STR8_STATE_BASE         EQU             $1FE9
STR8_STATE_END          EQU             $1FFF
STR8_MARK_SECTOR_HI     EQU             $1FE9
STR8_MARK_ADDR_LO       EQU             $1FEA
STR8_MARK_ADDR_HI       EQU             $1FEB
STR8_COPY_SRC_BANK      EQU             $1FEE
STR8_COPY_DST_BANK      EQU             $1FEF
STR8_COPY_MODE          EQU             $1FF0
STR8_BOOT_KEY_ENABLE    EQU             $1FF1
STR8_INPUT_SKIP_LF      EQU             $1FF1
STR8_STAGE_BUF_HI       EQU             $1FF6
STR8_UPD_MASK           EQU             $1FF7
STR8_UPD_DATA_LEN       EQU             $1FF9
STR8_UPD_DST_LO         EQU             $1FFB
STR8_UPD_DST_HI         EQU             $1FFC
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
; 2026-08-02T00:00-05:00        Codex       Missing local C000 target falls into STR8.
START:
                        JMP             STR8_BOOT_START

; Stable resident entry for HIMON/RAM tools. Caller sets the $1FE9-$1FFF
; worker state board, then this copies the flash worker to $0200 and runs it.
STR8_RUN_WORKER_SERVICE:
                        JMP             STR8_RUN_WORKER_SERVICE_BODY

STR8_AP_IMPORT_LINK_SERVICE:
                        JMP             STR8_AP_IMPORT_LINK_SERVICE_BODY

STR8_RECORD_SERVICE_ENTRY:
                        JMP             STR8_RECORD_SERVICE_BODY
STR8_RECORD_SERVICE_SIGNATURE:
                        DB              STR8_REC_SIG0_VALUE,STR8_REC_SIG1_VALUE
                        DB              STR8_REC_VERSION_VALUE
                        IF              STR8_RAM_PROOF
                        DB              (STR8_REC_CAP_BUFFER+STR8_REC_CAP_CONSOLE)
                        ELSE
                        DB              STR8_REC_CAPS_V1
                        ENDIF

; Stable bank-selector front door. A RAM caller passes A=bank 0-3. The body
; copies the bank-safe trampoline to $0200 and tail-calls its fixed $0203
; entry, which returns directly to the original RAM caller in the new bank.
STR8_BANK_SELECT_SERVICE_ENTRY:
                        JMP             STR8_BANK_SELECT_SERVICE_BODY

STR8_BOOT_START:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        JSR             STR8_IVY_INIT
                        JSR             STR8_INIT
                        IF              STR8_RAM_PROOF
                        ELSE
                        JSR             STR8_ATTACH_DELAY
                        JSR             STR8_BOOT_INPUT_ARM
                        JSR             STR8_PRINT_BANNER
                        JSR             STR8_STARTUP_DELAY
                        BCC             ?HIMON
                        CMP             #'S'
                        BEQ             ?STR8_KEY
                        CMP             #'3'
                        BEQ             ?HIMON_KEY
                        AND             #$03
                        JSR             STR8_BOOT_JUMP_BANK_A
                        BRA             ?STR8_TAKEOVER
?HIMON_KEY:            JSR             STR8_CON_FLUSH_RX
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_HIMON_WARM
?HIMON:
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_HIMON_COLD
?STR8_KEY:             JSR             STR8_CON_FLUSH_RX
?STR8_TAKEOVER:
                        ENDIF
STR8_ENTER_MENU:
                        STZ             STR8_INPUT_SKIP_LF
                        JSR             STR8_PRINT_SCREEN
                        JMP             STR8_CMD_LOOP

; ----------------------------------------------------------------------------
; STR8 lifecycle
; ----------------------------------------------------------------------------
; 2026-05-07T19:14-05:00        WLP2        Init flushes RX and gates boot-key polling.
; 2026-07-30T00:00-05:00        Codex       Boot arms input after the attach delay.
; 2026-08-01T00:00-05:00        Codex       Preserve a J-selected bank through startup.
STR8_INIT:
                        JMP             STR8_CON_INIT

STR8_BOOT_INPUT_ARM:
                        JSR             STR8_CON_FLUSH_RX
                        LDA             #$00
                        ROL
                        STA             STR8_BOOT_KEY_ENABLE
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
                        JSR             STR8_BOOT_TARGET_AVAILABLE
                        BCC             STR8_ENTER_MENU_NO_BOOT
                        STZ             STR8_HIMON_RESET_SIG0
                        STZ             STR8_HIMON_RESET_SIG1
                        STZ             STR8_HIMON_RESET_SIG2
                        STZ             STR8_HIMON_RESET_SIG3
                        JMP             STR8_HIMON_START

STR8_ENTER_HIMON_WARM:
                        JSR             STR8_BOOT_TARGET_AVAILABLE
                        BCC             STR8_ENTER_MENU_NO_BOOT
                        LDA             #$A5
                        STA             STR8_HIMON_RESET_SIG0
                        LDA             #$5A
                        STA             STR8_HIMON_RESET_SIG1
                        LDA             #$C3
                        STA             STR8_HIMON_RESET_SIG2
                        LDA             #$3C
                        STA             STR8_HIMON_RESET_SIG3
                        JMP             STR8_HIMON_START

; Minimal generic HIMON/user-app availability gate. A richer directory/CRC
; policy can replace this later; V0 only refuses an erased $C000 entry face.
STR8_BOOT_TARGET_AVAILABLE:
                        LDY             #$00
?BYTE:                 LDA             STR8_HIMON_START,Y
                        CMP             #$FF
                        BNE             ?YES
                        INY
                        CPY             #$10
                        BNE             ?BYTE
                        CLC
                        RTS
?YES:                  SEC
                        RTS

STR8_ENTER_MENU_NO_BOOT:
                        JSR             STR8_CON_FLUSH_RX
                        LDX             #<MSG_NO_BOOT
                        LDY             #>MSG_NO_BOOT
                        JSR             STR8_PRINT_XY
                        JMP             STR8_ENTER_MENU

                        IF              STR8_RAM_PROOF
                        ELSE
; 2026-08-02T00:00-05:00        Codex       Show 16 dots over six-second attach.
STR8_ATTACH_DELAY:
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        LDA             #STR8_ATTACH_DELAY_TICKS
?TICK:                 PHA
                        CMP             #STR8_ATTACH_LONG_MIN
                        BCC             ?SHORT
                        LDA             #STR8_ATTACH_LONG_A
                        BRA             ?WAIT
?SHORT:
                        LDA             #STR8_ATTACH_TICK_A
?WAIT:
                        JSR             STR8_DELAY_FIXED_A
                        LDA             #'.'
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        PLA
                        DEC             A
                        BNE             ?TICK
                        RTS
STR8_DELAY_FIXED_A:
                        LDX             #STR8_DELAY_TICK_X
                        LDY             #STR8_DELAY_TICK_Y
                        JMP             UTL_DELAY_AXY_8MHZ

STR8_PRINT_BANNER:
                        LDX             #<MSG_ID
                        LDY             #>MSG_ID
                        JMP             STR8_PRINT_XY

; OUT: C=1 and A='0'/'1'/'2'/'3'/'S' when a boot choice was consumed.
;      C=0 if the timeout elapsed.
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
?KEY_PRESSED:          TAX
                        PLA
                        TXA
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
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
?DONE:                 RTS

; One $24 tick plus five $23 ticks form the six-second prompt countdown.
STR8_DELAY_COUNTDOWN_TICK_A:
                        CMP             #STR8_DELAY_TICKS
                        BEQ             ?FIRST
                        LDA             #STR8_DELAY_TICK_A
                        BRA             ?WAIT
?FIRST:                LDA             #STR8_DELAY_FIRST_A
?WAIT:                 BRA             STR8_DELAY_FIXED_A

; 2026-07-31T14:32-05:00        Codex       Echo selector letters uppercase.
STR8_BOOT_KEY_POLL:
                        JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCC             ?NO
                        JSR             STR8_TO_UPPER_A
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        CMP             #'0'
                        BCC             ?NOT_DIGIT
                        CMP             #'4'
                        BCC             ?YES
?NOT_DIGIT:
                        AND             #$DF
                        CMP             #'S'
                        BEQ             ?YES
?NO:                   CLC
                        RTS
?YES:                  SEC
                        RTS
                        ENDIF

STR8_PRINT_SCREEN:
                        LDX             #<MSG_ID
                        LDY             #>MSG_ID
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_SCREEN
                        LDY             #>MSG_SCREEN
                        JMP             STR8_PRINT_XY

STR8_CMD_LOOP:
                        JSR             STR8_PRINT_PROMPT
                        IF              STR8_V1_LAYOUT
                        LDX             #$02
                        JSR             STR8_READ_LINE
                        BEQ             ?ABORT
                        LDA             STR8_REC_DATA_BUF
                        BRA             ?DISPATCH
?ABORT:                JSR             STR8_CMD_ABORT
                        BRA             STR8_CMD_LOOP
                        ELSE
                        JSR             STR8_READ_COMMAND
                        CMP             #$00
                        BNE             ?DISPATCH
                        JSR             STR8_CMD_ABORT
                        BRA             STR8_CMD_LOOP
                        ENDIF
?DISPATCH:
                        JSR             STR8_DISPATCH_A
                        BRA             STR8_CMD_LOOP

                        IF              STR8_V1_LAYOUT
; Shared V1 line editor.
;   IN:  X = maximum accepted printable bytes (1-252)
;   OUT: A = line length; STR8_REC_DATA_BUF is uppercase and zero-terminated
; Backspace/Delete edit the buffer and terminal. CR, LF, and CR/LF terminate;
; the deferred LF after CR is consumed by the next text read, including S19.
STR8_READ_LINE:
                        STX             STR8_LINE_LIMIT
                        LDY             #$00
?READ:                 JSR             STR8_READ_TEXT_BYTE_BLOCK
                        CMP             #$0D
                        BEQ             ?CR
                        CMP             #$0A
                        BEQ             ?DONE
                        CMP             #$08
                        BEQ             ?BACKSPACE
                        CMP             #$7F
                        BEQ             ?BACKSPACE
                        CMP             #' '
                        BCC             ?READ
                        CMP             #$7F
                        BCS             ?READ
                        JSR             STR8_TO_UPPER_A
                        CPY             STR8_LINE_LIMIT
                        BCS             ?READ
                        STA             STR8_REC_DATA_BUF,Y
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        INY
                        BRA             ?READ
?BACKSPACE:            CPY             #$00
                        BEQ             ?READ
                        DEY
                        LDA             #$08
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        LDA             #$08
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        BRA             ?READ
?CR:                   INC             STR8_INPUT_SKIP_LF
?DONE:                 LDA             #$00
                        STA             STR8_REC_DATA_BUF,Y
                        TYA
                        RTS

STR8_READ_TEXT_BYTE_BLOCK:
?READ:                 JSR             STR8_CON_READ_BYTE_BLOCK
                        PHA
                        LDA             STR8_INPUT_SKIP_LF
                        BEQ             ?KEEP
                        STZ             STR8_INPUT_SKIP_LF
                        PLA
                        CMP             #$0A
                        BEQ             ?READ
                        RTS
?KEEP:                 PLA
                        RTS
                        ELSE
; 2026-07-31T14:32-05:00        Codex       Uppercase echo; controls cancel.
; OUT: A=uppercase printable byte, or zero for Backspace/Delete/CR/LF.
;      A CRLF pair produces one zero result; the paired LF is consumed later.
STR8_READ_COMMAND:
?READ:
                        JSR             STR8_CON_READ_BYTE_BLOCK
                        LDX             STR8_INPUT_SKIP_LF
                        BEQ             ?CONTROL
                        STZ             STR8_INPUT_SKIP_LF
                        CMP             #$0A
                        BEQ             ?READ
?CONTROL:
                        CMP             #$0D
                        BEQ             ?CR
                        CMP             #$0A
                        BEQ             ?CANCEL
                        CMP             #$08
                        BEQ             ?CANCEL
                        CMP             #$7F
                        BEQ             ?CANCEL
                        JSR             STR8_TO_UPPER_A
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        RTS
?CR:                   INC             STR8_INPUT_SKIP_LF
?CANCEL:               LDA             #$00
                        RTS
                        ENDIF

; IN/OUT: A=ASCII byte; lowercase a-z becomes uppercase.
STR8_TO_UPPER_A:
                        CMP             #'a'
                        BCC             ?DONE
                        CMP             #$7B
                        BCS             ?DONE
                        AND             #$DF
?DONE:                 RTS

; ----------------------------------------------------------------------------
; Command dispatch
; ----------------------------------------------------------------------------
STR8_DISPATCH_A:
                        IF              STR8_V1_LAYOUT
                        CMP             #'I'
                        BNE             ?NOT_I
                        JMP             STR8_CMD_INSTALL_PREVIEW
?NOT_I:
                        ENDIF
                        CMP             #'J'
                        BNE             ?NOT_J
                        JMP             STR8_CMD_JUMP_BANK
?NOT_J:
                        IF              STR8_V1_LAYOUT
                        ELSE
                        CMP             #'G'
                        BNE             ?NOT_G
                        JMP             STR8_CMD_G_HIMON
?NOT_G:
                        CMP             #'U'
                        BNE             ?NOT_U
                        JMP             STR8_CMD_UPDATE_HIMON
?NOT_U:
                        ENDIF
                        CMP             #'R'
                        BNE             ?NOT_R
                        JMP             STR8_CMD_RESET
?NOT_R:
                        JMP             STR8_CMD_UNKNOWN

                        IF              STR8_V1_LAYOUT
; Non-mutating I preflight for Banks 0-3. The separate installer-dry host build
; continues through dense S19 staging. Neither form can mutate flash.
STR8_CMD_INSTALL_PREVIEW:
                        LDA             STR8_REC_DATA_BUF+1
                        BEQ             ?PROMPT
                        JMP             STR8_CMD_UNKNOWN
?PROMPT:
                        LDX             #<MSG_I_BANK
                        LDY             #>MSG_I_BANK
                        JSR             STR8_PRINT_XY
                        LDX             #$01
                        JSR             STR8_READ_LINE
                        CMP             #$01
                        BEQ             ?BANK
                        JMP             STR8_CMD_ABORT
?BANK:
                        LDA             STR8_REC_DATA_BUF
                        CMP             #'0'
                        BCC             ?BAD
                        CMP             #'4'
                        BCS             ?BAD
                        AND             #$03
                        STA             STR8_INSTALL_BANK
                        JSR             STR8_DIR_VALIDATE_BANK_A
                        STX             STR8_INSTALL_PAIR
                        STA             STR8_INSTALL_STATE
                        BCC             ?INVALID
                        CMP             #STR8_DIR_RECORD_EMPTY
                        BNE             ?EXISTING
                        LDA             #$FF
                        STA             STR8_INSTALL_ENTRY_LO
                        STA             STR8_INSTALL_ENTRY_HI
                        JSR             STR8_I_READ_TYPE
                        BCC             ?BAD
                        JSR             STR8_I_READ_DESCRIPTION
                        BCC             ?BAD
                        JMP             STR8_I_PRINT_SUMMARY
?EXISTING:             JSR             STR8_I_COPY_RECORD_METADATA
                        JMP             STR8_I_PRINT_SUMMARY
?INVALID:              LDX             #<MSG_I_INVALID
                        LDY             #>MSG_I_INVALID
                        JMP             STR8_PRINT_XY
?BAD:                  JMP             STR8_CMD_UNKNOWN

STR8_I_READ_TYPE:
                        LDX             #<MSG_I_TYPE_PROMPT
                        LDY             #>MSG_I_TYPE_PROMPT
                        JSR             STR8_PRINT_XY
                        LDX             #$02
                        JSR             STR8_READ_LINE
                        CMP             #$02
                        BNE             ?FAIL
                        LDA             STR8_REC_DATA_BUF
                        JSR             STR8_REC_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             STR8_REC_WORK_TMP
                        LDA             STR8_REC_DATA_BUF+1
                        JSR             STR8_REC_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ORA             STR8_REC_WORK_TMP
                        STA             STR8_INSTALL_TYPE
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_I_READ_DESCRIPTION:
                        LDX             #<MSG_I_DESC_PROMPT
                        LDY             #>MSG_I_DESC_PROMPT
                        JSR             STR8_PRINT_XY
                        LDX             #STR8_DIR_DESCRIPTION_LEN
                        JSR             STR8_READ_LINE
                        CMP             #STR8_DIR_DESCRIPTION_LEN
                        BNE             ?FAIL
                        LDX             #(STR8_DIR_DESCRIPTION_LEN-1)
?BYTE:                 LDA             STR8_REC_DATA_BUF,X
                        JSR             STR8_DIR_DESCRIPTION_BYTE_A
                        BCC             ?FAIL
                        STA             STR8_INSTALL_DESC,X
                        DEX
                        BPL             ?BYTE
                        SEC
                        RTS
?FAIL:                 CLC
                        RTS

STR8_I_COPY_RECORD_METADATA:
                        LDY             #STR8_DIR_TYPE
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_INSTALL_TYPE
                        LDX             #$00
                        LDY             #STR8_DIR_DESCRIPTION
?DESC:                 LDA             (STR8_PTR_LO),Y
                        STA             STR8_INSTALL_DESC,X
                        INY
                        INX
                        CPX             #STR8_DIR_DESCRIPTION_LEN
                        BNE             ?DESC
                        LDY             #STR8_DIR_ENTRY_LO
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_INSTALL_ENTRY_LO
                        INY
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_INSTALL_ENTRY_HI
                        RTS

STR8_I_PRINT_SUMMARY:
                        LDX             #<MSG_I_SUMMARY
                        LDY             #>MSG_I_SUMMARY
                        JSR             STR8_PRINT_XY
                        LDA             STR8_INSTALL_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDA             STR8_INSTALL_BANK
                        CMP             #STR8_DIR_BANK3
                        BEQ             ?RANGE3
                        LDX             #<MSG_I_RANGE_32K
                        LDY             #>MSG_I_RANGE_32K
                        BRA             ?RANGE
?RANGE3:               LDX             #<MSG_I_RANGE_28K
                        LDY             #>MSG_I_RANGE_28K
?RANGE:                JSR             STR8_PRINT_XY
                        LDX             #<MSG_I_TYPE
                        LDY             #>MSG_I_TYPE
                        JSR             STR8_PRINT_XY
                        LDA             STR8_INSTALL_TYPE
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDX             #<MSG_I_DESC
                        LDY             #>MSG_I_DESC
                        JSR             STR8_PRINT_XY
                        LDX             #$00
?PRINT_DESC:           LDA             STR8_INSTALL_DESC,X
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        INX
                        CPX             #STR8_DIR_DESCRIPTION_LEN
                        BNE             ?PRINT_DESC
                        LDA             STR8_INSTALL_BANK
                        CMP             #STR8_DIR_BANK3
                        BNE             ?STATE
                        LDA             STR8_INSTALL_STATE
                        CMP             #STR8_DIR_RECORD_EMPTY
                        BEQ             ?STATE
                        LDX             #<MSG_I_ENTRY
                        LDY             #>MSG_I_ENTRY
                        JSR             STR8_PRINT_XY
                        LDA             STR8_INSTALL_ENTRY_HI
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDA             STR8_INSTALL_ENTRY_LO
                        JSR             STR8_WRITE_HEX_BYTE_A
?STATE:                LDA             STR8_INSTALL_STATE
                        CMP             #STR8_DIR_RECORD_EMPTY
                        BEQ             ?EMPTY
                        CMP             #STR8_DIR_RECORD_INCOMPLETE
                        BEQ             ?INCOMPLETE
                        LDA             STR8_INSTALL_PAIR
                        CMP             #STR8_DIR_PAIR_NONE
                        BEQ             ?FULL
                        LDX             #<MSG_I_COMPLETE
                        LDY             #>MSG_I_COMPLETE
                        BRA             ?PRINT_STATE
?EMPTY:                LDX             #<MSG_I_EMPTY
                        LDY             #>MSG_I_EMPTY
                        BRA             ?PRINT_STATE
?INCOMPLETE:           LDX             #<MSG_I_INCOMPLETE
                        LDY             #>MSG_I_INCOMPLETE
                        BRA             ?PRINT_STATE
?FULL:                 LDX             #<MSG_I_FULL
                        LDY             #>MSG_I_FULL
?PRINT_STATE:          JSR             STR8_PRINT_XY
                        LDX             #<MSG_I_PAIR
                        LDY             #>MSG_I_PAIR
                        JSR             STR8_PRINT_XY
                        LDA             STR8_INSTALL_PAIR
                        JSR             STR8_WRITE_HEX_BYTE_A
                        IF              STR8_V1_INSTALLER_DRY
                        LDA             STR8_INSTALL_PAIR
                        CMP             #STR8_DIR_PAIR_NONE
                        BEQ             STR8_I_NO_WRITE
                        LDX             #<MSG_I_STAGE_CONFIRM
                        LDY             #>MSG_I_STAGE_CONFIRM
                        JSR             STR8_PRINT_XY
                        JSR             STR8_CONFIRM_Y
                        BCS             ?CONFIRMED
                        JMP             STR8_CMD_ABORT
?CONFIRMED:
                        LDX             #<MSG_I_SEND_S19
                        LDY             #>MSG_I_SEND_S19
                        JSR             STR8_PRINT_XY
                        JSR             STR8_I_RECEIVE_DENSE
                        BCC             ?STAGE_FAIL
                        LDX             #<MSG_I_STAGE_OK
                        LDY             #>MSG_I_STAGE_OK
                        JSR             STR8_PRINT_XY
                        BRA             STR8_I_NO_WRITE
?STAGE_FAIL:           LDX             #<MSG_I_S19_FAIL
                        LDY             #>MSG_I_S19_FAIL
                        JSR             STR8_PRINT_XY
STR8_I_NO_WRITE:       LDX             #<MSG_I_NO_WRITE
                        LDY             #>MSG_I_NO_WRITE
                        JMP             STR8_PRINT_XY

; Receive exactly $8000-$FFFF for Banks 0-2 or $8000-$EFFF for Bank 3.
; The single $0A00-$19FF sector tray is reused only after the dry sector-ready
; hook returns. The final sector stays in the tray until S9 is validated.
STR8_I_RECEIVE_DENSE:
                        STZ             STR8_INSTALL_EXPECT_LO
                        STZ             STR8_INSTALL_PHASE
                        STZ             STR8_INSTALL_STATUS
                        LDA             #$80
                        STA             STR8_INSTALL_EXPECT_HI
                        STA             STR8_INSTALL_SECTOR_HI
                        LDA             STR8_INSTALL_BANK
                        CMP             #STR8_DIR_BANK3
                        BEQ             ?LIMIT3
                        LDA             #$00
                        BRA             ?LIMIT
?LIMIT3:                LDA             #$F0
?LIMIT:                STA             STR8_INSTALL_LIMIT_HI
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_SOURCE_CONSOLE
                        STA             STR8_REC_SOURCE
?RECORD:               JSR             STR8_RECORD_SERVICE_BODY
                        BCS             ?PARSED
                        LDA             STR8_REC_STATUS
                        JMP             STR8_I_RECEIVE_FAIL_A
?PARSED:
                        LDA             STR8_REC_KIND
                        CMP             #STR8_REC_KIND_METADATA
                        BEQ             ?METADATA
                        CMP             #STR8_REC_KIND_DATA
                        BEQ             ?DATA
                        CMP             #STR8_REC_KIND_END
                        BNE             ?BAD_KIND
                        JMP             ?END
?BAD_KIND:
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?METADATA:             LDA             STR8_INSTALL_PHASE
                        BEQ             ?FIRST_METADATA
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?FIRST_METADATA:
                        INC             STR8_INSTALL_PHASE
                        BRA             ?RECORD
?DATA:                 LDA             STR8_INSTALL_PHASE
                        CMP             #$03
                        BCC             ?NOT_FINAL
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?NOT_FINAL:
                        LDA             STR8_REC_ADDR_LO
                        CMP             STR8_INSTALL_EXPECT_LO
                        BEQ             ?ADDRESS_LO
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?ADDRESS_LO:
                        LDA             STR8_REC_ADDR_HI
                        CMP             STR8_INSTALL_EXPECT_HI
                        BEQ             ?ADDRESS_HI
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?ADDRESS_HI:
                        LDA             STR8_REC_DATA_LEN
                        BNE             ?HAVE_DATA
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?HAVE_DATA:
                        LDA             #$02
                        STA             STR8_INSTALL_PHASE
                        LDA             STR8_INSTALL_EXPECT_LO
                        STA             STR8_PTR_LO
                        LDA             STR8_INSTALL_EXPECT_HI
                        AND             #$0F
                        CLC
                        ADC             #$0A
                        STA             STR8_PTR_HI
                        LDX             #$00
?COPY:                 LDY             #$00
                        LDA             STR8_REC_DATA_BUF,X
                        STA             (STR8_PTR_LO),Y
                        INX
                        INC             STR8_PTR_LO
                        BNE             ?EXPECTED
                        INC             STR8_PTR_HI
?EXPECTED:             INC             STR8_INSTALL_EXPECT_LO
                        BNE             ?COUNT
                        INC             STR8_INSTALL_EXPECT_HI
?COUNT:                DEC             STR8_REC_DATA_LEN
                        LDA             STR8_INSTALL_EXPECT_LO
                        BNE             ?MORE
                        LDA             STR8_INSTALL_EXPECT_HI
                        AND             #$0F
                        BNE             ?MORE
                        LDA             STR8_INSTALL_EXPECT_HI
                        CMP             STR8_INSTALL_LIMIT_HI
                        BEQ             ?FINAL
                        JSR             STR8_I_STAGE_SECTOR_READY
                        LDA             STR8_INSTALL_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             STR8_INSTALL_SECTOR_HI
                        STZ             STR8_PTR_LO
                        LDA             #$0A
                        STA             STR8_PTR_HI
?MORE:                 LDA             STR8_REC_DATA_LEN
                        BNE             ?COPY
                        JMP             ?RECORD
?FINAL:                LDA             STR8_REC_DATA_LEN
                        BEQ             ?FINAL_EXACT
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?FINAL_EXACT:
                        LDA             #$03
                        STA             STR8_INSTALL_PHASE
                        JMP             ?RECORD

?END:                  LDA             STR8_INSTALL_PHASE
                        CMP             #$03
                        BEQ             ?COVERAGE_OK
                        JMP             STR8_I_RECEIVE_DENSE_FAIL
?COVERAGE_OK:
                        LDA             STR8_REC_ENTRY_LO
                        AND             STR8_REC_ENTRY_HI
                        CMP             #$FF
                        BEQ             ?ENTRY_RANGE_OK
                        LDA             STR8_REC_ENTRY_HI
                        CMP             #$80
                        BCC             STR8_I_RECEIVE_ENTRY_FAIL
                        LDX             STR8_INSTALL_BANK
                        CPX             #STR8_DIR_BANK3
                        BNE             ?ENTRY_RANGE_OK
                        CMP             #$F0
                        BCS             STR8_I_RECEIVE_ENTRY_FAIL
?ENTRY_RANGE_OK:       LDA             STR8_INSTALL_BANK
                        CMP             #STR8_DIR_BANK3
                        BEQ             ?ENTRY3
                        LDA             STR8_REC_ENTRY_LO
                        CMP             $19FC
                        BNE             STR8_I_RECEIVE_ENTRY_FAIL
                        LDA             STR8_REC_ENTRY_HI
                        CMP             $19FD
                        BNE             STR8_I_RECEIVE_ENTRY_FAIL
                        BRA             ?TRAILING
?ENTRY3:               LDA             STR8_INSTALL_STATE
                        CMP             #STR8_DIR_RECORD_EMPTY
                        BNE             ?ENTRY3_EXISTING
                        LDA             STR8_REC_ENTRY_LO
                        STA             STR8_INSTALL_ENTRY_LO
                        LDA             STR8_REC_ENTRY_HI
                        STA             STR8_INSTALL_ENTRY_HI
                        BRA             ?TRAILING
?ENTRY3_EXISTING:      LDA             STR8_REC_ENTRY_LO
                        CMP             STR8_INSTALL_ENTRY_LO
                        BNE             STR8_I_RECEIVE_ENTRY_FAIL
                        LDA             STR8_REC_ENTRY_HI
                        CMP             STR8_INSTALL_ENTRY_HI
                        BNE             STR8_I_RECEIVE_ENTRY_FAIL
?TRAILING:             JSR             STR8_I_END_STREAM
                        BCC             STR8_I_RECEIVE_TRAIL_FAIL
                        JSR             STR8_I_STAGE_SECTOR_READY
                        SEC
                        RTS

STR8_I_RECEIVE_DENSE_FAIL:
                        LDA             #STR8_INSTALL_DENSE
                        BRA             STR8_I_RECEIVE_FAIL_A
STR8_I_RECEIVE_ENTRY_FAIL:
                        LDA             #STR8_INSTALL_ENTRY
                        BRA             STR8_I_RECEIVE_FAIL_A
STR8_I_RECEIVE_TRAIL_FAIL:
                        LDA             #STR8_INSTALL_TRAILING
STR8_I_RECEIVE_FAIL_A: STA             STR8_INSTALL_STATUS
                        JSR             STR8_I_DRAIN_QUEUED
                        CLC
                        RTS

; This dry slice is intentionally non-mutating. The next manual-commit slice
; replaces this hook with the journaled sector transaction.
STR8_I_STAGE_SECTOR_READY:
                        SEC
                        RTS

STR8_I_END_STREAM:
                        LDA             STR8_INPUT_SKIP_LF
                        BEQ             ?CHECK
                        JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCC             ?DONE
                        CMP             #$0A
                        BNE             ?FAIL
                        STZ             STR8_INPUT_SKIP_LF
?CHECK:                JSR             STR8_CON_READ_BYTE_NONBLOCK
                        BCS             ?FAIL
?DONE:                 SEC
                        RTS
?FAIL:                 JSR             STR8_I_DRAIN_QUEUED
                        CLC
                        RTS

STR8_I_DRAIN_QUEUED:
                        JSR             STR8_CON_FLUSH_RX
                        BCC             STR8_I_DRAIN_QUEUED
                        RTS
                        ELSE
                        LDX             #<MSG_I_NO_WRITE
                        LDY             #>MSG_I_NO_WRITE
                        JMP             STR8_PRINT_XY
                        ENDIF
                        ENDIF

; 2026-07-28T21:19-05:00        Codex       J0-J2 hand off opaque banks from RAM.
; 2026-07-28T22:48-05:00        Codex       Echo the two-byte J command at the prompt.
; 2026-08-02T00:00-05:00        Codex       J3 returns a running STR8 copy to Bank 3.
STR8_CMD_JUMP_BANK:
                        IF              STR8_V1_LAYOUT
                        LDA             STR8_REC_DATA_BUF+1
                        BEQ             ?BAD
                        ELSE
?OPERAND:
                        JSR             STR8_READ_COMMAND
                        CMP             #$00
                        BNE             ?HAVE_OPERAND
                        JMP             STR8_CMD_ABORT
?HAVE_OPERAND:
                        CMP             #' '
                        BEQ             ?OPERAND
                        ENDIF
                        CMP             #'0'
                        BCC             ?BAD
                        CMP             #'4'
                        BCS             ?BAD
                        AND             #$03
                        JSR             STR8_JUMP_BANK_PREP_A
                        JMP             STR8_JUMP_BANK_LAUNCH
?BAD:
                        JMP             STR8_CMD_UNKNOWN

                        IF              STR8_V1_LAYOUT
                        ELSE
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

                        IF              STR8_V1_LAYOUT
                        ELSE
STR8_CMD_COPY_FAIL:
                        IF              STR8_RAM_PROOF
                        JSR             STR8_SELECT_BANK_3
                        ENDIF
                        JMP             STR8_PRINT_COPY_FAIL
                        ENDIF

STR8_CMD_UNKNOWN:
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        LDX             #<MSG_HELP
                        LDY             #>MSG_HELP
                        JMP             STR8_PRINT_XY

                        IF              STR8_RAM_PROOF
                        ELSE
STR8_BOOT_JUMP_BANK_A:
                        JSR             STR8_JUMP_BANK_PREP_A
                        JSR             STR8_CON_FLUSH_RX
                        LDX             #<MSG_BOOT_BANK_WAIT
                        LDY             #>MSG_BOOT_BANK_WAIT
                        JSR             STR8_PRINT_XY
                        LDA             #STR8_BANK_BOOT_DELAY_A
                        JSR             STR8_DELAY_FIXED_A
                        JMP             STR8_JUMP_BANK_LAUNCH
                        ENDIF

STR8_JUMP_BANK_PREP_A:
                        STA             STR8_JUMP_BANK
                        STZ             STR8_JUMP_VEC_LO
                        STZ             STR8_JUMP_VEC_HI
                        STZ             STR8_JUMP_STATUS
                        LDX             #<MSG_JUMP_B
                        LDY             #>MSG_JUMP_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_JUMP_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JSR             STR8_PRINT_XY
                        RTS

STR8_JUMP_BANK_LAUNCH:
                        JSR             STR8_CON_FLUSH_RX
                        LDA             #STR8_COPY_MODE_JUMP_BANK
                        STA             STR8_COPY_MODE
                        IF              STR8_RAM_PROOF
                        JSR             STR8_JUMP_BANK_RAM
                        ELSE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        ENDIF
                        JMP             STR8_PRINT_JUMP_FAIL

STR8_RUN_WORKER_SERVICE_BODY:
                        IF              STR8_RAM_PROOF
                        CLC
                        RTS
                        ELSE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        RTS
                        ENDIF

; Published $F010 bank selector.
; IN:  A=bank 0-3; caller and JSR return address must be RAM below $8000.
; OUT: C=1 and selected bank remains visible; C=0 leaves the bank unchanged.
;      A/X/Y are clobbered. The copied RAM trampoline remains at $0203.
STR8_BANK_SELECT_SERVICE_BODY:
                        CMP             #STR8_BANK_COUNT
                        IF              STR8_RAM_PROOF
                        BCS             ?BAD_BANK_RAM
                        JSR             FLSH_BANK_SELECT_A
                        SEC
                        RTS
?BAD_BANK_RAM:         CLC
                        RTS
                        ELSE
                        BCS             ?BAD_BANK
                        PHA
                        TSX
                        LDA             $0103,X
                        BMI             ?BAD_RETURN
                        JSR             STR8_COPY_WORKER_TO_RAM
                        PLA
                        JMP             STR8_BANK_SELECT_RAM
?BAD_RETURN:           PLA
?BAD_BANK:             CLC
                        RTS
                        ENDIF

STR8_AP_IMPORT_LINK_SERVICE_BODY:
                        LDA             #HIM_AP_OP_LINK
                        STA             HIM_AP_OP
                        JMP             (HIM_SVC_AP_LO)

; ----------------------------------------------------------------------------
; V1 Bank Directory read-only foundation for I and directory-gated J.
;
; STR8_DIR_VALIDATE_BANK_A
;   IN:  A=bank 0-3, Bank 3 visible
;   OUT: A=STR8_DIR_RECORD_*; X=next/retry pair or $FF; C=1 unless INVALID
;
; STR8_DIR_SCAN_JOURNAL
;   IN:  STR8_PTR_LO/HI points at a 16-byte record
;   OUT: A=STR8_DIR_JOURNAL_*; X=next/retry pair or $FF; C=1 unless INVALID
;
; These routines never select a bank and never mutate flash. The installer
; must reject INVALID, retry INCOMPLETE at the returned pair, and begin EMPTY
; at pair zero. Launch code may accept only COMPLETE.
; ----------------------------------------------------------------------------
STR8_DIR_VALIDATE_BANK_A:
                        CLD
                        CMP             #STR8_DIR_RECORD_COUNT
                        BCC             ?BANK_OK
                        JMP             STR8_DIR_RETURN_RECORD_INVALID
?BANK_OK:              STA             STR8_DIR_BANK_WORK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        CLC
                        ADC             #<STR8_DIR_BASE
                        STA             STR8_PTR_LO
                        LDA             #>STR8_DIR_BASE
                        STA             STR8_PTR_HI

; An exactly all-$FF record is the only EMPTY representation.
                        LDY             #$00
?EMPTY_SCAN:           LDA             (STR8_PTR_LO),Y
                        CMP             #STR8_DIR_EMPTY_BYTE
                        BNE             ?STRUCTURE
                        INY
                        CPY             #STR8_DIR_RECORD_SIZE
                        BNE             ?EMPTY_SCAN
                        LDA             #STR8_DIR_RECORD_EMPTY
                        LDX             #$00
                        SEC
                        RTS

; RESERVED must remain erased.
?STRUCTURE:            LDY             #STR8_DIR_RESERVED
?RESERVED:             LDA             (STR8_PTR_LO),Y
                        CMP             #STR8_DIR_EMPTY_BYTE
                        BNE             STR8_DIR_RETURN_RECORD_INVALID
                        INY
                        CPY             #(STR8_DIR_RESERVED+STR8_DIR_RESERVED_LEN)
                        BNE             ?RESERVED

; DESCRIPTION is exactly five display-safe uppercase bytes.
                        LDY             #STR8_DIR_DESCRIPTION
?DESCRIPTION:          LDA             (STR8_PTR_LO),Y
                        JSR             STR8_DIR_DESCRIPTION_BYTE_A
                        BCC             STR8_DIR_RETURN_RECORD_INVALID
                        INY
                        CPY             #(STR8_DIR_DESCRIPTION+STR8_DIR_DESCRIPTION_LEN)
                        BNE             ?DESCRIPTION

                        LDY             #STR8_DIR_SEAL
                        LDA             (STR8_PTR_LO),Y
                        CMP             #STR8_DIR_SEAL_VALUE
                        BNE             STR8_DIR_RETURN_RECORD_INVALID

; Banks 0-2 have no local entry. Bank 3 accepts $8000-$EFFF or $FFFF.
?ENTRY:                LDA             STR8_DIR_BANK_WORK
                        CMP             #STR8_DIR_BANK3
                        BEQ             ?ENTRY_BANK3
                        LDY             #STR8_DIR_ENTRY_LO
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BNE             STR8_DIR_RETURN_RECORD_INVALID
                        INY
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BNE             STR8_DIR_RETURN_RECORD_INVALID
                        BRA             ?JOURNAL

?ENTRY_BANK3:          LDY             #STR8_DIR_ENTRY_HI
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BNE             ?ENTRY_BANK3_RANGE
                        DEY
                        LDA             (STR8_PTR_LO),Y
                        CMP             #$FF
                        BNE             STR8_DIR_RETURN_RECORD_INVALID
                        BRA             ?JOURNAL
?ENTRY_BANK3_RANGE:    CMP             #STR8_DIR_BANK3_ENTRY_MIN_HI
                        BCC             STR8_DIR_RETURN_RECORD_INVALID
                        CMP             #(STR8_DIR_BANK3_ENTRY_MAX_HI+1)
                        BCS             STR8_DIR_RETURN_RECORD_INVALID

?JOURNAL:              JSR             STR8_DIR_SCAN_JOURNAL
                        BCC             STR8_DIR_RETURN_RECORD_INVALID
                        CMP             #STR8_DIR_JOURNAL_STARTED
                        BEQ             ?INCOMPLETE
                        BCC             STR8_DIR_RETURN_RECORD_INVALID
                        LDA             #STR8_DIR_RECORD_COMPLETE
                        SEC
                        RTS
?INCOMPLETE:           LDA             #STR8_DIR_RECORD_INCOMPLETE
                        SEC
                        RTS

STR8_DIR_RETURN_RECORD_INVALID:
                        LDX             #STR8_DIR_PAIR_NONE
                        LDA             #STR8_DIR_RECORD_INVALID
                        CLC
                        RTS

STR8_DIR_DESCRIPTION_BYTE_A:
                        CMP             #'A'
                        BCC             ?DIGIT
                        CMP             #'Z'+1
                        BCC             ?VALID
?DIGIT:                CMP             #'0'
                        BCC             ?PUNCTUATION
                        CMP             #'9'+1
                        BCC             ?VALID
?PUNCTUATION:          CMP             #'-'
                        BEQ             ?VALID
                        CMP             #'_'
                        BEQ             ?VALID
                        CMP             #'.'
                        BEQ             ?VALID
                        CLC
                        RTS
?VALID:                SEC
                        RTS

STR8_DIR_SCAN_JOURNAL:
                        LDY             #STR8_DIR_JOURNAL
                        LDX             #$00
                        STZ             STR8_DIR_OPEN_WORK
?BYTE:                 LDA             (STR8_PTR_LO),Y
                        STA             STR8_DIR_PACKED_WORK
                        LDA             #$04
                        STA             STR8_DIR_LEFT_WORK
?PAIR:                 LDA             STR8_DIR_PACKED_WORK
                        AND             #$03
                        STA             STR8_DIR_PAIR_WORK
                        LDA             STR8_DIR_OPEN_WORK
                        BEQ             ?BEFORE_OPEN
                        LDA             STR8_DIR_PAIR_WORK
                        CMP             #STR8_DIR_PAIR_UNUSED
                        BEQ             ?NEXT_PAIR
                        JMP             ?INVALID

?BEFORE_OPEN:          LDA             STR8_DIR_PAIR_WORK
                        CMP             #STR8_DIR_PAIR_COMPLETE
                        BEQ             ?NEXT_PAIR
                        CMP             #STR8_DIR_PAIR_ILLEGAL
                        BEQ             ?INVALID
                        CMP             #STR8_DIR_PAIR_STARTED
                        BEQ             ?STARTED
                        TXA
                        BNE             ?USED
                        LDA             #STR8_DIR_JOURNAL_FRESH
                        BRA             ?OPEN
?USED:                 LDA             #STR8_DIR_JOURNAL_COMPLETE
                        BRA             ?OPEN
?STARTED:              LDA             #STR8_DIR_JOURNAL_STARTED
?OPEN:                 STA             STR8_DIR_OPEN_WORK
                        STX             STR8_DIR_RESULT_PAIR

?NEXT_PAIR:            LSR             STR8_DIR_PACKED_WORK
                        LSR             STR8_DIR_PACKED_WORK
                        INX
                        DEC             STR8_DIR_LEFT_WORK
                        BNE             ?PAIR
                        INY
                        CPY             #(STR8_DIR_JOURNAL+STR8_DIR_JOURNAL_LEN)
                        BNE             ?BYTE
                        LDA             STR8_DIR_OPEN_WORK
                        BNE             ?RETURN_OPEN
                        LDA             #STR8_DIR_JOURNAL_FULL
                        LDX             #STR8_DIR_PAIR_NONE
                        SEC
                        RTS
?RETURN_OPEN:          LDX             STR8_DIR_RESULT_PAIR
                        SEC
                        RTS
?INVALID:              LDA             #STR8_DIR_JOURNAL_INVALID
                        LDX             #STR8_DIR_PAIR_NONE
                        CLC
                        RTS

                        IF              STR8_V1_LAYOUT
; STR8_DIR_WRITE_BYTES
;   IN:  STR8_REC_ADDR_LO/HI = first Bank-3 directory byte
;        STR8_REC_DATA_LEN   = byte count, 1-64 within $FFB0-$FFEF
;        STR8_REC_DATA_BUF   = exact desired bytes
;   OUT: A/STR8_REC_STATUS = STR8_DIR_WRITE_*; C=1 only on exact verify
;        STR8_REC_FAIL/OBSERVED/EXPECTED identify the first byte failure
;
; This is the only V1 directory mutation primitive. It never erases. The
; complete request is preflighted before mode $07 runs, so a later 0-to-1
; transition cannot partially program an earlier byte. The RAM worker repeats
; that whole-request preflight after selecting Bank 3.
STR8_DIR_WRITE_BYTES:
                        CLD
                        JSR             STR8_REC_CLEAR_FAILURE
                        LDA             STR8_REC_DATA_LEN
                        BEQ             ?BAD_COUNT
                        LDA             STR8_REC_ADDR_HI
                        CMP             #>STR8_DIR_BASE
                        BNE             ?BAD_RANGE
                        LDA             STR8_REC_ADDR_LO
                        CMP             #<STR8_DIR_BASE
                        BCC             ?BAD_RANGE
                        CMP             #<(STR8_DIR_END+1)
                        BCS             ?BAD_RANGE
                        CLC
                        ADC             STR8_REC_DATA_LEN
                        BCS             ?BAD_RANGE
                        CMP             #<(STR8_DIR_END+2)
                        BCS             ?BAD_RANGE

                        JSR             STR8_REC_LOAD_APPLY_POINTERS
?PREFLIGHT:            LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_REC_WORK_TMP
                        AND             (STR8_COPY_PTR_LO),Y
                        CMP             (STR8_COPY_PTR_LO),Y
                        BNE             ?BAD_TRANSITION
                        JSR             STR8_REC_ADVANCE_APPLY_POINTERS
                        DEC             STR8_REC_WORK_COUNT
                        BNE             ?PREFLIGHT

                        JSR             STR8_RUN_PROGRAM_RECORD_WORKER
                        BCC             ?WORKER_FAIL

                        JSR             STR8_REC_LOAD_APPLY_POINTERS
?VERIFY:               LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_REC_WORK_TMP
                        CMP             (STR8_COPY_PTR_LO),Y
                        BNE             ?VERIFY_FAIL
                        JSR             STR8_REC_ADVANCE_APPLY_POINTERS
                        DEC             STR8_REC_WORK_COUNT
                        BNE             ?VERIFY
                        LDA             #STR8_DIR_WRITE_OK
                        STA             STR8_REC_STATUS
                        SEC
                        RTS

?BAD_COUNT:            LDA             #STR8_DIR_WRITE_BAD_COUNT
                        BRA             ?FAIL
?BAD_RANGE:            LDA             STR8_REC_ADDR_LO
                        STA             STR8_REC_FAIL_LO
                        LDA             STR8_REC_ADDR_HI
                        STA             STR8_REC_FAIL_HI
                        LDA             #STR8_DIR_WRITE_BAD_RANGE
                        BRA             ?FAIL
?BAD_TRANSITION:       JSR             STR8_REC_CAPTURE_APPLY_FAILURE
                        LDA             #STR8_DIR_WRITE_BAD_TRANS
                        BRA             ?FAIL
?WORKER_FAIL:          LDA             #STR8_DIR_WRITE_WORKER
                        BRA             ?FAIL
?VERIFY_FAIL:          JSR             STR8_REC_CAPTURE_APPLY_FAILURE
                        LDA             #STR8_DIR_WRITE_VERIFY
?FAIL:                 STA             STR8_REC_STATUS
                        CLC
                        RTS
                        ENDIF

; Preserve the caller's worker mode while sharing the exact mode-$07 doorway
; between HIMON L F and the directory writer.
STR8_RUN_PROGRAM_RECORD_WORKER:
                        IF              STR8_RAM_PROOF
                        CLC
                        RTS
                        ELSE
                        LDA             STR8_COPY_MODE
                        PHA
                        LDA             #STR8_COPY_MODE_PROGRAM_RECORD
                        STA             STR8_COPY_MODE
                        JSR             STR8_COPY_WORKER_TO_RAM
                        JSR             STR8_WORKER_RUN
                        LDA             #$00
                        ADC             #$00
                        STA             STR8_REC_WORK_TMP
                        PLA
                        STA             STR8_COPY_MODE
                        LDA             STR8_REC_WORK_TMP
                        CMP             #$01
                        RTS
                        ENDIF

; ----------------------------------------------------------------------------
; V1 validated-record service. PARSE validates a complete S0/S1/S9 record into
; $7B00 before publishing its descriptor. APPLY_LF performs whole-record policy
; preflight before the ROM build invokes the RAM flash worker.
; ----------------------------------------------------------------------------
STR8_RECORD_SERVICE_BODY:
                        CLD
                        LDA             STR8_REC_OP
                        CMP             #STR8_REC_OP_PARSE
                        BEQ             STR8_REC_PARSE
                        CMP             #STR8_REC_OP_APPLY_LF
                        BNE             ?BAD_OP
                        JMP             STR8_REC_APPLY_LF
?BAD_OP:
                        LDA             #STR8_REC_BAD_OP
                        JMP             STR8_REC_FAIL_A

STR8_REC_PARSE:
                        JSR             STR8_REC_CLEAR_RESULT
                        LDA             STR8_REC_FORMAT
                        CMP             #STR8_REC_FORMAT_S19
                        BEQ             ?FORMAT_OK
                        LDA             #STR8_REC_BAD_FORMAT
                        JMP             STR8_REC_FAIL_A
?FORMAT_OK:
                        LDA             STR8_REC_SOURCE
                        CMP             #STR8_REC_SOURCE_CONSOLE+1
                        BCC             ?SOURCE_OK
                        LDA             #STR8_REC_BAD_SOURCE
                        JMP             STR8_REC_FAIL_A
?SOURCE_OK:
                        LDA             STR8_REC_SRC_LO
                        STA             STR8_PTR_LO
                        LDA             STR8_REC_SRC_HI
                        STA             STR8_PTR_HI
                        LDA             STR8_REC_SRC_LEN
                        STA             STR8_REC_WORK_REMAIN
                        LDA             STR8_REC_SOURCE
                        CMP             #STR8_REC_SOURCE_BUFFER
                        BNE             ?CONSOLE_START

                        ; Validate the inclusive end without rejecting a
                        ; one-byte span at $FFFF.
                        LDA             STR8_REC_WORK_REMAIN
                        BEQ             ?BUFFER_START
                        DEC             A
                        CLC
                        ADC             STR8_PTR_LO
                        BCC             ?BUFFER_START
                        LDA             STR8_PTR_HI
                        CMP             #$FF
                        BNE             ?BUFFER_START
                        LDA             #STR8_REC_BAD_SOURCE
                        JMP             STR8_REC_FAIL_A

?CONSOLE_START:
                        JSR             STR8_REC_READ_CHAR
                        BCS             ?CONSOLE_HAVE_CHAR
                        JMP             STR8_REC_FAIL_READ_START
?CONSOLE_HAVE_CHAR:
                        CMP             #$0D
                        BEQ             ?CONSOLE_START
                        CMP             #$0A
                        BEQ             ?CONSOLE_START
                        BRA             ?HAVE_START
?BUFFER_START:
                        JSR             STR8_REC_READ_CHAR
                        BCS             ?HAVE_START
                        JMP             STR8_REC_FAIL_READ_START
?HAVE_START:
                        AND             #$DF
                        CMP             #'S'
                        BEQ             ?HAVE_S
                        LDA             #STR8_REC_BAD_START
                        JMP             STR8_REC_FAIL_A
?HAVE_S:
                        JSR             STR8_REC_READ_CHAR
                        BCS             ?HAVE_TYPE
                        JMP             STR8_REC_FAIL_READ_TYPE
?HAVE_TYPE:
                        STA             STR8_REC_WORK_TYPE
                        CMP             #'0'
                        BEQ             STR8_REC_PARSE_BODY
                        CMP             #'1'
                        BEQ             STR8_REC_PARSE_BODY
                        CMP             #'9'
                        BEQ             STR8_REC_PARSE_BODY
                        LDA             #STR8_REC_BAD_TYPE
                        JMP             STR8_REC_FAIL_A

STR8_REC_PARSE_BODY:
                        STZ             STR8_REC_WORK_SUM
                        JSR             STR8_REC_READ_SUM_BYTE
                        BCS             ?HAVE_COUNT
                        JMP             STR8_REC_FAIL_READ_HEX
?HAVE_COUNT:
                        STA             STR8_REC_WORK_COUNT
                        CMP             #$03
                        BCS             ?COUNT_MIN_OK
                        LDA             #STR8_REC_BAD_COUNT
                        JMP             STR8_REC_FAIL_A
?COUNT_MIN_OK:
                        LDA             STR8_REC_WORK_TYPE
                        CMP             #'9'
                        BNE             ?COUNT_OK
                        LDA             STR8_REC_WORK_COUNT
                        CMP             #$03
                        BEQ             ?COUNT_OK
                        LDA             #STR8_REC_BAD_COUNT
                        JMP             STR8_REC_FAIL_A
?COUNT_OK:
                        JSR             STR8_REC_READ_SUM_BYTE
                        BCS             ?HAVE_ADDR_HI
                        JMP             STR8_REC_FAIL_READ_HEX
?HAVE_ADDR_HI:
                        STA             STR8_REC_ADDR_HI
                        JSR             STR8_REC_READ_SUM_BYTE
                        BCS             ?HAVE_ADDR_LO
                        JMP             STR8_REC_FAIL_READ_HEX
?HAVE_ADDR_LO:
                        STA             STR8_REC_ADDR_LO
                        LDA             STR8_REC_WORK_COUNT
                        SEC
                        SBC             #$03
                        STA             STR8_REC_DATA_LEN
                        STA             STR8_REC_WORK_COUNT
                        LDX             #$00
?DATA:
                        LDA             STR8_REC_WORK_COUNT
                        BEQ             ?CHECKSUM
                        JSR             STR8_REC_READ_SUM_BYTE
                        BCS             ?HAVE_DATA_BYTE
                        JMP             STR8_REC_FAIL_READ_HEX
?HAVE_DATA_BYTE:
                        STA             STR8_REC_DATA_BUF,X
                        INX
                        DEC             STR8_REC_WORK_COUNT
                        BRA             ?DATA
?CHECKSUM:
                        JSR             STR8_REC_READ_SUM_BYTE
                        BCS             ?HAVE_CHECKSUM
                        JMP             STR8_REC_FAIL_READ_HEX
?HAVE_CHECKSUM:
                        LDA             STR8_REC_WORK_SUM
                        CMP             #$FF
                        BEQ             ?CHECKSUM_OK
                        LDA             #STR8_REC_BAD_CHECKSUM
                        JMP             STR8_REC_FAIL_A
?CHECKSUM_OK:
                        LDA             STR8_REC_SOURCE
                        CMP             #STR8_REC_SOURCE_BUFFER
                        BNE             ?CONSOLE_END
                        LDA             STR8_REC_WORK_REMAIN
                        BEQ             ?PUBLISH
                        LDA             #STR8_REC_BAD_END
                        JMP             STR8_REC_FAIL_A
?CONSOLE_END:
                        JSR             STR8_REC_READ_CHAR
                        BCS             ?HAVE_END
                        JMP             STR8_REC_FAIL_READ_END
?HAVE_END:
                        IF              STR8_V1_INSTALLER_DRY
                        CMP             #$0D
                        BNE             ?CHECK_LF
                        INC             STR8_INPUT_SKIP_LF
                        BRA             ?PUBLISH
                        ELSE
                        CMP             #$0D
                        BEQ             ?PUBLISH
                        ENDIF
?CHECK_LF:
                        CMP             #$0A
                        BEQ             ?PUBLISH
                        LDA             #STR8_REC_BAD_END
                        JMP             STR8_REC_FAIL_A

?PUBLISH:
                        LDA             #STR8_REC_DATA_BUF_LO
                        STA             STR8_REC_DATA_LO
                        LDA             #STR8_REC_DATA_BUF_HI
                        STA             STR8_REC_DATA_HI
                        LDA             STR8_REC_WORK_TYPE
                        CMP             #'9'
                        BEQ             ?END
                        AND             #$0F
                        INC             A
                        STA             STR8_REC_KIND
                        JMP             STR8_REC_RETURN_OK
?END:
                        LDA             #STR8_REC_KIND_END
                        STA             STR8_REC_KIND
                        LDA             #STR8_REC_FLAG_ENTRY_VALID
                        STA             STR8_REC_FLAGS
                        LDA             STR8_REC_ADDR_LO
                        STA             STR8_REC_ENTRY_LO
                        LDA             STR8_REC_ADDR_HI
                        STA             STR8_REC_ENTRY_HI
                        JMP             STR8_REC_RETURN_OK

STR8_REC_FAIL_READ_START:
                        LDX             #STR8_REC_BAD_START
                        BRA             STR8_REC_FAIL_READ_X
STR8_REC_FAIL_READ_TYPE:
                        LDX             #STR8_REC_BAD_TYPE
                        BRA             STR8_REC_FAIL_READ_X
STR8_REC_FAIL_READ_HEX:
                        LDX             #STR8_REC_BAD_HEX
                        BRA             STR8_REC_FAIL_READ_X
STR8_REC_FAIL_READ_END:
                        LDX             #STR8_REC_BAD_END
STR8_REC_FAIL_READ_X:
                        LDA             STR8_REC_STATUS
                        CMP             #STR8_REC_ABORT
                        BNE             ?NOT_ABORT
                        JMP             STR8_REC_RETURN_CURRENT_FAIL
?NOT_ABORT:
                        TXA
                        JMP             STR8_REC_FAIL_A

STR8_REC_APPLY_LF:
                        JSR             STR8_REC_CLEAR_FAILURE
                        LDA             STR8_REC_FORMAT
                        CMP             #STR8_REC_FORMAT_S19
                        BEQ             ?FORMAT_OK
                        LDA             #STR8_REC_BAD_FORMAT
                        JMP             STR8_REC_FAIL_A
?FORMAT_OK:
                        LDA             STR8_REC_KIND
                        CMP             #STR8_REC_KIND_DATA
                        BEQ             ?KIND_OK
                        LDA             #STR8_REC_BAD_TYPE
                        JMP             STR8_REC_FAIL_A
?KIND_OK:
                        LDA             STR8_REC_FLAGS
                        BEQ             ?FLAGS_OK
                        LDA             #STR8_REC_BAD_FORMAT
                        JMP             STR8_REC_FAIL_A
?FLAGS_OK:
                        LDA             STR8_REC_DATA_LO
                        CMP             #STR8_REC_DATA_BUF_LO
                        BNE             ?BAD_DATA
                        LDA             STR8_REC_DATA_HI
                        CMP             #STR8_REC_DATA_BUF_HI
                        BEQ             ?DATA_PTR_OK
?BAD_DATA:
                        LDA             #STR8_REC_BAD_SOURCE
                        JMP             STR8_REC_FAIL_A
?DATA_PTR_OK:
                        LDA             STR8_REC_DATA_LEN
                        CMP             #STR8_REC_DATA_MAX+1
                        BCC             ?LENGTH_OK
                        LDA             #STR8_REC_BAD_COUNT
                        JMP             STR8_REC_FAIL_A
?LENGTH_OK:
                        LDA             STR8_REC_DATA_LEN
                        BNE             ?NONEMPTY
                        JMP             STR8_REC_RETURN_OK
?NONEMPTY:
                        LDA             STR8_REC_ADDR_HI
                        CMP             #$80
                        BCC             ?PROTECT_START
                        CMP             #$C0
                        BCS             ?PROTECT_START
                        LDA             STR8_REC_DATA_LEN
                        DEC             A
                        CLC
                        ADC             STR8_REC_ADDR_LO
                        LDA             STR8_REC_ADDR_HI
                        ADC             #$00
                        CMP             #$C0
                        BCC             ?PREFLIGHT_INIT
                        STZ             STR8_REC_FAIL_LO
                        LDA             #$C0
                        STA             STR8_REC_FAIL_HI
                        LDA             #STR8_REC_LF_PROTECT
                        JMP             STR8_REC_FAIL_A
?PROTECT_START:
                        LDA             STR8_REC_ADDR_LO
                        STA             STR8_REC_FAIL_LO
                        LDA             STR8_REC_ADDR_HI
                        STA             STR8_REC_FAIL_HI
                        LDA             #STR8_REC_LF_PROTECT
                        JMP             STR8_REC_FAIL_A

?PREFLIGHT_INIT:
                        JSR             STR8_REC_LOAD_APPLY_POINTERS
?PREFLIGHT:
                        LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_REC_WORK_TMP
                        CMP             (STR8_COPY_PTR_LO),Y
                        BEQ             ?PREFLIGHT_NEXT
                        CMP             #$FF
                        BEQ             ?PREFLIGHT_NEXT
                        JSR             STR8_REC_CAPTURE_APPLY_FAILURE
                        LDA             #STR8_REC_LF_NEED_ERASE
                        JMP             STR8_REC_FAIL_A
?PREFLIGHT_NEXT:
                        JSR             STR8_REC_ADVANCE_APPLY_POINTERS
                        DEC             STR8_REC_WORK_COUNT
                        BNE             ?PREFLIGHT

                        JSR             STR8_RUN_PROGRAM_RECORD_WORKER
                        BCS             ?VERIFY_INIT
                        LDA             #STR8_REC_LF_WRITE
                        JMP             STR8_REC_FAIL_A

?VERIFY_INIT:
                        JSR             STR8_REC_LOAD_APPLY_POINTERS
?VERIFY:
                        LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        STA             STR8_REC_WORK_TMP
                        CMP             (STR8_COPY_PTR_LO),Y
                        BEQ             ?VERIFY_NEXT
                        JSR             STR8_REC_CAPTURE_APPLY_FAILURE
                        LDA             #STR8_REC_LF_VERIFY
                        JMP             STR8_REC_FAIL_A
?VERIFY_NEXT:
                        JSR             STR8_REC_ADVANCE_APPLY_POINTERS
                        DEC             STR8_REC_WORK_COUNT
                        BNE             ?VERIFY
                        JMP             STR8_REC_RETURN_OK

STR8_REC_LOAD_APPLY_POINTERS:
                        LDA             STR8_REC_ADDR_LO
                        STA             STR8_PTR_LO
                        LDA             STR8_REC_ADDR_HI
                        STA             STR8_PTR_HI
                        LDA             #STR8_REC_DATA_BUF_LO
                        STA             STR8_COPY_PTR_LO
                        LDA             #STR8_REC_DATA_BUF_HI
                        STA             STR8_COPY_PTR_HI
                        LDA             STR8_REC_DATA_LEN
                        STA             STR8_REC_WORK_COUNT
                        RTS

STR8_REC_ADVANCE_APPLY_POINTERS:
                        INC             STR8_PTR_LO
                        BNE             ?DATA
                        INC             STR8_PTR_HI
?DATA:
                        INC             STR8_COPY_PTR_LO
                        BNE             ?DONE
                        INC             STR8_COPY_PTR_HI
?DONE:
                        RTS

STR8_REC_CAPTURE_APPLY_FAILURE:
                        LDA             STR8_PTR_LO
                        STA             STR8_REC_FAIL_LO
                        LDA             STR8_PTR_HI
                        STA             STR8_REC_FAIL_HI
                        LDA             STR8_REC_WORK_TMP
                        STA             STR8_REC_OBSERVED
                        LDY             #$00
                        LDA             (STR8_COPY_PTR_LO),Y
                        STA             STR8_REC_EXPECTED
                        RTS

STR8_REC_CLEAR_RESULT:
                        LDX             #(STR8_REC_DATA_HI-STR8_REC_KIND)
?RESULT:               STZ             STR8_REC_KIND,X
                        DEX
                        BPL             ?RESULT
STR8_REC_CLEAR_FAILURE:
                        STZ             STR8_REC_STATUS
                        LDX             #(STR8_REC_EXPECTED-STR8_REC_FAIL_LO)
?FAILURE:              STZ             STR8_REC_FAIL_LO,X
                        DEX
                        BPL             ?FAILURE
                        RTS

STR8_REC_READ_SUM_BYTE:
                        JSR             STR8_REC_READ_HEX_BYTE
                        BCC             ?FAIL
                        PHA
                        CLC
                        ADC             STR8_REC_WORK_SUM
                        STA             STR8_REC_WORK_SUM
                        PLA
                        SEC
?FAIL:
                        RTS

STR8_REC_READ_HEX_BYTE:
                        JSR             STR8_REC_READ_CHAR
                        BCC             ?FAIL
                        JSR             STR8_REC_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             STR8_REC_WORK_TMP
                        JSR             STR8_REC_READ_CHAR
                        BCC             ?FAIL
                        JSR             STR8_REC_HEX_ASCII_TO_NIBBLE
                        BCC             ?FAIL
                        ORA             STR8_REC_WORK_TMP
?FAIL:
                        RTS

STR8_REC_HEX_ASCII_TO_NIBBLE:
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
                        RTS
?DIGIT:
                        SEC
                        SBC             #'0'
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_REC_READ_CHAR:
                        LDA             STR8_REC_SOURCE
                        CMP             #STR8_REC_SOURCE_BUFFER
                        BEQ             ?BUFFER
                        IF              STR8_V1_LAYOUT
                        JSR             STR8_READ_TEXT_BYTE_BLOCK
                        ELSE
                        JSR             STR8_CON_READ_BYTE_BLOCK
                        ENDIF
                        CMP             #$03
                        BNE             ?OK
                        LDA             #STR8_REC_ABORT
                        STA             STR8_REC_STATUS
                        CLC
                        RTS
?BUFFER:
                        LDA             STR8_REC_WORK_REMAIN
                        BEQ             ?EMPTY
                        LDY             #$00
                        LDA             (STR8_PTR_LO),Y
                        INC             STR8_PTR_LO
                        BNE             ?COUNT
                        INC             STR8_PTR_HI
?COUNT:
                        DEC             STR8_REC_WORK_REMAIN
?OK:
                        SEC
                        RTS
?EMPTY:
                        CLC
                        RTS

STR8_REC_RETURN_OK:
                        STZ             STR8_REC_STATUS
                        LDA             #STR8_REC_OK
                        SEC
                        RTS
STR8_REC_RETURN_CURRENT_FAIL:
                        LDA             STR8_REC_STATUS
                        CLC
                        RTS
STR8_REC_FAIL_A:
                        STA             STR8_REC_STATUS
                        CLC
                        RTS

                        IF              STR8_RAM_PROOF
STR8_SELECT_BANK_3:
                        JSR             FLSH_BANK_SELECT_3
                        RTS
                        ENDIF

STR8_CONFIRM_Y:
                        IF              STR8_V1_LAYOUT
                        LDX             #$01
                        JSR             STR8_READ_LINE
                        CMP             #$01
                        BNE             ?NO
                        LDA             STR8_REC_DATA_BUF
                        CMP             #'Y'
                        BNE             ?NO
                        SEC
                        RTS
?NO:                   CLC
                        RTS
                        ELSE
                        JSR             STR8_READ_COMMAND
                        CMP             #'Y'
                        BEQ             ?YES
                        CLC
?YES:
                        RTS
                        ENDIF

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
                        IF              STR8_WORKER_COPY_LEN_HI
                        LDX             #STR8_WORKER_COPY_LEN_HI
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
                        ELSE
                        LDY             #$00
                        ENDIF
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
                        IF              STR8_V1_LAYOUT
                        ELSE
; ----------------------------------------------------------------------------
; Fixed-gate HIMON update: receive S1/S9, stage blank C/D/E, then program C/D/E.
; ----------------------------------------------------------------------------
STR8_UPD_INIT:
                        STZ             STR8_UPD_MASK
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
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_SOURCE_CONSOLE
                        STA             STR8_REC_SOURCE
                        JSR             STR8_RECORD_SERVICE_BODY
                        BCC             ?FAIL
                        LDA             STR8_REC_KIND
                        CMP             #STR8_REC_KIND_METADATA
                        BEQ             ?RECORD
                        CMP             #STR8_REC_KIND_DATA
                        BEQ             ?DATA
                        CMP             #STR8_REC_KIND_END
                        BEQ             ?TERM
                        BRA             ?FAIL
?DATA:
                        JSR             STR8_STAGE_HIMON_RECORD
                        BCC             ?FAIL
                        LDA             #'.'
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        BRA             ?RECORD
?TERM:
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

STR8_STAGE_HIMON_RECORD:
                        LDA             STR8_REC_ADDR_LO
                        STA             STR8_UPD_DST_LO
                        LDA             STR8_REC_ADDR_HI
                        STA             STR8_UPD_DST_HI
                        LDA             STR8_REC_DATA_LEN
                        STA             STR8_UPD_DATA_LEN
                        BEQ             ?OK
                        LDA             STR8_UPD_DST_HI
                        CMP             #$C0
                        BCC             ?FAIL
                        CMP             #$F0
                        BCS             ?FAIL
                        LDA             STR8_UPD_DATA_LEN
                        DEC             A
                        CLC
                        ADC             STR8_UPD_DST_LO
                        LDA             STR8_UPD_DST_HI
                        ADC             #$00
                        CMP             #$F0
                        BCS             ?FAIL
                        LDA             #$01
                        TSB             STR8_UPD_MASK
                        LDX             #$00
?DATA:
                        LDA             STR8_UPD_DATA_LEN
                        BEQ             ?OK
                        LDA             STR8_UPD_DST_HI
                        AND             #$7F
                        STA             STR8_PTR_HI
                        LDA             STR8_UPD_DST_LO
                        STA             STR8_PTR_LO
                        LDY             #$00
                        LDA             STR8_REC_DATA_BUF,X
                        STA             (STR8_PTR_LO),Y
                        INX
                        INC             STR8_UPD_DST_LO
                        BNE             ?COUNT
                        INC             STR8_UPD_DST_HI
?COUNT:
                        DEC             STR8_UPD_DATA_LEN
                        BRA             ?DATA
?OK:
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
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS
                        ENDIF
                        ENDIF

                        IF              STR8_V1_LAYOUT
                        ELSE
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
                        ENDIF

STR8_PRINT_JUMP_FAIL:
                        LDX             #<MSG_JUMP_FAIL_B
                        LDY             #>MSG_JUMP_FAIL_B
                        JSR             STR8_PRINT_XY
                        LDA             STR8_JUMP_BANK
                        JSR             STR8_WRITE_DEC_DIGIT_A
                        LDX             #<MSG_JUMP_FAIL_VEC
                        LDY             #>MSG_JUMP_FAIL_VEC
                        JSR             STR8_PRINT_XY
                        LDA             STR8_JUMP_VEC_HI
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDA             STR8_JUMP_VEC_LO
                        JSR             STR8_WRITE_HEX_BYTE_A
                        LDX             #<MSG_CRLF
                        LDY             #>MSG_CRLF
                        JMP             STR8_PRINT_XY

STR8_WRITE_DEC_DIGIT_A:
                        AND             #$0F
                        CLC
                        ADC             #'0'
                        JMP             STR8_CON_WRITE_BYTE_BLOCK

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
                        JMP             STR8_CON_WRITE_BYTE_BLOCK
?DIGIT:                 CLC
                        ADC             #'0'
                        JMP             STR8_CON_WRITE_BYTE_BLOCK

                        IF              STR8_RAM_PROOF
; RAM-proof equivalent of worker mode $08. All code and bank-select helpers
; remain in RAM after the visible $8000-$FFFF bank window changes.
STR8_JUMP_BANK_RAM:
                        PHP
                        SEI
                        LDA             STR8_JUMP_BANK
                        CMP             #STR8_BANK_COUNT
                        BCS             ?BAD_BANK
                        JSR             FLSH_BANK_SELECT_A
                        LDA             STR8_RESET_VECTOR
                        STA             STR8_JUMP_VEC_LO
                        LDA             STR8_RESET_VECTOR+1
                        STA             STR8_JUMP_VEC_HI
                        CMP             #$80
                        BCC             ?LOW_VECTOR
                        CMP             #$FF
                        BNE             ?GO
                        LDA             STR8_JUMP_VEC_LO
                        CMP             #$FF
                        BEQ             ?ERASED_VECTOR
?GO:
                        LDA             #STR8_JUMP_STATUS_GO
                        STA             STR8_JUMP_STATUS
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        STZ             STR8_BANK_JUMP_SIG1
                        LDA             STR8_JUMP_BANK
                        STA             STR8_BANK_LAST_JUMP
                        LDA             #STR8_BANK_JUMP_SIG0_VALUE
                        STA             STR8_BANK_JUMP_SIG0
                        LDA             #STR8_BANK_JUMP_SIG1_VALUE
                        STA             STR8_BANK_JUMP_SIG1
                        JMP             (STR8_JUMP_VEC_LO)
?BAD_BANK:
                        LDA             #STR8_JUMP_STATUS_BANK
                        BRA             ?FAIL
?LOW_VECTOR:
                        LDA             #STR8_JUMP_STATUS_LOW
                        BRA             ?FAIL
?ERASED_VECTOR:
                        LDA             #STR8_JUMP_STATUS_ERASED
?FAIL:
                        STA             STR8_JUMP_STATUS
                        JSR             FLSH_BANK_SELECT_3
                        PLP
                        CLC
                        RTS
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
                        JSR             STR8_CON_WRITE_BYTE_BLOCK
                        INY
                        BNE             ?LOOP
                        INC             STR8_PTR_HI
                        BRA             ?LOOP
?LAST:                  AND             #$7F
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

                        INCLUDE         "str8-version.inc"
; 2026-08-03T09:46Z Codex       Compact the resident ROM location into the ID.
                        IF              STR8_RAM_PROOF
                        DB              $0D,$8A
                        ELSE
                        DB              " $F",$0D,$8A
                        ENDIF
MSG_SCREEN:
                        IF              STR8_RAM_PROOF
                        DB              "RAM $0200 BUF $4000-$4FFF",$0D,$0A
                        ENDIF
MSG_HELP:
                        IF              STR8_V1_LAYOUT
                        DB              "I J0 J1 J2 J3 R",$0D,$8A
                        ELSE
                        DB              "U J0 J1 J2 J3 G R",$0D,$8A
                        ENDIF
MSG_PROMPT:             DB              "STR8-N",('>'+$80)
                        IF              STR8_RAM_PROOF
                        ELSE
MSG_BOOT_PROMPT:        DB              $0D,$0A
                        DB              "0/1/2=BOOT 3=HIMON S=STR8 ",$A0
MSG_BOOT_BANK_WAIT:     DB              "BOOT IN 3S",$0D,$8A
                        ENDIF

MSG_OK:                 DB              $0D,$0A,"OK",$0D,$8A
MSG_ABORT:              DB              $0D,$0A,"ABORT",$0D,$8A
                        IF              STR8_V1_LAYOUT
MSG_I_BANK:             DB              $0D,$0A,"I B0-3:",$A0
MSG_I_TYPE_PROMPT:      DB              $0D,$0A,"TYPE:",$A0
MSG_I_DESC_PROMPT:      DB              $0D,$0A,"DESC:",$A0
MSG_I_INVALID:          DB              $0D,$0A,"DIR INVALID",$0D,$8A
MSG_I_SUMMARY:          DB              $0D,$0A,"I ",('B'+$80)
MSG_I_RANGE_32K:        DB              " 8000-FFFF",(' '+$80)
MSG_I_RANGE_28K:        DB              " 8000-EFFF",(' '+$80)
MSG_I_TYPE:             DB              $0D,$0A,"T",('='+$80)
MSG_I_DESC:             DB              " D",('='+$80)
MSG_I_ENTRY:            DB              " E=",('$'+$80)
MSG_I_EMPTY:            DB              " EMPTY",(' '+$80)
MSG_I_INCOMPLETE:       DB              " INCOMPLETE",(' '+$80)
MSG_I_COMPLETE:         DB              " COMPLETE",(' '+$80)
MSG_I_FULL:             DB              " FULL",(' '+$80)
MSG_I_PAIR:             DB              "P",('='+$80)
                        IF              STR8_V1_INSTALLER_DRY
MSG_I_STAGE_CONFIRM:    DB              " STAGE? Y:",$A0
MSG_I_SEND_S19:         DB              $0D,$0A,"SEND S19",$0D,$8A
MSG_I_STAGE_OK:         DB              "STAGE O",('K'+$80)
MSG_I_S19_FAIL:         DB              $0D,$0A,"S19 FAI",('L'+$80)
                        ENDIF
MSG_I_NO_WRITE:         DB              " NO WRITE",$0D,$8A
                        ENDIF
                        IF              STR8_V1_LAYOUT
                        ELSE
MSG_COPY_FAIL:          DB              $0D,$0A,"COPY FAIL",$0D,$8A
MSG_UPDATE_ROM_ONLY:    DB              $0D,$0A,"U ROM ONLY",$0D,$8A
MSG_UPDATE_HIMON:       DB              $0D,$0A,"UPDATE HIMON C000-EFFF? Y:",$A0
MSG_UPDATE_SEND_S19:    DB              $0D,$0A,"SEND S19 C000-EFFF",$0D,$8A
MSG_UPDATE_WRITE:       DB              $0D,$0A,"PROGRAM C000-EFFF? Y:",$A0
MSG_S19_FAIL:           DB              $0D,$0A,"S19 FAIL",$0D,$8A
MSG_S19_NO_DATA:        DB              $0D,$0A,"NO S19 DATA",$0D,$8A
MSG_G_HIMON:            DB              $0D,$0A,"G HIMON",$0D,$8A
                        ENDIF
MSG_NO_BOOT:            DB              $0D,$0A,"NO BOOT @C000",$0D,$8A
MSG_JUMP_B:             DB              $0D,$0A,"J ",('B'+$80)
MSG_JUMP_FAIL_B:        DB              $0D,$0A,"JERR ",('B'+$80)
MSG_JUMP_FAIL_VEC:      DB              " V=",('$'+$80)
                        IF              STR8_RAM_PROOF
MSG_COPY_FAIL_AT:       DB              $0D,$0A,"COPY FAIL @ ",('$'+$80)
                        ENDIF
MSG_CRLF:               DB              $0D,$8A

                        END

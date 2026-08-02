; ----------------------------------------------------------------------------
; str8.asm
; STR8 V0 small recovery proof.
;
; Command surface:
;   ?  print tiny ID
;   U  update HIMON from S19, fixed gate $C000-$EFFF
;   J0/J1/J2/J3  non-destructive reset-vector handoff to bank 0/1/2/3
;   G  go HIMON
;   R  reset through the live bank reset vector
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
STR8_WORKER_STORE_LO    EQU             $53
STR8_WORKER_STORE_HI    EQU             $FD
                        ELSE
STR8_WORKER_STORE_LO    EQU             $93
STR8_WORKER_STORE_HI    EQU             $FD
                        ENDIF
STR8_WORKER_COPY_LEN_LO EQU             $5D
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
                        JSR             STR8_READ_COMMAND
                        CMP             #$00
                        BNE             ?DISPATCH
                        JSR             STR8_CMD_ABORT
                        BRA             STR8_CMD_LOOP
?DISPATCH:
                        JSR             STR8_DISPATCH_A
                        BRA             STR8_CMD_LOOP

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
                        CMP             #'?'
                        BNE             ?NOT_ID
                        JMP             STR8_CMD_ID
?NOT_ID:
                        CMP             #'J'
                        BNE             ?NOT_J
                        JMP             STR8_CMD_JUMP_BANK
?NOT_J:
                        CMP             #'G'
                        BNE             ?NOT_G
                        JMP             STR8_CMD_G_HIMON
?NOT_G:
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
                        JMP             STR8_PRINT_XY

; 2026-07-28T21:19-05:00        Codex       J0-J2 hand off opaque banks from RAM.
; 2026-07-28T22:48-05:00        Codex       Echo the two-byte J command at the prompt.
; 2026-08-02T00:00-05:00        Codex       J3 returns a running STR8 copy to Bank 3.
STR8_CMD_JUMP_BANK:
?OPERAND:
                        JSR             STR8_READ_COMMAND
                        CMP             #$00
                        BNE             ?HAVE_OPERAND
                        JMP             STR8_CMD_ABORT
?HAVE_OPERAND:
                        CMP             #' '
                        BEQ             ?OPERAND
                        CMP             #'0'
                        BCC             ?BAD
                        CMP             #'4'
                        BCS             ?BAD
                        AND             #$03
                        JSR             STR8_JUMP_BANK_PREP_A
                        JMP             STR8_JUMP_BANK_LAUNCH
?BAD:
                        JMP             STR8_CMD_UNKNOWN

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

STR8_CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
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

STR8_AP_IMPORT_LINK_SERVICE_BODY:
                        LDA             #HIM_AP_OP_LINK
                        STA             HIM_AP_OP
                        JMP             (HIM_SVC_AP_LO)

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
                        CMP             #$0D
                        BEQ             ?PUBLISH
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

                        IF              STR8_RAM_PROOF
                        ; The relocated proof image has no stored RAM worker.
                        LDA             #STR8_REC_LF_WRITE
                        JMP             STR8_REC_FAIL_A
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
                        BNE             ?VERIFY_INIT
                        LDA             #STR8_REC_LF_WRITE
                        JMP             STR8_REC_FAIL_A
                        ENDIF

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
                        JSR             STR8_CON_READ_BYTE_BLOCK
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
                        JSR             STR8_READ_COMMAND
                        CMP             #'Y'
                        BEQ             ?YES
                        CLC
?YES:
                        RTS

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
MSG_SCREEN:
                        IF              STR8_RAM_PROOF
                        DB              "RAM $0200 BUF $4000-$4FFF",$0D,$0A
                        ELSE
                        DB              "ROM $F000",$0D,$0A
                        ENDIF
                        DB              "? U J0 J1 J2 J3 G R",$0D,$8A
MSG_PROMPT:             DB              "STR8-N",('>'+$80)
                        IF              STR8_RAM_PROOF
                        ELSE
MSG_BOOT_PROMPT:        DB              $0D,$0A
                        DB              "0/1/2=BOOT 3=HIMON S=STR8 ",$A0
MSG_BOOT_BANK_WAIT:     DB              "BOOT IN 3S",$0D,$8A
                        ENDIF

MSG_UNKNOWN:            DB              $0D,$0A,"?",$0D,$8A
MSG_OK:                 DB              $0D,$0A,"OK",$0D,$8A
MSG_ABORT:              DB              $0D,$0A,"ABORT",$0D,$8A
MSG_COPY_FAIL:          DB              $0D,$0A,"COPY FAIL",$0D,$8A
MSG_UPDATE_ROM_ONLY:    DB              $0D,$0A,"U ROM ONLY",$0D,$8A
MSG_UPDATE_HIMON:       DB              $0D,$0A,"UPDATE HIMON C000-EFFF? Y:",$A0
MSG_UPDATE_SEND_S19:    DB              $0D,$0A,"SEND S19 C000-EFFF",$0D,$8A
MSG_UPDATE_WRITE:       DB              $0D,$0A,"PROGRAM C000-EFFF? Y:",$A0
MSG_S19_FAIL:           DB              $0D,$0A,"S19 FAIL",$0D,$8A
MSG_S19_NO_DATA:        DB              $0D,$0A,"NO S19 DATA",$0D,$8A
MSG_G_HIMON:            DB              $0D,$0A,"G HIMON",$0D,$8A
MSG_NO_BOOT:            DB              $0D,$0A,"NO BOOT @C000",$0D,$8A
MSG_JUMP_B:             DB              $0D,$0A,"J ",('B'+$80)
MSG_JUMP_FAIL_B:        DB              $0D,$0A,"JERR ",('B'+$80)
MSG_JUMP_FAIL_VEC:      DB              " V=",('$'+$80)
                        IF              STR8_RAM_PROOF
MSG_COPY_FAIL_AT:       DB              $0D,$0A,"COPY FAIL @ ",('$'+$80)
                        ENDIF
MSG_CRLF:               DB              $0D,$8A

                        END

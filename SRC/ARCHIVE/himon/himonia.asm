; ----------------------------------------------------------------------------
; himonia.asm
; Compact supervisory debug monitor for W65C02S.
; Memory map target:
;   RAM   $0000-$7EFF (UPA $2000-$77FF, HIUPA $7800-$79FF)
;   IO    $7F00-$7FFF
;   FLASH $8000-$FFFF
; ----------------------------------------------------------------------------

                        MODULE          HIMONIA_APP

                        XDEF            START

                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            SYS_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_VEC_SET_NMI_XY
                        XREF            SYS_VEC_SET_IRQ_BRK_XY
                        XREF            BIO_FTDI_READ_BYTE_NONBLOCK

                        INCLUDE         "TEST/apps/himon/himon-shared-eq.inc"

TRAP_CAUSE               EQU             $7EEA
TRAP_BRK_SIG             EQU             $7EEB
TRAP_CAUSE_NONE          EQU             $00
TRAP_CAUSE_NMI           EQU             $01
TRAP_CAUSE_BRK           EQU             $02
CMD_FNV_SIG2             EQU             ('V'+$80)

                        CODE
START:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        LDA             RESET_SIG0
                        CMP             #$A5
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG1
                        CMP             #$5A
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG2
                        CMP             #$C3
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG3
                        CMP             #$3C
                        BNE             MON_COLD_RESET
                        STZ             NMI_CTX_FLAG
                        STZ             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        JMP             MON_START_INIT

MON_COLD_RESET:
                        JMP             MON_CLEAR_RAM

MON_REENTER:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS

MON_START_INIT:
                        LDA             #$A5
                        STA             RESET_SIG0
                        LDA             #$5A
                        STA             RESET_SIG1
                        LDA             #$C3
                        STA             RESET_SIG2
                        LDA             #$3C
                        STA             RESET_SIG3
                        JSR             SYS_INIT
                        JSR             SYS_FLUSH_RX

                        LDX             #<MON_NMI_TRAP
                        LDY             #>MON_NMI_TRAP
                        JSR             SYS_VEC_SET_NMI_XY
                        LDX             #<MON_BRK_TRAP
                        LDY             #>MON_BRK_TRAP
                        JSR             SYS_VEC_SET_IRQ_BRK_XY

                        LDX             #<MSG_BANNER
                        LDY             #>MSG_BANNER
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF

                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BNE             MAIN_LOOP
                        JSR             MON_PRINT_STOP_AND_REGS

MAIN_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             HIM_WRITE_HBSTRING

                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_ECHO_UPPER
                        BCC             MAIN_LOOP

                        STA             CMD_LEN
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MAIN_LOOP

                        CMP             #'?'
                        BNE             CMD_DISPATCH_NOT_HELP
                        JMP             CMD_HELP
CMD_DISPATCH_NOT_HELP:
                        CMP             #'M'
                        BNE             CMD_DISPATCH_NOT_M
                        JMP             CMD_M
CMD_DISPATCH_NOT_M:
                        CMP             #'D'
                        BNE             CMD_DISPATCH_NOT_D
                        JMP             CMD_D
CMD_DISPATCH_NOT_D:
                        CMP             #'U'
                        BNE             CMD_DISPATCH_NOT_U
                        JMP             CMD_U
CMD_DISPATCH_NOT_U:
                        CMP             #'R'
                        BNE             CMD_DISPATCH_NOT_R
                        JMP             CMD_R
CMD_DISPATCH_NOT_R:
                        CMP             #'X'
                        BNE             CMD_DISPATCH_NOT_X
                        JMP             CMD_X
CMD_DISPATCH_NOT_X:
                        CMP             #'G'
                        BNE             CMD_DISPATCH_NOT_G
                        JMP             CMD_G
CMD_DISPATCH_NOT_G:
                        CMP             #'L'
                        BNE             CMD_DISPATCH_NOT_L
                        JMP             CMD_L
CMD_DISPATCH_NOT_L:
                        CMP             #'Q'
                        BNE             CMD_DISPATCH_NOT_Q
                        JMP             CMD_Q
CMD_DISPATCH_NOT_Q:
                        CMP             #'B'
                        BNE             CMD_DISPATCH_NOT_B
                        JMP             CMD_B
CMD_DISPATCH_NOT_B:
                        CMP             #'S'
                        BNE             CMD_DISPATCH_NOT_S
                        JMP             CMD_S
CMD_DISPATCH_NOT_S:
                        CMP             #'A'
                        BNE             CMD_DISPATCH_NOT_A
                        JMP             CMD_A
CMD_DISPATCH_NOT_A:
                        BRA             CMD_UNKNOWN

CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

CMD_HELP:
                        LDX             #<MSG_HELP
                        LDY             #>MSG_HELP
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; D start [end|+len]
; ----------------------------------------------------------------------------
CMD_D:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_RANGE_REQUIRED
                        BCS             CMD_D_RANGE_OK
                        JMP             CMD_USAGE_D
CMD_D_RANGE_OK:
                        JSR             MON_PRINT_MEM_RANGE
                        JMP             MAIN_LOOP

CMD_USAGE_D:
                        LDX             #<MSG_USAGE_D
                        LDY             #>MSG_USAGE_D
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; M start [end|+len]
; ----------------------------------------------------------------------------
CMD_M:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_RANGE_REQUIRED
                        BCC             CMD_USAGE_M
                        JSR             MON_MODIFY_RANGE
                        JMP             MAIN_LOOP

CMD_USAGE_M:
                        LDX             #<MSG_USAGE_M
                        LDY             #>MSG_USAGE_M
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; R [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
; ----------------------------------------------------------------------------
CMD_R:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCS             CMD_R_HAVE_CTX
                        JMP             MAIN_LOOP
CMD_R_HAVE_CTX:
                        JSR             CMD_ADV_PTR
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             CMD_USAGE_R
                        JSR             MON_PRINT_STOP_AND_REGS
                        JMP             MAIN_LOOP

CMD_USAGE_R:
                        LDX             #<MSG_USAGE_R
                        LDY             #>MSG_USAGE_R
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; X [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
; ----------------------------------------------------------------------------
CMD_X:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCS             CMD_X_HAVE_CTX
                        JMP             MAIN_LOOP
CMD_X_HAVE_CTX:
                        JSR             CMD_ADV_PTR
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             CMD_USAGE_X
                        LDX             #<MSG_RESUME
                        LDY             #>MSG_RESUME
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_CTX_RESUME_RTI

CMD_USAGE_X:
                        LDX             #<MSG_USAGE_X
                        LDY             #>MSG_USAGE_X
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; G start
; ----------------------------------------------------------------------------
CMD_G:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_USAGE_G
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_G
                        LDX             #<MSG_GO
                        LDY             #>MSG_GO
                        JSR             HIM_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             (CMDP_ADDR_LO)

CMD_USAGE_G:
                        LDX             #<MSG_USAGE_G
                        LDY             #>MSG_USAGE_G
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; L  (S19-only loader: S1 data, S9 terminator; S0 skipped)
; ----------------------------------------------------------------------------
CMD_L:
                        JSR             CMD_ADV_PTR
                        STZ             LOAD_AUTO_GO
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_L_ARGS_OK
                        CMP             #'G'
                        BNE             CMD_USAGE_L_JMP
                        JSR             CMD_ADV_PTR
                        LDA             #$01
                        STA             LOAD_AUTO_GO
                        JSR             CMD_REQUIRE_EOL
                        BCS             CMD_L_ARGS_OK
CMD_USAGE_L_JMP:
                        JMP             CMD_USAGE_L
CMD_L_ARGS_OK:
                        STZ             LOAD_TOTAL_LO
                        STZ             LOAD_TOTAL_HI
                        STZ             LOAD_GO_VALID
                        STZ             LOAD_HAVE_DATA
                        STZ             LOAD_LAST_LO
                        STZ             LOAD_LAST_HI
                        LDX             #<MSG_L_READY
                        LDY             #>MSG_L_READY
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF

CMD_L_READ_LOOP:
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_UPPER
                        BCS             CMD_L_HAVE_LINE
                        STA             LOAD_LINE_STATUS
                        LDX             #<MSG_L_STATUS
                        LDY             #>MSG_L_STATUS
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        BRA             CMD_L_READ_LOOP

CMD_L_HAVE_LINE:
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_PEEK
                        BEQ             CMD_L_READ_LOOP
                        CMP             #'L'
                        BEQ             CMD_L_READ_LOOP

                        JSR             L_PARSE_RECORD
                        BCS             CMD_L_PARSE_OK
                        LDX             #<MSG_L_ERR
                        LDY             #>MSG_L_ERR
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        BRA             CMD_L_READ_LOOP

CMD_L_PARSE_OK:
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_TERM
                        BNE             CMD_L_READ_LOOP

                        LDA             LOAD_AUTO_GO
                        BEQ             CMD_L_PRINT_DONE
                        LDA             LOAD_GO_VALID
                        BEQ             CMD_L_GO_FALLBACK
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             CMD_L_PRINT_DONE
CMD_L_GO_FALLBACK:
                        LDA             LOAD_HAVE_DATA
                        BEQ             CMD_L_PRINT_DONE
                        LDA             LOAD_FIRST_LO
                        STA             LOAD_GO_LO
                        LDA             LOAD_FIRST_HI
                        STA             LOAD_GO_HI
                        LDA             #$01
                        STA             LOAD_GO_VALID

CMD_L_PRINT_DONE:
                        LDX             #<MSG_L_DONE
                        LDY             #>MSG_L_DONE
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_TOTAL_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_TOTAL_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_GO
                        LDY             #>MSG_L_GO
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_GO_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        LDA             LOAD_AUTO_GO
                        BEQ             CMD_L_MAIN
                        LDA             LOAD_GO_VALID
                        BEQ             CMD_L_MAIN
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BEQ             CMD_L_MAIN
                        JMP             (LOAD_GO_LO)
CMD_L_MAIN:
                        JMP             MAIN_LOOP

CMD_USAGE_L:
                        LDX             #<MSG_USAGE_L
                        LDY             #>MSG_USAGE_L
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

CMD_Q:
                        BRK             $65
                        JMP             MAIN_LOOP

                        INCLUDE         "TEST/apps/himon/himonia-debug.inc"
                        INCLUDE         "TEST/apps/himon/himonia-disasm.inc"
                        INCLUDE         "TEST/apps/himon/himonia-asm.inc"

; ----------------------------------------------------------------------------
; Trap handlers
; ----------------------------------------------------------------------------
MON_NMI_TRAP:
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        TSX
                        LDA             $0101,X
                        STA             NMI_CTX_P
                        LDA             $0102,X
                        STA             NMI_CTX_PCL
                        LDA             $0103,X
                        STA             NMI_CTX_PCH
                        TXA
                        CLC
                        ADC             #$03
                        STA             NMI_CTX_S
                        LDA             #$01
                        STA             NMI_CTX_FLAG
                        LDA             #TRAP_CAUSE_NMI
                        STA             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        JMP             MON_REENTER

MON_BRK_TRAP:
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        TSX
                        LDA             $0101,X
                        STA             NMI_CTX_P
                        LDA             $0102,X
                        STA             NMI_CTX_PCL
                        LDA             $0103,X
                        STA             NMI_CTX_PCH
                        TXA
                        CLC
                        ADC             #$03
                        STA             NMI_CTX_S
                        LDA             #$01
                        STA             NMI_CTX_FLAG
                        LDA             #TRAP_CAUSE_BRK
                        STA             TRAP_CAUSE

                        JSR             DBG_HANDLE_BRK
                        BCC             MON_BRK_TRAP_NORMAL
                        JMP             MON_REENTER

MON_BRK_TRAP_NORMAL:
                        LDA             NMI_CTX_PCL
                        SEC
                        SBC             #$01
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        SBC             #$00
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             TRAP_BRK_SIG
                        JMP             MON_REENTER

; ----------------------------------------------------------------------------
; Reset-time RAM clear
; ----------------------------------------------------------------------------
MON_CLEAR_RAM:
                        STZ             CMDP_PTR_LO
                        LDA             #$01
                        STA             CMDP_PTR_HI
                        LDY             #$00
                        LDA             #$00
MON_CLEAR_RAM_PAGE:
MON_CLEAR_RAM_BYTE:
                        STA             (CMDP_PTR_LO),Y
                        INY
                        BNE             MON_CLEAR_RAM_BYTE
                        INC             CMDP_PTR_HI
                        LDA             CMDP_PTR_HI
                        CMP             #$7F
                        BEQ             MON_CLEAR_RAM_ZP_BEGIN
                        LDA             #$00
                        BRA             MON_CLEAR_RAM_PAGE

MON_CLEAR_RAM_ZP_BEGIN:
                        LDX             #$00
MON_CLEAR_RAM_ZP:
                        STZ             $00,X
                        INX
                        BNE             MON_CLEAR_RAM_ZP
                        JMP             MON_START_INIT

; ----------------------------------------------------------------------------
; Tiny HIMONIA input
; ----------------------------------------------------------------------------
HIM_READ_LINE_ECHO_UPPER:
                        LDA             #$01
                        BRA             HIM_READ_LINE_SET_MODE
HIM_READ_LINE_UPPER:
                        LDA             #$00
HIM_READ_LINE_SET_MODE:
                        STA             CMD_IO_TMP
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        STZ             CMDP_REMAIN
HIM_READ_LINE_LOOP:
                        JSR             BIO_FTDI_READ_BYTE_BLOCK
                        CMP             #$03
                        BEQ             HIM_READ_LINE_ABORT
                        CMP             #$0D
                        BEQ             HIM_READ_LINE_DONE
                        CMP             #$0A
                        BEQ             HIM_READ_LINE_DONE
                        CMP             #$08
                        BEQ             HIM_READ_LINE_BACKSPACE
                        CMP             #$7F
                        BEQ             HIM_READ_LINE_BACKSPACE
                        JSR             HIM_CHAR_TO_UPPER
                        STA             CMDP_BYTE_TMP
                        LDA             CMDP_REMAIN
                        CMP             #$FF
                        BEQ             HIM_READ_LINE_LOOP
                        LDY             #$00
                        LDA             CMDP_BYTE_TMP
                        STA             (CMDP_PTR_LO),Y
                        JSR             CMD_ADV_PTR
                        INC             CMDP_REMAIN
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_LOOP
                        LDA             CMDP_BYTE_TMP
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        BRA             HIM_READ_LINE_LOOP

HIM_READ_LINE_BACKSPACE:
                        LDA             CMDP_REMAIN
                        BEQ             HIM_READ_LINE_LOOP
                        DEC             CMDP_REMAIN
                        LDA             CMDP_PTR_LO
                        BNE             HIM_READ_LINE_BS_DEC
                        DEC             CMDP_PTR_HI
HIM_READ_LINE_BS_DEC:
                        DEC             CMDP_PTR_LO
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_LOOP
                        LDA             #$08
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #$08
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        BRA             HIM_READ_LINE_LOOP

HIM_READ_LINE_DONE:
                        LDY             #$00
                        LDA             #$00
                        STA             (CMDP_PTR_LO),Y
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_DONE_STATUS
                        JSR             SYS_WRITE_CRLF
HIM_READ_LINE_DONE_STATUS:
                        LDA             CMDP_REMAIN
                        SEC
                        RTS

HIM_READ_LINE_ABORT:
                        JSR             SYS_WRITE_CRLF
                        LDA             #$03
                        CLC
                        RTS

HIM_CHAR_TO_UPPER:
                        CMP             #'a'
                        BCC             HIM_CHAR_TO_UPPER_DONE
                        CMP             #'z'+1
                        BCS             HIM_CHAR_TO_UPPER_DONE
                        SEC
                        SBC             #$20
HIM_CHAR_TO_UPPER_DONE:
                        RTS

HIM_WRITE_HBSTRING:
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        LDY             #$00
HIM_WRITE_HBSTRING_LOOP:
                        LDA             (CMDP_PTR_LO),Y
                        BMI             HIM_WRITE_HBSTRING_LAST
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INY
                        BNE             HIM_WRITE_HBSTRING_LOOP
                        INC             CMDP_PTR_HI
                        BRA             HIM_WRITE_HBSTRING_LOOP
HIM_WRITE_HBSTRING_LAST:
                        AND             #$7F
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

; ----------------------------------------------------------------------------
; Context helpers
; ----------------------------------------------------------------------------
MON_CTX_REQUIRE_VALID:
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BEQ             MON_CTX_REQUIRE_VALID_OK
                        LDX             #<MSG_NOCTX
                        LDY             #>MSG_NOCTX
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS
MON_CTX_REQUIRE_VALID_OK:
                        SEC
                        RTS

MON_CTX_PARSE_ASSIGN_LIST:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MON_CTX_PARSE_ASSIGN_LIST_DONE
MON_CTX_PARSE_ASSIGN_LOOP:
                        JSR             MON_CTX_PARSE_ASSIGN
                        BCC             MON_CTX_PARSE_ASSIGN_LIST_FAIL
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BNE             MON_CTX_PARSE_ASSIGN_LOOP
MON_CTX_PARSE_ASSIGN_LIST_DONE:
                        SEC
                        RTS
MON_CTX_PARSE_ASSIGN_LIST_FAIL:
                        CLC
                        RTS

MON_CTX_PARSE_ASSIGN:
                        JSR             CMD_PEEK
                        CMP             #'A'
                        BEQ             MON_CTX_PARSE_A
                        CMP             #'X'
                        BEQ             MON_CTX_PARSE_X
                        CMP             #'Y'
                        BEQ             MON_CTX_PARSE_Y
                        CMP             #'S'
                        BEQ             MON_CTX_PARSE_S
                        CMP             #'P'
                        BEQ             MON_CTX_PARSE_P_OR_PC
                        CLC
                        RTS

MON_CTX_PARSE_A:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_A
                        SEC
                        RTS

MON_CTX_PARSE_X:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_X
                        SEC
                        RTS

MON_CTX_PARSE_Y:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_Y
                        SEC
                        RTS

MON_CTX_PARSE_S:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_S
                        SEC
                        RTS

MON_CTX_PARSE_P_OR_PC:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        CMP             #'C'
                        BEQ             MON_CTX_PARSE_PC
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_P
                        SEC
                        RTS

MON_CTX_PARSE_PC:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             NMI_CTX_PCL
                        LDA             CMDP_ADDR_HI
                        STA             NMI_CTX_PCH
                        SEC
                        RTS

MON_CTX_PARSE_FAIL:
                        CLC
                        RTS

MON_PARSE_EQ:
                        JSR             CMD_PEEK
                        CMP             #'='
                        BNE             MON_PARSE_EQ_FAIL
                        JSR             CMD_ADV_PTR
                        SEC
                        RTS
MON_PARSE_EQ_FAIL:
                        CLC
                        RTS

MON_CTX_RESUME_RTI:
                        SEI
                        LDY             NMI_CTX_S
                        LDA             NMI_CTX_P
                        STA             $00FE,Y
                        LDA             NMI_CTX_PCL
                        STA             $00FF,Y
                        LDA             NMI_CTX_PCH
                        STA             $0100,Y

                        TYA
                        SEC
                        SBC             #$03
                        TAX
                        TXS

                        STZ             NMI_CTX_FLAG
                        LDA             NMI_CTX_A
                        LDX             NMI_CTX_X
                        LDY             NMI_CTX_Y
                        RTI

; ----------------------------------------------------------------------------
; Printing helpers
; ----------------------------------------------------------------------------
MON_PRINT_STOP_AND_REGS:
                        JSR             SYS_WRITE_CRLF
                        LDA             TRAP_CAUSE
                        CMP             #TRAP_CAUSE_BRK
                        BEQ             MON_PRINT_STOP_BRK
                        LDX             #<MSG_STOP_NMI
                        LDY             #>MSG_STOP_NMI
                        JSR             HIM_WRITE_HBSTRING
                        BRA             MON_PRINT_STOP_PC
MON_PRINT_STOP_BRK:
                        LDX             #<MSG_STOP_BRK
                        LDY             #>MSG_STOP_BRK
                        JSR             HIM_WRITE_HBSTRING
                        LDA             TRAP_BRK_SIG
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_STOP_PC
                        LDY             #>MSG_STOP_PC
                        JSR             HIM_WRITE_HBSTRING
MON_PRINT_STOP_PC:
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE

                        JSR             SYS_WRITE_CRLF
                        LDX             #<MSG_REG_A
                        LDY             #>MSG_REG_A
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_A
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_X
                        LDY             #>MSG_REG_X
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_X
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_Y
                        LDY             #>MSG_REG_Y
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_P
                        LDY             #>MSG_REG_P
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_P
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_S
                        LDY             #>MSG_REG_S
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_S
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        RTS

MON_PRINT_MEM_RANGE:
MON_PRINT_MEM_NEXT_LINE:
                        JSR             MON_CURR_GT_END
                        BCS             MON_PRINT_MEM_DONE
                        LDA             CMD_RANGE_TMP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK

                        STZ             CMD_PATTERN_COUNT
MON_PRINT_MEM_LINE_LOOP:
                        JSR             HIM_CHECK_CTRL_C
                        BCS             MON_PRINT_MEM_DONE
                        JSR             MON_CURR_GT_END
                        BCS             MON_PRINT_MEM_NEXT_LINE
                        LDA             CMD_PATTERN_COUNT
                        BEQ             MON_PRINT_MEM_SPACE
                        CMP             #$08
                        BNE             MON_PRINT_MEM_SPACE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
MON_PRINT_MEM_SPACE:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_HI
                        CMP             CMD_RANGE_END_HI
                        BNE             MON_PRINT_MEM_NOT_END
                        LDA             CMD_RANGE_TMP_LO
                        CMP             CMD_RANGE_END_LO
                        BEQ             MON_PRINT_MEM_DONE
MON_PRINT_MEM_NOT_END:
                        JSR             CMD_INC_RANGE_TMP
                        INC             CMD_PATTERN_COUNT
                        LDA             CMD_PATTERN_COUNT
                        CMP             #$10
                        BCC             MON_PRINT_MEM_LINE_LOOP
                        JSR             SYS_WRITE_CRLF
                        BRA             MON_PRINT_MEM_NEXT_LINE

MON_PRINT_MEM_DONE:
                        JSR             SYS_WRITE_CRLF
                        RTS

HIM_CHECK_CTRL_C:
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             HIM_CHECK_CTRL_C_NO
                        CMP             #$03
                        BEQ             HIM_CHECK_CTRL_C_YES
HIM_CHECK_CTRL_C_NO:
                        CLC
                        RTS
HIM_CHECK_CTRL_C_YES:
                        SEC
                        RTS

MON_MODIFY_RANGE:
                        STZ             CMD_PATTERN_COUNT
MON_MODIFY_LOOP:
                        JSR             MON_CURR_GT_END
                        BCS             MON_MODIFY_DONE
                        LDA             CMD_RANGE_TMP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK

                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_ECHO_UPPER
                        BCC             MON_MODIFY_ABORT
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MON_MODIFY_NEXT
                        CMP             #'.'
                        BEQ             MON_MODIFY_ABORT
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_MODIFY_BAD
                        STA             CMD_IO_TMP
                        JSR             CMD_REQUIRE_EOL
                        BCC             MON_MODIFY_BAD
                        LDY             #$00
                        LDA             CMD_IO_TMP
                        STA             (CMDP_START_LO),Y
                        INC             CMD_PATTERN_COUNT
MON_MODIFY_NEXT:
                        JSR             CMD_INC_RANGE_TMP
                        BRA             MON_MODIFY_LOOP

MON_MODIFY_BAD:
                        LDX             #<MSG_USAGE_M
                        LDY             #>MSG_USAGE_M
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        BRA             MON_MODIFY_LOOP

MON_MODIFY_ABORT:
                        RTS

MON_MODIFY_DONE:
                        RTS

MON_CURR_GT_END:
                        LDA             CMD_RANGE_TMP_HI
                        CMP             CMD_RANGE_END_HI
                        BCC             MON_CURR_GT_END_NO
                        BNE             MON_CURR_GT_END_YES
                        LDA             CMD_RANGE_TMP_LO
                        CMP             CMD_RANGE_END_LO
                        BCC             MON_CURR_GT_END_NO
                        BEQ             MON_CURR_GT_END_NO
MON_CURR_GT_END_YES:
                        SEC
                        RTS
MON_CURR_GT_END_NO:
                        CLC
                        RTS

CMD_INC_RANGE_TMP:
                        INC             CMD_RANGE_TMP_LO
                        BNE             CMD_INC_RANGE_TMP_DONE
                        INC             CMD_RANGE_TMP_HI
CMD_INC_RANGE_TMP_DONE:
                        INC             CMDP_START_LO
                        BNE             CMD_INC_RANGE_PTR_DONE
                        INC             CMDP_START_HI
CMD_INC_RANGE_PTR_DONE:
                        RTS

CMD_PARSE_RANGE_REQUIRED:
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_PARSE_RANGE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        STA             CMD_RANGE_TMP_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_TMP_HI
                        STA             CMDP_START_HI

                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_PARSE_RANGE_DEFAULT_END
                        CMP             #'+'
                        BEQ             CMD_PARSE_RANGE_PLUS

                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_PARSE_RANGE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_END_HI
                        BRA             CMD_PARSE_RANGE_HAVE_END

CMD_PARSE_RANGE_PLUS:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_PARSE_RANGE_FAIL
                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             CMDP_ADDR_HI
                        STA             CMD_RANGE_END_HI
                        BRA             CMD_PARSE_RANGE_HAVE_END

CMD_PARSE_RANGE_DEFAULT_END:
                        LDA             CMD_RANGE_START_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_END_HI

CMD_PARSE_RANGE_HAVE_END:
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_PARSE_RANGE_FAIL
                        LDA             CMD_RANGE_END_HI
                        CMP             CMD_RANGE_START_HI
                        BCC             CMD_PARSE_RANGE_FAIL
                        BNE             CMD_PARSE_RANGE_OK
                        LDA             CMD_RANGE_END_LO
                        CMP             CMD_RANGE_START_LO
                        BCC             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_OK:
                        SEC
                        RTS
CMD_PARSE_RANGE_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; S19 parser helpers (L command)
; ----------------------------------------------------------------------------
L_PARSE_RECORD:
                        STZ             LOAD_REC_KIND
                        JSR             CMD_PEEK
                        CMP             #'S'
                        BNE             L_PARSE_RECORD_FAIL
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        CMP             #'1'
                        BEQ             L_PARSE_RECORD_S1
                        CMP             #'9'
                        BEQ             L_PARSE_RECORD_S9
                        CMP             #'0'
                        BEQ             L_PARSE_RECORD_S0
                        BRA             L_PARSE_RECORD_FAIL
L_PARSE_RECORD_S1:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S1
                        RTS
L_PARSE_RECORD_S9:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S9
                        RTS
L_PARSE_RECORD_S0:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S0
                        RTS
L_PARSE_RECORD_FAIL:
                        CLC
                        RTS

L_PARSE_S0:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C1:
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C2:
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        SEC
                        SBC             #$03
                        BCS             L_PARSE_S0_HAVE_DLEN
                        JMP             L_PARSE_FAIL
L_PARSE_S0_HAVE_DLEN:
                        STA             LOAD_DATA_LEN
L_PARSE_S0_SKIP:
                        LDA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S0_CHK
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_D0
                        JMP             L_PARSE_FAIL
L_PARSE_S0_D0:
                        JSR             L_SUM_ADD_A
                        DEC             LOAD_DATA_LEN
                        BRA             L_PARSE_S0_SKIP
L_PARSE_S0_CHK:
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S0_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S0_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S0_OK:
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_PARSE_S1:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C1:
                        STA             LOAD_DST_HI
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C2:
                        STA             LOAD_DST_LO
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        SEC
                        SBC             #$03
                        BCS             L_PARSE_S1_HAVE_DLEN
                        JMP             L_PARSE_FAIL
L_PARSE_S1_HAVE_DLEN:
                        STA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S1_DATA
                        JSR             L_NOTE_S1_ADDR
L_PARSE_S1_DATA:
                        LDA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S1_CHK
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_D0
                        JMP             L_PARSE_FAIL
L_PARSE_S1_D0:
                        STA             CMD_IO_TMP
                        JSR             L_SUM_ADD_A
                        LDA             LOAD_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             CMD_IO_TMP
                        STA             (CMDP_ADDR_LO),Y
                        INC             LOAD_DST_LO
                        BNE             L_PARSE_S1_NEXT
                        INC             LOAD_DST_HI
L_PARSE_S1_NEXT:
                        INC             LOAD_TOTAL_LO
                        BNE             L_PARSE_S1_NEXT2
                        INC             LOAD_TOTAL_HI
L_PARSE_S1_NEXT2:
                        DEC             LOAD_DATA_LEN
                        BRA             L_PARSE_S1_DATA
L_PARSE_S1_CHK:
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S1_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S1_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S1_OK:
                        LDA             LOAD_DST_LO
                        STA             LOAD_LAST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_LAST_HI
                        LDA             #LOAD_REC_KIND_DATA
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_NOTE_S1_ADDR:
                        LDA             LOAD_HAVE_DATA
                        BNE             L_NOTE_S1_ADDR_HAVE_DATA
                        LDA             #$01
                        STA             LOAD_HAVE_DATA
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI
                        BRA             L_NOTE_S1_ADDR_PRINT

L_NOTE_S1_ADDR_HAVE_DATA:
                        LDA             LOAD_DST_HI
                        CMP             LOAD_LAST_HI
                        BNE             L_NOTE_S1_ADDR_PRINT
                        LDA             LOAD_DST_LO
                        CMP             LOAD_LAST_LO
                        BEQ             L_NOTE_S1_ADDR_DONE
L_NOTE_S1_ADDR_PRINT:
                        LDA             #'L'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'@'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             LOAD_DST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_DST_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
L_NOTE_S1_ADDR_DONE:
                        RTS

L_PARSE_S9:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C1:
                        STA             LOAD_GO_HI
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C2:
                        STA             LOAD_GO_LO
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        CMP             #$03
                        BNE             L_PARSE_FAIL

                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S9_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S9_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S9_OK:
                        LDA             #$01
                        STA             LOAD_GO_VALID
                        LDA             #LOAD_REC_KIND_TERM
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_SUM_ADD_A:
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        RTS

L_VERIFY_CHECKSUM_EOL:
                        LDA             LOAD_SUM
                        EOR             #$FF
                        CMP             LOAD_CHK
                        BNE             L_VERIFY_CHECKSUM_EOL_FAIL
                        JSR             CMD_PEEK
                        BEQ             L_VERIFY_CHECKSUM_EOL_OK
L_VERIFY_CHECKSUM_EOL_FAIL:
                        CLC
                        RTS
L_VERIFY_CHECKSUM_EOL_OK:
                        SEC
                        RTS

L_PARSE_HEX_BYTE_STRICT:
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             L_PARSE_HEX_BYTE_STRICT_FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             CMDP_NIB_HI
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             L_PARSE_HEX_BYTE_STRICT_FAIL
                        ORA             CMDP_NIB_HI
                        JSR             CMD_ADV_PTR
                        SEC
                        RTS
L_PARSE_HEX_BYTE_STRICT_FAIL:
                        CLC
                        RTS

L_PARSE_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Scanner / parser helpers
; ----------------------------------------------------------------------------
CMD_REQUIRE_EOL:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_REQUIRE_EOL_OK
                        CLC
                        RTS
CMD_REQUIRE_EOL_OK:
                        SEC
                        RTS

CMD_SKIP_SPACES:
                        JSR             CMD_PEEK
                        CMP             #' '
                        BEQ             CMD_SKIP_SPACES_ADV
                        CMP             #$09
                        BEQ             CMD_SKIP_SPACES_ADV
                        RTS
CMD_SKIP_SPACES_ADV:
                        JSR             CMD_ADV_PTR
                        BRA             CMD_SKIP_SPACES

CMD_PEEK:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        RTS

CMD_ADV_PTR:
                        INC             CMDP_PTR_LO
                        BNE             CMD_ADV_PTR_DONE
                        INC             CMDP_PTR_HI
CMD_ADV_PTR_DONE:
                        RTS

CMD_PARSE_HEX_WORD_TOKEN:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_SKIP_OPTIONAL_DOLLAR
                        STZ             CMDP_ADDR_HI
                        STZ             CMDP_ADDR_LO
                        STZ             CMDP_TOKEN_LEN
CMD_PARSE_HEX_WORD_LOOP:
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             CMD_PARSE_HEX_WORD_DONE
                        STA             CMDP_NIB_HI
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$04
                        BCS             CMD_PARSE_HEX_WORD_FAIL
                        INC             CMDP_TOKEN_LEN

                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI

                        LDA             CMDP_ADDR_LO
                        ORA             CMDP_NIB_HI
                        STA             CMDP_ADDR_LO
                        JSR             CMD_ADV_PTR
                        BRA             CMD_PARSE_HEX_WORD_LOOP
CMD_PARSE_HEX_WORD_DONE:
                        LDA             CMDP_TOKEN_LEN
                        BEQ             CMD_PARSE_HEX_WORD_FAIL
                        JSR             CMD_PEEK
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCC             CMD_PARSE_HEX_WORD_FAIL
                        SEC
                        RTS
CMD_PARSE_HEX_WORD_FAIL:
                        CLC
                        RTS

CMD_PARSE_HEX_BYTE_TOKEN:
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_PARSE_HEX_BYTE_TOKEN_FAIL
                        LDA             CMDP_ADDR_HI
                        BNE             CMD_PARSE_HEX_BYTE_TOKEN_FAIL
                        LDA             CMDP_ADDR_LO
                        SEC
                        RTS
CMD_PARSE_HEX_BYTE_TOKEN_FAIL:
                        CLC
                        RTS

CMD_SKIP_OPTIONAL_DOLLAR:
                        JSR             CMD_PEEK
                        CMP             #'$'
                        BNE             CMD_SKIP_OPTIONAL_DOLLAR_DONE
                        JSR             CMD_ADV_PTR
CMD_SKIP_OPTIONAL_DOLLAR_DONE:
                        RTS

CMD_IS_DELIM_OR_NUL:
                        CMP             #$00
                        BEQ             CMD_IS_DELIM_TRUE
                        CMP             #' '
                        BEQ             CMD_IS_DELIM_TRUE
                        CMP             #$09
                        BEQ             CMD_IS_DELIM_TRUE
                        CLC
                        RTS
CMD_IS_DELIM_TRUE:
                        SEC
                        RTS

CMD_HEX_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             CMD_HXN_BAD
                        CMP             #':'
                        BCC             CMD_HXN_DIGIT
                        CMP             #'A'
                        BCC             CMD_HXN_CHECK_LOWER
                        CMP             #'G'
                        BCC             CMD_HXN_UPPER
CMD_HXN_CHECK_LOWER:
                        CMP             #'a'
                        BCC             CMD_HXN_BAD
                        CMP             #'g'
                        BCS             CMD_HXN_BAD
                        SEC
                        SBC             #$57
                        SEC
                        RTS
CMD_HXN_UPPER:
                        SEC
                        SBC             #$37
                        SEC
                        RTS
CMD_HXN_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
CMD_HXN_BAD:
                        CLC
                        RTS

                        DATA
MSG_BANNER:              DB              $0D,$0A,"HIMONIA v",$B1
MSG_PROMPT:              DB              $BE
MSG_UNKNOWN:             DB              $BF
MSG_HELP:                DB              "? D M U R X G L B S A ",$D1
MSG_USAGE_D:             DB              "D start [end|+n]",$DD
MSG_USAGE_M:             DB              "M start [end|+n]",$AE
MSG_USAGE_R:             DB              "R reg",$F3
MSG_USAGE_X:             DB              "X reg",$F3
MSG_USAGE_G:             DB              "G ",$E1
MSG_USAGE_L:             DB              "L[G]",$A0
MSG_NOCTX:               DB              "NOCT",$D8
MSG_RESUME:              DB              "RESUME",$A0
MSG_GO:                  DB              "GO",$A0
MSG_L_READY:             DB              "L S1",$B9
MSG_L_STATUS:            DB              "L",$D3
MSG_L_ERR:               DB              "LER",$D2
MSG_L_DONE:              DB              "L OK",$BD
MSG_L_GO:                DB              " GO",$BD
MSG_STOP_NMI:            DB              "NMI PC",$BD
MSG_STOP_BRK:            DB              "BRK",$A0
MSG_STOP_PC:             DB              " PC",$BD
MSG_REG_A:               DB              "A",$BD
MSG_REG_X:               DB              " X",$BD
MSG_REG_Y:               DB              " Y",$BD
MSG_REG_P:               DB              " P",$BD
MSG_REG_S:               DB              " S",$BD
MSG_USAGE_B:             DB              "B start",$DD
MSG_USAGE_BC:            DB              "BC start",$DD
MSG_USAGE_BL:            DB              "B",$CC
MSG_USAGE_S:             DB              $D3
MSG_USAGE_U:             DB              "U start [end|+n]",$DD
MSG_USAGE_A:             DB              "A start [mne op]",$DD
MSG_BP_SET:              DB              "BP ",$A4
MSG_BP_CLR:              DB              "BC ",$A4
MSG_STEP:                DB              "STEP PC",$BD
MSG_STEP_OP:             DB              " OP",$BD
MSG_STEP_LEN:            DB              " LEN",$BD
MSG_STEP_NEXT:           DB              " NEXT",$BD
MSG_STEP_BP:             DB              " B",$D0
MSG_DIS_DB:              DB              ".DB ",$A4

ASM_MNEM_NAMES:
                        DB              "BRK",$00,"ORA",$00,"TSB",$00,"ASL",$00
                        DB              "RMB0","PHP",$00,"BBR0","BPL",$00
                        DB              "TRB",$00,"RMB1","CLC",$00,"INC",$00
                        DB              "BBR1","JSR",$00,"AND",$00,"BIT",$00
                        DB              "ROL",$00,"RMB2","PLP",$00,"BBR2"
                        DB              "BMI",$00,"RMB3","SEC",$00,"DEC",$00
                        DB              "BBR3","RTI",$00,"EOR",$00,"LSR",$00
                        DB              "RMB4","PHA",$00,"JMP",$00,"BBR4"
                        DB              "BVC",$00,"RMB5","CLI",$00,"PHY",$00
                        DB              "BBR5","RTS",$00,"ADC",$00,"STZ",$00
                        DB              "ROR",$00,"RMB6","PLA",$00,"BBR6"
                        DB              "BVS",$00,"RMB7","SEI",$00,"PLY",$00
                        DB              "BBR7","BRA",$00,"STA",$00,"STY",$00
                        DB              "STX",$00,"SMB0","DEY",$00,"TXA",$00
                        DB              "BBS0","BCC",$00,"SMB1","TYA",$00
                        DB              "TXS",$00,"BBS1","LDY",$00,"LDA",$00
                        DB              "LDX",$00,"SMB2","TAY",$00,"TAX",$00
                        DB              "BBS2","BCS",$00,"SMB3","CLV",$00
                        DB              "TSX",$00,"BBS3","CPY",$00,"CMP",$00
                        DB              "SMB4","INY",$00,"DEX",$00,"WAI",$00
                        DB              "BBS4","BNE",$00,"SMB5","CLD",$00
                        DB              "PHX",$00,"STP",$00,"BBS5","CPX",$00
                        DB              "SBC",$00,"SMB6","INX",$00,"NOP",$00
                        DB              "BBS6","BEQ",$00,"SMB7","SED",$00
                        DB              "PLX",$00,"BBS7"

ASM_OP_MNEM_ID:
                        DB              $01,$02,$00,$00,$03,$02,$04,$05
                        DB              $06,$02,$04,$00,$03,$02,$04,$07
                        DB              $08,$02,$02,$00,$09,$02,$04,$0A
                        DB              $0B,$02,$0C,$00,$09,$02,$04,$0D
                        DB              $0E,$0F,$00,$00,$10,$0F,$11,$12
                        DB              $13,$0F,$11,$00,$10,$0F,$11,$14
                        DB              $15,$0F,$0F,$00,$10,$0F,$11,$16
                        DB              $17,$0F,$18,$00,$10,$0F,$11,$19
                        DB              $1A,$1B,$00,$00,$00,$1B,$1C,$1D
                        DB              $1E,$1B,$1C,$00,$1F,$1B,$1C,$20
                        DB              $21,$1B,$1B,$00,$00,$1B,$1C,$22
                        DB              $23,$1B,$24,$00,$00,$1B,$1C,$25
                        DB              $26,$27,$00,$00,$28,$27,$29,$2A
                        DB              $2B,$27,$29,$00,$1F,$27,$29,$2C
                        DB              $2D,$27,$27,$00,$28,$27,$29,$2E
                        DB              $2F,$27,$30,$00,$1F,$27,$29,$31
                        DB              $32,$33,$00,$00,$34,$33,$35,$36
                        DB              $37,$10,$38,$00,$34,$33,$35,$39
                        DB              $3A,$33,$33,$00,$34,$33,$35,$3B
                        DB              $3C,$33,$3D,$00,$28,$33,$28,$3E
                        DB              $3F,$40,$41,$00,$3F,$40,$41,$42
                        DB              $43,$40,$44,$00,$3F,$40,$41,$45
                        DB              $46,$40,$40,$00,$3F,$40,$41,$47
                        DB              $48,$40,$49,$00,$3F,$40,$41,$4A
                        DB              $4B,$4C,$00,$00,$4B,$4C,$18,$4D
                        DB              $4E,$4C,$4F,$50,$4B,$4C,$18,$51
                        DB              $52,$4C,$4C,$00,$00,$4C,$18,$53
                        DB              $54,$4C,$55,$56,$00,$4C,$18,$57
                        DB              $58,$59,$00,$00,$58,$59,$0C,$5A
                        DB              $5B,$59,$5C,$00,$58,$59,$0C,$5D
                        DB              $5E,$59,$59,$00,$00,$59,$0C,$5F
                        DB              $60,$59,$61,$00,$00,$59,$0C,$62

ASM_OP_MODE:
                        DB              $11,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$02,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$04,$05,$05,$04
                        DB              $01,$0C,$02,$00,$0A,$0B,$0B,$10
                        DB              $0A,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$02,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$05,$05,$05,$04
                        DB              $01,$0C,$02,$00,$0B,$0B,$0B,$10
                        DB              $01,$07,$00,$00,$00,$04,$04,$04
                        DB              $01,$03,$02,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$00,$05,$05,$04
                        DB              $01,$0C,$01,$00,$00,$0B,$0B,$10
                        DB              $01,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$02,$00,$0D,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$05,$05,$05,$04
                        DB              $01,$0C,$01,$00,$0E,$0B,$0B,$10
                        DB              $0F,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$01,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$05,$05,$06,$04
                        DB              $01,$0C,$01,$00,$0A,$0B,$0B,$10
                        DB              $03,$07,$03,$00,$04,$04,$04,$04
                        DB              $01,$03,$01,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$05,$05,$06,$04
                        DB              $01,$0C,$01,$00,$0B,$0B,$0C,$10
                        DB              $03,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$01,$01,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$00,$05,$05,$04
                        DB              $01,$0C,$01,$01,$00,$0B,$0B,$10
                        DB              $03,$07,$00,$00,$04,$04,$04,$04
                        DB              $01,$03,$01,$00,$0A,$0A,$0A,$10
                        DB              $0F,$09,$08,$00,$00,$05,$05,$04
                        DB              $01,$0C,$01,$00,$00,$0B,$0B,$10

                        ENDMOD

                        END

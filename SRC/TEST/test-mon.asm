; ----------------------------------------------------------------------------
; test-mon:
; - Standalone monitor-load test image.
; - Built by `make test-mon` and linked at $5000.
; - Shows live up/down counters until a key arrives.
; - Ctrl-C exits through R-YORS call `brk $65`.
; ----------------------------------------------------------------------------

                        MODULE          TEST_MON_APP

                        XDEF            START

                        XREF            SYS_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_POLL_CHAR
                        XREF            SYS_READ_CHAR
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            UTL_DELAY_AXY_8MHZ

                        INCLUDE         "TEST/LIB/test-mon-eq.inc"

                        CODE
START:
                        JSR             SYS_INIT
                        JSR             SYS_FLUSH_RX

                        LDX             #<MSG_HDR_1
                        LDY             #>MSG_HDR_1
                        JSR             TMON_PRINT_LINE_XY
                        LDX             #<MSG_HDR_2
                        LDY             #>MSG_HDR_2
                        JSR             TMON_PRINT_LINE_XY
                        LDX             #<MSG_HDR_3
                        LDY             #>MSG_HDR_3
                        JSR             TMON_PRINT_LINE_XY

                        STZ             TMON_UP_START_LO
                        STZ             TMON_UP_START_HI
                        STZ             TMON_UP_LO
                        STZ             TMON_UP_HI
                        STZ             TMON_LAST_KEY_UP_LO
                        STZ             TMON_LAST_KEY_UP_HI
                        STZ             TMON_KEY_SPIN_LO
                        STZ             TMON_KEY_SPIN_HI
                        LDA             #$FF
                        STA             TMON_DOWN_START_LO
                        STA             TMON_DOWN_START_HI
                        STA             TMON_DOWN_LO
                        STA             TMON_DOWN_HI

TMON_LOOP:
                        JSR             TMON_TICK
                        JSR             TMON_MAYBE_PRINT_LIVE

                        JSR             SYS_POLL_CHAR
                        BCC             TMON_LOOP

                        JSR             SYS_READ_CHAR
                        STA             TMON_KEY
                        JSR             SYS_WRITE_CRLF
                        JSR             TMON_CAPTURE_KEY_SPINS
                        LDX             #<MSG_KEY
                        LDY             #>MSG_KEY
                        JSR             TMON_PRINT_XY
                        LDA             TMON_KEY
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             TMON_PRINT_KEY_CLASS
                        LDX             #<MSG_KEY_SPINS
                        LDY             #>MSG_KEY_SPINS
                        JSR             TMON_PRINT_XY
                        LDA             TMON_KEY_SPIN_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             TMON_KEY_SPIN_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDA             TMON_KEY
                        CMP             #TMON_CH_CTRL_C
                        BEQ             TMON_KEY_IS_CTRL_C
                        JMP             TMON_LOOP

TMON_KEY_IS_CTRL_C:
                        LDX             #<MSG_EXIT
                        LDY             #>MSG_EXIT
                        JSR             TMON_PRINT_LINE_XY
                        BRK             TMON_BRK_EXIT_CODE
                        RTS

TMON_TICK:
                        LDA             #TMON_SPIN_DELAY_A
                        LDX             #TMON_SPIN_DELAY_X
                        LDY             #TMON_SPIN_DELAY_Y
                        JSR             UTL_DELAY_AXY_8MHZ

                        INC             TMON_UP_LO
                        BNE             TMON_UP_OK
                        INC             TMON_UP_HI
TMON_UP_OK:
                        LDA             TMON_DOWN_LO
                        BNE             TMON_DOWN_DEC
                        DEC             TMON_DOWN_HI
TMON_DOWN_DEC:
                        DEC             TMON_DOWN_LO
                        RTS

TMON_MAYBE_PRINT_LIVE:
                        ; Print live status every $0400 spins (10-bit cadence)
                        ; so serial output does not dominate spin timing.
                        LDA             TMON_UP_LO
                        BNE             TMON_LIVE_DONE
                        LDA             TMON_UP_HI
                        AND             #TMON_LIVE_CADENCE_MASK
                        BNE             TMON_LIVE_DONE

                        LDA             #TMON_CH_CR
                        JSR             SYS_WRITE_CHAR
                        LDX             #<MSG_RT_UP
                        LDY             #>MSG_RT_UP
                        JSR             TMON_PRINT_XY
                        LDA             TMON_UP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             TMON_UP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_RT_DOWN
                        LDY             #>MSG_RT_DOWN
                        JSR             TMON_PRINT_XY
                        LDA             TMON_DOWN_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             TMON_DOWN_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_RT_TAIL
                        LDY             #>MSG_RT_TAIL
                        JSR             TMON_PRINT_XY
TMON_LIVE_DONE:
                        RTS

TMON_CAPTURE_KEY_SPINS:
                        ; elapsed spins since previous key event:
                        ; key_spins = up - last_key_up; then latch current up.
                        LDA             TMON_UP_LO
                        SEC
                        SBC             TMON_LAST_KEY_UP_LO
                        STA             TMON_KEY_SPIN_LO
                        LDA             TMON_UP_HI
                        SBC             TMON_LAST_KEY_UP_HI
                        STA             TMON_KEY_SPIN_HI

                        LDA             TMON_UP_LO
                        STA             TMON_LAST_KEY_UP_LO
                        LDA             TMON_UP_HI
                        STA             TMON_LAST_KEY_UP_HI
                        RTS

TMON_PRINT_KEY_CLASS:
                        LDA             TMON_KEY
                        CMP             #TMON_CH_CR
                        BEQ             TMON_KEY_CR
                        CMP             #TMON_CH_LF
                        BEQ             TMON_KEY_LF
                        CMP             #TMON_CH_BS
                        BEQ             TMON_KEY_BS
                        CMP             #TMON_CH_DEL
                        BEQ             TMON_KEY_DEL
                        CMP             #TMON_CH_ESC
                        BEQ             TMON_KEY_ESC

                        CMP             #TMON_ASCII_SPACE
                        BCC             TMON_KEY_CTRL
                        CMP             #TMON_CH_DEL
                        BCS             TMON_KEY_EXT

                        ; printable ASCII
                        LDX             #<MSG_KEY_ASCII
                        LDY             #>MSG_KEY_ASCII
                        JSR             TMON_PRINT_XY
                        LDA             TMON_KEY
                        JSR             SYS_WRITE_CHAR
                        LDA             #$27                    ; '
                        JSR             SYS_WRITE_CHAR
                        RTS

TMON_KEY_CR:
                        LDX             #<MSG_KEY_CR
                        LDY             #>MSG_KEY_CR
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_LF:
                        LDX             #<MSG_KEY_LF
                        LDY             #>MSG_KEY_LF
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_BS:
                        LDX             #<MSG_KEY_BS
                        LDY             #>MSG_KEY_BS
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_DEL:
                        LDX             #<MSG_KEY_DEL
                        LDY             #>MSG_KEY_DEL
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_ESC:
                        LDX             #<MSG_KEY_ESC
                        LDY             #>MSG_KEY_ESC
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_CTRL:
                        LDX             #<MSG_KEY_CTRL
                        LDY             #>MSG_KEY_CTRL
                        JSR             TMON_PRINT_XY
                        RTS

TMON_KEY_EXT:
                        LDX             #<MSG_KEY_EXT
                        LDY             #>MSG_KEY_EXT
                        JSR             TMON_PRINT_XY
                        RTS


TMON_PRINT_XY:
                        JSR             SYS_WRITE_CSTRING
                        RTS

TMON_PRINT_LINE_XY:
                        JSR             SYS_WRITE_CSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

                        DATA
MSG_HDR_1: DB $0D,$0A,"R-YORS test-mon load demo",$00
MSG_HDR_2:              DB              "linked for GO @ $5000",$00
MSG_HDR_3:              DB              "Ctrl-C exits via brk $65",$00
MSG_RT_UP:              DB              "spinning up=$",$00
MSG_RT_DOWN:            DB              " down=$",$00
MSG_RT_TAIL:            DB              "  (press key)",$00
MSG_KEY:                DB              "key=$",$00
MSG_KEY_ASCII:          DB              " ascii='",$00
MSG_KEY_CR:             DB              " <CR>",$00
MSG_KEY_LF:             DB              " <LF>",$00
MSG_KEY_BS:             DB              " <BS>",$00
MSG_KEY_DEL:            DB              " <DEL>",$00
MSG_KEY_ESC:            DB              " <ESC>",$00
MSG_KEY_CTRL:           DB              " <CTRL>",$00
MSG_KEY_EXT:            DB              " <EXT>",$00
MSG_KEY_SPINS:          DB              " elapsed-spins=$",$00
MSG_EXIT:               DB              "Ctrl-C received: brk $65",$00

; ----------------------------------------------------------------------------
; Reserved vector trampoline slots (placeholders only, no code yet).
; Layout intent:
;   RESET
;   NMI
;   IRQ master dispatch
;   IRQ BRK path
;   IRQ non-BRK path
; Each slot is 3 bytes to match a future `JMP $xxxx` trampoline footprint.
; ----------------------------------------------------------------------------
TMON_VEC_TRAMP_RESET:        DB              $00,$00,$00
TMON_VEC_TRAMP_NMI:          DB              $00,$00,$00
TMON_VEC_TRAMP_IRQ_MASTER:   DB              $00,$00,$00
TMON_VEC_TRAMP_IRQ_BRK:      DB              $00,$00,$00
TMON_VEC_TRAMP_IRQ_NOTBRK:   DB              $00,$00,$00

                        ENDMOD

                        END


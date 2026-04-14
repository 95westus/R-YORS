; ----------------------------------------------------------------------------
; test-mon:
; - Standalone monitor-load test image.
; - Built by `make test-mon` and linked at $5000.
; - Shows live up/down counters until a key arrives.
; - Ctrl-C exits through R-YORS call `brk $65`.
; ----------------------------------------------------------------------------

                        MODULE          TEST_MON_APP

                        XDEF            START

                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            UTL_DELAY_AXY_8MHZ

TMON_UP_LO              EQU             $7B60
TMON_UP_HI              EQU             $7B61
TMON_DOWN_LO            EQU             $7B62
TMON_DOWN_HI            EQU             $7B63
TMON_KEY                EQU             $7B64
TMON_UP_DELTA_LO        EQU             $7B65
TMON_UP_DELTA_HI        EQU             $7B66
TMON_DOWN_DELTA_LO      EQU             $7B67
TMON_DOWN_DELTA_HI      EQU             $7B68
TMON_UP_START_LO        EQU             $7B69
TMON_UP_START_HI        EQU             $7B6A
TMON_DOWN_START_LO      EQU             $7B6B
TMON_DOWN_START_HI      EQU             $7B6C
TMON_LAST_KEY_UP_LO     EQU             $7B6D
TMON_LAST_KEY_UP_HI     EQU             $7B6E
TMON_KEY_SPIN_LO        EQU             $7B6F
TMON_KEY_SPIN_HI        EQU             $7B70

TMON_SPIN_DELAY_A       EQU             $01
TMON_SPIN_DELAY_X       EQU             $01
TMON_SPIN_DELAY_Y       EQU             $E1                    ; ~10.0 s per 65536 spins (with current loop overhead)

                        CODE
START:
                        jsr             COR_FTDI_INIT
                        jsr             COR_FTDI_FLUSH_RX

                        ldx             #<MSG_HDR_1
                        ldy             #>MSG_HDR_1
                        jsr             TMON_PRINT_LINE_XY
                        ldx             #<MSG_HDR_2
                        ldy             #>MSG_HDR_2
                        jsr             TMON_PRINT_LINE_XY
                        ldx             #<MSG_HDR_3
                        ldy             #>MSG_HDR_3
                        jsr             TMON_PRINT_LINE_XY

                        stz             TMON_UP_START_LO
                        stz             TMON_UP_START_HI
                        stz             TMON_UP_LO
                        stz             TMON_UP_HI
                        stz             TMON_LAST_KEY_UP_LO
                        stz             TMON_LAST_KEY_UP_HI
                        stz             TMON_KEY_SPIN_LO
                        stz             TMON_KEY_SPIN_HI
                        lda             #$FF
                        sta             TMON_DOWN_START_LO
                        sta             TMON_DOWN_START_HI
                        sta             TMON_DOWN_LO
                        sta             TMON_DOWN_HI

TMON_LOOP:
                        jsr             TMON_TICK
                        jsr             TMON_MAYBE_PRINT_LIVE

                        jsr             COR_FTDI_POLL_CHAR
                        bcc             TMON_LOOP

                        jsr             COR_FTDI_READ_CHAR
                        sta             TMON_KEY
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             TMON_CAPTURE_KEY_SPINS
                        ldx             #<MSG_KEY
                        ldy             #>MSG_KEY
                        jsr             TMON_PRINT_XY
                        lda             TMON_KEY
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             TMON_PRINT_KEY_CLASS
                        ldx             #<MSG_KEY_SPINS
                        ldy             #>MSG_KEY_SPINS
                        jsr             TMON_PRINT_XY
                        lda             TMON_KEY_SPIN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             TMON_KEY_SPIN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             TMON_KEY
                        cmp             #$03
                        beq             TMON_KEY_IS_CTRL_C
                        jmp             TMON_LOOP

TMON_KEY_IS_CTRL_C:
                        ldx             #<MSG_EXIT
                        ldy             #>MSG_EXIT
                        jsr             TMON_PRINT_LINE_XY
                        brk             $65
                        rts

TMON_TICK:
                        lda             #TMON_SPIN_DELAY_A
                        ldx             #TMON_SPIN_DELAY_X
                        ldy             #TMON_SPIN_DELAY_Y
                        jsr             UTL_DELAY_AXY_8MHZ

                        inc             TMON_UP_LO
                        bne             TMON_UP_OK
                        inc             TMON_UP_HI
TMON_UP_OK:
                        lda             TMON_DOWN_LO
                        bne             TMON_DOWN_DEC
                        dec             TMON_DOWN_HI
TMON_DOWN_DEC:
                        dec             TMON_DOWN_LO
                        rts

TMON_MAYBE_PRINT_LIVE:
                        ; Print live status every $0400 spins (10-bit cadence)
                        ; so serial output does not dominate spin timing.
                        lda             TMON_UP_LO
                        bne             TMON_LIVE_DONE
                        lda             TMON_UP_HI
                        and             #$03
                        bne             TMON_LIVE_DONE

                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        ldx             #<MSG_RT_UP
                        ldy             #>MSG_RT_UP
                        jsr             TMON_PRINT_XY
                        lda             TMON_UP_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             TMON_UP_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_RT_DOWN
                        ldy             #>MSG_RT_DOWN
                        jsr             TMON_PRINT_XY
                        lda             TMON_DOWN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             TMON_DOWN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_RT_TAIL
                        ldy             #>MSG_RT_TAIL
                        jsr             TMON_PRINT_XY
TMON_LIVE_DONE:
                        rts

TMON_CAPTURE_KEY_SPINS:
                        ; elapsed spins since previous key event:
                        ; key_spins = up - last_key_up; then latch current up.
                        lda             TMON_UP_LO
                        sec
                        sbc             TMON_LAST_KEY_UP_LO
                        sta             TMON_KEY_SPIN_LO
                        lda             TMON_UP_HI
                        sbc             TMON_LAST_KEY_UP_HI
                        sta             TMON_KEY_SPIN_HI

                        lda             TMON_UP_LO
                        sta             TMON_LAST_KEY_UP_LO
                        lda             TMON_UP_HI
                        sta             TMON_LAST_KEY_UP_HI
                        rts

TMON_PRINT_KEY_CLASS:
                        lda             TMON_KEY
                        cmp             #$0D
                        beq             TMON_KEY_CR
                        cmp             #$0A
                        beq             TMON_KEY_LF
                        cmp             #$08
                        beq             TMON_KEY_BS
                        cmp             #$7F
                        beq             TMON_KEY_DEL
                        cmp             #$1B
                        beq             TMON_KEY_ESC

                        cmp             #$20
                        bcc             TMON_KEY_CTRL
                        cmp             #$7F
                        bcs             TMON_KEY_EXT

                        ; printable ASCII
                        ldx             #<MSG_KEY_ASCII
                        ldy             #>MSG_KEY_ASCII
                        jsr             TMON_PRINT_XY
                        lda             TMON_KEY
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #$27                    ; '
                        jsr             COR_FTDI_WRITE_CHAR
                        rts

TMON_KEY_CR:
                        ldx             #<MSG_KEY_CR
                        ldy             #>MSG_KEY_CR
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_LF:
                        ldx             #<MSG_KEY_LF
                        ldy             #>MSG_KEY_LF
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_BS:
                        ldx             #<MSG_KEY_BS
                        ldy             #>MSG_KEY_BS
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_DEL:
                        ldx             #<MSG_KEY_DEL
                        ldy             #>MSG_KEY_DEL
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_ESC:
                        ldx             #<MSG_KEY_ESC
                        ldy             #>MSG_KEY_ESC
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_CTRL:
                        ldx             #<MSG_KEY_CTRL
                        ldy             #>MSG_KEY_CTRL
                        jsr             TMON_PRINT_XY
                        rts

TMON_KEY_EXT:
                        ldx             #<MSG_KEY_EXT
                        ldy             #>MSG_KEY_EXT
                        jsr             TMON_PRINT_XY
                        rts


TMON_PRINT_XY:
                        jsr             COR_FTDI_WRITE_CSTRING
                        rts

TMON_PRINT_LINE_XY:
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

                        DATA
MSG_HDR_1:              db              $0D,$0A,"R-YORS test-mon load demo",$00
MSG_HDR_2:              db              "linked for GO @ $5000",$00
MSG_HDR_3:              db              "Ctrl-C exits via brk $65",$00
MSG_RT_UP:              db              "spinning up=$",$00
MSG_RT_DOWN:            db              " down=$",$00
MSG_RT_TAIL:            db              "  (press key)",$00
MSG_KEY:                db              "key=$",$00
MSG_KEY_ASCII:          db              " ascii='",$00
MSG_KEY_CR:             db              " <CR>",$00
MSG_KEY_LF:             db              " <LF>",$00
MSG_KEY_BS:             db              " <BS>",$00
MSG_KEY_DEL:            db              " <DEL>",$00
MSG_KEY_ESC:            db              " <ESC>",$00
MSG_KEY_CTRL:           db              " <CTRL>",$00
MSG_KEY_EXT:            db              " <EXT>",$00
MSG_KEY_SPINS:          db              " elapsed-spins=$",$00
MSG_EXIT:               db              "Ctrl-C received: brk $65",$00

                        ENDMOD

                        END

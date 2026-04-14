; ----------------------------------------------------------------------------
; Command monitor shell:
; - Reads one line at a time.
; - Parses and executes DISPLAY/FILL/COPY/MODIFY/QUIT in this file.
; ----------------------------------------------------------------------------

                        MODULE          CMD_APP

                        XDEF            START

                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            UTL_FIND_CHAR_CSTR
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_LINE_XY
                        XREF            SYS_CVN_WRITE_LINE_RTL_XY

CMD_BUF                  EQU             $7C00
CMD_LEN                  EQU             $7B00
CMD_LINE_STATUS          EQU             $7B01
CMDP_PTR_LO             EQU             $F0
CMDP_PTR_HI             EQU             $F1
CMDP_ADDR_LO            EQU             $F2
CMDP_ADDR_HI            EQU             $F3
CMDP_START_LO           EQU             $F4
CMDP_START_HI           EQU             $F5

CMDP_REMAIN             EQU             $7B20
CMDP_LINE_REMAIN        EQU             $7B21
CMDP_MOD_COUNT          EQU             $7B22
CMDP_NIB_HI             EQU             $7B23
CMDP_BYTE_TMP           EQU             $7B24

                        CODE
START:
                        jsr             COR_FTDI_INIT
                        jsr             COR_FTDI_FLUSH_RX
                        ldx             #<MSG_HDR_1
                        ldy             #>MSG_HDR_1
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HDR_2
                        ldy             #>MSG_HDR_2
                        jsr             SYS_CVN_WRITE_LINE_RTL_XY
                        ldx             #<MSG_HDR_3
                        ldy             #>MSG_HDR_3
                        jsr             SYS_WRITE_LINE_XY

CMD_MAIN_LOOP:
                        ldx             #<MSG_PROMPT
                        ldy             #>MSG_PROMPT
                        jsr             SYS_WRITE_CSTRING

                        ldx             #<CMD_BUF
                        ldy             #>CMD_BUF
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        bcs             CMD_HAVE_LINE

                        ; Handle C=0 statuses from line reader (BS/DEL/full), then retry.
                        sta             CMD_LINE_STATUS
                        ldx             #<MSG_LINE_STATUS
                        ldy             #>MSG_LINE_STATUS
                        jsr             SYS_WRITE_CSTRING
                        lda             CMD_LINE_STATUS
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_RETRY
                        ldy             #>MSG_RETRY
                        jsr             SYS_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             CMD_MAIN_LOOP

CMD_HAVE_LINE:
                        sta             CMD_LEN
                        ldx             #<CMD_BUF
                        ldy             #>CMD_BUF
                        jsr             CMD_PARSE_AND_EXECUTE
                        bra             CMD_MAIN_LOOP


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE
; PURPOSE: Parse and execute one command line.
; IN : X/Y = pointer to NUL-terminated command line
; OUT: C=1 command handled/success; C=0 unknown command or usage error
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE:
                        stx             CMDP_PTR_LO
                        sty             CMDP_PTR_HI
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             CMDP_EMPTY_OK

                        jsr             CMDP_MATCH_DISPLAY
                        bcs             CMDP_RUN_DISPLAY
                        jsr             CMDP_MATCH_FILL
                        bcc             CMDP_PARSE_NO_FILL
                        jmp             CMDP_RUN_FILL
CMDP_PARSE_NO_FILL:
                        jsr             CMDP_MATCH_COPY
                        bcc             CMDP_PARSE_NO_COPY
                        jmp             CMDP_RUN_COPY
CMDP_PARSE_NO_COPY:
                        jsr             CMDP_MATCH_MODIFY
                        bcc             CMDP_PARSE_NO_MODIFY
                        jmp             CMDP_RUN_MODIFY
CMDP_PARSE_NO_MODIFY:
                        jsr             CMDP_MATCH_QUIT
                        bcs             CMDP_RUN_QUIT

                        ldx             #<CMDP_MSG_ERR_UNKNOWN
                        ldy             #>CMDP_MSG_ERR_UNKNOWN
                        jsr             SYS_WRITE_LINE_XY
                        clc
                        rts

CMDP_EMPTY_OK:
                        sec
                        rts

CMDP_RUN_QUIT:
                        jsr             CMDP_REQUIRE_EOL
                        bcc             CMDP_QUIT_USAGE
                        brk             $65
                        sec
                        rts

CMDP_QUIT_USAGE:
                        ldx             #<CMDP_MSG_USAGE_QUIT
                        ldy             #>CMDP_MSG_USAGE_QUIT
                        jmp             CMDP_USAGE_LINE_XY

CMDP_RUN_DISPLAY:
                        jsr             CMDP_PARSE_HEX_WORD_TOKEN
                        bcc             CMDP_DISPLAY_USAGE
                        jsr             CMDP_REQUIRE_EOL
                        bcc             CMDP_DISPLAY_USAGE

                        jsr             CMDP_EXEC_DISPLAY_256
                        sec
                        rts

CMDP_DISPLAY_USAGE:
                        ldx             #<CMDP_MSG_USAGE_DISPLAY
                        ldy             #>CMDP_MSG_USAGE_DISPLAY
                        jmp             CMDP_USAGE_LINE_XY

CMDP_RUN_FILL:
                        jsr             CMDP_PARSE_HEX_WORD_TOKEN
                        bcc             CMDP_FILL_USAGE
                        jsr             CMDP_PARSE_HEX_BYTE_TOKEN
                        bcc             CMDP_FILL_USAGE
                        sta             CMDP_REMAIN
                        lda             CMDP_REMAIN
                        beq             CMDP_FILL_USAGE
                        jsr             CMDP_PARSE_HEX_BYTE_TOKEN
                        bcc             CMDP_FILL_USAGE
                        sta             CMDP_BYTE_TMP
                        jsr             CMDP_REQUIRE_EOL
                        bcc             CMDP_FILL_USAGE

CMDP_FILL_LOOP:
                        ldy             #$00
                        lda             CMDP_BYTE_TMP
                        sta             (CMDP_ADDR_LO),y
                        jsr             CMDP_INC_ADDR
                        dec             CMDP_REMAIN
                        bne             CMDP_FILL_LOOP
                        sec
                        rts

CMDP_FILL_USAGE:
                        ldx             #<CMDP_MSG_USAGE_FILL
                        ldy             #>CMDP_MSG_USAGE_FILL
                        jmp             CMDP_USAGE_LINE_XY

CMDP_RUN_COPY:
                        jsr             CMDP_PARSE_HEX_WORD_TOKEN
                        bcc             CMDP_COPY_USAGE
                        lda             CMDP_ADDR_LO
                        sta             CMDP_START_LO
                        lda             CMDP_ADDR_HI
                        sta             CMDP_START_HI

                        jsr             CMDP_PARSE_HEX_WORD_TOKEN
                        bcc             CMDP_COPY_USAGE
                        jsr             CMDP_PARSE_HEX_BYTE_TOKEN
                        bcc             CMDP_COPY_USAGE
                        sta             CMDP_REMAIN
                        lda             CMDP_REMAIN
                        beq             CMDP_COPY_USAGE
                        jsr             CMDP_REQUIRE_EOL
                        bcc             CMDP_COPY_USAGE

                        lda             CMDP_ADDR_LO                   ; dst ptr in CMDP_PTR
                        sta             CMDP_PTR_LO
                        lda             CMDP_ADDR_HI
                        sta             CMDP_PTR_HI
                        lda             CMDP_START_LO                  ; src ptr in CMDP_ADDR
                        sta             CMDP_ADDR_LO
                        lda             CMDP_START_HI
                        sta             CMDP_ADDR_HI

CMDP_COPY_LOOP:
                        ldy             #$00
                        lda             (CMDP_ADDR_LO),y
                        sta             (CMDP_PTR_LO),y
                        jsr             CMDP_INC_ADDR
                        jsr             CMDP_ADV_PTR
                        dec             CMDP_REMAIN
                        bne             CMDP_COPY_LOOP
                        sec
                        rts

CMDP_COPY_USAGE:
                        ldx             #<CMDP_MSG_USAGE_COPY
                        ldy             #>CMDP_MSG_USAGE_COPY
                        jmp             CMDP_USAGE_LINE_XY

CMDP_RUN_MODIFY:
                        jsr             CMDP_PARSE_HEX_WORD_TOKEN
                        bcc             CMDP_MODIFY_USAGE

                        lda             CMDP_ADDR_LO
                        sta             CMDP_START_LO
                        lda             CMDP_ADDR_HI
                        sta             CMDP_START_HI
                        stz             CMDP_MOD_COUNT

CMDP_MODIFY_PARSE_LOOP:
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             CMDP_MODIFY_DONE
                        jsr             CMDP_PARSE_HEX_BYTE_TOKEN
                        bcc             CMDP_MODIFY_USAGE
                        ldy             #$00
                        sta             (CMDP_ADDR_LO),y
                        jsr             CMDP_INC_ADDR
                        inc             CMDP_MOD_COUNT
                        bra             CMDP_MODIFY_PARSE_LOOP

CMDP_MODIFY_DONE:
                        lda             CMDP_MOD_COUNT
                        beq             CMDP_MODIFY_USAGE

                        ldx             #<CMDP_MSG_MOD_OK_1
                        ldy             #>CMDP_MSG_MOD_OK_1
                        jsr             SYS_WRITE_CSTRING
                        lda             CMDP_MOD_COUNT
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<CMDP_MSG_MOD_OK_2
                        ldy             #>CMDP_MSG_MOD_OK_2
                        jsr             SYS_WRITE_CSTRING
                        lda             CMDP_START_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             CMDP_START_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

CMDP_MODIFY_USAGE:
                        ldx             #<CMDP_MSG_USAGE_MODIFY
                        ldy             #>CMDP_MSG_USAGE_MODIFY
                        jmp             CMDP_USAGE_LINE_XY


; ----------------------------------------------------------------------------
; Command matching
; ----------------------------------------------------------------------------
CMDP_MATCH_DISPLAY:
                        ldx             #<CMDP_LIT_DISPLAY
                        ldy             #>CMDP_LIT_DISPLAY
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_FILL:
                        ldx             #<CMDP_LIT_FILL
                        ldy             #>CMDP_LIT_FILL
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_COPY:
                        ldx             #<CMDP_LIT_COPY
                        ldy             #>CMDP_LIT_COPY
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_MODIFY:
                        ldx             #<CMDP_LIT_MODIFY
                        ldy             #>CMDP_LIT_MODIFY
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_QUIT:
                        ldx             #<CMDP_LIT_QUIT
                        ldy             #>CMDP_LIT_QUIT
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_LITERAL_XY:
                        stx             CMDP_START_LO
                        sty             CMDP_START_HI
                        ldy             #$00
CMDP_MATCH_LITERAL_LOOP:
                        lda             (CMDP_START_LO),y
                        beq             CMDP_MATCH_LITERAL_DONE
                        sta             CMDP_BYTE_TMP
                        lda             (CMDP_PTR_LO),y
                        jsr             CMDP_TO_UPPER_A
                        cmp             CMDP_BYTE_TMP
                        bne             CMDP_MATCH_LITERAL_FAIL
                        iny
                        bne             CMDP_MATCH_LITERAL_LOOP
CMDP_MATCH_LITERAL_FAIL:
                        clc
                        rts
CMDP_MATCH_LITERAL_DONE:
                        lda             (CMDP_PTR_LO),y
                        jsr             CMDP_IS_DELIM_OR_NUL
                        bcc             CMDP_MATCH_LITERAL_FAIL
                        jsr             CMDP_ADV_PTR_TO_FOUND_DELIM
                        bcc             CMDP_MATCH_LITERAL_FAIL
                        sec
                        rts


; ----------------------------------------------------------------------------
; DISPLAY executor
; ----------------------------------------------------------------------------
CMDP_EXEC_DISPLAY_256:
                        lda             #$10
                        sta             CMDP_REMAIN

CMDP_DISPLAY_LINE:
                        lda             CMDP_REMAIN
                        beq             CMDP_DISPLAY_DONE

                        lda             CMDP_ADDR_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             CMDP_ADDR_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             #':'
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR

                        lda             #$10
                        sta             CMDP_LINE_REMAIN

CMDP_DISPLAY_BYTES:
                        lda             CMDP_LINE_REMAIN
                        beq             CMDP_DISPLAY_END_LINE
                        ldy             #$00
                        lda             (CMDP_ADDR_LO),y
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             CMDP_INC_ADDR
                        dec             CMDP_LINE_REMAIN
                        bra             CMDP_DISPLAY_BYTES

CMDP_DISPLAY_END_LINE:
                        jsr             COR_FTDI_WRITE_CRLF
                        dec             CMDP_REMAIN
                        bra             CMDP_DISPLAY_LINE

CMDP_DISPLAY_DONE:
                        sec
                        rts


; ----------------------------------------------------------------------------
; Parse helpers
; ----------------------------------------------------------------------------
CMDP_REQUIRE_EOL:
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             CMDP_REQUIRE_EOL_OK
                        clc
                        rts
CMDP_REQUIRE_EOL_OK:
                        sec
                        rts

CMDP_USAGE_LINE_XY:
                        jsr             SYS_WRITE_LINE_XY
                        clc
                        rts

CMDP_PARSE_HEX_WORD_TOKEN:
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_SKIP_OPTIONAL_DOLLAR
                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcc             CMDP_PARSE_HEX_WORD_FAIL
                        sta             CMDP_ADDR_HI
                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcc             CMDP_PARSE_HEX_WORD_FAIL
                        sta             CMDP_ADDR_LO
                        jsr             CMDP_PEEK_CHAR
                        jsr             CMDP_IS_DELIM_OR_NUL
                        bcc             CMDP_PARSE_HEX_WORD_FAIL
                        sec
                        rts
CMDP_PARSE_HEX_WORD_FAIL:
                        clc
                        rts

CMDP_PARSE_HEX_BYTE_TOKEN:
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_SKIP_OPTIONAL_DOLLAR
                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcc             CMDP_PARSE_HEX_BYTE_TOKEN_FAIL
                        sta             CMDP_BYTE_TMP
                        jsr             CMDP_PEEK_CHAR
                        jsr             CMDP_IS_DELIM_OR_NUL
                        bcc             CMDP_PARSE_HEX_BYTE_TOKEN_FAIL
                        lda             CMDP_BYTE_TMP
                        sec
                        rts
CMDP_PARSE_HEX_BYTE_TOKEN_FAIL:
                        clc
                        rts

CMDP_PARSE_HEX_BYTE_ADV:
                        jsr             CMDP_PARSE_HEX_NIBBLE_ADV
                        bcc             CMDP_PARSE_HEX_BYTE_ADV_FAIL
                        asl             a
                        asl             a
                        asl             a
                        asl             a
                        sta             CMDP_NIB_HI
                        jsr             CMDP_PARSE_HEX_NIBBLE_ADV
                        bcc             CMDP_PARSE_HEX_BYTE_ADV_FAIL
                        ora             CMDP_NIB_HI
                        sec
                        rts
CMDP_PARSE_HEX_BYTE_ADV_FAIL:
                        clc
                        rts

CMDP_PARSE_HEX_NIBBLE_ADV:
                        jsr             CMDP_PEEK_CHAR
                        jsr             CMDP_HEX_ASCII_TO_NIBBLE
                        bcc             CMDP_PARSE_HEX_NIBBLE_ADV_FAIL
                        pha
                        jsr             CMDP_ADV_PTR
                        pla
                        sec
                        rts
CMDP_PARSE_HEX_NIBBLE_ADV_FAIL:
                        clc
                        rts

CMDP_SKIP_OPTIONAL_DOLLAR:
                        jsr             CMDP_PEEK_CHAR
                        cmp             #'$'
                        bne             CMDP_SKIP_OPTIONAL_DOLLAR_DONE
                        jsr             CMDP_ADV_PTR
CMDP_SKIP_OPTIONAL_DOLLAR_DONE:
                        rts


; ----------------------------------------------------------------------------
; Generic scanner helpers
; ----------------------------------------------------------------------------
CMDP_SKIP_SPACES:
                        jsr             CMDP_PEEK_CHAR
                        cmp             #' '
                        beq             CMDP_SKIP_SPACES_ADV
                        cmp             #$09
                        beq             CMDP_SKIP_SPACES_ADV
                        rts
CMDP_SKIP_SPACES_ADV:
                        jsr             CMDP_ADV_PTR
                        bra             CMDP_SKIP_SPACES

CMDP_PEEK_CHAR:
                        ldy             #$00
                        lda             (CMDP_PTR_LO),y
                        rts

CMDP_ADV_PTR:
                        inc             CMDP_PTR_LO
                        bne             CMDP_ADV_PTR_DONE
                        inc             CMDP_PTR_HI
CMDP_ADV_PTR_DONE:
                        rts

; IN : A = delimiter byte already verified present at/after CMDP_PTR
; OUT: CMDP_PTR advanced to:
;      - just after delimiter when delimiter != 0
;      - NUL terminator when delimiter == 0
;      C = 1 on success, C = 0 only on unexpected scan cap
CMDP_ADV_PTR_TO_FOUND_DELIM:
                        pha
                        ldx             CMDP_PTR_LO
                        ldy             CMDP_PTR_HI
                        pla
                        jsr             UTL_FIND_CHAR_CSTR
                        bcc             CMDP_ADV_PTR_TO_FOUND_DELIM_FAIL
                        stx             CMDP_PTR_LO
                        sty             CMDP_PTR_HI
                        sec
                        rts
CMDP_ADV_PTR_TO_FOUND_DELIM_FAIL:
                        clc
                        rts

CMDP_INC_ADDR:
                        inc             CMDP_ADDR_LO
                        bne             CMDP_INC_ADDR_DONE
                        inc             CMDP_ADDR_HI
CMDP_INC_ADDR_DONE:
                        rts

CMDP_IS_DELIM_OR_NUL:
                        cmp             #$00
                        beq             CMDP_IS_DELIM_TRUE
                        cmp             #' '
                        beq             CMDP_IS_DELIM_TRUE
                        cmp             #$09
                        beq             CMDP_IS_DELIM_TRUE
                        clc
                        rts
CMDP_IS_DELIM_TRUE:
                        sec
                        rts

CMDP_TO_UPPER_A:
                        cmp             #'a'
                        bcc             CMDP_TO_UPPER_DONE
                        cmp             #'{'
                        bcs             CMDP_TO_UPPER_DONE
                        and             #$DF
CMDP_TO_UPPER_DONE:
                        rts

CMDP_HEX_ASCII_TO_NIBBLE:
                        cmp             #'0'
                        bcc             CMDP_HXN_BAD
                        cmp             #':'
                        bcc             CMDP_HXN_DIGIT
                        cmp             #'A'
                        bcc             CMDP_HXN_CHECK_LOWER
                        cmp             #'G'
                        bcc             CMDP_HXN_UPPER
CMDP_HXN_CHECK_LOWER:
                        cmp             #'a'
                        bcc             CMDP_HXN_BAD
                        cmp             #'g'
                        bcs             CMDP_HXN_BAD
                        sec
                        sbc             #$57
                        sec
                        rts
CMDP_HXN_UPPER:
                        sec
                        sbc             #$37
                        sec
                        rts
CMDP_HXN_DIGIT:
                        sec
                        sbc             #'0'
                        sec
                        rts
CMDP_HXN_BAD:
                        clc
                        rts

                        DATA
CMDP_LIT_DISPLAY:        db              "DISPLAY",$00
CMDP_LIT_FILL:           db              "FILL",$00
CMDP_LIT_COPY:           db              "COPY",$00
CMDP_LIT_MODIFY:         db              "MODIFY",$00
CMDP_LIT_QUIT:           db              "QUIT",$00
MSG_HDR_1:               db              $0d, $0a,"R-YORS command monitor",$00
MSG_HDR_2:               db              "DISPLAY FILL COPY MODIFY QUIT",$00
MSG_HDR_3:               db              $00
MSG_PROMPT:              db              "cmd> ",$00
MSG_LINE_STATUS:         db              "line status=$",$00
MSG_RETRY:               db              " (retry)",$00
CMDP_MSG_ERR_UNKNOWN:    db              "ERR: unknown command",$00
CMDP_MSG_USAGE_DISPLAY:  db              "usage: DISPLAY <addr16>",$00
CMDP_MSG_USAGE_FILL:     db              "usage: FILL <addr16> <count8> <byte8>",$00
CMDP_MSG_USAGE_COPY:     db              "usage: COPY <src16> <dst16> <count8>",$00
CMDP_MSG_USAGE_MODIFY:   db              "usage: MODIFY <addr16> <byte8> [byte8 ...]",$00
CMDP_MSG_USAGE_QUIT:     db              "usage: QUIT",$00
CMDP_MSG_MOD_OK_1:       db              "modified $",$00
CMDP_MSG_MOD_OK_2:       db              " bytes at $",$00

                        ENDMOD

                        END

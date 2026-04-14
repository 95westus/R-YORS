; ----------------------------------------------------------------------------
; Command monitor shell:
; - Reads one line at a time.
; - Parses and executes DISPLAY/FILL/COPY/MODIFY/QUIT in this file.
; ----------------------------------------------------------------------------

                        MODULE          MONITOR_APP

                        XDEF            START

                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE
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

; ----------------------------------------------------------------------------
; LOAD (S-Record) workspace
; ----------------------------------------------------------------------------
LOAD_LINE_STATUS        EQU             $7B30
LOAD_REC_TYPE           EQU             $7B31
LOAD_REC_KIND           EQU             $7B32
LOAD_ADDR_LEN           EQU             $7B33
LOAD_COUNT              EQU             $7B34
LOAD_DATA_LEN           EQU             $7B35
LOAD_SUM                EQU             $7B36
LOAD_CHK                EQU             $7B37
LOAD_DST_LO             EQU             $7B38
LOAD_DST_HI             EQU             $7B39
LOAD_GO_LO              EQU             $7B3A
LOAD_GO_HI              EQU             $7B3B
LOAD_GO_VALID           EQU             $7B3C
LOAD_TOTAL_LO           EQU             $7B3D
LOAD_TOTAL_HI           EQU             $7B3E
LOAD_REC_LO             EQU             $7B3F
LOAD_REC_HI             EQU             $7B40
LOAD_ADDR_B0            EQU             $7B41
LOAD_ADDR_B1            EQU             $7B42
LOAD_ADDR_B2            EQU             $7B43
LOAD_ADDR_B3            EQU             $7B44
LOAD_ROUTED             EQU             $7B45
LOAD_SPAN_COUNT         EQU             $7B46
LOAD_CUR_END_LO         EQU             $7B47
LOAD_CUR_END_HI         EQU             $7B48
LOAD_SPAN_BUF           EQU             $7B50
LOAD_SPAN_MAX           EQU             $08

LOAD_REC_KIND_DATA      EQU             $01
LOAD_REC_KIND_TERM      EQU             $02
LOAD_REC_KIND_SKIP      EQU             $03

LOAD_DATA_MAX           EQU             $40
LOAD_BUF                EQU             $7D00
LOAD_DATA_BUF           EQU             $7E00

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
                        jsr             COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
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
                        jsr             CMD_PARSE_AND_EXECUTE_ROUTER
                        bra             CMD_MAIN_LOOP


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE_ROUTER
; PURPOSE: Front router that handles LOAD first, then falls back to existing
;          parser for DISPLAY/FILL/COPY/MODIFY/QUIT.
; IN : X/Y = pointer to command line
; OUT: C mirrors selected command path result.
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE_ROUTER:
                        stx             CMDP_PTR_LO
                        sty             CMDP_PTR_HI
                        stz             LOAD_ROUTED
                        jsr             CMD_PARSE_AND_EXECUTE_LOAD_TRY
                        lda             LOAD_ROUTED
                        bne             CMDP_ROUTER_DONE
                        ldx             CMDP_PTR_LO
                        ldy             CMDP_PTR_HI
                        jmp             CMD_PARSE_AND_EXECUTE
CMDP_ROUTER_DONE:
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: CMD_PARSE_AND_EXECUTE_LOAD_TRY
; PURPOSE: Detect and run LOAD command family.
; IN : X/Y = pointer to command line
; OUT: LOAD_ROUTED=1 when command token was LOAD, C=command result.
; ----------------------------------------------------------------------------
CMD_PARSE_AND_EXECUTE_LOAD_TRY:
                        stx             CMDP_PTR_LO
                        sty             CMDP_PTR_HI
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             CMDP_LOAD_NOT_ROUTED
                        jsr             CMDP_MATCH_LOAD
                        bcc             CMDP_LOAD_NOT_ROUTED
                        lda             #$01
                        sta             LOAD_ROUTED
                        jmp             CMDP_RUN_LOAD
CMDP_LOAD_NOT_ROUTED:
                        clc
                        rts


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
                        jsr             CMDP_MATCH_HELP
                        bcc             CMDP_PARSE_NO_HELP
                        jmp             CMDP_RUN_HELP
CMDP_PARSE_NO_HELP:
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

CMDP_RUN_HELP:
                        jsr             CMDP_REQUIRE_EOL
                        bcc             CMDP_HELP_USAGE
                        ldx             #<MSG_HELP_1
                        ldy             #>MSG_HELP_1
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HELP_2
                        ldy             #>MSG_HELP_2
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HELP_3
                        ldy             #>MSG_HELP_3
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HELP_4
                        ldy             #>MSG_HELP_4
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HELP_5
                        ldy             #>MSG_HELP_5
                        jsr             SYS_WRITE_LINE_XY
                        ldx             #<MSG_HELP_6
                        ldy             #>MSG_HELP_6
                        jsr             SYS_WRITE_LINE_XY
                        sec
                        rts

CMDP_HELP_USAGE:
                        ldx             #<CMDP_MSG_USAGE_HELP
                        ldy             #>CMDP_MSG_USAGE_HELP
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

CMDP_MATCH_HELP:
                        ldx             #<CMDP_LIT_HELP
                        ldy             #>CMDP_LIT_HELP
                        jmp             CMDP_MATCH_LITERAL_XY

CMDP_MATCH_LOAD:
                        ldx             #<CMDP_LIT_LOAD
                        ldy             #>CMDP_LIT_LOAD
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
; LOAD command family
; ----------------------------------------------------------------------------
CMDP_RUN_LOAD:
                        jsr             MON_LOAD_VALIDATE_ARGS
                        bcc             CMDP_LOAD_USAGE
                        jsr             MON_LOAD_INIT
                        ldx             #<MSG_LOAD_READY
                        ldy             #>MSG_LOAD_READY
                        jsr             SYS_WRITE_LINE_XY

CMDP_LOAD_SESSION_LOOP:
                        jsr             MON_LOAD_READ_LINE
                        bcc             CMDP_LOAD_LINE_FAIL
                        jsr             MON_LOAD_PARSE_RECORD
                        bcc             CMDP_LOAD_PARSE_FAIL
                        lda             LOAD_REC_KIND
                        cmp             #LOAD_REC_KIND_DATA
                        beq             CMDP_LOAD_HANDLE_DATA
                        cmp             #LOAD_REC_KIND_TERM
                        beq             CMDP_LOAD_HANDLE_TERM
                        lda             LOAD_REC_TYPE
                        beq             CMDP_LOAD_SESSION_LOOP
                        jsr             MON_LOAD_ACCUM_RECORD_ONLY
                        bra             CMDP_LOAD_SESSION_LOOP

CMDP_LOAD_HANDLE_DATA:
                        jsr             MON_LOAD_NOTE_DATA_START
                        jsr             MON_LOAD_WRITE_RECORD_DATA
                        bcc             CMDP_LOAD_PARSE_FAIL
                        jsr             MON_LOAD_NOTE_DATA_END
                        jsr             MON_LOAD_ACCUM_RECORD_AND_BYTES
                        bra             CMDP_LOAD_SESSION_LOOP

CMDP_LOAD_HANDLE_TERM:
                        jsr             MON_LOAD_CAPTURE_GO
                        bcc             CMDP_LOAD_PARSE_FAIL
                        jsr             MON_LOAD_ACCUM_RECORD_ONLY
                        jsr             MON_LOAD_PRINT_SUMMARY
                        sec
                        rts

CMDP_LOAD_USAGE:
                        ldx             #<CMDP_MSG_USAGE_LOAD
                        ldy             #>CMDP_MSG_USAGE_LOAD
                        jmp             CMDP_USAGE_LINE_XY

CMDP_LOAD_LINE_FAIL:
                        ldx             #<MSG_LOAD_LINE_STATUS
                        ldy             #>MSG_LOAD_LINE_STATUS
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_LINE_STATUS
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        clc
                        rts

CMDP_LOAD_PARSE_FAIL:
                        ldx             #<MSG_LOAD_PARSE_FAIL
                        ldy             #>MSG_LOAD_PARSE_FAIL
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_REC_TYPE
                        beq             CMDP_LOAD_PARSE_FAIL_EOL
                        jsr             COR_FTDI_WRITE_CHAR
CMDP_LOAD_PARSE_FAIL_EOL:
                        jsr             COR_FTDI_WRITE_CRLF
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_VALIDATE_ARGS
; PURPOSE: Validate LOAD args. LOAD and LOAD S are the same command mode.
; ACCEPTS: LOAD
;          LOAD S
;          LOAD S19
;          LOAD S28
;          LOAD S37
; ----------------------------------------------------------------------------
MON_LOAD_VALIDATE_ARGS:
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             MON_LOAD_VALIDATE_OK
                        jsr             CMDP_TO_UPPER_A
                        cmp             #'S'
                        bne             MON_LOAD_VALIDATE_FAIL
                        jsr             CMDP_ADV_PTR
                        jsr             CMDP_PEEK_CHAR
                        beq             MON_LOAD_VALIDATE_NEED_EOL
                        cmp             #' '
                        beq             MON_LOAD_VALIDATE_NEED_EOL
                        cmp             #$09
                        beq             MON_LOAD_VALIDATE_NEED_EOL
                        cmp             #'1'
                        beq             MON_LOAD_VALIDATE_19
                        cmp             #'2'
                        beq             MON_LOAD_VALIDATE_28
                        cmp             #'3'
                        beq             MON_LOAD_VALIDATE_37
                        bne             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_19:
                        jsr             CMDP_ADV_PTR
                        jsr             CMDP_PEEK_CHAR
                        cmp             #'9'
                        bne             MON_LOAD_VALIDATE_FAIL
                        jsr             CMDP_ADV_PTR
                        bra             MON_LOAD_VALIDATE_NEED_EOL

MON_LOAD_VALIDATE_28:
                        jsr             CMDP_ADV_PTR
                        jsr             CMDP_PEEK_CHAR
                        cmp             #'8'
                        bne             MON_LOAD_VALIDATE_FAIL
                        jsr             CMDP_ADV_PTR
                        bra             MON_LOAD_VALIDATE_NEED_EOL

MON_LOAD_VALIDATE_37:
                        jsr             CMDP_ADV_PTR
                        jsr             CMDP_PEEK_CHAR
                        cmp             #'7'
                        bne             MON_LOAD_VALIDATE_FAIL
                        jsr             CMDP_ADV_PTR

MON_LOAD_VALIDATE_NEED_EOL:
                        jsr             CMDP_REQUIRE_EOL
                        bcc             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_OK:
                        sec
                        rts

MON_LOAD_VALIDATE_FAIL:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_INIT
; PURPOSE: Reset LOAD session counters and state.
; ----------------------------------------------------------------------------
MON_LOAD_INIT:
                        stz             LOAD_LINE_STATUS
                        stz             LOAD_REC_TYPE
                        stz             LOAD_REC_KIND
                        stz             LOAD_ADDR_LEN
                        stz             LOAD_COUNT
                        stz             LOAD_DATA_LEN
                        stz             LOAD_SUM
                        stz             LOAD_CHK
                        stz             LOAD_DST_LO
                        stz             LOAD_DST_HI
                        stz             LOAD_GO_LO
                        stz             LOAD_GO_HI
                        stz             LOAD_GO_VALID
                        stz             LOAD_TOTAL_LO
                        stz             LOAD_TOTAL_HI
                        stz             LOAD_REC_LO
                        stz             LOAD_REC_HI
                        stz             LOAD_SPAN_COUNT
                        stz             LOAD_CUR_END_LO
                        stz             LOAD_CUR_END_HI
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_READ_LINE
; PURPOSE: Read one incoming S-record text line into LOAD_BUF.
; OUT: C=1 success, C=0 with LOAD_LINE_STATUS set.
; ----------------------------------------------------------------------------
MON_LOAD_READ_LINE:
                        ldx             #<LOAD_BUF
                        ldy             #>LOAD_BUF
                        lda             #$02                            ; silent + uppercase (no line echo during LOAD)
                        jsr             COR_FTDI_READ_CSTRING_EDIT_MODE
                        bcs             MON_LOAD_READ_LINE_OK
                        sta             LOAD_LINE_STATUS
                        clc
                        rts
MON_LOAD_READ_LINE_OK:
                        sec
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PARSE_RECORD
; PURPOSE: Parse one S-record line (S19/S28/S37 and S7/S8/S9 termination).
; NOTES:
;   - S0/S5/S6 are accepted as non-data records and skipped.
;   - For S2/S3/S8/S7 addresses, upper address bytes must be zero.
; OUT:
;   - C=1 parse OK.
;   - LOAD_REC_KIND = DATA / TERM / SKIP.
;   - LOAD_DST_HI:LOAD_DST_LO = resolved 16-bit address for DATA/TERM.
; ----------------------------------------------------------------------------
MON_LOAD_PARSE_RECORD:
                        jmp             MON_LOAD_PARSE_BEGIN
MON_LOAD_PARSE_BLANK_NEAR:
                        jmp             MON_LOAD_PARSE_BLANK
MON_LOAD_PARSE_FAIL_NEAR:
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_BEGIN:
                        stz             LOAD_REC_TYPE
                        stz             LOAD_REC_KIND
                        stz             LOAD_ADDR_LEN
                        stz             LOAD_COUNT
                        stz             LOAD_DATA_LEN
                        stz             LOAD_SUM
                        stz             LOAD_CHK
                        stz             LOAD_ADDR_B0
                        stz             LOAD_ADDR_B1
                        stz             LOAD_ADDR_B2
                        stz             LOAD_ADDR_B3

                        ldx             #<LOAD_BUF
                        ldy             #>LOAD_BUF
                        stx             CMDP_PTR_LO
                        sty             CMDP_PTR_HI
                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             MON_LOAD_PARSE_BLANK_NEAR
                        jsr             CMDP_TO_UPPER_A
                        cmp             #'S'
                        bne             MON_LOAD_PARSE_FAIL_NEAR
                        jsr             CMDP_ADV_PTR
                        jsr             CMDP_PEEK_CHAR
                        jsr             CMDP_TO_UPPER_A
                        sta             LOAD_REC_TYPE
                        jsr             CMDP_ADV_PTR
                        jsr             MON_LOAD_CLASSIFY_TYPE
                        bcc             MON_LOAD_PARSE_FAIL_NEAR

                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcc             MON_LOAD_PARSE_FAIL_NEAR
                        sta             LOAD_COUNT
                        sta             LOAD_SUM

                        lda             LOAD_COUNT
                        sec
                        sbc             LOAD_ADDR_LEN
                        bcc             MON_LOAD_PARSE_FAIL_NEAR
                        sec
                        sbc             #$01
                        bcc             MON_LOAD_PARSE_FAIL_NEAR
                        sta             LOAD_DATA_LEN
                        cmp             #$41
                        bcs             MON_LOAD_PARSE_FAIL_NEAR

                        ldx             #$00
MON_LOAD_PARSE_ADDR_LOOP:
                        cpx             LOAD_ADDR_LEN
                        beq             MON_LOAD_PARSE_ADDR_DONE
                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcc             MON_LOAD_PARSE_FAIL_NEAR
                        pha
                        clc
                        adc             LOAD_SUM
                        sta             LOAD_SUM
                        pla
                        sta             LOAD_ADDR_B0,x
                        inx
                        bra             MON_LOAD_PARSE_ADDR_LOOP
MON_LOAD_PARSE_ADDR_DONE:

                        ldx             #$00
MON_LOAD_PARSE_DATA_LOOP:
                        cpx             LOAD_DATA_LEN
                        beq             MON_LOAD_PARSE_DATA_DONE
                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcs             MON_LOAD_PARSE_DATA_HAVE_BYTE
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_DATA_HAVE_BYTE:
                        pha
                        clc
                        adc             LOAD_SUM
                        sta             LOAD_SUM
                        pla
                        sta             LOAD_DATA_BUF,x
                        inx
                        bra             MON_LOAD_PARSE_DATA_LOOP
MON_LOAD_PARSE_DATA_DONE:

                        jsr             CMDP_PARSE_HEX_BYTE_ADV
                        bcs             MON_LOAD_PARSE_HAVE_CHK
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_HAVE_CHK:
                        sta             LOAD_CHK
                        clc
                        adc             LOAD_SUM
                        cmp             #$FF
                        beq             MON_LOAD_PARSE_CHK_OK
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_CHK_OK:

                        jsr             CMDP_SKIP_SPACES
                        jsr             CMDP_PEEK_CHAR
                        beq             MON_LOAD_PARSE_TAIL_OK
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_TAIL_OK:

                        lda             LOAD_REC_KIND
                        cmp             #LOAD_REC_KIND_SKIP
                        beq             MON_LOAD_PARSE_OK
                        jsr             MON_LOAD_RESOLVE_ADDR16
                        bcs             MON_LOAD_PARSE_OK
                        jmp             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_OK:
                        sec
                        rts

MON_LOAD_PARSE_BLANK:
                        lda             #LOAD_REC_KIND_SKIP
                        sta             LOAD_REC_KIND
                        sec
                        rts

MON_LOAD_PARSE_FAIL:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CLASSIFY_TYPE
; PURPOSE: Map S-record type to DATA/TERM/SKIP and expected address length.
; ----------------------------------------------------------------------------
MON_LOAD_CLASSIFY_TYPE:
                        lda             LOAD_REC_TYPE
                        cmp             #'1'
                        bne             MON_LOAD_CLASSIFY_NO_S1
                        lda             #LOAD_REC_KIND_DATA
                        sta             LOAD_REC_KIND
                        lda             #$02
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S1:
                        cmp             #'2'
                        bne             MON_LOAD_CLASSIFY_NO_S2
                        lda             #LOAD_REC_KIND_DATA
                        sta             LOAD_REC_KIND
                        lda             #$03
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S2:
                        cmp             #'3'
                        bne             MON_LOAD_CLASSIFY_NO_S3
                        lda             #LOAD_REC_KIND_DATA
                        sta             LOAD_REC_KIND
                        lda             #$04
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S3:
                        cmp             #'7'
                        bne             MON_LOAD_CLASSIFY_NO_S7
                        lda             #LOAD_REC_KIND_TERM
                        sta             LOAD_REC_KIND
                        lda             #$04
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S7:
                        cmp             #'8'
                        bne             MON_LOAD_CLASSIFY_NO_S8
                        lda             #LOAD_REC_KIND_TERM
                        sta             LOAD_REC_KIND
                        lda             #$03
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S8:
                        cmp             #'9'
                        bne             MON_LOAD_CLASSIFY_NO_S9
                        lda             #LOAD_REC_KIND_TERM
                        sta             LOAD_REC_KIND
                        lda             #$02
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S9:
                        cmp             #'0'
                        bne             MON_LOAD_CLASSIFY_NO_S0
                        lda             #LOAD_REC_KIND_SKIP
                        sta             LOAD_REC_KIND
                        lda             #$02
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S0:
                        cmp             #'5'
                        bne             MON_LOAD_CLASSIFY_NO_S5
                        lda             #LOAD_REC_KIND_SKIP
                        sta             LOAD_REC_KIND
                        lda             #$02
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_NO_S5:
                        cmp             #'6'
                        bne             MON_LOAD_CLASSIFY_FAIL
                        lda             #LOAD_REC_KIND_SKIP
                        sta             LOAD_REC_KIND
                        lda             #$03
                        sta             LOAD_ADDR_LEN
                        sec
                        rts
MON_LOAD_CLASSIFY_FAIL:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_RESOLVE_ADDR16
; PURPOSE: Resolve parsed record address into 16-bit target address.
; RULES:
;   - S1/S9: direct 16-bit.
;   - S2/S8: top byte must be 00.
;   - S3/S7: top two bytes must be 00.
; ----------------------------------------------------------------------------
MON_LOAD_RESOLVE_ADDR16:
                        lda             LOAD_ADDR_LEN
                        cmp             #$02
                        beq             MON_LOAD_RESOLVE_16
                        cmp             #$03
                        beq             MON_LOAD_RESOLVE_24
                        cmp             #$04
                        beq             MON_LOAD_RESOLVE_32
                        clc
                        rts

MON_LOAD_RESOLVE_16:
                        lda             LOAD_ADDR_B0
                        sta             LOAD_DST_HI
                        lda             LOAD_ADDR_B1
                        sta             LOAD_DST_LO
                        sec
                        rts

MON_LOAD_RESOLVE_24:
                        lda             LOAD_ADDR_B0
                        bne             MON_LOAD_RESOLVE_FAIL
                        lda             LOAD_ADDR_B1
                        sta             LOAD_DST_HI
                        lda             LOAD_ADDR_B2
                        sta             LOAD_DST_LO
                        sec
                        rts

MON_LOAD_RESOLVE_32:
                        lda             LOAD_ADDR_B0
                        ora             LOAD_ADDR_B1
                        bne             MON_LOAD_RESOLVE_FAIL
                        lda             LOAD_ADDR_B2
                        sta             LOAD_DST_HI
                        lda             LOAD_ADDR_B3
                        sta             LOAD_DST_LO
                        sec
                        rts

MON_LOAD_RESOLVE_FAIL:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_WRITE_RECORD_DATA
; PURPOSE: Write parsed record payload bytes to LOAD_DST address.
; ----------------------------------------------------------------------------
MON_LOAD_WRITE_RECORD_DATA:
                        lda             LOAD_DST_LO
                        sta             CMDP_ADDR_LO
                        lda             LOAD_DST_HI
                        sta             CMDP_ADDR_HI
                        ldx             #$00
MON_LOAD_WRITE_LOOP:
                        cpx             LOAD_DATA_LEN
                        beq             MON_LOAD_WRITE_DONE
                        lda             LOAD_DATA_BUF,x
                        ldy             #$00
                        sta             (CMDP_ADDR_LO),y
                        jsr             CMDP_INC_ADDR
                        inx
                        bra             MON_LOAD_WRITE_LOOP
MON_LOAD_WRITE_DONE:
                        sec
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_ACCUM_RECORD_ONLY / MON_LOAD_ACCUM_RECORD_AND_BYTES
; PURPOSE: Maintain LOAD session counters.
; ----------------------------------------------------------------------------
MON_LOAD_ACCUM_RECORD_ONLY:
                        inc             LOAD_REC_LO
                        bne             MON_LOAD_ACC_REC_DONE
                        inc             LOAD_REC_HI
MON_LOAD_ACC_REC_DONE:
                        rts

MON_LOAD_ACCUM_RECORD_AND_BYTES:
                        jsr             MON_LOAD_ACCUM_RECORD_ONLY
                        clc
                        lda             LOAD_TOTAL_LO
                        adc             LOAD_DATA_LEN
                        sta             LOAD_TOTAL_LO
                        lda             LOAD_TOTAL_HI
                        adc             #$00
                        sta             LOAD_TOTAL_HI
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CAPTURE_GO
; PURPOSE: Capture entry address from S7/S8/S9 termination record.
; ----------------------------------------------------------------------------
MON_LOAD_CAPTURE_GO:
                        lda             LOAD_REC_KIND
                        cmp             #LOAD_REC_KIND_TERM
                        bne             MON_LOAD_CAPTURE_GO_FAIL
                        lda             LOAD_DATA_LEN
                        bne             MON_LOAD_CAPTURE_GO_FAIL
                        lda             LOAD_DST_LO
                        sta             LOAD_GO_LO
                        lda             LOAD_DST_HI
                        sta             LOAD_GO_HI
                        lda             #$01
                        sta             LOAD_GO_VALID
                        sec
                        rts
MON_LOAD_CAPTURE_GO_FAIL:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_SUMMARY
; PURPOSE: Report LOAD completion counters and captured GO address.
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_SUMMARY:
                        ldx             #<MSG_LOAD_DONE_REC
                        ldy             #>MSG_LOAD_DONE_REC
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_REC_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             LOAD_REC_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_LOAD_DONE_BYTES
                        ldy             #>MSG_LOAD_DONE_BYTES
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_TOTAL_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             LOAD_TOTAL_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             MON_LOAD_PRINT_START_SUMMARY
                        ldx             #<MSG_LOAD_DONE_GO
                        ldy             #>MSG_LOAD_DONE_GO
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_GO_VALID
                        bne             MON_LOAD_PRINT_GO_VALUE
                        ldx             #<MSG_LOAD_NO_GO
                        ldy             #>MSG_LOAD_NO_GO
                        jsr             SYS_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        rts
MON_LOAD_PRINT_GO_VALUE:
                        lda             LOAD_GO_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             LOAD_GO_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_NOTE_DATA_START
; PURPOSE: Detect contiguous/non-contiguous data spans and note new starts.
; ----------------------------------------------------------------------------
MON_LOAD_NOTE_DATA_START:
                        lda             LOAD_SPAN_COUNT
                        beq             MON_LOAD_NOTE_NEW_SPAN
                        lda             LOAD_CUR_END_LO
                        clc
                        adc             #$01
                        sta             CMDP_ADDR_LO
                        lda             LOAD_CUR_END_HI
                        adc             #$00
                        sta             CMDP_ADDR_HI
                        lda             LOAD_DST_LO
                        cmp             CMDP_ADDR_LO
                        bne             MON_LOAD_NOTE_NEW_SPAN
                        lda             LOAD_DST_HI
                        cmp             CMDP_ADDR_HI
                        beq             MON_LOAD_NOTE_DATA_START_DONE
MON_LOAD_NOTE_NEW_SPAN:
                        jsr             MON_LOAD_STORE_SPAN_START
                        lda             LOAD_SPAN_COUNT
                        cmp             #$01
                        bne             MON_LOAD_NOTE_PRINT_SPAN
                        ldx             #<MSG_LOAD_START_ADDR
                        ldy             #>MSG_LOAD_START_ADDR
                        jmp             MON_LOAD_PRINT_DST_ADDR_LINE_XY
MON_LOAD_NOTE_PRINT_SPAN:
                        ldx             #<MSG_LOAD_SPAN_ADDR
                        ldy             #>MSG_LOAD_SPAN_ADDR
                        jmp             MON_LOAD_PRINT_DST_ADDR_LINE_XY
MON_LOAD_NOTE_DATA_START_DONE:
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_NOTE_DATA_END
; PURPOSE: Update current span end to last byte written by current data record.
; ----------------------------------------------------------------------------
MON_LOAD_NOTE_DATA_END:
                        lda             CMDP_ADDR_LO
                        bne             MON_LOAD_NOTE_END_HAVE_LO
                        dec             CMDP_ADDR_HI
MON_LOAD_NOTE_END_HAVE_LO:
                        dec             CMDP_ADDR_LO
                        lda             CMDP_ADDR_LO
                        sta             LOAD_CUR_END_LO
                        lda             CMDP_ADDR_HI
                        sta             LOAD_CUR_END_HI
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_STORE_SPAN_START
; PURPOSE: Store start address of a new span (up to LOAD_SPAN_MAX entries).
; ----------------------------------------------------------------------------
MON_LOAD_STORE_SPAN_START:
                        lda             LOAD_SPAN_COUNT
                        cmp             #LOAD_SPAN_MAX
                        bcs             MON_LOAD_STORE_SPAN_NO_STORE
                        asl             a
                        tax
                        lda             LOAD_DST_LO
                        sta             LOAD_SPAN_BUF,x
                        inx
                        lda             LOAD_DST_HI
                        sta             LOAD_SPAN_BUF,x
MON_LOAD_STORE_SPAN_NO_STORE:
                        inc             LOAD_SPAN_COUNT
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_DST_ADDR_LINE_XY
; PURPOSE: Print `X/Y` C-string prefix + current LOAD_DST address + CRLF.
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_DST_ADDR_LINE_XY:
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_DST_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             LOAD_DST_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_START_SUMMARY
; PURPOSE: Print load start info and additional span starts when non-contiguous.
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_START_SUMMARY:
                        ldx             #<MSG_LOAD_DONE_START
                        ldy             #>MSG_LOAD_DONE_START
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_SPAN_COUNT
                        beq             MON_LOAD_PRINT_START_NONE

                        lda             LOAD_SPAN_BUF+1
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             LOAD_SPAN_BUF+0
                        jsr             COR_FTDI_WRITE_HEX_BYTE

                        lda             LOAD_SPAN_COUNT
                        cmp             #$01
                        beq             MON_LOAD_PRINT_START_LINE_DONE
                        ldx             #<MSG_LOAD_DONE_SPANS
                        ldy             #>MSG_LOAD_DONE_SPANS
                        jsr             SYS_WRITE_CSTRING
                        lda             LOAD_SPAN_COUNT
                        jsr             COR_FTDI_WRITE_HEX_BYTE
MON_LOAD_PRINT_START_LINE_DONE:
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             LOAD_SPAN_COUNT
                        cmp             #$02
                        bcc             MON_LOAD_PRINT_START_DONE
                        cmp             #LOAD_SPAN_MAX
                        bcc             MON_LOAD_PRINT_SPAN_CAP_OK
                        lda             #LOAD_SPAN_MAX
MON_LOAD_PRINT_SPAN_CAP_OK:
                        sta             CMDP_LINE_REMAIN              ; total stored span count
                        lda             #$01
                        sta             CMDP_REMAIN                   ; current span index
MON_LOAD_PRINT_SPAN_LOOP:
                        lda             CMDP_REMAIN
                        cmp             CMDP_LINE_REMAIN
                        bcs             MON_LOAD_PRINT_START_DONE
                        lda             CMDP_REMAIN
                        asl             a
                        tay
                        lda             LOAD_SPAN_BUF,y
                        sta             CMDP_ADDR_LO
                        iny
                        lda             LOAD_SPAN_BUF,y
                        sta             CMDP_ADDR_HI
                        ldx             #<MSG_LOAD_DONE_SPAN
                        ldy             #>MSG_LOAD_DONE_SPAN
                        jsr             SYS_WRITE_CSTRING
                        lda             CMDP_ADDR_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             CMDP_ADDR_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        inc             CMDP_REMAIN
                        bra             MON_LOAD_PRINT_SPAN_LOOP

MON_LOAD_PRINT_START_NONE:
                        ldx             #<MSG_LOAD_NO_ADDR
                        ldy             #>MSG_LOAD_NO_ADDR
                        jsr             SYS_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
MON_LOAD_PRINT_START_DONE:
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
CMDP_LIT_HELP:           db              "HELP",$00
CMDP_LIT_LOAD:           db              "LOAD",$00
CMDP_LIT_QUIT:           db              "QUIT",$00
MSG_HDR_1:               db              $0d, $0a,"R-YORS command monitor",$00
MSG_HDR_2:               db              "DISPLAY FILL COPY MODIFY HELP LOAD QUIT",$00
MSG_HDR_3:               db              $00
MSG_PROMPT:              db              "cmd> ",$00
MSG_LINE_STATUS:         db              "line status=$",$00
MSG_RETRY:               db              " (retry)",$00
CMDP_MSG_ERR_UNKNOWN:    db              "ERR: unknown command",$00
CMDP_MSG_USAGE_DISPLAY:  db              "usage: DISPLAY <addr16>",$00
CMDP_MSG_USAGE_FILL:     db              "usage: FILL <addr16> <count8> <byte8>",$00
CMDP_MSG_USAGE_COPY:     db              "usage: COPY <src16> <dst16> <count8>",$00
CMDP_MSG_USAGE_MODIFY:   db              "usage: MODIFY <addr16> <byte8> [byte8 ...]",$00
CMDP_MSG_USAGE_HELP:     db              "usage: HELP",$00
CMDP_MSG_USAGE_LOAD:     db              "usage: LOAD [S|S19|S28|S37]",$00
CMDP_MSG_USAGE_QUIT:     db              "usage: QUIT",$00
CMDP_MSG_MOD_OK_1:       db              "modified $",$00
CMDP_MSG_MOD_OK_2:       db              " bytes at $",$00
MSG_HELP_1:              db              "DISPLAY <addr16>",$00
MSG_HELP_2:              db              "FILL <addr16> <count8> <byte8>",$00
MSG_HELP_3:              db              "COPY <src16> <dst16> <count8>",$00
MSG_HELP_4:              db              "MODIFY <addr16> <byte8> [byte8 ...]",$00
MSG_HELP_5:              db              "LOAD [S|S19|S28|S37]",$00
MSG_HELP_6:              db              "QUIT",$00
MSG_LOAD_READY:          db              "LOAD READY: paste S-record lines, end with S7/S8/S9",$00
MSG_LOAD_START_ADDR:     db              "LOAD start @ $",$00
MSG_LOAD_SPAN_ADDR:      db              "LOAD span  @ $",$00
MSG_LOAD_LINE_STATUS:    db              "LOAD line status=$",$00
MSG_LOAD_PARSE_FAIL:     db              "LOAD parse fail type=",$00
MSG_LOAD_DONE_REC:       db              "LOAD OK rec=$",$00
MSG_LOAD_DONE_BYTES:     db              " bytes=$",$00
MSG_LOAD_DONE_START:     db              " start=$",$00
MSG_LOAD_DONE_SPANS:     db              " spans=$",$00
MSG_LOAD_DONE_SPAN:      db              " span @ $",$00
MSG_LOAD_DONE_GO:        db              " go=$",$00
MSG_LOAD_NO_GO:          db              "????",$00
MSG_LOAD_NO_ADDR:        db              "????",$00

                        ENDMOD

                        END

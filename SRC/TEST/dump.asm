                        MODULE          DUMP_APP

                        XDEF            START
                        XDEF            CMD_DUMP
                        XDEF            CMD_MODIFY
                        XDEF            CMD_HELP
                        XDEF            CMD_QUIT

                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            UTL_FIND_CHAR_CSTR
                        XREF            UTL_CHAR_TO_UPPER

CMD_LEN                 EQU             $7B10
CMD_TBL_LEN             EQU             $7B11
CMD_TBL_START           EQU             $7B12
CMD_VEC_LO              EQU             $7B13
CMD_VEC_HI              EQU             $7B14

INPUT_ARG_PTR_LO        EQU             $EC
INPUT_ARG_PTR_HI        EQU             $ED
INPUT_CMD_PTR_LO        EQU             $EE
INPUT_CMD_PTR_HI        EQU             $EF

INPUT_BUF               EQU             $7C00

                        CODE
START:
                        cld
                        jsr             COR_FTDI_INIT
                        jsr             COR_FTDI_FLUSH_RX

?MAIN:
                        ldx             #<MSG_PROMPT
                        ldy             #>MSG_PROMPT
                        jsr             COR_FTDI_WRITE_CSTRING

                        ldx             #<INPUT_BUF
                        ldy             #>INPUT_BUF
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        bcc             ?MAIN

                        ldx             #<INPUT_BUF
                        ldy             #>INPUT_BUF
                        stx             INPUT_CMD_PTR_LO
                        sty             INPUT_CMD_PTR_HI

                        jsr             ?SKIP_CMD_SPACES
                        ldy             #$00
                        lda             (INPUT_CMD_PTR_LO),y
                        beq             ?MAIN

                        lda             #' '
                        ldx             INPUT_CMD_PTR_LO
                        ldy             INPUT_CMD_PTR_HI
                        jsr             UTL_FIND_CHAR_CSTR
                        bcc             ?NO_DELIM_FOUND
                        dec             a
?NO_DELIM_FOUND:
                        sta             CMD_LEN
                        stx             INPUT_ARG_PTR_LO
                        sty             INPUT_ARG_PTR_HI
                        jsr             ?SKIP_ARG_SPACES

                        ldx             #$00
?SCAN_CMD:              stx             CMD_TBL_START
                        lda             CMD_TBL,x
                        beq             ?UNKNOWN_CMD
                        sta             CMD_TBL_LEN
                        cmp             CMD_LEN
                        bne             ?ADV_TO_NEXT

                        inx
                        ldy             #$00
?CMP_LOOP:              lda             (INPUT_CMD_PTR_LO),y
                        jsr             UTL_CHAR_TO_UPPER
                        cmp             CMD_TBL,x
                        bne             ?ADV_TO_NEXT
                        iny
                        inx
                        cpy             CMD_TBL_LEN
                        bne             ?CMP_LOOP

                        lda             CMD_TBL,x
                        sta             CMD_VEC_LO
                        inx
                        lda             CMD_TBL,x
                        sta             CMD_VEC_HI
                        jsr             ?CALL_VEC
                        jmp             ?MAIN

?ADV_TO_NEXT:
                        lda             CMD_TBL_START
                        clc
                        adc             CMD_TBL_LEN
                        clc
                        adc             #$03
                        tax
                        bra             ?SCAN_CMD

?UNKNOWN_CMD:
                        ldx             #<MSG_UNKNOWN
                        ldy             #>MSG_UNKNOWN
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        jmp             ?MAIN

?CALL_VEC:
                        jmp             (CMD_VEC_LO)


?SKIP_CMD_SPACES:
                        ldy             #$00
?SKIP_CMD_LOOP:         lda             (INPUT_CMD_PTR_LO),y
                        cmp             #' '
                        beq             ?SKIP_CMD_ADV
                        cmp             #$09
                        beq             ?SKIP_CMD_ADV
                        rts
?SKIP_CMD_ADV:          inc             INPUT_CMD_PTR_LO
                        bne             ?SKIP_CMD_LOOP
                        inc             INPUT_CMD_PTR_HI
                        bra             ?SKIP_CMD_LOOP

?SKIP_ARG_SPACES:
                        ldy             #$00
?SKIP_ARG_LOOP:         lda             (INPUT_ARG_PTR_LO),y
                        cmp             #' '
                        beq             ?SKIP_ARG_ADV
                        cmp             #$09
                        beq             ?SKIP_ARG_ADV
                        rts
?SKIP_ARG_ADV:          inc             INPUT_ARG_PTR_LO
                        bne             ?SKIP_ARG_LOOP
                        inc             INPUT_ARG_PTR_HI
                        bra             ?SKIP_ARG_LOOP


CMD_DUMP:
                        ldy             #$00
                        lda             (INPUT_ARG_PTR_LO),y
                        beq             ?DUMP_NO_ARG
                        ldx             #<MSG_DUMP_ARG
                        ldy             #>MSG_DUMP_ARG
                        jsr             COR_FTDI_WRITE_CSTRING
                        ldy             #$00
                        lda             (INPUT_ARG_PTR_LO),y
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        rts
?DUMP_NO_ARG:
                        ldx             #<MSG_DUMP_NO_ARG
                        ldy             #>MSG_DUMP_NO_ARG
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

CMD_MODIFY:
                        ldx             #<MSG_MODIFY
                        ldy             #>MSG_MODIFY
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

CMD_HELP:
                        ldx             #<MSG_HELP
                        ldy             #>MSG_HELP
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

CMD_QUIT:
                        brk             $65
                        rts


                        DATA
MSG_PROMPT:             db              "dump> ",$00
MSG_UNKNOWN:            db              "unknown cmd",$00
MSG_DUMP_NO_ARG:        db              "DUMP needs arg",$00
MSG_DUMP_ARG:           db              "DUMP arg[0]=$",$00
MSG_MODIFY:             db              "MODIFY not implemented",$00
MSG_HELP:               db              "DUMP <arg>  MODIFY <arg>  HELP  QUIT",$00

CMD_TBL:
                        db              4,"DUMP"
                        word            CMD_DUMP
                        db              6,"MODIFY"
                        word            CMD_MODIFY
                        db              4,"HELP"
                        word            CMD_HELP
                        db              4,"QUIT"
                        word            CMD_QUIT
                        db              0

                        ENDMOD

                        END

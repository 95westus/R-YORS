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

CMD_LEN                    EQU             $7B10
CMD_TBL_LEN                EQU             $7B11
CMD_TBL_START              EQU             $7B12
CMD_VEC_LO                 EQU             $7B13
CMD_VEC_HI                 EQU             $7B14

INPUT_ARG_PTR_LO           EQU             $EC
INPUT_ARG_PTR_HI           EQU             $ED
INPUT_CMD_PTR_LO           EQU             $EE
INPUT_CMD_PTR_HI           EQU             $EF

INPUT_BUF                  EQU             $7C00

                        CODE
START:
                        CLD
                        JSR             COR_FTDI_INIT
                        JSR             COR_FTDI_FLUSH_RX

?MAIN:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             COR_FTDI_WRITE_CSTRING

                        LDX             #<INPUT_BUF
                        LDY             #>INPUT_BUF
                        JSR             COR_FTDI_READ_CSTRING_ECHO
                        BCC             ?MAIN

                        LDX             #<INPUT_BUF
                        LDY             #>INPUT_BUF
                        STX             INPUT_CMD_PTR_LO
                        STY             INPUT_CMD_PTR_HI

                        JSR             ?SKIP_CMD_SPACES
                        LDY             #$00
                        LDA             (INPUT_CMD_PTR_LO),Y
                        BEQ             ?MAIN

                        LDA             #' '
                        LDX             INPUT_CMD_PTR_LO
                        LDY             INPUT_CMD_PTR_HI
                        JSR             UTL_FIND_CHAR_CSTR
                        BCC             ?NO_DELIM_FOUND
                        DEC             A
?NO_DELIM_FOUND:
                        STA             CMD_LEN
                        STX             INPUT_ARG_PTR_LO
                        STY             INPUT_ARG_PTR_HI
                        JSR             ?SKIP_ARG_SPACES

                        LDX             #$00
?SCAN_CMD:              STX             CMD_TBL_START
                        LDA             CMD_TBL,X
                        BEQ             ?UNKNOWN_CMD
                        STA             CMD_TBL_LEN
                        CMP             CMD_LEN
                        BNE             ?ADV_TO_NEXT

                        INX
                        LDY             #$00
?CMP_LOOP:              LDA             (INPUT_CMD_PTR_LO),Y
                        JSR             UTL_CHAR_TO_UPPER
                        CMP             CMD_TBL,X
                        BNE             ?ADV_TO_NEXT
                        INY
                        INX
                        CPY             CMD_TBL_LEN
                        BNE             ?CMP_LOOP

                        LDA             CMD_TBL,X
                        STA             CMD_VEC_LO
                        INX
                        LDA             CMD_TBL,X
                        STA             CMD_VEC_HI
                        JSR             ?CALL_VEC
                        JMP             ?MAIN

?ADV_TO_NEXT:
                        LDA             CMD_TBL_START
                        CLC
                        ADC             CMD_TBL_LEN
                        CLC
                        ADC             #$03
                        TAX
                        BRA             ?SCAN_CMD

?UNKNOWN_CMD:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JSR             COR_FTDI_WRITE_CSTRING
                        JSR             COR_FTDI_WRITE_CRLF
                        JMP             ?MAIN

?CALL_VEC:
                        JMP             (CMD_VEC_LO)


?SKIP_CMD_SPACES:
                        LDY             #$00
?SKIP_CMD_LOOP:         LDA             (INPUT_CMD_PTR_LO),Y
                        CMP             #' '
                        BEQ             ?SKIP_CMD_ADV
                        CMP             #$09
                        BEQ             ?SKIP_CMD_ADV
                        RTS
?SKIP_CMD_ADV:          INC             INPUT_CMD_PTR_LO
                        BNE             ?SKIP_CMD_LOOP
                        INC             INPUT_CMD_PTR_HI
                        BRA             ?SKIP_CMD_LOOP

?SKIP_ARG_SPACES:
                        LDY             #$00
?SKIP_ARG_LOOP:         LDA             (INPUT_ARG_PTR_LO),Y
                        CMP             #' '
                        BEQ             ?SKIP_ARG_ADV
                        CMP             #$09
                        BEQ             ?SKIP_ARG_ADV
                        RTS
?SKIP_ARG_ADV:          INC             INPUT_ARG_PTR_LO
                        BNE             ?SKIP_ARG_LOOP
                        INC             INPUT_ARG_PTR_HI
                        BRA             ?SKIP_ARG_LOOP


CMD_DUMP:
                        LDY             #$00
                        LDA             (INPUT_ARG_PTR_LO),Y
                        BEQ             ?DUMP_NO_ARG
                        LDX             #<MSG_DUMP_ARG
                        LDY             #>MSG_DUMP_ARG
                        JSR             COR_FTDI_WRITE_CSTRING
                        LDY             #$00
                        LDA             (INPUT_ARG_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_HEX_BYTE
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS
?DUMP_NO_ARG:
                        LDX             #<MSG_DUMP_NO_ARG
                        LDY             #>MSG_DUMP_NO_ARG
                        JSR             COR_FTDI_WRITE_CSTRING
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS

CMD_MODIFY:
                        LDX             #<MSG_MODIFY
                        LDY             #>MSG_MODIFY
                        JSR             COR_FTDI_WRITE_CSTRING
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS

CMD_HELP:
                        LDX             #<MSG_HELP
                        LDY             #>MSG_HELP
                        JSR             COR_FTDI_WRITE_CSTRING
                        JSR             COR_FTDI_WRITE_CRLF
                        RTS

CMD_QUIT:
                        BRK             $65
                        RTS


                        DATA
MSG_PROMPT:             DB              "dump> ",$00
MSG_UNKNOWN:            DB              "unknown cmd",$00
MSG_DUMP_NO_ARG:        DB              "DUMP needs arg",$00
MSG_DUMP_ARG:           DB              "DUMP arg[0]=$",$00
MSG_MODIFY:             DB              "MODIFY not implemented",$00
MSG_HELP: DB "DUMP <arg> MODIFY <arg> HELP QUIT",$00

CMD_TBL:
                        DB              4,"DUMP"
                        WORD            CMD_DUMP
                        DB              6,"MODIFY"
                        WORD            CMD_MODIFY
                        DB              4,"HELP"
                        WORD            CMD_HELP
                        DB              4,"QUIT"
                        WORD            CMD_QUIT
                        DB              0

                        ENDMOD

                        END
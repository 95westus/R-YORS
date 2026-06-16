; ----------------------------------------------------------------------------
; pack40-test.asm
; RAM-loaded PACK40 round-trip proof, linked at $3000.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          PACK40_TEST_APP

                        XDEF            START
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            UTL_PACK40_PACK_CSTR
                        XREF            UTL_PACK40_UNPACK_CSTR

P40T_PTR_LO            EQU             $00
P40T_PTR_HI            EQU             $01
P40T_COUNT             EQU             $02

P40T_CB_SRC_LO         EQU             $00
P40T_CB_SRC_HI         EQU             $01
P40T_CB_DST_LO         EQU             $02
P40T_CB_DST_HI         EQU             $03
P40T_CB_PACKED_LEN     EQU             $04
P40T_CB_CHAR_LEN       EQU             $05

                        CODE

START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             P40T_PRINT_LINE

                        LDX             #<PACK40_PACK_CB
                        LDY             #>PACK40_PACK_CB
                        JSR             UTL_PACK40_PACK_CSTR
                        BCS             ?PACK_OK
                        LDX             #<MSG_PACK_FAIL
                        LDY             #>MSG_PACK_FAIL
                        JMP             P40T_FAIL_LINE

?PACK_OK:
                        STA             PACK40_UNPACK_CB+P40T_CB_PACKED_LEN
                        LDX             #<MSG_PACKED
                        LDY             #>MSG_PACKED
                        JSR             P40T_PRINT
                        JSR             P40T_PRINT_PACKED

                        LDX             #<PACK40_UNPACK_CB
                        LDY             #>PACK40_UNPACK_CB
                        JSR             UTL_PACK40_UNPACK_CSTR
                        BCS             ?UNPACK_OK
                        LDX             #<MSG_UNPACK_FAIL
                        LDY             #>MSG_UNPACK_FAIL
                        JMP             P40T_FAIL_LINE

?UNPACK_OK:
                        JSR             P40T_COMPARE
                        BCS             ?COMPARE_OK
                        LDX             #<MSG_COMPARE_FAIL
                        LDY             #>MSG_COMPARE_FAIL
                        JMP             P40T_FAIL_LINE

?COMPARE_OK:
                        LDX             #<MSG_UNPACKED
                        LDY             #>MSG_UNPACKED
                        JSR             P40T_PRINT
                        LDX             #<PACK40_UNPACK_BUF
                        LDY             #>PACK40_UNPACK_BUF
                        JSR             P40T_PRINT_LINE
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             P40T_PRINT_LINE
                        RTS

P40T_FAIL_LINE:
                        JSR             P40T_PRINT_LINE
                        RTS

P40T_PRINT_PACKED:
                        LDA             PACK40_PACK_CB+P40T_CB_PACKED_LEN
                        STA             P40T_COUNT
                        LDA             #<PACK40_PACK_BUF
                        STA             P40T_PTR_LO
                        LDA             #>PACK40_PACK_BUF
                        STA             P40T_PTR_HI
?LOOP:
                        LDA             P40T_COUNT
                        BEQ             ?DONE
                        LDY             #$00
                        LDA             (P40T_PTR_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        INC             P40T_PTR_LO
                        BNE             ?COUNT
                        INC             P40T_PTR_HI
?COUNT:
                        DEC             P40T_COUNT
                        BRA             ?LOOP
?DONE:
                        JMP             SYS_WRITE_CRLF

P40T_COMPARE:
                        LDA             #<PACK40_EXPECT
                        STA             P40T_PTR_LO
                        LDA             #>PACK40_EXPECT
                        STA             P40T_PTR_HI
                        LDY             #$00
?LOOP:
                        LDA             (P40T_PTR_LO),Y
                        CMP             PACK40_UNPACK_BUF,Y
                        BNE             ?FAIL
                        CMP             #$00
                        BEQ             ?OK
                        INY
                        BNE             ?LOOP
?FAIL:
                        CLC
                        RTS
?OK:
                        SEC
                        RTS

P40T_PRINT_LINE:
                        JSR             SYS_WRITE_CSTRING
                        JMP             SYS_WRITE_CRLF

P40T_PRINT:
                        JMP             SYS_WRITE_CSTRING

PACK40_PACK_CB:
                        DB              <PACK40_SOURCE,>PACK40_SOURCE
                        DB              <PACK40_PACK_BUF,>PACK40_PACK_BUF
                        DB              $00,$00

PACK40_UNPACK_CB:
                        DB              <PACK40_PACK_BUF,>PACK40_PACK_BUF
                        DB              <PACK40_UNPACK_BUF,>PACK40_UNPACK_BUF
                        DB              $00,$00

PACK40_SOURCE:
                        DB              "asm_asm.in_asm?PACK40X",0
PACK40_EXPECT:
                        DB              "ASM_ASM.IN_ASM?PACK40X",0

PACK40_PACK_BUF:
                        DS              $20
PACK40_UNPACK_BUF:
                        DS              $20

MSG_TITLE:             DB              "PACK40 TEST",0
MSG_PACKED:            DB              "PACKED=",0
MSG_UNPACKED:          DB              "UNPACKED=",0
MSG_PACK_FAIL:         DB              "FAIL PACK",0
MSG_UNPACK_FAIL:       DB              "FAIL UNPACK",0
MSG_COMPARE_FAIL:      DB              "FAIL COMPARE",0
MSG_OK:                DB              "OK",0

                        ENDMOD
                        END

; ----------------------------------------------------------------------------
; asm-v1-runtime-smoke.asm
; RAM-loaded smoke wrapper for the stripped ASM v1 runtime.
;
; Link this wrapper before asm-v1-runtime.obj so START remains at $2000 while
; the runtime is reached only through exported callable routines.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_RUNTIME_SMOKE_APP

                        XDEF            START

                        XREF            ASM_BEGIN
                        XREF            ASM_ASSEMBLE_LINE
                        XREF            ASM_END
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE

ASM_BEGINF_HAVE_PC     EQU             $01
ASMRT_TARGET_LO        EQU             $00
ASMRT_TARGET_HI        EQU             $70
ASMRT_RESULT           EQU             $67F0
ASMRT_CODE_LEN         EQU             $14
ASMRT_JSR_LO           EQU             $03
ASMRT_JSR_HI           EQU             $04
ASMRT_TAIL_LO          EQU             $12
ASMRT_TAIL_HI          EQU             $13

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMRT_PRINT_LINE

                        JSR             ASMRT_RUN
                        BCS             ASMRT_PASS

                        STA             ASMRT_RESULT
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JSR             ASMRT_PRINT
                        LDA             ASMRT_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS

ASMRT_PASS:
                        LDA             #$AC
                        STA             ASMRT_RESULT
                        LDX             #<MSG_PASS
                        LDY             #>MSG_PASS
                        JSR             ASMRT_PRINT_LINE
                        SEC
                        RTS

ASMRT_RUN:
                        STZ             $7000
                        STZ             $7001
                        STZ             $7002
                        STZ             $7003
                        STZ             $7004
                        STZ             $7005
                        STZ             $7006
                        STZ             $7007
                        STZ             $7008
                        STZ             $7009
                        STZ             $700A
                        STZ             $700B
                        STZ             $700C
                        STZ             $700D
                        STZ             $700E
                        STZ             $700F
                        STZ             $7010
                        STZ             $7011
                        STZ             $7012
                        STZ             $7013
                        STZ             $7101
                        STZ             $7102

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASMRT_TARGET_LO
                        LDY             #ASMRT_TARGET_HI
                        JSR             ASM_BEGIN
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_ORG
                        LDY             #>LINE_ORG
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_LDA
                        LDY             #>LINE_LDA
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_JSR_HEX_NIB
                        LDY             #>LINE_JSR_HEX_NIB
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_STA
                        LDY             #>LINE_STA
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_LDA_B
                        LDY             #>LINE_LDA_B
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_JSR_TAIL
                        LDY             #>LINE_JSR_TAIL
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_STA_B
                        LDY             #>LINE_STA_B
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_RTS
                        LDY             #>LINE_RTS
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_TAIL_JMP
                        LDY             #>LINE_TAIL_JMP
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        LDX             #<LINE_END
                        LDY             #>LINE_END
                        JSR             ASM_ASSEMBLE_LINE
                        BCC             ASMRT_RETURN_FAIL

                        JSR             ASM_END
                        BCC             ASMRT_RETURN_FAIL

                        JSR             ASMRT_CHECK_BYTES
ASMRT_RETURN_FAIL:
                        RTS

ASMRT_CHECK_BYTES:
                        LDA             $7000+ASMRT_JSR_LO
                        CMP             #$FF
                        BNE             ASMRT_JSR_NOT_FFFF
                        LDA             $7000+ASMRT_JSR_HI
                        CMP             #$FF
                        BEQ             ASMRT_BAD_JOIN
ASMRT_JSR_NOT_FFFF:
                        LDA             $7000+ASMRT_JSR_HI
                        BEQ             ASMRT_BAD_JOIN
                        STA             EXPECT_IMAGE+ASMRT_JSR_HI
                        LDA             $7000+ASMRT_JSR_LO
                        STA             EXPECT_IMAGE+ASMRT_JSR_LO

                        LDA             $7000+ASMRT_TAIL_LO
                        CMP             #$FF
                        BNE             ASMRT_TAIL_NOT_FFFF
                        LDA             $7000+ASMRT_TAIL_HI
                        CMP             #$FF
                        BEQ             ASMRT_BAD_JOIN
ASMRT_TAIL_NOT_FFFF:
                        LDA             $7000+ASMRT_TAIL_HI
                        BEQ             ASMRT_BAD_JOIN
                        STA             EXPECT_IMAGE+ASMRT_TAIL_HI
                        LDA             $7000+ASMRT_TAIL_LO
                        STA             EXPECT_IMAGE+ASMRT_TAIL_LO

                        LDX             #$00
ASMRT_CHECK_IMAGE_LOOP:
                        LDA             $7000,X
                        CMP             EXPECT_IMAGE,X
                        BNE             ASMRT_BAD_IMAGE
                        INX
                        CPX             #ASMRT_CODE_LEN
                        BNE             ASMRT_CHECK_IMAGE_LOOP

                        JSR             $7000
                        LDA             $7101
                        CMP             #'A'
                        BNE             ASMRT_BAD_OUTPUT_A
                        LDA             $7102
                        CMP             #'B'
                        BNE             ASMRT_BAD_OUTPUT_B
                        LDA             #$00
                        SEC
                        RTS

ASMRT_BAD_JOIN:
                        LDA             #$E3
                        CLC
                        RTS
ASMRT_BAD_IMAGE:
                        LDA             #$E4
                        CLC
                        RTS
ASMRT_BAD_OUTPUT_A:
                        LDA             #$E5
                        CLC
                        RTS
ASMRT_BAD_OUTPUT_B:
                        LDA             #$E6
                        CLC
                        RTS

ASMRT_PRINT_LINE:
                        JSR             ASMRT_PRINT
                        JMP             SYS_WRITE_CRLF

ASMRT_PRINT:
                        JMP             SYS_WRITE_CSTRING

                        DATA
MSG_TITLE:              DB              "ASM RT SMOKE",0
MSG_PASS:               DB              "ASM RT OK",0
MSG_FAIL:               DB              "ASM RT FAIL $",0
LINE_ORG:               DB              "ORG $7000",0
LINE_LDA:               DB              "LDA #$0A",0
LINE_JSR_HEX_NIB:       DB              "LABEL: JSR UTL_HEX_NIBBLE_TO_ASCII",0
LINE_STA:               DB              "STA $7101",0
LINE_LDA_B:             DB              "LDA #$0B",0
LINE_JSR_TAIL:          DB              "JSR TAIL",0
LINE_STA_B:             DB              "STA $7102",0
LINE_RTS:               DB              "RTS",0
LINE_TAIL_JMP:          DB              "TAIL JMP UTL_HEX_NIBBLE_TO_ASCII",0
LINE_END:               DB              "END",0
EXPECT_IMAGE:           DB              $A9,$0A,$20,$FF,$FF,$8D,$01,$71
                        DB              $A9,$0B,$20,$11,$70,$8D,$02,$71
                        DB              $60,$4C,$FF,$FF

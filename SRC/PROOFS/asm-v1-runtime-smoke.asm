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
                        STZ             $7101

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

                        LDX             #<LINE_RTS
                        LDY             #>LINE_RTS
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
                        LDA             $7000
                        CMP             #$A9
                        BNE             ASMRT_BAD_0
                        LDA             $7001
                        CMP             #$0A
                        BNE             ASMRT_BAD_1
                        LDA             $7002
                        CMP             #$20
                        BNE             ASMRT_BAD_2
                        LDA             $7003
                        CMP             #$FF
                        BNE             ASMRT_JOIN_LO_OK
                        LDA             $7004
                        CMP             #$FF
                        BEQ             ASMRT_BAD_3
ASMRT_JOIN_LO_OK:
                        LDA             $7005
                        CMP             #$8D
                        BNE             ASMRT_BAD_4
                        LDA             $7006
                        CMP             #$01
                        BNE             ASMRT_BAD_5
                        LDA             $7007
                        CMP             #$71
                        BNE             ASMRT_BAD_6
                        LDA             $7008
                        CMP             #$60
                        BNE             ASMRT_BAD_7
                        JSR             $7000
                        LDA             $7101
                        CMP             #'A'
                        BNE             ASMRT_BAD_8
                        LDA             #$00
                        SEC
                        RTS

ASMRT_BAD_0:
                        LDA             #$E0
                        CLC
                        RTS
ASMRT_BAD_1:
                        LDA             #$E1
                        CLC
                        RTS
ASMRT_BAD_2:
                        LDA             #$E2
                        CLC
                        RTS
ASMRT_BAD_3:
                        LDA             #$E3
                        CLC
                        RTS
ASMRT_BAD_4:
                        LDA             #$E4
                        CLC
                        RTS
ASMRT_BAD_5:
                        LDA             #$E5
                        CLC
                        RTS
ASMRT_BAD_6:
                        LDA             #$E6
                        CLC
                        RTS
ASMRT_BAD_7:
                        LDA             #$E7
                        CLC
                        RTS
ASMRT_BAD_8:
                        LDA             #$E8
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
LINE_RTS:               DB              "RTS",0
LINE_END:               DB              "END",0

; ----------------------------------------------------------------------------
; asm-v1-runtime-asmtest.asm
; RAM-loaded ASMTEST_3000 wrapper for the stripped ASM v1 runtime.
;
; Link this wrapper before asm-v1-runtime.obj so START remains at $2000 while
; the runtime is reached only through exported callable routines.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_RUNTIME_ASMTEST_APP

                        XDEF            START

                        XREF            ASM_BEGIN
                        XREF            ASM_ASSEMBLE_LINE
                        XREF            ASM_END
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE

ASM_BEGINF_HAVE_PC     EQU             $01
ASMRA_TARGET_LO        EQU             $00
ASMRA_TARGET_HI        EQU             $70
ASMRA_RESULT           EQU             $67F1
ASMRA_CODE_LEN         EQU             $27
ASMRA_OUT_LEN          EQU             $10
ASMRA_LINE_COUNT       EQU             $11

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMRA_PRINT_LINE

                        JSR             ASMRA_RUN
                        BCS             ASMRA_PASS

                        STA             ASMRA_RESULT
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JSR             ASMRA_PRINT
                        LDA             ASMRA_RESULT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS

ASMRA_PASS:
                        LDA             #$AC
                        STA             ASMRA_RESULT
                        LDX             #<MSG_PASS
                        LDY             #>MSG_PASS
                        JSR             ASMRA_PRINT_LINE
                        SEC
                        RTS

ASMRA_RUN:
                        JSR             ASMRA_CLEAR_TARGETS

                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #ASMRA_TARGET_LO
                        LDY             #ASMRA_TARGET_HI
                        JSR             ASM_BEGIN
                        BCS             ASMRA_BEGIN_OK
                        RTS
ASMRA_BEGIN_OK:
                        LDX             #$00
ASMRA_LINE_LOOP:
                        LDA             LINE_PTR_LO,X
                        STA             ASMRA_LINE_LO
                        LDA             LINE_PTR_HI,X
                        STA             ASMRA_LINE_HI
                        PHX
                        LDX             ASMRA_LINE_LO
                        LDY             ASMRA_LINE_HI
                        JSR             ASM_ASSEMBLE_LINE
                        PLX
                        BCS             ASMRA_LINE_OK
                        RTS
ASMRA_LINE_OK:
                        INX
                        CPX             #ASMRA_LINE_COUNT
                        BNE             ASMRA_LINE_LOOP

                        JSR             ASM_END
                        BCS             ASMRA_END_OK
                        RTS
ASMRA_END_OK:

                        JSR             ASMRA_CHECK_IMAGE
                        BCS             ASMRA_IMAGE_OK
                        RTS
ASMRA_IMAGE_OK:

                        JSR             $7000

                        JSR             ASMRA_CHECK_OUTPUT
                        BCS             ASMRA_OUTPUT_OK
                        RTS
ASMRA_OUTPUT_OK:

                        LDA             #$00
                        SEC
                        RTS

ASMRA_CLEAR_TARGETS:
                        LDX             #ASMRA_CODE_LEN
ASMRA_CLEAR_CODE_LOOP:
                        STZ             $7000,X
                        DEX
                        BPL             ASMRA_CLEAR_CODE_LOOP

                        LDX             #ASMRA_OUT_LEN
ASMRA_CLEAR_OUT_LOOP:
                        STZ             $7100,X
                        DEX
                        BPL             ASMRA_CLEAR_OUT_LOOP
                        RTS

ASMRA_CHECK_IMAGE:
                        LDX             #$00
ASMRA_CHECK_IMAGE_LOOP:
                        LDA             $7000,X
                        CMP             EXPECT_IMAGE,X
                        BNE             ASMRA_BAD_IMAGE
                        INX
                        CPX             #ASMRA_CODE_LEN
                        BNE             ASMRA_CHECK_IMAGE_LOOP

                        LDA             $7027
                        BNE             ASMRA_BAD_TRAIL
                        SEC
                        RTS

ASMRA_CHECK_OUTPUT:
                        LDX             #$00
ASMRA_CHECK_OUTPUT_LOOP:
                        LDA             $7100,X
                        CMP             EXPECT_OUTPUT,X
                        BNE             ASMRA_BAD_OUTPUT
                        INX
                        CPX             #ASMRA_OUT_LEN
                        BNE             ASMRA_CHECK_OUTPUT_LOOP

                        LDA             $7110
                        CMP             #$0F
                        BNE             ASMRA_BAD_SUM
                        SEC
                        RTS

ASMRA_BAD_IMAGE:
                        LDA             #$E0
                        CLC
                        RTS
ASMRA_BAD_TRAIL:
                        LDA             #$E1
                        CLC
                        RTS
ASMRA_BAD_OUTPUT:
                        LDA             #$E2
                        CLC
                        RTS
ASMRA_BAD_SUM:
                        LDA             #$E3
                        CLC
                        RTS

ASMRA_PRINT_LINE:
                        JSR             ASMRA_PRINT
                        JMP             SYS_WRITE_CRLF

ASMRA_PRINT:
                        JMP             SYS_WRITE_CSTRING

                        DATA
MSG_TITLE:              DB              "ASM RT ASMTEST",0
MSG_PASS:               DB              "ASM RT ASMTEST OK",0
MSG_FAIL:               DB              "ASM RT ASMTEST FAIL $",0

ASMRA_LINE_LO:          DB              $00
ASMRA_LINE_HI:          DB              $00

LINE_ORG:               DB              "ORG $7000",0
LINE_OUT_EQU:           DB              "OUT EQU $7100",0
LINE_SUM_EQU:           DB              "SUM EQU $7110",0
LINE_COUNT_EQU:         DB              "COUNT EQU 16",0
LINE_LDX:               DB              "ASMTEST LDX #0",0
LINE_STZ:               DB              "STZ SUM",0
LINE_LOOP_LDA:          DB              "LOOP LDA SEED,X",0
LINE_STA_OUT_X:         DB              "STA OUT,X",0
LINE_EOR_SUM:           DB              "EOR SUM",0
LINE_STA_SUM:           DB              "STA SUM",0
LINE_INX:               DB              "INX",0
LINE_CPX:               DB              "CPX #COUNT",0
LINE_BNE:               DB              "BNE LOOP",0
LINE_RTS:               DB              "RTS",0
LINE_SEED_DB:           DB              "SEED DB $52,$2D,$59,$4F,$52,$53,$20,$41",0
LINE_DB_CONT:           DB              "DB $53,$4D,$20,$54,$45,$53,$54,$2E",0
LINE_END:               DB              "END",0

LINE_PTR_LO:            DB              <LINE_ORG,<LINE_OUT_EQU,<LINE_SUM_EQU
                        DB              <LINE_COUNT_EQU,<LINE_LDX,<LINE_STZ
                        DB              <LINE_LOOP_LDA,<LINE_STA_OUT_X
                        DB              <LINE_EOR_SUM,<LINE_STA_SUM,<LINE_INX
                        DB              <LINE_CPX,<LINE_BNE,<LINE_RTS
                        DB              <LINE_SEED_DB,<LINE_DB_CONT,<LINE_END
LINE_PTR_HI:            DB              >LINE_ORG,>LINE_OUT_EQU,>LINE_SUM_EQU
                        DB              >LINE_COUNT_EQU,>LINE_LDX,>LINE_STZ
                        DB              >LINE_LOOP_LDA,>LINE_STA_OUT_X
                        DB              >LINE_EOR_SUM,>LINE_STA_SUM,>LINE_INX
                        DB              >LINE_CPX,>LINE_BNE,>LINE_RTS
                        DB              >LINE_SEED_DB,>LINE_DB_CONT,>LINE_END

EXPECT_IMAGE:           DB              $A2,$00,$9C,$10,$71,$BD,$17,$70
                        DB              $9D,$00,$71,$4D,$10,$71,$8D,$10
                        DB              $71,$E8,$E0,$10,$D0,$EF,$60,$52
                        DB              $2D,$59,$4F,$52,$53,$20,$41,$53
                        DB              $4D,$20,$54,$45,$53,$54,$2E
EXPECT_OUTPUT:          DB              $52,$2D,$59,$4F,$52,$53,$20,$41
                        DB              $53,$4D,$20,$54,$45,$53,$54,$2E

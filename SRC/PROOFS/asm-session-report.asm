; ----------------------------------------------------------------------------
; asm-session-report.asm
; External ASM v1 live-session reporter, linked at $7000.
;
; This program does not link against asm-v1-core.obj.  It reads the flash ASM
; UDATA addresses generated from asm-v1-flash-8000.map, so it reports the live
; session left behind by the flash-resident ASM command.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_SESSION_REPORT_APP

                        XDEF            START

                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE

                        INCLUDE         "asm-session-report.inc"

ASMR_PTR_LO            EQU             $00
ASMR_PTR_HI            EQU             $01
ASMR_SLOT              EQU             $02
ASMR_COUNT             EQU             $03
ASMR_TMP               EQU             $04

                        CODE

START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             ASMR_PRINT_LINE
                        JSR             ASMR_PRINT_MAP
                        JSR             ASMR_PRINT_SESSION
                        JSR             ASMR_PRINT_SYMBOL_TABLE
                        JSR             ASMR_PRINT_FIXUP_TABLE
                        JSR             ASMR_PRINT_RELOC_TABLE
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             ASMR_PRINT_LINE
                        RTS

ASMR_PRINT_MAP:
                        LDX             #<MSG_MAP
                        LDY             #>MSG_MAP
                        JSR             ASMR_PRINT
                        LDA             #>_END_DATA
                        LDX             #<_END_DATA
                        JSR             ASMR_PRINT_WORD
                        LDX             #<MSG_UDATA
                        LDY             #>MSG_UDATA
                        JSR             ASMR_PRINT
                        LDA             #>_BEG_UDATA
                        LDX             #<_BEG_UDATA
                        JSR             ASMR_PRINT_WORD
                        LDA             #'-'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #>_END_UDATA
                        LDX             #<_END_UDATA
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_SESSION:
                        LDX             #<MSG_SESSION
                        LDY             #>MSG_SESSION
                        JSR             ASMR_PRINT_LINE
                        LDX             #<MSG_STATE
                        LDY             #>MSG_STATE
                        JSR             ASMR_PRINT
                        LDA             ASM_SESSION_STATE
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_LAST_STATUS
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_LINE_COUNT_HI
                        LDX             ASM_LINE_COUNT_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_START_PC_HI
                        LDX             ASM_START_PC_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_PC_HI
                        LDX             ASM_PC_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_HIGH_PC_HI
                        LDX             ASM_HIGH_PC_LO
                        JSR             ASMR_PRINT_WORD
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_SEAL
                        LDY             #>MSG_SEAL
                        JSR             ASMR_PRINT
                        LDA             ASM_SEAL_FLAGS
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_SEAL_BASE_HI
                        LDX             ASM_SEAL_BASE_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_SEAL_END_HI
                        LDX             ASM_SEAL_END_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_SEAL_LEN_HI
                        LDX             ASM_SEAL_LEN_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_SEAL_FNV3
                        LDX             ASM_SEAL_FNV2
                        JSR             ASMR_PRINT_WORD
                        LDA             ASM_SEAL_FNV1
                        LDX             ASM_SEAL_FNV0
                        JSR             ASMR_PRINT_WORD
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_COUNTS
                        LDY             #>MSG_COUNTS
                        JSR             ASMR_PRINT
                        LDA             ASM_SYM_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_FIX_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_RELOC_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_EXPORT_REC_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_IMPORT_REC_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_IMPORT_RESOLVE_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDA             ASM_RELOCATE_COUNT
                        JSR             ASMR_PRINT_BYTE_FIELD
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_PACKAGE
                        LDY             #>MSG_PACKAGE
                        JSR             ASMR_PRINT
                        LDA             ASM_PACKAGE_BASE_HI
                        LDX             ASM_PACKAGE_BASE_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_PACKAGE_LEN_HI
                        LDX             ASM_PACKAGE_LEN_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_PACKAGE_BODY_LEN_HI
                        LDX             ASM_PACKAGE_BODY_LEN_LO
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDA             ASM_INSTALL_BASE_HI
                        LDX             ASM_INSTALL_BASE_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_SYMBOL_TABLE:
                        LDX             #<MSG_SYMBOLS
                        LDY             #>MSG_SYMBOLS
                        JSR             ASMR_PRINT_LINE
                        LDX             #<MSG_SYM_HEAD
                        LDY             #>MSG_SYM_HEAD
                        JSR             ASMR_PRINT_LINE
                        LDX             #$00
ASMR_PRINT_SYMBOL_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASMR_PRINT_SYMBOL_DONE
                        JSR             ASMR_PRINT_SYMBOL_ROW
                        LDX             ASMR_SLOT
                        INX
                        BRA             ASMR_PRINT_SYMBOL_LOOP
ASMR_PRINT_SYMBOL_DONE:
                        RTS

ASMR_PRINT_SYMBOL_ROW:
                        STX             ASMR_SLOT
                        TXA
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_STATE,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDY             ASMR_SLOT
                        LDA             ASM_SYM_VAL_HI,Y
                        LDX             ASM_SYM_VAL_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        JSR             ASMR_PRINT_SPACE
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_KIND,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_WIDTH,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_FLAGS,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDY             ASMR_SLOT
                        LDA             ASM_SYM_DEFLINE_HI,Y
                        LDX             ASM_SYM_DEFLINE_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_USECNT,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        JSR             ASMR_PRINT_SPACE
                        LDY             ASMR_SLOT
                        LDA             ASM_SYM_FIRSTREF_HI,Y
                        LDX             ASM_SYM_FIRSTREF_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        JSR             ASMR_PRINT_SPACE
                        LDX             ASMR_SLOT
                        JSR             ASMR_SET_SYM_NAME_PTR_X
                        JMP             ASMR_PRINT_PTR_LINE

ASMR_PRINT_FIXUP_TABLE:
                        LDX             #<MSG_FIXUPS
                        LDY             #>MSG_FIXUPS
                        JSR             ASMR_PRINT_LINE
                        LDX             #<MSG_FIX_HEAD
                        LDY             #>MSG_FIX_HEAD
                        JSR             ASMR_PRINT_LINE
                        LDX             #$00
ASMR_PRINT_FIXUP_LOOP:
                        CPX             ASM_FIX_COUNT
                        BEQ             ASMR_PRINT_FIXUP_DONE
                        JSR             ASMR_PRINT_FIXUP_ROW
                        LDX             ASMR_SLOT
                        INX
                        BRA             ASMR_PRINT_FIXUP_LOOP
ASMR_PRINT_FIXUP_DONE:
                        RTS

ASMR_PRINT_FIXUP_ROW:
                        STX             ASMR_SLOT
                        TXA
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_FIX_STATE,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_FIX_MODE,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        JSR             ASMR_PRINT_SPACE
                        JSR             ASMR_PRINT_SPACE
                        LDX             ASMR_SLOT
                        LDA             ASM_FIX_SEL,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        JSR             ASMR_PRINT_SPACE
                        LDY             ASMR_SLOT
                        LDA             ASM_FIX_SITE_HI,Y
                        LDX             ASM_FIX_SITE_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDY             ASMR_SLOT
                        LDA             ASM_FIX_BASE_HI,Y
                        LDX             ASM_FIX_BASE_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDX             ASMR_SLOT
                        JSR             ASMR_SET_FIX_NAME_PTR_X
                        JMP             ASMR_PRINT_PTR_LINE

ASMR_PRINT_RELOC_TABLE:
                        LDX             #<MSG_RELOCS
                        LDY             #>MSG_RELOCS
                        JSR             ASMR_PRINT_LINE
                        LDX             #<MSG_RELOC_HEAD
                        LDY             #>MSG_RELOC_HEAD
                        JSR             ASMR_PRINT_LINE
                        LDX             #$00
ASMR_PRINT_RELOC_LOOP:
                        CPX             ASM_RELOC_COUNT
                        BEQ             ASMR_PRINT_RELOC_DONE
                        JSR             ASMR_PRINT_RELOC_ROW
                        LDX             ASMR_SLOT
                        INX
                        BRA             ASMR_PRINT_RELOC_LOOP
ASMR_PRINT_RELOC_DONE:
                        RTS

ASMR_PRINT_RELOC_ROW:
                        STX             ASMR_SLOT
                        TXA
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDX             ASMR_SLOT
                        LDA             ASM_RELOC_KIND,X
                        JSR             ASMR_PRINT_BYTE_FIELD
                        LDY             ASMR_SLOT
                        LDA             ASM_RELOC_SITE_HI,Y
                        LDX             ASM_RELOC_SITE_LO,Y
                        JSR             ASMR_PRINT_WORD_FIELD
                        LDY             ASMR_SLOT
                        LDA             ASM_RELOC_TARGET_HI,Y
                        LDX             ASM_RELOC_TARGET_LO,Y
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_SET_SYM_NAME_PTR_X:
                        STX             ASMR_COUNT
                        LDA             #<ASM_SYM_NAMES
                        STA             ASMR_PTR_LO
                        LDA             #>ASM_SYM_NAMES
                        STA             ASMR_PTR_HI
                        LDX             ASMR_COUNT
                        BRA             ASMR_ADD_NAME_STRIDE

ASMR_SET_FIX_NAME_PTR_X:
                        STX             ASMR_COUNT
                        LDA             #<ASM_FIX_NAME_TEXT
                        STA             ASMR_PTR_LO
                        LDA             #>ASM_FIX_NAME_TEXT
                        STA             ASMR_PTR_HI
                        LDX             ASMR_COUNT
ASMR_ADD_NAME_STRIDE:
                        BEQ             ASMR_NAME_PTR_DONE
ASMR_ADD_NAME_LOOP:
                        CLC
                        LDA             ASMR_PTR_LO
                        ADC             #ASM_REPORT_SYM_NAME_MAX
                        STA             ASMR_PTR_LO
                        LDA             ASMR_PTR_HI
                        ADC             #$00
                        STA             ASMR_PTR_HI
                        DEX
                        BNE             ASMR_ADD_NAME_LOOP
ASMR_NAME_PTR_DONE:
                        RTS

ASMR_PRINT_BYTE_FIELD:
                        JSR             SYS_WRITE_HEX_BYTE
ASMR_PRINT_SPACE:
                        LDA             #' '
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

ASMR_PRINT_WORD_FIELD:
                        JSR             ASMR_PRINT_WORD
                        BRA             ASMR_PRINT_SPACE

ASMR_PRINT_WORD:
                        STX             ASMR_TMP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             ASMR_TMP
                        JMP             SYS_WRITE_HEX_BYTE

ASMR_PRINT_PTR_LINE:
                        LDX             ASMR_PTR_LO
                        LDY             ASMR_PTR_HI
                        JSR             SYS_WRITE_CSTRING
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_LINE:
                        JSR             ASMR_PRINT
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT:
                        JMP             SYS_WRITE_CSTRING

                        DATA

MSG_TITLE:             DB              "ASM SESSION REPORT",0
MSG_MAP:               DB              "MAP END=$",0
MSG_UDATA:             DB              " UDATA=$",0
MSG_SESSION:           DB              "SESSION",0
MSG_STATE:             DB              "ST LAST LINES START PC HIGH ",0
MSG_SEAL:              DB              "SEAL FL BASE END LEN FNV ",0
MSG_COUNTS:            DB              "COUNTS SYM FIX REL EXP IMP IMPRES RELCNT ",0
MSG_PACKAGE:           DB              "PKG @ LEN BODY INST ",0
MSG_SYMBOLS:           DB              "SYMBOLS",0
MSG_SYM_HEAD:          DB              "SL ST VALUE K  W  FL DEF  USE FIRST NAME",0
MSG_FIXUPS:            DB              "FIXUPS",0
MSG_FIX_HEAD:          DB              "SL ST MODE SEL SITE BASE NAME",0
MSG_RELOCS:            DB              "RELOCS",0
MSG_RELOC_HEAD:        DB              "SL K  SITE TARG",0
MSG_DONE:              DB              "ASM REPORT OK",0

                        ENDMOD
                        END

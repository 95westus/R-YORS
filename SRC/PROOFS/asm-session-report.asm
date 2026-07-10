; ----------------------------------------------------------------------------
; asm-session-report.asm
; External ASM v1 live-session reporter, linked at $7000.
;
; This program does not link against asm-v1-core.obj.  It reads the flash ASM
; UDATA addresses generated from asm-v1-flash-8000.map and uses ASM-F2's
; resident output helper entry points, so it reports the live session left
; behind by the flash-resident ASM command without carrying another print
; library copy in the package body.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_SESSION_REPORT_APP

                        XDEF            START

                        INCLUDE         "asm-session-report.inc"

BIO_FTDI_WRITE_BYTE_BLOCK EQU             ASM_RJ_WRITE_BYTE
SYS_WRITE_CSTRING        EQU             ASM_RJ_WRITE_CSTRING
SYS_WRITE_CRLF           EQU             ASM_RJ_PRINT_CRLF
SYS_WRITE_HEX_BYTE       EQU             ASM_RJ_WRITE_HEX_BYTE

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
                        JSR             ASMR_PRINT_COMPACT
                        JSR             ASMR_PRINT_MAP
                        JSR             ASMR_PRINT_SEAL
                        JSR             ASMR_PRINT_COUNTS
                        JSR             ASMR_PRINT_PACKAGE
                        JSR             ASMR_PRINT_USED
                        JSR             ASMR_PRINT_UNUSED
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

ASMR_PRINT_COMPACT:
                        JSR             ASMR_PRINT_STATUS
                        JSR             ASMR_PRINT_ERRLINE
                        JSR             ASMR_PRINT_START
                        JSR             ASMR_PRINT_PC
                        JSR             ASMR_PRINT_HIGH
                        JSR             ASMR_PRINT_BYTES
                        JSR             ASMR_PRINT_LINES
                        JSR             ASMR_PRINT_SYMS
                        JSR             ASMR_PRINT_FIXUPS
                        JSR             ASMR_PRINT_REFS
                        JMP             ASMR_PRINT_TRUNC

ASMR_PRINT_STATUS:
                        LDX             #<MSG_STATUS
                        LDY             #>MSG_STATUS
                        JSR             ASMR_PRINT
                        LDA             ASM_LAST_STATUS
                        BEQ             ASMR_PRINT_STATUS_OK
                        LDA             #'$'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             ASM_LAST_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF
ASMR_PRINT_STATUS_OK:
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             ASMR_PRINT_LINE

ASMR_PRINT_ERRLINE:
                        LDX             #<MSG_ERRLINE
                        LDY             #>MSG_ERRLINE
                        JSR             ASMR_PRINT
                        LDA             ASM_LAST_STATUS
                        BEQ             ASMR_PRINT_ERRLINE_ZERO
                        LDA             ASM_LINE_COUNT_HI
                        LDX             ASM_LINE_COUNT_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF
ASMR_PRINT_ERRLINE_ZERO:
                        LDA             #$00
                        LDX             #$00
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_START:
                        LDX             #<MSG_START
                        LDY             #>MSG_START
                        JSR             ASMR_PRINT
                        LDA             ASM_START_PC_HI
                        LDX             ASM_START_PC_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_PC:
                        LDX             #<MSG_PC
                        LDY             #>MSG_PC
                        JSR             ASMR_PRINT
                        LDA             ASM_PC_HI
                        LDX             ASM_PC_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_HIGH:
                        LDX             #<MSG_HIGH
                        LDY             #>MSG_HIGH
                        JSR             ASMR_PRINT
                        LDA             ASM_HIGH_PC_HI
                        LDX             ASM_HIGH_PC_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_BYTES:
                        LDX             #<MSG_BYTES
                        LDY             #>MSG_BYTES
                        JSR             ASMR_PRINT
                        LDA             ASM_HIGH_PC_LO
                        SEC
                        SBC             ASM_START_PC_LO
                        STA             ASMR_TMP
                        LDA             ASM_HIGH_PC_HI
                        SBC             ASM_START_PC_HI
                        LDX             ASMR_TMP
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_LINES:
                        LDX             #<MSG_LINES
                        LDY             #>MSG_LINES
                        JSR             ASMR_PRINT
                        LDA             ASM_LINE_COUNT_HI
                        LDX             ASM_LINE_COUNT_LO
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_SYMS:
                        LDX             #<MSG_SYMS
                        LDY             #>MSG_SYMS
                        JSR             ASMR_PRINT
                        LDA             ASM_SYM_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             ASMR_PRINT_LIMIT_SEP
                        LDA             #<ASM_SYM_MAX
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_FIXUPS:
                        LDX             #<MSG_FIXUPS_COUNT
                        LDY             #>MSG_FIXUPS_COUNT
                        JSR             ASMR_PRINT
                        LDA             ASM_FIX_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             ASMR_PRINT_LIMIT_SEP
                        LDA             #<ASM_FIX_MAX
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_REFS:
                        LDX             #<MSG_REFS
                        LDY             #>MSG_REFS
                        JSR             ASMR_PRINT
                        LDA             ASM_REF_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             ASMR_PRINT_LIMIT_SEP
                        LDA             #<ASM_REF_MAX
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_TRUNC:
                        LDA             ASM_REPORT_FLAGS
                        AND             #<ASM_REPORTF_TRUNC
                        BEQ             ASMR_PRINT_TRUNC_NO
                        LDX             #<MSG_TRUNC_YES
                        LDY             #>MSG_TRUNC_YES
                        JMP             ASMR_PRINT_LINE
ASMR_PRINT_TRUNC_NO:
                        LDX             #<MSG_TRUNC_NO
                        LDY             #>MSG_TRUNC_NO
                        JMP             ASMR_PRINT_LINE

ASMR_PRINT_SEAL:
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
                        RTS

ASMR_PRINT_COUNTS:
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
                        RTS

ASMR_PRINT_PACKAGE:
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

ASMR_PRINT_USED:
                        JSR             ASMR_HAS_USED_SYMBOL
                        BCC             ASMR_PRINT_USED_DONE
                        LDX             #<MSG_USED
                        LDY             #>MSG_USED
                        JSR             ASMR_PRINT_LINE
                        LDX             #$00
ASMR_PRINT_USED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASMR_PRINT_USED_DONE
                        LDA             ASM_SYM_FLAGS,X
                        AND             #<ASM_SYMF_USED
                        BEQ             ASMR_PRINT_USED_NEXT
                        JSR             ASMR_PRINT_USED_ROW
                        LDX             ASMR_SLOT
ASMR_PRINT_USED_NEXT:
                        INX
                        BRA             ASMR_PRINT_USED_LOOP
ASMR_PRINT_USED_DONE:
                        RTS

ASMR_HAS_USED_SYMBOL:
                        LDX             #$00
ASMR_HAS_USED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASMR_HAS_USED_NO
                        LDA             ASM_SYM_FLAGS,X
                        AND             #<ASM_SYMF_USED
                        BNE             ASMR_HAS_USED_YES
                        INX
                        BRA             ASMR_HAS_USED_LOOP
ASMR_HAS_USED_NO:
                        CLC
                        RTS
ASMR_HAS_USED_YES:
                        SEC
                        RTS

ASMR_PRINT_USED_ROW:
                        STX             ASMR_SLOT
                        JSR             ASMR_PRINT_SYMBOL_NAME
                        JSR             ASMR_PRINT_DEF_FIELD
                        LDX             #<MSG_USED_REFS
                        LDY             #>MSG_USED_REFS
                        JSR             ASMR_PRINT
                        LDX             ASMR_SLOT
                        LDA             ASM_SYM_USECNT,X
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_USED_FIRST
                        LDY             #>MSG_USED_FIRST
                        JSR             ASMR_PRINT
                        LDY             ASMR_SLOT
                        LDA             ASM_SYM_FIRSTREF_HI,Y
                        LDX             ASM_SYM_FIRSTREF_LO,Y
                        JSR             ASMR_PRINT_WORD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_UNUSED:
                        JSR             ASMR_HAS_UNUSED_SYMBOL
                        BCC             ASMR_PRINT_UNUSED_DONE
                        LDX             #<MSG_UNUSED
                        LDY             #>MSG_UNUSED
                        JSR             ASMR_PRINT_LINE
                        LDX             #$00
ASMR_PRINT_UNUSED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASMR_PRINT_UNUSED_DONE
                        LDA             ASM_SYM_FLAGS,X
                        AND             #<ASM_SYMF_USED
                        BNE             ASMR_PRINT_UNUSED_NEXT
                        JSR             ASMR_PRINT_UNUSED_ROW
                        LDX             ASMR_SLOT
ASMR_PRINT_UNUSED_NEXT:
                        INX
                        BRA             ASMR_PRINT_UNUSED_LOOP
ASMR_PRINT_UNUSED_DONE:
                        RTS

ASMR_HAS_UNUSED_SYMBOL:
                        LDX             #$00
ASMR_HAS_UNUSED_LOOP:
                        CPX             ASM_SYM_COUNT
                        BEQ             ASMR_HAS_UNUSED_NO
                        LDA             ASM_SYM_FLAGS,X
                        AND             #<ASM_SYMF_USED
                        BEQ             ASMR_HAS_UNUSED_YES
                        INX
                        BRA             ASMR_HAS_UNUSED_LOOP
ASMR_HAS_UNUSED_NO:
                        CLC
                        RTS
ASMR_HAS_UNUSED_YES:
                        SEC
                        RTS

ASMR_PRINT_UNUSED_ROW:
                        STX             ASMR_SLOT
                        JSR             ASMR_PRINT_SYMBOL_NAME
                        JSR             ASMR_PRINT_DEF_FIELD
                        JMP             SYS_WRITE_CRLF

ASMR_PRINT_SYMBOL_NAME:
                        JSR             ASMR_SET_SYM_NAME_PTR_X
                        LDX             ASMR_PTR_LO
                        LDY             ASMR_PTR_HI
                        JSR             ASMR_PRINT
                        JMP             ASMR_PRINT_SPACE

ASMR_PRINT_DEF_FIELD:
                        LDX             #<MSG_DEF
                        LDY             #>MSG_DEF
                        JSR             ASMR_PRINT
                        LDY             ASMR_SLOT
                        LDA             ASM_SYM_DEFLINE_HI,Y
                        LDX             ASM_SYM_DEFLINE_LO,Y
                        JMP             ASMR_PRINT_WORD

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

ASMR_PRINT_LIMIT_SEP:
                        LDA             #'/'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'$'
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

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

MSG_TITLE:             DB              "ASM REPORT",0
MSG_STATUS:            DB              "STATUS=",0
MSG_OK:                DB              "OK",0
MSG_ERRLINE:           DB              "ERRLINE=$",0
MSG_START:             DB              "START=$",0
MSG_PC:                DB              "PC=$",0
MSG_HIGH:              DB              "HIGH=$",0
MSG_BYTES:             DB              "BYTES=$",0
MSG_LINES:             DB              "LINES=$",0
MSG_SYMS:              DB              "SYMS=$",0
MSG_FIXUPS_COUNT:      DB              "FIXUPS=$",0
MSG_REFS:              DB              "REFS=$",0
MSG_TRUNC_YES:         DB              "TRUNC=YES",0
MSG_TRUNC_NO:          DB              "TRUNC=NO",0
MSG_MAP:               DB              "MAP END=$",0
MSG_UDATA:             DB              " UDATA=$",0
MSG_SEAL:              DB              "SEAL FL BASE END LEN FNV ",0
MSG_COUNTS:            DB              "COUNTS SYM FIX REL EXP IMP IMPRES RELCNT ",0
MSG_PACKAGE:           DB              "PKG @ LEN BODY INST ",0
MSG_USED:              DB              "USED",0
MSG_UNUSED:            DB              "UNUSED",0
MSG_DEF:               DB              "DEF=$",0
MSG_USED_REFS:         DB              " REFS=$",0
MSG_USED_FIRST:        DB              " FIRST=$",0
MSG_SYMBOLS:           DB              "SYMBOLS",0
MSG_SYM_HEAD:          DB              "SL ST VALUE K  W  FL DEF  USE FIRST NAME",0
MSG_FIXUPS:            DB              "FIXUPS",0
MSG_FIX_HEAD:          DB              "SL ST MODE SEL SITE BASE NAME",0
MSG_RELOCS:            DB              "RELOCS",0
MSG_RELOC_HEAD:        DB              "SL K  SITE TARG",0
MSG_DONE:              DB              "ASM REPORT OK",0

                        ENDMOD
                        END

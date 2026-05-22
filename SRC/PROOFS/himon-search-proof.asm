; ----------------------------------------------------------------------------
; himon-search-proof.asm
; RAM-loaded HIMON search proof, linked at $3000.
; Provides a tiny S> prompt for proving the future HIMON S command.
; ----------------------------------------------------------------------------

                        MODULE          HIMON_SEARCH_PROOF_APP

                        XDEF            START

; ----------------------------------------------------------------------------
; App-local zero page. HIMON treats $00-$AF as user/free while user code runs.
; ----------------------------------------------------------------------------
SEARCH_LINE_LO          EQU             $00
SEARCH_LINE_HI          EQU             $01
SEARCH_WORD_LO          EQU             $02
SEARCH_WORD_HI          EQU             $03
SEARCH_START_LO         EQU             $04
SEARCH_START_HI         EQU             $05
SEARCH_END_LO           EQU             $06
SEARCH_END_HI           EQU             $07
SEARCH_SCAN_LO          EQU             $08
SEARCH_SCAN_HI          EQU             $09
SEARCH_MATCH_LO         EQU             $0A
SEARCH_MATCH_HI         EQU             $0B
SEARCH_ROW_LO           EQU             $0C
SEARCH_ROW_HI           EQU             $0D
SEARCH_TMP              EQU             $0E
SEARCH_DIGITS           EQU             $0F
SEARCH_PAT_LEN          EQU             $10
SEARCH_COUNT            EQU             $11
SEARCH_HIT_FLAG         EQU             $12
SEARCH_IO_FLAG          EQU             $13
SEARCH_IMP_WRITE_LO     EQU             $14
SEARCH_IMP_WRITE_HI     EQU             $15
SEARCH_IMP_READ_LO      EQU             $16
SEARCH_IMP_READ_HI      EQU             $17
SEARCH_IMP_FLUSH_LO     EQU             $18
SEARCH_IMP_FLUSH_HI     EQU             $19
SEARCH_IMP_CTRL_C_LO    EQU             $1A
SEARCH_IMP_CTRL_C_HI    EQU             $1B
SEARCH_IMP_HEX_IN_LO    EQU             $1C
SEARCH_IMP_HEX_IN_HI    EQU             $1D
SEARCH_FIND_RES_LO      EQU             $1E
SEARCH_FIND_RES_HI      EQU             $1F
SEARCH_HASH_PTR_LO      EQU             $20
SEARCH_HASH_PTR_HI      EQU             $21
SEARCH_HASH_SCAN_LO     EQU             $22
SEARCH_HASH_SCAN_HI     EQU             $23

SEARCH_LINE_BUF         EQU             $7800
SEARCH_PAT_BUF          EQU             $7900
SEARCH_PAT_MAX          EQU             $40
SEARCH_HASH_SIG2        EQU             ('V'+$80)
SEARCH_HASH_SCAN_BASE_HI EQU            $80
SEARCH_HASH_KIND_EXEC   EQU             $01
SEARCH_ERR_WRITE        EQU             $E1
SEARCH_ERR_READ         EQU             $E2
SEARCH_ERR_FLUSH        EQU             $E3
SEARCH_ERR_CTRL_C       EQU             $E4
SEARCH_ERR_HEX_IN       EQU             $E5

                        CODE
START:
                        JSR             SEARCH_RESOLVE_WRITE
                        BCS             START_HAVE_WRITE
                        LDA             #SEARCH_ERR_WRITE
                        RTS
START_HAVE_WRITE:
                        JSR             SEARCH_RESOLVE_IMPORTS
                        BCS             START_IMPORTS_OK
                        LDX             #<MSG_IMPORT
                        LDY             #>MSG_IMPORT
                        JSR             SEARCH_PRINT_LINE
                        LDA             SEARCH_TMP
                        RTS

START_IMPORTS_OK:
                        JSR             SEARCH_BIO_FLUSH_RX
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             SEARCH_PRINT_LINE
                        LDX             #<MSG_USAGE
                        LDY             #>MSG_USAGE
                        JSR             SEARCH_PRINT_LINE

SEARCH_MAIN:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             SEARCH_WRITE_CSTRING
                        LDX             #<SEARCH_LINE_BUF
                        LDY             #>SEARCH_LINE_BUF
                        JSR             SEARCH_READ_LINE_ECHO
                        BCS             SEARCH_HAVE_LINE
                        CMP             #$03
                        BEQ             SEARCH_MAIN
                        LDX             #<MSG_FULL
                        LDY             #>MSG_FULL
                        JSR             SEARCH_PRINT_LINE
                        BRA             SEARCH_MAIN

SEARCH_HAVE_LINE:
                        JSR             SEARCH_RUN_LINE
                        BCC             SEARCH_MAIN
                        RTS

SEARCH_RUN_LINE:
                        LDA             #<SEARCH_LINE_BUF
                        STA             SEARCH_LINE_LO
                        LDA             #>SEARCH_LINE_BUF
                        STA             SEARCH_LINE_HI
                        JSR             SEARCH_SKIP_SPACES
                        JSR             SEARCH_PEEK
                        BEQ             SEARCH_RUN_DONE
                        CMP             #'?'
                        BEQ             SEARCH_USAGE
                        AND             #$DF
                        CMP             #'Q'
                        BEQ             SEARCH_QUIT
                        CMP             #'S'
                        BNE             SEARCH_PARSE_ARGS
                        JSR             SEARCH_ADV_LINE

SEARCH_PARSE_ARGS:
                        JSR             SEARCH_PARSE_RANGE
                        BCC             SEARCH_USAGE
                        JSR             SEARCH_PARSE_PATTERN
                        BCC             SEARCH_USAGE
                        JSR             SEARCH_SCAN_RANGE
SEARCH_RUN_DONE:
                        CLC
                        RTS

SEARCH_QUIT:
                        LDX             #<MSG_BYE
                        LDY             #>MSG_BYE
                        JSR             SEARCH_PRINT_LINE
                        SEC
                        RTS

SEARCH_USAGE:
                        LDX             #<MSG_USAGE
                        LDY             #>MSG_USAGE
                        JSR             SEARCH_PRINT_LINE
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Import resolver.  Search carries hash constants, not helper payload copies.
; ----------------------------------------------------------------------------
SEARCH_RESOLVE_WRITE:
                        LDX             #<HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             SEARCH_FIND_HASH_XY
                        BCS             SEARCH_RESOLVE_WRITE_FOUND
                        CLC
                        RTS
SEARCH_RESOLVE_WRITE_FOUND:
                        LDA             SEARCH_FIND_RES_LO
                        STA             SEARCH_IMP_WRITE_LO
                        LDA             SEARCH_FIND_RES_HI
                        STA             SEARCH_IMP_WRITE_HI
                        SEC
                        RTS

SEARCH_RESOLVE_IMPORTS:
                        JSR             SEARCH_RESOLVE_READ
                        BCS             SEARCH_RESOLVE_HAVE_READ
                        LDA             #SEARCH_ERR_READ
                        BRA             SEARCH_RESOLVE_IMPORT_FAIL
SEARCH_RESOLVE_HAVE_READ:
                        JSR             SEARCH_RESOLVE_FLUSH
                        BCS             SEARCH_RESOLVE_HAVE_FLUSH
                        LDA             #SEARCH_ERR_FLUSH
                        BRA             SEARCH_RESOLVE_IMPORT_FAIL
SEARCH_RESOLVE_HAVE_FLUSH:
                        JSR             SEARCH_RESOLVE_CTRL_C
                        BCS             SEARCH_RESOLVE_HAVE_CTRL_C
                        LDA             #SEARCH_ERR_CTRL_C
                        BRA             SEARCH_RESOLVE_IMPORT_FAIL
SEARCH_RESOLVE_HAVE_CTRL_C:
                        JSR             SEARCH_RESOLVE_HEX_IN
                        BCS             SEARCH_RESOLVE_IMPORTS_OK
                        LDA             #SEARCH_ERR_HEX_IN
                        BRA             SEARCH_RESOLVE_IMPORT_FAIL
SEARCH_RESOLVE_IMPORTS_OK:
                        SEC
                        RTS
SEARCH_RESOLVE_IMPORT_FAIL:
                        STA             SEARCH_TMP
                        CLC
                        RTS

SEARCH_RESOLVE_READ:
                        LDX             #<HASH_BIO_READ_BYTE_BLOCK
                        LDY             #>HASH_BIO_READ_BYTE_BLOCK
                        JSR             SEARCH_FIND_HASH_XY
                        BCC             SEARCH_RESOLVE_FAIL
                        LDA             SEARCH_FIND_RES_LO
                        STA             SEARCH_IMP_READ_LO
                        LDA             SEARCH_FIND_RES_HI
                        STA             SEARCH_IMP_READ_HI
                        SEC
                        RTS

SEARCH_RESOLVE_FLUSH:
                        LDX             #<HASH_BIO_FLUSH_RX
                        LDY             #>HASH_BIO_FLUSH_RX
                        JSR             SEARCH_FIND_HASH_XY
                        BCC             SEARCH_RESOLVE_FAIL
                        LDA             SEARCH_FIND_RES_LO
                        STA             SEARCH_IMP_FLUSH_LO
                        LDA             SEARCH_FIND_RES_HI
                        STA             SEARCH_IMP_FLUSH_HI
                        SEC
                        RTS

SEARCH_RESOLVE_CTRL_C:
                        LDX             #<HASH_BIO_GET_CTRL_C
                        LDY             #>HASH_BIO_GET_CTRL_C
                        JSR             SEARCH_FIND_HASH_XY
                        BCC             SEARCH_RESOLVE_FAIL
                        LDA             SEARCH_FIND_RES_LO
                        STA             SEARCH_IMP_CTRL_C_LO
                        LDA             SEARCH_FIND_RES_HI
                        STA             SEARCH_IMP_CTRL_C_HI
                        SEC
                        RTS

SEARCH_RESOLVE_HEX_IN:
                        LDX             #<HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             SEARCH_FIND_HASH_XY
                        BCC             SEARCH_RESOLVE_FAIL
                        LDA             SEARCH_FIND_RES_LO
                        STA             SEARCH_IMP_HEX_IN_LO
                        LDA             SEARCH_FIND_RES_HI
                        STA             SEARCH_IMP_HEX_IN_HI
                        SEC
                        RTS

SEARCH_RESOLVE_FAIL:
                        CLC
                        RTS

SEARCH_FIND_HASH_XY:
                        STX             SEARCH_HASH_PTR_LO
                        STY             SEARCH_HASH_PTR_HI
                        STZ             SEARCH_HASH_SCAN_LO
                        LDA             #SEARCH_HASH_SCAN_BASE_HI
                        STA             SEARCH_HASH_SCAN_HI
SEARCH_FIND_LOOP:
                        JSR             SEARCH_FIND_AT_END
                        BCS             SEARCH_FIND_FAIL
                        JSR             SEARCH_FIND_IS_RECORD
                        BCC             SEARCH_FIND_ADV
                        JSR             SEARCH_FIND_MATCH
                        BCS             SEARCH_FIND_FOUND
SEARCH_FIND_ADV:
                        INC             SEARCH_HASH_SCAN_LO
                        BNE             SEARCH_FIND_LOOP
                        INC             SEARCH_HASH_SCAN_HI
                        BRA             SEARCH_FIND_LOOP

SEARCH_FIND_FOUND:
                        LDY             #$07
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        AND             #SEARCH_HASH_KIND_EXEC
                        BEQ             SEARCH_FIND_ADV
                        CLC
                        LDA             SEARCH_HASH_SCAN_LO
                        ADC             #$08
                        STA             SEARCH_FIND_RES_LO
                        LDA             SEARCH_HASH_SCAN_HI
                        ADC             #$00
                        STA             SEARCH_FIND_RES_HI
                        LDA             #$01
                        SEC
                        RTS

SEARCH_FIND_FAIL:
                        CLC
                        RTS

SEARCH_FIND_AT_END:
                        LDA             SEARCH_HASH_SCAN_HI
                        CMP             #$FF
                        BNE             SEARCH_FIND_NOT_END
                        LDA             SEARCH_HASH_SCAN_LO
                        CMP             #$F8
                        BCS             SEARCH_FIND_END
SEARCH_FIND_NOT_END:
                        CLC
                        RTS
SEARCH_FIND_END:
                        SEC
                        RTS

SEARCH_FIND_IS_RECORD:
                        LDY             #$00
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        CMP             #'F'
                        BNE             SEARCH_FIND_NO
                        INY
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        CMP             #'N'
                        BNE             SEARCH_FIND_NO
                        INY
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        CMP             #SEARCH_HASH_SIG2
                        BNE             SEARCH_FIND_NO
                        SEC
                        RTS
SEARCH_FIND_NO:
                        CLC
                        RTS

SEARCH_FIND_MATCH:
                        LDY             #$03
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        LDY             #$00
                        CMP             (SEARCH_HASH_PTR_LO),Y
                        BNE             SEARCH_FIND_NO
                        LDY             #$04
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        LDY             #$01
                        CMP             (SEARCH_HASH_PTR_LO),Y
                        BNE             SEARCH_FIND_NO
                        LDY             #$05
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        LDY             #$02
                        CMP             (SEARCH_HASH_PTR_LO),Y
                        BNE             SEARCH_FIND_NO
                        LDY             #$06
                        LDA             (SEARCH_HASH_SCAN_LO),Y
                        LDY             #$03
                        CMP             (SEARCH_HASH_PTR_LO),Y
                        BNE             SEARCH_FIND_NO
                        SEC
                        RTS

SEARCH_BIO_WRITE_BYTE_BLOCK:
                        JMP             (SEARCH_IMP_WRITE_LO)

SEARCH_BIO_READ_BYTE_BLOCK:
                        JMP             (SEARCH_IMP_READ_LO)

SEARCH_BIO_FLUSH_RX:
                        JMP             (SEARCH_IMP_FLUSH_LO)

SEARCH_BIO_GET_CTRL_C:
                        JMP             (SEARCH_IMP_CTRL_C_LO)

SEARCH_UTL_HEX_ASCII_TO_NIBBLE:
                        JMP             (SEARCH_IMP_HEX_IN_LO)

; ----------------------------------------------------------------------------
; Parse: start end|+count
; ----------------------------------------------------------------------------
SEARCH_PARSE_RANGE:
                        JSR             SEARCH_PARSE_HEX_WORD
                        BCC             SEARCH_PARSE_RANGE_FAIL
                        LDA             SEARCH_WORD_LO
                        STA             SEARCH_START_LO
                        STA             SEARCH_SCAN_LO
                        LDA             SEARCH_WORD_HI
                        STA             SEARCH_START_HI
                        STA             SEARCH_SCAN_HI

                        JSR             SEARCH_SKIP_SPACES
                        JSR             SEARCH_PEEK
                        CMP             #'+'
                        BEQ             SEARCH_PARSE_COUNT

                        JSR             SEARCH_PARSE_HEX_WORD
                        BCC             SEARCH_PARSE_RANGE_FAIL
                        LDA             SEARCH_DIGITS
                        CMP             #$03
                        BCS             SEARCH_FULL_END
                        LDA             SEARCH_START_HI
                        STA             SEARCH_END_HI
                        LDA             SEARCH_WORD_LO
                        STA             SEARCH_END_LO
                        BRA             SEARCH_CHECK_RANGE

SEARCH_FULL_END:
                        LDA             SEARCH_WORD_LO
                        STA             SEARCH_END_LO
                        LDA             SEARCH_WORD_HI
                        STA             SEARCH_END_HI
                        BRA             SEARCH_CHECK_RANGE

SEARCH_PARSE_COUNT:
                        JSR             SEARCH_ADV_LINE
                        JSR             SEARCH_PARSE_HEX_WORD
                        BCC             SEARCH_PARSE_RANGE_FAIL
                        LDA             SEARCH_WORD_LO
                        ORA             SEARCH_WORD_HI
                        BEQ             SEARCH_PARSE_RANGE_FAIL
                        LDA             SEARCH_WORD_LO
                        BNE             SEARCH_COUNT_MINUS_1_LO
                        DEC             SEARCH_WORD_HI
SEARCH_COUNT_MINUS_1_LO:
                        DEC             SEARCH_WORD_LO
                        CLC
                        LDA             SEARCH_START_LO
                        ADC             SEARCH_WORD_LO
                        STA             SEARCH_END_LO
                        LDA             SEARCH_START_HI
                        ADC             SEARCH_WORD_HI
                        STA             SEARCH_END_HI
                        BCS             SEARCH_PARSE_RANGE_FAIL

SEARCH_CHECK_RANGE:
                        LDA             SEARCH_END_HI
                        CMP             SEARCH_START_HI
                        BCC             SEARCH_PARSE_RANGE_FAIL
                        BNE             SEARCH_PARSE_RANGE_OK
                        LDA             SEARCH_END_LO
                        CMP             SEARCH_START_LO
                        BCC             SEARCH_PARSE_RANGE_FAIL
SEARCH_PARSE_RANGE_OK:
                        SEC
                        RTS
SEARCH_PARSE_RANGE_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Pattern atoms: hex bytes and apostrophe-quoted text, in order.
; ----------------------------------------------------------------------------
SEARCH_PARSE_PATTERN:
                        STZ             SEARCH_PAT_LEN
SEARCH_PATTERN_LOOP:
                        JSR             SEARCH_SKIP_SPACES
                        JSR             SEARCH_PEEK
                        BEQ             SEARCH_PATTERN_DONE
                        CMP             #$27
                        BEQ             SEARCH_PATTERN_TEXT
                        JSR             SEARCH_PARSE_HEX_WORD
                        BCC             SEARCH_PATTERN_FAIL
                        LDA             SEARCH_WORD_HI
                        BNE             SEARCH_PATTERN_FAIL
                        LDA             SEARCH_WORD_LO
                        JSR             SEARCH_APPEND_A
                        BCC             SEARCH_PATTERN_FAIL
                        BRA             SEARCH_PATTERN_LOOP

SEARCH_PATTERN_TEXT:
                        JSR             SEARCH_ADV_LINE
                        STZ             SEARCH_COUNT
SEARCH_PATTERN_TEXT_LOOP:
                        JSR             SEARCH_PEEK
                        BEQ             SEARCH_PATTERN_FAIL
                        CMP             #$27
                        BEQ             SEARCH_PATTERN_TEXT_DONE
                        JSR             SEARCH_APPEND_A
                        BCC             SEARCH_PATTERN_FAIL
                        INC             SEARCH_COUNT
                        JSR             SEARCH_ADV_LINE
                        BRA             SEARCH_PATTERN_TEXT_LOOP

SEARCH_PATTERN_TEXT_DONE:
                        LDA             SEARCH_COUNT
                        BEQ             SEARCH_PATTERN_FAIL
                        JSR             SEARCH_ADV_LINE
                        BRA             SEARCH_PATTERN_LOOP

SEARCH_PATTERN_DONE:
                        LDA             SEARCH_PAT_LEN
                        BEQ             SEARCH_PATTERN_FAIL
                        SEC
                        RTS
SEARCH_PATTERN_FAIL:
                        CLC
                        RTS

SEARCH_APPEND_A:
                        STA             SEARCH_TMP
                        LDA             SEARCH_PAT_LEN
                        CMP             #SEARCH_PAT_MAX
                        BCS             SEARCH_APPEND_FAIL
                        TAY
                        LDA             SEARCH_TMP
                        STA             SEARCH_PAT_BUF,Y
                        INC             SEARCH_PAT_LEN
                        SEC
                        RTS
SEARCH_APPEND_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Hex word parser. OUT: word in SEARCH_WORD_*, digit count in SEARCH_DIGITS.
; ----------------------------------------------------------------------------
SEARCH_PARSE_HEX_WORD:
                        JSR             SEARCH_SKIP_SPACES
                        STZ             SEARCH_WORD_LO
                        STZ             SEARCH_WORD_HI
                        STZ             SEARCH_DIGITS
                        JSR             SEARCH_PEEK
                        CMP             #'$'
                        BNE             SEARCH_HEX_LOOP
                        JSR             SEARCH_ADV_LINE

SEARCH_HEX_LOOP:
                        JSR             SEARCH_PEEK
                        JSR             SEARCH_UTL_HEX_ASCII_TO_NIBBLE
                        BCC             SEARCH_HEX_DONE
                        LDX             SEARCH_DIGITS
                        CPX             #$04
                        BCS             SEARCH_HEX_FAIL
                        PHA
                        ASL             SEARCH_WORD_LO
                        ROL             SEARCH_WORD_HI
                        ASL             SEARCH_WORD_LO
                        ROL             SEARCH_WORD_HI
                        ASL             SEARCH_WORD_LO
                        ROL             SEARCH_WORD_HI
                        ASL             SEARCH_WORD_LO
                        ROL             SEARCH_WORD_HI
                        PLA
                        ORA             SEARCH_WORD_LO
                        STA             SEARCH_WORD_LO
                        INC             SEARCH_DIGITS
                        JSR             SEARCH_ADV_LINE
                        BRA             SEARCH_HEX_LOOP

SEARCH_HEX_DONE:
                        LDA             SEARCH_DIGITS
                        BEQ             SEARCH_HEX_FAIL
                        SEC
                        RTS
SEARCH_HEX_FAIL:
                        CLC
                        RTS

SEARCH_SKIP_SPACES:
                        JSR             SEARCH_PEEK
                        CMP             #' '
                        BEQ             SEARCH_SKIP_ADV
                        CMP             #$09
                        BEQ             SEARCH_SKIP_ADV
                        RTS
SEARCH_SKIP_ADV:
                        JSR             SEARCH_ADV_LINE
                        BRA             SEARCH_SKIP_SPACES

SEARCH_PEEK:
                        LDY             #$00
                        LDA             (SEARCH_LINE_LO),Y
                        RTS

SEARCH_ADV_LINE:
                        INC             SEARCH_LINE_LO
                        BNE             SEARCH_ADV_DONE
                        INC             SEARCH_LINE_HI
SEARCH_ADV_DONE:
                        RTS

; ----------------------------------------------------------------------------
; Search loop.
; ----------------------------------------------------------------------------
SEARCH_SCAN_RANGE:
                        STZ             SEARCH_HIT_FLAG
                        STZ             SEARCH_IO_FLAG
SEARCH_SCAN_LOOP:
                        JSR             SEARCH_SCAN_GT_END
                        BCS             SEARCH_SCAN_DONE
                        LDA             SEARCH_SCAN_HI
                        CMP             #$7F
                        BNE             SEARCH_SCAN_NOT_IO
                        LDA             #$01
                        STA             SEARCH_IO_FLAG
                        STZ             SEARCH_SCAN_LO
                        LDA             #$80
                        STA             SEARCH_SCAN_HI
                        BRA             SEARCH_SCAN_LOOP

SEARCH_SCAN_NOT_IO:
                        JSR             SEARCH_BIO_GET_CTRL_C
                        BCS             SEARCH_ABORT
                        JSR             SEARCH_MATCH_AT
                        BCC             SEARCH_SCAN_NEXT
                        LDA             #$01
                        STA             SEARCH_HIT_FLAG
                        JSR             SEARCH_PRINT_HIT

SEARCH_SCAN_NEXT:
                        LDA             SEARCH_SCAN_HI
                        CMP             SEARCH_END_HI
                        BNE             SEARCH_SCAN_INC
                        LDA             SEARCH_SCAN_LO
                        CMP             SEARCH_END_LO
                        BEQ             SEARCH_SCAN_DONE
SEARCH_SCAN_INC:
                        INC             SEARCH_SCAN_LO
                        BNE             SEARCH_SCAN_LOOP
                        INC             SEARCH_SCAN_HI
                        BRA             SEARCH_SCAN_LOOP

SEARCH_SCAN_DONE:
                        LDA             SEARCH_IO_FLAG
                        BEQ             SEARCH_SCAN_NO_IO_MSG
                        LDX             #<MSG_IO
                        LDY             #>MSG_IO
                        JSR             SEARCH_PRINT_LINE
SEARCH_SCAN_NO_IO_MSG:
                        LDA             SEARCH_HIT_FLAG
                        BNE             SEARCH_SCAN_RETURN
                        LDX             #<MSG_NF
                        LDY             #>MSG_NF
                        JSR             SEARCH_PRINT_LINE
SEARCH_SCAN_RETURN:
                        RTS

SEARCH_ABORT:
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JMP             SEARCH_PRINT_LINE

SEARCH_SCAN_GT_END:
                        LDA             SEARCH_SCAN_HI
                        CMP             SEARCH_END_HI
                        BCC             SEARCH_GT_NO
                        BNE             SEARCH_GT_YES
                        LDA             SEARCH_SCAN_LO
                        CMP             SEARCH_END_LO
                        BEQ             SEARCH_GT_NO
                        BCC             SEARCH_GT_NO
SEARCH_GT_YES:
                        SEC
                        RTS
SEARCH_GT_NO:
                        CLC
                        RTS

SEARCH_MATCH_GT_END:
                        LDA             SEARCH_MATCH_HI
                        CMP             SEARCH_END_HI
                        BCC             SEARCH_GT_NO
                        BNE             SEARCH_GT_YES
                        LDA             SEARCH_MATCH_LO
                        CMP             SEARCH_END_LO
                        BEQ             SEARCH_GT_NO
                        BCC             SEARCH_GT_NO
                        BRA             SEARCH_GT_YES

SEARCH_MATCH_AT:
                        LDA             SEARCH_SCAN_LO
                        STA             SEARCH_MATCH_LO
                        LDA             SEARCH_SCAN_HI
                        STA             SEARCH_MATCH_HI
                        LDX             #$00
SEARCH_MATCH_LOOP:
                        LDA             SEARCH_MATCH_HI
                        CMP             #$7F
                        BNE             SEARCH_MATCH_NOT_IO
                        LDA             #$01
                        STA             SEARCH_IO_FLAG
                        CLC
                        RTS
SEARCH_MATCH_NOT_IO:
                        JSR             SEARCH_MATCH_GT_END
                        BCS             SEARCH_MATCH_FAIL
                        LDY             #$00
                        LDA             (SEARCH_MATCH_LO),Y
                        CMP             SEARCH_PAT_BUF,X
                        BNE             SEARCH_MATCH_FAIL
                        INX
                        CPX             SEARCH_PAT_LEN
                        BEQ             SEARCH_MATCH_YES
                        INC             SEARCH_MATCH_LO
                        BNE             SEARCH_MATCH_LOOP
                        INC             SEARCH_MATCH_HI
                        BEQ             SEARCH_MATCH_FAIL
                        BRA             SEARCH_MATCH_LOOP
SEARCH_MATCH_YES:
                        SEC
                        RTS
SEARCH_MATCH_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Hit display: exact hit, separator, aligned D-style row.
; ----------------------------------------------------------------------------
SEARCH_PRINT_HIT:
                        LDA             SEARCH_SCAN_HI
                        JSR             SEARCH_WRITE_HEX_BYTE
                        LDA             SEARCH_SCAN_LO
                        JSR             SEARCH_WRITE_HEX_BYTE

                        LDA             SEARCH_SCAN_LO
                        AND             #$0F
                        CLC
                        ADC             SEARCH_PAT_LEN
                        CMP             #$11
                        BCC             SEARCH_HIT_SPACE
                        LDA             #'*'
                        BRA             SEARCH_HIT_SEP
SEARCH_HIT_SPACE:
                        LDA             #' '
SEARCH_HIT_SEP:
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK

                        LDA             SEARCH_SCAN_LO
                        AND             #$F0
                        STA             SEARCH_ROW_LO
                        LDA             SEARCH_SCAN_HI
                        STA             SEARCH_ROW_HI
                        JSR             SEARCH_PRINT_ROW_ADDR
                        LDA             #':'
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        JSR             SEARCH_PRINT_ROW_BYTES
                        JMP             SEARCH_WRITE_CRLF

SEARCH_PRINT_ROW_ADDR:
                        LDA             SEARCH_ROW_HI
                        JSR             SEARCH_WRITE_HEX_BYTE
                        LDA             SEARCH_ROW_LO
                        JMP             SEARCH_WRITE_HEX_BYTE

SEARCH_PRINT_ROW_BYTES:
                        STZ             SEARCH_COUNT
SEARCH_ROW_BYTE_LOOP:
                        LDA             SEARCH_COUNT
                        BEQ             SEARCH_ROW_BYTE_SPACE
                        CMP             #$08
                        BNE             SEARCH_ROW_BYTE_SPACE
                        LDA             #' '
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
SEARCH_ROW_BYTE_SPACE:
                        LDA             #' '
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDY             SEARCH_COUNT
                        LDA             (SEARCH_ROW_LO),Y
                        JSR             SEARCH_WRITE_HEX_BYTE
                        INC             SEARCH_COUNT
                        LDA             SEARCH_COUNT
                        CMP             #$10
                        BCC             SEARCH_ROW_BYTE_LOOP

                        LDA             #' '
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        STZ             SEARCH_COUNT
SEARCH_ROW_ASCII_LOOP:
                        LDY             SEARCH_COUNT
                        LDA             (SEARCH_ROW_LO),Y
                        CMP             #' '
                        BCC             SEARCH_ROW_DOT
                        CMP             #$7F
                        BCC             SEARCH_ROW_ASCII_OUT
SEARCH_ROW_DOT:
                        LDA             #'.'
SEARCH_ROW_ASCII_OUT:
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        INC             SEARCH_COUNT
                        LDA             SEARCH_COUNT
                        CMP             #$10
                        BCC             SEARCH_ROW_ASCII_LOOP
                        RTS

SEARCH_READ_LINE_ECHO:
                        STX             SEARCH_LINE_LO
                        STY             SEARCH_LINE_HI
                        STZ             SEARCH_COUNT
                        LDY             #$00
                        LDA             #$00
                        STA             (SEARCH_LINE_LO),Y
SEARCH_READ_LOOP:
                        JSR             SEARCH_BIO_READ_BYTE_BLOCK
                        CMP             #$03
                        BEQ             SEARCH_READ_ABORT
                        CMP             #$0D
                        BEQ             SEARCH_READ_DONE
                        CMP             #$0A
                        BEQ             SEARCH_READ_DONE
                        CMP             #$08
                        BEQ             SEARCH_READ_BACKSPACE
                        CMP             #$7F
                        BEQ             SEARCH_READ_BACKSPACE
                        CMP             #' '
                        BCC             SEARCH_READ_LOOP
                        CMP             #$7F
                        BCS             SEARCH_READ_LOOP
                        STA             SEARCH_TMP
                        LDA             SEARCH_COUNT
                        CMP             #$FE
                        BEQ             SEARCH_READ_FULL
                        LDY             #$00
                        LDA             SEARCH_TMP
                        STA             (SEARCH_LINE_LO),Y
                        JSR             SEARCH_ADV_LINE
                        INC             SEARCH_COUNT
                        LDA             SEARCH_TMP
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        BRA             SEARCH_READ_LOOP

SEARCH_READ_BACKSPACE:
                        LDA             SEARCH_COUNT
                        BEQ             SEARCH_READ_LOOP
                        DEC             SEARCH_COUNT
                        LDA             SEARCH_LINE_LO
                        BNE             SEARCH_READ_BS_DEC
                        DEC             SEARCH_LINE_HI
SEARCH_READ_BS_DEC:
                        DEC             SEARCH_LINE_LO
                        LDA             #$08
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #$08
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        BRA             SEARCH_READ_LOOP

SEARCH_READ_DONE:
                        LDY             #$00
                        LDA             #$00
                        STA             (SEARCH_LINE_LO),Y
                        JSR             SEARCH_WRITE_CRLF
                        LDA             SEARCH_COUNT
                        SEC
                        RTS

SEARCH_READ_ABORT:
                        JSR             SEARCH_WRITE_CRLF
                        LDA             #$03
                        CLC
                        RTS

SEARCH_READ_FULL:
                        LDY             #$00
                        LDA             #$00
                        STA             (SEARCH_LINE_LO),Y
                        JSR             SEARCH_WRITE_CRLF
                        LDA             #$FE
                        CLC
                        RTS

SEARCH_WRITE_HEX_BYTE:
                        PHA
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        JSR             SEARCH_WRITE_HEX_NIBBLE
                        PLA
                        AND             #$0F
SEARCH_WRITE_HEX_NIBBLE:
                        CMP             #$0A
                        BCC             SEARCH_WRITE_HEX_DIGIT
                        CLC
                        ADC             #$37
                        JMP             SEARCH_BIO_WRITE_BYTE_BLOCK
SEARCH_WRITE_HEX_DIGIT:
                        CLC
                        ADC             #'0'
                        JMP             SEARCH_BIO_WRITE_BYTE_BLOCK

SEARCH_WRITE_CRLF:
                        LDA             #$0D
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        LDA             #$0A
                        JMP             SEARCH_BIO_WRITE_BYTE_BLOCK

SEARCH_WRITE_CSTRING:
                        STX             SEARCH_LINE_LO
                        STY             SEARCH_LINE_HI
                        LDY             #$00
SEARCH_WRITE_CSTRING_LOOP:
                        LDA             (SEARCH_LINE_LO),Y
                        BEQ             SEARCH_WRITE_CSTRING_DONE
                        JSR             SEARCH_BIO_WRITE_BYTE_BLOCK
                        INY
                        BNE             SEARCH_WRITE_CSTRING_LOOP
                        INC             SEARCH_LINE_HI
                        BRA             SEARCH_WRITE_CSTRING_LOOP
SEARCH_WRITE_CSTRING_DONE:
                        RTS

SEARCH_PRINT_LINE:
                        JSR             SEARCH_WRITE_CSTRING
                        JMP             SEARCH_WRITE_CRLF

                        DATA
HASH_BIO_WRITE_BYTE_BLOCK:
                        DB              $30,$E9,$9F,$37
HASH_BIO_READ_BYTE_BLOCK:
                        DB              $85,$5B,$28,$20
HASH_BIO_FLUSH_RX:
                        DB              $B9,$22,$66,$2F
HASH_BIO_GET_CTRL_C:
                        DB              $D2,$50,$61,$42
HASH_UTL_HEX_ASCII_TO_NIBBLE:
                        DB              $B1,$14,$D7,$AD
MSG_TITLE:              DB              "HIMON SEARCH PROOF $3000",0
MSG_USAGE:              DB              "S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT",0
MSG_PROMPT:             DB              "S> ",0
MSG_FULL:               DB              "S FULL",0
MSG_IMPORT:             DB              "S IMP",0
MSG_NF:                 DB              "S NF",0
MSG_IO:                 DB              "S IO",0
MSG_ABORT:              DB              "S ABORT",0
MSG_BYE:                DB              "S DONE",0

                        END

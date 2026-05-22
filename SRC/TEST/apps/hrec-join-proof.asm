; ----------------------------------------------------------------------------
; hrec-join-proof.asm
; RAM-loaded HREC join proof, linked at $4000.
; Proves the "C" path: find resident THE_JOIN_EXEC_XY, then join BIO write.
; ----------------------------------------------------------------------------

                        MODULE          HREC_JOIN_PROOF_APP

                        XDEF            START

; ----------------------------------------------------------------------------
; App-local zero page. HIMON treats $00-$AF as user/free while user code runs.
; ----------------------------------------------------------------------------
HREC_STR_LO            EQU             $00
HREC_STR_HI            EQU             $01
HREC_JOIN_LO           EQU             $02
HREC_JOIN_HI           EQU             $03
HREC_HASH_PTR_LO       EQU             $04
HREC_HASH_PTR_HI       EQU             $05
HREC_SCAN_LO           EQU             $06
HREC_SCAN_HI           EQU             $07
HREC_IMP_WRITE_LO      EQU             $08
HREC_IMP_WRITE_HI      EQU             $09
HREC_IMP_READ_LO       EQU             $0A
HREC_IMP_READ_HI       EQU             $0B
HREC_USER_HASH0        EQU             $0C
HREC_USER_HASH1        EQU             $0D
HREC_USER_HASH2        EQU             $0E
HREC_USER_HASH3        EQU             $0F
HREC_LINE_COUNT        EQU             $10
HREC_LINE_INDEX        EQU             $11
HREC_USER_BYTE_INDEX   EQU             $12
HREC_NIBBLE_HI         EQU             $13
HREC_EXTRA_LO          EQU             $14
HREC_EXTRA_HI          EQU             $15
HREC_JOINER_LO         EQU             $16
HREC_JOINER_HI         EQU             $17

HREC_HASH_SIG2         EQU             ('V'+$80)
HREC_KIND_EXEC         EQU             $01
HREC_KIND_CONFIRM      EQU             $02
HREC_KIND_EXEC_TEXT    EQU             (HREC_KIND_EXEC+HREC_KIND_CONFIRM)
HREC_SCAN_BASE_HI      EQU             $80

                        CODE
START:
                        JSR             HREC_JOIN_INIT
                        BCS             START_HAVE_WRITE
                        RTS

START_HAVE_WRITE:
                        STX             HREC_IMP_WRITE_LO
                        STY             HREC_IMP_WRITE_HI
                        STZ             HREC_IMP_READ_LO
                        STZ             HREC_IMP_READ_HI

                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             HREC_PRINT_LINE
                        LDX             #<MSG_WRITE
                        LDY             #>MSG_WRITE
                        JSR             HREC_PRINT_JOIN_OK_LINE

                        LDX             #<HASH_THE_JOIN_EXEC_XY
                        STX             HREC_HASH_PTR_LO
                        LDY             #>HASH_THE_JOIN_EXEC_XY
                        STY             HREC_HASH_PTR_HI
                        LDA             HREC_JOINER_LO
                        STA             HREC_JOIN_LO
                        LDA             HREC_JOINER_HI
                        STA             HREC_JOIN_HI
                        LDX             #<MSG_JOINER
                        LDY             #>MSG_JOINER
                        JSR             HREC_PRINT_JOIN_OK_LINE

                        LDX             #<HASH_BIO_READ_BYTE_BLOCK
                        LDY             #>HASH_BIO_READ_BYTE_BLOCK
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_READ_NF
                        STX             HREC_IMP_READ_LO
                        STY             HREC_IMP_READ_HI
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             HREC_PRINT_JOIN_OK_LINE
                        BRA             TEST_FLUSH

; ----------------------------------------------------------------------------
; HREC_JOIN_INIT
; Bootstrap the resident join layer and first output dependency.
; OUT: C=1 with X/Y and HREC_JOIN_LO/HI = BIO_FTDI_WRITE_BYTE_BLOCK entry.
;      C=0 if the resident joiner or write routine cannot be joined.
; ----------------------------------------------------------------------------
HREC_JOIN_INIT:
                        LDX             #<HASH_THE_JOIN_EXEC_XY
                        LDY             #>HASH_THE_JOIN_EXEC_XY
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             HREC_JOIN_INIT_FAIL
                        STX             HREC_JOINER_LO
                        STY             HREC_JOINER_HI

                        LDX             #<HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             HREC_JOIN_INIT_FAIL
                        RTS
HREC_JOIN_INIT_FAIL:
                        CLC
                        RTS
TEST_READ_NF:
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             HREC_PRINT_JOIN_NF_LINE

TEST_FLUSH:
                        LDX             #<HASH_BIO_FLUSH_RX
                        LDY             #>HASH_BIO_FLUSH_RX
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_FLUSH_NF
                        LDX             #<MSG_FLUSH
                        LDY             #>MSG_FLUSH
                        JSR             HREC_PRINT_JOIN_OK_LINE
                        BRA             TEST_CTRL
TEST_FLUSH_NF:
                        LDX             #<MSG_FLUSH
                        LDY             #>MSG_FLUSH
                        JSR             HREC_PRINT_JOIN_NF_LINE

TEST_CTRL:
                        LDX             #<HASH_BIO_GET_CTRL_C
                        LDY             #>HASH_BIO_GET_CTRL_C
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_CTRL_NF
                        LDX             #<MSG_CTRL
                        LDY             #>MSG_CTRL
                        JSR             HREC_PRINT_JOIN_OK_LINE
                        BRA             TEST_HEX
TEST_CTRL_NF:
                        LDX             #<MSG_CTRL
                        LDY             #>MSG_CTRL
                        JSR             HREC_PRINT_JOIN_NF_LINE

TEST_HEX:
                        LDX             #<HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_HEX_NF
                        LDA             #'A'
                        JSR             HREC_CALL_JOIN
                        BCC             TEST_HEX_BAD
                        CMP             #$0A
                        BNE             TEST_HEX_BAD
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_HEX_A_OK_LINE
                        BRA             TEST_MISSING
TEST_HEX_NF:
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_JOIN_NF_LINE
                        BRA             TEST_MISSING
TEST_HEX_BAD:
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_JOIN_BAD_LINE

TEST_MISSING:
                        LDX             #<HASH_NO_SUCH_RECORD
                        LDY             #>HASH_NO_SUCH_RECORD
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_MISSING_OK
                        LDX             #<MSG_MISSING
                        LDY             #>MSG_MISSING
                        JSR             HREC_PRINT_JOIN_BAD_LINE
                        BRA             TEST_KIND
TEST_MISSING_OK:
                        LDX             #<MSG_MISSING
                        LDY             #>MSG_MISSING
                        JSR             HREC_PRINT_JOIN_NF_OK_LINE

TEST_KIND:
                        LDA             #HREC_KIND_CONFIRM
                        JSR             HREC_JOIN_EXEC_KIND
                        BCC             TEST_KIND_OK
                        JSR             HREC_PRINT_KIND_BAD_LINE
                        BRA             TEST_HEX_INV
TEST_KIND_OK:
                        JSR             HREC_PRINT_KIND_OK_LINE

TEST_HEX_INV:
                        LDX             #<HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             TEST_HEX_INV_NF
                        LDA             #'G'
                        JSR             HREC_CALL_JOIN
                        BCC             TEST_HEX_INV_OK
                        LDX             #<MSG_HEX_INV
                        LDY             #>MSG_HEX_INV
                        JSR             HREC_PRINT_BAD_LINE
                        BRA             TEST_DONE
TEST_HEX_INV_OK:
                        LDX             #<MSG_HEX_INV
                        LDY             #>MSG_HEX_INV
                        JSR             HREC_PRINT_HEX_G_OK_LINE
                        BRA             TEST_PTR
TEST_HEX_INV_NF:
                        LDX             #<MSG_HEX_INV
                        LDY             #>MSG_HEX_INV
                        JSR             HREC_PRINT_JOIN_NF_LINE
                        BRA             TEST_PTR

TEST_PTR:
                        LDX             #<HASH_PTR_EXT
                        LDY             #>HASH_PTR_EXT
                        JSR             HREC_JOIN_EXEC_LOCAL_XY
                        BCC             TEST_PTR_NF
                        JSR             HREC_CALL_JOIN
                        BCC             TEST_PTR_BAD
                        CMP             #$10
                        BNE             TEST_PTR_BAD
                        LDX             #<MSG_PTR
                        LDY             #>MSG_PTR
                        JSR             HREC_PRINT_PTR_OK_LINE
                        BRA             TEST_DONE
TEST_PTR_NF:
                        LDX             #<MSG_PTR
                        LDY             #>MSG_PTR
                        JSR             HREC_PRINT_JOIN_NF_LINE
                        BRA             TEST_DONE
TEST_PTR_BAD:
                        LDX             #<MSG_PTR
                        LDY             #>MSG_PTR
                        JSR             HREC_PRINT_JOIN_BAD_LINE

TEST_DONE:
                        JSR             HREC_INPUT_LOOP
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             HREC_PRINT_LINE
                        RTS

; ----------------------------------------------------------------------------
; HREC_JOIN_EXEC_XY
; IN : X/Y = pointer to little-endian hash32 bytes.
; OUT: found executable: C=1, X/Y=payload entry, HREC_JOIN_LO/HI=entry.
;      missing or non-exec: C=0.
; ----------------------------------------------------------------------------
HREC_JOIN_EXEC_XY:
                        JSR             HREC_FIND_XY
                        BCC             HREC_JOIN_FAIL
HREC_JOIN_EXEC_KIND:
                        AND             #HREC_KIND_EXEC
                        BEQ             HREC_JOIN_FAIL
HREC_JOIN_OK:
                        LDX             HREC_JOIN_LO
                        LDY             HREC_JOIN_HI
                        SEC
                        RTS
HREC_JOIN_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; HREC_FIND_XY
; IN : X/Y = pointer to little-endian hash32 bytes.
; OUT: C=1 found, A=kind, HREC_JOIN_LO/HI=record payload address.
;      C=0 not found.
; ----------------------------------------------------------------------------
HREC_FIND_XY:
                        STX             HREC_HASH_PTR_LO
                        STY             HREC_HASH_PTR_HI
                        STZ             HREC_SCAN_LO
                        LDA             #HREC_SCAN_BASE_HI
                        STA             HREC_SCAN_HI
HREC_FIND_LOOP:
                        JSR             HREC_FIND_AT_END
                        BCS             HREC_FIND_FAIL
                        JSR             HREC_FIND_IS_RECORD
                        BCC             HREC_FIND_ADV
                        JSR             HREC_FIND_MATCH
                        BCS             HREC_FIND_FOUND
HREC_FIND_ADV:
                        INC             HREC_SCAN_LO
                        BNE             HREC_FIND_LOOP
                        INC             HREC_SCAN_HI
                        BRA             HREC_FIND_LOOP

HREC_FIND_FOUND:
                        STZ             HREC_EXTRA_LO
                        STZ             HREC_EXTRA_HI
                        LDY             #$07
                        LDA             (HREC_SCAN_LO),Y
                        CMP             #HREC_KIND_EXEC_TEXT
                        BEQ             HREC_FIND_FOUND_PTR
                        CLC
                        LDA             HREC_SCAN_LO
                        ADC             #$08
                        STA             HREC_JOIN_LO
                        LDA             HREC_SCAN_HI
                        ADC             #$00
                        STA             HREC_JOIN_HI
                        LDY             #$07
                        LDA             (HREC_SCAN_LO),Y
                        SEC
                        RTS
HREC_FIND_FOUND_PTR:
                        LDY             #$08
                        LDA             (HREC_SCAN_LO),Y
                        STA             HREC_JOIN_LO
                        INY
                        LDA             (HREC_SCAN_LO),Y
                        STA             HREC_JOIN_HI
                        INY
                        LDA             (HREC_SCAN_LO),Y
                        STA             HREC_EXTRA_LO
                        INY
                        LDA             (HREC_SCAN_LO),Y
                        STA             HREC_EXTRA_HI
                        LDA             #HREC_KIND_EXEC_TEXT
                        SEC
                        RTS

HREC_FIND_FAIL:
                        CLC
                        RTS

HREC_FIND_AT_END:
                        LDA             HREC_SCAN_HI
                        CMP             #$FF
                        BNE             HREC_FIND_NOT_END
                        LDA             HREC_SCAN_LO
                        CMP             #$F8
                        BCS             HREC_FIND_END
HREC_FIND_NOT_END:
                        CLC
                        RTS
HREC_FIND_END:
                        SEC
                        RTS

HREC_FIND_IS_RECORD:
                        LDY             #$00
                        LDA             (HREC_SCAN_LO),Y
                        CMP             #'F'
                        BNE             HREC_FIND_NO
                        INY
                        LDA             (HREC_SCAN_LO),Y
                        CMP             #'N'
                        BNE             HREC_FIND_NO
                        INY
                        LDA             (HREC_SCAN_LO),Y
                        CMP             #HREC_HASH_SIG2
                        BNE             HREC_FIND_NO
                        SEC
                        RTS
HREC_FIND_NO:
                        CLC
                        RTS

HREC_FIND_MATCH:
                        LDY             #$03
                        LDA             (HREC_SCAN_LO),Y
                        LDY             #$00
                        CMP             (HREC_HASH_PTR_LO),Y
                        BNE             HREC_FIND_NO
                        LDY             #$04
                        LDA             (HREC_SCAN_LO),Y
                        LDY             #$01
                        CMP             (HREC_HASH_PTR_LO),Y
                        BNE             HREC_FIND_NO
                        LDY             #$05
                        LDA             (HREC_SCAN_LO),Y
                        LDY             #$02
                        CMP             (HREC_HASH_PTR_LO),Y
                        BNE             HREC_FIND_NO
                        LDY             #$06
                        LDA             (HREC_SCAN_LO),Y
                        LDY             #$03
                        CMP             (HREC_HASH_PTR_LO),Y
                        BNE             HREC_FIND_NO
                        SEC
                        RTS

HREC_JOIN_EXEC_LOCAL_XY:
                        JSR             HREC_FIND_LOCAL_XY
                        BCS             HREC_JOIN_EXEC_LOCAL_FOUND
                        JMP             HREC_JOIN_FAIL
HREC_JOIN_EXEC_LOCAL_FOUND:
                        JMP             HREC_JOIN_EXEC_KIND

HREC_FIND_LOCAL_XY:
                        STX             HREC_HASH_PTR_LO
                        STY             HREC_HASH_PTR_HI
                        LDA             #<HREC_PTR_RECORD
                        STA             HREC_SCAN_LO
                        LDA             #>HREC_PTR_RECORD
                        STA             HREC_SCAN_HI
                        JSR             HREC_FIND_IS_RECORD
                        BCC             HREC_FIND_FAIL
                        JSR             HREC_FIND_MATCH
                        BCC             HREC_FIND_FAIL
                        JMP             HREC_FIND_FOUND

HREC_PTR_TARGET:
                        LDA             #$10
                        SEC
                        RTS

HREC_CALL_JOIN:
                        JMP             (HREC_JOIN_LO)

; Call the resident THE_JOIN_EXEC_XY found by the bootstrap scanner.
; IN : X/Y = pointer to little-endian hash32 bytes.
; OUT: C=1 with X/Y and HREC_JOIN_LO/HI = executable entry.
HREC_JOIN_RESIDENT_XY:
                        STX             HREC_HASH_PTR_LO
                        STY             HREC_HASH_PTR_HI
                        STZ             HREC_EXTRA_LO
                        STZ             HREC_EXTRA_HI
                        JSR             HREC_CALL_JOINER
                        BCC             HREC_JOIN_RESIDENT_FAIL
                        STX             HREC_JOIN_LO
                        STY             HREC_JOIN_HI
                        SEC
                        RTS
HREC_JOIN_RESIDENT_FAIL:
                        CLC
                        RTS

HREC_CALL_JOINER:
                        JMP             (HREC_JOINER_LO)

HREC_BIO_WRITE_BYTE_BLOCK:
                        JMP             (HREC_IMP_WRITE_LO)

HREC_BIO_READ_BYTE_BLOCK:
                        JMP             (HREC_IMP_READ_LO)

HREC_INPUT_LOOP:
                        LDA             HREC_IMP_READ_LO
                        ORA             HREC_IMP_READ_HI
                        BNE             HREC_INPUT_HAVE_READ
                        LDX             #<MSG_INPUT_NO_READ
                        LDY             #>MSG_INPUT_NO_READ
                        JMP             HREC_PRINT_LINE
HREC_INPUT_HAVE_READ:
                        LDX             #<MSG_INPUT_HELP
                        LDY             #>MSG_INPUT_HELP
                        JSR             HREC_PRINT_LINE
HREC_INPUT_PROMPT:
                        LDX             #<MSG_INPUT_PROMPT
                        LDY             #>MSG_INPUT_PROMPT
                        JSR             HREC_WRITE_CSTRING
                        STZ             HREC_LINE_COUNT
HREC_INPUT_READ_LOOP:
                        JSR             HREC_BIO_READ_BYTE_BLOCK
                        CMP             #$0D
                        BEQ             HREC_INPUT_END_LINE
                        CMP             #$0A
                        BEQ             HREC_INPUT_END_LINE
                        PHA
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        PLA
                        LDX             HREC_LINE_COUNT
                        CPX             #$08
                        BCS             HREC_INPUT_TOO_LONG
                        STA             HREC_LINE_BUF,X
                        INC             HREC_LINE_COUNT
                        BRA             HREC_INPUT_READ_LOOP
HREC_INPUT_TOO_LONG:
                        JSR             HREC_DRAIN_LINE
                        JSR             HREC_PRINT_USER_BAD_LINE
                        BRA             HREC_INPUT_PROMPT
HREC_INPUT_END_LINE:
                        JSR             HREC_PRINT_CRLF
                        LDA             HREC_LINE_COUNT
                        BEQ             HREC_INPUT_DONE
                        CMP             #$08
                        BNE             HREC_INPUT_BAD
                        JSR             HREC_PARSE_LINE_HASH
                        BCC             HREC_INPUT_BAD
                        LDX             #<HREC_USER_HASH0
                        LDY             #>HREC_USER_HASH0
                        JSR             HREC_JOIN_EXEC_LOCAL_XY
                        BCS             HREC_INPUT_FOUND
                        LDX             #<HREC_USER_HASH0
                        LDY             #>HREC_USER_HASH0
                        JSR             HREC_JOIN_RESIDENT_XY
                        BCC             HREC_INPUT_NF
HREC_INPUT_FOUND:
                        LDX             #<MSG_USER
                        LDY             #>MSG_USER
                        JSR             HREC_PRINT_JOIN_OK_LINE
                        BRA             HREC_INPUT_PROMPT
HREC_INPUT_NF:
                        LDX             #<MSG_USER
                        LDY             #>MSG_USER
                        JSR             HREC_PRINT_JOIN_NF_LINE
                        BRA             HREC_INPUT_PROMPT
HREC_INPUT_BAD:
                        JSR             HREC_PRINT_USER_BAD_LINE
                        BRA             HREC_INPUT_PROMPT
HREC_INPUT_DONE:
                        RTS

HREC_PARSE_LINE_HASH:
                        STZ             HREC_LINE_INDEX
                        LDA             #$03
                        STA             HREC_USER_BYTE_INDEX
HREC_PARSE_LINE_HASH_LOOP:
                        LDX             HREC_LINE_INDEX
                        LDA             HREC_LINE_BUF,X
                        JSR             HREC_ASCII_TO_NIBBLE
                        BCC             HREC_PARSE_LINE_HASH_FAIL
                        ASL
                        ASL
                        ASL
                        ASL
                        STA             HREC_NIBBLE_HI
                        INC             HREC_LINE_INDEX
                        LDX             HREC_LINE_INDEX
                        LDA             HREC_LINE_BUF,X
                        JSR             HREC_ASCII_TO_NIBBLE
                        BCC             HREC_PARSE_LINE_HASH_FAIL
                        ORA             HREC_NIBBLE_HI
                        LDX             HREC_USER_BYTE_INDEX
                        STA             HREC_USER_HASH0,X
                        INC             HREC_LINE_INDEX
                        DEC             HREC_USER_BYTE_INDEX
                        BPL             HREC_PARSE_LINE_HASH_LOOP
                        SEC
                        RTS
HREC_PARSE_LINE_HASH_FAIL:
                        CLC
                        RTS

HREC_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             HREC_ASCII_TO_NIBBLE_BAD
                        CMP             #'9'+1
                        BCC             HREC_ASCII_TO_NIBBLE_DIGIT
                        CMP             #'A'
                        BCC             HREC_ASCII_TO_NIBBLE_BAD
                        CMP             #'F'+1
                        BCC             HREC_ASCII_TO_NIBBLE_UPPER
                        CMP             #'a'
                        BCC             HREC_ASCII_TO_NIBBLE_BAD
                        CMP             #'f'+1
                        BCS             HREC_ASCII_TO_NIBBLE_BAD
                        SEC
                        SBC             #$57
                        SEC
                        RTS
HREC_ASCII_TO_NIBBLE_UPPER:
                        SEC
                        SBC             #$37
                        SEC
                        RTS
HREC_ASCII_TO_NIBBLE_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
HREC_ASCII_TO_NIBBLE_BAD:
                        CLC
                        RTS

HREC_DRAIN_LINE:
                        JSR             HREC_BIO_READ_BYTE_BLOCK
                        CMP             #$0D
                        BEQ             HREC_DRAIN_LINE_DONE
                        CMP             #$0A
                        BEQ             HREC_DRAIN_LINE_DONE
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        BRA             HREC_DRAIN_LINE
HREC_DRAIN_LINE_DONE:
                        JMP             HREC_PRINT_CRLF

HREC_PRINT_USER_BAD_LINE:
                        LDX             #<MSG_USER_BAD
                        LDY             #>MSG_USER_BAD
                        JMP             HREC_PRINT_LINE

HREC_PRINT_JOIN_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_ENTRY_FIELD
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_JOIN_NF_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_EMPTY_ENTRY_FIELD
                        LDX             #<MSG_NF
                        LDY             #>MSG_NF
                        JMP             HREC_PRINT_LINE

HREC_PRINT_JOIN_NF_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_EMPTY_ENTRY_FIELD
                        LDX             #<MSG_NF_OK
                        LDY             #>MSG_NF_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_JOIN_BAD_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_ENTRY_FIELD
                        LDX             #<MSG_BAD
                        LDY             #>MSG_BAD
                        JMP             HREC_PRINT_LINE

HREC_PRINT_HEX_A_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_ENTRY_FIELD
                        LDX             #<MSG_IN_A_OUT_0A
                        LDY             #>MSG_IN_A_OUT_0A
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_HEX_G_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_ENTRY_FIELD
                        LDX             #<MSG_IN_G_C0
                        LDY             #>MSG_IN_G_C0
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_PTR_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        JSR             HREC_PRINT_HASH_FIELD
                        JSR             HREC_PRINT_ENTRY_FIELD
                        JSR             HREC_PRINT_EXTRA_FIELD
                        LDX             #<MSG_OUT_10
                        LDY             #>MSG_OUT_10
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_KIND_OK_LINE:
                        LDX             #<MSG_KIND
                        LDY             #>MSG_KIND
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_KIND_FIELD
                        LDY             #>MSG_KIND_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_KIND_BAD_LINE:
                        LDX             #<MSG_KIND
                        LDY             #>MSG_KIND
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_KIND_FIELD
                        LDY             #>MSG_KIND_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_BAD
                        LDY             #>MSG_BAD
                        JMP             HREC_PRINT_LINE

HREC_PRINT_HASH_FIELD:
                        LDX             #<MSG_HASH_FIELD
                        LDY             #>MSG_HASH_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDA             #'$'
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        LDY             #$03
                        LDA             (HREC_HASH_PTR_LO),Y
                        JSR             HREC_WRITE_HEX_BYTE
                        LDY             #$02
                        LDA             (HREC_HASH_PTR_LO),Y
                        JSR             HREC_WRITE_HEX_BYTE
                        LDY             #$01
                        LDA             (HREC_HASH_PTR_LO),Y
                        JSR             HREC_WRITE_HEX_BYTE
                        LDY             #$00
                        LDA             (HREC_HASH_PTR_LO),Y
                        JMP             HREC_WRITE_HEX_BYTE

HREC_PRINT_ENTRY_FIELD:
                        LDX             #<MSG_ENTRY_FIELD
                        LDY             #>MSG_ENTRY_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDA             #'$'
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        LDA             HREC_JOIN_HI
                        JSR             HREC_WRITE_HEX_BYTE
                        LDA             HREC_JOIN_LO
                        JMP             HREC_WRITE_HEX_BYTE

HREC_PRINT_EMPTY_ENTRY_FIELD:
                        LDX             #<MSG_ENTRY_FIELD
                        LDY             #>MSG_ENTRY_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_NO_ENTRY
                        LDY             #>MSG_NO_ENTRY
                        JMP             HREC_WRITE_CSTRING

HREC_PRINT_EXTRA_FIELD:
                        LDX             #<MSG_EXTRA_FIELD
                        LDY             #>MSG_EXTRA_FIELD
                        JSR             HREC_WRITE_CSTRING
                        LDX             HREC_EXTRA_LO
                        LDY             HREC_EXTRA_HI
                        JMP             HREC_WRITE_HBSTRING

HREC_WRITE_HEX_BYTE:
                        PHA
                        LSR
                        LSR
                        LSR
                        LSR
                        JSR             HREC_WRITE_HEX_NIBBLE
                        PLA
                        AND             #$0F
                        JMP             HREC_WRITE_HEX_NIBBLE

HREC_WRITE_HEX_NIBBLE:
                        AND             #$0F
                        CMP             #$0A
                        BCC             HREC_WRITE_HEX_DIGIT
                        CLC
                        ADC             #$37
                        JMP             HREC_BIO_WRITE_BYTE_BLOCK
HREC_WRITE_HEX_DIGIT:
                        CLC
                        ADC             #'0'
                        JMP             HREC_BIO_WRITE_BYTE_BLOCK

HREC_PRINT_CRLF:
                        LDA             #$0D
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        LDA             #$0A
                        JMP             HREC_BIO_WRITE_BYTE_BLOCK

HREC_PRINT_OK_LINE:
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JMP             HREC_PRINT_LINE

HREC_PRINT_NF_LINE:
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_NF
                        LDY             #>MSG_NF
                        JMP             HREC_PRINT_LINE

HREC_PRINT_BAD_LINE:
                        JSR             HREC_WRITE_CSTRING
                        LDX             #<MSG_BAD
                        LDY             #>MSG_BAD
                        JMP             HREC_PRINT_LINE

HREC_PRINT_LINE:
                        JSR             HREC_WRITE_CSTRING
                        LDA             #$0D
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        LDA             #$0A
                        JMP             HREC_BIO_WRITE_BYTE_BLOCK

HREC_WRITE_CSTRING:
                        STX             HREC_STR_LO
                        STY             HREC_STR_HI
HREC_WRITE_CSTRING_LOOP:
                        LDY             #$00
                        LDA             (HREC_STR_LO),Y
                        BEQ             HREC_WRITE_CSTRING_DONE
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        INC             HREC_STR_LO
                        BNE             HREC_WRITE_CSTRING_LOOP
                        INC             HREC_STR_HI
                        BRA             HREC_WRITE_CSTRING_LOOP
HREC_WRITE_CSTRING_DONE:
                        RTS

HREC_WRITE_HBSTRING:
                        STX             HREC_STR_LO
                        STY             HREC_STR_HI
HREC_WRITE_HBSTRING_LOOP:
                        LDY             #$00
                        LDA             (HREC_STR_LO),Y
                        PHA
                        AND             #$7F
                        JSR             HREC_BIO_WRITE_BYTE_BLOCK
                        PLA
                        BMI             HREC_WRITE_HBSTRING_DONE
                        INC             HREC_STR_LO
                        BNE             HREC_WRITE_HBSTRING_LOOP
                        INC             HREC_STR_HI
                        BRA             HREC_WRITE_HBSTRING_LOOP
HREC_WRITE_HBSTRING_DONE:
                        RTS

                        DATA
HASH_THE_JOIN_EXEC_XY:
                        DB              $F7,$15,$AF,$A9
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
HASH_NO_SUCH_RECORD:
                        DB              $EF,$BE,$AD,$DE
HASH_PTR_EXT:
                        DB              $10,$32,$54,$76
HREC_PTR_RECORD:
                        DB              'F','N',HREC_HASH_SIG2
                        DB              $10,$32,$54,$76
                        DB              HREC_KIND_EXEC_TEXT
                        DW              HREC_PTR_TARGET
                        DW              HREC_PTR_EXTRA
HREC_LINE_BUF:
                        DB              $00,$00,$00,$00,$00,$00,$00,$00

MSG_TITLE:             DB              "HREC JOIN PROOF $4000",0
MSG_WRITE:             DB              "WRITE ",0
MSG_JOINER:            DB              "JOINER ",0
MSG_READ:              DB              "READ ",0
MSG_FLUSH:             DB              "FLUSH ",0
MSG_CTRL:              DB              "CTRL ",0
MSG_HEX:               DB              "HEX ",0
MSG_MISSING:           DB              "MISSING ",0
MSG_KIND:              DB              "KIND ",0
MSG_PTR:               DB              "PTR ",0
MSG_HEX_INV:           DB              "HEXINV ",0
MSG_HASH_FIELD:        DB              "H=",0
MSG_ENTRY_FIELD:       DB              " E=",0
MSG_EXTRA_FIELD:       DB              " X=",0
MSG_NO_ENTRY:          DB              "----",0
MSG_IN_A_OUT_0A:       DB              " IN=A OUT=$0A ",0
MSG_IN_G_C0:           DB              " IN=G C=0 ",0
MSG_OUT_10:            DB              " OUT=$10 ",0
MSG_KIND_FIELD:        DB              "K=$02 ",0
HREC_PTR_EXTRA:        DB              "PTR-EXTR",$C1
MSG_INPUT_HELP:        DB              "TYPE 8 HEX HASH, CR QUIT",0
MSG_INPUT_PROMPT:      DB              "J> ",0
MSG_INPUT_NO_READ:     DB              "INPUT READ NF",0
MSG_USER:              DB              "USER ",0
MSG_USER_BAD:          DB              "USER BAD",0
MSG_OK:                DB              "OK",0
MSG_NF:                DB              "NF",0
MSG_NF_OK:             DB              "NF OK",0
MSG_BAD:               DB              "BAD",0
MSG_DONE:              DB              "DONE",0

                        END

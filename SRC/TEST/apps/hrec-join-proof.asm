; ----------------------------------------------------------------------------
; hrec-join-proof.asm
; RAM-loaded HREC join proof, linked at $3000.
; Proves the "C" path: silently join resident BIO write first, then talk.
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

HREC_HASH_SIG2         EQU             ('V'+$80)
HREC_SCAN_BASE_HI      EQU             $80

                        CODE
START:
                        LDX             #<HASH_BIO_WRITE_BYTE_BLOCK
                        LDY             #>HASH_BIO_WRITE_BYTE_BLOCK
                        JSR             HREC_JOIN_EXEC_XY
                        BCS             START_HAVE_WRITE
                        RTS

START_HAVE_WRITE:
                        STX             HREC_IMP_WRITE_LO
                        STY             HREC_IMP_WRITE_HI

                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             HREC_PRINT_LINE
                        LDX             #<MSG_WRITE
                        LDY             #>MSG_WRITE
                        JSR             HREC_PRINT_OK_LINE

                        LDX             #<HASH_BIO_READ_BYTE_BLOCK
                        LDY             #>HASH_BIO_READ_BYTE_BLOCK
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             TEST_READ_NF
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             HREC_PRINT_OK_LINE
                        BRA             TEST_FLUSH
TEST_READ_NF:
                        LDX             #<MSG_READ
                        LDY             #>MSG_READ
                        JSR             HREC_PRINT_NF_LINE

TEST_FLUSH:
                        LDX             #<HASH_BIO_FLUSH_RX
                        LDY             #>HASH_BIO_FLUSH_RX
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             TEST_FLUSH_NF
                        LDX             #<MSG_FLUSH
                        LDY             #>MSG_FLUSH
                        JSR             HREC_PRINT_OK_LINE
                        BRA             TEST_CTRL
TEST_FLUSH_NF:
                        LDX             #<MSG_FLUSH
                        LDY             #>MSG_FLUSH
                        JSR             HREC_PRINT_NF_LINE

TEST_CTRL:
                        LDX             #<HASH_BIO_GET_CTRL_C
                        LDY             #>HASH_BIO_GET_CTRL_C
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             TEST_CTRL_NF
                        LDX             #<MSG_CTRL
                        LDY             #>MSG_CTRL
                        JSR             HREC_PRINT_OK_LINE
                        BRA             TEST_HEX
TEST_CTRL_NF:
                        LDX             #<MSG_CTRL
                        LDY             #>MSG_CTRL
                        JSR             HREC_PRINT_NF_LINE

TEST_HEX:
                        LDX             #<HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             TEST_HEX_NF
                        LDA             #'A'
                        JSR             HREC_CALL_JOIN
                        BCC             TEST_HEX_BAD
                        CMP             #$0A
                        BNE             TEST_HEX_BAD
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_OK_LINE
                        BRA             TEST_MISSING
TEST_HEX_NF:
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_NF_LINE
                        BRA             TEST_MISSING
TEST_HEX_BAD:
                        LDX             #<MSG_HEX
                        LDY             #>MSG_HEX
                        JSR             HREC_PRINT_BAD_LINE

TEST_MISSING:
                        LDX             #<HASH_NO_SUCH_RECORD
                        LDY             #>HASH_NO_SUCH_RECORD
                        JSR             HREC_JOIN_EXEC_XY
                        BCC             TEST_MISSING_OK
                        LDX             #<MSG_MISSING
                        LDY             #>MSG_MISSING
                        JSR             HREC_PRINT_BAD_LINE
                        BRA             TEST_KIND
TEST_MISSING_OK:
                        LDX             #<MSG_MISSING
                        LDY             #>MSG_MISSING
                        JSR             HREC_PRINT_OK_LINE

TEST_KIND:
                        LDA             #$01
                        JSR             HREC_JOIN_EXEC_KIND
                        BCC             TEST_KIND_OK
                        LDX             #<MSG_KIND
                        LDY             #>MSG_KIND
                        JSR             HREC_PRINT_BAD_LINE
                        BRA             TEST_HEX_INV
TEST_KIND_OK:
                        LDX             #<MSG_KIND
                        LDY             #>MSG_KIND
                        JSR             HREC_PRINT_OK_LINE

TEST_HEX_INV:
                        LDX             #<HASH_UTL_HEX_ASCII_TO_NIBBLE
                        LDY             #>HASH_UTL_HEX_ASCII_TO_NIBBLE
                        JSR             HREC_JOIN_EXEC_XY
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
                        JSR             HREC_PRINT_OK_LINE
                        BRA             TEST_DONE
TEST_HEX_INV_NF:
                        LDX             #<MSG_HEX_INV
                        LDY             #>MSG_HEX_INV
                        JSR             HREC_PRINT_NF_LINE

TEST_DONE:
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             HREC_PRINT_LINE
                        RTS

; ----------------------------------------------------------------------------
; HREC_JOIN_EXEC_XY
; IN : X/Y = pointer to little-endian hash32 bytes.
; OUT: found executable: C=1, A=$00, X/Y=payload entry, HREC_JOIN_LO/HI=entry.
;      missing or non-exec: C=0.
; ----------------------------------------------------------------------------
HREC_JOIN_EXEC_XY:
                        JSR             HREC_FIND_XY
                        BCC             HREC_JOIN_FAIL
HREC_JOIN_EXEC_KIND:
                        BNE             HREC_JOIN_FAIL
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

HREC_CALL_JOIN:
                        JMP             (HREC_JOIN_LO)

HREC_BIO_WRITE_BYTE_BLOCK:
                        JMP             (HREC_IMP_WRITE_LO)

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
HASH_NO_SUCH_RECORD:
                        DB              $EF,$BE,$AD,$DE

MSG_TITLE:             DB              "HREC JOIN PROOF $4000",0
MSG_WRITE:             DB              "WRITE ",0
MSG_READ:              DB              "READ ",0
MSG_FLUSH:             DB              "FLUSH ",0
MSG_CTRL:              DB              "CTRL ",0
MSG_HEX:               DB              "HEX ",0
MSG_MISSING:           DB              "MISSING ",0
MSG_KIND:              DB              "KIND ",0
MSG_HEX_INV:           DB              "HEXINV ",0
MSG_OK:                DB              "OK",0
MSG_NF:                DB              "NF",0
MSG_BAD:               DB              "BAD",0
MSG_DONE:              DB              "DONE",0

                        END

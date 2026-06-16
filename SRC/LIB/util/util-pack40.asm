; ----------------------------------------------------------------------------
; util-pack40.asm
; Compact base-40 text packing helpers.
;
; Alphabet:
;   0      end/pad
;   1-26   A-Z
;   27-36  0-9
;   37     _
;   38     ?
;   39     .
;
; Packed triplet:
;   value = ((c0 * 40) + c1) * 40 + c2
;   bytes are stored little-endian.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          UTL_PACK40
                        XDEF            UTL_PACK40_ASCII_TO_CODE
                        XDEF            UTL_PACK40_CODE_TO_ASCII
                        XDEF            UTL_PACK40_PACK3
                        XDEF            UTL_PACK40_UNPACK3
                        XDEF            UTL_PACK40_PACK_CSTR
                        XDEF            UTL_PACK40_UNPACK_CSTR

; Control block for CSTR pack/unpack routines:
;   +0 source pointer low
;   +1 source pointer high
;   +2 destination pointer low
;   +3 destination pointer high
;   +4 packed byte count: output from PACK_CSTR, input to UNPACK_CSTR
;   +5 unpacked character count: output from both routines

UTL_P40_CB_SRC_LO      EQU             $00
UTL_P40_CB_SRC_HI      EQU             $01
UTL_P40_CB_DST_LO      EQU             $02
UTL_P40_CB_DST_HI      EQU             $03
UTL_P40_CB_PACKED_LEN  EQU             $04
UTL_P40_CB_CHAR_LEN    EQU             $05

; Utility scratch. Same volatile utility-ZP convention as the other UTL modules.
UTL_P40_CB_LO          EQU             $E0
UTL_P40_CB_HI          EQU             $E1
UTL_P40_SRC_LO         EQU             $E2
UTL_P40_SRC_HI         EQU             $E3
UTL_P40_DST_LO         EQU             $E4
UTL_P40_DST_HI         EQU             $E5
UTL_P40_CODE0          EQU             $E6
UTL_P40_CODE1          EQU             $E7
UTL_P40_CODE2          EQU             $E8
UTL_P40_VALUE_LO       EQU             $E9
UTL_P40_VALUE_HI       EQU             $EA
UTL_P40_TMP_LO         EQU             $EB
UTL_P40_TMP_HI         EQU             $EC
UTL_P40_PACKED_LEN     EQU             $ED
UTL_P40_CHAR_LEN       EQU             $EE

                        CODE

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_ASCII_TO_CODE
; IN : A = ASCII byte.
; OUT: C=1,A=PACK40 code on success; C=0,A=source byte on invalid input.
; NOTE: Lowercase letters are accepted and folded to uppercase.
; ----------------------------------------------------------------------------
UTL_PACK40_ASCII_TO_CODE:
                        AND             #$7F
                        BEQ             ?OK_ZERO
                        CMP             #'a'
                        BCC             ?NOT_LOWER
                        CMP             #'{'
                        BCS             ?NOT_LOWER
                        AND             #$DF
?NOT_LOWER:
                        CMP             #'A'
                        BCC             ?CHECK_DIGIT
                        CMP             #'['
                        BCS             ?CHECK_DIGIT
                        SEC
                        SBC             #'@'
                        SEC
                        RTS
?CHECK_DIGIT:
                        CMP             #'0'
                        BCC             ?CHECK_UNDER
                        CMP             #':'
                        BCS             ?CHECK_UNDER
                        SEC
                        SBC             #'0'
                        CLC
                        ADC             #27
                        SEC
                        RTS
?CHECK_UNDER:
                        CMP             #'_'
                        BNE             ?CHECK_Q
                        LDA             #37
                        SEC
                        RTS
?CHECK_Q:
                        CMP             #'?'
                        BNE             ?CHECK_DOT
                        LDA             #38
                        SEC
                        RTS
?CHECK_DOT:
                        CMP             #'.'
                        BNE             ?FAIL
                        LDA             #39
                        SEC
                        RTS
?OK_ZERO:
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_CODE_TO_ASCII
; IN : A = PACK40 code.
; OUT: C=1,A=ASCII byte on success; C=0 on invalid code.
; ----------------------------------------------------------------------------
UTL_PACK40_CODE_TO_ASCII:
                        CMP             #40
                        BCS             ?FAIL
                        CMP             #$00
                        BEQ             ?ZERO
                        CMP             #27
                        BCS             ?NOT_LETTER
                        CLC
                        ADC             #'@'
                        SEC
                        RTS
?NOT_LETTER:
                        CMP             #37
                        BCS             ?SPECIAL
                        CLC
                        ADC             #$15
                        SEC
                        RTS
?SPECIAL:
                        CMP             #37
                        BNE             ?NOT_UNDER
                        LDA             #'_'
                        SEC
                        RTS
?NOT_UNDER:
                        CMP             #38
                        BNE             ?DOT
                        LDA             #'?'
                        SEC
                        RTS
?DOT:
                        LDA             #'.'
                        SEC
                        RTS
?ZERO:
                        LDA             #$00
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_PACK3
; IN : A/X/Y = three PACK40 codes, each 0..39.
; OUT: C=1, X/Y = packed word low/high. C=0 if any code is invalid.
; ----------------------------------------------------------------------------
UTL_PACK40_PACK3:
                        STA             UTL_P40_CODE0
                        STX             UTL_P40_CODE1
                        STY             UTL_P40_CODE2
                        CMP             #40
                        BCS             ?FAIL
                        CPX             #40
                        BCS             ?FAIL
                        CPY             #40
                        BCS             ?FAIL

                        STZ             UTL_P40_VALUE_HI
                        STA             UTL_P40_VALUE_LO
                        JSR             UTL_PACK40_MUL40
                        LDA             UTL_P40_CODE1
                        JSR             UTL_PACK40_ADD_A
                        JSR             UTL_PACK40_MUL40
                        LDA             UTL_P40_CODE2
                        JSR             UTL_PACK40_ADD_A
                        LDX             UTL_P40_VALUE_LO
                        LDY             UTL_P40_VALUE_HI
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

UTL_PACK40_ADD_A:
                        CLC
                        ADC             UTL_P40_VALUE_LO
                        STA             UTL_P40_VALUE_LO
                        BCC             ?DONE
                        INC             UTL_P40_VALUE_HI
?DONE:
                        RTS

UTL_PACK40_MUL40:
                        LDA             UTL_P40_VALUE_LO
                        STA             UTL_P40_TMP_LO
                        LDA             UTL_P40_VALUE_HI
                        STA             UTL_P40_TMP_HI

                        ASL             UTL_P40_VALUE_LO
                        ROL             UTL_P40_VALUE_HI
                        ASL             UTL_P40_VALUE_LO
                        ROL             UTL_P40_VALUE_HI
                        ASL             UTL_P40_VALUE_LO
                        ROL             UTL_P40_VALUE_HI

                        LDX             #$05
?SHIFT32:
                        ASL             UTL_P40_TMP_LO
                        ROL             UTL_P40_TMP_HI
                        DEX
                        BNE             ?SHIFT32

                        CLC
                        LDA             UTL_P40_VALUE_LO
                        ADC             UTL_P40_TMP_LO
                        STA             UTL_P40_VALUE_LO
                        LDA             UTL_P40_VALUE_HI
                        ADC             UTL_P40_TMP_HI
                        STA             UTL_P40_VALUE_HI
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_UNPACK3
; IN : X/Y = packed word low/high.
; OUT: C=1, A/X/Y = three PACK40 codes. C=0 if packed word >= 64000.
; ----------------------------------------------------------------------------
UTL_PACK40_UNPACK3:
                        STX             UTL_P40_VALUE_LO
                        STY             UTL_P40_VALUE_HI
                        CPY             #$FA
                        BCS             ?FAIL

                        STZ             UTL_P40_CODE0
?DIV1600:
                        LDA             UTL_P40_VALUE_HI
                        CMP             #$06
                        BCC             ?DIV1600_DONE
                        BNE             ?SUB1600
                        LDA             UTL_P40_VALUE_LO
                        CMP             #$40
                        BCC             ?DIV1600_DONE
?SUB1600:
                        SEC
                        LDA             UTL_P40_VALUE_LO
                        SBC             #$40
                        STA             UTL_P40_VALUE_LO
                        LDA             UTL_P40_VALUE_HI
                        SBC             #$06
                        STA             UTL_P40_VALUE_HI
                        INC             UTL_P40_CODE0
                        BRA             ?DIV1600

?DIV1600_DONE:
                        STZ             UTL_P40_CODE1
?DIV40:
                        LDA             UTL_P40_VALUE_HI
                        BNE             ?SUB40
                        LDA             UTL_P40_VALUE_LO
                        CMP             #$28
                        BCC             ?DIV40_DONE
?SUB40:
                        SEC
                        LDA             UTL_P40_VALUE_LO
                        SBC             #$28
                        STA             UTL_P40_VALUE_LO
                        LDA             UTL_P40_VALUE_HI
                        SBC             #$00
                        STA             UTL_P40_VALUE_HI
                        INC             UTL_P40_CODE1
                        BRA             ?DIV40

?DIV40_DONE:
                        LDA             UTL_P40_CODE0
                        LDX             UTL_P40_CODE1
                        LDY             UTL_P40_VALUE_LO
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_PACK_CSTR
; IN : X/Y = control block pointer.
; OUT: C=1,A=packed byte count on success. Control block +4/+5 updated.
;      C=0 on invalid source character or output count overflow.
; ----------------------------------------------------------------------------
UTL_PACK40_PACK_CSTR:
                        JSR             UTL_PACK40_LOAD_CB
                        STZ             UTL_P40_PACKED_LEN
                        STZ             UTL_P40_CHAR_LEN

?GROUP:
                        STZ             UTL_P40_CODE0
                        STZ             UTL_P40_CODE1
                        STZ             UTL_P40_CODE2

                        JSR             UTL_PACK40_READ_CODE
                        BCC             ?FAIL
                        BEQ             ?DONE
                        STA             UTL_P40_CODE0

                        JSR             UTL_PACK40_READ_CODE
                        BCC             ?FAIL
                        BEQ             ?EMIT
                        STA             UTL_P40_CODE1

                        JSR             UTL_PACK40_READ_CODE
                        BCC             ?FAIL
                        BEQ             ?EMIT
                        STA             UTL_P40_CODE2

?EMIT:
                        LDA             UTL_P40_CODE0
                        LDX             UTL_P40_CODE1
                        LDY             UTL_P40_CODE2
                        JSR             UTL_PACK40_PACK3
                        BCC             ?FAIL
                        JSR             UTL_PACK40_WRITE_WORD
                        BCC             ?FAIL
                        BRA             ?GROUP

?DONE:
                        JSR             UTL_PACK40_STORE_COUNTS
                        LDA             UTL_P40_PACKED_LEN
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: UTL_PACK40_UNPACK_CSTR
; IN : X/Y = control block pointer; control block +4 = packed byte count.
; OUT: C=1,A=unpacked character count. Destination is NUL-terminated.
;      C=0 on odd byte count, invalid packed word, or output count overflow.
; ----------------------------------------------------------------------------
UTL_PACK40_UNPACK_CSTR:
                        JSR             UTL_PACK40_LOAD_CB
                        LDY             #UTL_P40_CB_PACKED_LEN
                        LDA             (UTL_P40_CB_LO),Y
                        STA             UTL_P40_PACKED_LEN
                        AND             #$01
                        BNE             ?FAIL
                        STZ             UTL_P40_CHAR_LEN

?WORD_LOOP:
                        LDA             UTL_P40_PACKED_LEN
                        BEQ             ?DONE
                        JSR             UTL_PACK40_READ_WORD
                        JSR             UTL_PACK40_UNPACK3
                        BCC             ?FAIL
                        STA             UTL_P40_CODE0
                        STX             UTL_P40_CODE1
                        STY             UTL_P40_CODE2

                        LDA             UTL_P40_CODE0
                        BEQ             ?DONE
                        JSR             UTL_PACK40_WRITE_CODE
                        BCC             ?FAIL
                        LDA             UTL_P40_CODE1
                        BEQ             ?DONE
                        JSR             UTL_PACK40_WRITE_CODE
                        BCC             ?FAIL
                        LDA             UTL_P40_CODE2
                        BEQ             ?DONE
                        JSR             UTL_PACK40_WRITE_CODE
                        BCC             ?FAIL
                        BRA             ?WORD_LOOP

?DONE:
                        JSR             UTL_PACK40_WRITE_NUL
                        JSR             UTL_PACK40_STORE_CHAR_LEN
                        LDA             UTL_P40_CHAR_LEN
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

UTL_PACK40_LOAD_CB:
                        STX             UTL_P40_CB_LO
                        STY             UTL_P40_CB_HI
                        LDY             #UTL_P40_CB_SRC_LO
                        LDA             (UTL_P40_CB_LO),Y
                        STA             UTL_P40_SRC_LO
                        INY
                        LDA             (UTL_P40_CB_LO),Y
                        STA             UTL_P40_SRC_HI
                        INY
                        LDA             (UTL_P40_CB_LO),Y
                        STA             UTL_P40_DST_LO
                        INY
                        LDA             (UTL_P40_CB_LO),Y
                        STA             UTL_P40_DST_HI
                        RTS

UTL_PACK40_STORE_COUNTS:
                        LDY             #UTL_P40_CB_PACKED_LEN
                        LDA             UTL_P40_PACKED_LEN
                        STA             (UTL_P40_CB_LO),Y
                        INY
                        LDA             UTL_P40_CHAR_LEN
                        STA             (UTL_P40_CB_LO),Y
                        RTS

UTL_PACK40_STORE_CHAR_LEN:
                        LDY             #UTL_P40_CB_CHAR_LEN
                        LDA             UTL_P40_CHAR_LEN
                        STA             (UTL_P40_CB_LO),Y
                        RTS

UTL_PACK40_READ_CODE:
                        LDY             #$00
                        LDA             (UTL_P40_SRC_LO),Y
                        BEQ             ?NUL
                        JSR             UTL_PACK40_ASCII_TO_CODE
                        BCC             ?FAIL
                        PHA
                        JSR             UTL_PACK40_INC_SRC
                        INC             UTL_P40_CHAR_LEN
                        BNE             ?COUNT_OK
                        PLA
                        BRA             ?FAIL
?COUNT_OK:
                        PLA
                        SEC
                        RTS
?NUL:
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

UTL_PACK40_WRITE_CODE:
                        JSR             UTL_PACK40_CODE_TO_ASCII
                        BCC             ?FAIL
                        LDY             #$00
                        STA             (UTL_P40_DST_LO),Y
                        JSR             UTL_PACK40_INC_DST
                        INC             UTL_P40_CHAR_LEN
                        BNE             ?OK
?FAIL:
                        CLC
                        RTS
?OK:
                        SEC
                        RTS

UTL_PACK40_WRITE_NUL:
                        LDA             #$00
                        LDY             #$00
                        STA             (UTL_P40_DST_LO),Y
                        RTS

UTL_PACK40_WRITE_WORD:
                        STY             UTL_P40_TMP_HI
                        TXA
                        LDY             #$00
                        STA             (UTL_P40_DST_LO),Y
                        JSR             UTL_PACK40_INC_DST
                        LDA             UTL_P40_TMP_HI
                        LDY             #$00
                        STA             (UTL_P40_DST_LO),Y
                        JSR             UTL_PACK40_INC_DST
                        CLC
                        LDA             UTL_P40_PACKED_LEN
                        ADC             #$02
                        BCS             ?FAIL
                        STA             UTL_P40_PACKED_LEN
                        SEC
                        RTS
?FAIL:
                        CLC
                        RTS

UTL_PACK40_READ_WORD:
                        LDY             #$00
                        LDA             (UTL_P40_SRC_LO),Y
                        TAX
                        JSR             UTL_PACK40_INC_SRC
                        LDY             #$00
                        LDA             (UTL_P40_SRC_LO),Y
                        STA             UTL_P40_TMP_HI
                        JSR             UTL_PACK40_INC_SRC
                        SEC
                        LDA             UTL_P40_PACKED_LEN
                        SBC             #$02
                        STA             UTL_P40_PACKED_LEN
                        LDY             UTL_P40_TMP_HI
                        RTS

UTL_PACK40_INC_SRC:
                        INC             UTL_P40_SRC_LO
                        BNE             ?DONE
                        INC             UTL_P40_SRC_HI
?DONE:
                        RTS

UTL_PACK40_INC_DST:
                        INC             UTL_P40_DST_LO
                        BNE             ?DONE
                        INC             UTL_P40_DST_HI
?DONE:
                        RTS

                        ENDMOD
                        END

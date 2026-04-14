                        XREF            COR_FTDI_INIT
                        XREF            COR_FTDI_FLUSH_RX
                        XREF            COR_FTDI_CHECK_ENUMERATED
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_READ_CHAR_TIMEOUT
                        XREF            COR_FTDI_READ_CHAR_SPINCOUNT
                        XREF            COR_FTDI_READ_CHAR_TIMEOUT_SPINDOWN
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            COR_FTDI_WRITE_CHAR_REPEAT
                        XREF            COR_FTDI_WRITE_CSTRING
                        XREF            COR_FTDI_READ_CSTRING_ECHO
                        XREF            COR_FTDI_READ_CSTRING_SILENT
                        XREF            COR_FTDI_READ_CSTRING_CORE
                        XREF            COR_FTDI_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            COR_FTDI_READ_CHAR_COOKED_ECHO
                        XREF            COR_FTDI_WRITE_CLASS_TAG_A
                        XREF            COR_FTDI_WRITE_VISIBLE_BUFFER
                        XREF            COR_FTDI_WRITE_CLASSIFIED_BUFFER
                        XREF            UTL_DELAY_AXY_8MHZ
                        XREF            UTL_CHAR_IN_RANGE
                        XREF            UTL_CHAR_IS_PRINTABLE
                        XREF            UTL_CHAR_IS_CONTROL
                        XREF            UTL_CHAR_IS_PUNCT
                        XREF            UTL_CHAR_IS_DIGIT
                        XREF            UTL_CHAR_IS_ALPHA
                        XREF            UTL_CHAR_IS_LOWER
                        XREF            UTL_CHAR_IS_UPPER
                        XREF            UTL_FIND_CHAR_CSTR
                        XREF            TST_PUTS_XY
                        XREF            TST_PRINT_LINE_XY
                        XREF            TST_PRINT_CARRY_BIT_A
                        XREF            TST_PRINT_CARRY_FROM_LAST_C

; -------------------------------------------------------------------------
; Backend unit-check harness (interactive where hardware/input is required).
; -------------------------------------------------------------------------

; Fixed RAM reservation requested by user:
; - 512-byte test buffer range at $7C00-$7DFF
TEST_BUF_PAGE0          EQU             $7C00
TEST_BUF_PAGE1          EQU             $7D00
TEST_BUF0_LAST          EQU             $7CFF
TEST_BUF1_LAST          EQU             $7DFF

; Scratch/state bytes for assertions.
TEST_OBS_A              EQU             $7B00
TEST_OBS_C              EQU             $7B01
TEST_EXP_A              EQU             $7B02
TEST_EXP_C              EQU             $7B03
TEST_PASS_COUNT         EQU             $7B04
TEST_FAIL_COUNT         EQU             $7B05
CLASS_LINE_LEN          EQU             $7B06
CLASS_CHAR              EQU             $7B07
CLASS_LINE_IDX          EQU             $7B08
CLASS_TERM_CHAR         EQU             $7B09
STR_FLAG_UPPER          EQU             $7B0A
STR_FLAG_LOWER          EQU             $7B0B
STR_FLAG_NUMERIC        EQU             $7B0C
STR_FLAG_PUNCT          EQU             $7B0D
STR_FLAG_ISPRINT        EQU             $7B0E
STR_FLAG_CTRL           EQU             $7B0F
STR_FLAG_LF             EQU             $7B10
STR_FLAG_CR             EQU             $7B11
W21_SPIN_LO             EQU             $7B12
W21_SPIN_HI             EQU             $7B13
W21_SPIN_CHAR           EQU             $7B14
W21_DOWN_LO             EQU             $7B15
W21_DOWN_HI             EQU             $7B16
W21_SEQ_LEN             EQU             $7B17
W21_SEQ_IDX             EQU             $7B18
FIND_NEEDLE_CHAR        EQU             $7B19
FIND_SCAN_CONSUMED      EQU             $7B1A
FIND_SCAN_PTR_LO        EQU             $7B1B
FIND_SCAN_PTR_HI        EQU             $7B1C

                        CODE 
START:
                        jsr             RESET_TEST_STATE
                        jsr             CLEAR_TEST_BUFFERS
                        jsr             COR_FTDI_INIT
                        jsr             COR_FTDI_FLUSH_RX

                        ldx             #<MSG_HDR_1
                        ldy             #>MSG_HDR_1
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_HDR_2
                        ldy             #>MSG_HDR_2
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_HDR_3
                        ldy             #>MSG_HDR_3
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_WRITE_CRLF

                        jsr             TEST

WAIT_LOOP:              wai
                        bra             WAIT_LOOP


; ----------------------------------------------------------------------------
; Test groups
; ----------------------------------------------------------------------------
TEST:
; ----------------------------------------------------------------------------
; ROUTINE: TEST  [RHID:94EE]
; MEM : ZP: none; FIXED_RAM: test harness scratch/buffers.
; PURPOSE: Backend command-style "routine of routines" orchestrator.
; IN : none
; OUT: pass/fail counters updated; returns to caller for summary/next stage.
; EXCEPTIONS/NOTES:
; - Interactive where visual/human timing confirmation is required.
; ----------------------------------------------------------------------------
TEST_FULLY_INTERACTIVE:
                        ldx             #<MSG_TEST_CMD
                        ldy             #>MSG_TEST_CMD
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_TEST_CMD_NOTE
                        ldy             #>MSG_TEST_CMD_NOTE
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_WRITE_CRLF

                        ; Consolidated interactive battery:
                        ; W18 char loop -> W19 string loop -> W20 delay/flush loop -> W21 timing loop.
                        ; Ctrl-C moves between phases; final Ctrl-C issues `brk $65`.
                        jsr             TEST_W18_CHAR_LOOP
                        jsr             TEST_W19_STRING_LOOP
                        jsr             TEST_W20_DELAY_FLUSH_LOOP
                        jsr             TEST_W21_SPINCOUNT_SPINDOWN_LOOP
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_VISUAL_CASE_CHECK  [RHID:623B]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Human-visible uppercase/lowercase check ("a" then "A").
; ----------------------------------------------------------------------------
TEST_VISUAL_CASE_CHECK:
                        ldx             #<MSG_W11A
                        ldy             #>MSG_W11A
                        jsr             TST_PRINT_LINE_XY

                        lda             #'a'
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #'A'
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W11A_Q
                        ldy             #>MSG_W11A_Q
                        jsr             ASK_YN_RECORD_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_UTL_CHAR_CLASS_VISUAL  [RHID:FE1B]
; MEM : ZP: none; FIXED_RAM: CLASS_CHAR($7B07).
; PURPOSE: Exercise utility character classifiers and show operator-visible flags.
; ----------------------------------------------------------------------------
TEST_UTL_CHAR_CLASS_VISUAL:
                        ldx             #<MSG_W16
                        ldy             #>MSG_W16
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W16_NOTE
                        ldy             #>MSG_W16_NOTE
                        jsr             TST_PRINT_LINE_XY

                        lda             #'A'
                        jsr             PRINT_UTL_FLAGS_A
                        lda             #'a'
                        jsr             PRINT_UTL_FLAGS_A
                        lda             #'5'
                        jsr             PRINT_UTL_FLAGS_A
                        lda             #'!'
                        jsr             PRINT_UTL_FLAGS_A
                        lda             #' '
                        jsr             PRINT_UTL_FLAGS_A

                        ldx             #<MSG_W16_RANGE
                        ldy             #>MSG_W16_RANGE
                        jsr             TST_PUTS_XY
                        lda             #'G'
                        ldx             #'A'
                        ldy             #'['
                        jsr             UTL_CHAR_IN_RANGE
                        jsr             TST_PRINT_CARRY_FROM_LAST_C
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W16_Q
                        ldy             #>MSG_W16_Q
                        jsr             ASK_YN_RECORD_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: PRINT_UTL_FLAGS_A  [RHID:BF90]
; MEM : ZP: none; FIXED_RAM: CLASS_CHAR($7B07).
; PURPOSE: Print utility classifier flags for byte in A.
; IN : A = byte to classify
; OUT: one report line emitted.
; ----------------------------------------------------------------------------
PRINT_UTL_FLAGS_A:
                        sta             CLASS_CHAR

                        ldx             #<MSG_W16_BYTE
                        ldy             #>MSG_W16_BYTE
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             COR_FTDI_WRITE_HEX_BYTE

                        ldx             #<MSG_W16_P
                        ldy             #>MSG_W16_P
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_PRINTABLE
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_C
                        ldy             #>MSG_W16_C
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_CONTROL
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_U
                        ldy             #>MSG_W16_U
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_UPPER
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_L
                        ldy             #>MSG_W16_L
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_LOWER
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_N
                        ldy             #>MSG_W16_N
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_DIGIT
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_A
                        ldy             #>MSG_W16_A
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_ALPHA
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W16_PUN
                        ldy             #>MSG_W16_PUN
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_PUNCT
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_DELAY_CONFIRM_VISUAL  [RHID:8AF7]
; MEM : ZP: none; FIXED_RAM: DELAY_AXY_X_INIT/DELAY_AXY_Y_INIT via delay routine.
; PURPOSE: Human confirmation step for ~6.502s delay behavior.
; ----------------------------------------------------------------------------
TEST_DELAY_CONFIRM_VISUAL:
                        ldx             #<MSG_W17
                        ldy             #>MSG_W17
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W17_NOTE
                        ldy             #>MSG_W17_NOTE
                        jsr             TST_PRINT_LINE_XY

                        lda             #$E5
                        ldx             #$B6
                        ldy             #$F8
                        jsr             UTL_DELAY_AXY_8MHZ

                        ldx             #<MSG_W17_DONE
                        ldy             #>MSG_W17_DONE
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W17_Q
                        ldy             #>MSG_W17_Q
                        jsr             ASK_YN_RECORD_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: ASK_YN_RECORD_XY  [RHID:1EE8]
; MEM : ZP: none; FIXED_RAM: pass/fail counters.
; PURPOSE: Ask a yes/no question and record pass/fail from operator response.
; IN : X/Y = question C-string pointer
; OUT: C=1 on yes, C=0 on no.
; EXCEPTIONS/NOTES:
; - Ctrl-C triggers `brk $65`.
; ----------------------------------------------------------------------------
ASK_YN_RECORD_XY:
                        jsr             TST_PRINT_LINE_XY
?PROMPT:
                        ldx             #<MSG_ASK_YN
                        ldy             #>MSG_ASK_YN
                        jsr             TST_PUTS_XY
?WAIT:
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #$03
                        beq             ?CTRL_C
                        cmp             #'Y'
                        beq             ?YES
                        cmp             #'y'
                        beq             ?YES
                        cmp             #'N'
                        beq             ?NO
                        cmp             #'n'
                        beq             ?NO
                        bra             ?WAIT
?YES:                   jsr             COR_FTDI_WRITE_CHAR
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             RECORD_PASS
                        sec
                        rts
?NO:                    jsr             COR_FTDI_WRITE_CHAR
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             RECORD_FAIL
                        clc
                        rts
?CTRL_C:                jsr             COR_FTDI_WRITE_CRLF
                        ldx             #<MSG_ASK_ABORT
                        ldy             #>MSG_ASK_ABORT
                        jsr             TST_PRINT_LINE_XY
                        brk             $65
                        clc
                        rts

TEST_INIT_FLUSH:
                        ldx             #<MSG_W01
                        ldy             #>MSG_W01
                        jsr             TST_PRINT_LINE_XY

                        jsr             COR_FTDI_INIT
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             CAPTURE_CA

                        lda             TEST_OBS_A              ; ignore A for this check
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

TEST_IS_ENUMERATED:
                        ldx             #<MSG_W02
                        ldy             #>MSG_W02
                        jsr             TST_PRINT_LINE_XY

                        jsr             COR_FTDI_CHECK_ENUMERATED
                        jsr             CAPTURE_CA

                        lda             TEST_OBS_C
                        beq             T02_EXPECT_ZERO
                        cmp             #$01
                        bne             T02_FAIL
                        lda             TEST_OBS_A
                        cmp             #$01
                        beq             T02_PASS
                        bra             T02_FAIL

T02_EXPECT_ZERO:
                        lda             TEST_OBS_A
                        cmp             #$00
                        beq             T02_PASS

T02_FAIL:
                        jsr             RECORD_FAIL
                        ldx             #<MSG_W02_NOTE
                        ldy             #>MSG_W02_NOTE
                        jsr             TST_PRINT_LINE_XY
                        jsr             PRINT_OBS_CA
                        rts

T02_PASS:
                        jsr             RECORD_PASS
                        rts

TEST_SCAN_AND_GET:
                        ldx             #<MSG_W03
                        ldy             #>MSG_W03
                        jsr             TST_PRINT_LINE_XY

                        jsr             COR_FTDI_FLUSH_RX
                        jsr             COR_FTDI_POLL_CHAR
                        jsr             CAPTURE_CA
                        jsr             ASSERT_C_EQ_0

                        ldx             #<MSG_W04
                        ldy             #>MSG_W04
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W04_PROMPT
                        ldy             #>MSG_W04_PROMPT
                        jsr             TST_PRINT_LINE_XY

                        jsr             COR_FTDI_FLUSH_RX
T04_SCAN_WAIT:
                        jsr             COR_FTDI_POLL_CHAR
                        bcc             T04_SCAN_WAIT
                        jsr             CAPTURE_CA
                        jsr             ASSERT_C_EQ_1

                        jsr             COR_FTDI_READ_CHAR
                        jsr             CAPTURE_CA
                        lda             #'S'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        jsr             COR_FTDI_FLUSH_RX
                        rts

TEST_PUT_CHAR:
                        ldx             #<MSG_W05
                        ldy             #>MSG_W05
                        jsr             TST_PRINT_LINE_XY

                        lda             #$00
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             CAPTURE_CA
                        lda             #$00
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        lda             #$FF
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             CAPTURE_CA
                        lda             #$FF
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        lda             #'A'
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             CAPTURE_CA
                        lda             #'A'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

TEST_PUT_CHAR_N:
                        ldx             #<MSG_W06
                        ldy             #>MSG_W06
                        jsr             TST_PRINT_LINE_XY

                        lda             #'N'
                        ldx             #$00
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             CAPTURE_CA
                        lda             #'N'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        lda             #'1'
                        ldx             #$01
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             CAPTURE_CA
                        lda             #'1'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        lda             #'.'
                        ldx             #$FF
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             CAPTURE_CA
                        lda             #'.'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF
                        rts
TEST_PUT_C_STR:
                        ldx             #<MSG_W07
                        ldy             #>MSG_W07
                        jsr             TST_PRINT_LINE_XY

                        lda             #$11                            ; ignored by backend
                        ldx             #<STR_EMPTY
                        ldy             #>STR_EMPTY
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             CAPTURE_CA
                        lda             #$00
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        lda             #$22                            ; ignored by backend
                        ldx             #<STR_ONE
                        ldy             #>STR_ONE
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             CAPTURE_CA
                        lda             #$01
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             #'.'
                        jsr             FILL_BUF_PAGE0_256
                        lda             #$00
                        sta             TEST_BUF0_LAST                  ; NUL at index 255
                        lda             #$33                            ; ignored by backend
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             CAPTURE_CA
                        lda             #$FF
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             #'.'
                        jsr             FILL_BUF_PAGE0_256              ; no NUL anywhere
                        lda             #$44                            ; ignored by backend
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             CAPTURE_CA
                        lda             #$FF
                        sta             TEST_EXP_A
                        lda             #$00
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             #$00                            ; prove A is ignored
                        ldx             #<STR_AB
                        ldy             #>STR_AB
                        jsr             COR_FTDI_WRITE_CSTRING
                        jsr             CAPTURE_CA
                        lda             #$02
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

TEST_GET_C_STR:
                        ldx             #<MSG_W08
                        ldy             #>MSG_W08
                        jsr             TST_PRINT_LINE_XY

                        ldx             #<MSG_W08_PROMPT_FULL
                        ldy             #>MSG_W08_PROMPT_FULL
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             CLEAR_TEST_BUFFERS
                        lda             #$00
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        jsr             CAPTURE_CA
                        lda             #$00
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        ldx             #$00
                        lda             #$00
                        jsr             ASSERT_PAGE0_BYTE_EQ

                        ldx             #<MSG_W08_PROMPT_BS
                        ldy             #>MSG_W08_PROMPT_BS
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             CLEAR_TEST_BUFFERS
                        lda             #$20
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        jsr             CAPTURE_CA
                        jsr             ASSERT_C0_A_BS_OR_DEL
                        ldx             #$00
                        lda             #$00
                        jsr             ASSERT_PAGE0_BYTE_EQ

                        ldx             #<MSG_W08_PROMPT_OK
                        ldy             #>MSG_W08_PROMPT_OK
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             CLEAR_TEST_BUFFERS
                        lda             #$FF
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        jsr             CAPTURE_CA
                        lda             #$02
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        ldx             #$00
                        lda             #'O'
                        jsr             ASSERT_PAGE1_BYTE_EQ
                        ldx             #$01
                        lda             #'K'
                        jsr             ASSERT_PAGE1_BYTE_EQ
                        ldx             #$02
                        lda             #$00
                        jsr             ASSERT_PAGE1_BYTE_EQ
                        rts
TEST_PUT_HEX_BYTE:
                        ldx             #<MSG_W09
                        ldy             #>MSG_W09
                        jsr             TST_PRINT_LINE_XY

                        lda             #$00
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             CAPTURE_CA
                        lda             #$00
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             #$FF
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             CAPTURE_CA
                        lda             #$FF
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

TEST_PUT_CRLF:
                        ldx             #<MSG_W10
                        ldy             #>MSG_W10
                        jsr             TST_PRINT_LINE_XY

                        lda             #$5A
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             CAPTURE_CA
                        lda             #$5A
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

TEST_GET_CHAR_ECHO_COOKED:
                        ldx             #<MSG_W11
                        ldy             #>MSG_W11
                        jsr             TST_PRINT_LINE_XY

                        ldx             #<MSG_W11_PROMPT_Z
                        ldy             #>MSG_W11_PROMPT_Z
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        jsr             CAPTURE_CA
                        lda             #'Z'
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        ldx             #<MSG_W11_PROMPT_ENTER
                        ldy             #>MSG_W11_PROMPT_ENTER
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        jsr             CAPTURE_CA
                        lda             #$0D
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        ldx             #<MSG_W11_PROMPT_BS
                        ldy             #>MSG_W11_PROMPT_BS
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        jsr             CAPTURE_CA
                        lda             #$08
                        sta             TEST_EXP_A
                        lda             #$00
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA

                        ldx             #<MSG_W11_PROMPT_ESC
                        ldy             #>MSG_W11_PROMPT_ESC
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        jsr             CAPTURE_CA
                        jsr             ASSERT_C_EQ_0
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_INTERACTIVE_BATTERY  [RHID:AEA8]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE0/1 plus test scratch bytes.
; PURPOSE: Interactive intensive backend battery with explicit user-driven input.
; IN : none
; OUT: C=1 when battery steps complete; Ctrl-C path executes `brk $65`.
; EXCEPTIONS/NOTES:
; - Runs W12 (char echo/noecho), W13 (string echo/noecho), W14 (timed W).
; - Any Ctrl-C detected in char/timed steps exits to BSO2.
; ----------------------------------------------------------------------------
TEST_INTERACTIVE_BATTERY:
                        jsr             COR_FTDI_WRITE_CRLF
                        ldx             #<MSG_W12_HDR
                        ldy             #>MSG_W12_HDR
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W12_HDR_NOTE
                        ldy             #>MSG_W12_HDR_NOTE
                        jsr             TST_PRINT_LINE_XY

                        jsr             TEST_W12_CHAR_ECHO_NOECHO
                        bcc             TIB_CTRL_C_EXIT
                        ldx             #<MSG_W12_Q
                        ldy             #>MSG_W12_Q
                        jsr             ASK_YN_RECORD_XY
                        jsr             TEST_W13_STRING_ECHO_NOECHO
                        bcc             TIB_CTRL_C_EXIT
                        ldx             #<MSG_W13_Q
                        ldy             #>MSG_W13_Q
                        jsr             ASK_YN_RECORD_XY
                        jsr             TEST_W14_TIMED_W_CHALLENGE
                        bcc             TIB_CTRL_C_EXIT
                        ldx             #<MSG_W14_Q
                        ldy             #>MSG_W14_Q
                        jsr             ASK_YN_RECORD_XY
                        sec
                        rts

TIB_CTRL_C_EXIT:
                        jsr             COR_FTDI_WRITE_CRLF
                        ldx             #<MSG_W12_EXIT
                        ldy             #>MSG_W12_EXIT
                        jsr             TST_PRINT_LINE_XY
                        brk             $65
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W12_CHAR_ECHO_NOECHO  [RHID:8306]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Prompt for noecho char and echo char, then confirm entered value.
; IN : none
; OUT: C=1 complete; C=0 on Ctrl-C.
; ----------------------------------------------------------------------------
TEST_W12_CHAR_ECHO_NOECHO:
                        ldx             #<MSG_W12
                        ldy             #>MSG_W12
                        jsr             TST_PRINT_LINE_XY

                        ldx             #<MSG_W12_NOECHO_PROMPT
                        ldy             #>MSG_W12_NOECHO_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        jsr             READ_PRINTABLE_CHAR_RAW_OR_CTRL_C
                        bcc             ?CTRL_C
                        jsr             PRINT_ENTERED_PRINTABLE_A

                        ldx             #<MSG_W12_ECHO_PROMPT
                        ldy             #>MSG_W12_ECHO_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
?ECHO_WAIT:             jsr             COR_FTDI_READ_CHAR_COOKED_ECHO
                        bcs             ?ECHO_CLASSIFY
                        cmp             #$03
                        beq             ?CTRL_C
                        bra             ?ECHO_WAIT
?ECHO_CLASSIFY:         cmp             #' '
                        bcc             ?ECHO_WAIT
                        cmp             #$7F
                        bcs             ?ECHO_WAIT
?ECHO_OK:               jsr             PRINT_ENTERED_PRINTABLE_A
                        sec
                        rts
?CTRL_C:                clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W13_STRING_ECHO_NOECHO  [RHID:0BF4]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE0/1.
; PURPOSE: Prompt for noecho and echo strings, then print captured result.
; IN : none
; OUT: C=1 complete.
; EXCEPTIONS/NOTES:
; - Uses backend line readers directly to validate both modes.
; ----------------------------------------------------------------------------
TEST_W13_STRING_ECHO_NOECHO:
                        ldx             #<MSG_W13
                        ldy             #>MSG_W13
                        jsr             TST_PRINT_LINE_XY

                        ldx             #<MSG_W13_NOECHO_PROMPT
                        ldy             #>MSG_W13_NOECHO_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_READ_CSTRING_SILENT
                        jsr             CAPTURE_CA
                        ldx             #<MSG_W13_STATUS
                        ldy             #>MSG_W13_STATUS
                        jsr             TST_PRINT_LINE_XY
                        jsr             PRINT_OBS_CA
                        ldx             #<MSG_W13_CAPTURE
                        ldy             #>MSG_W13_CAPTURE
                        jsr             TST_PUTS_XY
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W13_ECHO_PROMPT
                        ldy             #>MSG_W13_ECHO_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             COR_FTDI_READ_CSTRING_ECHO
                        jsr             CAPTURE_CA
                        ldx             #<MSG_W13_STATUS
                        ldy             #>MSG_W13_STATUS
                        jsr             TST_PRINT_LINE_XY
                        jsr             PRINT_OBS_CA
                        ldx             #<MSG_W13_CAPTURE
                        ldy             #>MSG_W13_CAPTURE
                        jsr             TST_PUTS_XY
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W14_TIMED_W_CHALLENGE  [RHID:C059]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Timed challenge: enter uppercase W before 6.502-second deadline.
; IN : none
; OUT: C=1 complete; C=0 on Ctrl-C.
; EXCEPTIONS/NOTES:
; - Uses UTL_DELAY_AXY_8MHZ max clamp (A=$E5, X=$B6, Y=$F8) for ~6.502 s.
; ----------------------------------------------------------------------------
TEST_W14_TIMED_W_CHALLENGE:
                        ldx             #<MSG_W14
                        ldy             #>MSG_W14
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W14_PROMPT
                        ldy             #>MSG_W14_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX
                        lda             #$E5                            ; ~229 * 28.39ms ~= 6.502s
                        jsr             COR_FTDI_READ_CHAR_TIMEOUT
                        bcc             ?TMO_OR_FAIL
                        cmp             #$03
                        beq             ?CTRL_C
                        cmp             #'W'
                        beq             ?SUCCESS

                        pha
                        ldx             #<MSG_W14_FAIL_WRONG
                        ldy             #>MSG_W14_FAIL_WRONG
                        jsr             TST_PUTS_XY
                        pla
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        lda             #'-'
                        ldx             #$06
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

?TMO_OR_FAIL:           cmp             #$FD
                        beq             ?TIMEOUT
                        pha
                        ldx             #<MSG_W14_FAIL_WRONG
                        ldy             #>MSG_W14_FAIL_WRONG
                        jsr             TST_PUTS_XY
                        pla
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

?TIMEOUT:               ldx             #<MSG_W14_FAIL_TIMEOUT
                        ldy             #>MSG_W14_FAIL_TIMEOUT
                        jsr             TST_PRINT_LINE_XY
                        lda             #'!'
                        ldx             #$06
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

?SUCCESS:               ldx             #<MSG_W14_SUCCESS
                        ldy             #>MSG_W14_SUCCESS
                        jsr             TST_PRINT_LINE_XY
                        lda             #'+'
                        ldx             #$06
                        jsr             COR_FTDI_WRITE_CHAR_REPEAT
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

?CTRL_C:                clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: READ_PRINTABLE_CHAR_RAW_OR_CTRL_C  [RHID:6490]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Read one raw printable ASCII char without echo, allow Ctrl-C escape.
; IN : none
; OUT: C=1 with printable char in A; C=0 on Ctrl-C.
; ----------------------------------------------------------------------------
READ_PRINTABLE_CHAR_RAW_OR_CTRL_C:
?LOOP:                  jsr             COR_FTDI_READ_CHAR
                        cmp             #$03
                        beq             ?CTRL_C
                        cmp             #' '
                        bcc             ?LOOP
                        cmp             #$7F
                        bcs             ?LOOP
                        sec
                        rts
?CTRL_C:                clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: HEX_ASCII_TO_NIBBLE  [RHID:0B2F]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Convert one ASCII hex digit to nibble value.
; IN : A = ASCII candidate
; OUT: C=1 and A=0..15 when valid; C=0 when invalid
; ----------------------------------------------------------------------------
HEX_ASCII_TO_NIBBLE:
                        cmp             #'0'
                        bcc             HXN_BAD
                        cmp             #':'
                        bcc             HXN_DIGIT
                        cmp             #'A'
                        bcc             HXN_CHECK_LOWER
                        cmp             #'G'
                        bcc             HXN_UPPER
HXN_CHECK_LOWER:
                        cmp             #'a'
                        bcc             HXN_BAD
                        cmp             #'g'
                        bcs             HXN_BAD
                        sec
                        sbc             #$57                            ; 'a'..'f' -> 10..15
                        sec
                        rts
HXN_UPPER:
                        sec
                        sbc             #$37                            ; 'A'..'F' -> 10..15
                        sec
                        rts
HXN_DIGIT:
                        sec
                        sbc             #'0'
                        sec
                        rts
HXN_BAD:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: READ_HEX_BYTE_OR_CTRL_C  [RHID:F912]
; MEM : ZP: none; FIXED_RAM: FIND_SCAN_CONSUMED($7B1A) as temporary high nibble.
; PURPOSE: Read one byte as two ASCII hex digits without echo.
; IN : none
; OUT: C=1 with byte in A when two valid digits are received; C=0 on Ctrl-C.
; EXCEPTIONS/NOTES:
; - Invalid characters are ignored and input continues.
; ----------------------------------------------------------------------------
READ_HEX_BYTE_OR_CTRL_C:
RHX_READ_HI:
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #$03
                        beq             RHX_CTRL_C
                        jsr             HEX_ASCII_TO_NIBBLE
                        bcc             RHX_READ_HI
                        asl             a
                        asl             a
                        asl             a
                        asl             a
                        sta             FIND_SCAN_CONSUMED

RHX_READ_LO:
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #$03
                        beq             RHX_CTRL_C
                        jsr             HEX_ASCII_TO_NIBBLE
                        bcc             RHX_READ_LO
                        ora             FIND_SCAN_CONSUMED
                        sec
                        rts

RHX_CTRL_C:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: PRINT_ENTERED_PRINTABLE_A  [RHID:BCC8]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Print confirmation line for entered printable char in A.
; IN : A = printable ASCII char
; OUT: line emitted: `'X' was entered (A=$58)`.
; ----------------------------------------------------------------------------
PRINT_ENTERED_PRINTABLE_A:
                        pha
                        ldx             #<MSG_W12_ENTERED_PREFIX
                        ldy             #>MSG_W12_ENTERED_PREFIX
                        jsr             TST_PUTS_XY
                        pla
                        pha
                        jsr             COR_FTDI_WRITE_CHAR
                        ldx             #<MSG_W12_ENTERED_MID
                        ldy             #>MSG_W12_ENTERED_MID
                        jsr             TST_PUTS_XY
                        pla
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             #')'
                        jsr             COR_FTDI_WRITE_CHAR
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W18_CHAR_LOOP  [RHID:DD79]
; MEM : ZP: none; FIXED_RAM: CLASS_CHAR.
; PURPOSE: Consolidated char test loop (type key -> show class/value/printability).
; IN : none
; OUT: loops until Ctrl-C, then returns to next test phase.
; EXCEPTIONS/NOTES:
; - Uses raw `COR_FTDI_READ_CHAR` (no echo).
; ----------------------------------------------------------------------------
TEST_W18_CHAR_LOOP:
                        ldx             #<MSG_W18
                        ldy             #>MSG_W18
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W18_NOTE
                        ldy             #>MSG_W18_NOTE
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX

W18_LOOP:
                        jsr             RESET_W18_LOOP_STATE
                        ldx             #<MSG_W18_PROMPT
                        ldy             #>MSG_W18_PROMPT
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #$03
                        beq             W18_EXIT
                        sta             CLASS_CHAR

                        ldx             #<MSG_W18_TYPE
                        ldy             #>MSG_W18_TYPE
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             COR_FTDI_WRITE_CLASS_TAG_A
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W18_CHAR
                        ldy             #>MSG_W18_CHAR
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        cmp             #' '
                        bcc             W18_NONPRINT
                        cmp             #$7F
                        bcs             W18_NONPRINT
                        lda             #$27
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             CLASS_CHAR
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #$27
                        jsr             COR_FTDI_WRITE_CHAR
                        bra             W18_CHAR_DONE
W18_NONPRINT:
                        ldx             #<MSG_W18_NONPRINT
                        ldy             #>MSG_W18_NONPRINT
                        jsr             TST_PUTS_XY
W18_CHAR_DONE:
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W18_HEX
                        ldy             #>MSG_W18_HEX
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W18_ISPRINT
                        ldy             #>MSG_W18_ISPRINT
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_PRINTABLE
                        jsr             TST_PRINT_CARRY_FROM_LAST_C
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W18_LOOP

W18_EXIT:
                        ldx             #<MSG_W18_EXIT
                        ldy             #>MSG_W18_EXIT
                        jsr             TST_PRINT_LINE_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W19_STRING_LOOP  [RHID:90C7]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1 + string/class scratch bytes.
; PURPOSE: Consolidated string loop with visible text, length, and aggregate flags.
; IN : none
; OUT: loops until Ctrl-C, then returns to next test phase.
; EXCEPTIONS/NOTES:
; - Input line capture is raw and supports Ctrl-C escape.
; ----------------------------------------------------------------------------
TEST_W19_STRING_LOOP:
                        ldx             #<MSG_W19
                        ldy             #>MSG_W19
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W19_NOTE
                        ldy             #>MSG_W19_NOTE
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX

W19_LOOP:
                        jsr             RESET_W19_LOOP_STATE
                        ldx             #<MSG_W19_PROMPT
                        ldy             #>MSG_W19_PROMPT
                        jsr             TST_PUTS_XY
                        jsr             READ_CLASSIFY_LINE_OR_CTRL_C
                        bcc             W19_EXIT
                        jsr             REPORT_PAGE1_STRING_SUMMARY
                        jsr             REPORT_PAGE1_FIND_CHAR_SUMMARY
                        bcc             W19_EXIT
                        lda             CLASS_LINE_LEN
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             COR_FTDI_WRITE_CLASSIFIED_BUFFER
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W19_LOOP

W19_EXIT:
                        ldx             #<MSG_W19_EXIT
                        ldy             #>MSG_W19_EXIT
                        jsr             TST_PRINT_LINE_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: REPORT_PAGE1_STRING_SUMMARY  [RHID:EF2C]
; MEM : ZP: none; FIXED_RAM: CLASS_LINE_LEN/TERM, CLASS_LINE_IDX, and STR_FLAG_* bytes.
; PURPOSE: Emit compact summary for captured line in TEST_BUF_PAGE1.
; IN : CLASS_LINE_LEN + TEST_BUF_PAGE1 payload + CLASS_TERM_CHAR.
; OUT: summary lines printed (string, length, flags).
; ----------------------------------------------------------------------------
REPORT_PAGE1_STRING_SUMMARY:
                        ldx             #<MSG_W19_STRING_LABEL
                        ldy             #>MSG_W19_STRING_LABEL
                        jsr             TST_PUTS_XY
                        lda             CLASS_LINE_LEN
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             COR_FTDI_WRITE_VISIBLE_BUFFER
                        jsr             COR_FTDI_WRITE_CRLF

                        ldx             #<MSG_W19_STRLEN
                        ldy             #>MSG_W19_STRLEN
                        jsr             TST_PUTS_XY
                        lda             CLASS_LINE_LEN
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF

                        jsr             RESET_STRING_FLAGS
                        stz             CLASS_LINE_IDX
RPS_LOOP:
                        ldx             CLASS_LINE_IDX
                        cpx             CLASS_LINE_LEN
                        beq             RPS_DONE_SCAN
                        lda             TEST_BUF_PAGE1,x
                        sta             CLASS_CHAR

                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_PRINTABLE
                        bcs             RPS_PRINT_OK
                        stz             STR_FLAG_ISPRINT
RPS_PRINT_OK:
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_CONTROL
                        bcc             RPS_CTRL_DONE
                        lda             #$01
                        sta             STR_FLAG_CTRL
RPS_CTRL_DONE:
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_UPPER
                        bcc             RPS_UPPER_DONE
                        lda             #$01
                        sta             STR_FLAG_UPPER
RPS_UPPER_DONE:
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_LOWER
                        bcc             RPS_LOWER_DONE
                        lda             #$01
                        sta             STR_FLAG_LOWER
RPS_LOWER_DONE:
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_DIGIT
                        bcc             RPS_NUM_DONE
                        lda             #$01
                        sta             STR_FLAG_NUMERIC
RPS_NUM_DONE:
                        lda             CLASS_CHAR
                        jsr             UTL_CHAR_IS_PUNCT
                        bcc             RPS_PUN_DONE
                        lda             #$01
                        sta             STR_FLAG_PUNCT
RPS_PUN_DONE:
                        inc             CLASS_LINE_IDX
                        bra             RPS_LOOP

RPS_DONE_SCAN:
                        lda             CLASS_TERM_CHAR
                        cmp             #$0A
                        bne             RPS_NO_LF
                        lda             #$01
                        sta             STR_FLAG_LF
RPS_NO_LF:
                        lda             CLASS_TERM_CHAR
                        cmp             #$0D
                        bne             RPS_NO_CR
                        lda             #$01
                        sta             STR_FLAG_CR
RPS_NO_CR:
                        ldx             #<MSG_W19_FLAGS_U
                        ldy             #>MSG_W19_FLAGS_U
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_UPPER
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_L
                        ldy             #>MSG_W19_FLAGS_L
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_LOWER
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_N
                        ldy             #>MSG_W19_FLAGS_N
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_NUMERIC
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_PUN
                        ldy             #>MSG_W19_FLAGS_PUN
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_PUNCT
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_PRINT
                        ldy             #>MSG_W19_FLAGS_PRINT
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_ISPRINT
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_CTRL
                        ldy             #>MSG_W19_FLAGS_CTRL
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_CTRL
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_LF
                        ldy             #>MSG_W19_FLAGS_LF
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_LF
                        jsr             TST_PRINT_CARRY_BIT_A

                        ldx             #<MSG_W19_FLAGS_CR
                        ldy             #>MSG_W19_FLAGS_CR
                        jsr             TST_PUTS_XY
                        lda             STR_FLAG_CR
                        jsr             TST_PRINT_CARRY_BIT_A
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: REPORT_PAGE1_FIND_CHAR_SUMMARY  [RHID:396B]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1, FIND_* scratch bytes.
; PURPOSE: Prompt for needle and run UTL_FIND_CHAR_CSTR on current W19 line.
; IN : TEST_BUF_PAGE1 must be NUL-terminated.
; OUT: C=1 continue W19 loop; C=0 on Ctrl-C from needle prompt.
; EXCEPTIONS/NOTES:
; - Needle prompt accepts two hex digits for full byte range (00..FF).
; ----------------------------------------------------------------------------
REPORT_PAGE1_FIND_CHAR_SUMMARY:
                        ldx             #<MSG_W19_FIND_PROMPT
                        ldy             #>MSG_W19_FIND_PROMPT
                        jsr             TST_PUTS_XY
                        jsr             READ_HEX_BYTE_OR_CTRL_C
                        bcc             RPF_CTRL_C
                        sta             FIND_NEEDLE_CHAR

                        ldx             #<MSG_W19_FIND_NEEDLE
                        ldy             #>MSG_W19_FIND_NEEDLE
                        jsr             TST_PUTS_XY
                        lda             FIND_NEEDLE_CHAR
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             FIND_NEEDLE_CHAR
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             UTL_FIND_CHAR_CSTR
                        php
                        sta             FIND_SCAN_CONSUMED
                        stx             FIND_SCAN_PTR_LO
                        sty             FIND_SCAN_PTR_HI

                        ldx             #<MSG_W19_FIND_C
                        ldy             #>MSG_W19_FIND_C
                        jsr             TST_PUTS_XY
                        plp
                        jsr             TST_PRINT_CARRY_FROM_LAST_C

                        ldx             #<MSG_W19_FIND_CONSUMED
                        ldy             #>MSG_W19_FIND_CONSUMED
                        jsr             TST_PUTS_XY
                        lda             FIND_SCAN_CONSUMED
                        jsr             COR_FTDI_WRITE_HEX_BYTE

                        ldx             #<MSG_W19_FIND_PTR
                        ldy             #>MSG_W19_FIND_PTR
                        jsr             TST_PUTS_XY
                        lda             FIND_SCAN_PTR_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             FIND_SCAN_PTR_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        sec
                        rts

RPF_CTRL_C:
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: RESET_STRING_FLAGS  [RHID:6616]
; MEM : ZP: none; FIXED_RAM: STR_FLAG_*.
; PURPOSE: Clear per-line aggregate flags and set ISPRINT optimistic default.
; ----------------------------------------------------------------------------
RESET_STRING_FLAGS:
                        stz             STR_FLAG_UPPER
                        stz             STR_FLAG_LOWER
                        stz             STR_FLAG_NUMERIC
                        stz             STR_FLAG_PUNCT
                        stz             STR_FLAG_CTRL
                        stz             STR_FLAG_LF
                        stz             STR_FLAG_CR
                        lda             #$01
                        sta             STR_FLAG_ISPRINT
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: PRINT_PAGE1_VISIBLE  [RHID:BA26]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1 + CLASS_LINE_LEN.
; PURPOSE: Print captured line with non-print bytes rendered as '.'.
; ----------------------------------------------------------------------------
PRINT_PAGE1_VISIBLE:
                        lda             CLASS_LINE_LEN
                        bne             PPV_HAS_DATA
                        ldx             #<MSG_W15_EMPTY
                        ldy             #>MSG_W15_EMPTY
                        jsr             TST_PUTS_XY
                        rts

PPV_HAS_DATA:
                        ldx             #$00
PPV_LOOP:
                        cpx             CLASS_LINE_LEN
                        beq             PPV_DONE
                        lda             TEST_BUF_PAGE1,x
                        cmp             #' '
                        bcc             PPV_DOT
                        cmp             #$7F
                        bcs             PPV_DOT
                        jsr             COR_FTDI_WRITE_CHAR
                        bra             PPV_NEXT
PPV_DOT:
                        lda             #'.'
                        jsr             COR_FTDI_WRITE_CHAR
PPV_NEXT:
                        inx
                        bra             PPV_LOOP
PPV_DONE:
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W20_DELAY_FLUSH_LOOP  [RHID:E2B2]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Timed-input and flush exercise, fully interactive and repeatable.
; IN : none
; OUT: loops until Ctrl-C, then returns so next stage can run.
; EXCEPTIONS/NOTES:
; - Delay challenge uses `COR_FTDI_READ_CHAR_TIMEOUT` with A=$E5 (~6.502s).
; - Flush probe invites typing, then flushes and verifies timeout on short window.
; ----------------------------------------------------------------------------
TEST_W20_DELAY_FLUSH_LOOP:
                        ldx             #<MSG_W20
                        ldy             #>MSG_W20
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W20_NOTE
                        ldy             #>MSG_W20_NOTE
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX

W20_LOOP:
                        ldx             #<MSG_W20_DELAY_PROMPT
                        ldy             #>MSG_W20_DELAY_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        lda             #$E5                            ; ~6.502s at 8MHz helper clamp
                        jsr             COR_FTDI_READ_CHAR_TIMEOUT
                        bcc             W20_DELAY_TMO_OR_FAIL
                        cmp             #$03
                        bne             W20_DELAY_HAVE_CHAR
                        jmp             W20_EXIT
W20_DELAY_HAVE_CHAR:
                        ldx             #<MSG_W20_DELAY_INTERRUPTED
                        ldy             #>MSG_W20_DELAY_INTERRUPTED
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W20_FLUSH_PHASE

W20_DELAY_TMO_OR_FAIL:
                        cmp             #$FD
                        beq             W20_DELAY_TIMEOUT
                        ldx             #<MSG_W20_DELAY_INTERRUPTED
                        ldy             #>MSG_W20_DELAY_INTERRUPTED
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W20_FLUSH_PHASE

W20_DELAY_TIMEOUT:
                        ldx             #<MSG_W20_DELAY_COMPLETE
                        ldy             #>MSG_W20_DELAY_COMPLETE
                        jsr             TST_PRINT_LINE_XY

W20_FLUSH_PHASE:
                        ldx             #<MSG_W20_FLUSH_STAGE
                        ldy             #>MSG_W20_FLUSH_STAGE
                        jsr             TST_PRINT_LINE_XY
                        lda             #$20                            ; ~0.9s "type now" staging window
                        ldx             #$00
                        ldy             #$00
                        jsr             UTL_DELAY_AXY_8MHZ
                        jsr             COR_FTDI_FLUSH_RX

                        ldx             #<MSG_W20_FLUSH_CHECK
                        ldy             #>MSG_W20_FLUSH_CHECK
                        jsr             TST_PRINT_LINE_XY
                        lda             #$20                            ; short post-flush probe
                        jsr             COR_FTDI_READ_CHAR_TIMEOUT
                        bcc             W20_FLUSH_TMO_OR_FAIL
                        cmp             #$03
                        bne             W20_FLUSH_HAVE_CHAR
                        jmp             W20_EXIT
W20_FLUSH_HAVE_CHAR:
                        ldx             #<MSG_W20_FLUSH_LEFTOVER
                        ldy             #>MSG_W20_FLUSH_LEFTOVER
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W20_LOOP

W20_FLUSH_TMO_OR_FAIL:
                        cmp             #$FD
                        beq             W20_FLUSH_OK
                        ldx             #<MSG_W20_FLUSH_LEFTOVER
                        ldy             #>MSG_W20_FLUSH_LEFTOVER
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             COR_FTDI_WRITE_CRLF
                        jmp             W20_LOOP

W20_FLUSH_OK:
                        ldx             #<MSG_W20_FLUSH_OK
                        ldy             #>MSG_W20_FLUSH_OK
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_WRITE_CRLF
                        jmp             W20_LOOP

W20_EXIT:
                        ldx             #<MSG_W20_EXIT
                        ldy             #>MSG_W20_EXIT
                        jsr             TST_PRINT_LINE_XY
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_W21_SPINCOUNT_SPINDOWN_LOOP  [RHID:5195]
; MEM : ZP: none; FIXED_RAM: W21_SPIN_*/W21_DOWN_*/W21_SEQ_* scratch bytes.
; PURPOSE: Live reaction-time spin test with real-time spin-up/spin-down counters.
; IN : none
; OUT: loops until Ctrl-C, then executes `brk $65`.
; EXCEPTIONS/NOTES:
; - Flushes RX before each run to avoid stale-input "cheat" keypresses.
; - Prints one CR-refreshed status line (no LF) until a key event arrives.
; - Captures ESC-led multi-byte sequences (ANSI/VT100 style) for classification.
; ----------------------------------------------------------------------------
TEST_W21_SPINCOUNT_SPINDOWN_LOOP:
                        ldx             #<MSG_W21
                        ldy             #>MSG_W21
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W21_NOTE
                        ldy             #>MSG_W21_NOTE
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W21_NOTE2
                        ldy             #>MSG_W21_NOTE2
                        jsr             TST_PRINT_LINE_XY

W21_LOOP:
                        jsr             RESET_W21_LOOP_STATE
                        jsr             COR_FTDI_FLUSH_RX
                        ldx             #<MSG_W21_SPIN_PROMPT
                        ldy             #>MSG_W21_SPIN_PROMPT
                        jsr             TST_PRINT_LINE_XY
                        stz             W21_SPIN_LO
                        stz             W21_SPIN_HI
                        lda             #$FF
                        sta             W21_DOWN_LO
                        sta             W21_DOWN_HI

W21_RT_LOOP:
                        jsr             W21_WRITE_COUNTER_LINE
                        jsr             COR_FTDI_POLL_CHAR
                        bcc             W21_RT_TICK
                        jsr             COR_FTDI_READ_CHAR
                        sta             W21_SPIN_CHAR
                        ldx             #$00
                        sta             TEST_BUF_PAGE0,x
                        lda             #$01
                        sta             W21_SEQ_LEN
                        lda             W21_SPIN_CHAR
                        cmp             #$1B
                        bne             W21_RT_EVENT_READY
                        jsr             W21_CAPTURE_ESC_TAIL
W21_RT_EVENT_READY:
                        jsr             COR_FTDI_WRITE_CRLF
                        lda             W21_SPIN_CHAR
                        cmp             #$03
                        bne             W21_REPORT_EVENT
                        jmp             W21_EXIT

W21_REPORT_EVENT:
                        ldx             #<MSG_W21_SUMMARY
                        ldy             #>MSG_W21_SUMMARY
                        jsr             TST_PUTS_XY
                        lda             W21_SPIN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             W21_SPIN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_W21_SUMMARY_MID
                        ldy             #>MSG_W21_SUMMARY_MID
                        jsr             TST_PUTS_XY
                        lda             W21_DOWN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             W21_DOWN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        jsr             W21_PRINT_CAPTURED_RAW

                        ldx             #<MSG_W21_CLASSIFIED
                        ldy             #>MSG_W21_CLASSIFIED
                        jsr             TST_PRINT_LINE_XY
                        lda             W21_SEQ_LEN
                        ldx             #<TEST_BUF_PAGE0
                        ldy             #>TEST_BUF_PAGE0
                        jsr             COR_FTDI_WRITE_CLASSIFIED_BUFFER
                        jsr             W21_PRINT_DECODED_EVENT
                        jsr             COR_FTDI_WRITE_CRLF
                        jmp             W21_LOOP

W21_RT_TICK:
                        lda             #$01
                        ldx             #$B6
                        ldy             #$F8
                        jsr             UTL_DELAY_AXY_8MHZ
                        inc             W21_SPIN_LO
                        bne             W21_RT_UP_DONE
                        inc             W21_SPIN_HI
W21_RT_UP_DONE:
                        lda             W21_DOWN_LO
                        bne             W21_RT_DOWN_DEC
                        dec             W21_DOWN_HI
W21_RT_DOWN_DEC:
                        dec             W21_DOWN_LO
                        jmp             W21_RT_LOOP

W21_EXIT:
                        ldx             #<MSG_W21_EXIT
                        ldy             #>MSG_W21_EXIT
                        jsr             TST_PRINT_LINE_XY
                        brk             $65
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: W21_WRITE_COUNTER_LINE  [RHID:86FE]
; MEM : ZP: none; FIXED_RAM: W21_SPIN_LO/HI, W21_DOWN_LO/HI.
; PURPOSE: Emit one CR-terminated live counter line (no LF).
; ----------------------------------------------------------------------------
W21_WRITE_COUNTER_LINE:
                        ldx             #<MSG_W21_RT_PREFIX
                        ldy             #>MSG_W21_RT_PREFIX
                        jsr             TST_PUTS_XY
                        lda             W21_SPIN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             W21_SPIN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_W21_RT_MID
                        ldy             #>MSG_W21_RT_MID
                        jsr             TST_PUTS_XY
                        lda             W21_DOWN_HI
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             W21_DOWN_LO
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_W21_RT_SUFFIX
                        ldy             #>MSG_W21_RT_SUFFIX
                        jsr             TST_PUTS_XY
                        lda             #$0D
                        jsr             COR_FTDI_WRITE_CHAR
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: W21_CAPTURE_ESC_TAIL  [RHID:C18D]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE0, W21_SEQ_LEN.
; PURPOSE: Capture trailing bytes after initial ESC using short timeout slices.
; IN : TEST_BUF_PAGE0[0] already holds ESC, W21_SEQ_LEN starts at 1.
; OUT: TEST_BUF_PAGE0 + W21_SEQ_LEN updated with captured sequence.
; ----------------------------------------------------------------------------
W21_CAPTURE_ESC_TAIL:
W21_ESC_TAIL_LOOP:
                        lda             #$02                            ; short gap timeout (~56ms)
                        jsr             COR_FTDI_READ_CHAR_TIMEOUT
                        bcc             W21_ESC_TAIL_DONE
                        ldx             W21_SEQ_LEN
                        cpx             #$20
                        bcs             W21_ESC_TAIL_DONE
                        sta             TEST_BUF_PAGE0,x
                        inc             W21_SEQ_LEN
                        bra             W21_ESC_TAIL_LOOP
W21_ESC_TAIL_DONE:
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: W21_PRINT_CAPTURED_RAW  [RHID:3F4C]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE0, W21_SEQ_LEN, W21_SEQ_IDX.
; PURPOSE: Emit captured key event bytes as hex octets.
; ----------------------------------------------------------------------------
W21_PRINT_CAPTURED_RAW:
                        ldx             #<MSG_W21_RAW
                        ldy             #>MSG_W21_RAW
                        jsr             TST_PUTS_XY
                        stz             W21_SEQ_IDX
W21_RAW_LOOP:
                        lda             W21_SEQ_IDX
                        cmp             W21_SEQ_LEN
                        beq             W21_RAW_DONE
                        ldx             W21_SEQ_IDX
                        lda             TEST_BUF_PAGE0,x
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        inc             W21_SEQ_IDX
                        lda             W21_SEQ_IDX
                        cmp             W21_SEQ_LEN
                        beq             W21_RAW_LOOP
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        bra             W21_RAW_LOOP
W21_RAW_DONE:
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: W21_PRINT_DECODED_EVENT  [RHID:6C3F]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE0, W21_SEQ_LEN.
; PURPOSE: Decode common ANSI/VT100-style key sequences into a human label.
; ----------------------------------------------------------------------------
W21_PRINT_DECODED_EVENT:
                        ldx             #<MSG_W21_DECODE_PREFIX
                        ldy             #>MSG_W21_DECODE_PREFIX
                        jsr             TST_PUTS_XY

                        lda             W21_SEQ_LEN
                        bne             W21_DEC_HAVE_DATA
                        ldx             #<MSG_W21_DEC_UNKNOWN
                        ldy             #>MSG_W21_DEC_UNKNOWN
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_HAVE_DATA:
                        ldx             #$00
                        lda             TEST_BUF_PAGE0,x
                        cmp             #$03
                        beq             W21_DEC_CTRL_C
                        cmp             #$1B
                        beq             W21_DEC_ESC
                        lda             W21_SEQ_LEN
                        cmp             #$01
                        bne             W21_DEC_MULTI_NONESC
                        ldx             #$00
                        lda             TEST_BUF_PAGE0,x
                        cmp             #' '
                        bcc             W21_DEC_SINGLE_CTRL
                        cmp             #$7F
                        bcs             W21_DEC_SINGLE_CTRL
                        ldx             #<MSG_W21_DEC_SINGLE_PRINT
                        ldy             #>MSG_W21_DEC_SINGLE_PRINT
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_SINGLE_CTRL:
                        ldx             #<MSG_W21_DEC_SINGLE_CTRL
                        ldy             #>MSG_W21_DEC_SINGLE_CTRL
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_MULTI_NONESC:
                        ldx             #<MSG_W21_DEC_MULTI_NONESC
                        ldy             #>MSG_W21_DEC_MULTI_NONESC
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_CTRL_C:
                        ldx             #<MSG_W21_DEC_CTRL_C
                        ldy             #>MSG_W21_DEC_CTRL_C
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_ESC:
                        lda             W21_SEQ_LEN
                        cmp             #$01
                        bne             W21_DEC_ESC_HAVE_TAIL
                        ldx             #<MSG_W21_DEC_ESC_ONLY
                        ldy             #>MSG_W21_DEC_ESC_ONLY
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_ESC_HAVE_TAIL:
                        ldx             #$01
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'['
                        beq             W21_DEC_ESC_CSI
                        cmp             #'O'
                        beq             W21_DEC_ESC_SS3
                        ldx             #<MSG_W21_DEC_ESC_OTHER
                        ldy             #>MSG_W21_DEC_ESC_OTHER
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_ESC_SS3:
                        lda             W21_SEQ_LEN
                        cmp             #$03
                        bne             W21_DEC_SS3_GENERIC
                        ldx             #$02
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'P'
                        bne             W21_DEC_SS3_NOT_F1
                        jmp             W21_DEC_F1
W21_DEC_SS3_NOT_F1:
                        cmp             #'Q'
                        bne             W21_DEC_SS3_NOT_F2
                        jmp             W21_DEC_F2
W21_DEC_SS3_NOT_F2:
                        cmp             #'R'
                        bne             W21_DEC_SS3_NOT_F3
                        jmp             W21_DEC_F3
W21_DEC_SS3_NOT_F3:
                        cmp             #'S'
                        bne             W21_DEC_SS3_GENERIC
                        jmp             W21_DEC_F4
W21_DEC_SS3_GENERIC:
                        ldx             #<MSG_W21_DEC_ESC_SS3
                        ldy             #>MSG_W21_DEC_ESC_SS3
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_ESC_CSI:
                        lda             W21_SEQ_LEN
                        cmp             #$03
                        bne             W21_DEC_CSI_LONG
                        ldx             #$02
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'A'
                        bne             W21_DEC_CSI_NOT_UP
                        jmp             W21_DEC_ARROW_UP
W21_DEC_CSI_NOT_UP:
                        cmp             #'B'
                        bne             W21_DEC_CSI_NOT_DOWN
                        jmp             W21_DEC_ARROW_DOWN
W21_DEC_CSI_NOT_DOWN:
                        cmp             #'C'
                        bne             W21_DEC_CSI_NOT_RIGHT
                        jmp             W21_DEC_ARROW_RIGHT
W21_DEC_CSI_NOT_RIGHT:
                        cmp             #'D'
                        bne             W21_DEC_CSI_NOT_LEFT
                        jmp             W21_DEC_ARROW_LEFT
W21_DEC_CSI_NOT_LEFT:
                        cmp             #'H'
                        bne             W21_DEC_CSI_NOT_HOME
                        jmp             W21_DEC_HOME
W21_DEC_CSI_NOT_HOME:
                        cmp             #'F'
                        bne             W21_DEC_CSI_GENERIC
                        jmp             W21_DEC_END
                        ldx             #<MSG_W21_DEC_ESC_CSI
                        ldy             #>MSG_W21_DEC_ESC_CSI
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_CSI_LONG:
                        lda             W21_SEQ_LEN
                        cmp             #$04
                        bne             W21_DEC_CSI_LEN5
                        ldx             #$03
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'~'
                        bne             W21_DEC_CSI_GENERIC
                        ldx             #$02
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'1'
                        bne             W21_DEC_CSI4_NOT_HOME
                        jmp             W21_DEC_HOME
W21_DEC_CSI4_NOT_HOME:
                        cmp             #'4'
                        bne             W21_DEC_CSI4_NOT_END
                        jmp             W21_DEC_END
W21_DEC_CSI4_NOT_END:
                        cmp             #'5'
                        bne             W21_DEC_CSI4_NOT_PGUP
                        jmp             W21_DEC_PGUP
W21_DEC_CSI4_NOT_PGUP:
                        cmp             #'6'
                        bne             W21_DEC_CSI_GENERIC
                        jmp             W21_DEC_PGDN
                        bra             W21_DEC_CSI_GENERIC

W21_DEC_CSI_LEN5:
                        lda             W21_SEQ_LEN
                        cmp             #$05
                        bne             W21_DEC_CSI_GENERIC
                        ldx             #$02
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'1'
                        bne             W21_DEC_CSI_GENERIC
                        ldx             #$04
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'~'
                        bne             W21_DEC_CSI_GENERIC
                        ldx             #$03
                        lda             TEST_BUF_PAGE0,x
                        cmp             #'1'
                        bne             W21_DEC_CSI5_NOT_F1
                        jmp             W21_DEC_F1
W21_DEC_CSI5_NOT_F1:
                        cmp             #'2'
                        bne             W21_DEC_CSI5_NOT_F2
                        jmp             W21_DEC_F2
W21_DEC_CSI5_NOT_F2:
                        cmp             #'3'
                        bne             W21_DEC_CSI5_NOT_F3
                        jmp             W21_DEC_F3
W21_DEC_CSI5_NOT_F3:
                        cmp             #'4'
                        bne             W21_DEC_CSI_GENERIC
                        jmp             W21_DEC_F4
                        bra             W21_DEC_CSI_GENERIC

W21_DEC_CSI_GENERIC:
                        ldx             #<MSG_W21_DEC_ESC_CSI
                        ldy             #>MSG_W21_DEC_ESC_CSI
                        jmp             W21_PRINT_DECODE_MSG_XY

W21_DEC_ARROW_UP:
                        ldx             #<MSG_W21_DEC_ARROW_UP
                        ldy             #>MSG_W21_DEC_ARROW_UP
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_ARROW_DOWN:
                        ldx             #<MSG_W21_DEC_ARROW_DOWN
                        ldy             #>MSG_W21_DEC_ARROW_DOWN
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_ARROW_RIGHT:
                        ldx             #<MSG_W21_DEC_ARROW_RIGHT
                        ldy             #>MSG_W21_DEC_ARROW_RIGHT
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_ARROW_LEFT:
                        ldx             #<MSG_W21_DEC_ARROW_LEFT
                        ldy             #>MSG_W21_DEC_ARROW_LEFT
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_HOME:
                        ldx             #<MSG_W21_DEC_HOME
                        ldy             #>MSG_W21_DEC_HOME
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_END:
                        ldx             #<MSG_W21_DEC_END
                        ldy             #>MSG_W21_DEC_END
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_PGUP:
                        ldx             #<MSG_W21_DEC_PGUP
                        ldy             #>MSG_W21_DEC_PGUP
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_PGDN:
                        ldx             #<MSG_W21_DEC_PGDN
                        ldy             #>MSG_W21_DEC_PGDN
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_F1:
                        ldx             #<MSG_W21_DEC_F1
                        ldy             #>MSG_W21_DEC_F1
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_F2:
                        ldx             #<MSG_W21_DEC_F2
                        ldy             #>MSG_W21_DEC_F2
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_F3:
                        ldx             #<MSG_W21_DEC_F3
                        ldy             #>MSG_W21_DEC_F3
                        jmp             W21_PRINT_DECODE_MSG_XY
W21_DEC_F4:
                        ldx             #<MSG_W21_DEC_F4
                        ldy             #>MSG_W21_DEC_F4
                        jmp             W21_PRINT_DECODE_MSG_XY


W21_PRINT_DECODE_MSG_XY:
                        jsr             TST_PUTS_XY
                        jsr             COR_FTDI_WRITE_CRLF
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: TEST_CLASSIFY_STR_LOOP  [RHID:C89C]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1, CLASS_LINE_LEN, CLASS_CHAR, CLASS_LINE_IDX.
; PURPOSE: Interactive regression loop to classify typed string bytes.
; IN : none
; OUT: loops until Ctrl-C is received, then executes `brk $65`
; EXCEPTIONS/NOTES:
; - Reads raw bytes so control characters can be classified.
; - Ctrl-C (`$03`) exits immediately to BSO2 break handler.
; ----------------------------------------------------------------------------
TEST_CLASSIFY_STR_LOOP:
                        ldx             #<MSG_W15
                        ldy             #>MSG_W15
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W15_NOTE
                        ldy             #>MSG_W15_NOTE
                        jsr             TST_PRINT_LINE_XY
                        ldx             #<MSG_W15_CLASSES
                        ldy             #>MSG_W15_CLASSES
                        jsr             TST_PRINT_LINE_XY
                        jsr             COR_FTDI_FLUSH_RX

W15_LOOP:
                        jsr             RESET_W15_LOOP_STATE
                        ldx             #<MSG_W15_PROMPT
                        ldy             #>MSG_W15_PROMPT
                        jsr             TST_PUTS_XY
                        jsr             READ_CLASSIFY_LINE_OR_CTRL_C
                        bcc             W15_EXIT
                        lda             CLASS_LINE_LEN
                        ldx             #<TEST_BUF_PAGE1
                        ldy             #>TEST_BUF_PAGE1
                        jsr             COR_FTDI_WRITE_CLASSIFIED_BUFFER
                        jsr             COR_FTDI_WRITE_CRLF
                        bra             W15_LOOP

W15_EXIT:
                        jsr             COR_FTDI_WRITE_CRLF
                        ldx             #<MSG_W15_EXIT
                        ldy             #>MSG_W15_EXIT
                        jsr             TST_PRINT_LINE_XY
                        brk             $65
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: READ_CLASSIFY_LINE_OR_CTRL_C  [RHID:CB3A]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1, CLASS_LINE_LEN.
; PURPOSE: Build a NUL-terminated input line in TEST_BUF_PAGE1 from raw bytes.
; IN : none
; OUT: C=1 line captured; C=0 if Ctrl-C observed.
;      On C=1, CLASS_LINE_LEN holds byte count and TEST_BUF_PAGE1 is NUL-terminated.
; EXCEPTIONS/NOTES:
; - Terminates on CR or LF (both normalized as line end).
; - If buffer reaches 254 bytes, additional non-EOL bytes are dropped until EOL/Ctrl-C.
; ----------------------------------------------------------------------------
READ_CLASSIFY_LINE_OR_CTRL_C:
                        stz             CLASS_LINE_LEN
                        stz             CLASS_TERM_CHAR
RC_READ_LOOP:
                        jsr             COR_FTDI_READ_CHAR
                        cmp             #$03                            ; Ctrl-C
                        beq             RC_CTRL_C
                        cmp             #$0D
                        beq             RC_EOI
                        cmp             #$0A
                        beq             RC_EOI

                        ldx             CLASS_LINE_LEN
                        cpx             #$FE
                        beq             RC_READ_LOOP

                        sta             TEST_BUF_PAGE1,x
                        pha
                        cmp             #' '
                        bcc             RC_NO_ECHO
                        cmp             #$7F
                        bcs             RC_NO_ECHO
                        jsr             COR_FTDI_WRITE_CHAR
RC_NO_ECHO:
                        pla
                        inc             CLASS_LINE_LEN
                        bra             RC_READ_LOOP

RC_EOI:
                        sta             CLASS_TERM_CHAR
                        jsr             COR_FTDI_WRITE_CRLF
                        ldx             CLASS_LINE_LEN
                        lda             #$00
                        sta             TEST_BUF_PAGE1,x
                        sec
                        rts

RC_CTRL_C:
                        lda             #$03
                        sta             CLASS_TERM_CHAR
                        clc
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: CLASSIFY_PAGE1_LINE  [RHID:97E7]
; MEM : ZP: none; FIXED_RAM: TEST_BUF_PAGE1, CLASS_LINE_LEN, CLASS_CHAR, CLASS_LINE_IDX.
; PURPOSE: Emit per-byte classification rows for the captured line in TEST_BUF_PAGE1.
; IN : CLASS_LINE_LEN = bytes to classify
; OUT: One output line per byte, format: `[ii] $bb -> <class>`
; EXCEPTIONS/NOTES:
; - Emits an `(empty)` line when no bytes were entered.
; ----------------------------------------------------------------------------
CLASSIFY_PAGE1_LINE:
                        lda             CLASS_LINE_LEN
                        bne             CPL_HAS_DATA
                        ldx             #<MSG_W15_EMPTY
                        ldy             #>MSG_W15_EMPTY
                        jsr             TST_PRINT_LINE_XY
                        rts

CPL_HAS_DATA:
                        stz             CLASS_LINE_IDX
CPL_LOOP:
                        ldx             CLASS_LINE_IDX
                        cpx             CLASS_LINE_LEN
                        beq             CPL_DONE

                        lda             TEST_BUF_PAGE1,x
                        sta             CLASS_CHAR

                        lda             #'['
                        jsr             COR_FTDI_WRITE_CHAR
                        txa
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        lda             #']'
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #' '
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             #'$'
                        jsr             COR_FTDI_WRITE_CHAR
                        lda             CLASS_CHAR
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        ldx             #<MSG_W15_ARROW
                        ldy             #>MSG_W15_ARROW
                        jsr             TST_PUTS_XY
                        lda             CLASS_CHAR
                        jsr             PRINT_CLASS_TAG_A
                        jsr             COR_FTDI_WRITE_CRLF

                        inc             CLASS_LINE_IDX
                        bra             CPL_LOOP
CPL_DONE:
                        rts


; ----------------------------------------------------------------------------
; ROUTINE: PRINT_CLASS_TAG_A  [RHID:C84C]
; MEM : ZP: none; FIXED_RAM: none.
; PURPOSE: Print class tag for byte in A.
; IN : A = byte to classify
; OUT: Corresponding class string emitted.
; EXCEPTIONS/NOTES:
; - Class buckets: CTRL, PRINT-SPACE, PRINT-DIGIT, PRINT-UPPER,
;   PRINT-LOWER, PRINT-PUNCT.
; ----------------------------------------------------------------------------
PRINT_CLASS_TAG_A:
                        cmp             #$20
                        bcc             PCTA_CTRL
                        cmp             #$7F
                        bcs             PCTA_CTRL

                        cmp             #' '
                        beq             PCTA_PRINT_SPACE
                        cmp             #'0'
                        bcc             PCTA_PRINT_PUNCT
                        cmp             #':'
                        bcc             PCTA_PRINT_DIGIT
                        cmp             #'A'
                        bcc             PCTA_PRINT_PUNCT
                        cmp             #'['
                        bcc             PCTA_PRINT_UPPER
                        cmp             #'a'
                        bcc             PCTA_PRINT_PUNCT
                        cmp             #'{'
                        bcc             PCTA_PRINT_LOWER

PCTA_PRINT_PUNCT:
                        ldx             #<MSG_W15_CLASS_PRINT_PUNCT
                        ldy             #>MSG_W15_CLASS_PRINT_PUNCT
                        jsr             TST_PUTS_XY
                        rts
PCTA_CTRL:
                        ldx             #<MSG_W15_CLASS_CTRL
                        ldy             #>MSG_W15_CLASS_CTRL
                        jsr             TST_PUTS_XY
                        rts
PCTA_PRINT_SPACE:
                        ldx             #<MSG_W15_CLASS_PRINT_SPACE
                        ldy             #>MSG_W15_CLASS_PRINT_SPACE
                        jsr             TST_PUTS_XY
                        rts
PCTA_PRINT_DIGIT:
                        ldx             #<MSG_W15_CLASS_PRINT_DIGIT
                        ldy             #>MSG_W15_CLASS_PRINT_DIGIT
                        jsr             TST_PUTS_XY
                        rts
PCTA_PRINT_UPPER:
                        ldx             #<MSG_W15_CLASS_PRINT_UPPER
                        ldy             #>MSG_W15_CLASS_PRINT_UPPER
                        jsr             TST_PUTS_XY
                        rts
PCTA_PRINT_LOWER:
                        ldx             #<MSG_W15_CLASS_PRINT_LOWER
                        ldy             #>MSG_W15_CLASS_PRINT_LOWER
                        jsr             TST_PUTS_XY
                        rts


; ----------------------------------------------------------------------------
; Assertion / reporting helpers
; ----------------------------------------------------------------------------
RESET_W18_LOOP_STATE:
                        stz             CLASS_CHAR
                        rts

RESET_W19_LOOP_STATE:
                        stz             CLASS_LINE_LEN
                        stz             CLASS_CHAR
                        stz             CLASS_LINE_IDX
                        stz             CLASS_TERM_CHAR
                        stz             FIND_NEEDLE_CHAR
                        stz             FIND_SCAN_CONSUMED
                        stz             FIND_SCAN_PTR_LO
                        stz             FIND_SCAN_PTR_HI
                        jsr             RESET_STRING_FLAGS
                        rts

RESET_W21_LOOP_STATE:
                        stz             W21_SPIN_LO
                        stz             W21_SPIN_HI
                        stz             W21_SPIN_CHAR
                        stz             W21_DOWN_LO
                        stz             W21_DOWN_HI
                        stz             W21_SEQ_LEN
                        stz             W21_SEQ_IDX
                        rts

RESET_W15_LOOP_STATE:
                        stz             CLASS_LINE_LEN
                        stz             CLASS_CHAR
                        stz             CLASS_LINE_IDX
                        stz             CLASS_TERM_CHAR
                        jsr             RESET_STRING_FLAGS
                        rts

RESET_TEST_STATE:
                        stz             TEST_PASS_COUNT
                        stz             TEST_FAIL_COUNT
                        stz             TEST_OBS_A
                        stz             TEST_OBS_C
                        stz             TEST_EXP_A
                        stz             TEST_EXP_C
                        rts

CAPTURE_CA:
                        php
                        sta             TEST_OBS_A
                        pla
                        and             #$01
                        sta             TEST_OBS_C
                        rts

ASSERT_C_EQ_0:
                        lda             TEST_OBS_A
                        sta             TEST_EXP_A
                        lda             #$00
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

ASSERT_C_EQ_1:
                        lda             TEST_OBS_A
                        sta             TEST_EXP_A
                        lda             #$01
                        sta             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

ASSERT_CA:
                        lda             TEST_OBS_C
                        cmp             TEST_EXP_C
                        bne             ASSERT_CA_FAIL
                        lda             TEST_OBS_A
                        cmp             TEST_EXP_A
                        bne             ASSERT_CA_FAIL
                        jsr             RECORD_PASS
                        rts

ASSERT_CA_FAIL:
                        jsr             RECORD_FAIL
                        jsr             PRINT_EXP_OBS_CA
                        rts

ASSERT_C0_A_BS_OR_DEL:
                        lda             TEST_OBS_C
                        cmp             #$00
                        bne             ASSERT_BS_DEL_FAIL
                        lda             TEST_OBS_A
                        cmp             #$08
                        beq             ASSERT_BS_DEL_PASS
                        cmp             #$7F
                        beq             ASSERT_BS_DEL_PASS

ASSERT_BS_DEL_FAIL:
                        jsr             RECORD_FAIL
                        ldx             #<MSG_EXPECT_BS_DEL
                        ldy             #>MSG_EXPECT_BS_DEL
                        jsr             TST_PRINT_LINE_XY
                        jsr             PRINT_OBS_CA
                        rts

ASSERT_BS_DEL_PASS:
                        jsr             RECORD_PASS
                        rts

ASSERT_PAGE0_BYTE_EQ:
                        sta             TEST_EXP_A
                        lda             TEST_BUF_PAGE0,x
                        sta             TEST_OBS_A
                        stz             TEST_OBS_C
                        stz             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

ASSERT_PAGE1_BYTE_EQ:
                        sta             TEST_EXP_A
                        lda             TEST_BUF_PAGE1,x
                        sta             TEST_OBS_A
                        stz             TEST_OBS_C
                        stz             TEST_EXP_C
                        jsr             ASSERT_CA
                        rts

RECORD_PASS:
                        inc             TEST_PASS_COUNT
                        ldx             #<MSG_PASS
                        ldy             #>MSG_PASS
                        jsr             TST_PRINT_LINE_XY
                        rts

RECORD_FAIL:
                        inc             TEST_FAIL_COUNT
                        ldx             #<MSG_FAIL
                        ldy             #>MSG_FAIL
                        jsr             TST_PRINT_LINE_XY
                        rts
PRINT_EXP_OBS_CA:
                        ldx             #<MSG_EXP_PREFIX
                        ldy             #>MSG_EXP_PREFIX
                        jsr             TST_PUTS_XY
                        lda             TEST_EXP_C
                        jsr             TST_PRINT_CARRY_BIT_A
                        ldx             #<MSG_A_EQ
                        ldy             #>MSG_A_EQ
                        jsr             TST_PUTS_XY
                        lda             TEST_EXP_A
                        jsr             COR_FTDI_WRITE_HEX_BYTE

                        ldx             #<MSG_OBS_PREFIX
                        ldy             #>MSG_OBS_PREFIX
                        jsr             TST_PUTS_XY
                        lda             TEST_OBS_C
                        jsr             TST_PRINT_CARRY_BIT_A
                        ldx             #<MSG_A_EQ
                        ldy             #>MSG_A_EQ
                        jsr             TST_PUTS_XY
                        lda             TEST_OBS_A
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

PRINT_OBS_CA:
                        ldx             #<MSG_OBS_ONLY
                        ldy             #>MSG_OBS_ONLY
                        jsr             TST_PUTS_XY
                        lda             TEST_OBS_C
                        jsr             TST_PRINT_CARRY_BIT_A
                        ldx             #<MSG_A_EQ
                        ldy             #>MSG_A_EQ
                        jsr             TST_PUTS_XY
                        lda             TEST_OBS_A
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF
                        rts

PRINT_SUMMARY:
                        jsr             COR_FTDI_WRITE_CRLF
                        ldx             #<MSG_SUMMARY
                        ldy             #>MSG_SUMMARY
                        jsr             TST_PUTS_XY

                        ldx             #<MSG_PASS_HEX
                        ldy             #>MSG_PASS_HEX
                        jsr             TST_PUTS_XY
                        lda             TEST_PASS_COUNT
                        jsr             COR_FTDI_WRITE_HEX_BYTE

                        ldx             #<MSG_FAIL_HEX
                        ldy             #>MSG_FAIL_HEX
                        jsr             TST_PUTS_XY
                        lda             TEST_FAIL_COUNT
                        jsr             COR_FTDI_WRITE_HEX_BYTE
                        jsr             COR_FTDI_WRITE_CRLF

                        lda             TEST_FAIL_COUNT
                        beq             SUMMARY_OK
                        ldx             #<MSG_SUMMARY_FAIL
                        ldy             #>MSG_SUMMARY_FAIL
                        jsr             TST_PRINT_LINE_XY
                        rts

SUMMARY_OK:
                        ldx             #<MSG_SUMMARY_OK
                        ldy             #>MSG_SUMMARY_OK
                        jsr             TST_PRINT_LINE_XY
                        rts


; ----------------------------------------------------------------------------
; Utility helpers
; ----------------------------------------------------------------------------
CLEAR_TEST_BUFFERS:
                        lda             #$00
                        ldx             #$00
CLR_LOOP:
                        sta             TEST_BUF_PAGE0,x
                        sta             TEST_BUF_PAGE1,x
                        inx
                        bne             CLR_LOOP
                        rts

; IN: A = byte fill value
FILL_BUF_PAGE0_256:
                        ldx             #$00
FILL0_LOOP:
                        sta             TEST_BUF_PAGE0,x
                        inx
                        bne             FILL0_LOOP
                        rts

                        DATA
; ----------------------------------------------------------------------------
; Constant strings
; ----------------------------------------------------------------------------
STR_EMPTY:              db              $00
STR_ONE:                db              "Q",$00
STR_AB:                 db              "AB",$00

MSG_HDR_1:              db              "backend unit check: COR_FTDI_*",$00
MSG_HDR_2:              db              "buffer reserved at $7C00-$7DFF (512 bytes)",$00
MSG_HDR_3:              db              "build marker: INTERACTIVE-V2 (W08 auto-skip)",$00
MSG_TEST_CMD:           db              "TEST command: backend routine-of-routines",$00
MSG_TEST_CMD_NOTE:      db              "interactive consolidated path: W18->W19->W20->W21",$00

MSG_W18:                db              "W18 char loop (Ctrl-C moves to W19)",$00
MSG_W18_NOTE:           db              "type one key, then class/value/printability are shown",$00
MSG_W18_PROMPT:         db              "W18> ",$00
MSG_W18_TYPE:           db              "  char type: ",$00
MSG_W18_CHAR:           db              "  char was: ",$00
MSG_W18_NONPRINT:       db              "non print",$00
MSG_W18_HEX:            db              "  char is $",$00
MSG_W18_ISPRINT:        db              "  char is print: ",$00
MSG_W18_EXIT:           db              "W18 done (Ctrl-C): moving to W19",$00

MSG_W19:                db              "W19 string loop (Ctrl-C moves to W20)",$00
MSG_W19_NOTE:           db              "enter a line; report prints string, len, flags, needle scan, and per-byte class",$00
MSG_W19_PROMPT:         db              "W19> ",$00
MSG_W19_EXIT:           db              "W19 done (Ctrl-C): moving to W20",$00
MSG_W19_STRING_LABEL:   db              "  string is: ",$00
MSG_W19_STRLEN:         db              "  strlen is $",$00
MSG_W19_FIND_PROMPT:    db              "  needle byte (2 hex digits 00-FF, Ctrl-C exits W19): ",$00
MSG_W19_FIND_NEEDLE:    db              "  needle=$",$00
MSG_W19_FIND_C:         db              "  scan C=",$00
MSG_W19_FIND_CONSUMED:  db              " consumed=$",$00
MSG_W19_FIND_PTR:       db              " next=$",$00
MSG_W19_FLAGS_U:        db              "  flags UPPER=",$00
MSG_W19_FLAGS_L:        db              " LOWER=",$00
MSG_W19_FLAGS_N:        db              " NUMERIC=",$00
MSG_W19_FLAGS_PUN:      db              " PUNCT=",$00
MSG_W19_FLAGS_PRINT:    db              " ISPRINT=",$00
MSG_W19_FLAGS_CTRL:     db              " CTRL=",$00
MSG_W19_FLAGS_LF:       db              " LF(0A)=",$00
MSG_W19_FLAGS_CR:       db              " CR(0D)=",$00

MSG_W20:                db              "W20 delay/flush loop (Ctrl-C moves to W21)",$00
MSG_W20_NOTE:           db              "6.502s wait can be interrupted; then staged flush is verified",$00
MSG_W20_DELAY_PROMPT:   db              "  delay test: press key within 6.502s, or wait for timeout",$00
MSG_W20_DELAY_INTERRUPTED: db           "  delay interrupted by A=$",$00
MSG_W20_DELAY_COMPLETE: db              "  delay completed with no input (timeout)",$00
MSG_W20_FLUSH_STAGE:    db              "  flush stage: type now for ~0.9s, then stop (flush follows)",$00
MSG_W20_FLUSH_CHECK:    db              "  post-flush check (~0.9s): expecting timeout",$00
MSG_W20_FLUSH_LEFTOVER: db              "  flush check saw input A=$",$00
MSG_W20_FLUSH_OK:       db              "  flush check timeout: no stale input",$00
MSG_W20_EXIT:           db              "W20 done (Ctrl-C): moving to W21",$00

MSG_W21:                db              "W21 reaction spin loop (Ctrl-C exits with brk $65)",$00
MSG_W21_NOTE:           db              "flushes RX, then runs live up/down counters until a key event arrives",$00
MSG_W21_NOTE2:          db              "ESC-led ANSI/VT100 multi-byte keys (F1/PgUp/arrows) are captured/classified",$00
MSG_W21_SPIN_PROMPT:    db              "  reaction test: wait, then press a key when ready",$00
MSG_W21_RT_PREFIX:      db              "  up=$",$00
MSG_W21_RT_MID:         db              " down=$",$00
MSG_W21_RT_SUFFIX:      db              "  [Ctrl-C exits]",$00
MSG_W21_SUMMARY:        db              "  captured counters: up=$",$00
MSG_W21_SUMMARY_MID:    db              " down=$",$00
MSG_W21_RAW:            db              "  raw bytes: ",$00
MSG_W21_CLASSIFIED:     db              "  classified bytes:",$00
MSG_W21_DECODE_PREFIX:  db              "  decode: ",$00
MSG_W21_DEC_UNKNOWN:    db              "unknown / empty capture",$00
MSG_W21_DEC_CTRL_C:     db              "Ctrl-C",$00
MSG_W21_DEC_SINGLE_PRINT: db            "single printable byte",$00
MSG_W21_DEC_SINGLE_CTRL: db             "single control byte",$00
MSG_W21_DEC_MULTI_NONESC: db            "multi-byte non-ESC payload",$00
MSG_W21_DEC_ESC_ONLY:   db              "ESC key (single byte)",$00
MSG_W21_DEC_ESC_OTHER:  db              "ESC + non-CSI/SS3 sequence",$00
MSG_W21_DEC_ESC_CSI:    db              "ANSI CSI sequence",$00
MSG_W21_DEC_ESC_SS3:    db              "VT100 SS3 sequence",$00
MSG_W21_DEC_ARROW_UP:   db              "Arrow Up",$00
MSG_W21_DEC_ARROW_DOWN: db              "Arrow Down",$00
MSG_W21_DEC_ARROW_RIGHT: db             "Arrow Right",$00
MSG_W21_DEC_ARROW_LEFT: db              "Arrow Left",$00
MSG_W21_DEC_HOME:       db              "Home",$00
MSG_W21_DEC_END:        db              "End",$00
MSG_W21_DEC_PGUP:       db              "Page Up",$00
MSG_W21_DEC_PGDN:       db              "Page Down",$00
MSG_W21_DEC_F1:         db              "F1",$00
MSG_W21_DEC_F2:         db              "F2",$00
MSG_W21_DEC_F3:         db              "F3",$00
MSG_W21_DEC_F4:         db              "F4",$00
MSG_W21_EXIT:           db              "Ctrl-C received: brk $65",$00

MSG_W01:                db              "W01 init+flush wrapper: expect C=1 from flush",$00
MSG_W02:                db              "W02 is_enumerated wrapper: expect (C,A)=(0,0) or (1,1)",$00
MSG_W02_NOTE:           db              "  note: wrapper should mirror PIN_FTDI_CHECK_ENUMERATED",$00

MSG_W03:                db              "W03 scan_char empty after flush: expect C=0",$00
MSG_W04:                db              "W04 scan/get char wrappers: expect C=1 then A='S'",$00
MSG_W04_PROMPT:         db              "  prompt: type uppercase S now",$00

MSG_W05:                db              "W05 put_char boundaries A=00,FF,'A': expect C=1 and A preserved",$00
MSG_W06:                db              "W06 put_char_n boundaries X=00,01,FF: expect C=1 and A preserved",$00

MSG_W07:                db              "W07 put_c_str boundaries empty/1/255/full/trunc + A ignored",$00

MSG_W08:                db              "W08 get_c_str fixed-254 (A ignored, BS/DEL, success)",$00
MSG_W08_PROMPT_FULL:    db              "  prompt: press ENTER immediately (A=00)",$00
MSG_W08_PROMPT_BS:      db              "  prompt: press BACKSPACE or DELETE as first key",$00
MSG_W08_PROMPT_OK:      db              "  prompt: type OK then ENTER (A=FF)",$00

MSG_W09:                db              "W09 put_hex_byte boundaries A=00,FF: expect C=1 and A preserved",$00
MSG_W10:                db              "W10 put_crlf: expect C=1 and A preserved",$00

MSG_W11:                db              "W11 get_char_echo_cooked boundaries",$00
MSG_W11_PROMPT_Z:       db              "  prompt: type uppercase Z",$00
MSG_W11_PROMPT_ENTER:   db              "  prompt: press ENTER",$00
MSG_W11_PROMPT_BS:      db              "  prompt: press BACKSPACE or DELETE",$00
MSG_W11_PROMPT_ESC:     db              "  prompt: press ESC (ignored control char, expect C=0)",$00
MSG_W11A:               db              "W11A visual case check (lower+upper)",$00
MSG_W11A_Q:             db              "did you see lowercase a followed by uppercase A?",$00

MSG_W12_HDR:            db              "W12-W14 interactive intensive backend battery",$00
MSG_W12_HDR_NOTE:       db              "  covers echo/noecho char+string paths and timed challenge",$00
MSG_W12_EXIT:           db              "Ctrl-C received during battery: brk $65",$00

MSG_W12:                db              "W12 single-char echo/noecho confirmation",$00
MSG_W12_NOECHO_PROMPT:  db              "  Enter char (will not be echoed):",$00
MSG_W12_ECHO_PROMPT:    db              "  Enter char (echo cooked path):",$00
MSG_W12_ENTERED_PREFIX: db              "  '",$00
MSG_W12_ENTERED_MID:    db              "' was entered (A=$",$00
MSG_W12_Q:              db              "did both W12 char checks behave as expected?",$00

MSG_W13:                db              "W13 string echo/noecho confirmation",$00
MSG_W13_NOECHO_PROMPT:  db              "  Enter string (noecho) then ENTER:",$00
MSG_W13_ECHO_PROMPT:    db              "  Enter string (echo) then ENTER:",$00
MSG_W13_STATUS:         db              "  status from line read:",$00
MSG_W13_CAPTURE:        db              "  captured: ",$00
MSG_W13_Q:              db              "did noecho hide typing and echo show typing?",$00

MSG_W14:                db              "W14 timed challenge: enter W in 6.502 seconds",$00
MSG_W14_PROMPT:         db              "  Press uppercase W before timeout starts now.",$00
MSG_W14_SUCCESS:        db              "  success path: W received on time",$00
MSG_W14_FAIL_TIMEOUT:   db              "  failure path: timeout (no input by 6.502s)",$00
MSG_W14_FAIL_WRONG:     db              "  failure path: wrong key A=$",$00
MSG_W14_Q:              db              "did W14 behavior match your observed input timing?",$00

MSG_W16:                db              "W16 utility char classifier exercise",$00
MSG_W16_NOTE:           db              "flags are shown as bits: 1=true 0=false",$00
MSG_W16_Q:              db              "do W16 classifier flags look correct for A,a,5,!,space?",$00
MSG_W16_BYTE:           db              "  ch=$",$00
MSG_W16_P:              db              " P=",$00
MSG_W16_C:              db              " C=",$00
MSG_W16_U:              db              " U=",$00
MSG_W16_L:              db              " L=",$00
MSG_W16_N:              db              " N=",$00
MSG_W16_A:              db              " A=",$00
MSG_W16_PUN:            db              " PUN=",$00
MSG_W16_RANGE:          db              "  UTL_CHAR_IN_RANGE('G','A','[') => ",$00

MSG_W17:                db              "W17 delay confirmation (~6.502s)",$00
MSG_W17_NOTE:           db              "wait for delay window to complete...",$00
MSG_W17_DONE:           db              "delay completed",$00
MSG_W17_Q:              db              "was the delay about 6.502 seconds?",$00

MSG_W15:                db              "W15 interactive byte classifier (loop until Ctrl-C)",$00
MSG_W15_NOTE:           db              "  type a line then ENTER; each byte is classified",$00
MSG_W15_CLASSES:        db              "  classes: CTRL / PRINT-SPACE / PRINT-DIGIT / PRINT-UPPER / PRINT-LOWER / PRINT-PUNCT",$00
MSG_W15_PROMPT:         db              "W15> ",$00
MSG_W15_EMPTY:          db              "(empty)",$00
MSG_W15_ARROW:          db              " -> ",$00
MSG_W15_EXIT:           db              "Ctrl-C received: brk $65",$00
MSG_W15_CLASS_CTRL:     db              "CTRL",$00
MSG_W15_CLASS_PRINT_SPACE: db           "PRINT-SPACE",$00
MSG_W15_CLASS_PRINT_DIGIT: db           "PRINT-DIGIT",$00
MSG_W15_CLASS_PRINT_UPPER: db           "PRINT-UPPER",$00
MSG_W15_CLASS_PRINT_LOWER: db           "PRINT-LOWER",$00
MSG_W15_CLASS_PRINT_PUNCT: db           "PRINT-PUNCT",$00

MSG_PASS:               db              "  PASS",$00
MSG_FAIL:               db              "  FAIL",$00
MSG_EXPECT_BS_DEL:      db              "  expected: C=0 and A=08 or 7F",$00

MSG_EXP_PREFIX:         db              "    exp C=",$00
MSG_OBS_PREFIX:         db              "  obs C=",$00
MSG_OBS_ONLY:           db              "    obs C=",$00
MSG_A_EQ:               db              " A=$",$00

MSG_SUMMARY:            db              "SUMMARY",$00
MSG_PASS_HEX:           db              " pass=$",$00
MSG_FAIL_HEX:           db              " fail=$",$00
MSG_SUMMARY_OK:         db              "all checks passed",$00
MSG_SUMMARY_FAIL:       db              "one or more checks failed",$00
MSG_ASK_YN:             db              "  confirm (Y/N): ",$00
MSG_ASK_ABORT:          db              "Ctrl-C received: brk $65",$00

VECTORS:                SECTION OFFSET $4200
                        db  "WLP2"

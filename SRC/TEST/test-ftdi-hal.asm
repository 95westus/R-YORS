                        XDEF            START

                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            COR_FTDI_WRITE_CRLF
                        XREF            BIO_FTDI_INIT
                        XREF            BIO_FTDI_READ_BYTE_NONBLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_NONBLOCK
                        XREF            BIO_FTDI_CHECK_ENUMERATED
                        XREF            BIO_FTDI_READ_BYTE_TMO
                        XREF            BIO_FTDI_WRITE_BYTE_TMO
                        XREF            BIO_FTDI_WAIT_RX_READY_TMO
                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            BIO_FTDI_DRAIN_RX_MAX
                        XREF            BIO_FTDI_FLUSH_RX
                        XREF            BIO_FTDI_FLUSH_RX_COUNT
                        XREF            BIO_FTDI_POLL_RX_READY

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             SYS_WRITE_CSTRING

                        JSR             BIO_FTDI_INIT
                        JSR             PRINT_BIO_C_STATUS
                        LDX             #<MSG_INIT_CALLED
                        LDY             #>MSG_INIT_CALLED
                        JSR             SYS_WRITE_CSTRING

SUITE_LOOP:
                        LDX             #<MSG_LOOP_HEADER
                        LDY             #>MSG_LOOP_HEADER
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 1: BIO-L1-FTDI-ENUM-CHK-01
; ----------------------------------------------------------------------------
                        LDX             #<MSG_T1_BEGIN
                        LDY             #>MSG_T1_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_CHECK_ENUMERATED
                        JSR             PRINT_BIO_C_STATUS
                        BCS             T1_ENUM_YES
T1_ENUM_NO:             LDX             #<MSG_T1_NO
                        LDY             #>MSG_T1_NO
                        JSR             SYS_WRITE_CSTRING
                        BRA             T2_BEGIN
T1_ENUM_YES:            LDX             #<MSG_T1_YES
                        LDY             #>MSG_T1_YES
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 2: BIO-L1-FTDI-READ-NB-01
; ----------------------------------------------------------------------------
T2_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T2_BEGIN
                        LDY             #>MSG_T2_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_FLUSH_RX
                        LDX             #<MSG_T2_READ
                        LDY             #>MSG_T2_READ
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        JSR             PRINT_BIO_C_STATUS
                        BCC             T2_EMPTY
                        LDX             #<MSG_BYTE
                        LDY             #>MSG_BYTE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        BRA             T3_BEGIN
T2_EMPTY:               LDX             #<MSG_T2_EMPTY
                        LDY             #>MSG_T2_EMPTY
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 3: BIO-L1-FTDI-WAIT-TMO-01
; ----------------------------------------------------------------------------
T3_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T3_BEGIN
                        LDY             #>MSG_T3_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_NO_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN1
                        LDY             #>MSG_RUN1
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$20
                        LDY             #$02
                        JSR             BIO_FTDI_WAIT_RX_READY_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCS             T3_READY_A
                        LDX             #<MSG_T3_EMPTY
                        LDY             #>MSG_T3_EMPTY
                        JSR             SYS_WRITE_CSTRING
                        BRA             T3_SECOND
T3_READY_A:             LDX             #<MSG_T3_READY
                        LDY             #>MSG_T3_READY
                        JSR             SYS_WRITE_CSTRING
T3_SECOND:
                        JSR             WAIT_TYPE_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN2
                        LDY             #>MSG_RUN2
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$20
                        LDY             #$02
                        JSR             BIO_FTDI_WAIT_RX_READY_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCS             T3_READY_B
                        LDX             #<MSG_T3_EMPTY
                        LDY             #>MSG_T3_EMPTY
                        JSR             SYS_WRITE_CSTRING
                        BRA             T4_BEGIN
T3_READY_B:             LDX             #<MSG_T3_READY
                        LDY             #>MSG_T3_READY
                        JSR             SYS_WRITE_CSTRING
                        BRA             T4_BEGIN

; ----------------------------------------------------------------------------
; TEST 4: BIO-L1-FTDI-WRITE-NB-01
; ----------------------------------------------------------------------------
T4_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T4_BEGIN
                        LDY             #>MSG_T4_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        LDA             #'N'
                        JSR             BIO_FTDI_WRITE_BYTE_NONBLOCK
                        JSR             PRINT_BIO_C_STATUS
                        BCC             T4_FAIL
                        JSR             COR_FTDI_WRITE_CRLF
                        LDX             #<MSG_T4_PASS
                        LDY             #>MSG_T4_PASS
                        JSR             SYS_WRITE_CSTRING
                        BRA             T5_BEGIN
T4_FAIL:                LDX             #<MSG_T4_FAIL
                        LDY             #>MSG_T4_FAIL
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 5: BIO-L1-FTDI-WRITE-TMO-01
; ----------------------------------------------------------------------------
T5_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T5_BEGIN
                        LDY             #>MSG_T5_BEGIN
                        JSR             SYS_WRITE_CSTRING

                        JSR             WAIT_NO_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN1
                        LDY             #>MSG_RUN1
                        JSR             SYS_WRITE_CSTRING
                        LDA             #'I'
                        LDX             #$00
                        LDY             #$00
                        JSR             BIO_FTDI_WRITE_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        JSR             COR_FTDI_WRITE_CRLF

                        JSR             WAIT_TYPE_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN2
                        LDY             #>MSG_RUN2
                        JSR             SYS_WRITE_CSTRING
                        LDA             #'B'
                        LDX             #$20
                        LDY             #$01
                        JSR             BIO_FTDI_WRITE_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        JSR             COR_FTDI_WRITE_CRLF

; ----------------------------------------------------------------------------
; TEST 6: BIO-L1-FTDI-READ-TMO-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T6_BEGIN
                        LDY             #>MSG_T6_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_FLUSH_RX
                        JSR             WAIT_NO_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN1
                        LDY             #>MSG_RUN1
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$00
                        LDY             #$00
                        JSR             BIO_FTDI_READ_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCS             T6_UNEXPECTED_DATA_A
                        LDX             #<MSG_T6_PASS
                        LDY             #>MSG_T6_PASS
                        JSR             SYS_WRITE_CSTRING
                        BRA             T6_SECOND
T6_UNEXPECTED_DATA_A:
                        LDX             #<MSG_T6_WARN
                        LDY             #>MSG_T6_WARN
                        JSR             PRINT_HEX_A_WITH_PREFIX
T6_SECOND:
                        JSR             WAIT_TYPE_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN2
                        LDY             #>MSG_RUN2
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$00
                        LDY             #$00
                        JSR             BIO_FTDI_READ_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCS             T6_UNEXPECTED_DATA_B
                        LDX             #<MSG_T6_PASS
                        LDY             #>MSG_T6_PASS
                        JSR             SYS_WRITE_CSTRING
                        BRA             T7_BEGIN
T6_UNEXPECTED_DATA_B:
                        LDX             #<MSG_T6_WARN
                        LDY             #>MSG_T6_WARN
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        BRA             T7_BEGIN

; ----------------------------------------------------------------------------
; TEST 7: BIO-L1-FTDI-READ-TMO-02
; ----------------------------------------------------------------------------
T7_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T7_BEGIN
                        LDY             #>MSG_T7_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_NO_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN1
                        LDY             #>MSG_RUN1
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$40
                        LDY             #$02
                        JSR             BIO_FTDI_READ_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCC             T7_TIMEOUT_A
                        LDX             #<MSG_BYTE
                        LDY             #>MSG_BYTE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        BRA             T7_SECOND
T7_TIMEOUT_A:           LDX             #<MSG_T7_TIMEOUT
                        LDY             #>MSG_T7_TIMEOUT
                        JSR             SYS_WRITE_CSTRING
T7_SECOND:
                        JSR             WAIT_TYPE_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN2
                        LDY             #>MSG_RUN2
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$40
                        LDY             #$02
                        JSR             BIO_FTDI_READ_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCC             T7_TIMEOUT_B
                        LDX             #<MSG_BYTE
                        LDY             #>MSG_BYTE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        BRA             T8_BEGIN
T7_TIMEOUT_B:           LDX             #<MSG_T7_TIMEOUT
                        LDY             #>MSG_T7_TIMEOUT
                        JSR             SYS_WRITE_CSTRING
                        BRA             T8_BEGIN

; ----------------------------------------------------------------------------
; TEST 8: BIO-L1-FTDI-DRAIN-MAX-01
; ----------------------------------------------------------------------------
T8_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T8_BEGIN
                        LDY             #>MSG_T8_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_FLUSH_RX
                        LDX             #$20
                        JSR             BIO_FTDI_DRAIN_RX_MAX
                        JSR             PRINT_BIO_C_STATUS
                        CMP             #$00
                        PHP
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        PLP
                        BEQ             T8_PASS
                        LDX             #<MSG_T8_FAIL
                        LDY             #>MSG_T8_FAIL
                        JSR             SYS_WRITE_CSTRING
                        BRA             T9_BEGIN
T8_PASS:                LDX             #<MSG_T8_PASS
                        LDY             #>MSG_T8_PASS
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 9: BIO-L1-FTDI-DRAIN-MAX-02
; ----------------------------------------------------------------------------
T9_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T9_BEGIN
                        LDY             #>MSG_T9_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_INPUT_WINDOW_3S
                        LDX             #$20
                        JSR             BIO_FTDI_DRAIN_RX_MAX
                        JSR             PRINT_BIO_C_STATUS
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        JSR             VERIFY_EMPTY_AFTER_FLUSH

; ----------------------------------------------------------------------------
; TEST 10: BIO-L1-FTDI-FLUSH-COUNT-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T10_BEGIN
                        LDY             #>MSG_T10_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_INPUT_WINDOW_3S
                        JSR             BIO_FTDI_FLUSH_RX_COUNT
                        JSR             PRINT_BIO_C_STATUS
                        CMP             #$00
                        PHP
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        PLP
                        BEQ             T10_PASS
                        LDX             #<MSG_T10_FAIL
                        LDY             #>MSG_T10_FAIL
                        JSR             SYS_WRITE_CSTRING
                        BRA             T11_BEGIN
T10_PASS:               LDX             #<MSG_T10_PASS
                        LDY             #>MSG_T10_PASS
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 11: BIO-L1-FTDI-FLUSH-COUNT-02
; ----------------------------------------------------------------------------
T11_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T11_BEGIN
                        LDY             #>MSG_T11_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_INPUT_WINDOW_3S
                        JSR             BIO_FTDI_FLUSH_RX_COUNT
                        JSR             PRINT_BIO_C_STATUS
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        JSR             VERIFY_EMPTY_AFTER_FLUSH

; ----------------------------------------------------------------------------
; TEST 12: BIO-L1-FTDI-FLUSH-PRESA-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T12_BEGIN
                        LDY             #>MSG_T12_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        LDA             #$A5
                        JSR             BIO_FTDI_FLUSH_RX
                        PHP
                        CMP             #$A5
                        BNE             T12_FAIL_A
                        PLP
                        BCC             T12_FAIL_C0
                        LDX             #<MSG_T12_PASS
                        LDY             #>MSG_T12_PASS
                        JSR             SYS_WRITE_CSTRING
                        BRA             T13_BEGIN
T12_FAIL_A:             PLP
                        LDX             #<MSG_T12_FAIL_A
                        LDY             #>MSG_T12_FAIL_A
                        JSR             SYS_WRITE_CSTRING
                        BRA             T13_BEGIN
T12_FAIL_C0:            LDX             #<MSG_T12_FAIL_C0
                        LDY             #>MSG_T12_FAIL_C0
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; TEST 13: BIO-L1-FTDI-READ-TMO-PROFILE-03
; ----------------------------------------------------------------------------
T13_BEGIN:
                        JSR             WAIT_BETWEEN_TESTS
                        LDX             #<MSG_T13_BEGIN
                        LDY             #>MSG_T13_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_FLUSH_RX
                        JSR             WAIT_NO_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN1
                        LDY             #>MSG_RUN1
                        JSR             SYS_WRITE_CSTRING
                        JSR             RUN_T13_PROFILE_SWEEP
                        JSR             WAIT_TYPE_INPUT_WINDOW_3S
                        LDX             #<MSG_RUN2
                        LDY             #>MSG_RUN2
                        JSR             SYS_WRITE_CSTRING
                        JSR             RUN_T13_PROFILE_SWEEP

; ----------------------------------------------------------------------------
; TEST 14: BIO-L1-FTDI-NONBLOCK-BURST-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        JSR             RUN_T14_NONBLOCK_BURST

; ----------------------------------------------------------------------------
; TEST 15: BIO-L1-FTDI-BLOCK-GUARDED-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        JSR             RUN_T15_BLOCKING_GUARDED

; ----------------------------------------------------------------------------
; TEST 16: BIO-L1-FTDI-SCAN-SWEEP-01
; ----------------------------------------------------------------------------
                        JSR             WAIT_BETWEEN_TESTS
                        JSR             RUN_T16_SCAN_SWEEP

DONE:                   LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_NEXT_CYCLE_OR_CTRL_C
                        JMP             SUITE_LOOP

; ----------------------------------------------------------------------------
; ROUTINE: VERIFY_EMPTY_AFTER_FLUSH  [HASH:CD75477E]
; ----------------------------------------------------------------------------
VERIFY_EMPTY_AFTER_FLUSH:
                        JSR             BIO_FTDI_POLL_RX_READY
                        JSR             PRINT_BIO_C_STATUS
                        BCS             ?STILL_READY
?EMPTY:                 LDX             #<MSG_VERIFY_EMPTY
                        LDY             #>MSG_VERIFY_EMPTY
                        JSR             SYS_WRITE_CSTRING
                        RTS
?STILL_READY:           LDX             #<MSG_VERIFY_STILL_READY
                        LDY             #>MSG_VERIFY_STILL_READY
                        JSR             SYS_WRITE_CSTRING
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: RUN_READ_TMO_PROFILE_CASE  [HASH:AAF2BCDF]
; IN : A = Y profile value to test
; ----------------------------------------------------------------------------
RUN_READ_TMO_PROFILE_CASE:
                        LDX             #<MSG_T13_PROFILE
                        LDY             #>MSG_T13_PROFILE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        TAY
                        LDX             #$02
                        JSR             BIO_FTDI_READ_BYTE_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCS             ?BYTE
                        LDX             #<MSG_T13_TIMEOUT
                        LDY             #>MSG_T13_TIMEOUT
                        JSR             SYS_WRITE_CSTRING
                        RTS
?BYTE:                  LDX             #<MSG_BYTE
                        LDY             #>MSG_BYTE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: RUN_T13_PROFILE_SWEEP  [HASH:76253B28]
; ----------------------------------------------------------------------------
RUN_T13_PROFILE_SWEEP:
                        LDA             #$00
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$01
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$02
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$04
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$08
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$10
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$20
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$40
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$03
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        LDA             #$80
                        JSR             RUN_READ_TMO_PROFILE_CASE
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: RUN_T14_NONBLOCK_BURST  [HASH:4EBDDF20]
; ----------------------------------------------------------------------------
RUN_T14_NONBLOCK_BURST:
                        LDX             #<MSG_T14_BEGIN
                        LDY             #>MSG_T14_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             BIO_FTDI_FLUSH_RX

                        LDA             #$00
                        STA             T14_READY_COUNT
                        LDX             #$20
?LOOP:                  JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             ?NEXT
                        INC             T14_READY_COUNT
?NEXT:                  DEX
                        BNE             ?LOOP

                        LDA             T14_READY_COUNT
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: RUN_T15_BLOCKING_GUARDED  [HASH:1FBDE95C]
; ----------------------------------------------------------------------------
RUN_T15_BLOCKING_GUARDED:
                        LDX             #<MSG_T15_BEGIN
                        LDY             #>MSG_T15_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        JSR             WAIT_TYPE_INPUT_WINDOW_3S

                        LDX             #$20
                        LDY             #$02
                        JSR             BIO_FTDI_WAIT_RX_READY_TMO
                        JSR             PRINT_BIO_C_STATUS
                        BCC             ?NO_INPUT

                        JSR             BIO_FTDI_READ_BYTE_BLOCK
                        JSR             PRINT_BIO_C_STATUS
                        LDX             #<MSG_BYTE
                        LDY             #>MSG_BYTE
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        BRA             ?WRITE_BLOCK

?NO_INPUT:              LDX             #<MSG_T15_SKIP
                        LDY             #>MSG_T15_SKIP
                        JSR             SYS_WRITE_CSTRING

?WRITE_BLOCK:           LDA             #'K'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             PRINT_BIO_C_STATUS
                        JSR             COR_FTDI_WRITE_CRLF
                        LDX             #<MSG_T15_WRITE_OK
                        LDY             #>MSG_T15_WRITE_OK
                        JSR             SYS_WRITE_CSTRING
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: RUN_T16_SCAN_SWEEP  [HASH:864B689D]
; ----------------------------------------------------------------------------
RUN_T16_SCAN_SWEEP:
                        LDX             #<MSG_T16_BEGIN
                        LDY             #>MSG_T16_BEGIN
                        JSR             SYS_WRITE_CSTRING
                        LDA             #$00
                        STA             T16_READY_COUNT
                        LDX             #$0C
?LOOP:                  JSR             BIO_FTDI_POLL_RX_READY
                        BCC             ?DELAY
                        INC             T16_READY_COUNT
?DELAY:                 JSR             DELAY_250MS_8MHZ
                        DEX
                        BNE             ?LOOP

                        LDA             T16_READY_COUNT
                        LDX             #<MSG_COUNT_A
                        LDY             #>MSG_COUNT_A
                        JSR             PRINT_HEX_A_WITH_PREFIX
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: WAIT_NEXT_CYCLE_OR_CTRL_C  [HASH:D2B5C683]
; ----------------------------------------------------------------------------
WAIT_NEXT_CYCLE_OR_CTRL_C:
                        LDX             #<MSG_NEXT_CYCLE
                        LDY             #>MSG_NEXT_CYCLE
                        JSR             SYS_WRITE_CSTRING
                        LDX             #$0C
?LOOP:                  JSR             CHECK_FOR_CTRL_C_EXIT
                        JSR             DELAY_250MS_8MHZ
                        DEX
                        BNE             ?LOOP
                        JSR             CHECK_FOR_CTRL_C_EXIT
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: CHECK_FOR_CTRL_C_EXIT  [HASH:0680F72C]
; ----------------------------------------------------------------------------
CHECK_FOR_CTRL_C_EXIT:
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             ?NO_CTRL_C
                        CMP             #$03
                        BNE             ?NO_CTRL_C
                        LDX             #<MSG_CTRL_C_EXIT
                        LDY             #>MSG_CTRL_C_EXIT
                        JSR             SYS_WRITE_CSTRING
                        BRK             00
?HALT:                  BRA             ?HALT
?NO_CTRL_C:             RTS

; ----------------------------------------------------------------------------
; ROUTINE: PRINT_HEX_A_WITH_PREFIX  [HASH:25CEEB64]
; IN :
; - X:Y = pointer to cstring prefix
; - A   = byte to print as hex
; OUT:
; - A and flags preserved
; ----------------------------------------------------------------------------
PRINT_HEX_A_WITH_PREFIX:
                        PHP
                        PHA
                        PHA
                        JSR             SYS_WRITE_CSTRING
                        PLA
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             COR_FTDI_WRITE_CRLF
                        PLA
                        PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PRINT_DELAY_MSG  [HASH:32A17112]
; ----------------------------------------------------------------------------
PRINT_DELAY_MSG:
                        LDX             #<MSG_DELAY
                        LDY             #>MSG_DELAY
                        JSR             SYS_WRITE_CSTRING
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: WAIT_INPUT_WINDOW_3S  [HASH:CCE1B1C3]
; ----------------------------------------------------------------------------
WAIT_INPUT_WINDOW_3S:
                        JSR             PRINT_DELAY_MSG
                        JSR             DELAY_3S_8MHZ
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: WAIT_BETWEEN_TESTS  [HASH:329FE7BD]
; ----------------------------------------------------------------------------
WAIT_BETWEEN_TESTS:
                        LDX             #<MSG_BETWEEN_TESTS
                        LDY             #>MSG_BETWEEN_TESTS
                        JSR             SYS_WRITE_CSTRING
                        JSR             DELAY_3S_8MHZ
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: WAIT_NO_INPUT_WINDOW_3S  [HASH:B632F3AD]
; ----------------------------------------------------------------------------
WAIT_NO_INPUT_WINDOW_3S:
                        LDX             #<MSG_DELAY_NO_INPUT
                        LDY             #>MSG_DELAY_NO_INPUT
                        JSR             SYS_WRITE_CSTRING
                        JSR             DELAY_3S_8MHZ
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: WAIT_TYPE_INPUT_WINDOW_3S  [HASH:654A8F56]
; ----------------------------------------------------------------------------
WAIT_TYPE_INPUT_WINDOW_3S:
                        LDX             #<MSG_DELAY_TYPE_INPUT
                        LDY             #>MSG_DELAY_TYPE_INPUT
                        JSR             SYS_WRITE_CSTRING
                        JSR             DELAY_3S_8MHZ
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: PRINT_BIO_C_STATUS  [HASH:0DBA7AD6]
; PURPOSE: Print carry status from last BIO call and preserve flags.
; ----------------------------------------------------------------------------
PRINT_BIO_C_STATUS:
                        PHP
                        PLA
                        PHA
                        AND             #$01
                        BNE             ?C_SET
?C_CLEAR:               LDX             #<MSG_BIO_C0
                        LDY             #>MSG_BIO_C0
                        JSR             SYS_WRITE_CSTRING
                        BRA             ?DONE
?C_SET:                 LDX             #<MSG_BIO_C1
                        LDY             #>MSG_BIO_C1
                        JSR             SYS_WRITE_CSTRING
?DONE:                  PLP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: DELAY_3S_8MHZ  [HASH:2D1D64D9]
; ----------------------------------------------------------------------------
DELAY_3S_8MHZ:
                        LDA             #$6A
DELAY3_OUTER:
                        LDX             #$B6
DELAY3_MIDDLE:
                        LDY             #$F8
DELAY3_INNER:
                        DEY
                        BNE             DELAY3_INNER
                        DEX
                        BNE             DELAY3_MIDDLE
                        DEC             A
                        BNE             DELAY3_OUTER
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: DELAY_250MS_8MHZ  [HASH:0CC1A404]
; ----------------------------------------------------------------------------
DELAY_250MS_8MHZ:
                        LDA             #$09
DELAY250_OUTER:
                        LDX             #$B6
DELAY250_MIDDLE:
                        LDY             #$F8
DELAY250_INNER:
                        DEY
                        BNE             DELAY250_INNER
                        DEX
                        BNE             DELAY250_MIDDLE
                        DEC             A
                        BNE             DELAY250_OUTER
                        RTS

MSG_TITLE:              DB              13,10,"BIO-L1-FTDI TEST SUITE",13,10,0
MSG_INIT_CALLED:        DB              "BIO_FTDI_INIT CALLED",13,10,0
MSG_LOOP_HEADER:        DB              13,10,"BEGIN SUITE CYCLE",13,10,0

MSG_T1_BEGIN:           DB              13,10,"BIO-L1-FTDI-ENUM-CHK-01",13,10,0
MSG_T1_YES:             DB              "BIO-L1-FTDI-ENUM-CHK-01: ENUMERATED",13,10,0
MSG_T1_NO:              DB              "BIO-L1-FTDI-ENUM-CHK-01: NOT ENUMERATED",13,10,0

MSG_T2_BEGIN:           DB              13,10,"BIO-L1-FTDI-READ-NB-01 (CLEAN)",13,10,0
MSG_T2_READ:            DB              "BIO-L1-FTDI-READ-NB-01: CALL",13,10,0
MSG_T2_EMPTY:           DB              "BIO-L1-FTDI-READ-NB-01: NO DATA",13,10,0

MSG_T3_BEGIN:           DB              13,10,"BIO-L1-FTDI-WAIT-TMO-01 X=0 Y=00",13,10,0
MSG_T3_READY:           DB              "BIO-L1-FTDI-WAIT-TMO-01: READY",13,10,0
MSG_T3_EMPTY:           DB              "BIO-L1-FTDI-WAIT-TMO-01: EMPTY/TMO",13,10,0

MSG_T4_BEGIN:           DB              13,10,"BIO-L1-FTDI-WRITE-NB-01 BYTE 'N'",13,10,0
MSG_T4_PASS:            DB              "BIO-L1-FTDI-WRITE-NB-01: SUCCESS",13,10,0
MSG_T4_FAIL:            DB              "BIO-L1-FTDI-WRITE-NB-01: NOT READY/TMO",13,10,0

MSG_T5_BEGIN:           DB              13,10,"BIO-L1-FTDI-WRITE-TMO-01 IMM+BOUNDED",13,10,0

MSG_T6_BEGIN:           DB              13,10,"BIO-L1-FTDI-READ-TMO-01 X=0 Y=00 CLEAN",13,10,0
MSG_T6_PASS:            DB              "BIO-L1-FTDI-READ-TMO-01: NO DATA",13,10,0
MSG_T6_WARN:            DB              "BIO-L1-FTDI-READ-TMO-01: BYTE=",0

MSG_T7_BEGIN:           DB              13,10,"BIO-L1-FTDI-READ-TMO-02 X=40 Y=02 IN 3S",13,10,0
MSG_T7_TIMEOUT:         DB              "BIO-L1-FTDI-READ-TMO-02: TMO/NO BYTE",13,10,0

MSG_T8_BEGIN:           DB              13,10,"BIO-L1-FTDI-DRAIN-MAX-01 X=20 CLEAN",13,10,0
MSG_T8_PASS:            DB              "BIO-L1-FTDI-DRAIN-MAX-01: PASS",13,10,0
MSG_T8_FAIL:            DB              "BIO-L1-FTDI-DRAIN-MAX-01: NONZERO",13,10,0

MSG_T9_BEGIN:           DB              13,10,"BIO-L1-FTDI-DRAIN-MAX-02 X=20 IN 3S",13,10,0

MSG_T10_BEGIN:          DB              13,10,"BIO-L1-FTDI-FLUSH-COUNT-01 CLEAN",13,10,0
MSG_T10_PASS:           DB              "BIO-L1-FTDI-FLUSH-COUNT-01: PASS",13,10,0
MSG_T10_FAIL:           DB              "BIO-L1-FTDI-FLUSH-COUNT-01: NONZERO",13,10,0

MSG_T11_BEGIN:          DB              13,10,"BIO-L1-FTDI-FLUSH-COUNT-02 IN 3S",13,10,0

MSG_T12_BEGIN:          DB              13,10,"BIO-L1-FTDI-FLUSH-PRESA-01",13,10,0
MSG_T12_PASS:           DB              "BIO-L1-FTDI-FLUSH-PRESA-01: PASS",13,10,0
MSG_T12_FAIL_A:         DB              "BIO-L1-FTDI-FLUSH-PRESA-01: A CHANGED",13,10,0
MSG_T12_FAIL_C0:        DB              "BIO-L1-FTDI-FLUSH-PRESA-01: C=0",13,10,0

MSG_T13_BEGIN:          DB              13,10,"BIO-L1-FTDI-READ-TMO-PROFILE-03",13,10,0
MSG_T13_PROFILE:        DB              "BIO-L1-FTDI-READ-TMO-PROFILE-03 Y=",0
MSG_T13_TIMEOUT:        DB              " -> TMO/NO BYTE",13,10,0
MSG_T14_BEGIN:          DB              13,10,"BIO-L1-FTDI-NONBLOCK-BURST-01 X=20",13,10,0
MSG_T15_BEGIN:          DB              13,10,"BIO-L1-FTDI-BLOCK-GUARDED-01",13,10,0
MSG_T15_SKIP:           DB              "BIO-L1-FTDI-BLOCK-GUARDED-01: SKIP READ (NO INPUT)",13,10,0
MSG_T15_WRITE_OK:       DB              "BIO-L1-FTDI-BLOCK-GUARDED-01: WRITE-BLOCK SENT 'K'",13,10,0
MSG_T16_BEGIN:          DB              13,10,"BIO-L1-FTDI-SCAN-SWEEP-01 X=0C STEP=250MS",13,10,0

MSG_BYTE:               DB              "BYTE=",0
MSG_COUNT_A:            DB              "COUNT A = ",0
MSG_VERIFY_EMPTY:       DB              "VERIFY: EMPTY AFTER OP",13,10,0
MSG_VERIFY_STILL_READY: DB              "VERIFY: STILL READY AFTER OP",13,10,0
MSG_BIO_C0:             DB              "BIO C=0",13,10,0
MSG_BIO_C1:             DB              "BIO C=1",13,10,0
MSG_DELAY:              DB              "DELAY 3S...",13,10,0
MSG_BETWEEN_TESTS:      DB              13,10,"PAUSE BETWEEN TESTS (3S)...",13,10,0
MSG_RUN1:               DB              "RUN 1 (DO NOT TYPE)",13,10,0
MSG_RUN2:               DB              "RUN 2 (TYPE NOW)",13,10,0
MSG_DELAY_NO_INPUT:     DB              "DELAY 3S - DO NOT TYPE",13,10,0
MSG_DELAY_TYPE_INPUT:   DB              "DELAY 3S - TYPE NOW",13,10,0
MSG_NEXT_CYCLE:         DB              13,10,"NEXT CYCLE IN ~3S (SEND CTRL+C TO STOP)",13,10,0
MSG_CTRL_C_EXIT:        DB              13,10,"CTRL+C DETECTED - EXITING TEST LOOP",13,10,0
MSG_DONE:               DB              13,10,"TEST SUITE CYCLE COMPLETE",13,10,0

T14_READY_COUNT:        DB              0
T16_READY_COUNT:        DB              0


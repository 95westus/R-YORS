; ----------------------------------------------------------------------------
; str8-record-phase1-proof.asm
; RAM-resident Phase-1 board proof for the STR8 V1 S19 record service.
;
; Link at $3000 and run with Bank 3 visible.  This proof never asks the
; worker to program a differing byte: the APPLY_LF success case contains only
; a byte already present in low flash.  The NEED_ERASE case is preflight only.
;
; Entries:
;   $3000 buffered parser and ABI suite
;   $3003 APPLY_LF non-erasing suite
;   $3006 console 252-byte S1 suite (send max252 S1, then CR)
;   $3009 console abort suite (send Ctrl-C)
;
; Result row $1A00-$1A17:
;   00 verdict ($AC pass, $E1 proof failure)
;   01 suite (01 buffer, 02 APPLY_LF, 03 console max, 04 console abort)
;   02 current/passed case count, 03 assertion field
;   04 actual, 05 expected, 06 service A, 07 service C, 08 service status
;   09 kind, 0A flags, 0B/0C address, 0D data length, 0E/0F entry
;   10/11 failure address, 12 observed, 13 expected
;   14/15 dynamic low-flash address, 16 before, 17 after
;
; Return: A=$AC, X=case count, Y=suite, C=1 on pass;
;         A=$E1, X=case, Y=field, C=0 on proof failure.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          STR8_RECORD_PHASE1_PROOF_APP

                        XDEF            START

                        INCLUDE         "STR8/str8-record-eq.inc"

P1_BOARD                EQU             $1A00
P1_VERDICT              EQU             P1_BOARD+$00
P1_SUITE_ROW            EQU             P1_BOARD+$01
P1_CASE_ROW             EQU             P1_BOARD+$02
P1_FIELD_ROW            EQU             P1_BOARD+$03
P1_ACTUAL_ROW           EQU             P1_BOARD+$04
P1_EXPECTED_ROW         EQU             P1_BOARD+$05
P1_RET_A_ROW            EQU             P1_BOARD+$06
P1_RET_C_ROW            EQU             P1_BOARD+$07
P1_STATUS_ROW           EQU             P1_BOARD+$08
P1_KIND_ROW             EQU             P1_BOARD+$09
P1_FLAGS_ROW            EQU             P1_BOARD+$0A
P1_ADDR_LO_ROW          EQU             P1_BOARD+$0B
P1_ADDR_HI_ROW          EQU             P1_BOARD+$0C
P1_DATA_LEN_ROW         EQU             P1_BOARD+$0D
P1_ENTRY_LO_ROW         EQU             P1_BOARD+$0E
P1_ENTRY_HI_ROW         EQU             P1_BOARD+$0F
P1_FAIL_LO_ROW          EQU             P1_BOARD+$10
P1_FAIL_HI_ROW          EQU             P1_BOARD+$11
P1_OBSERVED_ROW         EQU             P1_BOARD+$12
P1_EXPECTED_DATA_ROW    EQU             P1_BOARD+$13
P1_SCAN_LO_ROW          EQU             P1_BOARD+$14
P1_SCAN_HI_ROW          EQU             P1_BOARD+$15
P1_BEFORE_ROW           EQU             P1_BOARD+$16
P1_AFTER_ROW            EQU             P1_BOARD+$17

P1_STATE                EQU             $1A20
P1_SUITE                EQU             P1_STATE+$00
P1_COUNT                EQU             P1_STATE+$01
P1_FIELD                EQU             P1_STATE+$02
P1_EXPECT_STATUS        EQU             P1_STATE+$03
P1_EXPECT_CARRY         EQU             P1_STATE+$04
P1_EXPECT_FAIL_LO       EQU             P1_STATE+$07
P1_EXPECT_FAIL_HI       EQU             P1_STATE+$08
P1_EXPECT_OBSERVED      EQU             P1_STATE+$09
P1_EXPECT_DATA          EQU             P1_STATE+$0A

P1_LINE_LO              EQU             $00
P1_LINE_HI              EQU             $01
P1_LINE_LEN             EQU             $02
P1_DATA_LO              EQU             $03
P1_DATA_HI              EQU             $04
P1_DATA_LEN             EQU             $05
P1_INDEX                EQU             $06
P1_SCAN_LO              EQU             $07
P1_SCAN_HI              EQU             $08
P1_SCAN_OBSERVED        EQU             $09
P1_SCAN_EXPECTED        EQU             $0A
; Indirect-indexed 65C02 operands are zero-page pointers.  Keep the expected
; descriptor pointer here rather than in the $1Axx result/state area.
P1_DESC_LO              EQU             $0B
P1_DESC_HI              EQU             $0C

P1_SUITE_BUFFER         EQU             $01
P1_SUITE_APPLY          EQU             $02
P1_SUITE_CONSOLE_MAX    EQU             $03
P1_SUITE_CONSOLE_ABORT  EQU             $04

                        CODE
START:
                        JMP             P1_BUFFERED
                        JMP             P1_APPLY
                        JMP             P1_CONSOLE_MAX
                        JMP             P1_CONSOLE_ABORT

; ----------------------------------------------------------------------------
; $3000: resident header plus all buffered parser outcomes.  $6000-$6003 is
; a write guard: parsing the valid S1 and every malformed record must leave it
; untouched.
; ----------------------------------------------------------------------------
P1_BUFFERED:
                        CLD
                        LDA             #P1_SUITE_BUFFER
                        JSR             P1_BEGIN_SUITE
                        JSR             P1_NEXT_CASE
                        JSR             P1_CHECK_ROM_FACE
                        BCS             ?B1
                        JMP             P1_FAIL
?B1:
                        LDA             #$11
                        STA             $6000
                        LDA             #$22
                        STA             $6001
                        LDA             #$33
                        STA             $6002
                        LDA             #$44
                        STA             $6003

                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_S0
                        BCS             ?B2
                        JMP             P1_FAIL
?B2:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_S1
                        BCS             ?B3
                        JMP             P1_FAIL
?B3:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_S9
                        BCS             ?B4
                        JMP             P1_FAIL
?B4:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_S1_LOWER
                        BCS             ?B5
                        JMP             P1_FAIL
?B5:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_START
                        BCS             ?B6
                        JMP             P1_FAIL
?B6:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_TYPE
                        BCS             ?B7
                        JMP             P1_FAIL
?B7:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_HEX
                        BCS             ?B8
                        JMP             P1_FAIL
?B8:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_COUNT
                        BCS             ?B9
                        JMP             P1_FAIL
?B9:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_CHECKSUM
                        BCS             ?B10
                        JMP             P1_FAIL
?B10:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_END
                        BCS             ?B11
                        JMP             P1_FAIL
?B11:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_OP
                        BCS             ?B12
                        JMP             P1_FAIL
?B12:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_FORMAT
                        BCS             ?B13
                        JMP             P1_FAIL
?B13:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_BAD_SOURCE
                        BCS             ?B14
                        JMP             P1_FAIL
?B14:
                        JSR             P1_NEXT_CASE
                        JSR             P1_PARSE_WRAP_SOURCE
                        BCS             ?B15
                        JMP             P1_FAIL
?B15:
                        JMP             P1_PASS

; ----------------------------------------------------------------------------
; $3003: APPLY_LF safety boundary and all-matching worker path.
; ----------------------------------------------------------------------------
P1_APPLY:
                        CLD
                        LDA             #P1_SUITE_APPLY
                        JSR             P1_BEGIN_SUITE

                        JSR             P1_NEXT_CASE
                        JSR             P1_APPLY_ZERO
                        BCS             ?A1
                        JMP             P1_FAIL
?A1:
                        JSR             P1_NEXT_CASE
                        JSR             P1_APPLY_BELOW
                        BCS             ?A2
                        JMP             P1_FAIL
?A2:
                        JSR             P1_NEXT_CASE
                        JSR             P1_APPLY_CROSS
                        BCS             ?A3
                        JMP             P1_FAIL
?A3:
                        JSR             P1_NEXT_CASE
                        JSR             P1_APPLY_ABOVE
                        BCS             ?A4
                        JMP             P1_FAIL
?A4:
                        JSR             P1_NEXT_CASE
                        JSR             P1_FIND_OCCUPIED
                        BCS             ?A5_FOUND
                        LDA             #$F0
                        STA             P1_FIELD
                        STZ             P1_ACTUAL_ROW
                        LDA             #$01
                        STA             P1_EXPECTED_ROW
                        JMP             P1_FAIL
?A5_FOUND:
                        JSR             P1_APPLY_NEED_ERASE
                        BCS             ?A5
                        JMP             P1_FAIL
?A5:
                        JSR             P1_NEXT_CASE
                        JSR             P1_APPLY_MATCHING
                        BCS             ?A6
                        JMP             P1_FAIL
?A6:
                        JMP             P1_PASS

; ----------------------------------------------------------------------------
; $3006: console parser maximum.  After G 3006, paste the one S1 line from
; str8-record-phase1-max252.s19 and send its terminating CR.
; ----------------------------------------------------------------------------
P1_CONSOLE_MAX:
                        CLD
                        LDA             #P1_SUITE_CONSOLE_MAX
                        JSR             P1_BEGIN_SUITE
                        JSR             P1_NEXT_CASE
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_SOURCE_CONSOLE
                        STA             STR8_REC_SOURCE
                        LDA             #STR8_REC_OK
                        STA             P1_EXPECT_STATUS
                        LDA             #$01
                        STA             P1_EXPECT_CARRY
                        LDA             #<P1_DESC_MAX
                        STA             P1_DESC_LO
                        LDA             #>P1_DESC_MAX
                        STA             P1_DESC_HI
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCS             ?CM1
                        JMP             P1_FAIL
?CM1:
                        JSR             P1_EXPECT_DESCRIPTOR
                        BCS             ?CM2
                        JMP             P1_FAIL
?CM2:
                        JSR             P1_EXPECT_INCREMENT_BUFFER
                        BCS             ?CM3
                        JMP             P1_FAIL
?CM3:
                        JMP             P1_PASS

; ----------------------------------------------------------------------------
; $3009: console abort.  After G 3009, send Ctrl-C (byte $03).
; ----------------------------------------------------------------------------
P1_CONSOLE_ABORT:
                        CLD
                        LDA             #P1_SUITE_CONSOLE_ABORT
                        JSR             P1_BEGIN_SUITE
                        JSR             P1_NEXT_CASE
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_SOURCE_CONSOLE
                        STA             STR8_REC_SOURCE
                        LDA             #STR8_REC_ABORT
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCS             ?CA1
                        JMP             P1_FAIL
?CA1:
                        JMP             P1_PASS

; ----------------------------------------------------------------------------
; Buffered parser vectors.
; ----------------------------------------------------------------------------
P1_PARSE_S0:
                        LDA             #<P1_S0
                        STA             P1_LINE_LO
                        LDA             #>P1_S0
                        STA             P1_LINE_HI
                        LDA             #$0E
                        STA             P1_LINE_LEN
                        LDA             #<P1_DESC_S0
                        STA             P1_DESC_LO
                        LDA             #>P1_DESC_S0
                        STA             P1_DESC_HI
                        LDA             #<P1_DATA_HELLO
                        STA             P1_DATA_LO
                        LDA             #>P1_DATA_HELLO
                        STA             P1_DATA_HI
                        LDA             #$02
                        STA             P1_DATA_LEN
                        JMP             P1_PARSE_VALID

P1_PARSE_S1:
                        LDA             #<P1_S1
                        STA             P1_LINE_LO
                        LDA             #>P1_S1
                        STA             P1_LINE_HI
                        LDA             #$12
                        STA             P1_LINE_LEN
                        LDA             #<P1_DESC_S1
                        STA             P1_DESC_LO
                        LDA             #>P1_DESC_S1
                        STA             P1_DESC_HI
                        LDA             #<P1_DATA_DEAD
                        STA             P1_DATA_LO
                        LDA             #>P1_DATA_DEAD
                        STA             P1_DATA_HI
                        LDA             #$04
                        STA             P1_DATA_LEN
                        JMP             P1_PARSE_VALID

P1_PARSE_S9:
                        LDA             #<P1_S9
                        STA             P1_LINE_LO
                        LDA             #>P1_S9
                        STA             P1_LINE_HI
                        LDA             #$0A
                        STA             P1_LINE_LEN
                        LDA             #<P1_DESC_S9
                        STA             P1_DESC_LO
                        LDA             #>P1_DESC_S9
                        STA             P1_DESC_HI
                        STZ             P1_DATA_LEN
                        JMP             P1_PARSE_VALID

P1_PARSE_S1_LOWER:
                        LDA             #<P1_S1_LOWER
                        STA             P1_LINE_LO
                        LDA             #>P1_S1_LOWER
                        STA             P1_LINE_HI
                        LDA             #$12
                        STA             P1_LINE_LEN
                        LDA             #<P1_DESC_S1
                        STA             P1_DESC_LO
                        LDA             #>P1_DESC_S1
                        STA             P1_DESC_HI
                        LDA             #<P1_DATA_DEAD
                        STA             P1_DATA_LO
                        LDA             #>P1_DATA_DEAD
                        STA             P1_DATA_HI
                        LDA             #$04
                        STA             P1_DATA_LEN
                        JMP             P1_PARSE_VALID

P1_PARSE_VALID:
                        LDA             #STR8_REC_OK
                        STA             P1_EXPECT_STATUS
                        LDA             #$01
                        STA             P1_EXPECT_CARRY
                        JMP             P1_PARSE_BUFFER

P1_PARSE_BAD_START:
                        LDA             #<P1_BAD_START
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_START
                        STA             P1_LINE_HI
                        LDA             #$01
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_START
                        JMP             P1_PARSE_INVALID

P1_PARSE_BAD_TYPE:
                        LDA             #<P1_BAD_TYPE
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_TYPE
                        STA             P1_LINE_HI
                        LDA             #$02
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_TYPE
                        JMP             P1_PARSE_INVALID

P1_PARSE_BAD_HEX:
                        LDA             #<P1_BAD_HEX
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_HEX
                        STA             P1_LINE_HI
                        LDA             #$03
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_HEX
                        JMP             P1_PARSE_INVALID

P1_PARSE_BAD_COUNT:
                        LDA             #<P1_BAD_COUNT
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_COUNT
                        STA             P1_LINE_HI
                        LDA             #$04
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_COUNT
                        JMP             P1_PARSE_INVALID

P1_PARSE_BAD_CHECKSUM:
                        LDA             #<P1_BAD_CHECKSUM
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_CHECKSUM
                        STA             P1_LINE_HI
                        LDA             #$12
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_CHECKSUM
                        JMP             P1_PARSE_INVALID

P1_PARSE_BAD_END:
                        LDA             #<P1_BAD_END
                        STA             P1_LINE_LO
                        LDA             #>P1_BAD_END
                        STA             P1_LINE_HI
                        LDA             #$0B
                        STA             P1_LINE_LEN
                        LDA             #STR8_REC_BAD_END
                        JMP             P1_PARSE_INVALID

P1_PARSE_INVALID:
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        STZ             P1_DESC_LO
                        STZ             P1_DESC_HI
                        STZ             P1_DATA_LEN
                        JMP             P1_PARSE_BUFFER

P1_PARSE_BAD_OP:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_BAD_OP
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        JMP             P1_EXPECT_GUARD
?FAIL:                  RTS

P1_PARSE_BAD_FORMAT:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_BAD_FORMAT
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        JMP             P1_EXPECT_GUARD
?FAIL:                  RTS

P1_PARSE_BAD_SOURCE:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #$02
                        STA             STR8_REC_SOURCE
                        LDA             #STR8_REC_BAD_SOURCE
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        JMP             P1_EXPECT_GUARD
?FAIL:                  RTS

P1_PARSE_WRAP_SOURCE:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        STZ             STR8_REC_SOURCE
                        LDA             #$F0
                        STA             STR8_REC_SRC_LO
                        LDA             #$FF
                        STA             STR8_REC_SRC_HI
                        LDA             #$11
                        STA             STR8_REC_SRC_LEN
                        LDA             #STR8_REC_BAD_SOURCE
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        JMP             P1_EXPECT_GUARD
?FAIL:                  RTS

P1_PARSE_BUFFER:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_PARSE
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        STZ             STR8_REC_SOURCE
                        LDA             P1_LINE_LO
                        STA             STR8_REC_SRC_LO
                        LDA             P1_LINE_HI
                        STA             STR8_REC_SRC_HI
                        LDA             P1_LINE_LEN
                        STA             STR8_REC_SRC_LEN
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        LDA             P1_EXPECT_STATUS
                        BNE             ?GUARD
                        JSR             P1_EXPECT_DESCRIPTOR
                        BCC             ?FAIL
                        JSR             P1_EXPECT_BUFFER
                        BCC             ?FAIL
?GUARD:                 JMP             P1_EXPECT_GUARD
?FAIL:                  RTS

; ----------------------------------------------------------------------------
; APPLY_LF vectors.  They are constructed directly so each policy edge is
; isolated; the buffered suite above separately proves parser publication.
; ----------------------------------------------------------------------------
P1_APPLY_ZERO:
                        JSR             P1_INIT_APPLY
                        LDA             #$FF
                        STA             STR8_REC_ADDR_LO
                        STA             STR8_REC_ADDR_HI
                        STZ             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_OK
                        STA             P1_EXPECT_STATUS
                        LDA             #$01
                        STA             P1_EXPECT_CARRY
                        JSR             P1_ZERO_FAILURE_EXPECTED
                        JMP             P1_DO_APPLY

P1_APPLY_BELOW:
                        JSR             P1_INIT_APPLY
                        LDA             #$5A
                        STA             STR8_REC_DATA_BUF
                        LDA             #$FF
                        STA             STR8_REC_ADDR_LO
                        LDA             #$7F
                        STA             STR8_REC_ADDR_HI
                        LDA             #$01
                        STA             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_LF_PROTECT
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        LDA             #$FF
                        STA             P1_EXPECT_FAIL_LO
                        LDA             #$7F
                        STA             P1_EXPECT_FAIL_HI
                        STZ             P1_EXPECT_OBSERVED
                        STZ             P1_EXPECT_DATA
                        JMP             P1_DO_APPLY

P1_APPLY_CROSS:
                        JSR             P1_INIT_APPLY
                        STZ             STR8_REC_DATA_BUF
                        STZ             STR8_REC_DATA_BUF+1
                        LDA             #$FF
                        STA             STR8_REC_ADDR_LO
                        LDA             #$BF
                        STA             STR8_REC_ADDR_HI
                        LDA             #$02
                        STA             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_LF_PROTECT
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        STZ             P1_EXPECT_FAIL_LO
                        LDA             #$C0
                        STA             P1_EXPECT_FAIL_HI
                        STZ             P1_EXPECT_OBSERVED
                        STZ             P1_EXPECT_DATA
                        JMP             P1_DO_APPLY

P1_APPLY_ABOVE:
                        JSR             P1_INIT_APPLY
                        LDA             #$5A
                        STA             STR8_REC_DATA_BUF
                        STZ             STR8_REC_ADDR_LO
                        LDA             #$C0
                        STA             STR8_REC_ADDR_HI
                        LDA             #$01
                        STA             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_LF_PROTECT
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        STZ             P1_EXPECT_FAIL_LO
                        LDA             #$C0
                        STA             P1_EXPECT_FAIL_HI
                        STZ             P1_EXPECT_OBSERVED
                        STZ             P1_EXPECT_DATA
                        JMP             P1_DO_APPLY

P1_APPLY_NEED_ERASE:
                        JSR             P1_INIT_APPLY
                        LDA             P1_SCAN_EXPECTED
                        STA             STR8_REC_DATA_BUF
                        LDA             P1_SCAN_LO
                        STA             STR8_REC_ADDR_LO
                        LDA             P1_SCAN_HI
                        STA             STR8_REC_ADDR_HI
                        LDA             #$01
                        STA             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_LF_NEED_ERASE
                        STA             P1_EXPECT_STATUS
                        STZ             P1_EXPECT_CARRY
                        LDA             P1_SCAN_LO
                        STA             P1_EXPECT_FAIL_LO
                        LDA             P1_SCAN_HI
                        STA             P1_EXPECT_FAIL_HI
                        LDA             P1_SCAN_OBSERVED
                        STA             P1_EXPECT_OBSERVED
                        LDA             P1_SCAN_EXPECTED
                        STA             P1_EXPECT_DATA
                        JSR             P1_DO_APPLY
                        BCC             ?FAIL
                        JMP             P1_CHECK_SCAN_UNCHANGED
?FAIL:                  RTS

P1_APPLY_MATCHING:
                        JSR             P1_INIT_APPLY
                        LDA             P1_SCAN_OBSERVED
                        STA             STR8_REC_DATA_BUF
                        LDA             P1_SCAN_LO
                        STA             STR8_REC_ADDR_LO
                        LDA             P1_SCAN_HI
                        STA             STR8_REC_ADDR_HI
                        LDA             #$01
                        STA             STR8_REC_DATA_LEN
                        LDA             #STR8_REC_OK
                        STA             P1_EXPECT_STATUS
                        LDA             #$01
                        STA             P1_EXPECT_CARRY
                        JSR             P1_ZERO_FAILURE_EXPECTED
                        JSR             P1_DO_APPLY
                        BCC             ?FAIL
                        JMP             P1_CHECK_SCAN_UNCHANGED
?FAIL:                  RTS

P1_INIT_APPLY:
                        JSR             P1_CLEAR_REQUEST
                        LDA             #STR8_REC_OP_APPLY_LF
                        STA             STR8_REC_OP
                        LDA             #STR8_REC_FORMAT_S19
                        STA             STR8_REC_FORMAT
                        LDA             #STR8_REC_KIND_DATA
                        STA             STR8_REC_KIND
                        STZ             STR8_REC_FLAGS
                        LDA             #STR8_REC_DATA_BUF_LO
                        STA             STR8_REC_DATA_LO
                        LDA             #STR8_REC_DATA_BUF_HI
                        STA             STR8_REC_DATA_HI
                        RTS

P1_ZERO_FAILURE_EXPECTED:
                        STZ             P1_EXPECT_FAIL_LO
                        STZ             P1_EXPECT_FAIL_HI
                        STZ             P1_EXPECT_OBSERVED
                        STZ             P1_EXPECT_DATA
                        RTS

P1_DO_APPLY:
                        JSR             P1_CAPTURE_CALL
                        JSR             P1_EXPECT_RETURN
                        BCC             ?FAIL
                        JMP             P1_EXPECT_FAILURE
?FAIL:                  RTS

; Find one occupied visible-bank-3 low-flash byte.  Its complement is an
; unequal non-erasing request, while the byte itself exercises worker skip.
P1_FIND_OCCUPIED:
                        LDX             #$80
?PAGE:                  STZ             P1_LINE_LO
                        STX             P1_LINE_HI
                        LDY             #$00
?BYTE:                  LDA             (P1_LINE_LO),Y
                        CMP             #$FF
                        BNE             ?FOUND
                        INY
                        BNE             ?BYTE
                        INX
                        CPX             #$C0
                        BNE             ?PAGE
                        CLC
                        RTS
?FOUND:                 STA             P1_SCAN_OBSERVED
                        STA             P1_BEFORE_ROW
                        TYA
                        STA             P1_SCAN_LO
                        STA             P1_SCAN_LO_ROW
                        TXA
                        STA             P1_SCAN_HI
                        STA             P1_SCAN_HI_ROW
                        LDA             P1_SCAN_OBSERVED
                        EOR             #$01
                        STA             P1_SCAN_EXPECTED
                        SEC
                        RTS

P1_CHECK_SCAN_UNCHANGED:
                        LDA             P1_SCAN_LO
                        STA             P1_LINE_LO
                        LDA             P1_SCAN_HI
                        STA             P1_LINE_HI
                        LDY             #$00
                        LDA             (P1_LINE_LO),Y
                        STA             P1_AFTER_ROW
                        LDX             P1_SCAN_OBSERVED
                        LDA             #$24
                        STA             P1_FIELD
                        LDA             P1_AFTER_ROW
                        JMP             P1_ASSERT

; ----------------------------------------------------------------------------
; Common call, result, and assertion support.
; ----------------------------------------------------------------------------
P1_BEGIN_SUITE:
                        STA             P1_SUITE
                        LDX             #$00
                        LDA             #$00
?CLEAR:                 STA             P1_BOARD,X
                        INX
                        CPX             #$18
                        BNE             ?CLEAR
                        LDA             P1_SUITE
                        STA             P1_SUITE_ROW
                        STZ             P1_COUNT
                        RTS

P1_NEXT_CASE:
                        INC             P1_COUNT
                        LDA             P1_COUNT
                        STA             P1_CASE_ROW
                        RTS

P1_PASS:
                        LDA             #$AC
                        STA             P1_VERDICT
                        LDX             P1_COUNT
                        LDY             P1_SUITE
                        SEC
                        RTS

P1_FAIL:
                        LDA             #$E1
                        STA             P1_VERDICT
                        LDX             P1_CASE_ROW
                        LDY             P1_FIELD_ROW
                        CLC
                        RTS

P1_CLEAR_REQUEST:
                        LDX             #$00
                        LDA             #$00
?CLEAR:                 STA             STR8_REC_OP,X
                        INX
                        CPX             #$14
                        BNE             ?CLEAR
                        RTS

P1_CAPTURE_CALL:
                        JSR             STR8_RECORD_SERVICE
                        STA             P1_RET_A_ROW
                        PHP
                        PLA
                        AND             #$01
                        STA             P1_RET_C_ROW
                        LDA             STR8_REC_STATUS
                        STA             P1_STATUS_ROW
                        LDA             STR8_REC_KIND
                        STA             P1_KIND_ROW
                        LDA             STR8_REC_FLAGS
                        STA             P1_FLAGS_ROW
                        LDA             STR8_REC_ADDR_LO
                        STA             P1_ADDR_LO_ROW
                        LDA             STR8_REC_ADDR_HI
                        STA             P1_ADDR_HI_ROW
                        LDA             STR8_REC_DATA_LEN
                        STA             P1_DATA_LEN_ROW
                        LDA             STR8_REC_ENTRY_LO
                        STA             P1_ENTRY_LO_ROW
                        LDA             STR8_REC_ENTRY_HI
                        STA             P1_ENTRY_HI_ROW
                        LDA             STR8_REC_FAIL_LO
                        STA             P1_FAIL_LO_ROW
                        LDA             STR8_REC_FAIL_HI
                        STA             P1_FAIL_HI_ROW
                        LDA             STR8_REC_OBSERVED
                        STA             P1_OBSERVED_ROW
                        LDA             STR8_REC_EXPECTED
                        STA             P1_EXPECTED_DATA_ROW
                        RTS

P1_EXPECT_RETURN:
                        LDA             #$01
                        STA             P1_FIELD
                        LDA             P1_RET_A_ROW
                        LDX             P1_EXPECT_STATUS
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDA             #$02
                        STA             P1_FIELD
                        LDA             P1_RET_C_ROW
                        LDX             P1_EXPECT_CARRY
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDA             #$03
                        STA             P1_FIELD
                        LDA             P1_STATUS_ROW
                        LDX             P1_EXPECT_STATUS
                        JMP             P1_ASSERT
?FAIL:                  RTS

P1_EXPECT_DESCRIPTOR:
                        LDA             P1_DESC_LO
                        ORA             P1_DESC_HI
                        BNE             ?GO
                        SEC
                        RTS
?GO:                    LDX             #$00
?LOOP:                  STX             P1_INDEX
                        TXA
                        TAY
                        LDA             (P1_DESC_LO),Y
                        TAX
                        LDY             P1_INDEX
                        TYA
                        CLC
                        ADC             #$10
                        STA             P1_FIELD
                        LDA             STR8_REC_KIND,Y
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDX             P1_INDEX
                        INX
                        CPX             #$0D
                        BNE             ?LOOP
                        SEC
                        RTS
?FAIL:                  RTS

P1_EXPECT_BUFFER:
                        LDA             P1_DATA_LEN
                        BEQ             ?DONE
                        LDX             #$00
?LOOP:                  STX             P1_INDEX
                        TXA
                        TAY
                        LDA             (P1_DATA_LO),Y
                        TAX
                        LDY             P1_INDEX
                        TYA
                        STA             P1_FIELD
                        LDA             STR8_REC_DATA_BUF,Y
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDX             P1_INDEX
                        INX
                        CPX             P1_DATA_LEN
                        BNE             ?LOOP
?DONE:                  SEC
                        RTS
?FAIL:                  RTS

P1_EXPECT_INCREMENT_BUFFER:
                        LDX             #$00
?LOOP:                  STX             P1_FIELD
                        LDA             STR8_REC_DATA_BUF,X
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        INX
                        CPX             #$FC
                        BNE             ?LOOP
                        SEC
                        RTS
?FAIL:                  RTS

P1_EXPECT_GUARD:
                        LDX             #$00
?LOOP:                  LDA             $6000,X
                        STA             P1_ACTUAL_ROW
                        LDA             P1_GUARD_BYTES,X
                        STA             P1_EXPECTED_ROW
                        CMP             P1_ACTUAL_ROW
                        BEQ             ?NEXT
                        TXA
                        CLC
                        ADC             #$30
                        STA             P1_FIELD
                        CLC
                        RTS
?NEXT:                  INX
                        CPX             #$04
                        BNE             ?LOOP
                        SEC
                        RTS

P1_EXPECT_FAILURE:
                        LDA             #$20
                        STA             P1_FIELD
                        LDA             P1_FAIL_LO_ROW
                        LDX             P1_EXPECT_FAIL_LO
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDA             #$21
                        STA             P1_FIELD
                        LDA             P1_FAIL_HI_ROW
                        LDX             P1_EXPECT_FAIL_HI
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDA             #$22
                        STA             P1_FIELD
                        LDA             P1_OBSERVED_ROW
                        LDX             P1_EXPECT_OBSERVED
                        JSR             P1_ASSERT
                        BCC             ?FAIL
                        LDA             #$23
                        STA             P1_FIELD
                        LDA             P1_EXPECTED_DATA_ROW
                        LDX             P1_EXPECT_DATA
                        JMP             P1_ASSERT
?FAIL:                  RTS

P1_ASSERT:
                        STA             P1_ACTUAL_ROW
                        STX             P1_EXPECTED_ROW
                        CMP             P1_EXPECTED_ROW
                        BEQ             ?OK
                        LDA             P1_FIELD
                        STA             P1_FIELD_ROW
                        CLC
                        RTS
?OK:                    SEC
                        RTS

P1_CHECK_ROM_FACE:
                        LDX             #$00
?HEADER:                LDA             $F000,X
                        STA             P1_ACTUAL_ROW
                        LDA             P1_HEADER_BYTES,X
                        STA             P1_EXPECTED_ROW
                        CMP             P1_ACTUAL_ROW
                        BNE             ?HEADER_FAIL
                        INX
                        CPX             #$10
                        BNE             ?HEADER
                        LDX             #$00
?VECTOR:                LDA             $FFFA,X
                        STA             P1_ACTUAL_ROW
                        LDA             P1_VECTOR_BYTES,X
                        STA             P1_EXPECTED_ROW
                        CMP             P1_ACTUAL_ROW
                        BNE             ?VECTOR_FAIL
                        INX
                        CPX             #$06
                        BNE             ?VECTOR
                        SEC
                        RTS
?HEADER_FAIL:           TXA
                        CLC
                        ADC             #$40
                        BRA             ?FAIL
?VECTOR_FAIL:           TXA
                        CLC
                        ADC             #$60
?FAIL:                  STA             P1_FIELD_ROW
                        CLC
                        RTS

                        DATA
P1_HEADER_BYTES:        DB              $4C,$10,$F0,$4C,$83,$F3,$4C,$8A
                        DB              $F3,$4C,$92,$F3,$53,$52,$01,$07
P1_VECTOR_BYTES:        DB              $99,$F0,$00,$F0,$AD,$F0
P1_GUARD_BYTES:         DB              $11,$22,$33,$44

; Successful result descriptors, beginning at STR8_REC_KIND ($7E9C).
P1_DESC_S0:             DB              $01,$00,$00,$00,$02,$00,$00,$00,$7B,$00,$00,$00,$00
P1_DESC_S1:             DB              $02,$00,$00,$60,$04,$00,$00,$00,$7B,$00,$00,$00,$00
P1_DESC_S9:             DB              $03,$01,$34,$12,$00,$34,$12,$00,$7B,$00,$00,$00,$00
P1_DESC_MAX:            DB              $02,$00,$00,$20,$FC,$00,$00,$00,$7B,$00,$00,$00,$00

P1_DATA_HELLO:          DB              $48,$49
P1_DATA_DEAD:           DB              $DE,$AD,$BE,$EF

; All buffered lines deliberately omit CR/LF: source length is exact.
P1_S0:                  DB              "S0050000484969"
P1_S1:                  DB              "S1076000DEADBEEF60"
P1_S9:                  DB              "S9031234B6"
P1_S1_LOWER:            DB              "s1076000deadbeef60"
P1_BAD_START:           DB              "X"
P1_BAD_TYPE:            DB              "S2"
P1_BAD_HEX:             DB              "S1G"
P1_BAD_COUNT:           DB              "S102"
P1_BAD_CHECKSUM:        DB              "S1076000DEADBEEF61"
P1_BAD_END:             DB              "S9031234B6X"

                        END

MON_CMD_LOAD:
                        STZ             LOAD_AUTO_GO
                        JSR             MON_LOAD_VALIDATE_ARGS
                        BCC             MON_CMD_LOAD_USAGE
                        JSR             MON_LOAD_INIT
                        LDX             #<MSG_LOAD_READY
                        LDY             #>MSG_LOAD_READY
                        JSR             SYS_WRITE_HBLINE

MON_CMD_LOAD_SESSION_LOOP:
                        JSR             MON_LOAD_READ_LINE
                        BCC             MON_CMD_LOAD_LINE_FAIL
                        JSR             MON_LOAD_PARSE_RECORD
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_DATA
                        BEQ             MON_CMD_LOAD_HANDLE_DATA
                        CMP             #LOAD_REC_KIND_TERM
                        BEQ             MON_CMD_LOAD_HANDLE_TERM
                        LDA             LOAD_REC_TYPE
                        BEQ             MON_CMD_LOAD_SESSION_LOOP
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        BRA             MON_CMD_LOAD_SESSION_LOOP

MON_CMD_LOAD_HANDLE_DATA:
                        JSR             MON_LOAD_WRITE_RECORD_DATA
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_ACCUM_RECORD_AND_BYTES
                        JSR             MON_LOAD_TRACK_DATA_RANGE
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        BRA             MON_CMD_LOAD_SESSION_LOOP

MON_CMD_LOAD_HANDLE_TERM:
                        JSR             MON_LOAD_CAPTURE_GO
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        JSR             MON_LOAD_FINALIZE_RANGES
                        BCC             MON_CMD_LOAD_PARSE_FAIL
                        JSR             MON_LOAD_PRINT_SUMMARY
                        JSR             MON_LOAD_MAYBE_GO
                        RTS

MON_CMD_LOAD_USAGE:
                        LDX             #<CMDP_MSG_USAGE_LOAD
                        LDY             #>CMDP_MSG_USAGE_LOAD
                        JMP             CMDP_USAGE_LINE_XY

MON_CMD_LOAD_LINE_FAIL:
                        LDX             #<MSG_LOAD_LINE_STATUS
                        LDY             #>MSG_LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS

MON_CMD_LOAD_PARSE_FAIL:
                        LDX             #<MSG_LOAD_PARSE_FAIL
                        LDY             #>MSG_LOAD_PARSE_FAIL
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_REC_TYPE
                        BEQ             MON_CMD_LOAD_PARSE_FAIL_EOL
                        JSR             SYS_WRITE_CHAR
MON_CMD_LOAD_PARSE_FAIL_EOL:
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_MAYBE_GO  [HASH:4D263EB4]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, CARRY-STATUS, NOSTACK
; PURPOSE: For `LOAD GO`, transfer control to captured GO address.
; OUT: C=1 when no auto-go requested; C=0 when requested but no GO available.
; ----------------------------------------------------------------------------
MON_LOAD_MAYBE_GO:
                        LDA             LOAD_AUTO_GO
                        BEQ             MON_LOAD_MAYBE_GO_DONE
                        LDA             LOAD_GO_VALID
                        BEQ             MON_LOAD_MAYBE_GO_MISSING
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             MON_LOAD_MAYBE_GO_EXEC
                        CLC
                        RTS
MON_LOAD_MAYBE_GO_MISSING:
                        LDX             #<MSG_LOAD_GO_MISSING
                        LDY             #>MSG_LOAD_GO_MISSING
                        JSR             SYS_WRITE_HBLINE
                        CLC
                        RTS
MON_LOAD_MAYBE_GO_EXEC:
                        LDA             LOAD_GO_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_GO_HI
                        STA             CMDP_ADDR_HI
                        LDX             #<MSG_LOAD_GO_EXEC
                        LDY             #>MSG_LOAD_GO_EXEC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             (CMDP_ADDR_LO)
MON_LOAD_MAYBE_GO_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_VALIDATE_ARGS  [HASH:39D0BC33]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, LOAD, NOSTACK
; PURPOSE: Validate LOAD args.
; ACCEPTS: LOAD
;          LOAD GO
;          LOAD S19
;          LOAD GO S19
; ----------------------------------------------------------------------------
MON_LOAD_VALIDATE_ARGS:
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_VALIDATE_OK_NEAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'G'
                        BEQ             MON_LOAD_VALIDATE_AUTOGO_WORD
                        BRA             MON_LOAD_VALIDATE_FMT_START

MON_LOAD_VALIDATE_AUTOGO_WORD:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'O'
                        BNE             MON_LOAD_VALIDATE_FAIL_NEAR
                        JSR             CMDP_ADV_PTR
                        LDA             #$01
                        STA             LOAD_AUTO_GO
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_VALIDATE_OK_NEAR

MON_LOAD_VALIDATE_FMT_START:
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'S'
                        BNE             MON_LOAD_VALIDATE_FAIL
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'1'
                        BEQ             MON_LOAD_VALIDATE_19
                        BNE             MON_LOAD_VALIDATE_FAIL_NEAR

MON_LOAD_VALIDATE_OK_NEAR:
                        JMP             MON_LOAD_VALIDATE_OK
MON_LOAD_VALIDATE_FAIL_NEAR:
                        JMP             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_19:
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        CMP             #'9'
                        BNE             MON_LOAD_VALIDATE_FAIL
                        JSR             CMDP_ADV_PTR
                        BRA             MON_LOAD_VALIDATE_NEED_EOL

MON_LOAD_VALIDATE_NEED_EOL:
                        JSR             CMDP_REQUIRE_EOL
                        BCC             MON_LOAD_VALIDATE_FAIL

MON_LOAD_VALIDATE_OK:
                        SEC
                        RTS

MON_LOAD_VALIDATE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_INIT  [HASH:332B45E1]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Reset LOAD session counters and state.
; ----------------------------------------------------------------------------
MON_LOAD_INIT:
                        STZ             LOAD_LINE_STATUS
                        STZ             LOAD_REC_TYPE
                        STZ             LOAD_REC_KIND
                        STZ             LOAD_ADDR_LEN
                        STZ             LOAD_COUNT
                        STZ             LOAD_DATA_LEN
                        STZ             LOAD_SUM
                        STZ             LOAD_CHK
                        STZ             LOAD_DST_LO
                        STZ             LOAD_DST_HI
                        STZ             LOAD_GO_LO
                        STZ             LOAD_GO_HI
                        STZ             LOAD_GO_VALID
                        STZ             LOAD_TOTAL_LO
                        STZ             LOAD_TOTAL_HI
                        STZ             LOAD_REC_LO
                        STZ             LOAD_REC_HI
                        STZ             LOAD_HAVE_DATA
                        STZ             LOAD_FIRST_LO
                        STZ             LOAD_FIRST_HI
                        STZ             LOAD_LAST_LO
                        STZ             LOAD_LAST_HI
                        STZ             LOAD_CUR_START_LO
                        STZ             LOAD_CUR_START_HI
                        STZ             LOAD_CUR_END_LO
                        STZ             LOAD_CUR_END_HI
                        STZ             LOAD_RANGE_COUNT
                        STZ             LOAD_RANGE_OVF
                        STZ             LOAD_TMP_LO
                        STZ             LOAD_TMP_HI
                        STZ             LOAD_LEN_LO
                        STZ             LOAD_LEN_HI
                        STZ             LOAD_SPAN_LO
                        STZ             LOAD_SPAN_HI
                        STZ             LOAD_PRINT_COUNT
                        STZ             LOAD_CUR_VALID
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_READ_LINE  [HASH:A972A54E]
; TIER: APP-L5
; TAGS: MON, APP-L5, READ, SREC, CARRY-STATUS, NOSTACK
; PURPOSE: Read one incoming S-record text line into LOAD_BUF.
; OUT: C=1 success, C=0 with LOAD_LINE_STATUS set.
; ----------------------------------------------------------------------------
MON_LOAD_READ_LINE:
                        LDX             #<LOAD_BUF
                        LDY             #>LOAD_BUF
                        JSR             SYS_READ_CSTRING_SILENT_UPPER
                        BCS             MON_LOAD_READ_LINE_OK
                        STA             LOAD_LINE_STATUS
                        CLC
                        RTS
MON_LOAD_READ_LINE_OK:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PARSE_RECORD  [HASH:7B85C4C6]
; TIER: APP-L5
; TAGS: MON, APP-L5, UPPERCASE, SREC, PARSE, STACK
; PURPOSE: Parse one S19 line (S1 data, S9 termination).
; NOTES:
;   - S0/S5 are accepted as non-data records and skipped.
; OUT:
;   - C=1 parse OK.
;   - LOAD_REC_KIND = DATA / TERM / SKIP.
;   - LOAD_DST_HI:LOAD_DST_LO = resolved 16-bit address for DATA/TERM.
; ----------------------------------------------------------------------------
MON_LOAD_PARSE_RECORD:
                        JMP             MON_LOAD_PARSE_BEGIN
MON_LOAD_PARSE_BLANK_NEAR:
                        JMP             MON_LOAD_PARSE_BLANK
MON_LOAD_PARSE_FAIL_NEAR:
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_BEGIN:
                        STZ             LOAD_REC_TYPE
                        STZ             LOAD_REC_KIND
                        STZ             LOAD_ADDR_LEN
                        STZ             LOAD_COUNT
                        STZ             LOAD_DATA_LEN
                        STZ             LOAD_SUM
                        STZ             LOAD_CHK
                        STZ             LOAD_ADDR_B0
                        STZ             LOAD_ADDR_B1
                        STZ             LOAD_ADDR_B2
                        STZ             LOAD_ADDR_B3

                        LDX             #<LOAD_BUF
                        LDY             #>LOAD_BUF
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_PARSE_BLANK_NEAR
                        JSR             CMDP_TO_UPPER_A
                        CMP             #'S'
                        BNE             MON_LOAD_PARSE_FAIL_NEAR
                        JSR             CMDP_ADV_PTR
                        JSR             CMDP_PEEK_CHAR
                        JSR             CMDP_TO_UPPER_A
                        STA             LOAD_REC_TYPE
                        JSR             CMDP_ADV_PTR
                        JSR             MON_LOAD_CLASSIFY_TYPE
                        BCC             MON_LOAD_PARSE_FAIL_NEAR

                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        STA             LOAD_COUNT
                        STA             LOAD_SUM

                        LDA             LOAD_COUNT
                        SEC
                        SBC             LOAD_ADDR_LEN
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        SEC
                        SBC             #$01
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        STA             LOAD_DATA_LEN
                        CMP             #$41
                        BCS             MON_LOAD_PARSE_FAIL_NEAR

                        LDX             #$00
MON_LOAD_PARSE_ADDR_LOOP:
                        CPX             LOAD_ADDR_LEN
                        BEQ             MON_LOAD_PARSE_ADDR_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCC             MON_LOAD_PARSE_FAIL_NEAR
                        PHA
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        PLA
                        STA             LOAD_ADDR_B0,X
                        INX
                        BRA             MON_LOAD_PARSE_ADDR_LOOP
MON_LOAD_PARSE_ADDR_DONE:

                        LDX             #$00
MON_LOAD_PARSE_DATA_LOOP:
                        CPX             LOAD_DATA_LEN
                        BEQ             MON_LOAD_PARSE_DATA_DONE
                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCS             MON_LOAD_PARSE_DATA_HAVE_BYTE
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_DATA_HAVE_BYTE:
                        PHA
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        PLA
                        STA             LOAD_DATA_BUF,X
                        INX
                        BRA             MON_LOAD_PARSE_DATA_LOOP
MON_LOAD_PARSE_DATA_DONE:

                        JSR             CMDP_PARSE_HEX_BYTE_ADV
                        BCS             MON_LOAD_PARSE_HAVE_CHK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_HAVE_CHK:
                        STA             LOAD_CHK
                        CLC
                        ADC             LOAD_SUM
                        CMP             #$FF
                        BEQ             MON_LOAD_PARSE_CHK_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_CHK_OK:

                        JSR             CMDP_SKIP_SPACES
                        JSR             CMDP_PEEK_CHAR
                        BEQ             MON_LOAD_PARSE_TAIL_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_TAIL_OK:

                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_SKIP
                        BEQ             MON_LOAD_PARSE_OK
                        JSR             MON_LOAD_RESOLVE_ADDR16
                        BCS             MON_LOAD_PARSE_OK
                        JMP             MON_LOAD_PARSE_FAIL
MON_LOAD_PARSE_OK:
                        SEC
                        RTS

MON_LOAD_PARSE_BLANK:
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

MON_LOAD_PARSE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CLASSIFY_TYPE  [HASH:8798DE9A]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Map S-record type to DATA/TERM/SKIP and expected address length.
; ----------------------------------------------------------------------------
MON_LOAD_CLASSIFY_TYPE:
                        LDA             LOAD_REC_TYPE
                        CMP             #'1'
                        BNE             MON_LOAD_CLASSIFY_NO_S1
                        LDA             #LOAD_REC_KIND_DATA
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S1:
                        CMP             #'9'
                        BNE             MON_LOAD_CLASSIFY_NO_S9
                        LDA             #LOAD_REC_KIND_TERM
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S9:
                        CMP             #'0'
                        BNE             MON_LOAD_CLASSIFY_NO_S0
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S0:
                        CMP             #'5'
                        BNE             MON_LOAD_CLASSIFY_NO_S5
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        LDA             #$02
                        STA             LOAD_ADDR_LEN
                        SEC
                        RTS
MON_LOAD_CLASSIFY_NO_S5:
                        CLC
                        RTS
MON_LOAD_CLASSIFY_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_RESOLVE_ADDR16  [HASH:91C2A55A]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Resolve parsed record address into 16-bit target address.
; RULES:
;   - S1/S9: direct 16-bit.
;   - S2/S8: top byte must be 00.
;   - S3/S7: top two bytes must be 00.
; ----------------------------------------------------------------------------
MON_LOAD_RESOLVE_ADDR16:
                        LDA             LOAD_ADDR_LEN
                        CMP             #$02
                        BEQ             MON_LOAD_RESOLVE_16
                        CMP             #$03
                        BEQ             MON_LOAD_RESOLVE_24
                        CMP             #$04
                        BEQ             MON_LOAD_RESOLVE_32
                        CLC
                        RTS

MON_LOAD_RESOLVE_16:
                        LDA             LOAD_ADDR_B0
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B1
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_24:
                        LDA             LOAD_ADDR_B0
                        BNE             MON_LOAD_RESOLVE_FAIL
                        LDA             LOAD_ADDR_B1
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B2
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_32:
                        LDA             LOAD_ADDR_B0
                        ORA             LOAD_ADDR_B1
                        BNE             MON_LOAD_RESOLVE_FAIL
                        LDA             LOAD_ADDR_B2
                        STA             LOAD_DST_HI
                        LDA             LOAD_ADDR_B3
                        STA             LOAD_DST_LO
                        SEC
                        RTS

MON_LOAD_RESOLVE_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_WRITE_RECORD_DATA  [HASH:DFDFAB13]
; TIER: APP-L5
; TAGS: MON, APP-L5, WRITE, NOSTACK
; PURPOSE: Write parsed record payload bytes to LOAD_DST address.
; ----------------------------------------------------------------------------
MON_LOAD_WRITE_RECORD_DATA:
                        LDA             LOAD_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             CMDP_ADDR_HI
                        LDX             #$00
MON_LOAD_WRITE_LOOP:
                        CPX             LOAD_DATA_LEN
                        BEQ             MON_LOAD_WRITE_DONE
                        LDA             LOAD_DATA_BUF,X
                        LDY             #$00
                        STA             (CMDP_ADDR_LO),Y
                        JSR             CMDP_INC_ADDR
                        INX
                        BRA             MON_LOAD_WRITE_LOOP
MON_LOAD_WRITE_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_ACCUM_RECORD_ONLY / MON_LOAD_ACCUM_RECORD_AND_BYTES  [HASH:225FF9B1]
; TIER: APP-L5
; ALIAS_HASH: MON_LOAD_ACCUM_RECORD_AND_BYTES  [HASH:05A2B3E4]
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Maintain LOAD session counters.
; ----------------------------------------------------------------------------
MON_LOAD_ACCUM_RECORD_ONLY:
                        INC             LOAD_REC_LO
                        BNE             MON_LOAD_ACC_REC_DONE
                        INC             LOAD_REC_HI
MON_LOAD_ACC_REC_DONE:
                        RTS

MON_LOAD_ACCUM_RECORD_AND_BYTES:
                        JSR             MON_LOAD_ACCUM_RECORD_ONLY
                        CLC
                        LDA             LOAD_TOTAL_LO
                        ADC             LOAD_DATA_LEN
                        STA             LOAD_TOTAL_LO
                        LDA             LOAD_TOTAL_HI
                        ADC             #$00
                        STA             LOAD_TOTAL_HI
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_TRACK_DATA_RANGE  [HASH:2631A379]
; TIER: APP-L5
; TAGS: MON, APP-L5, NOSTACK
; PURPOSE: Track overall span and contiguous ranges for DATA records.
; ----------------------------------------------------------------------------
MON_LOAD_TRACK_DATA_RANGE:
                        LDA             LOAD_DATA_LEN
                        BNE             MON_LOAD_TRACK_HAVE_LEN
MON_LOAD_TRACK_EMPTY:
                        SEC
                        RTS

MON_LOAD_TRACK_HAVE_LEN:

                        ; tmp = record_end = LOAD_DST + LOAD_DATA_LEN - 1
                        CLC
                        LDA             LOAD_DST_LO
                        ADC             LOAD_DATA_LEN
                        STA             LOAD_TMP_LO
                        LDA             LOAD_DST_HI
                        ADC             #$00
                        STA             LOAD_TMP_HI
                        SEC
                        LDA             LOAD_TMP_LO
                        SBC             #$01
                        STA             LOAD_TMP_LO
                        LDA             LOAD_TMP_HI
                        SBC             #$00
                        STA             LOAD_TMP_HI

                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_TRACK_HAVE_DATA

                        ; First DATA record initializes all range state.
                        LDA             #$01
                        STA             LOAD_HAVE_DATA
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_LAST_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_LAST_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_HAVE_DATA:
                        ; first = min(first, current_record_start)
                        LDA             LOAD_DST_HI
                        CMP             LOAD_FIRST_HI
                        BCC             MON_LOAD_TRACK_SET_FIRST
                        BNE             MON_LOAD_TRACK_CHECK_LAST
                        LDA             LOAD_DST_LO
                        CMP             LOAD_FIRST_LO
                        BCC             MON_LOAD_TRACK_SET_FIRST
                        BRA             MON_LOAD_TRACK_CHECK_LAST

MON_LOAD_TRACK_SET_FIRST:
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI

MON_LOAD_TRACK_CHECK_LAST:
                        ; last = max(last, current_record_end)
                        LDA             LOAD_TMP_HI
                        CMP             LOAD_LAST_HI
                        BCC             MON_LOAD_TRACK_CHECK_CUR
                        BNE             MON_LOAD_TRACK_SET_LAST
                        LDA             LOAD_TMP_LO
                        CMP             LOAD_LAST_LO
                        BCC             MON_LOAD_TRACK_CHECK_CUR
                        BEQ             MON_LOAD_TRACK_CHECK_CUR

MON_LOAD_TRACK_SET_LAST:
                        LDA             LOAD_TMP_LO
                        STA             LOAD_LAST_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_LAST_HI

MON_LOAD_TRACK_CHECK_CUR:
                        LDA             LOAD_CUR_VALID
                        BNE             MON_LOAD_TRACK_GAP_CHECK
                        LDA             #$01
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_GAP_CHECK:
                        ; If start > (current_end + 1), commit current range
                        ;   and start new.
                        CLC
                        LDA             LOAD_CUR_END_LO
                        ADC             #$01
                        STA             LOAD_SPAN_LO
                        LDA             LOAD_CUR_END_HI
                        ADC             #$00
                        STA             LOAD_SPAN_HI

                        LDA             LOAD_DST_HI
                        CMP             LOAD_SPAN_HI
                        BCC             MON_LOAD_TRACK_SAME_RANGE
                        BNE             MON_LOAD_TRACK_NEW_RANGE
                        LDA             LOAD_DST_LO
                        CMP             LOAD_SPAN_LO
                        BCC             MON_LOAD_TRACK_SAME_RANGE
                        BEQ             MON_LOAD_TRACK_SAME_RANGE

MON_LOAD_TRACK_NEW_RANGE:
                        JSR             MON_LOAD_COMMIT_CURRENT_RANGE
                        LDA             #$01
                        STA             LOAD_CUR_VALID
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI
                        SEC
                        RTS

MON_LOAD_TRACK_SAME_RANGE:
                        ; Keep current start as the minimum.
                        LDA             LOAD_DST_HI
                        CMP             LOAD_CUR_START_HI
                        BCC             MON_LOAD_TRACK_SET_CUR_START
                        BNE             MON_LOAD_TRACK_CHECK_CUR_END
                        LDA             LOAD_DST_LO
                        CMP             LOAD_CUR_START_LO
                        BCC             MON_LOAD_TRACK_SET_CUR_START
                        BRA             MON_LOAD_TRACK_CHECK_CUR_END

MON_LOAD_TRACK_SET_CUR_START:
                        LDA             LOAD_DST_LO
                        STA             LOAD_CUR_START_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_CUR_START_HI

MON_LOAD_TRACK_CHECK_CUR_END:
                        ; Keep current end as the maximum.
                        LDA             LOAD_TMP_HI
                        CMP             LOAD_CUR_END_HI
                        BCC             MON_LOAD_TRACK_DONE
                        BNE             MON_LOAD_TRACK_SET_CUR_END
                        LDA             LOAD_TMP_LO
                        CMP             LOAD_CUR_END_LO
                        BCC             MON_LOAD_TRACK_DONE
                        BEQ             MON_LOAD_TRACK_DONE

MON_LOAD_TRACK_SET_CUR_END:
                        LDA             LOAD_TMP_LO
                        STA             LOAD_CUR_END_LO
                        LDA             LOAD_TMP_HI
                        STA             LOAD_CUR_END_HI

MON_LOAD_TRACK_DONE:
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_COMMIT_CURRENT_RANGE  [HASH:FF655A96]
; TIER: APP-L5
; TAGS: MON, APP-L5, NOSTACK
; PURPOSE: Commit current open range into range list.
; ----------------------------------------------------------------------------
MON_LOAD_COMMIT_CURRENT_RANGE:
                        LDA             LOAD_CUR_VALID
                        BNE             MON_LOAD_COMMIT_HAVE_RANGE
                        SEC
                        RTS

MON_LOAD_COMMIT_HAVE_RANGE:
                        LDA             LOAD_RANGE_COUNT
                        CMP             #LOAD_RANGE_MAX
                        BCS             MON_LOAD_COMMIT_OVF
                        ASL             A
                        ASL             A
                        TAX
                        LDA             LOAD_CUR_START_HI
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_START_LO
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_END_HI
                        STA             LOAD_RANGE_BASE,X
                        INX
                        LDA             LOAD_CUR_END_LO
                        STA             LOAD_RANGE_BASE,X
                        BRA             MON_LOAD_COMMIT_COUNT

MON_LOAD_COMMIT_OVF:
                        LDA             #$01
                        STA             LOAD_RANGE_OVF

MON_LOAD_COMMIT_COUNT:
                        INC             LOAD_RANGE_COUNT
                        STZ             LOAD_CUR_VALID
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_FINALIZE_RANGES  [HASH:B78F3D28]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, NOSTACK
; PURPOSE: Close the last open range at end-of-load.
; ----------------------------------------------------------------------------
MON_LOAD_FINALIZE_RANGES:
                        JSR             MON_LOAD_COMMIT_CURRENT_RANGE
                        SEC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_CAPTURE_GO  [HASH:3AD528DE]
; TIER: APP-L5
; TAGS: MON, APP-L5, SREC, NOSTACK
; PURPOSE: Capture entry address from S7/S8/S9 termination record.
; ----------------------------------------------------------------------------
MON_LOAD_CAPTURE_GO:
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_TERM
                        BNE             MON_LOAD_CAPTURE_GO_FAIL
                        LDA             LOAD_DATA_LEN
                        BNE             MON_LOAD_CAPTURE_GO_FAIL
                        LDA             LOAD_DST_LO
                        STA             LOAD_GO_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_GO_HI
                        LDA             #$01
                        STA             LOAD_GO_VALID
                        SEC
                        RTS
MON_LOAD_CAPTURE_GO_FAIL:
                        CLC
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_ONE_RANGE  [HASH:727B9D47]
; TIER: APP-L5
; TAGS: MON, APP-L5, STACK
; PURPOSE: Print one committed range line. IN: X = 0-based range index.
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_ONE_RANGE:
                        LDA             #'R'
                        JSR             SYS_WRITE_CHAR
                        TXA
                        CLC
                        ADC             #$01
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        PHX
                        TXA
                        ASL             A
                        ASL             A
                        TAY

                        LDA             LOAD_RANGE_BASE,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_RANGE_BASE+1,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #'-'
                        JSR             SYS_WRITE_CHAR
                        LDA             LOAD_RANGE_BASE+2,Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_RANGE_BASE+3,Y
                        JSR             SYS_WRITE_HEX_BYTE

                        SEC
                        LDA             LOAD_RANGE_BASE+3,Y
                        SBC             LOAD_RANGE_BASE+1,Y
                        STA             LOAD_LEN_LO
                        LDA             LOAD_RANGE_BASE+2,Y
                        SBC             LOAD_RANGE_BASE,Y
                        STA             LOAD_LEN_HI
                        CLC
                        LDA             LOAD_LEN_LO
                        ADC             #$01
                        STA             LOAD_LEN_LO
                        LDA             LOAD_LEN_HI
                        ADC             #$00
                        STA             LOAD_LEN_HI
                        PLX

                        LDX             #<MSG_LOAD_DONE_LEN
                        LDY             #>MSG_LOAD_DONE_LEN
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_LEN_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_LEN_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        RTS


; ----------------------------------------------------------------------------
; ROUTINE: MON_LOAD_PRINT_SUMMARY  [HASH:4D58AF3D]
; TIER: APP-L5
; TAGS: MON, APP-L5, LOAD, STACK
; PURPOSE: Print one end-of-load summary (counters, ranges, GO).
; ----------------------------------------------------------------------------
MON_LOAD_PRINT_SUMMARY:
                        LDX             #<MSG_LOAD_SUM_OK_START
                        LDY             #>MSG_LOAD_SUM_OK_START
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_SUMMARY_START_VALUE
                        LDX             #<MSG_LOAD_ADDR_UNKNOWN
                        LDY             #>MSG_LOAD_ADDR_UNKNOWN
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_END_LABEL
MON_LOAD_SUMMARY_START_VALUE:
                        LDA             LOAD_FIRST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_FIRST_LO
                        JSR             SYS_WRITE_HEX_BYTE

MON_LOAD_SUMMARY_END_LABEL:
                        LDX             #<MSG_LOAD_SUM_END
                        LDY             #>MSG_LOAD_SUM_END
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_HAVE_DATA
                        BNE             MON_LOAD_SUMMARY_END_VALUE
                        LDX             #<MSG_LOAD_ADDR_UNKNOWN
                        LDY             #>MSG_LOAD_ADDR_UNKNOWN
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_BYTES_LABEL
MON_LOAD_SUMMARY_END_VALUE:
                        LDA             LOAD_LAST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_LAST_LO
                        JSR             SYS_WRITE_HEX_BYTE

MON_LOAD_SUMMARY_BYTES_LABEL:
                        LDX             #<MSG_LOAD_SUM_BYTES
                        LDY             #>MSG_LOAD_SUM_BYTES
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_TOTAL_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_TOTAL_LO
                        JSR             SYS_WRITE_HEX_BYTE

                        LDX             #<MSG_LOAD_SUM_GO
                        LDY             #>MSG_LOAD_SUM_GO
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_GO_VALID
                        BNE             MON_LOAD_SUMMARY_GO_VALUE
                        LDX             #<MSG_LOAD_NO_GO
                        LDY             #>MSG_LOAD_NO_GO
                        JSR             SYS_WRITE_HBSTRING
                        BRA             MON_LOAD_SUMMARY_REC_LABEL
MON_LOAD_SUMMARY_GO_VALUE:
                        LDA             LOAD_GO_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             MON_LOAD_SUMMARY_REC_LABEL
                        LDX             #<MSG_LOAD_SUM_IGNORED
                        LDY             #>MSG_LOAD_SUM_IGNORED
                        JSR             SYS_WRITE_HBSTRING

MON_LOAD_SUMMARY_REC_LABEL:
                        LDX             #<MSG_LOAD_SUM_REC
                        LDY             #>MSG_LOAD_SUM_REC
                        JSR             SYS_WRITE_HBSTRING
                        LDA             LOAD_REC_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_REC_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDA             LOAD_RANGE_COUNT
                        CMP             #$02
                        BCS             MON_LOAD_SUMMARY_RANGES
                        LDA             LOAD_RANGE_OVF
                        BEQ             MON_LOAD_SUMMARY_DONE

MON_LOAD_SUMMARY_RANGES:
                        LDX             #<MSG_LOAD_RANGE_HDR
                        LDY             #>MSG_LOAD_RANGE_HDR
                        JSR             SYS_WRITE_HBLINE

                        LDA             LOAD_RANGE_COUNT
                        CMP             #LOAD_RANGE_MAX
                        BCC             MON_LOAD_SUMMARY_RANGE_COUNT_OK
                        LDA             #LOAD_RANGE_MAX
MON_LOAD_SUMMARY_RANGE_COUNT_OK:
                        STA             LOAD_PRINT_COUNT

                        LDX             #$00
MON_LOAD_SUMMARY_RANGE_LOOP:
                        CPX             LOAD_PRINT_COUNT
                        BEQ             MON_LOAD_SUMMARY_RANGE_DONE
                        JSR             MON_LOAD_PRINT_ONE_RANGE
                        INX
                        BRA             MON_LOAD_SUMMARY_RANGE_LOOP

MON_LOAD_SUMMARY_RANGE_DONE:
                        LDA             LOAD_RANGE_OVF
                        BEQ             MON_LOAD_SUMMARY_DONE
                        LDX             #<MSG_LOAD_RANGE_OVF
                        LDY             #>MSG_LOAD_RANGE_OVF
                        JSR             SYS_WRITE_HBLINE

MON_LOAD_SUMMARY_DONE:
                        RTS




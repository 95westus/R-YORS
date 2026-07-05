; ----------------------------------------------------------------------------
; himon.asm
; Compact supervisory debug monitor for W65C02S with FNV-1a command dispatch.
; Memory map target:
;   RAM   $0000-$7EFF (SYS_RAM_END; UPA $2000-$79FF, MON $7A00-$7EFF)
;   IO    $7F00-$7FFF (SYS_IO_BASE-SYS_IO_END)
;   FLASH $8000-$FFFF
; ----------------------------------------------------------------------------

                        MODULE          HIMON_APP

                        XDEF            START
                        XDEF            THE_JOIN_FIND
                        XDEF            THE_JOIN_EXEC
                        XDEF            THE_JOIN_EXEC_XY
                        XDEF            THE_JOIN_EXEC_XY_FNV
                        XDEF            THE_JOIN_LOAD_HASH_XY
                        XDEF            FNV1A_INIT_FNV
                        XDEF            FNV1A_UPDATE_A_FAST_FNV
                        XDEF            SYS_READ_CSTRING_ECHO_UPPER_FNV
                        XDEF            BIO_FTDI_PUT_CSTR_FNV
                        XDEF            SYS_PRINT_IO_SLOT_SKIP

                        XREF            BIO_FTDI_READ_BYTE_BLOCK
                        XREF            BIO_FTDI_WRITE_BYTE_BLOCK
                        XREF            SYS_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_VEC_ENTRY_NMI
                        XREF            SYS_VEC_ENTRY_IRQ_MASTER
                        XREF            SYS_VEC_DEFAULT_RESET
                        XREF            SYS_VEC_SET_NMI_XY
                        XREF            SYS_VEC_SET_IRQ_BRK_XY
                        XREF            SYS_VEC_SET_IRQ_NONBRK_XY
                        XREF            BIO_FTDI_READ_BYTE_NONBLOCK
                        XREF            FLASH_WRITE_BYTE_AXY
                        XREF            SYS_READ_CHAR
                        XREF            SYS_READ_CHAR_ECHO
                        XREF            SYS_READ_CHAR_COOKED_ECHO
                        XREF            SYS_GET_CTRL_C
                        XREF            UTL_HEX_ASCII_TO_NIBBLE

                        INCLUDE         "HIMON/himon-shared-eq.inc"

TRAP_CAUSE               EQU             $7EEA
TRAP_BRK_SIG             EQU             $7EEB
NMI_DEBOUNCE_FLAG        EQU             $7EEC
TRAP_CAUSE_NONE          EQU             $00
TRAP_CAUSE_NMI           EQU             $01
TRAP_CAUSE_BRK           EQU             $02
TRAP_CAUSE_DBG           EQU             $03
NMI_DEBOUNCE_A           EQU             $02
NMI_DEBOUNCE_X           EQU             $B6
NMI_DEBOUNCE_Y           EQU             $F8

CMD_HASH_TAB_LO          EQU             $E0
CMD_HASH_TAB_HI          EQU             $E1
FNV_HASH0                EQU             $B0
FNV_HASH1                EQU             $B1
FNV_HASH2                EQU             $B2
FNV_HASH3                EQU             $B3
FNV_TERM0                EQU             $C7
FNV_TERM1                EQU             $C8
FNV_TERM2                EQU             $C9
FNV_TERM3                EQU             $CA
CMD_HASH_EXTRA_LO        EQU             $7E66
CMD_HASH_EXTRA_HI        EQU             $7E67
CMD_HASH_FILTER_VALUE    EQU             $7E68
CMD_HASH_FILTER_OP       EQU             $7E69
CMD_EXEC_HASH0           EQU             $7E6E
CMD_EXEC_HASH1           EQU             $7E6F
CMD_EXEC_HASH2           EQU             $7E70
CMD_EXEC_HASH3           EQU             $7E71
CMD_EXEC_ENTRY_LO        EQU             $7E72
CMD_EXEC_ENTRY_HI        EQU             $7E73
CMD_EXEC_KIND            EQU             $7E74
BOOT_REASON              EQU             $7E75
CMD_EXEC_KIND_HASH       EQU             $00
CMD_EXEC_KIND_GO         EQU             $01
CMD_EXEC_KIND_LOADGO     EQU             $02
BOOT_REASON_NONE         EQU             $00
BOOT_REASON_COLD         EQU             $01
BOOT_REASON_WARM         EQU             $02

CMD_FLAG_TOP_INPUT       EQU             $01
CMD_ABORT_TOP            EQU             $04
; Current FNV record format:
;   'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,payload...
;   kind bit 0: executable.
;   kind bit 1: confirm before execution.
;   kind bit 2: text/metadata pointer is present.
;   kind=$01: executable code begins immediately after the kind byte.
;   kind=$03: legacy DW ENTRY, DW EXTRA, confirm before execution.
;   kind=$05: DW ENTRY, DW EXTRA, display text without confirmation.
CMD_FNV_SIG2             EQU             ('V'+$80)
CMD_HASH_KIND_EXEC       EQU             $01
CMD_HASH_KIND_CONFIRM    EQU             $02
CMD_HASH_KIND_TEXT       EQU             $04
CMD_HASH_KIND_EXEC_CONFIRM_TEXT EQU      (CMD_HASH_KIND_EXEC+CMD_HASH_KIND_CONFIRM)
CMD_HASH_KIND_EXEC_TEXT  EQU             (CMD_HASH_KIND_EXEC+CMD_HASH_KIND_TEXT)
CMD_HASH_SCAN_BASE_HI    EQU             $80
SEARCH_LINE_LO           EQU             $B4
SEARCH_LINE_HI           EQU             $B5
SEARCH_WORD_LO           EQU             $B6
SEARCH_WORD_HI           EQU             $B7
SEARCH_START_LO          EQU             $B8
SEARCH_START_HI          EQU             $B9
SEARCH_END_LO            EQU             $BA
SEARCH_END_HI            EQU             $BB
SEARCH_SCAN_LO           EQU             $BC
SEARCH_SCAN_HI           EQU             $BD
SEARCH_MATCH_LO          EQU             $BE
SEARCH_MATCH_HI          EQU             $BF
SEARCH_ROW_LO            EQU             $C0
SEARCH_ROW_HI            EQU             $C1
SEARCH_TMP               EQU             $C2
SEARCH_DIGITS            EQU             $C3
SEARCH_PAT_LEN           EQU             $C4
SEARCH_COUNT             EQU             $C5
SEARCH_HIT_FLAG          EQU             $C6
SEARCH_PAT_BUF           EQU             $7DC0
SEARCH_PAT_MAX           EQU             $40
QUOTE_HASH_TARGET0       EQU             $7A
QUOTE_HASH_TARGET1       EQU             $0F
QUOTE_HASH_TARGET2       EQU             $6A
QUOTE_HASH_TARGET3       EQU             $5F

                        CODE
START:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        LDA             RESET_SIG0
                        CMP             #$A5
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG1
                        CMP             #$5A
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG2
                        CMP             #$C3
                        BNE             MON_COLD_RESET
                        LDA             RESET_SIG3
                        CMP             #$3C
                        BNE             MON_COLD_RESET
                        JMP             BOOT_RESET_WARM_BODY

BOOT_COLD_RESET_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$F0,$30,$7A,$EC,CMD_HASH_KIND_EXEC_CONFIRM_TEXT ; BOOT_COLD_RESET $EC7A30F0 EXEC+CONFIRM
                        DW              BOOT_RESET_COLD
                        DW              TXT_BOOT_COLD_RESET
BOOT_RESET_COLD:
MON_COLD_RESET:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        JMP             MON_CLEAR_RAM

BOOT_WARM_RESET_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$AB,$AE,$33,$53,CMD_HASH_KIND_EXEC_CONFIRM_TEXT ; BOOT_WARM_RESET $5333AEAB EXEC+CONFIRM
                        DW              BOOT_RESET_WARM
                        DW              TXT_BOOT_WARM_RESET
BOOT_RESET_WARM:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
BOOT_RESET_WARM_BODY:
                        LDA             #BOOT_REASON_WARM
                        STA             BOOT_REASON
                        JSR             DBG_CLEAR_ALL
                        STZ             NMI_CTX_FLAG
                        STZ             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        STZ             NMI_DEBOUNCE_FLAG
                        JMP             MON_START_INIT

MON_REENTER:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        JSR             MON_INIT_COMMON
                        JMP             MON_AFTER_BANNER

MON_INIT_COMMON:
                        LDA             #$A5
                        STA             RESET_SIG0
                        LDA             #$5A
                        STA             RESET_SIG1
                        LDA             #$C3
                        STA             RESET_SIG2
                        LDA             #$3C
                        STA             RESET_SIG3
                        JSR             MON_INIT_SERVICE_VECTORS
                        JSR             SYS_INIT
                        JSR             SYS_FLUSH_RX

                        LDX             #<MON_NMI_TRAP_DEBOUNCE
                        LDY             #>MON_NMI_TRAP_DEBOUNCE
                        JSR             SYS_VEC_SET_NMI_XY
                        LDX             #<MON_BRK_TRAP
                        LDY             #>MON_BRK_TRAP
                        JSR             SYS_VEC_SET_IRQ_BRK_XY
                        LDX             #<MON_IRQ_TRAP
                        LDY             #>MON_IRQ_TRAP
                        JSR             SYS_VEC_SET_IRQ_NONBRK_XY
                        RTS

MON_INIT_SERVICE_VECTORS:
                        LDX             #HIM_SVC_BOOT_TABLE_END-HIM_SVC_BOOT_TABLE-1
MON_INIT_SERVICE_VECTORS_LOOP:
                        LDA             HIM_SVC_BOOT_TABLE,X
                        STA             RJOIN_EXEC_XY_LO,X
                        DEX
                        BPL             MON_INIT_SERVICE_VECTORS_LOOP
                        LDA             #$00
                        LDX             #HIM_SVC_CHECKSUM-HIM_SVC_SIG0-1
MON_INIT_SERVICE_CHECKSUM_LOOP:
                        EOR             HIM_SVC_SIG0,X
                        DEX
                        BPL             MON_INIT_SERVICE_CHECKSUM_LOOP
                        STA             HIM_SVC_CHECKSUM
                        RTS

HIM_SVC_BOOT_TABLE:
                        DB              <THE_JOIN_EXEC_XY,>THE_JOIN_EXEC_XY
                        DB              HIM_SVC_SIG0_VAL,HIM_SVC_SIG1_VAL
                        DB              HIM_SVC_VERSION_1,HIM_SVC_VECTOR_COUNT
                        DW              THE_JOIN_EXEC_XY
                        DW              BIO_FTDI_WRITE_BYTE_BLOCK
                        DW              SYS_WRITE_CSTRING
                        DW              SYS_WRITE_HEX_BYTE
                        DW              SYS_WRITE_CRLF
                        DW              HIM_READ_LINE_ECHO_UPPER
                        DW              UTL_HEX_ASCII_TO_NIBBLE
                        DW              FNV1A_INIT
                        DW              FNV1A_UPDATE_A_FAST
                        DW              HIM_CHAR_TO_UPPER
                        DW              HIM_WRITE_HBSTRING
HIM_SVC_BOOT_TABLE_END:

MON_START_INIT:
                        JSR             MON_INIT_COMMON
                        JSR             MON_BOOTLOG_RESET

                        LDX             #<MSG_BANNER
                        LDY             #>MSG_BANNER
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF

MON_AFTER_BANNER:
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BNE             MAIN_LOOP
                        JSR             MON_PRINT_STOP_AND_REGS

MAIN_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             HIM_WRITE_HBSTRING

                        LDA             #CMD_FLAG_TOP_INPUT
                        STA             CMD_FLAGS
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_ECHO_UPPER
                        STZ             CMD_FLAGS
                        BCS             MAIN_HAVE_LINE
                        CMP             #CMD_ABORT_TOP
                        BNE             MAIN_LOOP
                        BRK             $03
                        JMP             MAIN_LOOP

MAIN_HAVE_LINE:
                        STA             CMD_LEN
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MAIN_LOOP
                        JSR             CMD_HASH_TOKEN
                        JMP             CMD_DISPATCH_HASH

CMD_UNKNOWN:
                        LDX             #<MSG_UNKNOWN
                        LDY             #>MSG_UNKNOWN
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

CMD_HELP_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$8E,$B0,$0C,$3A,CMD_HASH_KIND_EXEC ; ? $3A0CB08E EXEC
CMD_HELP:
                        LDX             #<MSG_HELP
                        LDY             #>MSG_HELP
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; # [token] -- list/resolve FNV records without executing them.
; ----------------------------------------------------------------------------
CMD_HASH_INFO_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$12,$91,$0C,$26,CMD_HASH_KIND_EXEC ; # $260C9112 EXEC
CMD_HASH_INFO:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        LDA             CMDP_PTR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_START_HI
                        JSR             CMD_PEEK
                        BEQ             CMD_HASH_LIST
                        CMP             #'K'
                        BEQ             CMD_HASH_INFO_K_FILTER
CMD_HASH_INFO_LOOKUP:
                        JSR             CMD_HASH_TOKEN
                        JSR             CMD_HASH_PRINT_FNV
                        JSR             THE_JOIN_FIND
                        BCS             CMD_HASH_INFO_FOUND
                        LDX             #<MSG_HASH_NF
                        LDY             #>MSG_HASH_NF
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_PRINT_TOKEN
                        JSR             SYS_WRITE_CRLF
                        RTS
CMD_HASH_INFO_FOUND:
                        LDX             #<MSG_HASH_ENTRY
                        LDY             #>MSG_HASH_ENTRY
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_PRINT_ENTRY
                        LDX             #<MSG_HASH_K
                        LDY             #>MSG_HASH_K
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_PRINT_KIND
                        JSR             CMD_HASH_PRINT_TOKEN
                        JSR             CMD_HASH_PRINT_EXTRA
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_HASH_INFO_K_FILTER:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'='
                        BEQ             CMD_HASH_INFO_K_HAVE_OP
                        CMP             #'<'
                        BEQ             CMD_HASH_INFO_K_HAVE_OP
                        CMP             #'>'
                        BNE             CMD_HASH_INFO_RESTORE_LOOKUP
CMD_HASH_INFO_K_HAVE_OP:
                        STA             CMD_HASH_FILTER_OP
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             CMD_HASH_USAGE
                        STA             CMD_HASH_FILTER_VALUE
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_HASH_USAGE
                        BRA             CMD_HASH_LIST_WITH_FILTER
CMD_HASH_INFO_RESTORE_LOOKUP:
                        LDA             CMDP_START_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_PTR_HI
                        BRA             CMD_HASH_INFO_LOOKUP
CMD_HASH_USAGE:
                        LDX             #<MSG_HASH_USAGE
                        LDY             #>MSG_HASH_USAGE
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_HASH_LIST:
                        STZ             CMD_HASH_FILTER_OP
CMD_HASH_LIST_WITH_FILTER:
                        LDX             #<MSG_HASH_HDR
                        LDY             #>MSG_HASH_HDR
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JSR             CMD_HASH_SCAN_INIT
CMD_HASH_LIST_LOOP:
                        JSR             CMD_HASH_SCAN_NEXT_RECORD
                        BCC             CMD_HASH_LIST_DONE
                        JSR             CMD_HASH_RECORD_IN_FILTER
                        BCC             CMD_HASH_LIST_SKIP
                        JSR             CMD_HASH_PRINT_ROW
                        JSR             HIM_CHECK_CTRL_C
                        BCS             CMD_HASH_LIST_DONE
CMD_HASH_LIST_SKIP:
                        JSR             CMD_HASH_SCAN_ADV
                        BRA             CMD_HASH_LIST_LOOP
CMD_HASH_LIST_DONE:
                        RTS

; ----------------------------------------------------------------------------
; " text ["]
; Hash text through the closing quote or end of line. Input is already folded
; uppercase by the top-level reader; leading/trailing spaces are not hashed.
; ----------------------------------------------------------------------------
CMD_QUOTE_HASH_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$A5,$92,$0C,$27,CMD_HASH_KIND_EXEC_TEXT ; " $270C92A5 K=05 EXEC+TEXT
                        DW              CMD_QUOTE_HASH
                        DW              TXT_CMD_QUOTE_HASH
CMD_QUOTE_HASH:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        LDA             CMDP_PTR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_START_HI
CMD_QUOTE_FIND_END:
                        JSR             CMD_PEEK
                        BEQ             CMD_QUOTE_END_FOUND
                        CMP             #'"'
                        BEQ             CMD_QUOTE_END_FOUND
                        JSR             CMD_ADV_PTR
                        BRA             CMD_QUOTE_FIND_END
CMD_QUOTE_END_FOUND:
                        LDA             CMDP_PTR_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_ADDR_HI
CMD_QUOTE_TRIM:
                        LDA             CMDP_ADDR_LO
                        CMP             CMDP_START_LO
                        BNE             CMD_QUOTE_TRIM_HAVE_BYTE
                        LDA             CMDP_ADDR_HI
                        CMP             CMDP_START_HI
                        BEQ             CMD_QUOTE_HASH_RANGE
CMD_QUOTE_TRIM_HAVE_BYTE:
                        LDA             CMDP_ADDR_LO
                        BNE             CMD_QUOTE_TRIM_DEC_LO
                        DEC             CMDP_ADDR_HI
CMD_QUOTE_TRIM_DEC_LO:
                        DEC             CMDP_ADDR_LO
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             #' '
                        BEQ             CMD_QUOTE_TRIM
                        CMP             #$09
                        BEQ             CMD_QUOTE_TRIM
                        INC             CMDP_ADDR_LO
                        BNE             CMD_QUOTE_HASH_RANGE
                        INC             CMDP_ADDR_HI
CMD_QUOTE_HASH_RANGE:
                        JSR             FNV1A_INIT
                        LDA             CMDP_START_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_PTR_HI
CMD_QUOTE_HASH_LOOP:
                        LDA             CMDP_PTR_LO
                        CMP             CMDP_ADDR_LO
                        BNE             CMD_QUOTE_HASH_BYTE
                        LDA             CMDP_PTR_HI
                        CMP             CMDP_ADDR_HI
                        BEQ             CMD_QUOTE_HASH_DONE
CMD_QUOTE_HASH_BYTE:
                        JSR             CMD_PEEK
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A_FAST
                        JSR             CMD_ADV_PTR
                        BRA             CMD_QUOTE_HASH_LOOP
CMD_QUOTE_HASH_DONE:
                        JSR             CMD_SAVE_HASH
                        JSR             MON_PRINT_HASH
                        JSR             CMD_QUOTE_HASH_MATCH
                        BCC             CMD_QUOTE_HASH_CRLF
                        LDX             #<MSG_QUOTE_MATCH
                        LDY             #>MSG_QUOTE_MATCH
                        JSR             HIM_WRITE_HBSTRING
CMD_QUOTE_HASH_CRLF:
                        JMP             SYS_WRITE_CRLF

CMD_QUOTE_HASH_MATCH:
                        LDA             FNV_HASH0
                        CMP             #QUOTE_HASH_TARGET0
                        BNE             CMD_QUOTE_HASH_NO_MATCH
                        LDA             FNV_HASH1
                        CMP             #QUOTE_HASH_TARGET1
                        BNE             CMD_QUOTE_HASH_NO_MATCH
                        LDA             FNV_HASH2
                        CMP             #QUOTE_HASH_TARGET2
                        BNE             CMD_QUOTE_HASH_NO_MATCH
                        LDA             FNV_HASH3
                        CMP             #QUOTE_HASH_TARGET3
                        BNE             CMD_QUOTE_HASH_NO_MATCH
                        SEC
                        RTS
CMD_QUOTE_HASH_NO_MATCH:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; D [start [end|+count]]
; ----------------------------------------------------------------------------
CMD_D_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$13,$F2,$0B,$C1,CMD_HASH_KIND_EXEC ; D $C10BF213 EXEC
CMD_D:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_D_CONTINUE
                        JSR             CMD_PARSE_RANGE_REQUIRED
                        BCS             CMD_D_EXPLICIT_RANGE
                        JMP             CMD_USAGE_D
CMD_D_CONTINUE:
                        JSR             CMD_D_REPEAT_RANGE
                        BCC             CMD_USAGE_D
                        BRA             CMD_D_RANGE_OK
CMD_D_EXPLICIT_RANGE:
                        JSR             CMD_D_SAVE_SPAN
CMD_D_RANGE_OK:
                        JSR             MON_PRINT_MEM_RANGE
                        JSR             CMD_D_SAVE_NEXT
                        RTS

CMD_D_REPEAT_RANGE:
                        LDA             CMD_DISP_NEXT_LO
                        ORA             CMD_DISP_NEXT_HI
                        BEQ             CMD_D_REPEAT_FAIL

                        LDA             CMD_DISP_NEXT_LO
                        STA             CMD_RANGE_START_LO
                        STA             CMD_RANGE_TMP_LO
                        STA             CMDP_START_LO
                        LDA             CMD_DISP_NEXT_HI
                        STA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_TMP_HI
                        STA             CMDP_START_HI

                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             CMD_DISP_SPAN_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             CMD_DISP_SPAN_HI
                        STA             CMD_RANGE_END_HI
                        BCS             CMD_D_REPEAT_FAIL
                        SEC
                        RTS
CMD_D_REPEAT_FAIL:
                        CLC
                        RTS

CMD_D_SAVE_SPAN:
                        LDA             CMD_RANGE_END_LO
                        SEC
                        SBC             CMD_RANGE_START_LO
                        STA             CMD_DISP_SPAN_LO
                        LDA             CMD_RANGE_END_HI
                        SBC             CMD_RANGE_START_HI
                        STA             CMD_DISP_SPAN_HI
                        RTS

CMD_D_SAVE_NEXT:
                        LDA             CMD_RANGE_END_LO
                        CLC
                        ADC             #$01
                        STA             CMD_DISP_NEXT_LO
                        LDA             CMD_RANGE_END_HI
                        ADC             #$00
                        STA             CMD_DISP_NEXT_HI
                        RTS

CMD_USAGE_D:
                        LDX             #<MSG_USAGE_D
                        LDY             #>MSG_USAGE_D
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; S start end|+count bb|'TEXT' [...]
; ----------------------------------------------------------------------------
CMD_SEARCH_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$22,$13,$0C,$D6,CMD_HASH_KIND_EXEC_TEXT ; S $D60C1322 EXEC+TEXT
                        DW              CMD_SEARCH
                        DW              MSG_SEARCH_EXTRA
CMD_SEARCH:
                        JSR             CMD_ADV_PTR
                        LDA             CMDP_PTR_LO
                        STA             SEARCH_LINE_LO
                        LDA             CMDP_PTR_HI
                        STA             SEARCH_LINE_HI
                        JSR             SEARCH_PARSE_RANGE
                        BCC             CMD_SEARCH_USAGE
                        JSR             SEARCH_PARSE_PATTERN
                        BCC             CMD_SEARCH_USAGE
                        JSR             SEARCH_SCAN_RANGE
                        RTS

CMD_SEARCH_USAGE:
                        LDX             #<MSG_SEARCH_USAGE
                        LDY             #>MSG_SEARCH_USAGE
                        JSR             SEARCH_PRINT_LINE
                        RTS

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
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
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

SEARCH_SCAN_RANGE:
                        STZ             SEARCH_HIT_FLAG
SEARCH_SCAN_LOOP:
                        JSR             SEARCH_SCAN_GT_END
                        BCS             SEARCH_SCAN_DONE
                        LDA             SEARCH_SCAN_HI
                        CMP             #$7F
                        BNE             SEARCH_SCAN_NOT_IO
                        LDA             SEARCH_SCAN_LO
                        JSR             SYS_PRINT_IO_SLOT_SKIP
                        LDA             SEARCH_SCAN_LO
                        AND             #$E0
                        CLC
                        ADC             #$20
                        STA             SEARCH_SCAN_LO
                        LDA             #$7F
                        ADC             #$00
                        STA             SEARCH_SCAN_HI
                        BRA             SEARCH_SCAN_LOOP

SEARCH_SCAN_NOT_IO:
                        JSR             HIM_CHECK_CTRL_C
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
                        LDA             SEARCH_HIT_FLAG
                        BNE             SEARCH_SCAN_RETURN
                        LDX             #<MSG_SEARCH_NF
                        LDY             #>MSG_SEARCH_NF
                        JSR             SEARCH_PRINT_LINE
SEARCH_SCAN_RETURN:
                        RTS

SEARCH_ABORT:
                        LDX             #<MSG_SEARCH_ABORT
                        LDY             #>MSG_SEARCH_ABORT
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

SEARCH_PRINT_HIT:
                        LDA             SEARCH_SCAN_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             SEARCH_SCAN_LO
                        JSR             SYS_WRITE_HEX_BYTE

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
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK

                        LDA             SEARCH_SCAN_LO
                        AND             #$F0
                        STA             SEARCH_ROW_LO
                        LDA             SEARCH_SCAN_HI
                        STA             SEARCH_ROW_HI
                        JSR             SEARCH_PRINT_ROW_ADDR
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             SEARCH_PRINT_ROW_BYTES
                        JMP             SYS_WRITE_CRLF

SEARCH_PRINT_ROW_ADDR:
                        LDA             SEARCH_ROW_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             SEARCH_ROW_LO
                        JMP             SYS_WRITE_HEX_BYTE

SEARCH_PRINT_ROW_BYTES:
                        STZ             SEARCH_COUNT
SEARCH_ROW_BYTE_LOOP:
                        LDA             SEARCH_COUNT
                        BEQ             SEARCH_ROW_BYTE_SPACE
                        CMP             #$08
                        BNE             SEARCH_ROW_BYTE_SPACE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
SEARCH_ROW_BYTE_SPACE:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             SEARCH_COUNT
                        LDA             (SEARCH_ROW_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        INC             SEARCH_COUNT
                        LDA             SEARCH_COUNT
                        CMP             #$10
                        BCC             SEARCH_ROW_BYTE_LOOP

                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
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
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INC             SEARCH_COUNT
                        LDA             SEARCH_COUNT
                        CMP             #$10
                        BCC             SEARCH_ROW_ASCII_LOOP
                        RTS

SEARCH_PRINT_LINE:
                        JSR             HIM_WRITE_HBSTRING
                        JMP             SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; M start [end|+count]
; ----------------------------------------------------------------------------
CMD_M_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$18,$FD,$0B,$C8,CMD_HASH_KIND_EXEC ; M $C80BFD18 EXEC
CMD_M:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_RANGE_REQUIRED
                        BCC             CMD_USAGE_M
                        JSR             MON_MODIFY_RANGE_WRITABLE
                        BCC             CMD_M_PROTECT
                        JSR             MON_MODIFY_RANGE
                        RTS

CMD_USAGE_M:
                        LDX             #<MSG_USAGE_M
                        LDY             #>MSG_USAGE_M
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_M_PROTECT:
                        LDX             #<MSG_M_PROTECT
                        LDY             #>MSG_M_PROTECT
                        JSR             HIM_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; R [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
; ----------------------------------------------------------------------------
CMD_R_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$B5,$14,$0C,$D7,CMD_HASH_KIND_EXEC ; R $D70C14B5 EXEC
CMD_R:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCS             CMD_R_HAVE_CTX
                        RTS
CMD_R_HAVE_CTX:
                        JSR             CMD_ADV_PTR
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             CMD_USAGE_R
                        JSR             MON_PRINT_STOP_AND_REGS
                        RTS

CMD_USAGE_R:
                        LDX             #<MSG_USAGE_R
                        LDY             #>MSG_USAGE_R
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; X [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
; ----------------------------------------------------------------------------
CMD_X_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$27,$1E,$0C,$DD,CMD_HASH_KIND_EXEC ; X $DD0C1E27 EXEC
CMD_X:
                        JSR             MON_CTX_REQUIRE_VALID
                        BCS             CMD_X_HAVE_CTX
                        RTS
CMD_X_HAVE_CTX:
                        JSR             CMD_ADV_PTR
                        JSR             MON_CTX_PARSE_ASSIGN_LIST
                        BCC             CMD_USAGE_X
                        LDX             #<MSG_RESUME
                        LDY             #>MSG_RESUME
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_CTX_RESUME_RTI

CMD_USAGE_X:
                        LDX             #<MSG_USAGE_X
                        LDY             #>MSG_USAGE_X
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; G start
; ----------------------------------------------------------------------------
CMD_G_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$A6,$F3,$0B,$C2,CMD_HASH_KIND_EXEC ; G $C20BF3A6 EXEC
CMD_G:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_USAGE_G
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_G
                        LDX             #<MSG_GO
                        LDY             #>MSG_GO
                        JSR             HIM_WRITE_HBSTRING
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JSR             CMD_SAVE_ENTRY
                        LDA             #CMD_EXEC_KIND_GO
                        STA             CMD_EXEC_KIND
                        ; G clears the trap marker before run; X resumes it.
                        STZ             NMI_CTX_FLAG
                        STZ             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        JMP             (CMDP_ADDR_LO)

CMD_USAGE_G:
                        LDX             #<MSG_USAGE_G
                        LDY             #>MSG_USAGE_G
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

; ----------------------------------------------------------------------------
; L  (S19-only loader: S1 data, S9 terminator; S0 skipped)
; ----------------------------------------------------------------------------
CMD_L_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$AB,$FE,$0B,$C9,CMD_HASH_KIND_EXEC ; L $C90BFEAB EXEC
CMD_L:
                        JSR             CMD_ADV_PTR
                        STZ             LOAD_AUTO_GO
                        STZ             LOAD_FLASH_MODE
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_L_ARGS_OK
                        CMP             #'G'
                        BEQ             CMD_L_ARG_G
                        CMP             #'F'
                        BEQ             CMD_L_ARG_F
                        BRA             CMD_USAGE_L_JMP
CMD_L_ARG_G:
                        JSR             CMD_ADV_PTR
                        LDA             #$01
                        STA             LOAD_AUTO_GO
                        JSR             CMD_REQUIRE_EOL
                        BCS             CMD_L_ARGS_OK
                        BRA             CMD_USAGE_L_JMP
CMD_L_ARG_F:
                        JSR             CMD_ADV_PTR
                        LDA             #$01
                        STA             LOAD_FLASH_MODE
                        JSR             CMD_REQUIRE_EOL
                        BCS             CMD_L_ARGS_OK
CMD_USAGE_L_JMP:
                        JMP             CMD_USAGE_L
CMD_L_ARGS_OK:
                        JSR             DBG_CLEAR_ALL
                        STZ             LOAD_FAIL_CODE
                        STZ             LOAD_TOTAL_LO
                        STZ             LOAD_TOTAL_HI
                        STZ             LOAD_SKIP_LO
                        STZ             LOAD_SKIP_HI
                        STZ             LOAD_ABORT_MODE
                        STZ             LOAD_WRITE_OK
                        STZ             LOAD_FAIL_ADDR_LO
                        STZ             LOAD_FAIL_ADDR_HI
                        STZ             LOAD_GO_VALID
                        STZ             LOAD_HAVE_DATA
                        STZ             LOAD_LAST_LO
                        STZ             LOAD_LAST_HI
                        LDA             LOAD_FLASH_MODE
                        BEQ             CMD_L_READY_NORMAL
                        LDX             #<MSG_LF_READY
                        LDY             #>MSG_LF_READY
                        BRA             CMD_L_READY_PRINT
CMD_L_READY_NORMAL:
                        LDX             #<MSG_L_READY
                        LDY             #>MSG_L_READY
CMD_L_READY_PRINT:
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF

CMD_L_READ_LOOP:
                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_UPPER
                        BCS             CMD_L_HAVE_LINE
                        STA             LOAD_LINE_STATUS
                        LDX             #<MSG_L_STATUS
                        LDY             #>MSG_L_STATUS
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_LINE_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        BRA             CMD_L_READ_LOOP

CMD_L_HAVE_LINE:
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_PEEK
                        BEQ             CMD_L_READ_LOOP
                        CMP             #'L'
                        BEQ             CMD_L_READ_LOOP

                        LDA             LOAD_ABORT_MODE
                        BNE             CMD_L_KEEP_FAIL_CODE
                        STZ             LOAD_FAIL_CODE
CMD_L_KEEP_FAIL_CODE:
                        JSR             L_PARSE_RECORD
                        BCS             CMD_L_PARSE_OK
                        LDA             LOAD_ABORT_MODE
                        BNE             CMD_L_READ_LOOP
                        JSR             CMD_L_PRINT_FAIL
                        LDA             LOAD_FAIL_CODE
                        CMP             #LOAD_FAIL_PARSE
                        BEQ             CMD_L_READ_LOOP
                        LDA             LOAD_FLASH_MODE
                        BNE             CMD_L_FLASH_FAIL_DRAIN
                        JMP             CMD_L_FAIL_EXIT
CMD_L_FLASH_FAIL_DRAIN:
                        JSR             CMD_L_LATCH_FLASH_FAIL
                        BRA             CMD_L_READ_LOOP

CMD_L_PARSE_OK:
                        LDA             LOAD_REC_KIND
                        CMP             #LOAD_REC_KIND_TERM
                        BNE             CMD_L_READ_LOOP

                        LDA             LOAD_AUTO_GO
                        BEQ             CMD_L_PRINT_DONE
                        LDA             LOAD_GO_VALID
                        BEQ             CMD_L_GO_FALLBACK
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BNE             CMD_L_PRINT_DONE
CMD_L_GO_FALLBACK:
                        LDA             LOAD_HAVE_DATA
                        BEQ             CMD_L_PRINT_DONE
                        LDA             LOAD_FIRST_LO
                        STA             LOAD_GO_LO
                        LDA             LOAD_FIRST_HI
                        STA             LOAD_GO_HI
                        LDA             #$01
                        STA             LOAD_GO_VALID

CMD_L_PRINT_DONE:
                        LDA             LOAD_FLASH_MODE
                        BEQ             CMD_L_DONE_NORMAL
                        LDA             LOAD_ABORT_MODE
                        BNE             CMD_L_PRINT_FLASH_FAIL_DONE
                        LDX             #<MSG_LF_DONE
                        LDY             #>MSG_LF_DONE
                        BRA             CMD_L_DONE_PRINT
CMD_L_PRINT_FLASH_FAIL_DONE:
                        LDX             #<MSG_LF_FAIL_DONE
                        LDY             #>MSG_LF_FAIL_DONE
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_FAIL_CODE
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_WR
                        LDY             #>MSG_L_WR
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_TOTAL_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_TOTAL_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_SKIP
                        LDY             #>MSG_L_SKIP
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_SKIP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_SKIP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_GO
                        LDY             #>MSG_L_GO
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_GO_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JMP             CMD_L_FAIL_EXIT
CMD_L_DONE_NORMAL:
                        LDX             #<MSG_L_DONE
                        LDY             #>MSG_L_DONE
CMD_L_DONE_PRINT:
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_TOTAL_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_TOTAL_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_GO
                        LDY             #>MSG_L_GO
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_GO_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_GO_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        LDA             LOAD_AUTO_GO
                        BEQ             CMD_L_DONE_EXIT
                        LDA             LOAD_GO_VALID
                        BEQ             CMD_L_DONE_EXIT
                        LDA             LOAD_GO_HI
                        ORA             LOAD_GO_LO
                        BEQ             CMD_L_DONE_EXIT
                        LDA             LOAD_GO_LO
                        STA             CMD_EXEC_ENTRY_LO
                        LDA             LOAD_GO_HI
                        STA             CMD_EXEC_ENTRY_HI
                        LDA             #CMD_EXEC_KIND_LOADGO
                        STA             CMD_EXEC_KIND
                        JMP             (LOAD_GO_LO)
CMD_L_DONE_EXIT:
                        LDA             #LOAD_FAIL_NONE
                        SEC
                        RTS
CMD_L_FAIL_EXIT:
                        LDA             LOAD_FAIL_CODE
                        PHA
                        LDA             LOAD_FAIL_ADDR_HI
                        ORA             LOAD_FAIL_ADDR_LO
                        BEQ             CMD_L_FAIL_EXIT_DST
                        LDX             LOAD_FAIL_ADDR_HI
                        LDY             LOAD_FAIL_ADDR_LO
                        BRA             CMD_L_FAIL_EXIT_DONE
CMD_L_FAIL_EXIT_DST:
                        LDX             LOAD_DST_HI
                        LDY             LOAD_DST_LO
CMD_L_FAIL_EXIT_DONE:
                        PLA
                        CLC
                        RTS

CMD_L_LATCH_FLASH_FAIL:
                        LDA             LOAD_ABORT_MODE
                        BNE             CMD_L_LATCH_FLASH_FAIL_DONE
                        LDA             LOAD_DST_LO
                        STA             LOAD_FAIL_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FAIL_ADDR_HI
                        LDA             #$01
                        STA             LOAD_ABORT_MODE
CMD_L_LATCH_FLASH_FAIL_DONE:
                        RTS

CMD_USAGE_L:
                        LDX             #<MSG_USAGE_L
                        LDY             #>MSG_USAGE_L
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_Q_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$FC,$0F,$0C,$D4,CMD_HASH_KIND_EXEC ; Q $D40C0FFC EXEC
CMD_Q:
                        ; 2026-05-07T20:51-05:00        WLP2        Q now quiesces with WAI, then re-enters HIMON.
                        SEI
                        WAI
                        JMP             MON_REENTER

                        INCLUDE         "HIMON/himon-debug.inc"
                        INCLUDE         "HIMON/himon-disasm.inc"

; ----------------------------------------------------------------------------
; Trap handlers
; ----------------------------------------------------------------------------
MON_NMI_TRAP:
                        ; 2026-05-07T21:25-05:00        WLP2        Restored baseline NMI capture handler.
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        TSX
                        LDA             $0101,X
                        STA             NMI_CTX_P
                        LDA             $0102,X
                        STA             NMI_CTX_PCL
                        LDA             $0103,X
                        STA             NMI_CTX_PCH
                        TXA
                        CLC
                        ADC             #$03
                        STA             NMI_CTX_S
                        LDA             #$01
                        STA             NMI_CTX_FLAG
                        LDA             #TRAP_CAUSE_NMI
                        STA             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        JMP             MON_REENTER

MON_NMI_TRAP_DEBOUNCE:
                        ; 2026-05-07T21:25-05:00        WLP2        POC NMI handler eats switch bounce.
                        PHA
                        LDA             NMI_DEBOUNCE_FLAG
                        CMP             #$01
                        BNE             MON_NMI_TRAP_DEBOUNCE_CAPTURE
                        PLA
                        RTI
MON_NMI_TRAP_DEBOUNCE_CAPTURE:
                        LDA             #$01
                        STA             NMI_DEBOUNCE_FLAG
                        PLA
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        TSX
                        LDA             $0101,X
                        STA             NMI_CTX_P
                        LDA             $0102,X
                        STA             NMI_CTX_PCL
                        LDA             $0103,X
                        STA             NMI_CTX_PCH
                        TXA
                        CLC
                        ADC             #$03
                        STA             NMI_CTX_S
                        LDA             #$01
                        STA             NMI_CTX_FLAG
                        LDA             #TRAP_CAUSE_NMI
                        STA             TRAP_CAUSE
                        STZ             TRAP_BRK_SIG
                        JSR             MON_NMI_DEBOUNCE_DELAY
                        STZ             NMI_DEBOUNCE_FLAG
                        JMP             MON_REENTER

MON_NMI_DEBOUNCE_DELAY:
                        LDA             #NMI_DEBOUNCE_A
?OUTER:                 LDX             #NMI_DEBOUNCE_X
?MIDDLE:                LDY             #NMI_DEBOUNCE_Y
?INNER:                 DEY
                        BNE             ?INNER
                        DEX
                        BNE             ?MIDDLE
                        DEC             A
                        BNE             ?OUTER
                        RTS

MON_BRK_TRAP:
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        TSX
                        LDA             $0101,X
                        STA             NMI_CTX_P
                        LDA             $0102,X
                        STA             NMI_CTX_PCL
                        LDA             $0103,X
                        STA             NMI_CTX_PCH
                        TXA
                        CLC
                        ADC             #$03
                        STA             NMI_CTX_S
                        LDA             #$01
                        STA             NMI_CTX_FLAG
                        LDA             #TRAP_CAUSE_BRK
                        STA             TRAP_CAUSE

                        JSR             DBG_HANDLE_BRK
                        BCC             MON_BRK_TRAP_NORMAL
                        JMP             MON_REENTER

MON_BRK_TRAP_NORMAL:
                        LDA             NMI_CTX_PCL
                        SEC
                        SBC             #$01
                        STA             CMDP_ADDR_LO
                        LDA             NMI_CTX_PCH
                        SBC             #$00
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             TRAP_BRK_SIG
                        JMP             MON_REENTER

MON_IRQ_TRAP:
                        RTI

; ----------------------------------------------------------------------------
; Reset-time RAM clear
; ----------------------------------------------------------------------------
MON_CLEAR_RAM:
                        STZ             CMDP_PTR_LO
                        LDA             #$01
                        STA             CMDP_PTR_HI
                        LDY             #$00
                        LDA             #$00
MON_CLEAR_RAM_PAGE:
MON_CLEAR_RAM_BYTE:
                        STA             (CMDP_PTR_LO),Y
                        INY
                        BNE             MON_CLEAR_RAM_BYTE
                        INC             CMDP_PTR_HI
                        LDA             CMDP_PTR_HI
                        CMP             #>SYS_IO_BASE
                        BEQ             MON_CLEAR_RAM_ZP_BEGIN
                        LDA             #$00
                        BRA             MON_CLEAR_RAM_PAGE

MON_CLEAR_RAM_ZP_BEGIN:
                        LDX             #$00
MON_CLEAR_RAM_ZP:
                        STZ             $00,X
                        INX
                        BNE             MON_CLEAR_RAM_ZP
                        LDA             #BOOT_REASON_COLD
                        STA             BOOT_REASON
                        JMP             MON_START_INIT

; ----------------------------------------------------------------------------
; Tiny HIMONIA input
; ----------------------------------------------------------------------------
HIM_READ_LINE_ECHO_UPPER:
                        LDA             #$01
                        BRA             HIM_READ_LINE_SET_MODE
HIM_READ_LINE_UPPER:
                        LDA             #$00
HIM_READ_LINE_SET_MODE:
                        STA             CMD_IO_TMP
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        STZ             CMDP_REMAIN
HIM_READ_LINE_LOOP:
                        JSR             BIO_FTDI_READ_BYTE_BLOCK
                        CMP             #$03
                        BEQ             HIM_READ_LINE_ABORT
                        CMP             #$0D
                        BEQ             HIM_READ_LINE_DONE
                        CMP             #$0A
                        BEQ             HIM_READ_LINE_DONE
                        CMP             #$08
                        BEQ             HIM_READ_LINE_BACKSPACE
                        CMP             #$7F
                        BEQ             HIM_READ_LINE_BACKSPACE
                        JSR             HIM_CHAR_TO_UPPER
                        STA             CMDP_BYTE_TMP
                        LDA             CMDP_REMAIN
                        CMP             #$FF
                        BEQ             HIM_READ_LINE_LOOP
                        LDY             #$00
                        LDA             CMDP_BYTE_TMP
                        STA             (CMDP_PTR_LO),Y
                        JSR             CMD_ADV_PTR
                        INC             CMDP_REMAIN
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_LOOP
                        LDA             CMDP_BYTE_TMP
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        BRA             HIM_READ_LINE_LOOP

HIM_READ_LINE_BACKSPACE:
                        LDA             CMDP_REMAIN
                        BEQ             HIM_READ_LINE_LOOP
                        DEC             CMDP_REMAIN
                        LDA             CMDP_PTR_LO
                        BNE             HIM_READ_LINE_BS_DEC
                        DEC             CMDP_PTR_HI
HIM_READ_LINE_BS_DEC:
                        DEC             CMDP_PTR_LO
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_LOOP
                        LDA             #$08
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #$08
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        BRA             HIM_READ_LINE_LOOP

HIM_READ_LINE_DONE:
                        LDY             #$00
                        LDA             #$00
                        STA             (CMDP_PTR_LO),Y
                        LDA             CMD_IO_TMP
                        BEQ             HIM_READ_LINE_DONE_STATUS
                        JSR             SYS_WRITE_CRLF
HIM_READ_LINE_DONE_STATUS:
                        LDA             CMDP_REMAIN
                        SEC
                        RTS

HIM_READ_LINE_ABORT:
                        JSR             SYS_WRITE_CRLF
                        LDA             CMD_FLAGS
                        AND             #CMD_FLAG_TOP_INPUT
                        BEQ             HIM_READ_LINE_ABORT_LINE
                        LDA             CMDP_REMAIN
                        BNE             HIM_READ_LINE_ABORT_LINE
                        LDA             #CMD_ABORT_TOP
                        CLC
                        RTS
HIM_READ_LINE_ABORT_LINE:
                        LDA             #$03
                        CLC
                        RTS

HIM_CHAR_TO_UPPER:
                        CMP             #'a'
                        BCC             HIM_CHAR_TO_UPPER_DONE
                        CMP             #'z'+1
                        BCS             HIM_CHAR_TO_UPPER_DONE
                        SEC
                        SBC             #$20
HIM_CHAR_TO_UPPER_DONE:
                        RTS

HIM_WRITE_HBSTRING:
                        STX             CMDP_PTR_LO
                        STY             CMDP_PTR_HI
                        LDY             #$00
HIM_WRITE_HBSTRING_LOOP:
                        LDA             (CMDP_PTR_LO),Y
                        BMI             HIM_WRITE_HBSTRING_LAST
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INY
                        BNE             HIM_WRITE_HBSTRING_LOOP
                        INC             CMDP_PTR_HI
                        BRA             HIM_WRITE_HBSTRING_LOOP
HIM_WRITE_HBSTRING_LAST:
                        AND             #$7F
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

; ----------------------------------------------------------------------------
; Context helpers
; ----------------------------------------------------------------------------
MON_CTX_REQUIRE_VALID:
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BEQ             MON_CTX_REQUIRE_VALID_OK
                        LDX             #<MSG_NOCTX
                        LDY             #>MSG_NOCTX
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        CLC
                        RTS
MON_CTX_REQUIRE_VALID_OK:
                        SEC
                        RTS

MON_CTX_PARSE_ASSIGN_LIST:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MON_CTX_PARSE_ASSIGN_LIST_DONE
MON_CTX_PARSE_ASSIGN_LOOP:
                        JSR             MON_CTX_PARSE_ASSIGN
                        BCC             MON_CTX_PARSE_ASSIGN_LIST_FAIL
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BNE             MON_CTX_PARSE_ASSIGN_LOOP
MON_CTX_PARSE_ASSIGN_LIST_DONE:
                        SEC
                        RTS
MON_CTX_PARSE_ASSIGN_LIST_FAIL:
                        CLC
                        RTS

MON_CTX_PARSE_ASSIGN:
                        JSR             CMD_PEEK
                        CMP             #'A'
                        BEQ             MON_CTX_PARSE_A
                        CMP             #'X'
                        BEQ             MON_CTX_PARSE_X
                        CMP             #'Y'
                        BEQ             MON_CTX_PARSE_Y
                        CMP             #'S'
                        BEQ             MON_CTX_PARSE_S
                        CMP             #'P'
                        BEQ             MON_CTX_PARSE_P_OR_PC
                        CLC
                        RTS

MON_CTX_PARSE_A:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_A
                        SEC
                        RTS

MON_CTX_PARSE_X:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_X
                        SEC
                        RTS

MON_CTX_PARSE_Y:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_Y
                        SEC
                        RTS

MON_CTX_PARSE_S:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_S
                        SEC
                        RTS

MON_CTX_PARSE_P_OR_PC:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        CMP             #'C'
                        BEQ             MON_CTX_PARSE_PC
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        STA             NMI_CTX_P
                        SEC
                        RTS

MON_CTX_PARSE_PC:
                        JSR             CMD_ADV_PTR
                        JSR             MON_PARSE_EQ
                        BCC             MON_CTX_PARSE_FAIL
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             MON_CTX_PARSE_FAIL
                        LDA             CMDP_ADDR_LO
                        STA             NMI_CTX_PCL
                        LDA             CMDP_ADDR_HI
                        STA             NMI_CTX_PCH
                        SEC
                        RTS

MON_CTX_PARSE_FAIL:
                        CLC
                        RTS

MON_PARSE_EQ:
                        JSR             CMD_PEEK
                        CMP             #'='
                        BNE             MON_PARSE_EQ_FAIL
                        JSR             CMD_ADV_PTR
                        SEC
                        RTS
MON_PARSE_EQ_FAIL:
                        CLC
                        RTS

MON_CTX_RESUME_RTI:
                        SEI
                        LDY             NMI_CTX_S
                        LDA             NMI_CTX_P
                        STA             $00FE,Y
                        LDA             NMI_CTX_PCL
                        STA             $00FF,Y
                        LDA             NMI_CTX_PCH
                        STA             $0100,Y

                        TYA
                        SEC
                        SBC             #$03
                        TAX
                        TXS

                        STZ             NMI_CTX_FLAG
                        LDA             NMI_CTX_A
                        LDX             NMI_CTX_X
                        LDY             NMI_CTX_Y
                        RTI

; ----------------------------------------------------------------------------
; Printing helpers
; ----------------------------------------------------------------------------
MON_PRINT_STOP_AND_REGS:
                        JSR             SYS_WRITE_CRLF
                        LDA             TRAP_CAUSE
                        CMP             #TRAP_CAUSE_DBG
                        BEQ             MON_PRINT_STOP_DBG
                        CMP             #TRAP_CAUSE_BRK
                        BEQ             MON_PRINT_STOP_BRK
                        LDX             #<MSG_STOP_NMI
                        LDY             #>MSG_STOP_NMI
                        JSR             HIM_WRITE_HBSTRING
                        BRA             MON_PRINT_STOP_PC
MON_PRINT_STOP_BRK:
                        LDX             #<MSG_STOP_BRK
                        LDY             #>MSG_STOP_BRK
                        JSR             HIM_WRITE_HBSTRING
                        LDA             TRAP_BRK_SIG
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_STOP_PC
                        LDY             #>MSG_STOP_PC
                        JSR             HIM_WRITE_HBSTRING
MON_PRINT_STOP_PC:
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE

MON_PRINT_REGS:
                        JSR             SYS_WRITE_CRLF
MON_PRINT_REGS_BODY:
                        LDX             #<MSG_REG_A
                        LDY             #>MSG_REG_A
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_A
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_X
                        LDY             #>MSG_REG_X
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_X
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_Y
                        LDY             #>MSG_REG_Y
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_P
                        LDY             #>MSG_REG_P
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_P
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_REG_S
                        LDY             #>MSG_REG_S
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_S
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             MON_PRINT_FLAGS
                        JSR             SYS_WRITE_CRLF
                        RTS

MON_PRINT_STOP_DBG:
                        LDA             #'@'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JMP             MON_PRINT_REGS_BODY

MON_PRINT_RET_AND_REGS:
                        JSR             SYS_WRITE_CRLF
                        JSR             MON_PRINT_EXEC_ID
                        LDX             #<MSG_ENTRY
                        LDY             #>MSG_ENTRY
                        JSR             HIM_WRITE_HBSTRING
                        LDA             NMI_CTX_PCH
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             NMI_CTX_PCL
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        LDX             #<MSG_RET
                        LDY             #>MSG_RET
                        JSR             HIM_WRITE_HBSTRING
                        JMP             MON_PRINT_REGS_BODY

MON_PRINT_EXEC_ID:
                        LDA             CMD_EXEC_KIND
                        CMP             #CMD_EXEC_KIND_GO
                        BEQ             MON_PRINT_EXEC_GO
                        CMP             #CMD_EXEC_KIND_LOADGO
                        BEQ             MON_PRINT_EXEC_LOADGO
                        JMP             MON_PRINT_HASH
MON_PRINT_EXEC_GO:
                        LDX             #<MSG_BOX_GO
                        LDY             #>MSG_BOX_GO
                        BRA             MON_PRINT_BOX
MON_PRINT_EXEC_LOADGO:
                        LDX             #<MSG_BOX_LOADGO
                        LDY             #>MSG_BOX_LOADGO
MON_PRINT_BOX:
                        LDA             #'#'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             HIM_WRITE_HBSTRING
                        LDA             #'#'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

MON_PRINT_HASH:
                        LDA             #'#'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             CMD_EXEC_HASH3
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_EXEC_HASH2
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_EXEC_HASH1
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_EXEC_HASH0
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #'#'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

MON_PRINT_FLAGS:
                        LDA             NMI_CTX_P
                        LDX             #'N'
                        LDY             #'n'
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             NMI_CTX_P
                        LDX             #'V'
                        LDY             #'v'
                        ASL             A
                        ASL             A
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             #'-'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             NMI_CTX_P
                        LDX             #'B'
                        LDY             #'b'
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             NMI_CTX_P
                        LDX             #'D'
                        LDY             #'d'
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             NMI_CTX_P
                        LDX             #'I'
                        LDY             #'i'
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             NMI_CTX_P
                        LDX             #'Z'
                        LDY             #'z'
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        JSR             MON_PRINT_FLAG_CHAR
                        LDA             NMI_CTX_P
                        LDX             #'C'
                        LDY             #'c'
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
MON_PRINT_FLAG_CHAR:
                        BCS             MON_PRINT_FLAG_SET
                        TYA
                        BRA             MON_PRINT_FLAG_OUT
MON_PRINT_FLAG_SET:
                        TXA
MON_PRINT_FLAG_OUT:
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        RTS

MON_PRINT_MEM_RANGE:
MON_PRINT_MEM_NEXT_LINE:
                        JSR             MON_CURR_GT_END
                        BCC             MON_PRINT_MEM_RANGE_ACTIVE
                        JMP             MON_PRINT_MEM_DONE
MON_PRINT_MEM_RANGE_ACTIVE:
                        JSR             MON_PRINT_MEM_IO_SKIP
                        BCS             MON_PRINT_MEM_NEXT_LINE
                        LDA             CMD_RANGE_TMP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK

                        LDA             CMDP_START_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_PTR_HI
                        STZ             CMD_PATTERN_COUNT
MON_PRINT_MEM_LINE_LOOP:
                        JSR             HIM_CHECK_CTRL_C
                        BCS             MON_PRINT_MEM_ABORT
                        JSR             MON_CURR_GT_END
                        BCS             MON_PRINT_MEM_NEXT_LINE
                        JSR             MON_CURR_IS_IO
                        BCC             MON_PRINT_MEM_READ_BYTE
                        LDA             CMD_PATTERN_COUNT
                        BEQ             MON_PRINT_MEM_NEXT_LINE
                        JSR             MON_PRINT_MEM_ASCII
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_PRINT_MEM_NEXT_LINE
MON_PRINT_MEM_READ_BYTE:
                        LDA             CMD_PATTERN_COUNT
                        BEQ             MON_PRINT_MEM_SPACE
                        CMP             #$08
                        BNE             MON_PRINT_MEM_SPACE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
MON_PRINT_MEM_SPACE:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        INC             CMD_PATTERN_COUNT
                        LDA             CMD_RANGE_TMP_HI
                        CMP             CMD_RANGE_END_HI
                        BNE             MON_PRINT_MEM_NOT_END
                        LDA             CMD_RANGE_TMP_LO
                        CMP             CMD_RANGE_END_LO
                        BEQ             MON_PRINT_MEM_LAST_LINE
MON_PRINT_MEM_NOT_END:
                        JSR             CMD_INC_RANGE_TMP
                        LDA             CMD_PATTERN_COUNT
                        CMP             #$10
                        BCC             MON_PRINT_MEM_LINE_LOOP
                        JSR             MON_PRINT_MEM_ASCII
                        JSR             SYS_WRITE_CRLF
                        JMP             MON_PRINT_MEM_NEXT_LINE

MON_PRINT_MEM_LAST_LINE:
                        JSR             MON_PRINT_MEM_ASCII
MON_PRINT_MEM_ABORT:
                        JSR             SYS_WRITE_CRLF
MON_PRINT_MEM_DONE:
                        RTS

MON_PRINT_MEM_ASCII:
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'|'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        STZ             CMD_PATTERN_INDEX
MON_PRINT_MEM_ASCII_LOOP:
                        LDA             CMD_PATTERN_INDEX
                        CMP             CMD_PATTERN_COUNT
                        BCS             MON_PRINT_MEM_ASCII_DONE
                        TAY
                        LDA             (CMDP_PTR_LO),Y
                        CMP             #' '
                        BCC             MON_PRINT_MEM_ASCII_DOT
                        CMP             #$7F
                        BCC             MON_PRINT_MEM_ASCII_OUT
MON_PRINT_MEM_ASCII_DOT:
                        LDA             #'.'
MON_PRINT_MEM_ASCII_OUT:
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INC             CMD_PATTERN_INDEX
                        BRA             MON_PRINT_MEM_ASCII_LOOP
MON_PRINT_MEM_ASCII_DONE:
                        RTS

MON_CURR_IS_IO:
                        LDA             CMD_RANGE_TMP_HI
                        CMP             #$7F
                        BEQ             MON_CURR_IS_IO_YES
                        CLC
                        RTS
MON_CURR_IS_IO_YES:
                        SEC
                        RTS

MON_PRINT_MEM_IO_SKIP:
                        JSR             MON_CURR_IS_IO
                        BCS             MON_PRINT_MEM_IO_SKIP_YES
                        CLC
                        RTS
MON_PRINT_MEM_IO_SKIP_YES:
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_PRINT_IO_SLOT_SKIP
                        LDA             CMD_RANGE_TMP_LO
                        AND             #$E0
                        CLC
                        ADC             #$20
                        STA             CMD_RANGE_TMP_LO
                        STA             CMDP_START_LO
                        LDA             #$7F
                        ADC             #$00
                        STA             CMD_RANGE_TMP_HI
                        STA             CMDP_START_HI
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: SYS_PRINT_IO_SLOT_SKIP  [HASH:C2A5A6CE]
; IN : A = low byte inside $7Fxx I/O window.
; OUT: one named "$7Fxx: ... IO SKIP" line printed; A/X/Y clobbered.
; ----------------------------------------------------------------------------
SYS_PRINT_IO_SLOT_SKIP_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$CE,$A6,$A5,$C2,CMD_HASH_KIND_EXEC ; SYS_PRINT_IO_SLOT_SKIP $C2A5A6CE EXEC
SYS_PRINT_IO_SLOT_SKIP:
                        AND             #$E0
                        STA             CMD_IO_TMP
                        LDA             #$7F
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_IO_TMP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             CMD_IO_TMP
                        BEQ             SYS_PRINT_IO_SLOT_CS0
                        CMP             #$20
                        BEQ             SYS_PRINT_IO_SLOT_CS1
                        CMP             #$40
                        BEQ             SYS_PRINT_IO_SLOT_CS2
                        CMP             #$60
                        BEQ             SYS_PRINT_IO_SLOT_CS3
                        CMP             #$80
                        BEQ             SYS_PRINT_IO_SLOT_ACIA
                        CMP             #$A0
                        BEQ             SYS_PRINT_IO_SLOT_PIA
                        CMP             #$C0
                        BEQ             SYS_PRINT_IO_SLOT_VIA
                        LDX             #<MSG_D_IO_FTDI
                        LDY             #>MSG_D_IO_FTDI
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_CS0:
                        LDX             #<MSG_D_IO_CS0
                        LDY             #>MSG_D_IO_CS0
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_CS1:
                        LDX             #<MSG_D_IO_CS1
                        LDY             #>MSG_D_IO_CS1
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_CS2:
                        LDX             #<MSG_D_IO_CS2
                        LDY             #>MSG_D_IO_CS2
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_CS3:
                        LDX             #<MSG_D_IO_CS3
                        LDY             #>MSG_D_IO_CS3
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_ACIA:
                        LDX             #<MSG_D_IO_ACIA
                        LDY             #>MSG_D_IO_ACIA
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_PIA:
                        LDX             #<MSG_D_IO_PIA
                        LDY             #>MSG_D_IO_PIA
                        BRA             SYS_PRINT_IO_SLOT_TEXT
SYS_PRINT_IO_SLOT_VIA:
                        LDX             #<MSG_D_IO_VIA
                        LDY             #>MSG_D_IO_VIA
SYS_PRINT_IO_SLOT_TEXT:
                        JSR             HIM_WRITE_HBSTRING
                        JMP             SYS_WRITE_CRLF

HIM_CHECK_CTRL_C:
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             HIM_CHECK_CTRL_C_NO
                        CMP             #$03
                        BEQ             HIM_CHECK_CTRL_C_YES
HIM_CHECK_CTRL_C_NO:
                        CLC
                        RTS
HIM_CHECK_CTRL_C_YES:
                        SEC
                        RTS

MON_MODIFY_RANGE:
                        STZ             CMD_PATTERN_COUNT
MON_MODIFY_LOOP:
                        JSR             MON_CURR_GT_END
                        BCS             MON_MODIFY_DONE
                        LDA             CMD_RANGE_TMP_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMD_RANGE_TMP_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #':'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDY             #$00
                        LDA             (CMDP_START_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK

                        LDX             #<CMD_BUF
                        LDY             #>CMD_BUF
                        JSR             HIM_READ_LINE_ECHO_UPPER
                        BCC             MON_MODIFY_ABORT
                        LDA             #<CMD_BUF
                        STA             CMDP_PTR_LO
                        LDA             #>CMD_BUF
                        STA             CMDP_PTR_HI
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             MON_MODIFY_NEXT
                        CMP             #'.'
                        BEQ             MON_MODIFY_ABORT
                        JSR             CMD_PARSE_HEX_BYTE_TOKEN
                        BCC             MON_MODIFY_BAD
                        STA             CMD_IO_TMP
                        JSR             CMD_REQUIRE_EOL
                        BCC             MON_MODIFY_BAD
                        LDY             #$00
                        LDA             CMD_IO_TMP
                        STA             (CMDP_START_LO),Y
                        INC             CMD_PATTERN_COUNT
MON_MODIFY_NEXT:
                        JSR             CMD_INC_RANGE_TMP
                        BRA             MON_MODIFY_LOOP

MON_MODIFY_BAD:
                        LDX             #<MSG_USAGE_M
                        LDY             #>MSG_USAGE_M
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        BRA             MON_MODIFY_LOOP

MON_MODIFY_ABORT:
                        RTS

MON_MODIFY_DONE:
                        RTS

MON_MODIFY_RANGE_WRITABLE:
                        LDA             CMD_RANGE_START_HI
                        CMP             #>MON_WORK_BASE
                        BCS             MON_MODIFY_PROTECT_START
                        LDA             CMD_RANGE_END_HI
                        CMP             #>MON_WORK_BASE
                        BCS             MON_MODIFY_PROTECT_MON_BASE
                        SEC
                        RTS
MON_MODIFY_PROTECT_START:
                        LDA             CMD_RANGE_START_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMDP_ADDR_HI
                        CLC
                        RTS
MON_MODIFY_PROTECT_MON_BASE:
                        LDA             #<MON_WORK_BASE
                        STA             CMDP_ADDR_LO
                        LDA             #>MON_WORK_BASE
                        STA             CMDP_ADDR_HI
                        CLC
                        RTS

MON_CURR_GT_END:
                        LDA             CMD_RANGE_TMP_HI
                        CMP             CMD_RANGE_END_HI
                        BCC             MON_CURR_GT_END_NO
                        BNE             MON_CURR_GT_END_YES
                        LDA             CMD_RANGE_TMP_LO
                        CMP             CMD_RANGE_END_LO
                        BCC             MON_CURR_GT_END_NO
                        BEQ             MON_CURR_GT_END_NO
MON_CURR_GT_END_YES:
                        SEC
                        RTS
MON_CURR_GT_END_NO:
                        CLC
                        RTS

CMD_INC_RANGE_TMP:
                        INC             CMD_RANGE_TMP_LO
                        BNE             CMD_INC_RANGE_TMP_DONE
                        INC             CMD_RANGE_TMP_HI
CMD_INC_RANGE_TMP_DONE:
                        INC             CMDP_START_LO
                        BNE             CMD_INC_RANGE_PTR_DONE
                        INC             CMDP_START_HI
CMD_INC_RANGE_PTR_DONE:
                        RTS

CMD_PARSE_RANGE_REQUIRED:
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCS             CMD_PARSE_RANGE_START_OK
                        JMP             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_START_OK:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_START_LO
                        STA             CMD_RANGE_TMP_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_TMP_HI
                        STA             CMDP_START_HI

                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_PARSE_RANGE_DEFAULT_END
                        CMP             #'+'
                        BEQ             CMD_PARSE_RANGE_PLUS

                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCS             CMD_PARSE_RANGE_END_OK
                        JMP             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_END_OK:
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$03
                        BCS             CMD_PARSE_RANGE_FULL_END
                        LDA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_END_HI
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        BRA             CMD_PARSE_RANGE_HAVE_END

CMD_PARSE_RANGE_FULL_END:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_RANGE_END_HI
                        BRA             CMD_PARSE_RANGE_HAVE_END

CMD_PARSE_RANGE_PLUS:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCS             CMD_PARSE_RANGE_COUNT_OK
                        JMP             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_COUNT_OK:
                        LDA             CMDP_ADDR_LO
                        ORA             CMDP_ADDR_HI
                        BNE             CMD_PARSE_RANGE_COUNT_NONZERO
                        JMP             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_COUNT_NONZERO:
                        LDA             CMDP_ADDR_LO
                        BNE             CMD_PARSE_RANGE_COUNT_DEC_LO
                        DEC             CMDP_ADDR_HI
CMD_PARSE_RANGE_COUNT_DEC_LO:
                        DEC             CMDP_ADDR_LO
                        LDA             CMD_RANGE_START_LO
                        CLC
                        ADC             CMDP_ADDR_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_HI
                        ADC             CMDP_ADDR_HI
                        STA             CMD_RANGE_END_HI
                        BCS             CMD_PARSE_RANGE_FAIL
                        BRA             CMD_PARSE_RANGE_HAVE_END

CMD_PARSE_RANGE_DEFAULT_END:
                        LDA             CMD_RANGE_START_LO
                        STA             CMD_RANGE_END_LO
                        LDA             CMD_RANGE_START_HI
                        STA             CMD_RANGE_END_HI

CMD_PARSE_RANGE_HAVE_END:
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_PARSE_RANGE_FAIL
                        LDA             CMD_RANGE_END_HI
                        CMP             CMD_RANGE_START_HI
                        BCC             CMD_PARSE_RANGE_FAIL
                        BNE             CMD_PARSE_RANGE_OK
                        LDA             CMD_RANGE_END_LO
                        CMP             CMD_RANGE_START_LO
                        BCC             CMD_PARSE_RANGE_FAIL
CMD_PARSE_RANGE_OK:
                        SEC
                        RTS
CMD_PARSE_RANGE_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; S19 parser helpers (L command)
; ----------------------------------------------------------------------------
L_PARSE_RECORD:
                        STZ             LOAD_REC_KIND
                        JSR             CMD_PEEK
                        CMP             #'S'
                        BNE             L_PARSE_RECORD_FAIL
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        CMP             #'1'
                        BEQ             L_PARSE_RECORD_S1
                        CMP             #'9'
                        BEQ             L_PARSE_RECORD_S9
                        CMP             #'0'
                        BEQ             L_PARSE_RECORD_S0
                        BRA             L_PARSE_RECORD_FAIL
L_PARSE_RECORD_S1:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S1
                        RTS
L_PARSE_RECORD_S9:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S9
                        RTS
L_PARSE_RECORD_S0:
                        JSR             CMD_ADV_PTR
                        JSR             L_PARSE_S0
                        RTS
L_PARSE_RECORD_FAIL:
                        CLC
                        RTS

L_PARSE_S0:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C1:
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S0_C2:
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        SEC
                        SBC             #$03
                        BCS             L_PARSE_S0_HAVE_DLEN
                        JMP             L_PARSE_FAIL
L_PARSE_S0_HAVE_DLEN:
                        STA             LOAD_DATA_LEN
L_PARSE_S0_SKIP:
                        LDA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S0_CHK
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_D0
                        JMP             L_PARSE_FAIL
L_PARSE_S0_D0:
                        JSR             L_SUM_ADD_A
                        DEC             LOAD_DATA_LEN
                        BRA             L_PARSE_S0_SKIP
L_PARSE_S0_CHK:
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S0_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S0_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S0_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S0_OK:
                        LDA             #LOAD_REC_KIND_SKIP
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_PARSE_S1:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C1:
                        STA             LOAD_DST_HI
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S1_C2:
                        STA             LOAD_DST_LO
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        SEC
                        SBC             #$03
                        BCS             L_PARSE_S1_HAVE_DLEN
                        JMP             L_PARSE_FAIL
L_PARSE_S1_HAVE_DLEN:
                        STA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S1_DATA
                        JSR             L_NOTE_S1_ADDR
L_PARSE_S1_DATA:
                        LDA             LOAD_DATA_LEN
                        BEQ             L_PARSE_S1_CHK
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_D0
                        JMP             L_PARSE_FAIL
L_PARSE_S1_D0:
                        STA             CMD_IO_TMP
                        JSR             L_SUM_ADD_A
                        LDA             CMD_IO_TMP
                        JSR             L_WRITE_DATA_BYTE
                        BCS             L_PARSE_S1_WROTE
                        JMP             L_PARSE_FAIL
L_PARSE_S1_WROTE:
                        INC             LOAD_DST_LO
                        BNE             L_PARSE_S1_NEXT
                        INC             LOAD_DST_HI
L_PARSE_S1_NEXT:
                        LDA             LOAD_WRITE_OK
                        BEQ             L_PARSE_S1_NEXT2
                        INC             LOAD_TOTAL_LO
                        BNE             L_PARSE_S1_NEXT2
                        INC             LOAD_TOTAL_HI
L_PARSE_S1_NEXT2:
                        DEC             LOAD_DATA_LEN
                        BRA             L_PARSE_S1_DATA
L_PARSE_S1_CHK:
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S1_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S1_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S1_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S1_OK:
                        LDA             LOAD_DST_LO
                        STA             LOAD_LAST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_LAST_HI
                        LDA             #LOAD_REC_KIND_DATA
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_WRITE_DATA_BYTE:
                        STA             CMD_IO_TMP
                        STZ             LOAD_WRITE_OK
                        LDA             LOAD_FLASH_MODE
                        BNE             L_WRITE_DATA_BYTE_FLASH
                        LDA             LOAD_DST_HI
                        CMP             #$80
                        BCS             L_WRITE_DATA_BYTE_NEED_FLASH
                        CMP             #>SYS_IO_BASE
                        BCS             L_WRITE_DATA_BYTE_PROTECT
                        LDA             LOAD_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             CMDP_ADDR_HI
                        LDY             #$00
                        LDA             CMD_IO_TMP
                        STA             (CMDP_ADDR_LO),Y
                        LDA             #$01
                        STA             LOAD_WRITE_OK
                        SEC
                        RTS

L_WRITE_DATA_BYTE_NEED_FLASH:
                        LDA             #LOAD_FAIL_NEED_FLASH
                        STA             LOAD_FAIL_CODE
                        CLC
                        RTS

L_WRITE_DATA_BYTE_FLASH:
                        LDA             LOAD_ABORT_MODE
                        BEQ             L_WRITE_DATA_BYTE_FLASH_ACTIVE
                        JSR             L_COUNT_SKIPPED_BYTE
                        SEC
                        RTS
L_WRITE_DATA_BYTE_FLASH_ACTIVE:
                        LDA             LOAD_DST_HI
                        CMP             #$80
                        BCC             L_WRITE_DATA_BYTE_PROTECT
; 2026-05-07T22:58-05:00        WLP2        L F protects relocated HIMON/STR8 at $C000+.
                        CMP             #$C0
                        BCS             L_WRITE_DATA_BYTE_PROTECT
                        JSR             L_FLASH_SET_PTR
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        STA             LOAD_FLASH_OLD
                        CMP             CMD_IO_TMP
                        BEQ             L_WRITE_DATA_BYTE_MATCH
                        CMP             #$FF
                        BNE             L_WRITE_DATA_BYTE_ERASE
                        LDA             CMD_IO_TMP
                        LDX             LOAD_DST_LO
                        LDY             LOAD_DST_HI
                        JSR             FLASH_WRITE_BYTE_AXY
                        BCC             L_WRITE_DATA_BYTE_WRITE_FAIL
                        JSR             L_FLASH_SET_PTR
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             CMD_IO_TMP
                        BNE             L_WRITE_DATA_BYTE_WRITE_FAIL_A
                        LDA             #$01
                        STA             LOAD_WRITE_OK
                        SEC
                        RTS

L_WRITE_DATA_BYTE_MATCH:
                        LDA             #$01
                        STA             LOAD_WRITE_OK
                        SEC
                        RTS

L_WRITE_DATA_BYTE_PROTECT:
                        JSR             L_COUNT_SKIPPED_BYTE
                        LDA             #LOAD_FAIL_PROTECT
                        STA             LOAD_FAIL_CODE
                        CLC
                        RTS

L_WRITE_DATA_BYTE_ERASE:
                        JSR             L_COUNT_SKIPPED_BYTE
                        LDA             #LOAD_FAIL_ERASE
                        STA             LOAD_FAIL_CODE
                        CLC
                        RTS

L_WRITE_DATA_BYTE_WRITE_FAIL:
                        JSR             L_FLASH_SET_PTR
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
L_WRITE_DATA_BYTE_WRITE_FAIL_A:
                        STA             LOAD_FLASH_OLD
                        JSR             L_COUNT_SKIPPED_BYTE
                        LDA             #LOAD_FAIL_WRITE
                        STA             LOAD_FAIL_CODE
                        CLC
                        RTS

L_COUNT_SKIPPED_BYTE:
                        INC             LOAD_SKIP_LO
                        BNE             L_COUNT_SKIPPED_BYTE_DONE
                        INC             LOAD_SKIP_HI
L_COUNT_SKIPPED_BYTE_DONE:
                        RTS

L_FLASH_SET_PTR:
                        LDA             LOAD_DST_LO
                        STA             CMDP_ADDR_LO
                        LDA             LOAD_DST_HI
                        STA             CMDP_ADDR_HI
                        RTS

L_NOTE_S1_ADDR:
                        LDA             LOAD_HAVE_DATA
                        BNE             L_NOTE_S1_ADDR_HAVE_DATA
                        LDA             #$01
                        STA             LOAD_HAVE_DATA
                        LDA             LOAD_DST_LO
                        STA             LOAD_FIRST_LO
                        LDA             LOAD_DST_HI
                        STA             LOAD_FIRST_HI
                        BRA             L_NOTE_S1_ADDR_PRINT

L_NOTE_S1_ADDR_HAVE_DATA:
                        LDA             LOAD_DST_HI
                        CMP             LOAD_LAST_HI
                        BNE             L_NOTE_S1_ADDR_PRINT
                        LDA             LOAD_DST_LO
                        CMP             LOAD_LAST_LO
                        BEQ             L_NOTE_S1_ADDR_DONE
L_NOTE_S1_ADDR_PRINT:
                        LDA             #'L'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             #'@'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        LDA             LOAD_DST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_DST_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
L_NOTE_S1_ADDR_DONE:
                        RTS

L_PARSE_S9:
                        STZ             LOAD_SUM
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C0
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C0:
                        STA             LOAD_COUNT
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C1
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C1:
                        STA             LOAD_GO_HI
                        JSR             L_SUM_ADD_A
                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_C2
                        JMP             L_PARSE_FAIL
L_PARSE_S9_C2:
                        STA             LOAD_GO_LO
                        JSR             L_SUM_ADD_A

                        LDA             LOAD_COUNT
                        CMP             #$03
                        BNE             L_PARSE_FAIL

                        JSR             L_PARSE_HEX_BYTE_STRICT
                        BCS             L_PARSE_S9_CK
                        JMP             L_PARSE_FAIL
L_PARSE_S9_CK:
                        STA             LOAD_CHK
                        JSR             L_VERIFY_CHECKSUM_EOL
                        BCS             L_PARSE_S9_OK
                        JMP             L_PARSE_FAIL
L_PARSE_S9_OK:
                        LDA             #$01
                        STA             LOAD_GO_VALID
                        LDA             #LOAD_REC_KIND_TERM
                        STA             LOAD_REC_KIND
                        SEC
                        RTS

L_SUM_ADD_A:
                        CLC
                        ADC             LOAD_SUM
                        STA             LOAD_SUM
                        RTS

L_VERIFY_CHECKSUM_EOL:
                        LDA             LOAD_SUM
                        EOR             #$FF
                        CMP             LOAD_CHK
                        BNE             L_VERIFY_CHECKSUM_EOL_FAIL
                        JSR             CMD_PEEK
                        BEQ             L_VERIFY_CHECKSUM_EOL_OK
L_VERIFY_CHECKSUM_EOL_FAIL:
                        CLC
                        RTS
L_VERIFY_CHECKSUM_EOL_OK:
                        SEC
                        RTS

L_PARSE_HEX_BYTE_STRICT:
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             L_PARSE_HEX_BYTE_STRICT_FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             CMDP_NIB_HI
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             L_PARSE_HEX_BYTE_STRICT_FAIL
                        ORA             CMDP_NIB_HI
                        JSR             CMD_ADV_PTR
                        SEC
                        RTS
L_PARSE_HEX_BYTE_STRICT_FAIL:
                        CLC
                        RTS

L_PARSE_FAIL:
                        LDA             LOAD_FAIL_CODE
                        BNE             L_PARSE_FAIL_HAVE_CODE
                        LDA             #LOAD_FAIL_PARSE
                        STA             LOAD_FAIL_CODE
L_PARSE_FAIL_HAVE_CODE:
                        CLC
                        RTS

CMD_L_PRINT_FAIL:
                        LDA             LOAD_FAIL_CODE
                        LDX             LOAD_FLASH_MODE
                        BEQ             ?GENERIC
                        CMP             #LOAD_FAIL_PROTECT
                        BEQ             CMD_L_PRINT_FAIL_PROTECT
                        CMP             #LOAD_FAIL_ERASE
                        BEQ             CMD_L_PRINT_FAIL_ERASE
                        CMP             #LOAD_FAIL_WRITE
                        BEQ             CMD_L_PRINT_FAIL_WRITE
?GENERIC:
                        PHA
                        LDX             #<MSG_L_ERR
                        LDY             #>MSG_L_ERR
                        JSR             HIM_WRITE_HBSTRING
                        PLA
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

CMD_L_PRINT_FAIL_PROTECT:
                        LDX             #<MSG_LF_PROTECT
                        LDY             #>MSG_LF_PROTECT
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_L_PRINT_LOAD_DST
                        JMP             SYS_WRITE_CRLF

CMD_L_PRINT_FAIL_ERASE:
                        LDX             #<MSG_LF_ERASE
                        LDY             #>MSG_LF_ERASE
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_L_PRINT_LOAD_DST
                        LDX             #<MSG_L_OLD
                        LDY             #>MSG_L_OLD
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_FLASH_OLD
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_NEW
                        LDY             #>MSG_L_NEW
                        JSR             HIM_WRITE_HBSTRING
                        LDA             CMD_IO_TMP
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

CMD_L_PRINT_FAIL_WRITE:
                        LDX             #<MSG_LF_WRITE
                        LDY             #>MSG_LF_WRITE
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_L_PRINT_LOAD_DST
                        LDX             #<MSG_L_WANT
                        LDY             #>MSG_L_WANT
                        JSR             HIM_WRITE_HBSTRING
                        LDA             CMD_IO_TMP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_L_READ
                        LDY             #>MSG_L_READ
                        JSR             HIM_WRITE_HBSTRING
                        LDA             LOAD_FLASH_OLD
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

CMD_L_PRINT_LOAD_DST:
                        LDA             LOAD_DST_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             LOAD_DST_LO
                        JMP             SYS_WRITE_HEX_BYTE

; ----------------------------------------------------------------------------
; FNV-1a command token dispatch
; ----------------------------------------------------------------------------
CMD_HASH_TOKEN:
                        LDA             CMDP_PTR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_START_HI
                        JSR             FNV1A_INIT
                        JSR             CMD_PEEK
                        CMP             #'"'
                        BNE             CMD_HASH_TOKEN_LOOP
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A_FAST
                        BRA             CMD_HASH_TOKEN_DONE
CMD_HASH_TOKEN_LOOP:
                        JSR             CMD_PEEK
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCS             CMD_HASH_TOKEN_DONE
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A_FAST
                        JSR             CMD_ADV_PTR
                        BRA             CMD_HASH_TOKEN_LOOP
CMD_HASH_TOKEN_DONE:
                        LDA             CMDP_START_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_PTR_HI
                        JSR             CMD_SAVE_HASH
                        RTS

CMD_SAVE_HASH:
                        LDX             #$03
CMD_SAVE_HASH_LOOP:
                        LDA             FNV_HASH0,X
                        STA             CMD_EXEC_HASH0,X
                        DEX
                        BPL             CMD_SAVE_HASH_LOOP
                        RTS

CMD_DISPATCH_HASH:
                        JSR             CMD_HASH_SCAN_INIT
CMD_DISPATCH_SCAN_LOOP:
                        JSR             CMD_HASH_SCAN_NEXT_RECORD
                        BCC             CMD_DISPATCH_SCAN_MISS
                        JSR             CMD_HASH_RECORD_MATCH
                        BCC             CMD_DISPATCH_SCAN_NEXT
                        JSR             CMD_HASH_RECORD_IS_EXEC
                        BCC             CMD_DISPATCH_SCAN_NEXT
                        JSR             CMD_HASH_RECORD_ENTRY
                        JSR             CMD_HASH_CONFIRM_EXEC
                        BCC             CMD_DISPATCH_DONE
                        JSR             CMD_SAVE_ENTRY
                        STZ             CMD_EXEC_KIND
                        JSR             CMD_EXEC_ADDR
CMD_DISPATCH_DONE:
                        JMP             MAIN_LOOP
CMD_DISPATCH_SCAN_NEXT:
                        JSR             CMD_HASH_SCAN_ADV
                        BRA             CMD_DISPATCH_SCAN_LOOP
CMD_DISPATCH_SCAN_MISS:
                        JSR             MON_PRINT_HASH
                        LDX             #<MSG_HASH_NF
                        LDY             #>MSG_HASH_NF
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; THE_JOIN_EXEC_XY / THE_JOIN_EXEC -- resident executable-record join.
; IN : THE_JOIN_EXEC_XY: X/Y = pointer to little-endian hash32 bytes.
;      THE_JOIN_EXEC:    FNV_HASH0..3 = wanted hash.
; OUT: C=1 executable found, X/Y and CMDP_ADDR_LO/HI = entry,
;      CMD_HASH_EXTRA_LO/HI = extra pointer or $0000.
;      C=0 not found or not executable.
; ----------------------------------------------------------------------------
THE_JOIN_EXEC_XY_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$F7,$15,$AF,$A9,CMD_HASH_KIND_EXEC_TEXT ; THE_JOIN_EXEC_XY $A9AF15F7 EXEC+TEXT
                        DW              THE_JOIN_EXEC_XY
                        DW              TXT_THE_JOIN_EXEC_XY
THE_JOIN_EXEC_XY:
                        JSR             THE_JOIN_LOAD_HASH_XY
THE_JOIN_EXEC:
                        JSR             CMD_HASH_SCAN_INIT
THE_JOIN_EXEC_LOOP:
                        JSR             CMD_HASH_SCAN_NEXT_RECORD
                        BCC             THE_JOIN_EXEC_FAIL
                        JSR             CMD_HASH_RECORD_MATCH
                        BCC             THE_JOIN_EXEC_NEXT
                        JSR             CMD_HASH_RECORD_IS_EXEC
                        BCC             THE_JOIN_EXEC_NEXT
                        JSR             CMD_HASH_RECORD_ENTRY
                        JSR             CMD_HASH_RECORD_EXTRA
                        LDX             CMDP_ADDR_LO
                        LDY             CMDP_ADDR_HI
                        SEC
                        RTS
THE_JOIN_EXEC_NEXT:
                        JSR             CMD_HASH_SCAN_ADV
                        BRA             THE_JOIN_EXEC_LOOP
THE_JOIN_EXEC_FAIL:
                        CLC
                        RTS

THE_JOIN_LOAD_HASH_XY:
                        STX             CMDP_ADDR_LO
                        STY             CMDP_ADDR_HI
                        LDY             #$03
THE_JOIN_LOAD_HASH_LOOP:
                        LDA             (CMDP_ADDR_LO),Y
                        STA             FNV_HASH0,Y
                        DEY
                        BPL             THE_JOIN_LOAD_HASH_LOOP
                        RTS

; ----------------------------------------------------------------------------
; THE_JOIN_FIND -- resident FNV record lookup.
; IN : FNV_HASH0..3 = wanted hash.
; OUT: C=1 found, A=kind, CMDP_ADDR_LO/HI=entry,
;      CMD_HASH_EXTRA_LO/HI=extra pointer or $0000.
;      C=0 not found.
; ----------------------------------------------------------------------------
THE_JOIN_FIND:
CMD_HASH_FIND:
                        JSR             CMD_HASH_SCAN_INIT
THE_JOIN_FIND_LOOP:
CMD_HASH_FIND_LOOP:
                        JSR             CMD_HASH_SCAN_NEXT_RECORD
                        BCC             CMD_HASH_FIND_FAIL
                        JSR             CMD_HASH_RECORD_MATCH
                        BCC             CMD_HASH_FIND_NEXT
                        JSR             CMD_HASH_RECORD_ENTRY
                        JSR             CMD_HASH_RECORD_EXTRA
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        SEC
                        RTS
THE_JOIN_FIND_NEXT:
CMD_HASH_FIND_NEXT:
                        JSR             CMD_HASH_SCAN_ADV
                        BRA             THE_JOIN_FIND_LOOP
THE_JOIN_FIND_FAIL:
CMD_HASH_FIND_FAIL:
                        STZ             CMD_HASH_EXTRA_LO
                        STZ             CMD_HASH_EXTRA_HI
                        CLC
                        RTS

CMD_HASH_SCAN_INIT:
                        STZ             CMD_HASH_TAB_LO
                        LDA             #CMD_HASH_SCAN_BASE_HI
                        STA             CMD_HASH_TAB_HI
                        RTS

CMD_HASH_SCAN_END:
                        LDA             CMD_HASH_TAB_HI
                        CMP             #$FF
                        BNE             CMD_HASH_SCAN_NOT_END
                        LDA             CMD_HASH_TAB_LO
                        CMP             #$F8
                        BCS             CMD_HASH_SCAN_AT_END
CMD_HASH_SCAN_NOT_END:
                        CLC
                        RTS
CMD_HASH_SCAN_AT_END:
                        SEC
                        RTS

CMD_HASH_SCAN_ADV:
                        INC             CMD_HASH_TAB_LO
                        BNE             CMD_HASH_SCAN_ADV_SAME
                        INC             CMD_HASH_TAB_HI
                        SEC
                        RTS
CMD_HASH_SCAN_ADV_SAME:
                        CLC
                        RTS

CMD_HASH_SCAN_NEXT_RECORD:
                        JSR             CMD_HASH_SCAN_END
                        BCS             CMD_HASH_SCAN_NEXT_RECORD_FAIL
                        JSR             CMD_HASH_IS_RECORD
                        BCS             CMD_HASH_SCAN_NEXT_RECORD_FOUND
                        JSR             CMD_HASH_SCAN_ADV
                        BRA             CMD_HASH_SCAN_NEXT_RECORD
CMD_HASH_SCAN_NEXT_RECORD_FOUND:
                        SEC
                        RTS
CMD_HASH_SCAN_NEXT_RECORD_FAIL:
                        CLC
                        RTS

CMD_HASH_IS_RECORD:
                        LDY             #$00
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #'F'
                        BNE             CMD_HASH_IS_RECORD_NO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #'N'
                        BNE             CMD_HASH_IS_RECORD_NO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #CMD_FNV_SIG2
                        BNE             CMD_HASH_IS_RECORD_NO
                        SEC
                        RTS
CMD_HASH_IS_RECORD_NO:
                        CLC
                        RTS

CMD_HASH_RECORD_MATCH:
                        LDY             #$03
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             FNV_HASH0
                        BNE             CMD_HASH_RECORD_MATCH_NO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             FNV_HASH1
                        BNE             CMD_HASH_RECORD_MATCH_NO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             FNV_HASH2
                        BNE             CMD_HASH_RECORD_MATCH_NO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             FNV_HASH3
                        BNE             CMD_HASH_RECORD_MATCH_NO
                        SEC
                        RTS
CMD_HASH_RECORD_MATCH_NO:
                        CLC
                        RTS

CMD_HASH_RECORD_IS_EXEC:
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        LSR             A
                        RTS

CMD_HASH_RECORD_ENTRY:
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #CMD_HASH_KIND_EXEC_CONFIRM_TEXT
                        BEQ             CMD_HASH_RECORD_ENTRY_PTR
                        CMP             #CMD_HASH_KIND_EXEC_TEXT
                        BEQ             CMD_HASH_RECORD_ENTRY_PTR
                        CLC
                        LDA             CMD_HASH_TAB_LO
                        ADC             #$08
                        STA             CMDP_ADDR_LO
                        LDA             CMD_HASH_TAB_HI
                        ADC             #$00
                        STA             CMDP_ADDR_HI
                        RTS
CMD_HASH_RECORD_ENTRY_PTR:
                        LDY             #$08
                        LDA             (CMD_HASH_TAB_LO),Y
                        STA             CMDP_ADDR_LO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        STA             CMDP_ADDR_HI
                        RTS

CMD_HASH_RECORD_EXTRA:
                        STZ             CMD_HASH_EXTRA_LO
                        STZ             CMD_HASH_EXTRA_HI
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #CMD_HASH_KIND_EXEC_CONFIRM_TEXT
                        BEQ             CMD_HASH_RECORD_EXTRA_PTR
                        CMP             #CMD_HASH_KIND_EXEC_TEXT
                        BNE             CMD_HASH_RECORD_EXTRA_DONE
CMD_HASH_RECORD_EXTRA_PTR:
                        LDY             #$0A
                        LDA             (CMD_HASH_TAB_LO),Y
                        STA             CMD_HASH_EXTRA_LO
                        INY
                        LDA             (CMD_HASH_TAB_LO),Y
                        STA             CMD_HASH_EXTRA_HI
CMD_HASH_RECORD_EXTRA_DONE:
                        RTS

CMD_HASH_RECORD_IN_FILTER:
                        LDA             CMD_HASH_FILTER_OP
                        BEQ             CMD_HASH_RECORD_FILTER_YES
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        TAX
                        LDA             CMD_HASH_FILTER_OP
                        CMP             #'='
                        BEQ             CMD_HASH_RECORD_FILTER_EQ
                        CMP             #'<'
                        BEQ             CMD_HASH_RECORD_FILTER_LT
                        CMP             #'>'
                        BEQ             CMD_HASH_RECORD_FILTER_GT
CMD_HASH_RECORD_FILTER_YES:
                        SEC
                        RTS
CMD_HASH_RECORD_FILTER_EQ:
                        TXA
                        CMP             CMD_HASH_FILTER_VALUE
                        BEQ             CMD_HASH_RECORD_FILTER_YES
                        CLC
                        RTS
CMD_HASH_RECORD_FILTER_LT:
                        TXA
                        CMP             CMD_HASH_FILTER_VALUE
                        BCC             CMD_HASH_RECORD_FILTER_YES
                        CLC
                        RTS
CMD_HASH_RECORD_FILTER_GT:
                        TXA
                        CMP             CMD_HASH_FILTER_VALUE
                        BEQ             CMD_HASH_RECORD_FILTER_NO
                        BCS             CMD_HASH_RECORD_FILTER_YES
CMD_HASH_RECORD_FILTER_NO:
                        CLC
                        RTS

CMD_HASH_CONFIRM_EXEC:
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        CMP             #CMD_HASH_KIND_EXEC_CONFIRM_TEXT
                        BEQ             CMD_HASH_CONFIRM_ASK
                        SEC
                        RTS
CMD_HASH_CONFIRM_ASK:
                        LDX             #<MSG_RUN
                        LDY             #>MSG_RUN
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_RECORD_EXTRA
                        LDA             CMD_HASH_EXTRA_LO
                        ORA             CMD_HASH_EXTRA_HI
                        BEQ             CMD_HASH_CONFIRM_TOKEN
                        LDX             CMD_HASH_EXTRA_LO
                        LDY             CMD_HASH_EXTRA_HI
                        JSR             HIM_WRITE_HBSTRING
                        BRA             CMD_HASH_CONFIRM_ADDR
CMD_HASH_CONFIRM_TOKEN:
                        JSR             CMD_HASH_PRINT_TOKEN_RAW
CMD_HASH_CONFIRM_ADDR:
                        LDX             #<MSG_RUN_AT
                        LDY             #>MSG_RUN_AT
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_PRINT_ENTRY
                        LDX             #<MSG_HASH_K
                        LDY             #>MSG_HASH_K
                        JSR             HIM_WRITE_HBSTRING
                        JSR             CMD_HASH_PRINT_KIND
                        LDX             #<MSG_RUN_Q
                        LDY             #>MSG_RUN_Q
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_READ_CHAR_ECHO
                        JSR             HIM_CHAR_TO_UPPER
                        CMP             #'Y'
                        PHP
                        JSR             SYS_WRITE_CRLF
                        PLP
                        BEQ             CMD_HASH_CONFIRM_YES
                        CLC
                        RTS
CMD_HASH_CONFIRM_YES:
                        SEC
                        RTS

CMD_HASH_PRINT_ROW:
                        JSR             CMD_HASH_PRINT_RECORD_HASH
                        JSR             CMD_HASH_SPACE
                        JSR             CMD_HASH_RECORD_ENTRY
                        JSR             CMD_HASH_PRINT_ENTRY
                        JSR             CMD_HASH_SPACE
                        JSR             CMD_HASH_PRINT_KIND
                        JSR             CMD_HASH_PRINT_EXTRA
                        JSR             SYS_WRITE_CRLF
                        RTS

CMD_HASH_PRINT_FNV:
                        LDA             FNV_HASH3
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH2
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH1
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH0
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

CMD_HASH_PRINT_RECORD_HASH:
                        LDY             #$06
                        LDA             (CMD_HASH_TAB_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDY             #$05
                        LDA             (CMD_HASH_TAB_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDY             #$04
                        LDA             (CMD_HASH_TAB_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        LDY             #$03
                        LDA             (CMD_HASH_TAB_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

CMD_HASH_PRINT_ENTRY:
                        LDA             CMDP_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             CMDP_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

CMD_HASH_PRINT_KIND:
                        LDY             #$07
                        LDA             (CMD_HASH_TAB_LO),Y
                        JSR             SYS_WRITE_HEX_BYTE
                        RTS

CMD_HASH_PRINT_EXTRA:
                        JSR             CMD_HASH_RECORD_EXTRA
                        LDA             CMD_HASH_EXTRA_LO
                        ORA             CMD_HASH_EXTRA_HI
                        BEQ             CMD_HASH_PRINT_EXTRA_DONE
                        JSR             CMD_HASH_SPACE
                        LDX             CMD_HASH_EXTRA_LO
                        LDY             CMD_HASH_EXTRA_HI
                        JSR             HIM_WRITE_HBSTRING
CMD_HASH_PRINT_EXTRA_DONE:
                        RTS

CMD_HASH_PRINT_TOKEN:
                        JSR             CMD_HASH_SPACE
CMD_HASH_PRINT_TOKEN_RAW:
                        LDY             #$00
CMD_HASH_PRINT_TOKEN_LOOP:
                        LDA             (CMDP_PTR_LO),Y
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCS             CMD_HASH_PRINT_TOKEN_DONE
                        LDA             (CMDP_PTR_LO),Y
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        INY
                        BRA             CMD_HASH_PRINT_TOKEN_LOOP
CMD_HASH_PRINT_TOKEN_DONE:
                        RTS

CMD_HASH_SPACE:
                        LDA             #' '
                        JMP             BIO_FTDI_WRITE_BYTE_BLOCK

CMD_SAVE_ENTRY:
                        LDA             CMDP_ADDR_LO
                        STA             CMD_EXEC_ENTRY_LO
                        LDA             CMDP_ADDR_HI
                        STA             CMD_EXEC_ENTRY_HI
                        RTS

CMD_EXEC_ADDR:
                        JSR             CMD_CALL_ADDR
                        PHP
                        PHA
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BEQ             CMD_EXEC_ADDR_KEEP_TRAP
                        LDA             CMD_EXEC_KIND
                        BEQ             CMD_EXEC_ADDR_KEEP_TRAP
                        PLA
                        STA             NMI_CTX_A
                        STX             NMI_CTX_X
                        STY             NMI_CTX_Y
                        PLA
                        STA             NMI_CTX_P
                        TSX
                        STX             NMI_CTX_S
                        LDA             CMD_EXEC_ENTRY_LO
                        STA             NMI_CTX_PCL
                        LDA             CMD_EXEC_ENTRY_HI
                        STA             NMI_CTX_PCH
                        JSR             MON_PRINT_RET_AND_REGS
                        RTS
CMD_EXEC_ADDR_KEEP_TRAP:
                        PLA
                        PLP
                        BCS             CMD_EXEC_ADDR_DONE
                        CMP             #$00
                        BEQ             CMD_EXEC_ADDR_DONE
                        LDX             CMD_EXEC_KIND
                        BNE             CMD_EXEC_ADDR_DONE
                        LDX             CMD_EXEC_ENTRY_HI
                        CPX             #$C0
                        BCS             CMD_EXEC_ADDR_DONE
                        JSR             CMD_EXEC_PRINT_FAIL
CMD_EXEC_ADDR_DONE:
                        RTS

CMD_CALL_ADDR:
                        JMP             (CMDP_ADDR_LO)

CMD_EXEC_PRINT_FAIL:
                        PHA
                        JSR             MON_PRINT_HASH
                        LDX             #<MSG_EXEC_ERR
                        LDY             #>MSG_EXEC_ERR
                        JSR             HIM_WRITE_HBSTRING
                        PLA
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

FNV1A_INIT_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$1E,$EE,$9A,$4B,CMD_HASH_KIND_EXEC_TEXT ; FNV1A_INIT $4B9AEE1E EXEC+TEXT
                        DW              FNV1A_INIT
                        DW              TXT_FNV1A_INIT
FNV1A_INIT:
                        LDX             #$03
FNV1A_INIT_LOOP:
                        LDA             FNV1A_OFFSET_BASIS,X
                        STA             FNV_HASH0,X
                        DEX
                        BPL             FNV1A_INIT_LOOP
                        RTS

FNV1A_OFFSET_BASIS:
                        DB              $C5,$9D,$1C,$81

FNV1A_UPDATE_A:
                        EOR             FNV_HASH0
                        STA             FNV_HASH0
                        JMP             FNV1A_MUL_PRIME

FNV1A_MUL_PRIME:
                        JSR             MATH_COPY_HASH_TO_TERM
                        LDX             #$01
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$03
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$03
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$01
                        JSR             MATH_SHLADD_TERM_N
                        JMP             MATH_ADD_TERM1_TO_HASH3

MATH_COPY_HASH_TO_TERM:
                        LDX             #$03
MATH_COPY_HASH_LOOP:
                        LDA             FNV_HASH0,X
                        STA             FNV_TERM0,X
                        DEX
                        BPL             MATH_COPY_HASH_LOOP
                        RTS

MATH_SHLADD_TERM_N:
                        JSR             MATH_SHL_TERM_N
                        JMP             MATH_ADD_TERM_TO_HASH

MATH_SHL_TERM_N:
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        DEX
                        BNE             MATH_SHL_TERM_N
                        RTS

MATH_ADD_TERM_TO_HASH:
                        CLC
                        LDA             FNV_HASH0
                        ADC             FNV_TERM0
                        STA             FNV_HASH0
                        LDA             FNV_HASH1
                        ADC             FNV_TERM1
                        STA             FNV_HASH1
                        LDA             FNV_HASH2
                        ADC             FNV_TERM2
                        STA             FNV_HASH2
                        LDA             FNV_HASH3
                        ADC             FNV_TERM3
                        STA             FNV_HASH3
                        RTS

MATH_ADD_TERM1_TO_HASH3:
                        LDA             FNV_HASH3
                        CLC
                        ADC             FNV_TERM1
                        STA             FNV_HASH3
                        RTS

; Fast drop-in FNV-1a byte update. The original update/multiply path above
; stays resident; this one only expands the fixed 1,3,3,1 shift pattern.
; Tradeoff: spend a few ROM bytes to reduce software multiply loop overhead.
FNV1A_UPDATE_A_FAST_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$14,$23,$80,$A8,CMD_HASH_KIND_EXEC_TEXT ; FNV1A_UPDATE_A_FAST $A8802314 EXEC+TEXT
                        DW              FNV1A_UPDATE_A_FAST
                        DW              TXT_FNV1A_UPDATE_A_FAST
FNV1A_UPDATE_A_FAST:
                        EOR             FNV_HASH0
                        STA             FNV_HASH0
                        JMP             FNV1A_MUL_PRIME_FAST

FNV1A_MUL_PRIME_FAST:
                        JSR             MATH_COPY_HASH_TO_TERM

                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        JSR             MATH_ADD_TERM_TO_HASH

                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        JSR             MATH_ADD_TERM_TO_HASH

                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        JSR             MATH_ADD_TERM_TO_HASH

                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        JSR             MATH_ADD_TERM_TO_HASH
                        JMP             MATH_ADD_TERM1_TO_HASH3

; ----------------------------------------------------------------------------
; Scanner / parser helpers
; ----------------------------------------------------------------------------
CMD_REQUIRE_EOL:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_REQUIRE_EOL_OK
                        CLC
                        RTS
CMD_REQUIRE_EOL_OK:
                        SEC
                        RTS

CMD_SKIP_SPACES:
                        JSR             CMD_PEEK
                        CMP             #' '
                        BEQ             CMD_SKIP_SPACES_ADV
                        CMP             #$09
                        BEQ             CMD_SKIP_SPACES_ADV
                        RTS
CMD_SKIP_SPACES_ADV:
                        JSR             CMD_ADV_PTR
                        BRA             CMD_SKIP_SPACES

CMD_PEEK:
                        LDY             #$00
                        LDA             (CMDP_PTR_LO),Y
                        RTS

CMD_ADV_PTR:
                        INC             CMDP_PTR_LO
                        BNE             CMD_ADV_PTR_DONE
                        INC             CMDP_PTR_HI
CMD_ADV_PTR_DONE:
                        RTS

CMD_PARSE_HEX_WORD_TOKEN:
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_SKIP_OPTIONAL_DOLLAR
                        STZ             CMDP_ADDR_HI
                        STZ             CMDP_ADDR_LO
                        STZ             CMDP_TOKEN_LEN
CMD_PARSE_HEX_WORD_LOOP:
                        JSR             CMD_PEEK
                        JSR             CMD_HEX_ASCII_TO_NIBBLE
                        BCC             CMD_PARSE_HEX_WORD_DONE
                        STA             CMDP_NIB_HI
                        LDA             CMDP_TOKEN_LEN
                        CMP             #$04
                        BCS             CMD_PARSE_HEX_WORD_FAIL
                        INC             CMDP_TOKEN_LEN

                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI
                        ASL             CMDP_ADDR_LO
                        ROL             CMDP_ADDR_HI

                        LDA             CMDP_ADDR_LO
                        ORA             CMDP_NIB_HI
                        STA             CMDP_ADDR_LO
                        JSR             CMD_ADV_PTR
                        BRA             CMD_PARSE_HEX_WORD_LOOP
CMD_PARSE_HEX_WORD_DONE:
                        LDA             CMDP_TOKEN_LEN
                        BEQ             CMD_PARSE_HEX_WORD_FAIL
                        JSR             CMD_PEEK
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCS             CMD_PARSE_HEX_WORD_OK
                        JSR             CMD_PEEK
                        CMP             #'+'
                        BNE             CMD_PARSE_HEX_WORD_FAIL
CMD_PARSE_HEX_WORD_OK:
                        SEC
                        RTS
CMD_PARSE_HEX_WORD_FAIL:
                        CLC
                        RTS

CMD_PARSE_HEX_BYTE_TOKEN:
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCC             CMD_PARSE_HEX_BYTE_TOKEN_FAIL
                        LDA             CMDP_ADDR_HI
                        BNE             CMD_PARSE_HEX_BYTE_TOKEN_FAIL
                        LDA             CMDP_ADDR_LO
                        SEC
                        RTS
CMD_PARSE_HEX_BYTE_TOKEN_FAIL:
                        CLC
                        RTS

CMD_SKIP_OPTIONAL_DOLLAR:
                        JSR             CMD_PEEK
                        CMP             #'$'
                        BNE             CMD_SKIP_OPTIONAL_DOLLAR_DONE
                        JSR             CMD_ADV_PTR
CMD_SKIP_OPTIONAL_DOLLAR_DONE:
                        RTS

CMD_IS_DELIM_OR_NUL:
                        CMP             #$00
                        BEQ             CMD_IS_DELIM_TRUE
                        CMP             #' '
                        BEQ             CMD_IS_DELIM_TRUE
                        CMP             #$09
                        BEQ             CMD_IS_DELIM_TRUE
                        CLC
                        RTS
CMD_IS_DELIM_TRUE:
                        SEC
                        RTS

CMD_HEX_ASCII_TO_NIBBLE:
                        CMP             #'0'
                        BCC             CMD_HXN_BAD
                        CMP             #':'
                        BCC             CMD_HXN_DIGIT
                        CMP             #'A'
                        BCC             CMD_HXN_CHECK_LOWER
                        CMP             #'G'
                        BCC             CMD_HXN_UPPER
CMD_HXN_CHECK_LOWER:
                        CMP             #'a'
                        BCC             CMD_HXN_BAD
                        CMP             #'g'
                        BCS             CMD_HXN_BAD
                        SEC
                        SBC             #$57
                        SEC
                        RTS
CMD_HXN_UPPER:
                        SEC
                        SBC             #$37
                        SEC
                        RTS
CMD_HXN_DIGIT:
                        SEC
                        SBC             #'0'
                        SEC
                        RTS
CMD_HXN_BAD:
                        CLC
                        RTS

                        INCLUDE         "HIMON/himon-bootlog.inc"

                        DATA
HIM_FNV_FORCE_RESIDENT:
                        DW              SYS_READ_CHAR
                        DW              SYS_READ_CHAR_ECHO
                        DW              SYS_READ_CHAR_COOKED_ECHO
                        DW              SYS_GET_CTRL_C
                        DW              UTL_HEX_ASCII_TO_NIBBLE

SYS_READ_CSTRING_ECHO_UPPER_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$AF,$10,$DD,$E2,CMD_HASH_KIND_EXEC_TEXT ; SYS_READ_CSTRING_ECHO_UPPER $E2DD10AF EXEC+TEXT
                        DW              HIM_READ_LINE_ECHO_UPPER
                        DW              TXT_SYS_READ_CSTRING_ECHO_UPPER

BIO_FTDI_PUT_CSTR_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$42,$0F,$FA,$AE,CMD_HASH_KIND_EXEC_TEXT ; BIO_FTDI_PUT_CSTR $AEFA0F42 EXEC+TEXT
                        DW              SYS_WRITE_CSTRING
                        DW              TXT_BIO_FTDI_PUT_CSTR

HIMON_VERSION_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$80,$1A,$05,$B0,CMD_HASH_KIND_EXEC_CONFIRM_TEXT ; HIMON $B0051A80 EXEC+CONFIRM
                        DW              START
                        DW              MSG_HIMON_VERSION_HASH_TEXT

CMD_STR8_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$18,$0E,$AD,$A2,CMD_HASH_KIND_EXEC_CONFIRM_TEXT ; STR8 $A2AD0E18 EXEC+CONFIRM+TEXT
                        DW              $F000
                        DW              TXT_STR8

MSG_BANNER:              DB              $0D,$0A
                        INCLUDE         "himon-version.inc"
TXT_BOOT_COLD_RESET:     DB              "BOOT_COLD_RESE",('T'+$80)
TXT_BOOT_WARM_RESET:     DB              "BOOT_WARM_RESE",('T'+$80)
TXT_CMD_QUOTE_HASH:      DB              $22,"[TEXT]",$22
                        DB              " -> #5F6A0F7A# STR8 MATCH",('!'+$80)
TXT_THE_JOIN_EXEC_XY:    DB              "HASH ACQUIR",('E'+$80)
TXT_FNV1A_INIT:          DB              "HASH OPE",('N'+$80)
TXT_FNV1A_UPDATE_A_FAST: DB              "HASH MI",('X'+$80)
TXT_SYS_READ_CSTRING_ECHO_UPPER:
                        DB              "READ LIN",('E'+$80)
TXT_BIO_FTDI_PUT_CSTR:   DB              "PUT CST",('R'+$80)
TXT_STR8:                DB              "STR8: BOOTLOADE",('R'+$80)
MSG_PROMPT:              DB              ('>'+$80)
MSG_UNKNOWN:             DB              ('?'+$80)
MSG_HASH_NF:             DB              " HSH_NF",('!'+$80)
MSG_HASH_HDR:            DB              "HASH     ENTRY K TEX",('T'+$80)
MSG_HASH_ENTRY:          DB              " ENTRY",('='+$80)
MSG_HASH_K:              DB              " K",('='+$80)
MSG_EXEC_ERR:            DB              " EXEC ERR=",('$'+$80)
MSG_HASH_USAGE:          DB              "# [K=hh|K<hh|K>hh|token",(']'+$80)
MSG_RUN:                 DB              "RUN",(' '+$80)
MSG_RUN_AT:              DB              " ",('@'+$80)
MSG_RUN_Q:               DB              " ?",(' '+$80)
MSG_D_IO_CS0:            DB              "CS0      IO SKI",('P'+$80)
MSG_D_IO_CS1:            DB              "CS1      IO SKI",('P'+$80)
MSG_D_IO_CS2:            DB              "CS2      IO SKI",('P'+$80)
MSG_D_IO_CS3:            DB              "CS3      IO SKI",('P'+$80)
MSG_D_IO_ACIA:           DB              "ACIA     IO SKI",('P'+$80)
MSG_D_IO_PIA:            DB              "PIA      IO SKI",('P'+$80)
MSG_D_IO_VIA:            DB              "VIA      IO SKI",('P'+$80)
MSG_D_IO_FTDI:           DB              "FTDI VIA IO SKI",('P'+$80)
MSG_SEARCH_USAGE:        DB              "S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUI",('T'+$80)
MSG_SEARCH_NF:           DB              "S N",('F'+$80)
MSG_SEARCH_ABORT:        DB              "S ABOR",('T'+$80)
MSG_SEARCH_EXTRA:        DB              "S: SEARCH FROM RAM TO HASHED HIMON CM",('D'+$80)
MSG_HELP:                DB              "# ? S D M R X G L B N Q ",$22," STR",('8'+$80)
MSG_QUOTE_MATCH:         DB              " STR8 MATCH",('!'+$80)
MSG_USAGE_D:             DB              "D start [end|+cnt",(']'+$80)
MSG_USAGE_M:             DB              "M start [end|+cnt]",('.'+$80)
MSG_M_PROTECT:           DB              "M PROT=",('$'+$80)
MSG_USAGE_R:             DB              "R reg",('s'+$80)
MSG_USAGE_X:             DB              "X reg",('s'+$80)
MSG_USAGE_G:             DB              "G ",('a'+$80)
MSG_USAGE_L:             DB              "L [G|F]",(' '+$80)
MSG_NOCTX:               DB              "NOCT",('X'+$80)
MSG_RESUME:              DB              "RESUME",(' '+$80)
MSG_GO:                  DB              "GO",(' '+$80)
MSG_L_READY:             DB              "L S1",('9'+$80)
MSG_LF_READY:            DB              "L F S1",('9'+$80)
MSG_L_STATUS:            DB              "L",('S'+$80)
MSG_L_ERR:               DB              "LERR=",('$'+$80)
MSG_L_DONE:              DB              "L OK",('='+$80)
MSG_LF_DONE:             DB              "LF OK WR",('='+$80)
MSG_LF_FAIL_DONE:        DB              "LF FAIL",('='+$80)
MSG_L_WR:                DB              " WR",('='+$80)
MSG_L_SKIP:              DB              " SKIP",('='+$80)
MSG_L_GO:                DB              " GO",('='+$80)
MSG_LF_PROTECT:          DB              "LF PROT",('='+$80)
MSG_LF_ERASE:            DB              "LF ERASE",('='+$80)
MSG_LF_WRITE:            DB              "LF WFAIL",('='+$80)
MSG_L_OLD:               DB              " OLD",('='+$80)
MSG_L_NEW:               DB              " NEW",('='+$80)
MSG_L_WANT:              DB              " WANT",('='+$80)
MSG_L_READ:              DB              " READ",('='+$80)
MSG_STOP_NMI:            DB              "NMI PC",('='+$80)
MSG_STOP_BRK:            DB              "BRK",(' '+$80)
MSG_STOP_PC:             DB              " PC",('='+$80)
MSG_ENTRY:               DB              " ENTRY",('='+$80)
MSG_RET:                 DB              "RET",(' '+$80)
MSG_BOX_GO:              DB              "G",('O'+$80)
MSG_BOX_LOADGO:          DB              "LOADG",('O'+$80)
MSG_REG_A:               DB              "A",('='+$80)
MSG_REG_X:               DB              " X",('='+$80)
MSG_REG_Y:               DB              " Y",('='+$80)
MSG_REG_P:               DB              " P",('='+$80)
MSG_REG_S:               DB              " S",('='+$80)
MSG_USAGE_B:             DB              "B start",(']'+$80)
MSG_USAGE_BC:            DB              "B C start",(']'+$80)
MSG_USAGE_BL:            DB              "B ",('L'+$80)
MSG_USAGE_N:             DB              ('N'+$80)
MSG_BP_SET:              DB              "BP ",('$'+$80)
MSG_BP_CLR:              DB              "B C ",('$'+$80)
MSG_BP_FULL:             DB              "BP FUL",('L'+$80)
MSG_BP_NF:               DB              "BP N",('F'+$80)
MSG_DBG_RAM:             DB              "DBG RA",('M'+$80)
MSG_STEP:                DB              "STEP PC",('='+$80)
MSG_STEP_OP:             DB              " OP",('='+$80)
MSG_STEP_SIG:            DB              " SIG",('='+$80)
MSG_STEP_LEN:            DB              " LEN",('='+$80)
MSG_STEP_NEXT:           DB              " NEXT",('='+$80)
MSG_STEP_BP:             DB              " B",('P'+$80)

ASM_MNEM_NAMES:
                        DB              'B','R',('K'+$80),$80,'O','R',('A'+$80),$80,'T','S',('B'+$80),$80,'A','S',('L'+$80),$80,'R','M','B',('0'+$80),'P','H',('P'+$80),$80,'B','B','R',('0'+$80),'B','P',('L'+$80),$80
                        DB              'T','R',('B'+$80),$80,'R','M','B',('1'+$80),'C','L',('C'+$80),$80,'I','N',('C'+$80),$80,'B','B','R',('1'+$80),'J','S',('R'+$80),$80,'A','N',('D'+$80),$80,'B','I',('T'+$80),$80
                        DB              'R','O',('L'+$80),$80,'R','M','B',('2'+$80),'P','L',('P'+$80),$80,'B','B','R',('2'+$80),'B','M',('I'+$80),$80,'R','M','B',('3'+$80),'S','E',('C'+$80),$80,'D','E',('C'+$80),$80
                        DB              'B','B','R',('3'+$80),'R','T',('I'+$80),$80,'E','O',('R'+$80),$80,'L','S',('R'+$80),$80,'R','M','B',('4'+$80),'P','H',('A'+$80),$80,'J','M',('P'+$80),$80,'B','B','R',('4'+$80)
                        DB              'B','V',('C'+$80),$80,'R','M','B',('5'+$80),'C','L',('I'+$80),$80,'P','H',('Y'+$80),$80,'B','B','R',('5'+$80),'R','T',('S'+$80),$80,'A','D',('C'+$80),$80,'S','T',('Z'+$80),$80
                        DB              'R','O',('R'+$80),$80,'R','M','B',('6'+$80),'P','L',('A'+$80),$80,'B','B','R',('6'+$80),'B','V',('S'+$80),$80,'R','M','B',('7'+$80),'S','E',('I'+$80),$80,'P','L',('Y'+$80),$80
                        DB              'B','B','R',('7'+$80),'B','R',('A'+$80),$80,'S','T',('A'+$80),$80,'S','T',('Y'+$80),$80,'S','T',('X'+$80),$80,'S','M','B',('0'+$80),'D','E',('Y'+$80),$80,'T','X',('A'+$80),$80
                        DB              'B','B','S',('0'+$80),'B','C',('C'+$80),$80,'S','M','B',('1'+$80),'T','Y',('A'+$80),$80,'T','X',('S'+$80),$80,'B','B','S',('1'+$80),'L','D',('Y'+$80),$80,'L','D',('A'+$80),$80
                        DB              'L','D',('X'+$80),$80,'S','M','B',('2'+$80),'T','A',('Y'+$80),$80,'T','A',('X'+$80),$80,'B','B','S',('2'+$80),'B','C',('S'+$80),$80,'S','M','B',('3'+$80),'C','L',('V'+$80),$80
                        DB              'T','S',('X'+$80),$80,'B','B','S',('3'+$80),'C','P',('Y'+$80),$80,'C','M',('P'+$80),$80,'S','M','B',('4'+$80),'I','N',('Y'+$80),$80,'D','E',('X'+$80),$80,'W','A',('I'+$80),$80
                        DB              'B','B','S',('4'+$80),'B','N',('E'+$80),$80,'S','M','B',('5'+$80),'C','L',('D'+$80),$80,'P','H',('X'+$80),$80,'S','T',('P'+$80),$80,'B','B','S',('5'+$80),'C','P',('X'+$80),$80
                        DB              'S','B',('C'+$80),$80,'S','M','B',('6'+$80),'I','N',('X'+$80),$80,'N','O',('P'+$80),$80,'B','B','S',('6'+$80),'B','E',('Q'+$80),$80,'S','M','B',('7'+$80),'S','E',('D'+$80),$80
                        DB              'P','L',('X'+$80),$80,'B','B','S',('7'+$80)

ASM_OP_MNEM_ID:
                        DB              $01,$02,$00,$00,$03,$02,$04,$05
                        DB              $06,$02,$04,$00,$03,$02,$04,$07
                        DB              $08,$02,$02,$00,$09,$02,$04,$0A
                        DB              $0B,$02,$0C,$00,$09,$02,$04,$0D
                        DB              $0E,$0F,$00,$00,$10,$0F,$11,$12
                        DB              $13,$0F,$11,$00,$10,$0F,$11,$14
                        DB              $15,$0F,$0F,$00,$10,$0F,$11,$16
                        DB              $17,$0F,$18,$00,$10,$0F,$11,$19
                        DB              $1A,$1B,$00,$00,$00,$1B,$1C,$1D
                        DB              $1E,$1B,$1C,$00,$1F,$1B,$1C,$20
                        DB              $21,$1B,$1B,$00,$00,$1B,$1C,$22
                        DB              $23,$1B,$24,$00,$00,$1B,$1C,$25
                        DB              $26,$27,$00,$00,$28,$27,$29,$2A
                        DB              $2B,$27,$29,$00,$1F,$27,$29,$2C
                        DB              $2D,$27,$27,$00,$28,$27,$29,$2E
                        DB              $2F,$27,$30,$00,$1F,$27,$29,$31
                        DB              $32,$33,$00,$00,$34,$33,$35,$36
                        DB              $37,$10,$38,$00,$34,$33,$35,$39
                        DB              $3A,$33,$33,$00,$34,$33,$35,$3B
                        DB              $3C,$33,$3D,$00,$28,$33,$28,$3E
                        DB              $3F,$40,$41,$00,$3F,$40,$41,$42
                        DB              $43,$40,$44,$00,$3F,$40,$41,$45
                        DB              $46,$40,$40,$00,$3F,$40,$41,$47
                        DB              $48,$40,$49,$00,$3F,$40,$41,$4A
                        DB              $4B,$4C,$00,$00,$4B,$4C,$18,$4D
                        DB              $4E,$4C,$4F,$50,$4B,$4C,$18,$51
                        DB              $52,$4C,$4C,$00,$00,$4C,$18,$53
                        DB              $54,$4C,$55,$56,$00,$4C,$18,$57
                        DB              $58,$59,$00,$00,$58,$59,$0C,$5A
                        DB              $5B,$59,$5C,$00,$58,$59,$0C,$5D
                        DB              $5E,$59,$59,$00,$00,$59,$0C,$5F
                        DB              $60,$59,$61,$00,$00,$59,$0C,$62

ASM_OP_LEN_PACK:
                        DB              $5A,$AA,$59,$FF,$6A,$AA,$5D,$FF
                        DB              $5B,$AA,$59,$FF,$6A,$AA,$5D,$FF
                        DB              $59,$A9,$59,$FF,$6A,$A9,$5D,$FD
                        DB              $59,$AA,$59,$FF,$6A,$AA,$5D,$FF
                        DB              $5A,$AA,$59,$FF,$6A,$AA,$5D,$FF
                        DB              $6A,$AA,$59,$FF,$6A,$AA,$5D,$FF
                        DB              $5A,$AA,$59,$FF,$6A,$A9,$5D,$FD
                        DB              $5A,$AA,$59,$FF,$6A,$A9,$5D,$FD

                        ENDMOD

                        END

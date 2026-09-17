CMD_AP_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$94,$37,$D5,$3A,CMD_HASH_KIND_EXEC ; AP $3AD53794 EXEC
CMD_AP:
                        JSR             CMD_ADV_PTR
                        JSR             CMD_ADV_PTR
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        CMP             #'B'
                        BEQ             CMD_AP_MANAGER
                        CMP             #'L'
                        BEQ             CMD_AP_MANAGER
                        CMP             #'D'
                        BEQ             CMD_AP_MANAGER
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCS             CMD_AP_SRC_OK
                        JMP             CMD_USAGE_AP
CMD_AP_SRC_OK:
                        LDA             CMDP_ADDR_LO
                        STA             HIM_AP_SRC_LO
                        LDA             CMDP_ADDR_HI
                        STA             HIM_AP_SRC_HI
                        JSR             CMD_PARSE_HEX_WORD_TOKEN
                        BCS             CMD_AP_DST_OK
                        JMP             CMD_USAGE_AP
CMD_AP_DST_OK:
                        JSR             CMD_REQUIRE_EOL
                        BCS             CMD_AP_EOL_OK
                        JMP             CMD_USAGE_AP
CMD_AP_EOL_OK:
                        LDA             CMDP_ADDR_LO
                        STA             HIM_AP_DST_LO
                        LDA             CMDP_ADDR_HI
                        STA             HIM_AP_DST_HI
CMD_AP_LOAD_REQUEST:
                        LDA             #HIM_AP_OP_TAKEOVER
                        STA             HIM_AP_OP
                        JSR             HIM_AP_SERVICE
                        BCS             CMD_AP_LOAD_OK
                        LDX             #<MSG_AP_ERR
                        JSR             HIM_WRITE_PAGE_TEXT
                        LDA             HIM_AP_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF
CMD_AP_LOAD_OK:
                        STX             CMDP_ADDR_LO
                        STY             CMDP_ADDR_HI
                        JMP             CMD_GO_ADDR

CMD_AP_MANAGER:         LDA             #APMAN_MODE_AP
                        STA             APMAN_MODE
                        JMP             HIM_APMAN_BOOTSTRAP

CMD_USAGE_AP:
                        LDX             #<MSG_USAGE_AP
                        LDY             #>MSG_USAGE_AP
                        JMP             HIM_WRITE_HBLINE

; ----------------------------------------------------------------------------
; APS -- AP Store V1 read-only sector-header inventory/status.
; Scans exactly Banks 0-2, sectors $8-$F.
; ----------------------------------------------------------------------------
CMD_APS_FNV:
                        DB              'F','N',CMD_FNV_SIG2,$45,$CE,$A6,$64,CMD_HASH_KIND_EXEC ; APS $64A6CE45 EXEC
CMD_APS:
                        LDA             #APMAN_MODE_APS
                        STA             APMAN_MODE
                        JMP             HIM_APMAN_BOOTSTRAP

                        IF              0
                        JSR             CMD_ADV_PTR
                        JSR             CMD_ADV_PTR
                        JSR             CMD_ADV_PTR
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_USAGE_APS

; The selector trampoline occupies $0200-$0228. Keep this relocatable reader
; above it and copy it only while Bank 3 is visible.
                        LDX             #HIM_APS_HEADER_READ_CODE_SIZE-1
?COPY_RAM:             LDA             HIM_APS_HEADER_READ_CODE,X
                        STA             HIM_APS_HEADER_READ_RAM,X
                        DEX
                        BPL             ?COPY_RAM

                        STZ             HIM_APS_BANK
                        LDA             #$80
                        STA             HIM_APS_SECTOR_HI
?READ:                 JSR             HIM_APS_HEADER_READ_RAM
                        BCC             ?IO_ERROR
                        JSR             HIM_APS_PRINT_ROW

                        LDA             HIM_APS_SECTOR_HI
                        CLC
                        ADC             #$10
                        BNE             ?NEXT_SECTOR
                        INC             HIM_APS_BANK
                        LDA             HIM_APS_BANK
                        CMP             #$03
                        BCS             ?DONE
                        LDA             #$80
?NEXT_SECTOR:          STA             HIM_APS_SECTOR_HI
                        BRA             ?READ
?DONE:                 LDX             #<MSG_APS_OK
                        LDY             #>MSG_APS_OK
                        JSR             HIM_WRITE_HBSTRING
                        JMP             SYS_WRITE_CRLF
?IO_ERROR:             JSR             HIM_APS_PACK_LOCATION
                        PHA
                        LDX             #<MSG_APS_IOERR
                        LDY             #>MSG_APS_IOERR
                        JSR             HIM_WRITE_HBSTRING
                        PLA
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

CMD_USAGE_APS:
                        LDX             #<MSG_USAGE_APS
                        LDY             #>MSG_USAGE_APS
                        JSR             HIM_WRITE_HBSTRING
                        JMP             SYS_WRITE_CRLF

HIM_APS_PRINT_ROW:
                        JSR             HIM_APS_PACK_LOCATION
                        PHA
                        LDX             #<MSG_APS_PREFIX
                        LDY             #>MSG_APS_PREFIX
                        JSR             HIM_WRITE_HBSTRING
                        PLA
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        JSR             HIM_APS_CLASSIFY_HEADER
                        STA             HIM_APS_CLASS
                        TAX
                        LDA             MSG_APS_CLASS_LO,X
                        PHA
                        LDY             #>MSG_APS_HEADER_FF
                        PLA
                        TAX
                        JSR             HIM_WRITE_HBSTRING
                        LDA             HIM_APS_CLASS
                        CMP             #HIM_APS_CLASS_STAGED
                        BCC             ?EOL
                        CMP             #HIM_APS_CLASS_WORK
                        BCS             ?EOL
                        LDX             #<MSG_APS_GEN
                        LDY             #>MSG_APS_GEN
                        JSR             HIM_WRITE_HBSTRING
                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_GENERATION+1
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_GENERATION
                        JSR             SYS_WRITE_HEX_BYTE
?EOL:                  JMP             SYS_WRITE_CRLF

HIM_APS_PACK_LOCATION:
                        LDA             HIM_APS_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             HIM_APS_LOCATION
                        LDA             HIM_APS_SECTOR_HI
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        ORA             HIM_APS_LOCATION
                        STA             HIM_APS_LOCATION
                        RTS

; OUT: A=HIM_APS_CLASS_*. HEADER-FF means only that the 16-byte header is
; erased; CLAIM must still inspect all 4096 bytes before treating a sector as
; empty.
HIM_APS_CLASSIFY_HEADER:
                        LDA             HIM_APS_LOCATION
                        CMP             STR8_CONFIG_WORK_SECTOR
                        BNE             ?TOP_BACKUP
                        LDA             #HIM_APS_CLASS_WORK
                        RTS
?TOP_BACKUP:           CMP             STR8_CONFIG_TOP_BACKUP_SECTOR
                        BNE             ?MEDIA
                        LDA             #HIM_APS_CLASS_TOP_BACKUP
                        RTS
?MEDIA:
                        LDX             #APS_SECTOR_HEADER_BYTES-1
?ALL_FF:               LDA             HIM_APS_HEADER_BASE,X
                        CMP             #$FF
                        BNE             ?SIGNATURE
                        DEX
                        BPL             ?ALL_FF
                        LDA             #HIM_APS_CLASS_HEADER_FF
                        RTS
?SIGNATURE:            LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_SIG
                        CMP             #APS_SECTOR_SIG0
                        BNE             ?OPAQUE
                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_SIG+1
                        CMP             #APS_SECTOR_SIG1
                        BNE             ?OPAQUE
                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_SIG+2
                        CMP             #APS_SECTOR_SIG2
                        BNE             ?OPAQUE
                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_LOCATION
                        CMP             HIM_APS_LOCATION
                        BNE             ?CORRUPT

                        LDX             #$04
?RESERVED:             LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_RESERVED,X
                        CMP             #$FF
                        BNE             ?CORRUPT
                        DEX
                        BPL             ?RESERVED

                        JSR             FNV1A_INIT
                        LDY             #$00
?FNV:                  LDA             HIM_APS_HEADER_BASE,Y
                        JSR             FNV1A_UPDATE_A_FAST
                        INY
                        CPY             #APS_SH_OFF_FNV
                        BNE             ?FNV
                        LDX             #$03
?FNV_COMPARE:          LDA             FNV_HASH0,X
                        CMP             HIM_APS_HEADER_BASE+APS_SH_OFF_FNV,X
                        BNE             ?CORRUPT
                        DEX
                        BPL             ?FNV_COMPARE

                        LDA             HIM_APS_HEADER_BASE+APS_SH_OFF_STATE
                        CMP             #APS_SECTOR_STATE_STAGED
                        BEQ             ?STAGED
                        CMP             #APS_SECTOR_STATE_ACTIVE
                        BEQ             ?ACTIVE
                        CMP             #APS_SECTOR_STATE_RETIRED
                        BEQ             ?RETIRED
                        CMP             #APS_SECTOR_STATE_BAD
                        BEQ             ?BAD
                        CMP             #APS_SECTOR_STATE_RETIRED_BAD
                        BNE             ?CORRUPT
                        LDA             #HIM_APS_CLASS_RETIRED_BAD
                        RTS
?STAGED:               LDA             #HIM_APS_CLASS_STAGED
                        RTS
?ACTIVE:               LDA             #HIM_APS_CLASS_ACTIVE
                        RTS
?RETIRED:              LDA             #HIM_APS_CLASS_RETIRED
                        RTS
?BAD:                  LDA             #HIM_APS_CLASS_BAD
                        RTS
?OPAQUE:               LDA             #HIM_APS_CLASS_OPAQUE
                        RTS
?CORRUPT:              LDA             #HIM_APS_CLASS_CORRUPT
                        RTS

                        ENDIF

; ----------------------------------------------------------------------------
; L  (STR8-N-parsed RAM S19 loader: S1 data, S9 terminator; S0 skipped)
; Ctrl-C cancels the receive session. A fatal record error poisons the load,
; suppresses later S1 writes, and quenches input through S9 or Ctrl-C.
; Completed S1 writes remain in RAM and S9 execution is always absent.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; test-flash:
; - Standalone flash primitive test image.
; - Built by `make test-flash` and linked at $3000, above life.
; - Uses reserved low RAM at $0300 as a staging buffer.
; - Destructively erases/programs the visible flash sector $8000-$8FFF.
; - Destructively erases/programs D000-FFFF in flash banks 0-2.
; - Verifies guard failures for protected monitor flash $D000-$FFFF.
; - Prompts for one raw byte write to any entered address, no range guard.
; - Optional stage-2 sector worker copies one RAM worker, then programs 4K.
; ----------------------------------------------------------------------------

                        MODULE          TEST_FLASH_APP

                        XDEF            START

                        XREF            SYS_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_READ_CHAR
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HBSTRING
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            UTL_HEX_ASCII_TO_NIBBLE
;                       XREF            UTL_DELAY_AXY_8MHZ
                        XREF            FLASH_SECTOR_ERASE_XY
                        XREF            FLASH_SECTOR_ERASE_RAW_XY
                        XREF            FLASH_WRITE_BYTE_AXY
                        XREF            FLASH_WRITE_BYTE_RAW_AXY

TF_PTR_LO                 EQU             $CD
TF_PTR_HI                 EQU             $CE
TF_RAM_BUF                EQU             $0300
TF_INDEX                  EQU             $0310
TF_ADDR_LO                EQU             $0311
TF_ADDR_HI                EQU             $0312
TF_DATA                   EQU             $0313
TF_NIBBLE                 EQU             $0314
TF_COUNT                  EQU             $0315
TF_ENTRY_SP               EQU             $0316
TF_SRC_HI                 EQU             $0317
TF_DST_HI                 EQU             $0318
TF_SECTOR_HI              EQU             $0319
TF_BANK                   EQU             $031A
TF_BANK_BITS              EQU             $031B
TF_CANCEL_FLAG            EQU             $031C
TF_SRC_BANK               EQU             $031D
TF_DOUBLE_BUF_FLAG        EQU             $031E
TF_STAGE2_FLAG            EQU             $031F
TF_LEN                    EQU             $10
TF_FLASH_BASE_HI          EQU             $80
TF_FLASH_PROTECT_HI       EQU             $D0
TF_FLASH_BANKED_SRC_HI    EQU             $D0
TF_FLASH_BANKED_SECTORS   EQU             $03
TF_FLASH_BANKED_BANKS     EQU             $03
TF_FLASH_WINDOW_HI        EQU             $80
TF_SOURCE_BANK            EQU             $03
TF_FIRST_CHAIN_DST_BANK   EQU             $02
TF_SECTOR_BUF             EQU             $4000
TF_SECTOR_BUF_HI          EQU             $40
TF_SECTOR_BUF_END_HI      EQU             $50
TF_FTDI_VIA_PCR           EQU             $7FEC
TF_BANK_PCR_MASK          EQU             $EE
;TF_BANK_DELAY_A           EQU             $6A
;TF_BANK_DELAY_X           EQU             $B6
;TF_BANK_DELAY_Y           EQU             $F8
TF_STAGE2_WORKER_RAM      EQU             $1300
TF_FLASH_UNLOCK1          EQU             $D555
TF_FLASH_UNLOCK2          EQU             $AAAA
TF_FAST_ADDR_LO           EQU             $CD
TF_FAST_ADDR_HI           EQU             $CE
TF_FAST_DATA              EQU             $CF
TF_FAST_TMO0              EQU             $D0
TF_FAST_TMO1              EQU             $D1
TF_FAST_TMO2              EQU             $D2
TF_FAST_SRC_LO            EQU             $D4
TF_FAST_SRC_HI            EQU             $D5
TF_FAST_DST_LO            EQU             $D6
TF_FAST_DST_HI            EQU             $D7
TF_FAST_LEN_LO            EQU             $D8
TF_FAST_LEN_HI            EQU             $D9
TF_FAST_WRITE_TIMEOUT_HI  EQU             $02
TF_CTRL_C                 EQU             $03
TF_BRK_EXIT               EQU             $65
TF_GAP_CMD_BANK           EQU             $03
TF_GAP_CMD_ADDR_LO        EQU             $00
TF_GAP_CMD_ADDR_HI        EQU             $F0
TF_GAP_CMD_MSG_LO         EQU             $17
TF_GAP_CMD_MSG_HI         EQU             $F0
TF_HIM_WRITE_HBSTRING     EQU             $DDDA

                        CODE
START:
                        TSX
                        STX             TF_ENTRY_SP
                        JSR             SYS_INIT
                        JSR             SYS_FLUSH_RX

                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             TF_PRINT_XY
                        LDX             #<MSG_WARN
                        LDY             #>MSG_WARN
                        JSR             TF_PRINT_XY
                        JSR             SYS_READ_CHAR
                        AND             #$DF
                        CMP             #'Y'
                        BEQ             TF_RUN
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JSR             TF_PRINT_XY
                        CLC
                        BRK             TF_BRK_EXIT
                        RTS

TF_RUN:
                        JSR             SYS_WRITE_CRLF
                        LDA             #TF_SOURCE_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        JSR             TF_STAGE_PATTERN
                        JSR             TF_TEST_PROTECT_ERASE
                        JSR             TF_TEST_PROTECT_WRITE
                        JSR             TF_ERASE_SECTOR
                        JSR             TF_VERIFY_ERASED
                        JSR             TF_WRITE_PATTERN
                        JSR             TF_VERIFY_PATTERN
                        JSR             TF_TEST_ILLEGAL_REWRITE
                        JSR             TF_PREP_RAW_WRITE
                        JSR             TF_RAW_WRITE_PROMPT
                        JSR             TF_BANK_COPY_D000_FFFF
                        JSR             TF_COMMIT_BANK3_GAP_CMD

                        LDA             #TF_SOURCE_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        LDX             #<MSG_PASS
                        LDY             #>MSG_PASS
                        JSR             TF_PRINT_XY
                        SEC
                        BRK             TF_BRK_EXIT
                        RTS

TF_STAGE_PATTERN:
                        LDX             #$00
?LOOP:                  LDA             TF_PATTERN,X
                        STA             TF_RAM_BUF,X
                        INX
                        CPX             #TF_LEN
                        BNE             ?LOOP
                        RTS

TF_TEST_PROTECT_ERASE:
                        LDX             #<MSG_PROTECT_ERASE
                        LDY             #>MSG_PROTECT_ERASE
                        JSR             TF_PRINT_XY
                        LDX             #$00
                        LDY             #TF_FLASH_PROTECT_HI
                        JSR             FLASH_SECTOR_ERASE_XY
                        BCC             ?OK
                        LDA             #'P'
                        JMP             TF_FAIL_A
?OK:                    RTS

TF_TEST_PROTECT_WRITE:
                        LDX             #<MSG_PROTECT_WRITE
                        LDY             #>MSG_PROTECT_WRITE
                        JSR             TF_PRINT_XY
                        LDA             #$00
                        LDX             #$00
                        LDY             #TF_FLASH_PROTECT_HI
                        JSR             FLASH_WRITE_BYTE_AXY
                        BCC             ?OK
                        LDA             #'W'
                        JMP             TF_FAIL_A
?OK:                    RTS

TF_ERASE_SECTOR:
                        LDX             #<MSG_ERASE
                        LDY             #>MSG_ERASE
                        JSR             TF_PRINT_XY
                        LDX             #$00
                        LDY             #TF_FLASH_BASE_HI
                        JSR             FLASH_SECTOR_ERASE_XY
                        BCS             ?OK
                        LDA             #'E'
                        JMP             TF_FAIL_A
?OK:                    RTS

TF_VERIFY_ERASED:
                        LDX             #<MSG_VERIFY_ERASE
                        LDY             #>MSG_VERIFY_ERASE
                        JSR             TF_PRINT_XY
                        STZ             TF_PTR_LO
                        LDA             #TF_FLASH_BASE_HI
                        STA             TF_PTR_HI
?LOOP:                  LDY             #$00
                        LDA             (TF_PTR_LO),Y
                        CMP             #$FF
                        BEQ             ?NEXT
                        LDA             #'e'
                        JMP             TF_FAIL_A
?NEXT:                  INC             TF_PTR_LO
                        BNE             ?LOOP
                        INC             TF_PTR_HI
                        LDA             TF_PTR_HI
                        CMP             #(TF_FLASH_BASE_HI+$10)
                        BNE             ?LOOP
                        RTS

TF_WRITE_PATTERN:
                        LDX             #<MSG_WRITE
                        LDY             #>MSG_WRITE
                        JSR             TF_PRINT_XY
                        STZ             TF_INDEX
?LOOP:                  LDX             TF_INDEX
                        LDA             TF_RAM_BUF,X
                        LDX             TF_INDEX
                        LDY             #TF_FLASH_BASE_HI
                        JSR             FLASH_WRITE_BYTE_AXY
                        BCS             ?NEXT
                        LDA             #'B'
                        JMP             TF_FAIL_A
?NEXT:                  INC             TF_INDEX
                        LDA             TF_INDEX
                        CMP             #TF_LEN
                        BNE             ?LOOP
                        RTS

TF_VERIFY_PATTERN:
                        LDX             #<MSG_VERIFY_WRITE
                        LDY             #>MSG_VERIFY_WRITE
                        JSR             TF_PRINT_XY
                        STZ             TF_INDEX
?LOOP:                  LDY             TF_INDEX
                        LDA             $8000,Y
                        CMP             TF_RAM_BUF,Y
                        BEQ             ?NEXT
                        LDA             #'V'
                        JMP             TF_FAIL_A
?NEXT:                  INC             TF_INDEX
                        LDA             TF_INDEX
                        CMP             #TF_LEN
                        BNE             ?LOOP
                        RTS

TF_TEST_ILLEGAL_REWRITE:
                        LDX             #<MSG_ILLEGAL
                        LDY             #>MSG_ILLEGAL
                        JSR             TF_PRINT_XY
                        LDA             #$FF
                        LDX             #$01
                        LDY             #TF_FLASH_BASE_HI
                        JSR             FLASH_WRITE_BYTE_AXY
                        BCC             ?VERIFY
                        LDA             #'I'
                        JMP             TF_FAIL_A
?VERIFY:                LDA             $8001
                        CMP             #$55
                        BEQ             ?OK
                        LDA             #'i'
                        JMP             TF_FAIL_A
?OK:                    RTS

TF_PREP_RAW_WRITE:
                        LDX             #<MSG_RAW_PREP
                        LDY             #>MSG_RAW_PREP
                        JSR             TF_PRINT_XY
                        LDX             #$00
                        LDY             #TF_FLASH_BASE_HI
                        JSR             FLASH_SECTOR_ERASE_XY
                        BCS             ?OK
                        LDA             #'r'
                        JMP             TF_FAIL_A
?OK:                    RTS

TF_RAW_WRITE_PROMPT:
                        LDX             #<MSG_RAW_INTRO
                        LDY             #>MSG_RAW_INTRO
                        JSR             TF_PRINT_XY
                        LDX             #<MSG_RAW_ADDR
                        LDY             #>MSG_RAW_ADDR
                        JSR             TF_PRINT_XY
                        JSR             TF_READ_HEX_WORD
                        BCS             ?ADDR_OK
                        LDA             TF_CANCEL_FLAG
                        BEQ             ?ADDR_FAIL
                        JMP             TF_ABORT
?ADDR_FAIL:
                        LDA             #'A'
                        JMP             TF_FAIL_A
?ADDR_OK:               LDX             #<MSG_RAW_BYTE
                        LDY             #>MSG_RAW_BYTE
                        JSR             TF_PRINT_XY
                        JSR             TF_READ_HEX_BYTE
                        BCS             ?BYTE_OK
                        LDA             TF_CANCEL_FLAG
                        BEQ             ?BYTE_FAIL
                        JMP             TF_ABORT
?BYTE_FAIL:
                        LDA             #'H'
                        JMP             TF_FAIL_A
?BYTE_OK:               LDA             TF_DATA
                        LDX             TF_ADDR_LO
                        LDY             TF_ADDR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCS             ?WRITE_OK
                        LDA             #'R'
                        JMP             TF_FAIL_A
?WRITE_OK:              LDX             #<MSG_RAW_OK
                        LDY             #>MSG_RAW_OK
                        JSR             TF_PRINT_XY
                        LDA             TF_DATA
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_RAW_AT
                        LDY             #>MSG_RAW_AT
                        JSR             TF_PRINT_XY
                        LDA             TF_ADDR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             TF_ADDR_LO
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        RTS

TF_BANK_SELECT_A:
                        AND             #$03
                        TAX
                        LDA             TF_BANK_BIT_TABLE,X
                        STA             TF_BANK_BITS
                        LDA             #TF_BANK_PCR_MASK
                        TRB             TF_FTDI_VIA_PCR
                        LDA             TF_BANK_BITS
                        TSB             TF_FTDI_VIA_PCR
                        RTS

TF_BANK_SELECT_DELAY_A:
                        JSR             TF_BANK_SELECT_A
;                       LDA             #TF_BANK_DELAY_A
;                       LDX             #TF_BANK_DELAY_X
;                       LDY             #TF_BANK_DELAY_Y
;                       JSR             UTL_DELAY_AXY_8MHZ
                        RTS

TF_BANK_COPY_D000_FFFF:
                        LDX             #<MSG_BANK_SELECT
                        LDY             #>MSG_BANK_SELECT
                        JSR             TF_PRINT_XY
                        JSR             TF_ASK_DOUBLE_BUFFER
                        JSR             TF_ASK_STAGE2
                        JSR             TF_BANK_CHAIN_COPY_TARGETS
                        RTS

TF_ASK_DOUBLE_BUFFER:
                        LDX             #<MSG_DOUBLE_BUF
                        LDY             #>MSG_DOUBLE_BUF
                        JSR             TF_PRINT_XY
                        STZ             TF_DOUBLE_BUF_FLAG
?READ:                 JSR             SYS_READ_CHAR
                        CMP             #TF_CTRL_C
                        BEQ             ?ABORT
                        CMP             #' '
                        BEQ             ?READ
                        CMP             #$09
                        BEQ             ?READ
                        CMP             #$0D
                        BEQ             ?READ
                        CMP             #$0A
                        BEQ             ?READ
                        AND             #$DF
                        CMP             #'Y'
                        BNE             ?DONE
                        LDA             #$01
                        STA             TF_DOUBLE_BUF_FLAG
?DONE:                 JSR             SYS_WRITE_CRLF
                        RTS
?ABORT:                JMP             TF_ABORT

TF_ASK_STAGE2:
                        LDX             #<MSG_STAGE2
                        LDY             #>MSG_STAGE2
                        JSR             TF_PRINT_XY
                        STZ             TF_STAGE2_FLAG
?READ:                 JSR             SYS_READ_CHAR
                        CMP             #TF_CTRL_C
                        BEQ             ?ABORT
                        CMP             #' '
                        BEQ             ?READ
                        CMP             #$09
                        BEQ             ?READ
                        CMP             #$0D
                        BEQ             ?READ
                        CMP             #$0A
                        BEQ             ?READ
                        AND             #$DF
                        CMP             #'Y'
                        BNE             ?DONE
                        LDA             #$01
                        STA             TF_STAGE2_FLAG
                        STA             TF_DOUBLE_BUF_FLAG
?DONE:                 JSR             SYS_WRITE_CRLF
                        RTS
?ABORT:                JMP             TF_ABORT

TF_BANK_CHAIN_COPY_TARGETS:
                        LDX             #<MSG_BANK_ERASE_ALL
                        LDY             #>MSG_BANK_ERASE_ALL
                        JSR             TF_PRINT_XY
                        LDX             #<MSG_BANK_COPY_ALL
                        LDY             #>MSG_BANK_COPY_ALL
                        JSR             TF_PRINT_XY
                        LDA             #TF_FLASH_BANKED_SECTORS
                        STA             TF_COUNT
                        LDA             #TF_FLASH_BANKED_SRC_HI
                        STA             TF_SECTOR_HI
?SECTOR:               LDA             #TF_FIRST_CHAIN_DST_BANK
                        STA             TF_BANK
?BANK:                 LDA             TF_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        JSR             TF_PRINT_BANK_ERASE
                        LDX             #$00
                        LDY             TF_SECTOR_HI
                        JSR             FLASH_SECTOR_ERASE_RAW_XY
                        BCS             ?ERASE_OK
                        LDA             #'d'
                        JMP             TF_FAIL_A
?ERASE_OK:             LDA             TF_BANK
                        CLC
                        ADC             #$01
                        STA             TF_SRC_BANK
                        JSR             TF_PRINT_BANK_COPY
                        JSR             TF_COPY_SECTOR_TO_BANK
                        LDA             TF_BANK
                        BEQ             ?NEXT_SECTOR
                        DEC             TF_BANK
                        BRA             ?BANK
?NEXT_SECTOR:          LDA             TF_SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             TF_SECTOR_HI
                        DEC             TF_COUNT
                        BNE             ?SECTOR
                        RTS

TF_COMMIT_BANK3_GAP_CMD:
                        LDX             #<MSG_GAP_COMMIT
                        LDY             #>MSG_GAP_COMMIT
                        JSR             TF_PRINT_XY
                        LDA             #TF_GAP_CMD_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        STZ             TF_INDEX
?LOOP:                  LDX             TF_INDEX
                        CPX             #TF_GAP_CMD_LEN
                        BEQ             ?DONE
                        LDA             TF_GAP_CMD_PAYLOAD,X
                        STA             TF_DATA
                        LDA             #TF_GAP_CMD_ADDR_LO
                        CLC
                        ADC             TF_INDEX
                        STA             TF_ADDR_LO
                        LDA             #TF_GAP_CMD_ADDR_HI
                        ADC             #$00
                        STA             TF_ADDR_HI
                        STA             TF_PTR_HI
                        LDA             TF_ADDR_LO
                        STA             TF_PTR_LO
                        LDY             #$00
                        LDA             (TF_PTR_LO),Y
                        CMP             TF_DATA
                        BEQ             ?NEXT
                        CMP             #$FF
                        BEQ             ?WRITE
                        LDA             #'Z'
                        JMP             TF_FAIL_A
?WRITE:                 LDA             TF_DATA
                        LDX             TF_ADDR_LO
                        LDY             TF_ADDR_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCS             ?NEXT
                        LDA             #'Z'
                        JMP             TF_FAIL_A
?NEXT:                  INC             TF_INDEX
                        BRA             ?LOOP
?DONE:                  RTS

TF_COPY_SECTOR_TO_BANK:
                        LDA             TF_STAGE2_FLAG
                        BEQ             ?NOT_STAGE2
                        JMP             TF_COPY_SECTOR_STAGE2
?NOT_STAGE2:
                        LDA             TF_DOUBLE_BUF_FLAG
                        BEQ             TF_COPY_SECTOR_DIRECT
                        JMP             TF_COPY_SECTOR_BUFFERED

TF_COPY_SECTOR_DIRECT:
                        LDA             TF_SECTOR_HI
                        STA             TF_SRC_HI
                        CLC
                        ADC             #$10
                        STA             TF_DST_HI
?PAGE:                 STZ             TF_INDEX
?LOOP:                 LDA             TF_SRC_BANK
                        JSR             TF_BANK_SELECT_A
                        LDX             TF_INDEX
                        STX             TF_PTR_LO
                        LDA             TF_SRC_HI
                        STA             TF_PTR_HI
                        LDY             #$00
                        LDA             (TF_PTR_LO),Y
                        STA             TF_DATA
                        LDA             TF_BANK
                        JSR             TF_BANK_SELECT_A
                        LDA             TF_DATA
                        LDX             TF_INDEX
                        LDY             TF_SRC_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCS             ?NEXT
                        LDA             #'C'
                        JMP             TF_FAIL_A
?NEXT:                 INC             TF_INDEX
                        BNE             ?LOOP
                        INC             TF_SRC_HI
                        LDA             TF_SRC_HI
                        CMP             TF_DST_HI
                        BNE             ?PAGE
                        RTS

TF_COPY_SECTOR_BUFFERED:
                        JSR             TF_FILL_SECTOR_BUFFER
                        JSR             TF_PROGRAM_SECTOR_BUFFER
                        RTS

TF_COPY_SECTOR_STAGE2:
                        JSR             TF_FILL_SECTOR_BUFFER
                        JSR             TF_PROGRAM_SECTOR_BUFFER_STAGE2
                        RTS

TF_FILL_SECTOR_BUFFER:
                        LDA             TF_SRC_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        LDA             TF_SECTOR_HI
                        STA             TF_SRC_HI
                        LDA             #TF_SECTOR_BUF_HI
                        STA             TF_DST_HI
?PAGE:                 STZ             TF_INDEX
?LOOP:                 LDX             TF_INDEX
                        STX             TF_PTR_LO
                        LDA             TF_SRC_HI
                        STA             TF_PTR_HI
                        LDY             #$00
                        LDA             (TF_PTR_LO),Y
                        PHA
                        LDX             TF_INDEX
                        STX             TF_PTR_LO
                        LDA             TF_DST_HI
                        STA             TF_PTR_HI
                        PLA
                        STA             (TF_PTR_LO),Y
                        INC             TF_INDEX
                        BNE             ?LOOP
                        INC             TF_SRC_HI
                        INC             TF_DST_HI
                        LDA             TF_DST_HI
                        CMP             #TF_SECTOR_BUF_END_HI
                        BNE             ?PAGE
                        RTS

TF_PROGRAM_SECTOR_BUFFER:
                        LDA             TF_BANK
                        JSR             TF_BANK_SELECT_DELAY_A
                        LDA             #TF_SECTOR_BUF_HI
                        STA             TF_SRC_HI
                        LDA             TF_SECTOR_HI
                        STA             TF_DST_HI
                        CLC
                        ADC             #$10
                        STA             TF_ADDR_HI
?PAGE:                 STZ             TF_INDEX
?LOOP:                 LDX             TF_INDEX
                        STX             TF_PTR_LO
                        LDA             TF_SRC_HI
                        STA             TF_PTR_HI
                        LDY             #$00
                        LDA             (TF_PTR_LO),Y
                        LDX             TF_INDEX
                        LDY             TF_DST_HI
                        JSR             FLASH_WRITE_BYTE_RAW_AXY
                        BCS             ?NEXT
                        LDA             #'C'
                        JMP             TF_FAIL_A
?NEXT:                 INC             TF_INDEX
                        BNE             ?LOOP
                        INC             TF_SRC_HI
                        INC             TF_DST_HI
                        LDA             TF_DST_HI
                        CMP             TF_ADDR_HI
                        BNE             ?PAGE
                        RTS

TF_PROGRAM_SECTOR_BUFFER_STAGE2:
                        JSR             TF_STAGE2_COPY_WORKER
                        LDA             #<TF_SECTOR_BUF
                        STA             TF_FAST_SRC_LO
                        LDA             #>TF_SECTOR_BUF
                        STA             TF_FAST_SRC_HI
                        STZ             TF_FAST_DST_LO
                        LDA             TF_SECTOR_HI
                        STA             TF_FAST_DST_HI
                        STZ             TF_FAST_LEN_LO
                        LDA             #$10
                        STA             TF_FAST_LEN_HI
                        LDA             TF_BANK
                        JSR             TF_BANK_SELECT_A
                        PHP
                        SEI
                        JSR             TF_STAGE2_WORKER_RAM
                        BCS             ?OK
                        PLP
                        LDA             #'2'
                        JMP             TF_FAIL_A
?OK:                   PLP
                        SEC
                        RTS

TF_STAGE2_COPY_WORKER:
                        LDA             #<TF_STAGE2_WORKER_BEGIN
                        STA             TF_FAST_SRC_LO
                        LDA             #>TF_STAGE2_WORKER_BEGIN
                        STA             TF_FAST_SRC_HI
                        LDA             #<TF_STAGE2_WORKER_RAM
                        STA             TF_FAST_DST_LO
                        LDA             #>TF_STAGE2_WORKER_RAM
                        STA             TF_FAST_DST_HI
                        LDA             #<TF_STAGE2_WORKER_SIZE
                        STA             TF_FAST_LEN_LO
                        LDA             #>TF_STAGE2_WORKER_SIZE
                        STA             TF_FAST_LEN_HI
                        LDY             #$00
?LOOP:                 LDA             (TF_FAST_SRC_LO),Y
                        STA             (TF_FAST_DST_LO),Y
                        INC             TF_FAST_SRC_LO
                        BNE             ?SRC_OK
                        INC             TF_FAST_SRC_HI
?SRC_OK:               INC             TF_FAST_DST_LO
                        BNE             ?DST_OK
                        INC             TF_FAST_DST_HI
?DST_OK:               LDA             TF_FAST_LEN_LO
                        BNE             ?DEC_LO
                        DEC             TF_FAST_LEN_HI
?DEC_LO:               DEC             TF_FAST_LEN_LO
                        LDA             TF_FAST_LEN_LO
                        ORA             TF_FAST_LEN_HI
                        BNE             ?LOOP
                        RTS

; Runs from RAM at TF_STAGE2_WORKER_RAM. Keep internal branches relative.
TF_STAGE2_WORKER_BEGIN:
?BYTE:                 LDA             TF_FAST_LEN_LO
                        ORA             TF_FAST_LEN_HI
                        BEQ             ?OK
                        LDY             #$00
                        LDA             (TF_FAST_SRC_LO),Y
                        STA             TF_FAST_DATA
                        LDA             (TF_FAST_DST_LO),Y
                        CMP             TF_FAST_DATA
                        BEQ             ?NEXT
                        AND             TF_FAST_DATA
                        CMP             TF_FAST_DATA
                        BNE             ?FAIL_RESET

                        LDA             #$AA
                        STA             TF_FLASH_UNLOCK1
                        LDA             #$55
                        STA             TF_FLASH_UNLOCK2
                        LDA             #$A0
                        STA             TF_FLASH_UNLOCK1
                        LDA             TF_FAST_DATA
                        STA             (TF_FAST_DST_LO),Y

                        STZ             TF_FAST_TMO0
                        STZ             TF_FAST_TMO1
                        LDA             #TF_FAST_WRITE_TIMEOUT_HI
                        STA             TF_FAST_TMO2
?POLL:                 LDY             #$00
                        LDA             (TF_FAST_DST_LO),Y
                        CMP             TF_FAST_DATA
                        BEQ             ?NEXT
                        DEC             TF_FAST_TMO0
                        BNE             ?POLL
                        DEC             TF_FAST_TMO1
                        BNE             ?POLL
                        DEC             TF_FAST_TMO2
                        BNE             ?POLL
                        BRA             ?FAIL_RESET

?NEXT:                 INC             TF_FAST_SRC_LO
                        BNE             ?SRC_OK
                        INC             TF_FAST_SRC_HI
?SRC_OK:               INC             TF_FAST_DST_LO
                        BNE             ?DST_OK
                        INC             TF_FAST_DST_HI
?DST_OK:               LDA             TF_FAST_LEN_LO
                        BNE             ?DEC_LO
                        DEC             TF_FAST_LEN_HI
?DEC_LO:               DEC             TF_FAST_LEN_LO
                        BRA             ?BYTE

?FAIL_RESET:           LDA             #$F0
                        STA             TF_FLASH_UNLOCK1
                        CLC
                        RTS
?OK:                   SEC
                        RTS
TF_STAGE2_WORKER_END:
TF_STAGE2_WORKER_SIZE  EQU             TF_STAGE2_WORKER_END-TF_STAGE2_WORKER_BEGIN

TF_PRINT_BANK_ERASE:
                        LDX             #<MSG_BANK
                        LDY             #>MSG_BANK
                        JSR             TF_PRINT_XY
                        LDA             TF_BANK
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_ERASE_SECTOR
                        LDY             #>MSG_ERASE_SECTOR
                        JSR             TF_PRINT_XY
                        LDA             TF_SECTOR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_SECTOR_SUFFIX
                        LDY             #>MSG_SECTOR_SUFFIX
                        JSR             TF_PRINT_XY
                        RTS

TF_PRINT_BANK_COPY:
                        LDX             #<MSG_BANK
                        LDY             #>MSG_BANK
                        JSR             TF_PRINT_XY
                        LDA             TF_SRC_BANK
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_BANK_ARROW
                        LDY             #>MSG_BANK_ARROW
                        JSR             TF_PRINT_XY
                        LDA             TF_BANK
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_COPY_SECTOR
                        LDY             #>MSG_COPY_SECTOR
                        JSR             TF_PRINT_XY
                        LDA             TF_SECTOR_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_SECTOR_SUFFIX
                        LDY             #>MSG_SECTOR_SUFFIX
                        JSR             TF_PRINT_XY
                        RTS

TF_READ_HEX_WORD:
                        STZ             TF_CANCEL_FLAG
                        STZ             TF_ADDR_LO
                        STZ             TF_ADDR_HI
                        LDA             #$04
                        STA             TF_COUNT
?LOOP:                  JSR             TF_READ_HEX_NIBBLE_ECHO
                        BCC             ?FAIL
                        ASL             TF_ADDR_LO
                        ROL             TF_ADDR_HI
                        ASL             TF_ADDR_LO
                        ROL             TF_ADDR_HI
                        ASL             TF_ADDR_LO
                        ROL             TF_ADDR_HI
                        ASL             TF_ADDR_LO
                        ROL             TF_ADDR_HI
                        ORA             TF_ADDR_LO
                        STA             TF_ADDR_LO
                        DEC             TF_COUNT
                        BNE             ?LOOP
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS

TF_READ_HEX_BYTE:
                        STZ             TF_CANCEL_FLAG
                        JSR             TF_READ_HEX_NIBBLE_ECHO
                        BCC             ?FAIL
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             TF_DATA
                        JSR             TF_READ_HEX_NIBBLE_ECHO
                        BCC             ?FAIL
                        ORA             TF_DATA
                        STA             TF_DATA
                        SEC
                        RTS
?FAIL:                  CLC
                        RTS

TF_READ_HEX_NIBBLE_ECHO:
?READ:                  JSR             SYS_READ_CHAR
                        CMP             #TF_CTRL_C
                        BEQ             ?CANCEL
                        CMP             #' '
                        BEQ             ?READ
                        CMP             #$09
                        BEQ             ?READ
                        CMP             #$0D
                        BEQ             ?READ
                        CMP             #$0A
                        BEQ             ?READ
                        PHA
                        JSR             UTL_HEX_ASCII_TO_NIBBLE
                        BCC             ?BAD
                        STA             TF_NIBBLE
                        PLA
                        JSR             SYS_WRITE_CHAR
                        LDA             TF_NIBBLE
                        SEC
                        RTS
?BAD:                   PLA
                        CLC
                        RTS
?CANCEL:                STA             TF_CANCEL_FLAG
                        CLC
                        RTS

TF_ABORT:
                        LDA             #TF_SOURCE_BANK
                        JSR             TF_BANK_SELECT_A
                        LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JSR             TF_PRINT_XY
                        LDX             TF_ENTRY_SP
                        TXS
                        CLC
                        BRK             TF_BRK_EXIT
                        RTS

TF_FAIL_A:
                        PHA
                        LDA             #TF_SOURCE_BANK
                        JSR             TF_BANK_SELECT_A
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JSR             SYS_WRITE_HBSTRING
                        PLA
                        JSR             SYS_WRITE_CHAR
                        JSR             SYS_WRITE_CRLF
                        LDX             TF_ENTRY_SP
                        TXS
                        CLC
                        BRK             TF_BRK_EXIT
                        RTS

TF_PRINT_XY:
                        JSR             SYS_WRITE_HBSTRING
                        RTS

                        DATA
TF_PATTERN:
                        DB              $00,$55,$AA,$FF,$12,$34,$56,$78
                        DB              $87,$65,$43,$21,$F0,$0F,$5A,$A5
TF_GAP_CMD_PAYLOAD:
                        DB              'F','N',('V'+$80),$4D,$21,$0C,$DF,$00
                        DB              $A2,TF_GAP_CMD_MSG_LO
                        DB              $A0,TF_GAP_CMD_MSG_HI
                        DB              $20,<TF_HIM_WRITE_HBSTRING,>TF_HIM_WRITE_HBSTRING
                        DB              $A9,'Z',$A2,$F0,$A0,$08,$38,$60
                        DB              "FLASH GAP CMD",13,$8A
TF_GAP_CMD_PAYLOAD_END:
TF_GAP_CMD_LEN          EQU             TF_GAP_CMD_PAYLOAD_END-TF_GAP_CMD_PAYLOAD
; CA2 drives FA15; CB2 drives FAMS. SXB LEDs show logical bank bits inverted
; from the raw VIA PCR output state, so table entries are reversed.
TF_BANK_BIT_TABLE:
                        DB              $EE,$EC,$CE,$CC

MSG_TITLE:              DB              13,10,"FLASH TEST @3000",13,$8A
MSG_WARN:               DB              "ERASE/WRITE $8000-$8FFF AND BANKS 3->2->1->0 D000-FFFF. TYPE Y:",$A0
MSG_ABORT:              DB              13,10,"ABORT",13,$8A
MSG_PROTECT_ERASE:      DB              "PROTECT ERASE D000",13,$8A
MSG_PROTECT_WRITE:      DB              "PROTECT WRITE D000",13,$8A
MSG_ERASE:              DB              "ERASE 8000",13,$8A
MSG_VERIFY_ERASE:       DB              "VERIFY FF 8000-8FFF",13,$8A
MSG_WRITE:              DB              "WRITE PATTERN",13,$8A
MSG_VERIFY_WRITE:       DB              "VERIFY PATTERN",13,$8A
MSG_ILLEGAL:            DB              "CHECK 0-TO-1 REJECT",13,$8A
MSG_RAW_PREP:           DB              "ERASE 8000 FOR RAW WRITE",13,$8A
MSG_RAW_INTRO:          DB              "RAW WRITE NO RANGE CHECKS",13,$8A
MSG_RAW_ADDR:           DB              "ADDR ",('$'+$80)
MSG_RAW_BYTE:           DB              13,10,"BYTE ",('$'+$80)
MSG_RAW_OK:             DB              13,10,"WROTE ",('$'+$80)
MSG_RAW_AT:             DB              " @ ",('$'+$80)
MSG_BANK_SELECT:        DB              "BANK=FAMS:FA15 00=0 01=1 10=2 11=3",13,$8A
MSG_DOUBLE_BUF:         DB              "DOUBLE BUFFER $4000-$4FFF? Y:",$A0
MSG_STAGE2:             DB              13,10,"STAGE2 4K RAM WORKER? Y:",$A0
MSG_BANK_ERASE_ALL:     DB              "CASCADE EACH SECTOR D,E,F",13,$8A
MSG_BANK_COPY_ALL:      DB              "ERASE+COPY 3->2 2->1 1->0",13,$8A
MSG_GAP_COMMIT:         DB              "COMMIT Z @F000 BANK 3",13,$8A
MSG_BANK:               DB              "BANK ",('$'+$80)
MSG_BANK_ARROW:         DB              "-",('>'+$80)
MSG_ERASE_SECTOR:       DB              " ERASE ",('$'+$80)
MSG_COPY_SECTOR:        DB              " COPY ",('$'+$80)
MSG_SECTOR_SUFFIX:      DB              "000",13,$8A
MSG_FAIL:               DB              "FAIL",(' '+$80)
MSG_PASS:               DB              "PASS",13,$8A

                        END

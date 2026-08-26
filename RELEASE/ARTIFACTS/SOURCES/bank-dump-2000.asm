; ---------------------------------------------------------------------------
; Host-built counterpart of bank-dump-2000.a.
;
; BANKDUMP is a read-only fixed-$2000 APC.  It selects one physical bank/sector,
; stages the complete 4K sector at $4000, restores Bank 3, computes CRC16,
; and presents either a decoded AP-v2 header, one 256-byte page, or the whole
; sector as 16-byte hexadecimal/ASCII rows.  M at the bank prompt scans the
; complete 4x8 physical map with Bank Maintenance-compatible classifications.
; ---------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          BANK_DUMP
                        XDEF            BANKDUMP
                        XDEF            _END_CODE

; Current host-linked HIMON services.  The onboard .a imports these names;
; only internal control/data references are fixed to the sealed $2000 map.
BIO_FTDI_PUT_CSTR       EQU             $E69D
SYS_READ_CSTRING_ECHO_UPPER EQU         $CAE0
BIO_FTDI_WRITE_BYTE_BLOCK EQU           $E3F5

STATUS                  EQU             $7C00
BANK_NO                 EQU             $7C01
SECTOR_HI               EQU             $7C02
MODE                    EQU             $7C03
PAGE_NO                 EQU             $7C04
PAGES_LEFT              EQU             $7C05
ROWS_LEFT               EQU             $7C06
CRC_LO_RESULT           EQU             $7C08
CRC_HI_RESULT           EQU             $7C09
MAP_BANK                EQU             $7C0A
MAP_SECTOR              EQU             $7C0B
WORK_ROLE               EQU             $7C0C
BACKUP_ROLE             EQU             $7C0D
AP_PACKAGE_LO           EQU             $7C10
AP_PACKAGE_HI           EQU             $7C11
AP_BODY_LO              EQU             $7C12
AP_BODY_HI              EQU             $7C13
AP_EXPECT_FNV0          EQU             $7C14
INPUT                   EQU             $7000

PTR_LO                  EQU             $A0
PTR_HI                  EQU             $A1
SRC_LO                  EQU             $A2
SRC_HI                  EQU             $A3
DST_LO                  EQU             $A4
DST_HI                  EQU             $A5
CRC_LO                  EQU             $A6
CRC_HI                  EQU             $A7
ADDR_LO                 EQU             $A8
ADDR_HI                 EQU             $A9
AP_CAND_LO              EQU             $AA
AP_CAND_HI              EQU             $AB
AP_PARSE_LO             EQU             $AC
AP_PARSE_HI             EQU             $AD
AP_REMAIN_LO            EQU             $AE
AP_REMAIN_HI            EQU             $AF
FNV0                    EQU             $B0
FNV1                    EQU             $B1
FNV2                    EQU             $B2
FNV3                    EQU             $B3
AP_SECTION_LEN          EQU             $B4
AP_BODY_PTR_LO          EQU             $B5
AP_BODY_PTR_HI          EQU             $B6
AP_BODY_COUNT_LO        EQU             $B7
AP_BODY_COUNT_HI        EQU             $B8
AP_TMP0                 EQU             $B9
AP_TMP1                 EQU             $BA
FNV_SHIFT0              EQU             $C7
FNV_SHIFT1              EQU             $C8
FNV_SHIFT2              EQU             $C9
FNV_SHIFT3              EQU             $CA

BANK_SELECT             EQU             $F010
BANK_SELECT_RAM         EQU             $0203
BUFFER_HI               EQU             $40

                        CODE

; BEGIN SHARED BANKDUMP BODY
BANKDUMP:               BRA             RUN

RUN:                    STZ             STATUS
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             PUTS

ASK_BANK:               LDX             #<MSG_BANK
                        LDY             #>MSG_BANK
                        JSR             PUTS
                        JSR             READ_ONE
                        BCS             BANK_READ_OK
                        JMP             ABORT
BANK_READ_OK:           CMP             #'0'
                        BNE             BANK_NOT_ZERO
                        BRA             BANK_LOW_OK
BANK_NOT_ZERO:          CMP             #'M'
                        BNE             BANK_DIGIT
                        JMP             MAP_RUN
BANK_DIGIT:             CMP             #'0'
                        BCS             BANK_LOW_OK
                        JMP             BAD_BANK
BANK_LOW_OK:            CMP             #'4'
                        BCC             BANK_VALUE_OK
                        JMP             BAD_BANK
BANK_VALUE_OK:          SEC
                        SBC             #'0'
                        STA             BANK_NO

ASK_SECTOR:             LDX             #<MSG_SECTOR
                        LDY             #>MSG_SECTOR
                        JSR             PUTS
                        JSR             READ_ONE
                        BCS             SECTOR_READ_OK
                        JMP             ABORT
SECTOR_READ_OK:         JSR             HEX_VALUE
                        BCS             SECTOR_HEX_OK
                        JMP             BAD_SECTOR
SECTOR_HEX_OK:          CMP             #$08
                        BCS             SECTOR_VALUE_OK
                        JMP             BAD_SECTOR
SECTOR_VALUE_OK:        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             SECTOR_HI

ASK_MODE:               LDX             #<MSG_MODE
                        LDY             #>MSG_MODE
                        JSR             PUTS
                        JSR             READ_ONE
                        BCS             MODE_READ_OK
                        JMP             ABORT
MODE_READ_OK:           CMP             #'Q'
                        BNE             MODE_NOT_QUIT
                        JMP             ABORT
MODE_NOT_QUIT:          CMP             #'H'
                        BEQ             MODE_OK
                        CMP             #'P'
                        BEQ             MODE_PAGE
                        CMP             #'A'
                        BEQ             MODE_OK
BAD_MODE:               LDX             #<MSG_BAD_MODE
                        LDY             #>MSG_BAD_MODE
                        JSR             PUTS
                        BRA             ASK_MODE

MODE_PAGE:              STA             MODE
ASK_PAGE:               LDX             #<MSG_PAGE
                        LDY             #>MSG_PAGE
                        JSR             PUTS
                        JSR             READ_ONE
                        BCS             PAGE_READ_OK
                        JMP             ABORT
PAGE_READ_OK:           JSR             HEX_VALUE
                        BCC             BAD_PAGE
                        STA             PAGE_NO
                        BRA             CONFIGURED

MODE_OK:                STA             MODE
                        STZ             PAGE_NO
CONFIGURED:             JSR             STAGE
                        BCC             STAGE_FAIL
                        JSR             CRC16
                        JSR             PRINT_SELECTION
                        LDA             MODE
                        CMP             #'H'
                        BNE             NOT_HEADER
                        JSR             PRINT_AP_HEADER
                        LDA             #$01
                        STA             PAGES_LEFT
                        BRA             DUMP_PAGE
NOT_HEADER:             CMP             #'P'
                        BNE             ALL_PAGES
                        LDA             #$01
                        STA             PAGES_LEFT
                        BRA             DUMP_PAGE
ALL_PAGES:              LDA             #$10
                        STA             PAGES_LEFT

DUMP_PAGE:              JSR             DUMP_256
                        DEC             PAGES_LEFT
                        BEQ             COMPLETE
                        LDX             #<MSG_MORE
                        LDY             #>MSG_MORE
                        JSR             PUTS
                        JSR             READ_LINE
                        BCC             ABORT
                        LDA             INPUT
                        CMP             #'Q'
                        BEQ             ABORT
                        INC             PAGE_NO
                        BRA             DUMP_PAGE

COMPLETE:               LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             PUTS
                        LDA             #$AC
                        STA             STATUS
                        SEC
                        RTS

BAD_BANK:               LDX             #<MSG_BAD_BANK
                        LDY             #>MSG_BAD_BANK
                        JSR             PUTS
                        JMP             ASK_BANK
BAD_SECTOR:             LDX             #<MSG_BAD_SECTOR
                        LDY             #>MSG_BAD_SECTOR
                        JSR             PUTS
                        JMP             ASK_SECTOR
BAD_PAGE:               LDX             #<MSG_BAD_PAGE
                        LDY             #>MSG_BAD_PAGE
                        JSR             PUTS
                        JMP             ASK_PAGE

STAGE_FAIL:             LDX             #<MSG_STAGE_FAIL
                        LDY             #>MSG_STAGE_FAIL
                        JSR             PUTS
                        LDA             #$E1
                        STA             STATUS
                        CLC
                        RTS

ABORT:                  LDX             #<MSG_ABORT
                        LDY             #>MSG_ABORT
                        JSR             PUTS
                        LDA             #$E0
                        STA             STATUS
                        CLC
                        RTS

READ_ONE:               JSR             READ_LINE
                        BCC             READ_ONE_FAIL
                        LDA             INPUT+1
                        BNE             READ_ONE_FAIL
                        LDA             INPUT
                        SEC
                        RTS
READ_ONE_FAIL:          CLC
                        RTS

READ_LINE:              LDX             #<INPUT
                        LDY             #>INPUT
                        JMP             SYS_READ_CSTRING_ECHO_UPPER

HEX_VALUE:              CMP             #'0'
                        BCC             HEX_VALUE_BAD
                        CMP             #':'
                        BCC             HEX_VALUE_DIGIT
                        CMP             #'A'
                        BCC             HEX_VALUE_BAD
                        CMP             #'G'
                        BCS             HEX_VALUE_BAD
                        SEC
                        SBC             #$37
                        SEC
                        RTS
HEX_VALUE_DIGIT:        AND             #$0F
                        SEC
                        RTS
HEX_VALUE_BAD:          CLC
                        RTS

; M is a read-only 4-bank x 8-sector map.
; Role bytes come from the live Bank-3 top sector.
; Other sectors are staged before inspection.
; Bank 3 is restored before every output call.
MAP_RUN:                PHP
                        SEI
                        LDA             #$03
                        JSR             BANK_SELECT_RAM
                        BCS             MAP_ROLE_OK
                        PLP
                        JMP             STAGE_FAIL
MAP_ROLE_OK:            LDA             $FFF0
                        STA             WORK_ROLE
                        LDA             $FFF1
                        STA             BACKUP_ROLE
                        PLP
                        LDX             #<MSG_MAP_TITLE
                        LDY             #>MSG_MAP_TITLE
                        JSR             PUTS
                        STZ             MAP_BANK
MAP_BANK_LOOP:          LDA             #'B'
                        JSR             PUTC
                        LDA             MAP_BANK
                        CLC
                        ADC             #'0'
                        JSR             PUTC
                        LDA             #$80
                        STA             MAP_SECTOR
MAP_SECTOR_LOOP:        LDA             #' '
                        JSR             PUTC
                        LDA             MAP_BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             AP_TMP0
                        LDA             MAP_SECTOR
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        ORA             AP_TMP0
                        CMP             WORK_ROLE
                        BNE             MAP_NOT_WORK
                        LDA             #'W'
                        BRA             MAP_MARK
MAP_NOT_WORK:           CMP             BACKUP_ROLE
                        BNE             MAP_NOT_BACKUP
                        LDA             #'B'
                        BRA             MAP_MARK
MAP_NOT_BACKUP:         LDA             MAP_BANK
                        CMP             #$03
                        BNE             MAP_STAGE
                        LDA             MAP_SECTOR
                        CMP             #$F0
                        BNE             MAP_STAGE
                        LDA             #'P'
                        BRA             MAP_MARK
MAP_STAGE:              LDA             MAP_BANK
                        STA             BANK_NO
                        LDA             MAP_SECTOR
                        STA             SECTOR_HI
                        JSR             STAGE
                        BCS             MAP_STAGED
                        JMP             STAGE_FAIL
MAP_STAGED:             JSR             MAP_ERASED
                        BCC             MAP_USED
                        LDA             #'E'
                        BRA             MAP_MARK
MAP_USED:               JSR             AP_SCAN
                        BCC             MAP_PLAIN
                        LDA             #'A'
                        BRA             MAP_MARK
MAP_PLAIN:              LDA             #'U'
MAP_MARK:               JSR             PUTC
                        LDA             MAP_SECTOR
                        CLC
                        ADC             #$10
                        STA             MAP_SECTOR
                        BNE             MAP_SECTOR_LOOP
                        JSR             CRLF
                        INC             MAP_BANK
                        LDA             MAP_BANK
                        CMP             #$04
                        BCS             MAP_DONE
                        JMP             MAP_BANK_LOOP
MAP_DONE:               LDX             #<MSG_MAP_LEGEND
                        LDY             #>MSG_MAP_LEGEND
                        JSR             PUTS
                        LDX             #<MSG_MAP_OK
                        LDY             #>MSG_MAP_OK
                        JSR             PUTS
                        LDA             #$AC
                        STA             STATUS
                        SEC
                        RTS

MAP_ERASED:             STZ             PTR_LO
                        LDA             #BUFFER_HI
                        STA             PTR_HI
                        LDX             #$10
MAP_ERASED_PAGE:        LDY             #$00
MAP_ERASED_BYTE:        LDA             (PTR_LO),Y
                        CMP             #$FF
                        BNE             MAP_NOT_ERASED
                        INY
                        BNE             MAP_ERASED_BYTE
                        INC             PTR_HI
                        DEX
                        BNE             MAP_ERASED_PAGE
                        SEC
                        RTS
MAP_NOT_ERASED:         CLC
                        RTS

STAGE:                  PHP
                        SEI
                        LDA             #$03
                        JSR             BANK_SELECT
                        BCC             STAGE_BAD
                        LDA             BANK_NO
                        JSR             BANK_SELECT_RAM
                        BCC             STAGE_BAD
                        STZ             SRC_LO
                        LDA             SECTOR_HI
                        STA             SRC_HI
                        STZ             DST_LO
                        LDA             #BUFFER_HI
                        STA             DST_HI
                        LDX             #$10
STAGE_PAGE:             LDY             #$00
STAGE_BYTE:             LDA             (SRC_LO),Y
                        STA             (DST_LO),Y
                        INY
                        BNE             STAGE_BYTE
                        INC             SRC_HI
                        INC             DST_HI
                        DEX
                        BNE             STAGE_PAGE
                        LDA             #$03
                        JSR             BANK_SELECT_RAM
                        BCC             STAGE_BAD
                        PLP
                        SEC
                        RTS
STAGE_BAD:              LDA             #$03
                        JSR             BANK_SELECT_RAM
                        PLP
                        CLC
                        RTS

CRC16:                  LDA             #$FF
                        STA             CRC_LO
                        STA             CRC_HI
                        STZ             PTR_LO
                        LDA             #BUFFER_HI
                        STA             PTR_HI
                        LDX             #$10
CRC_PAGE:               LDY             #$00
CRC_BYTE:               LDA             (PTR_LO),Y
                        EOR             CRC_HI
                        STA             CRC_HI
                        PHX
                        LDX             #$08
CRC_BIT:                ASL             CRC_LO
                        ROL             CRC_HI
                        BCC             CRC_NEXT
                        LDA             CRC_LO
                        EOR             #$21
                        STA             CRC_LO
                        LDA             CRC_HI
                        EOR             #$10
                        STA             CRC_HI
CRC_NEXT:               DEX
                        BNE             CRC_BIT
                        PLX
                        INY
                        BNE             CRC_BYTE
                        INC             PTR_HI
                        DEX
                        BNE             CRC_PAGE
                        LDA             CRC_LO
                        STA             CRC_LO_RESULT
                        LDA             CRC_HI
                        STA             CRC_HI_RESULT
                        RTS

; Bank Maintenance-compatible AP-v2 validator.
; It scans the staged sector and validates section order.
; It also validates bounds and matches the body FNV.
AP_NEED:                STA             AP_TMP1
                        LDA             AP_REMAIN_HI
                        BNE             AP_NEED_OK
                        LDA             AP_REMAIN_LO
                        CMP             AP_TMP1
                        BCS             AP_NEED_OK
                        CLC
                        RTS
AP_NEED_OK:             SEC
                        RTS

AP_ADV:                 STA             AP_TMP1
                        JSR             AP_NEED
                        BCC             AP_ADV_BAD
                        LDA             AP_PARSE_LO
                        CLC
                        ADC             AP_TMP1
                        STA             AP_PARSE_LO
                        LDA             AP_PARSE_HI
                        ADC             #$00
                        STA             AP_PARSE_HI
                        LDA             AP_REMAIN_LO
                        SEC
                        SBC             AP_TMP1
                        STA             AP_REMAIN_LO
                        LDA             AP_REMAIN_HI
                        SBC             #$00
                        STA             AP_REMAIN_HI
                        SEC
                        RTS
AP_ADV_BAD:             CLC
                        RTS

AP_TAG:                 STA             AP_TMP0
                        LDA             #$03
                        JSR             AP_NEED
                        BCC             AP_TAG_BAD
                        LDY             #$00
                        LDA             (AP_PARSE_LO),Y
                        CMP             AP_TMP0
                        BNE             AP_TAG_BAD
                        INY
                        LDA             (AP_PARSE_LO),Y
                        STA             AP_SECTION_LEN
                        INY
                        LDA             (AP_PARSE_LO),Y
                        BNE             AP_TAG_BAD
                        LDA             #$03
                        JMP             AP_ADV
AP_TAG_BAD:             CLC
                        RTS

AP_HEAD:                LDA             AP_CAND_HI
                        CMP             #BUFFER_HI
                        BCC             AP_HEAD_BAD
                        CMP             #$50
                        BCS             AP_HEAD_BAD
                        LDA             #$00
                        SEC
                        SBC             AP_CAND_LO
                        STA             AP_REMAIN_LO
                        LDA             #$50
                        SBC             AP_CAND_HI
                        STA             AP_REMAIN_HI
                        LDA             #$05
                        JSR             AP_NEED
                        BCC             AP_HEAD_BAD
                        LDY             #$00
                        LDA             (AP_CAND_LO),Y
                        CMP             #'A'
                        BNE             AP_HEAD_BAD
                        INY
                        LDA             (AP_CAND_LO),Y
                        CMP             #'P'
                        BNE             AP_HEAD_BAD
                        INY
                        LDA             (AP_CAND_LO),Y
                        CMP             #$02
                        BNE             AP_HEAD_BAD
                        INY
                        LDA             (AP_CAND_LO),Y
                        STA             AP_PACKAGE_LO
                        INY
                        LDA             (AP_CAND_LO),Y
                        STA             AP_PACKAGE_HI
                        LDA             AP_PACKAGE_HI
                        CMP             AP_REMAIN_HI
                        BCC             AP_HEAD_FIT
                        BNE             AP_HEAD_BAD
                        LDA             AP_PACKAGE_LO
                        CMP             AP_REMAIN_LO
                        BCC             AP_HEAD_FIT
                        BNE             AP_HEAD_BAD
AP_HEAD_FIT:            LDA             AP_CAND_LO
                        STA             AP_PARSE_LO
                        LDA             AP_CAND_HI
                        STA             AP_PARSE_HI
                        LDA             AP_PACKAGE_LO
                        STA             AP_REMAIN_LO
                        LDA             AP_PACKAGE_HI
                        STA             AP_REMAIN_HI
                        LDA             #$05
                        JSR             AP_ADV
                        BCC             AP_HEAD_BAD
                        SEC
                        RTS
AP_HEAD_BAD:            CLC
                        RTS

AP_SEAL:                LDA             #'S'
                        JSR             AP_TAG
                        BCC             AP_SEAL_BAD
                        LDA             AP_SECTION_LEN
                        CMP             #$0B
                        BNE             AP_SEAL_BAD
                        JSR             AP_NEED
                        BCC             AP_SEAL_BAD
                        LDY             #$00
                        LDA             (AP_PARSE_LO),Y
                        CMP             #$01
                        BNE             AP_SEAL_BAD
                        LDY             #$05
                        LDA             (AP_PARSE_LO),Y
                        STA             AP_BODY_LO
                        INY
                        LDA             (AP_PARSE_LO),Y
                        STA             AP_BODY_HI
                        ORA             AP_BODY_LO
                        BEQ             AP_SEAL_BAD
                        LDY             #$01
                        LDA             (AP_PARSE_LO),Y
                        CLC
                        LDY             #$05
                        ADC             (AP_PARSE_LO),Y
                        STA             AP_TMP0
                        LDY             #$02
                        LDA             (AP_PARSE_LO),Y
                        LDY             #$06
                        ADC             (AP_PARSE_LO),Y
                        BCS             AP_SEAL_BAD
                        STA             AP_TMP1
                        LDY             #$03
                        LDA             (AP_PARSE_LO),Y
                        CMP             AP_TMP0
                        BNE             AP_SEAL_BAD
                        LDY             #$04
                        LDA             (AP_PARSE_LO),Y
                        CMP             AP_TMP1
                        BNE             AP_SEAL_BAD
                        LDY             #$07
                        LDX             #$00
AP_SEAL_FNV:            LDA             (AP_PARSE_LO),Y
                        STA             AP_EXPECT_FNV0,X
                        INY
                        INX
                        CPX             #$04
                        BNE             AP_SEAL_FNV
                        LDA             #$0B
                        JSR             AP_ADV
                        BCC             AP_SEAL_BAD
                        SEC
                        RTS
AP_SEAL_BAD:            CLC
                        RTS

AP_RELOC:               LDA             #'R'
                        JSR             AP_TAG
                        BCC             AP_RELOC_BAD
                        LDA             AP_SECTION_LEN
                        BEQ             AP_RELOC_BAD
                        JSR             AP_NEED
                        BCC             AP_RELOC_BAD
                        LDY             #$00
                        LDA             (AP_PARSE_LO),Y
                        CMP             #$11
                        BCS             AP_RELOC_BAD
                        STA             AP_TMP0
                        ASL             A
                        ASL             A
                        CLC
                        ADC             AP_TMP0
                        INC             A
                        CMP             AP_SECTION_LEN
                        BNE             AP_RELOC_BAD
                        LDA             AP_SECTION_LEN
                        JSR             AP_ADV
                        BCC             AP_RELOC_BAD
                        SEC
                        RTS
AP_RELOC_BAD:           CLC
                        RTS

AP_RECORD:              JSR             AP_TAG
                        BCC             AP_RECORD_BAD
                        LDA             AP_SECTION_LEN
                        BEQ             AP_RECORD_BAD
                        JSR             AP_NEED
                        BCC             AP_RECORD_BAD
                        LDA             AP_SECTION_LEN
                        JSR             AP_ADV
                        BCC             AP_RECORD_BAD
                        SEC
                        RTS
AP_RECORD_BAD:          CLC
                        RTS

AP_BODY:                LDA             #$03
                        JSR             AP_NEED
                        BCC             AP_BODY_BAD
                        LDY             #$00
                        LDA             (AP_PARSE_LO),Y
                        CMP             #'B'
                        BNE             AP_BODY_BAD
                        INY
                        LDA             (AP_PARSE_LO),Y
                        CMP             AP_BODY_LO
                        BNE             AP_BODY_BAD
                        INY
                        LDA             (AP_PARSE_LO),Y
                        CMP             AP_BODY_HI
                        BNE             AP_BODY_BAD
                        LDA             #$03
                        JSR             AP_ADV
                        BCC             AP_BODY_BAD
                        LDA             AP_REMAIN_LO
                        CMP             AP_BODY_LO
                        BNE             AP_BODY_BAD
                        LDA             AP_REMAIN_HI
                        CMP             AP_BODY_HI
                        BNE             AP_BODY_BAD
                        LDA             AP_PARSE_LO
                        STA             AP_BODY_PTR_LO
                        LDA             AP_PARSE_HI
                        STA             AP_BODY_PTR_HI
                        SEC
                        RTS
AP_BODY_BAD:            CLC
                        RTS

AP_HASH:                JSR             FNV_INIT
                        LDA             AP_BODY_LO
                        STA             AP_BODY_COUNT_LO
                        LDA             AP_BODY_HI
                        STA             AP_BODY_COUNT_HI
AP_HASH_MORE:           LDA             AP_BODY_COUNT_LO
                        ORA             AP_BODY_COUNT_HI
                        BEQ             AP_HASH_CHECK
                        LDY             #$00
                        LDA             (AP_BODY_PTR_LO),Y
                        JSR             FNV_UPDATE
                        INC             AP_BODY_PTR_LO
                        BNE             AP_HASH_COUNT
                        INC             AP_BODY_PTR_HI
AP_HASH_COUNT:          DEC             AP_BODY_COUNT_LO
                        LDA             AP_BODY_COUNT_LO
                        CMP             #$FF
                        BNE             AP_HASH_MORE
                        DEC             AP_BODY_COUNT_HI
                        BRA             AP_HASH_MORE
AP_HASH_CHECK:          LDX             #$03
AP_HASH_BYTE:           LDA             FNV0,X
                        CMP             AP_EXPECT_FNV0,X
                        BNE             AP_HASH_BAD
                        DEX
                        BPL             AP_HASH_BYTE
                        SEC
                        RTS
AP_HASH_BAD:            CLC
                        RTS

AP_SCAN:                STZ             AP_CAND_LO
                        LDA             #BUFFER_HI
                        STA             AP_CAND_HI
                        BRA             AP_SCAN_NEXT
AP_SCAN_ADV:            INC             AP_CAND_LO
                        BNE             AP_SCAN_NEXT
                        INC             AP_CAND_HI
                        LDA             AP_CAND_HI
                        CMP             #$50
                        BCC             AP_SCAN_NEXT
                        CLC
                        RTS
AP_SCAN_NEXT:           LDY             #$00
                        LDA             (AP_CAND_LO),Y
                        CMP             #'A'
                        BNE             AP_SCAN_ADV
                        JSR             AP_HEAD
                        BCC             AP_SCAN_ADV
                        JSR             AP_SEAL
                        BCC             AP_SCAN_ADV
                        JSR             AP_RELOC
                        BCC             AP_SCAN_ADV
                        LDA             #'E'
                        JSR             AP_RECORD
                        BCC             AP_SCAN_ADV
                        LDA             #'I'
                        JSR             AP_RECORD
                        BCC             AP_SCAN_ADV
                        JSR             AP_BODY
                        BCC             AP_SCAN_ADV
                        JSR             AP_HASH
                        BCC             AP_SCAN_ADV
                        SEC
                        RTS

FNV_INIT:               LDX             #$03
FNV_INIT_BYTE:          LDA             FNV_BASIS,X
                        STA             FNV0,X
                        DEX
                        BPL             FNV_INIT_BYTE
                        RTS
FNV_BASIS:              DB              $C5,$9D,$1C,$81

FNV_UPDATE:             EOR             FNV0
                        STA             FNV0
                        LDX             #$03
FNV_COPY:               LDA             FNV0,X
                        STA             FNV_SHIFT0,X
                        DEX
                        BPL             FNV_COPY
                        LDX             #$01
                        JSR             FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             FNV_SHIFT_ADD
                        LDX             #$03
                        JSR             FNV_SHIFT_ADD
                        LDX             #$01
                        JSR             FNV_SHIFT_ADD
                        LDA             FNV3
                        CLC
                        ADC             FNV_SHIFT1
                        STA             FNV3
                        RTS
FNV_SHIFT_ADD:          JSR             FNV_SHIFT
                        CLC
                        LDA             FNV0
                        ADC             FNV_SHIFT0
                        STA             FNV0
                        LDA             FNV1
                        ADC             FNV_SHIFT1
                        STA             FNV1
                        LDA             FNV2
                        ADC             FNV_SHIFT2
                        STA             FNV2
                        LDA             FNV3
                        ADC             FNV_SHIFT3
                        STA             FNV3
                        RTS
FNV_SHIFT:              ASL             FNV_SHIFT0
                        ROL             FNV_SHIFT1
                        ROL             FNV_SHIFT2
                        ROL             FNV_SHIFT3
                        DEX
                        BNE             FNV_SHIFT
                        RTS

PRINT_SELECTION:        LDX             #<MSG_SELECTED
                        LDY             #>MSG_SELECTED
                        JSR             PUTS
                        LDA             BANK_NO
                        CLC
                        ADC             #'0'
                        JSR             PUTC
                        LDA             #':'
                        JSR             PUTC
                        LDA             SECTOR_HI
                        JSR             HEX_BYTE
                        LDA             #$00
                        JSR             HEX_BYTE
                        LDX             #<MSG_CRC
                        LDY             #>MSG_CRC
                        JSR             PUTS
                        LDA             CRC_HI_RESULT
                        JSR             HEX_BYTE
                        LDA             CRC_LO_RESULT
                        JSR             HEX_BYTE
                        JMP             CRLF

PRINT_AP_HEADER:        LDA             $4000
                        CMP             #'A'
                        BEQ             AP_SIG0_OK
                        JMP             AP_NOT_V2
AP_SIG0_OK:             LDA             $4001
                        CMP             #'P'
                        BEQ             AP_SIG1_OK
                        JMP             AP_NOT_V2
AP_SIG1_OK:             LDA             $4002
                        CMP             #$02
                        BEQ             AP_VERSION_OK
                        JMP             AP_NOT_V2
AP_VERSION_OK:          LDA             $4005
                        CMP             #'S'
                        BEQ             AP_SEAL_OK
                        JMP             AP_BAD_SHAPE
AP_SEAL_OK:             LDA             $4006
                        CMP             #$0B
                        BEQ             AP_SEAL_LEN_OK
                        JMP             AP_BAD_SHAPE
AP_SEAL_LEN_OK:         LDA             $4007
                        BEQ             AP_SHAPE_OK
                        JMP             AP_BAD_SHAPE
AP_SHAPE_OK:            LDX             #<MSG_APC
                        LDY             #>MSG_APC
                        JSR             PUTS
                        LDA             $4002
                        JSR             HEX_BYTE
                        LDX             #<MSG_PKG
                        LDY             #>MSG_PKG
                        JSR             PUTS
                        LDA             $4004
                        JSR             HEX_BYTE
                        LDA             $4003
                        JSR             HEX_BYTE
                        LDX             #<MSG_BASE
                        LDY             #>MSG_BASE
                        JSR             PUTS
                        LDA             $400A
                        JSR             HEX_BYTE
                        LDA             $4009
                        JSR             HEX_BYTE
                        LDX             #<MSG_END
                        LDY             #>MSG_END
                        JSR             PUTS
                        LDA             $400C
                        JSR             HEX_BYTE
                        LDA             $400B
                        JSR             HEX_BYTE
                        LDX             #<MSG_BODY
                        LDY             #>MSG_BODY
                        JSR             PUTS
                        LDA             $400E
                        JSR             HEX_BYTE
                        LDA             $400D
                        JSR             HEX_BYTE
                        LDX             #<MSG_FNV
                        LDY             #>MSG_FNV
                        JSR             PUTS
                        LDA             $4012
                        JSR             HEX_BYTE
                        LDA             $4011
                        JSR             HEX_BYTE
                        LDA             $4010
                        JSR             HEX_BYTE
                        LDA             $400F
                        JSR             HEX_BYTE
                        JMP             CRLF
AP_NOT_V2:              LDX             #<MSG_NOT_AP
                        LDY             #>MSG_NOT_AP
                        JMP             PUTS
AP_BAD_SHAPE:           LDX             #<MSG_BAD_AP
                        LDY             #>MSG_BAD_AP
                        JMP             PUTS

DUMP_256:               STZ             PTR_LO
                        LDA             PAGE_NO
                        CLC
                        ADC             #BUFFER_HI
                        STA             PTR_HI
                        STZ             ADDR_LO
                        LDA             PAGE_NO
                        CLC
                        ADC             SECTOR_HI
                        STA             ADDR_HI
                        LDA             #$10
                        STA             ROWS_LEFT
DUMP_ROW:               JSR             CRLF
                        LDA             ADDR_HI
                        JSR             HEX_BYTE
                        LDA             ADDR_LO
                        JSR             HEX_BYTE
                        LDA             #':'
                        JSR             PUTC
                        LDA             #' '
                        JSR             PUTC
                        LDY             #$00
DUMP_HEX:               LDA             (PTR_LO),Y
                        JSR             HEX_BYTE
                        LDA             #' '
                        JSR             PUTC
                        INY
                        CPY             #$10
                        BNE             DUMP_HEX
                        LDA             #'|'
                        JSR             PUTC
                        LDY             #$00
DUMP_ASCII:             LDA             (PTR_LO),Y
                        CMP             #$20
                        BCC             DUMP_DOT
                        CMP             #$7F
                        BCS             DUMP_DOT
                        BRA             DUMP_CHAR
DUMP_DOT:               LDA             #'.'
DUMP_CHAR:              JSR             PUTC
                        INY
                        CPY             #$10
                        BNE             DUMP_ASCII
                        LDA             #'|'
                        JSR             PUTC
                        LDA             PTR_LO
                        CLC
                        ADC             #$10
                        STA             PTR_LO
                        BCC             DUMP_ADDR
                        INC             PTR_HI
DUMP_ADDR:              LDA             ADDR_LO
                        CLC
                        ADC             #$10
                        STA             ADDR_LO
                        BCC             DUMP_NEXT
                        INC             ADDR_HI
DUMP_NEXT:              DEC             ROWS_LEFT
                        BNE             DUMP_ROW
                        JMP             CRLF

HEX_BYTE:               PHA
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        JSR             HEX_NIBBLE
                        PLA
                        AND             #$0F
HEX_NIBBLE:             CMP             #$0A
                        BCC             HEX_DIGIT
                        CLC
                        ADC             #$37
                        JMP             PUTC
HEX_DIGIT:              CLC
                        ADC             #'0'
PUTC:                   JMP             BIO_FTDI_WRITE_BYTE_BLOCK
PUTS:                   JMP             BIO_FTDI_PUT_CSTR
CRLF:                   LDA             #$0D
                        JSR             PUTC
                        LDA             #$0A
                        JMP             PUTC

MSG_TITLE:              DB              $0D,$0A,'B','A','N','K','D','U','M','P'
                        DB              ' ','R','E','A','D','-','O','N','L','Y',$0D,$0A,0
MSG_BANK:               DB              'B','A','N','K',' ','0','-','3',' '
                        DB              'O','R',' ','M','=','M','A','P','>',' ',0
MSG_SECTOR:             DB              'S','E','C','T','O','R',' ','8','-','F','>',' ',0
MSG_MODE:               DB              'H','=','A','P','C',' ','H','E','A','D','E','R',' '
                        DB              'P','=','P','A','G','E',' ','A','=','A','L','L',' '
                        DB              'Q','=','Q','U','I','T','>',' ',0
MSG_PAGE:               DB              'P','A','G','E',' ','0','-','F','>',' ',0
MSG_BAD_BANK:           DB              '?',' ','B','A','N','K',' ','0','-','3'
                        DB              $0D,$0A,0
MSG_BAD_SECTOR:         DB              '?',' ','S','E','C','T','O','R'
                        DB              ' ','8','-','F',$0D,$0A,0
MSG_BAD_MODE:           DB              '?',' ','H',',','P',',','A'
                        DB              ' ','O','R',' ','Q',$0D,$0A,0
MSG_BAD_PAGE:           DB              '?',' ','P','A','G','E',' ','0','-','F'
                        DB              $0D,$0A,0
MSG_SELECTED:           DB              $0D,$0A,'B','A','N','K','D','U','M','P'
                        DB              ' ','B',0
MSG_CRC:                DB              ' ','C','R','C','1','6','=',0
MSG_APC:                DB              'A','P','C',' ','V','=',0
MSG_PKG:                DB              ' ','P','K','G','=',0
MSG_BASE:               DB              ' ','B','A','S','E','=',0
MSG_END:                DB              ' ','E','N','D','=',0
MSG_BODY:               DB              ' ','B','O','D','Y','=',0
MSG_FNV:                DB              ' ','F','N','V','=',0
MSG_NOT_AP:             DB              'A','P','C',' ','H','E','A','D','E','R',':'
                        DB              ' ','N','O','T',' ','A','P',' ','V','2',$0D,$0A,0
MSG_BAD_AP:             DB              'A','P','C',' ','H','E','A','D','E','R',':'
                        DB              ' ','B','A','D',' ','S','H','A','P','E',$0D,$0A,0
MSG_MORE:               DB              $0D,$0A,'-','-',' ','M','O','R','E',' '
                        DB              '(','E','N','T','E','R','=','N','E','X','T',','
                        DB              ' ','Q','=','Q','U','I','T',')','>',' ',0
MSG_OK:                 DB              $0D,$0A,'B','A','N','K','D','U','M','P'
                        DB              ' ','O','K',$3B,' ','B','3',' '
                        DB              'R','E','S','T','O','R','E','D',$0D,$0A,0
MSG_STAGE_FAIL:         DB              $0D,$0A,'B','A','N','K','D','U','M','P'
                        DB              ' ','E','1',$3B,' ','B','3',' '
                        DB              'R','E','S','T','O','R','E',' '
                        DB              'A','T','T','E','M','P','T','E','D',$0D,$0A,0
MSG_ABORT:              DB              $0D,$0A,'B','A','N','K','D','U','M','P'
                        DB              ' ','Q','U','I','T',$3B,' ','N','O',' '
                        DB              'F','L','A','S','H',' '
                        DB              'W','R','I','T','E',$0D,$0A,0
MSG_MAP_TITLE:          DB              $0D,$0A,'B','#',' ','8',' ','9',' ','A'
                        DB              ' ','B',' ','C',' ','D',' ','E',' ','F'
                        DB              $0D,$0A,$0D,$0A,0
MSG_MAP_LEGEND:         DB              'E','=','E','R','A','S','E','D',' '
                        DB              'U','=','U','S','E','D',' '
                        DB              'A','=','A','P',' ','V','A','L','I','D'
                        DB              $0D,$0A,'W','=','W','O','R','K',' '
                        DB              'B','=','B','3','F',' ','B','K','U','P',' '
                        DB              'P','=','B','3','F',' ','P','R','O','T'
                        DB              'E','C','T','E','D',$0D,$0A,0
MSG_MAP_OK:             DB              'B','A','N','K','D','U','M','P',' '
                        DB              'M','A','P',' ','O','K',$3B,' ','B','3',' '
                        DB              'R','E','S','T','O','R','E','D',$0D,$0A,0
; END SHARED BANKDUMP BODY

_END_CODE:
                        ENDMOD
                        END

; ---------------------------------------------------------------------------
; Host-built counterpart of bank-dump-2000.a.
;
; BANKDUMP is a read-only fixed-$2000 APC.  It selects one physical bank/sector,
; stages the complete 4K sector at $4000, restores Bank 3, computes CRC16,
; and presents either a decoded AP-v2 header, one 256-byte page, or the whole
; sector as 16-byte hexadecimal/ASCII rows.
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
MSG_BANK:               DB              'B','A','N','K',' ','0','-','3','>',' ',0
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
; END SHARED BANKDUMP BODY

_END_CODE:
                        ENDMOD
                        END

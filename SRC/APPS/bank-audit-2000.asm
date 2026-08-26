; ---------------------------------------------------------------------------
; Host-built counterpart of bank-audit-2000.a.
;
; BANKAUDIT is a read-only movable-AP utility.  It stages every 4K flash
; sector through $4000, computes CRC-16/CCITT-FALSE, prints four compact rows,
; snapshots Bank-3 role bytes, restores Bank 3, and never reaches a flash
; erase/program doorway.
; ---------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          BANK_AUDIT
                        XDEF            BANKAUDIT
                        XDEF            _END_CODE

; Current host-linked HIMON service.  The onboard .a uses an AP import, so its
; stored package remains map-independent across compatible HIMON builds.
BIO_FTDI_PUT_CSTR       EQU             $E7D3

STATUS                  EQU             $7C00
FAIL_BANK               EQU             $7C01
FAIL_SECTOR             EQU             $7C02
ROLE_BYTES              EQU             $7C08
CRC_TABLE               EQU             $7C10
LINE                    EQU             $7000

PTR_LO                  EQU             $A0
PTR_HI                  EQU             $A1
CRC_LO                  EQU             $A2
CRC_HI                  EQU             $A3
RES_LO                  EQU             $A4
RES_HI                  EQU             $A5
SRC_LO                  EQU             $A6
SRC_HI                  EQU             $A7
DST_LO                  EQU             $A8
DST_HI                  EQU             $A9
BANK_NO                 EQU             $AA
SECTOR_HI               EQU             $AB
SECTOR_NO               EQU             $AC

BANK_SELECT             EQU             $F010
BANK_SELECT_RAM         EQU             $0203
BUFFER_HI               EQU             $40

                        CODE

; BEGIN SHARED BANKAUDIT BODY
BANKAUDIT:              BRA             RUN

RUN:                    STZ             STATUS
                        STZ             FAIL_BANK
                        STZ             FAIL_SECTOR
                        LDA             #<CRC_TABLE
                        STA             RES_LO
                        LDA             #>CRC_TABLE
                        STA             RES_HI
                        STZ             BANK_NO
                        LDA             #$03
                        JSR             BANK_SELECT
                        BCC             FAIL

BANK_LOOP:              LDA             #$80
                        STA             SECTOR_HI

SECTOR_LOOP:            JSR             STAGE
                        BCC             FAIL
                        JSR             CRC16
                        LDA             SECTOR_HI
                        CMP             #$F0
                        BNE             STORE_CRC
                        LDA             BANK_NO
                        ASL             A
                        TAX
                        LDA             $4FF0
                        STA             ROLE_BYTES,X
                        LDA             $4FF1
                        STA             ROLE_BYTES+1,X

STORE_CRC:              LDY             #$00
                        LDA             CRC_LO
                        STA             (RES_LO),Y
                        INY
                        LDA             CRC_HI
                        STA             (RES_LO),Y
                        LDA             RES_LO
                        CLC
                        ADC             #$02
                        STA             RES_LO
                        BCC             NEXT_SECTOR
                        INC             RES_HI

NEXT_SECTOR:            LDA             SECTOR_HI
                        CLC
                        ADC             #$10
                        STA             SECTOR_HI
                        BNE             SECTOR_LOOP
                        INC             BANK_NO
                        LDA             BANK_NO
                        CMP             #$04
                        BNE             BANK_LOOP
                        JSR             PRINT_REPORT
                        LDA             #$AC
                        STA             STATUS
                        SEC
                        RTS

FAIL:                   LDA             BANK_NO
                        STA             FAIL_BANK
                        LDA             SECTOR_HI
                        STA             FAIL_SECTOR
                        LDX             #<MSG_FAIL
                        LDY             #>MSG_FAIL
                        JSR             BIO_FTDI_PUT_CSTR
                        LDA             #$E1
                        STA             STATUS
                        CLC
                        RTS

STAGE:                  PHP
                        SEI
                        LDA             BANK_NO
                        JSR             BANK_SELECT_RAM
                        BCC             STAGE_FAIL
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
                        BCC             STAGE_FAIL
                        PLP
                        SEC
                        RTS

STAGE_FAIL:             LDA             #$03
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
                        JSR             CRC_UPDATE
                        INY
                        BNE             CRC_BYTE
                        INC             PTR_HI
                        DEX
                        BNE             CRC_PAGE
                        RTS

CRC_UPDATE:             EOR             CRC_HI
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
                        RTS

PRINT_REPORT:           LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             BIO_FTDI_PUT_CSTR
                        LDA             #<CRC_TABLE
                        STA             RES_LO
                        LDA             #>CRC_TABLE
                        STA             RES_HI
                        STZ             BANK_NO

PRINT_BANK:             LDX             #$00
                        LDA             #'B'
                        STA             LINE,X
                        INX
                        LDA             BANK_NO
                        CLC
                        ADC             #'0'
                        STA             LINE,X
                        INX
                        LDA             #' '
                        STA             LINE,X
                        INX
                        LDA             #$08
                        STA             SECTOR_NO

PRINT_SECTOR:           LDA             SECTOR_NO
                        CMP             #$0A
                        BCC             PRINT_SECTOR_DIGIT
                        CLC
                        ADC             #$37
                        BRA             PRINT_SECTOR_NAME
PRINT_SECTOR_DIGIT:     CLC
                        ADC             #'0'
PRINT_SECTOR_NAME:      STA             LINE,X
                        INX
                        LDA             #'='
                        STA             LINE,X
                        INX
                        LDY             #$01
                        LDA             (RES_LO),Y
                        JSR             HEX_STORE
                        DEY
                        LDA             (RES_LO),Y
                        JSR             HEX_STORE
                        LDA             #' '
                        STA             LINE,X
                        INX
                        LDA             RES_LO
                        CLC
                        ADC             #$02
                        STA             RES_LO
                        BCC             PRINT_NEXT
                        INC             RES_HI
PRINT_NEXT:             INC             SECTOR_NO
                        LDA             SECTOR_NO
                        CMP             #$10
                        BNE             PRINT_SECTOR
                        LDA             #$0D
                        STA             LINE,X
                        INX
                        LDA             #$0A
                        STA             LINE,X
                        INX
                        STZ             LINE,X
                        LDX             #<LINE
                        LDY             #>LINE
                        JSR             BIO_FTDI_PUT_CSTR
                        INC             BANK_NO
                        LDA             BANK_NO
                        CMP             #$04
                        BNE             PRINT_BANK

                        LDX             #<MSG_OK
                        LDY             #>MSG_OK
                        JSR             BIO_FTDI_PUT_CSTR
                        RTS

HEX_STORE:              PHA
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
                        BRA             HEX_PUT
HEX_DIGIT:              CLC
                        ADC             #'0'
HEX_PUT:                STA             LINE,X
                        INX
                        RTS

MSG_TITLE:              DB              $0D,$0A,'B','A','N','K','A','U','D','I','T',' '
                        DB              'C','R','C','1','6','/','4','K',$0D,$0A,0
MSG_OK:                 DB              'B','A','N','K','A','U','D','I','T',' ','O','K',';',' '
                        DB              'B','3',' ','R','E','S','T','O','R','E','D',$0D,$0A,0
MSG_FAIL:               DB              $0D,$0A,'B','A','N','K','A','U','D','I','T',' '
                        DB              'E','1',';',' ','B','3',' ','R','E','S','T','O','R','E',' '
                        DB              'A','T','T','E','M','P','T','E','D',$0D,$0A,0
; END SHARED BANKAUDIT BODY

_END_CODE:
                        ENDMOD
                        END

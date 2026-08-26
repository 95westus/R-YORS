; ---------------------------------------------------------------------------
; APMAN V1 -- banked AP carrier manager, fixed at $7000.
;
; This first carrier manager deliberately keeps the media model small:
; exactly one complete AP v2 envelope at a 4K sector base. It understands the
; entry-export name, rejects duplicate names, loads/fixes without execution,
; executes on request, inventories carriers and AP Store headers, and installs
; only into a completely erased, unreserved sector.
;
; HIMON discovers and loads this package. All monitor calls go through the
; published RAM service card, so this body does not embed HIMON code addresses.
; ---------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          APMAN_V1
                        XDEF            APMAN
                        XDEF            _END_CODE
                        XDEF            APMAN_IMAGE_END

                        INCLUDE         "ASM/asm-abi-v1.inc"
                        INCLUDE         "ASM/ap-store-v1.inc"
                        INCLUDE         "ASM/apman-v1.inc"

HIM_SVC_WRITE_BYTE_LO   EQU             $7E08
HIM_SVC_WRITE_CSTRING_LO EQU            $7E0A
HIM_SVC_WRITE_HEX_BYTE_LO EQU           $7E0C
HIM_SVC_WRITE_CRLF_LO   EQU             $7E0E
HIM_SVC_FNV_INIT_LO     EQU             $7E14
HIM_SVC_FNV_UPDATE_LO   EQU             $7E16
HIM_SVC_AP_LO           EQU             $7E2D
HIM_AP_OP               EQU             $7E2F
HIM_AP_STATUS           EQU             $7E30
HIM_AP_SRC_LO           EQU             $7E31
HIM_AP_SRC_HI           EQU             $7E32
HIM_AP_DST_LO           EQU             $7E33
HIM_AP_DST_HI           EQU             $7E34
HIM_AP_PKG_LEN_LO       EQU             $7E35
HIM_AP_PKG_LEN_HI       EQU             $7E36
HIM_AP_BODY_LO          EQU             $7E37
HIM_AP_BODY_HI          EQU             $7E38
HIM_AP_BODY_LEN_LO      EQU             $7E39
HIM_AP_BODY_LEN_HI      EQU             $7E3A

HIM_AP_OP_PARSE         EQU             $00
HIM_AP_OP_LOAD          EQU             $01

FNV_HASH0               EQU             $B0
FNV_HASH1               EQU             $B1
FNV_HASH2               EQU             $B2
FNV_HASH3               EQU             $B3

PTRL                    EQU             $A0
PTRH                    EQU             $A1
TMP0                    EQU             $A2
TMP1                    EQU             $A3
TMP2                    EQU             $A4
TMP3                    EQU             $A5
COUNT                   EQU             $A6
BANK                    EQU             $A7
SECTOR                  EQU             $A8
FLAGS                   EQU             $A9
TAIL_LO                 EQU             $AA
TAIL_HI                 EQU             $AB
ROW_LO                  EQU             $AC
ROW_HI                  EQU             $AD
VALUE_LO                EQU             $AE
VALUE_HI                EQU             $AF

; HIMON copies its command page here before loading APMAN, because the manager
; may occupy $7A00-$7BFF. This low page is otherwise user-free foreground RAM.
CMD_BUF                 EQU             $1A00
STAGE_BASE              EQU             $0A00
STAGE_LIMIT_HI          EQU             $1A
STR8_SELECT             EQU             $F010
STR8_SELECT_RAM         EQU             $0203
STR8_WORKER_ENTRY       EQU             $0200
STR8_WORKER_SECTOR_HI   EQU             $7DE9
STR8_WORKER_DEST_BANK   EQU             $7DEF
STR8_WORKER_MODE        EQU             $7DF0
STR8_WORKER_BUFFER_HI   EQU             $7DF6
WORK_ROLE               EQU             $FFF0
BACKUP_ROLE             EQU             $FFF1

FLAG_LOAD_ONLY          EQU             $01
FLAG_SELECTOR_ADDR      EQU             $02
FLAG_APS_DETAIL         EQU             $04

                        CODE

; The four bytes following the entry branch are the bootstrap identity. The
; resident scanner checks them only after the AP v2 envelope validates.
APMAN:                  BRA             APMAN_DISPATCH
                        DB              'A','M','0','1'

APMAN_DISPATCH:         STZ             APMAN_STATUS
                        STZ             APMAN_FAIL_PHASE
                        LDA             APMAN_MODE
                        CMP             #APMAN_MODE_AP
                        BEQ             APMAN_COMMAND_AP
                        CMP             #APMAN_MODE_APS
                        BNE             APMAN_DISPATCH_NOT_APS
                        JMP             APMAN_COMMAND_APS
APMAN_DISPATCH_NOT_APS:
                        CMP             #APMAN_MODE_INSTALL
                        BNE             APMAN_DISPATCH_BAD
                        JMP             APMAN_INSTALL
APMAN_DISPATCH_BAD:
                        LDA             #APMAN_STATUS_BAD_COMMAND
                        JMP             APMAN_FAIL_A

; ---------------------------------------------------------------------------
; AP Bn name|s000 [destination]
; AP L Bn name|s000 [destination]
; ---------------------------------------------------------------------------
APMAN_COMMAND_AP:       LDA             #<CMD_BUF+2
                        STA             PTRL
                        LDA             #>CMD_BUF+2
                        STA             PTRH
                        STZ             FLAGS
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        CMP             #'L'
                        BNE             APMAN_AP_BANK
                        LDA             #FLAG_LOAD_ONLY
                        STA             FLAGS
                        JSR             APMAN_ADVANCE
                        JSR             APMAN_SKIP_SPACES
APMAN_AP_BANK:          LDY             #$00
                        LDA             (PTRL),Y
                        CMP             #'B'
                        BEQ             APMAN_AP_BANK_OK
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_BANK_OK:
                        JSR             APMAN_ADVANCE
                        LDY             #$00
                        LDA             (PTRL),Y
                        SEC
                        SBC             #'0'
                        BCS             APMAN_AP_BANK_NONNEG
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_BANK_NONNEG:
                        CMP             #$03
                        BCC             APMAN_AP_BANK_RANGE
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_BANK_RANGE:
                        STA             BANK
                        JSR             APMAN_ADVANCE
                        JSR             APMAN_SKIP_SPACES
                        JSR             APMAN_PARSE_SELECTOR
                        BCS             APMAN_AP_SELECTOR_OK
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_SELECTOR_OK:
                        LDA             PTRL
                        STA             TAIL_LO
                        LDA             PTRH
                        STA             TAIL_HI
                        LDA             #APMAN_PHASE_SCAN
                        STA             APMAN_FAIL_PHASE
                        LDA             FLAGS
                        AND             #FLAG_SELECTOR_ADDR
                        BEQ             APMAN_AP_FIND_NAME
                        JSR             APMAN_STAGE_VALIDATE
                        BCS             APMAN_AP_ADDRESS_VALID
                        JMP             APMAN_NOT_FOUND
APMAN_AP_ADDRESS_VALID:
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCS             APMAN_AP_ADDRESS_ENTRY
                        JMP             APMAN_BAD_PACKAGE
APMAN_AP_ADDRESS_ENTRY:
                        BRA             APMAN_AP_HAVE

APMAN_AP_FIND_NAME:     JSR             APMAN_FIND_NAMED
                        BCS             APMAN_AP_HAVE
                        JMP             APMAN_NOT_FOUND
APMAN_AP_HAVE:          JSR             APMAN_SET_PACKAGE_FACTS
                        LDA             TAIL_LO
                        STA             PTRL
                        LDA             TAIL_HI
                        STA             PTRH
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_AP_DEFAULT_DST
                        JSR             APMAN_PARSE_HEX_WORD
                        BCS             APMAN_AP_DST_PARSED
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_DST_PARSED:
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_AP_DST_EOL
                        JMP             APMAN_BAD_COMMAND
APMAN_AP_DST_EOL:
                        LDA             VALUE_LO
                        STA             APMAN_FOUND_LOAD_LO
                        LDA             VALUE_HI
                        STA             APMAN_FOUND_LOAD_HI
                        BRA             APMAN_AP_LOAD
APMAN_AP_DEFAULT_DST:   LDA             STAGE_BASE+$09
                        STA             APMAN_FOUND_LOAD_LO
                        LDA             STAGE_BASE+$0A
                        STA             APMAN_FOUND_LOAD_HI

APMAN_AP_LOAD:          JSR             APMAN_LOAD_RANGE_SAFE
                        BCS             APMAN_AP_LOAD_SAFE
                        JMP             APMAN_BAD_RANGE
APMAN_AP_LOAD_SAFE:     LDA             #APMAN_PHASE_LOAD
                        STA             APMAN_FAIL_PHASE
                        LDA             APMAN_FOUND_LOAD_LO
                        STA             HIM_AP_DST_LO
                        LDA             APMAN_FOUND_LOAD_HI
                        STA             HIM_AP_DST_HI
                        LDA             #HIM_AP_OP_LOAD
                        STA             HIM_AP_OP
                        JSR             APMAN_CALL_AP
                        BCS             APMAN_AP_LOADED
                        JMP             APMAN_BAD_PACKAGE
APMAN_AP_LOADED:
                        LDA             APMAN_FOUND_LOAD_LO
                        CLC
                        LDY             #$01
                        ADC             (ROW_LO),Y
                        STA             APMAN_FOUND_ENTRY_LO
                        LDA             APMAN_FOUND_LOAD_HI
                        INY
                        ADC             (ROW_LO),Y
                        STA             APMAN_FOUND_ENTRY_HI
                        LDX             #<MSG_AP_LOAD
                        LDY             #>MSG_AP_LOAD
                        JSR             APMAN_PUTS
                        JSR             APMAN_PRINT_LOCATION
                        LDX             #<MSG_ARROW
                        LDY             #>MSG_ARROW
                        JSR             APMAN_PUTS
                        LDA             APMAN_FOUND_LOAD_HI
                        JSR             APMAN_HEX
                        LDA             APMAN_FOUND_LOAD_LO
                        JSR             APMAN_HEX
                        JSR             APMAN_CRLF
                        LDA             #APMAN_STATUS_OK
                        STA             APMAN_STATUS
                        LDA             FLAGS
                        AND             #FLAG_LOAD_ONLY
                        BEQ             APMAN_AP_EXECUTE
                        JMP             APMAN_RETURN_OK
APMAN_AP_EXECUTE:
                        LDX             #<MSG_GO
                        LDY             #>MSG_GO
                        JSR             APMAN_PUTS
                        LDA             APMAN_FOUND_ENTRY_HI
                        JSR             APMAN_HEX
                        LDA             APMAN_FOUND_ENTRY_LO
                        JSR             APMAN_HEX
                        JSR             APMAN_CRLF
                        JMP             (APMAN_FOUND_ENTRY_LO)

; ---------------------------------------------------------------------------
; APS                 all status rows
; APS Bn              carrier list for one bank
; APS Bn name|s000    one validated carrier detail
; ---------------------------------------------------------------------------
APMAN_COMMAND_APS:     LDA             #<CMD_BUF+3
                        STA             PTRL
                        LDA             #>CMD_BUF+3
                        STA             PTRH
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        BNE             APMAN_APS_HAVE_ARGS
                        JMP             APMAN_APS_ALL
APMAN_APS_HAVE_ARGS:
                        CMP             #'B'
                        BEQ             APMAN_APS_BANK_OK
                        JMP             APMAN_BAD_COMMAND
APMAN_APS_BANK_OK:
                        JSR             APMAN_ADVANCE
                        LDY             #$00
                        LDA             (PTRL),Y
                        SEC
                        SBC             #'0'
                        BCS             APMAN_APS_BANK_NONNEG
                        JMP             APMAN_BAD_COMMAND
APMAN_APS_BANK_NONNEG:
                        CMP             #$03
                        BCC             APMAN_APS_BANK_RANGE
                        JMP             APMAN_BAD_COMMAND
APMAN_APS_BANK_RANGE:
                        STA             BANK
                        JSR             APMAN_ADVANCE
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_APS_BANK_LIST
                        STZ             FLAGS
                        JSR             APMAN_PARSE_SELECTOR
                        BCS             APMAN_APS_SELECTOR_OK
                        JMP             APMAN_BAD_COMMAND
APMAN_APS_SELECTOR_OK:
                        JSR             APMAN_SKIP_SPACES
                        LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_APS_SELECTOR_EOL
                        JMP             APMAN_BAD_COMMAND
APMAN_APS_SELECTOR_EOL:
                        LDA             FLAGS
                        AND             #FLAG_SELECTOR_ADDR
                        BEQ             APMAN_APS_DETAIL_NAME
                        JSR             APMAN_STAGE_VALIDATE
                        BCS             APMAN_APS_ADDRESS_VALID
                        JMP             APMAN_NOT_FOUND
APMAN_APS_ADDRESS_VALID:
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCS             APMAN_APS_DETAIL
                        JMP             APMAN_BAD_PACKAGE
APMAN_APS_DETAIL_NAME: JSR             APMAN_FIND_NAMED
                        BCS             APMAN_APS_DETAIL
                        JMP             APMAN_NOT_FOUND
APMAN_APS_DETAIL:      JSR             APMAN_SET_PACKAGE_FACTS
                        JSR             APMAN_PRINT_CARRIER_DETAIL
                        JMP             APMAN_RETURN_OK

APMAN_APS_BANK_LIST:   LDA             #$80
                        STA             SECTOR
APMAN_APS_BANK_LOOP:   JSR             APMAN_STAGE_VALIDATE
                        BCC             APMAN_APS_BANK_NEXT
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCC             APMAN_APS_BANK_NEXT
                        JSR             APMAN_SET_PACKAGE_FACTS
                        JSR             APMAN_PRINT_CARRIER_DETAIL
APMAN_APS_BANK_NEXT:   JSR             APMAN_NEXT_SECTOR
                        BCC             APMAN_APS_BANK_LOOP
                        JMP             APMAN_RETURN_OK

APMAN_APS_ALL:         STZ             BANK
APMAN_APS_ALL_BANK:    LDA             #$80
                        STA             SECTOR
APMAN_APS_ALL_SECTOR:  JSR             APMAN_PRINT_STATUS_ROW
                        JSR             APMAN_NEXT_SECTOR
                        BCC             APMAN_APS_ALL_SECTOR
                        INC             BANK
                        LDA             BANK
                        CMP             #$03
                        BCC             APMAN_APS_ALL_BANK
                        LDX             #<MSG_APS_OK
                        LDY             #>MSG_APS_OK
                        JSR             APMAN_PUTS
                        JMP             APMAN_RETURN_OK

; ---------------------------------------------------------------------------
; INSTALL request-card core. The command front end supplies a validated source
; address, bank, and the explicit confirmation byte. This routine finds the
; first completely erased, unreserved sector, stages the full 4K image, and
; invokes the maintained STR8 erase/program/verify worker from low RAM.
; ---------------------------------------------------------------------------
APMAN_INSTALL:         LDA             APMAN_CONFIRM
                        CMP             #APMAN_CONFIRM_INSTALL
                        BEQ             APMAN_INSTALL_CONFIRMED
                        JMP             APMAN_INSTALL_UNCONFIRMED
APMAN_INSTALL_CONFIRMED:
                        LDA             APMAN_INSTALL_BANK
                        CMP             #$03
                        BCC             APMAN_INSTALL_BANK_OK
                        JMP             APMAN_BAD_RANGE
APMAN_INSTALL_BANK_OK:
                        STA             BANK
                        LDA             APMAN_INSTALL_SRC_LO
                        STA             HIM_AP_SRC_LO
                        LDA             APMAN_INSTALL_SRC_HI
                        STA             HIM_AP_SRC_HI
                        LDA             #HIM_AP_OP_PARSE
                        STA             HIM_AP_OP
                        JSR             APMAN_CALL_AP
                        BCS             APMAN_INSTALL_PACKAGE_OK
                        JMP             APMAN_BAD_PACKAGE
APMAN_INSTALL_PACKAGE_OK:
                        LDA             HIM_AP_PKG_LEN_HI
                        CMP             #$10
                        BCC             APMAN_INSTALL_SIZE_OK
                        BEQ             APMAN_INSTALL_SIZE_1000
                        JMP             APMAN_BAD_RANGE
APMAN_INSTALL_SIZE_1000:
                        LDA             HIM_AP_PKG_LEN_LO
                        BEQ             APMAN_INSTALL_SIZE_OK
                        JMP             APMAN_BAD_RANGE
APMAN_INSTALL_SIZE_OK: LDA             #$80
                        STA             SECTOR
APMAN_INSTALL_SCAN:    JSR             APMAN_LOCATION_PROTECTED
                        BCS             APMAN_INSTALL_NEXT
                        JSR             APMAN_STAGE_RAW
                        BCS             APMAN_INSTALL_STAGED
                        JMP             APMAN_RESTORE_FAIL
APMAN_INSTALL_STAGED:
                        JSR             APMAN_STAGE_ERASED
                        BCS             APMAN_INSTALL_FOUND
APMAN_INSTALL_NEXT:    JSR             APMAN_NEXT_SECTOR
                        BCC             APMAN_INSTALL_SCAN
                        LDA             #APMAN_STATUS_NO_SPACE
                        JMP             APMAN_FAIL_A
APMAN_INSTALL_FOUND:   LDA             BANK
                        STA             APMAN_FOUND_BANK
                        LDA             SECTOR
                        STA             APMAN_FOUND_SECTOR_HI
                        LDA             HIM_AP_PKG_LEN_LO
                        STA             APMAN_FOUND_PKG_LEN_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        STA             APMAN_FOUND_PKG_LEN_HI
                        JSR             APMAN_FILL_STAGE_FF
                        JSR             APMAN_COPY_INSTALL_PACKAGE
                        JSR             APMAN_COPY_WORKER
                        LDA             BANK
                        STA             STR8_WORKER_DEST_BANK
                        LDA             SECTOR
                        STA             STR8_WORKER_SECTOR_HI
                        LDA             #>STAGE_BASE
                        STA             STR8_WORKER_BUFFER_HI
                        LDA             #$05
                        STA             STR8_WORKER_MODE
                        LDA             #APMAN_PHASE_PROGRAM
                        STA             APMAN_FAIL_PHASE
                        JSR             STR8_WORKER_ENTRY
                        BCS             APMAN_INSTALL_PROGRAMMED
                        LDA             #APMAN_STATUS_PROGRAM_FAIL
                        JMP             APMAN_FAIL_A
APMAN_INSTALL_PROGRAMMED:
                        LDX             #<MSG_INSTALLED
                        LDY             #>MSG_INSTALLED
                        JSR             APMAN_PUTS
                        JSR             APMAN_PRINT_LOCATION
                        LDX             #<MSG_LEN
                        LDY             #>MSG_LEN
                        JSR             APMAN_PUTS
                        LDA             APMAN_FOUND_PKG_LEN_HI
                        JSR             APMAN_HEX
                        LDA             APMAN_FOUND_PKG_LEN_LO
                        JSR             APMAN_HEX
                        JSR             APMAN_CRLF
                        JMP             APMAN_RETURN_OK
APMAN_INSTALL_UNCONFIRMED:
                        LDA             #APMAN_STATUS_NOT_CONFIRMED
                        JMP             APMAN_FAIL_A

; ---------------------------------------------------------------------------
; Carrier scan, AP v2 validation, and entry-export metadata.
; ---------------------------------------------------------------------------
APMAN_FIND_NAMED:      STZ             APMAN_MATCH_COUNT
                        LDA             #$80
                        STA             SECTOR
APMAN_FIND_NAME_LOOP:  JSR             APMAN_STAGE_VALIDATE
                        BCC             APMAN_FIND_NAME_NEXT
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCC             APMAN_FIND_NAME_NEXT
                        LDY             #$03
                        LDX             #$00
APMAN_FIND_HASH_LOOP:  LDA             (ROW_LO),Y
                        CMP             APMAN_NAME_HASH0,X
                        BNE             APMAN_FIND_NAME_NEXT
                        INY
                        INX
                        CPX             #$04
                        BNE             APMAN_FIND_HASH_LOOP
                        INC             APMAN_MATCH_COUNT
                        LDA             APMAN_MATCH_COUNT
                        CMP             #$01
                        BNE             APMAN_FIND_NAME_NEXT
                        LDA             SECTOR
                        STA             APMAN_FOUND_SECTOR_HI
APMAN_FIND_NAME_NEXT:  JSR             APMAN_NEXT_SECTOR
                        BCC             APMAN_FIND_NAME_LOOP
                        LDA             APMAN_MATCH_COUNT
                        BEQ             APMAN_FIND_NAME_FAIL
                        CMP             #$01
                        BEQ             APMAN_FIND_NAME_UNIQUE
                        JMP             APMAN_DUPLICATE
APMAN_FIND_NAME_UNIQUE:
                        LDA             APMAN_FOUND_SECTOR_HI
                        STA             SECTOR
                        JSR             APMAN_STAGE_VALIDATE
                        BCC             APMAN_FIND_NAME_FAIL
                        JSR             APMAN_FIND_ENTRY_ROW
                        RTS
APMAN_FIND_NAME_FAIL:  CLC
                        RTS

APMAN_STAGE_VALIDATE:  JSR             APMAN_STAGE_RAW
                        BCC             APMAN_STAGE_VALID_FAIL
                        STZ             HIM_AP_SRC_LO
                        LDA             #>STAGE_BASE
                        STA             HIM_AP_SRC_HI
                        LDA             #HIM_AP_OP_PARSE
                        STA             HIM_AP_OP
                        JSR             APMAN_CALL_AP
APMAN_STAGE_VALID_FAIL: RTS

; Locate the one entry export. ROW points at its flags byte.
APMAN_FIND_ENTRY_ROW:  LDA             #<STAGE_BASE+$05
                        STA             PTRL
                        LDA             #>STAGE_BASE+$05
                        STA             PTRH
                        JSR             APMAN_SKIP_SECTION
                        BCC             APMAN_ENTRY_FAIL
                        JSR             APMAN_SKIP_SECTION
                        BCC             APMAN_ENTRY_FAIL
                        LDY             #$00
                        LDA             (PTRL),Y
                        CMP             #'E'
                        BNE             APMAN_ENTRY_FAIL
                        LDA             #$03
                        JSR             APMAN_PTR_ADD_A
                        LDY             #$00
                        LDA             (PTRL),Y
                        STA             COUNT
                        JSR             APMAN_ADVANCE
APMAN_ENTRY_ROW_LOOP:  LDA             COUNT
                        BEQ             APMAN_ENTRY_FAIL
                        LDA             PTRL
                        STA             ROW_LO
                        LDA             PTRH
                        STA             ROW_HI
                        LDY             #$00
                        LDA             (ROW_LO),Y
                        BMI             APMAN_ENTRY_FOUND
                        LDY             #$07
                        LDA             (ROW_LO),Y
                        JSR             APMAN_ROW_SIZE
                        JSR             APMAN_PTR_ADD_A
                        DEC             COUNT
                        BRA             APMAN_ENTRY_ROW_LOOP
APMAN_ENTRY_FOUND:     SEC
                        RTS
APMAN_ENTRY_FAIL:      CLC
                        RTS

APMAN_SKIP_SECTION:    LDY             #$01
                        LDA             (PTRL),Y
                        STA             VALUE_LO
                        INY
                        LDA             (PTRL),Y
                        STA             VALUE_HI
                        LDA             PTRL
                        CLC
                        ADC             #$03
                        ADC             VALUE_LO
                        STA             PTRL
                        LDA             PTRH
                        ADC             VALUE_HI
                        STA             PTRH
                        SEC
                        RTS

; A=name length. Return A=8 + 2*ceil(length/3).
APMAN_ROW_SIZE:        LDX             #$08
APMAN_ROW_PACK:        CMP             #$01
                        BCC             APMAN_ROW_DONE
                        INX
                        INX
                        CMP             #$04
                        BCC             APMAN_ROW_DONE
                        SEC
                        SBC             #$03
                        BRA             APMAN_ROW_PACK
APMAN_ROW_DONE:        TXA
                        RTS

APMAN_SET_PACKAGE_FACTS:
                        LDA             BANK
                        STA             APMAN_FOUND_BANK
                        LDA             SECTOR
                        STA             APMAN_FOUND_SECTOR_HI
                        LDA             HIM_AP_PKG_LEN_LO
                        STA             APMAN_FOUND_PKG_LEN_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        STA             APMAN_FOUND_PKG_LEN_HI
                        RTS

; APMAN remains live at $7000 while it asks HIMON to copy/fix the selected
; body. Keep the loaded body in ordinary foreground RAM below the manager.
; The end address is exclusive, so a body ending exactly at $7000 is safe.
APMAN_LOAD_RANGE_SAFE: LDA             APMAN_FOUND_LOAD_HI
                        CMP             #$20
                        BCC             APMAN_LOAD_RANGE_BAD
                        LDA             APMAN_FOUND_LOAD_LO
                        CLC
                        ADC             HIM_AP_BODY_LEN_LO
                        STA             TMP0
                        LDA             APMAN_FOUND_LOAD_HI
                        ADC             HIM_AP_BODY_LEN_HI
                        STA             TMP1
                        BCS             APMAN_LOAD_RANGE_BAD
                        LDA             TMP1
                        CMP             #$70
                        BCC             APMAN_LOAD_RANGE_GOOD
                        BNE             APMAN_LOAD_RANGE_BAD
                        LDA             TMP0
                        BNE             APMAN_LOAD_RANGE_BAD
APMAN_LOAD_RANGE_GOOD: SEC
                        RTS
APMAN_LOAD_RANGE_BAD:  CLC
                        RTS

; ---------------------------------------------------------------------------
; Bank staging. APMAN is in RAM, so it may call $F010 before continuing via
; the installed $0203 selector. Every path restores Bank 3 before returning.
; ---------------------------------------------------------------------------
APMAN_STAGE_RAW:       PHP
                        SEI
                        LDA             BANK
                        JSR             STR8_SELECT
                        BCC             APMAN_STAGE_SELECT_FAIL
                        STZ             PTRL
                        LDA             SECTOR
                        STA             PTRH
                        STZ             VALUE_LO
                        LDA             #>STAGE_BASE
                        STA             VALUE_HI
                        LDX             #$10
APMAN_STAGE_PAGE:      LDY             #$00
APMAN_STAGE_BYTE:      LDA             (PTRL),Y
                        STA             (VALUE_LO),Y
                        INY
                        BNE             APMAN_STAGE_BYTE
                        INC             PTRH
                        INC             VALUE_HI
                        DEX
                        BNE             APMAN_STAGE_PAGE
                        LDA             #$03
                        JSR             STR8_SELECT_RAM
                        BCC             APMAN_STAGE_RESTORE_FAIL
                        PLP
                        SEC
                        RTS
APMAN_STAGE_SELECT_FAIL:
                        LDA             #$03
                        JSR             STR8_SELECT_RAM
APMAN_STAGE_RESTORE_FAIL:
                        PLP
                        CLC
                        RTS

APMAN_STAGE_ERASED:    STZ             PTRL
                        LDA             #>STAGE_BASE
                        STA             PTRH
                        LDX             #$10
APMAN_ERASE_PAGE:      LDY             #$00
APMAN_ERASE_BYTE:      LDA             (PTRL),Y
                        CMP             #$FF
                        BNE             APMAN_ERASE_USED
                        INY
                        BNE             APMAN_ERASE_BYTE
                        INC             PTRH
                        DEX
                        BNE             APMAN_ERASE_PAGE
                        SEC
                        RTS
APMAN_ERASE_USED:      CLC
                        RTS

APMAN_FILL_STAGE_FF:   STZ             PTRL
                        LDA             #>STAGE_BASE
                        STA             PTRH
                        LDX             #$10
                        LDA             #$FF
APMAN_FILL_PAGE:       LDY             #$00
APMAN_FILL_BYTE:       STA             (PTRL),Y
                        INY
                        BNE             APMAN_FILL_BYTE
                        INC             PTRH
                        DEX
                        BNE             APMAN_FILL_PAGE
                        RTS

APMAN_COPY_INSTALL_PACKAGE:
                        LDA             APMAN_INSTALL_SRC_LO
                        STA             PTRL
                        LDA             APMAN_INSTALL_SRC_HI
                        STA             PTRH
                        STZ             VALUE_LO
                        LDA             #>STAGE_BASE
                        STA             VALUE_HI
                        LDA             APMAN_FOUND_PKG_LEN_LO
                        STA             TMP0
                        LDA             APMAN_FOUND_PKG_LEN_HI
                        STA             TMP1
                        JMP             APMAN_COPY_BYTES

APMAN_COPY_WORKER:     LDA             #<APMAN_WORKER_IMAGE
                        STA             PTRL
                        LDA             #>APMAN_WORKER_IMAGE
                        STA             PTRH
                        STZ             VALUE_LO
                        LDA             #>STR8_WORKER_ENTRY
                        STA             VALUE_HI
                        LDA             #<APMAN_WORKER_SIZE
                        STA             TMP0
                        LDA             #>APMAN_WORKER_SIZE
                        STA             TMP1
APMAN_COPY_BYTES:      LDA             TMP0
                        ORA             TMP1
                        BEQ             APMAN_COPY_DONE
                        LDY             #$00
                        LDA             (PTRL),Y
                        STA             (VALUE_LO),Y
                        INC             PTRL
                        BNE             APMAN_COPY_SRC_OK
                        INC             PTRH
APMAN_COPY_SRC_OK:     INC             VALUE_LO
                        BNE             APMAN_COPY_DST_OK
                        INC             VALUE_HI
APMAN_COPY_DST_OK:     LDA             TMP0
                        BNE             APMAN_COPY_DEC_LO
                        DEC             TMP1
APMAN_COPY_DEC_LO:     DEC             TMP0
                        BRA             APMAN_COPY_BYTES
APMAN_COPY_DONE:       RTS

APMAN_LOCATION_PROTECTED:
                        JSR             APMAN_PACK_LOCATION
                        CMP             WORK_ROLE
                        BEQ             APMAN_LOCATION_YES
                        CMP             BACKUP_ROLE
                        BEQ             APMAN_LOCATION_YES
                        CLC
                        RTS
APMAN_LOCATION_YES:    SEC
                        RTS

APMAN_PACK_LOCATION:   LDA             BANK
                        ASL             A
                        ASL             A
                        ASL             A
                        ASL             A
                        STA             TMP0
                        LDA             SECTOR
                        LSR             A
                        LSR             A
                        LSR             A
                        LSR             A
                        ORA             TMP0
                        RTS

APMAN_NEXT_SECTOR:     LDA             SECTOR
                        CLC
                        ADC             #$10
                        STA             SECTOR
                        BEQ             APMAN_NEXT_DONE
                        CLC
                        RTS
APMAN_NEXT_DONE:       SEC
                        RTS

; ---------------------------------------------------------------------------
; APS printing.
; ---------------------------------------------------------------------------
APMAN_PRINT_STATUS_ROW:
                        LDX             #<MSG_APS_PREFIX
                        LDY             #>MSG_APS_PREFIX
                        JSR             APMAN_PUTS
                        JSR             APMAN_PACK_LOCATION
                        JSR             APMAN_HEX
                        LDA             #' '
                        JSR             APMAN_PUTC
                        JSR             APMAN_LOCATION_PROTECTED
                        BCC             APMAN_STATUS_MEDIA
                        JSR             APMAN_PACK_LOCATION
                        CMP             WORK_ROLE
                        BNE             APMAN_STATUS_BACKUP
                        LDX             #<MSG_WORK
                        LDY             #>MSG_WORK
                        JMP             APMAN_PUTS_CRLF
APMAN_STATUS_BACKUP:   LDX             #<MSG_BACKUP
                        LDY             #>MSG_BACKUP
                        JMP             APMAN_PUTS_CRLF
APMAN_STATUS_MEDIA:    JSR             APMAN_STAGE_RAW
                        BCC             APMAN_STATUS_IOERR
                        JSR             APMAN_STAGE_ERASED
                        BCC             APMAN_STATUS_NOT_ERASED
                        LDX             #<MSG_HDR_ERASED
                        LDY             #>MSG_HDR_ERASED
                        JMP             APMAN_PUTS_CRLF
APMAN_STATUS_NOT_ERASED:
                        JSR             APMAN_STAGE_VALIDATE
                        BCC             APMAN_STATUS_APS_HEADER
                        JSR             APMAN_FIND_ENTRY_ROW
                        BCC             APMAN_STATUS_UNMANAGED
                        LDX             #<MSG_APC
                        LDY             #>MSG_APC
                        JSR             APMAN_PUTS
                        JSR             APMAN_PRINT_ENTRY_NAME
                        LDX             #<MSG_LEN
                        LDY             #>MSG_LEN
                        JSR             APMAN_PUTS
                        LDA             HIM_AP_PKG_LEN_HI
                        JSR             APMAN_HEX
                        LDA             HIM_AP_PKG_LEN_LO
                        JSR             APMAN_HEX
                        JMP             APMAN_CRLF
APMAN_STATUS_APS_HEADER:
                        JSR             APMAN_VALIDATE_APS_HEADER
                        BCC             APMAN_STATUS_UNMANAGED
                        JSR             APMAN_PUTC
APMAN_STATUS_GEN:      LDX             #<MSG_GEN
                        LDY             #>MSG_GEN
                        JSR             APMAN_PUTS
                        LDA             STAGE_BASE+APS_SH_OFF_GENERATION+1
                        JSR             APMAN_HEX
                        LDA             STAGE_BASE+APS_SH_OFF_GENERATION
                        JSR             APMAN_HEX
                        JMP             APMAN_CRLF
APMAN_STATUS_UNMANAGED:LDX             #<MSG_UNMANAGED
                        LDY             #>MSG_UNMANAGED
                        JMP             APMAN_PUTS_CRLF
APMAN_STATUS_IOERR:    LDX             #<MSG_IOERR
                        LDY             #>MSG_IOERR
                        JMP             APMAN_PUTS_CRLF

; Validate the complete 16-byte AP Store sector header before assigning a
; state symbol. Return C=1/A=symbol or C=0 for unknown/corrupt media.
APMAN_VALIDATE_APS_HEADER:
                        LDA             STAGE_BASE+APS_SH_OFF_SIG
                        CMP             #APS_SECTOR_SIG0
                        BNE             APMAN_APS_HEADER_BAD
                        LDA             STAGE_BASE+APS_SH_OFF_SIG+1
                        CMP             #APS_SECTOR_SIG1
                        BNE             APMAN_APS_HEADER_BAD
                        LDA             STAGE_BASE+APS_SH_OFF_SIG+2
                        CMP             #APS_SECTOR_SIG2
                        BNE             APMAN_APS_HEADER_BAD
                        JSR             APMAN_PACK_LOCATION
                        CMP             STAGE_BASE+APS_SH_OFF_LOCATION
                        BNE             APMAN_APS_HEADER_BAD
                        LDX             #$04
APMAN_APS_RESERVED:    LDA             STAGE_BASE+APS_SH_OFF_RESERVED,X
                        CMP             #$FF
                        BNE             APMAN_APS_HEADER_BAD
                        DEX
                        BPL             APMAN_APS_RESERVED
                        JSR             APMAN_FNV_INIT
                        LDY             #$00
APMAN_APS_FNV:         LDA             STAGE_BASE,Y
                        JSR             APMAN_FNV_UPDATE
                        INY
                        CPY             #APS_SH_OFF_FNV
                        BNE             APMAN_APS_FNV
                        LDX             #$03
APMAN_APS_FNV_COMPARE:LDA             FNV_HASH0,X
                        CMP             STAGE_BASE+APS_SH_OFF_FNV,X
                        BNE             APMAN_APS_HEADER_BAD
                        DEX
                        BPL             APMAN_APS_FNV_COMPARE
                        LDA             STAGE_BASE+APS_SH_OFF_STATE
                        CMP             #APS_SECTOR_STATE_ACTIVE
                        BEQ             APMAN_APS_ACTIVE
                        CMP             #APS_SECTOR_STATE_RETIRED
                        BEQ             APMAN_APS_RETIRED
                        CMP             #APS_SECTOR_STATE_STAGED
                        BEQ             APMAN_APS_STAGED
                        CMP             #APS_SECTOR_STATE_BAD
                        BEQ             APMAN_APS_BAD
                        CMP             #APS_SECTOR_STATE_RETIRED_BAD
                        BNE             APMAN_APS_HEADER_BAD
APMAN_APS_BAD:         LDA             #'!'
                        BRA             APMAN_APS_HEADER_GOOD
APMAN_APS_STAGED:      LDA             #'~'
                        BRA             APMAN_APS_HEADER_GOOD
APMAN_APS_RETIRED:     LDA             #'-'
                        BRA             APMAN_APS_HEADER_GOOD
APMAN_APS_ACTIVE:      LDA             #'+'
APMAN_APS_HEADER_GOOD:SEC
                        RTS
APMAN_APS_HEADER_BAD: CLC
                        RTS

APMAN_PRINT_CARRIER_DETAIL:
                        LDX             #<MSG_APS_PREFIX
                        LDY             #>MSG_APS_PREFIX
                        JSR             APMAN_PUTS
                        JSR             APMAN_PRINT_LOCATION
                        LDX             #<MSG_APC
                        LDY             #>MSG_APC
                        JSR             APMAN_PUTS
                        JSR             APMAN_PRINT_ENTRY_NAME
                        LDX             #<MSG_LEN
                        LDY             #>MSG_LEN
                        JSR             APMAN_PUTS
                        LDA             HIM_AP_PKG_LEN_HI
                        JSR             APMAN_HEX
                        LDA             HIM_AP_PKG_LEN_LO
                        JSR             APMAN_HEX
                        LDX             #<MSG_AT
                        LDY             #>MSG_AT
                        JSR             APMAN_PUTS
                        LDA             STAGE_BASE+$0A
                        JSR             APMAN_HEX
                        LDA             STAGE_BASE+$09
                        JSR             APMAN_HEX
                        JMP             APMAN_CRLF

APMAN_PRINT_LOCATION:  LDA             #'B'
                        JSR             APMAN_PUTC
                        LDA             BANK
                        CLC
                        ADC             #'0'
                        JSR             APMAN_PUTC
                        LDA             #' '
                        JSR             APMAN_PUTC
                        LDA             SECTOR
                        JSR             APMAN_HEX
                        LDA             #$00
                        JMP             APMAN_HEX

; Decode and print the PACK40 entry name at ROW+8/ROW+9.
APMAN_PRINT_ENTRY_NAME:
                        LDY             #$07
                        LDA             (ROW_LO),Y
                        STA             COUNT
                        LDA             ROW_LO
                        CLC
                        ADC             #$08
                        STA             PTRL
                        LDA             ROW_HI
                        ADC             #$00
                        STA             PTRH
APMAN_NAME_GROUP:      LDA             COUNT
                        BEQ             APMAN_NAME_DONE
                        LDY             #$00
                        LDA             (PTRL),Y
                        STA             VALUE_LO
                        INY
                        LDA             (PTRL),Y
                        STA             VALUE_HI
                        JSR             APMAN_DIV40
                        LDA             TMP0
                        STA             TMP2
                        JSR             APMAN_DIV40
                        LDA             VALUE_LO
                        JSR             APMAN_PRINT_PACK40_CODE
                        DEC             COUNT
                        BEQ             APMAN_NAME_DONE
                        LDA             TMP0
                        JSR             APMAN_PRINT_PACK40_CODE
                        DEC             COUNT
                        BEQ             APMAN_NAME_DONE
                        LDA             TMP2
                        JSR             APMAN_PRINT_PACK40_CODE
                        DEC             COUNT
                        LDA             PTRL
                        CLC
                        ADC             #$02
                        STA             PTRL
                        BCC             APMAN_NAME_GROUP
                        INC             PTRH
                        BRA             APMAN_NAME_GROUP
APMAN_NAME_DONE:       RTS

; VALUE = VALUE/40, TMP0 = remainder. Small repeated subtraction is bounded by
; 1638 iterations for the first digit pair and keeps this infrequent printer
; substantially smaller than a general 16-bit divider.
APMAN_DIV40:           STZ             TMP0
                        STZ             TMP1
APMAN_DIV40_LOOP:      LDA             VALUE_HI
                        BNE             APMAN_DIV40_SUB
                        LDA             VALUE_LO
                        CMP             #$28
                        BCC             APMAN_DIV40_DONE
APMAN_DIV40_SUB:       LDA             VALUE_LO
                        SEC
                        SBC             #$28
                        STA             VALUE_LO
                        BCS             APMAN_DIV40_COUNT
                        DEC             VALUE_HI
APMAN_DIV40_COUNT:     INC             TMP0
                        BNE             APMAN_DIV40_LOOP
                        INC             TMP1
                        BRA             APMAN_DIV40_LOOP
APMAN_DIV40_DONE:      LDA             VALUE_LO
                        PHA
                        LDA             TMP0
                        STA             VALUE_LO
                        LDA             TMP1
                        STA             VALUE_HI
                        PLA
                        STA             TMP0
                        RTS

APMAN_PRINT_PACK40_CODE:
                        BEQ             APMAN_PACK40_SPACE
                        CMP             #$1B
                        BCC             APMAN_PACK40_ALPHA
                        CMP             #$25
                        BCC             APMAN_PACK40_DIGIT
                        BEQ             APMAN_PACK40_UNDER
                        CMP             #$26
                        BEQ             APMAN_PACK40_Q
                        LDA             #'.'
                        JMP             APMAN_PUTC
APMAN_PACK40_ALPHA:    CLC
                        ADC             #'@'
                        JMP             APMAN_PUTC
APMAN_PACK40_DIGIT:    SEC
                        SBC             #$1B
                        CLC
                        ADC             #'0'
                        JMP             APMAN_PUTC
APMAN_PACK40_UNDER:    LDA             #'_'
                        JMP             APMAN_PUTC
APMAN_PACK40_Q:        LDA             #'?'
                        JMP             APMAN_PUTC
APMAN_PACK40_SPACE:    LDA             #' '
                        JMP             APMAN_PUTC

; ---------------------------------------------------------------------------
; Command token helpers.
; ---------------------------------------------------------------------------
APMAN_PARSE_SELECTOR:  LDA             PTRL
                        STA             TAIL_LO
                        LDA             PTRH
                        STA             TAIL_HI
                        JSR             APMAN_TRY_SECTOR_ADDRESS
                        BCS             APMAN_SELECTOR_ADDRESS
                        LDA             TAIL_LO
                        STA             PTRL
                        LDA             TAIL_HI
                        STA             PTRH
                        JSR             APMAN_FNV_INIT
                        STZ             COUNT
APMAN_SELECTOR_NAME:   LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_SELECTOR_NAME_DONE
                        CMP             #' '
                        BEQ             APMAN_SELECTOR_NAME_DONE
                        JSR             APMAN_FNV_UPDATE
                        INC             COUNT
                        JSR             APMAN_ADVANCE
                        BRA             APMAN_SELECTOR_NAME
APMAN_SELECTOR_NAME_DONE:
                        LDA             COUNT
                        BEQ             APMAN_SELECTOR_FAIL
                        LDX             #$03
APMAN_SELECTOR_HASH_SAVE:
                        LDA             FNV_HASH0,X
                        STA             APMAN_NAME_HASH0,X
                        DEX
                        BPL             APMAN_SELECTOR_HASH_SAVE
                        SEC
                        RTS
APMAN_SELECTOR_ADDRESS:LDA             FLAGS
                        ORA             #FLAG_SELECTOR_ADDR
                        STA             FLAGS
                        LDA             VALUE_HI
                        STA             SECTOR
                        SEC
                        RTS
APMAN_SELECTOR_FAIL:   CLC
                        RTS

APMAN_TRY_SECTOR_ADDRESS:
                        JSR             APMAN_PARSE_HEX_WORD
                        BCC             APMAN_TRY_ADDRESS_FAIL
                        LDA             VALUE_LO
                        BNE             APMAN_TRY_ADDRESS_FAIL
                        LDA             VALUE_HI
                        AND             #$0F
                        BNE             APMAN_TRY_ADDRESS_FAIL
                        LDA             VALUE_HI
                        CMP             #$80
                        BCC             APMAN_TRY_ADDRESS_FAIL
                        SEC
                        RTS
APMAN_TRY_ADDRESS_FAIL:LDA             TAIL_LO
                        STA             PTRL
                        LDA             TAIL_HI
                        STA             PTRH
                        CLC
                        RTS

APMAN_PARSE_HEX_WORD:  STZ             VALUE_LO
                        STZ             VALUE_HI
                        LDX             #$04
APMAN_HEX_WORD_LOOP:   LDY             #$00
                        LDA             (PTRL),Y
                        JSR             APMAN_HEX_NIBBLE
                        BCC             APMAN_HEX_WORD_FAIL
                        PHA
                        ASL             VALUE_LO
                        ROL             VALUE_HI
                        ASL             VALUE_LO
                        ROL             VALUE_HI
                        ASL             VALUE_LO
                        ROL             VALUE_HI
                        ASL             VALUE_LO
                        ROL             VALUE_HI
                        PLA
                        ORA             VALUE_LO
                        STA             VALUE_LO
                        JSR             APMAN_ADVANCE
                        DEX
                        BNE             APMAN_HEX_WORD_LOOP
                        LDY             #$00
                        LDA             (PTRL),Y
                        BEQ             APMAN_HEX_WORD_OK
                        CMP             #' '
                        BNE             APMAN_HEX_WORD_FAIL
APMAN_HEX_WORD_OK:     SEC
                        RTS
APMAN_HEX_WORD_FAIL:   CLC
                        RTS

APMAN_HEX_NIBBLE:     CMP             #'0'
                        BCC             APMAN_NIBBLE_FAIL
                        CMP             #'9'+1
                        BCC             APMAN_NIBBLE_DIGIT
                        CMP             #'A'
                        BCC             APMAN_NIBBLE_FAIL
                        CMP             #'F'+1
                        BCS             APMAN_NIBBLE_FAIL
                        SEC
                        SBC             #'A'-10
                        SEC
                        RTS
APMAN_NIBBLE_DIGIT:    SEC
                        SBC             #'0'
                        SEC
                        RTS
APMAN_NIBBLE_FAIL:     CLC
                        RTS

APMAN_SKIP_SPACES:     LDY             #$00
                        LDA             (PTRL),Y
                        CMP             #' '
                        BNE             APMAN_SKIP_DONE
                        JSR             APMAN_ADVANCE
                        BRA             APMAN_SKIP_SPACES
APMAN_SKIP_DONE:       RTS
APMAN_ADVANCE:         INC             PTRL
                        BNE             APMAN_ADVANCE_DONE
                        INC             PTRH
APMAN_ADVANCE_DONE:    RTS
APMAN_PTR_ADD_A:       CLC
                        ADC             PTRL
                        STA             PTRL
                        BCC             APMAN_PTR_ADD_DONE
                        INC             PTRH
APMAN_PTR_ADD_DONE:    RTS

; ---------------------------------------------------------------------------
; Published-service trampolines. JSR here followed by JMP through the RAM
; vector lets the resident routine RTS directly to the APMAN caller.
; ---------------------------------------------------------------------------
APMAN_PUTC:            JMP             (HIM_SVC_WRITE_BYTE_LO)
APMAN_PUTS:            JMP             (HIM_SVC_WRITE_CSTRING_LO)
APMAN_HEX:             JMP             (HIM_SVC_WRITE_HEX_BYTE_LO)
APMAN_CRLF:            JMP             (HIM_SVC_WRITE_CRLF_LO)
APMAN_FNV_INIT:        JMP             (HIM_SVC_FNV_INIT_LO)
APMAN_FNV_UPDATE:      JMP             (HIM_SVC_FNV_UPDATE_LO)
APMAN_CALL_AP:         JMP             (HIM_SVC_AP_LO)

APMAN_PUTS_CRLF:      JSR             APMAN_PUTS
                        JMP             APMAN_CRLF

APMAN_RETURN_OK:       LDA             #APMAN_STATUS_OK
                        STA             APMAN_STATUS
                        SEC
                        RTS
APMAN_BAD_COMMAND:     LDA             #APMAN_STATUS_BAD_COMMAND
                        BRA             APMAN_FAIL_A
APMAN_NOT_FOUND:       LDA             #APMAN_STATUS_NOT_FOUND
                        BRA             APMAN_FAIL_A
APMAN_DUPLICATE:       LDA             #APMAN_STATUS_DUPLICATE
                        BRA             APMAN_FAIL_A
APMAN_BAD_PACKAGE:     LDA             #APMAN_STATUS_BAD_PACKAGE
                        BRA             APMAN_FAIL_A
APMAN_BAD_RANGE:       LDA             #APMAN_STATUS_BAD_RANGE
                        BRA             APMAN_FAIL_A
APMAN_RESTORE_FAIL:    LDA             #APMAN_STATUS_RESTORE_FAIL
APMAN_FAIL_A:          STA             APMAN_STATUS
                        PHA
                        LDX             #<MSG_ERR
                        LDY             #>MSG_ERR
                        JSR             APMAN_PUTS
                        PLA
                        JSR             APMAN_HEX
                        JSR             APMAN_CRLF
                        CLC
                        RTS

MSG_AP_LOAD:           DB              "AP LOAD ",0
MSG_INSTALLED:         DB              "INST ",0
MSG_GO:                DB              "GO ",0
MSG_ARROW:             DB              " -> ",0
MSG_APS_PREFIX:        DB              "APS ",0
MSG_APC:               DB              "APC ",0
MSG_LEN:               DB              " L=",0
MSG_AT:                DB              " @",0
MSG_GEN:               DB              " G=",0
MSG_WORK:              DB              "= WORK",0
MSG_BACKUP:            DB              "= BKUP B3F",0
MSG_HDR_ERASED:        DB              "HDR ERASED",0
MSG_UNMANAGED:         DB              "UNMANAGED",0
MSG_IOERR:             DB              "IOERR",0
MSG_APS_OK:            DB              "APS OK",$0D,$0A,0
MSG_ERR:               DB              "APMAN ERR=$",0

                        INCLUDE         "apman-str8-worker.inc"

_END_CODE:
APMAN_IMAGE_END         EQU             $7000+(_END_CODE-APMAN)
                        ENDMOD
                        END

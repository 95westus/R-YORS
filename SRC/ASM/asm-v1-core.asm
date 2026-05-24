; ----------------------------------------------------------------------------
; asm-v1-core.asm
; First real ASM v1 code foothold.
;
; This is not HIMON's legacy A mini-assembler. This module starts the new
; hash-based ASM proper with small callable routines that match the ASM 1.xx
; contracts: session begin/end and line preparation.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132

                        MODULE          ASM_V1_CORE

                        XDEF            START
                        XDEF            ASM_BEGIN
                        XDEF            ASM_END
                        XDEF            ASM_LEX_LINE

; ----------------------------------------------------------------------------
; ASM active zero-page frame, allocated downward from $AF.
; Keep in sync with DOC/GUIDES/ASM/HASHED_ASM.md.
; ----------------------------------------------------------------------------
ASM_LINE_PTR_LO        EQU             $AE
ASM_LINE_PTR_HI        EQU             $AF
ASM_PARSE_PTR_LO       EQU             $AC
ASM_PARSE_PTR_HI       EQU             $AD
ASM_TOKEN_PTR_LO       EQU             $AA
ASM_TOKEN_PTR_HI       EQU             $AB
ASM_SCAN_PTR_LO        EQU             $A8
ASM_SCAN_PTR_HI        EQU             $A9
ASM_EMIT_PTR_LO        EQU             $A6
ASM_EMIT_PTR_HI        EQU             $A7
ASM_NAME_PTR_LO        EQU             $A4
ASM_NAME_PTR_HI        EQU             $A5
ASM_HASH0              EQU             $A0
ASM_HASH1              EQU             $A1
ASM_HASH2              EQU             $A2
ASM_HASH3              EQU             $A3
ASM_HASH_TMP0          EQU             $9C
ASM_HASH_TMP1          EQU             $9D
ASM_HASH_TMP2          EQU             $9E
ASM_HASH_TMP3          EQU             $9F
ASM_VALUE_LO           EQU             $9A
ASM_VALUE_HI           EQU             $9B
ASM_CARE_LO            EQU             $98
ASM_CARE_HI            EQU             $99
ASM_BASE_LO            EQU             $96
ASM_BASE_HI            EQU             $97
ASM_MODE               EQU             $95
ASM_WIDTH              EQU             $94
ASM_FLAGS              EQU             $93
ASM_STATUS             EQU             $92
ASM_SLOT               EQU             $91
ASM_LEN                EQU             $90
ASM_DELIM              EQU             $8F
ASM_BIT                EQU             $8E
ASM_TMP0_LO            EQU             $8C
ASM_TMP0_HI            EQU             $8D
ASM_TMP1_LO            EQU             $8A
ASM_TMP1_HI            EQU             $8B
ASM_REF_PTR_LO         EQU             $88
ASM_REF_PTR_HI         EQU             $89
ASM_FIX_PTR_LO         EQU             $86
ASM_FIX_PTR_HI         EQU             $87
ASM_SYM_PTR_LO         EQU             $84
ASM_SYM_PTR_HI         EQU             $85

; ----------------------------------------------------------------------------
; Status, session, and v1 proof limits.
; ----------------------------------------------------------------------------
ASM_STATUS_OK          EQU             $00
ASM_STATUS_BAD_MNEM    EQU             $01
ASM_STATUS_BAD_DIR     EQU             $02
ASM_STATUS_BAD_OPER    EQU             $03
ASM_STATUS_BAD_MODE    EQU             $04
ASM_STATUS_BAD_WIDTH   EQU             $05
ASM_STATUS_BAD_RANGE   EQU             $06
ASM_STATUS_BAD_LINE    EQU             $07
ASM_STATUS_BAD_SYM     EQU             $08
ASM_STATUS_BAD_FIX     EQU             $09
ASM_STATUS_LOCAL_NYI   EQU             $0A

ASM_BEGINF_HAVE_PC     EQU             $01

ASM_SESS_IDLE          EQU             $00
ASM_SESS_ACTIVE        EQU             $01
ASM_SESS_ENDED         EQU             $02
ASM_SESS_FAILED        EQU             $03

ASM_LINE_MAX           EQU             $3F
ASM_SYM_MAX            EQU             $10
ASM_FIX_MAX            EQU             $08
ASM_REF_MAX            EQU             $10

                        CODE

; ----------------------------------------------------------------------------
; START
; Tiny non-printing smoke entry for the standalone S19 target.
; OUT: C=1 if ASM_BEGIN, one good line, one too-long-line rejection, and
;      ASM_END behaved as expected.
; ----------------------------------------------------------------------------
START:
                        LDA             #ASM_BEGINF_HAVE_PC
                        LDX             #<ASM_CODE_BUF
                        LDY             #>ASM_CODE_BUF
                        JSR             ASM_BEGIN
                        BCC             START_FAIL

                        LDX             #<ASM_SMOKE_LINE_OK
                        LDY             #>ASM_SMOKE_LINE_OK
                        JSR             ASM_LEX_LINE
                        BCC             START_FAIL

                        LDX             #<ASM_SMOKE_LINE_LONG
                        LDY             #>ASM_SMOKE_LINE_LONG
                        JSR             ASM_LEX_LINE
                        BCS             START_FAIL
                        CMP             #ASM_STATUS_BAD_LINE
                        BNE             START_FAIL

                        JSR             ASM_END
                        BCC             START_FAIL
                        RTS
START_FAIL:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_BEGIN
; IN : A bit0 set means X/Y carries explicit start PC.
;      A bit0 clear means use this module's scratch code buffer.
; OUT: C=1,A=OK,X/Y=current PC when session opened.
;      C=0,A=status on failure.
; MEM: ZP $80-$AF active ASM frame; RAM session state below.
; ----------------------------------------------------------------------------
ASM_BEGIN:
                        STA             ASM_FLAGS
                        STX             ASM_TMP0_LO
                        STY             ASM_TMP0_HI
                        JSR             ASM_CLEAR_SESSION

                        LDA             ASM_FLAGS
                        AND             #ASM_BEGINF_HAVE_PC
                        BEQ             ASM_BEGIN_DEFAULT_PC

                        LDA             ASM_TMP0_LO
                        STA             ASM_PC_LO
                        STA             ASM_START_PC_LO
                        LDA             ASM_TMP0_HI
                        STA             ASM_PC_HI
                        STA             ASM_START_PC_HI
                        BRA             ASM_BEGIN_HAVE_PC

ASM_BEGIN_DEFAULT_PC:
                        LDA             #<ASM_CODE_BUF
                        STA             ASM_PC_LO
                        STA             ASM_START_PC_LO
                        LDA             #>ASM_CODE_BUF
                        STA             ASM_PC_HI
                        STA             ASM_START_PC_HI

ASM_BEGIN_HAVE_PC:
                        LDA             ASM_PC_LO
                        STA             ASM_HIGH_PC_LO
                        LDA             ASM_PC_HI
                        STA             ASM_HIGH_PC_HI
                        LDA             #ASM_SESS_ACTIVE
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_OK
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_END
; OUT: C=1,A=OK,X/Y=current PC if no required fixups remain.
;      C=0,A=BAD_FIX,X/Y=current PC if pending fixups remain.
; NOTE: Full fixup resolve/reporting lands in ASM 2.20/2.40.
; ----------------------------------------------------------------------------
ASM_END:
                        LDA             ASM_SESSION_STATE
                        CMP             #ASM_SESS_FAILED
                        BEQ             ASM_END_FAILED

                        LDA             ASM_FIX_COUNT
                        BEQ             ASM_END_OK

                        LDA             #ASM_SESS_FAILED
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_BAD_FIX
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

ASM_END_OK:
                        LDA             #ASM_SESS_ENDED
                        STA             ASM_SESSION_STATE
                        LDA             #ASM_STATUS_OK
                        STA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        SEC
                        RTS

ASM_END_FAILED:
                        LDA             ASM_LAST_STATUS
                        STA             ASM_STATUS
                        LDX             ASM_PC_LO
                        LDY             ASM_PC_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: ASM_LEX_LINE
; IN : X/Y = NUL, CR, or LF-terminated source line.
; OUT: C=1,A=OK,X/Y=parse pointer if line length <= ASM_LINE_MAX.
;      C=0,A=BAD_LINE,X/Y=parse pointer when line is too long.
; DOES: Stores line and parse pointers. Does not tokenize yet.
; ----------------------------------------------------------------------------
ASM_LEX_LINE:
                        STX             ASM_LINE_PTR_LO
                        STY             ASM_LINE_PTR_HI
                        STX             ASM_PARSE_PTR_LO
                        STY             ASM_PARSE_PTR_HI
                        STZ             ASM_LEN
                        LDY             #$00

ASM_LEX_LINE_LOOP:
                        LDA             (ASM_LINE_PTR_LO),Y
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0D
                        BEQ             ASM_LEX_LINE_OK
                        CMP             #$0A
                        BEQ             ASM_LEX_LINE_OK

                        INC             ASM_LEN
                        LDA             ASM_LEN
                        CMP             #(ASM_LINE_MAX+1)
                        BCS             ASM_LEX_LINE_BAD

                        INY
                        BRA             ASM_LEX_LINE_LOOP

ASM_LEX_LINE_OK:
                        LDA             #ASM_STATUS_OK
                        STA             ASM_STATUS
                        LDX             ASM_PARSE_PTR_LO
                        LDY             ASM_PARSE_PTR_HI
                        SEC
                        RTS

ASM_LEX_LINE_BAD:
                        LDA             #ASM_STATUS_BAD_LINE
                        STA             ASM_STATUS
                        STA             ASM_LAST_STATUS
                        LDX             ASM_PARSE_PTR_LO
                        LDY             ASM_PARSE_PTR_HI
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Internal session clear.
; ----------------------------------------------------------------------------
ASM_CLEAR_SESSION:
                        STZ             ASM_SESSION_STATE
                        STZ             ASM_LAST_STATUS
                        STZ             ASM_LINE_COUNT_LO
                        STZ             ASM_LINE_COUNT_HI
                        STZ             ASM_SYM_COUNT
                        STZ             ASM_FIX_COUNT
                        STZ             ASM_REF_COUNT
                        STZ             ASM_REPORT_FLAGS
                        RTS

                        DATA

ASM_SESSION_STATE:     DB              $00
ASM_LAST_STATUS:       DB              $00
ASM_LINE_COUNT_LO:     DB              $00
ASM_LINE_COUNT_HI:     DB              $00
ASM_PC_LO:             DB              $00
ASM_PC_HI:             DB              $00
ASM_START_PC_LO:       DB              $00
ASM_START_PC_HI:       DB              $00
ASM_HIGH_PC_LO:        DB              $00
ASM_HIGH_PC_HI:        DB              $00
ASM_SYM_COUNT:         DB              $00
ASM_FIX_COUNT:         DB              $00
ASM_REF_COUNT:         DB              $00
ASM_REPORT_FLAGS:      DB              $00

ASM_SMOKE_LINE_OK:     DB              "ORG $3000",0
ASM_SMOKE_LINE_LONG:
                        DB              "12345678901234567890123456789012"
                        DB              "34567890123456789012345678901234",0

ASM_CODE_BUF:          DS              $0200

                        ENDMOD
                        END

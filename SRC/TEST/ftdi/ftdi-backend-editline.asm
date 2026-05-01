; -------------------------------------------------------------------------
; I/O / SUBROUTINE CONVENTION (applies to this module and call sites):
; - A is the primary input/output register for data.
; - Carry (C) is status:
;   C=1 => operation completed/byte available
;   C=0 => timeout/not ready/not available.
; - X and Y are scratch (call-clobbered) unless a routine explicitly documents
;   preservation.
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; CALL HIERARCHY / LAYER RULES
; L0 (Driver): drv-*.asm        -> direct hardware/MMIO access only.
; L1 (HAL):    hal-*.asm        -> calls L0, no direct hardware touching.
; L2 (Backend):backend-*.asm    -> protocol/helpers, calls L1/L2-common.
; L2 (Common): util-common.asm  -> pure utility routines, no hardware access.
; L3 (Access): lock/access-policy -> capability gates, lock/unlock, privilege
;   checks.
; L4 (Sys):    sys-*.asm        -> device-neutral I/O API (SYS_*), calls
;   L3/L2.
; L5 (App):    app/*.asm        -> monitor/app entry points.
; TEST (Out-of-band): test/*.asm -> test harnesses (not part of layer ABI).
;
; ZP ALLOCATION POLICY
; - See ZP_MAP.md for reserved/scratch ownership.
; - Add/update labels in ZP_MAP.md before claiming new ZP bytes.
;
; THIS FILE: L2 BACKEND (FTDI).
; - Calls L1 HAL and L2-common helpers.
; - Exports backend-scoped symbols (`COR_FTDI_*`) for adapter layer.
; Naming convention:
; - L2 backend exports use `COR_<DEVICE>_*` (this file: `COR_FTDI_*`).
; - Backend targets L1 `<DEVICE>_*`; where no HAL wrapper exists yet,
;   backend may call L0 `PIN_<DEVICE>_*` directly.
; -------------------------------------------------------------------------


                        MODULE          COR_FTDI_READ_CSTRING_EDIT_ECHO
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_ECHO
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_ECHO  [HASH:C45D5C96]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, ECHO, CARRY-STATUS, NOSTACK
; PURPOSE: Line-editor read wrapper (echo, no case conversion).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; NOTES:
; - Supports BS ($08/$7F), DEL (ESC[3~), and ANSI arrows ESC[A/ESC[C/ESC[D
;   plus ESCOA/ESCOC/ESCOD.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_ECHO:
                        LDA             #$01
                        JMP             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD

                        MODULE          COR_FTDI_READ_CSTRING_EDIT_SILENT
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_SILENT
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_SILENT  [HASH:E69D9BE6]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, ECHO, CARRY-STATUS, NOSTACK
; PURPOSE: Line-editor read wrapper (no echo, no case conversion).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_SILENT:
                        LDA             #$00
                        JMP             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD

        MODULE COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
        XDEF COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            COR_FTDI_READ_CSTRING_EDIT_MODE

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER  [HASH:680FEAD3]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, READ, ECHO, CARRY-STATUS, NOSTACK
; PURPOSE: Line-editor read wrapper (echo + force uppercase).
; IN : X/Y = destination pointer
; OUT: C=1, A=len on EOL completion; C=0, A=$FE on full buffer.
; ----------------------------------------------------------------------------
COR_FTDI_CVN_READ_CSTRING_EDIT_ECHO_UPPER:
                        LDA             #$03
                        JMP             COR_FTDI_READ_CSTRING_EDIT_MODE
                        ENDMOD

                        MODULE          COR_FTDI_READ_CSTRING_EDIT_MODE
                        XDEF            COR_FTDI_READ_CSTRING_EDIT_MODE
                        XREF            COR_FTDI_POLL_CHAR
                        XREF            COR_FTDI_READ_CHAR
                        XREF            COR_FTDI_WRITE_CHAR
                        XREF            UTL_CHAR_TO_UPPER
                        XREF            UTL_CHAR_TO_LOWER

FTDI_GCE_ESC               EQU             $1B
FTDI_GCE_PTR_LO            EQU             $E8
FTDI_GCE_PTR_HI            EQU             $E9
FTDI_GCE_MAX               EQU             $EA
FTDI_GCE_LEN               EQU             $EB
FTDI_GCE_PB_CH             EQU             $EC
FTDI_GCE_PB_VALID          EQU             $ED
FTDI_GCE_EOL               EQU             $EE
FTDI_GCE_MODE              EQU             $EF
FTDI_GCE_MODE_ECHO         EQU             $01
FTDI_GCE_MODE_UPPER        EQU             $02
FTDI_GCE_MODE_LOWER        EQU             $04

; ----------------------------------------------------------------------------
; ROUTINE: COR_FTDI_READ_CSTRING_EDIT_MODE  [HASH:AC8C5108]
; TIER: BACKEND-L2
; TAGS: COR, BACKEND-L2, ECHO, NUL-TERM, CARRY-STATUS, CALLS_COR, STACK
; PURPOSE: Mode-driven line editor with insert/delete and cursor movement.
; IN : A = mode bitfield (same bits as COR_FTDI_READ_CSTRING_MODE)
; OUT: C=1, A=len on EOL completion (buffer NUL-terminated)
;      X/Y = destination pointer
;      C=0, A=$FE on full buffer (buffer NUL-terminated)
; NOTES:
; - Handles BS/DEL in-buffer edits instead of returning retry statuses.
; - Treats BS as either $08 or $7F (common terminal backspace variants).
; - Handles ANSI arrow sequences: ESC[A / ESCOA (up), ESC[C / ESCOC (right),
;   ESC[D / ESCOD (left).
; - Handles ANSI Delete key sequence ESC[3~ as forward delete at cursor.
; - Echo behavior applies to both typed characters and in-line edits.
; ----------------------------------------------------------------------------
COR_FTDI_READ_CSTRING_EDIT_MODE:
                        STX             FTDI_GCE_PTR_LO
                        STY             FTDI_GCE_PTR_HI
                        STA             FTDI_GCE_MODE

                        LDA             FTDI_GCE_PB_VALID
                        CMP             #$01
                        BEQ             ?GCE_PB_STATE_OK
                        STZ             FTDI_GCE_PB_VALID
?GCE_PB_STATE_OK:
                        LDA             #$FE
                        STA             FTDI_GCE_MAX
                        STZ             FTDI_GCE_LEN
                        STZ             FTDI_GCE_EOL
                        ; cursor index
                        LDY             #$00
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y

?GCE_READ_LOOP:
                        JSR             ?GCE_GET_RAW_CHAR
                        CMP             #$0D
                        BNE             ?GCE_NOT_CR
                        JMP             ?GCE_HANDLE_EOL
?GCE_NOT_CR:
                        CMP             #$0A
                        BNE             ?GCE_NOT_LF
                        JMP             ?GCE_HANDLE_EOL
?GCE_NOT_LF:
                        CMP             #FTDI_GCE_ESC
                        BNE             ?GCE_NOT_ESC
                        JMP             ?GCE_HANDLE_ESC
?GCE_NOT_ESC:
                        CMP             #$08
                        BNE             ?GCE_NOT_BS
                        JMP             ?GCE_HANDLE_BS
?GCE_NOT_BS:
                        CMP             #$7F
                        BNE             ?GCE_NOT_BS7F
                        JMP             ?GCE_HANDLE_BS
?GCE_NOT_BS7F:
                        CMP             #$20
                        BCC             ?GCE_READ_LOOP
                        ; ignore other controls
                        CMP             #$7F
                        BCS             ?GCE_READ_LOOP
                        ; ignore non-printable 0x7F+

                        PHA
                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_UPPER
                        BEQ             ?GCE_CHECK_LOWER
                        PLA
                        JSR             UTL_CHAR_TO_UPPER
                        PHA
                        BRA             ?GCE_CASE_READY
?GCE_CHECK_LOWER:
                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_LOWER
                        BEQ             ?GCE_CASE_READY
                        PLA
                        JSR             UTL_CHAR_TO_LOWER
                        PHA
?GCE_CASE_READY:
                        LDA             FTDI_GCE_LEN
                        CMP             FTDI_GCE_MAX
                        BEQ             ?GCE_FULL_POP

                        LDA             FTDI_GCE_EOL
                        CMP             FTDI_GCE_LEN
                        BCS             ?GCE_STORE_CHAR

                        LDX             FTDI_GCE_LEN
?GCE_SHIFT_RIGHT_LOOP:
                        CPX             FTDI_GCE_EOL
                        BEQ             ?GCE_STORE_CHAR
                        DEX
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        INY
                        STA             (FTDI_GCE_PTR_LO),Y
                        BRA             ?GCE_SHIFT_RIGHT_LOOP

?GCE_STORE_CHAR:
                        PLA
                        LDY             FTDI_GCE_EOL
                        STA             (FTDI_GCE_PTR_LO),Y
                        INC             FTDI_GCE_LEN
                        LDY             FTDI_GCE_LEN
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y

                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BEQ             ?GCE_NO_ECHO_INSERT
                        LDX             FTDI_GCE_EOL
?GCE_ECHO_INSERT_LOOP:
                        CPX             FTDI_GCE_LEN
                        BEQ             ?GCE_ECHO_INSERT_DONE
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_CHAR
                        INX
                        BRA             ?GCE_ECHO_INSERT_LOOP
?GCE_ECHO_INSERT_DONE:
?GCE_NO_ECHO_INSERT:
                        INC             FTDI_GCE_EOL

                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BNE             ?GCE_INSERT_HAVE_ECHO
                        JMP             ?GCE_READ_LOOP
?GCE_INSERT_HAVE_ECHO:
                        LDA             FTDI_GCE_LEN
                        SEC
                        SBC             FTDI_GCE_EOL
                        TAX
?GCE_INSERT_BS_LOOP:
                        CPX             #$00
                        BNE             ?GCE_INSERT_BS_HAVE_COUNT
                        JMP             ?GCE_READ_LOOP
?GCE_INSERT_BS_HAVE_COUNT:
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        DEX
                        BRA             ?GCE_INSERT_BS_LOOP

?GCE_FULL_POP:
                        PLA
                        LDA             FTDI_GCE_LEN
                        TAY
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y
                        LDA             FTDI_GCE_MAX
                        CLC
                        RTS

?GCE_HANDLE_BS:
                        LDA             FTDI_GCE_EOL
                        BNE             ?GCE_BS_HAVE_CURSOR
                        JMP             ?GCE_READ_LOOP
?GCE_BS_HAVE_CURSOR:
                        DEC             FTDI_GCE_EOL
                        LDX             FTDI_GCE_EOL
?GCE_BS_SHIFT_LEFT:
                        INX
                        CPX             FTDI_GCE_LEN
                        BEQ             ?GCE_BS_SHIFT_DONE
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        DEX
                        TAY
                        STA             (FTDI_GCE_PTR_LO),Y
                        INX
                        BRA             ?GCE_BS_SHIFT_LEFT
?GCE_BS_SHIFT_DONE:
                        DEC             FTDI_GCE_LEN
                        LDY             FTDI_GCE_LEN
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y

                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BNE             ?GCE_BS_HAVE_ECHO
                        JMP             ?GCE_READ_LOOP
?GCE_BS_HAVE_ECHO:
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        LDX             FTDI_GCE_EOL
?GCE_BS_ECHO_TAIL:
                        CPX             FTDI_GCE_LEN
                        BEQ             ?GCE_BS_ECHO_SPACE
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_CHAR
                        INX
                        BRA             ?GCE_BS_ECHO_TAIL
?GCE_BS_ECHO_SPACE:
                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             FTDI_GCE_LEN
                        SEC
                        SBC             FTDI_GCE_EOL
                        CLC
                        ADC             #$01
                        TAX
?GCE_BS_ECHO_BACK:
                        CPX             #$00
                        BNE             ?GCE_BS_BACK_HAVE_COUNT
                        JMP             ?GCE_READ_LOOP
?GCE_BS_BACK_HAVE_COUNT:
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        DEX
                        BRA             ?GCE_BS_ECHO_BACK

?GCE_HANDLE_DEL:
                        LDA             FTDI_GCE_EOL
                        CMP             FTDI_GCE_LEN
                        BCC             ?GCE_DEL_HAVE_CURSOR
                        JMP             ?GCE_READ_LOOP
?GCE_DEL_HAVE_CURSOR:
                        LDX             FTDI_GCE_EOL
?GCE_DEL_SHIFT_LEFT:
                        INX
                        CPX             FTDI_GCE_LEN
                        BEQ             ?GCE_DEL_SHIFT_DONE
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        DEX
                        TAY
                        STA             (FTDI_GCE_PTR_LO),Y
                        INX
                        BRA             ?GCE_DEL_SHIFT_LEFT
?GCE_DEL_SHIFT_DONE:
                        DEC             FTDI_GCE_LEN
                        LDY             FTDI_GCE_LEN
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y

                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BNE             ?GCE_DEL_HAVE_ECHO
                        JMP             ?GCE_READ_LOOP
?GCE_DEL_HAVE_ECHO:
                        LDX             FTDI_GCE_EOL
?GCE_DEL_ECHO_TAIL:
                        CPX             FTDI_GCE_LEN
                        BEQ             ?GCE_DEL_ECHO_SPACE
                        TXA
                        TAY
                        LDA             (FTDI_GCE_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_CHAR
                        INX
                        BRA             ?GCE_DEL_ECHO_TAIL
?GCE_DEL_ECHO_SPACE:
                        LDA             #' '
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             FTDI_GCE_LEN
                        SEC
                        SBC             FTDI_GCE_EOL
                        CLC
                        ADC             #$01
                        TAX
?GCE_DEL_ECHO_BACK:
                        CPX             #$00
                        BNE             ?GCE_DEL_BACK_HAVE_COUNT
                        JMP             ?GCE_READ_LOOP
?GCE_DEL_BACK_HAVE_COUNT:
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        DEX
                        BRA             ?GCE_DEL_ECHO_BACK

?GCE_HANDLE_ESC:
                        JSR             ?GCE_GET_RAW_CHAR
                        CMP             #'['
                        BEQ             ?GCE_ESC_HAS_BRACKET
                        CMP             #'O'
                        BEQ             ?GCE_ESC_HAS_O
                        JMP             ?GCE_READ_LOOP
?GCE_ESC_HAS_BRACKET:
                        JSR             ?GCE_GET_RAW_CHAR
                        CMP             #'A'
                        BEQ             ?GCE_ESC_UP
                        CMP             #'C'
                        BEQ             ?GCE_ESC_RIGHT
                        CMP             #'D'
                        BEQ             ?GCE_ESC_LEFT
                        CMP             #'3'
                        BEQ             ?GCE_ESC_DEL_PARAM
                        JMP             ?GCE_READ_LOOP

?GCE_ESC_DEL_PARAM:
                        JSR             ?GCE_GET_RAW_CHAR
                        CMP             #'~'
                        BNE             ?GCE_ESC_DEL_NOT_TILDE
                        JMP             ?GCE_HANDLE_DEL
?GCE_ESC_DEL_NOT_TILDE:
                        JMP             ?GCE_READ_LOOP

?GCE_ESC_HAS_O:
                        JSR             ?GCE_GET_RAW_CHAR
                        CMP             #'A'
                        BEQ             ?GCE_ESC_UP
                        CMP             #'C'
                        BEQ             ?GCE_ESC_RIGHT
                        CMP             #'D'
                        BEQ             ?GCE_ESC_LEFT
                        JMP             ?GCE_READ_LOOP

?GCE_ESC_UP:            JMP             ?GCE_READ_LOOP
; hook for command history

?GCE_ESC_LEFT:
                        LDA             FTDI_GCE_EOL
                        BNE             ?GCE_ESC_LEFT_HAVE_CURSOR
                        JMP             ?GCE_READ_LOOP
?GCE_ESC_LEFT_HAVE_CURSOR:
                        DEC             FTDI_GCE_EOL
                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BNE             ?GCE_ESC_LEFT_HAVE_ECHO
                        JMP             ?GCE_READ_LOOP
?GCE_ESC_LEFT_HAVE_ECHO:
                        LDA             #$08
                        JSR             COR_FTDI_WRITE_CHAR
                        JMP             ?GCE_READ_LOOP

?GCE_ESC_RIGHT:
                        LDA             FTDI_GCE_EOL
                        CMP             FTDI_GCE_LEN
                        BCC             ?GCE_ESC_RIGHT_HAVE_CURSOR
                        JMP             ?GCE_READ_LOOP
?GCE_ESC_RIGHT_HAVE_CURSOR:
                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BEQ             ?GCE_ESC_RIGHT_ADV
                        LDY             FTDI_GCE_EOL
                        LDA             (FTDI_GCE_PTR_LO),Y
                        JSR             COR_FTDI_WRITE_CHAR
?GCE_ESC_RIGHT_ADV:
                        INC             FTDI_GCE_EOL
                        JMP             ?GCE_READ_LOOP

?GCE_HANDLE_EOL:
                        PHA
                        LDA             FTDI_GCE_MODE
                        AND             #FTDI_GCE_MODE_ECHO
                        BEQ             ?GCE_NO_ECHO_EOL
                        LDA             #$0D
                        JSR             COR_FTDI_WRITE_CHAR
                        LDA             #$0A
                        JSR             COR_FTDI_WRITE_CHAR
?GCE_NO_ECHO_EOL:
                        PLA
                        TAX
                        JSR             COR_FTDI_POLL_CHAR
                        BCC             ?GCE_TERM_OK
                        JSR             COR_FTDI_READ_CHAR
                        CPX             #$0D
                        BEQ             ?GCE_FIRST_CR
                        CMP             #$0D
                        BEQ             ?GCE_TERM_OK
                        BRA             ?GCE_PUSHBACK
?GCE_FIRST_CR:
                        CMP             #$0A
                        BEQ             ?GCE_TERM_OK
?GCE_PUSHBACK:
                        STA             FTDI_GCE_PB_CH
                        LDA             #$01
                        STA             FTDI_GCE_PB_VALID
?GCE_TERM_OK:
                        LDY             FTDI_GCE_LEN
                        LDA             #$00
                        STA             (FTDI_GCE_PTR_LO),Y
                        LDA             FTDI_GCE_LEN
                        SEC
                        RTS

?GCE_GET_RAW_CHAR:
                        LDA             FTDI_GCE_PB_VALID
                        BEQ             ?GCE_GET_RAW_READ
                        STZ             FTDI_GCE_PB_VALID
                        LDA             FTDI_GCE_PB_CH
                        RTS
?GCE_GET_RAW_READ:
                        JSR             COR_FTDI_READ_CHAR
                        RTS
                        ENDMOD

                        END
